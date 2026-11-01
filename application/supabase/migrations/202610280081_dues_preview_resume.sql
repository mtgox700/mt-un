begin;
create or replace function public.uniion_dues_evidence(p_org uuid,p_payment uuid,p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare f uniion_private.dues_evidence;aid uuid;can_download boolean;
begin
 perform public.uniion_module_use(p_org,'adherents');
 if not uniion_private.adherent_permission(p_org,'cotisations','read') or not exists(select 1 from uniion_private.dues_payments where organization_id=p_org and id=p_payment) or jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 can_download=uniion_private.authority(p_org,auth.uid(),'download');
 if p_action='prepare' then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or not(p_payload ?& array['filename','mime','size','sha256','request_id']) or p_payload-array['filename','mime','size','sha256','request_id']<>'{}' then raise insufficient_privilege;end if;
  perform 1 from uniion_private.dues_payments where id=p_payment for update;
  select * into f from uniion_private.dues_evidence where organization_id=p_org and request_id=(p_payload->>'request_id')::uuid;
  if found then
   if f.payment_id<>p_payment or f.filename is distinct from p_payload->>'filename' or f.mime is distinct from p_payload->>'mime' or f.size is distinct from (p_payload->>'size')::int or f.sha256 is distinct from p_payload->>'sha256' then raise insufficient_privilege;end if;
  else
   if (select count(*) from uniion_private.dues_evidence where payment_id=p_payment)>=20 then raise insufficient_privilege;end if;
   aid=gen_random_uuid();
   insert into uniion_private.dues_evidence(id,organization_id,payment_id,filename,mime,size,sha256,path,actor,request_id) values(aid,p_org,p_payment,p_payload->>'filename',p_payload->>'mime',(p_payload->>'size')::int,p_payload->>'sha256',p_org::text||'/'||p_payment::text||'/'||aid::text,auth.uid(),(p_payload->>'request_id')::uuid) returning * into f;
   insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.evidence.requested',jsonb_build_object('payment',p_payment,'file',f.id));
  end if;
  return to_jsonb(f);
 elsif p_action='resume' then
  if not uniion_private.adherent_permission(p_org,'cotisations','write') or p_payload-array['id']<>'{}' then raise insufficient_privilege;end if;
  select * into f from uniion_private.dues_evidence where id=(p_payload->>'id')::uuid and payment_id=p_payment and organization_id=p_org and status in ('pending','clean');
  if not found then raise insufficient_privilege;end if;
  if f.status='pending' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'dues.evidence.resume_requested',jsonb_build_object('file',f.id));end if;
  return to_jsonb(f);
 elsif p_action in ('get','preview') then
  if (p_action='get' and not can_download) or p_payload-array['id','audit']<>'{}' then raise insufficient_privilege;end if;
  select * into f from uniion_private.dues_evidence where id=(p_payload->>'id')::uuid and payment_id=p_payment and organization_id=p_org and status='clean';
  if not found then raise insufficient_privilege;end if;
  if p_payload->>'audit'='true' then insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),case when p_action='preview' then 'dues.evidence.previewed' else 'dues.evidence.downloaded' end,jsonb_build_object('payment',p_payment,'file',f.id));end if;
  return to_jsonb(f);
 elsif p_action<>'list' or p_payload<>'{}' then raise insufficient_privilege;end if;
 return jsonb_build_object('write',uniion_private.adherent_permission(p_org,'cotisations','write'),'download',can_download,'files',coalesce((select jsonb_agg(jsonb_build_object('id',id,'filename',filename,'mime',mime,'status',status,'createdAt',created_at,'size',size) order by created_at,id) from uniion_private.dues_evidence where organization_id=p_org and payment_id=p_payment),'[]'));
exception when invalid_text_representation or check_violation or numeric_value_out_of_range then raise insufficient_privilege;
end $$;
create or replace function public.uniion_dues_evidence_finish(p_id uuid,p_sha text,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare f uniion_private.dues_evidence;
begin
 if not uniion_private.is_scanner() or p_status not in ('clean','blocked') or p_status is null then raise insufficient_privilege;end if;
 select * into f from uniion_private.dues_evidence where id=p_id for update;
 if not found or f.sha256 is distinct from p_sha or (p_status='clean' and not exists(select 1 from storage.objects where bucket_id='uniion-private' and name=f.path and (metadata->>'size')::bigint=f.size)) then raise insufficient_privilege;end if;
 if f.status='blocked' then raise insufficient_privilege;end if;
 if f.status='clean' and p_status='clean' then return;end if;
 update uniion_private.dues_evidence set status=p_status where id=p_id;
 insert into public.uniion_security_events(organization_id,actor,event,details) values(f.organization_id,auth.uid(),'dues.evidence.scanned',jsonb_build_object('file',f.id,'status',p_status));
end $$;
notify pgrst,'reload schema';
commit;
