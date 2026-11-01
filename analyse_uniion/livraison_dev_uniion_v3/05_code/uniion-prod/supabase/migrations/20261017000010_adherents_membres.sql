-- Lot 3 — Adhérents (import serveur), Membres, Réglages.

-- ---------------------------------------------------------------- import CSV d'adhérents
-- Le navigateur lit le fichier et montre un aperçu ; le serveur revalide chaque ligne et décide seul.
-- p_simuler = true : rapport sans écriture (le bouton « Importer » n'apparaît qu'après une simulation).
-- Aucune valeur nominative dans le rapport : numéro de ligne et motif seulement.
create or replace function api.adherents_importer(p_fichier text, p_separateur text, p_lignes jsonb, p_simuler boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  l jsonb; n int := 0; ok int := 0; ko int := 0; doublons int := 0;
  rapport jsonb := '[]'; motifs text[]; v_email text; v_etab text; v_date date; v_montant numeric; vus text[] := '{}';
  imp text := 'imp_' || replace(gen_random_uuid()::text, '-', '');
begin
  perform app.exiger('tresorier');
  if jsonb_typeof(p_lignes) <> 'array' or jsonb_array_length(p_lignes) = 0 then raise exception 'fichier vide' using errcode = '22023'; end if;
  if jsonb_array_length(p_lignes) > 5000 then raise exception '5 000 lignes au plus par import' using errcode = '22023'; end if;

  for l in select * from jsonb_array_elements(p_lignes) loop
    n := n + 1; motifs := '{}';
    v_email := lower(trim(coalesce(l ->> 'email', '')));
    if coalesce(trim(l ->> 'prenom'), '') = '' then motifs := motifs || 'prénom manquant'; end if;
    if coalesce(trim(l ->> 'nom'), '') = '' then motifs := motifs || 'nom manquant'; end if;
    if v_email = '' then motifs := motifs || 'e-mail manquant';
    elsif v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$' then motifs := motifs || 'e-mail invalide'; end if;
    if coalesce(trim(l ->> 'entreprise'), '') = '' then motifs := motifs || 'entreprise manquante'; end if;
    if coalesce(trim(l ->> 'etablissement'), '') = '' then motifs := motifs || 'établissement manquant'; end if;
    v_date := null;
    if coalesce(l ->> 'date_adhesion', '') <> '' then
      begin v_date := to_date(l ->> 'date_adhesion', case when l ->> 'date_adhesion' ~ '^\d{4}-' then 'YYYY-MM-DD' else 'DD/MM/YYYY' end);
      exception when others then motifs := motifs || 'date d''adhésion illisible'; end;
    end if;
    v_montant := null;
    if coalesce(l ->> 'montant', '') <> '' then
      begin v_montant := replace(substring(l ->> 'montant' from '[0-9]+(?:[.,][0-9]{1,2})?'), ',', '.')::numeric;
      exception when others then motifs := motifs || 'montant illisible'; end;
    end if;
    if v_email <> '' and (v_email = any(vus) or exists (select 1 from adherent where organisation_id = app.org_id() and lower(email) = v_email and supprime_le is null)) then
      motifs := motifs || 'déjà présent (même e-mail)'; doublons := doublons + 1;
    end if;

    if cardinality(motifs) > 0 then
      ko := ko + 1; rapport := rapport || jsonb_build_object('ligne', n, 'motifs', to_jsonb(motifs));
      continue;
    end if;
    ok := ok + 1; vus := vus || v_email;
    if p_simuler then continue; end if;

    insert into etablissement (id, organisation_id, libelle)
    values ('etb_' || replace(gen_random_uuid()::text, '-', ''), app.org_id(), trim(l ->> 'etablissement'))
    on conflict (organisation_id, libelle) do nothing;
    select id into v_etab from etablissement where organisation_id = app.org_id() and libelle = trim(l ->> 'etablissement');

    insert into adherent (id, organisation_id, prenom, nom, email, telephone, emploi, entreprise, etablissement_id, section, direction,
                          date_adhesion, mode_reglement, montant_cotisation, consentement_contact)
    values ('adh_' || replace(gen_random_uuid()::text, '-', ''), app.org_id(), trim(l ->> 'prenom'), trim(l ->> 'nom'), v_email,
            nullif(trim(l ->> 'telephone'), ''), nullif(trim(l ->> 'emploi'), ''), trim(l ->> 'entreprise'), v_etab,
            nullif(trim(l ->> 'section'), ''), nullif(trim(l ->> 'direction'), ''), v_date, nullif(trim(l ->> 'mode_reglement'), ''), v_montant,
            -- Le consentement ne se présume pas : seul « oui » explicite l'active.
            lower(trim(coalesce(l ->> 'consentement', ''))) in ('oui', 'o', 'yes', '1', 'true'));
  end loop;

  if not p_simuler then
    insert into import_adherents (id, organisation_id, fichier_nom, separateur, lignes_total, lignes_valides, lignes_rejetees, rapport, lance_par)
    values (imp, app.org_id(), left(p_fichier, 180), p_separateur, n, ok, ko, rapport, app.personne_id());
    perform app.journaliser('adherents.importer', 'import_adherents', imp, format('%s importés, %s rejetés', ok, ko), true);
  end if;
  return jsonb_build_object('id', case when p_simuler then null else imp end, 'total', n, 'valides', ok, 'rejetees', ko, 'doublons', doublons, 'rapport', rapport);
end $$;

-- ---------------------------------------------------------------- membres (administrateur + double authentification)
create or replace function api.membres_lister() returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
begin
  perform app.exiger('admin');
  return jsonb_build_object(
    'sieges', (select sieges_souscrits from organisation where id = app.org_id()),
    'membres', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'prenom', p.prenom, 'nom', p.nom, 'email', p.email, 'mandat', p.mandat, 'mandat_fin', p.mandat_fin, 'bureau', p.bureau,
        'roles', (select coalesce(jsonb_agg(r.role order by r.role), '[]') from personne_role r where r.personne_id = p.id),
        'double_auth', exists (select 1 from auth.mfa_factors f where f.user_id = p.auth_user_id and f.status = 'verified'),
        'invitation_acceptee', exists (select 1 from auth.users u where u.id = p.auth_user_id and u.last_sign_in_at is not null))
      order by p.nom, p.prenom) from personne p where p.organisation_id = app.org_id() and p.desactive_le is null), '[]'));
end $$;

-- ---------------------------------------------------------------- réglages : mon profil
create or replace function api.mon_profil() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('prenom', prenom, 'nom', nom, 'email', email, 'telephone', telephone, 'mandat', mandat,
                            'mandat_fin', mandat_fin, 'coord_visibles', coord_visibles, 'version', version)
  from personne where id = app.personne_id()
$$;

grant execute on function api.adherents_importer(text, text, jsonb, boolean), api.membres_lister(), api.mon_profil() to authenticated;
