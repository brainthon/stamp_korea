import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { PORTAL, canonicalSource, detailLinks, parseDetail } from './portal.ts';
const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
Deno.serve(async req => {
  if (req.method !== 'POST') return reply(405, { error: 'POST required' });
  const token = req.headers.get('x-catalog-sync-token') ?? '';
  if (!/^[a-f0-9]{64}$/.test(token)) return reply(401, { error: 'Unauthorized' });
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } });
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  const hash = [...new Uint8Array(digest)].map(n => n.toString(16).padStart(2, '0')).join('');
  const authorized = await sb.rpc('verify_catalog_sync_token', { p_hash: hash });
  if (authorized.error || authorized.data !== true) return reply(401, { error: 'Unauthorized' });
  const started = await sb.rpc('begin_catalog_sync');
  if (started.error) return reply(500, { error: 'Could not start import' });
  const run = started.data;
  if (!run) return reply(200, { skipped: 'Already running' });
  let stage = 'list';
  const deadline = Date.now() + 110_000;
  async function remote(url: string) {
    if (Date.now() > deadline) throw new Error('Deadline reached');
    await new Promise(resolve => setTimeout(resolve, 500));
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await fetch(url, { headers: { 'User-Agent': 'StampMoaCatalog/1.0 (permission-authorized catalog import)' }, signal: AbortSignal.timeout(10_000), redirect: 'error' });
        if (!response.ok) throw new Error('Remote HTTP failed');
        return response;
      } catch (error) {
        if (attempt || Date.now() > deadline) throw error;
      }
    }
    throw new Error('Remote request failed');
  }
  try {
    const sources = await sb.from('official_stamp_catalog').select('source_url:data->>source_url').order('year', { ascending: false }).limit(300);
    if (sources.error) throw new Error('Catalog query failed');
    const known = new Set<string>();
    for (const row of sources.data) {
      try { if (row.source_url) known.add(canonicalSource(String(row.source_url))); } catch { /* legacy source omitted */ }
    }
    const links = new Set<string>();
    for (let page = 1; page <= 3; page++) {
      const response = await remote(`${PORTAL}/sp2/sg/spsg0101.jsp?currentPage=${page}`);
      const html = await response.text();
      if (html.length > 2_000_000) throw new Error('Oversized list');
      for (const link of detailLinks(html)) if (!known.has(link)) links.add(link);
    }
    const records = [];
    for (const link of [...links].slice(0, 10)) {
      stage = 'detail';
      const html = await (await remote(link)).text();
      if (html.length > 2_000_000) throw new Error('Oversized detail');
      const record = await parseDetail(html, link);
      stage = 'image';
      const image = await remote(record.image_url);
      const type = image.headers.get('content-type') ?? '';
      await image.body?.cancel();
      if (!type.startsWith('image/')) throw new Error('Invalid image response');
      records.push(record);
    }
    stage = 'database';
    const result = await sb.rpc('finish_catalog_sync', { p_run_id: run, p_records: records });
    if (result.error) throw new Error('Catalog commit failed');
    return reply(200, { run_id: run, imported_count: result.data, checked_new: records.length, pending: Math.max(0, links.size - records.length) });
  } catch (_) {
    // Do not log source HTML, credentials, or arbitrary error text.
    await sb.from('catalog_import_runs').update({ status: 'failed', finished_at: new Date().toISOString(), message: `자동 수집 실패: ${stage}` }).eq('id', run).eq('status', 'running');
    return reply(502, { run_id: run, error: `Import failed at ${stage}` });
  }
});
