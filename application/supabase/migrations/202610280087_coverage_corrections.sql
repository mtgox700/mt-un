begin;
alter table uniion_private.dues_entries add column coverage_revision bigint not null default 1;
create function uniion_private.coverage_revision() returns trigger language plpgsql set search_path='' as $$begin if new.coverage_end is distinct from old.coverage_end then new.coverage_revision=old.coverage_revision+1;end if;return new;end$$;
create trigger coverage_revision before update on uniion_private.dues_entries for each row execute function uniion_private.coverage_revision();
revoke all on function uniion_private.coverage_revision() from public,anon,authenticated;
create table uniion_private.coverage_corrections(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,entry_id uuid not null,
 actor uuid not null references auth.users,created_at timestamptz not null default now(),request_id uuid not null,
 payload jsonb not null,before_state jsonb not null,after_state jsonb not null,
 unique(organization_id,request_id),foreign key(organization_id,entry_id) references uniion_private.dues_entries(organization_id,id));
alter table uniion_private.coverage_corrections enable row level security;
revoke all on uniion_private.coverage_corrections from public,anon,authenticated;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_coverage_correction;
revoke all on function public.uniion_adherents_before_coverage_correction(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare s uniion_private.dues_schedules;a uniion_private.adherents;e uniion_private.dues_entries;ending date;old_state jsonb;previous uniion_private.coverage_corrections;r jsonb;
begin
 if p_action not in ('coverage_list','coverage_correct') then return public.uniion_adherents_before_coverage_correction(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
 -- Same lock order as cadence confirmation and the generation worker.
 select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
 if not found then raise insufficient_privilege;end if;
 select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;
 if not found then raise insufficient_privilege;end if;
 if p_action='coverage_correct' then
  if not(p_payload ?& array['id','entry','revision','lastDay','reason','request_id']) or p_payload-array['id','entry','revision','lastDay','reason','request_id']<>'{}' or jsonb_typeof(p_payload->'reason')<>'string' or coalesce(length(btrim(p_payload->>'reason')),0) not between 5 and 500 or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
  select * into previous from uniion_private.coverage_corrections where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
  else
   select * into e from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id=(p_payload->>'entry')::uuid for update;
   if not found or e.schedule_id is not null or e.coverage_end is null or e.coverage_revision is distinct from (p_payload->>'revision')::bigint then raise insufficient_privilege;end if;
   ending=uniion_private.adherent_date(p_payload->>'lastDay')+1;
   if ending is null or ending<=e.period or ending=e.coverage_end then raise insufficient_privilege;end if;
   -- Unknown manual periods cannot be crossed either: their start is already known.
   if exists(select 1 from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id<>e.id and period<ending and (coverage_end>e.period or (coverage_end is null and period>=e.period))) then raise insufficient_privilege;end if;
   old_state=jsonb_build_object('period',e.period,'lastDay',e.coverage_end-1,'revision',e.coverage_revision);
   update uniion_private.dues_entries set coverage_end=ending where id=e.id returning * into e;
   update uniion_private.dues_schedules set state=state where id=s.id;
   insert into uniion_private.coverage_corrections(organization_id,entry_id,actor,request_id,payload,before_state,after_state) values(p_org,e.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,old_state,jsonb_build_object('period',e.period,'lastDay',e.coverage_end-1,'revision',e.coverage_revision));
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.coverage_corrected',jsonb_build_object('entry',e.id,'before',old_state,'after',jsonb_build_object('lastDay',e.coverage_end-1,'revision',e.coverage_revision),'reason',btrim(p_payload->>'reason')));
  end if;
 elsif p_payload-array['id']<>'{}' then raise insufficient_privilege;
 end if;
 select jsonb_build_object('coverages',coalesce(jsonb_agg(jsonb_build_object('id',d.id,'period',d.period,'lastDay',d.coverage_end-1,'revision',d.coverage_revision,'cents',d.amount_cents,'history',(select coalesce(jsonb_agg(jsonb_build_object('date',h.created_at,'actor',h.actor,'before',h.before_state,'after',h.after_state,'reason',h.payload->>'reason') order by h.created_at,h.id),'[]') from uniion_private.coverage_corrections h where h.organization_id=p_org and h.entry_id=d.id)) order by d.period,d.id),'[]')) into r from uniion_private.dues_entries d where d.organization_id=p_org and d.adherent_id=a.id and d.schedule_id is null and d.coverage_end is not null;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or unique_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
