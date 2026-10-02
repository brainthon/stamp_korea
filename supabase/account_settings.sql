create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  new_stamps boolean not null default false,
  wishlist_matches boolean not null default false,
  exchange_updates boolean not null default false,
  events boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from public, anon;
grant select, insert, update on public.notification_preferences to authenticated;
create policy notification_preferences_read_self on public.notification_preferences for select to authenticated using ((select auth.uid()) = user_id);
create policy notification_preferences_insert_self on public.notification_preferences for insert to authenticated with check ((select auth.uid()) = user_id);
create policy notification_preferences_update_self on public.notification_preferences for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create or replace function public.set_my_nickname(p_nickname text) returns text
language plpgsql security invoker set search_path = '' as $$
declare uid uuid := auth.uid(); n text := btrim(p_nickname);
begin
  if uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Authentication required' using errcode='42501'; end if;
  if n is null or char_length(n) < 2 or char_length(n) > 20 or n ~ '[[:cntrl:]]' then raise exception 'Nickname must contain 2 to 20 characters without control characters' using errcode='22023'; end if;
  insert into public.profiles(id,nickname) values(uid,n) on conflict(id) do update set nickname=excluded.nickname;
  return n;
end;
$$;
revoke all on function public.set_my_nickname(text) from public, anon;
grant execute on function public.set_my_nickname(text) to authenticated;
