begin;
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data) values
('f1041000-0000-4000-8000-000000000001','authenticated','authenticated','evaluation-a@example.invalid','{}','{}'),
('f1041000-0000-4000-8000-000000000002','authenticated','authenticated','evaluation-b@example.invalid','{}','{}'),
('f1041000-0000-4000-8000-000000000003','authenticated','authenticated','evaluation-admin@example.invalid','{"stamp_admin":true}','{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1041000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"stamp_admin":true}}',true);
select set_config('request.jwt.claim.sub','f1041000-0000-4000-8000-000000000003',true);
select set_config('test.evaluation_baseline',public.recognition_evaluation_summary()::text,true);
reset role;
insert into public.recognition_runs(id,user_id,outcome,predicted_id,candidate_ids,duration_ms,model,algorithm_version) values
('f1042000-0000-4000-8000-000000000001','f1041000-0000-4000-8000-000000000001','matched','epost_3521',array['epost_3521'],100,'test','test'),
('f1042000-0000-4000-8000-000000000002','f1041000-0000-4000-8000-000000000001','matched','epost_3522',array['epost_3521','epost_3522'],100,'test','test'),
('f1042000-0000-4000-8000-000000000003','f1041000-0000-4000-8000-000000000001','no_match',null,'{}',100,'test','test');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1041000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','f1041000-0000-4000-8000-000000000001',true);
insert into public.recognition_feedback(run_id,user_id,kind,proposed_id) values
('f1042000-0000-4000-8000-000000000001','f1041000-0000-4000-8000-000000000001','correct','epost_3521'),
('f1042000-0000-4000-8000-000000000002','f1041000-0000-4000-8000-000000000001','incorrect','epost_3521'),
('f1042000-0000-4000-8000-000000000003','f1041000-0000-4000-8000-000000000001','unknown',null);
update public.recognition_feedback set kind='incorrect' where run_id='f1042000-0000-4000-8000-000000000001';
do $$begin
 if(select count(*) from public.recognition_runs)<>3 then raise exception 'Owner read failed';end if;
 begin update public.recognition_feedback set status='verified',ground_truth_id='epost_3521' where run_id='f1042000-0000-4000-8000-000000000001';raise exception 'Member approval accepted';exception when insufficient_privilege then null;end;
 begin perform public.recognition_evaluation_summary();raise exception 'Member summary access accepted';exception when insufficient_privilege then null;end;
 begin insert into public.recognition_runs(id,user_id,outcome,duration_ms,model,algorithm_version) values(gen_random_uuid(),auth.uid(),'matched',1,'test','test');raise exception 'Client forged prediction';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f1041000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','f1041000-0000-4000-8000-000000000002',true);
do $$begin
 if exists(select 1 from public.recognition_runs) or exists(select 1 from public.recognition_feedback) then raise exception 'Other account data leaked';end if;
 begin insert into public.recognition_feedback(run_id,user_id,kind) values('f1042000-0000-4000-8000-000000000001',auth.uid(),'correct');raise exception 'Foreign feedback accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f1041000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"stamp_admin":true}}',true);
select set_config('request.jwt.claim.sub','f1041000-0000-4000-8000-000000000003',true);
update public.recognition_feedback set status='verified',ground_truth_id='epost_3521',reviewed_by=auth.uid(),reviewed_at=now() where run_id in ('f1042000-0000-4000-8000-000000000001','f1042000-0000-4000-8000-000000000002');
update public.recognition_feedback set status='unscorable',reviewed_by=auth.uid(),reviewed_at=now() where run_id='f1042000-0000-4000-8000-000000000003';
do $$declare s jsonb; b jsonb;begin
 s:=public.recognition_evaluation_summary();b:=current_setting('test.evaluation_baseline')::jsonb;
 if (s->>'verified')::int-(b->>'verified')::int<>2 or (s->>'identified_correct')::int-(b->>'identified_correct')::int<>1 or (s->>'false_confirmations')::int-(b->>'false_confirmations')::int<>1 or (s->>'unscorable')::int-(b->>'unscorable')::int<>1 then raise exception 'Evaluation denominators incorrect';end if;
end $$;
reset role;
rollback;
select 'PASS: owner isolation, feedback edit, forgery rejection, admin review and accuracy denominators; fixtures rolled back' as result;
