begin;
-- R20 : le compte scanner (lecture de tout le bucket, scans, archives, suppression d'audio
-- approuvée) était reconnu sur sa seule identité, sans contrôle de session. Comme
-- transcription_storage() pour le worker de transcription, il faut désormais une session
-- Supabase active et non expirée. plpgsql (plans mis en cache, cf. R18) ; même signature,
-- même OID : politiques et fonctions appelantes inchangées.
create or replace function uniion_private.is_scanner() returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 return uniion_private.session_allowed() and exists(select 1 from uniion_private.scan_workers where user_id=auth.uid());
end$$;
revoke all on function uniion_private.is_scanner() from public,anon;
notify pgrst,'reload schema';
commit;
