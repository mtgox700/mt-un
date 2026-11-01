begin;
-- Receipts contain only a digest, scope and audit information. No direct table access.
create table uniion_private.agenda_image_receipts(event_id uuid not null references uniion_private.agenda_events(id),digest text not null,engine text not null,scanned_at timestamptz not null default now(),primary key(event_id,digest));
alter table uniion_private.agenda_image_receipts enable row level security;
revoke all on uniion_private.agenda_image_receipts from public,anon,authenticated;
create function public.uniion_agenda_image_receipt(p_event uuid,p_image text,p_engine text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.is_scanner() or p_image is null or p_engine is null or length(p_engine) not between 1 and 250 or length(p_image)>2800000 or p_image !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/]+={0,2}$' then raise insufficient_privilege;end if;
 insert into uniion_private.agenda_image_receipts(event_id,digest,engine) values(p_event,encode(extensions.digest(p_image,'sha256'),'hex'),p_engine) on conflict do nothing;
 return jsonb_build_object('ok',true);
end;$$;
revoke all on function public.uniion_agenda_image_receipt(uuid,text,text) from public,anon;
grant execute on function public.uniion_agenda_image_receipt(uuid,text,text) to authenticated;
create function uniion_private.agenda_image_allowed(p_event uuid,p_image text) returns boolean language sql stable security definer set search_path='' as $$
 select p_image is not null and (p_image in ('','uniion-logo.png') or exists(select 1 from uniion_private.agenda_image_receipts where event_id=p_event and digest=encode(extensions.digest(p_image,'sha256'),'hex')))
$$;
revoke all on function uniion_private.agenda_image_allowed(uuid,text) from public,anon,authenticated;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_work(uuid,uuid,text,jsonb)'::regprocedure);
 definition=replace(definition,$old$doc-array['title','format','blocks','charte']$old$,$new$doc-array['title','format','blocks','charte','style','styleOpts']$new$);
 definition=replace(definition,$old$item->>'logo' not in ('','uniion-logo.png')$old$,$new$not uniion_private.agenda_image_allowed(p_event,item->>'logo')$new$);
 definition=replace(definition,$old$length(x.value#>>'{}')>300$old$,$new$length(x.value#>>'{}')>case when x.key='logo' then 2800000 else 300 end$new$);
 definition=replace(definition,$old$for item in select value from jsonb_array_elements(doc->'blocks') loop$old$,$new$
 if doc ? 'style' and doc->'style'<>'null'::jsonb and (jsonb_typeof(doc->'style')<>'string' or doc->>'style' not in ('choc','journal','infographie','institutionnel','photo','serigraphie','bulletin','qr','satirique','bd','annonce','retro')) then raise insufficient_privilege;end if;
 if doc ? 'styleOpts' then
  if jsonb_typeof(doc->'styleOpts') is distinct from 'object' or (doc->'styleOpts')-array['palette','font']<>'{}'::jsonb then raise insufficient_privilege;end if;
  for item in select value from jsonb_each(doc->'styleOpts') loop
   if jsonb_typeof(item) is distinct from 'number' or (item#>>'{}') !~ '^[0-9]+$' then raise insufficient_privilege;end if;
  end loop;
  if coalesce((doc->'styleOpts'->>'palette')::int,0)>=(case doc->>'style' when 'choc' then 4 when 'journal' then 4 when 'infographie' then 4 when 'institutionnel' then 4 when 'photo' then 3 when 'serigraphie' then 4 when 'bulletin' then 4 when 'qr' then 4 when 'satirique' then 3 when 'bd' then 3 when 'annonce' then 2 when 'retro' then 3 else 1 end) or coalesce((doc->'styleOpts'->>'font')::int,0)>=(case doc->>'style' when 'choc' then 3 when 'journal' then 3 when 'infographie' then 3 when 'institutionnel' then 3 when 'photo' then 3 when 'serigraphie' then 3 when 'bulletin' then 3 when 'qr' then 3 when 'satirique' then 2 when 'bd' then 2 when 'annonce' then 2 when 'retro' then 2 else 1 end) then raise insufficient_privilege;end if;
 end if;
 for item in select value from jsonb_array_elements(doc->'blocks') loop
  if item ? 'img' and not uniion_private.agenda_image_allowed(p_event,item->>'img') then raise insufficient_privilege;end if;
  if item->>'type'='studio.photo' and item->>'text' ~ '^(https?:|data:)' then raise insufficient_privilege;end if;
$new$);
 definition=replace(definition,$old$item-array['id','type','text']$old$,$new$item-array['id','type','text','img']$new$);
 definition=replace(definition,$old$('h1','h2','h3','p','ul','quote','table','tag','pagebreak')$old$,$new$('h1','h2','h3','p','ul','quote','table','tag','pagebreak','studio.chiffre','studio.compare','studio.frise','studio.photo','studio.qr','studio.coupon','studio.trombi','studio.tampon','studio.surligne','studio.signature','studio.bulles','studio.exige')$new$);
 execute definition;
end;$patch$;
commit;
