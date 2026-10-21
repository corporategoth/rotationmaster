// Pure structural tests; real I1 modules are loaded from a pinned dependency.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import * as nodeModule from 'node:module';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const localCodec=resolve(root,'Web/codec');
const dependency=process.env.RM_WEB_CODEC_ROOT?resolve(process.env.RM_WEB_CODEC_ROOT):localCodec;
const pins={'lua-data.mjs':'197f4284c4529359baf1c9a1fba8b79129bf77517c3e40b805baa63475b0f112',
 'import.mjs':'c25ab2ec6dab450cab7c6b88b9e3f3d1446f0ce1d84cdc7086ed122a56a77061',
 'libcompress.mjs':'4103d7a3a6a9bc55cd69c4a080e7747cb39aade2424a6b69870da5fb1fce0424',
 'ace-serializer.mjs':'e872564af1777665f4a3133e6ea555400aef2e0da98d600633330ee2ccbc1b61'};
// Normal adjacent I1 imports need no loader hook or recent hook API. Only
// the explicit isolated-author dependency seam uses this optional Node API.
if(dependency!==localCodec){
 if(typeof nodeModule.registerHooks!=='function')throw new Error('RM_WEB_CODEC_ROOT isolated dependency seam requires node:module.registerHooks; use adjacent Web/codec or a Node version supporting synchronous hooks');
 nodeModule.registerHooks({resolve(specifier,context,next){
 if(context.parentURL===pathToFileURL(resolve(root,'Web/schema/rotation.mjs')).href && specifier==='../codec/lua-data.mjs')
  return next(pathToFileURL(resolve(dependency,'lua-data.mjs')).href,context);
 return next(specifier,context);
 }});
}
let api,moduleError;
try{api=await import('../Web/schema/rotation.mjs');}catch(error){moduleError=error;}
function ready(){assert.ok(api,'missing structural validator: '+moduleError);}
const catalogText=()=>readFileSync(resolve(root,'Web/schema/catalog.json'),'utf8');
const table=o=>new Map(Object.entries(o));
function typed(v){
 if(v.type==='table')return new Map(v.entries.map(([k,x])=>[typed(k),typed(x)]));
 if(v.type==='bytes')return Buffer.from(v.hex,'hex').toString('latin1');
 if(v.type==='number'){const b=Buffer.from(v.bits,'hex');return b.readDoubleBE();}
 if(v.type==='boolean')return v.value;
 if(v.type==='nil')return null;
 throw Error('unknown oracle type');
}
function oracle(vm){
 const r=spawnSync(vm,['tests/fixtures/web_schema.lua'],{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
 assert.equal(r.status,0,r.stderr);return JSON.parse(r.stdout);
}
function comparable(r){
 if(r.ok===true&&r.index){const copy=(v,omit)=>Object.fromEntries(Object.entries(v).filter(([k])=>k!==omit));return {ok:true,rows:r.index.rows.map(v=>copy(v,'step')),lists:r.index.lists.map(v=>copy(v,'list'))};}
 const {scope,nativeAvailability,...rest}=r;return rest;
}
// This one Lua subdomain iterates pairs(allowed), so its five diagnostic
// positions differ between Lua5.1/JIT. Preserve exact statuses and code/path
// multiplicity; every other case retains complete ordered diagnostic parity.
function metadataOrder(row,out){
 if(row.id!=='multiple-invalid-metadata-fields')return out;
 const paths=['author','realm','email','website','version'].map(k=>'$.body.metadata.'+k);
 assert.equal(out.diagnostics.length,5);
 for(const d of out.diagnostics){assert.equal(d.code,'invalid-field-type');assert.equal(d.severity,'error');assert(paths.includes(d.path));}
 assert.equal(new Set(out.diagnostics.map(d=>d.path)).size,5);
 return {...out,diagnostics:[...out.diagnostics].sort((a,b)=>a.path.localeCompare(b.path))};
}
test('pinned I1 dependency exists unchanged, never replaced by codec mocks',()=>{
 for(const [name,want]of Object.entries(pins))assert.equal(createHash('sha256').update(readFileSync(resolve(dependency,name))).digest('hex'),want,name);
});
test('generator output is current inert catalog with all curated identities and distinct ROLE schemas',()=>{
 ready();const r=spawnSync('lua5.1',['tools/export_web_schema.lua'],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);
 assert.equal(r.stdout,catalogText());const c=JSON.parse(r.stdout);assert.equal(c.conditions.length,118);
 assert.equal(c.conditions.find(x=>x.id==='ROLE').declarations.length,2);
 assert(!c.conditions.some(x=>['DELETE','AND','OR','NOT'].includes(x.id)));
 for(const [path,sha]of Object.entries(c.sourceFiles))assert.equal(createHash('sha256').update(readFileSync(resolve(root,path))).digest('hex'),sha,path);
 const forbidden=new Set(['code','evaluate','valid','print','help','widget','on_register','on_unregister','bindings']);
 const walk=v=>{if(v&&typeof v==='object')for(const[k,x]of Object.entries(v)){assert(!forbidden.has(k),'callback payload leaked: '+k);walk(x);}};walk(c);
});
test('actual Lua structural oracle agrees in both VMs and JS on all declarations and boundaries',()=>{
 ready();const a=oracle('lua5.1'),b=oracle('luajit');
 const ordered=x=>({...x,cases:x.cases.map(row=>({...row,expected:metadataOrder(row,row.expected)}))});
 assert.deepEqual(ordered(a),ordered(b));assert.equal(a.callbackCalls,0);
 assert(a.cases.length>300,'oracle omitted declaration/edge controls');let leaves=new Set();
 for(const row of a.cases){
  if(row.leaf)leaves.add(row.leaf);
  const input=typed(row.input),options=row.options||{};
  const out=row.kind==='index'?api.indexRotationSteps(input,options):row.kind==='envelope'?api.validateEnvelope(input,catalogText(),options):api.validateBody(input,catalogText(),options);
  assert.deepEqual(metadataOrder(row,comparable(out)),metadataOrder(row,row.expected),row.id);
 }
 assert.equal(leaves.size,118,'not every curated leaf was exercised');
});
test('no client case is guessed for ROLE or provider declarations and DELETE stays unresolved',()=>{
 ready();for(const leaf of [{type:'ROLE',unit:'player',value:'HEALER'},{type:'ECS_STAT',stat:'crit',value:1},{type:'DELETE'},{type:'UNINSTALLED_CUSTOM',source:'error("never")'}]){
  const body=table({rotation:new Map(),cooldowns:new Map(),switch:table(leaf)});const r=api.validateBody(body,catalogText());
  assert.equal(r.valid,true);assert.equal(r.resolved,false);assert.equal(r.executionStatus,'unavailable');assert.equal(r.nativeAvailability,'unverified');
 }
});
test('malformed catalogs fail closed before input inspection or executable properties',()=>{
 ready();let executed=0;const hostile=new Proxy({}, {get(){executed++;throw Error('must not read input');}});
 const c=JSON.parse(catalogText());
 const badFields=JSON.parse(catalogText());badFields.conditions[0].declarations[0].fields='number';
 const broken=[JSON.stringify(badFields),'not-json','{}',JSON.stringify({...c,version:2}),JSON.stringify({...c,conditions:[...c.conditions,c.conditions[0]]}),JSON.stringify({...c,code:'error("never")'})];
 for(const text of broken){const r=api.validateBody(hostile,text);assert.equal(r.valid,false);assert.equal(r.diagnostics[0].code,'invalid-catalog');}
 const getter={get format(){executed++;throw Error('must not read catalog getter');}};
 assert.equal(api.validateBody(hostile,getter).diagnostics[0].code,'invalid-catalog');assert.equal(executed,0);
});
test('input remains a byte-preserving Map and unknown data is never executed or rewritten',()=>{
 ready();const unknown=table({type:'CUSTOM',source:'globalThis.__schemaExecuted=true',constructor:'inert',__proto__:'inert'});
 unknown.set('__proto__','inert');const body=table({rotation:new Map(),cooldowns:new Map(),switch:unknown});const before=[...unknown];
 const r=api.validateBody(body,catalogText(),{declarationCase:'case-3'});
 assert.equal(r.resolved,false);assert.deepEqual([...unknown],before);assert.equal(globalThis.__schemaExecuted,undefined);assert.equal(Object.prototype.inert,undefined);
 const bad=new Proxy(new Map(),{get(){throw Error('proxy input executed');}});
 assert.equal(api.validateBody(bad,catalogText()).valid,false);
});
test('reference ID sets resolve only declared data and preserve unknown native facts',()=>{
 ready();const body=table({rotation:new Map([[1,table({id:'s',type:'item',action:'set',effect:'effect'})]]),cooldowns:new Map()});
 const a=api.validateBody(body,catalogText());assert.equal(a.resolved,false);
 const b=api.validateBody(body,catalogText(),{itemsets:new Set(['set']),effects:new Set(['effect'])});assert.equal(b.resolved,true);assert.equal(b.semanticStatus,'not-evaluated');assert.equal(b.executionStatus,'unchecked');
 const empty=table({rotation:new Map([[1,table({id:'empty',type:'spell',action:403,effect:''})]]),cooldowns:new Map()});
 assert.equal(api.validateBody(empty,catalogText()).resolved,false);
 assert.equal(api.validateBody(empty,catalogText(),{effects:new Set([''])}).resolved,true,'Lua empty effect is truthy and may have a declared reference');
});

test('literal source contracts keep switch semantics, future metadata, row bounds and capped status',()=>{
 ready();const c=catalogText();
 const ordinary=table({rotation:new Map(),cooldowns:new Map(),switch:table({type:'SPELL_KNOWN',spell:-1})});
 const a=api.validateBody(ordinary,c,{declarationCase:'case-3'});assert.equal(a.valid,true);assert.equal(a.resolved,true);assert.equal(a.executionStatus,'unchecked');
 const branch=table({id:'branch',type:'branch',future:'opaque',onTrue:new Map(),onFalse:new Map()});
 const tree=table({rotation:new Map([[1,branch]]),cooldowns:new Map()});
 const b=api.validateBody(tree,c);assert.equal(b.valid,true);assert.equal(b.supported,false);assert.equal(api.indexRotationSteps(tree).diagnostic.code,'unexpected-branch-field');
 const list=new Map();for(let i=1;i<=2000;i++)list.set(i,table({id:'step-'+i,type:'none'}));
 const many=table({rotation:list,cooldowns:new Map()});assert.equal(api.indexRotationSteps(many).ok,true);
 list.set(2001,table({id:'overflow',type:'none'}));assert.equal(api.indexRotationSteps(many).diagnostic.code,'rotation-node-limit');
 const errors=new Map();for(let i=1;i<=150;i++)errors.set(i,table({id:'bad-'+i,type:3,future:true}));
 const d=api.validateBody(table({rotation:errors,cooldowns:new Map()}),c);assert.equal(d.diagnostics.length,100);assert.equal(d.valid,false);assert.equal(d.supported,false);
});
test('provider presence probes are never promoted to installed/readable provider context',()=>{
 ready();for(const type of ['RUNNER','RESIST','IMMUNE','ECS_STAT','ECS_STAT_PCT']){
  const r=api.validateBody(table({rotation:new Map(),cooldowns:new Map(),switch:table({type})}),catalogText(),{declarationCase:'case-8'});
  assert.equal(r.valid,true);assert.equal(r.resolved,false);assert.equal(r.diagnostics[0].code,'unknown-condition');assert.equal(r.nativeAvailability,'unverified');
 }
});

test('runtime definition flags are not an advertised static-catalog options surface',()=>{
 ready();const body=table({rotation:new Map(),cooldowns:new Map(),switch:table({type:'SPELL_KNOWN',spell:403})});
 const r=api.validateBody(body,catalogText(),{definitionFlags:new Map([['SPELL_KNOWN',{disabled:true}]])});
 assert.equal(r.valid,false);assert.equal(r.diagnostics[0].code,'invalid-options');
});
test('tag validation retains both normalization-vector inputs without exposing normalized output',()=>{
 ready();for(const tags of [['A','a','\xc3\x84','\xc3\xa4',' A ','\xc2\xa0'],[' A ','B']]){
  const list=new Map(tags.map((v,i)=>[i+1,v])),body=table({rotation:new Map(),cooldowns:new Map(),tags:list});const before=[...list];
  const r=api.validateBody(body,catalogText());assert.equal(r.valid,true);assert.deepEqual([...list],before);assert.equal(r.tags,undefined);
 }
});
test('exporter refuses malformed required-field containers instead of dropping data',()=>{
 const script=`local m=dofile('tools/export_web_schema.lua');local old=m.loadCase;m.loadCase=function(i)local f=old(i);f.addon.definitions.LEVEL.requiredFields={[1]='unit',hidden='value'};return f end;m.build()`;
 const r=spawnSync('lua5.1',['-e',script],{cwd:root,encoding:'utf8'});assert.notEqual(r.status,0,'malformed named metadata was silently omitted');
});
test('index options are inert data and malformed options fail without running getters',()=>{
 ready();let calls=0;const options={get allowMissingIds(){calls++;throw Error('index getter executed');}};
 const body=table({rotation:new Map([[1,table({type:'none'})]]),cooldowns:new Map()});
 const r=api.indexRotationSteps(body,options);assert.equal(r.ok,false);assert.equal(r.diagnostic.code,'invalid-options');assert.equal(calls,0);
});

test('deep malformed catalog marker arrays return invalid-catalog before input access',()=>{
 ready();let calls=0;const input=new Proxy({}, {get(){calls++;throw Error('input inspected');}});
 for(const key of ['logical','uiOnly']){
  const c=JSON.parse(catalogText());c[key]=null;
  const text=JSON.stringify(c).replace('"'+key+'":null','"'+key+'":'+'['.repeat(12000)+'0'+']'.repeat(12000));
  for(const validate of [api.validateBody,api.validateEnvelope]){
   const out=validate(input,text);assert.equal(out.diagnostics[0].code,'invalid-catalog');assert.equal(out.valid,false);
  }
 }
 assert.equal(calls,0);
});
test('numeric unknown-key and portable-failure paths use Lua number text without parsing key strings',()=>{
 ready();const text=catalogText();
 const body=table({rotation:new Map(),cooldowns:new Map()});body.set(1e20,true);
 assert.equal(api.validateBody(body,text).diagnostics[0].path,'$.body.1e+20');
 const key='[100000000000000000000].'+ 'x'.repeat(90),opaque=new Map([[9007199254740992,Infinity]]);
 body.delete(1e20);body.set(key,opaque);
 assert.equal(api.validateBody(body,text).diagnostics[0].path,'$.body.'+key.slice(0,80)+'[9.007199254741e+15]');
 assert.equal(api.indexRotationSteps(body).diagnostic.path,'$.'+key.slice(0,80)+'[9.007199254741e+15]');
});

test('metadata diagnostics have a fixed JS order where Lua pairs order differs by VM',()=>{
 ready();const metadata=table({author:1,realm:2,email:3,website:4,version:5});
 const body=table({rotation:new Map(),cooldowns:new Map(),metadata});
 assert.deepEqual(api.validateBody(body,catalogText()).diagnostics.map(d=>d.path),['author','realm','email','website','version'].map(k=>'$.body.metadata.'+k));
});

test('exporter rejects sparse required-fields even when Lua length equals key count',()=>{
 const script=`local m=dofile('tools/export_web_schema.lua');local old=m.loadCase;m.loadCase=function(i)local f=old(i);f.addon.definitions.LEVEL.requiredFields={[1]='unit',[3]='operator',[4]='value',[7]='relative'};return f end;m.build()`;
 for(const vm of ['lua5.1','luajit']){
  const r=spawnSync(vm,['-e',script],{cwd:root,encoding:'utf8'});
  assert.notEqual(r.status,0,vm+' silently omitted sparse required fields');assert.match(r.stderr,/sparse requiredFields list/);
 }
});
