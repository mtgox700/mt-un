-- uniion — migration 3/7 : identité applicative et hook de jeton
-- Le jeton porte org_id et personne_id ; les fonctions ci-dessous les REVALIDENT en base à chaque
-- requête : un compte désactivé ou un rôle retiré perd l'accès immédiatement, sans attendre
-- l'expiration du jeton (15 min).

create or replace function app.personne_id() returns text
language sql stable security definer set search_path = public as $$
  select p.id from personne p
  where p.id = auth.jwt() ->> 'personne_id'
    and p.organisation_id = auth.jwt() ->> 'org_id'
    and p.auth_user_id = auth.uid()
    and p.desactive_le is null
$$;

create or replace function app.org_id() returns text
language sql stable security definer set search_path = public as $$
  select p.organisation_id from personne p where p.id = app.personne_id()
$$;

create or replace function app.has_role(r role_membre) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from personne_role where personne_id = app.personne_id() and role = r)
$$;

create or replace function app.bureau() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select bureau from personne where id = app.personne_id()), false)
$$;

create or replace function app.aal2() returns boolean
language sql stable as $$ select coalesce(auth.jwt() ->> 'aal', '') = 'aal2' $$;

create or replace function app.role_principal() returns role_membre
language sql stable security definer set search_path = public as $$
  select role from personne_role where personne_id = app.personne_id()
  order by array_position(array['admin','tresorier','communication','militant']::role_membre[], role) limit 1
$$;

create or replace function app.exiger(r role_membre, mfa boolean default true) returns void
language plpgsql stable as $$
begin
  if app.personne_id() is null then raise exception 'session invalide' using errcode = '28000'; end if;
  if not app.has_role(r) then raise exception 'rôle % requis', r using errcode = '42501'; end if;
  if mfa and not app.aal2() then raise exception 'double authentification requise' using errcode = '42501'; end if;
end $$;

create or replace function app.journaliser(p_action text, p_type text, p_id text,
  p_motif text default null, p_art9 boolean default false) returns void
language sql security definer set search_path = public as $$
  insert into audit (organisation_id, acteur_id, acteur_role, action, ressource_type, ressource_id, motif, article_9)
  values (app.org_id(), app.personne_id(), app.role_principal(), p_action, p_type, p_id, p_motif, p_art9)
$$;

-- Hook « Custom Access Token » de Supabase Auth (GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_*).
create or replace function app.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid    uuid  := (event ->> 'user_id')::uuid;
  claims jsonb := event -> 'claims';
  voulue text;
  p      record;
begin
  select raw_app_meta_data ->> 'org_active' into voulue from auth.users where id = uid;
  select pe.id, pe.organisation_id into p
  from personne pe
  where pe.auth_user_id = uid and pe.desactive_le is null
  order by (pe.organisation_id = voulue) desc nulls last, pe.cree_le
  limit 1;
  if p.id is null then
    claims := claims - 'org_id' - 'personne_id';
  else
    claims := claims || jsonb_build_object('org_id', p.organisation_id, 'personne_id', p.id);
  end if;
  return jsonb_set(event, '{claims}', claims);
end $$;

grant usage on schema app to supabase_auth_admin, authenticated, service_role;
grant execute on function app.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function app.custom_access_token_hook(jsonb) from authenticated, anon, public;
grant execute on function app.personne_id(), app.org_id(), app.has_role(role_membre), app.bureau(),
  app.aal2(), app.role_principal() to authenticated, service_role;
revoke execute on function app.journaliser(text, text, text, text, boolean), app.exiger(role_membre, boolean) from public, anon;
grant execute on function app.journaliser(text, text, text, text, boolean), app.exiger(role_membre, boolean) to authenticated, service_role;
