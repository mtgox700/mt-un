-- Correctif : les politiques evenement ↔ evenement_participant se référençaient mutuellement
-- (« infinite recursion detected in policy » à la première lecture de l'agenda).
-- Les contrôles passent par des fonctions security definer, qui ne déclenchent pas la RLS.

create or replace function app.invite_evt(e text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from evenement_participant where evenement_id = e and personne_id = app.personne_id())
$$;
create or replace function app.evt_visible(e text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from evenement x where x.id = e and x.organisation_id = app.org_id()
                 and (x.visibilite = 'section' or x.createur_id = app.personne_id() or app.invite_evt(x.id)
                      or (x.visibilite = 'bureau' and app.bureau())))
$$;
create or replace function app.createur_evt(e text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from evenement where id = e and createur_id = app.personne_id())
$$;

drop policy evenement_lecture on evenement;
create policy evenement_lecture on evenement for select to authenticated
  using (visibilite = 'section' or createur_id = (select app.personne_id()) or app.invite_evt(id)
         or (visibilite = 'bureau' and (select app.bureau())));

drop policy participant_lecture on evenement_participant;
drop policy participant_gestion on evenement_participant;
drop policy rappel_gestion on evenement_rappel;
create policy participant_lecture on evenement_participant for select to authenticated using (app.evt_visible(evenement_id));
create policy participant_ajout on evenement_participant for insert to authenticated with check (app.createur_evt(evenement_id));
create policy participant_retrait on evenement_participant for delete to authenticated using (app.createur_evt(evenement_id));
create policy rappel_gestion on evenement_rappel for all to authenticated using (app.createur_evt(evenement_id)) with check (app.createur_evt(evenement_id));
-- participant_reponse (update de sa propre réponse) est conservée.
