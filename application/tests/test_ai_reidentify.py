import unittest
from uniion.core.ai_context import prepare,token_map,reidentify,plain
from uniion.core.contracts import Denied
SOURCE={'ref':{'kind':'case','id':'00000000-0000-4000-8000-000000000001'},'version':'3','title':'Dossier de Camille Exemple',
 'names':['Camille Exemple','Alex Fictif'],
 'passages':[{'location':'description','text':'Camille Exemple (camille@example.invalid, 06 12 34 56 78) conteste son planning.'},
             {'location':'historique/1','text':'Alex Fictif a reçu Camille Exemple ; IBAN FR76 3000 6000 0112 3456 7890 189.'}]}
class ReidentifyTests(unittest.TestCase):
    def test_masked_passages_are_restored_exactly(self):
        # R12 : le texte appliqué ne doit plus contenir de jetons, et retrouver les valeurs d'origine.
        prepared=prepare([SOURCE]);mapping=token_map([SOURCE])
        for masked,item in zip(prepared['sources'][0]['passages'],SOURCE['passages']):
            self.assertIn('[',masked['text'])
            self.assertEqual(reidentify(masked['text'],mapping),plain(item['text']))
        self.assertEqual(reidentify(prepared['citations'][0]['title'],mapping),SOURCE['title'])
    def test_draft_written_with_tokens(self):
        prepared=prepare([SOURCE]);mapping=token_map([SOURCE])
        person=prepared['sources'][0]['passages'][0]['text'].split(' ')[0]
        draft=f'Recevoir {person} cette semaine.'
        self.assertEqual(reidentify(draft,mapping),'Recevoir Camille Exemple cette semaine.')
    def test_unknown_token_refuses_application(self):
        with self.assertRaises(Denied):reidentify('Contacter [PERSONNE_9] demain.',token_map([SOURCE]))
    def test_text_without_tokens_is_unchanged(self):
        self.assertEqual(reidentify('Aucune donnée masquée [à compléter].',token_map([SOURCE])),'Aucune donnée masquée [à compléter].')
    def test_mapping_matches_prepare_numbering(self):
        prepared=prepare([SOURCE]);mapping=token_map([SOURCE])
        self.assertEqual(prepared['masked']>0,True)
        self.assertTrue(all(k.startswith('[') for k in mapping))
