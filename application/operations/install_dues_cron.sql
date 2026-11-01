-- Local/cible explicite uniquement. Aucun secret, aucune suppression.
create extension if not exists pg_cron;
select cron.schedule('uniion-dues-hourly','7 * * * *','select uniion_private.run_dues_schedules();');
