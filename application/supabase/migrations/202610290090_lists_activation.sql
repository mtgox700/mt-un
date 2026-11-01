begin;
create table uniion_private.member_lists(id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.uniion_organizations, version int not null default 1,name text not null check(length(btrim(name)) between 1 and 180),description text not null default '' check(length(description)<=500),criteria jsonb not null,request_id uuid not null,actor uuid not null references auth.users,unique(organization_id,request_id));
alter table uniion_private.member_lists enable row level security;
revoke all on uniion_private.member_lists from public,anon,authenticated;
create function uniion_private.member_criteria(c jsonb) returns jsonb language plpgsql set search_path='' as $$begin
 if jsonb_typeof(c) is distinct from 'object' or c-array['q','ent','etab','sect','dir','statut']<>'{}' or exists(select 1 from jsonb_each(c) where jsonb_typeof(value)<>'string' or length(value#>>'{}')>300) or coalesce(c->>'statut','Tous')<>'Tous' then raise insufficient_privilege;end if;return c;
end$$;
revoke all on function uniion_private.member_criteria(jsonb) from public,anon,authenticated;
-- Contract for future campaign modules: authorized directory only, no dispatch or implicit sharing.
create function uniion_private.member_matches(d jsonb,c jsonb) returns boolean language sql immutable set search_path='' as $$select
 (coalesce(c->>'ent','Toutes') in ('','Toutes') or d->>'ent'=c->>'ent') and
 (coalesce(c->>'etab','Tous') in ('','Tous') or d->>'etab'=c->>'etab') and
 (coalesce(c->>'sect','Toutes') in ('','Toutes') or d->>'sect'=c->>'sect') and
 (coalesce(c->>'dir','Toutes') in ('','Toutes') or d->>'dir'=c->>'dir') and
 (coalesce(btrim(c->>'q'),'')='' or strpos(lower(concat_ws(' ',d->>'prenom',d->>'nom',d->>'email',d->>'poste')),lower(btrim(c->>'q')))>0)
$$;
revoke all on function uniion_private.member_matches(jsonb,jsonb) from public,anon,authenticated;
alter function public.uniion_adherents(uuid,text,jsonb) rename to uniion_adherents_before_completion;
revoke all on function public.uniion_adherents_before_completion(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_adherents(p_org uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;g uniion_private.member_lists;a uniion_private.adherents;s uniion_private.dues_schedules;d date;m int;conflicts jsonb;unknowns jsonb;previous uniion_private.schedule_changes;crit jsonb;
begin
 if p_action in ('list_create','list_update','campaign_targets','directory_export','schedule_activate_preview','schedule_activate') then
  perform public.uniion_module_use(p_org,'adherents');
  if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
  if p_action in ('list_create','list_update') then
   if not uniion_private.adherent_permission(p_org,'adherents','write') then raise insufficient_privilege;end if;
   if p_action='list_create' then
    if not(p_payload ?& array['name','description','criteria','request_id']) or p_payload-array['name','description','criteria','request_id']<>'{}' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
    crit=uniion_private.member_criteria(p_payload->'criteria');
    perform pg_advisory_xact_lock(hashtextextended(p_org::text||(p_payload->>'request_id'),0));
    select * into g from uniion_private.member_lists where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
    if found then
     if g.actor<>auth.uid() or g.name is distinct from p_payload->>'name' or g.description is distinct from p_payload->>'description' or g.criteria<>crit then raise insufficient_privilege;end if;
    else
     insert into uniion_private.member_lists(organization_id,name,description,criteria,request_id,actor) values(p_org,p_payload->>'name',p_payload->>'description',crit,(p_payload->>'request_id')::uuid,auth.uid()) returning * into g;
     insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherents.list_created',jsonb_build_object('id',g.id));
    end if;
   else
    if not(p_payload ?& array['id','version','name','description']) or p_payload-array['id','version','name','description']<>'{}' then raise insufficient_privilege;end if;
    update uniion_private.member_lists set name=p_payload->>'name',description=p_payload->>'description',version=version+1 where organization_id=p_org and id=(p_payload->>'id')::uuid and version=(p_payload->>'version')::int returning * into g;
    if not found then raise insufficient_privilege;end if;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherents.list_updated',jsonb_build_object('id',g.id,'version',g.version));
   end if;
  elsif p_action in ('campaign_targets','directory_export') then
   if p_payload-array['list']<>'{}' or (p_action='campaign_targets' and not(p_payload ? 'list')) then raise insufficient_privilege;end if;
   if p_payload ? 'list' then
    select * into g from uniion_private.member_lists where organization_id=p_org and id=(p_payload->>'list')::uuid;
    if not found then raise insufficient_privilege;end if;crit=g.criteria;
   else crit='{}';end if;
   if p_action='directory_export' and not uniion_private.adherent_permission(p_org,'adherents','export') then raise insufficient_privilege;end if;
   select jsonb_build_object('contract','uniion.members.targets.v1','organization',p_org,'list',g.id,'version',g.version,'delivery','not_requested','rows',coalesce(jsonb_agg(jsonb_build_object('id',id,'version',version,'prenom',data->>'prenom','nom',data->>'nom','email',data->>'email','ent',data->>'ent','etab',data->>'etab') order by id),'[]')) into r from uniion_private.adherents where organization_id=p_org and uniion_private.member_matches(data,crit);
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case p_action when 'directory_export' then 'adherents.directory_export' else 'adherents.targets_read' end,jsonb_build_object('list',g.id,'count',jsonb_array_length(r->'rows')));
   return r;
  else
   if not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
   if p_payload-array['id','start','memberVersion','request_id']<>'{}' then raise insufficient_privilege;end if;
   select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
   if not found or a.ended_on is not null then raise insufficient_privilege;end if;
   if p_action='schedule_activate' then
    select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
    if found then
     if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;return public.uniion_adherents(p_org,'list','{}');
    end if;
   end if;
   if exists(select 1 from uniion_private.dues_schedules where organization_id=p_org and adherent_id=a.id) then raise insufficient_privilege;end if;
   d=uniion_private.adherent_date(p_payload->>'start');m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
   if d is null or d<=(now() at time zone 'Europe/Paris')::date or a.joined_on is null or d<a.joined_on or m is null or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 then raise insufficient_privilege;end if;
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'cents',amount_cents)),'[]') into unknowns from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end is null;
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'lastDay',coverage_end-1)),'[]') into conflicts from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end>date_trunc('month',d)::date;
   if p_action='schedule_activate_preview' then return jsonb_build_object('preview',jsonb_build_object('activation',true,'memberVersion',a.version,'oldMonths',0,'oldCents',0,'months',m,'cents',(a.dues_terms->>'cents')::bigint,'start',d,'periodStart',date_trunc('month',d)::date,'lastDay',(date_trunc('month',d)+make_interval(months=>m))::date-1,'unknown',unknowns,'conflicts',conflicts,'canConfirm',unknowns='[]' and conflicts='[]'));end if;
   if p_payload->>'request_id' is null or a.version is distinct from (p_payload->>'memberVersion')::int or unknowns<>'[]' or conflicts<>'[]' then raise insufficient_privilege;end if;
   insert into uniion_private.dues_schedules(organization_id,adherent_id,anchor,member_anchor,months,amount_cents,actor) values(p_org,a.id,d,a.joined_on,m,(a.dues_terms->>'cents')::bigint,auth.uid()) returning * into s;
   insert into uniion_private.schedule_changes(organization_id,schedule_id,actor,request_id,payload,before_state,after_state) values(p_org,s.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,'{}',to_jsonb(s));
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_activated',jsonb_build_object('id',a.id,'start',d));
  end if;
  r=public.uniion_adherents_before_completion(p_org,'list','{}');
 else r=public.uniion_adherents_before_completion(p_org,p_action,p_payload);end if;
 if r ? 'rows' then
  r=r||jsonb_build_object('canManageLists',uniion_private.adherent_permission(p_org,'adherents','write'),'groups',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'name',name,'desc',description,'crit',criteria,'type','dyn','canal','E-mail') order by name,id) from uniion_private.member_lists where organization_id=p_org),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation or unique_violation then raise insufficient_privilege;
end$$;
revoke all on function public.uniion_adherents(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_adherents(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
