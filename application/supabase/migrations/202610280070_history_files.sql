begin;
create function public.uniion_convocation_files(p_org uuid,p_convocation uuid,p_file text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare c uniion_private.agenda_convocations;e uniion_private.agenda_events;p uniion_private.agenda_publications;items jsonb='[]';a public.uniion_attachments;ref jsonb;
begin
if not exists(select 1 from jsonb_array_elements(public.uniion_convocation_history(p_org)) h where h->>'id'=p_convocation::text) then raise insufficient_privilege;end if;
perform public.uniion_module_use(p_org,'documents');
if not uniion_private.authority(p_org,auth.uid(),'download') then raise insufficient_privilege;end if;
select * into c from uniion_private.agenda_convocations where id=p_convocation;
select * into e from uniion_private.agenda_events where id=c.event_id;
if not(c.message ? 'attachment_version') then return '[]'::jsonb;end if;
select * into p from uniion_private.agenda_publications where event_id=c.event_id and version=(c.message->>'attachment_version')::integer and published_at is not null;
if not found then raise insufficient_privilege;end if;
perform uniion_private.agenda_file_check(p_org,coalesce(p.document->'convocation_files','[]'),auth.uid());
items=jsonb_build_array(jsonb_build_object('id','pdf','name','ordre-du-jour.pdf'));
if e.version=c.event_version then items=items||jsonb_build_array(jsonb_build_object('id','ics','name','evenement.ics'));end if;
for ref in select value from jsonb_array_elements(coalesce(p.document->'convocation_files','[]')) loop
 select * into a from public.uniion_attachments where id=(ref->>'id')::uuid;
 items=items||jsonb_build_array(jsonb_build_object('id',a.id,'name',a.filename));
end loop;
if p_file is null then return items;end if;
if not exists(select 1 from jsonb_array_elements(items) i where i->>'id'=p_file) then raise insufficient_privilege;end if;
return jsonb_build_object('document',p.document,'version',p.version,'event',e.data||jsonb_build_object('id',e.id,'version',e.version));
end $$;
revoke all on function public.uniion_convocation_files(uuid,uuid,text) from public,anon;
grant execute on function public.uniion_convocation_files(uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
