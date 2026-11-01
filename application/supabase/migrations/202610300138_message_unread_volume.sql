begin;
-- Membership is constant within this statement. Check it once per conversation;
-- preserve the current episode/history bounds and recheck every forward chain.
create or replace function uniion_private.message_unread(o uuid,c uuid) returns bigint language sql stable security definer set search_path='' as $$
 select case when uniion_private.message_member(o,c) then (
  select count(*) from uniion_private.message_participations p
  join uniion_private.messages m on m.organization_id=p.organization_id and m.conversation=p.conversation
  left join uniion_private.message_reads r on r.organization_id=p.organization_id and r.conversation=p.conversation and r.participation=p.id
  where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null
  and m.author<>auth.uid() and m.seq>coalesce(r.seq,0)
  and (m.seq>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.message_seq=m.seq and g.revoked_at is null))
  and (not exists(select 1 from uniion_private.message_forwards f where f.organization_id=o and f.conversation=c and f.seq=m.seq) or uniion_private.message_visible(o,c,m.seq))
 ) else 0 end
$$;
notify pgrst,'reload schema';commit;
