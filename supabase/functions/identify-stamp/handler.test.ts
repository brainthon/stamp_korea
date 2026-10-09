import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import {auditRecord} from './audit.ts';
const source=stripTypeScriptTypes(readFileSync(new URL('./index.ts',import.meta.url),'utf8').replace(/^import .*;\n/gm,''));
function handler(options:{user?:boolean,key?:boolean,auditFails?:boolean,fetchError?:boolean}={}) {
 const recorded:unknown[]=[];
 let serve:(r:Request)=>Promise<Response>;
 const admin={auth:{getUser:async()=>({data:{user:options.user===false?null:{id:'owner',is_anonymous:false}},error:null})},rpc:async()=>({data:true,error:null}),from:(table:string)=>({insert:async(row:unknown)=>{assert.equal(table,'recognition_runs');recorded.push(row);return {error:options.auditFails?'db unavailable':null};}})};
 const env:Record<string,string>={SUPABASE_URL:'https://example.invalid',SUPABASE_SERVICE_ROLE_KEY:'private-server-key',GEMINI_MODEL:'test-model'};
 if(options.key)env.GEMINI_API_KEY='private-gemini-key';
 vm.runInNewContext(source,{Deno:{env:{get:(k:string)=>env[k]},serve:(fn:typeof serve)=>serve=fn},createClient:()=>admin,auditRecord,Error,Request,Response,TextDecoder,Uint8Array,AbortSignal,crypto,atob,btoa,console:{warn:()=>{}},fetch:async()=>{if(options.fetchError)throw new DOMException('private','TimeoutError');return new Response('',{status:429});},Date});
 return {run:(request:Request)=>serve(request),recorded};
}
const req=(body:unknown)=>new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer test'},body:JSON.stringify(body)});
test('method and authentication guards do not create identifiable records',async()=>{
 const a=handler({user:false});assert.equal((await a.run(new Request('https://example.invalid',{method:'OPTIONS'}))).status,200);
 assert.equal((await a.run(new Request('https://example.invalid'))).status,405);
 assert.equal((await a.run(req({}))).status,401);assert.equal(a.recorded.length,0);
});
test('authenticated failures have an ID and persist only whitelisted audit metadata',async()=>{
 const a=handler();const r=await a.run(req({image_base64:'private-photo'}));const body=await r.json();
 assert.equal(r.status,503);assert.ok(body.recognition_id);assert.equal((a.recorded[0] as any).error_code,'AI_NOT_CONFIGURED');
 assert.equal(JSON.stringify(a.recorded).includes('private'),false);
 const b=handler({key:true});assert.equal((await b.run(req({}))).status,400);assert.equal((b.recorded[0] as any).error_code,'INVALID_IMAGE');
});
test('audit persistence failure preserves the useful response and does not advertise an ID',async()=>{
 const a=handler({auditFails:true});const r=await a.run(req({}));assert.equal(r.status,503);assert.equal((await r.json()).recognition_id,null);
});
test('provider quota and timeout are recorded without provider payloads',async()=>{
 const jpeg=btoa(String.fromCharCode(255,216,255)+('x'.repeat(40)));
 for(const [fetchError,status,code] of [[false,429,'AI_QUOTA'],[true,504,'TIMEOUT']] as const){
  const a=handler({key:true,fetchError});const r=await a.run(req({image_base64:jpeg}));assert.equal(r.status,status);assert.equal((a.recorded[0] as any).error_code,code);assert.equal(JSON.stringify(a.recorded).includes(jpeg),false);
 }
});
