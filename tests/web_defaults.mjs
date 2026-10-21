import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {decodeImport} from '../Web/codec/import.mjs';
import {toTypedTree,checkPortable} from '../Web/codec/lua-data.mjs';
import {validateEnvelope,indexRotationSteps} from '../Web/schema/rotation.mjs';
import {diffRotations} from '../Web/schema/diff.mjs';
let api;try{api=await import('../Web/catalog/defaults.mjs');}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
const root=new URL('..',import.meta.url),catalogURL=new URL('../Web/catalog/defaults.json',import.meta.url);
const declarations=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
const text=()=>{assert(existsSync(catalogURL),'generated bundled catalog missing');return readFileSync(catalogURL,'utf8');};
const raw=()=>JSON.parse(text());
const parse=(value=text(),schema=declarations)=>{assert.equal(typeof api?.createBundledRotationCatalog,'function','pure bundled catalog API missing');return api.createBundledRotationCatalog(value,schema);};
const ready=()=>{const r=parse();assert.equal(r.ok,true);return r.catalog;};
const reject=doc=>{const r=parse(typeof doc==='string'?doc:JSON.stringify(doc));assert.deepEqual(r,{ok:false,reason:'invalid-bundled-catalog'});};
const bytes=s=>({type:'bytes',hex:Buffer.from(s,'latin1').toString('hex')});
const fields=m=>new Map(m.entries.map(([k,v])=>[Buffer.from(k.hex,'hex').toString('latin1'),v]));
function set(m,k,v){const hex=bytes(k).hex;const row=m.entries.find(([key])=>key.type==='bytes'&&key.hex===hex);if(row)row[1]=v;else m.entries.push([bytes(k),v]);}
const number=n=>{const b=Buffer.alloc(8);b.writeDoubleBE(n);return{type:'number',bits:b.toString('hex')};};

test('pure catalog exposes all28 actual source definitions without runtime facts',()=>{
 const c=ready(),rows=c.list();assert.equal(rows.length,28);assert.equal(new Set(rows.map(r=>r.id)).size,28);
 for(const row of rows){assert.equal(row.applicability.get('families').get(1),'tbc');assert.equal(row.validation.nativeAvailability,'unverified');for(const k of ['eligible','enabled','runtimeKey','spellName','icon'])assert.equal(Object.hasOwn(row,k),false);const value=c.get(row.id);assert(value.ok&&checkPortable(value.envelope).ok);const report=validateEnvelope(value.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);assert(indexRotationSteps(value.envelope.get('body')).ok);}
 assert.deepEqual(c.get({toString(){throw Error('no coercion');}}),{ok:false,reason:'unknown-default'});
});
test('production generator is deterministic/current BOTH and source inputs exact',()=>{
 const expected=text();for(const vm of ['lua5.1','luajit'])for(let i=0;i<2;i++)assert.equal(execFileSync(vm,['tools/export_web_defaults.lua'],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024}),expected);
 const doc=raw();for(const[path,sha]of Object.entries(doc.sourceFiles))assert.equal(createHash('sha256').update(readFileSync(new URL('../'+path,import.meta.url))).digest('hex'),sha,path);
 const toc=readFileSync(new URL('../RotationMaster.toc',import.meta.url),'utf8').split(/\r?\n/).filter(s=>/^Defaults\/.+\.lua$/.test(s));assert.deepEqual([...doc.packs.map(p=>p.sourcePath)].sort(),toc.sort());
});
test('all28 pinned actual codec wires decode to exact catalog Maps and strict diff equality',()=>{
 const fixture=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))),c=ready();assert.equal(fixture.format,'RotationMasterBundledDefaultWireFixtures');assert.equal(fixture.records.length,28);
 let rows=0;for(const record of fixture.records){const decoded=decodeImport(record.wire);assert(decoded.ok&&decoded.kind==='envelope');const selected=c.get(record.id);assert(selected.ok);assert.deepEqual(toTypedTree(decoded.value),record.expected);assert.deepEqual(toTypedTree(selected.envelope),record.expected);assert.equal(selected.source.sha256,record.sourceSHA);rows+=indexRotationSteps(decoded.value.get('body')).index.rows.length;const diff=diffRotations(decoded.value,selected.envelope);assert(diff.valid&&diff.complete&&diff.changes.length===0);}assert.equal(rows,258);
});
test('first19 frozen wire records stay exact; Hunter30–39 remains twentieth',()=>{
 const records=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))).records;
 assert.equal(records.length,28);
 assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,19))).digest('hex'),'354927d1a786ed221d8438670ab6b32689d586b0cf4fd3a288bebda299a86046');
 assert.equal(records[19].id,'rm.tbc.hunter.starter.30-39');
 assert.equal(records.filter(r=>r.id==='rm.tbc.hunter.starter.30-39').length,1);
});
test('first20 frozen wire records remain ordered; four class continuations append once',()=>{
 const records=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))).records;
 assert.equal(records.length,28);
 assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,20))).digest('hex'),'9f0a089c84b90cd7410a08efb7781ac730fbeb716a198b27f100c8af892db090');
 assert.deepEqual(records.slice(20,24).map(r=>r.id),["rm.tbc.druid.caster.starter.30-39","rm.tbc.paladin.starter.30-39","rm.tbc.rogue.starter.30-39","rm.tbc.warrior.starter.30-39"]);
});
test('first24 frozen wire records and catalog objects stay exact; Hunter40–49 appends once',()=>{
 const records=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))).records;
 assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,24))).digest('hex'),'c5d5576fe961b713f2ce59ffdcfb13fa49da21129ff75eab1bf4433bd1119e25');
 assert.equal(records[24].id,'rm.tbc.hunter.starter.40-49');
 assert.equal(records.filter(r=>r.id==='rm.tbc.hunter.starter.40-49').length,1);
 const old=raw().packs.filter(p=>p.id!=='rm.tbc.hunter.starter.40-49'&&p.id!=='rm.tbc.priest.shadow.40-49'&&p.id!=='rm.tbc.shaman.enhancement.40-49'&&p.id!=='rm.tbc.warlock.starter.40-49');
 assert.equal(createHash('sha256').update(JSON.stringify(old)).digest('hex'),'328b99ef8f466fda2c74db84cce16b72813d581d8470a283609c8caf90d2ac20');
});
test('first25 frozen wires and catalog objects stay ordered; Priest40–49 appends once',()=>{
 const records=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))).records;
 assert.equal(records.length,28);
 assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,25))).digest('hex'),'9b207ff6cbde16c3b1a9b92310fc27542dc2293c28fcd674c88dbcefbac00e02');
 assert.equal(records[25].id,'rm.tbc.priest.shadow.40-49');
 assert.equal(records.filter(r=>r.id==='rm.tbc.priest.shadow.40-49').length,1);
 const old=raw().packs.filter(p=>p.id!=='rm.tbc.priest.shadow.40-49'&&p.id!=='rm.tbc.shaman.enhancement.40-49'&&p.id!=='rm.tbc.warlock.starter.40-49');
 assert.equal(createHash('sha256').update(JSON.stringify(old)).digest('hex'),'30462a529f06ab944725e206367cb964d3f05180b40be6415ff72ab81516a5d6');
});
test('get/list outputs never expose private manifest, facets or declaration state',()=>{
 const c=ready(),first=c.list()[0],before=toTypedTree(c.get(first.id).envelope),one=c.get(first.id);one.envelope.get('body').get('rotation').clear();one.envelope.get('sources').get(1).set('url','poison');one.display.name='poison';one.source.sha256='poison';one.validation.diagnostics?.push('poison');first.applicability.set('class','poison');first.tags?.clear();first.display.name='poison';assert.deepEqual(toTypedTree(c.get(first.id).envelope),before);assert.notEqual(c.list()[0].display.name,'poison');assert.notEqual(c.get(first.id).source.sha256,'poison');
});
test('input is bounded JSON text only, schema failure fixed and no error/source echo',()=>{
 let calls=0;for(const value of [null,{},new String(text()),{toString(){calls++;throw Error('PRIVATE');},toJSON(){calls++;throw Error('PRIVATE');}},'x'.repeat(2097153),'{bad'])assert.deepEqual(parse(value),{ok:false,reason:'invalid-bundled-catalog'});assert.equal(calls,0);assert.deepEqual(parse(text(),'{bad'),{ok:false,reason:'schema-unavailable'});
});
test('closed root/record/display fields, stable identifiers and source hash links',()=>{
 const transforms=[d=>d.extra=true,d=>d.version=2,d=>d.nativeAvailability='ready',d=>d.packs[0].extra=true,d=>d.packs[0].display.extra=true,d=>d.packs[0].id='!',d=>d.packs[0].sourceSHA='0'.repeat(64),d=>d.packs[0].sourcePath='../evil.lua',d=>d.packs[0].display.nameKey='mismatch',d=>d.packs.push(d.packs[0])];for(const change of transforms){const d=raw();change(d);reject(d);}
});
test('typed marker closure, duplicate and rounded key aliases refuse before exposure',()=>{
 const transforms=[m=>m.extra=1,m=>m.type='unknown',m=>m.entries.push(m.entries[0]),m=>m.entries.push([number(1),bytes('x')],[{type:'number',bits:'3ff0000000000000'},bytes('y')]),m=>m.entries.push([number(0),bytes('bad')]),m=>m.entries.push([bytes('future'),{type:'bytes',hex:'xyz'}]),m=>m.entries.push([bytes('future'),{type:'number',bits:'7ff0000000000000'}])];for(const change of transforms){const d=raw();change(d.packs[0].envelope);reject(d);}
});
test('typed numeric and byte keys, null and inert source payload retain exact data',()=>{
 const d=raw(),m=d.packs[0].envelope;set(m,'customPayload',{type:'table',entries:[[number(1),{type:'boolean',value:false}],[bytes('1'),bytes('raw\x00\xff <script>throw 1</script>')],[bytes('nil'),{type:'nil'}]]});const r=parse(JSON.stringify(d));assert(r.ok);const x=r.catalog.get(d.packs[0].id).envelope.get('customPayload');assert.equal(x.get(1),false);assert.equal(x.get('1'),'raw\x00\xff <script>throw 1</script>');assert.equal(x.get('nil'),null);assert.equal(globalThis.pwned,undefined);
});
test('JSON deep unchecked markers and typed depth limits fail without recursion overflow',()=>{
 const d=raw();d.packs[0].envelope.type='DEEP';reject(JSON.stringify(d).replace('"DEEP"','['.repeat(12000)+'0'+']'.repeat(12000)));
 const x=raw();let v={type:'nil'};for(let i=0;i<66;i++)v={type:'table',entries:[[bytes('x'),v]]};set(x.packs[0].envelope,'future',v);reject(x);
});
test('aggregate and per-manifest resource limits remain explicit',()=>{
 let d=raw();d.packs=Array.from({length:65},()=>d.packs[0]);reject(d);
 d=raw();set(d.packs[0].envelope,'future',{type:'bytes',hex:'78'.repeat(262145)});reject(d);
 d=raw();const many={type:'table',entries:Array.from({length:10001},(_,i)=>[number(i+1),{type:'boolean',value:false}])};set(d.packs[0].envelope,'future',many);reject(d);
});
test('future envelope schema, invalid branch and mismatched declared identity fail catalog',()=>{
 for(const mutate of [m=>set(m,'schemaVersion',number(2)),m=>set(m,'id',bytes('other')),m=>{const body=fields(m).get('body');set(body,'rotation',{type:'table',entries:[[number(1),{type:'table',entries:[[bytes('id'),bytes('bad')],[bytes('type'),bytes('branch')],[bytes('onTrue'),{type:'table',entries:[]}]]}]]});}]){const d=raw();mutate(d.packs[0].envelope);reject(d);}
});
test('provenance hashes do not pretend to authenticate arbitrary well-formed payload content',()=>{
 const d=raw(),p=d.packs.find(p=>p.id==='rm.tbc.shaman.starter'),m=p.envelope;const b=fields(m).get('body'),steps=fields(b).get('rotation');const spell=steps.entries.map(x=>x[1]).find(s=>fields(s).get('action'));set(spell,'action',number(123));const r=parse(JSON.stringify(d));assert(r.ok);assert.equal(r.catalog.get(p.id).source.sha256,p.sourceSHA);
});

test('display labels remain Unicode text while symbolic keys stay ASCII bytes',()=>{
 const d=raw();assert(d.packs.every(p=>p.display.name.includes('–')));const c=ready();for(const p of d.packs)assert.equal(c.get(p.id).display.name,p.display.name);
 d.packs[0].display.name='Localized – Δ 😀';assert.equal(parse(JSON.stringify(d)).catalog.list()[0].display.name,'Localized – Δ 😀');
 d.packs[0].display.nameKey='nonASCIIé';set(d.packs[0].envelope,'nameKey',bytes('nonASCIIé'));reject(d);
});
test('record/source maxima and UTF8 text cap are enforced independently',()=>{
 let d=raw();d.packs=[];d.sourceFiles={};for(let i=0;i<128;i++)d.sourceFiles['safe/'+i+'.lua']='0'.repeat(64);assert(parse(JSON.stringify(d)).ok);d.sourceFiles['safe/extra.lua']='0'.repeat(64);reject(d);
 const base=text();assert(parse(base+' '.repeat(2097152-Buffer.byteLength(base))).ok);reject(base+' '.repeat(2097153-Buffer.byteLength(base)));
 reject(base+' '.repeat(2097152-Buffer.byteLength(base)-2)+'éé');
 d=raw();const p=d.packs[0];d.packs=[];for(let i=0;i<64;i++){const row=structuredClone(p);row.id='test.'+i;row.sourcePath='Defaults/test/'+i+'.lua';set(row.envelope,'id',bytes(row.id));d.sourceFiles[row.sourcePath]=row.sourceSHA;d.packs.push(row);}assert(parse(JSON.stringify(d)).ok);d.packs.push(structuredClone(d.packs[0]));reject(d);
});
test('trusted producer refuses native queries, duplicate registration and invalid declarations BOTH',()=>{
 const scripts=[
  ["local _,a=...; local x=UnitLevel('player')",'unsupported pack global UnitLevel'],
  ["local _,a=...; a:RegisterDefaultRotation({id='bad'})",'invalid-envelope'],
 ];
 for(const vm of ['lua5.1','luajit']){
  for(const [script,reason] of scripts){
   const body="local original=loadfile;local replacement="+JSON.stringify(script)+";loadfile=function(path)if path=='Defaults/tbc/shaman-starter.lua'then return assert(loadstring(replacement))end;return original(path)end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find("+JSON.stringify(reason)+",1,true),tostring(why))";
   execFileSync(vm,['-e',body],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
  }
  const duplicate="local original=loadfile;local scope,set=setfenv,getfenv;loadfile=function(path)local f=original(path);if path=='Defaults/tbc/shaman-starter.lua'then return function(...)scope(f,set(1));f(...);f(...)end end;return f end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find('duplicate-default-id',1,true),tostring(why))";
  execFileSync(vm,['-e',duplicate],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
 }
});
test('fresh actual LuaJIT fixture generation stays semantically equal without wire-order claims',()=>{
 const fresh=JSON.parse(execFileSync('luajit',['tools/export_web_defaults.lua','--fixtures'],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024}));const c=ready();assert.equal(fresh.records.length,28);for(const r of fresh.records){const decoded=decodeImport(r.wire);assert(decoded.ok);assert.deepEqual(toTypedTree(decoded.value),toTypedTree(c.get(r.id).envelope));}
});

test('first26 frozen source catalog objects and ordered wire bytes stay exact; Shaman40–49 appends once',()=>{
 const wireText=readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url));const records=JSON.parse(wireText).records;
 assert.equal(records.length,28);assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,26))).digest('hex'),'0341d283dfc472ae359c32059b64be03298db8460e80adb8c60e7097ab864c60');
 assert.equal(createHash('sha256').update(wireText.subarray(0,411744)).digest('hex'),'c695c4f08e8266c5a7a46f6fd6293f2188dd1cbc33429472e5b0beb93247886d');
 assert.equal(records[26].id,'rm.tbc.shaman.enhancement.40-49');assert.equal(records.filter(r=>r.id==='rm.tbc.shaman.enhancement.40-49').length,1);
 const old=raw().packs.filter(p=>p.id!=='rm.tbc.shaman.enhancement.40-49'&&p.id!=='rm.tbc.warlock.starter.40-49');assert.equal(old.length,26);assert.equal(createHash('sha256').update(JSON.stringify(old)).digest('hex'),'d4d510e312a5a71192d6b07b6dbfda771387b7e5a3285ad630fde6871d391ab2');
 const c=ready(),newRows=indexRotationSteps(c.get('rm.tbc.shaman.enhancement.40-49').envelope.get('body')).index.rows;
 const oldIds=new Set(old.flatMap(p=>indexRotationSteps(c.get(p.id).envelope.get('body')).index.rows.map(r=>r.step.get('id'))));
 assert.equal(newRows.length,7);for(const row of newRows){assert(row.step.get('id').startsWith('shaman-enhancement40-'));assert(!oldIds.has(row.step.get('id')));}
});

test('full old27 Shaman source catalog and ordered raw-wire prefix stay exact; Warlock is appended28th',()=>{
 const wireText=readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url));const records=JSON.parse(wireText).records;
 assert.equal(records.length,28);assert.equal(createHash('sha256').update(JSON.stringify(records.slice(0,27))).digest('hex'),'c99e4787b237513f7bbf0b7e79d8a05b108202669efd866b0d8390eeb244d9db');
 assert.equal(createHash('sha256').update(wireText.subarray(0,426069)).digest('hex'),'26eeb0101c5f93fd2184b4bf18aa4e68f536aeffc694c642942252a9a1c9d152');
 assert.equal(createHash('sha256').update(wireText.subarray(426069+1,wireText.length-15)).digest('hex'),'4ab72b56806c794fce7c9dd2de63e945ce4b526e00f6cf9eca74ac63e60b1930');
 assert.equal(records[26].id,'rm.tbc.shaman.enhancement.40-49');assert.equal(records[27].id,'rm.tbc.warlock.starter.40-49');assert.equal(records.filter(r=>r.id==='rm.tbc.warlock.starter.40-49').length,1);
 const old=raw().packs.filter(p=>p.id!=='rm.tbc.warlock.starter.40-49');assert.equal(old.length,27);assert.equal(createHash('sha256').update(JSON.stringify(old)).digest('hex'),'195f8f35127c7f3a76173893728118faf2486da9558ed4c90bdcab300b1ef401');
 for(const p of old)assert.equal(createHash('sha256').update(readFileSync(new URL('../'+p.sourcePath,import.meta.url))).digest('hex'),p.sourceSHA,p.sourcePath);
 const c=ready(),newRows=indexRotationSteps(c.get('rm.tbc.warlock.starter.40-49').envelope.get('body')).index.rows;
 const oldIds=new Set(old.flatMap(p=>indexRotationSteps(c.get(p.id).envelope.get('body')).index.rows.map(r=>r.step.get('id'))));
 assert.equal(newRows.length,14);for(const row of newRows){assert(row.step.get('id').startsWith('warlock-forties-'));assert(!oldIds.has(row.step.get('id')));}
});
