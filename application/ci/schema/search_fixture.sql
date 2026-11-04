-- Jeu fictif de messagerie pour check_search_equivalence.py (R19) : conversation visible de 5 000 messages,
-- conversation visible à partir du rang 100, conversation non visible, transferts depuis les deux.
begin;set local session_replication_role=replica;
insert into auth.users(id,email) values('60000000-0000-4000-8000-000000000001','lectrice@example.invalid'),('60000000-0000-4000-8000-000000000002','autre@example.invalid');
insert into auth.sessions(id,user_id,aal) values('61000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','aal1');
insert into public.uniion_organizations(id,name) values('62000000-0000-4000-8000-000000000001','Org');
insert into public.uniion_memberships(organization_id,user_id,joined_at) values('62000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','2026-01-01'),('62000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000002','2026-01-01');
insert into public.uniion_module_access values('62000000-0000-4000-8000-000000000001','messagerie',true,true,'included','2099-01-01');
insert into uniion_private.module_entitlements(organization_id,module,kind,starts,ends,reference,reason) values('62000000-0000-4000-8000-000000000001','messagerie','paid','2026-01-01','2099-01-01','FICTIF','Recette');
insert into public.uniion_permissions values('62000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','messagerie','read');
insert into uniion_private.message_conversations(organization_id,id,pair,kind,title) values
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001','g1','group','Bureau syndical'),
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000002','g2','group','Négociation budget'),
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000003','g3','group','Secret');
insert into uniion_private.message_participations(organization_id,conversation,user_id,organization_joined_at,visible_from) values
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','2026-01-01',1),
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000002','60000000-0000-4000-8000-000000000001','2026-01-01',100),
 ('62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000002','2026-01-01',1);
insert into uniion_private.messages(organization_id,conversation,seq,author,client_id,body)
 select '62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001',i,'60000000-0000-4000-8000-000000000001',gen_random_uuid(),
  case when i%97=0 then 'Point budget '||i when i%50=0 then 'transfert' else 'Message ordinaire '||i end from generate_series(1,5000) i;
insert into uniion_private.messages(organization_id,conversation,seq,author,client_id,body)
 select '62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000002',i,'60000000-0000-4000-8000-000000000001',gen_random_uuid(),case when i%3=0 then 'Budget caché ou visible '||i else 'Texte '||i end from generate_series(1,200) i;
insert into uniion_private.messages(organization_id,conversation,seq,author,client_id,body)
 select '62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000003',i,'60000000-0000-4000-8000-000000000002',gen_random_uuid(),'Budget secret '||i from generate_series(1,50) i;
-- Transferts dans g1 (messages « transfert ») : un sur deux depuis g2 (visible à partir de 100), un sur deux depuis g3 (non visible).
insert into uniion_private.message_forwards(organization_id,conversation,seq,source_conversation,source_seq)
 select '62000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001',i,
  case when (i/50)%2=0 then '63000000-0000-4000-8000-000000000002'::uuid else '63000000-0000-4000-8000-000000000003'::uuid end,
  case when (i/50)%2=0 then ((i/50)%200)+1 else ((i/50)%50)+1 end
 from generate_series(50,5000,50) i where i%97<>0;

insert into auth.mfa_factors(id,user_id,status,factor_type) values('64000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','verified','totp');
update auth.sessions set aal='aal2',factor_id='64000000-0000-4000-8000-000000000001' where id='61000000-0000-4000-8000-000000000001';
insert into uniion_private.trusted_mfa_factors(factor_id,user_id) values('64000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001');
commit;analyze;
