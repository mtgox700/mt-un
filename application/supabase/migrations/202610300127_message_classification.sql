begin;
alter table uniion_private.case_links alter column convocation drop not null;
alter table uniion_private.case_links add column message_conversation uuid,add column message_seq bigint;
alter table uniion_private.case_links add constraint case_message_source_fk foreign key(organization_id,message_conversation,message_seq) references uniion_private.messages(organization_id,conversation,seq),add constraint case_link_source_one check((convocation is not null and message_conversation is null and message_seq is null) or (convocation is null and message_conversation is not null and message_seq is not null));
create unique index case_message_link_once on uniion_private.case_links(organization_id,resource_id,message_conversation,message_seq,file) where message_conversation is not null;
create function uniion_private.message_case_source(o uuid,c uuid,s bigint,f text) returns jsonb language plpgsql stable set search_path='' as $$
declare m uniion_private.messages;a public.uniion_attachments;
begin
 perform public.uniion_module_use(o,'messagerie');
 if not uniion_private.message_visible(o,c,s) then return null;end if;
 select * into m from uniion_private.messages where organization_id=o and conversation=c and seq=s;
 if not found then return null;end if;
 if f<>'' then
  select a0.* into a from uniion_private.message_files mf join public.uniion_attachments a0 on a0.id=mf.attachment where mf.organization_id=o and mf.conversation=c and mf.seq=s and mf.attachment=f::uuid;
  if not found or not a.ready or a.scan_status<>'clean' or uniion_private.case_file_trashed(a.id) then return null;end if;
  return jsonb_build_object('name',a.filename);
 end if;
 return jsonb_build_object('name','Message','body',m.body);
exception when insufficient_privilege then return null;
end$$;
create function uniion_private.case_link_source(l uniion_private.case_links) returns jsonb language sql stable set search_path='' as $$
 select case when l.message_conversation is null then uniion_private.case_source(l.organization_id,l.convocation,l.file) else uniion_private.message_case_source(l.organization_id,l.message_conversation,l.message_seq,l.file) end
$$;
revoke all on function uniion_private.message_case_source(uuid,uuid,bigint,text),uniion_private.case_link_source(uniion_private.case_links) from public,anon,authenticated;
-- Existing list, counts, timeline and disposal continue to own destination rendering.
do $$declare fn text;d text;begin
 foreach fn in array array['uniion_private.case_classified_files(uuid,uuid)','uniion_private.case_json(uuid,uuid)'] loop
  d=pg_get_functiondef(fn::regprocedure);d=replace(d,'uniion_private.case_source(o,l.convocation,l.file)','uniion_private.case_link_source(l)');execute d;
 end loop;
end$$;
alter function public.uniion_case_link(uuid,uuid,uuid) rename to uniion_case_link_before_messages;
revoke all on function public.uniion_case_link_before_messages(uuid,uuid,uuid) from public,anon,authenticated;
create function public.uniion_case_link(p_org uuid,p_case uuid,p_link uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l uniion_private.case_links;
begin
 perform public.uniion_case_files(p_org,p_case);
 select * into l from uniion_private.case_links where organization_id=p_org and resource_id=p_case and id=p_link and not withdrawn;
 if not found then raise insufficient_privilege;end if;
 if l.message_conversation is null then return public.uniion_case_link_before_messages(p_org,p_case,p_link);end if;
 if l.file='' or uniion_private.case_link_source(l) is null then raise insufficient_privilege;end if;
 return jsonb_build_object('conversation',l.message_conversation,'attachment',l.file);
end$$;
create function public.uniion_message_classify(p_org uuid,p_case uuid,p_expected integer,p_conversation uuid,p_seq bigint,p_file text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare ident uuid;v integer;old uniion_private.case_links;
begin
 perform public.uniion_case_files(p_org,p_case);
 if not uniion_private.actor_resource(p_org,p_case,auth.uid(),true) or p_file is null or uniion_private.message_case_source(p_org,p_conversation,p_seq,p_file) is null then raise insufficient_privilege;end if;
 select version into v from public.uniion_resources where organization_id=p_org and id=p_case for update;
 select * into old from uniion_private.case_links where organization_id=p_org and resource_id=p_case and message_conversation=p_conversation and message_seq=p_seq and file=p_file;
 if found then
  if old.withdrawn then raise insufficient_privilege;end if;
  return jsonb_build_object('id',old.id,'already',true);
 end if;
 if p_expected is distinct from v then raise serialization_failure;end if;
 insert into uniion_private.case_links(organization_id,resource_id,message_conversation,message_seq,file,actor) values(p_org,p_case,p_conversation,p_seq,p_file,auth.uid()) returning id into ident;
 update public.uniion_resources set version=version+1 where id=p_case;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.classified',jsonb_build_object('case',p_case,'link',ident));
 return jsonb_build_object('id',ident,'already',false);
end$$;
revoke all on function public.uniion_case_link(uuid,uuid,uuid),public.uniion_message_classify(uuid,uuid,integer,uuid,bigint,text) from public,anon;
grant execute on function public.uniion_case_link(uuid,uuid,uuid),public.uniion_message_classify(uuid,uuid,integer,uuid,bigint,text) to authenticated;
notify pgrst,'reload schema';commit;
