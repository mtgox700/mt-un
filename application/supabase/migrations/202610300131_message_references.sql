begin;
create table uniion_private.message_forwards(
 organization_id uuid not null,conversation uuid not null,seq bigint not null,source_conversation uuid not null,source_seq bigint not null,
 primary key(organization_id,conversation,seq),
 foreign key(organization_id,conversation,seq) references uniion_private.messages(organization_id,conversation,seq),
 foreign key(organization_id,source_conversation,source_seq) references uniion_private.messages(organization_id,conversation,seq)
);
create table uniion_private.message_forward_batches(
 organization_id uuid not null references public.uniion_organizations,actor uuid not null references auth.users,client_id uuid not null,
 source_conversation uuid not null,source_seq bigint not null,targets uuid[] not null,result jsonb not null,
 primary key(organization_id,actor,client_id),
 foreign key(organization_id,source_conversation,source_seq) references uniion_private.messages(organization_id,conversation,seq)
);
alter table uniion_private.message_forwards enable row level security;
alter table uniion_private.message_forward_batches enable row level security;
revoke all on uniion_private.message_forwards,uniion_private.message_forward_batches from public,anon,authenticated;
alter function uniion_private.message_visible(uuid,uuid,bigint) rename to message_visible_before_references;
-- Bounded walk preserves every intermediate conversation's historical ACL.
create function uniion_private.message_origin(o uuid,c uuid,s bigint) returns uniion_private.messages language plpgsql stable security definer set search_path='' as $$
declare m uniion_private.messages;f uniion_private.message_forwards;depth integer;
begin
 for depth in 0..8 loop
  if not uniion_private.message_visible_before_references(o,c,s) then return null;end if;
  select * into m from uniion_private.messages where organization_id=o and conversation=c and seq=s;
  if not found then return null;end if;
  select * into f from uniion_private.message_forwards where organization_id=o and conversation=c and seq=s;
  if not found then
   if depth>0 and exists(select 1 from uniion_private.message_files mf join public.uniion_attachments a on a.id=mf.attachment where mf.organization_id=o and mf.conversation=c and mf.seq=s and (not a.ready or uniion_private.case_file_trashed(a.id))) then return null;end if;
   return m;
  end if;
  c=f.source_conversation;s=f.source_seq;
 end loop;
 return null;
end$$;
create function uniion_private.message_visible(o uuid,c uuid,s bigint) returns boolean language sql stable security definer set search_path='' as $$
 select (uniion_private.message_origin(o,c,s)).id is not null
$$;
revoke all on function uniion_private.message_origin(uuid,uuid,bigint),uniion_private.message_visible(uuid,uuid,bigint),uniion_private.message_visible_before_references(uuid,uuid,bigint) from public,anon,authenticated;
alter function uniion_private.message_json(uniion_private.messages) rename to message_json_before_references;
create function uniion_private.message_json(m uniion_private.messages) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare origin uniion_private.messages;r uniion_private.messages;quote uniion_private.messages;base jsonb;doc jsonb;
begin
 origin=uniion_private.message_origin(m.organization_id,m.conversation,m.seq);
 if origin.id is null then return null;end if;
 base=uniion_private.message_json_before_references(m);
 if origin.id<>m.id then
  doc=uniion_private.message_json_before_references(origin)->'file';
  if doc is not null and doc<>'null'::jsonb then doc=doc||jsonb_build_object('canWrite',false);end if;
  base=base||jsonb_build_object('text',origin.body,'file',doc,'fwd',true);
 end if;
 if m.reply_to is not null then
  select * into r from uniion_private.messages where organization_id=m.organization_id and conversation=m.conversation and seq=m.reply_to;
  quote=uniion_private.message_origin(m.organization_id,m.conversation,m.reply_to);
  base=base||jsonb_build_object('reply',case when quote.id is not null then jsonb_build_object('seq',r.seq::text,'text',left(quote.body,160),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=r.organization_id and user_id=r.author),'Membre')) end);
 end if;
 return base;
end$$;
revoke all on function uniion_private.message_json(uniion_private.messages),uniion_private.message_json_before_references(uniion_private.messages) from public,anon,authenticated;
-- File gateways require the destination reference and all source episodes, too.
alter function public.uniion_message_file_context(uuid,uuid,uuid) rename to uniion_message_file_context_before_references;
revoke all on function public.uniion_message_file_context_before_references(uuid,uuid,uuid) from public,anon,authenticated;
create function public.uniion_message_file_context(p_org uuid,p_conversation uuid,p_attachment uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.message_files;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 select * into f from uniion_private.message_files where organization_id=p_org and attachment=p_attachment;
 if not found then raise insufficient_privilege;end if;
 if f.conversation=p_conversation then return public.uniion_message_file_context_before_references(p_org,p_conversation,p_attachment);end if;
 if uniion_private.case_file_trashed(p_attachment) or not exists(select 1 from uniion_private.messages m cross join lateral (select uniion_private.message_origin(p_org,m.conversation,m.seq) original) q where m.organization_id=p_org and m.conversation=p_conversation and (q.original).conversation=f.conversation and (q.original).seq=f.seq) then raise insufficient_privilege;end if;
 return jsonb_build_object('resource',f.resource,'write',false);
end$$;
revoke all on function public.uniion_message_file_context(uuid,uuid,uuid) from public,anon;
grant execute on function public.uniion_message_file_context(uuid,uuid,uuid) to authenticated;
create or replace function uniion_private.message_case_source(o uuid,c uuid,s bigint,f text) returns jsonb language plpgsql stable set search_path='' as $$
declare m uniion_private.messages;a public.uniion_attachments;
begin
 perform public.uniion_module_use(o,'messagerie');
 m=uniion_private.message_origin(o,c,s);
 if m.id is null then return null;end if;
 if f<>'' then
  select a0.* into a from uniion_private.message_files mf join public.uniion_attachments a0 on a0.id=mf.attachment where mf.organization_id=o and mf.conversation=m.conversation and mf.seq=m.seq and mf.attachment=f::uuid;
  if not found or not a.ready or a.scan_status<>'clean' or uniion_private.case_file_trashed(a.id) then return null;end if;
  return jsonb_build_object('name',a.filename);
 end if;
 return jsonb_build_object('name','Message','body',m.body);
exception when insufficient_privilege then return null;
end$$;
notify pgrst,'reload schema';commit;
