begin;
-- Registration does not grant organizations access or commercial entitlements.
insert into uniion_private.module_catalog values('documents','Documents',true);
notify pgrst,'reload schema';commit;
