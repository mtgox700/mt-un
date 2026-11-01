begin;
-- Existing drafts get a new version: former approvals and snapshots remain untouched.
create trigger agenda_document_charter_upgrade before update on uniion_private.agenda_documents for each row when (not (new.document ? 'charte')) execute function uniion_private.agenda_document_charter();
update uniion_private.agenda_documents set version=version+1,updated_at=now() where not (document ? 'charte');
drop trigger agenda_document_charter_upgrade on uniion_private.agenda_documents;
commit;
