begin;
-- R18 : les fonctions de contrôle d'accès appelées par les politiques RLS étaient en langage SQL
-- SECURITY DEFINER, donc non « inlinées » et replanifiées à chaque appel, à chaque ligne et à chaque
-- niveau d'imbrication (11 s pour 5 000 lignes lues). Mêmes expressions, mêmes signatures et mêmes
-- attributs, en plpgsql dont les plans sont mis en cache (1 s). L'OID est conservé (create or replace) :
-- privilèges et politiques inchangés. Redéfinitions complètes, pas de substitution de texte.
CREATE OR REPLACE FUNCTION uniion_private.session_allowed()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
 select exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
 and (s.not_after is null or s.not_after>now())
 and ((auth.jwt()->>'aal'='aal2' and exists(select 1 from uniion_private.trusted_mfa_factors t
 join auth.mfa_factors f on f.id=t.factor_id and f.user_id=t.user_id
 where t.user_id=s.user_id and t.factor_id=s.factor_id and f.status='verified' and (t.valid_until is null or t.valid_until>now())))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal1'
 and not exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified')
 and not exists(select 1 from uniion_private.mfa_requirements m where m.user_id=auth.uid() and m.required))))
); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.actor_member(org uuid, who uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
 select uniion_private.session_allowed() and exists(select 1 from public.uniion_memberships m join public.uniion_organizations o on o.id=m.organization_id where m.organization_id=org and m.user_id=who and m.revoked_at is null and m.joined_at<=now() and o.active) and not exists(select 1 from uniion_private.membership_suspensions s where s.organization_id=org and s.user_id=who and s.suspended)
); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.member(org uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (select uniion_private.actor_member(org,auth.uid())); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.commercial_allowed(p_org uuid, p_module text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
select not exists(select 1 from uniion_private.module_catalog where id=p_module) or (exists(select 1 from uniion_private.module_catalog where id=p_module and available) and exists(select 1 from uniion_private.module_entitlements where organization_id=p_org and module=p_module and revoked_at is null and starts<=now() and ends>now()))
); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.case_disposed(r uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (select exists(select 1 from uniion_private.case_disposals where resource_id=r and link is null and state='approved')); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.resource_access_before_disposal(org uuid, resource uuid, write_access boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
 select uniion_private.member(org) and exists(
 select 1 from public.uniion_resources r
 join public.uniion_resource_grants g on g.organization_id=r.organization_id and g.resource_id=r.id
 join public.uniion_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id
 join public.uniion_module_access a on a.organization_id=r.organization_id and a.module=r.module
 join public.uniion_permissions p on p.organization_id=g.organization_id and p.user_id=g.user_id and p.module=r.module
 where r.organization_id=org and r.id=resource and g.user_id=auth.uid()
 and g.revoked_at is null and g.valid_until>now()
 and (r.created_at>=m.joined_at or g.history_approved)
 and a.authorized and a.enabled and a.valid_until>now() and uniion_private.commercial_allowed(a.organization_id,a.module)
 and p.permission=case when write_access then 'write' else 'read' end
 and (not write_access or g.can_write))
); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.resource_access_before_ai_case(org uuid, resource uuid, write_access boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (select not uniion_private.case_disposed(resource) and uniion_private.resource_access_before_disposal(org,resource,write_access)); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.resource_access_before_minutes(org uuid, resource uuid, write_access boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
 select uniion_private.resource_access_before_ai_case(org,resource,write_access)
 and (not exists(select 1 from uniion_private.ai_case_derivatives d where d.resource=resource_access_before_minutes.resource)
      or uniion_private.actor_resource(org,resource,auth.uid(),write_access))
); end$function$

;
CREATE OR REPLACE FUNCTION uniion_private.resource_access(org uuid, resource uuid, write_access boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin return (
 select case when exists(select 1 from uniion_private.meeting_minutes where resource_id=resource) then uniion_private.actor_resource(org,resource,auth.uid(),write_access) else uniion_private.resource_access_before_minutes(org,resource,write_access) end
); end$function$

;
notify pgrst,'reload schema';
commit;
