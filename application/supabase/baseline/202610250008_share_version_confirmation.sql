begin;
drop function public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean);
create function public.uniion_share_create(p_org uuid,p_target uuid,p_resources uuid[],p_people uuid[],p_until timestamptz,p_download boolean default false,p_versions jsonb default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare sid uuid;res uuid;person uuid;mine uuid=auth.uid();r public.uniion_resources;
begin
 if not uniion_private.authority(p_org,mine,'share') or p_org=p_target or not exists(select 1 from public.uniion_partners where source_id=p_org and target_id=p_target) or (p_download and not uniion_private.authority(p_org,mine,'download')) then raise insufficient_privilege; end if;
 if p_until is null or p_until<=now() or p_until>now()+interval '90 days' or coalesce(cardinality(p_resources),0) not between 1 and 20 or coalesce(cardinality(p_people),0) not between 1 and 20 then raise check_violation; end if;
 foreach person in array p_people loop if not uniion_private.actor_member(p_target,person) then raise insufficient_privilege; end if; end loop;
 insert into public.uniion_shares(source_id,target_id,creator,allowed,expires_at,download) values(p_org,p_target,mine,p_people,p_until,p_download) returning id into sid;
 foreach res in array p_resources loop
  select * into r from public.uniion_resources where id=res and organization_id=p_org;
  if not found or not r.external_share_allowed or not uniion_private.actor_resource(p_org,res,mine,false) then raise insufficient_privilege; end if;
  if p_versions is null or (p_versions->>res::text)::integer is distinct from r.version then raise exception 'Resource version changed' using errcode='40001'; end if;
  insert into public.uniion_share_items values(sid,p_org,res,r.version);
 end loop;
 insert into public.uniion_security_events(organization_id,target_id,actor,event,details) values(p_org,p_target,mine,'share.created',jsonb_build_object('share',sid,'resources',p_resources,'people',p_people,'download',p_download,'expires',p_until));
 return sid;
end $$;
revoke all on function public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb) from public,anon;
grant execute on function public.uniion_share_create(uuid,uuid,uuid[],uuid[],timestamptz,boolean,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
