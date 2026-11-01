begin;
create or replace function public.uniion_collections_context(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object('activeOrg',p_org,'actor',auth.uid(),'permissions',jsonb_build_object('admin',uniion_private.authority(p_org,auth.uid(),'organization_edit'),'acceptCollection',uniion_private.authority(p_org,auth.uid(),'collection_accept'),'publishCollection',uniion_private.authority(p_org,auth.uid(),'collection_publish')),
 'targets',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name) order by o.name) from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.source_id=p_org and o.active and uniion_private.authority(p_org,auth.uid(),'collection_publish')),'[]'),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_organizations o where o.id=p_org or exists(select 1 from uniion_private.collections c where p_org in(c.source,c.target) and o.id in(c.source,c.target) and (p_org=c.source or exists(select 1 from uniion_private.collection_versions cv where cv.collection=c.id and cv.published)))),'[]'),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from auth.users u join public.uniion_memberships m on m.user_id=u.id where m.organization_id=p_org and m.revoked_at is null and (u.id=auth.uid() or (uniion_private.authority(p_org,auth.uid(),'collection_publish') and exists(select 1 from uniion_private.collection_versions v join uniion_private.collections c on c.id=v.collection where c.source=p_org and v.author=u.id)))),'[]'),
 'collections',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'source',c.source,'target',c.target,'name',c.name,
 'versions',coalesce((select jsonb_agg(jsonb_build_object('number',v.number,'color',v.color,'text',v.text,'published',v.published,'author',case when p_org=c.source then v.author else null end) order by v.number) from uniion_private.collection_versions v where v.collection=c.id and ((p_org=c.source and uniion_private.authority(p_org,auth.uid(),'collection_publish')) or (v.published and (s.active is distinct from false or v.number<=s.accepted)))),'[]'),
 'subscription',case when p_org=c.target and s.collection is not null then jsonb_build_object('accepted',s.accepted,'active',s.active,'overrides',jsonb_build_object('text',s.override_text),'declined',s.declined,'history',s.history) else null end)) from uniion_private.collections c left join uniion_private.collection_subscriptions s on s.collection=c.id where p_org in(c.source,c.target) and ((p_org=c.source and uniion_private.authority(p_org,auth.uid(),'collection_publish')) or exists(select 1 from uniion_private.collection_versions v where v.collection=c.id and v.published))),'[]'));
end $$;
create function public.uniion_collection_create(p_org uuid,p_target uuid,p_name text,p_color text,p_text text) returns jsonb language plpgsql security definer set search_path='' as $$
declare ident uuid;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or not uniion_private.authority(p_org,auth.uid(),'collection_publish') then raise insufficient_privilege;end if;
 if p_target is null or p_target=p_org or not exists(select 1 from public.uniion_partners p join public.uniion_organizations o on o.id=p.target_id where p.source_id=p_org and p.target_id=p_target and o.active) then raise insufficient_privilege;end if;
 if p_name is null or length(trim(p_name)) not between 1 and 160 or p_color is null or p_color!~'^#[0-9a-fA-F]{6}$' or p_text is null or length(trim(p_text)) not between 1 and 400 then raise insufficient_privilege;end if;
 insert into uniion_private.collections(source,target,name) values(p_org,p_target,trim(p_name)) returning id into ident;
 insert into uniion_private.collection_versions(collection,number,color,text,author) values(ident,1,p_color,trim(p_text),auth.uid());
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'collection.created',jsonb_build_object('collection',ident,'target',p_target,'version',1));
 return jsonb_build_object('id',ident,'published',false);
end $$;
revoke all on function public.uniion_collection_create(uuid,uuid,text,text,text) from public,anon;
grant execute on function public.uniion_collection_create(uuid,uuid,text,text,text) to authenticated;
commit;
