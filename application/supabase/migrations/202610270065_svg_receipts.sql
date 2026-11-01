begin;
do $patch$
declare definition text;
begin
 definition=pg_get_functiondef('public.uniion_agenda_image_receipt(uuid,text,text)'::regprocedure);
 definition=replace(definition,'(png|jpeg);base64','(png|jpeg|svg\+xml);base64');
 execute definition;
end;$patch$;
commit;
