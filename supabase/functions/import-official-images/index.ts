import { createClient } from "npm:@supabase/supabase-js@2.57.4";
// This administrative worker is disabled by default. Deploy a short-lived,
// random-token-hash build for a supervised import, then redeploy this file.
const TOKEN_HASH: string = "DISABLED";
const EXPIRES: number = 0;
Deno.serve(async(req)=>{
  if(TOKEN_HASH==="DISABLED" || Date.now()>EXPIRES) return new Response("Import closed",{status:410});
  if(req.method!=="POST") return new Response("POST required",{status:405});
  const token=req.headers.get("Authorization")?.replace(/^Bearer /i,"")||"";
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(token))))
    .map(b=>b.toString(16).padStart(2,"0")).join("");
  if(hash!==TOKEN_HASH) return new Response("Unauthorized",{status:401});
  const url=Deno.env.get("SUPABASE_URL")!;
  const admin=createClient(url,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
  const {data:rows,error}=await admin.from("official_stamp_catalog").select("id,data").eq("source_verified",false).order("id").limit(8);
  if(error) return Response.json({error:"catalog_read_failed"},{status:500});
  const done=[],failed=[];
  for(const row of rows||[]) {
    try {
      const source=new URL(row.data.source_image_url||row.data.image_url);
      if(source.protocol!=="https:" || source.hostname!=="image.epost.go.kr" || !source.pathname.startsWith('/stamp/data_img/')) throw Error('source');
      const r=await fetch(source,{signal:AbortSignal.timeout(7000),redirect:"error"});
      if(!r.ok) throw Error('fetch');
      const mime=r.headers.get('content-type')?.split(';')[0]||'';
      if(!['image/jpeg','image/png','image/gif','image/webp'].includes(mime)) throw Error('mime');
      const bytes=new Uint8Array(await r.arrayBuffer());
      if(bytes.length<50||bytes.length>5242880) throw Error('size');
      const imageHash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(b=>b.toString(16).padStart(2,'0')).join('');
      const path=row.id+'/'+imageHash+'.'+({"image/jpeg":"jpg","image/png":"png","image/gif":"gif","image/webp":"webp"}[mime]);
      const upload=await admin.storage.from('official-stamps').upload(path,bytes,{contentType:mime,upsert:true});
      if(upload.error) throw Error('upload');
      const data={...row.data,image_url:url+'/storage/v1/object/public/official-stamps/'+path,image_sha256:imageHash};
      const update=await admin.from('official_stamp_catalog').update({data,source_verified:true,updated_at:new Date().toISOString()}).eq('id',row.id);
      if(update.error) throw Error('update');
      done.push(row.id);
    } catch(e) {failed.push({id:row.id,stage:e instanceof Error?e.message:'unknown'});}
  }
  return Response.json({done,failed});
});
