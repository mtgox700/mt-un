begin;
alter table public.uniion_attachments drop constraint uniion_attachments_mime_check;
alter table public.uniion_attachments add constraint uniion_attachments_mime_check check(mime in ('text/plain','application/pdf','image/png','image/jpeg','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
update storage.buckets set allowed_mime_types=array['text/plain','application/pdf','image/png','image/jpeg','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'] where id='uniion-private';
notify pgrst,'reload schema';
commit;
