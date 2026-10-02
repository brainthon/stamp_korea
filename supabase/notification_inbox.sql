create table if not exists public.member_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid references auth.users(id) on delete cascade,
 kind text not null check(kind in ('announcement','new_stamp','wishlist','exchange','event')),
 title text not null check(char_length(title) between 1 and 160),
 body text not null default '',
 created_at timestamptz not null default now()
);
create index if not exists member_notifications_owner_date on public.member_notifications(user_id,created_at desc,id desc);
alter table public.member_notifications enable row level security;
revoke all on public.member_notifications from public,anon,authenticated;
grant select on public.member_notifications to authenticated;
create policy member_notifications_visible on public.member_notifications for select to authenticated using (user_id is null or user_id=(select auth.uid()));
create table if not exists public.member_notification_reads (
 user_id uuid not null references auth.users(id) on delete cascade,
 notification_id uuid not null references public.member_notifications(id) on delete cascade,
 read_at timestamptz not null default now(),
 primary key(user_id,notification_id)
);
alter table public.member_notification_reads enable row level security;
revoke all on public.member_notification_reads from public,anon,authenticated;
grant select,insert on public.member_notification_reads to authenticated;
create policy member_notification_reads_self on public.member_notification_reads for select to authenticated using (user_id=(select auth.uid()));
create policy member_notification_reads_insert on public.member_notification_reads for insert to authenticated with check (user_id=(select auth.uid()) and exists(select 1 from public.member_notifications n where n.id=notification_id));
create or replace function public.my_unread_notification_count() returns bigint language sql stable security invoker set search_path='' as $$
 select count(*) from public.member_notifications n where auth.uid() is not null and not exists(select 1 from public.member_notification_reads r where r.notification_id=n.id and r.user_id=auth.uid());
$$;
revoke all on function public.my_unread_notification_count() from public,anon;
grant execute on function public.my_unread_notification_count() to authenticated;
