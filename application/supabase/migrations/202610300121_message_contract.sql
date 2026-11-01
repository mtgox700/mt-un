begin;
-- Profile labels use role_label in the identity schema.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_messaging(uuid,text,jsonb)'::regprocedure);
 d=replace(d,'coalesce(p.role,','coalesce(p.role_label,');
 d=replace(d,'length(btrim(p_payload->>''text'')) not between 1 and 10000','(length(btrim(p_payload->>''text'')) not between 1 and 10000 or length(p_payload->>''text'')>10000)');
 execute d;
end$$;
alter table uniion_private.messages add constraint messages_body_length check(length(body)<=10000);
notify pgrst,'reload schema';commit;
