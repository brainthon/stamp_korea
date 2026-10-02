-- Service-only helpers: storage must be deleted via the Storage API, not SQL.
create function public.account_deletion_manifest(p_user_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'blocked',
 exists(select 1 from public.member_memberships where user_id=p_user_id and plan='premium' and (subscription_status='active' or period_end>now()))
 or exists(select 1 from public.photo_contributions where reviewed_by=p_user_id and user_id<>p_user_id)
 or exists(select 1 from public.catalog_import_runs where requested_by=p_user_id)
 or exists(select 1 from public.member_admin_actions where actor_id=p_user_id)
 or exists(select 1 from storage.objects where (owner_id=p_user_id::text or owner=p_user_id) and bucket_id not in ('stamp-photos','stamp-images','recognition-contributions')),
 'objects',coalesce((select jsonb_agg(jsonb_build_object('bucket',bucket_id,'name',name)) from (
 select bucket_id,name from storage.objects where bucket_id in ('stamp-photos','stamp-images','recognition-contributions') and (owner_id=p_user_id::text or owner=p_user_id or name like p_user_id::text||'/%') order by bucket_id,name limit 100
 ) o),'[]'::jsonb));
$$;
revoke all on function public.account_deletion_manifest(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_manifest(uuid) to service_role;
create function public.cleanup_member_action_history(p_user_id uuid) returns void language sql security invoker set search_path='' as $$
 delete from public.member_admin_actions where member_id=p_user_id and actor_id<>p_user_id;
$$;
revoke all on function public.cleanup_member_action_history(uuid) from public,anon,authenticated;
grant execute on function public.cleanup_member_action_history(uuid) to service_role;
