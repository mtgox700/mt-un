-- uniion — migration 4/7 : droits et sécurité par ligne
-- Principe : rien n'est ouvert par défaut. Supabase accorde ALL aux rôles anon/authenticated sur
-- public : on retire tout, puis on rouvre table par table. Les données d'article 9 (adhérents,
-- cotisations) et les colonnes chiffrées ne sont accessibles QUE par fonctions (schéma api) ou
-- Edge Functions, pour que chaque lecture nominative soit journalisée.

revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from anon, public;
alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from anon, public;

-- RLS sur toutes les tables, puis cloisonnement RESTRICTIF par organisation (combiné en ET avec
-- les politiques permissives ci-dessous : aucune ne peut l'élargir).
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
  for t in
    select c.table_name from information_schema.columns c
    join pg_tables p on p.schemaname = 'public' and p.tablename = c.table_name
    where c.table_schema = 'public' and c.column_name = 'organisation_id'
  loop
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated
         using (organisation_id = (select app.org_id())) with check (organisation_id = (select app.org_id()))',
      t.table_name || '_cloisonnement', t.table_name);
  end loop;
end $$;

-- Aide : accès à un dossier (référent ou personne ajoutée). Security definer = pas de récursion RLS.
create or replace function app.acces_dossier(d text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from dossier x
    where x.id = d and x.organisation_id = app.org_id() and x.supprime_le is null
      and (x.referent_id = app.personne_id()
           or exists (select 1 from dossier_acces a where a.dossier_id = x.id and a.personne_id = app.personne_id())))
$$;
create or replace function app.referent_dossier(d text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from dossier where id = d and organisation_id = app.org_id() and referent_id = app.personne_id())
$$;
create or replace function app.membre_fil(f text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from fil_participant fp join fil on fil.id = fp.fil_id
                 where fp.fil_id = f and fp.personne_id = app.personne_id() and fil.organisation_id = app.org_id())
$$;
grant execute on function app.acces_dossier(text), app.referent_dossier(text), app.membre_fil(text) to authenticated;

-- ---------------------------------------------------------------- organisation & membres
grant select on organisation to authenticated;
grant update (nom, sigle, adresse, email) on organisation to authenticated;  -- type : jamais (base légale)
create policy organisation_lecture on organisation for select to authenticated using (id = (select app.org_id()));
create policy organisation_admin on organisation for update to authenticated
  using (id = (select app.org_id()) and (select app.has_role('admin')) and (select app.aal2()));

grant select on etablissement to authenticated;
grant insert, update, delete on etablissement to authenticated;
create policy etablissement_lecture on etablissement for select to authenticated using (true);
create policy etablissement_admin on etablissement for all to authenticated
  using ((select app.has_role('admin'))) with check ((select app.has_role('admin')));

-- Coordonnées : uniquement via la vue api.annuaire (respect de coord_visibles).
grant select (id, organisation_id, prenom, nom, mandat, mandat_debut, mandat_fin, etablissement_id,
              bureau, coord_visibles, desactive_le) on personne to authenticated;
grant update (telephone, coord_visibles) on personne to authenticated;
create policy personne_lecture on personne for select to authenticated using (true);
create policy personne_soi on personne for update to authenticated using (id = (select app.personne_id()));
-- Invitation, rôles, désactivation : Edge Function « membres » (service_role), journalisée.

grant select on personne_role to authenticated;
create policy personne_role_lecture on personne_role for select to authenticated
  using (exists (select 1 from personne p where p.id = personne_id));

grant select, delete on appareil to authenticated;
create policy appareil_soi on appareil for all to authenticated using (personne_id = (select app.personne_id()));

-- ---------------------------------------------------------------- dossiers (périmètre strict)
grant select, insert on dossier to authenticated;
grant update (intitule, categorie, description, statut, echeance, etablissement_id, niveau_masquage,
              clos_le, contentieux, supprime_le, version, modifie_le) on dossier to authenticated;
create policy dossier_perimetre on dossier for select to authenticated
  using (referent_id = (select app.personne_id())
         or exists (select 1 from dossier_acces a where a.dossier_id = dossier.id and a.personne_id = (select app.personne_id())));
create policy dossier_creation on dossier for insert to authenticated with check (referent_id = (select app.personne_id()));
create policy dossier_modification on dossier for update to authenticated using (app.acces_dossier(id));

grant select, insert, delete on dossier_acces to authenticated;
create policy dossier_acces_lecture on dossier_acces for select to authenticated using (app.acces_dossier(dossier_id));
create policy dossier_acces_gestion on dossier_acces for insert to authenticated with check (app.referent_dossier(dossier_id));
create policy dossier_acces_retrait on dossier_acces for delete to authenticated using (app.referent_dossier(dossier_id));

grant select, insert on dossier_historique to authenticated;  -- ajout seul
create policy dossier_historique_lecture on dossier_historique for select to authenticated using (app.acces_dossier(dossier_id));
create policy dossier_historique_ajout on dossier_historique for insert to authenticated
  with check (app.acces_dossier(dossier_id) and auteur_id = (select app.personne_id()));

-- dossier_note, dossier_conversation : colonnes chiffrées → Edge Function « coffre » uniquement.
-- piece_jointe : dépôt par Edge Function (antivirus, empreinte) ; lecture des métadonnées ici.
grant select on piece_jointe to authenticated;
create policy piece_lecture on piece_jointe for select to authenticated
  using (app.acces_dossier(dossier_id) and supprime_le is null and (antivirus_ok or depose_par = (select app.personne_id())));
grant select on piece_acces_log to authenticated;
create policy piece_log_referent on piece_acces_log for select to authenticated
  using (exists (select 1 from piece_jointe pj where pj.id = piece_id and app.referent_dossier(pj.dossier_id)));

-- ---------------------------------------------------------------- IA (métadonnées seulement)
grant select on requete_ia, ia_citation to authenticated;
create policy requete_ia_lecture on requete_ia for select to authenticated
  using (personne_id = (select app.personne_id()) or (select app.has_role('admin')));
create policy ia_citation_lecture on ia_citation for select to authenticated
  using (exists (select 1 from requete_ia r where r.id = requete_id));

-- ---------------------------------------------------------------- adhérents (article 9)
-- adherent, cotisation, attestation_fiscale, liste_membre_fixe, campagne_envoi, import_adherents,
-- desinscription : AUCUN droit direct. Accès par api.adherent_* (trésorier + double authentification,
-- journalisé) et Edge Functions d'envoi.
grant select, insert, update, delete on liste_diffusion to authenticated;
create policy liste_lecture on liste_diffusion for select to authenticated
  using ((select app.has_role('tresorier')) or (select app.has_role('admin')) or (select app.has_role('communication')));
create policy liste_gestion on liste_diffusion for all to authenticated
  using ((select app.has_role('tresorier')) and (select app.aal2()))
  with check ((select app.has_role('tresorier')) and (select app.aal2()));

grant select, insert on campagne to authenticated;
create policy campagne_lecture on campagne for select to authenticated
  using (creee_par = (select app.personne_id()) or (select app.has_role('tresorier')) or (select app.has_role('admin')));
create policy campagne_creation on campagne for insert to authenticated
  with check (creee_par = (select app.personne_id())
              and ((select app.has_role('tresorier')) or (select app.has_role('communication'))));

-- ---------------------------------------------------------------- agenda (visibilité filtrée à la lecture)
grant select, insert, update, delete on evenement to authenticated;
create policy evenement_lecture on evenement for select to authenticated
  using (visibilite = 'section'
         or createur_id = (select app.personne_id())
         or exists (select 1 from evenement_participant p where p.evenement_id = evenement.id and p.personne_id = (select app.personne_id()))
         or (visibilite = 'bureau' and (select app.bureau())));
create policy evenement_creation on evenement for insert to authenticated with check (createur_id = (select app.personne_id()));
create policy evenement_gestion on evenement for update to authenticated
  using (createur_id = (select app.personne_id()) or (select app.has_role('admin')));
create policy evenement_suppression on evenement for delete to authenticated
  using (createur_id = (select app.personne_id()) or (select app.has_role('admin')));

grant select, insert, update, delete on evenement_participant, evenement_rappel to authenticated;
create policy participant_lecture on evenement_participant for select to authenticated
  using (exists (select 1 from evenement e where e.id = evenement_id));
create policy participant_reponse on evenement_participant for update to authenticated
  using (personne_id = (select app.personne_id()));
create policy participant_gestion on evenement_participant for all to authenticated
  using (exists (select 1 from evenement e where e.id = evenement_id and e.createur_id = (select app.personne_id())));
create policy rappel_gestion on evenement_rappel for all to authenticated
  using (exists (select 1 from evenement e where e.id = evenement_id and e.createur_id = (select app.personne_id())));

-- ---------------------------------------------------------------- sites
grant select, insert, update on site_charte, rubrique to authenticated;
create policy charte_lecture on site_charte for select to authenticated using (true);
create policy charte_gestion on site_charte for all to authenticated
  using ((select app.has_role('communication')) or (select app.has_role('admin')))
  with check ((select app.has_role('communication')) or (select app.has_role('admin')));
create policy rubrique_lecture on rubrique for select to authenticated using (true);
create policy rubrique_gestion on rubrique for all to authenticated
  using ((select app.has_role('communication')) or (select app.has_role('admin')))
  with check ((select app.has_role('communication')) or (select app.has_role('admin')));

grant select, insert on page to authenticated;
grant update (titre, slug, chapo, blocs, rubrique_id, statut, relecteur_id, relecture_note, relecture_le,
              depubliee_le, supprime_le, version, modifie_le) on page to authenticated;
-- html_assaini : écrit uniquement par le serveur (liste blanche).
create policy page_lecture on page for select to authenticated
  using (statut = 'publiee' or auteur_id = (select app.personne_id()) or relecteur_id = (select app.personne_id())
         or (select app.has_role('communication')) or (select app.has_role('admin')));
create policy page_creation on page for insert to authenticated with check (auteur_id = (select app.personne_id()));
create policy page_modification on page for update to authenticated
  using (auteur_id = (select app.personne_id()) or relecteur_id = (select app.personne_id()) or (select app.has_role('communication')));

grant select, insert on demande_publication to authenticated;
create policy publication_lecture on demande_publication for select to authenticated
  using (exists (select 1 from page p where p.id = page_id));
create policy publication_creation on demande_publication for insert to authenticated
  with check ((select app.has_role('communication')) or (select app.has_role('admin')));

-- ---------------------------------------------------------------- documents, médias, extensions
grant select, insert, update, delete on document to authenticated;
create policy document_lecture on document for select to authenticated
  using (statut <> 'brouillon' or auteur_id = (select app.personne_id()));
create policy document_creation on document for insert to authenticated with check (auteur_id = (select app.personne_id()));
create policy document_modification on document for update to authenticated using (auteur_id = (select app.personne_id()));
create policy document_suppression on document for delete to authenticated
  using (auteur_id = (select app.personne_id()) or (select app.has_role('admin')));

grant select on signature to authenticated;  -- création : Edge Function (prestataire eIDAS)
create policy signature_lecture on signature for select to authenticated using (exists (select 1 from document d where d.id = document_id));

grant select, insert, update on media to authenticated;
create policy media_lecture on media for select to authenticated using (supprime_le is null);
create policy media_depot on media for insert to authenticated with check (depose_par = (select app.personne_id()));
create policy media_retrait on media for update to authenticated
  using (depose_par = (select app.personne_id()) or (select app.has_role('admin')));

grant select on extension to authenticated;
create policy extension_lecture on extension for select to authenticated using (retiree_le is null);
grant select, insert, update, delete on extension_activation to authenticated;
create policy activation_lecture on extension_activation for select to authenticated using (true);
create policy activation_admin on extension_activation for all to authenticated
  using ((select app.has_role('admin'))) with check ((select app.has_role('admin')) and active_par = (select app.personne_id()));

-- ---------------------------------------------------------------- sondages, réunions
grant select, insert on sondage to authenticated;
grant update (titre, type, options, cible, cloture_le, statut, version) on sondage to authenticated;
create policy sondage_lecture on sondage for select to authenticated
  using (statut in ('diffuse', 'clos') or auteur_id = (select app.personne_id()) or validateur_id = (select app.personne_id())
         or statut = 'en_validation');
create policy sondage_creation on sondage for insert to authenticated with check (auteur_id = (select app.personne_id()));
create policy sondage_brouillon on sondage for update to authenticated
  using (auteur_id = (select app.personne_id()) and statut in ('brouillon', 'en_validation'))
  with check (statut in ('brouillon', 'en_validation'));
-- Validation par un pair, réponses : api.sondage_valider / api.sondage_repondre.

grant select, insert, update on reunion to authenticated;
create policy reunion_lecture on reunion for select to authenticated
  using (cree_par = (select app.personne_id()) or participants ? (select app.personne_id()));
create policy reunion_creation on reunion for insert to authenticated with check (cree_par = (select app.personne_id()));
create policy reunion_modification on reunion for update to authenticated using (cree_par = (select app.personne_id()));

-- ---------------------------------------------------------------- messagerie
grant select on fil, fil_participant to authenticated;
create policy fil_lecture on fil for select to authenticated using (app.membre_fil(id));
create policy fil_participant_lecture on fil_participant for select to authenticated using (app.membre_fil(fil_id));
-- message : charge chiffrée → Edge Function « coffre ». Création de fil : api.fil_creer.

-- ---------------------------------------------------------------- transverse
grant select on notification to authenticated;
grant update (lu_le) on notification to authenticated;
create policy notification_soi on notification for all to authenticated using (personne_id = (select app.personne_id()));

grant select on audit to authenticated;
create policy audit_admin on audit for select to authenticated using ((select app.has_role('admin')) and (select app.aal2()));
-- tache_file, execution_retention : service_role uniquement.
