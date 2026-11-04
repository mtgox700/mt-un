--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: uniion_private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA uniion_private;


--
-- Name: uniion_adherents(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;g uniion_private.member_lists;a uniion_private.adherents;s uniion_private.dues_schedules;d date;m int;conflicts jsonb;unknowns jsonb;previous uniion_private.schedule_changes;crit jsonb;
begin
 if p_action in ('list_create','list_update','campaign_targets','directory_export','schedule_activate_preview','schedule_activate') then
  perform public.uniion_module_use(p_org,'adherents');
  if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
  if p_action in ('list_create','list_update') then
   if not uniion_private.adherent_permission(p_org,'adherents','write') then raise insufficient_privilege;end if;
   if p_action='list_create' then
    if not(p_payload ?& array['name','description','criteria','request_id']) or p_payload-array['name','description','criteria','request_id']<>'{}' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
    crit=uniion_private.member_criteria(p_payload->'criteria');if coalesce(crit->>'statut','Tous')<>'Tous' and not uniion_private.adherent_permission(p_org,'cotisations','read') then raise insufficient_privilege;end if;
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
    update uniion_private.member_lists set name=p_payload->>'name',description=p_payload->>'description',version=version+1 where organization_id=p_org and id=(p_payload->>'id')::uuid and version=(p_payload->>'version')::int and (coalesce(criteria->>'statut','Tous')='Tous' or uniion_private.adherent_permission(p_org,'cotisations','read')) returning * into g;
    if not found then raise insufficient_privilege;end if;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherents.list_updated',jsonb_build_object('id',g.id,'version',g.version));
   end if;
  elsif p_action in ('campaign_targets','directory_export') then
   if p_payload-array['list']<>'{}' or (p_action='campaign_targets' and not(p_payload ? 'list')) then raise insufficient_privilege;end if;
   if p_payload ? 'list' then
    select * into g from uniion_private.member_lists where organization_id=p_org and id=(p_payload->>'list')::uuid;
    if not found then raise insufficient_privilege;end if;crit=g.criteria;if coalesce(crit->>'statut','Tous')<>'Tous' and not uniion_private.adherent_permission(p_org,'cotisations','read') then raise insufficient_privilege;end if;
   else crit='{}';end if;
   if p_action='directory_export' and not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
   select jsonb_build_object('contract','uniion.members.targets.v1','organization',p_org,'list',g.id,'version',g.version,'delivery','not_requested','rows',coalesce(jsonb_agg(jsonb_build_object('id',id,'version',version,'prenom',data->>'prenom','nom',data->>'nom','email',data->>'email','ent',data->>'ent','etab',data->>'etab') order by id),'[]')) into r from uniion_private.adherents where organization_id=p_org and uniion_private.member_matches(data,crit) and (coalesce(crit->>'statut','Tous')='Tous' or uniion_private.member_dues_status(p_org,id)=crit->>'statut');
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
  if coalesce((r->>'financial')::boolean,false) then r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('statut',uniion_private.member_dues_status(p_org,(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));end if;
  r=r||jsonb_build_object('canManageLists',uniion_private.adherent_permission(p_org,'adherents','write'),'groups',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'name',name,'desc',description,'crit',criteria,'type','dyn','canal','E-mail') order by name,id) from uniion_private.member_lists where organization_id=p_org and (coalesce(criteria->>'statut','Tous')='Tous' or uniion_private.adherent_permission(p_org,'cotisations','read'))),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation or unique_violation then raise insufficient_privilege;
end$$;


--
-- Name: uniion_adherents_before_cadence(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_cadence(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;s uniion_private.dues_schedules;a uniion_private.adherents;proposal jsonb;previous uniion_private.schedule_changes;old_state jsonb;
begin
 if p_action in ('schedule_preview','schedule_resume') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ? 'id') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;
  if p_action='schedule_preview' then
   if p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
   return jsonb_build_object('preview',uniion_private.schedule_proposal(s,a));
  end if;
  if p_payload->>'request_id' is null or not(p_payload ?& array['revision','memberVersion','nextDue','request_id']) or p_payload-array['id','revision','memberVersion','nextDue','request_id']<>'{}' then raise insufficient_privilege;end if;
  select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if previous.payload<>p_payload or previous.actor<>auth.uid() then raise insufficient_privilege;end if;
  else
   proposal=uniion_private.schedule_proposal(s,a);
   if s.revision is distinct from (p_payload->>'revision')::bigint or a.version is distinct from (p_payload->>'memberVersion')::int or proposal->>'nextDue' is distinct from p_payload->>'nextDue' then raise insufficient_privilege;end if;
   old_state=to_jsonb(s);
   update uniion_private.dues_schedules set state='active',amount_cents=(proposal->>'cents')::bigint,next_index=(proposal->>'nextIndex')::int,actor=auth.uid() where id=s.id returning * into s;
   insert into uniion_private.schedule_changes(organization_id,schedule_id,actor,request_id,payload,before_state,after_state) values(p_org,s.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,old_state,to_jsonb(s));
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_resumed',jsonb_build_object('schedule',s.id,'revision',s.revision,'skipped',proposal->'skipped','previousCents',proposal->'oldCents','cents',proposal->'cents','nextDue',proposal->'nextDue'));
  end if;
  r=public.uniion_adherents_before_resume(p_org,'list','{}');
 else r=public.uniion_adherents_before_resume(p_org,p_action,p_payload);end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('schedule',(select jsonb_build_object('state',s2.state,'revision',s2.revision,'nextDue',uniion_private.dues_occurrence(s2.anchor,s2.months,s2.next_index),'cents',s2.amount_cents,'months',s2.months,'needsReview',a2.joined_on is distinct from s2.anchor or a2.dues_terms->>'cents' is distinct from s2.amount_cents::text or (case a2.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s2.months) from uniion_private.dues_schedules s2 join uniion_private.adherents a2 on a2.id=s2.adherent_id and a2.organization_id=s2.organization_id where s2.organization_id=p_org and s2.adherent_id=(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation then raise insufficient_privilege;
end$$;


--
-- Name: uniion_adherents_before_completion(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_completion(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a uniion_private.adherents;s uniion_private.dues_schedules;d date;first_due date;m int;today date=(now() at time zone 'Europe/Paris')::date;old_state jsonb;previous uniion_private.membership_changes;r jsonb;issues jsonb;can_manage boolean;
begin
 if p_action in ('membership_return_preview','membership_return','membership_end_correct') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'adherents','write') or not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  if p_action<>'membership_return_preview' then
   if p_payload->>'request_id' is null or jsonb_typeof(p_payload->'reason')<>'string' or coalesce(length(btrim(p_payload->>'reason')),0) not between 5 and 500 then raise insufficient_privilege;end if;
   select * into previous from uniion_private.membership_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if previous.actor<>auth.uid() or previous.action<>p_action or previous.payload<>p_payload then raise insufficient_privilege;end if;
    return public.uniion_adherents(p_org,'list','{}');
   end if;
  end if;
  d=uniion_private.adherent_date(p_payload->>'date');
  if a.ended_on is null or d is null or a.joined_on is null then raise insufficient_privilege;end if;
  old_state=jsonb_build_object('joinedOn',a.joined_on,'endedOn',a.ended_on,'cycle',a.membership_cycle,'version',a.version,'schedule',to_jsonb(s));
  if p_action='membership_end_correct' then
   if not(p_payload ?& array['id','version','date','reason','request_id']) or p_payload-array['id','version','date','reason','request_id']<>'{}' or a.version is distinct from (p_payload->>'version')::int or d<a.joined_on or d=a.ended_on then raise insufficient_privilege;end if;
   update uniion_private.adherents set ended_on=d,version=version+1,updated_at=now() where id=a.id returning * into a;
   update uniion_private.dues_schedules set state=case when d<=today then 'stopped' else 'paused' end where id=s.id;
  else
   if p_payload-array['id','version','date','mode','firstDue','reason','request_id','scheduleRevision']<>'{}' or coalesce(p_payload->>'mode','') not in ('paused','resume') or d<today or d<a.ended_on or a.ended_on>today then raise insufficient_privilege;end if;
   issues='[]';first_due=null;m=null;
   if p_payload->>'mode'='resume' then
    first_due=uniion_private.adherent_date(p_payload->>'firstDue');m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
    if s.id is null or first_due is null or first_due<d or first_due<today or m is null or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 then raise insufficient_privilege;end if;
    select coalesce(jsonb_agg(jsonb_build_object('period',period,'lastDay',coverage_end-1) order by period,id),'[]') into issues from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and (coverage_end is null or coverage_end>date_trunc('month',first_due)::date);
   end if;
   if p_action='membership_return_preview' then return jsonb_build_object('preview',jsonb_build_object('version',a.version,'scheduleRevision',s.revision,'date',d,'mode',p_payload->>'mode','firstDue',first_due,'months',m,'cents',a.dues_terms->'cents','conflicts',issues,'canConfirm',issues='[]'));end if;
   if not(p_payload ?& array['id','version','date','mode','reason','request_id','scheduleRevision']) or a.version is distinct from (p_payload->>'version')::int or s.revision is distinct from (p_payload->>'scheduleRevision')::bigint or issues<>'[]' then raise insufficient_privilege;end if;
   update uniion_private.adherents set ended_on=null,data=jsonb_set(data,'{since}',to_jsonb(d::text)),membership_cycle=membership_cycle+1,version=version+1,updated_at=now() where id=a.id returning * into a;
   if p_payload->>'mode'='resume' then
    update uniion_private.dues_schedules set member_anchor=d,anchor=first_due,months=m,amount_cents=(a.dues_terms->>'cents')::bigint,next_index=0,occurrence_offset=greatest(occurrence_offset+next_index,coalesce((select max(occurrence)+1 from uniion_private.dues_entries where schedule_id=s.id),0)),state='active',actor=auth.uid(),requires_reanchor=false where id=s.id;
   else
    update uniion_private.dues_schedules set member_anchor=d,state='paused',requires_reanchor=true where id=s.id;
   end if;
  end if;
  insert into uniion_private.membership_changes(organization_id,adherent_id,actor,request_id,action,payload,before_state,after_state) values(p_org,a.id,auth.uid(),(p_payload->>'request_id')::uuid,p_action,p_payload,old_state,jsonb_build_object('joinedOn',a.joined_on,'endedOn',a.ended_on,'cycle',a.membership_cycle,'version',a.version,'schedule',(select to_jsonb(ds) from uniion_private.dues_schedules ds where ds.id=s.id)));
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='membership_return' then 'adherent.rejoined' else 'adherent.end_corrected' end,jsonb_build_object('id',a.id,'date',d,'mode',p_payload->>'mode','reason',btrim(p_payload->>'reason'),'version',a.version));
  if p_action='membership_return' and p_payload->>'mode'='resume' then perform uniion_private.run_dues_schedules(p_org);end if;
  r=public.uniion_adherents_before_return(p_org,'list','{}');
 else
  if p_action in ('schedule_preview','schedule_resume','schedule_resolve_preview','schedule_resolve') then
   select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
   if s.requires_reanchor and p_action in ('schedule_preview','schedule_resume') then raise insufficient_privilege;end if;
  end if;
  r=public.uniion_adherents_before_return(p_org,p_action,p_payload);
  if p_action='schedule_resolve' and s.requires_reanchor then update uniion_private.dues_schedules set requires_reanchor=false where id=s.id and state='active' and anchor>=member_anchor;r=public.uniion_adherents_before_return(p_org,'list','{}');end if;
 end if;
 if r ? 'rows' then
  can_manage=coalesce((r->>'canEndMembership')::boolean,false);
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('membershipActive',(a2.ended_on is null or a2.ended_on>today) and (a2.membership_cycle=0 or a2.joined_on<=today),'rejoinedOn',case when a2.membership_cycle>0 then a2.joined_on end,'canRejoin',a2.ended_on<=today,'requiresReanchor',coalesce((select requires_reanchor from uniion_private.dues_schedules ds where ds.organization_id=p_org and ds.adherent_id=a2.id),false))||(case when can_manage then jsonb_build_object('membershipHistory',(select coalesce(jsonb_agg(jsonb_build_object('date',h.created_at,'action',h.action,'before',h.before_state-'schedule','after',h.after_state-'schedule','reason',h.payload->>'reason','actor',h.actor) order by h.created_at,h.id),'[]') from uniion_private.membership_changes h where h.organization_id=p_org and h.adherent_id=a2.id)) else '{}' end)) from jsonb_array_elements(r->'rows') x join uniion_private.adherents a2 on a2.organization_id=p_org and a2.id=(x->>'id')::uuid),'[]'));
 end if;return r;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or unique_violation or check_violation then raise insufficient_privilege;
end$$;


--
-- Name: uniion_adherents_before_coverage_correction(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_coverage_correction(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;s uniion_private.dues_schedules;a uniion_private.adherents;e uniion_private.dues_entries;d date;ending date;m int;unknowns jsonb;conflicts jsonb;old_state jsonb;previous uniion_private.schedule_changes;
begin
 if p_action in ('schedule_resolve_preview','schedule_resolve','schedule_coverage') then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  if not found and p_action<>'schedule_coverage' then raise insufficient_privilege;end if;
  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  if p_action='schedule_coverage' then
   if not(p_payload ?& array['id','entry','lastDay']) or p_payload-array['id','entry','lastDay']<>'{}' then raise insufficient_privilege;end if;
   select * into e from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id=(p_payload->>'entry')::uuid for update;
   ending=uniion_private.adherent_date(p_payload->>'lastDay')+1;
   if not found or ending is null or ending<=e.period or e.schedule_id is not null then raise insufficient_privilege;end if;
   if e.coverage_end is not null then
    if e.coverage_end<>ending then raise insufficient_privilege;end if;
   else
    if exists(select 1 from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and id<>e.id and coverage_end is not null and period<ending and coverage_end>e.period) then raise insufficient_privilege;end if;
    update uniion_private.dues_entries set coverage_end=ending where id=e.id;
    update uniion_private.dues_schedules set state=state where id=s.id;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.coverage_confirmed',jsonb_build_object('entry',e.id,'from',e.period,'untilExclusive',ending));
   end if;
   r=public.uniion_adherents_before_cadence(p_org,'list','{}');
  else
   if p_payload-array['id','start','revision','memberVersion','request_id']<>'{}' then raise insufficient_privilege;end if;
   if p_action='schedule_resolve' and p_payload->>'request_id' is not null then
    select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
    if found then
     if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
     return public.uniion_adherents(p_org,'list','{}');
    end if;
   end if;
   d=uniion_private.adherent_date(p_payload->>'start');m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
   if d is null or d<=(now() at time zone 'Europe/Paris')::date or m is null or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 or a.joined_on is distinct from s.member_anchor or d<a.joined_on then raise insufficient_privilege;end if;
   ending=(date_trunc('month',d)+make_interval(months=>m))::date;
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'cents',amount_cents) order by period,id),'[]') into unknowns from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end is null;
   -- A future existing charge would collide with a later recurrence: resolve after its coverage.
   select coalesce(jsonb_agg(jsonb_build_object('id',id,'period',period,'lastDay',coverage_end-1) order by period,id),'[]') into conflicts from uniion_private.dues_entries where organization_id=p_org and adherent_id=a.id and coverage_end>date_trunc('month',d)::date;
   if p_action='schedule_resolve_preview' then
    return jsonb_build_object('preview',jsonb_build_object('revision',s.revision,'memberVersion',a.version,'oldMonths',s.months,'months',m,'oldCents',s.amount_cents,'cents',(a.dues_terms->>'cents')::bigint,'start',d,'periodStart',date_trunc('month',d)::date,'lastDay',ending-1,'unknown',unknowns,'conflicts',conflicts,'canConfirm',unknowns='[]' and conflicts='[]'));
   end if;
   if not(p_payload ?& array['revision','memberVersion','request_id']) or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   select * into previous from uniion_private.schedule_changes where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
   else
    if unknowns<>'[]' or conflicts<>'[]' or s.revision is distinct from (p_payload->>'revision')::bigint or a.version is distinct from (p_payload->>'memberVersion')::int then raise insufficient_privilege;end if;
    old_state=to_jsonb(s);
    update uniion_private.dues_schedules set anchor=d,months=m,amount_cents=(a.dues_terms->>'cents')::bigint,next_index=0,occurrence_offset=greatest(occurrence_offset+next_index,coalesce((select max(occurrence)+1 from uniion_private.dues_entries where schedule_id=s.id),0)),state='active',actor=auth.uid() where id=s.id returning * into s;
    insert into uniion_private.schedule_changes(organization_id,schedule_id,actor,request_id,payload,before_state,after_state) values(p_org,s.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,old_state,to_jsonb(s));
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_reconfigured',jsonb_build_object('schedule',s.id,'fromMonths',old_state->'months','months',m,'start',d));
   end if;
   r=public.uniion_adherents_before_cadence(p_org,'list','{}');
  end if;
 else r=public.uniion_adherents_before_cadence(p_org,p_action,p_payload);end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(case when x->'schedule' is null or x->'schedule'='null' then x else jsonb_set(x,'{schedule,needsReview}',to_jsonb((select a2.joined_on is distinct from s2.member_anchor or a2.dues_terms->>'cents' is distinct from s2.amount_cents::text or (case a2.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s2.months from uniion_private.dues_schedules s2 join uniion_private.adherents a2 on a2.id=s2.adherent_id where s2.organization_id=p_org and s2.adherent_id=(x->>'id')::uuid))) end) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation then raise insufficient_privilege;
end$$;


--
-- Name: uniion_adherents_before_ending(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_ending(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare s uniion_private.dues_schedules;a uniion_private.adherents;e uniion_private.dues_entries;ending date;old_state jsonb;previous uniion_private.coverage_corrections;r jsonb;
begin
 if p_action not in ('coverage_list','coverage_correct') then return public.uniion_adherents_before_coverage_correction(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
 -- Same lock order as cadence confirmation and the generation worker.
 select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
 select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
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


--
-- Name: uniion_adherents_before_exports(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_exports(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare result jsonb; entry uniion_private.dues_entries; amount bigint; period_date date; due_date date; remaining bigint; previous uniion_private.dues_payments; request_key uuid; target uniion_private.dues_payments; correction uniion_private.dues_corrections; rev integer; reason_text text; effective_date date;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if p_action in ('charge','settle','payment','correct') then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
  if p_payload ? 'effective_on' then
   effective_date=uniion_private.adherent_date(p_payload->>'effective_on');
   if jsonb_typeof(p_payload->'effective_on') is distinct from 'string' or effective_date is null or effective_date>current_date then raise insufficient_privilege;end if;
  end if;
  if p_action='correct' then
   if not(p_payload ?& array['id','revision','amount_cents','reason','request_id']) or p_payload-array['id','revision','amount_cents','reason','request_id','effective_on']<>'{}' or jsonb_typeof(p_payload->'amount_cents') is distinct from 'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' or jsonb_typeof(p_payload->'revision') is distinct from 'number' or p_payload->>'revision' !~ '^[0-9]+$' or jsonb_typeof(p_payload->'reason') is distinct from 'string' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   amount=(p_payload->>'amount_cents')::bigint;reason_text=trim(p_payload->>'reason');request_key=(p_payload->>'request_id')::uuid;
   if amount not between 0 and 99999999999 or length(reason_text) not between 3 and 500 then raise insufficient_privilege;end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||request_key::text,0));
   select * into target from uniion_private.dues_payments where id=(p_payload->>'id')::uuid and organization_id=p_org;
   if not found then raise insufficient_privilege;end if;
   select * into entry from uniion_private.dues_entries where id=target.entry_id and organization_id=p_org for update;
   select * into correction from uniion_private.dues_corrections where organization_id=p_org and request_id=request_key;
   if found then
    if correction.payment_id<>target.id or correction.amount_cents<>amount or correction.reason<>reason_text or correction.effective_on is distinct from effective_date or correction.revision<>(p_payload->>'revision')::int+1 then raise insufficient_privilege;end if;
   else
    select coalesce(max(revision),0) into rev from uniion_private.dues_corrections where payment_id=target.id;
    if rev<>(p_payload->>'revision')::int then raise insufficient_privilege;end if;
    select entry.amount_cents-coalesce(sum(uniion_private.dues_effective(id)),0) into remaining from uniion_private.dues_payments where organization_id=p_org and entry_id=entry.id and id<>target.id;
    if amount>remaining then raise insufficient_privilege;end if;
    insert into uniion_private.dues_corrections(organization_id,payment_id,revision,amount_cents,reason,actor,request_id,effective_on) values(p_org,target.id,rev+1,amount,reason_text,auth.uid(),request_key,effective_date);
    update uniion_private.dues_entries set paid_at=case when amount=remaining then coalesce(paid_at,now()) else null end,paid_by=case when amount=remaining then coalesce(paid_by,auth.uid()) else null end where id=entry.id;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.corrected',jsonb_build_object('payment',target.id,'revision',rev+1,'request',request_key));
   end if;
  elsif p_action='charge' then
   if not(p_payload ?& array['adherent_id','amount_cents','period','due_on','request_id']) or p_payload-array['adherent_id','amount_cents','period','due_on','request_id']<>'{}' then raise insufficient_privilege;end if;
   if jsonb_typeof(p_payload->'amount_cents')<>'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' then raise insufficient_privilege;end if;
   amount=(p_payload->>'amount_cents')::bigint;
   period_date=uniion_private.adherent_date(p_payload->>'period');due_date=uniion_private.adherent_date(p_payload->>'due_on');
   if p_payload->>'request_id' is null then raise insufficient_privilege;end if;
   if amount not between 1 and 99999999999 or period_date is null or due_date is null or not exists(select 1 from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'adherent_id')::uuid) then raise insufficient_privilege;end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||(p_payload->>'request_id'),0));
   select * into entry from uniion_private.dues_entries where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
   if found then
    if entry.adherent_id<>(p_payload->>'adherent_id')::uuid or entry.amount_cents<>amount or entry.period<>period_date or entry.due_on<>due_date then raise insufficient_privilege;end if;
   else
    insert into uniion_private.dues_entries(organization_id,adherent_id,amount_cents,period,due_on,created_by,request_id) values(p_org,(p_payload->>'adherent_id')::uuid,amount,period_date,due_date,auth.uid(),(p_payload->>'request_id')::uuid) returning * into entry;
    insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.created',jsonb_build_object('id',entry.id));
   end if;
  else
   if p_action='settle' then
    if not(p_payload ?& array['id']) or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
    request_key=(p_payload->>'id')::uuid;
   else
    if not(p_payload ?& array['id','amount_cents','request_id']) or p_payload-array['id','amount_cents','request_id','effective_on']<>'{}' or jsonb_typeof(p_payload->'amount_cents') is distinct from 'number' or p_payload->>'amount_cents' !~ '^[0-9]+$' or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
    amount=(p_payload->>'amount_cents')::bigint;request_key=(p_payload->>'request_id')::uuid;
    if amount not between 1 and 99999999999 then raise insufficient_privilege;end if;
   end if;
   perform pg_advisory_xact_lock(hashtextextended(p_org::text||request_key::text,0));
   select * into entry from uniion_private.dues_entries where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
   if not found then raise insufficient_privilege;end if;
   select * into previous from uniion_private.dues_payments where organization_id=p_org and request_id=request_key;
   if found then
    if previous.entry_id<>entry.id or (p_action='payment' and (previous.amount_cents<>amount or previous.effective_on is distinct from effective_date)) then raise insufficient_privilege;end if;
   else
    select entry.amount_cents-coalesce(sum(uniion_private.dues_effective(id)),0) into remaining from uniion_private.dues_payments where organization_id=p_org and entry_id=entry.id;
    if p_action='settle' then amount=remaining;end if;
    if amount>remaining or (p_action='payment' and amount<=0) then raise insufficient_privilege;end if;
    if amount>0 then
     insert into uniion_private.dues_payments(organization_id,entry_id,amount_cents,actor,request_id,effective_on) values(p_org,entry.id,amount,auth.uid(),request_key,effective_date);
     if amount=remaining then update uniion_private.dues_entries set paid_at=now(),paid_by=auth.uid() where id=entry.id;end if;
     insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='settle' then 'dues.settled' else 'dues.payment_recorded' end,jsonb_build_object('id',entry.id,'request',request_key));
    end if;
   end if;
  end if;
  result=uniion_private.adherents_register(p_org,'list','{}');
 else result=uniion_private.adherents_register(p_org,p_action,p_payload);end if;
 if (result->>'financial')::boolean then
  result=jsonb_set(result,'{rows}',coalesce((select jsonb_agg(r||jsonb_build_object('duesLedger',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'cents',e.amount_cents,'period',e.period,'dueOn',e.due_on,'paidAt',e.paid_at,'paidCents',coalesce((select sum(uniion_private.dues_effective(id)) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),0),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'cents',uniion_private.dues_effective(id),'originalCents',amount_cents,'originalEffectiveOn',effective_on,'effectiveOn',coalesce((select c.effective_on from uniion_private.dues_corrections c where c.payment_id=dues_payments.id and c.effective_on is not null order by c.revision desc limit 1),effective_on),'revision',coalesce((select max(revision) from uniion_private.dues_corrections where payment_id=dues_payments.id),0),'corrections',coalesce((select jsonb_agg(jsonb_build_object('revision',revision,'cents',amount_cents,'reason',reason,'effectiveOn',effective_on,'actor',actor,'recordedAt',recorded_at) order by revision) from uniion_private.dues_corrections where payment_id=dues_payments.id),'[]'::jsonb),'recordedAt',recorded_at) order by recorded_at,id) from uniion_private.dues_payments where entry_id=e.id and organization_id=p_org),'[]'::jsonb)) order by e.due_on,e.id) from uniion_private.dues_entries e where e.organization_id=p_org and e.adherent_id=(r->>'id')::uuid),'[]'::jsonb))) from jsonb_array_elements(result->'rows') r),'[]'::jsonb));
 end if;
 return result;
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation or check_violation then raise insufficient_privilege;
end $_$;


--
-- Name: uniion_adherents_before_resume(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_resume(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;
begin
 if p_action='schedule_pause' then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ? 'id') or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
  update uniion_private.dues_schedules set state='paused' where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid;
  if not found then raise insufficient_privilege;end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.schedule_paused',p_payload);
  r=public.uniion_adherents_before_schedules(p_org,'list','{}');
 else
  -- Serialize manual creation with the automatic worker for this member.
  if p_action='charge' then perform 1 from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'adherent_id')::uuid for update;end if;
  r=public.uniion_adherents_before_schedules(p_org,p_action,p_payload);
  if p_action='import' then perform uniion_private.run_dues_schedules(p_org);r=public.uniion_adherents_before_schedules(p_org,'list','{}');end if;
 end if;
 if coalesce((r->>'financial')::boolean,false) then
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('schedule',(select jsonb_build_object('state',s.state,'nextDue',uniion_private.dues_occurrence(s.anchor,s.months,s.next_index),'cents',s.amount_cents,'months',s.months) from uniion_private.dues_schedules s where s.organization_id=p_org and s.adherent_id=(x->>'id')::uuid))) from jsonb_array_elements(r->'rows') x),'[]'));
 end if;
 return r;
exception when invalid_text_representation then raise insufficient_privilege;
end $$;


--
-- Name: uniion_adherents_before_return(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_return(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a uniion_private.adherents;s uniion_private.dues_schedules;ending date;previous uniion_private.adherent_endings;r jsonb;before jsonb;
begin
 if p_action='membership_end' then
  perform public.uniion_module_use(p_org,'adherents');
  if not uniion_private.adherent_permission(p_org,'adherents','write') or not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  if not(p_payload ?& array['id','version','date','reason','request_id']) or p_payload-array['id','version','date','reason','request_id']<>'{}' or jsonb_typeof(p_payload->'reason')<>'string' or coalesce(length(btrim(p_payload->>'reason')),0) not between 5 and 500 or p_payload->>'request_id' is null then raise insufficient_privilege;end if;
  select * into s from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
  if not found then raise insufficient_privilege;end if;
  select * into previous from uniion_private.adherent_endings where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if previous.actor<>auth.uid() or previous.payload<>p_payload then raise insufficient_privilege;end if;
  else
   ending=uniion_private.adherent_date(p_payload->>'date');
   if ending is null or a.joined_on is null or ending<a.joined_on or a.ended_on is not null or a.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
   before=jsonb_build_object('version',a.version,'endedOn',a.ended_on,'scheduleState',s.state);
   update uniion_private.adherents set ended_on=ending,version=version+1,updated_at=now() where id=a.id returning * into a;
   update uniion_private.dues_schedules set state=case when ending<=(now() at time zone 'Europe/Paris')::date then 'stopped' else state end where id=s.id;
   insert into uniion_private.adherent_endings(organization_id,adherent_id,actor,request_id,payload,before_state,after_state,cycle) values(p_org,a.id,auth.uid(),(p_payload->>'request_id')::uuid,p_payload,before,jsonb_build_object('version',a.version,'endedOn',ending),a.membership_cycle);
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherent.ended',jsonb_build_object('id',a.id,'date',ending,'reason',btrim(p_payload->>'reason'),'before',before,'version',a.version));
  end if;
  r=public.uniion_adherents_before_ending(p_org,'list','{}');
 else
  if p_action in ('schedule_preview','schedule_resume','schedule_resolve_preview','schedule_resolve','schedule_pause') then
   perform public.uniion_module_use(p_org,'adherents');
   perform 1 from uniion_private.dues_schedules where organization_id=p_org and adherent_id=(p_payload->>'id')::uuid for update;
   select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
   if a.ended_on<=(now() at time zone 'Europe/Paris')::date then raise insufficient_privilege;end if;
  end if;
  r=public.uniion_adherents_before_ending(p_org,p_action,p_payload);
 end if;
 if r ? 'rows' then
  r=r||jsonb_build_object('canEndMembership',uniion_private.adherent_permission(p_org,'adherents','write') and uniion_private.adherent_permission(p_org,'cotisations','write'));
  r=jsonb_set(r,'{rows}',coalesce((select jsonb_agg(x||jsonb_build_object('endedOn',a2.ended_on,'membershipActive',a2.ended_on is null or a2.ended_on>(now() at time zone 'Europe/Paris')::date)) from jsonb_array_elements(r->'rows') x join uniion_private.adherents a2 on a2.organization_id=p_org and a2.id=(x->>'id')::uuid),'[]'));
 end if;
 return r;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or unique_violation or check_violation then raise insufficient_privilege;
end$$;


--
-- Name: uniion_adherents_before_schedules(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_schedules(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;
begin
 r=public.uniion_adherents_before_summary(p_org,p_action,p_payload);
 if coalesce((r->>'financial')::boolean,false) then
  r=r||jsonb_build_object('financialSummary',uniion_private.dues_summary(r->'rows',(now() at time zone 'Europe/Paris')::date));
 end if;
 return r;
end $$;


--
-- Name: uniion_adherents_before_summary(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_adherents_before_summary(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r jsonb;
begin
 r=public.uniion_adherents_before_exports(p_org,p_action,p_payload);
 return r||jsonb_build_object('canExport',coalesce((r->>'financial')::boolean,false) and uniion_private.authority(p_org,auth.uid(),'download'));
end $$;


--
-- Name: uniion_admin_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_admin_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
BEGIN
 -- uniion_privileged_mfa_gate
 IF NOT uniion_private.session_allowed() OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN RAISE insufficient_privilege; END IF;
 result=public.uniion_admin_context_pre_cyber(p_org);
 return result||jsonb_build_object('partners',case when uniion_private.authority(p_org,auth.uid(),'share') then coalesce((
  select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'members',coalesce((
   select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from public.uniion_directory_grants g join auth.users u on u.id=g.listed_user
   where g.organization_id=o.id and g.target_id=p_org and g.grantee=auth.uid() and g.revoked_at is null and g.valid_until>now()
    and uniion_private.actor_member(o.id,g.listed_user) and uniion_private.authority(o.id,g.approved_by,'rights') and uniion_private.authority(o.id,g.approved_by,'share')
  ),'[]'::jsonb))) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.active and p.source_id=p_org and o.active
 ),'[]'::jsonb) else '[]'::jsonb end);
end $$;


--
-- Name: uniion_admin_context_core(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_admin_context_core(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare mine uuid=auth.uid();result jsonb;manage boolean;
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege; end if;
 manage=uniion_private.authority(p_org,mine,'rights');
 select jsonb_build_object(
 'authorities',coalesce((select jsonb_agg(jsonb_build_object('permission',permission,'delegable',delegable)) from public.uniion_authorities where organization_id=p_org and user_id=mine),'[]'::jsonb),
 'members',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',m.user_id,'name',u.email,
 'permissions',(select coalesce(jsonb_agg(jsonb_build_object('module',p.module,'permission',p.permission)),'[]'::jsonb) from public.uniion_permissions p where p.organization_id=p_org and p.user_id=m.user_id),
 'authorities',(select coalesce(jsonb_agg(a.permission),'[]'::jsonb) from public.uniion_authorities a where a.organization_id=p_org and a.user_id=m.user_id),
 'grants',(select coalesce(jsonb_agg(jsonb_build_object('resource',g.resource_id,'write',g.can_write,'until',g.valid_until,'history',g.history_approved,'revoked',g.revoked_at)),'[]'::jsonb) from public.uniion_resource_grants g where g.organization_id=p_org and g.user_id=m.user_id and uniion_private.actor_resource(p_org,g.resource_id,mine,false)))) from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=p_org and uniion_private.actor_member(p_org,m.user_id)),'[]'::jsonb) else '[]'::jsonb end,
 'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'version',r.version,'module',r.module,'shareable',r.external_share_allowed,'write',uniion_private.actor_resource(p_org,r.id,mine,true))) from public.uniion_resources r where r.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,mine,false)),'[]'::jsonb),
 'partners',case when uniion_private.authority(p_org,mine,'share') then coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'members',(select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',u.email)),'[]'::jsonb) from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=o.id and uniion_private.actor_member(o.id,m.user_id)))) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.active and p.source_id=p_org and o.active),'[]'::jsonb) else '[]'::jsonb end,
 'shares',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'source',s.source_id,'target',s.target_id,'source_name',so.name,'target_name',ta.name,'allowed',s.allowed,'beneficiaries',s.beneficiaries,'download',s.download,'expires',s.expires_at,'accepted',s.accepted_at,'revoked',s.revoked_at,
 'people',(select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from auth.users u where u.id=any(s.allowed)),
 'items',(select jsonb_agg(jsonb_build_object('id',i.resource_id,'version',i.version,'title',v.body->>'title','readable',uniion_private.share_access(s.id,i.resource_id,mine,false),'downloadable',uniion_private.share_access(s.id,i.resource_id,mine,true))) from public.uniion_share_items i join public.uniion_resource_versions v on v.organization_id=i.organization_id and v.resource_id=i.resource_id and v.version=i.version where i.share_id=s.id and (s.source_id=p_org or uniion_private.authority(p_org,mine,'accept') or uniion_private.share_access(s.id,i.resource_id,mine,false))))) from public.uniion_shares s join public.uniion_organizations so on so.id=s.source_id join public.uniion_organizations ta on ta.id=s.target_id where (s.source_id=p_org and uniion_private.authority(p_org,mine,'share') and not exists(select 1 from public.uniion_share_items i where i.share_id=s.id and not uniion_private.actor_resource(p_org,i.resource_id,mine,false))) or (s.target_id=p_org and (uniion_private.authority(p_org,mine,'accept') or (mine=any(s.beneficiaries) and exists(select 1 from public.uniion_share_items z where z.share_id=s.id and uniion_private.share_access(s.id,z.resource_id,mine,false)))))),'[]'::jsonb),
 'events',case when manage then coalesce((select jsonb_agg(x) from (select event,details,at from public.uniion_security_events where organization_id=p_org or target_id=p_org order by id desc limit 100)x),'[]'::jsonb) else '[]'::jsonb end
 ) into result;
 return result;
end $$;


--
-- Name: uniion_admin_context_files(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_admin_context_files(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 result=public.uniion_admin_context_core(p_org);
 result=result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'mime',a.mime,'size',a.size,'downloadable',uniion_private.attachment_access(a.id,auth.uid()))) from public.uniion_attachments a where a.organization_id=p_org and a.ready and uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),false)),'[]'::jsonb));
 result=jsonb_set(result,'{shares}',coalesce((select jsonb_agg(g||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'size',a.size)) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=(g->>'id')::uuid and exists(select 1 from jsonb_array_elements(g->'items') i where (i->>'id')::uuid=a.resource_id)),'[]'::jsonb))) from jsonb_array_elements(result->'shares') g),'[]'::jsonb));
 return result;
end $$;


--
-- Name: uniion_admin_context_pre_cyber(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_admin_context_pre_cyber(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 result=public.uniion_admin_context_files(p_org);
 return result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename,'mime',a.mime,'size',a.size,'scan_status',a.scan_status,'scanned_at',a.scanned_at,'downloadable',uniion_private.attachment_access(a.id,auth.uid()),'previewable',uniion_private.attachment_preview(a.id,auth.uid()),'rescan',uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true))) from public.uniion_attachments a where a.organization_id=p_org and uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),false)),'[]'::jsonb));
end $$;


--
-- Name: uniion_agenda_audience_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_audience_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare own text;
begin
 if not uniion_private.identity_admin(p_org) or not uniion_private.authority(p_org,auth.uid(),'agenda_audience') then return jsonb_build_object('manage',false,'members','[]'::jsonb,'options','[]'::jsonb);end if;
 perform public.uniion_module_use(p_org,'agenda');
 select audience into own from uniion_private.agenda_audiences where organization_id=p_org and user_id=auth.uid();
 return jsonb_build_object('manage',true,'options',case own when 'elus' then '["none","elus","adherents","public"]'::jsonb when 'adherents' then '["none","adherents","public"]'::jsonb when 'public' then '["none","public"]'::jsonb else '["none"]'::jsonb end,'members',coalesce((select jsonb_agg(jsonb_build_object('user',m.user_id,'audience',coalesce(a.audience,'none'))) from public.uniion_memberships m left join uniion_private.agenda_audiences a on a.organization_id=m.organization_id and a.user_id=m.user_id where m.organization_id=p_org and uniion_private.actor_member(p_org,m.user_id)),'[]'::jsonb));
end;$$;


--
-- Name: uniion_agenda_export(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_export(p_org uuid, p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare e uniion_private.agenda_events;
begin
perform public.uniion_module_use(p_org,'agenda');
select * into e from uniion_private.agenda_events where id=p_id and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) or not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.exported',jsonb_build_object('id',e.id,'version',e.version));
return e.data || jsonb_build_object('id',e.id,'version',e.version);
end;$$;


--
-- Name: uniion_agenda_files(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_files(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;files jsonb;aid uuid;file_record public.uniion_attachments;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event for update;
if p_action='select' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_convocation') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') or d.id is null or (p_payload->>'version')::integer is distinct from d.version or p_payload-array['version','files']<>'{}'::jsonb or jsonb_typeof(p_payload->'files') is distinct from 'array' or jsonb_array_length(p_payload->'files')>5 then raise insufficient_privilege;end if;
 if (select count(*)<>count(distinct value) from jsonb_array_elements_text(p_payload->'files')) then raise insufficient_privilege;end if;
 files='[]';
 for aid in select value::uuid from jsonb_array_elements_text(p_payload->'files') loop
  select * into file_record from public.uniion_attachments where id=aid and organization_id=p_org;
  if not found then raise insufficient_privilege;end if;
  files=files||jsonb_build_array(jsonb_build_object('id',file_record.id,'sha256',file_record.sha256));
 end loop;
 perform uniion_private.agenda_file_check(p_org,files,auth.uid());
 if coalesce(d.document->'convocation_files','[]')<>files then
 update uniion_private.agenda_documents set document=document||jsonb_build_object('convocation_files',files),version=version+1,updated_by=auth.uid(),updated_at=now() where event_id=p_event returning * into d;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.files.selected',jsonb_build_object('event',p_event,'version',d.version,'files',files));
 end if;
elsif p_action='context' then
 if p_payload<>'{}' then raise insufficient_privilege;end if;
else raise insufficient_privilege;end if;
return jsonb_build_object('version',d.version,'selected',coalesce(d.document->'convocation_files','[]'),
 'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.title)) from public.uniion_resources r where r.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,auth.uid(),true)),'[]'),
 'available',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'resource',a.resource_id,'size',a.size)) from public.uniion_attachments a where a.organization_id=p_org and a.ready and a.scan_status='clean' and uniion_private.attachment_access(a.id,auth.uid())),'[]'));
end;$$;


--
-- Name: uniion_agenda_image_receipt(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_image_receipt(p_event uuid, p_image text, p_engine text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
begin
 if not uniion_private.is_scanner() or p_image is null or p_engine is null or length(p_engine) not between 1 and 250 or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg|svg\+xml);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.agenda_image_receipts(event_id,digest,engine) values(p_event,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine) on conflict do nothing;
 return jsonb_build_object('ok',true);
end;$_$;


--
-- Name: uniion_agenda_list(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_list(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(data || jsonb_build_object('id',id,'version',version,'org','Organisation','invites','[]'::jsonb) order by data->>'date',data->>'start') from uniion_private.agenda_events where organization_id=p_org and uniion_private.agenda_visible(p_org,data)),'[]'::jsonb);
end;$$;


--
-- Name: uniion_agenda_notifications(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_notifications(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(jsonb_build_object('id',j.id,'event',e.id,'title',e.data->>'title','date',e.data->>'date','start',e.data->>'start') order by j.created_at desc) from uniion_private.agenda_reminders j join uniion_private.agenda_events e on e.id=j.event_id where e.organization_id=p_org and j.user_id=auth.uid() and j.version=e.version and j.status<>'cancelled' and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_visible(p_org,e.data)),'[]'::jsonb);
end;$$;


--
-- Name: uniion_agenda_publication(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_publication(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare files jsonb;
begin
if p_action in ('review','publish','published','export') then
 select document->'convocation_files' into files from uniion_private.agenda_documents where event_id=p_event;
 perform uniion_private.agenda_file_check(p_org,coalesce(files,'[]'),auth.uid());
end if;
return public.uniion_agenda_publication_without_files(p_org,p_event,p_action,p_payload);
end;$$;


--
-- Name: uniion_agenda_publication_notices(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_publication_notices(p_org uuid, p_read uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ids uuid[];
begin
 perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
 select array_agg(n.id) into ids from uniion_private.agenda_publication_notifications n join uniion_private.agenda_events e on e.id=n.event_id join uniion_private.agenda_documents d on d.event_id=e.id and d.version=n.version join uniion_private.agenda_publications p on p.event_id=e.id and p.version=n.version and p.source_version=e.version and p.published_at is not null where e.organization_id=p_org and n.user_id=auth.uid() and uniion_private.agenda_document_recipient(e.id,auth.uid());
 if p_read='00000000-0000-0000-0000-000000000000'::uuid then update uniion_private.agenda_publication_notifications set read_at=coalesce(read_at,now()) where id=any(ids) and user_id=auth.uid(); elsif p_read is not null then
 if not coalesce(p_read=any(ids),false) then raise insufficient_privilege;end if;
 update uniion_private.agenda_publication_notifications set read_at=coalesce(read_at,now()) where id=p_read and user_id=auth.uid();
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'event',n.event_id,'version',n.version,'title',p.document->>'title','read',n.read_at is not null,'created',n.created_at) order by n.created_at desc) from uniion_private.agenda_publication_notifications n join uniion_private.agenda_publications p on p.event_id=n.event_id and p.version=n.version where n.id=any(ids)),'[]'::jsonb);
end;$$;


--
-- Name: uniion_agenda_publication_without_files(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_publication_without_files(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;r uniion_private.agenda_publications;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org for update;
if not found or not uniion_private.agenda_visible(p_org,e.data) then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event for update;
if not found or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload-array['version']<>'{}'::jsonb or (p_payload->>'version')::integer is distinct from d.version then raise insufficient_privilege;end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=d.version;
if p_action='export' then
 if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
elsif p_action='review' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_review') or auth.uid()=d.updated_by or (r.published_at is not null and r.source_version<>e.version) then raise insufficient_privilege;end if;
 insert into uniion_private.agenda_publications(event_id,version,source_version,document,author,reviewer,reviewed_at) values(p_event,d.version,e.version,d.document,d.updated_by,auth.uid(),now()) on conflict(event_id,version) do update set source_version=excluded.source_version,reviewer=excluded.reviewer,reviewed_at=excluded.reviewed_at where uniion_private.agenda_publications.published_at is null;
elsif p_action='publish' then
 if not uniion_private.authority(p_org,auth.uid(),'agenda_publish') or r.reviewer is null or r.reviewer=d.updated_by or r.source_version<>e.version then raise insufficient_privilege;end if;
 if not uniion_private.agenda_recipient_allowed(p_event,r.reviewer) or not uniion_private.authority(p_org,r.reviewer,'agenda_review') then raise insufficient_privilege;end if;
 update uniion_private.agenda_publications set published_by=auth.uid(),published_at=coalesce(published_at,now()) where event_id=p_event and version=d.version;
elsif p_action not in ('status','published') then raise insufficient_privilege;
end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=d.version;
if p_action='published' and (r.published_at is null or r.source_version<>e.version) then raise insufficient_privilege;end if;
if p_action in ('export','review','publish') then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.document.'||p_action,jsonb_build_object('id',d.id,'version',d.version));end if;
return jsonb_build_object('version',d.version,'reviewed',r.reviewer is not null and r.source_version=e.version,'published',r.published_at is not null and r.source_version=e.version,'document',case when p_action in ('export','published') then d.document else null end);
end;$$;


--
-- Name: uniion_agenda_save(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_save(p_org uuid, p_event jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
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
end;$_$;


--
-- Name: uniion_agenda_work(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_work(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if p_action in ('check','finish') and exists(select 1 from uniion_private.agenda_convocations where id=(p_payload->>'id')::uuid and message ? 'attachment_version') and not exists(select 1 from uniion_private.convocation_archives where convocation=(p_payload->>'id')::uuid and organization_id=p_org and ready) then raise insufficient_privilege;end if;
 return public.uniion_agenda_work_before_archives(p_org,p_event,p_action,p_payload);
end $$;


--
-- Name: uniion_agenda_work_before_archives(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_agenda_work_before_archives(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;v integer;people jsonb;saved_message jsonb;
begin
if p_payload is null or jsonb_typeof(p_payload)<>'object' then raise insufficient_privilege;end if;
if p_action='attachments' then
 if p_payload-array['version','people']<>'{}'::jsonb then raise insufficient_privilege;end if;
 return uniion_private.convocation_documents(p_org,p_event,(p_payload->>'version')::integer,p_payload->'people');
elsif p_action='prepare' then
 if jsonb_typeof(p_payload->'people') is distinct from 'array' or jsonb_typeof(p_payload->'subject') is distinct from 'string' or jsonb_typeof(p_payload->'body') is distinct from 'string' then raise insufficient_privilege;end if;
 if (select count(*)<>count(distinct value) from jsonb_array_elements_text(p_payload->'people')) then raise insufficient_privilege;end if;
 if p_payload ? 'attachment_version' then
  if jsonb_typeof(p_payload->'attachment_version') is distinct from 'number' then raise insufficient_privilege;end if;
  v=(p_payload->>'attachment_version')::integer;
  perform uniion_private.convocation_documents(p_org,p_event,v,p_payload->'people');
 end if;
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload-'attachment_version');
 if v is not null and not (result->>'replayed')::boolean then
  update uniion_private.agenda_convocations set message=message||jsonb_build_object('attachment_version',v,'attachments',jsonb_build_array('ordre-du-jour.pdf','evenement.ics')) where id=(p_payload->>'id')::uuid;
 end if;
 return result;
elsif p_action in ('check','finish') then
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload);
 select c.message into saved_message from uniion_private.agenda_convocations c where c.id=(p_payload->>'id')::uuid and c.event_id=p_event and c.actor=auth.uid();
 if saved_message ? 'attachment_version' then perform uniion_private.convocation_documents(p_org,p_event,(saved_message->>'attachment_version')::integer,jsonb_build_array(p_payload->>'user'));end if;
 return result;
else
 result=uniion_private.agenda_work_core(p_org,p_event,p_action,p_payload);
 if p_action='recipients' then
  select version into v from uniion_private.agenda_documents where event_id=p_event;
  result=result||jsonb_build_object('documentVersion',v);
 end if;
 return result;
end if;
end;$$;


--
-- Name: uniion_ai_action_policy(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_action_policy(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare d uniion_private.ai_action_definitions;c uniion_private.ai_action_settings;roles jsonb;enabled boolean;v int;member_id uuid;manage boolean;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 manage=uniion_private.authority(p_org,auth.uid(),'organization_edit');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('manage',manage,'roles',coalesce((select jsonb_agg(role) from uniion_private.ai_business_roles where organization_id=p_org and user_id=auth.uid()),'[]'),'settings',coalesce((select jsonb_agg(jsonb_build_object('id',definition.id,'enabled',coalesce(setting.enabled,true),'roles',coalesce(setting.roles,definition.roles),'version',coalesce(setting.version,0))) from uniion_private.ai_action_definitions definition left join uniion_private.ai_action_settings setting on setting.organization_id=p_org and setting.action=definition.id),'[]'));
 end if;
 if p_action='assign_role' then
  if p_payload-array['user','email','role','enabled']<>'{}' or not(p_payload ?& array['role','enabled']) or ((p_payload ? 'user')=(p_payload ? 'email')) or jsonb_typeof(p_payload->'enabled')<>'boolean' or not uniion_private.authority(p_org,auth.uid(),'rights') then raise insufficient_privilege;end if;
  if p_payload ? 'email' then select id into member_id from auth.users where lower(email)=lower(trim(p_payload->>'email'));else member_id=(p_payload->>'user')::uuid;end if;
  if member_id is null or member_id=auth.uid() or not uniion_private.actor_member(p_org,member_id) or p_payload->>'role' not in ('secretaire','tresorier','titulaire','suppleant','ds','ssct') then raise insufficient_privilege;end if;
  if (p_payload->>'enabled')::boolean then insert into uniion_private.ai_business_roles values(p_org,member_id,p_payload->>'role') on conflict do nothing;
  else delete from uniion_private.ai_business_roles where organization_id=p_org and user_id=member_id and role=p_payload->>'role';end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.role_assigned',p_payload);return '{"updated":true}';
 end if;
 select * into d from uniion_private.ai_action_definitions where id=p_payload->>'id';if not found then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||d.id,0));
 select * into c from uniion_private.ai_action_settings where organization_id=p_org and action=d.id;
 roles=coalesce(c.roles,d.roles);enabled=coalesce(c.enabled,true);v=coalesce(c.version,0);
 if p_action='configure' then
  if not manage or p_payload-array['id','version','enabled','roles']<>'{}' or not(p_payload ?& array['id','version','enabled','roles']) or jsonb_typeof(p_payload->'enabled')<>'boolean' or jsonb_typeof(p_payload->'roles')<>'array' or jsonb_array_length(p_payload->'roles')>6 or v is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_array_elements_text(p_payload->'roles') x where x not in ('secretaire','tresorier','titulaire','suppleant','ds','ssct')) then raise insufficient_privilege;end if;
  insert into uniion_private.ai_action_settings values(p_org,d.id,(p_payload->>'enabled')::boolean,p_payload->'roles',v+1) on conflict(organization_id,action) do update set enabled=excluded.enabled,roles=excluded.roles,version=excluded.version;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'ai.action_configured',p_payload);return jsonb_build_object('updated',true,'version',v+1);
 end if;
 if p_action<>'authorize' or p_payload-array['id']<>'{}' or not enabled then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,d.module);
 if roles<>'[]' and not exists(select 1 from uniion_private.ai_business_roles where organization_id=p_org and user_id=auth.uid() and roles ? role) then raise insufficient_privilege;end if;
 return jsonb_build_object('allowed',true,'version',v,'roles',roles);
end$$;


--
-- Name: uniion_ai_case_create(uuid, uuid, jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_case_create(p_org uuid, p_request uuid, p_refs jsonb, p_title text, p_text text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare existing uuid;row jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||p_request::text,0));
 select resource into existing from uniion_private.ai_case_derivatives where organization_id=p_org and actor=auth.uid() and request=p_request;
 if found then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',existing));return jsonb_build_object('id',existing);end if;
 if not uniion_private.ai_refs_readable(p_org,p_refs) then raise insufficient_privilege;end if;
 row=public.uniion_cases(p_org,'create',jsonb_build_object('title',p_title,'long',p_text,'tag','Juridique','due',''));
 insert into uniion_private.ai_case_derivatives values(p_org,p_request,auth.uid(),(row->>'id')::uuid,p_refs);
 return jsonb_build_object('id',row->>'id');
end$$;


--
-- Name: uniion_ai_draft_apply(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_draft_apply(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare receipt uniion_private.ai_draft_applications;r public.uniion_resources;rid uuid;result jsonb;doc jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 if p_action is null or p_action not in ('status','apply') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='status' and p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
 if p_action='apply' and (not(p_payload ?& array['id','source','kind','version','text']) or p_payload-array['id','source','kind','version','text']<>'{}') then raise insufficient_privilege;end if;
 rid=(p_payload->>'id')::uuid;if rid is null then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||rid::text,0));
 select * into receipt from uniion_private.ai_draft_applications where organization_id=p_org and actor=auth.uid() and request_id=rid;
 if found then
  if not uniion_private.actor_resource(p_org,receipt.resource_id,auth.uid(),false) then raise insufficient_privilege;end if;
  return jsonb_build_object('applied',true,'resource',receipt.resource_id,'version',receipt.version,'kind',receipt.kind);
 end if;
 if p_action='status' then return jsonb_build_object('applied',false);end if;
 if p_payload->>'kind' is null or p_payload->>'kind' not in ('case','document','mobile-page','mobile-short','mobile-push','communication-plan') or jsonb_typeof(p_payload->'text') is distinct from 'string' or length(btrim(p_payload->>'text')) not between 1 and 6000 then raise insufficient_privilege;end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'source')::uuid for update;
 if not found or r.version is distinct from (p_payload->>'version')::integer or not uniion_private.actor_resource(p_org,r.id,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_payload->>'kind'='case' then
  -- Classified sources can have narrower ACL than the dossier. Never flatten them into an ordinary note.
  if r.module<>'dossiers' or exists(select 1 from uniion_private.case_links where organization_id=p_org and resource_id=r.id) or length(p_payload->>'text')>5000 then raise insufficient_privilege;end if;
  result=public.uniion_cases(p_org,'note',jsonb_build_object('id',r.id,'version',r.version,'text',p_payload->>'text'));
 elsif p_payload->>'kind'='document' then
  if r.module<>'documents' then raise insufficient_privilege;end if;
  doc=public.uniion_documents(p_org,'get',jsonb_build_object('id',r.id));
  if doc->>'status'<>'Brouillon' then raise insufficient_privilege;end if;
  result=public.uniion_documents(p_org,'save',jsonb_build_object('id',r.id,'version',r.version,'document',r.body||jsonb_build_object('blocks',(r.body->'blocks')||jsonb_build_array(jsonb_build_object('id','ai-'||rid::text,'type','p','text',p_payload->>'text')))));
 else
  if (p_payload->>'kind' like 'mobile-%' and r.module<>'mobile') or (p_payload->>'kind'='communication-plan' and r.module<>'communication') then raise insufficient_privilege;end if;
  doc=public.uniion_business_records(p_org,r.module,'get',jsonb_build_object('id',r.id));
  if doc->>'status'<>'Brouillon' then raise insufficient_privilege;end if;
  if p_payload->>'kind'='mobile-push' then
   if length(p_payload->>'text')>120 then raise insufficient_privilege;end if;
   doc=r.body||jsonb_build_object('push',p_payload->>'text');
  elsif p_payload->>'kind'='communication-plan' then
   doc=r.body||jsonb_build_object('content',jsonb_build_object('titre',r.title,'corps',p_payload->>'text','accroche','','appel','','visuel',''));
  else
   doc=r.body||jsonb_build_object('blocks',jsonb_build_array(jsonb_build_array('p',p_payload->>'text')));
  end if;
  result=public.uniion_business_records(p_org,r.module,'save',jsonb_build_object('id',r.id,'version',r.version,'data',doc));
 end if;
 insert into uniion_private.ai_draft_applications values(p_org,auth.uid(),rid,r.id,(result->>'version')::integer,p_payload->>'kind',now());
 return jsonb_build_object('applied',true,'resource',r.id,'version',result->'version','kind',p_payload->>'kind');
end$$;


--
-- Name: uniion_ai_interactive(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_interactive(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r uniion_private.ai_interactive_recipes;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 select * into r from uniion_private.ai_interactive_recipes where organization_id=p_org and enabled;
 if not found or not exists(select 1 from auth.users where id=auth.uid() and email like '%@uniion-local.example') then raise insufficient_privilege;end if;
 return jsonb_build_object('allowed',true,'version',r.version,'scope','fictitious-tenant');
end$$;


--
-- Name: uniion_ai_native(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_native(p_org uuid, p_kind text, p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare context jsonb;item record;agenda jsonb;name text;dependencies jsonb='[]';
begin
 if p_kind<>'workspace' then return public.uniion_ai_native_before_workspace(p_org,p_kind,p_id);end if;
 perform public.uniion_module_use(p_org,'assistant');if p_id<>p_org then raise insufficient_privilege;end if;
 select o.name into name from public.uniion_organizations o where o.id=p_org and o.active;
 context=jsonb_build_object('description','Espace uniion : droits de modules et de ressources distincts. Extrait limité aux dossiers sans source classée et aux réunions autorisés, ainsi qu’aux événements visibles. Une absence n’atteste pas l’absence de travail.','dateDeLecture',current_date,'dossiersEtReunions','[]'::jsonb,'agenda','[]'::jsonb);
 -- Exclude conversation derivatives before traversing their ACLs: no dependency cycle.
 for item in select r.* from public.uniion_resources r where r.organization_id=p_org and r.module in ('dossiers','reunions') and not exists(select 1 from uniion_private.ai_case_derivatives d where d.resource=r.id) and not exists(select 1 from uniion_private.case_links l where l.resource_id=r.id) order by r.created_at desc limit 40 loop
  if uniion_private.actor_resource(p_org,item.id,auth.uid(),false) then
   dependencies=dependencies||jsonb_build_array(jsonb_build_object('kind',case item.module when 'dossiers' then 'case' else item.module end,'id',item.id));
   context=jsonb_set(context,'{dossiersEtReunions}',(context->'dossiersEtReunions')||jsonb_build_array(jsonb_build_object('id',item.id,'module',item.module,'titre',item.title,'version',item.version,'date',item.body->>'date','description',left(coalesce(item.body->>'text',''),500),'echeance',(select due from uniion_private.cases where id=item.id),'statut',(select status from uniion_private.cases where id=item.id))));
  end if;
 end loop;
 begin
  select coalesce(jsonb_agg(jsonb_build_object('id',e->>'id','titre',e->>'title','date',e->>'date','debut',e->>'start','fin',e->>'end','lieu',e->>'lieu')),'[]') into agenda from (select value e from jsonb_array_elements(public.uniion_agenda_list(p_org)) limit 20) events;
  context=jsonb_set(context,'{agenda}',agenda);
  dependencies=dependencies||coalesce((select jsonb_agg(jsonb_build_object('kind','agenda','id',e->>'id')) from jsonb_array_elements(agenda)e),'[]');
 exception when insufficient_privilege then null;end;
 return jsonb_build_object('title',name,'version',1,'description',context::text,'dependencies',dependencies);
end$$;


--
-- Name: uniion_ai_native_before_workspace(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_native_before_workspace(p_org uuid, p_kind text, p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 if p_kind='agenda' then
  select value into result from jsonb_array_elements(public.uniion_agenda_list(p_org)) where value->>'id'=p_id::text;
 elsif p_kind='adherents' then
  select value into result from jsonb_array_elements(public.uniion_adherents(p_org,'list','{}')->'rows') where value->>'id'=p_id::text;
 elsif p_kind='workspace' then
  perform public.uniion_module_use(p_org,'assistant');
  if p_id<>p_org then raise insufficient_privilege;end if;
  select jsonb_build_object('title',name,'description','Espace de travail uniion. Les droits des modules et des ressources sont contrôlés séparément.','version',1) into result from public.uniion_organizations where id=p_org and active;
 else
  result=public.uniion_business_records(p_org,p_kind,'get',jsonb_build_object('id',p_id));
 end if;
 if result is null then raise insufficient_privilege;end if;
 return result;
end$$;


--
-- Name: uniion_ai_policy(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_policy(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
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
  if p_action='authorize' then perform public.uniion_module_use(p_org,'assistant');
  elsif not (uniion_private.super_admin() or uniion_private.actor_member(p_org,auth.uid())) then raise insufficient_privilege;end if;
  if p_payload<>'{}' then raise insufficient_privilege;end if;
 end if;
 ready=p.approved and coalesce(a.enabled and a.provider_version=p.version,false);
 if p_action='authorize' then
  if not ready or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='assistant' and permission='write') then raise insufficient_privilege;end if;
 end if;
 return jsonb_build_object('provider',p.id,'approved',p.approved,'providerVersion',p.version,'activationVersion',coalesce(a.version,0),'enabled',coalesce(a.enabled,false),'ready',ready,'scope',p.scope,'actor',auth.uid(),'canReview',uniion_private.super_admin(),'canActivate',uniion_private.actor_member(p_org,auth.uid()) and uniion_private.authority(p_org,auth.uid(),'organization_edit'));
end $_$;


--
-- Name: uniion_ai_recipe(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_recipe(p_org uuid, p_action text, p_refs jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare item jsonb;
begin
 if p_action<>'check' or not exists(select 1 from uniion_private.ai_interactive_recipes where organization_id=p_org and enabled) then return public.uniion_ai_recipe_certified151(p_org,p_action,p_refs);end if;
 perform public.uniion_ai_interactive(p_org);
 if jsonb_typeof(p_refs)<>'array' or jsonb_array_length(p_refs) not between 1 and 8 then raise insufficient_privilege;end if;
 for item in select value from jsonb_array_elements(p_refs) loop
  if jsonb_typeof(item)<>'object' or not(item ?& array['kind','id','fingerprint']) or item-array['kind','id','seq','fingerprint']<>'{}' or item->>'fingerprint' !~ '^[0-9a-f]{64}$' then raise insufficient_privilege;end if;
  if item->>'kind'='case' then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='document' then perform public.uniion_documents(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='message' then perform public.uniion_messaging(p_org,'locate',jsonb_build_object('id',item->>'id','seq',item->>'seq'));
  else perform public.uniion_ai_native(p_org,item->>'kind',(item->>'id')::uuid);end if;
 end loop;
 return '{"allowed":true}';
end$_$;


--
-- Name: uniion_ai_recipe_certified151(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_ai_recipe_certified151(p_org uuid, p_action text, p_refs jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare item jsonb; f uniion_private.ai_recipe_sources; result jsonb='[]'::jsonb; projection jsonb;
begin
 perform public.uniion_ai_policy(p_org,'authorize','{}');
 if p_action is null or p_action not in ('catalog','check') or jsonb_typeof(p_refs) is distinct from 'array' then raise insufficient_privilege;end if;
 if p_action='catalog' then
  if p_refs<>'[]' then raise insufficient_privilege;end if;
  for f in select * from uniion_private.ai_recipe_sources where organization_id=p_org and enabled order by kind,id,seq limit 64 loop
   begin
    if f.kind='case' then projection=public.uniion_cases(p_org,'get',jsonb_build_object('id',f.id));
    elsif f.kind='document' then projection=public.uniion_documents(p_org,'get',jsonb_build_object('id',f.id));
    elsif f.kind='message' then projection=public.uniion_messaging(p_org,'locate',jsonb_build_object('id',f.id,'seq',f.seq));
    else projection=public.uniion_ai_native(p_org,f.kind,f.id);
    end if;
    result=result||jsonb_build_array(jsonb_build_object('kind',f.kind,'id',f.id)||case when f.kind='message' then jsonb_build_object('seq',f.seq) else '{}'::jsonb end);
   exception when insufficient_privilege then null;
   end;
  end loop;
  return result;
 end if;
 if jsonb_array_length(p_refs) not between 1 and 8 then raise insufficient_privilege;end if;
 for item in select value from jsonb_array_elements(p_refs) loop
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['kind','id','fingerprint'])
   or item-array['kind','id','seq','fingerprint']<>'{}'
   or not exists(select 1 from uniion_private.ai_recipe_sources r where r.organization_id=p_org and r.kind=item->>'kind' and r.id::text=item->>'id' and r.seq=coalesce(item->>'seq','') and r.fingerprint=item->>'fingerprint' and r.enabled) then raise insufficient_privilege;end if;
  if item->>'kind'='case' then perform public.uniion_cases(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='document' then perform public.uniion_documents(p_org,'get',jsonb_build_object('id',item->>'id'));
  elsif item->>'kind'='message' then perform public.uniion_messaging(p_org,'locate',jsonb_build_object('id',item->>'id','seq',item->>'seq'));
  else perform public.uniion_ai_native(p_org,item->>'kind',(item->>'id')::uuid);end if;
 end loop;
 return jsonb_build_object('allowed',true);
end $$;


--
-- Name: uniion_attachment_finish(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_attachment_finish(p_org uuid, p_attachment uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or a.creator<>auth.uid() or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) or not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name and (metadata->>'size')::bigint=a.size) then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=true where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.uploaded',jsonb_build_object('attachment',a.id,'resource',a.resource_id));
 return jsonb_build_object('id',a.id,'filename',a.filename);
end $$;


--
-- Name: uniion_attachment_get(uuid, uuid, uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_attachment_get(p_org uuid, p_attachment uuid, p_share uuid DEFAULT NULL::uuid, p_audit boolean DEFAULT true, p_preview boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 if uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return public.uniion_attachment_get_before_trash(p_org,p_attachment,p_share,p_audit,p_preview);
end$$;


--
-- Name: uniion_attachment_get_before_trash(uuid, uuid, uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_attachment_get_before_trash(p_org uuid, p_attachment uuid, p_share uuid DEFAULT NULL::uuid, p_audit boolean DEFAULT true, p_preview boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found or not (case when p_preview then uniion_private.attachment_preview(a.id,auth.uid(),p_share) else uniion_private.attachment_access(a.id,auth.uid(),p_share) end) or (p_share is null and a.organization_id<>p_org) or (p_share is not null and not exists(select 1 from public.uniion_shares where id=p_share and target_id=p_org)) then raise insufficient_privilege;end if;
 if p_audit then insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(a.organization_id,case when p_share is null then null else p_org end,auth.uid(),case when p_preview then 'attachment.previewed' else 'attachment.downloaded' end,jsonb_build_object('attachment',a.id,'resource',a.resource_id,'share',p_share));end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;


--
-- Name: uniion_attachment_prepare(uuid, uuid, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_attachment_prepare(p_org uuid, p_resource uuid, p_filename text, p_mime text, p_size integer, p_sha256 text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 perform 1 from public.uniion_resources where id=p_resource and organization_id=p_org for update;
 if exists(select 1 from uniion_private.message_files where resource=p_resource and attachment is not null) then raise insufficient_privilege;end if;
 return public.uniion_attachment_prepare_before_messages(p_org,p_resource,p_filename,p_mime,p_size,p_sha256);
end$$;


--
-- Name: uniion_attachment_prepare_before_messages(uuid, uuid, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_attachment_prepare_before_messages(p_org uuid, p_resource uuid, p_filename text, p_mime text, p_size integer, p_sha256 text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare aid uuid=gen_random_uuid();path text;
begin
 if not uniion_private.actor_resource(p_org,p_resource,auth.uid(),true) then raise insufficient_privilege;end if;
 path=p_org::text||'/'||p_resource::text||'/'||aid::text;
 insert into public.uniion_attachments(id,organization_id,resource_id,filename,mime,size,sha256,object_name,creator) values(aid,p_org,p_resource,p_filename,p_mime,p_size,p_sha256,path,auth.uid());
 return jsonb_build_object('id',aid,'path',path);
end $$;


--
-- Name: uniion_audio_local_receipts(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_local_receipts(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 perform public.uniion_module_use(p_org,'reunions');
 return jsonb_build_object('receipts',coalesce((select jsonb_agg(jsonb_build_object('audio',a.id,'request',a.request_id,'meeting',a.meeting_id)) from uniion_private.meeting_audio a where a.organization_id=p_org and a.actor=auth.uid() and
 (exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=a.id) or (a.status='clean' and exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.path) and not exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=a.id and o.status<>'clean')))),'[]'));
end$$;


--
-- Name: uniion_audio_original(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_original(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare f uniion_private.meeting_audio;o uniion_private.meeting_audio_originals;partno integer;data bytea;old bytea;
begin
 if p_action is null or p_action not in ('begin','put','progress','assemble','receipt','download') then raise insufficient_privilege;end if;
 if jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 if p_action='download' then
  perform public.uniion_meeting_audio(p_org,p_meeting,'download',jsonb_build_object('audio',p_payload->>'audio','audit',true));
 else
  perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 end if;
 select * into f from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=(p_payload->>'audio')::uuid for update;
 if not found or f.status='blocked' or not exists(select 1 from uniion_private.meeting_consents c join public.uniion_resources r on r.id=c.meeting_id and r.organization_id=c.organization_id where c.organization_id=p_org and c.meeting_id=p_meeting and c.version=f.consent_version and r.version=f.meeting_version and c.accepted) or (p_action<>'download' and f.actor<>auth.uid()) then raise insufficient_privilege;end if;
 if p_action='begin' then
  if not(p_payload ?& array['audio','filename','size','sha256']) or p_payload-array['audio','filename','size','sha256']<>'{}' or jsonb_typeof(p_payload->'filename') is distinct from 'string' or jsonb_typeof(p_payload->'sha256') is distinct from 'string' or jsonb_typeof(p_payload->'size') is distinct from 'number' or (p_payload->>'size') !~ '^[1-9][0-9]{0,7}$' then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_audio_originals(audio_id,filename,size,sha256) values(f.id,p_payload->>'filename',(p_payload->>'size')::int,p_payload->>'sha256') on conflict do nothing;
 end if;
 select * into o from uniion_private.meeting_audio_originals where audio_id=f.id;
 if not found or o.status='blocked' then raise insufficient_privilege;end if;
 if p_action='begin' then
  if o.filename is distinct from p_payload->>'filename' or o.size is distinct from (p_payload->>'size')::int or o.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
 elsif p_action='put' then
  if p_payload-array['audio','part','content']<>'{}' or jsonb_typeof(p_payload->'part') is distinct from 'number' or (p_payload->>'part') !~ '^(0|[1-9][0-9]?)$' or jsonb_typeof(p_payload->'content') is distinct from 'string' or length(p_payload->>'content')>349528 then raise insufficient_privilege;end if;
  partno=(p_payload->>'part')::int;data=decode(p_payload->>'content','base64');
  if partno not between 0 and (o.size-1)/262144 or octet_length(data)<>least(262144,o.size-partno*262144) then raise insufficient_privilege;end if;
  select bytes into old from uniion_private.meeting_audio_original_parts where audio_id=f.id and part=partno;
  if found then if old<>data then raise insufficient_privilege;end if;
  else if o.status<>'pending' then raise insufficient_privilege;end if;insert into uniion_private.meeting_audio_original_parts values(f.id,partno,data);end if;
 elsif p_action in ('assemble','download') then
  if p_payload-array['audio']<>'{}' or (p_action='download' and o.status<>'clean') then raise insufficient_privilege;end if;
  select string_agg(bytes,''::bytea order by part) into data from uniion_private.meeting_audio_original_parts where audio_id=f.id;
  if data is null or octet_length(data)<>o.size then raise insufficient_privilege;end if;
  return to_jsonb(o)||jsonb_build_object('content',encode(data,'base64'));
 elsif p_action not in ('progress','receipt') or p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 if p_action='receipt' and o.status<>'clean' then raise insufficient_privilege;end if;
 return to_jsonb(o)||jsonb_build_object('parts',coalesce((select jsonb_agg(part order by part) from uniion_private.meeting_audio_original_parts where audio_id=f.id),'[]'));
exception when invalid_text_representation or check_violation or numeric_value_out_of_range or not_null_violation then raise insufficient_privilege;
end$_$;


--
-- Name: uniion_audio_original_finish(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_original_finish(p_audio uuid, p_sha text, p_status text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare o uniion_private.meeting_audio_originals;
begin
 if not uniion_private.is_scanner() or p_status is null or p_status not in ('clean','blocked') then raise insufficient_privilege;end if;
 select * into o from uniion_private.meeting_audio_originals where audio_id=p_audio for update;
 if not found or o.status='blocked' or o.sha256 is distinct from p_sha or o.size<>(select coalesce(sum(octet_length(bytes)),0) from uniion_private.meeting_audio_original_parts where audio_id=p_audio) then raise insufficient_privilege;end if;
 update uniion_private.meeting_audio_originals set status=p_status where audio_id=p_audio;
 insert into public.uniion_security_events(organization_id,actor,event,details) select organization_id,auth.uid(),'meeting.audio.original_scanned',jsonb_build_object('audio',p_audio,'status',p_status) from uniion_private.meeting_audio where id=p_audio;
end$$;


--
-- Name: uniion_audio_policy(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_policy(p_org uuid, p_hours integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 perform public.uniion_module_use(p_org,'reunions');
 if p_hours is not null then
  if not uniion_private.authority(p_org,auth.uid(),'organization_edit') or p_hours not between 1 and 168 then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_audio_policy values(p_org,p_hours) on conflict(organization_id) do update set local_hours=excluded.local_hours;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.local_policy',jsonb_build_object('hours',p_hours));
 end if;
 return jsonb_build_object('hours',coalesce((select local_hours from uniion_private.meeting_audio_policy where organization_id=p_org),24));
end$$;


--
-- Name: uniion_audio_retention(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_retention(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 result=public.uniion_audio_retention_before_remaining(p_org,p_meeting,p_action,p_payload);
 if p_action='status' then
  result=result||jsonb_build_object('remaining',(select count(*) from uniion_private.meeting_audio a where a.organization_id=p_org and a.meeting_id=p_meeting and not exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=a.id)));
 end if;
 return result;
end$$;


--
-- Name: uniion_audio_retention_before_remaining(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_retention_before_remaining(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare b uniion_private.audio_retention_batches;ids uuid[];bid uuid;inv jsonb;item record;op boolean=coalesce(uniion_private.super_admin(),false);
begin
 if p_action is null or p_action not in ('status','collect','list','approve','hold','refresh') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='status' then
  perform public.uniion_module_use(p_org,'reunions');
  if not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),false) or p_payload<>'{}' then raise insufficient_privilege;end if;
  return jsonb_build_object('validated',(select count(*) from uniion_private.audio_retention_validations v join uniion_private.meeting_audio a on a.id=v.audio_id where a.organization_id=p_org and a.meeting_id=p_meeting),'due',(select min(v.validated_at+interval '30 days') from uniion_private.audio_retention_validations v join uniion_private.meeting_audio a on a.id=v.audio_id where a.organization_id=p_org and a.meeting_id=p_meeting and not exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=a.id)), 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'state',state,'holdUntil',hold_until) order by created_at) from uniion_private.audio_retention_batches where organization_id=p_org and meeting_id=p_meeting),'[]'));
 end if;
 if not op then raise insufficient_privilege;end if;
 -- Metadata only, no filename, transcript, title or participants.
 if p_action='list' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(t) order by created_at) from uniion_private.audio_retention_batches t where organization_id=p_org),'[]'));
 elsif p_action='collect' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  perform pg_advisory_xact_lock(910180);
  for item in select distinct a.meeting_id from uniion_private.meeting_audio a join uniion_private.audio_retention_validations v on v.audio_id=a.id where a.organization_id=p_org and v.validated_at+interval '30 days'<=now() and not exists(select 1 from uniion_private.audio_retention_items i where i.audio_id=a.id) loop
   select array_agg(a.id order by a.id) into ids from uniion_private.meeting_audio a join uniion_private.audio_retention_validations v on v.audio_id=a.id where a.organization_id=p_org and a.meeting_id=item.meeting_id and v.validated_at+interval '30 days'<=now() and not exists(select 1 from uniion_private.audio_retention_items i where i.audio_id=a.id);
   inv=uniion_private.audio_inventory(ids);
   insert into uniion_private.audio_retention_batches(organization_id,meeting_id,inventory,requested_by) values(p_org,item.meeting_id,inv,auth.uid()) returning id into bid;
   insert into uniion_private.audio_retention_items select unnest(ids),bid;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.retention.requested',jsonb_build_object('batch',bid,'count',cardinality(ids)));
  end loop;
  return public.uniion_audio_retention(p_org,null,'list','{}');
 end if;
 if p_payload-array['id','inventory','reason','until']<>'{}' or length(btrim(p_payload->>'reason')) not between 1 and 240 or p_payload->>'reason' is null then raise insufficient_privilege;end if;
 select * into b from uniion_private.audio_retention_batches where id=(p_payload->>'id')::uuid and organization_id=p_org for update;
 if not found or b.state not in ('pending','held','approved') or b.inventory is distinct from p_payload->'inventory' then raise insufficient_privilege;end if;
 if p_action='refresh' then
  select array_agg(audio_id order by audio_id) into ids from uniion_private.audio_retention_items where batch_id=b.id;
  update uniion_private.audio_retention_batches set inventory=uniion_private.audio_inventory(ids),state=case when hold_until>now() then 'held' else 'pending' end,approved_by=null,approved_at=null,reason=p_payload->>'reason' where id=b.id;
 elsif p_action='hold' then
  if (p_payload->>'until')::timestamptz is null or (p_payload->>'until')::timestamptz<=now() then raise insufficient_privilege;end if;
  update uniion_private.audio_retention_batches set state='held',reason=p_payload->>'reason',hold_until=(p_payload->>'until')::timestamptz where id=b.id;
 else
  if b.hold_until>now() then raise insufficient_privilege;end if;
  -- R39 : la personne qui a demandé la suppression ne peut pas l'approuver seule.
  if b.requested_by is not distinct from auth.uid() then raise insufficient_privilege;end if;
  -- R38 : chaque audio du lot doit encore être éligible (PV publié, non révoqué).
  if exists(select 1 from uniion_private.audio_retention_items i where i.batch_id=b.id and not exists(select 1 from uniion_private.audio_retention_validations v where v.audio_id=i.audio_id)) then raise insufficient_privilege;end if;
  select array_agg(audio_id order by audio_id) into ids from uniion_private.audio_retention_items where batch_id=b.id;
  if uniion_private.audio_inventory(ids) is distinct from b.inventory then raise insufficient_privilege;end if;
  update uniion_private.audio_retention_batches set state='approved',reason=p_payload->>'reason',approved_by=auth.uid(),approved_at=now() where id=b.id;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.retention.'||p_action,jsonb_build_object('batch',b.id));
 return jsonb_build_object('ok',true);
end$$;


--
-- Name: uniion_audio_retention_execute(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_retention_execute(p_batch uuid, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare b uniion_private.audio_retention_batches;ids uuid[];
begin
 if not uniion_private.is_scanner() or p_action is null or p_action not in ('begin','finish') then raise insufficient_privilege;end if;
 select * into b from uniion_private.audio_retention_batches where id=p_batch for update;
 if not found or b.state not in ('approved','executing','done') or not exists(select 1 from uniion_private.super_admins where user_id=b.approved_by and active) then raise insufficient_privilege;end if;
 if b.state='done' then return jsonb_build_object('done',true,'paths','[]'::jsonb);end if;
 select array_agg(audio_id order by audio_id) into ids from uniion_private.audio_retention_items where batch_id=b.id;
 perform 1 from uniion_private.meeting_audio where id=any(ids) order by id for update;
 if p_action='begin' then
  if b.state='approved' and uniion_private.audio_inventory(ids) is distinct from b.inventory then raise insufficient_privilege;end if;
  insert into uniion_private.audio_tombstones(audio_id,batch_id,organization_id,meeting_id,sha256,request_id) select id,b.id,organization_id,meeting_id,sha256,request_id from uniion_private.meeting_audio where id=any(ids) on conflict do nothing;
  update uniion_private.meeting_audio set status='blocked' where id=any(ids);
  update uniion_private.meeting_audio_originals set status='blocked' where audio_id=any(ids);
  update uniion_private.transcription_jobs set state='cancelled',lease=null,worker=null,error='audio_deleted',updated_at=now() where source_ids&&ids and state<>'done';
  update uniion_private.audio_retention_batches set state='executing' where id=b.id;
 else
  if b.state<>'executing' or exists(select 1 from storage.objects where bucket_id='uniion-private' and name in(select path from uniion_private.meeting_audio where id=any(ids))) then raise insufficient_privilege;end if;
  delete from uniion_private.meeting_audio_chunks where audio_id=any(ids);
  delete from uniion_private.meeting_audio_original_parts where audio_id=any(ids);
  update uniion_private.audio_retention_batches set state='done',finished_at=now() where id=b.id;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(b.organization_id,auth.uid(),'meeting.retention.'||p_action,jsonb_build_object('batch',b.id));
 return jsonb_build_object('done',p_action='finish','paths',(select jsonb_agg(path order by id) from uniion_private.meeting_audio where id=any(ids)));
end$$;


--
-- Name: uniion_audio_sequence(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_audio_sequence(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare f uniion_private.meeting_audio;prev uniion_private.meeting_audio;s uniion_private.meeting_audio_sequences;offset_value bigint;pos integer;rec uuid;
begin
 if p_action='list' and p_payload='{}' then
  perform public.uniion_meeting_audio(p_org,p_meeting,'list','{}');
  return coalesce((select jsonb_agg(jsonb_build_object('audio',a.id,'recording',q.recording_id,'position',q.position,'offsetMs',q.offset_ms,'durationMs',a.duration_ms) order by q.position) from uniion_private.meeting_audio a join uniion_private.meeting_audio_sequences q on q.audio_id=a.id where a.organization_id=p_org and a.meeting_id=p_meeting),'[]');
 end if;
 if p_action is distinct from 'link' or jsonb_typeof(p_payload) is distinct from 'object' or not(p_payload ?& array['audio','recording','position']) or p_payload-array['audio','recording','position']<>'{}' or jsonb_typeof(p_payload->'position') is distinct from 'number' or (p_payload->>'position') !~ '^(0|[1-9][0-9]{0,2})$' then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 -- Meeting lock acquired by the preceding RPC serializes all links in a recording.
 select * into f from uniion_private.meeting_audio where id=(p_payload->>'audio')::uuid and organization_id=p_org and meeting_id=p_meeting and actor=auth.uid() and duration_ms>0;
 if not found then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'uploaded',jsonb_build_object('audio',f.id));
 rec=(p_payload->>'recording')::uuid;pos=(p_payload->>'position')::int;offset_value=0;
 if pos>0 then
  select a.* into prev from uniion_private.meeting_audio_sequences q join uniion_private.meeting_audio a on a.id=q.audio_id where q.recording_id=rec and q.position=pos-1;
  if not found or prev.organization_id<>p_org or prev.meeting_id<>p_meeting or prev.actor<>auth.uid() or prev.consent_version<>f.consent_version or prev.meeting_version<>f.meeting_version then raise insufficient_privilege;end if;
  select offset_ms+prev.duration_ms into offset_value from uniion_private.meeting_audio_sequences where audio_id=prev.id;
 elsif rec<>f.request_id then raise insufficient_privilege;end if;
 select * into s from uniion_private.meeting_audio_sequences where audio_id=f.id;
 if found then
  if s.recording_id<>rec or s.position<>pos or s.offset_ms<>offset_value then raise insufficient_privilege;end if;
 else insert into uniion_private.meeting_audio_sequences values(f.id,rec,pos,offset_value);end if;
 return jsonb_build_object('recording',rec,'position',pos,'offsetMs',offset_value,'durationMs',f.duration_ms);
exception when invalid_text_representation or check_violation or unique_violation or not_null_violation or numeric_value_out_of_range then raise insufficient_privilege;
end$_$;


--
-- Name: uniion_business_publication(uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_business_publication(p_org uuid, p_module text, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;p uniion_private.business_publications;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action='revoke' then
  perform public.uniion_module_use(p_org,'reunions');
  if p_module is distinct from 'reunions' or p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') or not uniion_private.actor_resource_before_minutes(p_org,d.meeting_id,auth.uid(),false) then raise insufficient_privilege;end if;
  update uniion_private.business_publications set revoked_at=coalesce(revoked_at,now()) where organization_id=p_org and resource_id=d.resource_id and version=(p_payload->>'version')::int returning * into p;
  if not found then raise insufficient_privilege;end if;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.revoke',jsonb_build_object('id',d.resource_id,'version',p.version));
  return jsonb_build_object('id',d.resource_id,'version',p.version,'reviewed',false,'published',false,'download',false);
 end if;
 if d.resource_id is not null and p_action in ('review','publish') then
  select * into r from public.uniion_resources where organization_id=p_org and id=d.resource_id;
  if jsonb_typeof(r.body->'minutes') is distinct from 'string' or length(btrim(r.body->>'minutes'))<1 then raise insufficient_privilege;end if;
 end if;
 result=public.uniion_business_publication_before_minutes(p_org,p_module,p_action,p_payload);
 if d.resource_id is not null and p_action='review' then
  update uniion_private.business_publications set body=jsonb_build_object('title',r.title,'minutes',r.body->>'minutes') where organization_id=p_org and resource_id=r.id and version=r.version and published_at is null;
 end if;
 return result;
end$$;


--
-- Name: uniion_business_publication_before_minutes(uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_business_publication_before_minutes(p_org uuid, p_module text, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r public.uniion_resources;p uniion_private.business_publications;targets uuid[];em text;uid uuid;
begin
 perform public.uniion_module_use(p_org,p_module);
 if p_module not in ('mobile','communication','intranet','reunions') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='feed' and p_payload='{}' then
  -- Approved version has its own audience. No source ids, actors or private citations metadata.
  return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'body',body,'source',case when uniion_private.actor_resource(p_org,resource_id,auth.uid(),false) then resource_id else null end,'published',published_at,'download',false) order by published_at desc) from uniion_private.business_publications where organization_id=p_org and module=p_module and published_at is not null and revoked_at is null and auth.uid()=any(recipients)),'[]'));
 end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module=p_module for update;
 if not found or not exists(select 1 from uniion_private.business_records where id=r.id and organization_id=p_org) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or (p_action not in ('revoke','status') and r.version is distinct from (p_payload->>'version')::int) then raise insufficient_privilege;end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=(p_payload->>'version')::int for update;
 if p_action='status' and p.id is null and r.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
 if p_action='review' then
  if p_payload-array['id','version','recipients']<>'{}' or jsonb_typeof(p_payload->'recipients')<>'array' or jsonb_array_length(p_payload->'recipients') not between 1 and 50 or not uniion_private.authority(p_org,auth.uid(),'content_review') or exists(select 1 from public.uniion_resource_versions where organization_id=p_org and resource_id=r.id and version<=r.version and (actor=auth.uid() or actor is null)) then raise insufficient_privilege;end if;
  targets=array[]::uuid[];
  for em in select jsonb_array_elements_text(p_payload->'recipients') loop
   select u.id into uid from auth.users u where lower(u.email)=lower(trim(em)) and uniion_private.actor_member(p_org,u.id);
   if uid is null then raise insufficient_privilege;end if;
   if not uid=any(targets) then targets=array_append(targets,uid);end if;
  end loop;
  if p.published_at is not null then raise insufficient_privilege;end if;
  insert into uniion_private.business_publications(organization_id,resource_id,version,module,body,recipients,reviewer) values(p_org,r.id,r.version,p_module,r.body,targets,auth.uid()) on conflict(organization_id,resource_id,version) do update set body=excluded.body,recipients=excluded.recipients,reviewer=excluded.reviewer,reviewed_at=now(),revoked_at=null;
 elsif p_action='publish' then
  if p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') or p.reviewer is null or p.revoked_at is not null or not uniion_private.actor_resource(p_org,r.id,p.reviewer,false) or not uniion_private.authority(p_org,p.reviewer,'content_review') then raise insufficient_privilege;end if;
  update uniion_private.business_publications set publisher=auth.uid(),published_at=now() where id=p.id and published_at is null;
 elsif p_action='revoke' then
  if p.id is null or p_payload-array['id','version']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'content_publish') then raise insufficient_privilege;end if;
  update uniion_private.business_publications set revoked_at=now() where id=p.id;
 elsif p_action<>'status' or p_payload-array['id','version']<>'{}' then raise insufficient_privilege;end if;
 if p_action<>'status' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.'||p_action,jsonb_build_object('id',r.id,'version',(p_payload->>'version')::int));end if;
 select * into p from uniion_private.business_publications where organization_id=p_org and resource_id=r.id and version=(p_payload->>'version')::int;
 return jsonb_build_object('id',r.id,'version',(p_payload->>'version')::int,'currentVersion',r.version,'reviewed',p.reviewer is not null and p.revoked_at is null,'published',p.published_at is not null and p.revoked_at is null,'audienceCount',coalesce(cardinality(p.recipients),0),'download',false);
end$$;


--
-- Name: uniion_business_records(uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_business_records(p_org uuid, p_module text, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;rows jsonb;d uniion_private.meeting_minutes;r public.uniion_resources;
begin
 select * into d from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(p_payload->>'id')::uuid;
 if found and p_action='save' then
  -- Only the draft prose/title may change. Source snapshots cannot be overwritten by the client.
  perform public.uniion_module_use(p_org,'reunions');
  select * into r from public.uniion_resources where id=d.resource_id and organization_id=p_org for update;
  if p_module is distinct from 'reunions' or not uniion_private.actor_resource(p_org,r.id,auth.uid(),true) or r.version is distinct from (p_payload->>'version')::int or p_payload-array['id','version','data']<>'{}'
   or (p_payload->'data')-array['title','minutes'] is distinct from r.body-array['title','minutes']
   or jsonb_typeof(p_payload->'data'->'title') is distinct from 'string' or length(btrim(p_payload->'data'->>'title')) not between 1 and 200
   or jsonb_typeof(p_payload->'data'->'minutes') is distinct from 'string' or octet_length((p_payload->'data')::text)>6291456 then raise insufficient_privilege;end if;
  update public.uniion_resources set title=p_payload->'data'->>'title',body=p_payload->'data',version=version+1 where id=r.id returning * into r;
  update uniion_private.business_records set updated_at=now() where id=r.id;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.save',jsonb_build_object('module','reunions','id',r.id,'version',r.version));
  return r.body||jsonb_build_object('id',r.id,'version',r.version,'module','reunions','meetingPV',true,'status','Brouillon','serverRecord',true,'canWrite',true);
 end if;
 result=public.uniion_business_records_before_minutes(p_org,p_module,p_action,p_payload);
 if p_module='reunions' and p_action='list' then
  select coalesce(jsonb_agg(x||case when exists(select 1 from uniion_private.meeting_minutes where resource_id=(x->>'id')::uuid and organization_id=p_org) then '{"meetingPV":true}'::jsonb else '{}'::jsonb end),'[]') into rows from jsonb_array_elements(result->'rows')x;
  return jsonb_build_object('rows',rows);
 end if;
 if exists(select 1 from uniion_private.meeting_minutes where organization_id=p_org and resource_id=(result->>'id')::uuid) then result=result||'{"meetingPV":true}'::jsonb;end if;
 return result;
end$$;


--
-- Name: uniion_business_records_base150(uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_business_records_base150(p_org uuid, p_module text, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r public.uniion_resources;rid uuid;d jsonb;
begin
 if p_module is null or p_module not in ('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,p_module);
 if p_action='list' and p_payload='{}' then
  return jsonb_build_object('rows',coalesce((select jsonb_agg(recordrow.body||jsonb_build_object('id',recordrow.id,'version',recordrow.version,'module',recordrow.module,'status','Brouillon','serverRecord',true,'canWrite',uniion_private.actor_resource(p_org,recordrow.id,auth.uid(),true)) order by stored.updated_at desc) from public.uniion_resources recordrow join uniion_private.business_records stored on stored.organization_id=recordrow.organization_id and stored.id=recordrow.id where recordrow.organization_id=p_org and recordrow.module=p_module and uniion_private.actor_resource(p_org,recordrow.id,auth.uid(),false)),'[]'));
 end if;
 if p_action='create' then
  if p_payload-array['data']<>'{}' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='write') then raise insufficient_privilege;end if;
  d=uniion_private.business_payload(p_module,p_payload->'data');
  insert into public.uniion_resources(organization_id,module,title,body) values(p_org,p_module,d->>'title',d) returning * into r;
  insert into uniion_private.business_records(organization_id,id,creator) values(p_org,r.id,auth.uid());
  insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,'infinity',null);
 else
  select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module=p_module for update;
  if not found or not exists(select 1 from uniion_private.business_records where organization_id=p_org and id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
  if p_action='get' and p_payload-array['id']='{}' then
   return r.body||jsonb_build_object('id',r.id,'version',r.version,'module',r.module,'status','Brouillon','serverRecord',true,'canWrite',uniion_private.actor_resource(p_org,r.id,auth.uid(),true));
  end if;
  if p_action<>'save' or p_payload-array['id','version','data']<>'{}' or r.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
  d=uniion_private.business_payload(p_module,p_payload->'data');
  update public.uniion_resources set title=d->>'title',body=d,version=version+1 where id=r.id returning * into r;
  update uniion_private.business_records set updated_at=now() where id=r.id;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'business.'||p_action,jsonb_build_object('module',p_module,'id',r.id,'version',r.version));
 return r.body||jsonb_build_object('id',r.id,'version',r.version,'module',r.module,'status','Brouillon','serverRecord',true,'canWrite',true);
end$$;


--
-- Name: uniion_business_records_before_minutes(uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_business_records_before_minutes(p_org uuid, p_module text, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;row jsonb;status text;rows jsonb='[]';
begin
 result=public.uniion_business_records_base150(p_org,p_module,p_action,p_payload);
 if p_action='list' then
  for row in select value from jsonb_array_elements(result->'rows') loop
   select case when revoked_at is not null then 'Brouillon' when published_at is not null then 'En ligne' else 'En relecture' end into status from uniion_private.business_publications where organization_id=p_org and resource_id=(row->>'id')::uuid and version=(row->>'version')::int;
   rows=rows||jsonb_build_array(row||jsonb_build_object('status',coalesce(status,'Brouillon')));
  end loop;
  return jsonb_build_object('rows',rows);
 end if;
 select case when revoked_at is not null then 'Brouillon' when published_at is not null then 'En ligne' else 'En relecture' end into status from uniion_private.business_publications where organization_id=p_org and resource_id=(result->>'id')::uuid and version=(result->>'version')::int;
 return result||jsonb_build_object('status',coalesce(status,'Brouillon'));
end$$;


--
-- Name: uniion_case_assign(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_assign(p_org uuid, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare rid uuid;target uuid;prior uuid;ver integer;target_name text;
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_payload-ARRAY['id','version','user']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'dossiers_assign') then raise insufficient_privilege;end if;
 rid=(p_payload->>'id')::uuid;target=(p_payload->>'user')::uuid;
 select version into ver from public.uniion_resources where organization_id=p_org and id=rid and module='dossiers' for update;
 if not found or ver is distinct from (p_payload->>'version')::integer or target=auth.uid() or not uniion_private.actor_resource(p_org,rid,auth.uid(),true) then raise insufficient_privilege;end if;
 select owner into prior from uniion_private.cases where organization_id=p_org and id=rid for update;
 if not found or target is null or target=prior then raise insufficient_privilege;end if;
 -- Serialize grant changes and recheck both read/write; assignment never creates a grant.
 perform 1 from public.uniion_resource_grants where organization_id=p_org and resource_id=rid and user_id in (prior,target,auth.uid()) order by user_id for update;
 if not uniion_private.actor_resource(p_org,rid,target,false) or not uniion_private.actor_resource(p_org,rid,target,true) or not uniion_private.actor_resource(p_org,rid,auth.uid(),true) then raise insufficient_privilege;end if;
 update uniion_private.cases set owner=target where organization_id=p_org and id=rid;
 update public.uniion_resource_grants set revoked_at=now() where organization_id=p_org and resource_id=rid and user_id=prior;
 update public.uniion_resources set version=version+1 where organization_id=p_org and id=rid;
 select name into target_name from uniion_private.identity_profiles where organization_id=p_org and user_id=target;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,rid,auth.uid(),'Référent modifié',coalesce(target_name,'Membre habilité')||' devient référent. Accès direct de l’ancien référent retiré.');
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.assigned',jsonb_build_object('resource',rid,'previous',prior,'target',target,'version',ver+1));
 -- Do not return the protected document to the outgoing assignee.
 return jsonb_build_object('ok',true,'accessRetained',uniion_private.actor_resource(p_org,rid,auth.uid(),false));
end$$;


--
-- Name: uniion_case_classify(uuid, uuid, integer, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_classify(p_org uuid, p_case uuid, p_expected integer, p_convocation uuid, p_file text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare source jsonb; v integer; ident uuid;
begin
 perform public.uniion_case_files(p_org,p_case);
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 source=uniion_private.case_source(p_org,p_convocation,p_file);
 if source is null or p_file is null then raise insufficient_privilege;end if;
 select version into v from public.uniion_resources where id=p_case and organization_id=p_org for update;
 select id into ident from uniion_private.case_links where organization_id=p_org and resource_id=p_case and convocation=p_convocation and file=p_file;
 if ident is not null and exists(select 1 from uniion_private.case_links where id=ident and withdrawn) then raise insufficient_privilege;end if;
 if ident is not null then return jsonb_build_object('id',ident,'already',true);end if;
 if p_expected is distinct from v then raise serialization_failure;end if;
 insert into uniion_private.case_links(organization_id,resource_id,convocation,file,actor) values(p_org,p_case,p_convocation,p_file,auth.uid()) returning id into ident;
 update public.uniion_resources set version=version+1 where id=p_case;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.classified',jsonb_build_object('case',p_case,'link',ident));
 return jsonb_build_object('id',ident,'already',false);
end$$;


--
-- Name: uniion_case_disposal(uuid, text, uuid, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_disposal(p_org uuid, p_action text, p_case uuid DEFAULT NULL::uuid, p_link uuid DEFAULT NULL::uuid, p_request uuid DEFAULT NULL::uuid, p_expected integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.case_disposals; v integer; ident uuid;
begin
 if p_action in ('admin_list','approve','reject') then
  if not uniion_private.super_admin() then raise insufficient_privilege;end if;
  if p_action='admin_list' then return jsonb_build_object('requests',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization',organization_id,'root',resource_id,'kind',case when exists(select 1 from uniion_private.documents d where d.id=resource_id) then 'Document' when link is null then 'Dossier' else 'Référence' end,'revision',version,'reason',reason,'state',state)) from uniion_private.case_disposals where state='pending'),'[]'));end if;
  select * into t from uniion_private.case_disposals where id=p_request;
  if not found then raise insufficient_privilege;end if;
  select version into v from public.uniion_resources where id=t.resource_id and organization_id=t.organization_id for update;
  select * into t from uniion_private.case_disposals where id=p_request for update;
  if t.state<>'pending' then raise insufficient_privilege;end if;
  if p_action='approve' then
   if not uniion_private.actor_resource(t.organization_id,t.resource_id,t.requester,true) then raise insufficient_privilege;end if;
   if v<>t.version then raise serialization_failure;end if;
   update uniion_private.case_links set withdrawn=true where id=t.link;
   update public.uniion_resources set version=version+1,body=body where id=t.resource_id;
  end if;
  update uniion_private.case_disposals set state=case when p_action='approve' then 'approved' else 'rejected' end,decider=auth.uid(),decided_at=now() where id=t.id;ident=t.id;
 else
  perform public.uniion_module_use(p_org,'dossiers');
  if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('request',entry.id,'filename',case when entry.link is null then 'Dossier · ' else 'Référence · ' end||r.title,'state',entry.state,'deleted',entry.decided_at,'case',entry.resource_id)) from uniion_private.case_disposals entry join public.uniion_resources r on r.id=entry.resource_id where r.module='dossiers' and entry.organization_id=p_org and (p_case is null or entry.resource_id=p_case) and entry.state in ('pending','approved') and uniion_private.actor_resource_before_disposal(p_org,entry.resource_id,auth.uid(),false)),'[]'));end if;
  select version into v from public.uniion_resources where id=p_case and organization_id=p_org and module='dossiers' for update;
  if not found or not uniion_private.actor_resource_before_disposal(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
  if p_action='request' then
   if uniion_private.case_disposed(p_case) or p_reason is null or p_reason not in ('obsolete','duplicate','other') then raise insufficient_privilege;end if;
   if p_link is not null and not exists(select 1 from uniion_private.case_links where id=p_link and resource_id=p_case and organization_id=p_org and not withdrawn) then raise insufficient_privilege;end if;
   if p_expected is distinct from v then raise serialization_failure;end if;
   insert into uniion_private.case_disposals(organization_id,resource_id,link,version,reason,requester) values(p_org,p_case,p_link,v,p_reason,auth.uid()) returning * into t;ident=t.id;
  elsif p_action='restore' then
   select * into t from uniion_private.case_disposals where id=p_request and organization_id=p_org and resource_id=p_case for update;
   if not found or t.state<>'approved' or (t.link is not null and uniion_private.case_disposed(p_case)) then raise insufficient_privilege;end if;
   update uniion_private.case_disposals set state='restored',decider=auth.uid(),decided_at=now() where id=t.id;
   update uniion_private.case_links set withdrawn=false where id=t.link;
   update public.uniion_resources set version=version+1,body=body where id=p_case;ident=t.id;
  else raise insufficient_privilege;end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(t.organization_id,auth.uid(),'case.disposal_'||p_action,jsonb_build_object('request',ident,'case',t.resource_id,'link',t.link));
 return jsonb_build_object('ok',true,'id',ident);
end$$;


--
-- Name: uniion_case_file_version(uuid, uuid, uuid, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_file_version(p_org uuid, p_case uuid, p_root uuid, p_expected integer, p_restore integer DEFAULT NULL::integer, p_filename text DEFAULT NULL::text, p_mime text DEFAULT NULL::text, p_size integer DEFAULT NULL::integer, p_sha256 text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if uniion_private.case_file_trashed(p_root) then raise insufficient_privilege;end if;
 return public.uniion_case_file_version_before_trash(p_org,p_case,p_root,p_expected,p_restore,p_filename,p_mime,p_size,p_sha256);
end$$;


--
-- Name: uniion_case_file_version_before_trash(uuid, uuid, uuid, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_file_version_before_trash(p_org uuid, p_case uuid, p_root uuid, p_expected integer, p_restore integer DEFAULT NULL::integer, p_filename text DEFAULT NULL::text, p_mime text DEFAULT NULL::text, p_size integer DEFAULT NULL::integer, p_sha256 text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments; item jsonb; next_revision integer; source_id uuid;
begin
 perform public.uniion_case_files(p_org,p_case,p_root);
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_root and organization_id=p_org and resource_id=p_case for update;
 if not found or exists(select 1 from uniion_private.case_file_versions where attachment=p_root and root<>p_root) then raise insufficient_privilege;end if;
 insert into uniion_private.case_file_versions(root,revision,attachment,actor,created_at) values(p_root,1,p_root,a.creator,a.created_at) on conflict do nothing;
 select max(revision)+1 into next_revision from uniion_private.case_file_versions where root=p_root;
 if p_expected is null or p_expected<>next_revision-1 then raise serialization_failure using message='Version modifiée';end if;
 if p_restore is not null then
  select v.attachment into source_id from uniion_private.case_file_versions v join public.uniion_attachments f on f.id=v.attachment where v.root=p_root and v.revision=p_restore and f.scan_status='clean' and f.ready and f.organization_id=p_org and f.resource_id=p_case;
  if source_id is null then raise insufficient_privilege;end if;
  item=jsonb_build_object('id',source_id);
 else
  item=public.uniion_attachment_prepare(p_org,p_case,p_filename,p_mime,p_size,p_sha256);
  source_id=(item->>'id')::uuid;
 end if;
 insert into uniion_private.case_file_versions(root,revision,attachment,actor) values(p_root,next_revision,source_id,auth.uid());
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,p_case,auth.uid(),case when p_restore is null then 'Version déposée — analyse requise' else 'Version restaurée' end,'Pièce '||p_root||' · version '||next_revision||case when p_restore is null then '' else ' depuis v'||p_restore end);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.file_version',jsonb_build_object('root',p_root,'revision',next_revision,'restored_from',p_restore));
 return item||jsonb_build_object('revision',next_revision);
end$$;


--
-- Name: uniion_case_files(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_files(p_org uuid, p_case uuid, p_attachment uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select base||jsonb_build_object('files',(base->'files')||uniion_private.case_classified_files(p_org,p_case)) from (select public.uniion_case_files_before_links(p_org,p_case,p_attachment) base) t
$$;


--
-- Name: uniion_case_files_before_links(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_files_before_links(p_org uuid, p_case uuid, p_attachment uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if not exists(select 1 from uniion_private.cases where organization_id=p_org and id=p_case) or not uniion_private.actor_resource(p_org,p_case,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_attachment is not null and not exists(select 1 from public.uniion_attachments where organization_id=p_org and resource_id=p_case and id=p_attachment) then raise insufficient_privilege;end if;
 return jsonb_build_object('write',uniion_private.actor_resource(p_org,p_case,auth.uid(),true),'download',uniion_private.authority(p_org,auth.uid(),'download'),'files',uniion_private.case_file_rows(p_org,p_case));
end$$;


--
-- Name: uniion_case_link(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_link(p_org uuid, p_case uuid, p_link uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare l uniion_private.case_links;
begin
 perform public.uniion_case_files(p_org,p_case);
 select * into l from uniion_private.case_links where organization_id=p_org and resource_id=p_case and id=p_link and not withdrawn;
 if not found then raise insufficient_privilege;end if;
 if l.message_conversation is null then return public.uniion_case_link_before_messages(p_org,p_case,p_link);end if;
 if l.file='' or uniion_private.case_link_source(l) is null then raise insufficient_privilege;end if;
 return jsonb_build_object('conversation',l.message_conversation,'attachment',l.file);
end$$;


--
-- Name: uniion_case_link_before_messages(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_link_before_messages(p_org uuid, p_case uuid, p_link uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare l uniion_private.case_links;s jsonb;
begin
 perform public.uniion_case_files(p_org,p_case);
 select * into l from uniion_private.case_links where id=p_link and organization_id=p_org and resource_id=p_case;
 if not found or l.file='' or l.withdrawn then raise insufficient_privilege;end if;
 s=uniion_private.case_source(p_org,l.convocation,l.file);
 if s is null then raise insufficient_privilege;end if;
 return jsonb_build_object('convocation',l.convocation,'file',l.file);
end$$;


--
-- Name: uniion_case_trash(uuid, uuid, text, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_trash(p_org uuid, p_case uuid, p_action text, p_root uuid DEFAULT NULL::uuid, p_request uuid DEFAULT NULL::uuid, p_expected integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.message_files;t uniion_private.case_file_trash;ident uuid;
begin
 select * into f from uniion_private.message_files where resource=p_case and organization_id=p_org;
 if not found or p_action in ('admin_list','approve','reject') then return public.uniion_case_trash_before_messages(p_org,p_case,p_action,p_root,p_request,p_expected,p_reason);end if;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'request',t.id,'state',t.state,'deleted',t.decided_at)) from uniion_private.case_file_trash t join public.uniion_attachments a on a.id=t.root where t.resource_id=p_case and t.state in ('pending','approved')),'[]'));end if;
 perform 1 from public.uniion_resources where id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_action='request' then
  if p_root is distinct from f.attachment or p_expected is distinct from 1 or p_reason is null or p_reason not in ('obsolete','duplicate','other') then raise insufficient_privilege;end if;
  insert into uniion_private.case_file_trash(organization_id,resource_id,root,revision,reason,requester) values(p_org,p_case,p_root,1,p_reason,auth.uid()) returning id into ident;
 elsif p_action='restore' then
  select * into t from uniion_private.case_file_trash where id=p_request and resource_id=p_case and organization_id=p_org for update;
  if not found or t.state<>'approved' then raise insufficient_privilege;end if;
  update uniion_private.case_file_trash set state='restored',restored_by=auth.uid(),restored_at=now() where id=t.id;ident=t.id;
 else raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.file_trash_'||p_action,jsonb_build_object('request',ident));
 return jsonb_build_object('id',ident,'ok',true);
end$$;


--
-- Name: uniion_case_trash_before_messages(uuid, uuid, text, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_case_trash_before_messages(p_org uuid, p_case uuid, p_action text, p_root uuid DEFAULT NULL::uuid, p_request uuid DEFAULT NULL::uuid, p_expected integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.case_file_trash; current_revision integer; ident uuid; rows jsonb;
begin
 if p_action in ('admin_list','approve','reject') then
  if not uniion_private.super_admin() then raise insufficient_privilege;end if;
  if p_action='admin_list' then return jsonb_build_object('requests',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization',organization_id,'root',root,'revision',revision,'reason',reason,'requested',requested_at,'state',state) order by requested_at) from uniion_private.case_file_trash where state='pending'),'[]'));end if;
  select * into t from uniion_private.case_file_trash where id=p_request;
  if not found then raise insufficient_privilege;end if;
  perform 1 from public.uniion_resources where organization_id=t.organization_id and id=t.resource_id for update;
  select * into t from uniion_private.case_file_trash where id=p_request for update;
  if t.state<>'pending' then raise insufficient_privilege;end if;
  select coalesce(max(revision),1) into current_revision from uniion_private.case_file_versions where root=t.root;
  if p_action='approve' and not uniion_private.actor_resource(t.organization_id,t.resource_id,t.requester,true) then raise insufficient_privilege;end if;
  if p_action='approve' and current_revision<>t.revision then raise serialization_failure using message='Versions modifiées depuis la demande';end if;
  update uniion_private.case_file_trash set state=case when p_action='approve' then 'approved' else 'rejected' end,approver=auth.uid(),decided_at=now() where id=t.id;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(t.organization_id,auth.uid(),'case.trash_'||p_action,jsonb_build_object('request',t.id,'root',t.root,'revision',t.revision));
  return jsonb_build_object('ok',true);
 end if;
 perform public.uniion_case_files(p_org,p_case);
 if p_action='list' then
  select coalesce(jsonb_agg(f||jsonb_build_object('request',q.id,'deleted',q.decided_at,'state',q.state)),'[]') into rows from jsonb_array_elements(uniion_private.case_file_rows_all(p_org,p_case)) f join uniion_private.case_file_trash q on q.root=(f->>'id')::uuid where q.organization_id=p_org and q.resource_id=p_case and q.state in ('pending','approved');
  return jsonb_build_object('rows',rows);
 end if;
 perform 1 from public.uniion_resources where organization_id=p_org and id=p_case for update;
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
 if p_action='request' then
  if p_reason is null or p_reason not in ('obsolete','duplicate','other') or not exists(select 1 from public.uniion_attachments where id=p_root and organization_id=p_org and resource_id=p_case) or exists(select 1 from uniion_private.case_file_versions where attachment=p_root and root<>p_root) then raise insufficient_privilege;end if;
  select coalesce(max(revision),1) into current_revision from uniion_private.case_file_versions where root=p_root;
  if p_expected is distinct from current_revision then raise serialization_failure;end if;
  insert into uniion_private.case_file_trash(organization_id,resource_id,root,revision,reason,requester) values(p_org,p_case,p_root,current_revision,p_reason,auth.uid()) returning id into ident;
 elsif p_action='restore' then
  select * into t from uniion_private.case_file_trash where id=p_request and organization_id=p_org and resource_id=p_case for update;
  if not found or t.state<>'approved' then raise insufficient_privilege;end if;
  update uniion_private.case_file_trash set state='restored',restored_by=auth.uid(),restored_at=now() where id=t.id;ident=t.id;
 else raise insufficient_privilege;
 end if;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,p_case,auth.uid(),case when p_action='request' then 'Mise en corbeille demandée' else 'Pièce restaurée depuis la corbeille' end,'Demande '||ident);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.trash_'||p_action,jsonb_build_object('request',ident));
 return jsonb_build_object('id',ident,'ok',true);
end$$;


--
-- Name: uniion_cases(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_cases(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare rid uuid;r public.uniion_resources;v jsonb;t text;bodytext text;
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then
 return jsonb_build_object('rows',coalesce((select jsonb_agg(uniion_private.case_json(p_org,c.id) order by resource.created_at desc) from uniion_private.cases c join public.uniion_resources resource on resource.id=c.id where c.organization_id=p_org and uniion_private.actor_resource(p_org,c.id,auth.uid(),false)),'[]'));
 end if;
 if p_action='create' then
 if not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='dossiers' and permission='create') or p_payload-ARRAY['title','long','tag','due']<>'{}' then raise insufficient_privilege;end if;
 else
 rid=(p_payload->>'id')::uuid;
 select * into r from public.uniion_resources where organization_id=p_org and id=rid and module='dossiers' for update;
 if not found or not exists(select 1 from uniion_private.cases where id=rid and organization_id=p_org) or not uniion_private.actor_resource(p_org,rid,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
 if p_action='get' and p_payload-ARRAY['id']='{}' then return uniion_private.case_json(p_org,rid);end if;
 if (p_payload->>'version')::int is distinct from r.version then raise insufficient_privilege;end if;
 end if;
 if p_action in ('create','edit') then
 if p_action='edit' and p_payload-ARRAY['id','version','title','long','due']<>'{}' then raise insufficient_privilege;end if;
 if jsonb_typeof(p_payload->'title') is distinct from 'string' or length(btrim(p_payload->>'title')) not between 1 and 200 or jsonb_typeof(p_payload->'long') is distinct from 'string' or length(p_payload->>'long')>5000 or jsonb_typeof(p_payload->'due') is distinct from 'string' or length(p_payload->>'due')>80 then raise insufficient_privilege;end if;
 if p_action='create' then
 if p_payload->>'tag' is null or p_payload->>'tag' not in ('Juridique','Harcèlement','CSSCT','ASC / Noël','Négociation') then raise insufficient_privilege;end if;
 insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'dossiers',btrim(p_payload->>'title'),jsonb_build_object('text',p_payload->>'long')) returning id into rid;
 insert into uniion_private.cases(organization_id,id,tag,due,owner,description) values(p_org,rid,p_payload->>'tag',p_payload->>'due',auth.uid(),p_payload->>'long');
 insert into public.uniion_resource_grants values(p_org,rid,auth.uid(),true,false,'infinity',null);
 t='Dossier créé';bodytext='Création enregistrée.';
 else
 update public.uniion_resources set title=btrim(p_payload->>'title'),body=jsonb_build_object('text',p_payload->>'long'),version=version+1 where id=rid;
 update uniion_private.cases set description=p_payload->>'long',due=p_payload->>'due' where id=rid;
 t='Dossier modifié';bodytext='Intitulé, description ou échéance mis à jour.';
 end if;
 elsif p_action='status' then
 if p_payload-ARRAY['id','version','status']<>'{}' or p_payload->>'status' is null or p_payload->>'status' not in ('todo','doing','done') then raise insufficient_privilege;end if;
 update uniion_private.cases set status=p_payload->>'status' where id=rid;
 update public.uniion_resources set version=version+1 where id=rid;
 t='État modifié';bodytext=case p_payload->>'status' when 'todo' then 'À faire' when 'doing' then 'En cours' else 'Terminé' end;
 elsif p_action='note' then
 if p_payload-ARRAY['id','version','text']<>'{}' or jsonb_typeof(p_payload->'text') is distinct from 'string' or length(btrim(p_payload->>'text')) not between 1 and 5000 then raise insufficient_privilege;end if;
 update public.uniion_resources set version=version+1 where id=rid;t='Note ajoutée';bodytext=btrim(p_payload->>'text');
 else raise insufficient_privilege;
 end if;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,rid,auth.uid(),t,bodytext);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.'||p_action,jsonb_build_object('resource',rid));
 return uniion_private.case_json(p_org,rid);
end$$;


--
-- Name: uniion_collection_change(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_collection_change(p_org uuid, p_collection uuid, p_action text, p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare c uniion_private.collections;s uniion_private.collection_subscriptions;v uniion_private.collection_versions;n integer;k text;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or p_action is null or p_data is null or jsonb_typeof(p_data)<>'object' then raise insufficient_privilege;end if;
 select * into c from uniion_private.collections where id=p_collection for update;
 if not found or p_org not in(c.source,c.target) then raise insufficient_privilege;end if;
 for k in select jsonb_object_keys(p_data) loop
 if k<>all(case when p_action='collectionDraft' then array['color','text'] when p_action='collectionOverride' then array['text'] when p_action='collectionStop' then array[]::text[] else array['version','expected'] end) then raise insufficient_privilege;end if;end loop;
 if p_action in ('collectionDraft','collectionPublish') then
 if p_org<>c.source or not uniion_private.authority(p_org,auth.uid(),'collection_publish') then raise insufficient_privilege;end if;
 if p_action='collectionDraft' then
 if jsonb_typeof(p_data->'color') is distinct from 'string' or jsonb_typeof(p_data->'text') is distinct from 'string' then raise insufficient_privilege;end if;
 select coalesce(max(number),0)+1 into n from uniion_private.collection_versions where collection=c.id;
 insert into uniion_private.collection_versions(collection,number,color,text,author) values(c.id,n,p_data->>'color',p_data->>'text',auth.uid());
 else
 update uniion_private.collection_versions set published=true,reviewer=auth.uid() where collection=c.id and number=(p_data->>'version')::integer and not published and author<>auth.uid();if not found then raise insufficient_privilege;end if;
 end if;
 else
 if p_org<>c.target or not uniion_private.authority(p_org,auth.uid(),'organization_edit') or not uniion_private.authority(p_org,auth.uid(),'collection_accept') then raise insufficient_privilege;end if;
 select * into s from uniion_private.collection_subscriptions where collection=c.id;
 if p_action in ('collectionAdopt','collectionAccept','collectionDecline') then
 select * into v from uniion_private.collection_versions where collection=c.id and published and number=(p_data->>'version')::integer;
 if not found then raise insufficient_privilege;end if;
 end if;
 if p_action='collectionAdopt' then
 if s.collection is not null then raise insufficient_privilege;end if;
 insert into uniion_private.collection_subscriptions(collection,accepted,history) values(c.id,v.number,jsonb_build_array(jsonb_build_object('version',v.number,'actor',auth.uid(),'at',now())));
 else
 if s.collection is null or not s.active then raise insufficient_privilege;end if;
 if p_action in ('collectionAccept','collectionDecline') then
 if (p_data->>'expected')::integer is distinct from s.accepted or v.number<=s.accepted then raise insufficient_privilege;end if;
 if p_action='collectionAccept' then update uniion_private.collection_subscriptions set accepted=v.number,history=history||jsonb_build_array(jsonb_build_object('version',v.number,'actor',auth.uid(),'at',now())) where collection=c.id;
 else update uniion_private.collection_subscriptions set declined=declined||to_jsonb(v.number) where collection=c.id;end if;
 elsif p_action='collectionOverride' then
 if jsonb_typeof(p_data->'text') is distinct from 'string' then raise insufficient_privilege;end if;
 update uniion_private.collection_subscriptions set override_text=p_data->>'text' where collection=c.id;
 elsif p_action='collectionStop' then update uniion_private.collection_subscriptions set active=false where collection=c.id;
 else raise insufficient_privilege;end if;
 end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'collection.'||p_action,jsonb_build_object('collection',c.id,'version',p_data->'version'));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_collection_create(uuid, uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_collection_create(p_org uuid, p_target uuid, p_name text, p_color text, p_text text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare ident uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'collection_publish') then raise insufficient_privilege;end if;
 if p_target is null or p_target=p_org or not exists(select 1 from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.active and p.source_id=p_org and p.target_id=p_target and o.active) then raise insufficient_privilege;end if;
 if p_name is null or length(trim(p_name)) not between 1 and 160 or p_color is null or p_color!~'^#[0-9a-fA-F]{6}$' or p_text is null or length(trim(p_text)) not between 1 and 400 then raise insufficient_privilege;end if;
 insert into uniion_private.collections(source,target,name) values(p_org,p_target,trim(p_name)) returning id into ident;
 insert into uniion_private.collection_versions(collection,number,color,text,author) values(ident,1,p_color,trim(p_text),auth.uid());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'collection.created',jsonb_build_object('collection',ident,'target',p_target,'version',1));
 return jsonb_build_object('id',ident,'published',false);
end $_$;


--
-- Name: uniion_collections_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_collections_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object('activeOrg',p_org,'actor',auth.uid(),'permissions',jsonb_build_object('admin',uniion_private.authority(p_org,auth.uid(),'organization_edit'),'acceptCollection',uniion_private.authority(p_org,auth.uid(),'collection_accept'),'publishCollection',uniion_private.authority(p_org,auth.uid(),'collection_publish')),
 'targets',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name) order by o.name) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.active and p.source_id=p_org and o.active and uniion_private.authority(p_org,auth.uid(),'collection_publish')),'[]'),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_organizations o where o.id=p_org or exists(select 1 from uniion_private.collections c where p_org in(c.source,c.target) and o.id in(c.source,c.target) and (p_org=c.source or exists(select 1 from uniion_private.collection_versions cv where cv.collection=c.id and cv.published)))),'[]'),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from auth.users u join public.uniion_memberships m on m.user_id=u.id where m.organization_id=p_org and m.revoked_at is null and (u.id=auth.uid() or (uniion_private.authority(p_org,auth.uid(),'collection_publish') and exists(select 1 from uniion_private.collection_versions v join uniion_private.collections c on c.id=v.collection where c.source=p_org and v.author=u.id)))),'[]'),
 'collections',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'source',c.source,'target',c.target,'name',c.name,
 'versions',coalesce((select jsonb_agg(jsonb_build_object('number',v.number,'color',v.color,'text',v.text,'published',v.published,'author',case when p_org=c.source then v.author else null end) order by v.number) from uniion_private.collection_versions v where v.collection=c.id and ((p_org=c.source and uniion_private.authority(p_org,auth.uid(),'collection_publish')) or (v.published and (s.active is distinct from false or v.number<=s.accepted)))),'[]'),
 'subscription',case when p_org=c.target and s.collection is not null then jsonb_build_object('accepted',s.accepted,'active',s.active,'overrides',jsonb_build_object('text',s.override_text),'declined',s.declined,'history',s.history) else null end)) from uniion_private.collections c left join uniion_private.collection_subscriptions s on s.collection=c.id where p_org in(c.source,c.target) and ((p_org=c.source and uniion_private.authority(p_org,auth.uid(),'collection_publish')) or exists(select 1 from uniion_private.collection_versions v where v.collection=c.id and v.published))),'[]'));
end $$;


--
-- Name: uniion_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_context() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_organizations o where uniion_private.member(o.id)),'[]'::jsonb),
 'permissions',coalesce((select jsonb_agg(jsonb_build_object('org',p.organization_id,'module',p.module,'permission',p.permission)) from public.uniion_permissions p join public.uniion_module_access a on a.organization_id=p.organization_id and a.module=p.module where p.user_id=auth.uid() and uniion_private.member(p.organization_id) and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)),'[]'::jsonb))
$$;


--
-- Name: uniion_convocation_archive(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_convocation_archive(p_org uuid, p_convocation uuid, p_action text, p_files jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare a uniion_private.convocation_archives; f jsonb; expected text;
begin
 if not uniion_private.is_scanner() then raise insufficient_privilege;end if;
 if not exists(select 1 from uniion_private.agenda_convocations c join uniion_private.agenda_events e on e.id=c.event_id where c.id=p_convocation and e.organization_id=p_org and c.message ? 'attachment_version') then raise insufficient_privilege;end if;
 if p_action='reserve' then
  if jsonb_typeof(p_files) is distinct from 'array' or jsonb_array_length(p_files)<>2 then raise insufficient_privilege;end if;
  if not exists(select 1 from uniion_private.agenda_convocation_deliveries where convocation=p_convocation and status='sending') then raise insufficient_privilege;end if;
  for f in select value from jsonb_array_elements(p_files) loop
   expected=case f->>'id' when 'pdf' then 'application/pdf' when 'ics' then 'text/calendar' end;
   if expected is null or f->>'mime' is distinct from expected or f->>'sha256' !~ '^[a-f0-9]{64}$' or (f->>'size')::int not between 1 and 5242880 or f->>'path' is distinct from p_org::text||'/'||p_convocation::text||'/'||(f->>'object')::uuid::text then raise insufficient_privilege;end if;
  end loop;
  if (select count(distinct value->>'id') from jsonb_array_elements(p_files))<>2 or (select count(distinct value->>'object') from jsonb_array_elements(p_files))<>2 then raise insufficient_privilege;end if;
  insert into uniion_private.convocation_archives(convocation,organization_id,files) values(p_convocation,p_org,p_files) on conflict do nothing;
 end if;
 select * into a from uniion_private.convocation_archives where convocation=p_convocation and organization_id=p_org for update;
 if not found or (p_action='reserve' and a.files is distinct from p_files) then raise insufficient_privilege;end if;
 if p_action='finish' then
  if exists(select 1 from jsonb_array_elements(a.files) item where not exists(select 1 from storage.objects o where o.bucket_id='uniion-private' and o.name=item->>'path')) then raise insufficient_privilege;end if;
  update uniion_private.convocation_archives set ready=true where convocation=p_convocation;
 elsif p_action not in ('reserve','read') then raise insufficient_privilege;end if;
 return a.files;
end $_$;


--
-- Name: uniion_convocation_files(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_convocation_files(p_org uuid, p_convocation uuid, p_file text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare c uniion_private.agenda_convocations;e uniion_private.agenda_events;p uniion_private.agenda_publications;items jsonb='[]';a public.uniion_attachments;ref jsonb; archived jsonb;
begin
if not exists(select 1 from jsonb_array_elements(public.uniion_convocation_history(p_org)) h where h->>'id'=p_convocation::text) then raise insufficient_privilege;end if;
perform public.uniion_module_use(p_org,'documents');
if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
select * into c from uniion_private.agenda_convocations where id=p_convocation;
select * into e from uniion_private.agenda_events where id=c.event_id;
if not(c.message ? 'attachment_version') then return '[]'::jsonb;end if;
select * into p from uniion_private.agenda_publications where event_id=c.event_id and version=(c.message->>'attachment_version')::integer and published_at is not null;
if not found then raise insufficient_privilege;end if;
perform uniion_private.agenda_file_check(p_org,coalesce(p.document->'convocation_files','[]'),auth.uid());
select files into archived from uniion_private.convocation_archives ar where ar.convocation=c.id and ar.organization_id=p_org and ar.ready and exists(select 1 from uniion_private.agenda_convocation_deliveries where convocation=c.id and status='sent');
if archived is not null then
 items=jsonb_build_array(jsonb_build_object('id','pdf','name','ordre-du-jour.pdf'),jsonb_build_object('id','ics','name','evenement.ics'));
end if;
for ref in select value from jsonb_array_elements(coalesce(p.document->'convocation_files','[]')) loop
 select * into a from public.uniion_attachments where id=(ref->>'id')::uuid;
 items=items||jsonb_build_array(jsonb_build_object('id',a.id,'name',a.filename));
end loop;
if p_file is null then return items;end if;
if not exists(select 1 from jsonb_array_elements(items) i where i->>'id'=p_file) then raise insufficient_privilege;end if;
if p_file in ('pdf','ics') then return jsonb_build_object('archive',(select value from jsonb_array_elements(archived) where value->>'id'=p_file));end if;
return jsonb_build_object('document',p.document,'version',p.version,'event',e.data||jsonb_build_object('id',e.id,'version',e.version));
end $$;


--
-- Name: uniion_convocation_history(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_convocation_history(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'event',c.event_id,'subject',c.message->>'subject','body',c.message->>'body','created',c.created_at,'mine',c.actor=auth.uid(),'sent',(select count(*) from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.status='sent'),'uncertain',(select count(*) from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.status in ('sending','uncertain'))) order by c.created_at desc,c.id) from uniion_private.agenda_convocations c join uniion_private.agenda_events e on e.id=c.event_id join public.uniion_memberships m on m.organization_id=e.organization_id and m.user_id=auth.uid() where e.organization_id=p_org and c.created_at>=m.joined_at and uniion_private.agenda_visible(p_org,e.data) and (c.actor=auth.uid() or exists(select 1 from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.user_id=auth.uid() and d.status='sent'))),'[]'::jsonb);
end $$;


--
-- Name: uniion_directory_authorize(uuid, uuid, uuid, uuid[], timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_directory_authorize(p_org uuid, p_target uuid, p_grantee uuid, p_people uuid[], p_until timestamp with time zone, p_enabled boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare person uuid;
BEGIN
 -- uniion_privileged_mfa_gate
 IF NOT uniion_private.session_allowed() OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN RAISE insufficient_privilege; END IF;
 if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.authority(p_org,auth.uid(),'share')
 or not uniion_private.actor_member(p_target,p_grantee)
 or not exists(select 1 from public.uniion_partners where active and source_id=p_target and target_id=p_org)
 or coalesce(cardinality(p_people),0) not between 1 and 20 or p_enabled is null then raise insufficient_privilege;end if;
 foreach person in array p_people loop
  if not uniion_private.actor_member(p_org,person) then raise insufficient_privilege;end if;
  if p_enabled then
   if p_until is null or p_until<=now() or p_until>now()+interval '90 days' then raise insufficient_privilege;end if;
   insert into public.uniion_directory_grants values(p_org,p_target,p_grantee,person,auth.uid(),p_until,null)
    on conflict(organization_id,target_id,grantee,listed_user) do update set approved_by=auth.uid(),valid_until=excluded.valid_until,revoked_at=null;
  else
   update public.uniion_directory_grants set revoked_at=now() where organization_id=p_org and target_id=p_target and grantee=p_grantee and listed_user=person;
  end if;
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details)
 values(p_org,p_target,auth.uid(),'directory.consent',jsonb_build_object('grantee',p_grantee,'people',p_people,'enabled',p_enabled,'until',p_until));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_directory_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_directory_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 return jsonb_build_object('grants',coalesce((select jsonb_agg(jsonb_build_object('target',g.target_id,'target_name',o.name,'grantee',g.grantee,'person',g.listed_user,'name',u.email,'until',g.valid_until,'revoked',g.revoked_at)) from public.uniion_directory_grants g join public.uniion_organizations o on o.id=g.target_id join auth.users u on u.id=g.listed_user where g.organization_id=p_org),'[]'::jsonb),
 'targets',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_partners p join public.uniion_organizations o on o.id=p.source_id where p.active and p.target_id=p_org and o.active),'[]'::jsonb));
end $$;


--
-- Name: uniion_document_archive_store(uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_archive_store(p_org uuid, p_id uuid, p_version integer, p_pdf text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$declare b bytea;begin
 if not uniion_private.is_scanner() or p_pdf is null or length(p_pdf)>28000000 then raise insufficient_privilege;end if;b=decode(p_pdf,'base64');if substring(b from 1 for 5)<>convert_to('%PDF-','UTF8') then raise insufficient_privilege;end if;
 insert into uniion_private.document_archives values(p_org,p_id,p_version,b,encode(extensions.digest(b,'sha256'),'hex')) on conflict do nothing;return jsonb_build_object('ok',true);end$$;


--
-- Name: uniion_document_defaults(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_defaults(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare current_logo text;v integer;manage boolean;
begin
 perform public.uniion_module_use(p_org,'documents');
 manage=uniion_private.authority(p_org,auth.uid(),'organization_edit');
 if p_action='save' then
  if not manage or jsonb_typeof(p_payload) is distinct from 'object' or p_payload-array['logo','version']<>'{}' or jsonb_typeof(p_payload->'logo') is distinct from 'string' then raise insufficient_privilege;end if;
  perform 1 from public.uniion_organizations where id=p_org for update;
 elsif p_action<>'get' or p_payload<>'{}' then raise insufficient_privilege;
 end if;
 select logo,version into current_logo,v from uniion_private.document_defaults where organization_id=p_org;
 current_logo=coalesce(current_logo,'uniion-logo.png');v=coalesce(v,0);
 if p_action='save' then
  if (p_payload->>'version')::integer is distinct from v then raise insufficient_privilege;end if;
  current_logo=p_payload->>'logo';
  if current_logo not in ('','uniion-logo.png') and not exists(select 1 from uniion_private.document_default_receipts where organization_id=p_org and digest=encode(extensions.digest(current_logo,'sha256'),'hex')) then raise insufficient_privilege;end if;
  v=v+1;
  insert into uniion_private.document_defaults values(p_org,current_logo,v,now()) on conflict(organization_id) do update set logo=excluded.logo,version=excluded.version,updated_at=excluded.updated_at;
  insert into uniion_private.document_default_versions values(p_org,v,current_logo,auth.uid(),now());
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.defaults',jsonb_build_object('version',v));
 end if;
 return jsonb_build_object('logo',current_logo,'version',v,'canWrite',manage);
end$$;


--
-- Name: uniion_document_defaults_image_receipt(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_defaults_image_receipt(p_document uuid, p_image text, p_engine text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
begin
 if not uniion_private.is_scanner() or p_engine is null or length(p_engine) not between 1 and 250 or p_image is null or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg|svg\+xml);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.document_default_receipts values(p_document,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine,now()) on conflict do nothing;
 return '{"ok":true}'::jsonb;
end$_$;


--
-- Name: uniion_document_disposal(uuid, text, uuid, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_disposal(p_org uuid, p_action text, p_case uuid DEFAULT NULL::uuid, p_link uuid DEFAULT NULL::uuid, p_request uuid DEFAULT NULL::uuid, p_expected integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.case_disposals; v integer; ident uuid;
begin
 if p_link is not null then raise insufficient_privilege;end if;
 if p_action in ('admin_list','approve','reject') then
  if not uniion_private.super_admin() then raise insufficient_privilege;end if;
  if p_action='admin_list' then return jsonb_build_object('requests',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization',organization_id,'root',resource_id,'kind',case when link is null then 'Dossier' else 'Référence' end,'revision',version,'reason',reason,'state',state)) from uniion_private.case_disposals where state='pending'),'[]'));end if;
  select * into t from uniion_private.case_disposals where id=p_request;
  if not found then raise insufficient_privilege;end if;
  select version into v from public.uniion_resources where id=t.resource_id and organization_id=t.organization_id for update;
  select * into t from uniion_private.case_disposals where id=p_request for update;
  if t.state<>'pending' then raise insufficient_privilege;end if;
  if p_action='approve' then
   if not uniion_private.actor_resource(t.organization_id,t.resource_id,t.requester,true) then raise insufficient_privilege;end if;
   if v<>t.version then raise serialization_failure;end if;
   update uniion_private.case_links set withdrawn=true where id=t.link;
   update public.uniion_resources set version=version+1,body=body where id=t.resource_id;
  end if;
  update uniion_private.case_disposals set state=case when p_action='approve' then 'approved' else 'rejected' end,decider=auth.uid(),decided_at=now() where id=t.id;ident=t.id;
 else
  perform public.uniion_module_use(p_org,'documents');
  if p_action='list' then return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('request',entry.id,'filename',case when entry.link is null then 'Document · ' else 'Référence · ' end||r.title,'state',entry.state,'deleted',entry.decided_at,'case',entry.resource_id)) from uniion_private.case_disposals entry join public.uniion_resources r on r.id=entry.resource_id where r.module='documents' and entry.organization_id=p_org and (p_case is null or entry.resource_id=p_case) and entry.state in ('pending','approved') and uniion_private.actor_resource_before_disposal(p_org,entry.resource_id,auth.uid(),false)),'[]'));end if;
  select version into v from public.uniion_resources where id=p_case and organization_id=p_org and module='documents' for update;
  if not found or not uniion_private.actor_resource_before_disposal(p_org,p_case,auth.uid(),true) then raise insufficient_privilege;end if;
  if p_action='request' then
   if uniion_private.case_disposed(p_case) or p_reason is null or p_reason not in ('obsolete','duplicate','other') then raise insufficient_privilege;end if;
   if p_link is not null and not exists(select 1 from uniion_private.case_links where id=p_link and resource_id=p_case and organization_id=p_org and not withdrawn) then raise insufficient_privilege;end if;
   if p_expected is distinct from v then raise serialization_failure;end if;
   insert into uniion_private.case_disposals(organization_id,resource_id,link,version,reason,requester) values(p_org,p_case,p_link,v,p_reason,auth.uid()) returning * into t;ident=t.id;
  elsif p_action='restore' then
   select * into t from uniion_private.case_disposals where id=p_request and organization_id=p_org and resource_id=p_case for update;
   if not found or t.state<>'approved' or (t.link is not null and uniion_private.case_disposed(p_case)) then raise insufficient_privilege;end if;
   update uniion_private.case_disposals set state='restored',decider=auth.uid(),decided_at=now() where id=t.id;
   update uniion_private.case_links set withdrawn=false where id=t.link;
   update public.uniion_resources set version=version+1,body=body where id=p_case;ident=t.id;
  else raise insufficient_privilege;end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(t.organization_id,auth.uid(),'case.disposal_'||p_action,jsonb_build_object('request',ident,'case',t.resource_id,'link',t.link));
 return jsonb_build_object('ok',true,'id',ident);
end$$;


--
-- Name: uniion_document_export(uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_export(p_org uuid, p_id uuid, p_version integer, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r public.uniion_resources;
begin
 perform public.uniion_module_use(p_org,'documents');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_id and module='documents' for share;
 if not found or not exists(select 1 from uniion_private.documents where organization_id=p_org and id=p_id) or not uniion_private.actor_resource(p_org,p_id,auth.uid(),false) or not uniion_private.authority(p_org,auth.uid(),'download') or p_version is distinct from r.version or p_action is null or p_action not in ('prepare','complete') then raise insufficient_privilege;end if;
 if p_action='complete' then
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.export.authorized',jsonb_build_object('resource',p_id,'version',p_version,'format','pdf'));
  return jsonb_build_object('version',r.version);
 end if;
 return jsonb_build_object('version',r.version,'document',uniion_private.document_json(p_org,p_id));
end$$;


--
-- Name: uniion_document_history(uuid, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_history(p_org uuid, p_id uuid, p_version integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$declare stored uniion_private.document_archives;begin
 perform public.uniion_module_use(p_org,'documents');if not uniion_private.actor_resource(p_org,p_id,auth.uid(),false) then raise insufficient_privilege;end if;
 if p_version is not null then
  if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
  select ar.* into stored from uniion_private.document_archives ar join uniion_private.document_publications p using(organization_id,resource_id,version) where ar.organization_id=p_org and ar.resource_id=p_id and ar.version=p_version and p.published_at is not null;
  if not found then raise insufficient_privilege;end if;
  return jsonb_build_object('base64',encode(stored.pdf,'base64'),'mime','application/pdf','filename','document-'||p_id||'-v'||p_version||'.pdf','sha256',stored.digest);
 end if;
 return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('version',p.version,'published',p.published_at,'archived',a.digest is not null) order by p.version desc) from uniion_private.document_publications p left join uniion_private.document_archives a using(organization_id,resource_id,version) where p.organization_id=p_org and p.resource_id=p_id and p.published_at is not null),'[]'));
end$$;


--
-- Name: uniion_document_image_receipt(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_image_receipt(p_document uuid, p_image text, p_engine text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
begin
 if not uniion_private.is_scanner() or p_image is null or p_engine is null or length(p_engine) not between 1 and 250 or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg|svg\+xml);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.document_image_receipts(document_id,digest,engine) values(p_document,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine) on conflict do nothing;
 return jsonb_build_object('ok',true);
end;$_$;


--
-- Name: uniion_document_job(uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_job(p_org uuid, p_id uuid, p_version integer, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$declare j uniion_private.document_export_jobs;begin
 perform public.uniion_document_export(p_org,p_id,p_version,'prepare');
 if p_action not in ('start','status','claim') or p_action is null then raise insufficient_privilege;end if;
 if p_action='start' then insert into uniion_private.document_export_jobs(organization_id,resource_id,version,requester) values(p_org,p_id,p_version,auth.uid()) on conflict do nothing;end if;
 select * into j from uniion_private.document_export_jobs where organization_id=p_org and resource_id=p_id and version=p_version and requester=auth.uid() for update;
 if not found then raise insufficient_privilege;end if;
 if p_action='claim' and (j.state in ('pending','error') or (j.state='running' and j.updated_at<now()-interval '5 minutes')) then
 update uniion_private.document_export_jobs set state='running',lease=gen_random_uuid(),updated_at=now(),error=null where id=j.id returning * into j;
 return jsonb_build_object('id',j.id,'state',j.state,'lease',j.lease);
 end if;
 return jsonb_build_object('id',j.id,'state',j.state,'result',case when p_action='status' and j.state='done' then j.result else null end,'error',j.error);
end$$;


--
-- Name: uniion_document_job_finish(uuid, uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_job_finish(p_job uuid, p_lease uuid, p_result jsonb, p_error text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 if not uniion_private.is_scanner() or (p_result is not null and octet_length(p_result::text)>29000000) or (p_error is not null and p_error not in ('pdf_overflow','unavailable','pdf_content_missing')) then raise insufficient_privilege;end if;
 update uniion_private.document_export_jobs set state=case when p_result is null then 'error' else 'done' end,result=p_result,error=p_error,updated_at=now() where id=p_job and lease=p_lease and state='running';
 return jsonb_build_object('ok',found);end$$;


--
-- Name: uniion_document_notices(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_notices(p_org uuid, p_read uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 perform public.uniion_module_use(p_org,'documents');
 if p_read is not null then update uniion_private.document_notices set read_at=coalesce(read_at,now()) where organization_id=p_org and user_id=auth.uid() and (id=p_read or p_read='00000000-0000-0000-0000-000000000000') and uniion_private.actor_resource(p_org,resource_id,auth.uid(),false);end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'resource',n.resource_id,'version',n.version,'title',v.body->>'title','read',n.read_at is not null,'created',n.created_at) order by n.created_at desc) from uniion_private.document_notices n join public.uniion_resource_versions v using(organization_id,resource_id,version) where n.organization_id=p_org and n.user_id=auth.uid() and uniion_private.actor_resource(p_org,n.resource_id,auth.uid(),false)),'[]');end$$;


--
-- Name: uniion_document_publication(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_publication(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$declare r public.uniion_resources;result jsonb;begin
 perform public.uniion_module_use(p_org,'documents');
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module='documents' for update;
 if not found or not exists(select 1 from uniion_private.documents where id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or r.version is distinct from (p_payload->>'version')::integer then raise insufficient_privilege;end if;
 if p_action='correction' then
  if p_payload-array['id','version','reason']<>'{}' or not uniion_private.authority(p_org,auth.uid(),'document_review') or exists(select 1 from public.uniion_resource_versions where resource_id=r.id and (actor=auth.uid() or actor is null)) or exists(select 1 from uniion_private.document_publications where resource_id=r.id and version=r.version and published_at is not null) or jsonb_typeof(p_payload->'reason') is distinct from 'string' then raise insufficient_privilege;end if;
  insert into uniion_private.document_corrections(organization_id,resource_id,version,actor,reason) values(p_org,r.id,r.version,auth.uid(),p_payload->>'reason');
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.correction',jsonb_build_object('resource',r.id,'version',r.version));
  return jsonb_build_object('id',r.id,'version',r.version,'reviewed',false,'published',false,'correction',p_payload->>'reason');
 end if;
 if p_action in ('review','publish') and exists(select 1 from uniion_private.document_corrections where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
 if p_action='prepare' then
  result=public.uniion_document_publication_base(p_org,'status',p_payload);
  if not uniion_private.authority(p_org,auth.uid(),'document_publish') or not (result->>'reviewed')::boolean or exists(select 1 from uniion_private.document_corrections where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
  return jsonb_build_object('version',r.version,'document',uniion_private.document_json(p_org,r.id));
 end if;
 if p_action='publish' and not exists(select 1 from uniion_private.document_archives where resource_id=r.id and version=r.version) then raise insufficient_privilege;end if;
 result=public.uniion_document_publication_base(p_org,p_action,p_payload);
 if p_action='publish' then
  insert into uniion_private.document_notices(organization_id,resource_id,version,user_id) select p_org,r.id,r.version,m.user_id from public.uniion_memberships m where m.organization_id=p_org and uniion_private.actor_resource(p_org,r.id,m.user_id,false) on conflict do nothing;
 end if;
 return result||jsonb_build_object('correction',(select reason from uniion_private.document_corrections where resource_id=r.id and version=r.version order by created_at desc limit 1));
end$$;


--
-- Name: uniion_document_publication_base(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_document_publication_base(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r public.uniion_resources;p uniion_private.document_publications;changed boolean:=false;
begin
 perform public.uniion_module_use(p_org,'documents');
 if jsonb_typeof(p_payload) is distinct from 'object' or not(p_payload ?& array['id','version']) or p_payload-array['id','version']<>'{}' or p_action is null or p_action not in ('status','review','publish') then raise insufficient_privilege;end if;
 select * into r from public.uniion_resources where organization_id=p_org and id=(p_payload->>'id')::uuid and module='documents' for update;
 if not found or not exists(select 1 from uniion_private.documents where organization_id=p_org and id=r.id) or not uniion_private.actor_resource(p_org,r.id,auth.uid(),false) or r.version is distinct from (p_payload->>'version')::integer then raise insufficient_privilege;end if;
 select * into p from uniion_private.document_publications where organization_id=p_org and resource_id=r.id and version=r.version;
 if p_action='review' then
  if not uniion_private.authority(p_org,auth.uid(),'document_review') or exists(select 1 from public.uniion_resource_versions where organization_id=p_org and resource_id=r.id and version<=r.version and (actor=auth.uid() or actor is null)) then raise insufficient_privilege;end if;
  if p.published_at is null then
   insert into uniion_private.document_publications(organization_id,resource_id,version,reviewer) values(p_org,r.id,r.version,auth.uid()) on conflict(organization_id,resource_id,version) do update set reviewer=excluded.reviewer,reviewed_at=now() where document_publications.reviewer<>excluded.reviewer;
   changed=found;
  end if;
 elsif p_action='publish' then
  if not uniion_private.authority(p_org,auth.uid(),'document_publish') or p.reviewer is null or not uniion_private.actor_resource(p_org,r.id,p.reviewer,false) or not uniion_private.authority(p_org,p.reviewer,'document_review') then raise insufficient_privilege;end if;
  update uniion_private.document_publications set publisher=auth.uid(),published_at=now() where organization_id=p_org and resource_id=r.id and version=r.version and published_at is null;
  changed=found;
 end if;
 if changed then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.'||p_action,jsonb_build_object('resource',r.id,'version',r.version));end if;
 select * into p from uniion_private.document_publications where organization_id=p_org and resource_id=r.id and version=r.version;
 return jsonb_build_object('id',r.id,'version',r.version,'reviewed',p.reviewer is not null,'published',p.published_at is not null);
end$$;


--
-- Name: uniion_documents(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_documents(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare rid uuid;r public.uniion_resources;doc jsonb;item jsonb;
begin
 perform public.uniion_module_use(p_org,'documents');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then return jsonb_build_object('defaults',public.uniion_document_defaults(p_org,'get','{}'),'rows',coalesce((select jsonb_agg(uniion_private.document_json(p_org,d.id) order by d.updated_at desc) from uniion_private.documents d where d.organization_id=p_org and uniion_private.actor_resource(p_org,d.id,auth.uid(),false)),'[]'));end if;
 if p_action='create' then
  if p_payload-array['model','document']<>'{}' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') then raise insufficient_privilege;end if;
  if jsonb_typeof(p_payload->'model') is distinct from 'string' or length(p_payload->>'model') not between 1 and 60 then raise insufficient_privilege;end if;
 else
  rid=(p_payload->>'id')::uuid;
  select * into r from public.uniion_resources where id=rid and organization_id=p_org and module='documents' for update;
  if not found or not exists(select 1 from uniion_private.documents where id=rid and organization_id=p_org) or not uniion_private.actor_resource(p_org,rid,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
  if p_action='get' and p_payload-array['id']='{}' then return uniion_private.document_json(p_org,rid);end if;
  if p_action<>'save' or p_payload-array['id','version','document']<>'{}' or (p_payload->>'version')::integer is distinct from r.version then raise insufficient_privilege;end if;
 end if;
 doc=p_payload->'document';
 if p_action='create' then
  item=public.uniion_document_defaults(p_org,'get','{}');
  doc=jsonb_set(doc,'{charte}',coalesce(doc->'charte','{"accent":"#DC2626","ink":"#111827","titleFont":"philosopher","bodyFont":"inter","density":"standard","header":true,"footer":true,"caps":false,"emetteur":"","section":"","email":"","phone":"","emetteurOverride":true}'::jsonb)||jsonb_build_object('logo',item->>'logo'));
 end if;
 if jsonb_typeof(doc) is distinct from 'object' or not(doc ?& array['title','format','blocks']) or doc-array['title','format','blocks','charte','style','styleOpts']<>'{}' or jsonb_typeof(doc->'title') is distinct from 'string' or length(btrim(doc->>'title')) not between 1 and 200 or doc->>'format' is null or doc->>'format' not in ('a4','a5','square','story','wide') or jsonb_typeof(doc->'blocks') is distinct from 'array' or jsonb_array_length(doc->'blocks') not between 0 and 100 or octet_length(doc::text)>7000000 then raise insufficient_privilege;end if;
 if doc ? 'style' and doc->'style'<>'null'::jsonb and (jsonb_typeof(doc->'style')<>'string' or doc->>'style' not in ('choc','journal','infographie','institutionnel','photo','serigraphie','bulletin','qr','satirique','bd','annonce','retro')) then raise insufficient_privilege;end if;
 if doc ? 'styleOpts' then
  if jsonb_typeof(doc->'styleOpts') is distinct from 'object' or (doc->'styleOpts')-array['palette','font']<>'{}'::jsonb then raise insufficient_privilege;end if;
  for item in select value from jsonb_each(doc->'styleOpts') loop
   if jsonb_typeof(item) is distinct from 'number' or (item#>>'{}') !~ '^[0-9]+$' then raise insufficient_privilege;end if;
  end loop;
  if coalesce((doc->'styleOpts'->>'palette')::int,0)>=(case doc->>'style' when 'choc' then 4 when 'journal' then 4 when 'infographie' then 4 when 'institutionnel' then 4 when 'photo' then 3 when 'serigraphie' then 4 when 'bulletin' then 4 when 'qr' then 4 when 'satirique' then 3 when 'bd' then 3 when 'annonce' then 2 when 'retro' then 3 else 1 end) or coalesce((doc->'styleOpts'->>'font')::int,0)>=(case doc->>'style' when 'choc' then 3 when 'journal' then 3 when 'infographie' then 3 when 'institutionnel' then 3 when 'photo' then 3 when 'serigraphie' then 3 when 'bulletin' then 3 when 'qr' then 3 when 'satirique' then 2 when 'bd' then 2 when 'annonce' then 2 when 'retro' then 2 else 1 end) then raise insufficient_privilege;end if;
 end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop
  if item ? 'img' and not uniion_private.document_image_allowed(rid,item->>'img') then raise insufficient_privilege;end if;
  if item->>'type'='studio.photo' and item->>'text' ~* '^\s*(https?:|data:|//)' then raise insufficient_privilege;end if;

  if jsonb_typeof(item) is distinct from 'object' or item-array['id','type','text','img']<>'{}' or jsonb_typeof(item->'id') is distinct from 'string' or length(item->>'id') not between 1 and 100 or item->>'type' is null or item->>'type' not in ('tag','h1','h2','h3','p','ul','quote','table','pagebreak','studio.chiffre','studio.compare','studio.frise','studio.photo','studio.qr','studio.coupon','studio.trombi','studio.tampon','studio.surligne','studio.signature','studio.bulles','studio.exige') or jsonb_typeof(item->'text') is distinct from 'string' or length(item->>'text')>20000 then raise insufficient_privilege;end if;
 end loop;
 if doc ? 'charte' then
  item=doc->'charte';
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']) or item-array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']<>'{}' then raise insufficient_privilege;end if;
  if item->>'accent' !~ '^#[0-9a-fA-F]{6}$' or item->>'ink' !~ '^#[0-9a-fA-F]{6}$' or item->>'titleFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'bodyFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'density' not in ('standard','compact','confort') or (p_action<>'create' and not uniion_private.document_image_allowed(rid,item->>'logo')) then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_each(item) x where (x.key in ('header','footer','caps','emetteurOverride') and jsonb_typeof(x.value) is distinct from 'boolean') or (x.key not in ('header','footer','caps','emetteurOverride') and (jsonb_typeof(x.value) is distinct from 'string' or length(x.value#>>'{}')>case when x.key='logo' then 2800000 else 300 end))) then raise insufficient_privilege;end if;
 end if;
 if p_action='create' then
  insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'documents',doc->>'title',doc) returning id into rid;
  insert into uniion_private.documents(organization_id,id,model) values(p_org,rid,p_payload->>'model');
 insert into uniion_private.document_image_receipts(document_id,digest,engine,scanned_at) select rid,digest,engine,scanned_at from uniion_private.document_default_receipts where organization_id=p_org and digest=encode(extensions.digest(doc->'charte'->>'logo','sha256'),'hex') on conflict do nothing;
  insert into public.uniion_resource_grants values(p_org,rid,auth.uid(),true,false,'infinity',null);
 else
  update public.uniion_resources set title=doc->>'title',body=doc,version=version+1 where id=rid;
  update uniion_private.documents set updated_at=now() where id=rid;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'document.'||p_action,jsonb_build_object('resource',rid));
 return uniion_private.document_json(p_org,rid);
end$_$;


--
-- Name: uniion_dues_evidence(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_dues_evidence(p_org uuid, p_payment uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.dues_evidence;aid uuid;can_download boolean;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'cotisations','read') or not exists(select 1 from uniion_private.dues_payments where organization_id=p_org and id=p_payment) or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 can_download=uniion_private.authority(p_org,auth.uid(),'download');
 if p_action='prepare' then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ?& array['filename','mime','size','sha256','request_id']) or p_payload-array['filename','mime','size','sha256','request_id']<>'{}' then raise insufficient_privilege;end if;
  perform 1 from uniion_private.dues_payments where id=p_payment for update;
  select * into f from uniion_private.dues_evidence where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if f.payment_id<>p_payment or f.filename is distinct from p_payload->>'filename' or f.mime is distinct from p_payload->>'mime' or f.size is distinct from (p_payload->>'size')::int or f.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
  else
   if (select count(*) from uniion_private.dues_evidence where payment_id=p_payment)>=20 then raise insufficient_privilege;end if;
   aid=gen_random_uuid();
   insert into uniion_private.dues_evidence(id,organization_id,payment_id,filename,mime,size,sha256,path,actor,request_id) values(aid,p_org,p_payment,p_payload->>'filename',p_payload->>'mime',(p_payload->>'size')::int,p_payload->>'sha256',p_org::text||'/'||p_payment::text||'/'||aid::text,auth.uid(),(p_payload->>'request_id')::uuid) returning * into f;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.evidence.requested',jsonb_build_object('payment',p_payment,'file',f.id));
  end if;
  return to_jsonb(f);
 elsif p_action='resume' then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
  select * into f from uniion_private.dues_evidence where id=(p_payload->>'id')::uuid and payment_id=p_payment and organization_id=p_org and status in ('pending','clean');
  if not found then raise insufficient_privilege;end if;
  if f.status='pending' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.evidence.resume_requested',jsonb_build_object('file',f.id));end if;
  return to_jsonb(f);
 elsif p_action in ('get','preview') then
  if (p_action='get' and not can_download) or p_payload-array['id','audit']<>'{}' then raise insufficient_privilege;end if;
  select * into f from uniion_private.dues_evidence where id=(p_payload->>'id')::uuid and payment_id=p_payment and organization_id=p_org and status='clean';
  if not found then raise insufficient_privilege;end if;
  if p_payload->>'audit'='true' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='preview' then 'dues.evidence.previewed' else 'dues.evidence.downloaded' end,jsonb_build_object('payment',p_payment,'file',f.id));end if;
  return to_jsonb(f);
 elsif p_action<>'list' or p_payload<>'{}' then raise insufficient_privilege;end if;
 return jsonb_build_object('write',uniion_private.adherent_permission(p_org,'cotisations','write'),'download',can_download,'files',coalesce((select jsonb_agg(jsonb_build_object('id',id,'filename',filename,'mime',mime,'status',status,'createdAt',created_at,'size',size) order by created_at,id) from uniion_private.dues_evidence where organization_id=p_org and payment_id=p_payment),'[]'));
exception when invalid_text_representation or check_violation or numeric_value_out_of_range then raise insufficient_privilege;
end $$;


--
-- Name: uniion_dues_evidence_finish(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_dues_evidence_finish(p_id uuid, p_sha text, p_status text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.dues_evidence;
begin
 if not uniion_private.is_scanner() or p_status not in ('clean','blocked') or p_status is null then raise insufficient_privilege;end if;
 select * into f from uniion_private.dues_evidence where id=p_id for update;
 if not found or f.sha256 is distinct from p_sha or (p_status='clean' and not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=f.path and (metadata->>'size')::bigint=f.size)) then raise insufficient_privilege;end if;
 if f.status='blocked' then raise insufficient_privilege;end if;
 if f.status='clean' and p_status='clean' then return;end if;
 update uniion_private.dues_evidence set status=p_status where id=p_id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'dues.evidence.scanned',jsonb_build_object('file',f.id,'status',p_status));
end $$;


--
-- Name: uniion_dues_export(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_dues_export(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare data jsonb;item jsonb;r uniion_private.dues_receipts;pid uuid;mid uuid;rev integer;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'adherents','read') or not uniion_private.adherent_permission(p_org,'cotisations','read') or not uniion_private.authority(p_org,auth.uid(),'download') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action in ('csv','csv_finish') then
  if not(p_payload ? 'member') or p_payload-array['member','hash']<>'{}' then raise insufficient_privilege;end if;
  data=uniion_private.dues_export_snapshot(p_org,(p_payload->>'member')::uuid);
  if data is null then raise insufficient_privilege;end if;
  if p_action='csv_finish' then
   if p_payload->>'hash' is distinct from md5(data::text) then raise insufficient_privilege;end if;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.csv.exported',jsonb_build_object('member',p_payload->>'member','hash',md5(data::text),'count',jsonb_array_length(data->'payments')));
  end if;
  return jsonb_build_object('data',data,'hash',md5(data::text));
 elsif p_action in ('receipt','receipt_finish') then
  if p_payload-array['payment','receipt']<>'{}' or not(p_payload ? 'payment') then raise insufficient_privilege;end if;
  pid=(p_payload->>'payment')::uuid;
  select e.adherent_id into mid from uniion_private.dues_payments p join uniion_private.dues_entries e on e.id=p.entry_id and e.organization_id=p.organization_id where p.id=pid and p.organization_id=p_org for update of e;
  if not found then raise insufficient_privilege;end if;
  data=uniion_private.dues_export_snapshot(p_org,mid);
  select value into item from jsonb_array_elements(data->'payments') where value->>'id'=pid::text;
  if (item->>'cents')::bigint<=0 or item->>'effectiveOn' is null then raise insufficient_privilege;end if;
  rev=(item->>'revision')::int;
  if p_action='receipt' then
   insert into uniion_private.dues_receipts(organization_id,payment_id,revision,snapshot,created_by) values(p_org,pid,rev,(data-'payments')||jsonb_build_object('payment',item),auth.uid()) on conflict do nothing;
  end if;
  select * into r from uniion_private.dues_receipts where payment_id=pid and organization_id=p_org and revision=rev;
  if not found or (p_action='receipt_finish' and r.id::text is distinct from p_payload->>'receipt') then raise insufficient_privilege;end if;
  if p_action='receipt_finish' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.receipt.exported',jsonb_build_object('receipt',r.id,'payment',pid,'revision',rev));end if;
  return jsonb_build_object('id',r.id,'createdAt',r.created_at,'revision',r.revision,'data',r.snapshot);
 else raise insufficient_privilege;end if;
exception when invalid_text_representation or numeric_value_out_of_range then raise insufficient_privilege;
end $$;


--
-- Name: uniion_identity_directory(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_identity_directory(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object(
 'members',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',coalesce(p.name,nullif(u.raw_user_meta_data->>'full_name',''),u.email),'email',u.email,'joined_at',m.joined_at,'revoked_at',m.revoked_at,'suspended',exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=m.organization_id and s.user_id=m.user_id and s.suspended)) order by m.joined_at,u.id) from public.uniion_memberships m join auth.users u on u.id=m.user_id left join uniion_private.identity_profiles p on p.organization_id=m.organization_id and p.user_id=m.user_id where m.organization_id=p_org),'[]'::jsonb),
 'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'created_at',i.created_at,'expires_at',i.expires_at,'accepted_at',i.accepted_at,'revoked_at',i.revoked_at,'status',case when i.accepted_at is not null then 'accepted' when i.revoked_at is not null then 'revoked' when i.expires_at<=now() then 'expired' else 'pending' end) order by i.created_at desc,i.id) from uniion_private.invitations i where i.organization_id=p_org),'[]'::jsonb));
end $$;


--
-- Name: uniion_identity_organization_save(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_identity_organization_save(p_org uuid, p_details jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare k text;v jsonb;
begin
 perform public.uniion_identity_profile(p_org);
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.authority(p_org,auth.uid(),'organization_edit') then raise insufficient_privilege;end if;
 if p_details is null or jsonb_typeof(p_details)<>'object' or length(p_details::text)>12000 then raise insufficient_privilege;end if;
 for k,v in select * from jsonb_each(p_details) loop
 if k<>all(array['type','nom','sigle','siret','idcc','effectif','sieges','mandatDebut','mandatFin','adresse','email','tel','secretaire','tresorier']) or jsonb_typeof(v)<>'string' or length(v#>>'{}')>500 then raise insufficient_privilege;end if;
 end loop;
 if coalesce(length(trim(p_details->>'nom')),0)=0 or coalesce(p_details->>'type','') not in ('cse','ud','section') then raise insufficient_privilege;end if;
 if coalesce(p_details->>'siret','')<>'' and (p_details->>'siret')!~'^[0-9]{14}$' then raise insufficient_privilege;end if;
 if coalesce(p_details->>'email','')<>'' and (p_details->>'email')!~'^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise insufficient_privilege;end if;
 foreach k in array array['effectif','sieges'] loop
 if coalesce(p_details->>k,'')<>'' and (p_details->>k)!~'^[0-9]{1,9}$' then raise insufficient_privilege;end if;
 end loop;
 foreach k in array array['mandatDebut','mandatFin'] loop
 if coalesce(p_details->>k,'')<>'' then
 if (p_details->>k)!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise insufficient_privilege;end if;
 perform (p_details->>k)::date;
 end if;end loop;
 if coalesce(p_details->>'mandatDebut','')<>'' and coalesce(p_details->>'mandatFin','')<>'' and p_details->>'mandatFin'<=p_details->>'mandatDebut' then raise insufficient_privilege;end if;
 update public.uniion_organizations set name=trim(p_details->>'nom') where id=p_org;
 insert into uniion_private.organization_details values(p_org,p_details) on conflict(organization_id) do update set details=excluded.details;
 return public.uniion_identity_profile(p_org);
end $_$;


--
-- Name: uniion_identity_profile(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_identity_profile(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return (select jsonb_build_object('id',u.id,'email',u.email,'name',coalesce(p.name,nullif(u.raw_user_meta_data->>'full_name',''),u.email),'role_label',coalesce(p.role_label,''),'organization_id',o.id,'organization',o.name,'organization_details',coalesce(d.details,'{}'::jsonb)||jsonb_build_object('nom',o.name),'can_manage',uniion_private.identity_admin(p_org),'can_edit_organization',auth.jwt()->>'aal'='aal2' and uniion_private.authority(p_org,auth.uid(),'organization_edit')) from auth.users u cross join public.uniion_organizations o left join uniion_private.identity_profiles p on p.organization_id=o.id and p.user_id=auth.uid() left join uniion_private.organization_details d on d.organization_id=o.id where u.id=auth.uid() and o.id=p_org);
end $$;


--
-- Name: uniion_identity_profile_save(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_identity_profile_save(p_org uuid, p_name text, p_role text, p_email text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 perform public.uniion_identity_profile(p_org);
 if p_name is null or length(trim(p_name)) not between 1 and 160 or p_role is null or length(trim(p_role)) not between 1 and 160 or p_email is distinct from (select email from auth.users where id=auth.uid()) then raise insufficient_privilege;end if;
 insert into uniion_private.identity_profiles values(p_org,auth.uid(),trim(p_name),trim(p_role)) on conflict(organization_id,user_id) do update set name=excluded.name,role_label=excluded.role_label;
 return public.uniion_identity_profile(p_org);
end $$;


--
-- Name: uniion_identity_rights(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_identity_rights(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 result=public.uniion_admin_context(p_org);
 return jsonb_build_object('members',result->'members','resources',result->'resources','authorities',result->'authorities','permissions',coalesce((select jsonb_agg(jsonb_build_object('module',p.module,'permission',p.permission)) from public.uniion_permissions p join public.uniion_module_access a using(organization_id,module) where p.organization_id=p_org and p.user_id=auth.uid() and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)),'[]'::jsonb));
end $$;


--
-- Name: uniion_invite_accept(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_invite_accept(p_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare invite uniion_private.invitations;mail text;
begin
 if not uniion_private.session_allowed() or p_token is null or length(p_token)<>64 then raise insufficient_privilege;end if;
 select lower(email) into mail from auth.users where id=auth.uid() and email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<now());
 select * into invite from uniion_private.invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
 if not found or mail is null or invite.email<>mail or invite.accepted_at is not null or invite.revoked_at is not null or invite.expires_at<=now()
 or not uniion_private.authority(invite.organization_id,invite.created_by,'rights') then raise insufficient_privilege;end if;
 if exists(select 1 from public.uniion_memberships where organization_id=invite.organization_id and user_id=auth.uid()) then raise insufficient_privilege;end if;
 insert into public.uniion_memberships(organization_id,user_id,joined_at) values(invite.organization_id,auth.uid(),now());
 -- No permissions, authorities, resource grants or historical access are created.
 update uniion_private.invitations set accepted_at=now(),accepted_by=auth.uid() where id=invite.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(invite.organization_id,auth.uid(),'invitation.accepted',jsonb_build_object('invitation',invite.id));
 return jsonb_build_object('organization_id',invite.organization_id,'business_rights_granted',false);
end $$;


--
-- Name: uniion_invite_create(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_invite_create(p_org uuid, p_email text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare ticket text=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');ident uuid;mail text=lower(trim(p_email));
begin
 if not uniion_private.identity_admin(p_org) or mail is null or length(mail)>320 or mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise insufficient_privilege;end if;
 -- Existing or revoked memberships are never silently reactivated by an invitation.
 if exists(select 1 from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=p_org and lower(u.email)=mail) then raise insufficient_privilege;end if;
 insert into uniion_private.invitations(organization_id,email,token_hash,created_by,expires_at)
 values(p_org,mail,encode(sha256(convert_to(ticket,'UTF8')),'hex'),auth.uid(),now()+interval '7 days') returning id into ident;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.created',jsonb_build_object('invitation',ident));
 return jsonb_build_object('id',ident,'token',ticket,'expires_in_seconds',604800);
end $_$;


--
-- Name: uniion_invite_resend(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_invite_resend(p_org uuid, p_invitation uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ticket text=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');mail text;
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update uniion_private.invitations set token_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),created_by=auth.uid(),expires_at=now()+interval '7 days' where id=p_invitation and organization_id=p_org and accepted_at is null and revoked_at is null returning email into mail;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.resent',jsonb_build_object('invitation',p_invitation));
 return jsonb_build_object('id',p_invitation,'token',ticket,'email',mail);
end $$;


--
-- Name: uniion_invite_revoke(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_invite_revoke(p_org uuid, p_invitation uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update uniion_private.invitations set revoked_at=coalesce(revoked_at,now()) where id=p_invitation and organization_id=p_org and accepted_at is null;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.revoked',jsonb_build_object('invitation',p_invitation));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_lost_factor_approve(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_approve(p_request uuid, p_verification_reference text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare job uniion_private.lost_factor_jobs;ids uuid[];
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or not exists(select 1 from uniion_private.platform_operators where user_id=auth.uid() and active)
 or p_verification_reference is null or length(trim(p_verification_reference)) not between 12 and 200 then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.user_id=auth.uid() or job.state<>'pending' or job.expires_at<=now() then raise insufficient_privilege;end if;
 select array_agg(id order by id) into ids from auth.mfa_factors where user_id=job.user_id and status='verified';
 if ids is distinct from job.factors then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='approved',approved_by=auth.uid(),verification_reference=trim(p_verification_reference),expires_at=now()+interval '30 minutes' where id=job.id;
 update uniion_private.trusted_mfa_factors set valid_until=now() where user_id=job.user_id;
 update auth.sessions set not_after=now() where user_id=job.user_id;
 return jsonb_build_object('ok',true,'worker_required',true);
end $$;


--
-- Name: uniion_lost_factor_cancel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_cancel(p_request uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare job uniion_private.lost_factor_jobs;mine uuid=auth.uid();
begin
 if not exists(select 1 from auth.sessions where user_id=mine and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.state not in ('pending','approved','processing','cleared') then raise insufficient_privilege;end if;
 if mine<>job.user_id and not (uniion_private.session_allowed() and auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.platform_operators where user_id=mine and active)) then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='cancelled',cancelled_at=now(),lease=null,lease_until=null where id=job.id;
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_lost_factor_check(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_check(p_request uuid, p_lease uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select auth.role()='service_role' and exists(select 1 from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active
 where j.id=p_request and j.lease=p_lease and j.state='processing' and j.lease_until>now() and j.expires_at>now())
$$;


--
-- Name: uniion_lost_factor_claim(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_claim(p_request uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare job uniion_private.lost_factor_jobs;ticket uuid=gen_random_uuid();
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.expires_at<=now() or not exists(select 1 from uniion_private.platform_operators where user_id=job.approved_by and active)
 or not (job.state='approved' or (job.state='processing' and job.lease_until<now())) then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='processing',lease=ticket,lease_until=now()+interval '2 minutes' where id=job.id;
 return jsonb_build_object('user_id',job.user_id,'factors',job.factors,'lease',ticket);
end $$;


--
-- Name: uniion_lost_factor_finish(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_finish(p_request uuid, p_lease uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare job uniion_private.lost_factor_jobs;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into job from uniion_private.lost_factor_jobs where id=p_request for update;
 if not found or job.state<>'processing' or job.lease is distinct from p_lease or job.lease_until<=now() or job.expires_at<=now()
 or not exists(select 1 from uniion_private.platform_operators where user_id=job.approved_by and active)
 or exists(select 1 from auth.mfa_factors where user_id=job.user_id and status='verified') then raise insufficient_privilege;end if;
 update uniion_private.lost_factor_jobs set state='cleared',expires_at=now()+interval '30 minutes',lease=null,lease_until=null where id=job.id;
 insert into uniion_private.mfa_requirements values(job.user_id,true) on conflict(user_id) do update set required=true;
 update auth.sessions set not_after=now() where user_id=job.user_id;
 return jsonb_build_object('ok',true,'relogin_required',true);
end $$;


--
-- Name: uniion_lost_factor_request(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_lost_factor_request() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ids uuid[];job uuid;
BEGIN
 IF NOT uniion_private.identity_in_scope() THEN RAISE insufficient_privilege; END IF;
 perform 1 from auth.users where id=auth.uid() for update;
 if not (exists(select 1 from public.uniion_memberships where user_id=auth.uid())
 or exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid())
 or exists(select 1 from uniion_private.platform_operators where user_id=auth.uid())) then raise insufficient_privilege;end if;
 if not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise insufficient_privilege;end if;
 select array_agg(id order by id) into ids from auth.mfa_factors where user_id=auth.uid() and status='verified';
 if coalesce(cardinality(ids),0)=0 or (select count(*) from uniion_private.lost_factor_jobs where user_id=auth.uid() and expires_at>now() and state in ('pending','approved','processing','cleared'))>=3 then raise insufficient_privilege;end if;
 insert into uniion_private.lost_factor_jobs(user_id,factors) values(auth.uid(),ids) returning id into job;
 return jsonb_build_object('id',job,'approval_required',true);
end $$;


--
-- Name: uniion_meeting_audio(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare r public.uniion_resources;c uniion_private.meeting_consents;g uniion_private.meeting_audio_grants;f uniion_private.meeting_audio;aid uuid;v integer;
begin
 if p_action is null or p_action not in ('grant','list','write','prepare','uploaded','listen','download') or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 perform public.uniion_module_use(p_org,'reunions');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting and module='reunions' for update;
 if not found or not exists(select 1 from uniion_private.business_records where organization_id=p_org and id=p_meeting)
 or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),p_action in ('grant','write','prepare','uploaded')) then raise insufficient_privilege;end if;
 if p_action='grant' then
  if not uniion_private.authority(p_org,auth.uid(),'rights') or not(p_payload ?& array['user','version','read','write','download']) or p_payload-array['user','version','read','write','download']<>'{}'
   or jsonb_typeof(p_payload->'user') is distinct from 'string' or (p_payload->>'user')::uuid=auth.uid()
   or not uniion_private.actor_member(p_org,(p_payload->>'user')::uuid)
   or jsonb_typeof(p_payload->'version') is distinct from 'number' or (p_payload->>'version') !~ '^(0|[1-9][0-9]{0,8})$'
   or jsonb_typeof(p_payload->'read') is distinct from 'boolean' or jsonb_typeof(p_payload->'write') is distinct from 'boolean' or jsonb_typeof(p_payload->'download') is distinct from 'boolean' then raise insufficient_privilege;end if;
  select version into v from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=(p_payload->>'user')::uuid;
  if coalesce(v,0)<>(p_payload->>'version')::int then raise insufficient_privilege;end if;
  insert into uniion_private.meeting_audio_grants values(p_org,p_meeting,(p_payload->>'user')::uuid,(p_payload->>'read')::boolean,(p_payload->>'write')::boolean,(p_payload->>'download')::boolean,coalesce(v,0)+1)
   on conflict(organization_id,meeting_id,user_id) do update set can_read=excluded.can_read,can_write=excluded.can_write,can_download=excluded.can_download,version=excluded.version;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.grant',jsonb_build_object('meeting',p_meeting,'user',p_payload->>'user','version',coalesce(v,0)+1,'read',p_payload->'read','write',p_payload->'write','download',p_payload->'download'));
  return jsonb_build_object('version',coalesce(v,0)+1);
 end if;
 select * into g from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=auth.uid();
 if not found or not g.can_read or (p_action in ('write','prepare','uploaded') and not g.can_write) or (p_action='download' and not g.can_download) then raise insufficient_privilege;end if;
 select * into c from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting;
 if not found or not c.accepted or c.meeting_version<>r.version then raise insufficient_privilege;end if;
 if p_action='write' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;return jsonb_build_object('ok',true);
 elsif p_action='list' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return jsonb_build_object('files',coalesce((select jsonb_agg(jsonb_build_object('id',id,'filename',filename,'size',size,'status',status,'hasOriginal',exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=meeting_audio.id and o.status='clean'),'canDownload',g.can_download,'consentVersion',consent_version,'current',consent_version=c.version and meeting_version=r.version and not exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=meeting_audio.id and o.status<>'clean')) order by created_at,id) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting),'[]'));
 elsif p_action='prepare' then
  if not(p_payload ?& array['request_id','consentVersion','filename','size','sha256']) or p_payload-array['request_id','consentVersion','filename','size','sha256']<>'{}'
   or jsonb_typeof(p_payload->'request_id') is distinct from 'string' or jsonb_typeof(p_payload->'filename') is distinct from 'string'
   or jsonb_typeof(p_payload->'sha256') is distinct from 'string' or jsonb_typeof(p_payload->'size') is distinct from 'number' or (p_payload->>'size') !~ '^[1-9][0-9]{0,7}$'
   or jsonb_typeof(p_payload->'consentVersion') is distinct from 'number' or (p_payload->>'consentVersion') !~ '^[1-9][0-9]{0,8}$'
   or c.version<>(p_payload->>'consentVersion')::int then raise insufficient_privilege;end if;
  select * into f from uniion_private.meeting_audio where organization_id=p_org and actor=auth.uid() and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if f.meeting_id<>p_meeting or f.consent_version<>c.version or f.meeting_version<>r.version or f.filename is distinct from p_payload->>'filename' or f.size is distinct from (p_payload->>'size')::int or f.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
  else
   if (select count(*) from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting)>=480 then raise insufficient_privilege;end if;
   aid=gen_random_uuid();
   insert into uniion_private.meeting_audio(id,organization_id,meeting_id,request_id,actor,consent_version,meeting_version,consent_actor,consent_at,participants,filename,size,sha256,path)
    values(aid,p_org,p_meeting,(p_payload->>'request_id')::uuid,auth.uid(),c.version,r.version,c.actor,c.updated_at,coalesce(r.body->'participants','[]'),p_payload->>'filename',(p_payload->>'size')::int,p_payload->>'sha256',p_org::text||'/'||p_meeting::text||'/'||aid::text) returning * into f;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.prepared',jsonb_build_object('meeting',p_meeting,'audio',f.id,'consentVersion',c.version));
  end if;
  return to_jsonb(f)-'participants';
 end if;
 if not(p_payload ? 'audio') or jsonb_typeof(p_payload->'audio') is distinct from 'string' or p_payload-(case when p_action='uploaded' then array['audio'] else array['audio','audit'] end)<>'{}' then raise insufficient_privilege;end if;
 if p_action<>'uploaded' and jsonb_typeof(p_payload->'audit') is distinct from 'boolean' then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=(p_payload->>'audio')::uuid and status='clean' and consent_version=c.version and meeting_version=r.version;
 if not found then raise insufficient_privilege;end if;
 if exists(select 1 from uniion_private.meeting_audio_originals where audio_id=f.id and status<>'clean') then raise insufficient_privilege;end if;
 if p_action='uploaded' then return jsonb_build_object('id',f.id,'status',f.status,'sha256',f.sha256,'size',f.size);end if;
 if p_payload->>'audit'='true' then
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.'||p_action,jsonb_build_object('meeting',p_meeting,'audio',f.id));
 end if;
 return to_jsonb(f)-'participants';
exception when invalid_text_representation or check_violation or numeric_value_out_of_range or not_null_violation then raise insufficient_privilege;
end$_$;


--
-- Name: uniion_meeting_audio_duration(uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio_duration(p_id uuid, p_sha text, p_duration_ms integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.meeting_audio;
begin
 if not uniion_private.is_scanner() or p_duration_ms is null or p_duration_ms not between 0 and 3600000 then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=p_id for update;
 if not found or f.status<>'clean' or f.sha256 is distinct from p_sha or (f.duration_ms is not null and f.duration_ms<>p_duration_ms) then raise insufficient_privilege;end if;
 if f.duration_ms is not null then return;end if;
 update uniion_private.meeting_audio set duration_ms=p_duration_ms where id=p_id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'meeting.audio.duration',jsonb_build_object('audio',f.id,'durationMs',p_duration_ms));
end$$;


--
-- Name: uniion_meeting_audio_finish(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio_finish(p_id uuid, p_sha text, p_status text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.meeting_audio;
begin
 if not uniion_private.is_scanner() or p_status is null or p_status not in ('clean','blocked') then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=p_id for update;
 if not found or f.sha256 is distinct from p_sha or f.status='blocked' or (p_status='clean' and not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=f.path and (metadata->>'size')::bigint=f.size)) then raise insufficient_privilege;end if;
 if f.status=p_status then return;end if;
 update uniion_private.meeting_audio set status=p_status where id=f.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'meeting.audio.scanned',jsonb_build_object('audio',f.id,'status',p_status));
end$$;


--
-- Name: uniion_meeting_audio_markers(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio_markers(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare meta jsonb;aid uuid;d integer;v integer;items jsonb;item jsonb;ids uuid[]='{}';marker_id uuid;
begin
 if p_action is null or p_action not in ('get','save') or jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 aid=(p_payload->>'audio')::uuid;
 -- Parent RPC locks the meeting and enforces source ACL, consent and clean status.
 if p_action='save' then
  perform public.uniion_meeting_audio(p_org,p_meeting,'uploaded',jsonb_build_object('audio',aid));
 else
  perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',aid,'audit',false));
 end if;
 select duration_ms into d from uniion_private.meeting_audio where organization_id=p_org and meeting_id=p_meeting and id=aid;
 if d is null then raise insufficient_privilege;end if;
 select version,markers into v,items from uniion_private.meeting_audio_markers where organization_id=p_org and meeting_id=p_meeting and audio_id=aid order by version desc limit 1;
 v=coalesce(v,0);items=coalesce(items,'[]');
 if p_action='save' then
  if not(p_payload ?& array['audio','version','markers']) or p_payload-array['audio','version','markers']<>'{}'
   or jsonb_typeof(p_payload->'version') is distinct from 'number' or (p_payload->>'version') !~ '^(0|[1-9][0-9]{0,8})$'
   or v<>(p_payload->>'version')::int or jsonb_typeof(p_payload->'markers') is distinct from 'array' then raise insufficient_privilege;end if;
  items=p_payload->'markers';
  if jsonb_array_length(items)>100 or octet_length(items::text)>150000 then raise insufficient_privilege;end if;
  for item in select value from jsonb_array_elements(items) loop
   if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['id','timeMs','kind','note']) or item-array['id','timeMs','kind','note']<>'{}'
    or jsonb_typeof(item->'id') is distinct from 'string' or jsonb_typeof(item->'timeMs') is distinct from 'number' or (item->>'timeMs') !~ '^(0|[1-9][0-9]{0,8})$'
    or (item->>'timeMs')::int>d or jsonb_typeof(item->'kind') is distinct from 'string' or item->>'kind' not in ('vote','decision','engagement','desaccord','verifier','diverse','point')
    or jsonb_typeof(item->'note') is distinct from 'string' or length(item->>'note')>1000 then raise insufficient_privilege;end if;
   marker_id=(item->>'id')::uuid;
   if marker_id=any(ids) then raise insufficient_privilege;end if;ids=array_append(ids,marker_id);
  end loop;
  v=v+1;
  insert into uniion_private.meeting_audio_markers values(p_org,p_meeting,aid,v,items,auth.uid(),now());
 else
  if p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.audio.markers.'||p_action,jsonb_build_object('audio',aid,'version',v));
 return jsonb_build_object('audio',aid,'version',v,'durationMs',d,'markers',items);
exception when invalid_text_representation or numeric_value_out_of_range then raise insufficient_privilege;
end$_$;


--
-- Name: uniion_meeting_audio_setup(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio_setup(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r public.uniion_resources;g uniion_private.meeting_audio_grants;c uniion_private.meeting_consents;u uuid;v integer;mode text;
begin
 perform public.uniion_module_use(p_org,'reunions');
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting and module='reunions' for update;
 if not found or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),false) or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='manage' then
  if not uniion_private.authority(p_org,auth.uid(),'rights') or not uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true)
   or p_payload-array['email','mode']<>'{}' or jsonb_typeof(p_payload->'email') is distinct from 'string' or jsonb_typeof(p_payload->'mode') is distinct from 'string' then raise insufficient_privilege;end if;
  mode=p_payload->>'mode';if mode not in ('read','write','download','revoke') then raise insufficient_privilege;end if;
  select id into u from auth.users where lower(email)=lower(btrim(p_payload->>'email'));
  if u is null then raise insufficient_privilege;end if;
  select version into v from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=u;
  return public.uniion_meeting_audio(p_org,p_meeting,'grant',jsonb_build_object('user',u,'version',coalesce(v,0),'read',mode<>'revoke','write',mode in ('write','download'),'download',mode='download'));
 end if;
 if p_action is distinct from 'status' or p_payload<>'{}' then raise insufficient_privilege;end if;
 select * into g from uniion_private.meeting_audio_grants where organization_id=p_org and meeting_id=p_meeting and user_id=auth.uid();
 select * into c from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting;
 return jsonb_build_object('meetingVersion',r.version,'consentVersion',coalesce(c.version,0),'consentCurrent',coalesce(c.accepted and c.meeting_version=r.version,false),
 'read',coalesce(g.can_read,false),'write',coalesce(g.can_read and g.can_write,false) and uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true),
 'download',coalesce(g.can_read and g.can_download,false),'manage',uniion_private.authority(p_org,auth.uid(),'rights') and uniion_private.actor_resource(p_org,p_meeting,auth.uid(),true));
end$$;


--
-- Name: uniion_meeting_audio_transfer(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_audio_transfer(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare f uniion_private.meeting_audio;partno integer;b bytea;old bytea;result bytea;
begin
 perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 if jsonb_typeof(p_payload) is distinct from 'object' or jsonb_typeof(p_payload->'audio') is distinct from 'string' then raise insufficient_privilege;end if;
 select * into f from uniion_private.meeting_audio where id=(p_payload->>'audio')::uuid and organization_id=p_org and meeting_id=p_meeting and actor=auth.uid() for update;
 if not found or f.status='blocked' or not exists(select 1 from uniion_private.meeting_consents where organization_id=p_org and meeting_id=p_meeting and version=f.consent_version and accepted) then raise insufficient_privilege;end if;
 if p_action='put' then
  if p_payload-array['audio','part','content']<>'{}' or jsonb_typeof(p_payload->'part') is distinct from 'number' or (p_payload->>'part') !~ '^(0|[1-9][0-9]?)$' or jsonb_typeof(p_payload->'content') is distinct from 'string' or length(p_payload->>'content')>349528 then raise insufficient_privilege;end if;
  partno=(p_payload->>'part')::int;b=decode(p_payload->>'content','base64');
  if partno not between 0 and (f.size-1)/262144 or octet_length(b)<>least(262144,f.size-partno*262144) then raise insufficient_privilege;end if;
  select bytes into old from uniion_private.meeting_audio_chunks where audio_id=f.id and part=partno;
  if found then
   if old<>b then raise insufficient_privilege;end if;
  else
   if f.status<>'pending' then raise insufficient_privilege;end if;
   insert into uniion_private.meeting_audio_chunks values(f.id,partno,b);
  end if;
 elsif p_action='assemble' then
  if p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
  select string_agg(bytes,''::bytea order by part) into result from uniion_private.meeting_audio_chunks where audio_id=f.id;
  if result is null or octet_length(result)<>f.size then raise insufficient_privilege;end if;
  return jsonb_build_object('filename',f.filename,'request_id',f.request_id,'consentVersion',f.consent_version,'content',encode(result,'base64'),'sha256',f.sha256);
 elsif p_action is distinct from 'status' or p_payload-array['audio']<>'{}' then raise insufficient_privilege;end if;
 return jsonb_build_object('audio',f.id,'parts',coalesce((select jsonb_agg(part order by part) from uniion_private.meeting_audio_chunks where audio_id=f.id),'[]'),'status',f.status);
exception when invalid_text_representation or numeric_value_out_of_range or check_violation then raise insufficient_privilege;
end$_$;


--
-- Name: uniion_meeting_consent(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_consent(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
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
end$_$;


--
-- Name: uniion_meeting_minutes(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_meeting_minutes(p_org uuid, p_meeting uuid, p_audio uuid, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare status jsonb;j uniion_private.transcription_jobs;d uniion_private.meeting_minutes;r public.uniion_resources;part uniion_private.transcription_parts;markers jsonb;item jsonb;transcript text='';marker_text text='';snap jsonb='[]';row jsonb;body jsonb;order_text text;ids uuid[];rec uuid;
begin
 if p_action='publications' then
  perform public.uniion_module_use(p_org,'reunions');
  if not uniion_private.authority(p_org,auth.uid(),'content_publish') or not uniion_private.actor_resource_before_minutes(p_org,p_meeting,auth.uid(),false) then raise insufficient_privilege;end if;
  return jsonb_build_object('rows',coalesce((select jsonb_agg(jsonb_build_object('id',m.resource_id,'version',p.version) order by p.version desc) from uniion_private.meeting_minutes m join uniion_private.business_publications p on p.organization_id=m.organization_id and p.resource_id=m.resource_id where m.organization_id=p_org and m.meeting_id=p_meeting and p.published_at is not null and p.revoked_at is null),'[]'));
 end if;
 if p_action is null or p_action not in ('prepare','status') then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',p_audio,'audit',false));
 -- A newly completed recording segment produces a new source set, never a silent stale PV.
 select recording_id into rec from uniion_private.meeting_audio_sequences where audio_id=p_audio;
 select array_agg(f.id order by coalesce(q.position,0),f.id) into ids from uniion_private.meeting_audio f left join uniion_private.meeting_audio_sequences q on q.audio_id=f.id where f.organization_id=p_org and f.meeting_id=p_meeting and (case when rec is null then f.id=p_audio else q.recording_id=rec end);
 -- Authorised co-reviewers can find the already prepared draft for this exact source set.
 select m.* into d from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id where m.organization_id=p_org and m.meeting_id=p_meeting and p.id=p_audio and exists(select 1 from uniion_private.transcription_jobs t where t.id=m.job_id and t.source_ids=ids) order by m.created_at desc limit 1;
 if found then return public.uniion_business_records(p_org,'reunions','get',jsonb_build_object('id',d.resource_id));end if;
 if p_action='status' then return jsonb_build_object('absent',true);end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');
 status=public.uniion_transcription(p_org,p_meeting,p_audio,'status');
 if status->>'state' is distinct from 'done' then raise insufficient_privilege;end if;
 select * into j from uniion_private.transcription_jobs where id=(status->>'id')::uuid;
 select * into r from public.uniion_resources where organization_id=p_org and id=p_meeting;
 if exists(select 1 from uniion_private.meeting_minutes where resource_id=p_meeting) then raise insufficient_privilege;end if;
 for part in select * from uniion_private.transcription_parts where job_id=j.id order by offset_ms,id loop
  markers=public.uniion_meeting_audio_markers(p_org,p_meeting,'get',jsonb_build_object('audio',part.id));
  snap=snap||jsonb_build_array(jsonb_build_object('audio',part.id,'sha256',part.sha256,'consentVersion',part.consent_version,'meetingVersion',part.meeting_version,'markerVersion',markers->'version','offsetMs',part.offset_ms));
  for item in select value from jsonb_array_elements(part.result->'segments') loop
   transcript=transcript||'['||to_char((part.offset_ms+(item->>'startMs')::bigint)*interval '1 millisecond','HH24:MI:SS.MS')||'–'||to_char((part.offset_ms+(item->>'endMs')::bigint)*interval '1 millisecond','HH24:MI:SS.MS')||'] '||(item->>'text')||E'\n';
  end loop;
  for item in select value from jsonb_array_elements(markers->'markers') loop
   marker_text=marker_text||'['||to_char((part.offset_ms+(item->>'timeMs')::bigint)*interval '1 millisecond','HH24:MI:SS.MS')||' · '||(case item->>'kind' when 'decision' then 'Décision' when 'engagement' then 'Engagement' when 'desaccord' then 'Désaccord' when 'verifier' then 'À vérifier' when 'point' then 'Changement de point' when 'vote' then 'Vote' else 'Question diverse' end)||'] '||(item->>'note')||E'\n';
  end loop;
 end loop;
 -- Fail explicitly instead of silently omitting sources from a long meeting.
 if length(transcript)+length(marker_text)+length(coalesce((r.body->'ordre')::text,''))>3145728 then raise program_limit_exceeded using message='minutes_source_too_large';end if;
 select coalesce(string_agg(case jsonb_typeof(x) when 'string' then x#>>'{}' else coalesce(x->>'title',x->>'titre',x->>'text',x->>'label',x::text) end,E'\n'),'Ordre du jour non renseigné.') into order_text from jsonb_array_elements(coalesce(r.body->'ordre','[]'))x;
 body=jsonb_build_object('title',left('PV — '||r.title,200),'ordre',coalesce(r.body->'ordre','[]'),'transcript',transcript,'markers',jsonb_build_array(marker_text),'minutes','PROJET À RELIRE — transcription automatique, aucune décision déduite.'||E'\n\nORDRE DU JOUR\n'||order_text||E'\n\nTRANSCRIPTION HORODATÉE\n'||transcript||E'\nMARQUEURS DE SÉANCE\n'||marker_text);
 if octet_length(body::text)>6291456 or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='reunions' and permission='create') then raise insufficient_privilege;end if;
 insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'reunions',body->>'title',body) returning * into r;
 insert into uniion_private.business_records(organization_id,id,creator) values(p_org,r.id,auth.uid());
 insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,'infinity',null);
 row=body||jsonb_build_object('id',r.id,'version',r.version,'module','reunions','status','Brouillon','serverRecord',true,'canWrite',true);
 insert into uniion_private.meeting_minutes values(p_org,(row->>'id')::uuid,p_meeting,j.id,snap,auth.uid(),now());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.minutes.prepared',jsonb_build_object('meeting',p_meeting,'resource',row->>'id','job',j.id,'sources',snap));
 return row||'{"meetingPV":true}'::jsonb;
end$$;


--
-- Name: uniion_membership_revoke(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_membership_revoke(p_org uuid, p_user uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if auth.uid()=p_user or not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update public.uniion_memberships set revoked_at=coalesce(revoked_at,now()) where organization_id=p_org and user_id=p_user;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'membership.revoked',jsonb_build_object('user',p_user));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_membership_status(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_membership_status(p_org uuid, p_user uuid, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if auth.uid()=p_user or not uniion_private.identity_admin(p_org) or p_action is null or p_action not in ('suspend','resume') then raise insufficient_privilege;end if;
 perform 1 from public.uniion_memberships where organization_id=p_org and user_id=p_user and revoked_at is null for update;
 if not found then raise insufficient_privilege;end if;
 insert into uniion_private.membership_suspensions values(p_org,p_user,p_action='suspend') on conflict(organization_id,user_id) do update set suspended=excluded.suspended;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'membership.'||p_action,jsonb_build_object('user',p_user));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_message_classify(uuid, uuid, integer, uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_message_classify(p_org uuid, p_case uuid, p_expected integer, p_conversation uuid, p_seq bigint, p_file text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ident uuid;v integer;old uniion_private.case_links;
begin
 perform public.uniion_case_files(p_org,p_case);
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) or p_file is null or uniion_private.message_case_source(p_org,p_conversation,p_seq,p_file) is null then raise insufficient_privilege;end if;
 select version into v from public.uniion_resources where organization_id=p_org and id=p_case for update;
 select * into old from uniion_private.case_links where organization_id=p_org and resource_id=p_case and message_conversation=p_conversation and message_seq=p_seq and file=p_file;
 if found then
  if old.withdrawn then raise insufficient_privilege;end if;
  return jsonb_build_object('id',old.id,'already',true);
 end if;
 if p_expected is distinct from v then raise serialization_failure;end if;
 insert into uniion_private.case_links(organization_id,resource_id,message_conversation,message_seq,file,actor) values(p_org,p_case,p_conversation,p_seq,p_file,auth.uid()) returning id into ident;
 update public.uniion_resources set version=version+1 where id=p_case;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.classified',jsonb_build_object('case',p_case,'link',ident));
 return jsonb_build_object('id',ident,'already',false);
end$$;


--
-- Name: uniion_message_file_context(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_message_file_context(p_org uuid, p_conversation uuid, p_attachment uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.message_files;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 select * into f from uniion_private.message_files where organization_id=p_org and attachment=p_attachment;
 if not found then raise insufficient_privilege;end if;
 if f.conversation=p_conversation then return public.uniion_message_file_context_before_references(p_org,p_conversation,p_attachment);end if;
 if uniion_private.case_file_trashed(p_attachment) or not exists(select 1 from uniion_private.messages m cross join lateral (select uniion_private.message_origin(p_org,m.conversation,m.seq) original) q where m.organization_id=p_org and m.conversation=p_conversation and (q.original).conversation=f.conversation and (q.original).seq=f.seq) then raise insufficient_privilege;end if;
 return jsonb_build_object('resource',f.resource,'write',false);
end$$;


--
-- Name: uniion_message_file_context_before_references(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_message_file_context_before_references(p_org uuid, p_conversation uuid, p_attachment uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.message_files;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 select * into f from uniion_private.message_files where organization_id=p_org and conversation=p_conversation and attachment=p_attachment;
 if not found or not uniion_private.actor_resource(p_org,f.resource,auth.uid(),false) or uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return jsonb_build_object('resource',f.resource,'write',uniion_private.actor_resource(p_org,f.resource,auth.uid(),true));
end$$;


--
-- Name: uniion_message_file_prepare(uuid, uuid, uuid, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_message_file_prepare(p_org uuid, p_conversation uuid, p_client uuid, p_filename text, p_mime text, p_size integer, p_sha256 text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare m jsonb; f uniion_private.message_files;a public.uniion_attachments;r uuid;item jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 perform 1 from uniion_private.message_conversations where organization_id=p_org and id=p_conversation for update;
 if not uniion_private.message_member(p_org,p_conversation) then raise insufficient_privilege;end if;
 if exists(select 1 from uniion_private.messages mx where mx.organization_id=p_org and mx.conversation=p_conversation and mx.author=auth.uid() and mx.client_id=p_client and not exists(select 1 from uniion_private.message_files fx where fx.organization_id=mx.organization_id and fx.conversation=mx.conversation and fx.seq=mx.seq)) then raise insufficient_privilege;end if;
 m=public.uniion_messaging(p_org,'send',jsonb_build_object('id',p_conversation,'clientId',p_client,'text','Pièce jointe'));
 select * into f from uniion_private.message_files where organization_id=p_org and conversation=p_conversation and seq=(m->>'seq')::bigint;
 if found then
  select * into a from public.uniion_attachments where id=f.attachment;
  if a.filename is distinct from p_filename or a.mime is distinct from p_mime or a.size is distinct from p_size or a.sha256 is distinct from p_sha256 then raise insufficient_privilege;end if;
 else
  insert into public.uniion_resources(organization_id,module,kind,title) values(p_org,'messagerie','message_file','Pièce de message') returning id into r;
  insert into uniion_private.message_files values(p_org,p_conversation,(m->>'seq')::bigint,r,null);
  item=public.uniion_attachment_prepare(p_org,r,p_filename,p_mime,p_size,p_sha256);
  update uniion_private.message_files set attachment=(item->>'id')::uuid where resource=r;
  select * into a from public.uniion_attachments where id=(item->>'id')::uuid;
 end if;
 if uniion_private.case_file_trashed(a.id) then raise insufficient_privilege;end if;
 if not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name) then update public.uniion_attachments set created_at=clock_timestamp() where id=a.id;end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'status',a.scan_status,'uploaded',exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name));
end$$;


--
-- Name: uniion_messaging(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare q text;rows jsonb;cursor_value text;
begin
 if p_action is null or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action not in ('search','targets') then return public.uniion_messaging_before_search_volume(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or not(p_payload ? 'query') or p_payload-array['query','before']<>'{}' or jsonb_typeof(p_payload->'query')<>'string' or length(p_payload->>'query')>200 or (p_action='search' and length(btrim(p_payload->>'query'))<1) or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
 q=lower(btrim(p_payload->>'query'));
 if p_action='targets' then
  with titles as materialized (
   select c.id,c.kind,uniion_private.message_conversation_before_live(p_org,c.id)->>'name' name
   from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id) and (not(p_payload ? 'before') or c.id<(p_payload->>'before')::uuid)
  ), page as materialized (select * from titles where strpos(lower(name),q)>0 order by id desc limit 50)
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'name',name) order by id desc),'[]'),case when count(*)=50 then min(id::text) end into rows,cursor_value from page;
 else
  -- Materialization prevents PostgreSQL from reevaluating a recursive source ACL
  -- for each field. Titles are computed once per authorized conversation.
  with titles as materialized (
   select c.id,c.kind,uniion_private.message_conversation_before_live(p_org,c.id)->>'name' name
   from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id)
  ), origins as materialized (
   select m,uniion_private.message_origin(p_org,m.conversation,m.seq) original
   from uniion_private.messages m join titles t on t.id=m.conversation
   where m.organization_id=p_org and (not(p_payload ? 'before') or m.id<(p_payload->>'before')::uuid)
   -- R19 : l'origine (contrôle d'accès récursif) n'est calculée que pour les candidats possibles :
   -- titre, corps ou fichier qui contiennent la recherche, ou transfert (dont le texte vient de
   -- l'original). Pour un message non transféré, l'origine est le message lui-même : le filtre
   -- final ci-dessous, inchangé, donne donc exactement les mêmes résultats.
   and (strpos(lower(t.name),q)>0 or strpos(lower(m.body),q)>0
    or exists(select 1 from uniion_private.message_forwards fw where fw.organization_id=p_org and fw.conversation=m.conversation and fw.seq=m.seq)
    or exists(select 1 from uniion_private.message_files f join public.uniion_attachments a on a.id=f.attachment where f.organization_id=p_org and f.conversation=m.conversation and f.seq=m.seq and strpos(lower(a.filename),q)>0))
  ), page as materialized (
   select o.m,t.name,t.kind from origins o join titles t on t.id=(o.m).conversation
   where (o.original).id is not null and
   (strpos(lower((o.original).body),q)>0 or strpos(lower(t.name),q)>0 or exists(select 1 from uniion_private.message_files f join public.uniion_attachments a on a.id=f.attachment where f.organization_id=p_org and f.conversation=(o.original).conversation and f.seq=(o.original).seq and strpos(lower(a.filename),q)>0))
   order by (o.m).id desc limit 50
  ) select coalesce(jsonb_agg(jsonb_build_object('id',(m).id,'conversation',(m).conversation,'name',name,'kind',kind,'message',uniion_private.message_json(m)) order by (m).id desc),'[]'),case when count(*)=50 then min((m).id::text) end into rows,cursor_value from page;
 end if;
 return jsonb_build_object('rows',rows,'next',cursor_value);
end$$;


--
-- Name: uniion_messaging_before_live(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging_before_live(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare cid uuid;s bigint;targets uuid[];target uuid;client uuid;prior uniion_private.message_forward_batches;item jsonb;result jsonb:='[]';q text;rows jsonb;cursor_value text;origin uniion_private.messages;depth integer;rc uuid;rs bigint;f uniion_private.message_forwards;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action not in ('forward','search','locate','targets') then return public.uniion_messaging_before_search(p_org,p_action,p_payload);end if;
 if p_action in ('search','targets') then
  if not(p_payload ? 'query') or p_payload-array['query','before']<>'{}' or jsonb_typeof(p_payload->'query')<>'string' or length(p_payload->>'query')>200 or (p_action='search' and length(btrim(p_payload->>'query'))<1) or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
  q=lower(btrim(p_payload->>'query'));
  if p_action='targets' then
   select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'kind',r.kind) order by r.id desc),'[]'),case when count(*)=50 then min(r.id::text) end into rows,cursor_value from (
    select cv.id,cv.kind,uniion_private.message_conversation_json(p_org,cv.id)->>'name' name from uniion_private.message_conversations cv where cv.organization_id=p_org and uniion_private.message_member(p_org,cv.id) and (not(p_payload ? 'before') or cv.id<(p_payload->>'before')::uuid) and strpos(lower(uniion_private.message_conversation_json(p_org,cv.id)->>'name'),q)>0 order by cv.id desc limit 50)r;
  else
   select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'conversation',r.conversation,'name',r.name,'kind',r.kind,'message',r.projection) order by r.id desc),'[]'),case when count(*)=50 then min(r.id::text) end into rows,cursor_value from (
    select m.id,m.conversation,cv.kind,uniion_private.message_conversation_json(p_org,m.conversation)->>'name' name,uniion_private.message_json(m) projection
    from uniion_private.messages m join uniion_private.message_conversations cv on cv.organization_id=m.organization_id and cv.id=m.conversation
    cross join lateral (select uniion_private.message_origin(p_org,m.conversation,m.seq) original) resolved
    where m.organization_id=p_org and (not(p_payload ? 'before') or m.id<(p_payload->>'before')::uuid) and (resolved.original).id is not null
    and (strpos(lower((resolved.original).body),q)>0 or strpos(lower(uniion_private.message_conversation_json(p_org,m.conversation)->>'name'),q)>0 or exists(select 1 from uniion_private.message_files mf join public.uniion_attachments a on a.id=mf.attachment where mf.organization_id=p_org and mf.conversation=(resolved.original).conversation and mf.seq=(resolved.original).seq and strpos(lower(a.filename),q)>0))
    order by m.id desc limit 50)r;
  end if;
  return jsonb_build_object('rows',rows,'next',cursor_value);
 end if;
 if p_action='locate' then
  if not(p_payload ?& array['id','seq']) or p_payload-array['id','seq']<>'{}' or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;
  if not uniion_private.message_visible(p_org,cid,s) then raise insufficient_privilege;end if;
  select jsonb_agg(uniion_private.message_json(m) order by m.seq),case when count(*)=50 then min(m.seq)::text end into rows,cursor_value from (select * from uniion_private.messages where organization_id=p_org and conversation=cid and seq<=s and uniion_private.message_visible(p_org,cid,seq) order by seq desc limit 50)m;
  return uniion_private.message_conversation_json(p_org,cid)||jsonb_build_object('messages',coalesce(rows,'[]'),'next',cursor_value,'focused',s::text);
 end if;
 if not(p_payload ?& array['id','seq','clientId','targets']) or p_payload-array['id','seq','clientId','targets']<>'{}' or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' or jsonb_typeof(p_payload->'clientId')<>'string' or jsonb_typeof(p_payload->'targets')<>'array' or jsonb_array_length(p_payload->'targets') not between 1 and 20 or exists(select 1 from jsonb_array_elements(p_payload->'targets')v where jsonb_typeof(v)<>'string') then raise insufficient_privilege;end if;
 cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;client=(p_payload->>'clientId')::uuid;
 select array_agg(v::uuid order by v::uuid) into targets from jsonb_array_elements_text(p_payload->'targets')v;
 if cid=any(targets) or cardinality(targets)<>(select count(distinct t) from unnest(targets)t) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='write') then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||auth.uid()::text||client::text,0));
 -- Acquire all source-chain and destination locks in UUID order, matching membership mutations.
 perform 1 from uniion_private.message_conversations cv where cv.organization_id=p_org and (cv.id=any(targets) or cv.id in(with recursive chain(c,s,d) as(select cid,s,0 union all select f0.source_conversation,f0.source_seq,ch.d+1 from chain ch join uniion_private.message_forwards f0 on f0.organization_id=p_org and f0.conversation=ch.c and f0.seq=ch.s where ch.d<8)select c from chain)) order by cv.id for update;
 origin=uniion_private.message_origin(p_org,cid,s);
 if origin.id is null then raise insufficient_privilege;end if;
 foreach target in array targets loop
  if not uniion_private.message_member(p_org,target) then raise insufficient_privilege;end if;
 end loop;
 select * into prior from uniion_private.message_forward_batches where organization_id=p_org and actor=auth.uid() and client_id=client;
 if found then
  if prior.source_conversation<>cid or prior.source_seq<>s or prior.targets<>targets then raise insufficient_privilege;end if;
  for item in select value from jsonb_array_elements(prior.result) loop
   if not uniion_private.message_visible(p_org,(item->>'conversation')::uuid,(item->>'seq')::bigint) then raise insufficient_privilege;end if;
  end loop;
  return jsonb_build_object('rows',prior.result,'already',true);
 end if;
 rc=cid;rs=s;
 for depth in 0..7 loop
  select * into f from uniion_private.message_forwards where organization_id=p_org and conversation=rc and seq=rs;
  exit when not found;rc=f.source_conversation;rs=f.source_seq;
  if depth=7 then raise insufficient_privilege;end if;
 end loop;
 foreach target in array targets loop
  if exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=target and author=auth.uid() and client_id=client) then raise insufficient_privilege;end if;
  item=public.uniion_messaging_before_search(p_org,'send',jsonb_build_object('id',target,'clientId',client,'text','Référence de message'));
  insert into uniion_private.message_forwards values(p_org,target,(item->>'seq')::bigint,cid,s);
  result=result||jsonb_build_array(jsonb_build_object('conversation',target,'seq',item->>'seq','id',item->>'id'));
 end loop;
 insert into uniion_private.message_forward_batches values(p_org,auth.uid(),client,cid,s,targets,result);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.forwarded_reference',jsonb_build_object('source',cid,'seq',s,'targets',targets,'clientId',client));
 return jsonb_build_object('rows',result,'already',false);
end$_$;


--
-- Name: uniion_messaging_before_mark_all(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging_before_mark_all(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare cid uuid;s bigint;p uuid;rows jsonb;state jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='read' then
  if not(p_payload ?& array['id','seq']) or p_payload-array['id','seq']<>'{}' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;
  perform 1 from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
  if not uniion_private.message_visible(p_org,cid,s) then raise insufficient_privilege;end if;
  select id into p from uniion_private.message_participations where organization_id=p_org and conversation=cid and user_id=auth.uid() and left_at is null;
  insert into uniion_private.message_reads values(p_org,cid,p,s,clock_timestamp()) on conflict(organization_id,conversation,participation) do update set seq=greatest(message_reads.seq,excluded.seq),read_at=case when excluded.seq>message_reads.seq then excluded.read_at else message_reads.read_at end;
  return jsonb_build_object('unread',uniion_private.message_unread(p_org,cid));
 elsif p_action='live' then
  if p_payload-array['id','at']<>'{}' then raise insufficient_privilege;end if;
  -- Only the caller's authorized projection influences the opaque resume cursor.
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'unread',uniion_private.message_unread(p_org,c.id),'revision',md5(uniion_private.message_conversation_json(p_org,c.id)::text||uniion_private.message_revision(p_org,c.id))) order by c.id),'[]') into rows from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id);
  state=jsonb_build_object('conversations',rows,'listing',public.uniion_messaging_before_live(p_org,'list','{}'),'notices',public.uniion_messaging(p_org,'notices','{}'));
  if p_payload ? 'at' and (not(p_payload ? 'id') or jsonb_typeof(p_payload->'at')<>'string' or (p_payload->>'at')!~'^[1-9][0-9]{0,17}$') then raise insufficient_privilege;end if;
  if p_payload ? 'id' then
   cid=(p_payload->>'id')::uuid;
   if uniion_private.message_member(p_org,cid) then state=state||jsonb_build_object('thread',public.uniion_messaging_before_live(p_org,case when p_payload ? 'at' then 'locate' else 'get' end,jsonb_build_object('id',cid)||case when p_payload ? 'at' then jsonb_build_object('seq',p_payload->>'at') else '{}'::jsonb end));else state=state||jsonb_build_object('thread',null);end if;
  end if;
  return state||jsonb_build_object('cursor',md5(state::text));
 elsif p_action='notices' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return coalesce((select jsonb_agg(x.notice order by x.created desc,x.id) from (select m.id,m.created_at created,jsonb_build_object('id',m.id,'conversation',m.conversation,'seq',m.seq::text,'title',uniion_private.message_conversation_json(p_org,m.conversation)->>'name','created',m.created_at) notice from uniion_private.messages m where m.organization_id=p_org and m.author<>auth.uid() and uniion_private.message_visible(p_org,m.conversation,m.seq) and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=p_org and r.conversation=m.conversation and p.user_id=auth.uid() and p.left_at is null),0) order by m.created_at desc,m.id limit 50)x),'[]');
 end if;
 return public.uniion_messaging_before_live(p_org,p_action,p_payload);
end$_$;


--
-- Name: uniion_messaging_before_notice_volume(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging_before_notice_volume(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare r record;
begin
 if p_action<>'read_all' then return public.uniion_messaging_before_mark_all(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if p_payload is distinct from '{}'::jsonb then raise insufficient_privilege;end if;
 for r in select m.conversation,max(m.seq) seq from uniion_private.messages m where m.organization_id=p_org and uniion_private.message_visible(p_org,m.conversation,m.seq) group by m.conversation order by m.conversation loop
  perform public.uniion_messaging_before_mark_all(p_org,'read',jsonb_build_object('id',r.conversation,'seq',r.seq::text));
 end loop;
 return jsonb_build_object('read',true);
end$$;


--
-- Name: uniion_messaging_before_search(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging_before_search(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare cv uniion_private.message_conversations;actor uniion_private.message_participations;target uniion_private.message_participations;cid uuid;u uuid;members uuid[];sequences bigint[];s bigint;k text;changed boolean:=false;event_name text;target_id uuid;reply jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action in ('participants','list','create','get','send') then return uniion_private.messaging_a(p_org,p_action,p_payload);end if;
 if p_action not in ('group_create','group_save','member_role','leave','history_grant','history_revoke') then raise insufficient_privilege;end if;
 if p_action in ('group_create','group_save') then
  if not(p_payload ?& array['name','desc','members']) or jsonb_typeof(p_payload->'name')<>'string' or length(btrim(p_payload->>'name')) not between 1 and 120 or length(p_payload->>'name')>120 or jsonb_typeof(p_payload->'desc')<>'string' or length(p_payload->>'desc')>2000 or jsonb_typeof(p_payload->'members')<>'array' or jsonb_array_length(p_payload->'members') not between 0 and 99 then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_array_elements(p_payload->'members') v where jsonb_typeof(v)<>'string') then raise insufficient_privilege;end if;
  select coalesce(array_agg(v::uuid order by v::uuid),array[]::uuid[]) into members from jsonb_array_elements_text(p_payload->'members')v;
  if cardinality(members)<>(select count(distinct x) from unnest(members)x) or auth.uid()=any(members) then raise insufficient_privilege;end if;
  foreach u in array members loop
   if not uniion_private.actor_member(p_org,u) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=u and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  end loop;
 end if;
 if p_action='group_create' then if cardinality(members)=0 then raise insufficient_privilege;end if;
  if not(p_payload ? 'clientId') or p_payload-array['clientId','name','desc','members']<>'{}' or jsonb_typeof(p_payload->'clientId')<>'string' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='create') then raise insufficient_privilege;end if;
  k='group:'||auth.uid()::text||':'||(p_payload->>'clientId')::uuid::text;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||k,0));
  select * into cv from uniion_private.message_conversations where organization_id=p_org and pair=k;
  if found then
   if cv.creation_payload is distinct from (p_payload||jsonb_build_object('members',to_jsonb(members))) or not uniion_private.message_member(p_org,cv.id) then raise insufficient_privilege;end if;
   return uniion_private.message_conversation_json(p_org,cv.id);
  end if;
  insert into uniion_private.message_conversations(organization_id,pair,kind,title,description,creation_payload) values(p_org,k,'group',btrim(p_payload->>'name'),p_payload->>'desc',p_payload||jsonb_build_object('members',to_jsonb(members))) returning id into cid;
  insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,is_admin) select p_org,cid,user_id,joined_at,user_id=auth.uid() from public.uniion_memberships where organization_id=p_org and (user_id=auth.uid() or user_id=any(members));
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.group_created',jsonb_build_object('conversation',cid,'members',cardinality(members)+1));
  return uniion_private.message_conversation_json(p_org,cid);
 end if;
 if not(p_payload ?& array['id','version']) or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'version')<>'number' or (p_payload->>'version') !~ '^[1-9][0-9]{0,8}$' then raise insufficient_privilege;end if;
 cid=(p_payload->>'id')::uuid;
 select * into cv from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
 if not found or not uniion_private.message_member(p_org,cid) or cv.version<>(p_payload->>'version')::integer then raise insufficient_privilege;end if;
 select * into actor from uniion_private.message_participations where organization_id=p_org and conversation=cid and user_id=auth.uid() and left_at is null;
 if p_action='group_save' then
  if cv.kind<>'group' or not actor.is_admin or p_payload-array['id','version','name','desc','members']<>'{}' then raise insufficient_privilege;end if;
  -- Removed/stale episodes are closed; an addition ALWAYS gets a fresh episode.
  update uniion_private.message_participations p set left_at=clock_timestamp() where p.organization_id=p_org and p.conversation=cid and p.left_at is null and p.user_id<>auth.uid() and (not(p.user_id=any(members)) or not uniion_private.message_current(p_org,cid,p.user_id));
  foreach u in array members loop
   if not uniion_private.message_current(p_org,cid,u) then
    insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from) select p_org,cid,user_id,joined_at,cv.next_seq+1 from public.uniion_memberships where organization_id=p_org and user_id=u;
   end if;
  end loop;
  update uniion_private.message_conversations set title=btrim(p_payload->>'name'),description=p_payload->>'desc' where organization_id=p_org and id=cid;
  event_name='members_changed';changed=true;
 elsif p_action='member_role' then
  if cv.kind<>'group' or not actor.is_admin or not(p_payload ?& array['participant','admin']) or p_payload-array['id','version','participant','admin']<>'{}' or jsonb_typeof(p_payload->'admin')<>'boolean' or jsonb_typeof(p_payload->'participant')<>'string' then raise insufficient_privilege;end if;
  u=(p_payload->>'participant')::uuid;
  if u=auth.uid() or not uniion_private.message_current(p_org,cid,u) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=u and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  update uniion_private.message_participations set is_admin=(p_payload->>'admin')::boolean where organization_id=p_org and conversation=cid and user_id=u and left_at is null;
  event_name='moderator_changed';changed=true;target_id=u;
 elsif p_action='leave' then
  if cv.kind<>'group' or p_payload-array['id','version']<>'{}' then raise insufficient_privilege;end if;
  if actor.is_admin and not exists(select 1 from uniion_private.message_participations p where p.organization_id=p_org and p.conversation=cid and p.user_id<>auth.uid() and p.left_at is null and p.is_admin and uniion_private.message_current(p_org,cid,p.user_id) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=p.user_id and module='messagerie' and permission='read')) then raise insufficient_privilege;end if;
  update uniion_private.message_participations set left_at=clock_timestamp() where organization_id=p_org and conversation=cid and id=actor.id;
  event_name='member_left';changed=true;target_id=auth.uid();
 else
  if not uniion_private.authority(p_org,auth.uid(),'history') or not(p_payload ? 'period') or jsonb_typeof(p_payload->'period')<>'string' then raise insufficient_privilege;end if;
  select * into target from uniion_private.message_participations where organization_id=p_org and conversation=cid and id=(p_payload->>'period')::uuid and left_at is null;
  if not found or target.user_id=auth.uid() or not uniion_private.message_current(p_org,cid,target.user_id) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=target.user_id and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  target_id=target.id;
  if p_action='history_grant' then
   if not(p_payload ? 'messages') or p_payload-array['id','version','period','messages']<>'{}' or jsonb_typeof(p_payload->'messages')<>'array' or jsonb_array_length(p_payload->'messages') not between 1 and 100 then raise insufficient_privilege;end if;
   if exists(select 1 from jsonb_array_elements(p_payload->'messages')v where jsonb_typeof(v)<>'string' or v#>>'{}' !~ '^[1-9][0-9]{0,17}$') then raise insufficient_privilege;end if;
   select array_agg(v::bigint) into sequences from jsonb_array_elements_text(p_payload->'messages')v;
   if cardinality(sequences)<>(select count(distinct x) from unnest(sequences)x) then raise insufficient_privilege;end if;
   foreach s in array sequences loop
    if not uniion_private.message_visible(p_org,cid,s) or not exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=cid and seq=s) then raise insufficient_privilege;end if;
    insert into uniion_private.message_history_grants(organization_id,conversation,participation,message_seq,granted_by) values(p_org,cid,target.id,s,auth.uid()) on conflict(organization_id,conversation,participation,message_seq) where revoked_at is null do nothing;
   end loop;
   event_name='history_granted';changed=true;
  else
   if p_payload-array['id','version','period']<>'{}' then raise insufficient_privilege;end if;
   update uniion_private.message_history_grants set revoked_at=clock_timestamp() where organization_id=p_org and conversation=cid and participation=target.id and revoked_at is null;
   event_name='history_revoked';changed=true;
  end if;
 end if;
 if changed then
  update uniion_private.message_conversations set version=version+1 where organization_id=p_org and id=cid;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.'||event_name,jsonb_build_object('conversation',cid,'version',cv.version+1,'target',target_id,'messages',sequences,'members',members));
 end if;
 if p_action='leave' then return jsonb_build_object('left',true);end if;
 return uniion_private.message_conversation_json(p_org,cid);
end$_$;


--
-- Name: uniion_messaging_before_search_volume(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_messaging_before_search_volume(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if p_action<>'notices' then return public.uniion_messaging_before_notice_volume(p_org,p_action,p_payload);end if;
 perform public.uniion_module_use(p_org,'messagerie');
 if p_payload is distinct from '{}'::jsonb then raise insufficient_privilege;end if;
 return (with candidates as materialized (
  select m.id,m.conversation,m.seq,m.created_at from uniion_private.messages m
  where m.organization_id=p_org and m.author<>auth.uid()
  and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=p_org and r.conversation=m.conversation and p.user_id=auth.uid() and p.left_at is null),0)
  and uniion_private.message_visible(p_org,m.conversation,m.seq)
  order by m.created_at desc,m.id limit 50
 ), titles as materialized (
  select c.conversation,uniion_private.message_conversation_before_live(p_org,c.conversation)->>'name' title from (select distinct conversation from candidates)c
 ) select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'conversation',m.conversation,'seq',m.seq::text,'title',t.title,'created',m.created_at) order by m.created_at desc,m.id),'[]'::jsonb) from candidates m join titles t using(conversation));
end$$;


--
-- Name: uniion_mfa_authorize_factor(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_mfa_authorize_factor(p_factor uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare job uuid;
BEGIN
 IF NOT uniion_private.identity_in_scope() THEN RAISE insufficient_privilege; END IF;
 perform 1 from auth.users where id=auth.uid() for update;
 if not exists(select 1 from auth.mfa_factors where id=p_factor and user_id=auth.uid() and status='unverified' and factor_type='totp') then raise insufficient_privilege;end if;
 if uniion_private.reenrollment_allowed() then
  select j.id into job from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active where j.user_id=auth.uid() and j.state='cleared' and j.expires_at>now() order by j.requested_at limit 1 for update of j;
  if not found then raise insufficient_privilege;end if;
  update uniion_private.lost_factor_jobs set state='enrolled',replacement_factor=p_factor where id=job;
  insert into uniion_private.trusted_mfa_factors(factor_id,user_id,valid_until) values(p_factor,auth.uid(),now()+interval '10 minutes');
 else
  if not uniion_private.session_allowed() or (exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid() and required) and auth.jwt()->>'aal' is distinct from 'aal2') then raise insufficient_privilege;end if;
  insert into uniion_private.trusted_mfa_factors(factor_id,user_id) values(p_factor,auth.uid()) on conflict do nothing;
 end if;
 return true;
end $$;


--
-- Name: uniion_mfa_recovery_approve(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_mfa_recovery_approve(p_request uuid, p_verification_reference text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare req uniion_private.mfa_recovery_requests;
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2'
 or not exists(select 1 from uniion_private.platform_operators where user_id=auth.uid() and active)
 or p_verification_reference is null or length(trim(p_verification_reference)) not between 12 and 200 then raise insufficient_privilege;end if;
 select * into req from uniion_private.mfa_recovery_requests where id=p_request for update;
 if not found or req.user_id=auth.uid() or req.approved_at is not null or req.expires_at<=now()
 or not exists(select 1 from auth.mfa_factors where id=req.factor_id and user_id=req.user_id and status='unverified') then raise insufficient_privilege;end if;
 -- Replace trust, not the user's credentials. Keep all records for audit.
 update uniion_private.trusted_mfa_factors set valid_until=now() where user_id=req.user_id;
 insert into uniion_private.trusted_mfa_factors(factor_id,user_id,valid_until) values(req.factor_id,req.user_id,now()+interval '30 minutes');
 update auth.sessions set not_after=now() where user_id=req.user_id;
 update uniion_private.mfa_recovery_requests set approved_by=auth.uid(),approved_at=now(),verification_reference=trim(p_verification_reference) where id=req.id;
 return jsonb_build_object('ok',true,'relogin_required',true,'activation_expires_in_seconds',1800);
end $$;


--
-- Name: uniion_mfa_recovery_request(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_mfa_recovery_request(p_factor uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ident uuid;
begin
 if not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now()))
 or not exists(select 1 from uniion_private.mfa_requirements where user_id=auth.uid() and required)
 or not exists(select 1 from auth.mfa_factors where id=p_factor and user_id=auth.uid() and status='unverified' and factor_type='totp') then raise insufficient_privilege;end if;
 if (select count(*) from uniion_private.mfa_recovery_requests where user_id=auth.uid() and expires_at>now() and approved_at is null)>=3 then raise insufficient_privilege;end if;
 insert into uniion_private.mfa_recovery_requests(user_id,factor_id) values(auth.uid(),p_factor) returning id into ident;
 return jsonb_build_object('id',ident,'expires_in_seconds',1800,'approval_required',true);
end $$;


--
-- Name: uniion_module_commercial(uuid, text, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_module_commercial(p_org uuid, p_module text, p_reason text, p_from timestamp with time zone, p_until timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare eid uuid;
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.super_admin() or p_reason is null or length(btrim(p_reason)) not between 1 and 240 or p_from is null or p_until is null or p_until<=p_from or p_until<=now() or not exists(select 1 from public.uniion_organizations where id=p_org and active) or not exists(select 1 from uniion_private.module_catalog where id=p_module and available) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized) then raise insufficient_privilege;end if;
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reason,created_by) values(p_org,p_module,'commercial',p_from,p_until,btrim(p_reason),auth.uid()) returning id into eid;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,'commercial.granted',auth.uid());return jsonb_build_object('id',eid);
end $$;


--
-- Name: uniion_module_config(uuid, text, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_module_config(p_org uuid, p_module text, p_action text, p_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or p_enabled is null or p_action is null or p_action not in ('catalog','authorize','delegate','enable') or not exists(select 1 from uniion_private.module_catalog where id=p_module) or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
if not uniion_private.super_admin() then
 if p_action<>'enable' or not uniion_private.authority(p_org,auth.uid(),'organization_edit') or not uniion_private.actor_member(p_org,auth.uid()) or not exists(select 1 from uniion_private.module_delegations where organization_id=p_org and id=p_module and enabled) then raise insufficient_privilege;end if;
end if;
if p_action='enable' and p_enabled and (not uniion_private.commercial_allowed(p_org,p_module) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized)) then raise insufficient_privilege;end if;
insert into public.uniion_module_access(organization_id,module,authorized,enabled,entitlement,valid_until) values(p_org,p_module,false,false,'commercial','infinity') on conflict do nothing;
if p_action='catalog' then update uniion_private.module_catalog set available=p_enabled where id=p_module;
elsif p_action='authorize' then update public.uniion_module_access set authorized=p_enabled where organization_id=p_org and module=p_module;
elsif p_action='delegate' then insert into uniion_private.module_delegations values(p_org,p_module,p_enabled) on conflict(organization_id,id) do update set enabled=excluded.enabled;
else update public.uniion_module_access set enabled=p_enabled where organization_id=p_org and module=p_module;end if;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,p_action||'.'||p_enabled::text,auth.uid());return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_module_revoke(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_module_revoke(p_org uuid, p_module text, p_entitlement uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
perform pg_advisory_xact_lock(72420943);
if not uniion_private.super_admin() then raise insufficient_privilege;end if;
update uniion_private.module_entitlements set revoked_at=now() where id=p_entitlement and organization_id=p_org and module=p_module and kind='commercial' and revoked_at is null;
if not found then raise insufficient_privilege;end if;
insert into uniion_private.module_events(organization_id,module,event,actor) values(p_org,p_module,'commercial.revoked',auth.uid());return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_module_use(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_module_use(p_org uuid, p_module text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.actor_member(p_org,auth.uid()) or not uniion_private.commercial_allowed(p_org,p_module) or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now()) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='read') then raise insufficient_privilege;end if;
return jsonb_build_object('allowed',true);
end $$;


--
-- Name: uniion_modules_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_modules_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare global_admin boolean=uniion_private.super_admin();
begin
if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not exists(select 1 from public.uniion_organizations where id=p_org and active) or not (global_admin or uniion_private.actor_member(p_org,auth.uid())) then raise insufficient_privilege;end if;
return jsonb_build_object('organizations',case when global_admin then (select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.uniion_organizations where active) else '[]'::jsonb end,'superAdmin',global_admin,'manage',uniion_private.authority(p_org,auth.uid(),'organization_edit'),'organization',(select name from public.uniion_organizations where id=p_org),'modules',(select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'available',c.available,'authorized',coalesce(a.authorized,false),'enabled',coalesce(a.enabled,false),'delegated',coalesce(d.enabled,false),'eligible',uniion_private.commercial_allowed(p_org,c.id),'canUse',uniion_private.actor_member(p_org,auth.uid()) and uniion_private.commercial_allowed(p_org,c.id) and coalesce(a.authorized and a.enabled and a.valid_until>now(),false) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=c.id and permission='read'),'entitlements',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'from',e.starts,'until',e.ends,'reason',e.reason,'reference',e.reference,'revoked',e.revoked_at) order by e.starts) from uniion_private.module_entitlements e where e.organization_id=p_org and e.module=c.id),'[]'::jsonb)) order by c.id) from uniion_private.module_catalog c left join public.uniion_module_access a on a.organization_id=p_org and a.module=c.id left join uniion_private.module_delegations d on d.organization_id=p_org and d.id=c.id));
end $$;


--
-- Name: uniion_partners_registry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_partners_registry() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
if not uniion_private.super_admin() then raise insufficient_privilege;end if;
return jsonb_build_object('organizations',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',active) order by name,id) from public.uniion_organizations),'[]'::jsonb),'partners',coalesce((select jsonb_agg(jsonb_build_object('source',source_id,'target',target_id,'active',active) order by source_id,target_id) from public.uniion_partners),'[]'::jsonb),'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.at desc,e.id desc) from (select id,source_id,target_id,enabled,at from uniion_private.partner_events order by at desc,id desc limit 100) e),'[]'::jsonb));
end $$;


--
-- Name: uniion_partners_save(uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_partners_save(p_source uuid, p_target uuid, p_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
if not uniion_private.super_admin() or p_source is null or p_target is null or p_source=p_target or p_enabled is null then raise insufficient_privilege;end if;
perform pg_advisory_xact_lock(72420946);
if not exists(select 1 from public.uniion_organizations where id=p_source and (active or not p_enabled)) or not exists(select 1 from public.uniion_organizations where id=p_target and (active or not p_enabled)) then raise insufficient_privilege;end if;
insert into public.uniion_partners(source_id,target_id,active) values(p_source,p_target,p_enabled) on conflict(source_id,target_id) do update set active=excluded.active;
insert into uniion_private.partner_events(source_id,target_id,enabled,actor) values(p_source,p_target,p_enabled,auth.uid());
return jsonb_build_object('ok',true,'business_access',false);
end $$;


--
-- Name: uniion_platform_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_platform_role() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$ select jsonb_build_object('superAdmin',coalesce(uniion_private.super_admin(),false)) $$;


--
-- Name: uniion_require_mfa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_require_mfa() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified') then raise insufficient_privilege;end if;
 insert into uniion_private.mfa_requirements values(auth.uid(),true) on conflict(user_id) do update set required=true;
 update uniion_private.trusted_mfa_factors set valid_until=null where user_id=auth.uid() and factor_id=(select factor_id from auth.sessions where id::text=auth.jwt()->>'session_id' and user_id=auth.uid());
 return true;
end $$;


--
-- Name: uniion_rights_batch(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_rights_batch(p_org uuid, p_user uuid, p_changes jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare c jsonb;k text;
begin
 if not uniion_private.identity_admin(p_org) or p_user=auth.uid() or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege;end if;
 if p_changes is null or jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes) not between 1 and 100 then raise insufficient_privilege;end if;
 for c in select value from jsonb_array_elements(p_changes) loop
 if jsonb_typeof(c)<>'object' or jsonb_typeof(c->'enabled') is distinct from 'boolean' or not(c?'type' and c?'permission') then raise insufficient_privilege;end if;
 for k in select jsonb_object_keys(c) loop
 if k<>all(array['type','module','permission','enabled','resource','until','history']) then raise insufficient_privilege;end if;end loop;
 if c?'history' and jsonb_typeof(c->'history')<>'boolean' then raise insufficient_privilege;end if;
 perform public.uniion_rights_change(p_org,p_user,c->>'type',c->>'module',c->>'permission',(c->>'enabled')::boolean,(c->>'resource')::uuid,(c->>'until')::timestamptz,coalesce((c->>'history')::boolean,false));
 end loop;
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_rights_change(uuid, uuid, text, text, text, boolean, uuid, timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_rights_change(p_org uuid, p_user uuid, p_type text, p_module text, p_permission text, p_enabled boolean, p_resource uuid DEFAULT NULL::uuid, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_history boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare mine uuid=auth.uid();r public.uniion_resources;g public.uniion_resource_grants;
begin
 if not uniion_private.identity_admin(p_org) or p_enabled is null or p_history is null or p_type is null or p_permission is null then raise insufficient_privilege;end if;
 if mine=p_user or not uniion_private.authority(p_org,mine,'rights') or not uniion_private.actor_member(p_org,p_user) then raise insufficient_privilege; end if;
 if p_type='agenda_audience' then
  perform public.uniion_module_use(p_org,'agenda');
  if not uniion_private.authority(p_org,mine,'agenda_audience') or p_permission not in ('elus','adherents','public','none') or (not p_enabled and p_permission<>'none') or (p_enabled and p_permission='none') then raise insufficient_privilege;end if;
  if p_enabled and not exists(select 1 from uniion_private.agenda_audiences where organization_id=p_org and user_id=mine and (audience='elus' or (audience='adherents' and p_permission in ('adherents','public')) or (audience='public' and p_permission='public'))) then raise insufficient_privilege;end if;
  insert into uniion_private.agenda_audiences values(p_org,p_user,p_permission) on conflict(organization_id,user_id) do update set audience=excluded.audience;
  update uniion_private.agenda_reminders j set status='cancelled',finished_at=now() from uniion_private.agenda_events e where e.id=j.event_id and e.organization_id=p_org and j.user_id=p_user and j.status='pending' and not uniion_private.agenda_recipient_allowed(e.id,p_user);
 elsif p_type='permission' then
  if p_module is null or not exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now() and uniion_private.commercial_allowed(organization_id,module)) then raise insufficient_privilege;end if;
  if p_permission not in ('read','write','create') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=mine and module=p_module and permission=p_permission) then raise insufficient_privilege; end if;
  if p_enabled then insert into public.uniion_permissions values(p_org,p_user,p_module,p_permission) on conflict do nothing;
  else delete from public.uniion_permissions where organization_id=p_org and user_id=p_user and module=p_module and permission=p_permission; end if;
 elsif p_type='authority' then
  if not exists(select 1 from public.uniion_authorities where organization_id=p_org and user_id=mine and permission=p_permission and delegable) then raise insufficient_privilege; end if;
  if p_enabled then insert into public.uniion_authorities values(p_org,p_user,p_permission,false) on conflict do nothing;
  else delete from public.uniion_authorities where organization_id=p_org and user_id=p_user and permission=p_permission; end if;
 elsif p_type='resource' then
  select * into r from public.uniion_resources where id=p_resource and organization_id=p_org;
  if not found or not uniion_private.actor_resource(p_org,p_resource,mine,false) then raise insufficient_privilege; end if;
  select * into g from public.uniion_resource_grants where organization_id=p_org and resource_id=p_resource and user_id=mine;
  if p_permission not in ('read','write') or (p_permission='write' and not uniion_private.actor_resource(p_org,p_resource,mine,true)) then raise insufficient_privilege; end if;
  if p_enabled then
   if g.user_id is null or g.revoked_at is not null or g.valid_until is null then raise insufficient_privilege;end if;
   if p_until is null or p_until<=now() or p_until>g.valid_until or (p_history and not uniion_private.authority(p_org,mine,'history')) then raise insufficient_privilege; end if;
   -- No automatic historical unlock: a resource predating membership requires its own permission.
   insert into public.uniion_resource_grants values(p_org,p_resource,p_user,p_permission='write',p_history,p_until,null)
   on conflict(organization_id,resource_id,user_id) do update set can_write=excluded.can_write,history_approved=excluded.history_approved,valid_until=excluded.valid_until,revoked_at=null;
  else update public.uniion_resource_grants set revoked_at=now() where organization_id=p_org and resource_id=p_resource and user_id=p_user; end if;
 else raise insufficient_privilege;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,mine,'rights.changed',jsonb_build_object('user',p_user,'type',p_type,'module',p_module,'permission',p_permission,'enabled',p_enabled,'resource',p_resource,'until',p_until,'history',p_history));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_save(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_save(p_org uuid, p_changes jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare c jsonb; r public.uniion_resources; mod text; new_id uuid; result jsonb='[]'::jsonb;
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege; end if;
 if jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes)>100 then raise check_violation; end if;
 for c in select value from jsonb_array_elements(p_changes) loop
  mod=case c->>'kind' when 'dossiers' then 'socle' when 'docs' then 'socle' when 'pollsData' then 'sondages' when 'reunions' then 'reunions' else null end;
  if mod is null or jsonb_typeof(c->'body')<>'object' or coalesce(length(c->>'client_id'),0) not between 1 and 100 or c->'body'->>'id' is distinct from c->>'client_id' or octet_length((c->'body')::text)>100000 then raise check_violation; end if;
  if coalesce(length(c->'body'->>'title'),0) not between 1 and 300 then raise check_violation; end if;
  if c->>'kind'='dossiers' and (jsonb_typeof(c->'body'->'timeline') is distinct from 'array' or c->'body'->>'status' not in ('todo','doing','done') or c->'body'->>'status' is null) then raise check_violation; end if;
  if c->>'kind'='docs' and jsonb_typeof(c->'body'->'blocks') is distinct from 'array' then raise check_violation; end if;
  if c->>'kind'='reunions' and (jsonb_typeof(c->'body'->'markers') is distinct from 'array' or jsonb_typeof(c->'body'->'ordre') is distinct from 'array') then raise check_violation; end if;
  if c->>'kind'='pollsData' then raise insufficient_privilege; end if; -- Publication/answers require dedicated commands.
  if not exists(select 1 from public.uniion_module_access a join public.uniion_permissions p using(organization_id,module) where a.organization_id=p_org and a.module=mod and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module) and p.user_id=auth.uid() and p.permission='write') then raise insufficient_privilege; end if;
  select * into r from public.uniion_resources where organization_id=p_org and kind=c->>'kind' and client_id=c->>'client_id' for update;
  if found then
   if c->>'kind'='docs' and c->'body'->>'status' is distinct from r.body->>'status' then raise insufficient_privilege; end if;
   if c->>'kind'='reunions' and (c->'body'->>'pv' is distinct from r.body->>'pv' or c->'body'->>'audio' is distinct from r.body->>'audio') then raise insufficient_privilege; end if;
   if not uniion_private.resource_access(p_org,r.id,true) then raise insufficient_privilege; end if;
   if (c->>'version')::integer is distinct from r.version then raise exception 'Version conflict' using errcode='40001'; end if;
   update public.uniion_resources set body=c->'body',title=left(coalesce(c->'body'->>'title',c->'body'->>'titre','Sans titre'),300),version=version+1 where id=r.id returning * into r;
  else
   if c->>'kind'='docs' and c->'body'->>'status' is distinct from 'Brouillon' then raise insufficient_privilege; end if;
   if c->>'kind'='reunions' then raise insufficient_privilege; end if; -- Audio storage not connected.
   if c->>'version' is not null or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=mod and permission='create') then raise insufficient_privilege; end if;
   insert into public.uniion_resources(organization_id,module,kind,client_id,title,body) values(p_org,mod,c->>'kind',c->>'client_id',left(coalesce(c->'body'->>'title',c->'body'->>'titre','Sans titre'),300),c->'body') returning * into r;
   insert into public.uniion_resource_grants values(p_org,r.id,auth.uid(),true,false,now()+interval '365 days',null);
  end if;
  insert into public.uniion_events(organization_id,actor,resource_id,event,version) values(p_org,auth.uid(),r.id,'save',r.version);
  result=result||jsonb_build_array(jsonb_build_object('id',r.id,'kind',r.kind,'client_id',r.client_id,'version',r.version));
 end loop;
 return result;
end $$;


--
-- Name: uniion_scan_job(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_scan_job(p_attachment uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment;
 if not found then raise insufficient_privilege;end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256,'generation',a.scan_generation);
end $$;


--
-- Name: uniion_scan_request(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_scan_request(p_org uuid, p_attachment uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments;
begin
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org for update;
 if not found or not uniion_private.actor_resource(p_org,a.resource_id,auth.uid(),true) then raise insufficient_privilege;end if;
 if not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name and (metadata->>'size')::bigint=a.size) then raise insufficient_privilege;end if;
 if a.scanned_at is null then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.uploaded',jsonb_build_object('attachment',a.id,'resource',a.resource_id,'quarantined',true));end if;
 update public.uniion_attachments set ready=false,scan_status='pending',scan_reason=null,scan_generation=gen_random_uuid() where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'attachment.scan_requested',jsonb_build_object('attachment',a.id));
 return jsonb_build_object('id',a.id);
end $$;


--
-- Name: uniion_scan_result(uuid, text, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_scan_result(p_attachment uuid, p_sha256 text, p_status text, p_engine text, p_reason text, p_generation uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare a public.uniion_attachments;
begin
 if not uniion_private.is_scanner() or p_status not in ('clean','infected','invalid','error') or length(coalesce(p_engine,''))>250 or length(coalesce(p_reason,''))>250 then raise insufficient_privilege;end if;
 select * into a from public.uniion_attachments where id=p_attachment for update;
 if not found or a.sha256<>p_sha256 or a.scan_status<>'pending' or a.scan_generation is distinct from p_generation then raise insufficient_privilege;end if;
 update public.uniion_attachments set ready=(p_status='clean'),scan_status=p_status,scanned_at=now(),scan_engine=p_engine,scan_reason=p_reason where id=a.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(a.organization_id,auth.uid(),'attachment.scan_'||p_status,jsonb_build_object('attachment',a.id,'engine',p_engine,'generation',p_generation));
 return jsonb_build_object('id',a.id,'filename',a.filename,'scan_status',p_status);
end $$;


--
-- Name: uniion_session_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_session_status() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('active',exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now())),
 'aal',coalesce(auth.jwt()->>'aal','aal1'),
 'required',exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') or exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required),
 'allowed',uniion_private.session_allowed(),'enrollment_allowed',uniion_private.reenrollment_allowed())
$$;


--
-- Name: uniion_share_accept(uuid, uuid, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_share_accept(p_org uuid, p_share uuid, p_people uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare s public.uniion_shares;person uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.target_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'accept') or s.revoked_at is not null or s.expires_at<=now() or s.accepted_at is not null or not uniion_private.authority(s.source_id,s.creator,'share') then raise insufficient_privilege; end if;
 if coalesce(cardinality(p_people),0)=0 or not p_people<@s.allowed then raise insufficient_privilege; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_org,person) then raise insufficient_privilege; end if; end loop;
 update public.uniion_shares set beneficiaries=p_people,accepted_at=now(),accepted_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.accepted',jsonb_build_object('share',p_share,'people',p_people));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_share_create(uuid, uuid, uuid[], uuid[], timestamp with time zone, boolean, jsonb, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_share_create(p_org uuid, p_target uuid, p_resources uuid[], p_people uuid[], p_until timestamp with time zone, p_download boolean DEFAULT false, p_versions jsonb DEFAULT NULL::jsonb, p_attachments uuid[] DEFAULT '{}'::uuid[]) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare sid uuid;aid uuid;a public.uniion_attachments;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 if p_attachments is null or cardinality(p_attachments)>20 then raise check_violation;end if;
 sid=public.uniion_share_create_core(p_org,p_target,p_resources,p_people,p_until,p_download,p_versions);
 foreach aid in array p_attachments loop
  select * into a from public.uniion_attachments where id=aid and organization_id=p_org and ready;
  if not found or not a.resource_id=any(p_resources) or not uniion_private.attachment_access(a.id,auth.uid()) then raise insufficient_privilege;end if;
  insert into public.uniion_share_attachments values(sid,a.resource_id,a.id);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,auth.uid(),'share.files_selected',jsonb_build_object('share',sid,'attachments',p_attachments));
 return sid;
end $$;


--
-- Name: uniion_share_create_core(uuid, uuid, uuid[], uuid[], timestamp with time zone, boolean, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_share_create_core(p_org uuid, p_target uuid, p_resources uuid[], p_people uuid[], p_until timestamp with time zone, p_download boolean DEFAULT false, p_versions jsonb DEFAULT NULL::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare sid uuid;res uuid;person uuid;mine uuid=auth.uid();r public.uniion_resources;
begin
 if not uniion_private.authority(p_org,mine,'share') or p_org=p_target or not exists(select 1 from public.uniion_partners where active and source_id=p_org and target_id=p_target) or (p_download and not uniion_private.authority(p_org,mine,'download')) then raise insufficient_privilege; end if;
 if p_until is null or p_until<=now() or p_until>now()+interval '90 days' or coalesce(cardinality(p_resources),0) not between 1 and 20 or coalesce(cardinality(p_people),0) not between 1 and 20 then raise check_violation; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_target,person) then raise insufficient_privilege; end if; end loop;
 insert into public.uniion_shares(source_id,target_id,creator,allowed,expires_at,download) values(p_org,p_target,mine,p_people,p_until,p_download) returning id into sid;
 foreach res in array p_resources loop
  select * into r from public.uniion_resources where id=res and organization_id=p_org;
  if not found or not r.external_share_allowed or not uniion_private.actor_resource(p_org,res,mine,false) then raise insufficient_privilege; end if;
  if p_versions is null or (p_versions->>res::text)::integer is distinct from r.version then raise exception 'Resource version changed' using errcode='40001'; end if;
  insert into public.uniion_share_items values(sid,p_org,res,r.version);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,mine,'share.created',jsonb_build_object('share',sid,'resources',p_resources,'people',p_people,'download',p_download,'expires',p_until));
 return sid;
end $$;


--
-- Name: uniion_share_revoke(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_share_revoke(p_org uuid, p_share uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare s public.uniion_shares;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.source_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege; end if;
 update public.uniion_shares set revoked_at=coalesce(revoked_at,now()),revoked_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.revoked',jsonb_build_object('share',p_share));
 return jsonb_build_object('ok',true);
end $$;


--
-- Name: uniion_shared_check(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_shared_check(p_org uuid, p_share uuid, p_resource uuid, p_download boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_shares where id=p_share and target_id=p_org)
 and uniion_private.share_access(p_share,p_resource,auth.uid(),p_download)
$$;


--
-- Name: uniion_shared_read(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_shared_read(p_org uuid, p_share uuid, p_resource uuid, p_download boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 result=public.uniion_shared_read_files(p_org,p_share,p_resource,p_download);
 return result||jsonb_build_object('attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'mime',a.mime,'scan_status',a.scan_status,'downloadable',uniion_private.attachment_access(a.id,auth.uid(),p_share),'previewable',uniion_private.attachment_preview(a.id,auth.uid(),p_share))) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=p_share and sa.resource_id=p_resource),'[]'::jsonb));
end $$;


--
-- Name: uniion_shared_read_core(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_shared_read_core(p_org uuid, p_share uuid, p_resource uuid, p_download boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare s public.uniion_shares;result jsonb;
begin
 select * into s from public.uniion_shares where id=p_share;
 if not found or s.target_id<>p_org or not uniion_private.share_access(p_share,p_resource,auth.uid(),p_download) then raise insufficient_privilege; end if;
 select jsonb_build_object('id',r.id,'title',v.body->>'title','body',v.body,'version',v.version,'source',s.source_id,'expires',s.expires_at)
 into result from public.uniion_share_items i join public.uniion_resources r on r.id=i.resource_id join public.uniion_resource_versions v on v.organization_id=i.organization_id and v.resource_id=i.resource_id and v.version=i.version where i.share_id=p_share and i.resource_id=p_resource;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),case when p_download then 'share.downloaded' else 'share.read' end,jsonb_build_object('share',p_share,'resource',p_resource));
 return result;
end $$;


--
-- Name: uniion_shared_read_files(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_shared_read_files(p_org uuid, p_share uuid, p_resource uuid, p_download boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;
begin
 result=public.uniion_shared_read_core(p_org,p_share,p_resource,p_download);
 return result||jsonb_build_object('kind',(select kind from public.uniion_resources where id=p_resource),'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'mime',a.mime,'downloadable',uniion_private.attachment_access(a.id,auth.uid(),p_share))) from public.uniion_share_attachments sa join public.uniion_attachments a on a.id=sa.attachment_id where sa.share_id=p_share and sa.resource_id=p_resource),'[]'::jsonb));
end $$;


--
-- Name: uniion_support_approve(uuid, uuid, uuid[], uuid[], timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_approve(p_org uuid, p_ticket uuid, p_agents uuid[], p_resources uuid[], p_until timestamp with time zone, p_download boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin perform pg_advisory_xact_lock(72420942);return public.uniion_support_approve_before_registry(p_org,p_ticket,p_agents,p_resources,p_until,p_download);end $$;


--
-- Name: uniion_support_approve_before_registry(uuid, uuid, uuid[], uuid[], timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_approve_before_registry(p_org uuid, p_ticket uuid, p_agents uuid[], p_resources uuid[], p_until timestamp with time zone, p_download boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.support_tickets;gid uuid;r public.uniion_resources;rid uuid;uid uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') or p_download is null or (p_download and not uniion_private.authority(p_org,auth.uid(),'download')) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;
 if not found or t.state<>'open' or p_until is null or p_until<=now() or p_until>now()+interval '90 days' or coalesce(cardinality(p_agents),0) not between 1 and 20 or coalesce(cardinality(p_resources),0) not between 1 and 20 then raise insufficient_privilege;end if;
 foreach uid in array p_agents loop if uid is null or not uniion_private.support_assigned(t.id,uid) then raise insufficient_privilege;end if;end loop;
 insert into uniion_private.support_grants(ticket,agents,expires,download,creator) values(t.id,p_agents,p_until,p_download,auth.uid()) returning id into gid;
 foreach rid in array p_resources loop
 select * into r from public.uniion_resources where id=rid and organization_id=p_org;
 if not found or not r.external_share_allowed or not uniion_private.actor_resource(p_org,rid,auth.uid(),false) then raise insufficient_privilege;end if;
 insert into uniion_private.support_items values(gid,r.id,r.version,r.title,r.body);
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.approved',jsonb_build_object('ticket',t.id,'grant',gid,'agents',p_agents,'resources',p_resources,'expires',p_until,'download',p_download));
 return jsonb_build_object('id',gid);
end $$;


--
-- Name: uniion_support_approve_files(uuid, uuid, uuid[], uuid[], timestamp with time zone, boolean, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_approve_files(p_org uuid, p_ticket uuid, p_agents uuid[], p_resources uuid[], p_until timestamp with time zone, p_download boolean, p_attachments uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;fid uuid;a public.uniion_attachments;
begin
 if p_attachments is null or cardinality(p_attachments)>20 then raise insufficient_privilege;end if;
 result=public.uniion_support_approve(p_org,p_ticket,p_agents,p_resources,p_until,p_download);
 foreach fid in array p_attachments loop
 select * into a from public.uniion_attachments where id=fid and organization_id=p_org;
 if not found or not(a.resource_id=any(p_resources)) or not a.ready or a.scan_status<>'clean' then raise insufficient_privilege;end if;
 insert into uniion_private.support_files values((result->>'id')::uuid,a.id,a.sha256);
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.files.selected',jsonb_build_object('ticket',p_ticket,'grant',result->>'id','attachments',p_attachments));
 return result;
end $$;


--
-- Name: uniion_support_assign(uuid, uuid, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_assign(p_org uuid, p_ticket uuid, p_agents uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin perform pg_advisory_xact_lock(72420942);return public.uniion_support_assign_before_registry(p_org,p_ticket,p_agents);end $$;


--
-- Name: uniion_support_assign_before_registry(uuid, uuid, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_assign_before_registry(p_org uuid, p_ticket uuid, p_agents uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare u uuid;removed uuid[];
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') or p_agents is null or cardinality(p_agents)>20 then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;if not found then raise insufficient_privilege;end if;
 foreach u in array p_agents loop if u is null or not exists(select 1 from uniion_private.support_agents where user_id=u and active) then raise insufficient_privilege;end if;end loop;
 select coalesce(array_agg(user_id),'{}') into removed from uniion_private.support_assignments where ticket=p_ticket and active and not(user_id=any(p_agents));
 update uniion_private.support_assignments set active=false where ticket=p_ticket and user_id=any(removed);
 -- Preserve history and permanently exclude removed agents from existing grants.
 update uniion_private.support_grants set excluded=array(select distinct v from unnest(excluded||removed) v) where ticket=p_ticket and agents&&removed;
 update uniion_private.support_requests set status='cancelled' where ticket=p_ticket and agent=any(removed) and status='pending';
 foreach u in array p_agents loop insert into uniion_private.support_assignments(ticket,user_id,active) values(p_ticket,u,true) on conflict(ticket,user_id) do update set active=true;end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.assigned',jsonb_build_object('ticket',p_ticket,'agents',p_agents,'removed',removed));
 return jsonb_build_object('assigned',p_agents,'business_access',false);
end $$;


--
-- Name: uniion_support_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_context(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;ts jsonb='[]';gs jsonb;t jsonb;g jsonb;files jsonb;
begin
 result=public.uniion_support_context_without_files(p_org);
 result=result||jsonb_build_object('attachments',case when (result->>'manage')::boolean then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'resource',a.resource_id,'filename',a.filename)) from public.uniion_attachments a where a.organization_id=p_org and a.ready and a.scan_status='clean' and exists(select 1 from jsonb_array_elements(result->'resources') r where r->>'id'=a.resource_id::text)),'[]') else '[]'::jsonb end);
 for t in select value from jsonb_array_elements(result->'tickets') loop
 gs='[]';
 for g in select value from jsonb_array_elements(t->'grants') loop
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'size',a.size,'previewable',a.ready and a.scan_status='clean' and a.mime in ('application/pdf','image/png','image/jpeg'),'downloadable',a.ready and a.scan_status='clean' and (g->>'download')::boolean)),'[]') into files from uniion_private.support_files f join public.uniion_attachments a on a.id=f.attachment where f.grant_id=(g->>'id')::uuid and exists(select 1 from jsonb_array_elements(g->'items') i where i->>'id'=a.resource_id::text);
 gs=gs||jsonb_build_array(g||jsonb_build_object('attachments',files));end loop;
 ts=ts||jsonb_build_array(t||jsonb_build_object('grants',gs));end loop;
 return result||jsonb_build_object('tickets',ts);
end $$;


--
-- Name: uniion_support_context_without_files(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_context_without_files(p_org uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare manage boolean;member boolean;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 member=uniion_private.member(p_org);manage=uniion_private.authority(p_org,auth.uid(),'share');
 if not member and not exists(select 1 from uniion_private.support_tickets t where t.organization_id=p_org and uniion_private.support_assigned(t.id,auth.uid())) then raise insufficient_privilege;end if;
 return jsonb_build_object('availableAgents',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',name) order by name) from uniion_private.support_agents where active),'[]') else '[]'::jsonb end,'actor',auth.uid(),'organization',(select name from public.uniion_organizations where id=p_org),'manage',manage,'member',member,
 'resources',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.title)) from public.uniion_resources r where r.organization_id=p_org and r.external_share_allowed and uniion_private.actor_resource(p_org,r.id,auth.uid(),false)),'[]') else '[]'::jsonb end,
 'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'state',t.state,'staff',uniion_private.support_assigned(t.id,auth.uid()),'agents',coalesce((select jsonb_agg(jsonb_build_object('id',a.user_id,'name',a.name)) from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t.id and x.active and a.active and (manage or a.user_id=auth.uid())),'[]'),
 'requests',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'agent',q.agent,'reason',q.reason,'status',q.status) order by q.created_at) from uniion_private.support_requests q where q.ticket=t.id and (manage or q.agent=auth.uid())),'[]'),'grants',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'agents',g.agents,'excluded',case when manage then to_jsonb(g.excluded) else '[]'::jsonb end,'expires',g.expires,'download',g.download,'revoked',g.revoked_at is not null or g.agents<@g.excluded or (not manage and auth.uid()=any(g.excluded)),'items',case when manage or (t.state='open' and not(auth.uid()=any(g.excluded)) and g.revoked_at is null and g.expires>now() and uniion_private.authority(p_org,g.creator,'share')) then coalesce((select jsonb_agg(jsonb_build_object('id',i.resource,'name',i.title,'version',i.version)) from uniion_private.support_items i where i.grant_id=g.id and (manage or uniion_private.actor_resource(p_org,i.resource,g.creator,false))),'[]') else '[]'::jsonb end)) from uniion_private.support_grants g where g.ticket=t.id and (manage or auth.uid()=any(g.agents))),'[]')) order by t.created_at desc,t.id) from uniion_private.support_tickets t where t.organization_id=p_org and (manage or t.created_by=auth.uid() or uniion_private.support_assigned(t.id,auth.uid()))),'[]'));
end $$;


--
-- Name: uniion_support_create(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_create(p_org uuid, p_title text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare tid uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or p_title is null or length(btrim(p_title)) not between 1 and 120 then raise insufficient_privilege;end if;
 insert into uniion_private.support_tickets(organization_id,title,created_by) values(p_org,btrim(p_title),auth.uid()) returning id into tid;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.created',jsonb_build_object('ticket',tid));
 return jsonb_build_object('id',tid,'state','open');
end $$;


--
-- Name: uniion_support_file_get(uuid, uuid, uuid, uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_file_get(p_org uuid, p_ticket uuid, p_grant uuid, p_attachment uuid, p_preview boolean, p_audit boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin
 if uniion_private.case_file_trashed(p_attachment) then raise insufficient_privilege;end if;
 return public.uniion_support_file_get_before_trash(p_org,p_ticket,p_grant,p_attachment,p_preview,p_audit);
end$$;


--
-- Name: uniion_support_file_get_before_trash(uuid, uuid, uuid, uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_file_get_before_trash(p_org uuid, p_ticket uuid, p_grant uuid, p_attachment uuid, p_preview boolean, p_audit boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.support_tickets;g uniion_private.support_grants;i uniion_private.support_items;a public.uniion_attachments;p_resource uuid;p_download boolean;
begin
 if p_preview is null or p_audit is null then raise insufficient_privilege;end if;p_download=not p_preview;
 select * into a from public.uniion_attachments where id=p_attachment and organization_id=p_org;
 if not found or not a.ready or a.scan_status<>'clean' or (p_preview and a.mime not in ('application/pdf','image/png','image/jpeg')) or not exists(select 1 from uniion_private.support_files where grant_id=p_grant and attachment=a.id and sha256=a.sha256) then raise insufficient_privilege;end if;
 p_resource=a.resource_id;
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_download is null or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for share;
 if not found or t.state<>'open' or not uniion_private.support_assigned(t.id,auth.uid()) then raise insufficient_privilege;end if;
 select * into g from uniion_private.support_grants where id=p_grant and ticket=t.id for share;
 if not found or g.revoked_at is not null or auth.uid()=any(g.excluded) or g.expires<=now() or not(auth.uid()=any(g.agents)) or (p_download and not g.download) or not uniion_private.authority(p_org,g.creator,'share') or (p_download and not uniion_private.authority(p_org,g.creator,'download')) then raise insufficient_privilege;end if;
 select * into i from uniion_private.support_items where grant_id=g.id and resource=p_resource;
 if not found or not uniion_private.actor_resource(p_org,p_resource,g.creator,false) or not exists(select 1 from public.uniion_resources where id=p_resource and organization_id=p_org and external_share_allowed) then raise insufficient_privilege;end if;
 if p_audit then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_preview then 'support.file.previewed' else 'support.file.downloaded' end,jsonb_build_object('ticket',t.id,'grant',g.id,'attachment',a.id));end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'filename',a.filename,'mime',a.mime,'size',a.size,'sha256',a.sha256);
end $$;


--
-- Name: uniion_support_read(uuid, uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_read(p_org uuid, p_ticket uuid, p_grant uuid, p_resource uuid, p_download boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.support_tickets;g uniion_private.support_grants;i uniion_private.support_items;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_download is null or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for share;
 if not found or t.state<>'open' or not uniion_private.support_assigned(t.id,auth.uid()) then raise insufficient_privilege;end if;
 select * into g from uniion_private.support_grants where id=p_grant and ticket=t.id for share;
 if not found or g.revoked_at is not null or auth.uid()=any(g.excluded) or g.expires<=now() or not(auth.uid()=any(g.agents)) or (p_download and not g.download) or not uniion_private.authority(p_org,g.creator,'share') or (p_download and not uniion_private.authority(p_org,g.creator,'download')) then raise insufficient_privilege;end if;
 select * into i from uniion_private.support_items where grant_id=g.id and resource=p_resource;
 if not found or not uniion_private.actor_resource(p_org,p_resource,g.creator,false) or not exists(select 1 from public.uniion_resources where id=p_resource and organization_id=p_org and external_share_allowed) then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_download then 'support.downloaded' else 'support.read' end,jsonb_build_object('ticket',t.id,'grant',g.id,'resource',i.resource));
 return jsonb_build_object('title',i.title,'version',i.version,'body',i.body);
end $$;


--
-- Name: uniion_support_registry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_registry() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.super_admin() then raise insufficient_privilege;end if;
 return jsonb_build_object('agents',coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',name,'active',active) order by name,user_id) from uniion_private.support_agents),'[]'));
end $$;


--
-- Name: uniion_support_registry_save(uuid, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_registry_save(p_user uuid, p_name text, p_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if not uniion_private.super_admin() or p_user is null or p_name is null or length(btrim(p_name)) not between 1 and 120 or p_enabled is null or not exists(select 1 from auth.users where id=p_user and email_confirmed_at is not null) then raise insufficient_privilege;end if;
 -- Serialize registry changes with assignment and grant creation.
 perform pg_advisory_xact_lock(72420942);
 insert into uniion_private.support_agents(user_id,name,active) values(p_user,btrim(p_name),p_enabled) on conflict(user_id) do update set name=excluded.name,active=excluded.active;
 if not p_enabled then
 update uniion_private.support_assignments set active=false where user_id=p_user and active;
 update uniion_private.support_grants set excluded=array(select distinct v from unnest(excluded||array[p_user]) v) where p_user=any(agents);
 update uniion_private.support_requests set status='cancelled' where agent=p_user and status='pending';
 end if;
 insert into uniion_private.platform_events(actor,event,subject) values(auth.uid(),case when p_enabled then 'support.agent.enabled' else 'support.agent.disabled' end,p_user);
 return jsonb_build_object('id',p_user,'active',p_enabled,'business_access',false);
end $$;


--
-- Name: uniion_support_reject(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_reject(p_org uuid, p_ticket uuid, p_request uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;if not found then raise insufficient_privilege;end if;
 update uniion_private.support_requests set status='rejected' where id=p_request and ticket=p_ticket and status='pending';if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.rejected',jsonb_build_object('ticket',p_ticket,'request',p_request));return jsonb_build_object('status','rejected');
end $$;


--
-- Name: uniion_support_request(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_request(p_org uuid, p_ticket uuid, p_reason text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare q uuid;
begin
 perform pg_advisory_xact_lock(72420942);
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or p_reason is null or length(btrim(p_reason)) not between 1 and 240 or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org and state='open' for update;
 if not found or not uniion_private.support_assigned(p_ticket,auth.uid()) or exists(select 1 from uniion_private.support_requests where ticket=p_ticket and agent=auth.uid() and status='pending') then raise insufficient_privilege;end if;
 insert into uniion_private.support_requests(ticket,agent,reason) values(p_ticket,auth.uid(),btrim(p_reason)) returning id into q;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.requested',jsonb_build_object('ticket',p_ticket,'request',q));return jsonb_build_object('id',q,'status','pending');
end $$;


--
-- Name: uniion_support_revoke(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_revoke(p_org uuid, p_ticket uuid, p_grant uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege;end if;
 perform 1 from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;if not found then raise insufficient_privilege;end if;
 update uniion_private.support_grants set revoked_at=now() where id=p_grant and ticket=p_ticket and revoked_at is null;if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.revoked',jsonb_build_object('ticket',p_ticket,'grant',p_grant));return true;
end $$;


--
-- Name: uniion_support_status(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_support_status(p_org uuid, p_ticket uuid, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare t uniion_private.support_tickets;manager boolean;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() or not exists(select 1 from public.uniion_organizations where id=p_org and active) then raise insufficient_privilege;end if;
 manager=uniion_private.authority(p_org,auth.uid(),'share');
 select * into t from uniion_private.support_tickets where id=p_ticket and organization_id=p_org for update;
 if not found or not(manager or uniion_private.support_assigned(t.id,auth.uid())) then raise insufficient_privilege;end if;
 if p_action='close' and t.state='open' then
 update uniion_private.support_tickets set state='closed',closed_at=now(),closed_by=auth.uid() where id=t.id;
 update uniion_private.support_grants set revoked_at=now() where ticket=t.id and revoked_at is null;
 elsif p_action='reopen' and t.state='closed' and manager then update uniion_private.support_tickets set state='open' where id=t.id;
 else raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'support.'||p_action,jsonb_build_object('ticket',t.id));
 return jsonb_build_object('id',t.id,'state',case when p_action='close' then 'closed' else 'open' end,'business_access',false);
end $$;


--
-- Name: uniion_transcription(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_transcription(p_org uuid, p_meeting uuid, p_audio uuid, p_action text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ids uuid[];key text;j uniion_private.transcription_jobs;a uniion_private.meeting_audio;aid uuid;rec uuid;
begin
 if p_action is null or p_action not in ('start','status','cancel','retry') then raise insufficient_privilege;end if;
 perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',p_audio,'audit',false));
 select recording_id into rec from uniion_private.meeting_audio_sequences where audio_id=p_audio;
 select array_agg(f.id order by coalesce(s.position,0),f.id) into ids from uniion_private.meeting_audio f left join uniion_private.meeting_audio_sequences s on s.audio_id=f.id where f.organization_id=p_org and f.meeting_id=p_meeting and (case when rec is null then f.id=p_audio else s.recording_id=rec end);
 foreach aid in array ids loop perform public.uniion_meeting_audio(p_org,p_meeting,'listen',jsonb_build_object('audio',aid,'audit',false));end loop;
 key=array_to_string(ids,',');
 if p_action<>'status' then perform public.uniion_meeting_audio(p_org,p_meeting,'write','{}');end if;
 if p_action='start' then
  insert into uniion_private.transcription_jobs(organization_id,meeting_id,requester,source_ids,source_key) values(p_org,p_meeting,auth.uid(),ids,key) on conflict do nothing;
 end if;
 select * into j from uniion_private.transcription_jobs where organization_id=p_org and meeting_id=p_meeting and requester=auth.uid() and source_key=key for update;
 if not found then return jsonb_build_object('state','absent');end if;
 if p_action='start' then
  insert into uniion_private.transcription_parts(job_id,id,sha256,consent_version,meeting_version,offset_ms,duration_ms)
  select j.id,f.id,f.sha256,f.consent_version,f.meeting_version,coalesce(s.offset_ms,0),f.duration_ms from uniion_private.meeting_audio f left join uniion_private.meeting_audio_sequences s on s.audio_id=f.id where f.id=any(ids) on conflict do nothing;
 elsif p_action='cancel' and j.state in ('pending','running','error') then
  update uniion_private.transcription_jobs set state='cancelled',lease=null,worker=null,updated_at=now() where id=j.id returning * into j;
 elsif p_action='retry' and j.state in ('error','cancelled') then
  update uniion_private.transcription_jobs set state='pending',lease=null,worker=null,error=null,updated_at=now() where id=j.id returning * into j;
 end if;
 if p_action<>'status' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.transcription.'||p_action,jsonb_build_object('meeting',p_meeting,'job',j.id));end if;
 return jsonb_build_object('id',j.id,'state',j.state,'error',j.error,'total',cardinality(ids),'completed',(select count(*) from uniion_private.transcription_parts where job_id=j.id and result is not null),'parts',case when j.state='done' then (select jsonb_agg(jsonb_build_object('audio',id,'offsetMs',offset_ms,'result',result) order by offset_ms,id) from uniion_private.transcription_parts where job_id=j.id) else '[]'::jsonb end);
end$$;


--
-- Name: uniion_transcription_worker(text, uuid, uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uniion_transcription_worker(p_action text, p_job uuid DEFAULT NULL::uuid, p_lease uuid DEFAULT NULL::uuid, p_audio uuid DEFAULT NULL::uuid, p_result jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare j uniion_private.transcription_jobs;p uniion_private.transcription_parts;s jsonb;
begin
 if not uniion_private.session_allowed() or not exists(select 1 from uniion_private.transcription_workers where user_id=auth.uid()) or p_action is null or p_action not in ('claim','next','finish','error') then raise insufficient_privilege;end if;
 if p_action='claim' then
  -- R34 : une tâche en attente dont les sources ne sont plus valides (réunion modifiée, consentement
  -- re-signé, droits retirés) n'est plus jamais traitée. Elle passe en erreur, visible, au lieu
  -- d'être réévaluée à chaque prise en charge (au plus 50 par appel).
  update uniion_private.transcription_jobs t set state='error',error='sources_changed',lease=null,worker=null,updated_at=now()
   where t.id in (select q.id from uniion_private.transcription_jobs q where q.state='pending' and not uniion_private.transcription_valid(q) order by q.updated_at limit 50 for update skip locked);
  select * into j from uniion_private.transcription_jobs q where (state='pending' or state='running' and updated_at<now()-interval '6 minutes') and uniion_private.transcription_valid(q) order by updated_at for update skip locked limit 1;
  if not found then return '{}'::jsonb;end if;
  update uniion_private.transcription_jobs set state='running',lease=gen_random_uuid(),worker=auth.uid(),updated_at=now(),error=null where id=j.id returning * into j;
  return jsonb_build_object('id',j.id,'lease',j.lease);
 end if;
 select * into j from uniion_private.transcription_jobs where id=p_job and state='running' and lease=p_lease and worker=auth.uid() and updated_at>now()-interval '6 minutes' for update;
 if not found or not uniion_private.transcription_valid(j) then raise insufficient_privilege;end if;
 if p_action='error' then
  update uniion_private.transcription_jobs set state='error',error='local_engine_unavailable',lease=null,worker=null,updated_at=now() where id=j.id;return jsonb_build_object('ok',true);
 end if;
 if p_action='finish' then
  select * into p from uniion_private.transcription_parts where job_id=j.id and id=p_audio and result is null for update;
  if not found or p_result is null or jsonb_typeof(p_result) is distinct from 'object' or p_result-array['engine','model','segments']<>'{}' or p_result->>'engine' is distinct from 'faster-whisper/1.2.1' or p_result->>'model' is distinct from 'ebe41f70d5b6dfa9166e2c581c45c9c0cfc57b66' or jsonb_typeof(p_result->'segments') is distinct from 'array' or octet_length(p_result::text)>200000 then raise insufficient_privilege;end if;
  for s in select value from jsonb_array_elements(p_result->'segments') loop
   if jsonb_typeof(s) is distinct from 'object' or jsonb_typeof(s->'startMs') is distinct from 'number' or jsonb_typeof(s->'endMs') is distinct from 'number' or (s->>'startMs') !~ '^[0-9]{1,9}$' or (s->>'endMs') !~ '^[0-9]{1,9}$' or jsonb_typeof(s->'text') is distinct from 'string' or length(s->>'text')>10000 or (s->>'startMs')::bigint<0 or (s->>'endMs')::bigint>(p.duration_ms) or (s->>'endMs')::bigint<=(s->>'startMs')::bigint or not(s ?& array['startMs','endMs','text']) then raise insufficient_privilege;end if;
  end loop;
  update uniion_private.transcription_parts set result=p_result where job_id=j.id and id=p_audio;
 end if;
 update uniion_private.transcription_jobs set updated_at=now() where id=j.id;
 select * into p from uniion_private.transcription_parts where job_id=j.id and result is null order by offset_ms,id limit 1;
 if not found then
  update uniion_private.transcription_jobs set state='done',lease=null,worker=null where id=j.id;
  return jsonb_build_object('done',true);
 end if;
 return (select jsonb_build_object('audio',a.id,'path',a.path,'sha256',p.sha256,'size',a.size) from uniion_private.meeting_audio a where a.id=p.id);
end$_$;


--
-- Name: actor_member(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_member(org uuid, who uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
 select uniion_private.session_allowed() and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=who and m.revoked_at is null and m.joined_at<=now() and o.active) and not exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=org and s.user_id=who and s.suspended)
); end$$;


--
-- Name: actor_resource(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_resource(org uuid, res uuid, who uuid, wr boolean DEFAULT false) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare d uniion_private.meeting_minutes;
begin
 select * into d from uniion_private.meeting_minutes where resource_id=res and organization_id=org;
 if not found then return uniion_private.actor_resource_before_minutes(org,res,who,wr);end if;
 -- Source access is cumulative. No generic grant or support role bypasses this gate.
 return uniion_private.minutes_sources_allowed(org,d.meeting_id,d.job_id,who)
 and uniion_private.actor_resource_before_minutes(org,d.meeting_id,who,wr);
end$$;


--
-- Name: actor_resource_before_ai_case(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_resource_before_ai_case(org uuid, res uuid, who uuid, wr boolean DEFAULT false) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare f uniion_private.message_files;
begin
 select * into f from uniion_private.message_files where resource=res;
 if not found then return uniion_private.actor_resource_before_messages(org,res,who,wr);end if;
 if f.organization_id<>org or not uniion_private.message_current(org,f.conversation,who) then return false;end if;
 -- module_use authenticates the actual caller. Authority checks for a requester at approval use the same module state.
 if not uniion_private.session_allowed() or auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.commercial_allowed(org,'messagerie') or not exists(select 1 from public.uniion_module_access where organization_id=org and module='messagerie' and authorized and enabled and valid_until>now()) or not exists(select 1 from public.uniion_permissions where organization_id=org and user_id=who and module='messagerie' and permission='read') then return false;end if;
 return exists(select 1 from public.uniion_permissions where organization_id=org and user_id=who and module='messagerie' and permission=case when wr then 'write' else 'read' end)
 and exists(select 1 from uniion_private.message_participations p where p.organization_id=org and p.conversation=f.conversation and p.user_id=who and p.left_at is null and (f.seq>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=org and g.conversation=f.conversation and g.participation=p.id and g.message_seq=f.seq and g.revoked_at is null)))
 and (not wr or exists(select 1 from uniion_private.messages m where m.organization_id=org and m.conversation=f.conversation and m.seq=f.seq and m.author=who));
exception when insufficient_privilege then return false;
end$$;


--
-- Name: actor_resource_before_disposal(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_resource_before_disposal(org uuid, res uuid, who uuid, wr boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.actor_member(org,who) and exists(select 1 from public.uniion_resources r
 join public.uniion_resource_grants g on g.organization_id=r.organization_id and g.resource_id=r.id
 join public.uniion_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id
 join public.uniion_module_access a on a.organization_id=r.organization_id and a.module=r.module
 join public.uniion_permissions p on p.organization_id=g.organization_id and p.user_id=g.user_id and p.module=r.module
 where r.organization_id=org and r.id=res and g.user_id=who and g.revoked_at is null and g.valid_until>now()
 and (r.created_at>=m.joined_at or g.history_approved) and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)
 and p.permission=case when wr then 'write' else 'read' end and (not wr or g.can_write))
$$;


--
-- Name: actor_resource_before_messages(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_resource_before_messages(org uuid, res uuid, who uuid, wr boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$ select not uniion_private.case_disposed(res) and uniion_private.actor_resource_before_disposal(org,res,who,wr) $$;


--
-- Name: actor_resource_before_minutes(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.actor_resource_before_minutes(org uuid, res uuid, who uuid, wr boolean DEFAULT false) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare d uniion_private.ai_case_derivatives;
begin
 if not uniion_private.actor_resource_before_ai_case(org,res,who,wr) then return false;end if;
 select * into d from uniion_private.ai_case_derivatives where resource=res;
 if not found then return true;end if;
 -- A private conversation stays private even if a generic grant is added.
 return d.organization_id=org and d.actor=who and who=auth.uid() and uniion_private.ai_refs_readable(org,d.refs);
end$$;


--
-- Name: adherent_date(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherent_date(p_text text) RETURNS date
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $_$
declare t text=trim(coalesce(p_text,'')); d date; parts text[];
begin
 if t ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then
  parts=string_to_array(t,'/'); d=make_date(parts[3]::int,parts[2]::int,parts[1]::int);
 elsif t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  parts=string_to_array(t,'-'); d=make_date(parts[1]::int,parts[2]::int,parts[3]::int);
 else return null;end if;
 return d;
exception when datetime_field_overflow then return null;
end $_$;


--
-- Name: adherent_dues(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherent_dues(p_text text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $_$
declare t text=lower(trim(coalesce(p_text,''))); m text[];
begin
 if t='' then return jsonb_build_object('status','empty');end if;
 m=regexp_match(t,'^([0-9]{1,9})([.,]([0-9]{1,2}))?[[:space:]]*(€|eur)([[:space:]]*/[[:space:]]*(mois|trimestre|an))?$');
 if m is null then return jsonb_build_object('status','review');end if;
 return jsonb_build_object('status','valid','cents',m[1]::bigint*100+coalesce(rpad(m[3],2,'0'),'0')::int,'currency','EUR','period',case m[6] when 'mois' then 'month' when 'trimestre' then 'quarter' when 'an' then 'year' else null end);
end $_$;


--
-- Name: adherent_payload(jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherent_payload(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $_$
declare d jsonb; k text;
begin
if jsonb_typeof(p_data) is distinct from 'object' or p_data-array['prenom','nom','email','tel','poste','ent','etab','sect','dir','mandat','since','mode','montant']<>'{}'::jsonb or not(p_data ?& array['prenom','nom','email','ent','etab']) or exists(select 1 from jsonb_each(p_data) where jsonb_typeof(value)<>'string' or length(value#>>'{}')>300) then raise insufficient_privilege;end if;
select jsonb_object_agg(key,trim(value#>>'{}')) into d from jsonb_each(p_data);
foreach k in array array['prenom','nom','ent','etab'] loop if length(d->>k)=0 then raise insufficient_privilege;end if;end loop;
if d->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise insufficient_privilege;end if;
d=jsonb_build_object('tel','','poste','','sect','','dir','','mandat','','since','','mode','','montant','')||d||jsonb_build_object('email',lower(d->>'email'));
return d;
end $_$;


--
-- Name: adherent_permission(uuid, text, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherent_permission(p_org uuid, p_module text, p_permission text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
select exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission=p_permission)
 and exists(select 1 from public.uniion_module_access where organization_id=p_org and module=p_module and authorized and enabled and valid_until>now())
 and (p_module<>'cotisations' or p_permission='read' or exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module=p_module and permission='read'))
$$;


--
-- Name: adherent_validate_typed(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherent_validate_typed() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
 if tg_op='INSERT' or new.data->>'since' is distinct from old.data->>'since' then
  if coalesce(new.data->>'since','')<>'' and uniion_private.adherent_date(new.data->>'since') is null then raise insufficient_privilege;end if;
 end if;
 if tg_op='INSERT' or new.data->>'montant' is distinct from old.data->>'montant' then
  if uniion_private.adherent_dues(new.data->>'montant')->>'status'='review' then raise insufficient_privilege;end if;
 end if;
 return new;
end $$;


--
-- Name: adherents_register(uuid, text, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.adherents_register(p_org uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare old uniion_private.adherents; d jsonb; rowdata jsonb; count_added integer=0; financial boolean; ids jsonb='[]';
begin
perform public.uniion_module_use(p_org,'adherents');
financial=uniion_private.adherent_permission(p_org,'cotisations','read');
if p_action='import' then
 if not uniion_private.adherent_permission(p_org,'adherents','create') or jsonb_typeof(p_payload) is distinct from 'array' or jsonb_array_length(p_payload) not between 1 and 100 then raise insufficient_privilege;end if;
 for rowdata in select value from jsonb_array_elements(p_payload) loop
  d=uniion_private.adherent_payload(rowdata);
  if (d->>'mode'<>'' or d->>'montant'<>'') and not uniion_private.adherent_permission(p_org,'cotisations','write') then raise insufficient_privilege;end if;
  insert into uniion_private.adherents(organization_id,data) values(p_org,d) returning * into old;
  ids=ids||jsonb_build_array(old.id);count_added=count_added+1;
 end loop;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherents.imported',jsonb_build_object('count',count_added,'ids',ids));
elsif p_action='save' then
 if not uniion_private.adherent_permission(p_org,'adherents','write') or jsonb_typeof(p_payload) is distinct from 'object' or p_payload-array['id','version','data']<>'{}' or not(p_payload ?& array['id','version','data']) then raise insufficient_privilege;end if;
 select * into old from uniion_private.adherents where organization_id=p_org and id=(p_payload->>'id')::uuid for update;
 if not found or old.version is distinct from (p_payload->>'version')::int then raise insufficient_privilege;end if;
 d=uniion_private.adherent_payload(p_payload->'data');
 if not uniion_private.adherent_permission(p_org,'cotisations','write') then
  if (p_payload->'data') ? 'mode' or (p_payload->'data') ? 'montant' then raise insufficient_privilege;end if;
  d=d||jsonb_build_object('mode',old.data->>'mode','montant',old.data->>'montant');
 end if;
 update uniion_private.adherents set data=d,version=version+1,updated_at=now() where id=old.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'adherent.saved',jsonb_build_object('id',old.id,'version',old.version+1));
elsif p_action<>'list' or p_payload<>'{}'::jsonb then raise insufficient_privilege;end if;
return jsonb_build_object('rows',coalesce((select jsonb_agg((case when financial then data else data-array['mode','montant'] end)||jsonb_build_object('id',id,'version',version,'joinedOn',joined_on,'dateNeedsReview',coalesce(data->>'since','')<>'' and joined_on is null)||(case when financial then jsonb_build_object('dues',dues_terms) else '{}'::jsonb end) order by data->>'nom',data->>'prenom',id) from uniion_private.adherents where organization_id=p_org),'[]'::jsonb),'financial',financial,'financialWrite',financial and uniion_private.adherent_permission(p_org,'cotisations','write'));
exception when unique_violation then raise insufficient_privilege;
end $$;


--
-- Name: agenda_claim(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_claim() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare j uniion_private.agenda_reminders; address text;
begin
perform uniion_private.agenda_enqueue();
-- R25 : un rappel resté « en cours d'envoi » (worker interrompu) devient incertain, visible, sans renvoi.
update uniion_private.agenda_reminders set status='uncertain',finished_at=now() where status='sending' and coalesce(sending_at,created_at)<now()-interval '15 minutes';
select * into j from uniion_private.agenda_reminders where status='pending' order by created_at for update skip locked limit 1;
if not found then return null;end if;
select email into address from auth.users where id=j.user_id;
if address !~ '^[^[:space:]@]+@(uniion-local[.]example|example[.]invalid)$' then update uniion_private.agenda_reminders set status='cancelled',finished_at=now() where id=j.id;return jsonb_build_object('skipped',true);end if;
update uniion_private.agenda_reminders set status='sending',sending_at=now() where id=j.id;
return jsonb_build_object('id',j.id,'email',address);
end;$_$;


--
-- Name: agenda_document_charter(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_document_charter() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare org uuid;name text;detail jsonb;
begin
 select organization_id into org from uniion_private.agenda_events where id=new.event_id;
 select o.name,coalesce(d.details,'{}'::jsonb) into name,detail from public.uniion_organizations o left join uniion_private.organization_details d on d.organization_id=o.id where o.id=org;
 new.document=new.document||jsonb_build_object('charte',jsonb_build_object('accent','#DC2626','ink','#111827','titleFont','philosopher','bodyFont','inter','density','standard','logo','uniion-logo.png','header',true,'footer',true,'caps',false,'emetteur',coalesce(nullif(detail->>'sigle',''),name),'section',coalesce(nullif(split_part(detail->>'adresse',',',1),''),name),'email',coalesce(detail->>'email',''),'phone','03 27 14 88 20','emetteurOverride',true));
 return new;
end;$$;


--
-- Name: agenda_document_recipient(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_document_recipient(p_event uuid, p_user uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
select uniion_private.agenda_recipient_allowed(p_event,p_user) and exists(select 1 from uniion_private.agenda_events e join public.uniion_permissions p on p.organization_id=e.organization_id and p.user_id=p_user and p.module='documents' and p.permission='read' join public.uniion_module_access m on m.organization_id=e.organization_id and m.module='documents' and m.authorized and m.enabled and m.valid_until>now() where e.id=p_event and uniion_private.commercial_allowed(e.organization_id,'documents'));
$$;


--
-- Name: agenda_enqueue(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_enqueue() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare n integer;
begin
update uniion_private.agenda_reminders j set status='cancelled',finished_at=now() where status='pending' and not exists(select 1 from uniion_private.agenda_events e where e.id=j.event_id and e.version=j.version and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_recipient_allowed(e.id,j.user_id));
insert into uniion_private.agenda_reminders(event_id,version,user_id)
select e.id,e.version,a.user_id from uniion_private.agenda_events e join uniion_private.agenda_audiences a on a.organization_id=e.organization_id where e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris' >now() and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris' <=now()+interval '48 hours' and uniion_private.agenda_recipient_allowed(e.id,a.user_id) on conflict do nothing;
get diagnostics n=row_count;return n;
end;$$;


--
-- Name: agenda_file_check(uuid, jsonb, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_file_check(p_org uuid, p_files jsonb, p_user uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare item jsonb;a public.uniion_attachments;total bigint=0;
begin
if jsonb_typeof(p_files) is distinct from 'array' or jsonb_array_length(p_files)>5 then raise insufficient_privilege;end if;
for item in select value from jsonb_array_elements(p_files) loop
 select * into a from public.uniion_attachments where id=(item->>'id')::uuid and organization_id=p_org;
 if not found or not a.ready or a.scan_status<>'clean' or a.sha256 is distinct from item->>'sha256' or not uniion_private.attachment_access(a.id,p_user) then raise insufficient_privilege;end if;
 total=total+a.size;
end loop;
if total>10485760 then raise insufficient_privilege;end if;
end;$$;


--
-- Name: agenda_finish(uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_finish(p_id uuid, p_ok boolean) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
update uniion_private.agenda_reminders set status=case when p_ok then 'sent' else 'uncertain' end,finished_at=now() where id=p_id and status='sending';
$$;


--
-- Name: agenda_image_allowed(uuid, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_image_allowed(p_event uuid, p_image text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select p_image is not null and (p_image in ('','uniion-logo.png') or exists(select 1 from uniion_private.agenda_image_receipts where event_id=p_event and digest=encode(extensions.digest(p_image,'sha256'),'hex')))
$$;


--
-- Name: agenda_preflight(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_preflight(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare valid boolean;
begin
select exists(select 1 from uniion_private.agenda_reminders j join uniion_private.agenda_events e on e.id=j.event_id where j.id=p_id and j.status='sending' and j.version=e.version and e.data->>'rappel'='true' and ((e.data->>'date')::date+(e.data->>'start')::time) at time zone 'Europe/Paris'>now() and uniion_private.agenda_recipient_allowed(e.id,j.user_id)) into valid;
if not valid then update uniion_private.agenda_reminders set status='cancelled',finished_at=now() where id=p_id and status='sending';end if;
return valid;
end;$$;


--
-- Name: agenda_publication_notify(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_publication_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if new.published_at is not null and (tg_op='INSERT' or old.published_at is null) then
 insert into uniion_private.agenda_publication_notifications(event_id,version,user_id)
 select new.event_id,new.version,m.user_id from public.uniion_memberships m join uniion_private.agenda_events e on e.organization_id=m.organization_id where e.id=new.event_id and uniion_private.agenda_document_recipient(e.id,m.user_id) on conflict do nothing;
 end if;return new;
end;$$;


--
-- Name: agenda_recipient_allowed(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_recipient_allowed(p_event uuid, p_user uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
select exists(select 1 from uniion_private.agenda_events e join uniion_private.agenda_audiences a on a.organization_id=e.organization_id and a.user_id=p_user where e.id=p_event and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=e.organization_id and m.user_id=p_user and m.revoked_at is null and m.joined_at<=now() and o.active) and not exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=e.organization_id and s.user_id=p_user and s.suspended) and uniion_private.commercial_allowed(e.organization_id,'agenda') and exists(select 1 from public.uniion_module_access where organization_id=e.organization_id and module='agenda' and authorized and enabled and valid_until>now()) and exists(select 1 from public.uniion_permissions where organization_id=e.organization_id and user_id=p_user and module='agenda' and permission='read') and (a.audience='elus' or (a.audience='adherents' and e.data->>'visib' in ('adherents','public')) or (a.audience='public' and e.data->>'visib'='public')));
$$;


--
-- Name: agenda_visible(uuid, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_visible(p_org uuid, p_data jsonb) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
select exists(select 1 from uniion_private.agenda_audiences where organization_id=p_org and user_id=auth.uid() and (audience='elus' or (audience='adherents' and p_data->>'visib' in ('adherents','public')) or (audience='public' and p_data->>'visib'='public')));
$$;


--
-- Name: agenda_work_core(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.agenda_work_core(p_org uuid, p_event uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare stale_count integer;e uniion_private.agenda_events;d uniion_private.agenda_documents;ident uuid;person uuid;people uuid[];doc jsonb;rows jsonb;item jsonb;
begin
perform public.uniion_module_use(p_org,'agenda');
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise insufficient_privilege;end if;
if p_action in ('document','save_document') then
 perform public.uniion_module_use(p_org,'documents');
 select * into d from uniion_private.agenda_documents where event_id=p_event for update;
 if p_action='document' then
  if p_payload<>'{}'::jsonb then raise insufficient_privilege;end if;
  if not found then
   if not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='create') then raise insufficient_privilege;end if;
   ident=gen_random_uuid();doc=jsonb_build_object('id',ident,'title','Ordre du jour — '||(e.data->>'title'),'model','cr','format','a4','status','Brouillon','updated','à l’instant','blocks',jsonb_build_array(jsonb_build_object('id',ident||'-1','type','h1','text','Ordre du jour — '||(e.data->>'title')),jsonb_build_object('id',ident||'-2','type','p','text',(e.data->>'date')||' · '||(e.data->>'start')||' — '||(e.data->>'end')||' · '||(e.data->>'lieu')),jsonb_build_object('id',ident||'-3','type','h2','text','Participants'),jsonb_build_object('id',ident||'-4','type','p','text','À compléter'),jsonb_build_object('id',ident||'-5','type','h2','text','Points à examiner'),jsonb_build_object('id',ident||'-6','type','p','text',coalesce(nullif(e.data->>'notes',''),'À compléter'))));
   insert into uniion_private.agenda_documents(event_id,id,source_version,document,updated_by) values(p_event,ident,e.version,doc,auth.uid()) on conflict(event_id) do nothing;
   select * into d from uniion_private.agenda_documents where event_id=p_event;
  end if;
 else
  if d.id is null or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') or (p_payload->>'version')::integer is distinct from d.version or p_payload-array['version','document']<>'{}'::jsonb then raise insufficient_privilege;end if;
  doc=p_payload->'document';if octet_length(doc::text)>8388608 then raise insufficient_privilege;end if;
  if jsonb_typeof(doc)<>'object' or not(doc ?& array['title','format','blocks']) or doc-array['title','format','blocks','charte','style','styleOpts']<>'{}'::jsonb or jsonb_typeof(doc->'title')<>'string' or length(trim(doc->>'title')) not between 1 and 200 or doc->>'format' not in ('a4','a5','square','story','wide') or jsonb_typeof(doc->'blocks')<>'array' or jsonb_array_length(doc->'blocks') not between 1 and 100 then raise insufficient_privilege;end if;
  
 if doc ? 'charte' then
  item=doc->'charte';
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']) or item-array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']<>'{}'::jsonb then raise insufficient_privilege;end if;
  if (item->>'accent') !~ '^#[0-9a-fA-F]{6}$' or (item->>'ink') !~ '^#[0-9a-fA-F]{6}$' or item->>'titleFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'bodyFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'density' not in ('standard','compact','confort') or not uniion_private.agenda_image_allowed(p_event,item->>'logo') then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_each(item) x where (x.key in ('header','footer','caps','emetteurOverride') and jsonb_typeof(x.value) is distinct from 'boolean') or (x.key not in ('header','footer','caps','emetteurOverride') and (jsonb_typeof(x.value) is distinct from 'string' or length(x.value#>>'{}')>case when x.key='logo' then 2800000 else 300 end))) then raise insufficient_privilege;end if;
 end if;
 
 if doc ? 'style' and doc->'style'<>'null'::jsonb and (jsonb_typeof(doc->'style')<>'string' or doc->>'style' not in ('choc','journal','infographie','institutionnel','photo','serigraphie','bulletin','qr','satirique','bd','annonce','retro')) then raise insufficient_privilege;end if;
 if doc ? 'styleOpts' then
  if jsonb_typeof(doc->'styleOpts') is distinct from 'object' or (doc->'styleOpts')-array['palette','font']<>'{}'::jsonb then raise insufficient_privilege;end if;
  for item in select value from jsonb_each(doc->'styleOpts') loop
   if jsonb_typeof(item) is distinct from 'number' or (item#>>'{}') !~ '^[0-9]+$' then raise insufficient_privilege;end if;
  end loop;
  if coalesce((doc->'styleOpts'->>'palette')::int,0)>=(case doc->>'style' when 'choc' then 4 when 'journal' then 4 when 'infographie' then 4 when 'institutionnel' then 4 when 'photo' then 3 when 'serigraphie' then 4 when 'bulletin' then 4 when 'qr' then 4 when 'satirique' then 3 when 'bd' then 3 when 'annonce' then 2 when 'retro' then 3 else 1 end) or coalesce((doc->'styleOpts'->>'font')::int,0)>=(case doc->>'style' when 'choc' then 3 when 'journal' then 3 when 'infographie' then 3 when 'institutionnel' then 3 when 'photo' then 3 when 'serigraphie' then 3 when 'bulletin' then 3 when 'qr' then 3 when 'satirique' then 2 when 'bd' then 2 when 'annonce' then 2 when 'retro' then 2 else 1 end) then raise insufficient_privilege;end if;
 end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop
  if item ? 'img' and not uniion_private.agenda_image_allowed(p_event,item->>'img') then raise insufficient_privilege;end if;
  if item->>'type'='studio.photo' and ltrim(item->>'text', E' \n\t\r') ~ '^(https?:|data:)' then raise insufficient_privilege;end if;

   if jsonb_typeof(item)<>'object' or item-array['id','type','text','img']<>'{}'::jsonb or not(item ?& array['id','type','text']) or jsonb_typeof(item->'text')<>'string' or length(item->>'text')>8000 or item->>'type' not in ('h1','h2','h3','p','ul','quote','table','tag','pagebreak','studio.chiffre','studio.compare','studio.frise','studio.photo','studio.qr','studio.coupon','studio.trombi','studio.tampon','studio.surligne','studio.signature','studio.bulles','studio.exige') then raise insufficient_privilege;end if;
  end loop;
  update uniion_private.agenda_documents set document=document||doc,version=version+1,updated_by=auth.uid(),updated_at=now() where event_id=p_event returning * into d;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.document.'||p_action,jsonb_build_object('id',d.id,'version',d.version));
 return jsonb_build_object('document',d.document,'version',d.version,'sourceVersion',d.source_version,'canWrite',exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write'));
end if;
if not uniion_private.authority(p_org,auth.uid(),'agenda_convocation') then raise insufficient_privilege;end if;
if p_action='recipients' then
 if p_payload<>'{}'::jsonb then raise insufficient_privilege;end if;
 return jsonb_build_object('event',e.data||jsonb_build_object('id',e.id,'version',e.version),'people',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email,'email',u.email)) from auth.users u where u.email ~ '^[^[:space:]@]+@(uniion-local[.]example|example[.]invalid)$' and uniion_private.agenda_recipient_allowed(p_event,u.id)),'[]'::jsonb));
elsif p_action='prepare' then
 if p_payload-array['id','version','people','subject','body']<>'{}'::jsonb or not(p_payload ?& array['id','version','people','subject','body']) or (p_payload->>'version')::integer<>e.version or jsonb_typeof(p_payload->'people')<>'array' or jsonb_array_length(p_payload->'people') not between 1 and 20 or length(trim(p_payload->>'subject')) not between 1 and 200 or length(trim(p_payload->>'body')) not between 1 and 6000 then raise insufficient_privilege;end if;
 ident=(p_payload->>'id')::uuid;select array_agg(value::uuid) into people from jsonb_array_elements_text(p_payload->'people');
 foreach person in array people loop
  if not uniion_private.agenda_recipient_allowed(p_event,person) or not exists(select 1 from auth.users where id=person and email ~ '^[^[:space:]@]+@(uniion-local[.]example|example[.]invalid)$') then raise insufficient_privilege;end if;
 end loop;
 insert into uniion_private.agenda_convocations values(ident,p_event,e.version,auth.uid(),p_payload-array['id','people','version'],now()) on conflict do nothing;
 if not found then
  -- R25 : au rejeu, les destinataires restés « en cours d'envoi » plus de 10 minutes deviennent
  -- incertains et sont comptés ; ils ne sont pas renvoyés (au plus une fois).
  with stale as (update uniion_private.agenda_convocation_deliveries d set status='uncertain' from uniion_private.agenda_convocations c
   where d.convocation=ident and c.id=ident and d.status='sending' and c.created_at<now()-interval '10 minutes' returning 1)
  select count(*) into stale_count from stale;
  return jsonb_build_object('deliveries','[]'::jsonb,'replayed',true,'uncertain',stale_count);
 end if;
 insert into uniion_private.agenda_convocation_deliveries(convocation,user_id) select ident,unnest(people) on conflict do nothing;
 select jsonb_agg(jsonb_build_object('user',u.id,'email',u.email)) into rows from auth.users u where u.id=any(people);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.convocation.prepared',jsonb_build_object('id',ident,'count',cardinality(people)));
 return jsonb_build_object('deliveries',rows,'subject',p_payload->>'subject','body',p_payload->>'body','replayed',false);
elsif p_action in ('check','finish') then
 if p_payload-array['id','user','ok']<>'{}'::jsonb then raise insufficient_privilege;end if;
 ident=(p_payload->>'id')::uuid;person=(p_payload->>'user')::uuid;
 if not exists(select 1 from uniion_private.agenda_convocations c join uniion_private.agenda_convocation_deliveries t on t.convocation=c.id where c.id=ident and c.event_id=p_event and c.actor=auth.uid() and c.event_version=e.version and t.user_id=person and t.status='sending') or not uniion_private.agenda_recipient_allowed(p_event,person) then raise insufficient_privilege;end if;
 if p_action='finish' then
  if jsonb_typeof(p_payload->'ok') is distinct from 'boolean' then raise insufficient_privilege;end if;
  update uniion_private.agenda_convocation_deliveries set status=case when (p_payload->>'ok')::boolean then 'sent' else 'uncertain' end where convocation=ident and user_id=person;
 end if;return jsonb_build_object('ok',true);
end if;
raise insufficient_privilege;
end;$_$;


--
-- Name: ai_refs_readable(uuid, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.ai_refs_readable(o uuid, refs jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare ref jsonb;source_kind text;rid uuid;
begin
 if jsonb_typeof(refs)<>'array' or jsonb_array_length(refs) not between 1 and 64 then return false;end if;
 for ref in select value from jsonb_array_elements(refs) loop
  source_kind=ref->>'kind';rid=(ref->>'id')::uuid;
  if source_kind in ('agenda','adherents','workspace') then
   perform public.uniion_ai_native(o,source_kind,rid);
  elsif source_kind='message' then
   perform public.uniion_module_use(o,'messagerie');
   if not uniion_private.message_visible(o,rid,(ref->>'seq')::bigint) or not exists(select 1 from uniion_private.messages where organization_id=o and conversation=rid and seq=(ref->>'seq')::bigint) then return false;end if;
  else
   -- Pure ACL check: PostgREST table reads run in a read-only transaction.
   if source_kind not in ('case','document','reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis') then return false;end if;
   if not exists(select 1 from public.uniion_resources where organization_id=o and id=rid and module=case source_kind when 'case' then 'dossiers' when 'document' then 'documents' else source_kind end) or not uniion_private.actor_resource(o,rid,auth.uid(),false) then return false;end if;
   -- Classified sources have their own cumulative restrictions; do not flatten them.
   if source_kind='case' and exists(select 1 from uniion_private.case_links where organization_id=o and resource_id=rid) then return false;end if;
  end if;
 end loop;
 return true;
exception when insufficient_privilege or invalid_text_representation then return false;
end$$;


--
-- Name: archive_upload(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.archive_upload(path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.convocation_archives a, jsonb_array_elements(a.files) f where not a.ready and f->>'path'=path)
$$;


--
-- Name: attachment_access(uuid, uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.attachment_access(aid uuid, who uuid, sid uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_attachments a where a.id=aid and a.ready and
 case when sid is null then uniion_private.actor_resource(a.organization_id,a.resource_id,who,false) and uniion_private.authority(a.organization_id,who,'download')
 else exists(select 1 from public.uniion_share_attachments sa where sa.attachment_id=a.id and sa.share_id=sid and sa.resource_id=a.resource_id and uniion_private.share_access(sid,a.resource_id,who,true)) end)
$$;


--
-- Name: attachment_preview(uuid, uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.attachment_preview(aid uuid, who uuid, sid uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_attachments a where a.id=aid and a.ready and a.scan_status='clean' and a.mime in ('application/pdf','image/png','image/jpeg') and case when sid is null then uniion_private.actor_resource(a.organization_id,a.resource_id,who,false) else exists(select 1 from public.uniion_share_attachments sa where sa.share_id=sid and sa.attachment_id=aid and sa.resource_id=a.resource_id and uniion_private.share_access(sid,a.resource_id,who,false)) end)
$$;


--
-- Name: audio_inventory(uuid[]); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.audio_inventory(ids uuid[]) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('scope','audio-bytes-only','audio',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'path',a.path,'sha256',a.sha256,'size',a.size,'request',a.request_id,'chunks',(select count(*) from uniion_private.meeting_audio_chunks c where c.audio_id=a.id),'original',case when o.audio_id is null then null else jsonb_build_object('size',o.size,'sha256',o.sha256,'parts',(select count(*) from uniion_private.meeting_audio_original_parts p where p.audio_id=a.id)) end) order by a.id) from uniion_private.meeting_audio a left join uniion_private.meeting_audio_originals o on o.audio_id=a.id where a.id=any(ids)),'[]'),
 'retained',jsonb_build_object('transcriptionParts',(select count(*) from uniion_private.transcription_parts where id=any(ids)),'privatePV',(select count(distinct m.resource_id) from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id where p.id=any(ids)),'publications',(select count(distinct b.id) from uniion_private.business_publications b join uniion_private.meeting_minutes m on m.resource_id=b.resource_id join uniion_private.transcription_parts p on p.job_id=m.job_id where p.id=any(ids)),'metadata',true,'backups',true,'offlineDevices','unconfirmed'))
$$;


--
-- Name: audio_published(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.audio_published(p_audio uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_minutes m on m.job_id=p.job_id
  join uniion_private.business_publications b on b.organization_id=m.organization_id and b.resource_id=m.resource_id
  where p.id=p_audio and b.published_at is not null and b.revoked_at is null)
$$;


--
-- Name: authority(uuid, uuid, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.authority(org uuid, who uuid, perm text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.actor_member(org,who) and exists(select 1 from public.uniion_authorities where organization_id=org and user_id=who and permission=perm)
$$;


--
-- Name: business_payload(text, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.business_payload(m text, d jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
declare fields text[];item jsonb;
begin
 fields=case m
 when 'reunions' then array['title','type','date','ordre','markers','transcript','minutes','participants']
 when 'communication' then array['title','date','fmt','canal','obj','ton','sujet','content','items']
 when 'mobile' then array['title','type','aud','blocks','pushOn','push','subject']
 when 'formations' then array['title','theme','dur','level','role','goal','modules','intro','retenir','sources','cur','done','ans','ex','fb','chat','finished']
 when 'sondages' then array['title','question','options','description','mode','results','respondents']
 when 'intranet' then array['title','blocks','description','type']
 when 'reporting' then array['title','period','indicators','description']
 when 'raccourcis' then array['title','items','description'] end;
 if fields is null or jsonb_typeof(d) is distinct from 'object' or d-fields<>'{}' or jsonb_typeof(d->'title') is distinct from 'string' or length(btrim(d->>'title')) not between 1 and 200 or octet_length(d::text)>100000 then raise insufficient_privilege;end if;
 -- These values are data only. Neither status, audience grants nor approval can be supplied here.
 if exists(select 1 from jsonb_each(d) where key=any(array['type','date','fmt','canal','obj','ton','sujet','aud','push','subject','theme','level','role','goal','intro','sources','question','description','mode','period']) and (jsonb_typeof(value)<>'string' or length(value#>>'{}')>12000)) then raise insufficient_privilege;end if;
 if exists(select 1 from jsonb_each(d) where key=any(array['ordre','markers','participants','items','blocks','modules','retenir','done','chat','options','indicators']) and (jsonb_typeof(value)<>'array' or jsonb_array_length(value)>100)) then raise insufficient_privilege;end if;
 if d ? 'blocks' then
  for item in select value from jsonb_array_elements(d->'blocks') loop
   if jsonb_typeof(item)<>'array' or jsonb_array_length(item)<>2 or item->>0 not in ('h','p','info','btn','contact') or jsonb_typeof(item->1)<>'string' or length(item->>1)>12000 then raise insufficient_privilege;end if;
  end loop;
 end if;
 -- Poll answers/results are owned by the voting subsystem, never arbitrary record saves.
 if m='sondages' and (d ? 'results' or d ? 'respondents') then raise insufficient_privilege;end if;
 return d;
end$$;


--
-- Name: case_assignment_context(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_assignment_context(o uuid, rid uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
select jsonb_build_object('ownerId',c.owner,'canAssign',uniion_private.authority(o,auth.uid(),'dossiers_assign') and uniion_private.actor_resource(o,rid,auth.uid(),true),
 'assignees',coalesce((select jsonb_agg(jsonb_build_object('id',g.user_id,'name',coalesce(nullif(p.name,''),'Membre habilité'),'role',coalesce(p.role_label,'')) order by p.name,g.user_id)
 from public.uniion_resource_grants g left join uniion_private.identity_profiles p on p.organization_id=g.organization_id and p.user_id=g.user_id
 where g.organization_id=o and g.resource_id=rid and uniion_private.actor_resource(o,rid,g.user_id,false) and uniion_private.actor_resource(o,rid,g.user_id,true)
 and (g.user_id=c.owner or (uniion_private.authority(o,auth.uid(),'dossiers_assign') and uniion_private.actor_resource(o,rid,auth.uid(),true) and g.user_id<>auth.uid()))),'[]'))
 from uniion_private.cases c where c.organization_id=o and c.id=rid
$$;


--
-- Name: case_classified_files(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_classified_files(o uuid, c uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'filename',s->>'name','created',l.created_at,'size',0,'status','reference','classified',true,'version',1,'maxVersion',1,'versions','[]'::jsonb)),'[]') from uniion_private.case_links l cross join lateral (select uniion_private.case_link_source(l) s) checked where l.organization_id=o and l.resource_id=c and l.file<>'' and not l.withdrawn and s is not null
$$;


--
-- Name: case_disposed(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_disposed(r uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (select exists(select 1 from uniion_private.case_disposals where resource_id=r and link is null and state='approved')); end$$;


--
-- Name: case_file_rows(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_file_rows(o uuid, c uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select coalesce(jsonb_agg(f),'[]') from jsonb_array_elements(uniion_private.case_file_rows_all(o,c)) f where not uniion_private.case_file_trashed((f->>'id')::uuid)
$$;


--
-- Name: case_file_rows_all(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_file_rows_all(o uuid, c uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
with entries as (
 select a.id root,1 revision,a.id attachment,a.created_at from public.uniion_attachments a where a.organization_id=o and a.resource_id=c and not exists(select 1 from uniion_private.case_file_versions v where v.attachment=a.id)
 union all select v.root,v.revision,v.attachment,v.created_at from uniion_private.case_file_versions v join public.uniion_attachments a on a.id=v.attachment where a.organization_id=o and a.resource_id=c
), rows as (select e.*,a.filename,a.mime,a.size,a.scan_status from entries e join public.uniion_attachments a on a.id=e.attachment), currents as (
 select distinct on(root) * from rows order by root,(scan_status='clean') desc,revision desc
)
select coalesce(jsonb_agg(jsonb_build_object('id',x.root,'attachment',x.attachment,'version',x.revision,'maxVersion',(select max(revision) from rows where root=x.root),'filename',x.filename,'mime',x.mime,'size',x.size,'created',x.created_at,'status',x.scan_status,'versions',(select jsonb_agg(jsonb_build_object('version',r.revision,'attachment',r.attachment,'status',r.scan_status,'created',r.created_at) order by r.revision desc) from rows r where r.root=x.root)) order by x.created_at desc),'[]') from currents x
$$;


--
-- Name: case_file_trashed(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_file_trashed(a uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_attachments where id=a and uniion_private.case_disposed(resource_id)) or exists(select 1 from uniion_private.case_file_trash t where t.state='approved' and (t.root=a or exists(select 1 from uniion_private.case_file_versions v where v.root=t.root and v.attachment=a)))
$$;


--
-- Name: case_json(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_json(o uuid, rid uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select base||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',jsonb_array_length(uniion_private.case_file_rows(o,rid))+jsonb_array_length(uniion_private.case_classified_files(o,rid)),'timeline',(base->'timeline')||coalesce((select jsonb_agg(jsonb_build_object('link',l.id,'date',to_char(l.created_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title','Message classé · '||(s->>'name'),'body',s->>'body') order by l.created_at) from uniion_private.case_links l cross join lateral (select uniion_private.case_link_source(l) s) checked where l.organization_id=o and l.resource_id=rid and l.file='' and not l.withdrawn and s is not null),'[]')) from (select uniion_private.case_json_base(o,rid) base) t
$$;


--
-- Name: case_json_base(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_json_base(o uuid, rid uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
select jsonb_build_object('id',r.id,'version',r.version,'title',r.title,'tag',c.tag,'due',c.due,'status',c.status,'owner',coalesce((select name from uniion_private.identity_profiles where organization_id=o and user_id=c.owner),'Membre habilité'),'desc',left(c.description,180),'long',c.description,'ask',r.title,'canWrite',uniion_private.actor_resource(o,rid,auth.uid(),true),'timeline',coalesce((select jsonb_agg(jsonb_build_object('date',to_char(h.happened_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title',h.title,'body',h.body) order by h.id) from uniion_private.case_history h where h.organization_id=o and h.resource_id=rid),'[]')) from public.uniion_resources r join uniion_private.cases c on c.id=r.id and c.organization_id=r.organization_id where r.organization_id=o and r.id=rid
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: case_links; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.case_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    convocation uuid,
    file text DEFAULT ''::text NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    withdrawn boolean DEFAULT false NOT NULL,
    message_conversation uuid,
    message_seq bigint,
    CONSTRAINT case_link_source_one CHECK ((((convocation IS NOT NULL) AND (message_conversation IS NULL) AND (message_seq IS NULL)) OR ((convocation IS NULL) AND (message_conversation IS NOT NULL) AND (message_seq IS NOT NULL))))
);


--
-- Name: case_link_source(uniion_private.case_links); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_link_source(l uniion_private.case_links) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select case when l.message_conversation is null then uniion_private.case_source(l.organization_id,l.convocation,l.file) else uniion_private.message_case_source(l.organization_id,l.message_conversation,l.message_seq,l.file) end
$$;


--
-- Name: case_source(uuid, uuid, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.case_source(o uuid, c uuid, f text) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO ''
    AS $$
declare item jsonb; document jsonb;
begin
 select value into item from jsonb_array_elements(public.uniion_convocation_history(o)) where value->>'id'=c::text;
 if item is null then return null;end if;
 if f<>'' then
  select value into document from jsonb_array_elements(public.uniion_convocation_files(o,c,null)) where value->>'id'=f;
  if document is null then return null;end if;
  if f not in ('pdf','ics') then perform public.uniion_attachment_get(o,f::uuid,null,false,true);end if;
  return jsonb_build_object('name',document->>'name');
 end if;
 return jsonb_build_object('name',item->>'subject','body',item->>'body');
exception when insufficient_privilege then return null;
end$$;


--
-- Name: commercial_allowed(uuid, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.commercial_allowed(p_org uuid, p_module text) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
select not exists(select 1 from uniion_private.module_catalog where id=p_module) or (exists(select 1 from uniion_private.module_catalog where id=p_module and available) and exists(select 1 from uniion_private.module_entitlements where organization_id=p_org and module=p_module and revoked_at is null and starts<=now() and ends>now()))
); end$$;


--
-- Name: convocation_documents(uuid, uuid, integer, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.convocation_documents(p_org uuid, p_event uuid, p_version integer, p_people jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare result jsonb;files jsonb;person uuid;reviewer uuid;
begin
result=uniion_private.convocation_documents_without_files(p_org,p_event,p_version,p_people);
files=coalesce(result->'document'->'convocation_files','[]');
perform uniion_private.agenda_file_check(p_org,files,auth.uid());
select r.reviewer into reviewer from uniion_private.agenda_publications r where event_id=p_event and version=p_version;
perform uniion_private.agenda_file_check(p_org,files,reviewer);
for person in select value::uuid from jsonb_array_elements_text(p_people) loop perform uniion_private.agenda_file_check(p_org,files,person);end loop;
return result;
end;$$;


--
-- Name: convocation_documents_without_files(uuid, uuid, integer, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.convocation_documents_without_files(p_org uuid, p_event uuid, p_version integer, p_people jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;r uniion_private.agenda_publications;person uuid;
begin
perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
if not uniion_private.authority(p_org,auth.uid(),'agenda_convocation') or not uniion_private.authority(p_org,auth.uid(),'agenda_publish') or not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
select * into e from uniion_private.agenda_events where id=p_event and organization_id=p_org;
if not found or not uniion_private.agenda_visible(p_org,e.data) then raise insufficient_privilege;end if;
select * into d from uniion_private.agenda_documents where event_id=p_event;
if not found or p_version is distinct from d.version then raise insufficient_privilege;end if;
select * into r from uniion_private.agenda_publications where event_id=p_event and version=p_version;
if not found or r.published_at is null or r.source_version<>e.version or r.reviewer=d.updated_by or not uniion_private.agenda_recipient_allowed(p_event,r.reviewer) or not uniion_private.authority(p_org,r.reviewer,'agenda_review') then raise insufficient_privilege;end if;
if jsonb_typeof(p_people) is distinct from 'array' or jsonb_array_length(p_people) not between 1 and 20 then raise insufficient_privilege;end if;
for person in select value::uuid from jsonb_array_elements_text(p_people) loop
 if not uniion_private.agenda_recipient_allowed(p_event,person) or not uniion_private.authority(p_org,person,'download') or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=person and module='documents' and permission='read') then raise insufficient_privilege;end if;
end loop;
return jsonb_build_object('document',r.document,'version',d.version,'event',e.data||jsonb_build_object('id',e.id,'version',e.version));
end;$$;


--
-- Name: coverage_revision(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.coverage_revision() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$begin if new.coverage_end is distinct from old.coverage_end then new.coverage_revision=old.coverage_revision+1;end if;return new;end$$;


--
-- Name: document_image_allowed(uuid, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.document_image_allowed(p_document uuid, p_image text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select p_image is not null and (p_image in ('','uniion-logo.png') or exists(select 1 from uniion_private.document_image_receipts where document_id=p_document and digest=encode(extensions.digest(p_image,'sha256'),'hex')))
$$;


--
-- Name: document_json(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.document_json(o uuid, rid uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select uniion_private.document_json_before_corrections(o,rid)||case when exists(select 1 from uniion_private.document_corrections c join public.uniion_resources r on r.id=c.resource_id and r.version=c.version where c.organization_id=o and c.resource_id=rid) then jsonb_build_object('status','À corriger') else '{}'::jsonb end
$$;


--
-- Name: document_json_before_corrections(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.document_json_before_corrections(o uuid, rid uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
 select r.body||jsonb_build_object('id',r.id,'version',r.version,'title',r.title,'model',d.model,'status',coalesce((select case when p.published_at is not null then 'Diffusé' else 'Validé' end from uniion_private.document_publications p where p.organization_id=o and p.resource_id=rid and p.version=r.version),'Brouillon'),'serverDocument',true,'updated',to_char(d.updated_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'canWrite',uniion_private.actor_resource(o,rid,auth.uid(),true)) from public.uniion_resources r join uniion_private.documents d on d.id=r.id and d.organization_id=r.organization_id where r.organization_id=o and r.id=rid
$$;


--
-- Name: dues_effective(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.dues_effective(p_id uuid) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
select coalesce((select amount_cents from uniion_private.dues_corrections where payment_id=p_id order by revision desc limit 1),(select amount_cents from uniion_private.dues_payments where id=p_id))
$$;


--
-- Name: dues_evidence_insert(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.dues_evidence_insert(p_path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.dues_evidence where path=p_path and status='pending')
$$;


--
-- Name: dues_export_snapshot(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.dues_export_snapshot(p_org uuid, p_member uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('organization',(select name from public.uniion_organizations where id=p_org),'memberId',a.id,'member',trim((a.data->>'prenom')||' '||(a.data->>'nom')),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'period',e.period,'dueOn',e.due_on,'chargeCents',e.amount_cents,'originalCents',p.amount_cents,'cents',uniion_private.dues_effective(p.id),'recordedAt',p.recorded_at,'effectiveOn',coalesce((select c.effective_on from uniion_private.dues_corrections c where c.payment_id=p.id and c.effective_on is not null order by revision desc limit 1),p.effective_on),'revision',coalesce((select max(revision) from uniion_private.dues_corrections where payment_id=p.id),0)) order by e.period,p.recorded_at,p.id) from uniion_private.dues_entries e join uniion_private.dues_payments p on p.entry_id=e.id and p.organization_id=e.organization_id where e.organization_id=p_org and e.adherent_id=a.id),'[]')) from uniion_private.adherents a where a.organization_id=p_org and a.id=p_member
$$;


--
-- Name: dues_occurrence(date, integer, integer); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.dues_occurrence(anchor date, months integer, n integer) RETURNS date
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$select (anchor+make_interval(months=>months*n))::date$$;


--
-- Name: dues_summary(jsonb, date); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.dues_summary(rows jsonb, as_of date) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$
with members as (select value r from jsonb_array_elements(rows)),
entries as (select r->>'id' member,e from members cross join lateral jsonb_array_elements(coalesce(r->'duesLedger','[]')) e),
ledger as (select member,e,(e->>'cents')::bigint amount,(e->>'paidCents')::bigint paid,(e->>'dueOn')::date due from entries),
per_member as (select member,sum(amount-paid) filter(where due<as_of) overdue,min(due) filter(where due<as_of and amount>paid) oldest,
 count(*) filter(where due<=as_of) due_count,coalesce(sum(amount-paid) filter(where due<=as_of),0) remaining from ledger group by member),
payments as (select p from entries cross join lateral jsonb_array_elements(e->'payments') p),
modes as (select coalesce(nullif(btrim(r->>'mode'),''),'Non renseigné') label,count(*) n from members group by 1)
select jsonb_build_object('asOf',as_of,'quarterStart',date_trunc('quarter',as_of)::date,
 'dueCents',coalesce((select sum(amount) from ledger where due<=as_of),0),
 'paidDueCents',coalesce((select sum(paid) from ledger where due<=as_of),0),
 'remainingCents',coalesce((select sum(amount-paid) from ledger where due<=as_of),0),
 'overdueCents',coalesce((select sum(amount-paid) from ledger where due<as_of),0),
 'quarterCents',coalesce((select sum((p->>'cents')::bigint) from payments where (p->>'effectiveOn')::date between date_trunc('quarter',as_of)::date and as_of),0),
 'undatedCents',coalesce((select sum((p->>'cents')::bigint) from payments where p->>'effectiveOn' is null),0),
 'assessedMembers',(select count(*) from per_member where due_count>0),
 'upToDateMembers',(select count(*) from per_member where due_count>0 and remaining=0),
 'modes',coalesce((select jsonb_agg(jsonb_build_object('label',label,'n',n) order by label) from modes),'[]'),
 'arrears',coalesce((select jsonb_agg(jsonb_build_object('id',member,'cents',overdue,'dueOn',oldest) order by oldest,member) from per_member where overdue>0),'[]'));
$$;


--
-- Name: entry_coverage(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.entry_coverage() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
declare months int;
begin
 perform 1 from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id for update;
 if new.schedule_id is not null then
  select s.months into months from uniion_private.dues_schedules s where s.id=new.schedule_id and s.organization_id=new.organization_id;
  new.coverage_end=(date_trunc('month',new.period)+make_interval(months=>months))::date;
  if uniion_private.schedule_overlap(new.organization_id,new.adherent_id,new.period,new.coverage_end) then raise insufficient_privilege;end if;
 elsif exists(select 1 from uniion_private.dues_entries where organization_id=new.organization_id and adherent_id=new.adherent_id and (period=new.period or (coverage_end is not null and period<=new.period and coverage_end>new.period))) then raise insufficient_privilege;
 end if;
 return new;
end$$;


--
-- Name: entry_membership_end(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.entry_membership_end() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$declare a uniion_private.adherents;begin
 select * into a from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id for update;
 if (a.ended_on is not null and (new.due_on>=a.ended_on or (now() at time zone 'Europe/Paris')::date>=a.ended_on)) or (a.membership_cycle>0 and (new.due_on<a.joined_on or (now() at time zone 'Europe/Paris')::date<a.joined_on)) then raise insufficient_privilege;end if;return new;
end$$;


--
-- Name: identity_admin(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.identity_admin(org uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select auth.jwt()->>'aal'='aal2' and uniion_private.authority(org,auth.uid(),'rights')
$$;


--
-- Name: identity_in_scope(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.identity_in_scope() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_memberships where user_id=auth.uid()) or exists(select 1 from uniion_private.platform_operators where user_id=auth.uid()) or exists(select 1 from uniion_private.super_admins where user_id=auth.uid() and active) or exists(select 1 from uniion_private.support_agents where user_id=auth.uid() and active)
$$;


--
-- Name: is_scanner(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.is_scanner() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 return uniion_private.session_allowed() and exists(select 1 from uniion_private.scan_workers where user_id=auth.uid());
end$$;


--
-- Name: meeting_audio_insert(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.meeting_audio_insert(p_path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.meeting_audio where path=p_path and status='pending')
$$;


--
-- Name: member(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.member(org uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (select uniion_private.actor_member(org,auth.uid())); end$$;


--
-- Name: member_criteria(jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.member_criteria(c jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$begin
 if jsonb_typeof(c) is distinct from 'object' or c-array['q','ent','etab','sect','dir','statut']<>'{}' or exists(select 1 from jsonb_each(c) where jsonb_typeof(value)<>'string' or length(value#>>'{}')>300) or coalesce(c->>'statut','Tous') not in ('Tous','ajour','retard','nouveau') then raise insufficient_privilege;end if;return c;
end$$;


--
-- Name: member_dues_status(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.member_dues_status(o uuid, m uuid) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
with ledger as (select e.due_on,e.amount_cents-coalesce((select sum(uniion_private.dues_effective(p.id)) from uniion_private.dues_payments p where p.organization_id=o and p.entry_id=e.id),0) remaining from uniion_private.dues_entries e where e.organization_id=o and e.adherent_id=m)
select case when exists(select 1 from ledger where due_on<(now() at time zone 'Europe/Paris')::date and remaining>0) then 'retard'
when exists(select 1 from ledger where due_on<=(now() at time zone 'Europe/Paris')::date) and not exists(select 1 from ledger where due_on<=(now() at time zone 'Europe/Paris')::date and remaining>0) then 'ajour' else 'nouveau' end
$$;


--
-- Name: member_matches(jsonb, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.member_matches(d jsonb, c jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$select
 (coalesce(c->>'ent','Toutes') in ('','Toutes') or d->>'ent'=c->>'ent') and
 (coalesce(c->>'etab','Tous') in ('','Tous') or d->>'etab'=c->>'etab') and
 (coalesce(c->>'sect','Toutes') in ('','Toutes') or d->>'sect'=c->>'sect') and
 (coalesce(c->>'dir','Toutes') in ('','Toutes') or d->>'dir'=c->>'dir') and
 (coalesce(btrim(c->>'q'),'')='' or strpos(lower(concat_ws(' ',d->>'prenom',d->>'nom',d->>'email',d->>'poste')),lower(btrim(c->>'q')))>0)
$$;


--
-- Name: message_admin(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_admin(o uuid, c uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.message_member(o,c) and exists(select 1 from uniion_private.message_participations where organization_id=o and conversation=c and user_id=auth.uid() and left_at is null and is_admin)
$$;


--
-- Name: message_case_source(uuid, uuid, bigint, text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_case_source(o uuid, c uuid, s bigint, f text) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO ''
    AS $$
declare m uniion_private.messages;a public.uniion_attachments;
begin
 perform public.uniion_module_use(o,'messagerie');
 m=uniion_private.message_origin(o,c,s);
 if m.id is null then return null;end if;
 if f<>'' then
  select a0.* into a from uniion_private.message_files mf join public.uniion_attachments a0 on a0.id=mf.attachment where mf.organization_id=o and mf.conversation=m.conversation and mf.seq=m.seq and mf.attachment=f::uuid;
  if not found or not a.ready or a.scan_status<>'clean' or uniion_private.case_file_trashed(a.id) then return null;end if;
  return jsonb_build_object('name',a.filename);
 end if;
 return jsonb_build_object('name','Message','body',m.body);
exception when insufficient_privilege then return null;
end$$;


--
-- Name: message_conversation_before_live(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_conversation_before_live(o uuid, c uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('id',c,'kind',cv.kind,'name',case when cv.kind='group' then cv.title else coalesce((select ip.name from uniion_private.message_participations p left join uniion_private.identity_profiles ip on ip.organization_id=p.organization_id and ip.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id<>auth.uid() and p.left_at is null limit 1),'Membre') end,
 'desc',cv.description,'version',cv.version,'canManage',cv.kind='group' and uniion_private.message_admin(o,c),'canHistory',uniion_private.authority(o,auth.uid(),'history'),
 'memberRows',coalesce((select jsonb_agg(jsonb_build_object('id',p.user_id,'period',p.id,'name',coalesce(ip.name,'Membre'),'role',coalesce(ip.role_label,'Membre'),'admin',p.is_admin,'me',p.user_id=auth.uid(),'visibleFrom',p.visible_from::text,'historyCount',(select count(*) from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.revoked_at is null)) order by p.joined_at,p.id)
 from uniion_private.message_participations p left join uniion_private.identity_profiles ip on ip.organization_id=p.organization_id and ip.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.left_at is null and uniion_private.message_current(o,c,p.user_id)),'[]'),
 'messages',coalesce((select jsonb_agg(uniion_private.message_json(m)) from (select * from uniion_private.messages where organization_id=o and conversation=c and uniion_private.message_visible(o,c,seq) order by seq desc limit 1)m),'[]'))
 from uniion_private.message_conversations cv where cv.organization_id=o and cv.id=c
$$;


--
-- Name: message_conversation_json(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_conversation_json(o uuid, c uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.message_conversation_before_live(o,c)||jsonb_build_object('unread',uniion_private.message_unread(o,c))
$$;


--
-- Name: message_current(uuid, uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_current(o uuid, c uuid, u uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.actor_member(o,u) and exists(select 1 from uniion_private.message_participations p join public.uniion_memberships m on m.organization_id=p.organization_id and m.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id=u and p.left_at is null and p.organization_joined_at=m.joined_at)
$$;


--
-- Name: messages; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.messages (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    seq bigint NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    author uuid NOT NULL,
    client_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    reply_to bigint,
    CONSTRAINT messages_body_check CHECK (((length(btrim(body)) >= 1) AND (length(btrim(body)) <= 10000))),
    CONSTRAINT messages_body_length CHECK ((length(body) <= 10000))
);


--
-- Name: message_json(uniion_private.messages); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_json(m uniion_private.messages) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare origin uniion_private.messages;r uniion_private.messages;quote uniion_private.messages;base jsonb;doc jsonb;
begin
 origin=uniion_private.message_origin(m.organization_id,m.conversation,m.seq);
 if origin.id is null then return null;end if;
 base=uniion_private.message_json_before_references(m);
 if origin.id<>m.id then
  doc=uniion_private.message_json_before_references(origin)->'file';
  if doc is not null and doc<>'null'::jsonb then doc=doc||jsonb_build_object('canWrite',false);end if;
  base=base||jsonb_build_object('text',origin.body,'file',doc,'fwd',true);
 end if;
 if m.reply_to is not null then
  select * into r from uniion_private.messages where organization_id=m.organization_id and conversation=m.conversation and seq=m.reply_to;
  quote=uniion_private.message_origin(m.organization_id,m.conversation,m.reply_to);
  base=base||jsonb_build_object('reply',case when quote.id is not null then jsonb_build_object('seq',r.seq::text,'text',left(quote.body,160),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=r.organization_id and user_id=r.author),'Membre')) end);
 end if;
 return base;
end$$;


--
-- Name: message_json_before_files(uniion_private.messages); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_json_before_files(m uniion_private.messages) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select jsonb_build_object('id',m.id,'seq',m.seq::text,'text',m.body,'mine',m.author=auth.uid(),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=m.organization_id and user_id=m.author),'Membre'),'created',m.created_at,'clientId',m.client_id,'reply',
 (select jsonb_build_object('seq',r.seq::text,'text',left(r.body,160),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=r.organization_id and user_id=r.author),'Membre')) from uniion_private.messages r where r.organization_id=m.organization_id and r.conversation=m.conversation and r.seq=m.reply_to and uniion_private.message_visible(r.organization_id,r.conversation,r.seq)))
$$;


--
-- Name: message_json_before_references(uniion_private.messages); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_json_before_references(m uniion_private.messages) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.message_json_before_files(m)||jsonb_build_object('file',(select jsonb_build_object('id',a.id,'resource',f.resource,'name',a.filename,'status',case when uniion_private.case_file_trashed(a.id) then 'trash' else a.scan_status end,'size',a.size,'sha256',a.sha256,'preview',uniion_private.attachment_preview(a.id,auth.uid()),'uploaded',exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name),'canWrite',m.author=auth.uid(),'download',uniion_private.authority(m.organization_id,auth.uid(),'download')) from uniion_private.message_files f join public.uniion_attachments a on a.id=f.attachment where f.organization_id=m.organization_id and f.conversation=m.conversation and f.seq=m.seq and uniion_private.message_visible(m.organization_id,m.conversation,m.seq)))
$$;


--
-- Name: message_member(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_member(o uuid, c uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.message_current(o,c,auth.uid())
$$;


--
-- Name: message_origin(uuid, uuid, bigint); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_origin(o uuid, c uuid, s bigint) RETURNS uniion_private.messages
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare m uniion_private.messages;f uniion_private.message_forwards;depth integer;
begin
 for depth in 0..8 loop
  if not uniion_private.message_visible_before_references(o,c,s) then return null;end if;
  select * into m from uniion_private.messages where organization_id=o and conversation=c and seq=s;
  if not found then return null;end if;
  select * into f from uniion_private.message_forwards where organization_id=o and conversation=c and seq=s;
  if not found then
   if depth>0 and exists(select 1 from uniion_private.message_files mf join public.uniion_attachments a on a.id=mf.attachment where mf.organization_id=o and mf.conversation=c and mf.seq=s and (not a.ready or uniion_private.case_file_trashed(a.id))) then return null;end if;
   return m;
  end if;
  c=f.source_conversation;s=f.source_seq;
 end loop;
 return null;
end$$;


--
-- Name: message_revision(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_revision(o uuid, c uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select md5(coalesce(string_agg(case
  when m.reply_to is null
   and not exists(select 1 from uniion_private.message_files f where f.organization_id=o and f.conversation=c and f.seq=m.seq)
   and not exists(select 1 from uniion_private.message_forwards f where f.organization_id=o and f.conversation=c and f.seq=m.seq)
  then jsonb_build_array(m.id,m.seq::text,m.body,m.author=auth.uid(),coalesce(ip.name,'Membre'),m.created_at,m.client_id)::text
  else uniion_private.message_json(m)::text end,',' order by m.seq),''))
 from uniion_private.messages m left join uniion_private.identity_profiles ip on ip.organization_id=m.organization_id and ip.user_id=m.author
 where m.organization_id=o and m.conversation=c and uniion_private.message_visible(o,c,m.seq)
$$;


--
-- Name: message_unread(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_unread(o uuid, c uuid) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select case when uniion_private.message_member(o,c) then (
  select count(*) from uniion_private.message_participations p
  join uniion_private.messages m on m.organization_id=p.organization_id and m.conversation=p.conversation
  left join uniion_private.message_reads r on r.organization_id=p.organization_id and r.conversation=p.conversation and r.participation=p.id
  where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null
  and m.author<>auth.uid() and m.seq>coalesce(r.seq,0)
  and (m.seq>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.message_seq=m.seq and g.revoked_at is null))
  and (not exists(select 1 from uniion_private.message_forwards f where f.organization_id=o and f.conversation=c and f.seq=m.seq) or uniion_private.message_visible(o,c,m.seq))
 ) else 0 end
$$;


--
-- Name: message_visible(uuid, uuid, bigint); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_visible(o uuid, c uuid, s bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select (uniion_private.message_origin(o,c,s)).id is not null
$$;


--
-- Name: message_visible_before_references(uuid, uuid, bigint); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.message_visible_before_references(o uuid, c uuid, s bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.message_member(o,c) and exists(select 1 from uniion_private.message_participations p where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null and
 (s>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.message_seq=s and g.revoked_at is null)))
$$;


--
-- Name: messaging_a(uuid, text, jsonb); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.messaging_a(p_org uuid, p_action text, p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare renew_user uuid;renewed boolean:=false;boundary bigint;cid uuid;other uuid;pair_key text;v_seq bigint;prior uniion_private.messages;msg uniion_private.messages;rows jsonb;cursor_value bigint;lim integer:=50;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action in ('create','send') and not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='write') then raise insufficient_privilege;end if;
 if p_action='participants' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',m.user_id,'name',coalesce(p.name,'Membre'),'role',coalesce(p.role_label,'Membre')) order by m.user_id) from public.uniion_memberships m left join uniion_private.identity_profiles p on p.organization_id=m.organization_id and p.user_id=m.user_id where m.organization_id=p_org and m.user_id<>auth.uid() and uniion_private.actor_member(p_org,m.user_id) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=m.user_id and module='messagerie' and permission='read')),'[]');
 elsif p_action='create' then
  if not(p_payload ? 'participant') or p_payload-'participant'<>'{}' or jsonb_typeof(p_payload->'participant')<>'string' then raise insufficient_privilege;end if;
  other=(p_payload->>'participant')::uuid;
  if other is null or other=auth.uid() or not uniion_private.actor_member(p_org,other) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=other and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  pair_key=least(auth.uid()::text,other::text)||':'||greatest(auth.uid()::text,other::text);
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||pair_key,0));
  select id into cid from uniion_private.message_conversations where organization_id=p_org and pair=pair_key;
  if cid is null then
   insert into uniion_private.message_conversations(organization_id,pair) values(p_org,pair_key) returning id into cid;
   insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at) select p_org,cid,user_id,joined_at from public.uniion_memberships where organization_id=p_org and user_id in(auth.uid(),other);
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.conversation_created',jsonb_build_object('conversation',cid));
  end if;
  select next_seq+1 into boundary from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
  foreach renew_user in array array[auth.uid(),other] loop
   if not uniion_private.message_current(p_org,cid,renew_user) then
    update uniion_private.message_participations set left_at=clock_timestamp() where organization_id=p_org and conversation=cid and user_id=renew_user and left_at is null;
    insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from)
     select p_org,cid,user_id,joined_at,boundary from public.uniion_memberships where organization_id=p_org and user_id=renew_user;
    renewed=true;
   end if;
  end loop;
  if renewed then
   update uniion_private.message_conversations set version=version+1 where organization_id=p_org and id=cid;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.direct_reinvited',jsonb_build_object('conversation',cid,'visibleFrom',boundary));
  end if;
  if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  return uniion_private.message_conversation_json(p_org,cid);
 elsif p_action='list' then
  if p_payload-'before'<>'{}' or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
  return (select jsonb_build_object('rows',coalesce(jsonb_agg(uniion_private.message_conversation_json(p_org,q.id) order by q.id desc),'[]'),'next',case when count(*)=lim then min(q.id::text) end) from (select id from uniion_private.message_conversations where organization_id=p_org and uniion_private.message_member(p_org,id) and (not(p_payload ? 'before') or id<(p_payload->>'before')::uuid) order by id desc limit lim)q);
 elsif p_action in ('get','send') then
  if not(p_payload ? 'id') or jsonb_typeof(p_payload->'id')<>'string' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;
  if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  if p_action='get' then
   if p_payload-array['id','before']<>'{}' or (p_payload ? 'before' and (jsonb_typeof(p_payload->'before')<>'string' or (p_payload->>'before') !~ '^[1-9][0-9]{0,17}$')) then raise insufficient_privilege;end if;
   select jsonb_agg(uniion_private.message_json(q) order by q.seq),case when count(*)=lim then min(q.seq) end into rows,cursor_value from (select * from uniion_private.messages where organization_id=p_org and conversation=cid and uniion_private.message_visible(p_org,cid,seq) and (not(p_payload ? 'before') or seq<(p_payload->>'before')::bigint) order by seq desc limit lim)q;
   return uniion_private.message_conversation_json(p_org,cid)||jsonb_build_object('messages',coalesce(rows,'[]'),'next',cursor_value::text);
  end if;
  if not(p_payload ?& array['id','clientId','text']) or p_payload-array['id','clientId','text','replyTo']<>'{}' or jsonb_typeof(p_payload->'text')<>'string' or (length(btrim(p_payload->>'text')) not between 1 and 10000 or length(p_payload->>'text')>10000) or jsonb_typeof(p_payload->'clientId')<>'string' or (p_payload ? 'replyTo' and (jsonb_typeof(p_payload->'replyTo')<>'string' or (p_payload->>'replyTo') !~ '^[1-9][0-9]{0,17}$')) then raise insufficient_privilege;end if;
  perform 1 from uniion_private.message_conversations where organization_id=p_org and id=cid for update; if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  if p_payload ? 'replyTo' and not exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=cid and seq=(p_payload->>'replyTo')::bigint and uniion_private.message_visible(p_org,cid,seq)) then raise insufficient_privilege;end if;
  select * into prior from uniion_private.messages where organization_id=p_org and conversation=cid and author=auth.uid() and client_id=(p_payload->>'clientId')::uuid;
  if found then
   if prior.body is distinct from (p_payload->>'text') or prior.reply_to is distinct from (p_payload->>'replyTo')::bigint or not uniion_private.message_visible(p_org,cid,prior.seq) then raise insufficient_privilege;end if;
   return uniion_private.message_json(prior);
  end if;
  update uniion_private.message_conversations set next_seq=next_seq+1 where organization_id=p_org and id=cid returning next_seq into v_seq;
  insert into uniion_private.messages(organization_id,conversation,seq,author,client_id,body,reply_to) values(p_org,cid,v_seq,auth.uid(),(p_payload->>'clientId')::uuid,p_payload->>'text',(p_payload->>'replyTo')::bigint) returning * into msg;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.sent',jsonb_build_object('conversation',cid,'message',msg.id));
  return uniion_private.message_json(msg);
 end if;
 raise insufficient_privilege;
end $_$;


--
-- Name: minutes_sources_allowed(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.minutes_sources_allowed(o uuid, meeting uuid, job uuid, who uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.actor_resource(o,meeting,who,false) and uniion_private.commercial_allowed(o,'reunions')
 and exists(select 1 from uniion_private.meeting_audio_grants where organization_id=o and meeting_id=meeting and user_id=who and can_read)
 and exists(select 1 from uniion_private.transcription_jobs where id=job and organization_id=o and meeting_id=meeting and state='done')
 and exists(select 1 from uniion_private.transcription_parts where job_id=job)
 and not exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_audio a on a.id=p.id
 left join uniion_private.meeting_consents c on c.organization_id=a.organization_id and c.meeting_id=a.meeting_id
 left join public.uniion_resources r on r.organization_id=a.organization_id and r.id=a.meeting_id
 where p.job_id=job and (a.organization_id<>o or a.meeting_id<>meeting or c.accepted is distinct from true or c.version is distinct from p.consent_version or c.meeting_version is distinct from p.meeting_version or r.version is distinct from p.meeting_version or a.status<>'clean' or a.sha256<>p.sha256 or p.result is null or exists(select 1 from uniion_private.meeting_audio_originals x where x.audio_id=a.id and x.status<>'clean')))
$$;


--
-- Name: new_dues_schedule(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.new_dues_schedule() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare m int;n int=0;today date=(now() at time zone 'Europe/Paris')::date;
begin
 m=case new.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
 if new.joined_on is null or m is null or coalesce((new.dues_terms->>'cents')::bigint,0)<=0 or not uniion_private.schedule_allowed(new.organization_id,auth.uid()) then return new;end if;
 n=greatest(0,((extract(year from today)::int-extract(year from new.joined_on)::int)*12+extract(month from today)::int-extract(month from new.joined_on)::int)/m);
 if uniion_private.dues_occurrence(new.joined_on,m,n)<today then n=n+1;end if;
 insert into uniion_private.dues_schedules(organization_id,adherent_id,anchor,member_anchor,months,amount_cents,next_index,actor) values(new.organization_id,new.id,new.joined_on,new.joined_on,m,(new.dues_terms->>'cents')::bigint,n,auth.uid());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(new.organization_id,auth.uid(),'dues.schedule_created',jsonb_build_object('adherent',new.id));
 return new;
end $$;


--
-- Name: prevent_audio_resurrection(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.prevent_audio_resurrection() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 if exists(select 1 from uniion_private.audio_tombstones where organization_id=new.organization_id and meeting_id=new.meeting_id and (audio_id=new.id or request_id=new.request_id or sha256=new.sha256)) and (tg_op='INSERT' or new.status<>'blocked') then raise insufficient_privilege;end if;
 return new;
end$$;


--
-- Name: record_audio_validation(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.record_audio_validation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 -- R38 : le délai de conservation de l'audio court à partir de la publication du PV, pas de sa
 -- relecture ; une révocation retire l'éligibilité s'il ne reste aucune publication active.
 if new.published_at is not null and new.revoked_at is null then
  insert into uniion_private.audio_retention_validations(audio_id,validated_at,reviewer,resource_id,version)
  select p.id,new.published_at,new.reviewer,new.resource_id,new.version from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id
  where m.resource_id=new.resource_id and m.organization_id=new.organization_id
  on conflict(audio_id) do nothing;
 elsif new.revoked_at is not null then
  delete from uniion_private.audio_retention_validations v where v.audio_id in (
   select p.id from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id where m.resource_id=new.resource_id and m.organization_id=new.organization_id)
  and not uniion_private.audio_published(v.audio_id);
 end if;
 return new;
end$$;


--
-- Name: record_version(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.record_version() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
 insert into public.uniion_resource_versions(organization_id,resource_id,version,body,actor)
 values(new.organization_id,new.id,new.version,new.body,auth.uid());return new;
end $$;


--
-- Name: reenrollment_allowed(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.reenrollment_allowed() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now()))
 and not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified')
 and exists(select 1 from uniion_private.lost_factor_jobs j join uniion_private.platform_operators p on p.user_id=j.approved_by and p.active where j.user_id=auth.uid() and j.state='cleared' and j.expires_at>now())
$$;


--
-- Name: resource_access(uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.resource_access(org uuid, resource uuid, write_access boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
 select case when exists(select 1 from uniion_private.meeting_minutes where resource_id=resource) then uniion_private.actor_resource(org,resource,auth.uid(),write_access) else uniion_private.resource_access_before_minutes(org,resource,write_access) end
); end$$;


--
-- Name: resource_access_before_ai_case(uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.resource_access_before_ai_case(org uuid, resource uuid, write_access boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (select not uniion_private.case_disposed(resource) and uniion_private.resource_access_before_disposal(org,resource,write_access)); end$$;


--
-- Name: resource_access_before_disposal(uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.resource_access_before_disposal(org uuid, resource uuid, write_access boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
 select uniion_private.member(org) and exists(
 select 1 from public.uniion_resources r
 join public.uniion_resource_grants g on g.organization_id=r.organization_id and g.resource_id=r.id
 join public.uniion_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id
 join public.uniion_module_access a on a.organization_id=r.organization_id and a.module=r.module
 join public.uniion_permissions p on p.organization_id=g.organization_id and p.user_id=g.user_id and p.module=r.module
 where r.organization_id=org and r.id=resource and g.user_id=auth.uid()
 and g.revoked_at is null and g.valid_until>now()
 and (r.created_at>=m.joined_at or g.history_approved)
 and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)
 and p.permission=case when write_access then 'write' else 'read' end
 and (not write_access or g.can_write))
); end$$;


--
-- Name: resource_access_before_minutes(uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.resource_access_before_minutes(org uuid, resource uuid, write_access boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
 select uniion_private.resource_access_before_ai_case(org,resource,write_access)
 and (not exists(select 1 from uniion_private.ai_case_derivatives d where d.resource=resource_access_before_minutes.resource)
      or uniion_private.actor_resource(org,resource,auth.uid(),write_access))
); end$$;


--
-- Name: retention_storage(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.retention_storage(path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $_$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.audio_tombstones t join uniion_private.audio_retention_batches b on b.id=t.batch_id join uniion_private.meeting_audio a on a.id=t.audio_id join uniion_private.super_admins s on s.user_id=b.approved_by and s.active where a.path=$1 and b.state='executing')
$_$;


--
-- Name: run_dues_schedules(uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.run_dues_schedules(p_org uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare s uniion_private.dues_schedules;a uniion_private.adherents;d date;today date=(now() at time zone 'Europe/Paris')::date;made int=0;blocked int=0;loops int;entry uuid;
begin
 for s in select * from uniion_private.dues_schedules where state='active' and (p_org is null or organization_id=p_org) order by id for update skip locked loop
  select * into a from uniion_private.adherents where id=s.adherent_id and organization_id=s.organization_id for update;
  if a.ended_on is not null and a.ended_on<=today then update uniion_private.dues_schedules set state='stopped' where id=s.id;continue;end if;
  -- R53 : un échéancier dont le créateur a perdu ses droits n'est plus sauté en silence.
  if not uniion_private.schedule_allowed(s.organization_id,s.actor) then
   update uniion_private.dues_schedules set state='review' where id=s.id;blocked=blocked+1;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(s.organization_id,s.actor,'dues.schedule_review',jsonb_build_object('schedule',s.id,'reason','actor_without_rights'));
   continue;
  end if;
  if a.joined_on is distinct from s.member_anchor or (a.dues_terms->>'cents')::bigint is distinct from s.amount_cents or (case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end) is distinct from s.months then
   update uniion_private.dues_schedules set state='review' where id=s.id;blocked=blocked+1;continue;
  end if;
  loops=0;
  loop
   d=uniion_private.dues_occurrence(s.anchor,s.months,s.next_index);exit when d>today or loops>=24 or (a.ended_on is not null and d>=a.ended_on);
   -- An existing manual charge for this calendar period needs human reconciliation.
   if uniion_private.schedule_overlap(s.organization_id,s.adherent_id,date_trunc('month',d)::date,(date_trunc('month',d)+make_interval(months=>s.months))::date) then
    update uniion_private.dues_schedules set state='conflict' where id=s.id;blocked=blocked+1;exit;
   end if;
   insert into uniion_private.dues_entries(organization_id,adherent_id,amount_cents,period,due_on,created_by,request_id,schedule_id,occurrence)
    values(s.organization_id,s.adherent_id,s.amount_cents,date_trunc('month',d)::date,d,s.actor,gen_random_uuid(),s.id,s.occurrence_offset+s.next_index) returning id into entry;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(s.organization_id,s.actor,'dues.scheduled',jsonb_build_object('schedule',s.id,'entry',entry,'occurrence',s.next_index));
   s.next_index=s.next_index+1;update uniion_private.dues_schedules set next_index=s.next_index where id=s.id;made=made+1;loops=loops+1;
  end loop;
 end loop;
 return jsonb_build_object('created',made,'blocked',blocked);
end $$;


--
-- Name: schedule_allowed(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.schedule_allowed(o uuid, u uuid) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
select exists(select 1 from public.uniion_memberships where organization_id=o and user_id=u and revoked_at is null and joined_at<=now()) and not exists(select 1 from uniion_private.membership_suspensions where organization_id=o and user_id=u and suspended) and exists(select 1 from public.uniion_organizations where id=o and active)
 and uniion_private.commercial_allowed(o,'adherents')
 and not exists(select 1 from (values('adherents','read'),('cotisations','read'),('cotisations','write')) required(module,permission)
 where not exists(select 1 from public.uniion_permissions p where p.organization_id=o and p.user_id=u and p.module=required.module and p.permission=required.permission))
 and (select count(*)=2 from public.uniion_module_access where organization_id=o and module in('adherents','cotisations') and authorized and enabled and valid_until>now());
$$;


--
-- Name: schedule_end_guard(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.schedule_end_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$begin
 if new.state='active' and exists(select 1 from uniion_private.adherents where organization_id=new.organization_id and id=new.adherent_id and ended_on<=(now() at time zone 'Europe/Paris')::date) then raise insufficient_privilege;end if;return new;
end$$;


--
-- Name: schedule_overlap(uuid, uuid, date, date); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.schedule_overlap(o uuid, m uuid, first_day date, end_day date) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$select exists(select 1 from uniion_private.dues_entries where organization_id=o and adherent_id=m and (coverage_end is null or (period<end_day and coverage_end>first_day)))$$;


--
-- Name: adherents; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.adherents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    joined_on date GENERATED ALWAYS AS (uniion_private.adherent_date((data ->> 'since'::text))) STORED,
    dues_terms jsonb GENERATED ALWAYS AS (uniion_private.adherent_dues((data ->> 'montant'::text))) STORED,
    ended_on date,
    membership_cycle integer DEFAULT 0 NOT NULL,
    CONSTRAINT adherent_end_after_join CHECK (((ended_on IS NULL) OR (joined_on IS NULL) OR (ended_on >= joined_on)))
);


--
-- Name: dues_schedules; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    adherent_id uuid NOT NULL,
    anchor date NOT NULL,
    months integer NOT NULL,
    amount_cents bigint NOT NULL,
    next_index integer DEFAULT 0 NOT NULL,
    state text DEFAULT 'active'::text NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    member_anchor date NOT NULL,
    occurrence_offset integer DEFAULT 0 NOT NULL,
    requires_reanchor boolean DEFAULT false NOT NULL,
    CONSTRAINT dues_schedules_amount_cents_check CHECK ((amount_cents > 0)),
    CONSTRAINT dues_schedules_months_check CHECK ((months = ANY (ARRAY[1, 3, 12]))),
    CONSTRAINT dues_schedules_next_index_check CHECK ((next_index >= 0)),
    CONSTRAINT dues_schedules_state_check CHECK ((state = ANY (ARRAY['active'::text, 'paused'::text, 'review'::text, 'conflict'::text, 'stopped'::text])))
);


--
-- Name: schedule_proposal(uniion_private.dues_schedules, uniion_private.adherents); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.schedule_proposal(s uniion_private.dues_schedules, a uniion_private.adherents) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO ''
    AS $$
declare today date=(now() at time zone 'Europe/Paris')::date;n int;d date;m int;
begin
 m=case a.dues_terms->>'period' when 'month' then 1 when 'quarter' then 3 when 'year' then 12 end;
 if a.joined_on is distinct from s.member_anchor or m is distinct from s.months or coalesce((a.dues_terms->>'cents')::bigint,0)<=0 or s.state='conflict' then raise insufficient_privilege;end if;
 n=greatest(s.next_index,0,((extract(year from today)::int-extract(year from s.anchor)::int)*12+extract(month from today)::int-extract(month from s.anchor)::int)/s.months);
 if uniion_private.dues_occurrence(s.anchor,s.months,n)<today then n=n+1;end if;
 d=uniion_private.dues_occurrence(s.anchor,s.months,n);
 if uniion_private.schedule_overlap(s.organization_id,s.adherent_id,date_trunc('month',d)::date,(date_trunc('month',d)+make_interval(months=>s.months))::date) then raise insufficient_privilege;end if;
 return jsonb_build_object('revision',s.revision,'memberVersion',a.version,'nextIndex',n,'nextDue',d,'oldCents',s.amount_cents,'cents',(a.dues_terms->>'cents')::bigint,'months',s.months,'skipped',n-s.next_index);
end$$;


--
-- Name: schedule_revision(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.schedule_revision() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$begin new.revision=old.revision+1;return new;end$$;


--
-- Name: session_allowed(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.session_allowed() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$begin return (
 select exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
 and (s.not_after is null or s.not_after>now())
 and ((auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.trusted_mfa_factors t
 join auth.mfa_factors f on f.id=t.factor_id and f.user_id=t.user_id
 where t.user_id=s.user_id and t.factor_id=s.factor_id and f.status='verified' and (t.valid_until is null or t.valid_until>now())))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal1'
 and not exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified')
 and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required))))
); end$$;


--
-- Name: share_access(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.share_access(sid uuid, res uuid, who uuid, dl boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select not exists(select 1 from uniion_private.meeting_minutes where resource_id=res) and uniion_private.share_access_before_minutes(sid,res,who,dl)
$$;


--
-- Name: share_access_before_ai_case(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.share_access_before_ai_case(sid uuid, res uuid, who uuid, dl boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select not exists(select 1 from uniion_private.message_files where resource=res) and uniion_private.share_access_before_messages(sid,res,who,dl)
$$;


--
-- Name: share_access_before_messages(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.share_access_before_messages(sid uuid, res uuid, who uuid, dl boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_shares s join public.uniion_share_items i on i.share_id=s.id
 join public.uniion_resources r on r.id=i.resource_id and r.organization_id=i.organization_id
 where s.id=sid and i.resource_id=res and i.organization_id=s.source_id and r.external_share_allowed
 and s.accepted_at is not null and s.revoked_at is null and s.expires_at>now() and who=any(s.beneficiaries)
 and uniion_private.actor_member(s.target_id,who)
 and uniion_private.authority(s.source_id,s.creator,'share')
 and uniion_private.actor_resource(s.source_id,res,s.creator,false)
 and exists(select 1 from public.uniion_permissions p join public.uniion_module_access a using(organization_id,module)
 where p.organization_id=s.target_id and p.user_id=who and p.module=r.module and p.permission='read' and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module))
 and (not dl or (s.download and uniion_private.authority(s.source_id,s.creator,'download') and uniion_private.authority(s.target_id,who,'download'))))
$$;


--
-- Name: share_access_before_minutes(uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.share_access_before_minutes(sid uuid, res uuid, who uuid, dl boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$select not exists(select 1 from uniion_private.ai_case_derivatives where resource=res) and uniion_private.share_access_before_ai_case(sid,res,who,dl)$$;


--
-- Name: storage_insert(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.storage_insert(path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_attachments a where a.object_name=path and not a.ready and a.creator=auth.uid() and a.created_at>now()-interval '15 minutes' and uniion_private.actor_resource(a.organization_id,a.resource_id,auth.uid(),true))
$$;


--
-- Name: storage_read(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.storage_read(path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from public.uniion_attachments a where a.object_name=path and (uniion_private.attachment_access(a.id,auth.uid()) or exists(select 1 from public.uniion_share_attachments sa where sa.attachment_id=a.id and uniion_private.attachment_access(a.id,auth.uid(),sa.share_id))))
$$;


--
-- Name: super_admin(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.super_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.session_allowed() and auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.super_admins where user_id=auth.uid() and active)
$$;


--
-- Name: support_assigned(uuid, uuid); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.support_assigned(t uuid, u uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select exists(select 1 from uniion_private.support_assignments x join uniion_private.support_agents a on a.user_id=x.user_id where x.ticket=t and x.active and a.user_id=u and a.active)
$$;


--
-- Name: support_requests_closed(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.support_requests_closed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin if new.state='closed' then update uniion_private.support_requests set status='cancelled' where ticket=new.id and status='pending';end if;return new;end $$;


--
-- Name: support_requests_granted(); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.support_requests_granted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin update uniion_private.support_requests set status='approved' where ticket=new.ticket and agent=any(new.agents) and status='pending';return new;end $$;


--
-- Name: transcription_storage(text); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.transcription_storage(path text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $_$
 select uniion_private.session_allowed() and exists(select 1 from uniion_private.transcription_workers where user_id=auth.uid()) and exists(select 1 from uniion_private.transcription_jobs j join uniion_private.transcription_parts p on p.job_id=j.id join uniion_private.meeting_audio a on a.id=p.id where a.path=$1 and p.result is null and j.worker=auth.uid() and j.state='running' and j.updated_at>now()-interval '6 minutes' and uniion_private.transcription_valid(j))
$_$;


--
-- Name: transcription_jobs; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.transcription_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    requester uuid NOT NULL,
    source_ids uuid[] NOT NULL,
    source_key text NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    lease uuid,
    worker uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    error text,
    CONSTRAINT transcription_jobs_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'running'::text, 'done'::text, 'error'::text, 'cancelled'::text])))
);


--
-- Name: transcription_valid(uniion_private.transcription_jobs); Type: FUNCTION; Schema: uniion_private; Owner: -
--

CREATE FUNCTION uniion_private.transcription_valid(j uniion_private.transcription_jobs) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
 select uniion_private.actor_resource(j.organization_id,j.meeting_id,j.requester,true)
 and uniion_private.commercial_allowed(j.organization_id,'reunions')
 and exists(select 1 from uniion_private.meeting_audio_grants g where g.organization_id=j.organization_id and g.meeting_id=j.meeting_id and g.user_id=j.requester and g.can_read and g.can_write)
 and not exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_audio a on a.id=p.id
 left join uniion_private.meeting_consents c on c.organization_id=a.organization_id and c.meeting_id=a.meeting_id
 left join public.uniion_resources r on r.id=a.meeting_id and r.organization_id=a.organization_id
 where p.job_id=j.id and (c.accepted is distinct from true or c.version is distinct from p.consent_version or r.version is distinct from p.meeting_version or c.meeting_version is distinct from p.meeting_version or a.sha256<>p.sha256 or a.status<>'clean' or exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=a.id and o.status<>'clean')))
$$;


--
-- Name: uniion_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    filename text NOT NULL,
    mime text NOT NULL,
    size integer NOT NULL,
    sha256 text NOT NULL,
    object_name text NOT NULL,
    creator uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ready boolean DEFAULT false NOT NULL,
    scan_status text DEFAULT 'pending'::text NOT NULL,
    scanned_at timestamp with time zone,
    scan_engine text,
    scan_reason text,
    scan_generation uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT uniion_attachments_filename_check CHECK ((((length(filename) >= 1) AND (length(filename) <= 180)) AND (filename !~ '[[:cntrl:]/\\]'::text))),
    CONSTRAINT uniion_attachments_mime_check CHECK ((mime = ANY (ARRAY['text/plain'::text, 'application/pdf'::text, 'image/png'::text, 'image/jpeg'::text, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::text, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'::text]))),
    CONSTRAINT uniion_attachments_scan_status_check CHECK ((scan_status = ANY (ARRAY['pending'::text, 'clean'::text, 'infected'::text, 'invalid'::text, 'error'::text]))),
    CONSTRAINT uniion_attachments_sha256_check CHECK ((sha256 ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT uniion_attachments_size_check CHECK (((size >= 1) AND (size <= 5242880))),
    CONSTRAINT uniion_clean_ready CHECK (((NOT ready) OR ((scan_status = 'clean'::text) AND (scanned_at IS NOT NULL))))
);


--
-- Name: uniion_authorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_authorities (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    permission text NOT NULL,
    delegable boolean DEFAULT false NOT NULL,
    CONSTRAINT uniion_authorities_permission_check CHECK (((permission = ANY (ARRAY['content_review'::text, 'content_publish'::text])) OR ((permission = ANY (ARRAY['document_review'::text, 'document_publish'::text])) OR ((permission = 'dossiers_assign'::text) OR (permission = ANY (ARRAY['rights'::text, 'share'::text, 'accept'::text, 'download'::text, 'history'::text, 'organization_edit'::text, 'collection_publish'::text, 'collection_accept'::text, 'agenda_audience'::text, 'agenda_convocation'::text, 'agenda_review'::text, 'agenda_publish'::text]))))))
);


--
-- Name: uniion_directory_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_directory_grants (
    organization_id uuid NOT NULL,
    target_id uuid NOT NULL,
    grantee uuid NOT NULL,
    listed_user uuid NOT NULL,
    approved_by uuid NOT NULL,
    valid_until timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT uniion_directory_grants_check CHECK ((organization_id <> target_id))
);


--
-- Name: uniion_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_events (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    actor uuid NOT NULL,
    resource_id uuid NOT NULL,
    event text NOT NULL,
    version integer NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: uniion_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.uniion_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.uniion_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: uniion_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_memberships (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone
);


--
-- Name: uniion_module_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_module_access (
    organization_id uuid NOT NULL,
    module text NOT NULL,
    authorized boolean DEFAULT false NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    entitlement text NOT NULL,
    valid_until timestamp with time zone NOT NULL,
    CONSTRAINT uniion_module_access_entitlement_check CHECK ((entitlement = ANY (ARRAY['paid'::text, 'commercial'::text, 'included'::text])))
);


--
-- Name: uniion_organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: uniion_partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_partners (
    source_id uuid NOT NULL,
    target_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT uniion_partners_check CHECK ((source_id <> target_id))
);


--
-- Name: uniion_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_permissions (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    module text NOT NULL,
    permission text NOT NULL,
    CONSTRAINT uniion_permissions_permission_check CHECK ((permission = ANY (ARRAY['read'::text, 'write'::text, 'create'::text])))
);


--
-- Name: uniion_resource_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_resource_grants (
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    user_id uuid NOT NULL,
    can_write boolean DEFAULT false NOT NULL,
    history_approved boolean DEFAULT false NOT NULL,
    valid_until timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone
);


--
-- Name: uniion_resource_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_resource_versions (
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    body jsonb NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL,
    actor uuid
);


--
-- Name: uniion_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_resources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    module text NOT NULL,
    title text NOT NULL,
    body jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    kind text DEFAULT 'resource'::text NOT NULL,
    client_id text,
    external_share_allowed boolean DEFAULT false NOT NULL
);


--
-- Name: uniion_security_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_security_events (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    target_id uuid,
    actor uuid NOT NULL,
    event text NOT NULL,
    details jsonb NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: uniion_security_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.uniion_security_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.uniion_security_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: uniion_share_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_share_attachments (
    share_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    attachment_id uuid NOT NULL
);


--
-- Name: uniion_share_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_share_items (
    share_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL
);


--
-- Name: uniion_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uniion_shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_id uuid NOT NULL,
    target_id uuid NOT NULL,
    creator uuid NOT NULL,
    allowed uuid[] NOT NULL,
    beneficiaries uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    download boolean DEFAULT false NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    accepted_by uuid,
    revoked_at timestamp with time zone,
    revoked_by uuid,
    CONSTRAINT uniion_shares_allowed_check CHECK ((cardinality(allowed) > 0)),
    CONSTRAINT uniion_shares_check CHECK ((source_id <> target_id)),
    CONSTRAINT uniion_shares_check1 CHECK ((beneficiaries <@ allowed))
);


--
-- Name: adherent_endings; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.adherent_endings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    adherent_id uuid NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid NOT NULL,
    payload jsonb NOT NULL,
    before_state jsonb NOT NULL,
    after_state jsonb NOT NULL,
    cycle integer DEFAULT 0 NOT NULL
);


--
-- Name: agenda_audiences; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_audiences (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    audience text NOT NULL,
    CONSTRAINT agenda_audiences_audience_check CHECK ((audience = ANY (ARRAY['none'::text, 'elus'::text, 'adherents'::text, 'public'::text])))
);


--
-- Name: agenda_convocation_deliveries; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_convocation_deliveries (
    convocation uuid NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'sending'::text NOT NULL,
    CONSTRAINT agenda_convocation_deliveries_status_check CHECK ((status = ANY (ARRAY['sending'::text, 'sent'::text, 'uncertain'::text, 'cancelled'::text])))
);


--
-- Name: agenda_convocations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_convocations (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    event_version integer NOT NULL,
    actor uuid NOT NULL,
    message jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agenda_documents; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_documents (
    event_id uuid NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_version integer NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    document jsonb NOT NULL,
    updated_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agenda_events; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    creator uuid NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    data jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agenda_image_receipts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_image_receipts (
    event_id uuid NOT NULL,
    digest text NOT NULL,
    engine text NOT NULL,
    scanned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agenda_publication_notifications; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_publication_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    version integer NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone
);


--
-- Name: agenda_publications; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_publications (
    event_id uuid NOT NULL,
    version integer NOT NULL,
    source_version integer NOT NULL,
    document jsonb NOT NULL,
    author uuid NOT NULL,
    reviewer uuid,
    reviewed_at timestamp with time zone,
    published_by uuid,
    published_at timestamp with time zone
);


--
-- Name: agenda_reminders; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.agenda_reminders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    version integer NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    sending_at timestamp with time zone,
    CONSTRAINT agenda_reminders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sending'::text, 'sent'::text, 'cancelled'::text, 'uncertain'::text])))
);


--
-- Name: ai_action_definitions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_action_definitions (
    id text NOT NULL,
    module text NOT NULL,
    roles jsonb NOT NULL
);


--
-- Name: ai_action_settings; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_action_settings (
    organization_id uuid NOT NULL,
    action text NOT NULL,
    enabled boolean NOT NULL,
    roles jsonb NOT NULL,
    version integer NOT NULL
);


--
-- Name: ai_activations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_activations (
    organization_id uuid NOT NULL,
    provider text NOT NULL,
    provider_version integer NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    updated_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ai_activations_version_check CHECK ((version > 0))
);


--
-- Name: ai_business_roles; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_business_roles (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    CONSTRAINT ai_business_roles_role_check CHECK ((role = ANY (ARRAY['secretaire'::text, 'tresorier'::text, 'titulaire'::text, 'suppleant'::text, 'ds'::text, 'ssct'::text])))
);


--
-- Name: ai_case_derivatives; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_case_derivatives (
    organization_id uuid NOT NULL,
    request uuid NOT NULL,
    actor uuid NOT NULL,
    resource uuid NOT NULL,
    refs jsonb NOT NULL
);


--
-- Name: ai_draft_applications; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_draft_applications (
    organization_id uuid NOT NULL,
    actor uuid NOT NULL,
    request_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    kind text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ai_draft_applications_kind_check CHECK ((kind = ANY (ARRAY['case'::text, 'document'::text, 'mobile-page'::text, 'mobile-short'::text, 'mobile-push'::text, 'communication-plan'::text])))
);


--
-- Name: ai_interactive_recipes; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_interactive_recipes (
    organization_id uuid NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: ai_providers; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_providers (
    id text NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    scope text DEFAULT 'fixture-only'::text NOT NULL,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    CONSTRAINT ai_providers_id_check CHECK ((id = 'codex-local'::text)),
    CONSTRAINT ai_providers_scope_check CHECK ((scope = 'fixture-only'::text)),
    CONSTRAINT ai_providers_version_check CHECK ((version > 0))
);


--
-- Name: ai_recipe_sources; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.ai_recipe_sources (
    organization_id uuid NOT NULL,
    kind text NOT NULL,
    id uuid NOT NULL,
    seq text DEFAULT ''::text NOT NULL,
    fingerprint text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    CONSTRAINT ai_recipe_sources_check CHECK ((((kind = 'message'::text) AND (seq <> ''::text)) OR ((kind <> 'message'::text) AND (seq = ''::text)))),
    CONSTRAINT ai_recipe_sources_fingerprint_check CHECK ((fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ai_recipe_sources_kind_check CHECK ((kind = ANY (ARRAY['case'::text, 'document'::text, 'message'::text, 'agenda'::text, 'adherents'::text, 'workspace'::text, 'reunions'::text, 'communication'::text, 'mobile'::text, 'formations'::text, 'sondages'::text, 'intranet'::text, 'reporting'::text, 'raccourcis'::text]))),
    CONSTRAINT ai_recipe_sources_seq_check CHECK (((seq = ''::text) OR (seq ~ '^[1-9][0-9]{0,17}$'::text)))
);


--
-- Name: audio_retention_batches; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.audio_retention_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    inventory jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    reason text,
    hold_until timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    finished_at timestamp with time zone,
    requested_by uuid,
    CONSTRAINT audio_retention_batches_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'held'::text, 'approved'::text, 'executing'::text, 'done'::text])))
);


--
-- Name: audio_retention_items; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.audio_retention_items (
    audio_id uuid NOT NULL,
    batch_id uuid NOT NULL
);


--
-- Name: audio_retention_validations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.audio_retention_validations (
    audio_id uuid NOT NULL,
    validated_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewer uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL
);


--
-- Name: audio_tombstones; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.audio_tombstones (
    audio_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    sha256 text NOT NULL,
    request_id uuid NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: business_publications; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.business_publications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    module text NOT NULL,
    body jsonb NOT NULL,
    recipients uuid[] NOT NULL,
    reviewer uuid NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL,
    publisher uuid,
    published_at timestamp with time zone,
    revoked_at timestamp with time zone
);


--
-- Name: business_records; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.business_records (
    organization_id uuid NOT NULL,
    id uuid NOT NULL,
    creator uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: case_disposals; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.case_disposals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    link uuid,
    version integer NOT NULL,
    reason text NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    requester uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    decider uuid,
    decided_at timestamp with time zone,
    CONSTRAINT case_disposals_reason_check CHECK ((reason = ANY (ARRAY['obsolete'::text, 'duplicate'::text, 'other'::text]))),
    CONSTRAINT case_disposals_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'restored'::text])))
);


--
-- Name: case_file_trash; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.case_file_trash (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    root uuid NOT NULL,
    revision integer NOT NULL,
    reason text NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    requester uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    approver uuid,
    decided_at timestamp with time zone,
    restored_by uuid,
    restored_at timestamp with time zone,
    CONSTRAINT case_file_trash_reason_check CHECK ((reason = ANY (ARRAY['obsolete'::text, 'duplicate'::text, 'other'::text]))),
    CONSTRAINT case_file_trash_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'restored'::text])))
);


--
-- Name: case_file_versions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.case_file_versions (
    root uuid NOT NULL,
    revision integer NOT NULL,
    attachment uuid NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT case_file_versions_revision_check CHECK ((revision > 0))
);


--
-- Name: case_history; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.case_history (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    actor uuid NOT NULL,
    happened_at timestamp with time zone DEFAULT now() NOT NULL,
    title text NOT NULL,
    body text NOT NULL
);


--
-- Name: case_history_id_seq; Type: SEQUENCE; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME uniion_private.case_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cases; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.cases (
    organization_id uuid NOT NULL,
    id uuid NOT NULL,
    status text DEFAULT 'todo'::text NOT NULL,
    tag text NOT NULL,
    due text DEFAULT ''::text NOT NULL,
    owner uuid NOT NULL,
    description text NOT NULL,
    CONSTRAINT cases_status_check CHECK ((status = ANY (ARRAY['todo'::text, 'doing'::text, 'done'::text])))
);


--
-- Name: collection_subscriptions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.collection_subscriptions (
    collection uuid NOT NULL,
    accepted integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    override_text text DEFAULT ''::text NOT NULL,
    declined jsonb DEFAULT '[]'::jsonb NOT NULL,
    history jsonb DEFAULT '[]'::jsonb NOT NULL,
    CONSTRAINT collection_subscriptions_override_text_check CHECK ((length(override_text) <= 400))
);


--
-- Name: collection_versions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.collection_versions (
    collection uuid NOT NULL,
    number integer NOT NULL,
    color text NOT NULL,
    text text NOT NULL,
    author uuid NOT NULL,
    published boolean DEFAULT false NOT NULL,
    reviewer uuid,
    CONSTRAINT collection_versions_check CHECK (((NOT published) OR ((reviewer IS NOT NULL) AND (reviewer <> author)))),
    CONSTRAINT collection_versions_color_check CHECK ((color ~ '^#[0-9a-fA-F]{6}$'::text)),
    CONSTRAINT collection_versions_number_check CHECK ((number > 0)),
    CONSTRAINT collection_versions_text_check CHECK (((length(text) >= 1) AND (length(text) <= 400)))
);


--
-- Name: collections; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.collections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source uuid NOT NULL,
    target uuid NOT NULL,
    name text NOT NULL,
    CONSTRAINT collections_check CHECK ((source <> target)),
    CONSTRAINT collections_name_check CHECK (((length(name) >= 1) AND (length(name) <= 160)))
);


--
-- Name: convocation_archives; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.convocation_archives (
    convocation uuid NOT NULL,
    organization_id uuid NOT NULL,
    files jsonb NOT NULL,
    ready boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: coverage_corrections; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.coverage_corrections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid NOT NULL,
    payload jsonb NOT NULL,
    before_state jsonb NOT NULL,
    after_state jsonb NOT NULL
);


--
-- Name: document_archives; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_archives (
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    pdf bytea NOT NULL,
    digest text NOT NULL,
    CONSTRAINT document_archives_pdf_check CHECK (((octet_length(pdf) >= 1) AND (octet_length(pdf) <= 20971520)))
);


--
-- Name: document_corrections; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_corrections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    actor uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_corrections_reason_check CHECK (((length(btrim(reason)) >= 5) AND (length(btrim(reason)) <= 2000)))
);


--
-- Name: document_default_receipts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_default_receipts (
    organization_id uuid NOT NULL,
    digest text NOT NULL,
    engine text NOT NULL,
    scanned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_default_versions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_default_versions (
    organization_id uuid NOT NULL,
    version integer NOT NULL,
    logo text NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_defaults; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_defaults (
    organization_id uuid NOT NULL,
    logo text NOT NULL,
    version integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_export_jobs; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_export_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    requester uuid NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    lease uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    result jsonb,
    error text,
    CONSTRAINT document_export_jobs_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'running'::text, 'done'::text, 'error'::text])))
);


--
-- Name: document_image_receipts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_image_receipts (
    document_id uuid NOT NULL,
    digest text NOT NULL,
    engine text NOT NULL,
    scanned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_notices; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_notices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    user_id uuid NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_publications; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.document_publications (
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    version integer NOT NULL,
    reviewer uuid NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL,
    publisher uuid,
    published_at timestamp with time zone
);


--
-- Name: documents; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.documents (
    organization_id uuid NOT NULL,
    id uuid NOT NULL,
    model text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: dues_corrections; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_corrections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    revision integer NOT NULL,
    amount_cents bigint NOT NULL,
    reason text NOT NULL,
    actor uuid NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid NOT NULL,
    effective_on date,
    CONSTRAINT dues_corrections_amount_cents_check CHECK (((amount_cents >= 0) AND (amount_cents <= '99999999999'::bigint))),
    CONSTRAINT dues_corrections_reason_check CHECK (((length(TRIM(BOTH FROM reason)) >= 3) AND (length(TRIM(BOTH FROM reason)) <= 500))),
    CONSTRAINT dues_corrections_revision_check CHECK ((revision > 0))
);


--
-- Name: dues_entries; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    adherent_id uuid NOT NULL,
    amount_cents bigint NOT NULL,
    currency text DEFAULT 'EUR'::text NOT NULL,
    period date NOT NULL,
    due_on date NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    paid_at timestamp with time zone,
    paid_by uuid,
    request_id uuid NOT NULL,
    schedule_id uuid,
    occurrence integer,
    coverage_end date,
    coverage_revision bigint DEFAULT 1 NOT NULL,
    CONSTRAINT dues_entries_amount_cents_check CHECK (((amount_cents > 0) AND (amount_cents <= '99999999999'::bigint))),
    CONSTRAINT dues_entries_check CHECK (((paid_at IS NULL) = (paid_by IS NULL))),
    CONSTRAINT dues_entries_currency_check CHECK ((currency = 'EUR'::text)),
    CONSTRAINT positive_coverage CHECK (((coverage_end IS NULL) OR (coverage_end > period)))
);


--
-- Name: dues_evidence; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_evidence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    filename text NOT NULL,
    mime text NOT NULL,
    size integer NOT NULL,
    sha256 text NOT NULL,
    path text NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    request_id uuid NOT NULL,
    CONSTRAINT dues_evidence_filename_check CHECK ((((length(filename) >= 1) AND (length(filename) <= 180)) AND (filename !~ '[[:cntrl:]/\\]'::text))),
    CONSTRAINT dues_evidence_mime_check CHECK ((mime = ANY (ARRAY['application/pdf'::text, 'image/png'::text, 'image/jpeg'::text, 'text/plain'::text, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::text, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'::text]))),
    CONSTRAINT dues_evidence_sha256_check CHECK ((sha256 ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT dues_evidence_size_check CHECK (((size >= 1) AND (size <= 5242880))),
    CONSTRAINT dues_evidence_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'clean'::text, 'blocked'::text])))
);


--
-- Name: dues_payments; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    amount_cents bigint NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    actor uuid NOT NULL,
    request_id uuid NOT NULL,
    effective_on date,
    CONSTRAINT dues_payments_amount_cents_check CHECK ((amount_cents > 0))
);


--
-- Name: dues_receipts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.dues_receipts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    revision integer NOT NULL,
    snapshot jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL
);


--
-- Name: identity_profiles; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.identity_profiles (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    role_label text NOT NULL
);


--
-- Name: invitations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    email text NOT NULL,
    token_hash text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    accepted_by uuid,
    revoked_at timestamp with time zone,
    CONSTRAINT invitations_check CHECK ((expires_at > created_at))
);


--
-- Name: lost_factor_jobs; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.lost_factor_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    factors uuid[] NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:30:00'::interval) NOT NULL,
    approved_by uuid,
    verification_reference text,
    state text DEFAULT 'pending'::text NOT NULL,
    lease uuid,
    lease_until timestamp with time zone,
    replacement_factor uuid,
    cancelled_at timestamp with time zone,
    CONSTRAINT lost_factor_jobs_factors_check CHECK ((cardinality(factors) > 0)),
    CONSTRAINT lost_factor_jobs_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'approved'::text, 'processing'::text, 'cleared'::text, 'enrolled'::text, 'cancelled'::text])))
);


--
-- Name: meeting_audio; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor uuid NOT NULL,
    consent_version integer NOT NULL,
    meeting_version integer NOT NULL,
    consent_actor uuid NOT NULL,
    consent_at timestamp with time zone NOT NULL,
    participants jsonb NOT NULL,
    filename text NOT NULL,
    size integer NOT NULL,
    sha256 text NOT NULL,
    path text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    duration_ms integer,
    CONSTRAINT meeting_audio_duration_ms_check CHECK (((duration_ms >= 0) AND (duration_ms <= 3600000))),
    CONSTRAINT meeting_audio_filename_check CHECK ((((length(filename) >= 5) AND (length(filename) <= 180)) AND (filename !~ '[[:cntrl:]/\\]'::text) AND (filename ~* '\.wav$'::text))),
    CONSTRAINT meeting_audio_sha256_check CHECK ((sha256 ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT meeting_audio_size_check CHECK (((size >= 44) AND (size <= 5242880))),
    CONSTRAINT meeting_audio_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'clean'::text, 'blocked'::text])))
);


--
-- Name: meeting_audio_chunks; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_chunks (
    audio_id uuid NOT NULL,
    part integer NOT NULL,
    bytes bytea NOT NULL,
    CONSTRAINT meeting_audio_chunks_bytes_check CHECK (((octet_length(bytes) >= 1) AND (octet_length(bytes) <= 262144))),
    CONSTRAINT meeting_audio_chunks_part_check CHECK (((part >= 0) AND (part <= 19)))
);


--
-- Name: meeting_audio_grants; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_grants (
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    user_id uuid NOT NULL,
    can_read boolean NOT NULL,
    can_write boolean NOT NULL,
    can_download boolean NOT NULL,
    version integer NOT NULL,
    CONSTRAINT meeting_audio_grants_version_check CHECK ((version > 0))
);


--
-- Name: meeting_audio_markers; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_markers (
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    audio_id uuid NOT NULL,
    version integer NOT NULL,
    markers jsonb NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT meeting_audio_markers_markers_check CHECK ((jsonb_typeof(markers) = 'array'::text)),
    CONSTRAINT meeting_audio_markers_version_check CHECK ((version > 0))
);


--
-- Name: meeting_audio_original_parts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_original_parts (
    audio_id uuid NOT NULL,
    part integer NOT NULL,
    bytes bytea NOT NULL,
    CONSTRAINT meeting_audio_original_parts_bytes_check CHECK (((octet_length(bytes) >= 1) AND (octet_length(bytes) <= 262144))),
    CONSTRAINT meeting_audio_original_parts_part_check CHECK (((part >= 0) AND (part <= 79)))
);


--
-- Name: meeting_audio_originals; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_originals (
    audio_id uuid NOT NULL,
    filename text NOT NULL,
    size integer NOT NULL,
    sha256 text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    CONSTRAINT meeting_audio_originals_filename_check CHECK ((((length(filename) >= 1) AND (length(filename) <= 180)) AND (filename !~ '[[:cntrl:]/\\]'::text))),
    CONSTRAINT meeting_audio_originals_sha256_check CHECK ((sha256 ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT meeting_audio_originals_size_check CHECK (((size >= 1) AND (size <= 20971520))),
    CONSTRAINT meeting_audio_originals_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'clean'::text, 'blocked'::text])))
);


--
-- Name: meeting_audio_policy; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_policy (
    organization_id uuid NOT NULL,
    local_hours integer NOT NULL,
    CONSTRAINT meeting_audio_policy_local_hours_check CHECK (((local_hours >= 1) AND (local_hours <= 168)))
);


--
-- Name: meeting_audio_sequences; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_audio_sequences (
    audio_id uuid NOT NULL,
    recording_id uuid NOT NULL,
    "position" integer NOT NULL,
    offset_ms bigint NOT NULL,
    CONSTRAINT meeting_audio_sequences_offset_ms_check CHECK (((offset_ms >= 0) AND (offset_ms <= 28800000))),
    CONSTRAINT meeting_audio_sequences_position_check CHECK ((("position" >= 0) AND ("position" <= 239)))
);


--
-- Name: meeting_consents; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_consents (
    organization_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    version integer NOT NULL,
    meeting_version integer NOT NULL,
    accepted boolean NOT NULL,
    actor uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT meeting_consents_version_check CHECK ((version > 0))
);


--
-- Name: meeting_minutes; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.meeting_minutes (
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    meeting_id uuid NOT NULL,
    job_id uuid NOT NULL,
    source_snapshot jsonb NOT NULL,
    creator uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: member_lists; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.member_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    criteria jsonb NOT NULL,
    request_id uuid NOT NULL,
    actor uuid NOT NULL,
    CONSTRAINT member_lists_description_check CHECK ((length(description) <= 500)),
    CONSTRAINT member_lists_name_check CHECK (((length(btrim(name)) >= 1) AND (length(btrim(name)) <= 180)))
);


--
-- Name: membership_changes; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.membership_changes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    adherent_id uuid NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid NOT NULL,
    action text NOT NULL,
    payload jsonb NOT NULL,
    before_state jsonb NOT NULL,
    after_state jsonb NOT NULL
);


--
-- Name: membership_suspensions; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.membership_suspensions (
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    suspended boolean NOT NULL
);


--
-- Name: message_conversations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_conversations (
    organization_id uuid NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pair text NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    next_seq bigint DEFAULT 0 NOT NULL,
    kind text DEFAULT 'direct'::text NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    creation_payload jsonb,
    CONSTRAINT message_conversations_kind_check CHECK ((kind = ANY (ARRAY['direct'::text, 'group'::text])))
);


--
-- Name: message_files; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_files (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    seq bigint NOT NULL,
    resource uuid NOT NULL,
    attachment uuid
);


--
-- Name: message_forward_batches; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_forward_batches (
    organization_id uuid NOT NULL,
    actor uuid NOT NULL,
    client_id uuid NOT NULL,
    source_conversation uuid NOT NULL,
    source_seq bigint NOT NULL,
    targets uuid[] NOT NULL,
    result jsonb NOT NULL
);


--
-- Name: message_forwards; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_forwards (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    seq bigint NOT NULL,
    source_conversation uuid NOT NULL,
    source_seq bigint NOT NULL
);


--
-- Name: message_history_grants; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_history_grants (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    participation uuid NOT NULL,
    message_seq bigint NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    granted_by uuid NOT NULL,
    granted_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    revoked_at timestamp with time zone
);


--
-- Name: message_participations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_participations (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    user_id uuid NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    joined_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    organization_joined_at timestamp with time zone NOT NULL,
    visible_from bigint DEFAULT 1 NOT NULL,
    left_at timestamp with time zone,
    is_admin boolean DEFAULT false NOT NULL
);


--
-- Name: message_reads; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.message_reads (
    organization_id uuid NOT NULL,
    conversation uuid NOT NULL,
    participation uuid NOT NULL,
    seq bigint NOT NULL,
    read_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: mfa_recovery_requests; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.mfa_recovery_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    factor_id uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:30:00'::interval) NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    verification_reference text
);


--
-- Name: mfa_requirements; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.mfa_requirements (
    user_id uuid NOT NULL,
    required boolean DEFAULT true NOT NULL
);


--
-- Name: module_catalog; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.module_catalog (
    id text NOT NULL,
    name text NOT NULL,
    available boolean DEFAULT true NOT NULL
);


--
-- Name: module_delegations; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.module_delegations (
    organization_id uuid NOT NULL,
    id text NOT NULL,
    enabled boolean DEFAULT false NOT NULL
);


--
-- Name: module_entitlements; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.module_entitlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    module text NOT NULL,
    kind text NOT NULL,
    starts timestamp with time zone NOT NULL,
    ends timestamp with time zone NOT NULL,
    reference text,
    reason text,
    created_by uuid,
    revoked_at timestamp with time zone,
    CONSTRAINT entitlement_evidence_required CHECK ((((kind = 'paid'::text) AND (reference IS NOT NULL) AND (length(btrim(reference)) > 0)) OR ((kind = 'commercial'::text) AND (reason IS NOT NULL) AND ((length(btrim(reason)) >= 1) AND (length(btrim(reason)) <= 240)) AND (created_by IS NOT NULL)))),
    CONSTRAINT module_entitlements_check CHECK ((ends > starts)),
    CONSTRAINT module_entitlements_check1 CHECK ((((kind = 'paid'::text) AND (length(btrim(reference)) > 0)) OR ((kind = 'commercial'::text) AND ((length(btrim(reason)) >= 1) AND (length(btrim(reason)) <= 240)) AND (created_by IS NOT NULL)))),
    CONSTRAINT module_entitlements_kind_check CHECK ((kind = ANY (ARRAY['paid'::text, 'commercial'::text])))
);


--
-- Name: module_events; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.module_events (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    module text NOT NULL,
    event text NOT NULL,
    actor uuid NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: module_events_id_seq; Type: SEQUENCE; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.module_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME uniion_private.module_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: organization_details; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.organization_details (
    organization_id uuid NOT NULL,
    details jsonb NOT NULL
);


--
-- Name: partner_events; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.partner_events (
    id bigint NOT NULL,
    source_id uuid NOT NULL,
    target_id uuid NOT NULL,
    enabled boolean NOT NULL,
    actor uuid NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: partner_events_id_seq; Type: SEQUENCE; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.partner_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME uniion_private.partner_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: platform_events; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.platform_events (
    id bigint NOT NULL,
    actor uuid NOT NULL,
    event text NOT NULL,
    subject uuid NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: platform_events_id_seq; Type: SEQUENCE; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.platform_events ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME uniion_private.platform_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: platform_operators; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.platform_operators (
    user_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: scan_workers; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.scan_workers (
    user_id uuid NOT NULL
);


--
-- Name: schedule_changes; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.schedule_changes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    schedule_id uuid NOT NULL,
    actor uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid NOT NULL,
    payload jsonb NOT NULL,
    before_state jsonb NOT NULL,
    after_state jsonb NOT NULL
);


--
-- Name: super_admins; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.super_admins (
    user_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: support_agents; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_agents (
    user_id uuid NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: support_assignments; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_assignments (
    ticket uuid NOT NULL,
    user_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: support_files; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_files (
    grant_id uuid NOT NULL,
    attachment uuid NOT NULL,
    sha256 text NOT NULL
);


--
-- Name: support_grants; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket uuid NOT NULL,
    agents uuid[] NOT NULL,
    expires timestamp with time zone NOT NULL,
    download boolean NOT NULL,
    creator uuid NOT NULL,
    revoked_at timestamp with time zone,
    excluded uuid[] DEFAULT '{}'::uuid[] NOT NULL
);


--
-- Name: support_items; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_items (
    grant_id uuid NOT NULL,
    resource uuid NOT NULL,
    version integer NOT NULL,
    title text NOT NULL,
    body jsonb NOT NULL
);


--
-- Name: support_requests; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket uuid NOT NULL,
    agent uuid NOT NULL,
    reason text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT support_requests_reason_check CHECK (((length(reason) >= 1) AND (length(reason) <= 240))),
    CONSTRAINT support_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text])))
);


--
-- Name: support_tickets; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.support_tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    title text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    state text DEFAULT 'open'::text NOT NULL,
    closed_at timestamp with time zone,
    closed_by uuid,
    CONSTRAINT support_tickets_state_check CHECK ((state = ANY (ARRAY['open'::text, 'closed'::text]))),
    CONSTRAINT support_tickets_title_check CHECK (((length(title) >= 1) AND (length(title) <= 120)))
);


--
-- Name: transcription_parts; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.transcription_parts (
    job_id uuid NOT NULL,
    id uuid NOT NULL,
    sha256 text NOT NULL,
    consent_version integer NOT NULL,
    meeting_version integer NOT NULL,
    offset_ms bigint NOT NULL,
    duration_ms integer NOT NULL,
    result jsonb
);


--
-- Name: transcription_workers; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.transcription_workers (
    user_id uuid NOT NULL
);


--
-- Name: trusted_mfa_factors; Type: TABLE; Schema: uniion_private; Owner: -
--

CREATE TABLE uniion_private.trusted_mfa_factors (
    factor_id uuid NOT NULL,
    user_id uuid NOT NULL,
    authorized_at timestamp with time zone DEFAULT now() NOT NULL,
    valid_until timestamp with time zone
);


--
-- Name: uniion_attachments uniion_attachments_object_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_attachments
    ADD CONSTRAINT uniion_attachments_object_name_key UNIQUE (object_name);


--
-- Name: uniion_attachments uniion_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_attachments
    ADD CONSTRAINT uniion_attachments_pkey PRIMARY KEY (id);


--
-- Name: uniion_authorities uniion_authorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_authorities
    ADD CONSTRAINT uniion_authorities_pkey PRIMARY KEY (organization_id, user_id, permission);


--
-- Name: uniion_directory_grants uniion_directory_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_pkey PRIMARY KEY (organization_id, target_id, grantee, listed_user);


--
-- Name: uniion_events uniion_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_events
    ADD CONSTRAINT uniion_events_pkey PRIMARY KEY (id);


--
-- Name: uniion_memberships uniion_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_memberships
    ADD CONSTRAINT uniion_memberships_pkey PRIMARY KEY (organization_id, user_id);


--
-- Name: uniion_module_access uniion_module_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_module_access
    ADD CONSTRAINT uniion_module_access_pkey PRIMARY KEY (organization_id, module);


--
-- Name: uniion_organizations uniion_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_organizations
    ADD CONSTRAINT uniion_organizations_pkey PRIMARY KEY (id);


--
-- Name: uniion_partners uniion_partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_partners
    ADD CONSTRAINT uniion_partners_pkey PRIMARY KEY (source_id, target_id);


--
-- Name: uniion_permissions uniion_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_permissions
    ADD CONSTRAINT uniion_permissions_pkey PRIMARY KEY (organization_id, user_id, module, permission);


--
-- Name: uniion_resource_grants uniion_resource_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_grants
    ADD CONSTRAINT uniion_resource_grants_pkey PRIMARY KEY (organization_id, resource_id, user_id);


--
-- Name: uniion_resource_versions uniion_resource_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_versions
    ADD CONSTRAINT uniion_resource_versions_pkey PRIMARY KEY (organization_id, resource_id, version);


--
-- Name: uniion_resources uniion_resources_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resources
    ADD CONSTRAINT uniion_resources_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: uniion_resources uniion_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resources
    ADD CONSTRAINT uniion_resources_pkey PRIMARY KEY (id);


--
-- Name: uniion_security_events uniion_security_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_security_events
    ADD CONSTRAINT uniion_security_events_pkey PRIMARY KEY (id);


--
-- Name: uniion_share_attachments uniion_share_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_attachments
    ADD CONSTRAINT uniion_share_attachments_pkey PRIMARY KEY (share_id, attachment_id);


--
-- Name: uniion_share_items uniion_share_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_items
    ADD CONSTRAINT uniion_share_items_pkey PRIMARY KEY (share_id, resource_id);


--
-- Name: uniion_shares uniion_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_pkey PRIMARY KEY (id);


--
-- Name: adherent_endings adherent_endings_organization_id_adherent_id_cycle_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherent_endings
    ADD CONSTRAINT adherent_endings_organization_id_adherent_id_cycle_key UNIQUE (organization_id, adherent_id, cycle);


--
-- Name: adherent_endings adherent_endings_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherent_endings
    ADD CONSTRAINT adherent_endings_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: adherent_endings adherent_endings_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherent_endings
    ADD CONSTRAINT adherent_endings_pkey PRIMARY KEY (id);


--
-- Name: adherents adherents_org_id_unique; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherents
    ADD CONSTRAINT adherents_org_id_unique UNIQUE (organization_id, id);


--
-- Name: adherents adherents_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherents
    ADD CONSTRAINT adherents_pkey PRIMARY KEY (id);


--
-- Name: agenda_audiences agenda_audiences_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_audiences
    ADD CONSTRAINT agenda_audiences_pkey PRIMARY KEY (organization_id, user_id);


--
-- Name: agenda_convocation_deliveries agenda_convocation_deliveries_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocation_deliveries
    ADD CONSTRAINT agenda_convocation_deliveries_pkey PRIMARY KEY (convocation, user_id);


--
-- Name: agenda_convocations agenda_convocations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocations
    ADD CONSTRAINT agenda_convocations_pkey PRIMARY KEY (id);


--
-- Name: agenda_documents agenda_documents_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_documents
    ADD CONSTRAINT agenda_documents_id_key UNIQUE (id);


--
-- Name: agenda_documents agenda_documents_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_documents
    ADD CONSTRAINT agenda_documents_pkey PRIMARY KEY (event_id);


--
-- Name: agenda_events agenda_events_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_events
    ADD CONSTRAINT agenda_events_pkey PRIMARY KEY (id);


--
-- Name: agenda_image_receipts agenda_image_receipts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_image_receipts
    ADD CONSTRAINT agenda_image_receipts_pkey PRIMARY KEY (event_id, digest);


--
-- Name: agenda_publication_notifications agenda_publication_notifications_event_id_version_user_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publication_notifications
    ADD CONSTRAINT agenda_publication_notifications_event_id_version_user_id_key UNIQUE (event_id, version, user_id);


--
-- Name: agenda_publication_notifications agenda_publication_notifications_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publication_notifications
    ADD CONSTRAINT agenda_publication_notifications_pkey PRIMARY KEY (id);


--
-- Name: agenda_publications agenda_publications_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publications
    ADD CONSTRAINT agenda_publications_pkey PRIMARY KEY (event_id, version);


--
-- Name: agenda_reminders agenda_reminders_event_id_version_user_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_reminders
    ADD CONSTRAINT agenda_reminders_event_id_version_user_id_key UNIQUE (event_id, version, user_id);


--
-- Name: agenda_reminders agenda_reminders_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_reminders
    ADD CONSTRAINT agenda_reminders_pkey PRIMARY KEY (id);


--
-- Name: ai_action_definitions ai_action_definitions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_action_definitions
    ADD CONSTRAINT ai_action_definitions_pkey PRIMARY KEY (id);


--
-- Name: ai_action_settings ai_action_settings_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_action_settings
    ADD CONSTRAINT ai_action_settings_pkey PRIMARY KEY (organization_id, action);


--
-- Name: ai_activations ai_activations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_activations
    ADD CONSTRAINT ai_activations_pkey PRIMARY KEY (organization_id);


--
-- Name: ai_business_roles ai_business_roles_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_business_roles
    ADD CONSTRAINT ai_business_roles_pkey PRIMARY KEY (organization_id, user_id, role);


--
-- Name: ai_case_derivatives ai_case_derivatives_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_case_derivatives
    ADD CONSTRAINT ai_case_derivatives_pkey PRIMARY KEY (organization_id, actor, request);


--
-- Name: ai_case_derivatives ai_case_derivatives_resource_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_case_derivatives
    ADD CONSTRAINT ai_case_derivatives_resource_key UNIQUE (resource);


--
-- Name: ai_draft_applications ai_draft_applications_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_draft_applications
    ADD CONSTRAINT ai_draft_applications_pkey PRIMARY KEY (organization_id, actor, request_id);


--
-- Name: ai_interactive_recipes ai_interactive_recipes_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_interactive_recipes
    ADD CONSTRAINT ai_interactive_recipes_pkey PRIMARY KEY (organization_id);


--
-- Name: ai_providers ai_providers_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_providers
    ADD CONSTRAINT ai_providers_pkey PRIMARY KEY (id);


--
-- Name: ai_recipe_sources ai_recipe_sources_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_recipe_sources
    ADD CONSTRAINT ai_recipe_sources_pkey PRIMARY KEY (organization_id, kind, id, seq);


--
-- Name: audio_retention_batches audio_retention_batches_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_batches
    ADD CONSTRAINT audio_retention_batches_pkey PRIMARY KEY (id);


--
-- Name: audio_retention_items audio_retention_items_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_items
    ADD CONSTRAINT audio_retention_items_pkey PRIMARY KEY (audio_id);


--
-- Name: audio_retention_validations audio_retention_validations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_validations
    ADD CONSTRAINT audio_retention_validations_pkey PRIMARY KEY (audio_id);


--
-- Name: audio_tombstones audio_tombstones_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_tombstones
    ADD CONSTRAINT audio_tombstones_pkey PRIMARY KEY (audio_id);


--
-- Name: business_publications business_publications_organization_id_resource_id_version_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_publications
    ADD CONSTRAINT business_publications_organization_id_resource_id_version_key UNIQUE (organization_id, resource_id, version);


--
-- Name: business_publications business_publications_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_publications
    ADD CONSTRAINT business_publications_pkey PRIMARY KEY (id);


--
-- Name: business_records business_records_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_records
    ADD CONSTRAINT business_records_pkey PRIMARY KEY (id);


--
-- Name: case_disposals case_disposals_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_disposals
    ADD CONSTRAINT case_disposals_pkey PRIMARY KEY (id);


--
-- Name: case_file_trash case_file_trash_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_pkey PRIMARY KEY (id);


--
-- Name: case_file_versions case_file_versions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_versions
    ADD CONSTRAINT case_file_versions_pkey PRIMARY KEY (root, revision);


--
-- Name: case_history case_history_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_history
    ADD CONSTRAINT case_history_pkey PRIMARY KEY (id);


--
-- Name: case_links case_links_organization_id_resource_id_convocation_file_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_links_organization_id_resource_id_convocation_file_key UNIQUE (organization_id, resource_id, convocation, file);


--
-- Name: case_links case_links_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_links_pkey PRIMARY KEY (id);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: collection_subscriptions collection_subscriptions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_subscriptions
    ADD CONSTRAINT collection_subscriptions_pkey PRIMARY KEY (collection);


--
-- Name: collection_versions collection_versions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_versions
    ADD CONSTRAINT collection_versions_pkey PRIMARY KEY (collection, number);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: convocation_archives convocation_archives_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.convocation_archives
    ADD CONSTRAINT convocation_archives_pkey PRIMARY KEY (convocation);


--
-- Name: coverage_corrections coverage_corrections_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.coverage_corrections
    ADD CONSTRAINT coverage_corrections_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: coverage_corrections coverage_corrections_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.coverage_corrections
    ADD CONSTRAINT coverage_corrections_pkey PRIMARY KEY (id);


--
-- Name: document_archives document_archives_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_archives
    ADD CONSTRAINT document_archives_pkey PRIMARY KEY (organization_id, resource_id, version);


--
-- Name: document_corrections document_corrections_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_corrections
    ADD CONSTRAINT document_corrections_pkey PRIMARY KEY (id);


--
-- Name: document_default_receipts document_default_receipts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_default_receipts
    ADD CONSTRAINT document_default_receipts_pkey PRIMARY KEY (organization_id, digest);


--
-- Name: document_default_versions document_default_versions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_default_versions
    ADD CONSTRAINT document_default_versions_pkey PRIMARY KEY (organization_id, version);


--
-- Name: document_defaults document_defaults_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_defaults
    ADD CONSTRAINT document_defaults_pkey PRIMARY KEY (organization_id);


--
-- Name: document_export_jobs document_export_jobs_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_export_jobs
    ADD CONSTRAINT document_export_jobs_pkey PRIMARY KEY (id);


--
-- Name: document_export_jobs document_export_jobs_resource_id_version_requester_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_export_jobs
    ADD CONSTRAINT document_export_jobs_resource_id_version_requester_key UNIQUE (resource_id, version, requester);


--
-- Name: document_image_receipts document_image_receipts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_image_receipts
    ADD CONSTRAINT document_image_receipts_pkey PRIMARY KEY (document_id, digest);


--
-- Name: document_notices document_notices_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_notices
    ADD CONSTRAINT document_notices_pkey PRIMARY KEY (id);


--
-- Name: document_notices document_notices_resource_id_version_user_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_notices
    ADD CONSTRAINT document_notices_resource_id_version_user_id_key UNIQUE (resource_id, version, user_id);


--
-- Name: document_publications document_publications_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_publications
    ADD CONSTRAINT document_publications_pkey PRIMARY KEY (organization_id, resource_id, version);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: dues_corrections dues_corrections_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_corrections
    ADD CONSTRAINT dues_corrections_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: dues_corrections dues_corrections_payment_id_revision_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_corrections
    ADD CONSTRAINT dues_corrections_payment_id_revision_key UNIQUE (payment_id, revision);


--
-- Name: dues_corrections dues_corrections_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_corrections
    ADD CONSTRAINT dues_corrections_pkey PRIMARY KEY (id);


--
-- Name: dues_entries dues_entries_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_entries_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: dues_entries dues_entries_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_entries_pkey PRIMARY KEY (id);


--
-- Name: dues_evidence dues_evidence_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_evidence
    ADD CONSTRAINT dues_evidence_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: dues_evidence dues_evidence_path_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_evidence
    ADD CONSTRAINT dues_evidence_path_key UNIQUE (path);


--
-- Name: dues_evidence dues_evidence_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_evidence
    ADD CONSTRAINT dues_evidence_pkey PRIMARY KEY (id);


--
-- Name: dues_entries dues_org_id_unique; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_org_id_unique UNIQUE (organization_id, id);


--
-- Name: dues_payments dues_payments_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_payments
    ADD CONSTRAINT dues_payments_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: dues_payments dues_payments_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_payments
    ADD CONSTRAINT dues_payments_pkey PRIMARY KEY (id);


--
-- Name: dues_receipts dues_receipts_payment_id_revision_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_receipts
    ADD CONSTRAINT dues_receipts_payment_id_revision_key UNIQUE (payment_id, revision);


--
-- Name: dues_receipts dues_receipts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_receipts
    ADD CONSTRAINT dues_receipts_pkey PRIMARY KEY (id);


--
-- Name: dues_entries dues_schedule_occurrence; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_schedule_occurrence UNIQUE (schedule_id, occurrence);


--
-- Name: dues_schedules dues_schedules_organization_id_adherent_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_schedules
    ADD CONSTRAINT dues_schedules_organization_id_adherent_id_key UNIQUE (organization_id, adherent_id);


--
-- Name: dues_schedules dues_schedules_organization_id_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_schedules
    ADD CONSTRAINT dues_schedules_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: dues_schedules dues_schedules_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_schedules
    ADD CONSTRAINT dues_schedules_pkey PRIMARY KEY (id);


--
-- Name: identity_profiles identity_profiles_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.identity_profiles
    ADD CONSTRAINT identity_profiles_pkey PRIMARY KEY (organization_id, user_id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_token_hash_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.invitations
    ADD CONSTRAINT invitations_token_hash_key UNIQUE (token_hash);


--
-- Name: lost_factor_jobs lost_factor_jobs_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.lost_factor_jobs
    ADD CONSTRAINT lost_factor_jobs_pkey PRIMARY KEY (id);


--
-- Name: meeting_audio_chunks meeting_audio_chunks_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_chunks
    ADD CONSTRAINT meeting_audio_chunks_pkey PRIMARY KEY (audio_id, part);


--
-- Name: meeting_audio_grants meeting_audio_grants_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_grants
    ADD CONSTRAINT meeting_audio_grants_pkey PRIMARY KEY (organization_id, meeting_id, user_id);


--
-- Name: meeting_audio_markers meeting_audio_markers_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_markers
    ADD CONSTRAINT meeting_audio_markers_pkey PRIMARY KEY (organization_id, meeting_id, audio_id, version);


--
-- Name: meeting_audio meeting_audio_organization_id_actor_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_organization_id_actor_request_id_key UNIQUE (organization_id, actor, request_id);


--
-- Name: meeting_audio meeting_audio_organization_id_meeting_id_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_organization_id_meeting_id_id_key UNIQUE (organization_id, meeting_id, id);


--
-- Name: meeting_audio_original_parts meeting_audio_original_parts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_original_parts
    ADD CONSTRAINT meeting_audio_original_parts_pkey PRIMARY KEY (audio_id, part);


--
-- Name: meeting_audio_originals meeting_audio_originals_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_originals
    ADD CONSTRAINT meeting_audio_originals_pkey PRIMARY KEY (audio_id);


--
-- Name: meeting_audio meeting_audio_path_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_path_key UNIQUE (path);


--
-- Name: meeting_audio meeting_audio_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_pkey PRIMARY KEY (id);


--
-- Name: meeting_audio_policy meeting_audio_policy_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_policy
    ADD CONSTRAINT meeting_audio_policy_pkey PRIMARY KEY (organization_id);


--
-- Name: meeting_audio_sequences meeting_audio_sequences_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_sequences
    ADD CONSTRAINT meeting_audio_sequences_pkey PRIMARY KEY (audio_id);


--
-- Name: meeting_audio_sequences meeting_audio_sequences_recording_id_position_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_sequences
    ADD CONSTRAINT meeting_audio_sequences_recording_id_position_key UNIQUE (recording_id, "position");


--
-- Name: meeting_consents meeting_consents_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_consents
    ADD CONSTRAINT meeting_consents_pkey PRIMARY KEY (organization_id, meeting_id);


--
-- Name: meeting_minutes meeting_minutes_organization_id_meeting_id_job_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_organization_id_meeting_id_job_id_key UNIQUE (organization_id, meeting_id, job_id);


--
-- Name: meeting_minutes meeting_minutes_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_pkey PRIMARY KEY (resource_id);


--
-- Name: member_lists member_lists_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.member_lists
    ADD CONSTRAINT member_lists_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: member_lists member_lists_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.member_lists
    ADD CONSTRAINT member_lists_pkey PRIMARY KEY (id);


--
-- Name: membership_changes membership_changes_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_changes
    ADD CONSTRAINT membership_changes_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: membership_changes membership_changes_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_changes
    ADD CONSTRAINT membership_changes_pkey PRIMARY KEY (id);


--
-- Name: membership_suspensions membership_suspensions_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_suspensions
    ADD CONSTRAINT membership_suspensions_pkey PRIMARY KEY (organization_id, user_id);


--
-- Name: message_conversations message_conversations_organization_id_pair_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_conversations
    ADD CONSTRAINT message_conversations_organization_id_pair_key UNIQUE (organization_id, pair);


--
-- Name: message_conversations message_conversations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_conversations
    ADD CONSTRAINT message_conversations_pkey PRIMARY KEY (organization_id, id);


--
-- Name: message_files message_files_attachment_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_attachment_key UNIQUE (attachment);


--
-- Name: message_files message_files_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_pkey PRIMARY KEY (organization_id, conversation, seq);


--
-- Name: message_files message_files_resource_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_resource_key UNIQUE (resource);


--
-- Name: message_forward_batches message_forward_batches_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forward_batches
    ADD CONSTRAINT message_forward_batches_pkey PRIMARY KEY (organization_id, actor, client_id);


--
-- Name: message_forwards message_forwards_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forwards
    ADD CONSTRAINT message_forwards_pkey PRIMARY KEY (organization_id, conversation, seq);


--
-- Name: message_history_grants message_history_grants_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_history_grants
    ADD CONSTRAINT message_history_grants_pkey PRIMARY KEY (organization_id, id);


--
-- Name: message_participations message_participations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_participations
    ADD CONSTRAINT message_participations_pkey PRIMARY KEY (organization_id, conversation, id);


--
-- Name: message_reads message_reads_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_reads
    ADD CONSTRAINT message_reads_pkey PRIMARY KEY (organization_id, conversation, participation);


--
-- Name: messages messages_organization_id_conversation_author_client_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_organization_id_conversation_author_client_id_key UNIQUE (organization_id, conversation, author, client_id);


--
-- Name: messages messages_organization_id_conversation_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_organization_id_conversation_id_key UNIQUE (organization_id, conversation, id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (organization_id, conversation, seq);


--
-- Name: mfa_recovery_requests mfa_recovery_requests_factor_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_recovery_requests
    ADD CONSTRAINT mfa_recovery_requests_factor_id_key UNIQUE (factor_id);


--
-- Name: mfa_recovery_requests mfa_recovery_requests_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_recovery_requests
    ADD CONSTRAINT mfa_recovery_requests_pkey PRIMARY KEY (id);


--
-- Name: mfa_requirements mfa_requirements_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_requirements
    ADD CONSTRAINT mfa_requirements_pkey PRIMARY KEY (user_id);


--
-- Name: module_catalog module_catalog_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_catalog
    ADD CONSTRAINT module_catalog_pkey PRIMARY KEY (id);


--
-- Name: module_delegations module_delegations_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_delegations
    ADD CONSTRAINT module_delegations_pkey PRIMARY KEY (organization_id, id);


--
-- Name: module_entitlements module_entitlements_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_entitlements
    ADD CONSTRAINT module_entitlements_pkey PRIMARY KEY (id);


--
-- Name: module_events module_events_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_events
    ADD CONSTRAINT module_events_pkey PRIMARY KEY (id);


--
-- Name: organization_details organization_details_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.organization_details
    ADD CONSTRAINT organization_details_pkey PRIMARY KEY (organization_id);


--
-- Name: partner_events partner_events_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.partner_events
    ADD CONSTRAINT partner_events_pkey PRIMARY KEY (id);


--
-- Name: dues_payments payments_org_id; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_payments
    ADD CONSTRAINT payments_org_id UNIQUE (organization_id, id);


--
-- Name: platform_events platform_events_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.platform_events
    ADD CONSTRAINT platform_events_pkey PRIMARY KEY (id);


--
-- Name: platform_operators platform_operators_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.platform_operators
    ADD CONSTRAINT platform_operators_pkey PRIMARY KEY (user_id);


--
-- Name: scan_workers scan_workers_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.scan_workers
    ADD CONSTRAINT scan_workers_pkey PRIMARY KEY (user_id);


--
-- Name: schedule_changes schedule_changes_organization_id_request_id_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.schedule_changes
    ADD CONSTRAINT schedule_changes_organization_id_request_id_key UNIQUE (organization_id, request_id);


--
-- Name: schedule_changes schedule_changes_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.schedule_changes
    ADD CONSTRAINT schedule_changes_pkey PRIMARY KEY (id);


--
-- Name: super_admins super_admins_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.super_admins
    ADD CONSTRAINT super_admins_pkey PRIMARY KEY (user_id);


--
-- Name: support_agents support_agents_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_agents
    ADD CONSTRAINT support_agents_pkey PRIMARY KEY (user_id);


--
-- Name: support_assignments support_assignments_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_assignments
    ADD CONSTRAINT support_assignments_pkey PRIMARY KEY (ticket, user_id);


--
-- Name: support_files support_files_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_files
    ADD CONSTRAINT support_files_pkey PRIMARY KEY (grant_id, attachment);


--
-- Name: support_grants support_grants_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_grants
    ADD CONSTRAINT support_grants_pkey PRIMARY KEY (id);


--
-- Name: support_items support_items_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_items
    ADD CONSTRAINT support_items_pkey PRIMARY KEY (grant_id, resource);


--
-- Name: support_requests support_requests_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_requests
    ADD CONSTRAINT support_requests_pkey PRIMARY KEY (id);


--
-- Name: support_tickets support_tickets_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_tickets
    ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);


--
-- Name: transcription_jobs transcription_jobs_organization_id_meeting_id_requester_sou_key; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_jobs
    ADD CONSTRAINT transcription_jobs_organization_id_meeting_id_requester_sou_key UNIQUE (organization_id, meeting_id, requester, source_key);


--
-- Name: transcription_jobs transcription_jobs_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_jobs
    ADD CONSTRAINT transcription_jobs_pkey PRIMARY KEY (id);


--
-- Name: transcription_parts transcription_parts_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_parts
    ADD CONSTRAINT transcription_parts_pkey PRIMARY KEY (job_id, id);


--
-- Name: transcription_workers transcription_workers_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_workers
    ADD CONSTRAINT transcription_workers_pkey PRIMARY KEY (user_id);


--
-- Name: trusted_mfa_factors trusted_mfa_factors_pkey; Type: CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.trusted_mfa_factors
    ADD CONSTRAINT trusted_mfa_factors_pkey PRIMARY KEY (factor_id);


--
-- Name: uniion_memberships_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uniion_memberships_user ON public.uniion_memberships USING btree (user_id);


--
-- Name: uniion_resource_client; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniion_resource_client ON public.uniion_resources USING btree (organization_id, kind, client_id);


--
-- Name: uniion_resources_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uniion_resources_org ON public.uniion_resources USING btree (organization_id);


--
-- Name: uniion_shares_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uniion_shares_source ON public.uniion_shares USING btree (source_id);


--
-- Name: uniion_shares_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uniion_shares_target ON public.uniion_shares USING btree (target_id);


--
-- Name: adherents_email_org; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX adherents_email_org ON uniion_private.adherents USING btree (organization_id, lower((data ->> 'email'::text)));


--
-- Name: case_disposals_active; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX case_disposals_active ON uniion_private.case_disposals USING btree (resource_id, COALESCE(link, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE (state = ANY (ARRAY['pending'::text, 'approved'::text]));


--
-- Name: case_file_trash_active; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX case_file_trash_active ON uniion_private.case_file_trash USING btree (root) WHERE (state = ANY (ARRAY['pending'::text, 'approved'::text]));


--
-- Name: case_message_link_once; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX case_message_link_once ON uniion_private.case_links USING btree (organization_id, resource_id, message_conversation, message_seq, file) WHERE (message_conversation IS NOT NULL);


--
-- Name: message_current_participant; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX message_current_participant ON uniion_private.message_participations USING btree (organization_id, conversation, user_id) WHERE (left_at IS NULL);


--
-- Name: message_history_active; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX message_history_active ON uniion_private.message_history_grants USING btree (organization_id, conversation, participation, message_seq) WHERE (revoked_at IS NULL);


--
-- Name: message_notice_order; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE INDEX message_notice_order ON uniion_private.messages USING btree (organization_id, created_at DESC, id);


--
-- Name: message_participant_lookup; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE INDEX message_participant_lookup ON uniion_private.message_participations USING btree (organization_id, user_id, conversation) WHERE (left_at IS NULL);


--
-- Name: messages_search_cursor; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE INDEX messages_search_cursor ON uniion_private.messages USING btree (organization_id, id DESC);


--
-- Name: one_collection_draft; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX one_collection_draft ON uniion_private.collection_versions USING btree (collection) WHERE (NOT published);


--
-- Name: support_one_pending; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX support_one_pending ON uniion_private.support_requests USING btree (ticket, agent) WHERE (status = 'pending'::text);


--
-- Name: uniion_pending_invitation; Type: INDEX; Schema: uniion_private; Owner: -
--

CREATE UNIQUE INDEX uniion_pending_invitation ON uniion_private.invitations USING btree (organization_id, email) WHERE ((accepted_at IS NULL) AND (revoked_at IS NULL));


--
-- Name: uniion_resources uniion_record_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER uniion_record_version AFTER INSERT OR UPDATE OF body ON public.uniion_resources FOR EACH ROW EXECUTE FUNCTION uniion_private.record_version();


--
-- Name: adherents adherent_typed; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER adherent_typed BEFORE INSERT OR UPDATE ON uniion_private.adherents FOR EACH ROW EXECUTE FUNCTION uniion_private.adherent_validate_typed();


--
-- Name: agenda_documents agenda_document_charter_insert; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER agenda_document_charter_insert BEFORE INSERT ON uniion_private.agenda_documents FOR EACH ROW EXECUTE FUNCTION uniion_private.agenda_document_charter();


--
-- Name: agenda_publications agenda_publication_notified; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER agenda_publication_notified AFTER INSERT OR UPDATE ON uniion_private.agenda_publications FOR EACH ROW EXECUTE FUNCTION uniion_private.agenda_publication_notify();


--
-- Name: dues_entries coverage_revision; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER coverage_revision BEFORE UPDATE ON uniion_private.dues_entries FOR EACH ROW EXECUTE FUNCTION uniion_private.coverage_revision();


--
-- Name: dues_entries entry_coverage; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER entry_coverage BEFORE INSERT ON uniion_private.dues_entries FOR EACH ROW EXECUTE FUNCTION uniion_private.entry_coverage();


--
-- Name: dues_entries entry_membership_end; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER entry_membership_end BEFORE INSERT ON uniion_private.dues_entries FOR EACH ROW EXECUTE FUNCTION uniion_private.entry_membership_end();


--
-- Name: adherents new_dues_schedule; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER new_dues_schedule AFTER INSERT ON uniion_private.adherents FOR EACH ROW EXECUTE FUNCTION uniion_private.new_dues_schedule();


--
-- Name: dues_schedules schedule_end_guard; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER schedule_end_guard BEFORE INSERT OR UPDATE ON uniion_private.dues_schedules FOR EACH ROW EXECUTE FUNCTION uniion_private.schedule_end_guard();


--
-- Name: dues_schedules schedule_revision; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER schedule_revision BEFORE UPDATE ON uniion_private.dues_schedules FOR EACH ROW EXECUTE FUNCTION uniion_private.schedule_revision();


--
-- Name: support_tickets support_requests_closed; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER support_requests_closed AFTER UPDATE OF state ON uniion_private.support_tickets FOR EACH ROW EXECUTE FUNCTION uniion_private.support_requests_closed();


--
-- Name: support_grants support_requests_granted; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER support_requests_granted AFTER INSERT ON uniion_private.support_grants FOR EACH ROW EXECUTE FUNCTION uniion_private.support_requests_granted();


--
-- Name: meeting_audio uniion_audio_tombstone; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER uniion_audio_tombstone BEFORE INSERT OR UPDATE ON uniion_private.meeting_audio FOR EACH ROW EXECUTE FUNCTION uniion_private.prevent_audio_resurrection();


--
-- Name: business_publications uniion_audio_validation; Type: TRIGGER; Schema: uniion_private; Owner: -
--

CREATE TRIGGER uniion_audio_validation AFTER INSERT OR UPDATE OF reviewed_at, published_at, revoked_at ON uniion_private.business_publications FOR EACH ROW EXECUTE FUNCTION uniion_private.record_audio_validation();


--
-- Name: uniion_attachments uniion_attachments_creator_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_attachments
    ADD CONSTRAINT uniion_attachments_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: uniion_attachments uniion_attachments_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_attachments
    ADD CONSTRAINT uniion_attachments_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: uniion_authorities uniion_authorities_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_authorities
    ADD CONSTRAINT uniion_authorities_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: uniion_directory_grants uniion_directory_grants_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);


--
-- Name: uniion_directory_grants uniion_directory_grants_grantee_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_grantee_fkey FOREIGN KEY (grantee) REFERENCES auth.users(id);


--
-- Name: uniion_directory_grants uniion_directory_grants_listed_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_listed_user_fkey FOREIGN KEY (listed_user) REFERENCES auth.users(id);


--
-- Name: uniion_directory_grants uniion_directory_grants_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_directory_grants uniion_directory_grants_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_directory_grants
    ADD CONSTRAINT uniion_directory_grants_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_events uniion_events_actor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_events
    ADD CONSTRAINT uniion_events_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: uniion_events uniion_events_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_events
    ADD CONSTRAINT uniion_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_memberships uniion_memberships_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_memberships
    ADD CONSTRAINT uniion_memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_memberships uniion_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_memberships
    ADD CONSTRAINT uniion_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: uniion_module_access uniion_module_access_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_module_access
    ADD CONSTRAINT uniion_module_access_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_partners uniion_partners_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_partners
    ADD CONSTRAINT uniion_partners_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_partners uniion_partners_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_partners
    ADD CONSTRAINT uniion_partners_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_permissions uniion_permissions_organization_id_module_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_permissions
    ADD CONSTRAINT uniion_permissions_organization_id_module_fkey FOREIGN KEY (organization_id, module) REFERENCES public.uniion_module_access(organization_id, module);


--
-- Name: uniion_permissions uniion_permissions_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_permissions
    ADD CONSTRAINT uniion_permissions_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: uniion_resource_grants uniion_resource_grants_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_grants
    ADD CONSTRAINT uniion_resource_grants_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: uniion_resource_grants uniion_resource_grants_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_grants
    ADD CONSTRAINT uniion_resource_grants_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: uniion_resource_versions uniion_resource_versions_actor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_versions
    ADD CONSTRAINT uniion_resource_versions_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: uniion_resource_versions uniion_resource_versions_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resource_versions
    ADD CONSTRAINT uniion_resource_versions_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: uniion_resources uniion_resources_organization_id_module_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_resources
    ADD CONSTRAINT uniion_resources_organization_id_module_fkey FOREIGN KEY (organization_id, module) REFERENCES public.uniion_module_access(organization_id, module);


--
-- Name: uniion_security_events uniion_security_events_actor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_security_events
    ADD CONSTRAINT uniion_security_events_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: uniion_security_events uniion_security_events_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_security_events
    ADD CONSTRAINT uniion_security_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_security_events uniion_security_events_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_security_events
    ADD CONSTRAINT uniion_security_events_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_share_attachments uniion_share_attachments_attachment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_attachments
    ADD CONSTRAINT uniion_share_attachments_attachment_id_fkey FOREIGN KEY (attachment_id) REFERENCES public.uniion_attachments(id);


--
-- Name: uniion_share_attachments uniion_share_attachments_share_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_attachments
    ADD CONSTRAINT uniion_share_attachments_share_id_resource_id_fkey FOREIGN KEY (share_id, resource_id) REFERENCES public.uniion_share_items(share_id, resource_id);


--
-- Name: uniion_share_items uniion_share_items_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_items
    ADD CONSTRAINT uniion_share_items_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES public.uniion_resource_versions(organization_id, resource_id, version);


--
-- Name: uniion_share_items uniion_share_items_share_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_share_items
    ADD CONSTRAINT uniion_share_items_share_id_fkey FOREIGN KEY (share_id) REFERENCES public.uniion_shares(id);


--
-- Name: uniion_shares uniion_shares_accepted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES auth.users(id);


--
-- Name: uniion_shares uniion_shares_creator_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: uniion_shares uniion_shares_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES auth.users(id);


--
-- Name: uniion_shares uniion_shares_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.uniion_organizations(id);


--
-- Name: uniion_shares uniion_shares_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uniion_shares
    ADD CONSTRAINT uniion_shares_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.uniion_organizations(id);


--
-- Name: adherent_endings adherent_endings_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherent_endings
    ADD CONSTRAINT adherent_endings_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: adherent_endings adherent_endings_organization_id_adherent_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherent_endings
    ADD CONSTRAINT adherent_endings_organization_id_adherent_id_fkey FOREIGN KEY (organization_id, adherent_id) REFERENCES uniion_private.adherents(organization_id, id);


--
-- Name: adherents adherents_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.adherents
    ADD CONSTRAINT adherents_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: agenda_audiences agenda_audiences_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_audiences
    ADD CONSTRAINT agenda_audiences_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: agenda_audiences agenda_audiences_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_audiences
    ADD CONSTRAINT agenda_audiences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: agenda_convocation_deliveries agenda_convocation_deliveries_convocation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocation_deliveries
    ADD CONSTRAINT agenda_convocation_deliveries_convocation_fkey FOREIGN KEY (convocation) REFERENCES uniion_private.agenda_convocations(id);


--
-- Name: agenda_convocation_deliveries agenda_convocation_deliveries_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocation_deliveries
    ADD CONSTRAINT agenda_convocation_deliveries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: agenda_convocations agenda_convocations_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocations
    ADD CONSTRAINT agenda_convocations_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: agenda_convocations agenda_convocations_event_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_convocations
    ADD CONSTRAINT agenda_convocations_event_id_fkey FOREIGN KEY (event_id) REFERENCES uniion_private.agenda_events(id);


--
-- Name: agenda_documents agenda_documents_event_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_documents
    ADD CONSTRAINT agenda_documents_event_id_fkey FOREIGN KEY (event_id) REFERENCES uniion_private.agenda_events(id);


--
-- Name: agenda_documents agenda_documents_updated_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_documents
    ADD CONSTRAINT agenda_documents_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id);


--
-- Name: agenda_events agenda_events_creator_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_events
    ADD CONSTRAINT agenda_events_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: agenda_events agenda_events_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_events
    ADD CONSTRAINT agenda_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: agenda_image_receipts agenda_image_receipts_event_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_image_receipts
    ADD CONSTRAINT agenda_image_receipts_event_id_fkey FOREIGN KEY (event_id) REFERENCES uniion_private.agenda_events(id);


--
-- Name: agenda_publication_notifications agenda_publication_notifications_event_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publication_notifications
    ADD CONSTRAINT agenda_publication_notifications_event_id_version_fkey FOREIGN KEY (event_id, version) REFERENCES uniion_private.agenda_publications(event_id, version);


--
-- Name: agenda_publication_notifications agenda_publication_notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publication_notifications
    ADD CONSTRAINT agenda_publication_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: agenda_publications agenda_publications_event_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_publications
    ADD CONSTRAINT agenda_publications_event_id_fkey FOREIGN KEY (event_id) REFERENCES uniion_private.agenda_documents(event_id);


--
-- Name: agenda_reminders agenda_reminders_event_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_reminders
    ADD CONSTRAINT agenda_reminders_event_id_fkey FOREIGN KEY (event_id) REFERENCES uniion_private.agenda_events(id);


--
-- Name: agenda_reminders agenda_reminders_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.agenda_reminders
    ADD CONSTRAINT agenda_reminders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: ai_action_settings ai_action_settings_action_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_action_settings
    ADD CONSTRAINT ai_action_settings_action_fkey FOREIGN KEY (action) REFERENCES uniion_private.ai_action_definitions(id);


--
-- Name: ai_action_settings ai_action_settings_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_action_settings
    ADD CONSTRAINT ai_action_settings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: ai_activations ai_activations_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_activations
    ADD CONSTRAINT ai_activations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: ai_activations ai_activations_provider_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_activations
    ADD CONSTRAINT ai_activations_provider_fkey FOREIGN KEY (provider) REFERENCES uniion_private.ai_providers(id);


--
-- Name: ai_activations ai_activations_updated_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_activations
    ADD CONSTRAINT ai_activations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id);


--
-- Name: ai_business_roles ai_business_roles_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_business_roles
    ADD CONSTRAINT ai_business_roles_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: ai_case_derivatives ai_case_derivatives_organization_id_resource_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_case_derivatives
    ADD CONSTRAINT ai_case_derivatives_organization_id_resource_fkey FOREIGN KEY (organization_id, resource) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: ai_draft_applications ai_draft_applications_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_draft_applications
    ADD CONSTRAINT ai_draft_applications_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: ai_draft_applications ai_draft_applications_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_draft_applications
    ADD CONSTRAINT ai_draft_applications_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: ai_draft_applications ai_draft_applications_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_draft_applications
    ADD CONSTRAINT ai_draft_applications_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: ai_interactive_recipes ai_interactive_recipes_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_interactive_recipes
    ADD CONSTRAINT ai_interactive_recipes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: ai_providers ai_providers_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_providers
    ADD CONSTRAINT ai_providers_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);


--
-- Name: ai_recipe_sources ai_recipe_sources_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.ai_recipe_sources
    ADD CONSTRAINT ai_recipe_sources_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: audio_retention_batches audio_retention_batches_approved_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_batches
    ADD CONSTRAINT audio_retention_batches_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);


--
-- Name: audio_retention_batches audio_retention_batches_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_batches
    ADD CONSTRAINT audio_retention_batches_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: audio_retention_batches audio_retention_batches_requested_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_batches
    ADD CONSTRAINT audio_retention_batches_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES auth.users(id);


--
-- Name: audio_retention_items audio_retention_items_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_items
    ADD CONSTRAINT audio_retention_items_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: audio_retention_items audio_retention_items_batch_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_items
    ADD CONSTRAINT audio_retention_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES uniion_private.audio_retention_batches(id);


--
-- Name: audio_retention_validations audio_retention_validations_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_validations
    ADD CONSTRAINT audio_retention_validations_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: audio_retention_validations audio_retention_validations_reviewer_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_retention_validations
    ADD CONSTRAINT audio_retention_validations_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES auth.users(id);


--
-- Name: audio_tombstones audio_tombstones_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_tombstones
    ADD CONSTRAINT audio_tombstones_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: audio_tombstones audio_tombstones_batch_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.audio_tombstones
    ADD CONSTRAINT audio_tombstones_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES uniion_private.audio_retention_batches(id);


--
-- Name: business_publications business_publications_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_publications
    ADD CONSTRAINT business_publications_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: business_publications business_publications_publisher_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_publications
    ADD CONSTRAINT business_publications_publisher_fkey FOREIGN KEY (publisher) REFERENCES auth.users(id);


--
-- Name: business_publications business_publications_reviewer_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_publications
    ADD CONSTRAINT business_publications_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES auth.users(id);


--
-- Name: business_records business_records_creator_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_records
    ADD CONSTRAINT business_records_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: business_records business_records_organization_id_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.business_records
    ADD CONSTRAINT business_records_organization_id_id_fkey FOREIGN KEY (organization_id, id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: case_disposals case_disposals_decider_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_disposals
    ADD CONSTRAINT case_disposals_decider_fkey FOREIGN KEY (decider) REFERENCES auth.users(id);


--
-- Name: case_disposals case_disposals_link_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_disposals
    ADD CONSTRAINT case_disposals_link_fkey FOREIGN KEY (link) REFERENCES uniion_private.case_links(id);


--
-- Name: case_disposals case_disposals_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_disposals
    ADD CONSTRAINT case_disposals_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: case_disposals case_disposals_requester_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_disposals
    ADD CONSTRAINT case_disposals_requester_fkey FOREIGN KEY (requester) REFERENCES auth.users(id);


--
-- Name: case_file_trash case_file_trash_approver_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_approver_fkey FOREIGN KEY (approver) REFERENCES auth.users(id);


--
-- Name: case_file_trash case_file_trash_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: case_file_trash case_file_trash_requester_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_requester_fkey FOREIGN KEY (requester) REFERENCES auth.users(id);


--
-- Name: case_file_trash case_file_trash_restored_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_restored_by_fkey FOREIGN KEY (restored_by) REFERENCES auth.users(id);


--
-- Name: case_file_trash case_file_trash_root_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_trash
    ADD CONSTRAINT case_file_trash_root_fkey FOREIGN KEY (root) REFERENCES public.uniion_attachments(id);


--
-- Name: case_file_versions case_file_versions_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_versions
    ADD CONSTRAINT case_file_versions_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: case_file_versions case_file_versions_attachment_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_versions
    ADD CONSTRAINT case_file_versions_attachment_fkey FOREIGN KEY (attachment) REFERENCES public.uniion_attachments(id);


--
-- Name: case_file_versions case_file_versions_root_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_file_versions
    ADD CONSTRAINT case_file_versions_root_fkey FOREIGN KEY (root) REFERENCES public.uniion_attachments(id);


--
-- Name: case_history case_history_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_history
    ADD CONSTRAINT case_history_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: case_links case_links_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_links_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: case_links case_links_convocation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_links_convocation_fkey FOREIGN KEY (convocation) REFERENCES uniion_private.agenda_convocations(id);


--
-- Name: case_links case_links_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_links_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: case_links case_message_source_fk; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.case_links
    ADD CONSTRAINT case_message_source_fk FOREIGN KEY (organization_id, message_conversation, message_seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: cases cases_organization_id_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.cases
    ADD CONSTRAINT cases_organization_id_id_fkey FOREIGN KEY (organization_id, id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: cases cases_organization_id_owner_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.cases
    ADD CONSTRAINT cases_organization_id_owner_fkey FOREIGN KEY (organization_id, owner) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: collection_subscriptions collection_subscriptions_collection_accepted_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_subscriptions
    ADD CONSTRAINT collection_subscriptions_collection_accepted_fkey FOREIGN KEY (collection, accepted) REFERENCES uniion_private.collection_versions(collection, number);


--
-- Name: collection_subscriptions collection_subscriptions_collection_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_subscriptions
    ADD CONSTRAINT collection_subscriptions_collection_fkey FOREIGN KEY (collection) REFERENCES uniion_private.collections(id);


--
-- Name: collection_versions collection_versions_author_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_versions
    ADD CONSTRAINT collection_versions_author_fkey FOREIGN KEY (author) REFERENCES auth.users(id);


--
-- Name: collection_versions collection_versions_collection_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_versions
    ADD CONSTRAINT collection_versions_collection_fkey FOREIGN KEY (collection) REFERENCES uniion_private.collections(id);


--
-- Name: collection_versions collection_versions_reviewer_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collection_versions
    ADD CONSTRAINT collection_versions_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES auth.users(id);


--
-- Name: collections collections_source_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collections
    ADD CONSTRAINT collections_source_fkey FOREIGN KEY (source) REFERENCES public.uniion_organizations(id);


--
-- Name: collections collections_target_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.collections
    ADD CONSTRAINT collections_target_fkey FOREIGN KEY (target) REFERENCES public.uniion_organizations(id);


--
-- Name: convocation_archives convocation_archives_convocation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.convocation_archives
    ADD CONSTRAINT convocation_archives_convocation_fkey FOREIGN KEY (convocation) REFERENCES uniion_private.agenda_convocations(id);


--
-- Name: convocation_archives convocation_archives_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.convocation_archives
    ADD CONSTRAINT convocation_archives_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: coverage_corrections coverage_corrections_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.coverage_corrections
    ADD CONSTRAINT coverage_corrections_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: coverage_corrections coverage_corrections_organization_id_entry_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.coverage_corrections
    ADD CONSTRAINT coverage_corrections_organization_id_entry_id_fkey FOREIGN KEY (organization_id, entry_id) REFERENCES uniion_private.dues_entries(organization_id, id);


--
-- Name: document_archives document_archives_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_archives
    ADD CONSTRAINT document_archives_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES public.uniion_resource_versions(organization_id, resource_id, version);


--
-- Name: document_corrections document_corrections_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_corrections
    ADD CONSTRAINT document_corrections_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: document_corrections document_corrections_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_corrections
    ADD CONSTRAINT document_corrections_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES public.uniion_resource_versions(organization_id, resource_id, version);


--
-- Name: document_default_receipts document_default_receipts_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_default_receipts
    ADD CONSTRAINT document_default_receipts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: document_default_versions document_default_versions_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_default_versions
    ADD CONSTRAINT document_default_versions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: document_defaults document_defaults_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_defaults
    ADD CONSTRAINT document_defaults_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: document_export_jobs document_export_jobs_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_export_jobs
    ADD CONSTRAINT document_export_jobs_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES public.uniion_resource_versions(organization_id, resource_id, version);


--
-- Name: document_export_jobs document_export_jobs_requester_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_export_jobs
    ADD CONSTRAINT document_export_jobs_requester_fkey FOREIGN KEY (requester) REFERENCES auth.users(id);


--
-- Name: document_image_receipts document_image_receipts_document_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_image_receipts
    ADD CONSTRAINT document_image_receipts_document_id_fkey FOREIGN KEY (document_id) REFERENCES uniion_private.documents(id);


--
-- Name: document_notices document_notices_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_notices
    ADD CONSTRAINT document_notices_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES uniion_private.document_publications(organization_id, resource_id, version);


--
-- Name: document_notices document_notices_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_notices
    ADD CONSTRAINT document_notices_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: document_publications document_publications_organization_id_resource_id_version_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_publications
    ADD CONSTRAINT document_publications_organization_id_resource_id_version_fkey FOREIGN KEY (organization_id, resource_id, version) REFERENCES public.uniion_resource_versions(organization_id, resource_id, version);


--
-- Name: document_publications document_publications_publisher_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_publications
    ADD CONSTRAINT document_publications_publisher_fkey FOREIGN KEY (publisher) REFERENCES auth.users(id);


--
-- Name: document_publications document_publications_reviewer_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.document_publications
    ADD CONSTRAINT document_publications_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES auth.users(id);


--
-- Name: documents documents_organization_id_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.documents
    ADD CONSTRAINT documents_organization_id_id_fkey FOREIGN KEY (organization_id, id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: dues_corrections dues_corrections_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_corrections
    ADD CONSTRAINT dues_corrections_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: dues_corrections dues_corrections_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_corrections
    ADD CONSTRAINT dues_corrections_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES uniion_private.dues_payments(organization_id, id);


--
-- Name: dues_entries dues_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: dues_entries dues_entries_organization_id_adherent_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_entries_organization_id_adherent_id_fkey FOREIGN KEY (organization_id, adherent_id) REFERENCES uniion_private.adherents(organization_id, id);


--
-- Name: dues_entries dues_entries_paid_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_entries_paid_by_fkey FOREIGN KEY (paid_by) REFERENCES auth.users(id);


--
-- Name: dues_evidence dues_evidence_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_evidence
    ADD CONSTRAINT dues_evidence_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: dues_evidence dues_evidence_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_evidence
    ADD CONSTRAINT dues_evidence_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES uniion_private.dues_payments(organization_id, id);


--
-- Name: dues_payments dues_payments_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_payments
    ADD CONSTRAINT dues_payments_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: dues_payments dues_payments_organization_id_entry_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_payments
    ADD CONSTRAINT dues_payments_organization_id_entry_id_fkey FOREIGN KEY (organization_id, entry_id) REFERENCES uniion_private.dues_entries(organization_id, id);


--
-- Name: dues_receipts dues_receipts_created_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_receipts
    ADD CONSTRAINT dues_receipts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: dues_receipts dues_receipts_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_receipts
    ADD CONSTRAINT dues_receipts_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES uniion_private.dues_payments(organization_id, id);


--
-- Name: dues_entries dues_schedule_org_fk; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_entries
    ADD CONSTRAINT dues_schedule_org_fk FOREIGN KEY (organization_id, schedule_id) REFERENCES uniion_private.dues_schedules(organization_id, id);


--
-- Name: dues_schedules dues_schedules_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_schedules
    ADD CONSTRAINT dues_schedules_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: dues_schedules dues_schedules_organization_id_adherent_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.dues_schedules
    ADD CONSTRAINT dues_schedules_organization_id_adherent_id_fkey FOREIGN KEY (organization_id, adherent_id) REFERENCES uniion_private.adherents(organization_id, id);


--
-- Name: identity_profiles identity_profiles_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.identity_profiles
    ADD CONSTRAINT identity_profiles_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: invitations invitations_accepted_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.invitations
    ADD CONSTRAINT invitations_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES auth.users(id);


--
-- Name: invitations invitations_created_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.invitations
    ADD CONSTRAINT invitations_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: invitations invitations_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.invitations
    ADD CONSTRAINT invitations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: lost_factor_jobs lost_factor_jobs_approved_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.lost_factor_jobs
    ADD CONSTRAINT lost_factor_jobs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);


--
-- Name: lost_factor_jobs lost_factor_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.lost_factor_jobs
    ADD CONSTRAINT lost_factor_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: meeting_audio meeting_audio_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: meeting_audio_chunks meeting_audio_chunks_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_chunks
    ADD CONSTRAINT meeting_audio_chunks_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: meeting_audio meeting_audio_consent_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_consent_actor_fkey FOREIGN KEY (consent_actor) REFERENCES auth.users(id);


--
-- Name: meeting_audio_grants meeting_audio_grants_organization_id_meeting_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_grants
    ADD CONSTRAINT meeting_audio_grants_organization_id_meeting_id_fkey FOREIGN KEY (organization_id, meeting_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: meeting_audio_grants meeting_audio_grants_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_grants
    ADD CONSTRAINT meeting_audio_grants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: meeting_audio_markers meeting_audio_markers_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_markers
    ADD CONSTRAINT meeting_audio_markers_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: meeting_audio_markers meeting_audio_markers_organization_id_meeting_id_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_markers
    ADD CONSTRAINT meeting_audio_markers_organization_id_meeting_id_audio_id_fkey FOREIGN KEY (organization_id, meeting_id, audio_id) REFERENCES uniion_private.meeting_audio(organization_id, meeting_id, id);


--
-- Name: meeting_audio meeting_audio_organization_id_meeting_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio
    ADD CONSTRAINT meeting_audio_organization_id_meeting_id_fkey FOREIGN KEY (organization_id, meeting_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: meeting_audio_original_parts meeting_audio_original_parts_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_original_parts
    ADD CONSTRAINT meeting_audio_original_parts_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio_originals(audio_id);


--
-- Name: meeting_audio_originals meeting_audio_originals_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_originals
    ADD CONSTRAINT meeting_audio_originals_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: meeting_audio_policy meeting_audio_policy_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_policy
    ADD CONSTRAINT meeting_audio_policy_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: meeting_audio_sequences meeting_audio_sequences_audio_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_audio_sequences
    ADD CONSTRAINT meeting_audio_sequences_audio_id_fkey FOREIGN KEY (audio_id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: meeting_consents meeting_consents_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_consents
    ADD CONSTRAINT meeting_consents_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: meeting_consents meeting_consents_organization_id_meeting_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_consents
    ADD CONSTRAINT meeting_consents_organization_id_meeting_id_fkey FOREIGN KEY (organization_id, meeting_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: meeting_minutes meeting_minutes_creator_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: meeting_minutes meeting_minutes_job_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_job_id_fkey FOREIGN KEY (job_id) REFERENCES uniion_private.transcription_jobs(id);


--
-- Name: meeting_minutes meeting_minutes_organization_id_meeting_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_organization_id_meeting_id_fkey FOREIGN KEY (organization_id, meeting_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: meeting_minutes meeting_minutes_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.meeting_minutes
    ADD CONSTRAINT meeting_minutes_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: member_lists member_lists_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.member_lists
    ADD CONSTRAINT member_lists_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: member_lists member_lists_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.member_lists
    ADD CONSTRAINT member_lists_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: membership_changes membership_changes_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_changes
    ADD CONSTRAINT membership_changes_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: membership_changes membership_changes_organization_id_adherent_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_changes
    ADD CONSTRAINT membership_changes_organization_id_adherent_id_fkey FOREIGN KEY (organization_id, adherent_id) REFERENCES uniion_private.adherents(organization_id, id);


--
-- Name: membership_suspensions membership_suspensions_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.membership_suspensions
    ADD CONSTRAINT membership_suspensions_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: message_conversations message_conversations_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_conversations
    ADD CONSTRAINT message_conversations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: message_files message_files_attachment_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_attachment_fkey FOREIGN KEY (attachment) REFERENCES public.uniion_attachments(id);


--
-- Name: message_files message_files_organization_id_conversation_seq_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_organization_id_conversation_seq_fkey FOREIGN KEY (organization_id, conversation, seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: message_files message_files_organization_id_resource_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_files
    ADD CONSTRAINT message_files_organization_id_resource_fkey FOREIGN KEY (organization_id, resource) REFERENCES public.uniion_resources(organization_id, id);


--
-- Name: message_forward_batches message_forward_batches_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forward_batches
    ADD CONSTRAINT message_forward_batches_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: message_forward_batches message_forward_batches_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forward_batches
    ADD CONSTRAINT message_forward_batches_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: message_forward_batches message_forward_batches_organization_id_source_conversatio_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forward_batches
    ADD CONSTRAINT message_forward_batches_organization_id_source_conversatio_fkey FOREIGN KEY (organization_id, source_conversation, source_seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: message_forwards message_forwards_organization_id_conversation_seq_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forwards
    ADD CONSTRAINT message_forwards_organization_id_conversation_seq_fkey FOREIGN KEY (organization_id, conversation, seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: message_forwards message_forwards_organization_id_source_conversation_sourc_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_forwards
    ADD CONSTRAINT message_forwards_organization_id_source_conversation_sourc_fkey FOREIGN KEY (organization_id, source_conversation, source_seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: message_history_grants message_history_grants_granted_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_history_grants
    ADD CONSTRAINT message_history_grants_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES auth.users(id);


--
-- Name: message_history_grants message_history_grants_organization_id_conversation_messag_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_history_grants
    ADD CONSTRAINT message_history_grants_organization_id_conversation_messag_fkey FOREIGN KEY (organization_id, conversation, message_seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: message_history_grants message_history_grants_organization_id_conversation_partic_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_history_grants
    ADD CONSTRAINT message_history_grants_organization_id_conversation_partic_fkey FOREIGN KEY (organization_id, conversation, participation) REFERENCES uniion_private.message_participations(organization_id, conversation, id);


--
-- Name: message_participations message_participations_organization_id_conversation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_participations
    ADD CONSTRAINT message_participations_organization_id_conversation_fkey FOREIGN KEY (organization_id, conversation) REFERENCES uniion_private.message_conversations(organization_id, id);


--
-- Name: message_participations message_participations_organization_id_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_participations
    ADD CONSTRAINT message_participations_organization_id_user_id_fkey FOREIGN KEY (organization_id, user_id) REFERENCES public.uniion_memberships(organization_id, user_id);


--
-- Name: message_reads message_reads_organization_id_conversation_participation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_reads
    ADD CONSTRAINT message_reads_organization_id_conversation_participation_fkey FOREIGN KEY (organization_id, conversation, participation) REFERENCES uniion_private.message_participations(organization_id, conversation, id);


--
-- Name: message_reads message_reads_organization_id_conversation_seq_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.message_reads
    ADD CONSTRAINT message_reads_organization_id_conversation_seq_fkey FOREIGN KEY (organization_id, conversation, seq) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: messages messages_author_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_author_fkey FOREIGN KEY (author) REFERENCES auth.users(id);


--
-- Name: messages messages_organization_id_conversation_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_organization_id_conversation_fkey FOREIGN KEY (organization_id, conversation) REFERENCES uniion_private.message_conversations(organization_id, id);


--
-- Name: messages messages_organization_id_conversation_reply_to_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.messages
    ADD CONSTRAINT messages_organization_id_conversation_reply_to_fkey FOREIGN KEY (organization_id, conversation, reply_to) REFERENCES uniion_private.messages(organization_id, conversation, seq);


--
-- Name: mfa_recovery_requests mfa_recovery_requests_approved_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_recovery_requests
    ADD CONSTRAINT mfa_recovery_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);


--
-- Name: mfa_recovery_requests mfa_recovery_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_recovery_requests
    ADD CONSTRAINT mfa_recovery_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: mfa_requirements mfa_requirements_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.mfa_requirements
    ADD CONSTRAINT mfa_requirements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: module_delegations module_delegations_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_delegations
    ADD CONSTRAINT module_delegations_id_fkey FOREIGN KEY (id) REFERENCES uniion_private.module_catalog(id);


--
-- Name: module_delegations module_delegations_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_delegations
    ADD CONSTRAINT module_delegations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: module_entitlements module_entitlements_created_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_entitlements
    ADD CONSTRAINT module_entitlements_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: module_entitlements module_entitlements_module_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_entitlements
    ADD CONSTRAINT module_entitlements_module_fkey FOREIGN KEY (module) REFERENCES uniion_private.module_catalog(id);


--
-- Name: module_entitlements module_entitlements_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_entitlements
    ADD CONSTRAINT module_entitlements_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: module_events module_events_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_events
    ADD CONSTRAINT module_events_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: module_events module_events_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.module_events
    ADD CONSTRAINT module_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: organization_details organization_details_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.organization_details
    ADD CONSTRAINT organization_details_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: partner_events partner_events_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.partner_events
    ADD CONSTRAINT partner_events_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: partner_events partner_events_source_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.partner_events
    ADD CONSTRAINT partner_events_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.uniion_organizations(id);


--
-- Name: partner_events partner_events_target_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.partner_events
    ADD CONSTRAINT partner_events_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.uniion_organizations(id);


--
-- Name: platform_events platform_events_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.platform_events
    ADD CONSTRAINT platform_events_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: platform_events platform_events_subject_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.platform_events
    ADD CONSTRAINT platform_events_subject_fkey FOREIGN KEY (subject) REFERENCES auth.users(id);


--
-- Name: platform_operators platform_operators_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.platform_operators
    ADD CONSTRAINT platform_operators_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: scan_workers scan_workers_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.scan_workers
    ADD CONSTRAINT scan_workers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: schedule_changes schedule_changes_actor_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.schedule_changes
    ADD CONSTRAINT schedule_changes_actor_fkey FOREIGN KEY (actor) REFERENCES auth.users(id);


--
-- Name: schedule_changes schedule_changes_organization_id_schedule_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.schedule_changes
    ADD CONSTRAINT schedule_changes_organization_id_schedule_id_fkey FOREIGN KEY (organization_id, schedule_id) REFERENCES uniion_private.dues_schedules(organization_id, id);


--
-- Name: super_admins super_admins_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.super_admins
    ADD CONSTRAINT super_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: support_agents support_agents_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_agents
    ADD CONSTRAINT support_agents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: support_assignments support_assignments_ticket_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_assignments
    ADD CONSTRAINT support_assignments_ticket_fkey FOREIGN KEY (ticket) REFERENCES uniion_private.support_tickets(id);


--
-- Name: support_assignments support_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_assignments
    ADD CONSTRAINT support_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES uniion_private.support_agents(user_id);


--
-- Name: support_files support_files_attachment_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_files
    ADD CONSTRAINT support_files_attachment_fkey FOREIGN KEY (attachment) REFERENCES public.uniion_attachments(id);


--
-- Name: support_files support_files_grant_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_files
    ADD CONSTRAINT support_files_grant_id_fkey FOREIGN KEY (grant_id) REFERENCES uniion_private.support_grants(id);


--
-- Name: support_grants support_grants_creator_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_grants
    ADD CONSTRAINT support_grants_creator_fkey FOREIGN KEY (creator) REFERENCES auth.users(id);


--
-- Name: support_grants support_grants_ticket_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_grants
    ADD CONSTRAINT support_grants_ticket_fkey FOREIGN KEY (ticket) REFERENCES uniion_private.support_tickets(id);


--
-- Name: support_items support_items_grant_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_items
    ADD CONSTRAINT support_items_grant_id_fkey FOREIGN KEY (grant_id) REFERENCES uniion_private.support_grants(id);


--
-- Name: support_items support_items_resource_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_items
    ADD CONSTRAINT support_items_resource_fkey FOREIGN KEY (resource) REFERENCES public.uniion_resources(id);


--
-- Name: support_requests support_requests_agent_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_requests
    ADD CONSTRAINT support_requests_agent_fkey FOREIGN KEY (agent) REFERENCES uniion_private.support_agents(user_id);


--
-- Name: support_requests support_requests_ticket_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_requests
    ADD CONSTRAINT support_requests_ticket_fkey FOREIGN KEY (ticket) REFERENCES uniion_private.support_tickets(id);


--
-- Name: support_tickets support_tickets_closed_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_tickets
    ADD CONSTRAINT support_tickets_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES auth.users(id);


--
-- Name: support_tickets support_tickets_created_by_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_tickets
    ADD CONSTRAINT support_tickets_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: support_tickets support_tickets_organization_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.support_tickets
    ADD CONSTRAINT support_tickets_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.uniion_organizations(id);


--
-- Name: transcription_jobs transcription_jobs_requester_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_jobs
    ADD CONSTRAINT transcription_jobs_requester_fkey FOREIGN KEY (requester) REFERENCES auth.users(id);


--
-- Name: transcription_parts transcription_parts_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_parts
    ADD CONSTRAINT transcription_parts_id_fkey FOREIGN KEY (id) REFERENCES uniion_private.meeting_audio(id);


--
-- Name: transcription_parts transcription_parts_job_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_parts
    ADD CONSTRAINT transcription_parts_job_id_fkey FOREIGN KEY (job_id) REFERENCES uniion_private.transcription_jobs(id);


--
-- Name: transcription_workers transcription_workers_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.transcription_workers
    ADD CONSTRAINT transcription_workers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: trusted_mfa_factors trusted_mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: uniion_private; Owner: -
--

ALTER TABLE ONLY uniion_private.trusted_mfa_factors
    ADD CONSTRAINT trusted_mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: uniion_resources granted_resources; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY granted_resources ON public.uniion_resources FOR SELECT TO authenticated USING (uniion_private.resource_access(organization_id, id, false));


--
-- Name: uniion_organizations member_organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY member_organizations ON public.uniion_organizations FOR SELECT TO authenticated USING (uniion_private.member(id));


--
-- Name: uniion_resource_versions readable_versions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY readable_versions ON public.uniion_resource_versions FOR SELECT TO authenticated USING (uniion_private.resource_access(organization_id, resource_id, false));


--
-- Name: uniion_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_authorities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_authorities ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_directory_grants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_directory_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_events ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_module_access; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_module_access ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_partners; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_partners ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_resource_grants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_resource_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_resource_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_resource_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_resources; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_resources ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_security_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_security_events ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_share_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_share_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_share_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_share_items ENABLE ROW LEVEL SECURITY;

--
-- Name: uniion_shares; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uniion_shares ENABLE ROW LEVEL SECURITY;

--
-- Name: adherent_endings; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.adherent_endings ENABLE ROW LEVEL SECURITY;

--
-- Name: adherents; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.adherents ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_audiences; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_audiences ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_convocation_deliveries; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_convocation_deliveries ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_convocations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_convocations ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_documents; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_events; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_events ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_image_receipts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_image_receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_publication_notifications; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_publication_notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_publications; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_publications ENABLE ROW LEVEL SECURITY;

--
-- Name: agenda_reminders; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.agenda_reminders ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_action_definitions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_action_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_action_settings; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_action_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_activations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_activations ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_business_roles; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_business_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_case_derivatives; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_case_derivatives ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_draft_applications; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_draft_applications ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_interactive_recipes; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_interactive_recipes ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_providers; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_recipe_sources; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.ai_recipe_sources ENABLE ROW LEVEL SECURITY;

--
-- Name: audio_retention_batches; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.audio_retention_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: audio_retention_items; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.audio_retention_items ENABLE ROW LEVEL SECURITY;

--
-- Name: audio_retention_validations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.audio_retention_validations ENABLE ROW LEVEL SECURITY;

--
-- Name: audio_tombstones; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.audio_tombstones ENABLE ROW LEVEL SECURITY;

--
-- Name: business_publications; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.business_publications ENABLE ROW LEVEL SECURITY;

--
-- Name: business_records; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.business_records ENABLE ROW LEVEL SECURITY;

--
-- Name: case_disposals; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_disposals ENABLE ROW LEVEL SECURITY;

--
-- Name: case_file_trash; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_file_trash ENABLE ROW LEVEL SECURITY;

--
-- Name: case_file_versions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_file_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: case_history; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_history ENABLE ROW LEVEL SECURITY;

--
-- Name: case_links; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.case_links ENABLE ROW LEVEL SECURITY;

--
-- Name: cases; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.cases ENABLE ROW LEVEL SECURITY;

--
-- Name: collection_subscriptions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.collection_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: collection_versions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.collection_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: collections; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.collections ENABLE ROW LEVEL SECURITY;

--
-- Name: convocation_archives; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.convocation_archives ENABLE ROW LEVEL SECURITY;

--
-- Name: coverage_corrections; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.coverage_corrections ENABLE ROW LEVEL SECURITY;

--
-- Name: document_archives; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_archives ENABLE ROW LEVEL SECURITY;

--
-- Name: document_corrections; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_corrections ENABLE ROW LEVEL SECURITY;

--
-- Name: document_default_receipts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_default_receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: document_default_versions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_default_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: document_defaults; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_defaults ENABLE ROW LEVEL SECURITY;

--
-- Name: document_export_jobs; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_export_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: document_image_receipts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_image_receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: document_notices; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_notices ENABLE ROW LEVEL SECURITY;

--
-- Name: document_publications; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.document_publications ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_corrections; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_corrections ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_entries; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_evidence; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_evidence ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_payments; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_receipts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: dues_schedules; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.dues_schedules ENABLE ROW LEVEL SECURITY;

--
-- Name: identity_profiles; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.identity_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_chunks; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_chunks ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_grants; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_markers; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_markers ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_original_parts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_original_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_originals; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_originals ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_policy; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_policy ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_audio_sequences; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_audio_sequences ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_consents; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_consents ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_minutes; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.meeting_minutes ENABLE ROW LEVEL SECURITY;

--
-- Name: member_lists; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.member_lists ENABLE ROW LEVEL SECURITY;

--
-- Name: membership_changes; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.membership_changes ENABLE ROW LEVEL SECURITY;

--
-- Name: membership_suspensions; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.membership_suspensions ENABLE ROW LEVEL SECURITY;

--
-- Name: message_conversations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: message_files; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_files ENABLE ROW LEVEL SECURITY;

--
-- Name: message_forward_batches; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_forward_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: message_forwards; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_forwards ENABLE ROW LEVEL SECURITY;

--
-- Name: message_history_grants; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_history_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: message_participations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_participations ENABLE ROW LEVEL SECURITY;

--
-- Name: message_reads; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.message_reads ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: module_catalog; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.module_catalog ENABLE ROW LEVEL SECURITY;

--
-- Name: module_delegations; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.module_delegations ENABLE ROW LEVEL SECURITY;

--
-- Name: module_entitlements; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.module_entitlements ENABLE ROW LEVEL SECURITY;

--
-- Name: module_events; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.module_events ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_details; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.organization_details ENABLE ROW LEVEL SECURITY;

--
-- Name: partner_events; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.partner_events ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_events; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.platform_events ENABLE ROW LEVEL SECURITY;

--
-- Name: schedule_changes; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.schedule_changes ENABLE ROW LEVEL SECURITY;

--
-- Name: super_admins; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.super_admins ENABLE ROW LEVEL SECURITY;

--
-- Name: support_agents; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_agents ENABLE ROW LEVEL SECURITY;

--
-- Name: support_assignments; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: support_files; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_files ENABLE ROW LEVEL SECURITY;

--
-- Name: support_grants; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: support_items; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_items ENABLE ROW LEVEL SECURITY;

--
-- Name: support_requests; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: support_tickets; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.support_tickets ENABLE ROW LEVEL SECURITY;

--
-- Name: transcription_jobs; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.transcription_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: transcription_parts; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.transcription_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: transcription_workers; Type: ROW SECURITY; Schema: uniion_private; Owner: -
--

ALTER TABLE uniion_private.transcription_workers ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


