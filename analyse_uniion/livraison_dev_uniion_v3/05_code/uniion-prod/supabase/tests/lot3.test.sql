-- Tests du lot 3 (migrations 9 à 11) : dossiers, import d'adhérents, agenda, documents. Lancer : supabase test db
begin;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'ref@t.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'autre@t.test'),
  ('00000000-0000-0000-0000-0000000000b3', 'tres@t.test'),
  ('00000000-0000-0000-0000-0000000000b4', 'ext@t.test');
insert into organisation (id, nom, sigle, type) values ('org_l3', 'Org lot 3', 'L3', 'section'), ('org_x', 'Autre org', 'X', 'section');
insert into personne (id, organisation_id, prenom, nom, email, auth_user_id) values
  ('per_ref',   'org_l3', 'Rita',  'Referente', 'ref@t.test',   '00000000-0000-0000-0000-0000000000b1'),
  ('per_autre', 'org_l3', 'Paul',  'Autre',     'autre@t.test', '00000000-0000-0000-0000-0000000000b2'),
  ('per_tr',    'org_l3', 'Tom',   'Tresorier', 'tres@t.test',  '00000000-0000-0000-0000-0000000000b3'),
  ('per_ext',   'org_x',  'Eve',   'Externe',   'ext@t.test',   '00000000-0000-0000-0000-0000000000b4');
insert into personne_role (personne_id, role) values ('per_ref', 'militant'), ('per_autre', 'militant'), ('per_tr', 'tresorier'), ('per_ext', 'militant');
insert into adherent (id, organisation_id, prenom, nom, email, entreprise) values ('adh_l3', 'org_l3', 'Deja', 'La', 'deja@t.test', 'SA');

create function pg_temp.qui(uid text, pid text, org text default 'org_l3', aal text default 'aal1') returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'personne_id', pid, 'org_id', org, 'aal', aal)::text, true)
$$;

-- ---------------------------------------------------------------- dossiers (migration 9)
select pg_temp.qui('00000000-0000-0000-0000-0000000000b1', 'per_ref');
select lives_ok($$insert into dossier (intitule, categorie) values ('Test', 'Juridique')$$, 'Création sans identifiant ni référent : posés par la base');
select is((select referent_id from dossier where intitule = 'Test'), 'per_ref', 'Le référent est la personne connectée');
select like((select id from dossier where intitule = 'Test'), 'dos\_%', 'Identifiant dos_ généré');
select throws_ok($$insert into dossier (intitule, categorie, detail_chiffre) values ('X', 'Y', '\x00')$$, '42501', null, 'detail_chiffre interdit en écriture directe');
select throws_ok($$insert into dossier (intitule, categorie, referent_id) values ('X', 'Y', 'per_autre')$$, '42501', null, 'On ne crée pas un dossier au nom d''un autre');
select is((select count(*)::int from dossier_historique h join dossier d on d.id = h.dossier_id where d.intitule = 'Test' and h.titre = 'Dossier ouvert'), 1, 'Ouverture tracée');
update dossier set statut = 'doing' where intitule = 'Test';
select is((select version from dossier where intitule = 'Test'), 2, 'Version incrémentée par la base');
select is((select corps from dossier_historique h join dossier d on d.id = h.dossier_id where d.intitule = 'Test' and h.titre = 'État modifié'), 'À traiter → En cours', 'Changement d''état tracé');
select throws_ok($$update dossier set version = 99 where intitule = 'Test'$$, '42501', null, 'La version ne se modifie pas à la main');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b2', 'per_autre');
select is((select count(*)::int from dossier where intitule = 'Test'), 0, 'Dossier invisible hors périmètre');

-- ---------------------------------------------------------------- import d'adhérents (migration 10)
select pg_temp.qui('00000000-0000-0000-0000-0000000000b2', 'per_autre', 'org_l3', 'aal2');
select throws_ok($$select api.adherents_importer('f.csv', ';', '[{"prenom":"A"}]')$$, '42501', null, 'Import réservé au trésorier');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b3', 'per_tr', 'org_l3', 'aal1');
select throws_ok($$select api.adherents_importer('f.csv', ';', '[{"prenom":"A"}]')$$, '42501', null, 'Import refusé sans double authentification');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b3', 'per_tr', 'org_l3', 'aal2');
select is((api.adherents_importer('f.csv', ';', '[
  {"prenom":"Ana","nom":"Un","email":"ana@t.test","entreprise":"SA","etablissement":"Nord","consentement":"oui"},
  {"prenom":"Ben","nom":"Deux","email":"ben@t.test","entreprise":"SA","etablissement":"Nord"},
  {"prenom":"","nom":"Trois","email":"pas-un-mail","entreprise":"SA","etablissement":"Nord"},
  {"prenom":"Deja","nom":"La","email":"DEJA@t.test","entreprise":"SA","etablissement":"Nord"}]', true) ->> 'valides')::int, 2, 'Simulation : 2 lignes valides sur 4');
reset role;
select is((select count(*)::int from adherent where organisation_id = 'org_l3'), 1, 'La simulation n''écrit rien');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b3', 'per_tr', 'org_l3', 'aal2');
select is((api.adherents_importer('f.csv', ';', '[
  {"prenom":"Ana","nom":"Un","email":"ana@t.test","entreprise":"SA","etablissement":"Nord","consentement":"oui"},
  {"prenom":"Ben","nom":"Deux","email":"ben@t.test","entreprise":"SA","etablissement":"Nord"}]', false) ->> 'valides')::int, 2, 'Import effectif');
reset role;
select is((select string_agg(prenom || ':' || consentement_contact, ',' order by prenom) from adherent where email in ('ana@t.test', 'ben@t.test')), 'Ana:true,Ben:false',
  'Consentement jamais présumé');
select is((select count(*)::int from import_adherents where organisation_id = 'org_l3'), 1, 'Import consigné');
select ok(not exists (select 1 from import_adherents where rapport::text ~ '(Ana|Ben|t\.test)'), 'Rapport sans donnée nominative');

-- ---------------------------------------------------------------- agenda et documents (migration 11)
select pg_temp.qui('00000000-0000-0000-0000-0000000000b1', 'per_ref');
insert into evenement (titre, type, debut, fin, visibilite) values ('Bureau', 'cse', now(), now() + interval '1 hour', 'bureau');
select throws_ok($$insert into evenement_participant (evenement_id, personne_id) select id, 'per_ext' from evenement where titre = 'Bureau'$$,
  '42501', null, 'Invité hors organisation refusé');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b2', 'per_autre');
select is((select count(*)::int from evenement where titre = 'Bureau'), 0, 'Événement « bureau » non transmis à un non-membre du bureau');
select pg_temp.qui('00000000-0000-0000-0000-0000000000b1', 'per_ref');
insert into document (titre, gabarit) values ('Tract', 'classique');
select throws_ok($$update document set statut = 'signe' where titre = 'Tract'$$, '42501', null, '« Signé » ne se pose pas depuis le client');
update document set titre = 'Tract v2' where titre = 'Tract';
select is((select version from document where titre = 'Tract v2'), 2, 'Version du document tenue par la base');

select * from finish();
rollback;
