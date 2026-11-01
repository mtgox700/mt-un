begin;
-- Dossiers use the existing resource grants, never organization membership alone.
create table uniion_private.cases (
 organization_id uuid not null, id uuid primary key, status text not null default 'todo' check(status in ('todo','doing','done')),
 tag text not null, due text not null default '', owner uuid not null, description text not null,
 foreign key(organization_id,id) references public.uniion_resources(organization_id,id),
 foreign key(organization_id,owner) references public.uniion_memberships(organization_id,user_id)
);
create table uniion_private.case_history (
 id bigint generated always as identity primary key, organization_id uuid not null, resource_id uuid not null,
 actor uuid not null, happened_at timestamptz not null default now(), title text not null, body text not null,
 foreign key(organization_id,resource_id) references public.uniion_resources(organization_id,id)
);
alter table uniion_private.cases enable row level security;
alter table uniion_private.case_history enable row level security;
revoke all on uniion_private.cases,uniion_private.case_history from public,anon,authenticated;
create function uniion_private.case_json(o uuid,rid uuid) returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('id',r.id,'version',r.version,'title',r.title,'tag',c.tag,'due',c.due,'status',c.status,'owner',coalesce((select name from uniion_private.identity_profiles where organization_id=o and user_id=c.owner),'Membre habilité'),'desc',left(c.description,180),'long',c.description,'ask',r.title,'canWrite',uniion_private.actor_resource(o,rid,auth.uid(),true),'timeline',coalesce((select jsonb_agg(jsonb_build_object('date',to_char(h.happened_at at time zone 'Europe/Paris','DD/MM/YYYY HH24:MI'),'title',h.title,'body',h.body) order by h.id) from uniion_private.case_history h where h.organization_id=o and h.resource_id=rid),'[]')) from public.uniion_resources r join uniion_private.cases c on c.id=r.id and c.organization_id=r.organization_id where r.organization_id=o and r.id=rid
$$;
create function public.uniion_cases(p_org uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare rid uuid;r public.uniion_resources;v jsonb;t text;bodytext text;
begin
 perform public.uniion_module_use(p_org,'dossiers');
 if jsonb_typeof(p_payload) is distinct from 'object' then raise insufficient_privilege;end if;
 if p_action='list' and p_payload='{}' then
 return jsonb_build_object('rows',coalesce((select jsonb_agg(uniion_private.case_json(p_org,c.id) order by r.created_at desc) from uniion_private.cases c join public.uniion_resources r on r.id=c.id where c.organization_id=p_org and uniion_private.actor_resource(p_org,c.id,auth.uid(),false)),'[]'));
 end if;
 if p_action='create' then
 if not exists(select 1 from public.uniion_permissions where organization_id=p_org and user_id=auth.uid() and module='dossiers' and permission='create') or p_payload-ARRAY['title','long','tag','due']<>'{}' then raise insufficient_privilege;end if;
 else
 rid=(p_payload->>'id')::uuid;
 select * into r from public.uniion_resources where organization_id=p_org and id=rid and module='dossiers' for update;
 if not found or not exists(select 1 from uniion_private.cases where id=rid and organization_id=p_org) or not uniion_private.actor_resource(p_org,rid,auth.uid(),p_action<>'get') then raise insufficient_privilege;end if;
 if p_action='get' and p_payload-ARRAY['id']='{}' then return uniion_private.case_json(p_org,rid);end if;
 if (p_payload->>'version')::int is distinct from r.version then raise insufficient_privilege;end if;
 end if;
 if p_action in ('create','edit') then
 if p_action='edit' and p_payload-ARRAY['id','version','title','long','due']<>'{}' then raise insufficient_privilege;end if;
 if jsonb_typeof(p_payload->'title') is distinct from 'string' or length(btrim(p_payload->>'title')) not between 1 and 200 or jsonb_typeof(p_payload->'long') is distinct from 'string' or length(p_payload->>'long')>5000 or jsonb_typeof(p_payload->'due') is distinct from 'string' or length(p_payload->>'due')>80 then raise insufficient_privilege;end if;
 if p_action='create' then
 if p_payload->>'tag' is null or p_payload->>'tag' not in ('Juridique','Harcèlement','CSSCT','ASC / Noël','Négociation') then raise insufficient_privilege;end if;
 insert into public.uniion_resources(organization_id,module,title,body) values(p_org,'dossiers',btrim(p_payload->>'title'),jsonb_build_object('text',p_payload->>'long')) returning id into rid;
 insert into uniion_private.cases(organization_id,id,tag,due,owner,description) values(p_org,rid,p_payload->>'tag',p_payload->>'due',auth.uid(),p_payload->>'long');
 insert into public.uniion_resource_grants values(p_org,rid,auth.uid(),true,false,'infinity',null);
 t='Dossier créé';bodytext='Création enregistrée.';
 else
 update public.uniion_resources set title=btrim(p_payload->>'title'),body=jsonb_build_object('text',p_payload->>'long'),version=version+1 where id=rid;
 update uniion_private.cases set description=p_payload->>'long',due=p_payload->>'due' where id=rid;
 t='Dossier modifié';bodytext='Intitulé, description ou échéance mis à jour.';
 end if;
 elsif p_action='status' then
 if p_payload-ARRAY['id','version','status']<>'{}' or p_payload->>'status' is null or p_payload->>'status' not in ('todo','doing','done') then raise insufficient_privilege;end if;
 update uniion_private.cases set status=p_payload->>'status' where id=rid;
 update public.uniion_resources set version=version+1 where id=rid;
 t='État modifié';bodytext=case p_payload->>'status' when 'todo' then 'À faire' when 'doing' then 'En cours' else 'Terminé' end;
 elsif p_action='note' then
 if p_payload-ARRAY['id','version','text']<>'{}' or jsonb_typeof(p_payload->'text') is distinct from 'string' or length(btrim(p_payload->>'text')) not between 1 and 5000 then raise insufficient_privilege;end if;
 update public.uniion_resources set version=version+1 where id=rid;t='Note ajoutée';bodytext=btrim(p_payload->>'text');
 else raise insufficient_privilege;
 end if;
 insert into uniion_private.case_history(organization_id,resource_id,actor,title,body) values(p_org,rid,auth.uid(),t,bodytext);
 insert into public.uniion_security_events(organization_id,actor,event,details) values(p_org,auth.uid(),'case.'||p_action,jsonb_build_object('resource',rid));
 return uniion_private.case_json(p_org,rid);
end$$;
revoke all on function uniion_private.case_json(uuid,uuid),public.uniion_cases(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.uniion_cases(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
