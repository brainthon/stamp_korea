-- Auth data stays behind a server-only RPC; clients cannot query auth.users.
create schema if not exists admin_private;
revoke all on schema admin_private from public,anon,authenticated;
grant usage on schema admin_private to service_role;
create function admin_private.member_directory(p_query text,p_status text,p_page integer)
returns jsonb language sql stable security definer set search_path='' as $$
with matched as (
 select u.id,u.email,coalesce(nullif(p.nickname,''),u.raw_user_meta_data->>'name','') as nickname,
 u.created_at,u.last_sign_in_at,u.email_confirmed_at,u.banned_until,
 coalesce(u.raw_app_meta_data->>'stamp_admin','false')='true' as is_admin,
 coalesce(u.raw_app_meta_data->'providers','[]'::jsonb) as providers
 from auth.users u left join public.profiles p on p.id=u.id
 where not u.is_anonymous and
 (coalesce(p_query,'')='' or position(lower(p_query) in lower(coalesce(u.email,'')||' '||coalesce(p.nickname,'')||' '||coalesce(u.raw_user_meta_data->>'name','')))>0)
 and (p_status='all' or (p_status='unconfirmed' and u.email_confirmed_at is null)
 or (p_status='restricted' and u.banned_until>now()) or (p_status='admin' and u.raw_app_meta_data->>'stamp_admin'='true'))
), page_rows as (
 select * from matched order by created_at desc,id limit 25 offset greatest(0,least(p_page,10000))*25
), enriched as (
 select r.*,(select count(*) from public.user_collections c where c.user_id=r.id) as collection_count,
 (select count(*) from public.photo_contributions c where c.user_id=r.id) as photo_count from page_rows r
)
select jsonb_build_object('total',(select count(*) from matched),'members',coalesce((select jsonb_agg(e order by e.created_at desc,e.id) from enriched e),'[]'::jsonb));
$$;
revoke all on function admin_private.member_directory(text,text,integer) from public,anon,authenticated;
grant execute on function admin_private.member_directory(text,text,integer) to service_role;
create function public.admin_member_directory(p_query text default '',p_status text default 'all',p_page integer default 0)
returns jsonb language sql stable security invoker set search_path='' as $$
select admin_private.member_directory(p_query,p_status,p_page);
$$;
revoke all on function public.admin_member_directory(text,text,integer) from public,anon,authenticated;
grant execute on function public.admin_member_directory(text,text,integer) to service_role;

create table public.member_admin_actions (
 id uuid primary key default gen_random_uuid(),
 actor_id uuid not null references auth.users(id),
 member_id uuid not null references auth.users(id),
 action text not null check(action in ('restrict','restore')),
 reason text not null check(length(reason) between 3 and 300),
 status text not null default 'pending' check(status in ('pending','success','failed')),
 created_at timestamptz not null default now()
);
alter table public.member_admin_actions enable row level security;
revoke all on public.member_admin_actions from anon,authenticated;
grant select on public.member_admin_actions to authenticated;
grant all on public.member_admin_actions to service_role;
create policy member_actions_admin_read on public.member_admin_actions for select to authenticated
using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create index member_actions_recent on public.member_admin_actions(member_id,created_at desc);
