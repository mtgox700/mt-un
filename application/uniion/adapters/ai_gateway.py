"""Fixture gateway with persistent reservations and no automatic retry."""
import threading
import time
from uuid import UUID
from uniion.core.contracts import Denied, Unavailable
from .sessions import RateLimited

FIXTURES = {
    'connection': 'Répondez exactement : UNIION_S08_OK',
    'summary': 'Cas entièrement fictif : le comité Exemple prépare une réunion mardi. Alex Exemple rédige un ordre du jour jeudi. Résumez ces deux actions en deux phrases, sans ajouter de faits.',
}


def policy(api, token, data):
    if not isinstance(data, dict) or set(data) != {'organization_id', 'action', 'payload'}:
        raise Denied()
    org = str(UUID(data['organization_id']))
    if data['action'] not in ('status', 'approve', 'activate') or not isinstance(data['payload'], dict):
        raise Denied()
    return api.request('/rest/v1/rpc/uniion_ai_policy', token,
                       {'p_org': org, 'p_action': data['action'], 'p_payload': data['payload']})


class AIGateway:
    def __init__(self, provider_factory=None, ledger=None):
        if provider_factory is None:
            from .codex_local import CodexLocal
            provider_factory = CodexLocal
        from .ai_runs import RunLedger
        self.ledger = ledger or RunLedger()
        self.provider_factory = provider_factory
        self.lock = threading.Lock()
        self.active = {}
        self.cancelled = {}

    def cancel(self, sid, org, request_id):
        # Same response for an unknown or another session's request.
        with self.lock:
            now = time.monotonic()
            self.cancelled = {k:v for k,v in self.cancelled.items() if v > now}
            if len(self.cancelled) >= 2048: raise RateLimited()
            key = (sid, org, request_id)
            self.cancelled[key] = now + 180
            event = self.active.get(key)
            if event: event.set()
        return {'cancelled': True}

    def generate(self, sid, data, authorize, context=None, record=False):
        contextual = set(data) == {'organization_id','request_id','sources'}
        if contextual:
            if context is None: raise Denied()
            from .ai_context import refs
            refs(data['sources'])
        elif set(data) != {'organization_id','request_id','fixture'} or data['fixture'] not in FIXTURES:
            raise Denied()
        org, rid = str(UUID(data['organization_id'])), str(UUID(data['request_id']))
        initial = authorize(org)
        if initial.get('scope') != 'fixture-only' or initial.get('provider') != 'codex-local' or initial.get('ready') is not True:
            raise Denied()
        key = (sid, org, rid)
        from uniion.core.ai_context import digest
        actor=initial['actor']
        with self.lock:
            if self.cancelled.get(key,0)>time.monotonic():raise Denied('ai_cancelled')
            owner=self.ledger.reserve(org,actor,rid,digest(data))
            event=threading.Event();self.active[key]=event
        def check():
            if event.is_set() or not self.ledger.live(org,actor,rid,owner): raise Denied('ai_cancelled')
            current = authorize(org)
            if current != initial: raise Denied('ai_policy_changed')
        dispatched=False
        last_poll=0.0
        def cancelled():
            nonlocal last_poll
            if event.is_set():return True
            now=time.monotonic()
            if now-last_poll>=1:
                last_poll=now
                if not self.ledger.live(org,actor,rid,owner):event.set()
            return event.is_set()
        gateway=self
        class TrackedProvider:
            def complete(self,*args,**kwargs):
                nonlocal dispatched
                check()
                gateway.ledger.start(org,actor,rid,owner)
                dispatched=True
                kwargs['cancelled']=cancelled
                return gateway.provider_factory().complete(*args,**kwargs)
        try:
            check()
            provider = TrackedProvider()
            extra = context.generate(org,data['sources'],provider,check,event.is_set) if contextual else {}
            text = extra['text'] if contextual else provider.complete(FIXTURES[data['fixture']], (), cancelled=event.is_set)
            check()
            if not isinstance(text, str) or not text.strip() or len(text) > 16000:
                raise Unavailable('ai_invalid_response')
            if record and not contextual:raise Denied()
            if record:extra['persistent']=True
            if self.ledger.finish(org,actor,rid,owner,'succeeded',response=extra if record else None)!='succeeded':raise Denied('ai_cancelled')
            return {'state':'succeeded','text': text.strip(), 'scope': 'fixture-only', 'provider': 'codex-local',
                    'request_id': rid, 'usage': None, 'cost': None, **extra}
        except (Denied,) as exc:
            self.ledger.finish(org,actor,rid,owner,'cancelled' if event.is_set() else 'failed')
            raise
        except Exception:
            # An attempted handoff may have reached the provider. Never refund it.
            self.ledger.finish(org,actor,rid,owner,'uncertain' if dispatched else 'failed')
            raise
        finally:
            with self.lock: self.active.pop(key, None)
