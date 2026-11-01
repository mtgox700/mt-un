"""Supabase user-scoped transport. No service key, demo identity or disk sessions.

Foundation only: intentionally not connected to the demo server until the
database migration and end-to-end tenant tests have passed.
"""
import json
import os
import urllib.error
import urllib.parse
import urllib.request
import uuid


class AccessDenied(Exception):
    pass


class SupabaseUnavailable(Exception):
    pass


class SupabaseAccess:
    def __init__(self, url=None, key=None, opener=None, local=False):
        self.url = (url or os.environ.get('UNIION_SUPABASE_URL', '')).rstrip('/')
        self.key = key or os.environ.get('UNIION_SUPABASE_PUBLISHABLE_KEY', '')
        parsed = urllib.parse.urlparse(self.url)
        is_local = local and self.url == 'http://127.0.0.1:54321'
        if not is_local and (parsed.scheme != 'https' or not parsed.hostname
                or not parsed.hostname.endswith('.supabase.co')
                or parsed.path or parsed.query or parsed.fragment or parsed.username
                or parsed.port not in (None, 443)):
            raise ValueError('URL du projet Supabase managé requise')
        # Deliberately accept only the new public-key format: never service_role.
        if not is_local and not self.key.startswith('sb_publishable_'):
            raise ValueError('Clé publique Supabase publishable requise')
        self.open = opener or urllib.request.urlopen

    def request(self, path, token=None, body=None, method=None):
        headers = {'Content-Type': 'application/json'}
        if self.key: headers['apikey'] = self.key
        if token:
            if not isinstance(token, str) or any(c.isspace() for c in token):
                raise AccessDenied('Session invalide')
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(self.url + path, headers=headers,
            data=None if body is None else json.dumps(body).encode(), method=method)
        try:
            with self.open(req, timeout=15) as response:
                raw=response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            if exc.code in (400, 401, 403, 404, 422):
                raise AccessDenied('Accès refusé') from None
            raise SupabaseUnavailable('Supabase indisponible') from None
        except (OSError, ValueError):
            raise SupabaseUnavailable('Supabase indisponible') from None

    def user(self, token):
        if not token:
            raise AccessDenied('Connexion requise')
        user = self.request('/auth/v1/user', token)
        try:
            uuid.UUID(user['id'])
        except (ValueError, KeyError, TypeError):
            raise AccessDenied('Session invalide') from None
        return {'id': user['id'], 'email': user.get('email')}

    def login(self, email, password):
        # Caller must keep tokens server-side; never persist in localStorage.
        if not isinstance(email, str) or not isinstance(password, str):
            raise AccessDenied('Identifiants invalides')
        return self.request('/auth/v1/token?grant_type=password',
                            body={'email': email, 'password': password})

    def logout(self, token, scope="local"):
        if scope not in ("local","global"):raise ValueError("Invalid logout scope")
        headers={'Content-Type':'application/json','Authorization':'Bearer '+token}
        if self.key:headers['apikey']=self.key
        try:
            with self.open(urllib.request.Request(self.url+'/auth/v1/logout?scope='+scope,data=b'{}',headers=headers),timeout=15) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            if exc.code not in (401,403):raise SupabaseUnavailable('Révocation distante non confirmée') from None
        except OSError:raise SupabaseUnavailable('Révocation distante non confirmée') from None

    def resources(self, token, organization_id):
        self.user(token)
        try:
            org = str(uuid.UUID(organization_id))
        except (ValueError, TypeError, AttributeError):
            raise AccessDenied('Organisation invalide') from None
        # RLS applies with the user's token, including against direct REST calls.
        return self.request('/rest/v1/uniion_resources?select=id,organization_id,module,title,body,version,kind,client_id'
                            '&organization_id=eq.' + org, token)
