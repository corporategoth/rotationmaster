import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {createDraftEditor} from '../Web/editor/draft.mjs';
import {decodeImport} from '../Web/codec/import.mjs';
import {encodeExport} from '../Web/codec/export.mjs';
import {toTypedTree} from '../Web/codec/lua-data.mjs';
const schemaText=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
const record=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url),'utf8')).records[0];
const accepted=value=>({decode:{ok:true,kind:value.get('format')==='RotationMaster'?'envelope':'legacy',value,original:encodeExport(value).text}});
function setup(value=decodeImport(record.wire).value){let source=accepted(value);const editor=createDraftEditor({schemaText,readSource:()=>source});return {editor,value,replace(v){source=v;},source:()=>source};}
const body=v=>v.get('format')==='RotationMaster'?v.get('body'):v;
const typed=v=>toTypedTree(v);
function generated(editor){assert.equal(editor.review().ok,true);const result=editor.generate();assert.equal(result.ok,true,result.reason);const decoded=decodeImport(result.text);assert.equal(decoded.ok,true,decoded.reason);return decoded.value;}

test('detached envelope commands preserve every other typed subtree and retained manifest field',()=>{
 const value=decodeImport(record.wire).value,b=body(value);b.set('priority',-0);b.set('revision',17);
 b.set('opaque',new Map([[1,false],['1',new Map([[3,String.fromCharCode(...Array.from({length:256},(_,i)=>i))]])],['empty',new Map()],['zero',-0]]));
 const before=typed(value),{editor}=setup(value);assert.equal(editor.start(),true);assert.equal(editor.setDisabled('true'),true);
 const expected=decodeImport(encodeExport(value).text).value;body(expected).set('disabled',true);
 assert.deepEqual(typed(generated(editor)),typed(expected));assert.deepEqual(typed(value),before);assert.equal(Object.is(body(generated(editor)).get('priority'),-0),true);
 // A caller mutation of the accepted Map cannot reach the private snapshots.
 b.set('revision',99);assert.equal(body(generated(editor)).get('revision'),17);
});
test('legacy exports remain legacy with holes and distinct numeric and byte keys',()=>{
 const value=new Map([['rotation',new Map()],['cooldowns',new Map()],['metadata',new Map([['author','\xff']])],['opaque',new Map([[2,'hole'],['2','bytes']])]]);
 const {editor}=setup(value);assert.equal(editor.start(),true);assert.equal(editor.setPriority(true,-100000),true);const output=generated(editor);
 const expected=decodeImport(encodeExport(value).text).value;expected.set('priority',-100000);assert.deepEqual(typed(output),typed(expected));assert.equal(output.has('body'),false);
});
test('unset false true and signed zero are distinct literal commands with atomic invalid input',()=>{
 const {editor}=setup();assert.equal(editor.start(),true);
 for(const state of ['absent','false','true']){assert.equal(editor.setDisabled(state),true);const b=body(generated(editor));assert.equal(b.has('disabled'),state!=='absent');if(state!=='absent')assert.equal(b.get('disabled'),state==='true');}
 for(const priority of [-100000,-0,100000]){assert.equal(editor.setPriority(true,priority),true);assert.equal(Object.is(body(generated(editor)).get('priority'),priority),true);}
 assert.equal(editor.setPriority(false),true);const previous=editor.view();assert.equal(body(generated(editor)).has('priority'),false);
 for(const value of [100001,-100001,NaN,Infinity,1.5,'1',null])assert.equal(editor.setPriority(true,value),false);
 assert.equal(editor.setDisabled('unset'),false);assert.deepEqual(editor.view().fields,previous.fields);
});
test('generation needs an exact reviewed revision and never reuses earlier output',()=>{
 const {editor}=setup();editor.start();assert.equal(editor.generate().ok,false);generated(editor);assert.equal(typeof editor.view().output,'string');
 editor.setPriority(true,4);assert.equal(editor.view().output,null);assert.equal(editor.view().review,null);assert.equal(editor.generate().ok,false);
 editor.review();assert.equal(editor.generate().ok,true);
});
test('source replacement retirement cannot revive from matching text and retains recoverable field values',()=>{
 const s=setup(),e=s.editor;e.start();e.setPriority(true,42);generated(e);const original=s.source();s.replace(null);assert.equal(e.sync(),false);
 assert.equal(e.view().state,'retired');assert.equal(e.view().fields.priority.value,42);assert.equal(e.view().output,null);s.replace(original);assert.equal(e.sync(),false);assert.equal(e.generate().ok,false);assert.equal(e.start(),false);
 e.discard();assert.equal(e.start(),true);assert.notEqual(e.view().fields.priority.value,42);
});
test('admission validates actual Maps independently of analyzer claims and refuses future or strict-invalid input',()=>{
 for(const mutation of [v=>v.set('schemaVersion',2),v=>body(v).set('priority','wrong'),v=>body(v).set('rotation',new Map([[1,new Map([['id','branch'],['type','branch'],['onTrue',new Map()],['onFalse',new Map()],['future',true]])]]))]){
  const value=decodeImport(record.wire).value;mutation(value);const {editor}=setup(value);assert.equal(editor.start(),false);
 }
 const {editor}=setup(new Map([['priority',3]]));assert.equal(editor.start(),false);
});
test('unknown valid custom data remains editable and exported without executing it',()=>{
 const value=new Map([['rotation',new Map([[1,new Map([['id','custom'],['type','spell'],['action',403],['conditions',new Map([['type','CUSTOM_UNRESOLVED'],['source','error("never")']])]])]])],['cooldowns',new Map()]]);
 const {editor}=setup(value);assert.equal(editor.start(),true);editor.setPriority(true,0);assert.equal(body(generated(editor)).get('rotation').get(1).get('conditions').get('source'),'error("never")');
});
test('encoder refusal keeps the draft and no stale output rather than returning original bytes',()=>{
 const value=new Map([['rotation',new Map()],['cooldowns',new Map()],['pad1','a'.repeat(262144)],['pad2','b'.repeat(262144)],['pad3','c'.repeat(262144)],['pad4','d'.repeat(261000)]]);
 const initial=encodeExport(value);assert.equal(initial.ok,true);const length=Buffer.from(initial.text,'base64').length-1;
 value.set('pad4',value.get('pad4')+'d'.repeat(1048576-5-length));const original=encodeExport(value);assert.equal(original.ok,true);
 const decoded=decodeImport(original.text);assert.equal(decoded.ok,true);const {editor}=setup(decoded.value);assert.equal(editor.start(),true);assert.equal(editor.review().ok,true);assert.equal(editor.generate().ok,true);
 editor.setPriority(true,100000);assert.equal(editor.view().output,null);assert.equal(editor.review().ok,true);
 assert.deepEqual(editor.generate(),{ok:false,reason:'serialized-size-limit'});assert.equal(editor.view().output,null);assert.equal(editor.view().state,'current');assert.equal(editor.view().fields.priority.value,100000);
 editor.setPriority(false);editor.review();assert.equal(editor.generate().ok,true);
});
test('reentrant source reads cannot publish an older admission or retire a newer draft',()=>{
 const source=accepted(decodeImport(record.wire).value);let editor,reenter=true;
 editor=createDraftEditor({schemaText,readSource(){if(reenter){reenter=false;assert.equal(editor.start(),true);editor.setPriority(true,7);}return source;}});
 assert.equal(editor.start(),false);assert.equal(editor.view().fields.priority.value,7);assert.equal(body(generated(editor)).get('priority'),7);
});
test('missing schema source and disposed editors have no authority',()=>{
 const source=accepted(decodeImport(record.wire).value);const unavailable=createDraftEditor({readSource:()=>source});assert.equal(unavailable.start(),false);
 const {editor}=setup();editor.start();generated(editor);editor.dispose();assert.equal(editor.view().state,'empty');assert.equal(editor.start(),false);assert.equal(editor.setDisabled('true'),false);assert.equal(editor.generate().ok,false);
});
test('modified typed legacy fixture is accepted by actual LuaJIT codec and Lua5.1 Ace parser',()=>{
 const bytes=String.fromCharCode(...Array.from({length:256},(_,i)=>i));
 const value=new Map([['rotation',new Map()],['cooldowns',new Map()],['revision',17],['opaque',new Map([[1,false],['1',bytes],['zero',-0],['empty',new Map()]])]]),{editor}=setup(value);
 assert.equal(editor.start(),true);editor.setPriority(true,-0);editor.setDisabled('false');editor.review();const result=editor.generate();assert.equal(result.ok,true);
 const program=String.raw`
local payload=io.read('*a');local value
if mode=='wire' then local data,deps=dofile('tests/fixtures/codec.lua')();value=assert(assert(data.NewCodec(deps)):Decode(payload)).value
else assert(loadfile('Libs/LibStub/LibStub.lua'))();assert(loadfile('Libs/AceSerializer-3.0/AceSerializer-3.0.lua'))();local raw=payload:gsub('..',function(h)return string.char(tonumber(h,16))end);local ok;ok,value=LibStub('AceSerializer-3.0'):Deserialize(raw);assert(ok)end
assert(value.priority==0 and 1/value.priority==-math.huge and value.disabled==false and value.revision==17)
assert(value.opaque[1]==false and value.opaque.zero==0 and 1/value.opaque.zero==-math.huge and next(value.opaque.empty)==nil)
local bytes={};for i=0,255 do bytes[#bytes+1]=string.char(i)end;assert(value.opaque['1']==table.concat(bytes));io.write('accepted')`;
 for(const [vm,mode,payload]of [['luajit','wire',result.text],['lua5.1','serializer',Buffer.from(result.text,'base64').subarray(1).toString('hex')]]){
  const native=spawnSync(vm,['-e',"local mode='"+mode+"';"+program],{cwd:new URL('../',import.meta.url),input:payload,encoding:'utf8',timeout:15000});assert.equal(native.status,0,native.stderr);assert.equal(native.stdout,'accepted');
 }
});
test('opaque aliases to the selected body do not become a second write target',()=>{
 const value=decodeImport(record.wire).value;value.set('opaqueBody',value.get('body'));const expected=decodeImport(encodeExport(value).text).value;expected.get('body').set('disabled',true);
 const {editor}=setup(value);assert.equal(editor.start(),true);editor.setDisabled('true');assert.deepEqual(typed(generated(editor)),typed(expected));
});
test('a source read failure retires generated authority without losing recoverable edits',()=>{
 const source=accepted(decodeImport(record.wire).value);let broken=false;const editor=createDraftEditor({schemaText,readSource(){if(broken)throw Error('read unavailable');return source;}});
 editor.start();editor.setPriority(true,29);generated(editor);broken=true;assert.equal(editor.sync(),false);assert.equal(editor.view().output,null);assert.equal(editor.view().fields.priority.value,29);broken=false;assert.equal(editor.sync(),false);assert.equal(editor.generate().ok,false);
});
for(const [before,after]of [[0,-0],[-0,0]])test('literal priority review records '+(Object.is(before,-0)?'-0':'0')+' to '+(Object.is(after,-0)?'-0':'0')+' before exporting changed bits',()=>{
 const original=encodeExport(new Map([['rotation',new Map()],['cooldowns',new Map()],['priority',before],['disabled',false],['revision',17]])).text;
 const value=decodeImport(original).value,unchanged=typed(value),{editor}=setup(value);assert.equal(editor.start(),true);editor.setPriority(true,after);
 const review=editor.review();assert.equal(review.ok,true);assert.equal(review.changes.length,1);const change=review.changes[0];assert.equal(change.field,'priority');assert.equal(change.before.present,true);assert.equal(change.after.present,true);assert.equal(Object.is(change.before.value,before),true);assert.equal(Object.is(change.after.value,after),true);
 const output=editor.generate();assert.equal(output.ok,true);assert.notEqual(output.text,original);assert.equal(Object.is(decodeImport(output.text).value.get('priority'),after),true);assert.deepEqual(typed(value),unchanged);
});
test('unchanged zero bits absence and false have no literal review changes and presence edits stay single',()=>{
 for(const priority of [undefined,0,-0])for(const disabled of [undefined,false]){
  const value=new Map([['rotation',new Map()],['cooldowns',new Map()]]);if(priority!==undefined)value.set('priority',priority);if(disabled!==undefined)value.set('disabled',disabled);
  const before=typed(value),{editor}=setup(value);assert.equal(editor.start(),true);editor.setPriority(priority!==undefined,priority);editor.setDisabled(disabled===undefined?'absent':'false');assert.deepEqual(editor.review(),{ok:true,changes:[]});assert.deepEqual(typed(generated(editor)),before);
  editor.setDisabled(disabled===undefined?'false':'absent');const changed=editor.review();assert.equal(changed.changes.length,1);assert.equal(changed.changes[0].field,'disabled');assert.equal(changed.changes[0].before.present,disabled!==undefined);assert.equal(changed.changes[0].after.present,disabled===undefined);
 }
});
