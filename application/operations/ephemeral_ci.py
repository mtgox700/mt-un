"""Fresh local Supabase integration target. No source credentials, backups or data."""
import pathlib,sys,secrets,subprocess,time,json,uuid
import backup_restore as b,restore_services as services
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 name='uniion-ci-'+secrets.token_hex(4);result={'container':name,'file_volume':name+'-files','services':[]};credentials={};checks=[]
 def check(label,ok):
  checks.append({'test':label,'ok':bool(ok)})
  if not ok:raise RuntimeError('CI check failed: '+label)
 try:
  b.run(['docker','run','-d','--name',name,'--network','none','--label','uniion.ephemeral-ci=true','-e','POSTGRES_HOST_AUTH_METHOD=trust',b.IMAGE])
  for _ in range(120):
   try:b.sql('select 1',name);break
   except RuntimeError:time.sleep(.5)
  b.sql('CREATE DATABASE restored TEMPLATE template0',name)
  b.sql('CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin; CREATE SCHEMA storage AUTHORIZATION supabase_storage_admin; CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions; ALTER SCHEMA public OWNER TO postgres; GRANT USAGE ON SCHEMA public TO anon,authenticated,service_role;',name,'restored')
  b.run(['docker','volume','create',result['file_volume']])
  client=services.start(result,credentials,fresh=True)
  ready=False
  for _ in range(120):
   try:
    ready=b.sql("select (to_regclass('auth.users') is not null and to_regclass('storage.objects') is not null)::text",name,'restored')=='true'
    if ready and services.request(client,9999,'/health')['status']==200 and services.request(client,5000,'/status')['status']==200:break
   except RuntimeError:pass
   time.sleep(.5)
  check('fresh_auth_storage_ready',ready and services.request(client,5000,'/status')['status']==200)
  # Fresh infrastructure grants: operations remain constrained by Storage RLS policies.
  b.sql('GRANT USAGE ON SCHEMA storage TO anon,authenticated,service_role; GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated; GRANT SELECT ON storage.buckets TO authenticated;',name,'restored')
  migrations=sorted((ROOT/'supabase/baseline').glob('*.sql'))+sorted((ROOT/'supabase/migrations').glob('*.sql'))
  for migration in migrations:b.sql(migration.read_text(),name,'restored')
  check('all_24_migrations_from_empty_database',len(migrations)==24)
  b.sql("NOTIFY pgrst, 'reload schema'",name,'restored');time.sleep(1)
  accounts=[]
  for index in range(2):
   password=secrets.token_urlsafe(32);email=f'ci-{index}@uniion-local.example'
   made=services.request(client,9999,'/admin/users',credentials['service_token'],{'email':email,'password':password,'email_confirm':True})
   check('fictional_user_created_'+str(index),made['status'] in (200,201))
   user=made['data']['id'];org=str(uuid.uuid4());resource=str(uuid.uuid4())
   b.sql(f"""insert into public.uniion_organizations(id,name) values('{org}','CI fictive');
insert into public.uniion_memberships(organization_id,user_id) values('{org}','{user}');
insert into public.uniion_module_access values('{org}','socle',true,true,'included',now()+interval '1 day');
insert into public.uniion_permissions values('{org}','{user}','socle','read');
insert into public.uniion_resources(id,organization_id,module,title) values('{resource}','{org}','socle','CI fictive');
insert into public.uniion_resource_grants values('{org}','{resource}','{user}',false,true,now()+interval '1 day',null);""",name,'restored')
   login=services.request(client,9999,'/token?grant_type=password',body={'email':email,'password':password});check('login_'+str(index),login['status']==200)
   accounts.append({'id':user,'org':org,'resource':resource,'token':login['data']['access_token'],'email':email,'password':password})
  for i,a in enumerate(accounts):
   own=services.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+a['org'],a['token'])
   check('own_read_'+str(i),own['status']==200 and any(r['id']==a['resource'] for r in own['data']))
   foreign=services.request(client,3000,'/uniion_resources?select=id&organization_id=eq.'+accounts[1-i]['org'],a['token'])
   check('foreign_read_denied_'+str(i),foreign['status']==200 and foreign['data']==[])
   modified=services.request(client,3000,'/uniion_resources?id=eq.'+accounts[1-i]['resource'],a['token'],{'title':'forbidden'},'PATCH')
   check('foreign_write_denied_'+str(i),modified['status'] in (401,403,204) and b.sql("select title from public.uniion_resources where id='"+accounts[1-i]['resource']+"'",name,'restored')=='CI fictive')
  from ephemeral_paths import run as advanced_paths
  advanced_paths(name,client,accounts,check)
  from ephemeral_files import run as file_paths
  file_paths(name,client,accounts,credentials['service_token'],check)
  from ephemeral_recovery import run as recovery_path
  recovery_path(name,client,accounts,credentials['service_token'],check)
  a=accounts[0];b.sql("update public.uniion_memberships set revoked_at=now() where user_id='"+a['id']+"'",name,'restored')
  refused=services.request(client,3000,'/uniion_resources?select=id',a['token']);check('revoked_member_denied',refused['status']==200 and refused['data']==[])
  proof={'passed':True,'checks':checks,'count':len(checks),'source_accessed':False,'fresh_database':True,'container':name,'automatic_deletion':False}
  dest=ROOT/'preuves/S01-ephemeral';dest.mkdir(exist_ok=True);(dest/'integration.json').write_text(json.dumps(proof,indent=2));print(json.dumps({'passed':True,'count':len(checks)}))
 finally:
  credentials.clear()
  subprocess.run(['docker','stop',*result.get('services',[]),name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
if __name__=='__main__':main()
