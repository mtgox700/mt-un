-- uniion — migration 5/7 : fonctions exposées (schéma api)
-- À exposer dans PostgREST : PGRST_DB_SCHEMAS=public,storage,graphql_public,api
-- Toutes en security definer : elles contournent la RLS et filtrent donc EXPLICITEMENT
-- sur app.org_id(). Chaque lecture nominative d'adhérent est inscrite au journal d'audit.

create schema if not exists api;
grant usage on schema api to authenticated, service_role;
alter default privileges in schema api revoke execute on functions from public, anon;

-- ---------------------------------------------------------------- annuaire
create or replace view api.annuaire with (security_barrier = true) as
  select p.id, p.prenom, p.nom, p.mandat, p.etablissement_id, p.bureau,
         case when p.coord_visibles or p.id = app.personne_id() or app.has_role('admin') then p.email end     as email,
         case when p.coord_visibles or p.id = app.personne_id() or app.has_role('admin') then p.telephone end as telephone
  from public.personne p
  where p.organisation_id = app.org_id() and p.desactive_le is null;
grant select on api.annuaire to authenticated;

-- ---------------------------------------------------------------- identité courante (revalidée en base)
create or replace function api.moi() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'personne_id', app.personne_id(), 'org_id', app.org_id(), 'bureau', app.bureau(), 'aal', auth.jwt() ->> 'aal',
    'roles', (select coalesce(jsonb_agg(role), '[]') from personne_role where personne_id = app.personne_id()))
$$;

-- ---------------------------------------------------------------- organisation active
create or replace function api.basculer_organisation(p_org text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from personne where auth_user_id = auth.uid() and organisation_id = p_org and desactive_le is null) then
    raise exception 'organisation non rattachée à ce compte' using errcode = '42501';
  end if;
  update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}') || jsonb_build_object('org_active', p_org)
  where id = auth.uid();
  -- Le client appelle ensuite supabase.auth.refreshSession() pour obtenir un jeton à jour.
end $$;

create or replace function api.mes_organisations() returns table (organisation_id text, nom text, sigle text, type org_type)
language sql stable security definer set search_path = public as $$
  select o.id, o.nom, o.sigle, o.type from personne p join organisation o on o.id = p.organisation_id
  where p.auth_user_id = auth.uid() and p.desactive_le is null order by o.nom
$$;

-- ---------------------------------------------------------------- adhérents (article 9)
create or replace function api.adherents_lister(p_filtres jsonb default '{}', p_limite int default 200, p_decalage int default 0)
returns setof adherent
language plpgsql security definer set search_path = public as $$
begin
  perform app.exiger('tresorier');
  perform app.journaliser('adherents.lister', 'adherent', null, p_filtres::text, true);
  return query
    select a.* from adherent a
    where a.organisation_id = app.org_id() and a.supprime_le is null
      and (not p_filtres ? 'entreprise'        or a.entreprise                in (select jsonb_array_elements_text(p_filtres -> 'entreprise')))
      and (not p_filtres ? 'etablissement_id'  or a.etablissement_id          in (select jsonb_array_elements_text(p_filtres -> 'etablissement_id')))
      and (not p_filtres ? 'section'           or a.section                   in (select jsonb_array_elements_text(p_filtres -> 'section')))
      and (not p_filtres ? 'direction'         or a.direction                 in (select jsonb_array_elements_text(p_filtres -> 'direction')))
      and (not p_filtres ? 'statut_cotisation' or a.statut_cotisation::text   in (select jsonb_array_elements_text(p_filtres -> 'statut_cotisation')))
      and (not p_filtres ? 'recherche'         or (a.nom || ' ' || a.prenom) ilike '%' || (p_filtres ->> 'recherche') || '%')
    order by a.nom, a.prenom
    limit least(greatest(p_limite, 1), 500) offset greatest(p_decalage, 0);
end $$;

create or replace function api.adherent_lire(p_id text) returns adherent
language plpgsql security definer set search_path = public as $$
declare r adherent;
begin
  perform app.exiger('tresorier');
  select * into r from adherent where id = p_id and organisation_id = app.org_id() and supprime_le is null;
  if r.id is null then raise exception 'adhérent introuvable' using errcode = 'P0002'; end if;
  perform app.journaliser('adherent.lire', 'adherent', p_id, null, true);
  return r;
end $$;

-- Création si p.id absent ; sinon mise à jour avec concurrence optimiste (p.version).
create or replace function api.adherent_enregistrer(p jsonb) returns adherent
language plpgsql security definer set search_path = public as $$
declare r adherent;
begin
  perform app.exiger('tresorier');
  if p ->> 'id' is null then
    insert into adherent (id, organisation_id, prenom, nom, email, telephone, emploi, entreprise, etablissement_id,
                          section, direction, date_adhesion, mode_reglement, montant_cotisation, statut_cotisation, consentement_contact)
    values ('adh_' || replace(gen_random_uuid()::text, '-', ''), app.org_id(), p ->> 'prenom', p ->> 'nom', p ->> 'email',
            p ->> 'telephone', p ->> 'emploi', p ->> 'entreprise', p ->> 'etablissement_id', p ->> 'section', p ->> 'direction',
            (p ->> 'date_adhesion')::date, p ->> 'mode_reglement', (p ->> 'montant_cotisation')::numeric,
            coalesce((p ->> 'statut_cotisation')::statut_cotisation, 'a_jour'), coalesce((p ->> 'consentement_contact')::boolean, false))
    returning * into r;
    perform app.journaliser('adherent.creer', 'adherent', r.id, null, true);
  else
    update adherent set
      prenom = coalesce(p ->> 'prenom', prenom), nom = coalesce(p ->> 'nom', nom),
      email = case when p ? 'email' then p ->> 'email' else email end,
      telephone = case when p ? 'telephone' then p ->> 'telephone' else telephone end,
      emploi = coalesce(p ->> 'emploi', emploi), entreprise = coalesce(p ->> 'entreprise', entreprise),
      etablissement_id = coalesce(p ->> 'etablissement_id', etablissement_id),
      section = coalesce(p ->> 'section', section), direction = coalesce(p ->> 'direction', direction),
      date_fin_adhesion = case when p ? 'date_fin_adhesion' then (p ->> 'date_fin_adhesion')::date else date_fin_adhesion end,
      mode_reglement = coalesce(p ->> 'mode_reglement', mode_reglement),
      montant_cotisation = coalesce((p ->> 'montant_cotisation')::numeric, montant_cotisation),
      statut_cotisation = coalesce((p ->> 'statut_cotisation')::statut_cotisation, statut_cotisation),
      consentement_contact = coalesce((p ->> 'consentement_contact')::boolean, consentement_contact),
      version = version + 1, modifie_le = now()
    where id = p ->> 'id' and organisation_id = app.org_id() and version = (p ->> 'version')::int and supprime_le is null
    returning * into r;
    if r.id is null then raise exception 'conflit de version ou adhérent introuvable' using errcode = '40001'; end if;
    perform app.journaliser('adherent.modifier', 'adherent', r.id, null, true);
  end if;
  return r;
end $$;

create or replace function api.adherent_supprimer(p_id text, p_motif text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform app.exiger('tresorier');
  if coalesce(trim(p_motif), '') = '' then raise exception 'motif obligatoire' using errcode = '22023'; end if;
  update adherent set supprime_le = now(), version = version + 1 where id = p_id and organisation_id = app.org_id() and supprime_le is null;
  if not found then raise exception 'adhérent introuvable' using errcode = 'P0002'; end if;
  perform app.journaliser('adherent.supprimer', 'adherent', p_id, p_motif, true);
end $$;

-- Agrégats pour l'administrateur : jamais de nom, et les groupes de moins de 5 sont masqués
-- (une case à 1 ou 2 personnes ré-identifie).
create or replace function api.adherents_agregats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  if not (app.has_role('admin') or app.has_role('tresorier')) then raise exception 'rôle requis' using errcode = '42501'; end if;
  select jsonb_build_object(
    'total', count(*),
    'par_statut', (select jsonb_object_agg(s, case when n < 5 then null else n end)
                   from (select statut_cotisation::text s, count(*) n from adherent
                         where organisation_id = app.org_id() and supprime_le is null group by 1) x),
    'par_etablissement', (select jsonb_object_agg(coalesce(e, 'non renseigné'), case when n < 5 then null else n end)
                          from (select etablissement_id e, count(*) n from adherent
                                where organisation_id = app.org_id() and supprime_le is null group by 1) y))
  into res from adherent where organisation_id = app.org_id() and supprime_le is null;
  return res;
end $$;

-- ---------------------------------------------------------------- sondages
create or replace function api.sondage_valider(p_id text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update sondage set statut = 'valide', validateur_id = app.personne_id(), version = version + 1
  where id = p_id and organisation_id = app.org_id() and statut = 'en_validation' and auteur_id <> app.personne_id();
  if not found then raise exception 'validation impossible (auteur, statut ou sondage introuvable)' using errcode = '42501'; end if;
  perform app.journaliser('sondage.valider', 'sondage', p_id);
end $$;

create or replace function api.sondage_repondre(p_id text, p_valeur jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from sondage where id = p_id and organisation_id = app.org_id() and statut = 'diffuse'
                 and (cloture_le is null or cloture_le > now())) then
    raise exception 'sondage fermé' using errcode = '42501';
  end if;
  insert into sondage_participation (sondage_id, personne_id) values (p_id, app.personne_id());  -- unique : 1 vote
  insert into sondage_reponse (sondage_id, valeur) values (p_id, p_valeur);                      -- sans lien
end $$;

create or replace function api.sondage_resultats(p_id text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('participants', (select count(*) from sondage_participation where sondage_id = p_id),
                            'reponses', coalesce(jsonb_agg(r.valeur), '[]'))
  from sondage_reponse r join sondage s on s.id = r.sondage_id
  where r.sondage_id = p_id and s.organisation_id = app.org_id() and s.statut in ('diffuse', 'clos')
$$;

-- ---------------------------------------------------------------- messagerie
create or replace function api.fil_creer(p_sujet text, p_participants text[]) returns text
language plpgsql security definer set search_path = public as $$
declare f text := 'fil_' || replace(gen_random_uuid()::text, '-', '');
        tous text[] := array(select distinct unnest(p_participants || app.personne_id()));
begin
  if app.personne_id() is null then raise exception 'session invalide' using errcode = '28000'; end if;
  if (select count(*) from personne where id = any(tous) and organisation_id = app.org_id() and desactive_le is null) <> cardinality(tous) then
    raise exception 'participant hors organisation' using errcode = '42501';
  end if;
  insert into fil (id, organisation_id, sujet) values (f, app.org_id(), p_sujet);
  insert into fil_participant (fil_id, personne_id) select f, unnest(tous);
  return f;
end $$;

-- Supervision : appelée par l'Edge Function « sante » (service_role) uniquement.
create or replace function api.retention_a_jour() returns boolean
language sql stable security definer set search_path = public as $$ select app.retention_a_jour() $$;

grant execute on all functions in schema api to authenticated;
revoke execute on function api.retention_a_jour() from authenticated;
grant execute on function api.retention_a_jour() to service_role;
