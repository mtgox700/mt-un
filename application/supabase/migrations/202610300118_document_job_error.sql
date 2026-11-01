begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_document_job_finish(uuid,uuid,jsonb,text)'::regprocedure);
 d=replace(d,'''pdf_overflow'',''unavailable''','''pdf_overflow'',''unavailable'',''pdf_content_missing''');execute d;
end$$;
notify pgrst,'reload schema';commit;
