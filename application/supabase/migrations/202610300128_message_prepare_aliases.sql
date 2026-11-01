begin;
do $$declare d text;begin
 d=pg_get_functiondef('public.uniion_message_file_prepare(uuid,uuid,uuid,text,text,integer,text)'::regprocedure);
 d=replace(d,'select 1 from uniion_private.messages m where m.organization_id=p_org and m.conversation=p_conversation and m.author=auth.uid() and m.client_id=p_client and not exists(select 1 from uniion_private.message_files f where f.organization_id=m.organization_id and f.conversation=m.conversation and f.seq=m.seq)','select 1 from uniion_private.messages mx where mx.organization_id=p_org and mx.conversation=p_conversation and mx.author=auth.uid() and mx.client_id=p_client and not exists(select 1 from uniion_private.message_files fx where fx.organization_id=mx.organization_id and fx.conversation=mx.conversation and fx.seq=mx.seq)');
 execute d;
end$$;
notify pgrst,'reload schema';commit;
