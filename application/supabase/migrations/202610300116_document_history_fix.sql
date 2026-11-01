begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_document_history(uuid,uuid,integer)'::regprocedure);
 d=replace(d,'declare a uniion_private.document_archives','declare stored uniion_private.document_archives');
 d=replace(d,'into a from','into stored from');d=replace(d,'encode(a.pdf','encode(stored.pdf');d=replace(d,$s$'sha256',a.digest$s$,$s$'sha256',stored.digest$s$);execute d;
end$$;
alter function uniion_private.document_json(uuid,uuid) rename to document_json_before_corrections;
create function uniion_private.document_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
 select uniion_private.document_json_before_corrections(o,rid)||case when exists(select 1 from uniion_private.document_corrections c join public.uniion_resources r on r.id=c.resource_id and r.version=c.version where c.organization_id=o and c.resource_id=rid) then jsonb_build_object('status','À corriger') else '{}'::jsonb end
$$;
revoke all on function uniion_private.document_json_before_corrections(uuid,uuid),uniion_private.document_json(uuid,uuid) from public,anon,authenticated;
notify pgrst,'reload schema';commit;
