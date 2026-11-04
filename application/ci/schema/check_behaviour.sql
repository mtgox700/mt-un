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
 raise notice 'comportements de contrôle d''accès : OK';
end$$;
rollback;
