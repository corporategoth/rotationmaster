import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {decodeImport} from '../Web/codec/import.mjs';
import {toTypedTree} from '../Web/codec/lua-data.mjs';
const load=path=>import(path).catch(e=>{if(e.code==='ERR_MODULE_NOT_FOUND')return {};throw e;});
const model=await load('../Web/viewer/model.mjs');
const render=await load('../Web/viewer/render.mjs');
const app=await load('../Web/viewer/app.mjs');
const golden=JSON.parse(readFileSync(new URL('./fixtures/web_codec.json',import.meta.url))).goldens;
const wire=golden[0].text;
const map=entries=>new Map(entries);
// Viewer seam fixtures are synthetic presentation controls, never schema parity.
const analyzed=()=>({validation:{valid:true,supported:true,resolved:false,semanticStatus:'not-evaluated',qualityStatus:'unreviewed',executionStatus:'unchecked',diagnostics:[]},body:map([['rotation',map([])],['cooldowns',map([])]]),index:{rows:[]}});
function session(services={}){assert.equal(typeof model.createViewerSession,'function','viewer session is missing');return model.createViewerSession(services);}

test('actual legacy and envelope codec goldens retain exact original text without claiming structure',()=>{
 for(const fixture of golden){const s=session();s.edit(' \n'+fixture.text+'\t');const view=s.decode();assert.equal(view.decode.ok,true,fixture.id);assert.equal(s.original(),' \n'+fixture.text+'\t');assert.deepEqual(toTypedTree(view.decode.value),toTypedTree(decodeImport(fixture.text).value));assert.equal(view.analysis,null);assert.match(view.structureMessage,/not connected/);}
});
test('edit, failure and clear retire accepted export and result',()=>{
 const s=session();s.edit(wire);s.decode();assert.equal(s.original(),wire);s.edit('RM9:bad');assert.equal(s.original(),null);assert.equal(s.view(),null);assert.equal(s.decode().decode.reason,'unsupported-transport-version');assert.equal(s.original(),null);s.clear();assert.equal(s.view(),null);assert.equal(s.input(),'');
});
test('oversized input refuses without truncating or retaining an accepted result',()=>{
 const s=session();s.edit('x'.repeat(2097153));assert.equal(s.input(),'');assert.equal(s.decode().decode.reason,'import-size-limit');assert.equal(s.original(),null);
});
test('analyzer is called only after actual decode, results do not replace original Map or export',()=>{
 let calls=0,seen;const s=session({analyze(value){calls++;seen=value;return analyzed();}});s.edit('bad');s.decode();assert.equal(calls,0);s.edit(wire);const v=s.decode();assert.equal(calls,1);assert.equal(seen,v.decode);assert.equal(s.original(),wire);assert.equal(v.analysis.validation.resolved,false);
});
test('analyzer errors and malformed result show unavailable structure without swallowing transport',()=>{
 for(const analyze of [()=>{throw new Error('PRIVATE MARKER');},()=>({validation:{valid:true}})]){const s=session({analyze});s.edit(wire);const v=s.decode();assert.equal(v.decode.ok,true);assert.equal(v.analysis,null);assert.match(v.structureMessage,/unavailable/);assert(!JSON.stringify(v.structureMessage).includes('PRIVATE'));assert.equal(s.original(),wire);}
});
test('reentrant analyze edit cannot publish stale accepted state',()=>{
 let s;s=session({analyze(){s.edit('newer');return analyzed();}});s.edit(wire);assert.equal(s.decode(),null);assert.equal(s.view(),null);assert.equal(s.original(),null);assert.equal(s.input(),'newer');
});
test('byte formatting preserves invalid UTF8, controls, bidi, offsets and literal HTML',()=>{
 assert.equal(typeof model.formatBytes,'function');assert.equal(model.formatBytes('caf\xc3\xa9').text,'café');assert.equal(model.formatBytes('\xff\x00').text,'\\xFF\\x00');assert.equal(model.formatBytes('a\xe2\x80\xaeb').text,'a\\u{202E}b');assert.equal(model.formatBytes('<img src=x>').text,'<img src=x>');const v=model.formatBytes('abcdef',{offset:2,limit:2});assert.equal(v.text,'cd');assert.equal(v.remaining,2);
});
test('UTF-8 C1 controls are visibly escaped without changing byte input',()=>{
 for(let n=0x80;n<=0x9F;n++){const bytes='\xc2'+String.fromCharCode(n),before=bytes;assert.equal(model.formatBytes(bytes).text,'\\x'+n.toString(16).toUpperCase());assert.equal(bytes,before);}
});
test('raw inspection distinguishes numeric and byte keys and never renumbers holes',()=>{
 assert.equal(typeof model.rawEntries,'function');const value=map([[3,'third'],['3','string'],['__proto__',false]]);const before=toTypedTree(value);const rows=model.rawEntries(value);assert.deepEqual(rows.map(x=>x.path),[[3],['3'],['__proto__']]);assert.deepEqual(toTypedTree(value),before);
});
// Minimal DOM boundary host. Browser paint/selection/accessibility acceptance is separate.
class Element{
 constructor(tag,doc){this.tagName=tag;this.doc=doc;this.children=[];this.attributes={};this.listeners={};this.value='';this.disabled=false;this.hidden=false;this.parentNode=null;this.ownText='';}
 append(...nodes){for(const node of nodes){if(typeof node==='string')throw Error('use text nodes');node.parentNode=this;this.children.push(node);}}
 replaceChildren(...nodes){for(const child of this.children)child.parentNode=null;this.children=[];this.ownText='';this.append(...nodes);}
 set textContent(s){this.replaceChildren();this.ownText=String(s);}get textContent(){return this.ownText+this.children.map(x=>x.textContent).join('');}
 set innerHTML(_){throw Error('HTML interpretation forbidden');}
 setAttribute(k,v){this.attributes[k]=String(v);}addEventListener(k,fn){(this.listeners[k]??=[]).push(fn);}removeEventListener(k,fn){this.listeners[k]=(this.listeners[k]??[]).filter(x=>x!==fn);}
 focus(){this.doc.activeElement=this;}select(){this.selected=true;}click(){if(!this.disabled)return this.fire('click');}fire(type){return Promise.all((this.listeners[type]??[]).map(fn=>fn({preventDefault(){},target:this})));}
}
function document(){const d={activeElement:null,createElement(tag){return new Element(tag,d);},createTextNode(s){const n=new Element('#text',d);n.textContent=s;return n;}};return d;}
function find(root,predicate){if(predicate(root))return root;for(const c of root.children){const found=find(c,predicate);if(found)return found;}return null;}
function all(root){return [root,...root.children.flatMap(all)];}
function host(){const d=document();const root=d.createElement('main');return {d,root};}
function display(value,analysis=null){return {decode:{ok:true,value,original:wire,kind:'legacy'},analysis,structureMessage:'Structure not checked: schema bridge not connected.'};}
test('renderer uses literal text only for hostile content and keeps native readiness unknown',()=>{
 assert.equal(typeof render.renderViewer,'function');const {d,root}=host();render.renderViewer(d,root,display(map([['name','<script>alert(1)</script>'],['url','javascript:bad']])));assert(root.textContent.includes('<script>alert(1)</script>'));assert(root.textContent.includes('Native readiness not checked'));assert(!all(root).some(x=>['script','img','iframe','a'].includes(x.tagName)));assert(!all(root).some(x=>'href'in x.attributes||'src'in x.attributes));
});
test('injected ordered sections retain paths, disabled actions, forced arms and nested logic literally',()=>{
 const {d,root}=host();const a=analyzed();a.index.rows=[{section:'rotation',index:1,path:['rotation',1],depth:0,step:map([['type','branch'],['mode','false'],['conditions',map([['type','NOT'],['value',map([['type','CUSTOM'],['code','<svg onload=x>']])]])]])},{section:'rotation',index:1,path:['rotation',1,'onTrue',1],depth:1,arm:'true',unreachable:true,step:map([['type','spell'],['action',403],['disabled',true]])},{section:'cooldowns',index:1,path:['cooldowns',1],depth:0,step:map([['type','item'],['action',7]])}];render.renderViewer(d,root,display(map([]),a));const t=root.textContent;for(const want of ['Ordered actions','Cooldowns','Forced false','True arm','Disabled','NOT','CUSTOM','<svg onload=x>','403'])assert(t.includes(want),want);assert(t.indexOf('Forced false')<t.indexOf('403'));assert(t.includes('References unresolved'));assert(t.includes('Native readiness not checked'));
});
test('raw and ordered pagination expose remaining count while bounding rendered nodes and text',async()=>{
 const value=map(Array.from({length:1000},(_,i)=>[i+1,'x'.repeat(1024)]));const {d,root}=host();render.renderViewer(d,root,display(value));assert(all(root).length<=2000);assert(root.textContent.length<=98304);assert(root.textContent.includes('1000'));const next=find(root,x=>x.tagName==='button'&&x.textContent==='Next entries');assert(next);await next.click();assert(root.textContent.includes('[number 201]'));assert(!root.textContent.includes('[number 1] ='));
});
test('clear/release renderer retires old disclosure buttons',async()=>{
 const {d,root}=host();const release=render.renderViewer(d,root,display(map([['long','z'.repeat(12000)]])));const old=find(root,x=>x.tagName==='button');release();await old?.click();assert.equal(root.textContent,'');
});
function mounted(options={}){assert.equal(typeof app.mountViewer,'function');const {d,root}=host();const api=app.mountViewer(d,root,options);return {...api,d,root};}
test('mounted reader decodes only on submit and input changes remove stale export/result',async()=>{
 const m=mounted();m.input.value=wire;await m.input.fire('input');assert.equal(m.copy.disabled,true);await m.form.fire('submit');assert.equal(m.copy.disabled,false);assert(m.result.textContent.includes('Native readiness not checked'));m.input.value='changed';await m.input.fire('input');assert.equal(m.copy.disabled,true);assert.equal(m.result.textContent,'');m.dispose();assert.equal((m.form.listeners.submit??[]).length,0);
});
test('copy denial offers exact selected original, no clipboard access before explicit action',async()=>{
 let calls=0;const m=mounted({writeClipboard:async()=>{calls++;throw Error('denied');}});m.input.value=' \n'+wire;await m.form.fire('submit');assert.equal(calls,0);await m.copy.click();assert.equal(calls,1);assert.equal(m.manual.value,' \n'+wire);assert.equal(m.manual.hidden,false);assert.equal(m.manual.selected,true);await m.clear.click();assert.equal(m.manual.value,'');assert.equal(m.copy.disabled,true);assert.equal(m.d.activeElement,m.input);
});
test('pending clipboard completion cannot restore a cleared or newer session',async()=>{
 let reject;const m=mounted({writeClipboard:()=>new Promise((_,r)=>{reject=r;})});m.input.value=wire;await m.form.fire('submit');const copying=m.copy.click();await m.clear.click();reject(Error('denied'));await copying;assert.equal(m.manual.hidden,true);assert.equal(m.manual.value,'');assert.equal(m.copy.disabled,true);
});
test('repeated decode replaces one result, and malformed analyzer never announces ready',async()=>{
 const m=mounted({analyze:()=>({valid:true})});m.input.value=wire;await m.form.fire('submit');const count=m.result.children.length;await m.form.fire('submit');assert.equal(m.result.children.length,count);assert(m.result.textContent.includes('unavailable'));assert(!m.result.textContent.includes('Ready to execute'));
});
test('static module entry mounts the reader when its owned host is present',async()=>{
 const {d,root}=host();d.getElementById=id=>id==='viewer'?root:null;const previous=globalThis.document,previousFetch=globalThis.fetch;let requested;
 try{globalThis.document=d;globalThis.fetch=async url=>{requested=String(url);return new Response(catalogText);};await import('../Web/viewer/app.mjs?entry-control');assert(find(root,x=>x.tagName==='textarea'));assert(root.textContent.includes('Paste export'));assert(requested.endsWith('/Web/schema/catalog.json'));const input=find(root,x=>x.tagName==='textarea');input.value=golden.at(-1).text;await find(root,x=>x.tagName==='form').fire('submit');assert(root.textContent.includes('Structure valid'));}finally{globalThis.fetch=previousFetch;if(previous===undefined)delete globalThis.document;else globalThis.document=previous;}
});
test('combined large ordered/raw/diagnostic content remains navigable without a hidden budget tail',async()=>{
 const {d,root}=host();const value=map(Array.from({length:1000},(_,i)=>['long-key-'+i,'v'.repeat(1024)]));const a=analyzed();a.validation.diagnostics=Array.from({length:100},()=>({path:'p'.repeat(256),code:'d'.repeat(256)}));
 a.index.rows=Array.from({length:100},(_,i)=>({section:'rotation',index:i+1,path:['rotation',i+1],step:map([['type','spell'],['action',403],['conditions',map(Array.from({length:20},(_,j)=>['field'+j,'q'.repeat(300)]))]])}));
 render.renderViewer(d,root,display(value,a));assert(all(root).length<=2000);assert(root.textContent.length<=98304);assert(find(root,x=>x.tagName==='button'&&x.textContent==='Next actions'));
 const raw=find(root,x=>x.tagName==='button'&&x.textContent==='Show raw data');assert(raw);await raw.click();assert(find(root,x=>x.tagName==='button'&&x.textContent==='Next entries'));assert(root.textContent.includes('1000'));
});
test('long raw string keys are inspectable as bytes without changing their identity',async()=>{
 const {d,root}=host();const key='k'.repeat(90)+'TAIL';render.renderViewer(d,root,display(map([[key,true]])));const inspect=find(root,x=>x.tagName==='button'&&x.textContent==='Inspect key');assert(inspect);await inspect.click();assert(root.textContent.includes('k'.repeat(90)+'TAIL'));
});
test('guard previews disclose incomplete content and action flags remain authored data',()=>{
 const {d,root}=host();const a=analyzed();a.index.rows=[{section:'rotation',index:1,path:['rotation',1],step:map([['type','spell'],['action',403],['ranked',true],['use_name',false],['conditions',map(Array.from({length:40},(_,i)=>['field'+i,'z'.repeat(100)]))]])}];render.renderViewer(d,root,display(map([]),a));assert(root.textContent.includes('ranked: true'));assert(root.textContent.includes('use_name: false'));assert(root.textContent.includes('Inspect step for complete fields'));
});
test('successful clipboard action copies wrapped original and announces success',async()=>{
 const original=' \n'+wire+'\t';let copied;const m=mounted({writeClipboard:async text=>{copied=text;}});m.input.value=original;await m.form.fire('submit');await m.copy.click();assert.equal(copied,original);assert.equal(m.status.textContent,'Original export copied.');assert.equal(m.manual.hidden,true);
});
test('escaped byte expansion cannot consume raw paging controls or hide declared page entries',()=>{
 const {d,root}=host();const a=analyzed();a.validation.diagnostics=Array.from({length:100},()=>({path:'\xff'.repeat(128),code:'\xfe'.repeat(128)}));const value=map(Array.from({length:1000},(_,i)=>[i+1,'\xff'.repeat(512)]));assert(toTypedTree(value));render.renderViewer(d,root,display(value,a));assert(root.textContent.includes('[number 200] ='));assert(find(root,x=>x.tagName==='button'&&x.textContent==='Next entries'));assert(all(root).length<=2000);assert(root.textContent.length<=98304);
});
test('pagination and inspection move keyboard focus to the newly rendered section',async()=>{
 const {d,root}=host();render.renderViewer(d,root,display(map(Array.from({length:401},(_,i)=>[i+1,'v']))));await find(root,x=>x.tagName==='button'&&x.textContent==='Next entries').click();assert.equal(d.activeElement?.textContent,'Raw decoded data');await find(root,x=>x.tagName==='button'&&x.textContent==='Inspect value').click();assert.equal(d.activeElement?.textContent,'Value inspection');
});
test('invalid envelope body can retain real structural diagnostics without inventing a body',()=>{
 const s=session({analyze:()=>({validation:{valid:false,supported:false,resolved:false,diagnostics:[{code:'expected-rotation-object',path:'$.body',severity:'error'}]},body:null,index:null})});s.edit(wire);const v=s.decode();assert.equal(v.analysis?.validation.valid,false);assert.equal(v.analysis.body,null);assert.equal(v.analysis.validation.diagnostics[0].code,'expected-rotation-object');assert.equal(s.original(),wire);
});
test('long escaped action labels cannot remove later action headings or next-page authority',()=>{
 const {d,root}=host();const a=analyzed();a.validation.diagnostics=Array.from({length:100},()=>({path:'\xff'.repeat(128),code:'\xfe'.repeat(128)}));a.index.rows=Array.from({length:100},(_,i)=>({section:'rotation',index:i+1,path:['rotation',i+1],step:map([['type','spell'],['action','\xff'.repeat(256)],['ranked',true],['use_name',true],['suppress_attack',true],['conditions',map(Array.from({length:12},(_,j)=>['k'+j,'\xff'.repeat(100)]))]])}));render.renderViewer(d,root,display(map([['name','\xff'.repeat(256)]]),a));assert(root.textContent.includes('50. spell'));assert(find(root,x=>x.tagName==='button'&&x.textContent==='Next actions'));assert(root.textContent.length<=98304);
});

// Real I1+I2 composition below. No injected schema answers or callback execution.
const catalogText=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
function realSession(){assert.equal(typeof model.createSchemaAnalyzer,'function','real schema adapter is missing');return session({analyze:model.createSchemaAnalyzer(catalogText)});}
test('real schema binding preserves legacy unresolved state and six-row reviewed envelope',()=>{
 for(const g of golden){const s=realSession();s.edit(g.text);const v=s.decode();assert(v.decode.ok);assert(v.analysis);assert.equal(s.original(),g.text);assert.equal(v.analysis.validation.semanticStatus,'not-evaluated');assert.equal(v.analysis.validation.qualityStatus,'unreviewed');assert.equal(v.analysis.validation.nativeAvailability,'unverified');
  if(g.id.startsWith('original90083')){assert.equal(v.analysis.validation.valid,true);assert.equal(v.analysis.validation.resolved,false);assert.equal(v.analysis.index.rows.length,12);}
  else if(g.kind==='envelope'){assert.equal(v.analysis.validation.valid,true);assert.equal(v.analysis.validation.supported,true);assert.equal(v.analysis.validation.resolved,true);assert.equal(v.analysis.index.rows.length,6);}
  else{assert.equal(v.analysis.validation.valid,false);assert.equal(v.analysis.index,null);}
 }
});
const {execFileSync}=await import('node:child_process');
function actualWires(){
 const lua=String.raw`local d,deps=dofile('tests/fixtures/codec.lua')();local c=d.NewCodec(deps)
 local leaf={id='step',type='spell',action=403,conditions={type='USER_CODE',code="error('MUST NOT RUN') <script>globalThis.pwned=true</script>",bytes=string.char(255)}}
 local cases={
 {rotation={leaf},cooldowns={}},
 {rotation={{id='branch',type='branch',mode='false',conditions={type='AND',value={}},onTrue={{id='dup',type='spell',action=403}},onFalse={{id='dup',type='spell',action=403}}}},cooldowns={}},
 {format='RM-Profile',profile={}},
 {format='RotationMaster',schemaVersion=1,id='badbody',revision=1,nameKey='Bad',applicability={families={'tbc'},class='SHAMAN',actionContext='player'},body=false},
 {rotation={{id='role',type='spell',action=403,conditions={type='ROLE',unit='player',value='TANK'}}},cooldowns={}},
 {rotation={[1]={id='numeric',type='spell',action=403},['1']=false},cooldowns={}}
 };for _,v in ipairs(cases)do print(assert(c:Encode(v)))end`;
 return execFileSync('luajit',['-e',lua],{cwd:new URL('..',import.meta.url),encoding:'utf8'}).trim().split('\n');
}
test('actual bundled wire unknown code, forced hidden collisions, foreign data and bad body remain inert',()=>{
 const wires=actualWires();const views=wires.map(w=>{const s=realSession();s.edit(w);const v=s.decode();assert.equal(s.original(),w);return v;});
 assert.equal(views[0].analysis.validation.valid,true);assert.equal(views[0].analysis.validation.resolved,false);assert.equal(globalThis.pwned,undefined);
 assert(views[1].analysis.validation.diagnostics.some(x=>x.code==='duplicate-step-id'));assert.equal(views[1].analysis.index,null);
 assert.equal(views[2].analysis.validation.valid,false);assert.equal(views[3].analysis.validation.valid,false);assert.equal(views[3].analysis.body,null);
 assert.equal(views[4].analysis.validation.resolved,false);assert.equal(views[5].analysis.validation.valid,false);
 const {d,root}=host();render.renderViewer(d,root,views[0]);assert(root.textContent.includes('USER_CODE'));assert(root.textContent.includes('Native readiness not checked'));assert(!all(root).some(x=>x.tagName==='script'));
 render.renderViewer(d,root,views[5]);assert(root.textContent.includes('[number 1]'));assert(root.textContent.includes('[bytes "1"]'));
});
test('real malformed catalog fails closed without asserting user data structurally valid',()=>{
 const s=session({analyze:model.createSchemaAnalyzer('{bad json')});s.edit(wire);const v=s.decode();assert.equal(v.decode.ok,true);assert.equal(v.analysis,null);assert.match(v.structureMessage,/unavailable/);assert.equal(s.original(),wire);
});
test('real boot loads local schema then exposes reviewed native-unknown results and original copy',async()=>{
 assert.equal(typeof app.bootstrapViewer,'function');const {d,root}=host();const m=await app.bootstrapViewer(d,root,{loadCatalog:async()=>catalogText,writeClipboard:async()=>{}});m.input.value=golden.at(-1).text;await m.form.fire('submit');assert(m.result.textContent.includes('Structure valid'));assert(m.result.textContent.includes('References found'));assert(m.result.textContent.includes('Native readiness not checked'));assert(m.result.textContent.includes('403'));assert.equal(m.copy.disabled,false);m.dispose();
});
test('failed schema load keeps raw/original recovery without manufactured structure',async()=>{
 assert.equal(typeof app.bootstrapViewer,'function');const {d,root}=host();const m=await app.bootstrapViewer(d,root,{loadCatalog:async()=>{throw Error('PRIVATE');}});m.input.value=wire;await m.form.fire('submit');assert(m.result.textContent.includes('Structure unavailable'));assert(!m.result.textContent.includes('PRIVATE'));assert(m.result.textContent.includes('Raw decoded data'));assert.equal(m.copy.disabled,false);m.dispose();
});
test('newer boot supersedes pending older schema load and retires prior handlers',async()=>{
 assert.equal(typeof app.bootstrapViewer,'function');const {d,root}=host();let resolve;const first=app.bootstrapViewer(d,root,{loadCatalog:()=>new Promise(r=>{resolve=r;})});const newer=await app.bootstrapViewer(d,root,{loadCatalog:async()=>catalogText});resolve(catalogText);assert.equal(await first,null);assert.equal(find(root,x=>x.tagName==='textarea'),newer.input);const oldInput=newer.input;await app.bootstrapViewer(d,root,{loadCatalog:async()=>catalogText});assert.equal((oldInput.listeners.input??[]).length,0);
});
test('static catalog loader refuses oversize/interrupted/non-UTF8 responses without arbitrary URLs',async()=>{
 assert.equal(typeof app.loadLocalCatalog,'function');let seen;const ok=await app.loadLocalCatalog(async url=>{seen=String(url);return new Response(catalogText);});assert.equal(ok,catalogText);assert(seen.endsWith('/Web/schema/catalog.json'));
 for(const response of [new Response('x'.repeat(524289)),new Response(Uint8Array.of(255)),new Response('missing',{status:404}),new Response(new ReadableStream({start(controller){controller.error(new Error('interrupted'));}}))])await assert.rejects(()=>app.loadLocalCatalog(async()=>response));
});
test('real envelope metadata shows declared family/class/source values without claiming applicability',()=>{
 const s=realSession();s.edit(golden.at(-1).text);const view=s.decode();const {d,root}=host();render.renderViewer(d,root,view);assert(root.textContent.includes('SHAMAN'));assert(root.textContent.includes('tbc'));const sources=view.decode.value.get('sources');const first=sources.get(1);assert(root.textContent.includes(first.get('url')));assert(root.textContent.includes('Native readiness not checked'));
});
test('actual future envelope remains raw-only even when its body has schema-one-looking steps',()=>{
 const lua=`local d,deps=dofile('tests/fixtures/codec.lua')();print(assert(d.NewCodec(deps):Encode({format='RotationMaster',schemaVersion=2,id='future',revision=1,nameKey='Future',body={rotation={{id='one',type='spell',action=403}},cooldowns={}}})))`;
 const wire=execFileSync('luajit',['-e',lua],{cwd:new URL('..',import.meta.url),encoding:'utf8'}).trim();const s=realSession();s.edit(wire);const v=s.decode();assert.equal(v.analysis.validation.valid,true);assert.equal(v.analysis.validation.supported,false);assert.equal(v.analysis.index,null);const {d,root}=host();render.renderViewer(d,root,v);assert(!root.textContent.includes('Ordered actions'));assert(!root.textContent.includes('Structure valid'));assert(root.textContent.includes('Unsupported envelope schema. Structure and references were not checked.'));assert(!root.textContent.includes('Bridge flags'));assert(root.textContent.includes('Raw decoded data'));assert.equal(s.original(),wire);
});
test('recognized schema-one future branch fields retain ordered inspection and unsupported status',()=>{
 const lua=`local d,deps=dofile('tests/fixtures/codec.lua')();print(assert(d.NewCodec(deps):Encode({format='RotationMaster',schemaVersion=1,id='futurefield',revision=1,nameKey='Future field',descriptionKey='Opaque branch',applicability={families={'tbc'},actionContext='player',class='SHAMAN'},body={rotation={{id='b',type='branch',mode='evaluate',conditions={type='AND',value={}},onTrue={},onFalse={},future=true}},cooldowns={}}})))`;
 const wire=execFileSync('luajit',['-e',lua],{cwd:new URL('..',import.meta.url),encoding:'utf8'}).trim();const s=realSession();s.edit(wire);const v=s.decode();assert.equal(v.analysis.validation.valid,true);assert.equal(v.analysis.validation.supported,false);assert.equal(v.analysis.index.rows.length,1);const {d,root}=host();render.renderViewer(d,root,v);assert(root.textContent.includes('Ordered actions'));assert(root.textContent.includes('contains unsupported data'));assert.equal(s.original(),wire);
});
test('metadata rail is a sibling of one grouped navigation/content grid cell',()=>{
 const {d,root}=host();const a=analyzed();a.index.rows=[{section:'rotation',index:1,path:['rotation',1],step:map([['type','spell'],['action',403]])}];render.renderViewer(d,root,display(map([]),a));const content=find(root,x=>x.attributes.class==='content');assert(content);assert(find(content,x=>x.attributes.class==='view-tools'));assert(find(content,x=>x.attributes.class==='ordered'));const declared=find(root,x=>x.attributes.class==='declared');assert.equal(content.parentNode,declared.parentNode);assert(!all(declared).includes(content));
});
test('repeated inspection buttons describe adjacent row context using only generated IDs',async()=>{
 const {d,root}=host();const a=analyzed();a.index.rows=[{section:'rotation',index:1,path:['rotation',1],step:map([['type','spell'],['action',403]])},{section:'cooldowns',index:1,path:['cooldowns',1],step:map([['type','item'],['action',7]])}];render.renderViewer(d,root,display(map([['malicious\" onclick=x','data'],['k'.repeat(90),false]]),a));
 function check(){const controls=all(root).filter(x=>x.tagName==='button'&&/^Inspect (step|value|key)$/.test(x.textContent));assert(controls.length);for(const b of controls){const id=b.attributes['aria-describedby'];assert.match(id,/^rmv-context-\d+-\d+-\d+$/);const context=find(root,x=>x.attributes.id===id);assert(context);assert.equal(context.parentNode,b.parentNode);assert(context.textContent.length);assert(!id.includes('malicious'));}return controls;}
 assert.equal(check().length,2);await find(root,x=>x.tagName==='button'&&x.textContent==='Show raw data').click();assert.equal(check().length,3);
});
test('shared raw pager preserves complete long-key inspection and return focus in the single reader',async()=>{
 const {d,root}=host(),key='k'.repeat(1300);const value=map(Array.from({length:201},(_,i)=>[i+1,false]));value.set(key,'literal');render.renderViewer(d,root,display(value));await find(root,x=>x.tagName==='button'&&x.textContent==='Next entries').click();await find(root,x=>x.tagName==='button'&&x.textContent==='Inspect key').click();assert(root.textContent.includes('of 1300'));await find(root,x=>x.tagName==='button'&&x.textContent==='Next bytes').click();assert(root.textContent.includes('Bytes 1025'));await find(root,x=>x.tagName==='button'&&x.textContent==='Close inspection').click();assert.equal(d.activeElement.textContent,'Raw decoded data');assert(root.textContent.includes('Previous entries'));
});

test('raw view stays grouped beside declared metadata in the shared content cell',()=>{
 const {d,root}=host();render.renderViewer(d,root,display(map([['x',false]])));
 const raw=find(root,e=>e.attributes.class==='raw'),content=find(root,e=>e.attributes.class==='content');
 assert(raw&&content);assert.equal(raw.parentNode,content);
});
