import copy,unittest
from uniion.adapters.ai_artifacts import validate
from uniion.core.contracts import Unavailable
class ArtifactTests(unittest.TestCase):
 def setUp(self):
  self.course={'title':'Cours fictif','intro':'Introduction','retenir':['Vérifier'],'sources':'Référence à vérifier','modules':[{'title':'Préparation','minutes':30,'objectif':'Vérifier','points':[{'h':'Faits','text':'Vérifiez les faits.'}],'exemple':'Réunion fictive','exercice':'Question','quiz':{'q':'Quel fait ?','choices':['A','B'],'answer':0,'explain':'Explication'}}]}
  self.sources=[{'passages':[{'location':'dur','text':'dur : 30'}]}]
 def test_course_duration_and_quiz(self):self.assertEqual(validate('formation-course',self.course,self.sources),self.course)
 def test_wrong_duration_and_choice_rejected(self):
  for field,value in [('minutes',20),('minutes',True),('quiz',{'q':'Q','choices':['A','B'],'answer':2,'explain':'X'})]:
   row=copy.deepcopy(self.course);row['modules'][0][field]=value
   with self.assertRaises(Unavailable):validate('formation-course',row,self.sources)
 def test_commands_and_duplicate_choices_rejected(self):
  for action,payload in [('document-compose',{'title':'X','paragraphs':['Texte'],'publish':True}),('poll-options',{'options':['A','A']}),('formation-feedback',{'text':'x'*1201})]:
   with self.assertRaises(Unavailable):validate(action,payload,[])
 def test_oversize_and_unknown_artifact_rejected(self):
  with self.assertRaises(Unavailable):validate('document-compose',{'title':'X','paragraphs':['x'*4001]},[])
