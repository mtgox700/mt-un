begin;
create table uniion_private.agenda_publication_notifications(id uuid primary key default gen_random_uuid(),event_id uuid not null,version integer not null,user_id uuid not null references auth.users,created_at timestamptz not null default now(),read_at timestamptz,foreign key(event_id,version) references uniion_private.agenda_publications,unique(event_id,version,user_id));
alter table uniion_private.agenda_publication_notifications enable row level security;
revoke all on uniion_private.agenda_publication_notifications from public,anon,authenticated;
create function uniion_private.agenda_document_recipient(p_event uuid,p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
select uniion_private.agenda_recipient_allowed(p_event,p_user) and exists(select 1 from uniion_private.agenda_events e join public.uniion_permissions p on p.organization_id=e.organization_id and p.user_id=p_user and p.module='documents' and p.permission='read' join public.uniion_module_access m on m.organization_id=e.organization_id and m.module='documents' and m.authorized and m.enabled and m.valid_until>now() where e.id=p_event and uniion_private.commercial_allowed(e.organization_id,'documents'));
$$;
create function uniion_private.agenda_publication_notify() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.published_at is not null and (tg_op='INSERT' or old.published_at is null) then
 insert into uniion_private.agenda_publication_notifications(event_id,version,user_id)
 select new.event_id,new.version,m.user_id from public.uniion_memberships m join uniion_private.agenda_events e on e.organization_id=m.organization_id where e.id=new.event_id and uniion_private.agenda_document_recipient(e.id,m.user_id) on conflict do nothing;
 end if;return new;
end;$$;
create trigger agenda_publication_notified after insert or update on uniion_private.agenda_publications for each row execute function uniion_private.agenda_publication_notify();
create function public.uniion_agenda_publication_notices(p_org uuid,p_read uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];
begin
 perform public.uniion_module_use(p_org,'agenda');perform public.uniion_module_use(p_org,'documents');
 select array_agg(n.id) into ids from uniion_private.agenda_publication_notifications n join uniion_private.agenda_events e on e.id=n.event_id join uniion_private.agenda_documents d on d.event_id=e.id and d.version=n.version join uniion_private.agenda_publications p on p.event_id=e.id and p.version=n.version and p.source_version=e.version and p.published_at is not null where e.organization_id=p_org and n.user_id=auth.uid() and uniion_private.agenda_document_recipient(e.id,auth.uid());
 if p_read is not null then
 if not coalesce(p_read=any(ids),false) then raise insufficient_privilege;end if;
 update uniion_private.agenda_publication_notifications set read_at=coalesce(read_at,now()) where id=p_read and user_id=auth.uid();
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'event',n.event_id,'version',n.version,'title',p.document->>'title','read',n.read_at is not null,'created',n.created_at) order by n.created_at desc) from uniion_private.agenda_publication_notifications n join uniion_private.agenda_publications p on p.event_id=n.event_id and p.version=n.version where n.id=any(ids)),'[]'::jsonb);
end;$$;
revoke all on function uniion_private.agenda_document_recipient(uuid,uuid),uniion_private.agenda_publication_notify() from public,anon,authenticated;
revoke all on function public.uniion_agenda_publication_notices(uuid,uuid) from public,anon;
grant execute on function public.uniion_agenda_publication_notices(uuid,uuid) to authenticated;
commit;
