begin;
alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
alter table public.uniion_authorities add constraint uniion_authorities_permission_check check(permission in ('rights','share','accept','download','history','organization_edit','collection_publish','collection_accept','agenda_audience','agenda_convocation'));
create table uniion_private.agenda_documents(event_id uuid primary key references uniion_private.agenda_events,id uuid unique not null default gen_random_uuid(),source_version integer not null,version integer not null default 1,document jsonb not null,updated_by uuid not null references auth.users,updated_at timestamptz not null default now());
create table uniion_private.agenda_convocations(id uuid primary key,event_id uuid not null references uniion_private.agenda_events,event_version integer not null,actor uuid not null references auth.users,message jsonb not null,created_at timestamptz not null default now());
create table uniion_private.agenda_convocation_deliveries(convocation uuid references uniion_private.agenda_convocations,user_id uuid references auth.users,status text not null default 'sending' check(status in ('sending','sent','uncertain','cancelled')),primary key(convocation,user_id));
alter table uniion_private.agenda_documents enable row level security;
alter table uniion_private.agenda_convocations enable row level security;
alter table uniion_private.agenda_convocation_deliveries enable row level security;
revoke all on uniion_private.agenda_documents,uniion_private.agenda_convocations,uniion_private.agenda_convocation_deliveries from public,anon,authenticated;
create function public.uniion_agenda_work(p_org uuid,p_event uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e uniion_private.agenda_events;d uniion_private.agenda_documents;ident uuid;person uuid;people uuid[];doc jsonb;rows jsonb;item jsonb;
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
   ident=gen_random_uuid();doc=jsonb_build_object('id',ident,'title','Ordre du jour — '||(e.data->>'title'),'model','cr','format','a4','status','Brouillon','updated','à l’instant','blocks',jsonb_build_array(jsonb_build_object('id',ident||'-1','type','h1','text','Ordre du jour — '||(e.data->>'title')),jsonb_build_object('id',ident||'-2','type','p','text',(e.data->>'date')||' · '||(e.data->>'start')||' — '||(e.data->>'end')||' · '||(e.data->>'lieu')),jsonb_build_object('id',ident||'-3','type','h2','text','Points à examiner'),jsonb_build_object('id',ident||'-4','type','p','text',coalesce(nullif(e.data->>'notes',''),'À compléter'))));
   insert into uniion_private.agenda_documents(event_id,id,source_version,document,updated_by) values(p_event,ident,e.version,doc,auth.uid()) on conflict(event_id) do nothing;
   select * into d from uniion_private.agenda_documents where event_id=p_event;
  end if;
 else
  if d.id is null or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='documents' and permission='write') or (p_payload->>'version')::integer is distinct from d.version or p_payload-array['version','document']<>'{}'::jsonb then raise insufficient_privilege;end if;
  doc=p_payload->'document';
  if jsonb_typeof(doc)<>'object' or not(doc ?& array['title','format','blocks']) or doc-array['title','format','blocks']<>'{}'::jsonb or jsonb_typeof(doc->'title')<>'string' or length(trim(doc->>'title')) not between 1 and 200 or doc->>'format' not in ('a4','a5','square','story','wide') or jsonb_typeof(doc->'blocks')<>'array' or jsonb_array_length(doc->'blocks') not between 1 and 100 then raise insufficient_privilege;end if;
  for item in select value from jsonb_array_elements(doc->'blocks') loop
   if jsonb_typeof(item)<>'object' or item-array['id','type','text']<>'{}'::jsonb or not(item ?& array['id','type','text']) or jsonb_typeof(item->'text')<>'string' or length(item->>'text')>8000 or item->>'type' not in ('h1','h2','p','ul','quote','table','tag','pagebreak') then raise insufficient_privilege;end if;
  end loop;
  update uniion_private.agenda_documents set document=document||doc,version=version+1,updated_by=auth.uid(),updated_at=now() where event_id=p_event returning * into d;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'agenda.document.'||p_action,jsonb_build_object('id',d.id,'version',d.version));
 return jsonb_build_object('document',d.document,'version',d.version,'sourceVersion',d.source_version);
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
 if not found then return jsonb_build_object('deliveries','[]'::jsonb,'replayed',true);end if;
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
end;$$;
revoke all on function public.uniion_agenda_work(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_agenda_work(uuid,uuid,text,jsonb) to authenticated;
commit;
