begin;
do $$declare d text;begin
 d=pg_get_functiondef('uniion_private.message_json(uniion_private.messages)'::regprocedure);
 d=replace(d,'''size'',a.size,''canWrite''','''size'',a.size,''sha256'',a.sha256,''preview'',uniion_private.attachment_preview(a.id,auth.uid()),''uploaded'',exists(select 1 from storage.objects where bucket_id=''uniion-private'' and name=a.object_name),''canWrite''');execute d;
end$$;
notify pgrst,'reload schema';commit;
