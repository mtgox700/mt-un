-- uniion — migration 6/7 : stockage de fichiers
-- Arborescence imposée : {organisation_id}/{personne_id}/{fichier}. Tous les buckets sont privés.
--   media   : photos des documents et pages (dépôt direct par le client, ≤ 5 Mo, images seulement)
--   pieces  : pièces de dossier — AUCUNE politique client : dépôt, antivirus, journal d'accès et
--             URL signées de 60 s par l'Edge Function « pieces ».
--   exports : PDF, CSV, ICS produits par le serveur, lisibles par leur seul demandeur.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('media',   'media',   false, 5242880,  array['image/jpeg', 'image/png', 'image/webp']),
  ('pieces',  'pieces',  false, 83886080, null),
  ('exports', 'exports', false, 52428800, array['application/pdf', 'text/csv', 'text/calendar'])
on conflict (id) do nothing;

create policy media_lecture on storage.objects for select to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select app.org_id()));
create policy media_depot on storage.objects for insert to authenticated
  with check (bucket_id = 'media'
              and (storage.foldername(name))[1] = (select app.org_id())
              and (storage.foldername(name))[2] = (select app.personne_id()));
create policy media_suppression on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select app.org_id())
         and ((storage.foldername(name))[2] = (select app.personne_id()) or (select app.has_role('admin'))));

create policy exports_lecture on storage.objects for select to authenticated
  using (bucket_id = 'exports'
         and (storage.foldername(name))[1] = (select app.org_id())
         and (storage.foldername(name))[2] = (select app.personne_id()));
