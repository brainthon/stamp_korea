create policy catalog_admin_read on public.official_stamp_catalog for select to authenticated using ((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
create policy catalog_admin_update on public.official_stamp_catalog for update to authenticated using ((select auth.jwt()->'app_metadata'->>'stamp_admin')='true') with check ((select auth.jwt()->'app_metadata'->>'stamp_admin')='true');
grant update(name,year,face_value,search_text,data,updated_at) on public.official_stamp_catalog to authenticated;
create or replace function public.admin_save_stamp(p_id text,p_expected timestamptz,p_data jsonb) returns void language plpgsql security invoker set search_path=public as $$
begin
 if coalesce(auth.jwt()->'app_metadata'->>'stamp_admin','false') <> 'true' then raise exception 'admin_required'; end if;
 if p_data->>'id' is distinct from p_id or length(trim(coalesce(p_data->>'name','')))=0 or length(trim(coalesce(p_data->>'description','')))=0 then raise exception 'invalid_details'; end if;
 if (p_data->>'issue_date') !~ '^\d{4}-\d{2}-\d{2}$' or extract(year from (p_data->>'issue_date')::date)::text <> p_data->>'year' then raise exception 'invalid_date'; end if;
 if coalesce(p_data->>'image_url','') !~ '^https://(image\.epost\.go\.kr/|dyrteyrpimesipypwdpo\.supabase\.co/storage/v1/object/public/official-stamps/)' then raise exception 'invalid_image_host'; end if;
 update public.official_stamp_catalog set name=p_data->>'name',year=(p_data->>'year')::integer,face_value=p_data->>'face_value',search_text=lower(concat_ws(' ',p_data->>'name',p_data->>'design',p_data->>'face_value')),data=p_data,updated_at=clock_timestamp() where id=p_id and updated_at=p_expected;
 if not found then raise exception 'record_changed_reload'; end if;
end $$;
revoke all on function public.admin_save_stamp(text,timestamptz,jsonb) from public,anon;
grant execute on function public.admin_save_stamp(text,timestamptz,jsonb) to authenticated;
