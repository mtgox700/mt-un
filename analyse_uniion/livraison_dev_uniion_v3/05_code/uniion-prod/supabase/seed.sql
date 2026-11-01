-- Données de DÉVELOPPEMENT uniquement (synthétiques). Jamais chargé en recette/production.
-- Comptes : sophie@demo.test / marc@demo.test — mot de passe : Demo-uniion-2026!
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'sophie@demo.test',
   extensions.crypt('Demo-uniion-2026!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'marc@demo.test',
   extensions.crypt('Demo-uniion-2026!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into organisation (id, nom, sigle, type, idcc) values ('org_demo', 'Section syndicale Métallurgie — Démo', 'FO Métaux', 'section', '3248');
insert into etablissement (id, organisation_id, libelle) values ('eta_1', 'org_demo', 'Site Nord'), ('eta_2', 'org_demo', 'Site Sud');
insert into personne (id, organisation_id, prenom, nom, email, mandat, auth_user_id, bureau, mfa_actif) values
  ('per_sophie', 'org_demo', 'Sophie', 'Marchand', 'sophie@demo.test', 'Déléguée syndicale · secrétaire de section', '11111111-1111-1111-1111-111111111111', true, false),
  ('per_marc',   'org_demo', 'Marc',   'Lemaire',  'marc@demo.test',   'Trésorier de section',                      '22222222-2222-2222-2222-222222222222', true, false);
insert into personne_role (personne_id, role) values ('per_sophie', 'militant'), ('per_sophie', 'admin'), ('per_marc', 'militant'), ('per_marc', 'tresorier');
insert into dossier (id, organisation_id, intitule, categorie, referent_id, echeance) values
  ('dos_demo_1', 'org_demo', 'Planning des équipes de nuit', 'Temps de travail', 'per_sophie', current_date + 10);
insert into adherent (id, organisation_id, prenom, nom, entreprise, etablissement_id, section, statut_cotisation) values
  ('adh_demo_1', 'org_demo', 'Camille', 'Exemple', 'Démo Industrie', 'eta_1', 'Production', 'a_jour');
insert into extension (id, version, nom, api, fichier, integrite_sri, signature) values
  ('uniion-studio', '1.2.0', 'uniion Studio', 1, '/ext/uniion-studio-1.2.0.js', 'sha384-A-CALCULER-AU-BUILD', 'A-SIGNER-AU-BUILD');
