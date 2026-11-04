-- Comportements de contrôle d'accès vérifiés sur la base migrée. Toute assertion fausse fait échouer la CI.
\set ON_ERROR_STOP 1
begin;
set local session_replication_role=replica;
insert into auth.users(id,email) values
 ('40000000-0000-4000-8000-000000000001','scanner-actif@example.invalid'),
 ('40000000-0000-4000-8000-000000000002','scanner-revoque@example.invalid'),
 ('40000000-0000-4000-8000-000000000003','non-scanner@example.invalid');
insert into auth.sessions(id,user_id,aal,not_after) values
 ('41000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','aal1',null),
 ('41000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000002','aal1',now()-interval '1 minute'),
 ('41000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000003','aal1',null);
insert into auth.users(id,email) values('40000000-0000-4000-8000-000000000004','worker-transcription@example.invalid');
insert into auth.sessions(id,user_id,aal,not_after) values('41000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000004','aal1',null);
insert into uniion_private.transcription_workers values('40000000-0000-4000-8000-000000000004');
insert into uniion_private.transcription_jobs(id,organization_id,meeting_id,requester,source_ids,source_key) values('42000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000003','{}','orpheline');
-- R53 : échéancier dont le créateur n'est plus membre.
insert into public.uniion_organizations(id,name) values('43000000-0000-4000-8000-000000000001','Org comportements');
insert into uniion_private.agenda_events(id,organization_id,creator,data) values('43000000-0000-4000-8000-000000000004','43000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','{}');
insert into public.uniion_resources(id,organization_id,module,title) values('43000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000001','reunions','Réunion'),('46000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000001','reunions','PV');
insert into uniion_private.adherents(id,organization_id,data) values('43000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000001','{}');
insert into uniion_private.dues_schedules(id,organization_id,adherent_id,anchor,months,amount_cents,actor,member_anchor) values('44000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000003','2026-01-01',1,1000,'40000000-0000-4000-8000-000000000003','2026-01-01');
-- R25 : rappel bloqué « en cours d'envoi » depuis une heure.
insert into uniion_private.agenda_reminders(id,event_id,version,user_id,status,created_at) values('45000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000004',1,'40000000-0000-4000-8000-000000000003','sending',now()-interval '2 hours');
-- R38 : PV relu (non publié) d'un audio.
insert into uniion_private.meeting_audio(id,organization_id,meeting_id,request_id,actor,consent_version,meeting_version,consent_actor,consent_at,participants,filename,size,sha256,path) values('46000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000002',gen_random_uuid(),'40000000-0000-4000-8000-000000000003',1,1,'40000000-0000-4000-8000-000000000003',now(),'[]','reunion.wav',44,repeat('a',64),'p/a');
insert into uniion_private.transcription_parts(job_id,id,sha256,consent_version,meeting_version,offset_ms,duration_ms) values('42000000-0000-4000-8000-000000000001','46000000-0000-4000-8000-000000000001',repeat('a',64),1,1,0,1000);
insert into uniion_private.meeting_minutes(organization_id,resource_id,meeting_id,job_id,source_snapshot,creator) values('43000000-0000-4000-8000-000000000001','46000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000002','42000000-0000-4000-8000-000000000001','[]','40000000-0000-4000-8000-000000000003');
insert into uniion_private.business_publications(id,organization_id,resource_id,version,module,body,recipients,reviewer) values('46000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000001','46000000-0000-4000-8000-000000000002',1,'reunions','{}','{}','40000000-0000-4000-8000-000000000003');
insert into uniion_private.scan_workers values('40000000-0000-4000-8000-000000000001'),('40000000-0000-4000-8000-000000000002');
set local session_replication_role=origin;
create function pg_temp.as_user(u text,s text) returns void language sql as $$select set_config('request.jwt.claims',json_build_object('sub',u,'session_id',s,'aal','aal1','role','authenticated')::text,true)$$;
do $$begin
 -- R20 : scanner reconnu seulement avec une session active.
 perform pg_temp.as_user('40000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000001');
 if not uniion_private.is_scanner() then raise exception 'R20 : scanner avec session active refusé';end if;
 perform pg_temp.as_user('40000000-0000-4000-8000-000000000002','41000000-0000-4000-8000-000000000002');
 if uniion_private.is_scanner() then raise exception 'R20 : scanner avec session expirée accepté';end if;
 perform pg_temp.as_user('40000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-0000000000ff');
 if uniion_private.is_scanner() then raise exception 'R20 : scanner sans session existante accepté';end if;
 perform pg_temp.as_user('40000000-0000-4000-8000-000000000003','41000000-0000-4000-8000-000000000003');
 if uniion_private.is_scanner() then raise exception 'R20 : compte non scanner accepté';end if;
 -- R34 : une tâche en attente dont les sources ne sont plus valides passe en erreur à la prise en charge.
 perform pg_temp.as_user('40000000-0000-4000-8000-000000000004','41000000-0000-4000-8000-000000000004');
 perform public.uniion_transcription_worker('claim');
 if (select state from uniion_private.transcription_jobs where id='42000000-0000-4000-8000-000000000001')<>'error' then raise exception 'R34 : tâche orpheline restée en attente';end if;
 if (select error from uniion_private.transcription_jobs where id='42000000-0000-4000-8000-000000000001') is distinct from 'sources_changed' then raise exception 'R34 : motif absent';end if;
 -- R53 : l'échéancier passe à revoir au lieu d'être sauté en silence.
 perform uniion_private.run_dues_schedules('43000000-0000-4000-8000-000000000001');
 if (select state from uniion_private.dues_schedules where id='44000000-0000-4000-8000-000000000001')<>'review' then raise exception 'R53 : échéancier sans droits resté actif';end if;
 -- R25 : le rappel bloqué devient incertain.
 perform uniion_private.agenda_claim();
 if (select status from uniion_private.agenda_reminders where id='45000000-0000-4000-8000-000000000001')<>'uncertain' then raise exception 'R25 : rappel resté en cours d''envoi';end if;
 -- R38 : relecture seule = pas d'éligibilité ; publication = éligible ; révocation = plus éligible.
 update uniion_private.business_publications set reviewed_at=now() where id='46000000-0000-4000-8000-000000000003';
 if exists(select 1 from uniion_private.audio_retention_validations where audio_id='46000000-0000-4000-8000-000000000001') then raise exception 'R38 : audio éligible dès la relecture';end if;
 update uniion_private.business_publications set published_at=now() where id='46000000-0000-4000-8000-000000000003';
 if not exists(select 1 from uniion_private.audio_retention_validations where audio_id='46000000-0000-4000-8000-000000000001') then raise exception 'R38 : audio non éligible après publication';end if;
 update uniion_private.business_publications set revoked_at=now() where id='46000000-0000-4000-8000-000000000003';
 if exists(select 1 from uniion_private.audio_retention_validations where audio_id='46000000-0000-4000-8000-000000000001') then raise exception 'R38 : audio encore éligible après révocation';end if;
 raise notice 'comportements de contrôle d''accès : OK';
end$$;
rollback;
