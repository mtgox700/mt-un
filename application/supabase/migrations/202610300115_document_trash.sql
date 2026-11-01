begin;
-- Reuse the existing reversible super-admin approval circuit, scoped to Documents.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_case_disposal(uuid,text,uuid,uuid,uuid,integer,text)'::regprocedure);
 d=replace(d,'FUNCTION public.uniion_case_disposal','FUNCTION public.uniion_document_disposal');
 d=replace(d,$str$'dossiers'$str$,$str$'documents'$str$);
 d=replace(d,$str$if p_action in ('admin_list'$str$,$str$if p_link is not null then raise insufficient_privilege;end if;
 if p_action in ('admin_list'$str$);
 d=replace(d,$str$where t.organization_id=p_org and$str$, $str$where r.module='documents' and t.organization_id=p_org and$str$);
 d=replace(d,'set version=version+1 where','set version=version+1,body=body where');
 execute d;
end$$;
revoke all on function public.uniion_document_disposal(uuid,text,uuid,uuid,uuid,integer,text) from public,anon;
grant execute on function public.uniion_document_disposal(uuid,text,uuid,uuid,uuid,integer,text) to authenticated;
-- The shared administrator queue already includes these requests; label their module.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_case_disposal(uuid,text,uuid,uuid,uuid,integer,text)'::regprocedure);
 d=replace(d,$str$case when link is null then 'Dossier' else 'Référence' end$str$,$str$case when exists(select 1 from uniion_private.documents d where d.id=resource_id) then 'Document' when link is null then 'Dossier' else 'Référence' end$str$);
 d=replace(d,'set version=version+1 where','set version=version+1,body=body where');execute d;
end$$;
notify pgrst,'reload schema';commit;
