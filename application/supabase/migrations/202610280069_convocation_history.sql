begin;
create function public.uniion_convocation_history(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
perform public.uniion_module_use(p_org,'agenda');
return coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'event',c.event_id,'subject',c.message->>'subject','body',c.message->>'body','created',c.created_at,'mine',c.actor=auth.uid(),'sent',(select count(*) from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.status='sent'),'uncertain',(select count(*) from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.status in ('sending','uncertain'))) order by c.created_at desc,c.id) from uniion_private.agenda_convocations c join uniion_private.agenda_events e on e.id=c.event_id join public.uniion_memberships m on m.organization_id=e.organization_id and m.user_id=auth.uid() where e.organization_id=p_org and c.created_at>=m.joined_at and uniion_private.agenda_visible(p_org,e.data) and (c.actor=auth.uid() or exists(select 1 from uniion_private.agenda_convocation_deliveries d where d.convocation=c.id and d.user_id=auth.uid() and d.status='sent'))),'[]'::jsonb);
end $$;
revoke all on function public.uniion_convocation_history(uuid) from public,anon;
grant execute on function public.uniion_convocation_history(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
