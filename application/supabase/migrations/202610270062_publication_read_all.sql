begin;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_publication_notices(uuid,uuid)'::regprocedure);
 definition=replace(definition,'if p_read is not null then','if p_read=''00000000-0000-0000-0000-000000000000''::uuid then update uniion_private.agenda_publication_notifications set read_at=coalesce(read_at,now()) where id=any(ids) and user_id=auth.uid(); elsif p_read is not null then');
 execute definition;
end;$patch$;
commit;
