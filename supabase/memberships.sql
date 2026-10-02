-- Only trusted server code can change a membership; profile metadata is unrelated.
create table public.member_memberships (
 user_id uuid primary key references auth.users(id) on delete cascade,
 plan text not null default 'free' check(plan in ('free','premium')),
 subscription_status text not null default 'inactive' check(subscription_status in ('inactive','active','canceled','expired')),
 period_start timestamptz,
 period_end timestamptz,
 updated_at timestamptz not null default now(),
 check((plan='free' and subscription_status='inactive' and period_start is null and period_end is null)
 or (plan='premium' and subscription_status in ('active','canceled','expired') and period_start is not null and period_end is not null and period_end>period_start))
);
alter table public.member_memberships enable row level security;
revoke all on public.member_memberships from anon,authenticated;
grant select on public.member_memberships to authenticated;
grant all on public.member_memberships to service_role;
create policy membership_read_self on public.member_memberships for select to authenticated
using(user_id=(select auth.uid()));
insert into public.member_memberships(user_id) select id from auth.users where not is_anonymous on conflict do nothing;

create function admin_private.initialize_membership() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.member_memberships(user_id) values(new.id) on conflict do nothing;
 return new;
end $$;
revoke all on function admin_private.initialize_membership() from public,anon,authenticated;
create trigger initialize_stamp_membership after insert on auth.users for each row execute function admin_private.initialize_membership();

create function public.get_my_membership() returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare m public.member_memberships;
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='42501'; end if;
 select * into m from public.member_memberships where user_id=auth.uid();
 return jsonb_build_object(
  'plan',coalesce(m.plan,'free'),
  'effective_plan',case when m.plan='premium' and m.subscription_status in ('active','canceled') and m.period_start<=now() and m.period_end>now() then 'premium' else 'free' end,
  'subscription_status',case when m.plan='premium' and m.period_end<=now() then 'expired' else coalesce(m.subscription_status,'inactive') end,
  'period_start',m.period_start,'period_end',m.period_end);
end $$;
revoke all on function public.get_my_membership() from public,anon;
grant execute on function public.get_my_membership() to authenticated;

create function admin_private.member_directory_with_plan(p_query text,p_status text,p_page integer,p_plan text)
returns jsonb language sql stable security definer set search_path='' as $$
with members as (
 select u.id,u.email,coalesce(nullif(p.nickname,''),u.raw_user_meta_data->>'name','') as nickname,
 u.created_at,u.last_sign_in_at,u.email_confirmed_at,u.banned_until,
 coalesce(u.raw_app_meta_data->>'stamp_admin','false')='true' as is_admin,
 coalesce(u.raw_app_meta_data->'providers','[]'::jsonb) as providers,
 coalesce(m.plan,'free') as plan,
 case when m.plan='premium' and m.subscription_status in ('active','canceled') and m.period_start<=now() and m.period_end>now() then 'premium' else 'free' end as effective_plan,
 case when m.plan='premium' and m.period_end<=now() then 'expired' else coalesce(m.subscription_status,'inactive') end as subscription_status,
 m.period_start,m.period_end
 from auth.users u left join public.profiles p on p.id=u.id left join public.member_memberships m on m.user_id=u.id
 where not u.is_anonymous and
 (coalesce(p_query,'')='' or position(lower(p_query) in lower(coalesce(u.email,'')||' '||coalesce(p.nickname,'')||' '||coalesce(u.raw_user_meta_data->>'name','')))>0)
 and (p_status='all' or (p_status='unconfirmed' and u.email_confirmed_at is null)
 or (p_status='restricted' and u.banned_until>now()) or (p_status='admin' and u.raw_app_meta_data->>'stamp_admin'='true'))
), matched as (
 select * from members where p_plan='all' or effective_plan=p_plan
), page_rows as (
 select * from matched order by created_at desc,id limit 25 offset greatest(0,least(p_page,10000))*25
), enriched as (
 select r.*,(select count(*) from public.user_collections c where c.user_id=r.id) as collection_count,
 (select count(*) from public.photo_contributions c where c.user_id=r.id) as photo_count from page_rows r
)
select jsonb_build_object('total',(select count(*) from matched),'members',coalesce((select jsonb_agg(e order by e.created_at desc,e.id) from enriched e),'[]'::jsonb));
$$;
revoke all on function admin_private.member_directory_with_plan(text,text,integer,text) from public,anon,authenticated;
grant execute on function admin_private.member_directory_with_plan(text,text,integer,text) to service_role;
create function public.admin_member_directory_by_plan(p_query text,p_status text,p_page integer,p_plan text)
returns jsonb language sql stable security invoker set search_path='' as $$
select admin_private.member_directory_with_plan(p_query,p_status,p_page,p_plan);
$$;
revoke all on function public.admin_member_directory_by_plan(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.admin_member_directory_by_plan(text,text,integer,text) to service_role;
