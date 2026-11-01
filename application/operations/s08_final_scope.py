"""Isolate acceptance output; refuse any write to historical evidence."""
from pathlib import Path
import sys,os
ROOT=Path(__file__).resolve().parents[1]
def install(suite):
 destination=ROOT/'preuves/S08-F-final'/suite;destination.mkdir(parents=True,exist_ok=True)
 private=ROOT/'.local-auth/s08-f-final'/suite;private.mkdir(parents=True,exist_ok=True)
 methods={n:getattr(Path,n) for n in ('write_text','write_bytes','read_text','read_bytes','mkdir','chmod')}
 redirected={}
 def target(p,write=False):
  p=Path(os.path.abspath(p))
  if p in redirected:return redirected[p]
  if write:
   if p.is_relative_to(ROOT/'preuves') and not p.is_relative_to(ROOT/'preuves/S08-F-final'):
    q=destination/p.relative_to(ROOT/'preuves');redirected[p]=q;methods['mkdir'](q.parent,parents=True,exist_ok=True);return q
   if p.is_relative_to(ROOT/'.local-auth') and not p.is_relative_to(ROOT/'.local-auth/s08-f-final'):
    q=private/p.relative_to(ROOT/'.local-auth');redirected[p]=q;methods['mkdir'](q.parent,parents=True,exist_ok=True);return q
  return p
 for name in ('write_text','write_bytes','read_text','read_bytes','chmod'):
  def wrapped(self,*args,_name=name,**kw):return methods[_name](target(self,_name.startswith('write')),*args,**kw)
  setattr(Path,name,wrapped)
 def mkdir(self,*args,**kw):return methods['mkdir'](target(self,True),*args,**{**kw,'parents':True})
 Path.mkdir=mkdir
 def audit(event,args):
  if event=='open' and isinstance(args[0],(str,bytes,os.PathLike)):
   p=Path(os.path.abspath(os.fsdecode(args[0])));flags=args[2] or 0
   if flags & (os.O_WRONLY|os.O_RDWR|os.O_CREAT|os.O_TRUNC) and p.is_relative_to(ROOT/'preuves') and not p.is_relative_to(ROOT/'preuves/S08-F-final'):
    raise PermissionError('Historical proof write blocked')
 sys.addaudithook(audit)
 return destination
