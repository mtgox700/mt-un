begin;
create or replace function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select uniion_private.case_json_base(o,rid)||uniion_private.case_assignment_context(o,rid)||jsonb_build_object('fileCount',(select count(*) from public.uniion_attachments where organization_id=o and resource_id=rid))
$$;
revoke all on function uniion_private.case_json(uuid,uuid) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
