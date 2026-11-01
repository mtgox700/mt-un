from pathlib import Path
source=Path(__file__).with_name('s06_documents.py').read_text().split("check('anonymous_denied'")[0]
exec(compile(source,__file__,'exec'))
styles=['choc','journal','infographie','institutionnel','photo','serigraphie','bulletin','qr','satirique','bd','annonce','retro']
blocks=['chiffre','compare','frise','photo','qr','coupon','trombi','tampon','surligne','signature','bulles','exige']
doc['blocks']=[{'id':str(i),'type':'studio.'+t,'text':'42\nRecette fictive'} for i,t in enumerate(blocks)]
for i,style in enumerate(styles):
 app.sessions.clock=lambda i=i:time.time()+i*61
 value={**doc,'style':style,'styleOpts':{'palette':0,'font':0}}
 st,r,_=call(x,'create',{'model':'recette','document':value});check(style+'_create',st==200)
 st,loaded,_=call(x,'get',{'id':r['id']});check(style+'_reload',st==200 and loaded['blocks']==value['blocks'] and loaded['style']==style)
out=ROOT/'preuves/S06-logos-extensions';(out/'matrix.json').write_text(json.dumps({'passed':True,'count':len(checks),'checks':checks},indent=2));print(json.dumps({'passed':True,'count':len(checks)}))
