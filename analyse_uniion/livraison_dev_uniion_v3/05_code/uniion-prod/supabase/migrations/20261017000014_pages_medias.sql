-- Correctifs relevés en écrivant les tests du lot 3 (pages, médias).
-- 1. Pages : la politique de modification n'avait pas de « with check » ni de contrôle d'état :
--    l'auteur pouvait passer sa propre page en « publiee » sans relecture.
-- 2. Médias : le chemin n'était pas lié à l'organisation. Une ligne pointant vers le fichier
--    d'une autre organisation, mise à la corbeille, aurait fait purger ce fichier à 30 jours.

-- ---------------------------------------------------------------- pages : circuit de relecture
create or replace function app.page_controle() returns trigger
language plpgsql set search_path = public as $$
declare moi text := app.personne_id();
        comm boolean := app.has_role('communication') or app.has_role('admin');
begin
  if current_user <> 'authenticated' then return new; end if;  -- serveur (assainissement, rétention)

  if new.auteur_id <> old.auteur_id then raise exception 'auteur non modifiable' using errcode = '42501'; end if;
  if (new.relecture_note, new.relecture_le) is distinct from (old.relecture_note, old.relecture_le)
     and moi is distinct from new.relecteur_id then
    raise exception 'seul le relecteur annote la relecture' using errcode = '42501';
  end if;

  -- Contenu modifié après relecture : retour en brouillon, relecture à refaire
  if (new.titre, new.chapo, new.blocs, new.slug) is distinct from (old.titre, old.chapo, old.blocs, old.slug)
     and old.statut <> 'brouillon' and new.statut = old.statut then
    new.statut := 'brouillon'; new.relecture_le := null;
  end if;

  if new.statut is distinct from old.statut then
    case new.statut
      when 'brouillon' then
        if moi <> new.auteur_id and not comm then raise exception 'retour en brouillon : auteur' using errcode = '42501'; end if;
      when 'relue', 'retournee' then
        if new.relecteur_id is null or moi is distinct from new.relecteur_id or moi = new.auteur_id then
          raise exception 'la relecture revient au relecteur désigné, distinct de l''auteur' using errcode = '42501';
        end if;
        new.relecture_le := now();
      when 'en_attente_webmaster', 'publiee' then
        if not comm then raise exception 'publication : rôle communication ou administrateur' using errcode = '42501'; end if;
        if old.statut not in ('relue', 'en_attente_webmaster') then
          raise exception 'page non relue' using errcode = '42501';
        end if;
    end case;
  end if;

  new.version := old.version + 1;
  new.modifie_le := now();
  return new;
end $$;
create trigger page_controle before update on page for each row execute function app.page_controle();

-- ---------------------------------------------------------------- sonde de santé
-- La sonde appelait api.retention_a_jour, qui n'existait pas (seul app.retention_a_jour) : elle aurait
-- répondu 503 en permanence.
create or replace function api.retention_a_jour() returns boolean
language sql stable security definer set search_path = public as $$ select app.retention_a_jour() $$;
revoke all on function api.retention_a_jour() from public, anon, authenticated;
grant execute on function api.retention_a_jour() to service_role;

-- ---------------------------------------------------------------- médias : chemin lié au déposant
alter table media add constraint media_chemin_proprietaire
  check (split_part(chemin, '/', 1) = organisation_id and split_part(chemin, '/', 2) = depose_par);
alter table media alter column organisation_id set default app.org_id();
alter table media alter column depose_par set default app.personne_id();

-- Seuls la corbeille et le rattachement se modifient ; jamais le chemin ni le consentement.
revoke update on media from authenticated;
grant update (supprime_le, document_id, page_id) on media to authenticated;
drop policy if exists media_retrait on media;
create policy media_retrait on media for update to authenticated
  using (depose_par = (select app.personne_id()) or (select app.has_role('admin')))
  with check (depose_par = (select app.personne_id()) or (select app.has_role('admin')));
