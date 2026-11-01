"""Replay C without overwriting previous proofs."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
shutil.copyfile(root/'preuves/S09-C/parole-fictive.wav',root/'preuves/S09-D/C-regression/parole-fictive.wav')
s=Path(__file__).with_name('s09_transcription_integration.py').read_text().replace('preuves/S09-C','preuves/S09-D/C-regression')
exec(compile(s,__file__,'exec'))
