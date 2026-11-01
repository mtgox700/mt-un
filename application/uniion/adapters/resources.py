import uuid
from uniion.core.contracts import Principal,Denied,Unavailable
from .supabase_transport import AccessDenied,SupabaseUnavailable

def identifier(value):
    if not isinstance(value,str):raise Denied()
    try:return str(uuid.UUID(value))
    except (ValueError,AttributeError):raise Denied() from None

class SupabaseResources:
    """Request-scoped user transport. No service_role, no cached permissions."""
    def __init__(self,api,token):self.api=api;self._token=token
    def principal(self,organization_id):
        organization_id=identifier(organization_id)
        try:
            user=self.api.user(self._token)
            context=self.api.request('/rest/v1/rpc/uniion_context',self._token,{})
            if organization_id not in {o['id'] for o in context['organizations']}:raise Denied()
            return Principal(user['id'],organization_id)
        except AccessDenied:raise Denied() from None
        except SupabaseUnavailable:raise Unavailable() from None
    def read(self,principal,resource_id):
        resource_id=identifier(resource_id)
        # Re-evaluate membership on each command, including after revocation.
        if self.principal(principal.organization_id)!=principal:raise Denied()
        try:
            rows=self.api.request('/rest/v1/uniion_resources?select=id,organization_id,module,title,body,version,kind,client_id&id=eq.'+resource_id+'&organization_id=eq.'+principal.organization_id,self._token)
        except AccessDenied:raise Denied() from None
        except SupabaseUnavailable:raise Unavailable() from None
        if len(rows)!=1:raise Denied()
        row=rows[0]
        if row.get('organization_id')!=principal.organization_id or row.get('id')!=resource_id:raise Denied()
        return row
