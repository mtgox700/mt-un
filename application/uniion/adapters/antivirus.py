"""Real ClamAV INSTREAM scanner, fail closed. Content never leaves loopback."""
import socket,struct,datetime,time,json,pathlib,threading,subprocess,base64,tempfile,os,uuid,selectors
def _tool(variable,default,name):
 # Configurable path (R2): explicit variable, then historical local path, then PATH lookup.
 import shutil
 value=os.environ.get(variable)
 if value:return value
 return default if os.path.exists(default) else (shutil.which(name) or default)
ROOT=pathlib.Path(os.environ.get('UNIION_LOCAL_STATE_ROOT',str(pathlib.Path(__file__).resolve().parents[3]/'prototype-evolution/organisation-droits-partage')))
PYTHON=_tool('UNIION_PYTHON','/Users/mt/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3','python3')
LOCK=threading.Lock();IDENTITY=None
RENDERS=threading.BoundedSemaphore(2)
DOCKER=_tool('UNIION_DOCKER','/Users/mt/.docker/bin/docker','docker')
# Immutable local image ID: no runtime image pull or tag replacement.
RENDER_IMAGE='sha256:bf334ee257e5cd1b985e15f1d4bffd042bf6829c6e7809703181733e3d16a05d'
class ScanUnavailable(Exception):pass
class FileBlocked(Exception):pass
class PreviewUnavailable(Exception):pass

def reply(s):
 out=b''
 while len(out)<4096:
  b=s.recv(4096)
  if not b:break
  out+=b
  if b'\0' in out:break
 return out.rstrip(b'\0\n').decode('utf-8','replace')
def scan(raw):
 try:
  with socket.create_connection(('127.0.0.1',3310),timeout=5) as s:s.sendall(b'zVERSION\0');engine=reply(s)
  stamp=engine.rsplit('/',1)[1];updated=datetime.datetime.strptime(stamp,'%a %b %d %H:%M:%S %Y').replace(tzinfo=datetime.timezone.utc).timestamp()
  if not -86400<time.time()-updated<7*86400:raise ScanUnavailable('Signatures antivirus trop anciennes')
  with socket.create_connection(('127.0.0.1',3310),timeout=5) as s:
   s.settimeout(45);s.sendall(b'zINSTREAM\0')
   for i in range(0,len(raw),65536):part=raw[i:i+65536];s.sendall(struct.pack('!I',len(part))+part)
   s.sendall(struct.pack('!I',0));result=reply(s)
  if result.endswith(' FOUND'):return 'infected',engine,'Menace detectee'
  if result!='stream: OK':raise ScanUnavailable('Analyse non terminee')
  return 'clean',engine,''
 except (OSError,ValueError,IndexError) as e:raise ScanUnavailable('Antivirus indisponible') from None

def bounded_process(cmd,payload,timeout=30,max_output=6*1024*1024):
 # Bound parent-side output too: a compromised renderer must not exhaust the gateway.
 process=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
 chunks=[];size=0;sent=0;deadline=time.monotonic()+timeout
 try:
  os.set_blocking(process.stdin.fileno(),False);os.set_blocking(process.stdout.fileno(),False)
  with selectors.DefaultSelector() as selector:
   if payload:selector.register(process.stdin,selectors.EVENT_WRITE)
   else:process.stdin.close()
   selector.register(process.stdout,selectors.EVENT_READ)
   while selector.get_map():
    remaining=deadline-time.monotonic()
    if remaining<=0:raise subprocess.TimeoutExpired(cmd,timeout)
    for key,_ in selector.select(min(remaining,.1)):
     if key.fileobj is process.stdin:
      try:sent+=os.write(key.fd,payload[sent:sent+65536])
      except BrokenPipeError:sent=len(payload)
      if sent==len(payload):selector.unregister(process.stdin);process.stdin.close()
     else:
      part=os.read(key.fd,65536)
      if not part:selector.unregister(process.stdout)
      else:
       size+=len(part)
       if size>max_output:raise FileBlocked('Sortie du moteur hors limites')
       chunks.append(part)
   code=process.wait(timeout=max(.001,deadline-time.monotonic()))
   return subprocess.CompletedProcess(cmd,code,b''.join(chunks))
 finally:
  if process.poll() is None:process.kill();process.wait(timeout=5)
  process.stdin.close();process.stdout.close()

def renderer(raw,mime,page=1,preview=False):
 if not RENDERS.acquire(blocking=False):raise ScanUnavailable('Service de rendu occupé')
 name='uniion-render-'+uuid.uuid4().hex
 try:
  cmd=[DOCKER,'run','--rm','-i','--name',name,'--network','none','--read-only','--user','65532:65532','--cap-drop','ALL','--security-opt','no-new-privileges','--memory','384m','--memory-swap','384m','--cpus','1','--pids-limit','64','--tmpfs','/tmp:rw,noexec,nosuid,size=64m,uid=65532,gid=65532',RENDER_IMAGE]
  r=bounded_process(cmd,json.dumps({'content':base64.b64encode(raw).decode(),'mime':mime,'page':page,'preview':preview}).encode())
  if r.returncode or len(r.stdout)>6*1024*1024:raise FileBlocked('Fichier non visualisable ou hors limites')
  result=json.loads(r.stdout)
  if not result.get('ok'):raise FileBlocked('Format non accepte')
  return result
 except (OSError,subprocess.TimeoutExpired,ValueError):raise FileBlocked('Validation du format non terminee') from None
 finally:
  # Only the unique ephemeral processing container, never a data/backup volume.
  try:subprocess.run([DOCKER,'rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=5)
  except (OSError,subprocess.TimeoutExpired):pass
  RENDERS.release()

def worker_token(api):
 global IDENTITY
 with LOCK:
  if not IDENTITY or IDENTITY.get('expires_at',0)<time.time()+60:
   try:
    cfg=json.loads((ROOT/'.local-auth/scanner.json').read_text());IDENTITY=api.login(cfg['email'],cfg['password'])
   except Exception:raise ScanUnavailable('Service de scan indisponible') from None
  return IDENTITY['access_token']
