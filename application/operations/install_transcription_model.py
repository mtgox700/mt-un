"""Explicit public-model download; never called by the application or worker."""
import hashlib,json,pathlib
from huggingface_hub import snapshot_download
ROOT=pathlib.Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'preuves/S09-C/model-manifest.json'
def main():
 manifest=json.loads(REFERENCE.read_text());target=ROOT/'.local-transcription/model'
 snapshot_download(manifest['repository'],revision=manifest['revision'],local_dir=target,allow_patterns=list(manifest['files']))
 for name,digest in manifest['files'].items():
  if hashlib.sha256((target/name).read_bytes()).hexdigest()!=digest:raise ValueError('Model integrity failure')
 (ROOT/'.local-transcription/model-manifest.json').write_text(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
