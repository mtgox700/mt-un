begin;
-- Plain messages have no dynamic file, forward or reply ACL. Their visible
-- fields can be hashed directly after message_visible; rich references keep
-- the complete authorized projection so revocations still change revisions.
create function uniion_private.message_revision(o uuid,c uuid) returns text language sql stable security definer set search_path='' as $$
 select md5(coalesce(string_agg(case
  when m.reply_to is null
   and not exists(select 1 from uniion_private.message_files f where f.organization_id=o and f.conversation=c and f.seq=m.seq)
   and not exists(select 1 from uniion_private.message_forwards f where f.organization_id=o and f.conversation=c and f.seq=m.seq)
  then jsonb_build_array(m.id,m.seq::text,m.body,m.author=auth.uid(),coalesce(ip.name,'Membre'),m.created_at,m.client_id)::text
  else uniion_private.message_json(m)::text end,',' order by m.seq),''))
 from uniion_private.messages m left join uniion_private.identity_profiles ip on ip.organization_id=m.organization_id and ip.user_id=m.author
 where m.organization_id=o and m.conversation=c and uniion_private.message_visible(o,c,m.seq)
$$;
revoke all on function uniion_private.message_revision(uuid,uuid) from public,anon,authenticated;
do $$declare d text;old text;begin
 d=pg_get_functiondef('public.uniion_messaging_before_mark_all(uuid,text,jsonb)'::regprocedure);
 old='coalesce((select string_agg(uniion_private.message_json(m)::text,'','' order by seq) from uniion_private.messages m where m.organization_id=p_org and m.conversation=c.id and uniion_private.message_visible(p_org,c.id,m.seq)),'''')';
 if strpos(d,old)=0 then raise exception 'Expected live revision definition missing';end if;
 execute replace(d,old,'uniion_private.message_revision(p_org,c.id)');
end$$;
notify pgrst,'reload schema';commit;
