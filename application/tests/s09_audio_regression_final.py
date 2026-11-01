"""Re-run A2 controls without modifying historical evidence."""
from pathlib import Path
source=Path(__file__).with_name('s09_audio_integration.py').read_text().replace('preuves/S09-A2-audio','preuves/S09-B-final/A2-regression')
exec(compile(source,__file__,'exec'))
