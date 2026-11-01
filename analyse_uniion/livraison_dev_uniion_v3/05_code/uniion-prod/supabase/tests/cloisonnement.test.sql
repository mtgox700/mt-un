-- Tests de cloisonnement (pgTAP). Lancer : supabase test db
-- Deux organisations, quatre personnes. Chaque test se place dans la peau d'un utilisateur
-- en posant les claims du jeton, exactement comme PostgREST.
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'sophie@a.test'),
  ('00000000-0000-0000-0000-00000000000b', 'paul@a.test'),
  ('00000000-0000-0000-0000-00000000000c', 'tresor@a.test'),
  ('00000000-0000-0000-0000-00000000000d', 'intrus@b.test');
insert into organisation (id, nom, sigle, type) values ('org_a', 'Section A', 'A', 'section'), ('org_b', 'Section B', 'B', 'section');
insert into personne (id, organisation_id, prenom, nom, email, auth_user_id, bureau) values
  ('per_sophie', 'org_a', 'Sophie', 'Marchand', 'sophie@a.test', '00000000-0000-0000-0000-00000000000a', true),
  ('per_paul',   'org_a', 'Paul',   'Durand',   'paul@a.test',   '00000000-0000-0000-0000-00000000000b', false),
  ('per_tresor', 'org_a', 'Tom',    'Caisse',   'tresor@a.test', '00000000-0000-0000-0000-00000000000c', false),
  ('per_intrus', 'org_b', 'Ivan',   'Trus',     'intrus@b.test', '00000000-0000-0000-0000-00000000000d', true);
insert into personne_role values ('per_sophie', 'militant'), ('per_paul', 'militant'), ('per_tresor', 'tresorier'), ('per_intrus', 'admin');
insert into dossier (id, organisation_id, intitule, categorie, referent_id) values
  ('dos_1', 'org_a', 'Harcèlement', 'RPS', 'per_sophie'),
  ('dos_2', 'org_b', 'Autre org',  'RH',  'per_intrus');
insert into adherent (id, organisation_id, prenom, nom) values ('adh_1', 'org_a', 'Marie', 'Dupont');
insert into evenement (id, organisation_id, titre, type, debut, fin, createur_id, visibilite) values
  ('evt_bureau', 'org_a', 'Bureau', 'reunion', now(), now() + interval '1 hour', 'per_sophie', 'bureau');

create function pg_temp.en_tant_que(uid text, pid text, org text, aal text default 'aal1') returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'personne_id', pid, 'org_id', org, 'aal', aal)::text, true)
$$;

-- Sophie, référente de dos_1
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000a', 'per_sophie', 'org_a');
select is((select count(*) from dossier)::int, 1, 'Sophie voit son dossier');
select is((select count(*) from evenement)::int, 1, 'Sophie (bureau) voit l''événement bureau');
select throws_ok($$select * from adherent$$, '42501', null, 'Sophie : aucun accès direct aux adhérents');
select throws_ok($$select * from api.adherents_lister()$$, '42501', null, 'Sophie : fonction adhérents refusée (rôle)');

-- Paul, même organisation, pas dans le périmètre
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000b', 'per_paul', 'org_a');
select is((select count(*) from dossier)::int, 0, 'Paul ne voit PAS le dossier de Sophie (correctif du schéma d''origine)');
select is((select count(*) from evenement)::int, 0, 'Paul (hors bureau) ne reçoit pas l''événement bureau');
select throws_ok($$insert into dossier (id, organisation_id, intitule, categorie, referent_id) values ('dos_x','org_a','x','x','per_sophie')$$,
  '42501', null, 'Paul ne peut pas créer un dossier au nom de Sophie');

-- Trésorier
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000c', 'per_tresor', 'org_a', 'aal1');
select throws_ok($$select * from api.adherents_lister()$$, '42501', null, 'Trésorier sans double authentification : refusé');
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000c', 'per_tresor', 'org_a', 'aal2');
select is((select count(*) from api.adherents_lister())::int, 1, 'Trésorier avec double authentification : accès');
reset role;
select is((select count(*) from audit where action = 'adherents.lister' and article_9)::int, 1, 'Lecture nominative journalisée');
select isnt((select empreinte from audit order by id desc limit 1), null, 'Empreinte chaînée posée');

-- Intrus d'une autre organisation qui forge un jeton vers org_a
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000d', 'per_intrus', 'org_a');
select is((select count(*) from dossier)::int, 0, 'Jeton forgé vers une autre organisation : rien');
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000d', 'per_intrus', 'org_b');
select is((select count(*) from personne)::int, 1, 'Intrus ne voit que sa propre organisation');

-- Compte désactivé : accès coupé sans attendre l'expiration du jeton
reset role;
update personne set desactive_le = now() where id = 'per_sophie';
select pg_temp.en_tant_que('00000000-0000-0000-0000-00000000000a', 'per_sophie', 'org_a');
select is((select count(*) from dossier)::int, 0, 'Compte désactivé : plus aucun accès immédiatement');

select * from finish();
rollback;
