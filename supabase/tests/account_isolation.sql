begin;
do $$
declare a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); seen integer; n integer; ok boolean;
begin
 insert into auth.users(id,aud,role,email) values(a,'authenticated','authenticated',a::text||'@example.invalid'),(b,'authenticated','authenticated',b::text||'@example.invalid');
 insert into public.user_collections(id,user_id,stamp_id,count) values(a::text,a,'rls_test',1),(b::text,b,'rls_test',1);
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 select count(*) into seen from public.user_collections where id in(a::text,b::text);
 if seen != 1 then raise exception 'Cross-account read isolation failed'; end if;
 update public.user_collections set memo='blocked' where id=b::text;
 get diagnostics n = row_count;
 if n != 0 then raise exception 'Cross-account update allowed'; end if;
 begin
  insert into public.user_collections(id,user_id,stamp_id,count) values(gen_random_uuid()::text,b,'attack',1);
  raise exception 'Cross-account insert allowed';
 exception when insufficient_privilege then null;
 end;
 begin
  perform public.reserve_stamp_scan(a);
  raise exception 'Client can bypass quota';
 exception when insufficient_privilege then null;
 end;
 execute 'reset role';
 for i in 1..20 loop
  ok := public.reserve_stamp_scan(a);
  if not ok then raise exception 'Quota denied too early'; end if;
 end loop;
 if public.reserve_stamp_scan(a) then raise exception 'Quota limit failed'; end if;
 execute 'set local role anon';
 begin
  select count(*) into seen from public.user_collections;
  if seen != 0 then raise exception 'Guest can read collections'; end if;
 exception when insufficient_privilege then
  null; -- Denial at table privilege level is also valid guest isolation.
 end;
 execute 'reset role';
end $$;
rollback;
select 'PASS: owner read/write isolation, guest denial, server-only quota and 20-request limit; test records rolled back' as verification;
