-- uniion — migration 2/7 : rattachement à Supabase Auth, compléments v3/v4, journal chaîné

-- Supabase Auth gère les sessions : la table du schéma d'origine n'a plus d'objet.
drop table if exists session;

-- Une personne = un mandat dans une organisation. Un même compte Auth peut porter
-- plusieurs personnes (élu dans deux organisations) : l'organisation active est dans le jeton.
alter table personne
  add column auth_user_id uuid references auth.users on delete set null,
  add column bureau       boolean not null default false;
create unique index personne_auth_org on personne (auth_user_id, organisation_id) where auth_user_id is not null;

alter table reunion add column cree_par text references personne;

-- MVP : chiffrement serveur au repos (AES-256-GCM, clé d'organisation hors base, Edge Function « coffre »).
-- Le bout en bout (clés par appareil) est reporté au lot 6 : la colonne reste prête.
alter table message alter column cles_destinataires drop not null;
comment on table message is
  'MVP : charge chiffrée par le serveur, clé hors base. Libellé interface : « chiffré en transit et au repos ». E2E : lot 6.';

alter type surface_ia add value if not exists 'messagerie';
alter type surface_ia add value if not exists 'dossier_guide';
alter type surface_ia add value if not exists 'formation';
alter type surface_ia add value if not exists 'communication';

-- Vote unique sans lien avec la réponse : la participation et la réponse sont dans deux tables
-- sans clé commune, insérées par la même fonction (api.sondage_repondre).
create table sondage_participation (
  sondage_id  text not null references sondage on delete cascade,
  personne_id text not null references personne on delete cascade,
  primary key (sondage_id, personne_id)
);

-- ---------------------------------------------------------------- extensions (uniion Studio)
-- Registre tenu par l'éditeur. Le front ne charge qu'un fichier servi par uniion, vérifié par SRI.
create table extension (
  id             text not null,                     -- 'uniion-studio'
  version        text not null,                     -- '1.2.0'
  nom            text not null,
  editeur        text not null default 'uniion',
  api            integer not null,                  -- EXT_API attendu par le front
  fichier        text not null check (fichier ~ '^/ext/[a-z0-9.-]+\.js$'),
  integrite_sri  text not null check (integrite_sri ~ '^sha384-'),
  signature      text not null,                     -- Ed25519 de l'éditeur sur integrite_sri
  publiee_le     timestamptz not null default now(),
  retiree_le     timestamptz,
  primary key (id, version)
);

create table extension_activation (
  organisation_id     text not null references organisation on delete cascade,
  extension_id        text not null,
  version             text not null,
  elements_desactives text[] not null default '{}', -- styles, blocs, thèmes coupés un à un
  active_par          text not null references personne,
  active_le           timestamptz not null default now(),
  primary key (organisation_id, extension_id),
  foreign key (extension_id, version) references extension (id, version)
);

-- ---------------------------------------------------------------- médias (photos des documents et pages)
create table media (
  id                     text primary key default 'med_' || replace(gen_random_uuid()::text, '-', ''),
  organisation_id        text not null references organisation on delete cascade,
  chemin                 text not null unique,     -- bucket « media » : {organisation_id}/{personne_id}/{uuid}.webp
  type_mime              text not null check (type_mime in ('image/jpeg', 'image/png', 'image/webp')),
  taille_octets          integer not null check (taille_octets <= 5 * 1024 * 1024),
  largeur                integer,
  hauteur                integer,
  personne_identifiable  boolean not null default false,
  consentement_image     boolean,                  -- obligatoire si personne_identifiable
  document_id            text references document on delete cascade,
  page_id                text references page on delete cascade,
  depose_par             text not null references personne,
  cree_le                timestamptz not null default now(),
  supprime_le            timestamptz,
  check (not personne_identifiable or consentement_image is true)
);
create index on media (organisation_id, cree_le desc) where supprime_le is null;

-- ---------------------------------------------------------------- journal d'audit chaîné
create schema if not exists app;

create or replace function app.audit_chainer() returns trigger
language plpgsql set search_path = public, extensions as $$
declare prec text;
begin
  perform pg_advisory_xact_lock(hashtext('audit:' || new.organisation_id));
  select empreinte into prec from audit where organisation_id = new.organisation_id order by id desc limit 1;
  new.horodatage     := coalesce(new.horodatage, now());
  new.empreinte_prec := prec;
  new.empreinte := encode(digest(concat_ws('|', coalesce(prec, 'ORIGINE'), new.organisation_id,
    coalesce(new.acteur_id, ''), new.action, new.ressource_type, coalesce(new.ressource_id, ''),
    coalesce(new.motif, ''), new.article_9::text, new.horodatage::text), 'sha256'), 'hex');
  return new;
end $$;
alter table audit alter column empreinte drop not null;
create trigger audit_chainer before insert on audit for each row execute function app.audit_chainer();
alter table audit add constraint audit_empreinte_posee check (empreinte is not null) not valid;
