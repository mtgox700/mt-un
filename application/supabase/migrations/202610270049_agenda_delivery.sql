begin;
create function public.uniion_agenda_export(p_org uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare e uniion_private.agenda_events;
begin
perform public.uniion_module_use(p_org,'agenda');
select * into e from uniion_private.agenda_events where id=p_id and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) or not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.exported',jsonb_build_object('id',e.id,'version',e.version));
return e.data || jsonb_build_object('id',e.id,'version',e.version);
end;$$;
revoke all on function public.uniion_agenda_export(uuid,uuid) from public,anon;
grant execute on function public.uniion_agenda_export(uuid,uuid) to authenticated;
create table uniion_private.agenda_reminders(id uuid primary key default gen_random_uuid(),event_id uuid not null references uniion_private.agenda_events,version integer not null,user_id uuid not null references auth.users,status text not null default 'pending' check(status in ('pending','sending','sent','cancelled','uncertain')),created_at timestamptz not null default now(),finished_at timestamptz,unique(event_id,version,user_id));
alter table uniion_private.agenda_reminders enable row level security;
revoke all on uniion_private.agenda_reminders from public,anon,authenticated;
create function uniion_private.agenda_recipient_allowed(p_event uuid,p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from uniion_private.agenda_events e join uniion_private.agenda_audiences a on a.organization_id=e.organization_id and a.user_id=p_user where e.id=p_event and uniion_private.actor_member(e.organization_id,p_user) and uniion_private.commercial_allowed(e.organization_id,'agenda') and exists(select 1 from public.uniion_module_access where organization_id=e.organization_id and module='agenda' and authorized and enabled and valid_until>now()) and exists(select 1 from public.uniion_permissions where organization_id=e.organization_id and user_id=p_user and module='agenda' and permission='read') and (a.audience='elus' or (a.audience='adherents' and e.data->>'visib' in ('adherents','public')) or (a.audience='public' and e.data->>'visib'='public')));
$$;
create function uniion_private.agenda_enqueue() returns integer language plpgsql security definer set search_path='' as $$
declare n integer;
begin
update uniion_private.agenda_reminders j set status='cancelled',finished_at=now() where status='pending' and not exists(select 1 from uniion_private.agenda_events e where e.id=j.event_id and e.version=j.version and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_recipient_allowed(e.id,j.user_id));
insert into uniion_private.agenda_reminders(event_id,version,user_id)
select e.id,e.version,a.user_id from uniion_private.agenda_events e join uniion_private.agenda_audiences a on a.organization_id=e.organization_id where e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris' >now() and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris' <=now()+interval '48 hours' and uniion_private.agenda_recipient_allowed(e.id,a.user_id) on conflict do nothing;
get diagnostics n=row_count;return n;
end;$$;
create function uniion_private.agenda_claim() returns jsonb language plpgsql security definer set search_path='' as $$
declare j uniion_private.agenda_reminders; address text;
begin
perform uniion_private.agenda_enqueue();
select * into j from uniion_private.agenda_reminders where status='pending' order by created_at for update skip locked limit 1;
if not found then return null;end if;
select email into address from auth.users where id=j.user_id;
if address !~ '^[^[:space:]@]+@(uniion-local[.]example|example[.]invalid)$' then update uniion_private.agenda_reminders set status='cancelled',finished_at=now() where id=j.id;return jsonb_build_object('skipped',true);end if;
update uniion_private.agenda_reminders set status='sending' where id=j.id;
return jsonb_build_object('id',j.id,'email',address);
end;$$;
create function uniion_private.agenda_finish(p_id uuid,p_ok boolean) returns void language sql security definer set search_path='' as $$
update uniion_private.agenda_reminders set status=case when p_ok then 'sent' else 'uncertain' end,finished_at=now() where id=p_id and status='sending';
$$;
create function public.uniion_agenda_notifications(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(jsonb_build_object('id',j.id,'event',e.id,'title',e.data->>'title','date',e.data->>'date','start',e.data->>'start') order by j.created_at desc) from uniion_private.agenda_reminders j join uniion_private.agenda_events e on e.id=j.event_id where e.organization_id=p_org and j.user_id=auth.uid() and j.version=e.version and j.status<>'cancelled' and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_visible(p_org,e.data)),'[]'::jsonb);
end;$$;
revoke all on function uniion_private.agenda_recipient_allowed(uuid,uuid),uniion_private.agenda_enqueue(),uniion_private.agenda_claim(),uniion_private.agenda_finish(uuid,boolean) from public,anon,authenticated;
revoke all on function public.uniion_agenda_notifications(uuid) from public,anon;
grant execute on function public.uniion_agenda_notifications(uuid) to authenticated;
commit;
