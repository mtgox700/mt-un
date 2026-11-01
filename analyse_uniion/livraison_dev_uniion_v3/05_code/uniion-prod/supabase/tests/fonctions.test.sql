-- Tests des fonctions métier et de la couverture RLS (pgTAP). Lancer : supabase test db
begin;
select plan(16);

-- ---------------------------------------------------------------- couverture
-- Toute table de public a la RLS ; celles sans politique sont volontairement « serveur seul ».
select is(
  (select coalesce(string_agg(tablename, ', ' order by tablename), '') from pg_tables
   where schemaname = 'public' and not rowsecurity),
  '', 'Aucune table sans RLS');
select is(
  (select coalesce(string_agg(t.tablename, ', ' order by t.tablename), '') from pg_tables t
   where t.schemaname = 'public'
     and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename and p.permissive = 'PERMISSIVE')
     and t.tablename not in ('adherent', 'cotisation', 'attestation_fiscale', 'liste_membre_fixe', 'campagne_envoi', 'desinscription',
                             'import_adherents', 'dossier_note', 'dossier_conversation', 'message', 'sondage_reponse',
                             'sondage_participation', 'tache_file', 'execution_retention')),
  '', 'Toute table sans politique client figure dans la liste « serveur seul »');
select is(
  (select count(*)::int from information_schema.role_table_grants
   where grantee = 'authenticated' and table_schema = 'public'
     and table_name in ('adherent', 'cotisation', 'attestation_fiscale', 'dossier_note', 'message', 'sondage_reponse', 'tache_file')),
  0, 'Tables sensibles : aucun droit direct pour authenticated');
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'api' and not p.prosecdef and p.prokind = 'f'),
  0, 'Toutes les fonctions api sont security definer (filtrage explicite)');
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('api', 'app') and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0, 'Toute fonction security definer fixe son search_path');

-- ---------------------------------------------------------------- jeu de données
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'auteur@t.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'pair@t.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'tresor@t.test');
insert into organisation (id, nom, sigle, type) values ('org_t', 'Org test', 'T', 'section');
insert into personne (id, organisation_id, prenom, nom, email, auth_user_id) values
  ('per_auteur', 'org_t', 'Alice', 'Auteur', 'auteur@t.test', '00000000-0000-0000-0000-0000000000a1'),
  ('per_pair',   'org_t', 'Bruno', 'Pair',   'pair@t.test',   '00000000-0000-0000-0000-0000000000a2'),
  ('per_tres',   'org_t', 'Tina',  'Tresor', 'tresor@t.test', '00000000-0000-0000-0000-0000000000a3');
insert into personne_role (personne_id, role) values ('per_auteur', 'militant'), ('per_pair', 'communication'), ('per_tres', 'tresorier');
insert into sondage (id, organisation_id, titre, type, auteur_id, statut) values ('son_1', 'org_t', 'Horaires', 'choix', 'per_auteur', 'en_validation');
insert into document (id, organisation_id, titre, gabarit, auteur_id) values ('doc_b', 'org_t', 'Brouillon', 'tract', 'per_auteur');
insert into adherent (id, organisation_id, prenom, nom, email, consentement_contact, section) values
  ('adh_ok',  'org_t', 'Oui',  'Consent', 'oui@t.test',  true,  'Prod'),
  ('adh_non', 'org_t', 'Non',  'Refus',   'non@t.test',  false, 'Prod'),
  ('adh_des', 'org_t', 'Des',  'Inscrit', 'des@t.test',  true,  'Prod');
insert into desinscription (organisation_id, email_empreinte, canal) values ('org_t', app.empreinte_email('org_t', 'des@t.test'), 'email');
insert into liste_diffusion (id, organisation_id, libelle, type, canal, criteres) values ('lst_1', 'org_t', 'Production', 'dyn', 'email', '{"section":["Prod"]}');
insert into campagne (id, organisation_id, liste_id, objet, corps, canal, creee_par) values ('cmp_1', 'org_t', 'lst_1', 'AG', 'Bonjour {prenom}', 'email', 'per_tres');

create function pg_temp.qui(uid text, pid text, aal text default 'aal1') returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'personne_id', pid, 'org_id', 'org_t', 'aal', aal)::text, true)
$$;

-- ---------------------------------------------------------------- sondages
select pg_temp.qui('00000000-0000-0000-0000-0000000000a1', 'per_auteur');
select throws_ok($$select api.sondage_valider('son_1')$$, '42501', null, 'L''auteur ne valide pas son propre sondage');
select pg_temp.qui('00000000-0000-0000-0000-0000000000a2', 'per_pair');
select lives_ok($$select api.sondage_valider('son_1')$$, 'Un pair valide le sondage');
reset role;
update sondage set statut = 'diffuse' where id = 'son_1';
select pg_temp.qui('00000000-0000-0000-0000-0000000000a2', 'per_pair');
select lives_ok($$select api.sondage_repondre('son_1', '"A"')$$, 'Premier vote accepté');
select throws_ok($$select api.sondage_repondre('son_1', '"B"')$$, '23505', null, 'Second vote refusé');
reset role;
select is((select count(*)::int from information_schema.columns where table_name = 'sondage_reponse' and column_name like '%personne%'), 0,
  'La réponse ne porte aucun lien vers une personne');

-- ---------------------------------------------------------------- documents
select pg_temp.qui('00000000-0000-0000-0000-0000000000a2', 'per_pair');
select is((select count(*)::int from document), 0, 'Le brouillon d''autrui est invisible');

-- ---------------------------------------------------------------- campagnes
select pg_temp.qui('00000000-0000-0000-0000-0000000000a2', 'per_pair', 'aal2');
select throws_ok($$select api.campagne_envoyer('cmp_1')$$, '42501', null, 'Communication ne lance pas une diffusion aux adhérents');
select pg_temp.qui('00000000-0000-0000-0000-0000000000a3', 'per_tres', 'aal1');
select throws_ok($$select api.campagne_envoyer('cmp_1')$$, '42501', null, 'Trésorier sans double authentification : refusé');
select pg_temp.qui('00000000-0000-0000-0000-0000000000a3', 'per_tres', 'aal2');
select is(api.campagne_envoyer('cmp_1'), 1, 'Seul l''adhérent consentant et non désinscrit est destinataire');
select throws_ok($$select api.campagne_envoyer('cmp_1')$$, '23505', null, 'Une campagne ne part qu''une fois');
reset role;
select is((select count(*)::int from tache_file where nature = 'email'), 1, 'Un envoi mis en file, revérifié au moment de partir');

select * from finish();
rollback;
