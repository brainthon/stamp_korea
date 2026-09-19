import {test} from 'node:test';
import assert from 'node:assert/strict';
import {decideMatch,validReference} from './hybrid.ts';
const row={id:'epost_3834',name:'제21대 대통령 취임',year:'2025',face_value:'430원'};
const observed={is_stamp:true,name:row.name,country:'대한민국',visible_text:'제21대 대통령 취임 430원',year:'2025',face_value:'430원'};
const comparison={candidate_id:row.id,visual_match:'strong',conflicting_details:false,readable_title_match:true,ambiguous:false};
test('links only supplied catalog data after visual and metadata agreement',()=>{
  assert.deepEqual(decideMatch(observed,[row],comparison),row);
});
test('ambiguous, unreadable, unknown, conflicting and missing-reference cases stay unconfirmed',()=>{
  for(const change of [{ambiguous:true},{conflicting_details:true},{visual_match:'weak'},{candidate_id:'invented'}])
    assert.equal(decideMatch(observed,[row],{...comparison,...change}),null);
  for(const change of [{year:'2024'},{face_value:'430전'},{face_value:'43.0원'},{is_stamp:false},{country:'Japan',visible_text:''}])
    assert.equal(decideMatch({...observed,...change},[row],comparison),null);
  assert.equal(decideMatch(observed,[],comparison),null);
  assert.equal(decideMatch(observed,[row],null),null);
});
test('printed amount without won and missing tiny year do not reject a distinctive match',()=>{
  assert.equal(decideMatch({...observed,face_value:'430'},[row],comparison),row);
  assert.equal(decideMatch({...observed,year:'',face_value:'430'},[row],comparison),row);
  assert.equal(decideMatch({...observed,year:''},[row],{...comparison,readable_title_match:false}),null);
  assert.equal(decideMatch({...observed,face_value:'430환'},[row],comparison),null);
});
test('reference fetching is restricted to this project public official-image bucket',()=>{
  const project='https://example.supabase.co';
  assert.equal(validReference(project+'/storage/v1/object/public/official-stamps/a.jpg',project),true);
  for(const url of ['http://127.0.0.1/a','https://evil.test/a',project+'/storage/v1/object/public/stamp-photos/a.jpg',project.replace('https:','http:')+'/storage/v1/object/public/official-stamps/a'])
    assert.equal(validReference(url,project),false);
});
