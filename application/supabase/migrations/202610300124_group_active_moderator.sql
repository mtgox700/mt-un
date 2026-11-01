begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_messaging(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'if u=auth.uid() or not uniion_private.message_current(p_org,cid,u) then','if u=auth.uid() or not uniion_private.message_current(p_org,cid,u) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=u and module=''messagerie'' and permission=''read'') then');
 d=replace(d,'and p.is_admin and uniion_private.message_current(p_org,cid,p.user_id))','and p.is_admin and uniion_private.message_current(p_org,cid,p.user_id) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=p.user_id and module=''messagerie'' and permission=''read''))');
 execute d;
end$$;
notify pgrst,'reload schema';commit;
