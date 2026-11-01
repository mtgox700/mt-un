begin;
create function uniion_private.agenda_document_charter() returns trigger language plpgsql security definer set search_path='' as $$
declare org uuid;name text;detail jsonb;
begin
 select organization_id into org from uniion_private.agenda_events where id=new.event_id;
 select o.name,coalesce(d.details,'{}'::jsonb) into name,detail from public.uniion_organizations o left join uniion_private.organization_details d on d.organization_id=o.id where o.id=org;
 new.document=new.document||jsonb_build_object('charte',jsonb_build_object('accent','#DC2626','ink','#111827','titleFont','philosopher','bodyFont','inter','density','standard','logo','uniion-logo.png','header',true,'footer',true,'caps',false,'emetteur',coalesce(nullif(detail->>'sigle',''),name),'section',coalesce(nullif(split_part(detail->>'adresse',',',1),''),name),'email',coalesce(detail->>'email',''),'phone','03 27 14 88 20','emetteurOverride',true));
 return new;
end;$$;
create trigger agenda_document_charter_insert before insert on uniion_private.agenda_documents for each row execute function uniion_private.agenda_document_charter();
revoke all on function uniion_private.agenda_document_charter() from public,anon,authenticated;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_work(uuid,uuid,text,jsonb)'::regprocedure);
 definition=replace(definition,$old$doc-array['title','format','blocks']$old$,$new$doc-array['title','format','blocks','charte']$new$);
 definition=replace(definition,$old$for item in select value from jsonb_array_elements(doc->'blocks') loop$old$,$new$
 if doc ? 'charte' then
  item=doc->'charte';
  if jsonb_typeof(item) is distinct from 'object' or not(item ?& array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']) or item-array['accent','ink','titleFont','bodyFont','density','logo','header','footer','caps','emetteur','section','email','phone','emetteurOverride']<>'{}'::jsonb then raise insufficient_privilege;end if;
  if (item->>'accent') !~ '^#[0-9a-fA-F]{6}$' or (item->>'ink') !~ '^#[0-9a-fA-F]{6}$' or item->>'titleFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'bodyFont' not in ('philosopher','inter','montserrat','lora','georgia') or item->>'density' not in ('standard','compact','confort') or item->>'logo' not in ('','uniion-logo.png') then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_each(item) x where (x.key in ('header','footer','caps','emetteurOverride') and jsonb_typeof(x.value) is distinct from 'boolean') or (x.key not in ('header','footer','caps','emetteurOverride') and (jsonb_typeof(x.value) is distinct from 'string' or length(x.value#>>'{}')>300))) then raise insufficient_privilege;end if;
 end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop$new$);
 definition=replace(definition,$old$('h1','h2','p','ul','quote','table','tag','pagebreak')$old$,$new$('h1','h2','h3','p','ul','quote','table','tag','pagebreak')$new$);
 execute definition;
end;$patch$;
commit;
