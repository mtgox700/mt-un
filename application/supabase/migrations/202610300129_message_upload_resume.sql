begin;
-- An interrupted upload may be resumed after the original short insertion window.
-- Only the same checked content/key can refresh an object that does not exist yet.
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_message_file_prepare(uuid,uuid,uuid,text,text,integer,text)'::regprocedure);
 d=replace(d,$code$ return jsonb_build_object('id',a.id,'path',a.object_name,'status',a.scan_status$code$, $code$ if uniion_private.case_file_trashed(a.id) then raise insufficient_privilege;end if;
 if not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=a.object_name) then update public.uniion_attachments set created_at=clock_timestamp() where id=a.id;end if;
 return jsonb_build_object('id',a.id,'path',a.object_name,'status',a.scan_status$code$);execute d;
end$$;
notify pgrst,'reload schema';commit;
