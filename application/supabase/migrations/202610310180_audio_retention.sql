begin;
-- Audio only: derived texts and approved publications have distinct retention.
create table uniion_private.audio_retention_validations(
 audio_id uuid primary key references uniion_private.meeting_audio,
 validated_at timestamptz not null default now(),reviewer uuid not null references auth.users,
 resource_id uuid not null,version integer not null);
create table uniion_private.audio_retention_batches(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.uniion_organizations,
 meeting_id uuid not null,inventory jsonb not null,created_at timestamptz not null default now(),
 state text not null default 'pending' check(state in ('pending','held','approved','executing','done')),
 reason text,hold_until timestamptz,approved_by uuid references auth.users,approved_at timestamptz,finished_at timestamptz);
create table uniion_private.audio_retention_items(
 audio_id uuid primary key references uniion_private.meeting_audio,batch_id uuid not null references uniion_private.audio_retention_batches);
create table uniion_private.audio_tombstones(
 audio_id uuid primary key references uniion_private.meeting_audio,batch_id uuid not null references uniion_private.audio_retention_batches,
 organization_id uuid not null,meeting_id uuid not null,sha256 text not null,request_id uuid not null,at timestamptz not null default now());
alter table uniion_private.audio_retention_validations enable row level security;
alter table uniion_private.audio_retention_batches enable row level security;
alter table uniion_private.audio_retention_items enable row level security;
alter table uniion_private.audio_tombstones enable row level security;
revoke all on uniion_private.audio_retention_validations,uniion_private.audio_retention_batches,uniion_private.audio_retention_items,uniion_private.audio_tombstones from public,anon,authenticated;
create function uniion_private.record_audio_validation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- The existing review RPC already enforces distinct actor and exact version.
 insert into uniion_private.audio_retention_validations(audio_id,validated_at,reviewer,resource_id,version)
 select p.id,new.reviewed_at,new.reviewer,new.resource_id,new.version from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id
 where m.resource_id=new.resource_id and m.organization_id=new.organization_id
 on conflict(audio_id) do nothing;
 return new;
end$$;
create trigger uniion_audio_validation after insert or update of reviewed_at on uniion_private.business_publications for each row execute function uniion_private.record_audio_validation();
insert into uniion_private.audio_retention_validations(audio_id,validated_at,reviewer,resource_id,version)
select distinct on(p.id) p.id,b.reviewed_at,b.reviewer,b.resource_id,b.version from uniion_private.business_publications b join uniion_private.meeting_minutes m on m.resource_id=b.resource_id and m.organization_id=b.organization_id join uniion_private.transcription_parts p on p.job_id=m.job_id order by p.id,b.reviewed_at on conflict do nothing;
create function uniion_private.audio_inventory(ids uuid[]) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('scope','audio-bytes-only','audio',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'path',a.path,'sha256',a.sha256,'size',a.size,'request',a.request_id,'chunks',(select count(*) from uniion_private.meeting_audio_chunks c where c.audio_id=a.id),'original',case when o.audio_id is null then null else jsonb_build_object('size',o.size,'sha256',o.sha256,'parts',(select count(*) from uniion_private.meeting_audio_original_parts p where p.audio_id=a.id)) end) order by a.id) from uniion_private.meeting_audio a left join uniion_private.meeting_audio_originals o on o.audio_id=a.id where a.id=any(ids)),'[]'),
 'retained',jsonb_build_object('transcriptionParts',(select count(*) from uniion_private.transcription_parts where id=any(ids)),'privatePV',(select count(distinct m.resource_id) from uniion_private.meeting_minutes m join uniion_private.transcription_parts p on p.job_id=m.job_id where p.id=any(ids)),'publications',(select count(distinct b.id) from uniion_private.business_publications b join uniion_private.meeting_minutes m on m.resource_id=b.resource_id join uniion_private.transcription_parts p on p.job_id=m.job_id where p.id=any(ids)),'metadata',true,'backups',true,'offlineDevices','unconfirmed'))
$$;
create function public.uniion_audio_retention(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
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
   insert into uniion_private.audio_retention_batches(organization_id,meeting_id,inventory) values(p_org,item.meeting_id,inv) returning id into bid;
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
  select array_agg(audio_id order by audio_id) into ids from uniion_private.audio_retention_items where batch_id=b.id;
  if uniion_private.audio_inventory(ids) is distinct from b.inventory then raise insufficient_privilege;end if;
  update uniion_private.audio_retention_batches set state='approved',reason=p_payload->>'reason',approved_by=auth.uid(),approved_at=now() where id=b.id;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'meeting.retention.'||p_action,jsonb_build_object('batch',b.id));
 return jsonb_build_object('ok',true);
end$$;
-- Scanner is the existing non-interactive byte handler; it cannot approve.
create function public.uniion_audio_retention_execute(p_batch uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
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
create function uniion_private.retention_storage(path text) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.is_scanner() and exists(select 1 from uniion_private.audio_tombstones t join uniion_private.audio_retention_batches b on b.id=t.batch_id join uniion_private.meeting_audio a on a.id=t.audio_id join uniion_private.super_admins s on s.user_id=b.approved_by and s.active where a.path=$1 and b.state='executing')
$$;
create policy uniion_audio_retention_delete on storage.objects for delete to authenticated using(bucket_id='uniion-private' and uniion_private.retention_storage(name));
create policy uniion_audio_retention_scanner on storage.objects for select to authenticated using(bucket_id='uniion-private' and uniion_private.retention_storage(name));
revoke all on function uniion_private.record_audio_validation(),uniion_private.audio_inventory(uuid[]),uniion_private.retention_storage(text),public.uniion_audio_retention(uuid,uuid,text,jsonb),public.uniion_audio_retention_execute(uuid,text) from public,anon,authenticated;
grant execute on function uniion_private.retention_storage(text),public.uniion_audio_retention(uuid,uuid,text,jsonb),public.uniion_audio_retention_execute(uuid,text) to authenticated;
create function uniion_private.prevent_audio_resurrection() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from uniion_private.audio_tombstones where organization_id=new.organization_id and meeting_id=new.meeting_id and (audio_id=new.id or request_id=new.request_id or sha256=new.sha256)) and (tg_op='INSERT' or new.status<>'blocked') then raise insufficient_privilege;end if;
 return new;
end$$;
create trigger uniion_audio_tombstone before insert or update on uniion_private.meeting_audio for each row execute function uniion_private.prevent_audio_resurrection();
revoke all on function uniion_private.prevent_audio_resurrection() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
