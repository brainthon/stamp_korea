import {test} from 'node:test';
import assert from 'node:assert/strict';
import {auditRecord} from './audit.ts';
test('retains original prediction with bounded candidates and no photo or OCR',()=>{
 const r=auditRecord({official:{id:'epost_3521'},candidates:Array.from({length:10},(_,i)=>({id:`epost_${i}`})),match_status:'matched',image_base64:'PRIVATE',visible_text:'PRIVATE',message:'PRIVATE',description:'PRIVATE'},200,'owner','run','model',123.4);
 assert.equal(r.predicted_id,'epost_3521');assert.equal(r.candidate_ids.length,5);assert.equal(r.duration_ms,123);
 assert.equal(JSON.stringify(r).includes('PRIVATE'),false);
 assert.equal(r.error_code,null);
});
test('failure and abstention are not counted as confirmed identification',()=>{
 const failed=auditRecord({code:'TIMEOUT',message:'private'},504,'owner','run','model',-1);
 assert.equal(failed.outcome,'error');assert.equal(failed.error_code,'TIMEOUT');assert.equal(failed.predicted_id,null);assert.equal(failed.duration_ms,0);
 assert.equal(auditRecord({match_status:'retake'},200,'owner','run','model',5).outcome,'retake');
 assert.equal(auditRecord({match_status:'comparison_unavailable'},200,'owner','run','model',5).predicted_id,null);
});
