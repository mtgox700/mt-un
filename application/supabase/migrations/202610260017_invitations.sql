begin;
create table uniion_private.invitations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.uniion_organizations,
 email text not null,token_hash text not null unique,created_by uuid not null references auth.users,
 created_at timestamptz not null default now(),expires_at timestamptz not null,
 accepted_at timestamptz,accepted_by uuid references auth.users,revoked_at timestamptz,
 check(expires_at>created_at)
);
revoke all on uniion_private.invitations from public,anon,authenticated;
create unique index uniion_pending_invitation on uniion_private.invitations(organization_id,email) where accepted_at is null and revoked_at is null;
create function uniion_private.identity_admin(org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.jwt()->>'aal'='aal2' and uniion_private.authority(org,auth.uid(),'rights')
$$;
revoke all on function uniion_private.identity_admin(uuid) from public,anon,authenticated;
create function public.uniion_invite_create(p_org uuid,p_email text) returns jsonb language plpgsql security definer set search_path='' as $$
declare ticket text=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');ident uuid;mail text=lower(trim(p_email));
begin
 if not uniion_private.identity_admin(p_org) or mail is null or length(mail)>320 or mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise insufficient_privilege;end if;
 -- Existing or revoked memberships are never silently reactivated by an invitation.
 if exists(select 1 from public.uniion_memberships m join auth.users u on u.id=m.user_id where m.organization_id=p_org and lower(u.email)=mail) then raise insufficient_privilege;end if;
 insert into uniion_private.invitations(organization_id,email,token_hash,created_by,expires_at)
 values(p_org,mail,encode(sha256(convert_to(ticket,'UTF8')),'hex'),auth.uid(),now()+interval '7 days') returning id into ident;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.created',jsonb_build_object('invitation',ident));
 return jsonb_build_object('id',ident,'token',ticket,'expires_in_seconds',604800);
end $$;
create function public.uniion_invite_accept(p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare invite uniion_private.invitations;mail text;
begin
 if not uniion_private.session_allowed() or p_token is null or length(p_token)<>64 then raise insufficient_privilege;end if;
 select lower(email) into mail from auth.users where id=auth.uid() and email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<now());
 select * into invite from uniion_private.invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
 if not found or mail is null or invite.email<>mail or invite.accepted_at is not null or invite.revoked_at is not null or invite.expires_at<=now()
 or not uniion_private.authority(invite.organization_id,invite.created_by,'rights') then raise insufficient_privilege;end if;
 if exists(select 1 from public.uniion_memberships where organization_id=invite.organization_id and user_id=auth.uid()) then raise insufficient_privilege;end if;
 insert into public.uniion_memberships(organization_id,user_id,joined_at) values(invite.organization_id,auth.uid(),now());
 -- No permissions, authorities, resource grants or historical access are created.
 update uniion_private.invitations set accepted_at=now(),accepted_by=auth.uid() where id=invite.id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(invite.organization_id,auth.uid(),'invitation.accepted',jsonb_build_object('invitation',invite.id));
 return jsonb_build_object('organization_id',invite.organization_id,'business_rights_granted',false);
end $$;
create function public.uniion_invite_revoke(p_org uuid,p_invitation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update uniion_private.invitations set revoked_at=coalesce(revoked_at,now()) where id=p_invitation and organization_id=p_org and accepted_at is null;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.revoked',jsonb_build_object('invitation',p_invitation));
 return jsonb_build_object('ok',true);
end $$;
create function public.uniion_membership_revoke(p_org uuid,p_user uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid()=p_user or not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update public.uniion_memberships set revoked_at=coalesce(revoked_at,now()) where organization_id=p_org and user_id=p_user;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'membership.revoked',jsonb_build_object('user',p_user));
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.uniion_invite_create(uuid,text),public.uniion_invite_accept(text),public.uniion_invite_revoke(uuid,uuid),public.uniion_membership_revoke(uuid,uuid) from public,anon;
grant execute on function public.uniion_invite_create(uuid,text),public.uniion_invite_accept(text),public.uniion_invite_revoke(uuid,uuid),public.uniion_membership_revoke(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
