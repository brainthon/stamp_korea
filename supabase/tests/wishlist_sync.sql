begin;
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data) values
('f1040000-0000-4000-8000-000000000001','authenticated','authenticated','wishlist-a@example.invalid','{}','{}'),
('f1040000-0000-4000-8000-000000000002','authenticated','authenticated','wishlist-b@example.invalid','{}','{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1040000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','f1040000-0000-4000-8000-000000000001',true);
do $$declare stamp text; n integer; begin
 select id into strict stamp from public.official_stamp_catalog limit 1;
 perform public.import_my_wishlist(array[stamp,stamp,'nonexistent-wishlist-test'],'f1040000-0000-4000-8000-000000000001');
 perform public.import_my_wishlist(array[stamp],'f1040000-0000-4000-8000-000000000001');
 if (select count(*) from public.user_wishlist)<>1 then raise exception 'Import did not deduplicate';end if;
 insert into public.user_wishlist(user_id,stamp_id) values ('f1040000-0000-4000-8000-000000000001',stamp)
 on conflict(user_id,stamp_id) do update set stamp_id=excluded.stamp_id;
 if (select count(*) from public.user_wishlist)<>1 then raise exception 'Cloud add duplicated';end if;
 begin insert into public.user_wishlist(user_id,stamp_id) values ('f1040000-0000-4000-8000-000000000002',stamp); raise exception 'Foreign write accepted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f1040000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','f1040000-0000-4000-8000-000000000002',true);
do $$begin
 if exists(select 1 from public.user_wishlist) then raise exception 'Other account records visible';end if;
 perform public.import_my_wishlist(array[(select id from public.official_stamp_catalog limit 1)],'f1040000-0000-4000-8000-000000000001');
 if exists(select 1 from public.user_wishlist) then raise exception 'Mismatched migration owner accepted';end if;
 delete from public.user_wishlist where user_id='f1040000-0000-4000-8000-000000000001';
end $$;
select set_config('request.jwt.claims','{"sub":"f1040000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','f1040000-0000-4000-8000-000000000001',true);
do $$begin
 if (select count(*) from public.user_wishlist)<>1 then raise exception 'Other account removed A record';end if;
 delete from public.user_wishlist where user_id='f1040000-0000-4000-8000-000000000001';
 if exists(select 1 from public.user_wishlist) then raise exception 'Cloud removal did not persist';end if;
end $$;
reset role;
rollback;
select 'PASS: wishlist migration, duplicate add, owner isolation, cloud removal; test records rolled back' as result;
