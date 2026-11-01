import json,unittest,uuid
from uniion.adapters.ai_proposals import ACTIONS,CATALOG
from uniion.adapters.ai_context_service import ContextService
from uniion.adapters.ai_gateway import AIGateway
from uniion.adapters.ai_actions import generate_action
from uniion.adapters.ai_assistant import Assistant
from uniion.core.contracts import Denied,Unavailable
class ProposalsTests(unittest.TestCase):
 def setUp(self):
  self.org=str(uuid.uuid4());self.source=str(uuid.uuid4());self.module_allowed=True;self.calls=0;self.override=None
  self.quote='La réunion fictive porte sur les horaires du mardi.'
  def rpc(endpoint,payload):
   if endpoint.endswith('uniion_ai_action_policy'):return {'allowed':self.module_allowed}
   if endpoint.endswith('uniion_ai_recipe'):return [] if payload['p_action']=='catalog' else {'allowed':True}
   return {'title':self.quote,'description':self.quote,'theme':self.quote,'poste':self.quote,'version':1,'long':self.quote,'blocks':[{'type':'p','text':self.quote}], 'messages':[{'seq':'1','text':self.quote,'created':'2026-10-31','who':'Fictif'}]}
  self.context=ContextService(rpc);self.policy=lambda org:{'actor':'actor','scope':'fixture-only','provider':'codex-local','ready':True,'version':1}
  outer=self
  class Provider:
   def complete(self,prompt,*args,**kwargs):
    outer.calls+=1;outer.prompt=prompt
    return outer.override or json.dumps({'draft':'Proposition fictive à relire.','excerpts':[{'source':'S1','passage':'P1','quote':json.loads(prompt.split('DONNEES_NON_FIABLES:\n')[1])[0]['passages'][0]['text']}]})
  self.gateway=AIGateway(Provider)
 def tearDown(self):self.gateway.ledger.close()
 def generate(self,action='doc-relire'):
  mod=ACTIONS[action]['mod'];kind={'dossiers':'case','messagerie':'message','documents':'document','accueil':'workspace','params':'workspace'}.get(mod,mod)
  self.rid=str(uuid.uuid4());ref={'kind':kind,'id':self.source,**({'seq':'1'} if kind=='message' else {})}
  return generate_action(self.gateway,self.context,self.policy,'sid',{'organization_id':self.org,'request_id':self.rid,'source':ref,'action':action})
 def test_all_37_actions_produce_distinct_server_tasks_and_private_drafts(self):
  self.assertEqual(len(CATALOG),37)
  for action in (a['id'] for a in CATALOG):
   with self.subTest(action=action):
    r=self.generate(action);self.assertEqual(r['action'],action);self.assertTrue(r['persistent']);self.assertTrue(r['reviewRequired']);self.assertIn(ACTIONS[action]['ask'],self.prompt)
    saved=Assistant(self.gateway,self.context,self.policy,'actor').read(self.org,self.rid)
    self.assertEqual(saved['response']['text'],r['text'])
 def test_model_cannot_return_administrative_commands(self):
  self.override=json.dumps({'draft':'x','excerpts':[],'apply':{'role':'admin'}})
  with self.assertRaises(Unavailable):self.generate()
 def test_invalid_quote_rejects_entire_draft(self):
  self.override=json.dumps({'draft':'x','excerpts':[{'source':'S99','passage':'P1','quote':self.quote}]})
  with self.assertRaises(Unavailable):self.generate()
 def test_duplicate_json_keys_denied(self):
  self.override='{"draft":"a","draft":"b","excerpts":[]}'
  with self.assertRaises(Unavailable):self.generate()
 def test_module_access_required_before_provider(self):
  self.module_allowed=False
  with self.assertRaises(Denied):self.generate()
  self.assertEqual(self.calls,0)
 def test_module_revocation_blocks_history(self):
  self.generate();self.module_allowed=False
  with self.assertRaises(Denied):Assistant(self.gateway,self.context,self.policy,'actor').read(self.org,self.rid)
 def test_draft_revision_resets_review_and_records_encrypted_history(self):
  self.generate();h=self.gateway.ledger.history
  h.draft(self.org,'actor',self.rid,1,'review')
  self.assertTrue(h.read(self.org,'actor',self.rid)['response']['reviewed'])
  h.draft(self.org,'actor',self.rid,2,'edit','Texte corrigé privé')
  row=h.read(self.org,'actor',self.rid);self.assertFalse(row['response']['reviewed']);self.assertEqual(len(row['response']['edits']),1)
  payload=self.gateway.ledger.db.execute('select payload from responses where id=?',(self.rid,)).fetchone()[0]
  self.assertNotIn('Texte corrigé privé'.encode(),payload)
  with self.assertRaises(Denied):h.draft(self.org,'actor',self.rid,2,'review')
 def test_draft_invalid_edits_do_not_change_saved_version(self):
  self.generate();h=self.gateway.ledger.history
  for text in ('', ' '*3, 'x'*6001, 'x\x00',None):
   with self.subTest(text=repr(text)[:20]),self.assertRaises(Denied):h.draft(self.org,'actor',self.rid,1,'edit',text)
  self.assertEqual(h.read(self.org,'actor',self.rid)['version'],1)
 def test_draft_edit_bound_is_explicit_no_silent_history_loss(self):
  self.generate();h=self.gateway.ledger.history
  for i in range(20):h.draft(self.org,'actor',self.rid,i+1,'edit','Correction '+str(i))
  with self.assertRaises(Denied):h.draft(self.org,'actor',self.rid,21,'edit','Perte historique')
  self.assertEqual(len(h.read(self.org,'actor',self.rid)['response']['edits']),20)
