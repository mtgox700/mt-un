begin;
create index messages_search_cursor on uniion_private.messages(organization_id,id desc);
alter function public.uniion_messaging(uuid,text,jsonb) rename to uniion_messaging_before_search;
revoke all on function public.uniion_messaging_before_search(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cid uuid;s bigint;targets uuid[];target uuid;client uuid;prior uniion_private.message_forward_batches;item jsonb;result jsonb:='[]';q text;rows jsonb;cursor_value text;origin uniion_private.messages;depth integer;rc uuid;rs bigint;f uniion_private.message_forwards;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action not in ('forward','search','locate','targets') then return public.uniion_messaging_before_search(p_org,p_action,p_payload);end if;
 if p_action in ('search','targets') then
  if not(p_payload ? 'query') or p_payload-array['query','before']<>'{}' or jsonb_typeof(p_payload->'query')<>'string' or length(p_payload->>'query')>200 or (p_action='search' and length(btrim(p_payload->>'query'))<1) or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
  q=lower(btrim(p_payload->>'query'));
  if p_action='targets' then
   select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'kind',r.kind) order by r.id desc),'[]'),case when count(*)=50 then min(r.id::text) end into rows,cursor_value from (
    select cv.id,cv.kind,uniion_private.message_conversation_json(p_org,cv.id)->>'name' name from uniion_private.message_conversations cv where cv.organization_id=p_org and uniion_private.message_member(p_org,cv.id) and (not(p_payload ? 'before') or cv.id<(p_payload->>'before')::uuid) and strpos(lower(uniion_private.message_conversation_json(p_org,cv.id)->>'name'),q)>0 order by cv.id desc limit 50)r;
  else
   select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'conversation',r.conversation,'name',r.name,'kind',r.kind,'message',r.projection) order by r.id desc),'[]'),case when count(*)=50 then min(r.id::text) end into rows,cursor_value from (
    select m.id,m.conversation,cv.kind,uniion_private.message_conversation_json(p_org,m.conversation)->>'name' name,uniion_private.message_json(m) projection
    from uniion_private.messages m join uniion_private.message_conversations cv on cv.organization_id=m.organization_id and cv.id=m.conversation
    cross join lateral (select uniion_private.message_origin(p_org,m.conversation,m.seq) original) resolved
    where m.organization_id=p_org and (not(p_payload ? 'before') or m.id<(p_payload->>'before')::uuid) and (resolved.original).id is not null
    and (strpos(lower((resolved.original).body),q)>0 or strpos(lower(uniion_private.message_conversation_json(p_org,m.conversation)->>'name'),q)>0 or exists(select 1 from uniion_private.message_files mf join public.uniion_attachments a on a.id=mf.attachment where mf.organization_id=p_org and mf.conversation=(resolved.original).conversation and mf.seq=(resolved.original).seq and strpos(lower(a.filename),q)>0))
    order by m.id desc limit 50)r;
  end if;
  return jsonb_build_object('rows',rows,'next',cursor_value);
 end if;
 if p_action='locate' then
  if not(p_payload ?& array['id','seq']) or p_payload-array['id','seq']<>'{}' or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;
  if not uniion_private.message_visible(p_org,cid,s) then raise insufficient_privilege;end if;
  select jsonb_agg(uniion_private.message_json(m) order by m.seq),case when count(*)=50 then min(m.seq)::text end into rows,cursor_value from (select * from uniion_private.messages where organization_id=p_org and conversation=cid and seq<=s and uniion_private.message_visible(p_org,cid,seq) order by seq desc limit 50)m;
  return uniion_private.message_conversation_json(p_org,cid)||jsonb_build_object('messages',coalesce(rows,'[]'),'next',cursor_value,'focused',s::text);
 end if;
 if not(p_payload ?& array['id','seq','clientId','targets']) or p_payload-array['id','seq','clientId','targets']<>'{}' or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' or jsonb_typeof(p_payload->'clientId')<>'string' or jsonb_typeof(p_payload->'targets')<>'array' or jsonb_array_length(p_payload->'targets') not between 1 and 20 or exists(select 1 from jsonb_array_elements(p_payload->'targets')v where jsonb_typeof(v)<>'string') then raise insufficient_privilege;end if;
 cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;client=(p_payload->>'clientId')::uuid;
 select array_agg(v::uuid order by v::uuid) into targets from jsonb_array_elements_text(p_payload->'targets')v;
 if cid=any(targets) or cardinality(targets)<>(select count(distinct t) from unnest(targets)t) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='write') then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||client::text,0));
 -- Acquire all source-chain and destination locks in UUID order, matching membership mutations.
 perform 1 from uniion_private.message_conversations cv where cv.organization_id=p_org and (cv.id=any(targets) or cv.id in(with recursive chain(c,s,d) as(select cid,s,0 union all select f0.source_conversation,f0.source_seq,ch.d+1 from chain ch join uniion_private.message_forwards f0 on f0.organization_id=p_org and f0.conversation=ch.c and f0.seq=ch.s where ch.d<8)select c from chain)) order by cv.id for update;
 origin=uniion_private.message_origin(p_org,cid,s);
 if origin.id is null then raise insufficient_privilege;end if;
 foreach target in array targets loop
  if not uniion_private.message_member(p_org,target) then raise insufficient_privilege;end if;
 end loop;
 select * into prior from uniion_private.message_forward_batches where organization_id=p_org and actor=auth.uid() and client_id=client;
 if found then
  if prior.source_conversation<>cid or prior.source_seq<>s or prior.targets<>targets then raise insufficient_privilege;end if;
  for item in select value from jsonb_array_elements(prior.result) loop
   if not uniion_private.message_visible(p_org,(item->>'conversation')::uuid,(item->>'seq')::bigint) then raise insufficient_privilege;end if;
  end loop;
  return jsonb_build_object('rows',prior.result,'already',true);
 end if;
 rc=cid;rs=s;
 for depth in 0..7 loop
  select * into f from uniion_private.message_forwards where organization_id=p_org and conversation=rc and seq=rs;
  exit when not found;rc=f.source_conversation;rs=f.source_seq;
  if depth=7 then raise insufficient_privilege;end if;
 end loop;
 foreach target in array targets loop
  if exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=target and author=auth.uid() and client_id=client) then raise insufficient_privilege;end if;
  item=public.uniion_messaging_before_search(p_org,'send',jsonb_build_object('id',target,'clientId',client,'text','Référence de message'));
  insert into uniion_private.message_forwards values(p_org,target,(item->>'seq')::bigint,cid,s);
  result=result||jsonb_build_array(jsonb_build_object('conversation',target,'seq',item->>'seq','id',item->>'id'));
 end loop;
 insert into uniion_private.message_forward_batches values(p_org,auth.uid(),client,cid,s,targets,result);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.forwarded_reference',jsonb_build_object('source',cid,'seq',s,'targets',targets,'clientId',client));
 return jsonb_build_object('rows',result,'already',false);
end$$;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
