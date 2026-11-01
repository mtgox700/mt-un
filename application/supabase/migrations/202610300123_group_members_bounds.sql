begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_messaging(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'jsonb_array_length(p_payload->''members'') not between 1 and 99','jsonb_array_length(p_payload->''members'') not between 0 and 99');
 d=replace(d,'array_agg(v::uuid order by v::uuid) into members','coalesce(array_agg(v::uuid order by v::uuid),array[]::uuid[]) into members');
 d=replace(d,'if p_action=''group_create'' then','if p_action=''group_create'' then if cardinality(members)=0 then raise insufficient_privilege;end if;');
 d=replace(d,'if not found or target.user_id=auth.uid() or not uniion_private.message_current(p_org,cid,target.user_id) then','if not found or target.user_id=auth.uid() or not uniion_private.message_current(p_org,cid,target.user_id) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=target.user_id and module=''messagerie'' and permission=''read'') then');
 execute d;
end$$;
notify pgrst,'reload schema';commit;
