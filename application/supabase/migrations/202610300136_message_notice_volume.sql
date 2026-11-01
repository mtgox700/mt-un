begin;
-- Select the bounded authorized page before projecting conversation metadata.
-- The previous projection recomputed the full unread count per candidate message.
create index message_notice_order on uniion_private.messages(organization_id,created_at desc,id);
alter function public.uniion_messaging(uuid,text,jsonb) rename to uniion_messaging_before_notice_volume;
revoke all on function public.uniion_messaging_before_notice_volume(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_action<>'notices' then return public.uniion_messaging_before_notice_volume(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if p_payload is distinct from '{}'::jsonb then raise insufficient_privilege;end if;
 return (with candidates as materialized (
  select m.id,m.conversation,m.seq,m.created_at from uniion_private.messages m
  where m.organization_id=p_org and m.author<>auth.uid()
  and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=p_org and r.conversation=m.conversation and p.user_id=auth.uid() and p.left_at is null),0)
  and uniion_private.message_visible(p_org,m.conversation,m.seq)
  order by m.created_at desc,m.id limit 50
 ), titles as materialized (
  select c.conversation,uniion_private.message_conversation_before_live(p_org,c.conversation)->>'name' title from (select distinct conversation from candidates)c
 ) select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'conversation',m.conversation,'seq',m.seq::text,'title',t.title,'created',m.created_at) order by m.created_at desc,m.id),'[]'::jsonb) from candidates m join titles t using(conversation));
end$$;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
