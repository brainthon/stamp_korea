-- Aggregates only; no member emails, photographs or tokens leave this endpoint.
create function admin_private.operating_stats(p_days integer) returns jsonb
language sql stable security definer set search_path='' as $$
with bounds as (
 select (now() at time zone 'UTC')::date as today,
 (now() at time zone 'UTC')::date-greatest(1,least(p_days,30))+1 as first_day
), members as (
 select u.id,u.created_at,
 (m.plan='premium' and m.subscription_status in ('active','canceled') and m.period_start<=now() and m.period_end>now()) is_premium
 from auth.users u left join public.member_memberships m on m.user_id=u.id where not u.is_anonymous
), days as (
 select generate_series(first_day::timestamp,today::timestamp,interval '1 day')::date as day_key from bounds
), signups as (
 select (created_at at time zone 'UTC')::date as day_key,count(*) n from members,bounds
 where created_at >= first_day::timestamp at time zone 'UTC' group by 1
), scans as (
 select usage_day as day_key,sum(requests) n from public.scan_usage,bounds where usage_day between first_day and today group by 1
), imports as (
 select r.* from public.catalog_import_runs r,bounds where started_at>=first_day::timestamp at time zone 'UTC'
)
select jsonb_build_object(
 'generated_at',now(),'timezone','UTC','days',greatest(1,least(p_days,30)),
 'members',jsonb_build_object('total',(select count(*) from members),'premium',(select count(*) from members where is_premium),'free',(select count(*) from members where not coalesce(is_premium,false)),'new',(select coalesce(sum(n),0) from signups)),
 'scans',(select coalesce(sum(n),0) from scans),
 'series',(select jsonb_agg(jsonb_build_object('day',d.day_key,'signups',coalesce(s.n,0),'scans',coalesce(c.n,0)) order by d.day_key) from days d left join signups s using(day_key) left join scans c using(day_key)),
 'collections',jsonb_build_object('entries',(select count(*) from public.user_collections where user_id is not null),'quantity',(select coalesce(sum(count),0) from public.user_collections where user_id is not null)),
 'photos',jsonb_build_object('total',(select count(*) from public.photo_contributions),'pending',(select count(*) from public.photo_contributions where status='pending'),'approved',(select count(*) from public.photo_contributions where status='approved'),'rejected',(select count(*) from public.photo_contributions where status='rejected')),
 'catalog',(select count(*) from public.official_stamp_catalog),
 'imports',jsonb_build_object('success',(select count(*) from imports where status='success'),'failed',(select count(*) from imports where status='failed'),'running',(select count(*) from imports where status='running'),'inserted',(select coalesce(sum(imported_count),0) from imports where status='success' and kind='scheduled_import'))
);
$$;
revoke all on function admin_private.operating_stats(integer) from public,anon,authenticated;
grant execute on function admin_private.operating_stats(integer) to service_role;
create function public.admin_operating_stats(p_days integer default 7) returns jsonb
language sql stable security invoker set search_path='' as $$ select admin_private.operating_stats(p_days); $$;
revoke all on function public.admin_operating_stats(integer) from public,anon,authenticated;
grant execute on function public.admin_operating_stats(integer) to service_role;
