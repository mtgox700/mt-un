begin;
alter function public.uniion_messaging(uuid,text,jsonb) rename to uniion_messaging_before_mark_all;
revoke all on function public.uniion_messaging_before_mark_all(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r record;
begin
 if p_action<>'read_all' then return public.uniion_messaging_before_mark_all(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if p_payload is distinct from '{}'::jsonb then raise insufficient_privilege;end if;
 for r in select m.conversation,max(m.seq) seq from uniion_private.messages m where m.organization_id=p_org and uniion_private.message_visible(p_org,m.conversation,m.seq) group by m.conversation order by m.conversation loop
  perform public.uniion_messaging_before_mark_all(p_org,'read',jsonb_build_object('id',r.conversation,'seq',r.seq::text));
 end loop;
 return jsonb_build_object('read',true);
end$$;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
