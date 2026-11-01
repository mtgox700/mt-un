begin;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_work(uuid,uuid,text,jsonb)'::regprocedure);
 definition=replace(definition,$old$doc=p_payload->'document';$old$,$new$doc=p_payload->'document';if octet_length(doc::text)>8388608 then raise insufficient_privilege;end if;$new$);
 definition=replace(definition,$old$item->>'text' ~ '^(https?:|data:)'$old$,$new$ltrim(item->>'text', E' \n\t\r') ~ '^(https?:|data:)'$new$);
 execute definition;
end;$patch$;
commit;
