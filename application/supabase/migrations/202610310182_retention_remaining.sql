begin;
alter function public.uniion_audio_retention(uuid,uuid,text,jsonb) rename to uniion_audio_retention_before_remaining;
create function public.uniion_audio_retention(p_org uuid,p_meeting uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result=public.uniion_audio_retention_before_remaining(p_org,p_meeting,p_action,p_payload);
 if p_action='status' then
  result=result||jsonb_build_object('remaining',(select count(*) from uniion_private.meeting_audio a where a.organization_id=p_org and a.meeting_id=p_meeting and not exists(select 1 from uniion_private.audio_tombstones t where t.audio_id=a.id)));
 end if;
 return result;
end$$;
revoke all on function public.uniion_audio_retention_before_remaining(uuid,uuid,text,jsonb),public.uniion_audio_retention(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.uniion_audio_retention(uuid,uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
