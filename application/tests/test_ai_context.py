import json,unittest,uuid
from uniion.core.ai_context import Masker,plain,prepare,verify_excerpts
from uniion.adapters.ai_context import refs,read
from uniion.adapters.ai_context_service import ContextService
from uniion.core.contracts import Denied,Unavailable
from uniion.adapters.supabase_transport import AccessDenied

class ContextTests(unittest.TestCase):
    def setUp(self):
        self.id=str(uuid.uuid4());self.reference={'kind':'document','id':self.id};self.calls=[];self.denied=False;self.registered=True
        self.row={'id':self.id,'title':'Note fictive','version':1,'blocks':[{'type':'p','text':'Réunion prévue mardi à neuf heures.'}], 'charte':{'email':'NEVER_SEND','logo':'NEVER_FETCH'}}
        def call(endpoint,payload):
            self.calls.append(endpoint)
            if self.denied:raise AccessDenied()
            if endpoint.endswith('uniion_ai_recipe'):
                if not self.registered:raise AccessDenied()
                return {'allowed':True}
            return self.row.copy()
        self.service=ContextService(call)
    def test_projection_excludes_nontext_metadata(self):
        r=self.service.preview('org',[self.reference]);self.assertNotIn('NEVER',json.dumps(r));self.assertNotIn(self.id,json.dumps(r['sources']))
    def test_read_uses_module_contract(self):
        self.service.preview('org',[self.reference]);self.assertEqual(self.calls,['/rest/v1/rpc/uniion_documents']*2)
    def test_unknown_fields_in_ref_denied(self):
        with self.assertRaises(Denied):refs([{**self.reference,'text':'injected'}])
    def test_duplicate_refs_denied(self):
        with self.assertRaises(Denied):refs([self.reference,self.reference])
    def test_empty_refs_denied(self):
        with self.assertRaises(Denied):refs([])
    def test_snapshot_checks_current_rights(self):
        r=self.service.preview('org',[self.reference]);self.denied=True
        with self.assertRaises(AccessDenied):self.service.check('org',r['snapshot'])
    def test_change_without_version_bump_detected(self):
        r=self.service.preview('org',[self.reference]);self.row['blocks'][0]['text']='Autre texte'
        with self.assertRaises(Denied):self.service.check('org',r['snapshot'])
    def test_valid_excerpts(self):
        c=self.service.preview('org',[self.reference]);raw=json.dumps({'excerpts':[{'source':'S1','passage':'P1','quote':'Réunion prévue mardi'}]});r=verify_excerpts(raw,c);self.assertEqual(r[0]['location'],'bloc/1')
    def test_fabricated_quote_rejected(self):
        c=self.service.preview('org',[self.reference])
        with self.assertRaises(Unavailable):verify_excerpts(json.dumps({'excerpts':[{'source':'S1','passage':'P1','quote':'Affirmation inventée'}]}),c)
    def test_forged_source_rejected(self):
        c=self.service.preview('org',[self.reference])
        with self.assertRaises(Unavailable):verify_excerpts(json.dumps({'excerpts':[{'source':'S9','passage':'P1','quote':'Réunion prévue mardi'}]}),c)
    def test_extra_instruction_output_rejected(self):
        c=self.service.preview('org',[self.reference])
        with self.assertRaises(Unavailable):verify_excerpts('{"excerpts":[],"publish":true}',c)
    def test_duplicate_json_key_rejected(self):
        c=self.service.preview('org',[self.reference])
        with self.assertRaises(Unavailable):verify_excerpts('{"excerpts":[],"excerpts":[]}',c)
    def provider(self,effect=lambda:None):
        class P:
            def complete(_,prompt,sources,cancelled):
                self.sent=prompt;effect()
                return json.dumps({'excerpts':[{'source':'S1','passage':'P1','quote':'Réunion prévue mardi'}]})
        return P()
    def test_generation_uses_only_sanitized_labeled_content(self):
        self.service.generate('org',[self.reference],self.provider(),lambda:None,lambda:False)
        self.assertNotIn(self.id,self.sent);self.assertNotIn('NEVER',self.sent);self.assertIn('DONNEES_NON_FIABLES',self.sent)
    def test_unregistered_content_never_sent(self):
        self.registered=False
        with self.assertRaises(AccessDenied):self.service.generate('org',[self.reference],self.provider(),lambda:None,lambda:False)
        self.assertFalse(hasattr(self,'sent'))
    def test_revocation_during_model_discards_output(self):
        with self.assertRaises(AccessDenied):self.service.generate('org',[self.reference],self.provider(lambda:setattr(self,'denied',True)),lambda:None,lambda:False)
    def test_version_change_during_model_discards_output(self):
        with self.assertRaises(Denied):self.service.generate('org',[self.reference],self.provider(lambda:self.row.update(version=2)),lambda:None,lambda:False)
    def test_context_limit_refuses_without_truncation(self):
        self.row['blocks'][0]['text']='x'*24001
        with self.assertRaises(Denied):self.service.preview('org',[self.reference])
    def test_message_projection_ignores_other_rows_replies_and_files(self):
        row={'messages':[{'seq':'1','text':'OTHER_PRIVATE'}, {'seq':'2','text':'Sélection autorisée','who':'Camille Recette','created':'date','reply':{'text':'REPLY_SECRET'},'files':['ATTACHMENT_SECRET']}]}
        s=read(lambda *a:row,'org',{'kind':'message','id':self.id,'seq':'2'});self.assertNotIn('SECRET',json.dumps(s));self.assertNotIn('OTHER_PRIVATE',json.dumps(s))
    def test_requested_message_absent_is_refused(self):
        with self.assertRaises(Denied):read(lambda *a:{'messages':[]},'org',{'kind':'message','id':self.id,'seq':'2'})
    def test_case_only_description_and_filtered_history(self):
        row={'long':'Description','timeline':[{'body':'Note','date':'date'}],'title':'Titre','version':1,'owner':'Camille Recette','assignments':'SECRET','files':'SECRET'}
        s=read(lambda *a:row,'org',{'kind':'case','id':self.id});self.assertEqual(len(s['passages']),2);self.assertNotIn('SECRET',json.dumps(s))
    def test_script_and_link_attributes_do_not_enter_context(self):
        self.assertEqual(plain('<script>NEVER</script><p>Texte <a href="https://secret.invalid">utile</a></p>'),'Texte utile')
    def test_mask_names_email_phone_url_and_uuid(self):
        m=Masker(['Camille Recette']);r=m.mask('Camille Recette camille@example.invalid 06 12 34 56 78 https://example.invalid/private '+self.id)
        for x in ['Camille','camille@','06 12','https:',self.id]:self.assertNotIn(x,r)
    def test_mask_unicode_email_and_zero_width(self):
        r=Masker().mask('cami\u200blle＠example.invalid');self.assertNotIn('example.invalid',r)
    def test_mapping_is_not_returned_or_shared(self):
        a=Masker();a.mask('a@example.invalid');self.assertEqual(Masker().mask('b@example.invalid'),'[COURRIEL_1]')
