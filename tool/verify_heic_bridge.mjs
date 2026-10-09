import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const bridge=readFileSync(new URL('../web/heic/bridge.js',import.meta.url),'utf8');
for(const outcome of ['ok','error','crash']) {
 let terminated=false;let sent;
 class Worker {
  constructor(url){assert.equal(url.href,'https://app.example/base/heic/worker.js');}
  terminate(){terminated=true;}
  postMessage(value){sent=value;queueMicrotask(()=>outcome==='crash'?this.onerror():this.onmessage({data:outcome==='ok'?{ok:true,bytes:new Uint8Array([255,216,255]).buffer}:{ok:false}}));}
 }
 const window={};vm.runInNewContext(bridge,{window,Worker,document:{baseURI:'https://app.example/base/'},URL,Uint8Array,setTimeout,clearTimeout,Error});
 const input=new Uint8Array([1,2,3]);
 if(outcome==='ok'){assert.deepEqual(await window.stampConvertHeic(input),new Uint8Array([255,216,255]));}else{await assert.rejects(window.stampConvertHeic(input));}
 assert.equal(terminated,true);assert.notEqual(sent,input.buffer);assert.deepEqual(input,new Uint8Array([1,2,3]));
 await assert.rejects(window.stampConvertHeic(new Uint8Array(20*1024*1024+1)));
}
console.log('PASS: HEIC bridge transfer copy, worker cleanup, decoder failure and size limit');
