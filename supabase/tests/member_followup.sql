begin;
insert into auth.users(id,email) values('f1020000-0000-4000-8000-000000000001','member-test-1@example.invalid'),('f1020000-0000-4000-8000-000000000002','member-test-2@example.invalid');
insert into public.official_stamp_catalog(id,name,year,face_value,search_text,data,source_verified,updated_at)
select 'TEST_FOLLOWUP_STAMP','검증 신규 우표',2026,face_value,'test',data||jsonb_build_object('id','TEST_FOLLOWUP_STAMP','name','검증 신규 우표','issue_date',(now() at time zone 'Asia/Seoul')::date::text),false,now() from public.official_stamp_catalog limit 1;
update public.official_stamp_catalog set source_verified=true where id='TEST_FOLLOWUP_STAMP';
update public.official_stamp_catalog set source_verified=false where id='TEST_FOLLOWUP_STAMP';
update public.official_stamp_catalog set source_verified=true where id='TEST_FOLLOWUP_STAMP';
do $$begin if (select count(*) from public.member_notifications where source_key='stamp:TEST_FOLLOWUP_STAMP')<>1 then raise exception 'Automatic notice or deduplication failed'; end if;end$$;
insert into public.member_announcements(id,title,body,created_by) values('f1021000-0000-4000-8000-000000000001','검증 공지','알림함 게시 검증','f1020000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1020000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{}}',true);
do $$begin
perform public.import_my_wishlist(array['TEST_FOLLOWUP_STAMP','UNKNOWN_STAMP'],'f1020000-0000-4000-8000-000000000001');
perform public.import_my_wishlist(array['TEST_FOLLOWUP_STAMP'],'f1020000-0000-4000-8000-000000000001');
if (select count(*) from public.user_wishlist)<>1 then raise exception 'Wishlist migration dedup failed';end if;
begin insert into public.user_wishlist(user_id,stamp_id) values('f1020000-0000-4000-8000-000000000002','TEST_FOLLOWUP_STAMP');raise exception 'Other account insert permitted';exception when insufficient_privilege then null;end;
begin perform public.publish_member_announcement('f1021000-0000-4000-8000-000000000001');raise exception 'Member publication permitted';exception when insufficient_privilege then null;end;
begin perform public.account_deletion_manifest('f1020000-0000-4000-8000-000000000002');raise exception 'Member deletion helper permitted';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claims','{"sub":"f1020000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{}}',true);
do $$begin
if exists(select 1 from public.user_wishlist) then raise exception 'Other wishlist leaked';end if;
if exists(select 1 from public.member_announcements) then raise exception 'Draft leaked';end if;
end$$;
select set_config('request.jwt.claims','{"sub":"f1020000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"stamp_admin":true}}',true);
do $$declare a uuid;b uuid;begin
 a:=public.publish_member_announcement('f1021000-0000-4000-8000-000000000001');
 b:=public.publish_member_announcement('f1021000-0000-4000-8000-000000000001');
 if a<>b then raise exception 'Publication retry not idempotent';end if;
 if (select count(*) from public.member_notifications where source_key='announcement:f1021000-0000-4000-8000-000000000001')<>1 then raise exception 'Duplicate publication';end if;
 update public.member_announcements set title='Forbidden published edit' where id='f1021000-0000-4000-8000-000000000001';
 if found then raise exception 'Published edit permitted';end if;
end$$;
reset role;
insert into public.notification_preferences(user_id) values('f1020000-0000-4000-8000-000000000001');
insert into public.member_notification_reads(user_id,notification_id) select 'f1020000-0000-4000-8000-000000000001',id from public.member_notifications where source_key='stamp:TEST_FOLLOWUP_STAMP';
insert into public.photo_contributions(id,user_id,stamp_id,image_path,consent_version,reference_consent) values('f1022000-0000-4000-8000-000000000001','f1020000-0000-4000-8000-000000000001','TEST_FOLLOWUP_STAMP','f1020000-0000-4000-8000-000000000001/f1022000-0000-4000-8000-000000000001.jpg','2026-09-30-v1',true);
set local role service_role;
do $$declare m jsonb;begin
m:=public.account_deletion_manifest('f1020000-0000-4000-8000-000000000001');
if (m->>'blocked')::boolean then raise exception 'Free member incorrectly blocked';end if;
end$$;
reset role;
delete from auth.users where id='f1020000-0000-4000-8000-000000000001';
do $$begin
if exists(select 1 from public.user_wishlist where user_id='f1020000-0000-4000-8000-000000000001') or exists(select 1 from public.notification_preferences where user_id='f1020000-0000-4000-8000-000000000001') or exists(select 1 from public.member_notification_reads where user_id='f1020000-0000-4000-8000-000000000001') or exists(select 1 from public.photo_contributions where user_id='f1020000-0000-4000-8000-000000000001') then raise exception 'Account cascade failed';end if;
if not exists(select 1 from public.official_stamp_catalog where id='TEST_FOLLOWUP_STAMP') then raise exception 'Official stamp deleted';end if;
end$$;
rollback;
select 'passed: wishlist migration/isolation, admin publish/retry/immutability, automatic notice dedup, deletion helper access and cascade; all fixtures rolled back' as verification;
