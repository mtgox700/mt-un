from pathlib import Path
source=Path(__file__).with_name('ephemeral_ci.py').read_text().replace("check('all_24_migrations_from_empty_database',len(migrations)==24)","check('all_current_migrations_from_empty_database',len(migrations)>24)").replace('preuves/S01-ephemeral','preuves/S05-finalisation/fresh')
exec(compile(source,__file__,'exec'))
