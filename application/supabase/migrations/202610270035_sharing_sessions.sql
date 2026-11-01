begin;
create or replace function public.uniion_share_create(p_org uuid,p_target uuid,p_resources uuid[],p_people uuid[],p_until timestamptz,p_download boolean default false,p_versions jsonb default null,p_attachments uuid[] default '{}') returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;aid uuid;a public.uniion_attachments;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 if p_attachments is null or cardinality(p_attachments)>20 then raise check_violation;end if;
 sid=public.uniion_share_create_core(p_org,p_target,p_resources,p_people,p_until,p_download,p_versions);
 foreach aid in array p_attachments loop
  select * into a from public.uniion_attachments where id=aid and organization_id=p_org and ready;
  if not found or not a.resource_id=any(p_resources) or not uniion_private.attachment_access(a.id,auth.uid()) then raise insufficient_privilege;end if;
  insert into public.uniion_share_attachments values(sid,a.resource_id,a.id);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,auth.uid(),'share.files_selected',jsonb_build_object('share',sid,'attachments',p_attachments));
 return sid;
end $$;
create or replace function public.uniion_share_accept(p_org uuid,p_share uuid,p_people uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.uniion_shares;person uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.target_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'accept') or s.revoked_at is not null or s.expires_at<=now() or s.accepted_at is not null or not uniion_private.authority(s.source_id,s.creator,'share') then raise insufficient_privilege; end if;
 if coalesce(cardinality(p_people),0)=0 or not p_people<@s.allowed then raise insufficient_privilege; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_org,person) then raise insufficient_privilege; end if; end loop;
 update public.uniion_shares set beneficiaries=p_people,accepted_at=now(),accepted_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.accepted',jsonb_build_object('share',p_share,'people',p_people));
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.uniion_share_revoke(p_org uuid,p_share uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.uniion_shares;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.session_allowed() then raise insufficient_privilege;end if;
 select * into s from public.uniion_shares where id=p_share for update;
 if not found or s.source_id<>p_org or not uniion_private.authority(p_org,auth.uid(),'share') then raise insufficient_privilege; end if;
 update public.uniion_shares set revoked_at=coalesce(revoked_at,now()),revoked_by=auth.uid() where id=p_share;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(s.source_id,s.target_id,auth.uid(),'share.revoked',jsonb_build_object('share',p_share));
 return jsonb_build_object('ok',true);
end $$;
commit;
