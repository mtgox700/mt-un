begin;
-- Preserve the validated mobile contact template as plain text data.
create or replace function uniion_private.business_payload(m text,d jsonb) returns jsonb language plpgsql set search_path='' as $$
declare fields text[];item jsonb;
begin
 fields=case m
 when 'reunions' then array['title','type','date','ordre','markers','transcript','minutes','participants']
 when 'communication' then array['title','date','fmt','canal','obj','ton','sujet','content','items']
 when 'mobile' then array['title','type','aud','blocks','pushOn','push','subject']
 when 'formations' then array['title','theme','dur','level','role','goal','modules','intro','retenir','sources','cur','done','ans','ex','fb','chat','finished']
 when 'sondages' then array['title','question','options','description','mode','results','respondents']
 when 'intranet' then array['title','blocks','description','type']
 when 'reporting' then array['title','period','indicators','description']
 when 'raccourcis' then array['title','items','description'] end;
 if fields is null or jsonb_typeof(d) is distinct from 'object' or d-fields<>'{}' or jsonb_typeof(d->'title') is distinct from 'string' or length(btrim(d->>'title')) not between 1 and 200 or octet_length(d::text)>100000 then raise insufficient_privilege;end if;
 -- These values are data only. Neither status, audience grants nor approval can be supplied here.
 if exists(select 1 from jsonb_each(d) where key=any(array['type','date','fmt','canal','obj','ton','sujet','aud','push','subject','theme','level','role','goal','intro','sources','question','description','mode','period']) and (jsonb_typeof(value)<>'string' or length(value#>>'{}')>12000)) then raise insufficient_privilege;end if;
 if exists(select 1 from jsonb_each(d) where key=any(array['ordre','markers','participants','items','blocks','modules','retenir','done','chat','options','indicators']) and (jsonb_typeof(value)<>'array' or jsonb_array_length(value)>100)) then raise insufficient_privilege;end if;
 if d ? 'blocks' then
  for item in select value from jsonb_array_elements(d->'blocks') loop
   if jsonb_typeof(item)<>'array' or jsonb_array_length(item)<>2 or item->>0 not in ('h','p','info','btn','contact') or jsonb_typeof(item->1)<>'string' or length(item->>1)>12000 then raise insufficient_privilege;end if;
  end loop;
 end if;
 -- Poll answers/results are owned by the voting subsystem, never arbitrary record saves.
 if m='sondages' and (d ? 'results' or d ? 'respondents') then raise insufficient_privilege;end if;
 return d;
end$$;
notify pgrst,'reload schema';commit;
