begin;
-- Keep the private vault MIME allowlist; only the checked PCM profile is added.
update storage.buckets set allowed_mime_types=array_append(allowed_mime_types,'audio/wav')
where id='uniion-private' and allowed_mime_types is not null and not ('audio/wav'=any(allowed_mime_types));
commit;
