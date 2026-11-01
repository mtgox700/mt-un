begin;
create table uniion_private.message_reads(
 organization_id uuid not null,conversation uuid not null,participation uuid not null,seq bigint not null,read_at timestamptz not null default clock_timestamp(),
 primary key(organization_id,conversation,participation),
 foreign key(organization_id,conversation,participation) references uniion_private.message_participations(organization_id,conversation,id),
 foreign key(organization_id,conversation,seq) references uniion_private.messages(organization_id,conversation,seq)
);
alter table uniion_private.message_reads enable row level security;
revoke all on uniion_private.message_reads from public,anon,authenticated;
create function uniion_private.message_unread(o uuid,c uuid) returns bigint language sql stable security definer set search_path='' as $$
 select count(*) from uniion_private.messages m where m.organization_id=o and m.conversation=c and m.author<>auth.uid() and uniion_private.message_visible(o,c,m.seq) and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=o and r.conversation=c and p.user_id=auth.uid() and p.left_at is null),0)
$$;
alter function uniion_private.message_conversation_json(uuid,uuid) rename to message_conversation_before_live;
create function uniion_private.message_conversation_json(o uuid,c uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select uniion_private.message_conversation_before_live(o,c)||jsonb_build_object('unread',uniion_private.message_unread(o,c))
$$;
alter function public.uniion_messaging(uuid,text,jsonb) rename to uniion_messaging_before_live;
revoke all on function public.uniion_messaging_before_live(uuid,text,jsonb) from public,anon,authenticated;
create function public.uniion_messaging(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cid uuid;s bigint;p uuid;rows jsonb;state jsonb;
begin
 perform public.uniion_module_use(p_org,'messagerie');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='read' then
  if not(p_payload ?& array['id','seq']) or p_payload-array['id','seq']<>'{}' or jsonb_typeof(p_payload->'seq')<>'string' or (p_payload->>'seq')!~'^[1-9][0-9]{0,17}$' then raise insufficient_privilege;end if;
  cid=(p_payload->>'id')::uuid;s=(p_payload->>'seq')::bigint;
  perform 1 from uniion_private.message_conversations where organization_id=p_org and id=cid for update;
  if not uniion_private.message_visible(p_org,cid,s) then raise insufficient_privilege;end if;
  select id into p from uniion_private.message_participations where organization_id=p_org and conversation=cid and user_id=auth.uid() and left_at is null;
  insert into uniion_private.message_reads values(p_org,cid,p,s,clock_timestamp()) on conflict(organization_id,conversation,participation) do update set seq=greatest(message_reads.seq,excluded.seq),read_at=case when excluded.seq>message_reads.seq then excluded.read_at else message_reads.read_at end;
  return jsonb_build_object('unread',uniion_private.message_unread(p_org,cid));
 elsif p_action='live' then
  if p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
  -- Only the caller's authorized projection influences the opaque resume cursor.
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'unread',uniion_private.message_unread(p_org,c.id),'revision',md5(uniion_private.message_conversation_json(p_org,c.id)::text||coalesce((select string_agg(uniion_private.message_json(m)::text,',' order by seq) from uniion_private.messages m where m.organization_id=p_org and m.conversation=c.id and uniion_private.message_visible(p_org,c.id,m.seq)),''))) order by c.id),'[]') into rows from uniion_private.message_conversations c where c.organization_id=p_org and uniion_private.message_member(p_org,c.id);
  state=jsonb_build_object('conversations',rows);
  if p_payload ? 'id' then
   cid=(p_payload->>'id')::uuid;
   if uniion_private.message_member(p_org,cid) then state=state||jsonb_build_object('thread',public.uniion_messaging_before_live(p_org,'get',jsonb_build_object('id',cid)));else state=state||jsonb_build_object('thread',null);end if;
  end if;
  return state||jsonb_build_object('cursor',md5(state::text));
 elsif p_action='notices' then
  if p_payload<>'{}' then raise insufficient_privilege;end if;
  return coalesce((select jsonb_agg(x.notice order by x.created desc,x.id) from (select m.id,m.created_at created,jsonb_build_object('id',m.id,'conversation',m.conversation,'seq',m.seq::text,'title',uniion_private.message_conversation_json(p_org,m.conversation)->>'name','created',m.created_at) notice from uniion_private.messages m where m.organization_id=p_org and m.author<>auth.uid() and uniion_private.message_visible(p_org,m.conversation,m.seq) and m.seq>coalesce((select r.seq from uniion_private.message_reads r join uniion_private.message_participations p on p.organization_id=r.organization_id and p.conversation=r.conversation and p.id=r.participation where r.organization_id=p_org and r.conversation=m.conversation and p.user_id=auth.uid() and p.left_at is null),0) order by m.created_at desc,m.id limit 50)x),'[]');
 end if;
 return public.uniion_messaging_before_live(p_org,p_action,p_payload);
end$$;
revoke all on function uniion_private.message_unread(uuid,uuid),uniion_private.message_conversation_json(uuid,uuid),uniion_private.message_conversation_before_live(uuid,uuid) from public,anon,authenticated;
revoke all on function public.uniion_messaging(uuid,text,jsonb) from public,anon;
grant execute on function public.uniion_messaging(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';commit;
