create policy official_admin_upload on storage.objects for insert to authenticated
with check(bucket_id='official-stamps' and (select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and name like 'admin/%');
create policy official_admin_read on storage.objects for select to authenticated
using(bucket_id='official-stamps' and (select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy official_admin_cleanup on storage.objects for delete to authenticated
using(bucket_id='official-stamps' and (select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and name like 'admin/%'
and not exists(select 1 from public.official_stamp_catalog c where c.data->>'image_url' like '%/official-stamps/'||name));

create table public.catalog_import_runs (
 id uuid primary key default gen_random_uuid(),
 stamp_id text references public.official_stamp_catalog(id),
 requested_by uuid references auth.users(id),
 kind text not null check(kind in ('manual_refresh','scheduled_import')),
 status text not null default 'running' check(status in ('running','success','failed')),
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 imported_count integer not null default 0,
 message text not null default '' check(length(message)<=1000)
);
alter table public.catalog_import_runs enable row level security;
revoke all on public.catalog_import_runs from anon,authenticated;
grant select,insert on public.catalog_import_runs to authenticated;
grant all on public.catalog_import_runs to service_role;
create policy import_admin_read on public.catalog_import_runs for select to authenticated using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy import_admin_request on public.catalog_import_runs for insert to authenticated with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and requested_by=(select auth.uid()) and kind='manual_refresh' and status='running' and finished_at is null and imported_count=0 and message='');
create index import_runs_recent on public.catalog_import_runs(started_at desc);
create unique index import_one_running on public.catalog_import_runs(stamp_id) where status='running' and kind='manual_refresh';
