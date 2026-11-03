import unittest
from uuid import UUID
from uniion.adapters.ai_context_service import ContextService
ORG='00000000-0000-4000-8000-000000000001'
MODULES=('reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis')
def uid(i):return str(UUID(int=i))
class FakeContract:
    """Contrats fictifs : 8 modules et 2 modules natifs de 64 lignes chacun, un tiers des sources refusées par la recette."""
    def __init__(self,interactive=True):self.calls=[];self.interactive=interactive
    def __call__(self,endpoint,payload):
        self.calls.append(endpoint)
        name=endpoint.rsplit('/',1)[1]
        if name=='uniion_ai_recipe':
            if payload['p_action']=='catalog':return [{'kind':'case','id':uid(1)}]
            ref=payload['p_refs'][0]
            return {'allowed':int(ref['id'][-4:],16)%3!=0}
        if name=='uniion_ai_interactive':return {'allowed':self.interactive}
        if name in ('uniion_business_records','uniion_cases','uniion_documents'):
            if payload['p_action']=='list':
                base={'uniion_cases':1000,'uniion_documents':2000}.get(name,3000+100*MODULES.index(payload.get('p_module','reunions')))
                return {'rows':[{'id':uid(base+i)} for i in range(70)]}
            row=payload['p_payload']
            if name=='uniion_cases':return {'long':'Description','timeline':[],'title':'Dossier','version':1,'owner':''}
            if name=='uniion_documents':return {'blocks':[{'type':'p','text':'Texte'}],'title':'Document','version':1}
        if name=='uniion_ai_native':return {'title':'Fiche','version':1,'description':'Texte','blocks':[['p','Texte']]}
        raise AssertionError(endpoint)
class CatalogTests(unittest.TestCase):
    def test_catalog_stops_once_limit_is_reached(self):
        call=FakeContract();refs=ContextService(call).catalog(ORG,8)
        self.assertEqual(len(refs),8)
        # R9 : sans arrêt anticipé, plus de 1 300 appels pour ce volume.
        self.assertLess(len(call.calls),40)
    def test_catalog_respects_recipe_and_order(self):
        refs=ContextService(FakeContract()).catalog(ORG,64)
        self.assertEqual(len(refs),64);self.assertEqual(refs[0],{'kind':'case','id':uid(1)})
        self.assertTrue(all(int(r['id'][-4:],16)%3!=0 for r in refs))
        self.assertEqual(len({(r['kind'],r['id']) for r in refs}),64)
    def test_catalog_without_interactive_recipe_uses_registry_only(self):
        call=FakeContract(interactive=False);refs=ContextService(call).catalog(ORG,8)
        self.assertEqual(refs,[{'kind':'case','id':uid(1)}])
        self.assertNotIn('/rest/v1/rpc/uniion_business_records',call.calls)
