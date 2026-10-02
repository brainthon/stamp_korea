import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { portalURL,parsePortal,boundedBody } from './portal.ts';
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const reply=(status:number,data:unknown)=>Response.json(data,{status,headers});
Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers});
  if(req.method!=='POST') return reply(405,{error:'POST required'});
  const base=Deno.env.get('SUPABASE_URL')!,service=createClient(base,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const token=req.headers.get('Authorization')?.replace(/^Bearer /i,'')||'';
  const {data:{user},error:authError}=await service.auth.getUser(token);
  if(authError || !user) return reply(401,{error:'로그인이 필요합니다.'});
  if(user.app_metadata?.stamp_admin!==true) return reply(403,{error:'관리자 권한이 필요합니다.'});
  let id:string;
  try {const body=await req.json();id=body.id; if(typeof id!=='string'||!/^epost_\d+$/.test(id)) throw Error();}catch{return reply(400,{error:'올바른 우표 ID가 필요합니다.'});}
  const client=createClient(base,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}});
  const {data:row,error:rowError}=await client.from('official_stamp_catalog').select('data,updated_at').eq('id',id).single();
  if(rowError) return reply(404,{error:'우표를 찾지 못했습니다.'});
  const cutoff=new Date(Date.now()-60000).toISOString();
  const {count,error:countError}=await service.from('catalog_import_runs').select('id',{count:'exact',head:true}).eq('requested_by',user.id).gte('started_at',cutoff);
  if(countError) return reply(503,{error:'수집 이력을 확인하지 못했습니다.'});
  if((count||0)>=5) return reply(429,{error:'잠시 후 다시 수집해 주세요.'});
  // A crashed invocation can be retried after five minutes.
  await service.from('catalog_import_runs').update({status:'failed',finished_at:new Date().toISOString(),message:'실행 시간 초과. 다시 수집할 수 있습니다.'}).eq('stamp_id',id).eq('status','running').lt('started_at',new Date(Date.now()-300000).toISOString());
  const {data:run,error:runError}=await client.from('catalog_import_runs').insert({stamp_id:id,requested_by:user.id,kind:'manual_refresh'}).select('id').single();
  if(runError) return reply(409,{error:'이미 수집 중이거나 수집 이력을 기록하지 못했습니다.'});
  try {
    const source=portalURL(String(row.data.source_url||''));
    const response=await fetch(source,{signal:AbortSignal.timeout(15000),redirect:'error'});
    const html=new TextDecoder().decode(await boundedBody(response,1024*1024));
    const parsed=parsePortal(html,id);
    const image=await fetch(String(parsed.image_url),{signal:AbortSignal.timeout(10000),redirect:'error'});
    if(!['image/jpeg','image/png','image/gif','image/webp'].includes(image.headers.get('content-type')?.split(';')[0]||'')) throw Error('invalid_image');
    const bytes=await boundedBody(image,5*1024*1024);if(bytes.length<50) throw Error('invalid_image');
    const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(html)))).map(b=>b.toString(16).padStart(2,'0')).join('');
    const data={...row.data,...parsed,source_url:source,fetched_at:new Date().toISOString(),source_sha256:hash};
    // Preserve an existing stored representative image; refresh its portal source separately.
    if(String(row.data.image_url||'').startsWith(base+'/storage/v1/object/public/official-stamps/')) data.image_url=row.data.image_url;
    const {error:saveError}=await client.rpc('admin_save_stamp',{p_id:id,p_expected:row.updated_at,p_data:data});
    if(saveError) throw Error('save_conflict');
    const {error:logError}=await service.from('catalog_import_runs').update({status:'success',finished_at:new Date().toISOString(),imported_count:1,message:'공식 출처에서 상세정보를 갱신했습니다.'}).eq('id',run.id);
    if(logError) return reply(500,{error:'우표는 갱신됐지만 완료 이력을 기록하지 못했습니다.',run_id:run.id});
    return reply(200,{ok:true,run_id:run.id});
  }catch(error){
    const code=error instanceof Error?error.message:'';
    const message=code==='save_conflict'?'다른 수정과 충돌했습니다. 목록을 새로고침 후 다시 시도해 주세요.':code==='invalid_details'?'포털 형식 또는 필수 정보가 일치하지 않습니다.':code==='invalid_source'?'공식 상세 페이지 주소를 확인해 주세요.':'포털 접속 또는 이미지 검증에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    await service.from('catalog_import_runs').update({status:'failed',finished_at:new Date().toISOString(),message}).eq('id',run.id);
    return reply(422,{error:message,run_id:run.id});
  }
});
