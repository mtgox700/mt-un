"""Read-only query timings on the retained isolated load target."""
import backup_restore as b,time,json,sys
container='uniion-ci-57192d92';results=[]
claims="select set_config('request.jwt.claims',json_build_object('sub',s.user_id,'session_id',s.id,'role','authenticated','aal','aal2')::text,true) from auth.sessions s join auth.users u on u.id=s.user_id where u.email='ci-1@uniion-local.example' and s.factor_id is not null order by s.created_at desc limit 1;"
for action in ['get','notices','live','search']:
 q="begin;set local statement_timeout='10s';"+claims+"select jsonb_typeof(public.uniion_messaging(organization_id,'"+action+"',"+("'{\"query\":\"Volume\"}'" if action=='search' else "'{}'" if action=='notices' else "jsonb_build_object('id',id)")+")) from uniion_private.message_conversations limit 1;rollback;"
 t=time.monotonic()
 try:b.sql(q,container,'restored');ok=True
 except RuntimeError:ok=False
 results.append({'action':action,'ok':ok,'seconds':round(time.monotonic()-t,3)});print(json.dumps(results[-1]),flush=True)
(b.ROOT/('preuves/S07-F/volume-diagnostic-'+sys.argv[1]+'.json')).write_text(json.dumps(results,indent=2))
