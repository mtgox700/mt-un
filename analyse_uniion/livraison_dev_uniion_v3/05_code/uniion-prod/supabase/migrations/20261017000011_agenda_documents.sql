-- Lot 3 — Agenda, Documents / tracts, médias, extensions.

-- Surfaces IA présentes dans les prompts mais absentes du type : l'insertion au journal échouait.
alter type surface_ia add value if not exists 'dossier_guide';
alter type surface_ia add value if not exists 'communication';
alter type surface_ia add value if not exists 'messagerie';
alter type surface_ia add value if not exists 'formation';

-- Version et date de modification tenues par la base (réutilisable).
create or replace function app.versionner() returns trigger language plpgsql as $$
begin new.version := old.version + 1; new.modifie_le := now(); return new; end $$;

-- ---------------------------------------------------------------- agenda
alter table evenement alter column id set default 'evt_' || replace(gen_random_uuid()::text, '-', '');
alter table evenement alter column organisation_id set default app.org_id();
alter table evenement alter column createur_id set default app.personne_id();
revoke insert, update on evenement from authenticated;
grant insert (titre, type, debut, fin, journee_entiere, lieu, description, visibilite, dossier_id) on evenement to authenticated;
grant update (titre, type, debut, fin, journee_entiere, lieu, description, visibilite, dossier_id, supprime_le) on evenement to authenticated;
create trigger evenement_version before update on evenement for each row execute function app.versionner();
-- Un dossier ne se lie qu'à un événement par quelqu'un qui y a accès.
alter table evenement add constraint evenement_dossier_acces check (dossier_id is null or app.acces_dossier(dossier_id)) not valid;

-- Invités : membres actifs de l'organisation uniquement (pas d'e-mail externe depuis le client).
create or replace function app.participant_valide() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.personne_id is null or not exists (select 1 from personne where id = new.personne_id and organisation_id = app.org_id() and desactive_le is null) then
    raise exception 'invité hors organisation' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger participant_valide before insert on evenement_participant for each row execute function app.participant_valide();
revoke update on evenement_participant from authenticated;
grant update (reponse) on evenement_participant to authenticated;

-- ---------------------------------------------------------------- documents
alter table document add column if not exists apparence jsonb not null default '{}';  -- { palette, police }
alter table document alter column id set default 'doc_' || replace(gen_random_uuid()::text, '-', '');
alter table document alter column organisation_id set default app.org_id();
alter table document alter column auteur_id set default app.personne_id();
revoke insert, update on document from authenticated;
grant insert (titre, gabarit, format, blocs, apparence) on document to authenticated;
grant update (titre, gabarit, format, statut, blocs, apparence, supprime_le) on document to authenticated;
create trigger document_version before update on document for each row execute function app.versionner();

-- « Signé » ne se pose que par le prestataire de signature (Edge Function), jamais par le client.
create or replace function app.document_statut() returns trigger language plpgsql as $$
begin
  if new.statut = 'signe' and old.statut <> 'signe' and current_user = 'authenticated' then
    raise exception 'la signature passe par le prestataire eIDAS' using errcode = '42501';
  end if;
  if old.statut = 'signe' and new.blocs is distinct from old.blocs then
    raise exception 'document signé : contenu figé' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger document_statut before update on document for each row execute function app.document_statut();

-- ---------------------------------------------------------------- médias
alter table media alter column organisation_id set default app.org_id();
alter table media alter column depose_par set default app.personne_id();

-- ---------------------------------------------------------------- extensions actives de l'organisation
create or replace function api.extensions_actives() returns table (id text, version text, fichier text, integrite_sri text, signature text, elements_desactives text[])
language sql stable security definer set search_path = public as $$
  select e.id, e.version, e.fichier, e.integrite_sri, e.signature, a.elements_desactives
  from extension_activation a join extension e on e.id = a.extension_id and e.version = a.version
  where a.organisation_id = app.org_id() and e.retiree_le is null
$$;
grant execute on function api.extensions_actives() to authenticated;
