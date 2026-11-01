"""Replay historical audio behavior into current proof directory only."""
from pathlib import Path
source=Path(__file__).with_name('s09_audio_integration.py').read_text().replace('preuves/S09-A2-audio','preuves/S09-C/A2-regression')
exec(compile(source,__file__,'exec'))
