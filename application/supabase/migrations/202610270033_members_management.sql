begin;
create table uniion_private.membership_suspensions(organization_id uuid not null,user_id uuid not null,suspended boolean not null,primary key(organization_id,user_id),foreign key(organization_id,user_id) references public.uniion_memberships);
alter table uniion_private.membership_suspensions enable row level security;
revoke all on uniion_private.membership_suspensions from public,anon,authenticated;
create or replace function uniion_private.actor_member(org uuid,who uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.session_allowed() and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=who and m.revoked_at is null and m.joined_at<=now() and o.active) and not exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=org and s.user_id=who and s.suspended)
$$;
create or replace function uniion_private.member(org uuid) returns boolean language sql stable security definer set search_path='' as $$select uniion_private.actor_member(org,auth.uid())$$;
create function public.uniion_membership_status(p_org uuid,p_user uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid()=p_user or not uniion_private.identity_admin(p_org) or p_action is null or p_action not in ('suspend','resume') then raise insufficient_privilege;end if;
 perform 1 from public.uniion_memberships where organization_id=p_org and user_id=p_user and revoked_at is null for update;
 if not found then raise insufficient_privilege;end if;
 insert into uniion_private.membership_suspensions values(p_org,p_user,p_action='suspend') on conflict(organization_id,user_id) do update set suspended=excluded.suspended;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'membership.'||p_action,jsonb_build_object('user',p_user));
 return jsonb_build_object('ok',true);
end $$;
create function public.uniion_invite_resend(p_org uuid,p_invitation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare ticket text=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');mail text;
begin
 if not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 update uniion_private.invitations set token_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),created_by=auth.uid(),expires_at=now()+interval '7 days' where id=p_invitation and organization_id=p_org and accepted_at is null and revoked_at is null returning email into mail;
 if not found then raise insufficient_privilege;end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'invitation.resent',jsonb_build_object('invitation',p_invitation));
 return jsonb_build_object('id',p_invitation,'token',ticket,'email',mail);
end $$;
revoke all on function public.uniion_membership_status(uuid,uuid,text),public.uniion_invite_resend(uuid,uuid) from public,anon;
grant execute on function public.uniion_membership_status(uuid,uuid,text),public.uniion_invite_resend(uuid,uuid) to authenticated;
create or replace function public.uniion_identity_directory(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not coalesce((public.uniion_session_status()->>'allowed')::boolean,false) or not uniion_private.identity_admin(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object(
 'members',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',coalesce(p.name,nullif(u.raw_user_meta_data->>'full_name',''),u.email),'email',u.email,'joined_at',m.joined_at,'revoked_at',m.revoked_at,'suspended',exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=m.organization_id and s.user_id=m.user_id and s.suspended)) order by m.joined_at,u.id) from public.uniion_memberships m join auth.users u on u.id=m.user_id left join uniion_private.identity_profiles p on p.organization_id=m.organization_id and p.user_id=m.user_id where m.organization_id=p_org),'[]'::jsonb),
 'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'created_at',i.created_at,'expires_at',i.expires_at,'accepted_at',i.accepted_at,'revoked_at',i.revoked_at,'status',case when i.accepted_at is not null then 'accepted' when i.revoked_at is not null then 'revoked' when i.expires_at<=now() then 'expired' else 'pending' end) order by i.created_at desc,i.id) from uniion_private.invitations i where i.organization_id=p_org),'[]'::jsonb));
end $$;
commit;
