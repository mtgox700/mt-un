begin;
create or replace function uniion_private.ai_refs_readable(o uuid,refs jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare ref jsonb;kind text;rid uuid;
begin
 if jsonb_typeof(refs)<>'array' or jsonb_array_length(refs) not between 1 and 8 then return false;end if;
 for ref in select value from jsonb_array_elements(refs) loop
  kind=ref->>'kind';rid=(ref->>'id')::uuid;
  if kind in ('agenda','adherents','workspace') then
   perform public.uniion_ai_native(o,kind,rid);
  elsif kind='message' then
   perform public.uniion_module_use(o,'messagerie');
   if not uniion_private.message_visible(o,rid,(ref->>'seq')::bigint) or not exists(select 1 from uniion_private.messages where organization_id=o and conversation=rid and seq=(ref->>'seq')::bigint) then return false;end if;
  else
   -- Pure ACL check: PostgREST table reads run in a read-only transaction.
   if kind not in ('case','document','reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis') then return false;end if;
   if not exists(select 1 from public.uniion_resources where organization_id=o and id=rid and module=case kind when 'case' then 'dossiers' when 'document' then 'documents' else kind end) or not uniion_private.actor_resource(o,rid,auth.uid(),false) then return false;end if;
   -- Classified sources have their own cumulative restrictions; do not flatten them.
   if kind='case' and exists(select 1 from uniion_private.case_links where organization_id=o and resource_id=rid) then return false;end if;
  end if;
 end loop;
 return true;
exception when insufficient_privilege or invalid_text_representation then return false;
end$$;
notify pgrst,'reload schema';commit;
