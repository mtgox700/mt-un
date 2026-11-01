"""Server-owned history and memory retrieval, always guarded by current sources."""
from uniion.core.contracts import Denied
from .supabase_transport import AccessDenied
from .ai_context import refs

class Assistant:
    def __init__(self,gateway,context,authorize,actor):
        self.gateway=gateway;self.history=gateway.ledger.history;self.context=context;self.authorize=authorize;self.actor=actor
    def checked(self,org,rid):
        item=self.history.read(org,self.actor,rid)
        if item['response'].get('action'):
            from .ai_proposals import check_action_access
            check_action_access(self.context,org,item['response']['action'])
        if item['response'].get('mode')=='conversation':
            from .ai_conversation import interactive
            interactive(self.context,org)
            for parent in item['response'].get('parents',[]):
                if self.history.read(org,self.actor,parent['id'])['version']!=parent['version']:raise Denied('ai_parent_changed')
        sources=self.context.check(org,item['response']['snapshot'])
        self.context.recipe(org,sources)
        if item['response'].get('action'):check_action_access(self.context,org,item['response']['action'])
        if self.history.read(org,self.actor,rid)['version']!=item['version']:raise Denied('ai_history_changed')
        return item
    def list(self,org):
        initial=self.authorize(org);items=[];memories=[];seen=set()
        for row in self.history.rows(org,self.actor):
            try:item=self.checked(org,row['id'])
            except (Denied,AccessDenied):continue
            items.append({**{k:v for k,v in item.items() if k!='response'},'title':item['response'].get('title',item['response'].get('actionLabel','Synthèse fictive vérifiée'))});seen.add(item['id'])
            if item['remembered']:memories.append(item)
        for row in self.history.remembered_rows(org,self.actor):
            if row['id'] in seen:continue
            try:memories.append(self.checked(org,row['id']))
            except (Denied,AccessDenied):continue
        if self.authorize(org)!=initial:raise Denied()
        return {'items':items,'memories':memories,'memory':self.history.preference(org,self.actor),'limit':50}
    def read(self,org,rid):
        initial=self.authorize(org);item=self.checked(org,rid)
        if self.authorize(org)!=initial:raise Denied()
        return item
    def change(self,org,data):
        initial=self.authorize(org);action=data['action'];rid=data['id']
        self.checked(org,rid)
        if self.authorize(org)!=initial:raise Denied()
        return self.history.change(org,self.actor,rid,data['version'],action,data.get('enabled'))
    def generate(self,sid,org,rid,values):
        selected=refs(values)
        signature=self.history.signature(org,self.actor)
        for memory_id,_ in signature[1]:
            item=self.checked(org,memory_id)
            for s in item['response']['snapshot']:
                ref={k:v for k,v in s.items() if k!='fingerprint'}
                if ref not in selected:selected.append(ref)
        refs(selected) # fail instead of silently truncating the cumulative restrictions
        def authorize(current_org):
            policy=self.authorize(current_org)
            if self.history.signature(org,self.actor)!=signature:raise Denied('ai_memory_changed')
            # Recheck each remembered version, including sources, before/after inference.
            for memory_id,_ in signature[1]:self.checked(org,memory_id)
            return policy
        return self.gateway.generate(sid,{'organization_id':org,'request_id':rid,'sources':selected},authorize,self.context,record=True)
