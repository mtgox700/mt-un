"""Server-only tokens. Bounded local session store, no persistence or browser JWT."""
import time,secrets,threading,hashlib,uuid
from http.cookies import SimpleCookie
from uniion.core.contracts import Denied,Unavailable
from .supabase_transport import AccessDenied,SupabaseUnavailable

class RateLimited(Exception):pass
class SessionStore:
    def __init__(self,api,clock=time.time):
        self.api=api;self.clock=clock;self.sessions={};self.attempts={};self.lock=threading.RLock()
    # R4 : les échecs de code MFA sont comptés sur une heure (10 au plus), dans l'état persistant.
    MFA_FAILURES=10
    def window(self,key):return 3600 if key.startswith('mfa-fail:') else 60
    def prune(self):
        now=self.clock()
        self.attempts={k:[t for t in v if t>now-self.window(k)] for k,v in self.attempts.items() if v and v[-1]>now-self.window(k)}
    def limit(self,key,maximum):
        now=self.clock();self.prune()
        if len(self.attempts.get(key,[]))>=maximum:raise RateLimited()
        self.attempts.setdefault(key,[]).append(now)
    def check_failures(self,key,maximum):
        self.prune()
        if len(self.attempts.get(key,[]))>=maximum:raise RateLimited()
    def record_failure(self,key):self.attempts.setdefault(key,[]).append(self.clock())
    def cookie(self,sid):return 'uniion_s01='+sid+'; HttpOnly; SameSite=Strict; Path=/; Max-Age='+('28800' if sid else '0')
    def find(self,header,create=False):
        c=SimpleCookie()
        try:c.load(header)
        except Exception:raise Denied() from None
        sid=c['uniion_s01'].value if 'uniion_s01' in c else None
        now=self.clock()
        for key in list(self.sessions):
            s=self.sessions[key]
            if now>=s['end'] or now-s['last']>=s['idle']:
                self.sessions.pop(key,None)
                # Close server-side tokens where possible; local access is closed regardless.
                if s.get('access_token'):
                    try:self.revoke(s)
                    except (AccessDenied,SupabaseUnavailable):pass
        s=self.sessions.get(sid)
        if not s and create:
            if len(self.sessions)>=2048 or sum(not x.get('access_token') for x in self.sessions.values())>=256:raise RateLimited()
            sid=secrets.token_urlsafe(32);s={'csrf':secrets.token_urlsafe(32),'end':now+600,'last':now,'idle':600};self.sessions[sid]=s
        if s:s['last']=now
        return sid,s
    def rotate(self,sid,s):
        self.sessions.pop(sid,None);sid=secrets.token_urlsafe(32);s['csrf']=secrets.token_urlsafe(32);self.sessions[sid]=s;return sid
    def update(self,s,data):
        for key in ('access_token','refresh_token','expires_at'):s[key]=data[key]
    def revoke(self,s,scope="local"):
        # Expired access JWTs must not leave an otherwise valid refresh session behind.
        if s.get('expires_at',0)<self.clock()+30:
            try:self.update(s,self.api.request('/auth/v1/token?grant_type=refresh_token',body={'refresh_token':s['refresh_token']}))
            except AccessDenied:
                if scope=='global':raise
                return
        self.api.logout(s['access_token'],scope='global') if scope=='global' else self.api.logout(s['access_token'])
    def authenticate(self,s):
        if not s or not s.get('access_token'):raise Denied()
        try:
            if s['expires_at']<self.clock()+30:
                self.update(s,self.api.request('/auth/v1/token?grant_type=refresh_token',body={'refresh_token':s['refresh_token']}))
            user=self.api.request('/auth/v1/user',s['access_token'])
            status=self.api.request('/rest/v1/rpc/uniion_session_status',s['access_token'],{})
            if not status.get('active'):raise Denied()
            return user,status
        except AccessDenied:raise Denied() from None
        except SupabaseUnavailable:raise Unavailable() from None
    def public(self,s):
        if not s.get('access_token'):return {'authenticated':False,'csrf':s['csrf']}
        user,status=self.authenticate(s)
        return {'authenticated':True,'csrf':s['csrf'],'user':{'id':user['id'],'email':user.get('email')},'aal':status['aal'],'mfa_required':status['required'],'business_allowed':status['allowed'],'enrollment_allowed':status.get('enrollment_allowed',False),'factors':[{'id':f['id'],'status':f['status'],'type':f['factor_type'],'name':f.get('friendly_name','')} for f in user.get('factors',[])]}
    def factor(self,user,factor_id):
        try:factor_id=str(uuid.UUID(factor_id))
        except (ValueError,TypeError,AttributeError):raise Denied() from None
        if factor_id not in [f['id'] for f in user.get('factors',[])]:raise Denied()
        return factor_id
    def identity_token(self,s):
        """Under the session lock: authenticate, check business access and rate, return the access token."""
        user,status=self.authenticate(s)
        if not status['allowed']:raise Denied()
        self.limit('identity:'+user['id'],20)
        return s['access_token']
    def identity_dispatch(self,path,token,data):
        """Outside the session lock: business call with an already authorized token (R1)."""
        s={'access_token':token}
        if path=='/identity/ai':
            from .ai_gateway import policy
            return policy(self.api,s['access_token'],data)
        if path=='/identity/messaging':
            from .messaging import dispatch
            return dispatch(self.api,s['access_token'],data)
        if path=='/identity/business':
            from .business_records import dispatch
            return dispatch(self.api,s['access_token'],data)
        if path=='/identity/documents':
            from .documents import dispatch
            return dispatch(self.api,s['access_token'],data)
        if path=='/identity/cases':
            from .cases import dispatch
            return dispatch(self.api,s['access_token'],data)
        if path=='/identity/adherents':
            from .adherents import dispatch
            return dispatch(self.api,s['access_token'],data)
        if path=='/identity/agenda/convocations/files':
            from .agenda import history_files
            return history_files(self.api,s['access_token'],data)
        if path=='/identity/agenda/convocations/history':
            from uuid import UUID
            if set(data)!={'organization_id'}:raise Denied()
            try:org=str(UUID(data['organization_id']))
            except (ValueError,TypeError,AttributeError):raise Denied() from None
            return self.api.request('/rest/v1/rpc/uniion_convocation_history',s['access_token'],{'p_org':org})
        if path in ('/identity/agenda/work','/identity/agenda/convocations/send'):
            from .agenda import workflow
            return workflow(self.api,s['access_token'],data,send=path.endswith('/send'))
        if path=='/identity/agenda/export':
            from .agenda import export
            return export(self.api,s['access_token'],data)
        if path in ('/identity/support/files/preview','/identity/support/files/download'):
            import re
            from . import attachments
            preview_mode=path.endswith('/preview')
            expected={'organization_id','ticket','grant','attachment'}|({'page'} if preview_mode else set())
            if set(data)!=expected or any(not isinstance(data.get(k),str) or not re.fullmatch('[0-9a-fA-F-]{36}',data[k]) for k in expected-{'page'}):raise Denied()
            if preview_mode and (type(data['page']) is not int or not 1<=data['page']<=200):raise Denied()
            return attachments.support_file(self.api,s['access_token'],data['organization_id'],data,preview_mode)
        if path in ('/identity/attachments/preview','/identity/attachments/download'):
            import base64,re
            from . import attachments
            expected={'organization_id','attachment','share'}|({'page'} if path.endswith('/preview') else set())
            if set(data)!=expected or any(not isinstance(data.get(k),str) or not re.fullmatch('[0-9a-fA-F-]{36}',data[k]) for k in ('organization_id','attachment')):raise Denied()
            if data['share'] is not None and (not isinstance(data['share'],str) or not re.fullmatch('[0-9a-fA-F-]{36}',data['share'])):raise Denied()
            if path.endswith('/preview'):
                if type(data['page']) is not int or not 1<=data['page']<=200:raise Denied()
                return attachments.preview(self.api,s['access_token'],data['organization_id'],data)
            meta,raw=attachments.download(self.api,s['access_token'],data['organization_id'],data)
            return {'filename':meta['filename'],'mime':meta['mime'],'content':base64.b64encode(raw).decode()}
        if path in ('/identity/invitations/send','/identity/invitations/resend'):
            from .local_invitation_mail import send
            return send(self.api,s['access_token'],data,resend=path.endswith('/resend'))
        from .identity import dispatch
        return dispatch(self.api,s['access_token'],path,data)
    def post(self,path,sid,s,data,ip):
        if not s:raise Denied()
        if path=='/auth/recovery/request':
            email=data.get('email')
            if not isinstance(email,str) or len(email)>320 or '@' not in email:raise Denied()
            self.limit('recovery-ip:'+ip,10)
            self.limit('recovery:'+hashlib.sha256(email.strip().casefold().encode()).hexdigest(),3)
            try:self.api.request('/auth/v1/recover',body={'email':email})
            except AccessDenied:pass # same public response for unknown identities
            return sid,{'ok':True,'message':'Si le compte existe, les instructions de récupération seront envoyées.'}
        if path=='/auth/recovery/verify':
            if s.get('access_token'):raise Denied()
            self.limit('recovery-verify:'+ip,10)
            token_hash=data.get('token_hash')
            if not isinstance(token_hash,str) or not 20<=len(token_hash)<=256:raise Denied()
            result=self.api.request('/auth/v1/verify',body={'token_hash':token_hash,'type':'recovery'})
            self.update(s,result);s.update(end=self.clock()+1800,idle=600,last=self.clock(),recovery_until=self.clock()+600)
            sid=self.rotate(sid,s);return sid,self.public(s)
        if path=='/auth/login':
            email=data.get('email');password=data.get('password')
            if not isinstance(email,str) or len(email)>320 or not isinstance(password,str) or len(password)>1024:raise Denied()
            self.limit('ip:'+ip,100);self.limit('login:'+hashlib.sha256(email.strip().casefold().encode()).hexdigest(),10)
            if s.get('access_token'):raise Denied() # logout before switching identity
            result=self.api.login(email,password);self.api.user(result['access_token'])
            self.update(s,result);s.update(end=self.clock()+28800,idle=1800,last=self.clock())
            sid=self.rotate(sid,s);return sid,self.public(s)
        if path=='/auth/logout':
            try:
                if s.get('access_token'):self.revoke(s)
            finally:self.sessions.pop(sid,None)
            return '',{'ok':True}
        user,status=self.authenticate(s)
        if path=='/auth/mfa/lost/request':
            self.limit('lost-factor:'+user['id'],3)
            return sid,self.api.request('/rest/v1/rpc/uniion_lost_factor_request',s['access_token'],{})
        if path in ('/auth/mfa/lost/approve','/auth/mfa/lost/cancel'):
            self.limit('lost-factor-review:'+user['id'],10)
            from .identity import dispatch
            return sid,dispatch(self.api,s['access_token'],path,data)
        if path=='/auth/mfa/recovery/enroll':
            self.limit('mfa-recovery:'+user['id'],3)
            if not status['required'] or status['allowed']:raise Denied()
            result=self.api.request('/auth/v1/factors',s['access_token'],{'factor_type':'totp','friendly_name':'Récupération demandée'})
            try:request=self.api.request('/rest/v1/rpc/uniion_mfa_recovery_request',s['access_token'],{'p_factor':result['id']})
            except (AccessDenied,SupabaseUnavailable):
                try:self.api.request('/auth/v1/factors/'+result['id'],s['access_token'],method='DELETE')
                except (AccessDenied,SupabaseUnavailable):pass
                raise
            return sid,{'id':result['id'],'totp':result['totp'],'request':request}
        if path=='/auth/mfa/recovery/request':
            self.limit('mfa-recovery:'+user['id'],3)
            factor=self.factor(user,data.get('factor_id'))
            return sid,self.api.request('/rest/v1/rpc/uniion_mfa_recovery_request',s['access_token'],{'p_factor':factor})
        if path=='/auth/mfa/recovery/approve':
            self.limit('mfa-review:'+user['id'],10)
            from .identity import dispatch
            return sid,dispatch(self.api,s['access_token'],path,data)
        if path.startswith('/identity/'):
            if not status['allowed']:raise Denied()
            self.limit('identity:'+user['id'],20)
            return sid,self.identity_dispatch(path,s['access_token'],data)
        if path=='/auth/password':
            if s.get('recovery_until',0)<=self.clock() or not status['allowed']:raise Denied()
            password=data.get('password')
            if not isinstance(password,str) or not 12<=len(password)<=1024:raise Denied()
            self.api.request('/auth/v1/user',s['access_token'],{'password':password},method='PUT')
            try:self.revoke(s,scope='global')
            finally:self.sessions.pop(sid,None)
            return '',{'ok':True,'message':'Mot de passe modifié. Reconnectez-vous.'}
        self.limit('mfa:'+user['id'],20)
        if path=='/auth/mfa/enroll':
            if status['required'] and (status['aal']!='aal2' or not status['allowed']) and not status.get('enrollment_allowed'):raise Denied()
            if any(f['status']=='verified' for f in user.get('factors',[])) and status['aal']!='aal2':raise Denied()
            if len(user.get('factors',[]))>=5:raise Denied()
            name=data.get('name','Authentificateur')
            if not isinstance(name,str) or not 1<=len(name)<=60:raise Denied()
            result=self.api.request('/auth/v1/factors',s['access_token'],{'factor_type':'totp','friendly_name':name})
            try:self.api.request('/rest/v1/rpc/uniion_mfa_authorize_factor',s['access_token'],{'p_factor':result['id']})
            except (AccessDenied,SupabaseUnavailable):
                # The factor stays untrusted even if cleanup cannot reach Auth.
                try:self.api.request('/auth/v1/factors/'+result['id'],s['access_token'],method='DELETE')
                except (AccessDenied,SupabaseUnavailable):pass
                raise
            # Enrollment material returned once, never saved in application state/logs.
            return sid,{'id':result['id'],'totp':result['totp']}
        factor=self.factor(user,data.get('factor_id'))
        if path=='/auth/mfa/challenge':
            result=self.api.request('/auth/v1/factors/'+factor+'/challenge',s['access_token'],{})
            s['challenge']={'factor':factor,'id':result['id'],'end':self.clock()+300}
            return sid,{'id':result['id']}
        if path=='/auth/mfa/verify':
            challenge=s.get('challenge',{});code=data.get('code')
            if challenge.get('factor')!=factor or challenge.get('id')!=data.get('challenge_id') or challenge.get('end',0)<=self.clock() or not isinstance(code,str) or len(code)!=6 or not code.isascii() or not code.isdigit():raise Denied()
            failures='mfa-fail:'+user['id'];self.check_failures(failures,self.MFA_FAILURES)
            try:result=self.api.request('/auth/v1/factors/'+factor+'/verify',s['access_token'],{'challenge_id':challenge['id'],'code':code})
            except AccessDenied:
                self.record_failure(failures);raise
            self.update(s,result);s.pop('challenge',None)
            self.api.request('/rest/v1/rpc/uniion_require_mfa',s['access_token'],{})
            sid=self.rotate(sid,s);return sid,self.public(s)
        if path=='/auth/mfa/remove':
            factor_row=next(f for f in user['factors'] if f['id']==factor)
            if factor_row['status']=='verified' and (status['aal']!='aal2' or len([f for f in user['factors'] if f['status']=='verified'])<2):raise Denied()
            if any(f['status']=='verified' for f in user.get('factors',[])) and status['aal']!='aal2':raise Denied()
            self.api.request('/auth/v1/factors/'+factor,s['access_token'],method='DELETE');return sid,{'ok':True}
        raise Denied()
