-- Applied to the existing stamp_app project; preserves existing tables and records.
drop policy if exists profiles_policy on public.profiles;
drop policy if exists user_collections_policy on public.user_collections;
drop policy if exists stamps_policy on public.stamps;
drop policy if exists stamp_images_policy on storage.objects;
create policy profiles_read_self on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_self on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_self on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy collections_owner on public.user_collections for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create index if not exists user_collections_owner_idx on public.user_collections(user_id);
create policy stamps_read on public.stamps for select to anon, authenticated using (true);
-- Existing legacy bucket also becomes private; no existing files are deleted.
update storage.buckets set public = false where id = 'stamp-images';
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('stamp-photos','stamp-photos',false,4194304,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=4194304,allowed_mime_types=array['image/jpeg'];
create policy photos_owner on storage.objects for all to authenticated
using (bucket_id in ('stamp-photos','stamp-images') and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id in ('stamp-photos','stamp-images') and (storage.foldername(name))[1] = (select auth.uid())::text);

create table public.scan_usage (
 user_id uuid not null references auth.users(id) on delete cascade,
 usage_day date not null default current_date,
 requests integer not null default 0,
 primary key(user_id,usage_day)
);
alter table public.scan_usage enable row level security;
-- Server-only atomic quota, never directly callable with an app key.
create function public.reserve_stamp_scan(p_user_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare allowed boolean;
begin
 insert into public.scan_usage(user_id,usage_day,requests) values(p_user_id,current_date,1)
 on conflict(user_id,usage_day) do update set requests=public.scan_usage.requests+1
 where public.scan_usage.requests < 20 returning true into allowed;
 return coalesce(allowed,false);
end $$;
revoke all on function public.reserve_stamp_scan(uuid) from public,anon,authenticated;
grant execute on function public.reserve_stamp_scan(uuid) to service_role;
create policy scan_usage_read_self on public.scan_usage for select to authenticated using ((select auth.uid()) = user_id);
-- Preserve the unowned legacy record. New records must have a valid owner.
alter table public.user_collections add constraint user_collections_owner_required check (user_id is not null) not valid;
alter table public.user_collections add constraint user_collections_user_fkey foreign key (user_id) references auth.users(id) on delete cascade not valid;
alter table public.user_collections add constraint user_collections_positive_count check (count > 0) not valid;
