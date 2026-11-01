begin;
insert into uniion_private.ai_action_definitions values
('formation-course','formations','[]'::jsonb),
('formation-feedback','formations','[]'::jsonb),
('document-compose','documents','[]'::jsonb),
('intranet-compose','intranet','[]'::jsonb),
('meeting-minutes','reunions','["secretaire"]'::jsonb),
('communication-compose','communication','[]'::jsonb),
('poll-options','sondages','[]'::jsonb);
notify pgrst,'reload schema';commit;
