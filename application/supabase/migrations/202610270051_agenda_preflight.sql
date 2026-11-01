begin;
create function uniion_private.agenda_preflight(p_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare valid boolean;
begin
select exists(select 1 from uniion_private.agenda_reminders j join uniion_private.agenda_events e on e.id=j.event_id where j.id=p_id and j.status='sending' and j.version=e.version and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_recipient_allowed(e.id,j.user_id)) into valid;
if not valid then update uniion_private.agenda_reminders set status='cancelled',finished_at=now() where id=p_id and status='sending';end if;
return valid;
end;$$;
revoke all on function uniion_private.agenda_preflight(uuid) from public,anon,authenticated;
commit;
