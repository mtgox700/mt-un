begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_adherents(uuid,text,jsonb)'::regprocedure);
 d=replace(d,$q$uniion_private.adherent_permission(p_org,'adherents','export')$q$,$q$uniion_private.authority(p_org,auth.uid(),'download')$q$);execute d;
end$$;
notify pgrst,'reload schema';
commit;
