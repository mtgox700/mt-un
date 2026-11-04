import unittest
from uuid import UUID
from uniion.adapters.ai_runs import RunLedger
from uniion.adapters.ai_context_service import ContextService
from uniion.adapters import ai_drafts
from uniion.core.ai_context import prepare
ORG=str(UUID(int=1));ACTOR=str(UUID(int=2));CASE=str(UUID(int=3));RID=str(UUID(int=4))
CASE_ROW={'long':'Camille Exemple (camille@example.invalid) conteste son planning.','timeline':[],'title':'Dossier planning','version':5,'owner':'Camille Exemple'}
class Gateway:
    def __init__(self):self.ledger=RunLedger()
class Contracts:
    def __init__(self):self.applied=None
    def __call__(self,endpoint,payload):
        name=endpoint.rsplit('/',1)[1]
        if name=='uniion_cases':return dict(CASE_ROW)
        if name in ('uniion_ai_recipe',):return {'allowed':True}
        if name=='uniion_ai_action_policy':return {'allowed':True}
        if name=='uniion_ai_draft_apply':
            if payload['p_action']=='status':return {'applied':False}
            self.applied=payload['p_payload'];return {'applied':True}
        raise AssertionError(endpoint)
class DraftApplyTests(unittest.TestCase):
    def test_applied_text_is_reidentified(self):
        # R12 : le brouillon rédigé sur la source masquée arrive en clair dans le dossier.
        contracts=Contracts();context=ContextService(contracts);gateway=Gateway()
        source=context.load(ORG,[{'kind':'case','id':CASE}])[0]
        masked=prepare([source])['sources'][0]['passages'][0]['text']
        person=masked.split(' ')[0];email=masked.split('(')[1].split(')')[0]
        response={'text':f'Appeler {person} ({email}) avant vendredi.','excerpts':[],'snapshot':context.snapshot([source]),
                  'action':'dos-next','mode':'business-draft','reviewed':True,'persistent':True}
        ledger=gateway.ledger;owner=ledger.reserve(ORG,ACTOR,RID,'empreinte');ledger.start(ORG,ACTOR,RID,owner)
        ledger.finish(ORG,ACTOR,RID,owner,'succeeded',response=response)
        result=ai_drafts.dispatch(gateway,context,lambda org:{'allowed':True},ACTOR,{'organization_id':ORG,'action':'apply','id':RID,'version':1})
        self.assertEqual(result,{'applied':True})
        self.assertEqual(contracts.applied['text'],'Appeler Camille Exemple (camille@example.invalid) avant vendredi.')
        self.assertEqual(contracts.applied['kind'],'case')
