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
// The packaged premades of both editions (TBC Anniversary and WoW Forever),
// frozen in catalog order: [id, step rows, sha256 of JSON.stringify([catalog
// pack object, wire fixture record])]. Re-freeze only alongside a deliberate
// pack change (regenerate with the repo's generators). The wire half pins the
// committed fixture bytes: the codec serialises in pairs() order, which LuaJIT
// varies run to run, so a fresh --fixtures run differs byte-wise while staying
// semantically equal (see the last test). Never regenerate it to go green.
const PREMADES=[
 ["rm.forever.druid.balance",28,"82d199c81704b8194267c53e8d0af94bdd3f9080a9b2d851ed1b8290a7c29236"],
 ["rm.forever.druid.balance.tavern",14,"269c3c3d54c3f799b24d54cd07557598ae2ca1fe8f7d90f5473fe3ea01ef6f97"],
 ["rm.forever.druid.feral",44,"cd318c34caecf6af1f7b1bd71b022bbb6bc592eba0ff1c51660ba2538d5bb54a"],
 ["rm.forever.druid.restoration",23,"3733772f06dc755ab9eb9ac59b30cd485f6b2ce35861cc8952f75adb4cba02c1"],
 ["rm.forever.druid.restoration.icyveins",23,"3b61dbe2fb1aae5ceda254fab5881ef53b96d87b32ac32aaebab7839a4be5528"],
 ["rm.forever.hunter.ranged",45,"6e25c6fba51a641bcd4429e807b86a630996335b71591973d9d0b83f379a0320"],
 ["rm.forever.hunter.ranged.mobalytics",40,"68ed2150118894e727d001e07352408bd101d7c3cee267aa9329ea5d94924ae6"],
 ["rm.forever.hunter.survival",30,"f56296fdca8ec83a7dc9a70d057478b8a423efe52698adda5d1655006b995d28"],
 ["rm.forever.hunter.survival.weave",31,"4fba977da168a5c10be7755e7225f4cb5f61bb262c67aa47412290b87f000271"],
 ["rm.forever.mage.arcane",38,"923cd39e494823679f3980220ac01ebbb0358bd0bb3ab66aebbb7f8c68ac169d"],
 ["rm.forever.mage.fire",40,"a0ee4ccde50bd83961dd16aa700aee53f8b0057d1e2915ecfb223a876c980564"],
 ["rm.forever.mage.fire.icyveins",32,"3336cf71199576fada1c8f794ae15736afd1e78ca6d0dbaba48ff6d2a339fd6b"],
 ["rm.forever.mage.frost",42,"ced45b04922e61b79ed7ce9a0c449fe2f5b2299c07ca7e4abf4a68195e66fb22"],
 ["rm.forever.paladin.holy",28,"15a4cda96f60ceeae1390772f733462bcb0ba81738c03371bd7f94cae7c8c134"],
 ["rm.forever.paladin.holy.wowhead",26,"d473dd314d3f517bf4fc0c6f353a740e181a97507026ba8b7283119bd56bbe32"],
 ["rm.forever.paladin.protection",24,"e92877a7b106f3a22a22bff5b5a6b581849bde08e81c5dff17ea098797d42efc"],
 ["rm.forever.paladin.protection.icyveins",18,"a7ec9802b84939cd6af3821569e99abd2db7c3d9991e4e420bd06f68c9949590"],
 ["rm.forever.paladin.retribution",30,"dce2f7a999106c720ab83188a540ba6fea63f7e7dd1db073a0937b2299e7f2b7"],
 ["rm.forever.priest.dps",60,"8cacf895030f01cffda8080e0c98b53746c6c7f0b113483f9870ec1d3c18a356"],
 ["rm.forever.priest.dps.mobalytics",44,"008d8927b35f499c17a35fa9cf363759893747c111d51f5e50aea4e0d390ff09"],
 ["rm.forever.priest.healer",45,"a9c243301da3d77ef726d318b53722f77f915bf9f2e7bd9b9ffb52ad1ae317a5"],
 ["rm.forever.rogue.dps",39,"56bbe1baa81cf31e3055dad36a51baf0ba73022311f655f9f0011d1adeab5c34"],
 ["rm.forever.rogue.subtlety.warcrafttavern",30,"6ff992b67b2534290e36af1636d364aed2212dd7c5438d786995af13da3a0597"],
 ["rm.forever.rogue.subtlety.wowhead",29,"0544b5082231c1de784bc3aa754ee4f50714fc288e49e90f139b9e2488cc8018"],
 ["rm.forever.shaman.elemental",35,"9ca03905864f603b0fc40ec89df8069d2427cf02cf5fff7870d38dae3ddef77e"],
 ["rm.forever.shaman.enhancement",30,"29ccffe0b078542b527a7cfde982f3a80669cddad2d6f8499497681a0b59efd8"],
 ["rm.forever.shaman.enhancement.wowhead",17,"6d8ffb3e4c8b83cbaa4129be06272cbb03f0c56bf805622a2c1e4932999817d8"],
 ["rm.forever.shaman.restoration",27,"8d2a5ccb00f38336704ad83d26fa6d0202f65e9dc35bb5b1f7ecad9c8412f656"],
 ["rm.forever.warlock.dps",64,"312ea5afe2c6be5eaa1196ecefbe6ec9039b2cbf6eca2338409f8d1223471fa8"],
 ["rm.forever.warlock.dps.icyveins",67,"1bd65f022eef67a3421156cc6c08eb7444bcd97c2b5fc6badacdf1addccdb305"],
 ["rm.forever.warlock.dps.wowhead",57,"1c1383025f69d422bf87d48b956bb00c1849e99693bbfeb95f2b8e5549c9c479"],
 ["rm.forever.warrior.dps",36,"1dc8323edaac4d051232164d79fcc662648ec232ebdd1dee327576939ea22ee8"],
 ["rm.forever.warrior.dps.warcrafttavern",23,"f4f782d69ca4d32ec3f04696d596254cd4be11f1ee07885ab42584eccc6c1b93"],
 ["rm.forever.warrior.protection",31,"328f45b7033a7e3456ae62db3041120864cef55913f639abb55e6218aad91447"],
 ["rm.forever.warrior.protection.warcrafttavern",17,"65686714c34a025b4c98eaf3712de370400291579d67dd593230dbae32d2cf4c"],
 ["rm.tbc.druid.balance",25,"f0cab5f33cf43074f0de8e71791b3c2a17a214d708b1b80a729c89b6d978d99e"],
 ["rm.tbc.druid.feral.icyveins",44,"ab0283ceb39b22444bcea6bf702d0decfb835e80c462b7d9c28d092ca6d34358"],
 ["rm.tbc.druid.feral.wowhead",44,"4ae0d9b6b2d518effa935e4d2ec2b6cc7a70557e87c587c864b6ded2476d748d"],
 ["rm.tbc.druid.restoration",25,"ad128c156db745480b7af3c35ac7bb1a4afa10a01304bf8c5f5f2f6ec2818fc1"],
 ["rm.tbc.hunter.ranged.wowhead",40,"a6bd23d666fb25ea4a7c2b467674d2f8f21fdc2be517ed85e9e2dfe961a4c53f"],
 ["rm.tbc.hunter.ranged.wowsims",44,"5afd89e012d507fbee9edf6c98858beae98da6503729df7cc2ec1ceced99355c"],
 ["rm.tbc.mage.arcane",43,"71eae3d52041ef0a4d31ae6a4f88543f019f3cd88452f5b4a3868aac064fd44e"],
 ["rm.tbc.mage.fire.icyveins",39,"180ee9dc887926103f31015349f4a6722f751e25730f5275ab93f368be7acbfb"],
 ["rm.tbc.mage.fire.wowhead",39,"6cad49a8f643290a6e439040108a0837c1b77e86ad50a56f1ce02843d6e14da3"],
 ["rm.tbc.mage.frost",43,"a6575805aa0791e82d78174f7fb01017d06611f669b25b47409a25bedc379ea2"],
 ["rm.tbc.paladin.holy",19,"9002603eae9f3e625710ca09a70d5213a280baf953bbb49d9f62b86488aef293"],
 ["rm.tbc.paladin.holy.wowhead",18,"1b39b48e02bd86cd667d0fc4b0faaff4918f4347a851249f0505c4c99efc8951"],
 ["rm.tbc.paladin.protection.icyveins",19,"1032ba05944c47b98aa44c339d09977e9591e9dd2469151269b16cb40f670bf0"],
 ["rm.tbc.paladin.protection.wowhead",26,"1dd8cd7b999716034bcb81a71e2e76c5e980482d8bf5d8808987ba97c12120f4"],
 ["rm.tbc.paladin.retribution.icyveins",24,"985f2b17dafe96c158c1f5e29b0ff9145b5f17d05dd52f772aed29100da3bad5"],
 ["rm.tbc.paladin.retribution.twist",32,"6f0c7a429b29b9ceebc7e626ab20b04e15db58689cf9b2efc965d66446233f8b"],
 ["rm.tbc.paladin.retribution.wowhead",23,"9aedf36bca6e3f4d94e5ffa5f76dbb3424817809f899388a3e88a0969326985c"],
 ["rm.tbc.priest.dps.icyveins",49,"6f71e9b0bb3f697f632adb615922789b3f7ab95b361e276b02825991759e8c4d"],
 ["rm.tbc.priest.dps.wowhead",46,"4f904e6bdf455274660388d469a70db2331c6c030f878ddcc658f7362e090f1a"],
 ["rm.tbc.priest.healer.icyveins",35,"46abf9e72c3e058c167693f8f0d678f65bb046d6fe364187df675a1931388dda"],
 ["rm.tbc.priest.healer.wowhead",40,"0ee38dc83fc47eb8a445276f7ed8e4b09c7f1856567af4355b63795cc7fb59b5"],
 ["rm.tbc.rogue.dps.wowhead",30,"f77a7ae63003f21cc0504c22a9053bc1db9d9dc053f622b2ebe971fba79b02b6"],
 ["rm.tbc.rogue.dps.wowsims",32,"0d62ae6818fd28760fcec6aee54a1acedfa296eb24fa975110bd969733e7c0f0"],
 ["rm.tbc.shaman.elemental.icyveins",26,"629e60d03bfb1f74c9474f41c30fdeede41ce6b5499e9b5d8f08f918df8ca4ad"],
 ["rm.tbc.shaman.elemental.nextaction",14,"927048b11b4b8885f6144932713e8dc3709321c8fe698a82ea48d1f0cf3f1a94"],
 ["rm.tbc.shaman.elemental.wowhead",26,"3e42e53ae9aa4f1d742dcaa04ae1103b72d26897717475a54dc9eb22e75cd85f"],
 ["rm.tbc.shaman.enhancement.icyveins",31,"c2516f66441aa58372fba97ffb14f7b92df2576d800171925e4b65ccca0c1583"],
 ["rm.tbc.shaman.enhancement.wowsims",31,"06546a276d6c07bf6cd9699055366d0288d75117762f07fd28f233631e48918d"],
 ["rm.tbc.shaman.restoration",24,"0ced684f68fe0d1d55f7259a04582c3f5e6160287c46b3588d938f60f1c4b319"],
 ["rm.tbc.warlock.dps.icyveins",59,"9582ddb418c75facc9aff6808535fb6256c7690d083db843c835449b3865ed03"],
 ["rm.tbc.warlock.dps.wowhead",56,"6b38a3811491c9a984153c03b69e243c5cfa130b126540e3c891579099d9a6b2"],
 ["rm.tbc.warrior.dps.icyveins",32,"4fa7a2f37b5cac0dab6450f2e2a66757f855e869479b6ea1737001b51fe99191"],
 ["rm.tbc.warrior.dps.wowsims",34,"0776c84f2c3f6e5d09d7d78d2f629b0714b2bb6bd6d8b4d7b78f19c60fa69311"],
 ["rm.tbc.warrior.protection.icyveins",22,"72d3712468e27004e4509ea1d0cfbfa7188c317bcf20cc78a825bccda6453560"],
 ["rm.tbc.warrior.protection.wowhead",24,"ecc28a243085e695456ab6f855006f1147988a6c4ef21700589cd3aebebb5740"]
];
const FAMILIES=['forever','tbc'];
const FIXTURE_SHA='a3491db189f116cf0e37b9ee35d838cee4a19ec700c496a6b4c297a0e4a0b4b0';

test('pure catalog exposes every actual source definition without runtime facts',()=>{
 const c=ready(),rows=c.list(),n=raw().packs.length;assert(n>0);assert.equal(rows.length,n);assert.equal(new Set(rows.map(r=>r.id)).size,n);
 const editions=new Map(FAMILIES.map(f=>[f,0]));
 for(const row of rows){const families=row.applicability.get('families');assert.equal(families.size,1,row.id);const family=families.get(1);assert(editions.has(family),row.id+' family '+family);assert(row.id.startsWith('rm.'+family+'.'),row.id);editions.set(family,editions.get(family)+1);assert.equal(row.validation.nativeAvailability,'unverified');for(const k of ['eligible','enabled','runtimeKey','spellName','icon'])assert.equal(Object.hasOwn(row,k),false);const value=c.get(row.id);assert(value.ok&&checkPortable(value.envelope).ok);const report=validateEnvelope(value.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);assert(indexRotationSteps(value.envelope.get('body')).ok);}
 for(const[family,count]of editions)assert(count>0,'no '+family+' premades');
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
// Pack-level body.disabled, re-derived over both editions: only the TBC
// seal-twisting premade is off by default. Many packs of both editions carry
// disabled STEPS (situational rows), but none is disabled as a whole.
test('the seal-twisting premade ships present, valid and marked disabled; no other pack of either edition is',()=>{
 const c=ready(),id='rm.tbc.paladin.retribution.twist';assert(c.list().some(r=>r.id===id));
 const twist=c.get(id);assert(twist.ok);assert.equal(twist.envelope.get('body').get('disabled'),true);
 const report=validateEnvelope(twist.envelope,declarations);assert(report.valid&&report.supported&&report.resolved);
 assert.deepEqual(c.list().filter(r=>!r.id.startsWith('rm.retail.')&&c.get(r.id).envelope.get('body').get('disabled')!==undefined).map(r=>r.id),[id]);
});
test('get/list outputs never expose private manifest, facets or declaration state',()=>{
 const c=ready(),first=c.list()[0],before=toTypedTree(c.get(first.id).envelope),one=c.get(first.id);one.envelope.get('body').get('rotation').clear();one.envelope.get('sources').get(1).set('url','poison');one.display.name='poison';one.source.sha256='poison';one.validation.diagnostics?.push('poison');first.applicability.set('class','poison');first.tags?.clear();first.display.name='poison';assert.deepEqual(toTypedTree(c.get(first.id).envelope),before);assert.notEqual(c.list()[0].display.name,'poison');assert.notEqual(c.get(first.id).source.sha256,'poison');
});
test('input is bounded JSON text only, schema failure fixed and no error/source echo',()=>{
 let calls=0;for(const value of [null,{},new String(text()),{toString(){calls++;throw Error('PRIVATE');},toJSON(){calls++;throw Error('PRIVATE');}},'x'.repeat(8388609),'{bad'])assert.deepEqual(parse(value),{ok:false,reason:'invalid-bundled-catalog'});assert.equal(calls,0);assert.deepEqual(parse(text(),'{bad'),{ok:false,reason:'schema-unavailable'});
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
 let d=raw();d.packs=Array.from({length:257},()=>d.packs[0]);reject(d);
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
 let d=raw();d.packs=[];d.sourceFiles={};for(let i=0;i<512;i++)d.sourceFiles['safe/'+i+'.lua']='0'.repeat(64);assert(parse(JSON.stringify(d)).ok);d.sourceFiles['safe/extra.lua']='0'.repeat(64);reject(d);
 const base=text();assert(parse(base+' '.repeat(8388608-Buffer.byteLength(base))).ok);reject(base+' '.repeat(8388609-Buffer.byteLength(base)));
 reject(base+' '.repeat(8388608-Buffer.byteLength(base)-2)+'éé');
 d=raw();const p=[...d.packs].sort((a,b)=>JSON.stringify(a).length-JSON.stringify(b).length)[0];d.packs=[];// smallest pack, so 257 copies stay under the text cap
 for(let i=0;i<256;i++){const row=structuredClone(p);row.id='test.'+i;row.sourcePath='Defaults/test/'+i+'.lua';set(row.envelope,'id',bytes(row.id));d.sourceFiles[row.sourcePath]=row.sourceSHA;d.packs.push(row);}assert(parse(JSON.stringify(d)).ok);d.packs.push(structuredClone(d.packs[0]));reject(d);
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
