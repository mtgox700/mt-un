-- uniion — migration 7/7 : durées de conservation (MODELE_DONNEES.md §Conservation)
-- Chaque règle écrit une ligne dans execution_retention, même à zéro ligne traitée :
-- une purge sans trace d'exécution est une purge non exécutée. Les fichiers (audio, pièces,
-- médias) sont mis en file (tache_file, nature 'retention') et supprimés du stockage par
-- l'Edge Function « file-taches ».

create extension if not exists pg_cron;

create or replace function app._regle(p_entite text, p_sql text, p_anonymise boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare n integer; t0 timestamptz := clock_timestamp();
begin
  execute p_sql;
  get diagnostics n = row_count;
  insert into execution_retention (entite, lignes_traitees, lignes_supprimees, lignes_anonymisees, duree_ms)
  values (p_entite, n, case when p_anonymise then 0 else n end, case when p_anonymise then n else 0 end,
          extract(milliseconds from clock_timestamp() - t0)::int);
end $$;

create or replace function app.fichier_a_purger(p_org text, p_bucket text, p_chemin text) returns void
language sql security definer set search_path = public as $$
  insert into tache_file (id, organisation_id, nature, charge, idempotency_key)
  values ('tch_' || replace(gen_random_uuid()::text, '-', ''), p_org, 'retention',
          jsonb_build_object('bucket', p_bucket, 'chemin', p_chemin), 'purge:' || p_bucket || ':' || p_chemin)
  on conflict (idempotency_key) do nothing
$$;

create or replace function app.retention_executer() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- Fichiers d'abord (avant que les lignes qui les référencent disparaissent)
  perform app.fichier_a_purger(organisation_id, 'pieces', audio_chemin) from reunion
    where audio_chemin is not null and date_seance < now() - interval '90 days';
  perform app._regle('reunion.audio_90j',
    $q$update reunion set audio_chemin = null, audio_supprime_le = now()
       where audio_chemin is not null and date_seance < now() - interval '90 days'$q$);
  perform app.fichier_a_purger(d.organisation_id, 'pieces', pj.chemin_chiffre)
    from piece_jointe pj join dossier d on d.id = pj.dossier_id
    where (pj.supprime_le < now() - interval '30 days')
       or (d.clos_le < now() - interval '5 years' and not d.contentieux)
       or (d.clos_le < now() - interval '10 years');
  perform app.fichier_a_purger(organisation_id, 'media', chemin) from media where supprime_le < now() - interval '30 days';

  -- Dossiers : anonymisation à 5 ans (10 ans si contentieux), agrégats conservés
  perform app._regle('dossier.contenu_echu', $q$
    with echus as (select id from dossier where intitule <> 'Dossier anonymisé'
                   and ((clos_le < now() - interval '5 years' and not contentieux) or clos_le < now() - interval '10 years'))
    , a as (delete from dossier_note where dossier_id in (select id from echus))
    , b as (delete from dossier_historique where dossier_id in (select id from echus))
    , c as (delete from dossier_conversation where dossier_id in (select id from echus))
    , d as (delete from piece_jointe where dossier_id in (select id from echus))
    , e as (delete from dossier_acces where dossier_id in (select id from echus))
    update dossier set intitule = 'Dossier anonymisé', description = null, detail_chiffre = null
    where id in (select id from echus)$q$, true);
  perform app._regle('dossier_conversation.2ans', $q$delete from dossier_conversation where cree_le < now() - interval '2 years'$q$);
  perform app._regle('requete_ia.12mois',         $q$delete from requete_ia where cree_le < now() - interval '12 months'
                                                     and id not in (select requete_id from dossier_conversation where requete_id is not null)$q$);

  -- Adhérents : anonymisation 3 ans après la fin d'adhésion (les cotisations restent 10 ans : comptabilité)
  perform app._regle('adherent.radie_3ans', $q$
    update adherent set prenom = '—', nom = 'Ancien adhérent', email = null, telephone = null, emploi = null,
           section = null, direction = null, supprime_le = coalesce(supprime_le, now())
    where date_fin_adhesion < now() - interval '3 years' and nom <> 'Ancien adhérent'$q$, true);
  perform app._regle('adherent.corbeille_30j', $q$
    update adherent set prenom = '—', nom = 'Ancien adhérent', email = null, telephone = null, emploi = null
    where supprime_le < now() - interval '30 days' and nom <> 'Ancien adhérent'$q$, true);
  perform app._regle('cotisation.10ans',          $q$delete from cotisation where encaisse_le < now() - interval '10 years'$q$);
  perform app._regle('attestation_fiscale.6ans',  $q$delete from attestation_fiscale where emise_le < now() - interval '6 years'$q$);
  perform app._regle('campagne.contenu_12mois',   $q$update campagne set corps = '', objet = '[contenu purgé]'
                                                     where cree_le < now() - interval '12 months' and objet <> '[contenu purgé]'$q$, true);

  -- Documents, réunions, agenda, sites
  perform app._regle('document.brouillon_2ans',   $q$delete from document where statut = 'brouillon' and modifie_le < now() - interval '2 years'$q$);
  perform app._regle('document.corbeille_30j',    $q$delete from document where supprime_le < now() - interval '30 days'$q$);
  perform app._regle('reunion.transcription_2ans', $q$update reunion set transcription = null
                                                     where transcription is not null and date_seance < now() - interval '2 years'$q$, true);
  perform app._regle('evenement.3ans',            $q$delete from evenement where fin < now() - interval '3 years' or supprime_le < now() - interval '30 days'$q$);
  perform app._regle('page.corbeille_30j',        $q$delete from page where supprime_le < now() - interval '30 days'$q$);
  perform app._regle('media.corbeille_30j',       $q$delete from media where supprime_le < now() - interval '30 days'$q$);
  perform app._regle('piece_jointe.corbeille_30j', $q$delete from piece_jointe where supprime_le < now() - interval '30 days'$q$);

  -- Messagerie : mandat de l'auteur + 12 mois
  perform app._regle('message.mandat_12mois', $q$
    delete from message m using personne p where p.id = m.auteur_id
    and m.envoye_le < now() - interval '12 months' and p.mandat_fin < now() - interval '12 months'$q$);

  -- Transverse
  perform app._regle('notification.90j', $q$delete from notification where cree_le < now() - interval '90 days'$q$);
  perform app._regle('appareil.90j',     $q$delete from appareil where coalesce(derniere_activite, '-infinity') < now() - interval '90 days'$q$);
  perform app._regle('audit.5ans',       $q$delete from audit where horodatage < now() - interval '5 years'$q$);
  perform app._regle('personne.revoquee_3mois', $q$
    update personne set prenom = '—', nom = 'Ancien membre', email = id || '@anonymise.invalid', telephone = null,
           auth_user_id = null, anonymise_le = now()
    where desactive_le < now() - interval '3 months' and anonymise_le is null$q$, true);
end $$;

-- Désactivation automatique à la fin du mandat (EXPLOITATION.md §5 : sous 24 h)
create or replace function app.fin_de_mandat() returns void
language sql security definer set search_path = public as $$
  update personne set desactive_le = now() where mandat_fin < current_date and desactive_le is null
$$;

-- Supervision : la dernière exécution complète date-t-elle de moins de 26 h ?
create or replace function app.retention_a_jour() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(max(execute_le) > now() - interval '26 hours', false) from execution_retention where entite = 'personne.revoquee_3mois'
$$;

select cron.schedule('uniion-fin-de-mandat', '5 * * * *',  'select app.fin_de_mandat()');
select cron.schedule('uniion-retention',     '15 3 * * *', 'select app.retention_executer()');
select cron.schedule('uniion-cron-menage',   '0 4 * * 0',  $$delete from cron.job_run_details where end_time < now() - interval '30 days'$$);
