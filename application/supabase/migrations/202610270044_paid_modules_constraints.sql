begin;
alter table uniion_private.module_entitlements add constraint entitlement_evidence_required check ((kind='paid' and reference is not null and length(btrim(reference))>0) or (kind='commercial' and reason is not null and length(btrim(reason)) between 1 and 240 and created_by is not null));
commit;
