begin;
-- Explicit "new discussion" with the same partner renews stale direct episodes,
-- never on list/get/send and never by restoring an old history grant.
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.messaging_a(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'declare cid uuid;other uuid;','declare renew_user uuid;renewed boolean:=false;boundary bigint;cid uuid;other uuid;');
 d=replace(d,'if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  return uniion_private.message_conversation_json(p_org,cid);',
 'select next_seq+1 into boundary from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
  foreach renew_user in array array[auth.uid(),other] loop
   if not uniion_private.message_current(p_org,cid,renew_user) then
    update uniion_private.message_participations set left_at=clock_timestamp() where organization_id=p_org and conversation=cid and user_id=renew_user and left_at is null;
    insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from)
     select p_org,cid,user_id,joined_at,boundary from public.uniion_memberships where organization_id=p_org and user_id=renew_user;
    renewed=true;
   end if;
  end loop;
  if renewed then
   update uniion_private.message_conversations set version=version+1 where organization_id=p_org and id=cid;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),''message.direct_reinvited'',jsonb_build_object(''conversation'',cid,''visibleFrom'',boundary));
  end if;
  if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  return uniion_private.message_conversation_json(p_org,cid);');
 if position('message.direct_reinvited' in d)=0 then raise exception 'direct renewal patch missing';end if;
 execute d;
end$$;
notify pgrst,'reload schema';commit;
