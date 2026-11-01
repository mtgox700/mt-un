-- Tests du lot 3, suite : pages, médias, extensions, rétention (dates simulées), trésorerie (migration 13).
begin;
select plan(28);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'aut@t.test'),
  ('00000000-0000-0000-0000-0000000000c2', 'rel@t.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'com@t.test'),
  ('00000000-0000-0000-0000-0000000000c4', 'adm@t.test'),
  ('00000000-0000-0000-0000-0000000000c5', 'tre@t.test');
insert into organisation (id, nom, sigle, type) values ('org_b', 'Org B', 'B', 'section'), ('org_v', 'Victime', 'V', 'section');
insert into personne (id, organisation_id, prenom, nom, email, auth_user_id) values
  ('per_aut', 'org_b', 'Ana', 'Auteur',     'aut@t.test', '00000000-0000-0000-0000-0000000000c1'),
  ('per_rel', 'org_b', 'Rui', 'Relecteur',  'rel@t.test', '00000000-0000-0000-0000-0000000000c2'),
  ('per_com', 'org_b', 'Cam', 'Comm',       'com@t.test', '00000000-0000-0000-0000-0000000000c3'),
  ('per_adm', 'org_b', 'Ali', 'Admin',      'adm@t.test', '00000000-0000-0000-0000-0000000000c4'),
  ('per_tre', 'org_b', 'Tia', 'Tresoriere', 'tre@t.test', '00000000-0000-0000-0000-0000000000c5');
insert into personne_role (personne_id, role) values
  ('per_aut', 'militant'), ('per_rel', 'militant'), ('per_com', 'communication'), ('per_adm', 'admin'), ('per_tre', 'tresorier');
insert into adherent (id, organisation_id, prenom, nom, email, entreprise) values ('adh_b', 'org_b', 'Zoe', 'Membre', 'zoe@t.test', 'SA');

create function pg_temp.qui(uid text, pid text, aal text default 'aal1') returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'personne_id', pid, 'org_id', 'org_b', 'aal', aal)::text, true)
$$;

-- ---------------------------------------------------------------- pages : relecture ≠ auteur (migration 14)
select pg_temp.qui('00000000-0000-0000-0000-0000000000c1', 'per_aut');
insert into page (id, organisation_id, site, titre, slug, auteur_id, relecteur_id)
  values ('pag_t', 'org_b', 'intranet', 'Grève', 'greve', 'per_aut', 'per_rel');
select throws_ok($$update page set statut = 'publiee' where id = 'pag_t'$$, '42501', null, 'L''auteur ne publie pas sa page');
select throws_ok($$update page set statut = 'relue' where id = 'pag_t'$$, '42501', null, 'L''auteur ne se relit pas');
select throws_ok($$update page set relecteur_id = 'per_aut' where id = 'pag_t'$$, '23514', null, 'Relecteur = auteur refusé par la base');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c3', 'per_com');
select throws_ok($$update page set statut = 'publiee' where id = 'pag_t'$$, '42501', null, 'Pas de publication sans relecture');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c2', 'per_rel');
update page set statut = 'relue', relecture_note = 'OK' where id = 'pag_t';
select pg_temp.qui('00000000-0000-0000-0000-0000000000c3', 'per_com');
select lives_ok($$update page set statut = 'publiee' where id = 'pag_t'$$, 'Publication après relecture');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c1', 'per_aut');
update page set blocs = '[{"t":"p","v":"modifié"}]' where id = 'pag_t';
select is((select statut::text from page where id = 'pag_t'), 'brouillon', 'Modifier une page relue la renvoie en relecture');

-- ---------------------------------------------------------------- médias (migration 14)
select throws_ok($$insert into media (chemin, type_mime, taille_octets) values ('org_v/per_x/a.webp', 'image/webp', 100)$$,
  '23514', null, 'Chemin d''une autre organisation refusé');
select throws_ok($$insert into media (chemin, type_mime, taille_octets, personne_identifiable) values ('org_b/per_aut/b.webp', 'image/webp', 100, true)$$,
  '23514', null, 'Personne reconnaissable sans accord refusée');
insert into media (id, chemin, type_mime, taille_octets) values ('med_t', 'org_b/per_aut/c.webp', 'image/webp', 100);
select throws_ok($$update media set chemin = 'org_b/per_aut/autre.webp' where id = 'med_t'$$, '42501', null, 'Le chemin ne se modifie pas');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c2', 'per_rel');
update media set supprime_le = now() where id = 'med_t';
reset role;
select ok((select supprime_le is null from media where id = 'med_t'), 'Un autre militant ne met pas le média à la corbeille');

-- ---------------------------------------------------------------- extensions
insert into extension (id, version, nom, api, fichier, integrite_sri, signature) values
  ('uniion-studio', '1.2.0', 'uniion Studio', 1, '/ext/studio-1.2.0.js', 'sha384-AAAA', 'sig');
select throws_ok($$insert into extension (id, version, nom, api, fichier, integrite_sri, signature)
  values ('x', '1', 'X', 1, 'https://cdn.example/x.js', 'sha384-B', 's')$$, '23514', null, 'Fichier hors /ext/ refusé');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c1', 'per_aut');
select throws_ok($$insert into extension_activation (organisation_id, extension_id, version, active_par) values ('org_b', 'uniion-studio', '1.2.0', 'per_aut')$$,
  '42501', null, 'Activation réservée à l''administrateur');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c4', 'per_adm');
insert into extension_activation (organisation_id, extension_id, version, active_par) values ('org_b', 'uniion-studio', '1.2.0', 'per_adm');
select is((select count(*)::int from api.extensions_actives()), 1, 'Extension active servie');
reset role;
update extension set retiree_le = now() where id = 'uniion-studio';
select pg_temp.qui('00000000-0000-0000-0000-0000000000c4', 'per_adm');
select is((select count(*)::int from api.extensions_actives()), 0, 'Version retirée par l''éditeur : plus chargée');

-- ---------------------------------------------------------------- trésorerie (migration 13)
select pg_temp.qui('00000000-0000-0000-0000-0000000000c1', 'per_aut', 'aal2');
select throws_ok($$select api.tresorerie_synthese(2026)$$, '42501', null, 'Synthèse réservée au trésorier');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c5', 'per_tre', 'aal1');
select throws_ok($$select api.cotisations_lister('adh_b')$$, '42501', null, 'Trésorier sans double authentification refusé');
select pg_temp.qui('00000000-0000-0000-0000-0000000000c5', 'per_tre', 'aal2');
select throws_ok($$select api.cotisation_enregistrer('{"adherent_id":"adh_b","periode":"sept","montant":10}')$$, '22023', null, 'Période invalide');
select throws_ok($$select api.cotisation_enregistrer('{"adherent_id":"adh_b","periode":"2025","montant":0}')$$, '22023', null, 'Montant nul refusé');
select api.cotisation_enregistrer('{"adherent_id":"adh_b","periode":"2025","montant":120,"encaisse_le":"2025-03-01"}');
select api.cotisation_enregistrer('{"adherent_id":"adh_b","periode":"2025","montant":150,"encaisse_le":"2025-03-01"}');
select is((api.tresorerie_synthese(2025) ->> 'encaisse')::numeric, 150::numeric, 'Une ligne par période : la correction remplace');
select throws_ok(format('select api.attestations_generer(%s)', extract(year from current_date)), '22023', null, 'Attestation sur année non close refusée');
select is(api.attestations_generer(2025), 1, 'Attestation générée');
select is((api.attestation_lire('adh_b', 2025) ->> 'montant')::numeric, 150::numeric, 'Montant attesté = versements de l''année');
reset role;
select ok(exists (select 1 from audit where action = 'attestation.lire' and ressource_id = 'adh_b'), 'Lecture d''attestation journalisée');

-- ---------------------------------------------------------------- rétention (dates simulées)
set local session_replication_role = replica;  -- pose de dates passées sans déclencheurs
insert into dossier (id, organisation_id, intitule, categorie, referent_id, statut, clos_le, contentieux)
  values ('dos_vieux', 'org_b', 'Licenciement M. X', 'Juridique', 'per_aut', 'done', now() - interval '6 years', false),
         ('dos_cont',  'org_b', 'Prud''hommes',     'Juridique', 'per_aut', 'done', now() - interval '6 years', true);
update media set supprime_le = now() - interval '31 days' where id = 'med_t';
update personne set desactive_le = now() - interval '4 months' where id = 'per_rel';
set local session_replication_role = origin;
select app.retention_executer();
select is((select intitule from dossier where id = 'dos_vieux'), 'Dossier anonymisé', 'Dossier clos depuis 5 ans : anonymisé');
select is((select intitule from dossier where id = 'dos_cont'), 'Prud''hommes', 'Contentieux : conservé 10 ans');
select ok(not exists (select 1 from media where id = 'med_t')
          and exists (select 1 from tache_file where idempotency_key = 'purge:media:org_b/per_aut/c.webp'), 'Média en corbeille : ligne supprimée, fichier mis en file de purge');
select is((select nom from personne where id = 'per_rel'), 'Ancien membre', 'Membre révoqué depuis 3 mois : anonymisé');
select ok((select count(distinct entite) >= 21 from execution_retention where execute_le > now() - interval '1 minute'), 'Chaque règle trace son exécution, même à zéro ligne');

select * from finish();
rollback;
