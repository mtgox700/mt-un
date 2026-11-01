"""Minimal projections of native module contracts, never browser corpus."""
import json
from uniion.core.contracts import Denied
KINDS=('agenda','adherents','workspace','reunions','communication','mobile','formations','sondages','intranet','reporting','raccourcis')
FIELDS={
 'agenda':('title','type','date','start','end','lieu','notes'),
 'adherents':('poste','ent','etab','mandat','since','statut'),
 'workspace':('description',),
 'reunions':('title','type','date','ordre','markers','transcript','minutes'),
 'communication':('title','date','fmt','canal','obj','ton','sujet','content','items'),
 'mobile':('title','type','aud','blocks','push','subject'),
 'formations':('theme','dur','level','role','goal','intro','modules','retenir','sources','cur','ex'),
 'sondages':('title','question','options','description','mode'),
 'intranet':('title','description','blocks'),
 'reporting':('title','period','indicators','description'),
 'raccourcis':('title','items','description')}
def native_read(call,org,ref):
 row=call('/rest/v1/rpc/uniion_ai_native',{'p_org':org,'p_kind':ref['kind'],'p_id':ref['id']})
 passages=[]
 for key in FIELDS[ref['kind']]:
  value=row.get(key)
  if value is None or value=='' or value==[]:continue
  text=value if isinstance(value,str) else json.dumps(value,ensure_ascii=False)
  passages.append({'location':key,'text':key+' : '+text})
 if not passages:raise Denied('ai_empty_source')
 names=[str(row.get('prenom',''))+' '+str(row.get('nom',''))] if ref['kind']=='adherents' else []
 return row.get('title','Fiche membre'),str(row['version']),passages,names
