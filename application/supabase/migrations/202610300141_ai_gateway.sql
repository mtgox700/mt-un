begin;
insert into uniion_private.module_catalog(id,name) values('assistant','Assistant IA');
create table uniion_private.ai_providers(
 id text primary key check(id='codex-local'), approved boolean not null default false,
 version integer not null default 1 check(version>0),
 scope text not null default 'fixture-only' check(scope='fixture-only'),
 reviewed_by uuid references auth.users, reviewed_at timestamptz
);
insert into uniion_private.ai_providers(id) values('codex-local');
create table uniion_private.ai_activations(
 organization_id uuid primary key references public.uniion_organizations,
 provider text not null references uniion_private.ai_providers,
 provider_version integer not null,
 enabled boolean not null default false,
 version integer not null default 1 check(version>0),
 updated_by uuid not null references auth.users,updated_at timestamptz not null default now()
);
alter table uniion_private.ai_providers enable row level security;
alter table uniion_private.ai_activations enable row level security;
revoke all on uniion_private.ai_providers,uniion_private.ai_activations from public,anon,authenticated;
create function public.uniion_ai_policy(p_org uuid,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p uniion_private.ai_providers; a uniion_private.ai_activations; ready boolean;
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or p_action is null or jsonb_typeof(p_payload) is distinct from 'object'
 or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 if p_action not in ('status','authorize','approve','activate') then raise insufficient_privilege;end if;
 if p_action in ('approve','activate') then perform pg_advisory_xact_lock(72420801);end if;
 select * into p from uniion_private.ai_providers where id='codex-local';
 select * into a from uniion_private.ai_activations where organization_id=p_org;
 if p_action='approve' then
  if not uniion_private.super_admin() or not(p_payload ?& array['enabled','version']) or p_payload-array['enabled','version']<>'{}'
   or jsonb_typeof(p_payload->'enabled') is distinct from 'boolean' or jsonb_typeof(p_payload->'version') is distinct from 'number'
   or p_payload->>'version' !~ '^[1-9][0-9]{0,8}$' or (p_payload->>'version')::integer<>p.version then raise insufficient_privilege;end if;
  update uniion_private.ai_providers set approved=(p_payload->>'enabled')::boolean,version=version+1,reviewed_by=auth.uid(),reviewed_at=now() where id=p.id returning * into p;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.provider_reviewed',jsonb_build_object('provider',p.id,'approved',p.approved,'version',p.version,'scope',p.scope));
 elsif p_action='activate' then
  if not uniion_private.actor_member(p_org,auth.uid()) or not uniion_private.authority(p_org,auth.uid(),'organization_edit')
   or not(p_payload ?& array['enabled','version','providerVersion']) or p_payload-array['enabled','version','providerVersion']<>'{}'
   or jsonb_typeof(p_payload->'enabled') is distinct from 'boolean' or jsonb_typeof(p_payload->'version') is distinct from 'number'
   or jsonb_typeof(p_payload->'providerVersion') is distinct from 'number'
   or p_payload->>'version' !~ '^[0-9]{1,9}$' or p_payload->>'providerVersion' !~ '^[1-9][0-9]{0,8}$'
   or (p_payload->>'version')::integer<>coalesce(a.version,0) or (p_payload->>'providerVersion')::integer<>p.version
   or ((p_payload->>'enabled')::boolean and not p.approved) then raise insufficient_privilege;end if;
  insert into uniion_private.ai_activations values(p_org,p.id,p.version,(p_payload->>'enabled')::boolean,1,auth.uid(),now())
  on conflict(organization_id) do update set provider_version=excluded.provider_version,enabled=excluded.enabled,version=ai_activations.version+1,updated_by=auth.uid(),updated_at=now() returning * into a;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.activation_changed',jsonb_build_object('provider',p.id,'enabled',a.enabled,'version',a.version));
 else
  perform public.uniion_module_use(p_org,'assistant');
  if p_payload<>'{}' then raise insufficient_privilege;end if;
 end if;
 ready=p.approved and coalesce(a.enabled and a.provider_version=p.version,false);
 if p_action='authorize' then
  if not ready or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='assistant' and permission='write') then raise insufficient_privilege;end if;
 end if;
 return jsonb_build_object('provider',p.id,'approved',p.approved,'providerVersion',p.version,'activationVersion',coalesce(a.version,0),'enabled',coalesce(a.enabled,false),'ready',ready,'scope',p.scope,'actor',auth.uid());
end $$;
revoke all on function public.uniion_ai_policy(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_ai_policy(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
