begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_document_disposal(uuid,text,uuid,uuid,uuid,integer,text)'::regprocedure);
 d=replace(d,'where entry.organization_id=p_org and','where r.module=''documents'' and entry.organization_id=p_org and');
 d=replace(d,'''Dossier · ''','''Document · ''');execute d;
 d=pg_get_functiondef('public.uniion_case_disposal(uuid,text,uuid,uuid,uuid,integer,text)'::regprocedure);
 d=replace(d,'where entry.organization_id=p_org and','where r.module=''dossiers'' and entry.organization_id=p_org and');execute d;
end$$;
notify pgrst,'reload schema';commit;
