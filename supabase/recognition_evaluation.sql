create table public.recognition_runs (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(), outcome text not null,
 predicted_id text references public.official_stamp_catalog(id) on delete set null,
 candidate_ids text[] not null default '{}', error_code text,
 duration_ms integer not null check(duration_ms>=0), model text not null, algorithm_version text not null
);
alter table public.recognition_runs enable row level security;
revoke all on public.recognition_runs from public,anon,authenticated;
grant select on public.recognition_runs to authenticated;
grant insert on public.recognition_runs to service_role;
create policy runs_read on public.recognition_runs for select to authenticated
 using(user_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create index recognition_runs_owner on public.recognition_runs(user_id,created_at desc);
create index recognition_runs_date on public.recognition_runs(created_at desc);
create table public.recognition_feedback (
 run_id uuid primary key references public.recognition_runs(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('correct','incorrect','unknown')),
 proposed_id text references public.official_stamp_catalog(id) on delete set null,
 status text not null default 'pending' check(status in ('pending','verified','unscorable')),
 ground_truth_id text references public.official_stamp_catalog(id) on delete set null,
 reviewed_by uuid references auth.users(id) on delete set null, reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 check(status<>'verified' or ground_truth_id is not null)
);
alter table public.recognition_feedback enable row level security;
revoke all on public.recognition_feedback from public,anon,authenticated;
grant select,insert on public.recognition_feedback to authenticated;
grant update(kind,proposed_id,status,ground_truth_id,reviewed_by,reviewed_at) on public.recognition_feedback to authenticated;
create policy feedback_read on public.recognition_feedback for select to authenticated
 using(user_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy feedback_insert on public.recognition_feedback for insert to authenticated
 with check(user_id=(select auth.uid()) and status='pending' and ground_truth_id is null and reviewed_by is null and reviewed_at is null
 and exists(select 1 from public.recognition_runs r where r.id=run_id and r.user_id=(select auth.uid())));
create policy feedback_member_update on public.recognition_feedback for update to authenticated
 using(user_id=(select auth.uid()) and status='pending')
 with check(user_id=(select auth.uid()) and status='pending' and ground_truth_id is null and reviewed_by is null and reviewed_at is null);
create policy feedback_admin_update on public.recognition_feedback for update to authenticated
 using((select auth.jwt()->'app_metadata'->>'stamp_admin')='true')
 with check((select auth.jwt()->'app_metadata'->>'stamp_admin')='true' and reviewed_by=(select auth.uid()) and reviewed_at is not null);
alter table public.photo_contributions add column recognition_run_id uuid references public.recognition_runs(id) on delete set null;
drop policy contributions_submit on public.photo_contributions;
create policy contributions_submit on public.photo_contributions for insert to authenticated
 with check(user_id=(select auth.uid()) and status='pending' and reviewed_by is null and reviewed_at is null and review_note=''
 and (recognition_run_id is null or exists(select 1 from public.recognition_runs r where r.id=recognition_run_id and r.user_id=(select auth.uid()))));
create index contribution_run on public.photo_contributions(recognition_run_id) where recognition_run_id is not null;
create function public.recognition_evaluation_summary() returns jsonb language plpgsql security invoker set search_path='' as $$
declare summary jsonb;
begin
 if coalesce(auth.jwt()->'app_metadata'->>'stamp_admin','false')<>'true' then raise exception 'Admin required' using errcode='42501';end if;
 select jsonb_build_object(
 'period_days',30,'total',count(*),
 'automatic_matches',count(*) filter(where r.outcome='matched'),
 'technical_errors',count(*) filter(where r.error_code is not null or r.outcome in ('catalog_unavailable','comparison_unavailable')),
 'pending',count(*) filter(where f.status='pending'),
 'verified',count(*) filter(where f.status='verified'),
 'identified_correct',count(*) filter(where f.status='verified' and r.predicted_id=f.ground_truth_id),
 'verified_matches',count(*) filter(where f.status='verified' and r.outcome='matched'),
 'false_confirmations',count(*) filter(where f.status='verified' and r.outcome='matched' and r.predicted_id is distinct from f.ground_truth_id),
 'candidate_hits',count(*) filter(where f.status='verified' and f.ground_truth_id=any(r.candidate_ids)),
 'unscorable',count(*) filter(where f.status='unscorable')
 ) into summary from public.recognition_runs r left join public.recognition_feedback f on f.run_id=r.id
 where r.created_at>=now()-interval '30 days';
 return summary;
end $$;
revoke all on function public.recognition_evaluation_summary() from public,anon;
grant execute on function public.recognition_evaluation_summary() to authenticated;
