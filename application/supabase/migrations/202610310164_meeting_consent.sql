begin;
-- Operator attestation only: never grants audio access or external processing.
create table uniion_private.meeting_consents (
 organization_id uuid not null, meeting_id uuid not null,
 version integer not null check(version>0), meeting_version integer not null,
 accepted boolean not null, actor uuid not null references auth.users,
 updated_at timestamptz not null default now(),
 primary key(organization_id,meeting_id),
 foreign key(organization_id,meeting_id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.meeting_consents enable row level security;
revoke all on uniion_private.meeting_consents from public,anon,authenticated;
create function public.uniion_meeting_consent(p_org uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.uniion_resources; c uniion_private.meeting_consents; expected integer;
begin
 if p_action is null or p_action not in ('get','set') or jsonb_typeof(p_payload) is distinct from 'object'
 then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,'reunions');
 if jsonb_typeof(p_payload->'id') is distinct from 'string' then raise insufficient_privilege;end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module='reunions' for update;
 if not found or not exists(select 1 from uniion_private.business_records where organization_id=p_org and id=r.id)
 or not uniion_private.actor_resource(p_org,r.id,auth.uid(),p_action='set') then raise insufficient_privilege;end if;
 select * into c from uniion_private.meeting_consents where organization_id=p_org and meeting_id=r.id;
 if p_action='get' then
  if p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
 else
  if p_payload-array['id','version','meetingVersion','accepted']<>'{}'
   or jsonb_typeof(p_payload->'version') is distinct from 'number'
   or (p_payload->>'version') !~ '^(0|[1-9][0-9]{0,8})$'
   or jsonb_typeof(p_payload->'meetingVersion') is distinct from 'number'
   or (p_payload->>'meetingVersion') !~ '^[1-9][0-9]{0,8}$'
   or jsonb_typeof(p_payload->'accepted') is distinct from 'boolean' then raise insufficient_privilege;end if;
  expected=coalesce(c.version,0);
  if expected<>(p_payload->>'version')::integer or r.version<>(p_payload->>'meetingVersion')::integer then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_consents(organization_id,meeting_id,version,meeting_version,accepted,actor)
   values(p_org,r.id,expected+1,r.version,(p_payload->>'accepted')::boolean,auth.uid())
   on conflict(organization_id,meeting_id) do update set version=excluded.version,meeting_version=excluded.meeting_version,accepted=excluded.accepted,actor=excluded.actor,updated_at=now()
   returning * into c;
  insert into public.uniion_security_events(organization_id,actor,event,details)
   values(p_org,auth.uid(),'meeting.consent',jsonb_build_object('id',r.id,'version',c.version,'meetingVersion',c.meeting_version,'accepted',c.accepted));
 end if;
 return jsonb_build_object('id',r.id,'version',coalesce(c.version,0),'meetingVersion',r.version,
  'attestedMeetingVersion',c.meeting_version,'accepted',coalesce(c.accepted,false),
  'current',coalesce(c.accepted and c.meeting_version=r.version,false),'updatedAt',c.updated_at);
end$$;
revoke all on function public.uniion_meeting_consent(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_meeting_consent(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
