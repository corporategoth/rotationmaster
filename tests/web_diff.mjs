import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {decodeImport} from '../Web/codec/import.mjs';
import {toTypedTree} from '../Web/codec/lua-data.mjs';
const {diffRotations}=await import('../Web/schema/diff.mjs').catch(e=>{if(e.code==='ERR_MODULE_NOT_FOUND')return {};throw e;});
const fixtures=JSON.parse(readFileSync(new URL('./fixtures/web_diff.json',import.meta.url)));
const M=entries=>new Map(entries),list=values=>M(values.map((v,i)=>[i+1,v]));
const env=steps=>M([['body',M([['rotation',list(steps)],['cooldowns',M([])]])]]);
const step=(id,action=403)=>M([['id',id],['type','spell'],['action',action]]);
const options=m=>m?Object.fromEntries(m):undefined;
function resultMap(r){return M(Object.entries(r).map(([k,v])=>[k,k==='changes'?list(v.map(c=>M(Object.entries(c).map(([f,x])=>[f,f==='segments'?list(x.map(s=>M(Object.entries(s)))):x])))):k==='diagnostics'?list(v.map(d=>M(Object.entries(d)))):v]));}
function run(left,right,opts){assert.equal(typeof diffRotations,'function','pure comparator is absent');return diffRotations(left,right,opts);}
for(const row of fixtures.cases.filter(r=>r.wire))test('frozen actual Lua oracle: '+row.id,()=>{
 const d=decodeImport(row.wire);assert(d.ok);const v=d.value;const left=v.get('left'),right=v.get('right');const before=[toTypedTree(left),toTypedTree(right)];const actual=run(left,right,options(v.get('options')));assert.deepEqual(toTypedTree(resultMap(actual)),toTypedTree(v.get('result')));assert.deepEqual([toTypedTree(left),toTypedTree(right)],before);
});
test('fresh actual LuaJIT exporter parity does not depend on generated fixture replacement',()=>{
 const text=execFileSync('luajit',['tools/export_web_diff_fixtures.lua'],{cwd:new URL('..',import.meta.url),encoding:'utf8'});let n=0;
 for(const line of text.trim().split('\n')){const row=JSON.parse(line);if(!row.wire)continue;const v=decodeImport(row.wire).value;assert.deepEqual(toTypedTree(resultMap(run(v.get('left'),v.get('right'),options(v.get('options'))))),toTypedTree(v.get('result')),row.id);n++;}assert.equal(n,15);
});
test('LIS large move and 500-change truncation remain bounded and explicit',()=>{
 const a=env(Array.from({length:1000},(_,i)=>step('s'+i))),b=env([...a.get('body').get('rotation').values()].map(s=>M(s)));const l=b.get('body').get('rotation');const first=l.get(1);for(let i=1;i<1000;i++)l.set(i,l.get(i+1));l.set(1000,first);let r=run(a,b);assert(r.valid&&r.complete);assert.equal(r.changes.length,1);assert.equal(r.changes[0].kind,'moved');for(const s of l.values())s.set('action',529);r=run(a,b);assert(r.valid&&!r.complete);assert.equal(r.changes.length,500);assert.equal(r.diagnostics[0].code,'diff-change-limit');
});
test('4096-byte display path bound reports incomplete without fabricated equality',()=>{const a=env([]),b=env([]);a.set('k'.repeat(4097),1);b.set('k'.repeat(4097),2);const r=run(a,b);assert(r.valid&&!r.complete);assert.equal(r.changes.length,0);assert.equal(r.diagnostics[0].code,'diff-path-limit');});
test('results detach before/after payloads and path segments from input and later calls',()=>{
 const a=env([]),b=env([step('one')]);const r=run(a,b);r.changes[0].after.set('action',999);r.changes[0].segments[0].key='modified';assert.equal(b.get('body').get('rotation').get(1).get('action'),403);assert.equal(run(a,b).changes[0].segments[0].key,'body');
});
test('untrusted option accessors, prototypes and host objects do not execute',()=>{
 let calls=0;for(const o of [Object.defineProperty({},'ignoreIdentity',{get(){calls++;throw Error('PRIVATE');}}),Object.create({}),new Map(),()=>{},null,{extra:true},{ignoreIdentity:'yes'},{leftOrigins:{}}]){const r=run(env([]),env([]),o);assert(!r.valid);assert.equal(r.diagnostics[0].code,'invalid-options');}assert.equal(calls,0);
});
test('native Map input methods are not invoked and cycle/nonfinite/function/Unicode failures are bounded',()=>{
 const a=env([]);a.entries=a.keys=a.get=()=>{throw Error('input method');};assert(run(a,env([])).valid);
 const cyc=M([]);cyc.set('self',cyc);for(const [v,code]of [[cyc,'data-cycle'],[M([['bad',NaN]]),'non-finite-number'],[M([['bad',()=>{}]]),'non-portable-type'],[M([['bad','\u1000']]),'non-portable-type']]){const r=run(v,env([]));assert(!r.valid);assert.equal(r.diagnostics[0].code,code);assert.equal(r.changes.length,0);}
 let getter=0;const proxy=new Proxy(new Map(),{getPrototypeOf(){getter++;throw Error('trap');}});assert(!run(proxy,env([])).valid);assert.equal(getter,0);
});
test('strict branch indexing validates forced-away arms and rejects unknown branch fields',()=>{
 const s=M([['id','branch'],['type','branch'],['mode','false'],['onTrue',list([step('same')])],['onFalse',list([step('same')])]]);let r=run(env([s]),env([]));assert.equal(r.diagnostics[0].code,'ambiguous-step-identity');s.set('onTrue',list([]));s.set('future',true);r=run(env([s]),env([]));assert.equal(r.diagnostics[0].code,'unexpected-branch-field');
});
test('per-input portable and index limits are enforced without raising defaults',()=>{
 for(const [a,code]of [[M([['s','x'.repeat(262145)]]),'data-string-limit'],[env(Array.from({length:2001},(_,i)=>step('s'+i))),'rotation-node-limit'],[M(Array.from({length:10001},(_,i)=>['k'+i,false])),'data-node-limit']])assert.equal(run(a,env([])).diagnostics[0].code,code);
 let a=false;for(let i=0;i<66;i++)a=M([['n',a]]);assert.equal(run(a,env([])).diagnostics[0].code,'data-depth-limit');
});
function oracle(lua){const source="local d,deps=dofile('tests/fixtures/codec.lua')();local codec=assert(d.NewCodec(deps));"+lua;return execFileSync('luajit',['-e',source],{cwd:new URL('..',import.meta.url),encoding:'utf8'}).trim().split('\n').map(s=>decodeImport(s).value);}
function assertOracle(v){const actual=run(v.get('left'),v.get('right'),options(v.get('options')));assert.deepEqual(toTypedTree(resultMap(actual)),toTypedTree(v.get('result')));}
test('actual LuaJIT quoting covers all byte controls, following digits and raw high bytes',()=>{
 for(const v of oracle(`local a,b={body={}},{body={}};for i=0,255 do local k=string.char(i)..'4';a[k]=false;b[k]=true end;print(assert(codec:Encode({left=a,right=b,result=d.DiffRotations(a,b)})))`))assertOracle(v);
});
test('actual large finite numeric-key display rounding retains typed integer identity',()=>{
 for(const v of oracle(`local a,b={body={}},{body={}};for _,k in ipairs({1e14,1e20,1e100,1e300,9007199254740992,100000000000005,100000000000015,999999999999995})do a[k]=1;b[k]=2 end;print(assert(codec:Encode({left=a,right=b,result=d.DiffRotations(a,b)})))`))assertOracle(v);
});
test('deterministic actual Lua pairs compare fields, identities, moves, nested payload and false values',()=>{
 const values=oracle(`for n=1,40 do local a={id='a',revision=1,body={rotation={},cooldowns={}}};for i=1,6 do a.body.rotation[i]={id='s'..i,type='spell',action=i,conditions={type='AND',value={}},ranked=i%2==0}end;local b=assert(d.CopyData(a));local t=b.body.rotation;table.insert(t,1,table.remove(t,n%6+1));t[n%6+1].action=400+n;t[n%6+1].conditions.payload={['body.rotation']=false,[1]=n,['1']='byte'};if n%2==0 then b.body.revision=n end;if n%3==0 then b.revision=n end;print(assert(codec:Encode({left=a,right=b,result=d.DiffRotations(a,b)})))end`);assert.equal(values.length,40);for(const v of values)assertOracle(v);
});
test('exact display path boundary, default absent lists and body primitives match actual API',()=>{
 const values=oracle(`for _,n in ipairs({4094,4095})do local a,b={body={}},{body={}};a[string.rep('a',n)]=1;b[string.rep('a',n)]=2;print(assert(codec:Encode({left=a,right=b,result=d.DiffRotations(a,b)})))end;for _,body in ipairs({false,0,'',true})do local a,b={body=body},{body={}};print(assert(codec:Encode({left=a,right=b,result=d.DiffRotations(a,b)})))end`);assert.equal(values.length,6);for(const v of values)assertOracle(v);
});
test('branch-depth limit and aggregate byte budget remain separately enforced',()=>{
 function nested(n){let s=step('end');for(let i=0;i<n;i++)s=M([['id','b'+i],['type','branch'],['onTrue',list([s])],['onFalse',list([])]]);return env([s]);}
 // Portable depth64 is independent and may fail before a deeper branch graph.
 const r=run(nested(17),env([]));assert(!r.valid);assert(['rotation-depth-limit','data-depth-limit'].includes(r.diagnostics[0].code));
 const a=env([]);for(let i=0;i<5;i++)a.set('text'+i,'x'.repeat(262140));assert.equal(run(a,env([])).diagnostics[0].code,'data-byte-limit');
});
test('ordinary false origin falls back, unused malformed origin stays inert, and collisions refuse',()=>{
 const a=env([step('one')]);assert.equal(run(a,a,{rightOrigins:M([['one',false],['unused','!']])}).changes.length,0);const r=run(a,env([step('x'),step('one')]),{rightOrigins:M([['x','one']])});assert(!r.valid);assert.equal(r.changes.length,0);assert.equal(r.diagnostics[0].code,'ambiguous-step-identity');
});

test('accepted null-valued nested payloads remain portable in detached output',()=>{
 const added=M([['nil',null],['other',false]]),right=M([['added',added]]);
 const before=toTypedTree(right);const r=run(M([]),right);assert(r.valid&&r.complete);
 const copied=r.changes[0].after;assert.deepEqual(toTypedTree(copied),toTypedTree(added));
 assert.notEqual(copied,added);assert.equal(copied.get('nil'),null);
 copied.set('other',true);assert.deepEqual(toTypedTree(right),before);
});
