begin;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_publication(uuid,uuid,text,jsonb)'::regprocedure);
 definition=replace(definition,$old$if not uniion_private.authority(p_org,auth.uid(),'agenda_review') or auth.uid()=d.updated_by then raise insufficient_privilege;end if;$old$,$new$if not uniion_private.authority(p_org,auth.uid(),'agenda_review') or auth.uid()=d.updated_by or (r.published_at is not null and r.source_version<>e.version) then raise insufficient_privilege;end if;$new$);
 execute definition;
end;$patch$;
commit;
