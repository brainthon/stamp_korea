-- Member wishlist and administrator announcements. No notifications are backfilled.
create table public.user_wishlist (
 user_id uuid not null references auth.users(id) on delete cascade,
 stamp_id text not null references public.official_stamp_catalog(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,stamp_id)
);
alter table public.user_wishlist enable row level security;
revoke all on public.user_wishlist from public,anon,authenticated;
grant select,insert,update,delete on public.user_wishlist to authenticated;
create policy wishlist_owner on public.user_wishlist for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop function if exists public.import_my_wishlist(text[]);
create function public.import_my_wishlist(p_ids text[], p_owner uuid) returns void language sql security invoker set search_path='' as $$
 insert into public.user_wishlist(user_id,stamp_id)
 select auth.uid(),c.id from public.official_stamp_catalog c where c.id=any(p_ids[1:500]) and auth.uid()=p_owner
 on conflict(user_id,stamp_id) do nothing;
$$;
revoke all on function public.import_my_wishlist(text[],uuid) from public,anon;
grant execute on function public.import_my_wishlist(text[],uuid) to authenticated;

alter table public.member_notifications add column source_key text unique;
alter table public.member_notifications add column stamp_id text references public.official_stamp_catalog(id) on delete set null;
create table public.member_announcements (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(btrim(title)) between 1 and 160),
 body text not null check(char_length(btrim(body)) between 1 and 10000),
 status text not null default 'draft' check(status in ('draft','published')),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 published_at timestamptz
);
alter table public.member_announcements enable row level security;
revoke all on public.member_announcements from public,anon,authenticated;
grant select,insert,update on public.member_announcements to authenticated;
create policy announcements_admin_read on public.member_announcements for select to authenticated using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy announcements_admin_insert on public.member_announcements for insert to authenticated with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and created_by=(select auth.uid()) and status='draft' and published_at is null);
create policy announcements_admin_update on public.member_announcements for update to authenticated using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and status='draft') with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
grant insert on public.member_notifications to authenticated;
create policy notifications_admin_publish on public.member_notifications for insert to authenticated with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and user_id is null and kind='announcement' and stamp_id is null and source_key like 'announcement:%');
create or replace function public.publish_member_announcement(p_id uuid) returns uuid language plpgsql security invoker set search_path='' as $$
declare a public.member_announcements; notice uuid;
begin
 if auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'stamp_admin','false')<>'true' then raise exception 'Administrator required' using errcode='42501'; end if;
 select * into a from public.member_announcements where id=p_id;
 if a.status='published' then
  select id into notice from public.member_notifications where source_key='announcement:'||p_id::text;
  if notice is null then raise exception 'Publication could not be verified'; end if;
  return notice;
 end if;
 select * into a from public.member_announcements where id=p_id for update;
 if not found then
  select id into notice from public.member_notifications where source_key='announcement:'||p_id::text;
  if notice is not null then return notice; end if;
 end if;
 if not found then raise exception 'Announcement not found' using errcode='22023'; end if;
 if a.status='draft' then
  update public.member_announcements set status='published',published_at=now() where id=p_id;
  insert into public.member_notifications(kind,title,body,source_key) values('announcement',a.title,a.body,'announcement:'||p_id::text) returning id into notice;
 else
  select id into notice from public.member_notifications where source_key='announcement:'||p_id::text;
 end if;
 if notice is null then raise exception 'Publication could not be verified'; end if;
 return notice;
end;
$$;
revoke all on function public.publish_member_announcement(uuid) from public,anon;
grant execute on function public.publish_member_announcement(uuid) to authenticated;

create schema if not exists notification_private;
revoke all on schema notification_private from public,anon,authenticated;
-- Internal catalogue trigger must insert notifications even when catalogue writes
-- use a member-scoped administrator connection. It is not callable by clients.
create function notification_private.catalog_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare issued date;
begin
 if not new.source_verified then return new; end if;
 if tg_op='UPDATE' and old.source_verified then return new; end if;
 if coalesce(new.data->>'issue_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return new; end if;
 begin issued:=(new.data->>'issue_date')::date; exception when datetime_field_overflow or invalid_datetime_format then return new; end;
 if issued < (now() at time zone 'Asia/Seoul')::date-14 or issued > (now() at time zone 'Asia/Seoul')::date+90 then return new; end if;
 insert into public.member_notifications(kind,title,body,stamp_id,source_key)
 values('new_stamp','신규 우표가 도감에 등록됐어요',new.name||E'\n발행일: '||issued::text||E'\n우표도감에서 이미지와 발행 정보를 확인하세요.',new.id,'stamp:'||new.id)
 on conflict(source_key) do nothing;
 return new;
end;
$$;
revoke all on function notification_private.catalog_notice() from public,anon,authenticated;
create trigger official_catalog_notice after insert or update of source_verified on public.official_stamp_catalog for each row execute function notification_private.catalog_notice();
