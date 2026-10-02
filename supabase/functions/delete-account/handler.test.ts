import {test} from 'node:test';
import assert from 'node:assert/strict';
import {deleteAccount} from './handler.ts';
const uid='11111111-1111-4111-8111-111111111111';
const request=(body:any={confirmation:'탈퇴'},token='verified-token')=>new Request('https://example.invalid/delete-account',{method:'POST',headers:token?{'Authorization':`Bearer ${token}`}:{},body:JSON.stringify(body)});
function mock(options:any={}){
 const calls:any[]=[];let iteration=0;
 return {calls,client:{auth:{getUser:async(token:string)=>{calls.push(['verify',token]);return {data:{user:options.invalid?null:{id:uid,app_metadata:{stamp_admin:options.admin??false}}},error:options.invalid?{}:null};},admin:{signOut:async(token:string,scope:string)=>{calls.push(['signout',token,scope]);return{error:options.signoutError?{}:null};},deleteUser:async(id:string)=>{calls.push(['delete',id]);return{error:null};}}},rpc:async(name:string,params:any)=>{calls.push([name,params]);if(name==='cleanup_member_action_history')return{error:null};return{data:{blocked:options.blocked??false,objects:iteration++===0&&options.photo?[{bucket:'recognition-contributions',name:`${uid}/photo.jpg`}]:[]},error:null};},storage:{from:(bucket:string)=>({remove:async(names:string[])=>{calls.push(['storage',bucket,names]);return{error:options.storageError?{}:null};}})}}};
}
test('verified current user only; storage then global signout then deletion',async()=>{
 const {calls,client}=mock({photo:true});const response=await deleteAccount(request({confirmation:'탈퇴',user_id:'another-user'}),client);
 assert.equal(response.status,200);assert.deepEqual(calls.find(c=>c[0]==='delete'),['delete',uid]);assert.deepEqual(calls.find(c=>c[0]==='signout'),['signout','verified-token','global']);
 assert(calls.findIndex(c=>c[0]==='storage')<calls.findIndex(c=>c[0]==='signout'));assert(calls.findIndex(c=>c[0]==='signout')<calls.findIndex(c=>c[0]==='delete'));
 for(const call of calls.filter(c=>c[0]==='account_deletion_manifest'||c[0]==='cleanup_member_action_history'))assert.equal(call[1].p_user_id,uid);
});
for(const [name,options,body,token,status] of [
 ['missing token',{},undefined,'',401],['invalid session',{invalid:true},undefined,'token',401],['admin account',{admin:true},undefined,'token',409],['missing confirmation',{}, {},'token',400],['subscription or protected records',{blocked:true},undefined,'token',409],['storage cleanup failure',{photo:true,storageError:true},undefined,'token',500],['session revocation failure',{signoutError:true},undefined,'token',500],
] as any[])test(name,async()=>{const {calls,client}=mock(options);const response=await deleteAccount(request(body,token),client);assert.equal(response.status,status);assert(!calls.some(c=>c[0]==='delete'));});
