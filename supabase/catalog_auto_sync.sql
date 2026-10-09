-- Server-side daily import. Secrets are created only inside Vault, never printed.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
do $$ begin
 if not exists(select 1 from vault.secrets where name='stamp_catalog_sync_token') then
  perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'stamp_catalog_sync_token','Private scheduler token for stamp catalog import');
 end if;
end $$;

create unique index if not exists catalog_scheduled_single_run
on public.catalog_import_runs(kind) where kind='scheduled_import' and status='running';

create or replace function public.verify_catalog_sync_token(p_hash text)
returns boolean language sql security definer set search_path='' as $$
 select exists(select 1 from vault.decrypted_secrets
 where name='stamp_catalog_sync_token' and encode(extensions.digest(decrypted_secret,'sha256'),'hex')=p_hash);
$$;
revoke all on function public.verify_catalog_sync_token(text) from public,anon,authenticated;
grant execute on function public.verify_catalog_sync_token(text) to service_role;

create or replace function public.begin_catalog_sync()
returns uuid language plpgsql security definer set search_path='' as $$
declare run uuid;
begin
 update public.catalog_import_runs set status='failed',finished_at=now(),message='자동 수집 중단 또는 제한시간 초과'
 where kind='scheduled_import' and status='running' and started_at<now()-interval '15 minutes';
 insert into public.catalog_import_runs(kind,status,message) values('scheduled_import','running','Supabase 예약 수집') returning id into run;
 return run;
exception when unique_violation then return null;
end;
$$;
revoke all on function public.begin_catalog_sync() from public,anon,authenticated;
grant execute on function public.begin_catalog_sync() to service_role;

create or replace function public.finish_catalog_sync(p_run_id uuid,p_records jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare inserted integer; validated_record jsonb;
begin
 perform 1 from public.catalog_import_runs where id=p_run_id and kind='scheduled_import' and status='running' for update;
 if not found then raise exception 'Import run unavailable'; end if;
 if p_records is null or jsonb_typeof(p_records) <> 'array' or jsonb_array_length(p_records)>10 then raise exception 'Invalid import batch'; end if;
 for validated_record in select value from jsonb_array_elements(p_records) loop
  if not (validated_record ?& array['id','stamp_number','source_sha256','source_url','image_url','issue_date','year']) or coalesce(validated_record->>'id','') !~ '^epost_[0-9]+$' or validated_record->>'id' <> 'epost_'||(validated_record->>'stamp_number')
   or coalesce(validated_record->>'name','')='' or coalesce(validated_record->>'description','')='' or coalesce(validated_record->>'face_value','')=''
   or coalesce(validated_record->>'source_sha256','') !~ '^[a-f0-9]{64}$'
   or coalesce(validated_record->>'source_url','') !~ '^https://stamp[.]epost[.]go[.]kr/sp2/sg/spsg0102[.]jsp[?]tbsmh15seqnum=[0-9]+&tbsmh01seqnum=[0-9]+$'
   or coalesce(validated_record->>'image_url','') !~ '^https://image[.]epost[.]go[.]kr/'
   or coalesce(validated_record->>'issue_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   or extract(year from (validated_record->>'issue_date')::date)::integer <> (validated_record->>'year')::integer
   or length(validated_record::text)>100000 then raise exception 'Invalid official stamp';
  end if;
 end loop;
 with new_rows as (
 insert into public.official_stamp_catalog(id,name,year,face_value,search_text,data,source_verified)
 select item->>'id',item->>'name',(item->>'year')::integer,item->>'face_value',
 lower(concat_ws(' ',item->>'name',item->>'design',item->>'face_value',item->>'year')),item,true
 from jsonb_array_elements(p_records) item
 on conflict(id) do nothing returning id
 ) select count(*) into inserted from new_rows;
 update public.catalog_import_runs set status='success',finished_at=now(),imported_count=inserted,
 message=case when inserted=0 then '신규 우표 없음: 포털 확인 완료' else '신규 우표 자동 등록 완료' end
 where id=p_run_id;
 return inserted;
end;
$$;
revoke all on function public.finish_catalog_sync(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_catalog_sync(uuid,jsonb) to service_role;

-- pg_cron UTC: 00:30 UTC is 09:30 Asia/Seoul.
select cron.schedule('stamp-catalog-daily','30 0 * * *',$job$
 select net.http_post(
  url:='https://dyrteyrpimesipypwdpo.supabase.co/functions/v1/sync-stamp-catalog',
  headers:=jsonb_build_object('Content-Type','application/json','x-catalog-sync-token',
   (select decrypted_secret from vault.decrypted_secrets where name='stamp_catalog_sync_token')),
  body:='{}'::jsonb,timeout_milliseconds:=120000
 );
$job$);
