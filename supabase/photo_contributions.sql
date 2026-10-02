create table public.photo_contributions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 stamp_id text not null references public.official_stamp_catalog(id),
 image_path text not null unique,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 consent_version text not null check(consent_version='2026-09-30-v1'),
 reference_consent boolean not null check(reference_consent),
 training_consent boolean not null default false,
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id),
 review_note text not null default '' check(length(review_note)<=1000),
 check(image_path = user_id::text || '/' || id::text || '.jpg')
);
alter table public.photo_contributions enable row level security;
revoke all on public.photo_contributions from anon,authenticated;
grant select,insert,delete on public.photo_contributions to authenticated;
grant update(status,stamp_id,reviewed_at,reviewed_by,review_note) on public.photo_contributions to authenticated;
create index photo_contributions_owner on public.photo_contributions(user_id);
create index photo_contributions_approved on public.photo_contributions(stamp_id,created_at) where status='approved';
create policy contributions_read on public.photo_contributions for select to authenticated using (user_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy contributions_submit on public.photo_contributions for insert to authenticated with check(user_id=(select auth.uid()) and status='pending' and reviewed_by is null and reviewed_at is null and review_note='');
create policy contributions_withdraw on public.photo_contributions for delete to authenticated using(user_id=(select auth.uid()));
create policy contributions_review on public.photo_contributions for update to authenticated using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true') with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and reviewed_by=(select auth.uid()) and reviewed_at is not null);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('recognition-contributions','recognition-contributions',false,1048576,array['image/jpeg']);
create policy contributions_upload on storage.objects for insert to authenticated with check(bucket_id='recognition-contributions' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.photo_contributions c where c.image_path=name));
create policy contributions_photo_read on storage.objects for select to authenticated using(bucket_id='recognition-contributions' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select auth.jwt()->'app_metadata'->>'stamp_admin')='true'));
create policy contributions_photo_delete on storage.objects for delete to authenticated using(bucket_id='recognition-contributions' and (storage.foldername(name))[1]=(select auth.uid())::text);
