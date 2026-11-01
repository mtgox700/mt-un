begin;
do $patch$
declare d text;
begin
 d=pg_get_functiondef('public.uniion_agenda_work(uuid,uuid,text,jsonb)'::regprocedure);
 d=replace(d,$old$'sourceVersion',d.source_version)$old$,$new$'sourceVersion',d.source_version,'canWrite',exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write'))$new$);
 execute d;
end;$patch$;
commit;
