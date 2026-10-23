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

const fixtureURL=new URL('./fixtures/web_defaults.json',import.meta.url);
const SAMPLE='rm.tbc.shaman.enhancement.icyveins',SAMPLE_SOURCE='Defaults/tbc/shaman-enhancement-icyveins.lua';
// The packaged TBC premades, frozen in catalog order: [id, step rows, sha256 of
// JSON.stringify([catalog pack object, wire fixture record])]. Re-freeze only
// alongside a deliberate pack change (regenerate with the repo's generators).
const PREMADES=[
 ["rm.tbc.druid.balance",25,"10d3133bbb058af6724f873aaa9e4864c7b26248d23c278a029d1a4a53bba2e7"],
 ["rm.tbc.druid.feral.icyveins",44,"c79e6adf2afc6b3649fcb0b5eec6b0afeee09506f6a52448e78b1a23c5d6db5f"],
 ["rm.tbc.druid.feral.wowhead",44,"5ca9e2bfbf6a74abcdace1f9dfd15674c969b9a272cfaffbbf3849a56752be9a"],
 ["rm.tbc.druid.restoration",25,"b1b83879fa072b561ee04aeda6890e68f27132eaba7cb8a742c8995ba4a1ecbb"],
 ["rm.tbc.hunter.ranged.wowhead",40,"dda47ba4133992a21d5a59cc9034ceee28f8428ce4002214c5dde6726c1d16c0"],
 ["rm.tbc.hunter.ranged.wowsims",44,"da5a1e26f97f4f03d286e4825a78aad34705251e6a0f9a515fa353ee07e059b0"],
 ["rm.tbc.mage.arcane",43,"beaad6ca57c405fa6c5e30591c985f5e8a0682bc793be2e57a472ead18782265"],
 ["rm.tbc.mage.fire.icyveins",39,"b98f582fd7b63d86ecc6725fa17bca35c2bfe32dacc8f6b1b333a04e6a5cae1d"],
 ["rm.tbc.mage.fire.wowhead",39,"1ac870f13e55931b12bfa5e872ed40bea524b77e4c1a3c05ba6973dfc1f152b6"],
 ["rm.tbc.mage.frost",43,"c42c29085f0924709375f0d33ca3748036af52603f2254ee69e33ea1be9e842c"],
 ["rm.tbc.paladin.holy",19,"6bc57a13df5ca3c7e60c7145fc1e28386b9de20de4b1191015e2af7b1c2b79b9"],
 ["rm.tbc.paladin.holy.wowhead",18,"022945aa195dbcfc3e8d412c28d890d32b097014ad5f4f37bf3f74507b70c59c"],
 ["rm.tbc.paladin.protection.icyveins",19,"1e48eee44b57cb21cc545a263a41840852f22c2bc60d29e730f116f2ada0e6c9"],
 ["rm.tbc.paladin.protection.wowhead",26,"3d3453b893b56a7e1574baf0fbbe980bb32c7fdac5917ee0ba63d32540d29de7"],
 ["rm.tbc.paladin.retribution.icyveins",24,"1d958d9809b3ec9ca77570eafb6b71e19f53089d3a13b0f49415dfec3f5c33a8"],
 ["rm.tbc.paladin.retribution.twist",32,"9e226d3da1b8431819b9d4a4f568328883b2645316fa333b18e0318c56576117"],
 ["rm.tbc.paladin.retribution.wowhead",23,"4d0f08d329c698fc3ca62b796036c8c89925e93cd5911ab4b137b7c9311554f0"],
 ["rm.tbc.priest.dps.icyveins",49,"25093b17d087d63dd71b5f55b8f48b1b78b4f1951bcb7fd4b074cb9927bbd786"],
 ["rm.tbc.priest.dps.wowhead",46,"c79f84ec260382dbb18182f2cb5323f2a190944a8d56fae2a9c18c4ba08400c3"],
 ["rm.tbc.priest.healer.icyveins",35,"2160cae6052c61adbbd9a0ff15f5ca0d69e9e8a40fb40ef6cf8d9a3b8f489d09"],
 ["rm.tbc.priest.healer.wowhead",40,"00e775b25353342e26783d263d84c1d6ccf5ed07443b0518cca82a52a5fb7037"],
 ["rm.tbc.rogue.dps.wowhead",30,"760ab0e552a9feed87063b49f4f3210523013d214f3b6d221fa2b856179d0675"],
 ["rm.tbc.rogue.dps.wowsims",32,"90e4b26ff83a5a106e17413f9b33fa1d2703c1b3d58d0413553e65b40401718f"],
 ["rm.tbc.shaman.elemental.icyveins",26,"87c617b685bcca315588bc19e1926587f0800532af5ae89b3e5fc3830e5da245"],
 ["rm.tbc.shaman.elemental.nextaction",14,"56505b4e716fdf5e7a1900efbc34f3028c8c8b3cc67588509f5312bbe1f99219"],
 ["rm.tbc.shaman.elemental.wowhead",26,"6140d8bdc05d824f229ac6bdc5f10c9e829b4fca8bff5c0b26520672f4e0c354"],
 ["rm.tbc.shaman.enhancement.icyveins",31,"a611b33512966ea3807de2cfd8aeb88fff666322092b0858e2d0640f3aaa6e14"],
 ["rm.tbc.shaman.enhancement.wowsims",31,"f3eefe96d5dce8ecda3a06ba779fccce11f4ce62a3c064a88cd628dc231bd537"],
 ["rm.tbc.shaman.restoration",24,"cd82c2d34018a6d38d3514a67fb6933c1943bac22326d246ad6a0ff7889b1f08"],
 ["rm.tbc.warlock.dps.icyveins",59,"41f5d2633c4b5c0aac8ac9c0d2ff082b33bfe42dfa46fbe3de2441bb92975b2f"],
 ["rm.tbc.warlock.dps.wowhead",56,"a6b4eca9e7351f004b84e91dae470e5e61889e55d331d0555e72d9b229a7a858"],
 ["rm.tbc.warrior.dps.icyveins",32,"7d4c45ffd92fa57b80f3820d753ac5a9cd3fad5118da2415931e16ab6a58afc5"],
 ["rm.tbc.warrior.dps.wowsims",34,"1e5ec85c8adfcb7e8e754621c1528255e2b92640186e1b32d60a03955ad9e596"],
 ["rm.tbc.warrior.protection.icyveins",22,"fdd63be26fb52c2bc5a3fc8c570900a1fc5fec0e54601f2de7914a6fc7a40a03"],
 ["rm.tbc.warrior.protection.wowhead",24,"55e3c8ba747b41316ead9eec0cffcde3f35794ccc772928790333cd25ed5275c"]
];
const FIXTURE_SHA='ec6d21ae8dfc03af2000d6641c5762d7ebaf80e2c6ca24f05f644e3c6bee9532';

test('pure catalog exposes every actual source definition without runtime facts',()=>{
 const c=ready(),rows=c.list(),n=raw().packs.length;assert(n>0);assert.equal(rows.length,n);assert.equal(new Set(rows.map(r=>r.id)).size,n);
 for(const row of rows){assert.equal(row.applicability.get('families').get(1),'tbc');assert.equal(row.validation.nativeAvailability,'unverified');for(const k of ['eligible','enabled','runtimeKey','spellName','icon'])assert.equal(Object.hasOwn(row,k),false);const value=c.get(row.id);assert(value.ok&&checkPortable(value.envelope).ok);const report=validateEnvelope(value.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);assert(indexRotationSteps(value.envelope.get('body')).ok);}
 assert.deepEqual(c.get({toString(){throw Error('no coercion');}}),{ok:false,reason:'unknown-default'});
});
test('production generator is deterministic/current BOTH and source inputs exact',()=>{
 const expected=text();for(const vm of ['lua5.1','luajit'])for(let i=0;i<2;i++)assert.equal(execFileSync(vm,['tools/export_web_defaults.lua'],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024}),expected);
 const doc=raw();for(const[path,sha]of Object.entries(doc.sourceFiles))assert.equal(createHash('sha256').update(readFileSync(new URL('../'+path,import.meta.url))).digest('hex'),sha,path);
 const toc=readFileSync(new URL('../RotationMaster.toc',import.meta.url),'utf8').split(/\r?\n/).filter(s=>/^Defaults\/.+\.lua$/.test(s)&&!s.startsWith('Defaults/blocks/'));assert.deepEqual([...doc.packs.map(p=>p.sourcePath)].sort(),toc.sort());
});
test('every catalog pack has one pinned actual codec wire decoding to its exact Map with strict diff equality',()=>{
 const fixture=JSON.parse(readFileSync(fixtureURL)),c=ready();assert.equal(fixture.format,'RotationMasterBundledDefaultWireFixtures');assert.deepEqual(fixture.records.map(r=>r.id),c.list().map(r=>r.id));
 let rows=0,expected=0;for(const row of c.list())expected+=indexRotationSteps(c.get(row.id).envelope.get('body')).index.rows.length;for(const record of fixture.records){const decoded=decodeImport(record.wire);assert(decoded.ok&&decoded.kind==='envelope');const selected=c.get(record.id);assert(selected.ok);assert.deepEqual(toTypedTree(decoded.value),record.expected);assert.deepEqual(toTypedTree(selected.envelope),record.expected);assert.equal(selected.source.sha256,record.sourceSHA);rows+=indexRotationSteps(decoded.value.get('body')).index.rows.length;const diff=diffRotations(decoded.value,selected.envelope);assert(diff.valid&&diff.complete&&diff.changes.length===0);}assert(rows>0);assert.equal(rows,expected);
});
test('packaged premades are frozen: ordered ids, catalog objects, wire records and raw fixture bytes',()=>{
 const wire=readFileSync(fixtureURL),records=JSON.parse(wire).records,packs=raw().packs,c=ready();
 assert.deepEqual(packs.map(p=>p.id),PREMADES.map(([id])=>id));assert.deepEqual(records.map(r=>r.id),PREMADES.map(([id])=>id));
 const changed=PREMADES.filter(([id,rows,sha],i)=>indexRotationSteps(c.get(id).envelope.get('body')).index.rows.length!==rows||createHash('sha256').update(JSON.stringify([packs[i],records[i]])).digest('hex')!==sha).map(([id])=>id);
 assert.deepEqual(changed,[]);
 assert.equal(createHash('sha256').update(wire).digest('hex'),FIXTURE_SHA);
});
test('the retired level-bracket packs are gone from the catalog, wires and source list',()=>{
 const doc=raw(),records=JSON.parse(readFileSync(fixtureURL)).records,bracket=/\.starter(\.|$)|\.\d+-\d+$/;
 for(const id of [...doc.packs.map(p=>p.id),...records.map(r=>r.id)])assert(!bracket.test(id),id);
 for(const path of Object.keys(doc.sourceFiles))assert(!/starter/.test(path),path);
 for(const id of ['rm.tbc.shaman.starter','rm.tbc.warlock.starter.40-49','rm.tbc.priest.shadow.50-59'])assert.deepEqual(ready().get(id),{ok:false,reason:'unknown-default'});
});
test('the seal-twisting premade ships present, valid and marked disabled; no other pack is',()=>{
 const c=ready(),id='rm.tbc.paladin.retribution.twist';assert(c.list().some(r=>r.id===id));
 const twist=c.get(id);assert(twist.ok);assert.equal(twist.envelope.get('body').get('disabled'),true);
 const report=validateEnvelope(twist.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);
 assert.deepEqual(c.list().filter(r=>c.get(r.id).envelope.get('body').get('disabled')!==undefined).map(r=>r.id),[id]);
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
 const d=raw(),p=d.packs.find(p=>p.id===SAMPLE),m=p.envelope;const b=fields(m).get('body'),steps=fields(b).get('rotation');const spell=steps.entries.map(x=>x[1]).find(s=>fields(s).get('action'));set(spell,'action',number(123));const r=parse(JSON.stringify(d));assert(r.ok);assert.equal(r.catalog.get(p.id).source.sha256,p.sourceSHA);
});
test('display labels remain Unicode text while symbolic keys stay ASCII bytes',()=>{
 const d=raw();assert(d.packs.some(p=>/[^\x00-\x7f]/.test(p.display.name+p.display.description)),'some packaged display text is non-ASCII');const c=ready();for(const p of d.packs){assert.equal(c.get(p.id).display.name,p.display.name);assert.equal(c.get(p.id).display.description,p.display.description);}
 d.packs[0].display.name='Localized – Δ 😀';assert.equal(parse(JSON.stringify(d)).catalog.list()[0].display.name,'Localized – Δ 😀');
 d.packs[0].display.nameKey='nonASCIIé';set(d.packs[0].envelope,'nameKey',bytes('nonASCIIé'));reject(d);
});
test('record/source maxima and UTF8 text cap are enforced independently',()=>{
 let d=raw();d.packs=[];d.sourceFiles={};for(let i=0;i<128;i++)d.sourceFiles['safe/'+i+'.lua']='0'.repeat(64);assert(parse(JSON.stringify(d)).ok);d.sourceFiles['safe/extra.lua']='0'.repeat(64);reject(d);
 const base=text();assert(parse(base+' '.repeat(2097152-Buffer.byteLength(base))).ok);reject(base+' '.repeat(2097153-Buffer.byteLength(base)));
 reject(base+' '.repeat(2097152-Buffer.byteLength(base)-2)+'éé');
 d=raw();const p=[...d.packs].sort((a,b)=>JSON.stringify(a).length-JSON.stringify(b).length)[0];d.packs=[];// smallest pack, so 65 copies stay under the text cap
 for(let i=0;i<64;i++){const row=structuredClone(p);row.id='test.'+i;row.sourcePath='Defaults/test/'+i+'.lua';set(row.envelope,'id',bytes(row.id));d.sourceFiles[row.sourcePath]=row.sourceSHA;d.packs.push(row);}assert(parse(JSON.stringify(d)).ok);d.packs.push(structuredClone(d.packs[0]));reject(d);
});
test('trusted producer refuses native queries, duplicate registration and invalid declarations BOTH',()=>{
 const scripts=[
  ["local _,a=...; local x=UnitLevel('player')",'unsupported pack global UnitLevel'],
  ["local _,a=...; a:RegisterDefaultRotation({id='bad'})",'invalid-envelope'],
 ];
 for(const vm of ['lua5.1','luajit']){
  for(const [script,reason] of scripts){
   const body="local original=loadfile;local replacement="+JSON.stringify(script)+";loadfile=function(path)if path=='"+SAMPLE_SOURCE+"'then return assert(loadstring(replacement))end;return original(path)end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find("+JSON.stringify(reason)+",1,true),tostring(why))";
   execFileSync(vm,['-e',body],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
  }
  const duplicate="local original=loadfile;local scope,set=setfenv,getfenv;loadfile=function(path)local f=original(path);if path=='"+SAMPLE_SOURCE+"'then return function(...)scope(f,set(1));f(...);f(...)end end;return f end;local m=dofile('tools/export_web_defaults.lua');local ok,why=pcall(m.build);assert(not ok and tostring(why):find('duplicate-default-id',1,true),tostring(why))";
  execFileSync(vm,['-e',duplicate],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
 }
});
test('fresh actual LuaJIT fixture generation stays semantically equal without wire-order claims',()=>{
 const fresh=JSON.parse(execFileSync('luajit',['tools/export_web_defaults.lua','--fixtures'],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024}));const c=ready();assert.deepEqual(fresh.records.map(r=>r.id),c.list().map(r=>r.id));for(const r of fresh.records){const decoded=decodeImport(r.wire);assert(decoded.ok);assert.deepEqual(toTypedTree(decoded.value),toTypedTree(c.get(r.id).envelope));}
});
