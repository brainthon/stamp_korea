export const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const reply=(status:number,data:unknown)=>Response.json(data,{status,headers});
// Adapter is injected so destructive sequencing can be tested without real users.
export async function deleteAccount(req:Request, client:any):Promise<Response> {
 if(req.method==='OPTIONS') return new Response('ok',{headers});
 if(req.method!=='POST') return reply(405,{error:'POST required'});
 try {
  const token=req.headers.get('Authorization')?.replace(/^Bearer /i,'')||'';
  if(!token) return reply(401,{error:'로그인이 필요합니다.'});
  const {data:{user},error}=await client.auth.getUser(token);
  if(error||!user||user.is_anonymous) return reply(401,{error:'다시 로그인해 주세요.'});
  if(user.app_metadata?.stamp_admin===true) return reply(409,{error:'관리자 계정은 권한과 운영 기록을 정리한 후 탈퇴할 수 있습니다.'});
  const body=await req.json();
  if(body.confirmation!=='탈퇴') return reply(400,{error:'탈퇴 확인을 입력해 주세요.'});
  const uid=user.id; // Never trust a client-supplied user ID.
  for(let batch=0;batch<200;batch++) {
   const {data:manifest,error:lookupError}=await client.rpc('account_deletion_manifest',{p_user_id:uid});
   if(lookupError||!manifest||!Array.isArray(manifest.objects)) return reply(500,{error:'삭제할 자료를 확인하지 못했습니다. 다시 시도해 주세요.'});
   if(manifest.blocked) return reply(409,{error:'구독 또는 운영 기록 확인이 필요한 계정입니다. 구독과 계정 상태를 먼저 확인해 주세요.'});
   if(manifest.objects.length===0) break;
   const groups=new Map<string,string[]>();
   for(const obj of manifest.objects) {
    if(!['stamp-photos','stamp-images','recognition-contributions'].includes(obj.bucket)||typeof obj.name!=='string') return reply(500,{error:'사진 삭제 범위를 확인하지 못했습니다.'});
    groups.set(obj.bucket,[...(groups.get(obj.bucket)||[]),obj.name]);
   }
   for(const [bucket,names] of groups) {
    const {error:storageError}=await client.storage.from(bucket).remove(names);
    if(storageError) return reply(500,{error:'사진 삭제에 실패했습니다. 계정은 유지되며 다시 시도할 수 있습니다.'});
   }
   if(batch===199) return reply(503,{error:'사진 정리 중입니다. 다시 탈퇴를 요청해 주세요.'});
  }
  const {error:historyError}=await client.rpc('cleanup_member_action_history',{p_user_id:uid});
  if(historyError) return reply(500,{error:'연관 기록 정리에 실패했습니다. 다시 시도해 주세요.'});
  const {error:signoutError}=await client.auth.admin.signOut(token,'global');
  if(signoutError) return reply(500,{error:'로그인 세션 정리에 실패했습니다. 다시 시도해 주세요.'});
  const {error:deleteError}=await client.auth.admin.deleteUser(uid);
  if(deleteError) return reply(500,{error:'계정 삭제를 완료하지 못했습니다. 다시 로그인해 확인해 주세요.'});
  return reply(200,{ok:true});
 } catch {return reply(400,{error:'탈퇴 요청을 처리하지 못했습니다. 다시 로그인해 확인해 주세요.'});}
}
