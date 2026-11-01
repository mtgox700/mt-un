begin;
do $patch$
declare definition text;before_text text;after_text text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_work(uuid,uuid,text,jsonb)'::regprocedure);
 before_text=$old$jsonb_build_object('id',ident||'-3','type','h2','text','Points à examiner'),jsonb_build_object('id',ident||'-4','type','p','text',coalesce(nullif(e.data->>'notes',''),'À compléter'))$old$;
 after_text=$new$jsonb_build_object('id',ident||'-3','type','h2','text','Participants'),jsonb_build_object('id',ident||'-4','type','p','text','À compléter'),jsonb_build_object('id',ident||'-5','type','h2','text','Points à examiner'),jsonb_build_object('id',ident||'-6','type','p','text',coalesce(nullif(e.data->>'notes',''),'À compléter'))$new$;
 if position(before_text in definition)=0 then raise exception 'Template missing';end if;
 execute replace(definition,before_text,after_text);
end;$patch$;
commit;
