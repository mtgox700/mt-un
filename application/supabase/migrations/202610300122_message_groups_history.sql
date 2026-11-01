begin;
alter table uniion_private.message_conversations add column kind text not null default 'direct' check(kind in ('direct','group')),
 add column title text not null default '',add column description text not null default '',
 add column version integer not null default 1,add column creation_payload jsonb;
alter table uniion_private.message_participations add column is_admin boolean not null default false;
create index message_participant_lookup on uniion_private.message_participations(organization_id,user_id,conversation) where left_at is null;
create table uniion_private.message_history_grants(
 organization_id uuid not null,conversation uuid not null,participation uuid not null,message_seq bigint not null,
 id uuid not null default gen_random_uuid(),granted_by uuid not null references auth.users,granted_at timestamptz not null default clock_timestamp(),revoked_at timestamptz,
 primary key(organization_id,id),
 foreign key(organization_id,conversation,participation) references uniion_private.message_participations(organization_id,conversation,id),
 foreign key(organization_id,conversation,message_seq) references uniion_private.messages(organization_id,conversation,seq)
);
create unique index message_history_active on uniion_private.message_history_grants(organization_id,conversation,participation,message_seq) where revoked_at is null;
alter table uniion_private.message_history_grants enable row level security;
revoke all on uniion_private.message_history_grants from public,anon,authenticated;
create function uniion_private.message_current(o uuid,c uuid,u uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_member(o,u) and exists(select 1 from uniion_private.message_participations p join public.uniion_memberships m on m.organization_id=p.organization_id and m.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id=u and p.left_at is null and p.organization_joined_at=m.joined_at)
$$;
create or replace function uniion_private.message_member(o uuid,c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.message_current(o,c,auth.uid())
$$;
create function uniion_private.message_admin(o uuid,c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.message_member(o,c) and exists(select 1 from uniion_private.message_participations where organization_id=o and conversation=c and user_id=auth.uid() and left_at is null and is_admin)
$$;
create or replace function uniion_private.message_visible(o uuid,c uuid,s bigint) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.message_member(o,c) and exists(select 1 from uniion_private.message_participations p where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null and
 (s>=p.visible_from or exists(select 1 from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.message_seq=s and g.revoked_at is null)))
$$;
create or replace function uniion_private.message_conversation_json(o uuid,c uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c,'kind',cv.kind,'name',case when cv.kind='group' then cv.title else coalesce((select ip.name from uniion_private.message_participations p left join uniion_private.identity_profiles ip on ip.organization_id=p.organization_id and ip.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id<>auth.uid() and p.left_at is null limit 1),'Membre') end,
 'desc',cv.description,'version',cv.version,'canManage',cv.kind='group' and uniion_private.message_admin(o,c),'canHistory',uniion_private.authority(o,auth.uid(),'history'),
 'memberRows',coalesce((select jsonb_agg(jsonb_build_object('id',p.user_id,'period',p.id,'name',coalesce(ip.name,'Membre'),'role',coalesce(ip.role_label,'Membre'),'admin',p.is_admin,'me',p.user_id=auth.uid(),'visibleFrom',p.visible_from::text,'historyCount',(select count(*) from uniion_private.message_history_grants g where g.organization_id=o and g.conversation=c and g.participation=p.id and g.revoked_at is null)) order by p.joined_at,p.id)
 from uniion_private.message_participations p left join uniion_private.identity_profiles ip on ip.organization_id=p.organization_id and ip.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.left_at is null and uniion_private.message_current(o,c,p.user_id)),'[]'),
 'messages',coalesce((select jsonb_agg(uniion_private.message_json(m)) from (select * from uniion_private.messages where organization_id=o and conversation=c and uniion_private.message_visible(o,c,seq) order by seq desc limit 1)m),'[]'))
 from uniion_private.message_conversations cv where cv.organization_id=o and cv.id=c
$$;
-- Keep the already-tested A implementation internal, behind the single public entry point.
alter function public.uniion_messaging(uuid,text,jsonb) set schema uniion_private;
alter function uniion_private.uniion_messaging(uuid,text,jsonb) rename to messaging_a;
revoke all on function uniion_private.messaging_a(uuid,text,jsonb) from public,anon,authenticated;
-- Recheck participation after acquiring the same lock used by membership changes.
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.messaging_a(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'id=cid for update;','id=cid for update; if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;');
 execute d;
end$$;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cv uniion_private.message_conversations;actor uniion_private.message_participations;target uniion_private.message_participations;cid uuid;u uuid;members uuid[];sequences bigint[];s bigint;k text;changed boolean:=false;event_name text;target_id uuid;reply jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action in ('participants','list','create','get','send') then return uniion_private.messaging_a(p_org,p_action,p_payload);end if;
 if p_action not in ('group_create','group_save','member_role','leave','history_grant','history_revoke') then raise insufficient_privilege;end if;
 if p_action in ('group_create','group_save') then
  if not(p_payload ?& array['name','desc','members']) or jsonb_typeof(p_payload->'name')<>'string' or length(btrim(p_payload->>'name')) not between 1 and 120 or length(p_payload->>'name')>120 or jsonb_typeof(p_payload->'desc')<>'string' or length(p_payload->>'desc')>2000 or jsonb_typeof(p_payload->'members')<>'array' or jsonb_array_length(p_payload->'members') not between 1 and 99 then raise insufficient_privilege;end if;
  if exists(select 1 from jsonb_array_elements(p_payload->'members') v where jsonb_typeof(v)<>'string') then raise insufficient_privilege;end if;
  select array_agg(v::uuid order by v::uuid) into members from jsonb_array_elements_text(p_payload->'members')v;
  if cardinality(members)<>(select count(distinct x) from unnest(members)x) or auth.uid()=any(members) then raise insufficient_privilege;end if;
  foreach u in array members loop
   if not uniion_private.actor_member(p_org,u) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=u and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  end loop;
 end if;
 if p_action='group_create' then
  if not(p_payload ? 'clientId') or p_payload-array['clientId','name','desc','members']<>'{}' or jsonb_typeof(p_payload->'clientId')<>'string' or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='create') then raise insufficient_privilege;end if;
  k='group:'||auth.uid()::text||':'||(p_payload->>'clientId')::uuid::text;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||k,0));
  select * into cv from uniion_private.message_conversations where organization_id=p_org and pair=k;
  if found then
   if cv.creation_payload is distinct from (p_payload||jsonb_build_object('members',to_jsonb(members))) or not uniion_private.message_member(p_org,cv.id) then raise insufficient_privilege;end if;
   return uniion_private.message_conversation_json(p_org,cv.id);
  end if;
  insert into uniion_private.message_conversations(organization_id,pair,kind,title,description,creation_payload) values(p_org,k,'group',btrim(p_payload->>'name'),p_payload->>'desc',p_payload||jsonb_build_object('members',to_jsonb(members))) returning id into cid;
  insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,is_admin) select p_org,cid,user_id,joined_at,user_id=auth.uid() from public.uniion_memberships where organization_id=p_org and (user_id=auth.uid() or user_id=any(members));
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.group_created',jsonb_build_object('conversation',cid,'members',cardinality(members)+1));
  return uniion_private.message_conversation_json(p_org,cid);
 end if;
 if not(p_payload ?& array['id','version']) or jsonb_typeof(p_payload->'id')<>'string' or jsonb_typeof(p_payload->'version')<>'number' or (p_payload->>'version') !~ '^[1-9][0-9]{0,8}$' then raise insufficient_privilege;end if;
 cid=(p_payload->>'id')::uuid;
 select * into cv from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
 if not found or not uniion_private.message_member(p_org,cid) or cv.version<>(p_payload->>'version')::integer then raise insufficient_privilege;end if;
 select * into actor from uniion_private.message_participations where organization_id=p_org and conversation=cid and user_id=auth.uid() and left_at is null;
 if p_action='group_save' then
  if cv.kind<>'group' or not actor.is_admin or p_payload-array['id','version','name','desc','members']<>'{}' then raise insufficient_privilege;end if;
  -- Removed/stale episodes are closed; an addition ALWAYS gets a fresh episode.
  update uniion_private.message_participations p set left_at=clock_timestamp() where p.organization_id=p_org and p.conversation=cid and p.left_at is null and p.user_id<>auth.uid() and (not(p.user_id=any(members)) or not uniion_private.message_current(p_org,cid,p.user_id));
  foreach u in array members loop
   if not uniion_private.message_current(p_org,cid,u) then
    insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from) select p_org,cid,user_id,joined_at,cv.next_seq+1 from public.uniion_memberships where organization_id=p_org and user_id=u;
   end if;
  end loop;
  update uniion_private.message_conversations set title=btrim(p_payload->>'name'),description=p_payload->>'desc' where organization_id=p_org and id=cid;
  event_name='members_changed';changed=true;
 elsif p_action='member_role' then
  if cv.kind<>'group' or not actor.is_admin or not(p_payload ?& array['participant','admin']) or p_payload-array['id','version','participant','admin']<>'{}' or jsonb_typeof(p_payload->'admin')<>'boolean' or jsonb_typeof(p_payload->'participant')<>'string' then raise insufficient_privilege;end if;
  u=(p_payload->>'participant')::uuid;
  if u=auth.uid() or not uniion_private.message_current(p_org,cid,u) then raise insufficient_privilege;end if;
  update uniion_private.message_participations set is_admin=(p_payload->>'admin')::boolean where organization_id=p_org and conversation=cid and user_id=u and left_at is null;
  event_name='moderator_changed';changed=true;target_id=u;
 elsif p_action='leave' then
  if cv.kind<>'group' or p_payload-array['id','version']<>'{}' then raise insufficient_privilege;end if;
  if actor.is_admin and not exists(select 1 from uniion_private.message_participations p where p.organization_id=p_org and p.conversation=cid and p.user_id<>auth.uid() and p.left_at is null and p.is_admin and uniion_private.message_current(p_org,cid,p.user_id)) then raise insufficient_privilege;end if;
  update uniion_private.message_participations set left_at=clock_timestamp() where organization_id=p_org and conversation=cid and id=actor.id;
  event_name='member_left';changed=true;target_id=auth.uid();
 else
  if not uniion_private.authority(p_org,auth.uid(),'history') or not(p_payload ? 'period') or jsonb_typeof(p_payload->'period')<>'string' then raise insufficient_privilege;end if;
  select * into target from uniion_private.message_participations where organization_id=p_org and conversation=cid and id=(p_payload->>'period')::uuid and left_at is null;
  if not found or target.user_id=auth.uid() or not uniion_private.message_current(p_org,cid,target.user_id) then raise insufficient_privilege;end if;
  target_id=target.id;
  if p_action='history_grant' then
   if not(p_payload ? 'messages') or p_payload-array['id','version','period','messages']<>'{}' or jsonb_typeof(p_payload->'messages')<>'array' or jsonb_array_length(p_payload->'messages') not between 1 and 100 then raise insufficient_privilege;end if;
   if exists(select 1 from jsonb_array_elements(p_payload->'messages')v where jsonb_typeof(v)<>'string' or v#>>'{}' !~ '^[1-9][0-9]{0,17}$') then raise insufficient_privilege;end if;
   select array_agg(v::bigint) into sequences from jsonb_array_elements_text(p_payload->'messages')v;
   if cardinality(sequences)<>(select count(distinct x) from unnest(sequences)x) then raise insufficient_privilege;end if;
   foreach s in array sequences loop
    if not uniion_private.message_visible(p_org,cid,s) or not exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=cid and seq=s) then raise insufficient_privilege;end if;
    insert into uniion_private.message_history_grants(organization_id,conversation,participation,message_seq,granted_by) values(p_org,cid,target.id,s,auth.uid()) on conflict(organization_id,conversation,participation,message_seq) where revoked_at is null do nothing;
   end loop;
   event_name='history_granted';changed=true;
  else
   if p_payload-array['id','version','period']<>'{}' then raise insufficient_privilege;end if;
   update uniion_private.message_history_grants set revoked_at=clock_timestamp() where organization_id=p_org and conversation=cid and participation=target.id and revoked_at is null;
   event_name='history_revoked';changed=true;
  end if;
 end if;
 if changed then
  update uniion_private.message_conversations set version=version+1 where organization_id=p_org and id=cid;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.'||event_name,jsonb_build_object('conversation',cid,'version',cv.version+1,'target',target_id,'messages',sequences,'members',members));
 end if;
 if p_action='leave' then return jsonb_build_object('left',true);end if;
 return uniion_private.message_conversation_json(p_org,cid);
end$$;
revoke all on function uniion_private.message_current(uuid,uuid,uuid),uniion_private.message_admin(uuid,uuid) from public,anon,authenticated;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
