begin;
alter table public.uniion_authorities drop constraint uniion_authorities_permission_check;
alter table public.uniion_authorities add constraint uniion_authorities_permission_check check(permission in ('rights','share','accept','download','history','organization_edit','collection_publish','collection_accept'));
create table uniion_private.collections(id uuid primary key default gen_random_uuid(),source uuid not null references public.uniion_organizations,target uuid not null references public.uniion_organizations,name text not null check(length(name) between 1 and 160),check(source<>target));
create table uniion_private.collection_versions(collection uuid references uniion_private.collections,number integer check(number>0),color text not null check(color~'^#[0-9a-fA-F]{6}$'),text text not null check(length(text) between 1 and 400),author uuid not null references auth.users,published boolean not null default false,reviewer uuid references auth.users,primary key(collection,number),check(not published or (reviewer is not null and reviewer<>author)));
create unique index one_collection_draft on uniion_private.collection_versions(collection) where not published;
create table uniion_private.collection_subscriptions(collection uuid primary key references uniion_private.collections,accepted integer not null,active boolean not null default true,override_text text not null default '' check(length(override_text)<=400),declined jsonb not null default '[]',history jsonb not null default '[]',foreign key(collection,accepted) references uniion_private.collection_versions(collection,number));
alter table uniion_private.collections enable row level security;
alter table uniion_private.collection_versions enable row level security;
alter table uniion_private.collection_subscriptions enable row level security;
revoke all on uniion_private.collections,uniion_private.collection_versions,uniion_private.collection_subscriptions from public,anon,authenticated;
create function public.uniion_collections_context(p_org uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not uniion_private.member(p_org) then raise insufficient_privilege;end if;
 return jsonb_build_object('activeOrg',p_org,'actor',auth.uid(),'permissions',jsonb_build_object('admin',uniion_private.authority(p_org,auth.uid(),'organization_edit'),'acceptCollection',uniion_private.authority(p_org,auth.uid(),'collection_accept'),'publishCollection',uniion_private.authority(p_org,auth.uid(),'collection_publish')),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name)) from public.uniion_organizations o where o.id=p_org or exists(select 1 from uniion_private.collections c where p_org in(c.source,c.target) and o.id in(c.source,c.target))),'[]'),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.email)) from auth.users u join public.uniion_memberships m on m.user_id=u.id where m.organization_id=p_org and m.revoked_at is null and (u.id=auth.uid() or (uniion_private.authority(p_org,auth.uid(),'collection_publish') and exists(select 1 from uniion_private.collection_versions v join uniion_private.collections c on c.id=v.collection where c.source=p_org and v.author=u.id)))),'[]'),
 'collections',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'source',c.source,'target',c.target,'name',c.name,
 'versions',coalesce((select jsonb_agg(jsonb_build_object('number',v.number,'color',v.color,'text',v.text,'published',v.published,'author',case when p_org=c.source then v.author else null end) order by v.number) from uniion_private.collection_versions v where v.collection=c.id and (p_org=c.source or (v.published and (s.active is distinct from false or v.number<=s.accepted)))),'[]'),
 'subscription',case when p_org=c.target and s.collection is not null then jsonb_build_object('accepted',s.accepted,'active',s.active,'overrides',jsonb_build_object('text',s.override_text),'declined',s.declined,'history',s.history) else null end)) from uniion_private.collections c left join uniion_private.collection_subscriptions s on s.collection=c.id where p_org in(c.source,c.target) and exists(select 1 from uniion_private.collection_versions v where v.collection=c.id and v.published)),'[]'));
end $$;
create function public.uniion_collection_change(p_org uuid,p_collection uuid,p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c uniion_private.collections;s uniion_private.collection_subscriptions;v uniion_private.collection_versions;n integer;k text;
begin
 if auth.jwt()->>'aal' is distinct from 'aal2' or not uniion_private.member(p_org) or p_action is null or p_data is null or jsonb_typeof(p_data)<>'object' then raise insufficient_privilege;end if;
 select * into c from uniion_private.collections where id=p_collection for update;
 if not found or p_org not in(c.source,c.target) then raise insufficient_privilege;end if;
 for k in select jsonb_object_keys(p_data) loop
 if k<>all(case when p_action='collectionDraft' then array['color','text'] when p_action='collectionOverride' then array['text'] when p_action='collectionStop' then array[]::text[] else array['version','expected'] end) then raise insufficient_privilege;end if;end loop;
 if p_action in ('collectionDraft','collectionPublish') then
 if p_org<>c.source or not uniion_private.authority(p_org,auth.uid(),'collection_publish') then raise insufficient_privilege;end if;
 if p_action='collectionDraft' then
 if jsonb_typeof(p_data->'color') is distinct from 'string' or jsonb_typeof(p_data->'text') is distinct from 'string' then raise insufficient_privilege;end if;
 select coalesce(max(number),0)+1 into n from uniion_private.collection_versions where collection=c.id;
 insert into uniion_private.collection_versions(collection,number,color,text,author) values(c.id,n,p_data->>'color',p_data->>'text',auth.uid());
 else
 update uniion_private.collection_versions set published=true,reviewer=auth.uid() where collection=c.id and number=(p_data->>'version')::integer and not published and author<>auth.uid();if not found then raise insufficient_privilege;end if;
 end if;
 else
 if p_org<>c.target or not uniion_private.authority(p_org,auth.uid(),'organization_edit') or not uniion_private.authority(p_org,auth.uid(),'collection_accept') then raise insufficient_privilege;end if;
 select * into s from uniion_private.collection_subscriptions where collection=c.id;
 if p_action in ('collectionAdopt','collectionAccept','collectionDecline') then
 select * into v from uniion_private.collection_versions where collection=c.id and published and number=(p_data->>'version')::integer;
 if not found then raise insufficient_privilege;end if;
 end if;
 if p_action='collectionAdopt' then
 if s.collection is not null then raise insufficient_privilege;end if;
 insert into uniion_private.collection_subscriptions(collection,accepted,history) values(c.id,v.number,jsonb_build_array(jsonb_build_object('version',v.number,'actor',auth.uid(),'at',now())));
 else
 if s.collection is null or not s.active then raise insufficient_privilege;end if;
 if p_action in ('collectionAccept','collectionDecline') then
 if (p_data->>'expected')::integer is distinct from s.accepted or v.number<=s.accepted then raise insufficient_privilege;end if;
 if p_action='collectionAccept' then update uniion_private.collection_subscriptions set accepted=v.number,history=history||jsonb_build_array(jsonb_build_object('version',v.number,'actor',auth.uid(),'at',now())) where collection=c.id;
 else update uniion_private.collection_subscriptions set declined=declined||to_jsonb(v.number) where collection=c.id;end if;
 elsif p_action='collectionOverride' then
 if jsonb_typeof(p_data->'text') is distinct from 'string' then raise insufficient_privilege;end if;
 update uniion_private.collection_subscriptions set override_text=p_data->>'text' where collection=c.id;
 elsif p_action='collectionStop' then update uniion_private.collection_subscriptions set active=false where collection=c.id;
 else raise insufficient_privilege;end if;
 end if;
 end if;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'collection.'||p_action,jsonb_build_object('collection',c.id,'version',p_data->'version'));
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.uniion_collections_context(uuid),public.uniion_collection_change(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_collections_context(uuid),public.uniion_collection_change(uuid,uuid,text,jsonb) to authenticated;
commit;
