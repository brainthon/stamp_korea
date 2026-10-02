-- Applied 2026-10-02: remove privileges not needed by the mobile client.
revoke all on public.user_collections from anon;
revoke truncate, references, trigger on public.user_collections from authenticated;
grant select, insert, update, delete on public.user_collections to authenticated;
