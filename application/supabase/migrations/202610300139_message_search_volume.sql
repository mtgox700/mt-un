begin;
alter function public.uniion_messaging(uuid,text,jsonb) rename to uniion_messaging_before_search_volume;
revoke all on function public.uniion_messaging_before_search_volume(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare q text;rows jsonb;cursor_value text;
begin
 if p_action not in ('search','targets') then return public.uniion_messaging_before_search_volume(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or not(p_payload ? 'query') or p_payload-array['query','before']<>'{}' or jsonb_typeof(p_payload->'query')<>'string' or length(p_payload->>'query')>200 or (p_action='search' and length(btrim(p_payload->>'query'))<1) or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
 q=lower(btrim(p_payload->>'query'));
 if p_action='targets' then
  with titles as materialized (
   select c.id,c.kind,uniion_private.message_conversation_before_live(p_org,c.id)->>'name' name
   from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id) and (not(p_payload ? 'before') or c.id<(p_payload->>'before')::uuid)
  ), page as materialized (select * from titles where strpos(lower(name),q)>0 order by id desc limit 50)
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'name',name) order by id desc),'[]'),case when count(*)=50 then min(id::text) end into rows,cursor_value from page;
 else
  -- Materialization prevents PostgreSQL from reevaluating a recursive source ACL
  -- for each field. Titles are computed once per authorized conversation.
  with titles as materialized (
   select c.id,c.kind,uniion_private.message_conversation_before_live(p_org,c.id)->>'name' name
   from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id)
  ), origins as materialized (
   select m,uniion_private.message_origin(p_org,m.conversation,m.seq) original
   from uniion_private.messages m join titles t on t.id=m.conversation
   where m.organization_id=p_org and (not(p_payload ? 'before') or m.id<(p_payload->>'before')::uuid)
  ), page as materialized (
   select o.m,t.name,t.kind from origins o join titles t on t.id=(o.m).conversation
   where (o.original).id is not null and
   (strpos(lower((o.original).body),q)>0 or strpos(lower(t.name),q)>0 or exists(select 1 from uniion_private.message_files f join public.uniion_attachments a on a.id=f.attachment where f.organization_id=p_org and f.conversation=(o.original).conversation and f.seq=(o.original).seq and strpos(lower(a.filename),q)>0))
   order by (o.m).id desc limit 50
  ) select coalesce(jsonb_agg(jsonb_build_object('id',(m).id,'conversation',(m).conversation,'name',name,'kind',kind,'message',uniion_private.message_json(m)) order by (m).id desc),'[]'),case when count(*)=50 then min((m).id::text) end into rows,cursor_value from page;
 end if;
 return jsonb_build_object('rows',rows,'next',cursor_value);
end$$;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
