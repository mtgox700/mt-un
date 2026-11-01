"""Validated output schemas for the existing specialist editors; no executable fields."""
from uniion.core.contracts import Unavailable
SPECS={
 'formation-course':{'mod':'formations','label':'Préparer une autoformation','ask':'Prépare un cours pédagogique à partir de la configuration et des sources. Ne présente aucune référence juridique absente comme certaine. artifact contient title, intro, modules, retenir, sources. Chaque module contient title, minutes, objectif, points (h,text), exemple, exercice, quiz (q,choices,answer,explain). De 1 à 8 modules, 2 à 4 choix par quiz. La durée totale égale la durée demandée. Types obligatoires : title, intro et sources sont des chaînes de texte ; retenir est une liste de chaînes ; minutes est un entier ; points est une liste d’objets {h: chaîne, text: chaîne} ; choices est une liste de chaînes ; answer est l’indice entier de la bonne réponse, à partir de 0, jamais le texte de la réponse ; explain est une chaîne. Chaque objet contient exactement ces clés, sans ajout. Toutes les références non présentes dans les sources portent la mention « référence à vérifier ».'},
 'formation-feedback':{'mod':'formations','label':'Relire mon exercice','ask':'Relis la réponse à l’exercice du module courant : points corrects, points à vérifier, piste d’amélioration. artifact contient uniquement text, de 1200 caractères maximum.'},
 'document-compose':{'mod':'documents','label':'Rédiger un document','ask':'Rédige un document à partir du brief fourni. artifact contient title et paragraphs (1 à 12 paragraphes). Les faits absents restent [à compléter].'},
 'intranet-compose':{'mod':'intranet','label':'Rédiger une page','ask':'Rédige une page claire à partir du brief. artifact contient title et paragraphs (1 à 12 paragraphes). Aucun HTML, URL ni pièce jointe inventée.'},
 'meeting-minutes':{'mod':'reunions','label':'Rédiger le procès-verbal','ask':'Prépare un projet de procès-verbal distinguant ordre du jour, faits et décisions effectivement rapportées. Ne crée ni vote ni décision absente. artifact contient title et paragraphs (1 à 12 paragraphes).'},
 'communication-compose':{'mod':'communication','label':'Rédiger une publication','ask':'Rédige une proposition de publication selon le format, le ton et les faits fournis. artifact contient titre, accroche, corps, appel, visuel. Les faits absents restent [à compléter].'},
 'poll-options':{'mod':'sondages','label':'Proposer des réponses','ask':'Propose entre 2 et 6 réponses neutres et distinctes à la question de sondage. artifact contient uniquement options, liste de textes courts.'}}

def text(v,limit=6000,empty=False):
 if not isinstance(v,str) or len(v)>limit or (not empty and not v.strip()) or any(ord(c)<32 and c not in '\n\t\r' for c in v):raise ValueError()
 return v

def keys(v,names):
 if not isinstance(v,dict) or set(v)!=set(names.split()):raise ValueError()

def texts(v,lo,hi,limit=6000):
 if not isinstance(v,list) or not lo<=len(v)<=hi:raise ValueError()
 for x in v:text(x,limit)

def validate(action,v,sources):
 try:
  if action=='formation-course':
   keys(v,'title intro modules retenir sources');text(v['title'],200);text(v['intro'],2000);text(v['sources'],3000);texts(v['retenir'],1,8,1000)
   if not isinstance(v['modules'],list) or not 1<=len(v['modules'])<=8:raise ValueError()
   for m in v['modules']:
    keys(m,'title minutes objectif points exemple exercice quiz')
    for k in ('title','objectif','exemple','exercice'):text(m[k],2000)
    if type(m['minutes'])!=int or not 1<=m['minutes']<=120:raise ValueError()
    if not isinstance(m['points'],list) or not 1<=len(m['points'])<=5:raise ValueError()
    for p in m['points']:keys(p,'h text');text(p['h'],200);text(p['text'],3000)
    q=m['quiz'];keys(q,'q choices answer explain');text(q['q'],1000);text(q['explain'],1500);texts(q['choices'],2,4,500)
    if type(q['answer'])!=int or not 0<=q['answer']<len(q['choices']):raise ValueError()
   duration=next((p['text'].split(' : ',1)[1] for s in sources for p in s['passages'] if p['location']=='dur'),None)
   if duration is None or sum(m['minutes'] for m in v['modules'])!=int(duration):raise ValueError()
  elif action=='formation-feedback':keys(v,'text');text(v['text'],1200)
  elif action=='poll-options':keys(v,'options');texts(v['options'],2,6,200);assert len(set(v['options']))==len(v['options'])
  elif action=='communication-compose':
   keys(v,'titre accroche corps appel visuel')
   for k in v:text(v[k],6000,empty=k!='corps')
  else:keys(v,'title paragraphs');text(v['title'],200);texts(v['paragraphs'],1,12,4000)
  return v
 except (ValueError,TypeError,KeyError,AssertionError):raise Unavailable('ai_artifact_invalid') from None
