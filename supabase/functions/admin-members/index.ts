import { createClient } from "npm:@supabase/supabase-js@2.57.4";
const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const reply=(status:number,data:unknown)=>Response.json(data,{status,headers});
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers});
 if(req.method!=='POST') return reply(405,{error:'POST required'});
 try {
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const token=req.headers.get('Authorization')?.replace(/^Bearer /i,'')||'';
  if(!token) return reply(401,{error:'로그인이 필요합니다.'});
  const {data:{user},error}=await client.auth.getUser(token);
  if(error||!user) return reply(401,{error:'다시 로그인해 주세요.'});
  if(user.app_metadata?.stamp_admin!==true) return reply(403,{error:'관리자 권한이 필요합니다.'});
  const body=await req.json();
  if(body.action==='stats') {
   if(![7,30].includes(body.days)) return reply(400,{error:'통계 기간을 확인해 주세요.'});
   const {data,error}=await client.rpc('admin_operating_stats',{p_days:body.days});
   return error?reply(500,{error:'운영 통계를 조회하지 못했습니다.'}):reply(200,data);
  }
  if(body.action==='list') {
   const plan=body.plan??'all';
   if(!['all','free','premium'].includes(plan)) return reply(400,{error:'회원 등급 조건을 확인해 주세요.'});
   if(typeof body.query!=='string'||body.query.length>100||!['all','unconfirmed','restricted','admin'].includes(body.status)||!Number.isInteger(body.page)||body.page<0||body.page>10000) return reply(400,{error:'검색 조건을 확인해 주세요.'});
   const {data,error}=await client.rpc('admin_member_directory_by_plan',{p_query:body.query.trim(),p_status:body.status,p_page:body.page,p_plan:plan});
   return error?reply(500,{error:'회원 목록을 조회하지 못했습니다.'}):reply(200,data);
  }
  if(!['restrict','restore'].includes(body.action)||typeof body.id!=='string'||!/^[0-9a-f-]{36}$/i.test(body.id)||typeof body.reason!=='string'||body.reason.trim().length<3||body.reason.trim().length>300) return reply(400,{error:'대상과 사유(3~300자)를 확인해 주세요.'});
  const {data:{user:target},error:targetError}=await client.auth.admin.getUserById(body.id);
  if(targetError||!target) return reply(404,{error:'회원을 찾지 못했습니다.'});
  if(target.id===user.id||target.app_metadata?.stamp_admin===true) return reply(409,{error:'관리자 계정의 로그인 상태는 변경할 수 없습니다.'});
  const {data:log,error:logError}=await client.from('member_admin_actions').insert({actor_id:user.id,member_id:target.id,action:body.action,reason:body.reason.trim()}).select('id').single();
  if(logError) return reply(500,{error:'관리 이력을 기록하지 못했습니다. 변경하지 않았습니다.'});
  const {error:updateError}=await client.auth.admin.updateUserById(target.id,{ban_duration:body.action==='restrict'?'720h':'none'});
  const {error:finishError}=await client.from('member_admin_actions').update({status:updateError?'failed':'success'}).eq('id',log.id);
  if(updateError) return reply(500,{error:'로그인 상태를 변경하지 못했습니다.'});
  if(finishError) return reply(500,{error:'상태는 변경됐지만 이력 완료 기록에 실패했습니다. 새로고침 후 확인해 주세요.'});
  return reply(200,{ok:true});
 } catch {return reply(400,{error:'요청을 처리하지 못했습니다. 다시 시도해 주세요.'});}
});
