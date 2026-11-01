begin;
-- Metadata receipts for the caller's own saved drafts. No business contents.
create function public.uniion_audio_local_receipts(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.uniion_module_use(p_org,'reunions');
 return jsonb_build_object('receipts',coalesce((select jsonb_agg(jsonb_build_object('audio',a.id,'request',a.request_id,'meeting',a.meeting_id)) from uniion_private.meeting_audio a where a.organization_id=p_org and a.actor=auth.uid() and
 (exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=a.id) or (a.status='clean' and exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.path) and not exists(select 1 from uniion_private.meeting_audio_originals o where o.audio_id=a.id and o.status<>'clean')))),'[]'));
end$$;
revoke all on function public.uniion_audio_local_receipts(uuid) from public,anon;
grant execute on function public.uniion_audio_local_receipts(uuid) to authenticated;
notify pgrst,'reload schema';commit;
