begin;
-- Historical records may have manual dues without a schedule. Coverage remains audited.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_adherents_before_ending(uuid,text,jsonb)'::regprocedure);
 d=replace(d,E' if not found then raise insufficient_privilege;end if;\n select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;',E' select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>''id'')::uuid for update;');
 execute d;
 d=pg_get_functiondef('public.uniion_adherents_before_coverage_correction(uuid,text,jsonb)'::regprocedure);
 d=replace(d,E'  if not found then raise insufficient_privilege;end if;\n  select * into a from uniion_private.adherents where organization_id=p_org and id=s.adherent_id for update;',E'  if not found and p_action<>''schedule_coverage'' then raise insufficient_privilege;end if;\n  select * into a from uniion_private.adherents where organization_id=p_org and id=(p_payload->>''id'')::uuid for update;\n  if not found then raise insufficient_privilege;end if;');
 execute d;
end$$;
notify pgrst,'reload schema';
commit;
