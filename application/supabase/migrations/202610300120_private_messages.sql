begin;
insert into uniion_private.module_catalog(id,name) values('messagerie','Messagerie');
create table uniion_private.message_conversations(
 organization_id uuid not null references public.uniion_organizations,
 id uuid not null default gen_random_uuid(), pair text not null,
 created_at timestamptz not null default clock_timestamp(), next_seq bigint not null default 0,
 primary key(organization_id,id),unique(organization_id,pair)
);
create table uniion_private.message_participations(
 organization_id uuid not null,conversation uuid not null,user_id uuid not null,
 id uuid not null default gen_random_uuid(),joined_at timestamptz not null default clock_timestamp(),
 organization_joined_at timestamptz not null,visible_from bigint not null default 1,left_at timestamptz,
 primary key(organization_id,conversation,id),
 foreign key(organization_id,conversation) references uniion_private.message_conversations(organization_id,id),
 foreign key(organization_id,user_id) references public.uniion_memberships(organization_id,user_id)
);
create unique index message_current_participant on uniion_private.message_participations(organization_id,conversation,user_id) where left_at is null;
create table uniion_private.messages(
 organization_id uuid not null,conversation uuid not null,seq bigint not null,
 id uuid not null default gen_random_uuid(),author uuid not null references auth.users,
 client_id uuid not null,body text not null check(length(btrim(body)) between 1 and 10000),
 created_at timestamptz not null default clock_timestamp(),reply_to bigint,
 primary key(organization_id,conversation,seq),unique(organization_id,conversation,id),
 unique(organization_id,conversation,author,client_id),
 foreign key(organization_id,conversation) references uniion_private.message_conversations(organization_id,id),
 foreign key(organization_id,conversation,reply_to) references uniion_private.messages(organization_id,conversation,seq)
);
alter table uniion_private.message_conversations enable row level security;
alter table uniion_private.message_participations enable row level security;
alter table uniion_private.messages enable row level security;
revoke all on uniion_private.message_conversations,uniion_private.message_participations,uniion_private.messages from public,anon,authenticated;
create function uniion_private.message_member(o uuid,c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.actor_member(o,auth.uid()) and exists(select 1 from uniion_private.message_participations p join public.uniion_memberships m on m.organization_id=p.organization_id and m.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null and p.organization_joined_at=m.joined_at)
$$;
create function uniion_private.message_visible(o uuid,c uuid,s bigint) returns boolean language sql stable security definer set search_path='' as $$
 select uniion_private.message_member(o,c) and exists(select 1 from uniion_private.message_participations p where p.organization_id=o and p.conversation=c and p.user_id=auth.uid() and p.left_at is null and s>=p.visible_from)
$$;
create function uniion_private.message_json(m uniion_private.messages) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',m.id,'seq',m.seq::text,'text',m.body,'mine',m.author=auth.uid(),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=m.organization_id and user_id=m.author),'Membre'),'created',m.created_at,'clientId',m.client_id,'reply',
 (select jsonb_build_object('seq',r.seq::text,'text',left(r.body,160),'who',coalesce((select name from uniion_private.identity_profiles where organization_id=r.organization_id and user_id=r.author),'Membre')) from uniion_private.messages r where r.organization_id=m.organization_id and r.conversation=m.conversation and r.seq=m.reply_to and uniion_private.message_visible(r.organization_id,r.conversation,r.seq)))
$$;
create function uniion_private.message_conversation_json(o uuid,c uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c,'name',coalesce((select ip.name from uniion_private.message_participations p left join uniion_private.identity_profiles ip on ip.organization_id=p.organization_id and ip.user_id=p.user_id where p.organization_id=o and p.conversation=c and p.user_id<>auth.uid() and p.left_at is null limit 1),'Membre'),'messages',coalesce((select jsonb_agg(uniion_private.message_json(m)) from (select * from uniion_private.messages where organization_id=o and conversation=c and uniion_private.message_visible(o,c,seq) order by seq desc limit 1)m),'[]'::jsonb))
$$;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cid uuid;other uuid;pair_key text;v_seq bigint;prior uniion_private.messages;msg uniion_private.messages;rows jsonb;cursor_value bigint;lim integer:=50;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' or p_action is null then raise insufficient_privilege;end if;
 if p_action in ('create','send') and not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='messagerie' and permission='write') then raise insufficient_privilege;end if;
 if p_action='participants' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',m.user_id,'name',coalesce(p.name,'Membre'),'role',coalesce(p.role,'Membre')) order by m.user_id) from public.uniion_memberships m left join uniion_private.identity_profiles p on p.organization_id=m.organization_id and p.user_id=m.user_id where m.organization_id=p_org and m.user_id<>auth.uid() and uniion_private.actor_member(p_org,m.user_id) and exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=m.user_id and module='messagerie' and permission='read')),'[]');
 elsif p_action='create' then
  if not(p_payload ? 'participant') or p_payload-'participant'<>'{}' or jsonb_typeof(p_payload->'participant')<>'string' then raise insufficient_privilege;end if;
  other=(p_payload->>'participant')::uuid;
  if other is null or other=auth.uid() or not uniion_private.actor_member(p_org,other) or not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=other and module='messagerie' and permission='read') then raise insufficient_privilege;end if;
  pair_key=least(auth.uid()::text,other::text)||':'||greatest(auth.uid()::text,other::text);
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||pair_key,0));
  select id into cid from uniion_private.message_conversations where organization_id=p_org and pair=pair_key;
  if cid is null then
   insert into uniion_private.message_conversations(organization_id,pair) values(p_org,pair_key) returning id into cid;
   insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at) select p_org,cid,user_id,joined_at from public.uniion_memberships where organization_id=p_org and user_id in(auth.uid(),other);
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.conversation_created',jsonb_build_object('conversation',cid));
  end if;
  if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  return uniion_private.message_conversation_json(p_org,cid);
 elsif p_action='list' then
  if p_payload-'before'<>'{}' or (p_payload ? 'before' and jsonb_typeof(p_payload->'before')<>'string') then raise insufficient_privilege;end if;
  return (select jsonb_build_object('rows',coalesce(jsonb_agg(uniion_private.message_conversation_json(p_org,q.id) order by q.id desc),'[]'),'next',case when count(*)=lim then min(q.id::text) end) from (select id from uniion_private.message_conversations where organization_id=p_org and uniion_private.message_member(p_org,id) and (not(p_payload ? 'before') or id<(p_payload->>'before')::uuid) order by id desc limit lim)q);
 elsif p_action in ('get','send') then
  if not(p_payload ? 'id') or jsonb_typeof(p_payload->'id')<>'string' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;
  if not uniion_private.message_member(p_org,cid) then raise insufficient_privilege;end if;
  if p_action='get' then
   if p_payload-array['id','before']<>'{}' or (p_payload ? 'before' and (jsonb_typeof(p_payload->'before')<>'string' or (p_payload->>'before') !~ '^[1-9][0-9]{0,17}$')) then raise insufficient_privilege;end if;
   select jsonb_agg(uniion_private.message_json(q) order by q.seq),case when count(*)=lim then min(q.seq) end into rows,cursor_value from (select * from uniion_private.messages where organization_id=p_org and conversation=cid and uniion_private.message_visible(p_org,cid,seq) and (not(p_payload ? 'before') or seq<(p_payload->>'before')::bigint) order by seq desc limit lim)q;
   return uniion_private.message_conversation_json(p_org,cid)||jsonb_build_object('messages',coalesce(rows,'[]'),'next',cursor_value::text);
  end if;
  if not(p_payload ?& array['id','clientId','text']) or p_payload-array['id','clientId','text','replyTo']<>'{}' or jsonb_typeof(p_payload->'text')<>'string' or length(btrim(p_payload->>'text')) not between 1 and 10000 or jsonb_typeof(p_payload->'clientId')<>'string' or (p_payload ? 'replyTo' and (jsonb_typeof(p_payload->'replyTo')<>'string' or (p_payload->>'replyTo') !~ '^[1-9][0-9]{0,17}$')) then raise insufficient_privilege;end if;
  perform 1 from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
  if p_payload ? 'replyTo' and not exists(select 1 from uniion_private.messages where organization_id=p_org and conversation=cid and seq=(p_payload->>'replyTo')::bigint and uniion_private.message_visible(p_org,cid,seq)) then raise insufficient_privilege;end if;
  select * into prior from uniion_private.messages where organization_id=p_org and conversation=cid and author=auth.uid() and client_id=(p_payload->>'clientId')::uuid;
  if found then
   if prior.body is distinct from (p_payload->>'text') or prior.reply_to is distinct from (p_payload->>'replyTo')::bigint or not uniion_private.message_visible(p_org,cid,prior.seq) then raise insufficient_privilege;end if;
   return uniion_private.message_json(prior);
  end if;
  update uniion_private.message_conversations set next_seq=next_seq+1 where organization_id=p_org and id=cid returning next_seq into v_seq;
  insert into uniion_private.messages(organization_id,conversation,seq,author,client_id,body,reply_to) values(p_org,cid,v_seq,auth.uid(),(p_payload->>'clientId')::uuid,p_payload->>'text',(p_payload->>'replyTo')::bigint) returning * into msg;
  insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'message.sent',jsonb_build_object('conversation',cid,'message',msg.id));
  return uniion_private.message_json(msg);
 end if;
 raise insufficient_privilege;
end $$;
revoke all on function uniion_private.message_member(uuid,uuid),uniion_private.message_visible(uuid,uuid,bigint),uniion_private.message_json(uniion_private.messages),uniion_private.message_conversation_json(uuid,uuid) from public,anon,authenticated;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
