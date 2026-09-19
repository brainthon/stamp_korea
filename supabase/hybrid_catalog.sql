create extension if not exists pg_trgm with schema extensions;
create table if not exists public.official_stamp_catalog (
  id text primary key,
  name text not null,
  year integer not null,
  face_value text not null,
  search_text text not null,
  data jsonb not null,
  source_verified boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint official_catalog_source check (data->>'source_url' like 'https://stamp.epost.go.kr/%')
);
alter table public.official_stamp_catalog enable row level security;
revoke all on public.official_stamp_catalog from anon, authenticated;
grant select on public.official_stamp_catalog to anon, authenticated;
grant all on public.official_stamp_catalog to service_role;
drop policy if exists "Read source verified catalog" on public.official_stamp_catalog;
create policy "Read source verified catalog" on public.official_stamp_catalog
  for select to anon,authenticated using (source_verified);
create index if not exists official_catalog_search on public.official_stamp_catalog
  using gin (search_text extensions.gin_trgm_ops);
create index if not exists official_catalog_year on public.official_stamp_catalog(year);

create or replace function public.find_stamp_candidates(p_text text, p_year integer default null, p_face text default '')
returns table(data jsonb, retrieval_score real)
language sql stable security invoker set search_path = public,extensions
as $$
  with q as (select left(lower(coalesce(p_text,'')),1500) as text,
    regexp_replace(lower(coalesce(p_face,'')), '[[:space:],]', '', 'g') as face),
  ranked as (
    select c.data,
      (similarity(c.search_text,q.text)*3 +
       case when p_year=c.year then 0.7 else 0 end +
       case when q.face<>'' and regexp_replace(lower(c.face_value),'[[:space:],]','','g')=q.face then 0.6 else 0 end +
       coalesce((select sum(least(length(t),10)::real/10) from
          (select distinct t from regexp_split_to_table(q.text,'[^[:alnum:]가-힣]+') t
           where length(t)>=2 and t not in ('대한민국','korea','우표','기념우표','원','한국')) words
          where c.search_text like '%'||t||'%'),0))::real as score
    from public.official_stamp_catalog c cross join q
    where c.source_verified and (
      c.year=p_year or similarity(c.search_text,q.text)>0.025 or
      exists(select 1 from regexp_split_to_table(q.text,'[^[:alnum:]가-힣]+') t
        where length(t)>=2 and t not in ('대한민국','korea','우표','기념우표','한국') and c.search_text like '%'||t||'%')
    )
  ) select data,score from ranked where score>0 order by score desc,data->>'id' limit 8;
$$;
revoke all on function public.find_stamp_candidates(text,integer,text) from public,anon,authenticated;
grant execute on function public.find_stamp_candidates(text,integer,text) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('official-stamps','official-stamps',true,5242880,array['image/jpeg','image/png','image/gif','image/webp'])
on conflict(id) do nothing;
