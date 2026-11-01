begin;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_rights_change(uuid,uuid,text,text,text,boolean,uuid,timestamptz,boolean)'::regprocedure);
 if position('perform uniion_private.agenda_enqueue();' in definition)=0 then raise exception 'Audience branch missing';end if;
 definition=replace(definition,'perform uniion_private.agenda_enqueue();',
 'update uniion_private.agenda_reminders j set status=''cancelled'',finished_at=now() from uniion_private.agenda_events e where e.id=j.event_id and e.organization_id=p_org and j.user_id=p_user and j.status=''pending'' and not uniion_private.agenda_recipient_allowed(e.id,p_user);');
 execute definition;
end;$patch$;
commit;
