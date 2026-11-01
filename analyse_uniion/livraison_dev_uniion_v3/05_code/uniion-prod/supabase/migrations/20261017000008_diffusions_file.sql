-- uniion — migration 8 : diffusions aux adhérents, désinscription, file de tâches planifiée

-- Recherche d'un compte Auth existant (élu déjà inscrit dans une autre organisation). service_role seul.
create or replace function api.auth_id_par_email(p_email text) returns uuid
language sql stable security definer set search_path = public, auth as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1
$$;
revoke execute on function api.auth_id_par_email(text) from public, anon, authenticated;
grant execute on function api.auth_id_par_email(text) to service_role;

-- Empreinte d'e-mail par organisation : témoin de refus sans l'adresse en clair.
create or replace function app.empreinte_email(p_org text, p_email text) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(digest(p_org || ':' || lower(trim(p_email)), 'sha256'), 'hex')
$$;

-- Lancement d'une campagne : réservé aux rôles ayant accès au fichier (AUTORISATIONS.md 5.2).
-- Les destinataires sont figés ici pour la trace ; consentement et désinscription sont revérifiés
-- par la file au moment de chaque envoi.
create or replace function api.campagne_envoyer(p_campagne text) returns integer
language plpgsql security definer set search_path = public as $$
declare c campagne; l liste_diffusion; n integer;
begin
  if not ((app.has_role('tresorier') or app.has_role('admin')) and app.aal2()) then
    raise exception 'réservé au trésorier ou à l''administrateur avec double authentification' using errcode = '42501';
  end if;
  select * into c from campagne where id = p_campagne and organisation_id = app.org_id();
  if c.id is null then raise exception 'campagne introuvable' using errcode = 'P0002'; end if;
  if exists (select 1 from campagne_envoi where campagne_id = c.id) then raise exception 'campagne déjà lancée' using errcode = '23505'; end if;
  select * into l from liste_diffusion where id = c.liste_id and organisation_id = app.org_id() and supprime_le is null;
  if l.id is null then raise exception 'liste introuvable' using errcode = 'P0002'; end if;

  with dest as (
    select a.id from adherent a
    where a.organisation_id = app.org_id() and a.supprime_le is null and a.consentement_contact and a.email is not null
      and (
        (l.type = 'fixe' and exists (select 1 from liste_membre_fixe m where m.liste_id = l.id and m.adherent_id = a.id))
        or (l.type = 'dyn'
          and (not l.criteres ? 'entreprise'        or a.entreprise              in (select jsonb_array_elements_text(l.criteres -> 'entreprise')))
          and (not l.criteres ? 'etablissement_id'  or a.etablissement_id        in (select jsonb_array_elements_text(l.criteres -> 'etablissement_id')))
          and (not l.criteres ? 'section'           or a.section                 in (select jsonb_array_elements_text(l.criteres -> 'section')))
          and (not l.criteres ? 'direction'         or a.direction               in (select jsonb_array_elements_text(l.criteres -> 'direction')))
          and (not l.criteres ? 'statut_cotisation' or a.statut_cotisation::text in (select jsonb_array_elements_text(l.criteres -> 'statut_cotisation')))))
      and not exists (select 1 from desinscription d where d.organisation_id = a.organisation_id and d.canal = c.canal
                      and d.email_empreinte = app.empreinte_email(a.organisation_id, a.email))
  ), envois as (
    insert into campagne_envoi (campagne_id, adherent_id) select c.id, id from dest returning id
  )
  insert into tache_file (id, organisation_id, nature, charge, idempotency_key, prochaine_tentative)
  select 'tch_' || replace(gen_random_uuid()::text, '-', ''), app.org_id(), 'email',
         jsonb_build_object('envoi_id', e.id::text), 'envoi:' || e.id, coalesce(c.planifiee_le, now())
  from envois e;
  get diagnostics n = row_count;

  update liste_diffusion set dernier_recalcul = now(), effectif_dernier = n where id = l.id;
  perform app.journaliser('campagne.envoyer', 'campagne', c.id, n || ' destinataire(s), canal ' || c.canal, true);
  return n;
end $$;
grant execute on function api.campagne_envoyer(text) to authenticated;

-- Suivi agrégé d'une campagne (aucun nom).
create or replace function api.campagne_suivi(p_campagne text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_object_agg(etat, n) from (
    select e.etat::text, count(*) n from campagne_envoi e join campagne c on c.id = e.campagne_id
    where c.id = p_campagne and c.organisation_id = app.org_id()
      and (c.creee_par = app.personne_id() or app.has_role('tresorier') or app.has_role('admin'))
    group by 1) x
$$;
grant execute on function api.campagne_suivi(text) to authenticated;

-- File de tâches : appel de l'Edge Function chaque minute. Secrets lus dans Vault
-- (créés par install-vps.sh : file_url, file_jeton, anon_key).
create extension if not exists pg_net;
select cron.schedule('uniion-file-taches', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'file_url'),
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key'),
      'x-file', (select decrypted_secret from vault.decrypted_secrets where name = 'file_jeton')),
    body := '{}'::jsonb, timeout_milliseconds := 55000)
  where exists (select 1 from vault.decrypted_secrets where name = 'file_url')
$$);
