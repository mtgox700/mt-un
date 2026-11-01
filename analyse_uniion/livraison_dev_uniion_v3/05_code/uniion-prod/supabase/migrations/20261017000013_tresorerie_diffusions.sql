-- Lot 3 — Trésorerie (cotisations, attestations fiscales) et diffusions aux adhérents.
-- Tout passe par des fonctions : trésorier + double authentification, chaque lecture nominative journalisée.

-- ---------------------------------------------------------------- cotisations
alter table cotisation alter column id set default 'cot_' || replace(gen_random_uuid()::text, '-', '');

create or replace function api.cotisations_lister(p_adherent text) returns setof cotisation
language plpgsql security definer set search_path = public as $$
begin
  perform app.exiger('tresorier');
  if not exists (select 1 from adherent where id = p_adherent and organisation_id = app.org_id()) then
    raise exception 'adhérent introuvable' using errcode = 'P0002';
  end if;
  perform app.journaliser('cotisations.lister', 'adherent', p_adherent, null, true);
  return query select * from cotisation where adherent_id = p_adherent order by periode desc;
end $$;

-- Saisie ou correction d'un versement (une ligne par période).
create or replace function api.cotisation_enregistrer(p jsonb) returns cotisation
language plpgsql security definer set search_path = public as $$
declare r cotisation;
begin
  perform app.exiger('tresorier');
  if not exists (select 1 from adherent where id = p ->> 'adherent_id' and organisation_id = app.org_id() and supprime_le is null) then
    raise exception 'adhérent introuvable' using errcode = 'P0002';
  end if;
  if coalesce(p ->> 'periode', '') !~ '^\d{4}(-(T[1-4]|\d{2}))?$' then raise exception 'période attendue : 2026, 2026-T3 ou 2026-09' using errcode = '22023'; end if;
  if coalesce((p ->> 'montant')::numeric, 0) <= 0 then raise exception 'montant invalide' using errcode = '22023'; end if;
  insert into cotisation (adherent_id, periode, montant, mode, encaisse_le, piece_justificative, saisi_par)
  values (p ->> 'adherent_id', p ->> 'periode', (p ->> 'montant')::numeric, p ->> 'mode', (p ->> 'encaisse_le')::date, p ->> 'piece_justificative', app.personne_id())
  on conflict (adherent_id, periode) do update set montant = excluded.montant, mode = excluded.mode, encaisse_le = excluded.encaisse_le,
    piece_justificative = excluded.piece_justificative, saisi_par = excluded.saisi_par
  returning * into r;
  perform app.journaliser('cotisation.enregistrer', 'adherent', r.adherent_id, r.periode || ' : ' || r.montant || ' €', true);
  return r;
end $$;

create or replace function api.cotisation_supprimer(p_id text, p_motif text) returns void
language plpgsql security definer set search_path = public as $$
declare a text;
begin
  perform app.exiger('tresorier');
  if coalesce(trim(p_motif), '') = '' then raise exception 'motif obligatoire' using errcode = '22023'; end if;
  delete from cotisation c using adherent ad where c.id = p_id and ad.id = c.adherent_id and ad.organisation_id = app.org_id() returning c.adherent_id into a;
  if a is null then raise exception 'versement introuvable' using errcode = 'P0002'; end if;
  perform app.journaliser('cotisation.supprimer', 'adherent', a, p_motif, true);
end $$;

-- Synthèse de l'année : montants et effectifs, aucun nom.
create or replace function api.tresorerie_synthese(p_annee int) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform app.exiger('tresorier');
  return jsonb_build_object(
    'encaisse', (select coalesce(sum(c.montant), 0) from cotisation c join adherent a on a.id = c.adherent_id
                 where a.organisation_id = app.org_id() and extract(year from c.encaisse_le) = p_annee),
    'cotisants', (select count(distinct c.adherent_id) from cotisation c join adherent a on a.id = c.adherent_id
                  where a.organisation_id = app.org_id() and extract(year from c.encaisse_le) = p_annee),
    'en_retard', (select count(*) from adherent where organisation_id = app.org_id() and supprime_le is null and statut_cotisation = 'en_retard'),
    'attestations', (select count(*) from attestation_fiscale f join adherent a on a.id = f.adherent_id where a.organisation_id = app.org_id() and f.annee = p_annee));
end $$;

-- ---------------------------------------------------------------- attestations fiscales (art. 199 quater C du CGI)
-- Montant = versements encaissés pendant l'année civile. Régénérable : la dernière émission fait foi.
create or replace function api.attestations_generer(p_annee int) returns integer
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform app.exiger('tresorier');
  if p_annee >= extract(year from current_date) then raise exception 'l''année doit être close' using errcode = '22023'; end if;
  insert into attestation_fiscale (id, adherent_id, annee, montant_total, emise_le)
  select 'att_' || replace(gen_random_uuid()::text, '-', ''), c.adherent_id, p_annee, sum(c.montant), current_date
  from cotisation c join adherent a on a.id = c.adherent_id
  where a.organisation_id = app.org_id() and extract(year from c.encaisse_le) = p_annee
  group by c.adherent_id
  on conflict (adherent_id, annee) do update set montant_total = excluded.montant_total, emise_le = excluded.emise_le;
  get diagnostics n = row_count;
  perform app.journaliser('attestations.generer', 'organisation', app.org_id(), p_annee || ' : ' || n || ' attestation(s)', true);
  return n;
end $$;

create or replace function api.attestation_lire(p_adherent text, p_annee int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  perform app.exiger('tresorier');
  select jsonb_build_object('prenom', a.prenom, 'nom', a.nom, 'annee', f.annee, 'montant', f.montant_total, 'emise_le', f.emise_le,
                            'organisation', o.nom, 'sigle', o.sigle, 'adresse', o.adresse)
  into r from attestation_fiscale f join adherent a on a.id = f.adherent_id join organisation o on o.id = a.organisation_id
  where f.adherent_id = p_adherent and f.annee = p_annee and a.organisation_id = app.org_id();
  if r is null then raise exception 'aucune attestation pour cette année' using errcode = 'P0002'; end if;
  perform app.journaliser('attestation.lire', 'adherent', p_adherent, p_annee::text, true);
  return r;
end $$;

-- ---------------------------------------------------------------- diffusions
alter table liste_diffusion alter column id set default 'lst_' || replace(gen_random_uuid()::text, '-', '');
alter table liste_diffusion alter column organisation_id set default app.org_id();
alter table campagne alter column id set default 'cmp_' || replace(gen_random_uuid()::text, '-', '');
alter table campagne alter column organisation_id set default app.org_id();
alter table campagne alter column creee_par set default app.personne_id();

-- Effectif joignable d'une liste (consentement, non désinscrit). Sous 5, l'effectif n'est pas affiché.
create or replace function api.liste_effectif(p_liste text) returns integer
language plpgsql stable security definer set search_path = public as $$
declare l liste_diffusion; n int;
begin
  if not (app.has_role('tresorier') or app.has_role('admin') or app.has_role('communication')) then raise exception 'rôle requis' using errcode = '42501'; end if;
  select * into l from liste_diffusion where id = p_liste and organisation_id = app.org_id() and supprime_le is null;
  if l.id is null then raise exception 'liste introuvable' using errcode = 'P0002'; end if;
  select count(*) into n from adherent a
  where a.organisation_id = app.org_id() and a.supprime_le is null and a.consentement_contact and a.email is not null
    and ((l.type = 'fixe' and exists (select 1 from liste_membre_fixe m where m.liste_id = l.id and m.adherent_id = a.id))
      or (l.type = 'dyn'
        and (not l.criteres ? 'etablissement_id'  or a.etablissement_id        in (select jsonb_array_elements_text(l.criteres -> 'etablissement_id')))
        and (not l.criteres ? 'section'           or a.section                 in (select jsonb_array_elements_text(l.criteres -> 'section')))
        and (not l.criteres ? 'direction'         or a.direction               in (select jsonb_array_elements_text(l.criteres -> 'direction')))
        and (not l.criteres ? 'entreprise'        or a.entreprise              in (select jsonb_array_elements_text(l.criteres -> 'entreprise')))
        and (not l.criteres ? 'statut_cotisation' or a.statut_cotisation::text in (select jsonb_array_elements_text(l.criteres -> 'statut_cotisation')))))
    and not exists (select 1 from desinscription d where d.organisation_id = a.organisation_id and d.canal = l.canal
                    and d.email_empreinte = app.empreinte_email(a.organisation_id, a.email));
  return case when n < 5 and not app.has_role('tresorier') then null else n end;
end $$;

-- Valeurs proposées pour les critères (sections, directions) : libellés seuls, sans effectif.
create or replace function api.criteres_disponibles() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (app.has_role('tresorier') or app.has_role('admin') or app.has_role('communication')) then raise exception 'rôle requis' using errcode = '42501'; end if;
  return jsonb_build_object(
    'section', (select coalesce(jsonb_agg(distinct section order by section), '[]') from adherent where organisation_id = app.org_id() and section is not null and supprime_le is null),
    'direction', (select coalesce(jsonb_agg(distinct direction order by direction), '[]') from adherent where organisation_id = app.org_id() and direction is not null and supprime_le is null));
end $$;

grant execute on function api.cotisations_lister(text), api.cotisation_enregistrer(jsonb), api.cotisation_supprimer(text, text),
  api.tresorerie_synthese(int), api.attestations_generer(int), api.attestation_lire(text, int),
  api.liste_effectif(text), api.criteres_disponibles() to authenticated;
