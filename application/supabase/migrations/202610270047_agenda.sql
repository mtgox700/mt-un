begin;
create table uniion_private.agenda_audiences(organization_id uuid references public.uniion_organizations(id),user_id uuid references auth.users(id),audience text not null check(audience in ('elus','adherents','public')),primary key(organization_id,user_id));
create table uniion_private.agenda_events(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.uniion_organizations(id),creator uuid not null references auth.users(id),version integer not null default 1,data jsonb not null,updated_at timestamptz not null default now());
alter table uniion_private.agenda_events enable row level security;
alter table uniion_private.agenda_audiences enable row level security;
revoke all on uniion_private.agenda_events,uniion_private.agenda_audiences from public,anon,authenticated;
create function uniion_private.agenda_visible(p_org uuid,p_data jsonb) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from uniion_private.agenda_audiences where organization_id=p_org and user_id=auth.uid() and (audience='elus' or (audience='adherents' and p_data->>'visib' in ('adherents','public')) or (audience='public' and p_data->>'visib'='public')));
$$;
create function public.uniion_agenda_list(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(data || jsonb_build_object('id',id,'version',version,'org','Organisation','invites','[]'::jsonb) order by data->>'date',data->>'start') from uniion_private.agenda_events where organization_id=p_org and uniion_private.agenda_visible(p_org,data)),'[]'::jsonb);
end;$$;
create function public.uniion_agenda_save(p_org uuid,p_event jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare eid uuid; oldrow uniion_private.agenda_events; payload jsonb; ver integer;
begin
perform public.uniion_module_use(p_org,'agenda');
if jsonb_typeof(p_event)<>'object' or p_event - array['id','version','title','type','date','start','end','lieu','visib','notes','rappel'] <> '{}'::jsonb or not (p_event ?& array['title','type','date','start','end','lieu','visib','notes','rappel']) then raise insufficient_privilege;end if;
payload=p_event-array['id','version'];
if exists(select 1 from jsonb_each(payload) where key<>'rappel' and jsonb_typeof(value)<>'string') or jsonb_typeof(payload->'rappel')<>'boolean' or length(trim(payload->>'title')) not between 1 and 200 or length(payload->>'notes')>4000 or length(payload->>'lieu')>300 or payload->>'type' not in ('cse','nego','perm','form','ag','ech') or payload->>'visib' not in ('elus','adherents','public') or payload->>'date' !~ '^\d{4}-\d{2}-\d{2}$' or payload->>'start' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or payload->>'end' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or payload->>'end'<=payload->>'start' then raise insufficient_privilege;end if;
perform (payload->>'date')::date;
if not uniion_private.agenda_visible(p_org,payload) then raise insufficient_privilege;end if;
if p_event ? 'id' then
select * into oldrow from uniion_private.agenda_events where id=(p_event->>'id')::uuid and organization_id=p_org for update;
if not found or not uniion_private.agenda_visible(p_org,oldrow.data) or oldrow.version is distinct from (p_event->>'version')::integer or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='agenda' and permission='write') then raise insufficient_privilege;end if;
eid=oldrow.id;ver=oldrow.version+1;
update uniion_private.agenda_events set data=payload,version=ver,updated_at=now() where id=eid;
else
if not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='agenda' and permission='create') then raise insufficient_privilege;end if;
insert into uniion_private.agenda_events(organization_id,creator,data) values(p_org,auth.uid(),payload) returning id,version into eid,ver;
end if;
insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.saved',jsonb_build_object('id',eid,'version',ver));
return payload || jsonb_build_object('id',eid,'version',ver,'org','Organisation','invites','[]'::jsonb);
end;$$;
revoke all on function uniion_private.agenda_visible(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.uniion_agenda_list(uuid),public.uniion_agenda_save(uuid,jsonb) from public,anon;
grant execute on function public.uniion_agenda_list(uuid),public.uniion_agenda_save(uuid,jsonb) to authenticated;
commit;
