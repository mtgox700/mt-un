begin;
-- Constats P2 de la revue : R53 (échéanciers), R25 (envois incertains), R38 (délai de conservation
-- audio), R39 (double approbation des suppressions). Redéfinitions complètes, mêmes signatures.
alter table uniion_private.agenda_reminders add column if not exists sending_at timestamptz;
alter table uniion_private.audio_retention_batches add column if not exists requested_by uuid references auth.users;
create or replace function uniion_private.audio_published(p_audio uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from uniion_private.transcription_parts p join uniion_private.meeting_minutes m on m.job_id=p.job_id
  join uniion_private.business_publications b on b.organization_id=m.organization_id and b.resource_id=m.resource_id
  where p.id=p_audio and b.published_at is not null and b.revoked_at is null)
$$;
revoke all on function uniion_private.audio_published(uuid) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION uniion_private.run_dues_schedules(p_org uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end $function$;
CREATE OR REPLACE FUNCTION uniion_private.agenda_claim()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;
CREATE OR REPLACE FUNCTION uniion_private.agenda_work_core(p_org uuid, p_event uuid, p_action text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;
CREATE OR REPLACE FUNCTION uniion_private.record_audio_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end$function$;
drop trigger if exists uniion_audio_validation on uniion_private.business_publications;
create trigger uniion_audio_validation after insert or update of reviewed_at,published_at,revoked_at on uniion_private.business_publications for each row execute function uniion_private.record_audio_validation();
-- Données existantes : une éligibilité n'est conservée que pour un audio dont le PV est publié et non révoqué.
delete from uniion_private.audio_retention_validations v where not uniion_private.audio_published(v.audio_id);
CREATE OR REPLACE FUNCTION public.uniion_audio_retention_before_remaining(p_org uuid, p_meeting uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end$function$;
notify pgrst,'reload schema';
commit;
