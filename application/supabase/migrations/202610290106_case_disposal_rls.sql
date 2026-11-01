begin;
-- Policies keep function OIDs across a rename: explicitly bind to the disposal gate.
alter policy granted_resources on public.uniion_resources using (uniion_private.resource_access(organization_id,id,false));
alter policy readable_versions on public.uniion_resource_versions using (uniion_private.resource_access(organization_id,resource_id,false));
notify pgrst,'reload schema';
commit;
