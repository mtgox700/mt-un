-- Lot 3 — ce que les écrans Dossiers attendent de la base.
-- 1. Identifiants, organisation et référent posés par la base, jamais par le client.
-- 2. Insertion limitée aux colonnes métier (detail_chiffre passe par « coffre »).
-- 3. Concurrence optimiste : version incrémentée ici, le client filtre sur l'ancienne.
-- 4. Changement d'état tracé dans l'historique par la base (le client ne peut pas l'omettre).

alter table dossier alter column id set default 'dos_' || replace(gen_random_uuid()::text, '-', '');
alter table dossier alter column organisation_id set default app.org_id();
alter table dossier alter column referent_id set default app.personne_id();
alter table dossier_historique alter column id set default 'hist_' || replace(gen_random_uuid()::text, '-', '');
alter table dossier_historique alter column auteur_id set default app.personne_id();

revoke insert on dossier from authenticated;
grant insert (intitule, categorie, description, echeance, etablissement_id, niveau_masquage, contentieux) on dossier to authenticated;
revoke update (version, modifie_le) on dossier from authenticated;
grant insert (dossier_id, titre, corps) on dossier_historique to authenticated;

create or replace function app.dossier_avant_maj() returns trigger
language plpgsql as $$
begin
  new.version := old.version + 1;
  new.modifie_le := now();
  if new.statut is distinct from old.statut then
    new.clos_le := case when new.statut = 'done' then now() else null end;
  end if;
  return new;
end $$;
create trigger dossier_avant_maj before update on dossier for each row execute function app.dossier_avant_maj();

create or replace function app.dossier_apres_maj() returns trigger
language plpgsql security definer set search_path = public as $$
declare lib constant jsonb := '{"todo":"À traiter","doing":"En cours","done":"Terminé"}';
begin
  if new.statut is distinct from old.statut then
    insert into dossier_historique (dossier_id, titre, corps, auteur_id)
    values (new.id, 'État modifié', (lib ->> old.statut::text) || ' → ' || (lib ->> new.statut::text), coalesce(app.personne_id(), new.referent_id));
  end if;
  if new.supprime_le is not null and old.supprime_le is null then
    perform app.journaliser('dossier.supprimer', 'dossier', new.id);
  end if;
  return null;
end $$;
create trigger dossier_apres_maj after update on dossier for each row execute function app.dossier_apres_maj();

create or replace function app.dossier_apres_creation() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into dossier_historique (dossier_id, titre, auteur_id) values (new.id, 'Dossier ouvert', new.referent_id);
  return null;
end $$;
create trigger dossier_apres_creation after insert on dossier for each row execute function app.dossier_apres_creation();

-- Personnes ajoutables au périmètre d'un dossier : membres actifs de l'organisation, sans coordonnées.
create or replace view api.collegues with (security_invoker = true) as
  select id, prenom, nom, mandat from personne where desactive_le is null;
grant select on api.collegues to authenticated;
