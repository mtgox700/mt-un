"""Replay the existing fresh Supabase drill with all current migrations and new evidence."""
from pathlib import Path
source=Path(__file__).with_name('ephemeral_ci.py').read_text()
source=source.replace("check('all_24_migrations_from_empty_database',len(migrations)==24)","check('all_current_migrations_from_empty_database',len(migrations)>24)")
source=source.replace("preuves/S01-ephemeral","preuves/S04-cloture/fresh")
exec(compile(source,__file__,'exec'))
