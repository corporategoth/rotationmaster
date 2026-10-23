import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {mountViewer,bootstrapViewer} from '../Web/viewer/app.mjs';
import {createSchemaAnalyzer} from '../Web/viewer/model.mjs';
import {createBundledRotationCatalog} from '../Web/catalog/defaults.mjs';
const schema=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
const bundle=readFileSync(new URL('../Web/catalog/defaults.json',import.meta.url),'utf8');
const fixtures=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url),'utf8')).records;
// A deliberate real wire, not record [0]: the smallest packaged pack, so its
// wrapped share link and incoming fragment stay inside the 8192-byte limit
// whatever order or editions the catalog holds (several premades exceed it).
const sample=[...fixtures].sort((a,b)=>a.wire.length-b.wire.length||(a.id<b.id?-1:1))[0];
const wire=sample.wire,small='AV4xXlRedF5e',pageURL='https://example.invalid/viewer/?private=drop#old';
const analyze=createSchemaAnalyzer(schema),facade=()=>createBundledRotationCatalog(bundle,schema).catalog;
class Element{
 constructor(tag,doc){this.tagName=tag;this.doc=doc;this.children=[];this.attributes={};this.listeners={};this.value='';this.disabled=false;this.hidden=false;this.ownText='';}
 append(...nodes){for(const n of nodes){n.parentNode=this;this.children.push(n);}}replaceChildren(...nodes){for(const n of this.children)n.parentNode=null;this.children=[];this.ownText='';this.append(...nodes);}
 set textContent(v){this.replaceChildren();this.ownText=String(v);}get textContent(){return this.ownText+this.children.map(n=>n.textContent).join('');}set innerHTML(_){throw Error('HTML forbidden');}
 setAttribute(k,v){this.attributes[k]=String(v);}addEventListener(k,fn){(this.listeners[k]??=[]).push(fn);}removeEventListener(k,fn){this.listeners[k]=(this.listeners[k]??[]).filter(v=>v!==fn);}focus(){this.doc.activeElement=this;}select(){this.selected=true;}remove(){if(this.parentNode)this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null;}
 fire(name){return Promise.all((this.listeners[name]??[]).map(fn=>fn({preventDefault(){},target:this})));}click(){return this.disabled?Promise.resolve():this.fire('click');}
}
const all=e=>[e,...e.children.flatMap(all)],id=(e,s)=>all(e).find(n=>n.attributes.id===s),button=(e,s)=>all(e).find(n=>n.tagName==='button'&&n.textContent===s);
function host(){const d={activeElement:null,createElement(t){return new Element(t,d);}};d.body=d.createElement('body');const root=d.createElement('main');d.body.append(root);d.getElementById=s=>id(d.body,s);return {d,root};}
function mount(options={}){const h=host(),value=mountViewer(h.d,h.root,{analyze,pageURL,loadBundled:async()=>facade(),...options});Object.assign(value,h);return value;}
async function decode(p,text=wire){p.input.value=text;await p.form.fire('submit');}
const share=(m,prefix='')=>{const b=id(m.root,prefix+'share-link');assert(b,'pane share control exists');return b;};
const download=(m,prefix='')=>{const b=id(m.root,prefix+'download-original');assert(b,'pane download control exists');return b;};
const incoming=m=>id(m.root,'incoming-share');
function fragments(initial=''){let value=initial,callback,cleanups=0;return {readFragment:()=>value,listenFragment(fn){callback=fn;return()=>{cleanups++;};},set(v){value=v;callback?.();},get callback(){return callback;},get cleanups(){return cleanups;}};}

test('the sample real wire is a packaged premade that fits a wrapped share link',()=>{
 assert(sample&&/^rm\.(tbc|forever|retail)\./.test(sample.id)&&facade().get(sample.id).ok,'sample is a packaged premade');
 assert(('https://example.invalid/viewer/#rm-import-v1='+encodeURIComponent(' \r\n'+wire+'\t')).length<=8192,sample.id);
});
test('sharing requires a current accepted source and preserves exact wrapped real wire',async()=>{
 const copied=[],files=[],m=mount({writeClipboard:async text=>copied.push(text),downloadFile:async file=>files.push(file)});
 assert(m.root.textContent.includes('Share links contain the complete original export'));assert.equal(share(m).disabled,true);assert.equal(download(m).disabled,true);const original=' \r\n'+wire+'\t';await decode(m,original);
 await share(m).click();assert.equal(copied[0],'https://example.invalid/viewer/#rm-import-v1='+encodeURIComponent(original));assert(m.status.textContent.includes('link copied'));
 await download(m).click();assert.equal(files.length,1);assert.equal(files[0].filename,'rotation-master-export.txt');assert.equal(files[0].mediaType,'text/plain;charset=utf-8');assert.equal(new TextDecoder().decode(files[0].bytes),original);assert(m.status.textContent.includes('requested'));assert(!m.status.textContent.includes('saved'));
});
test('programmatic mismatch cannot share or download an older accepted decode',async()=>{
 let calls=0;const m=mount({writeClipboard:async()=>{calls++;},downloadFile:async()=>{calls++;}});await decode(m);m.input.value='changed without event';await share(m).click();await download(m).click();assert.equal(calls,0);assert(m.status.textContent.includes('Decode'));assert.equal(m.copy.disabled,false);m.input.value=wire;await share(m).click();assert.equal(calls,1);
});
test('First and Second exports own independent links files and exact original-copy controls',async()=>{
 const copies=[],files=[],m=mount({writeClipboard:async s=>copies.push(s),downloadFile:async f=>files.push(f)});await decode(m,wire);await m.openComparison.click();await decode(m.right,'\r\n'+small+'\t');await share(m,'compare-').click();await download(m).click();await m.right.copy.click();assert.equal(copies[0],'https://example.invalid/viewer/#rm-import-v1=%0D%0AAV4xXlRedF5e%09');assert.equal(copies[1],'\r\n'+small+'\t');assert.equal(new TextDecoder().decode(files[0].bytes),wire);
});
test('link clipboard failure uses a separate labelled manual field without replacing original recovery',async()=>{
 const m=mount({writeClipboard:async()=>{throw Error('PRIVATE');}});await decode(m,small);await m.copy.click();assert.equal(m.manual.value,small);await share(m).click();const manual=id(m.root,'manual-share-link');assert(manual&&!manual.hidden);assert.equal(manual.value,'https://example.invalid/viewer/#rm-import-v1='+small);assert.equal(m.manual.value,small);assert(all(m.root).some(n=>n.tagName==='label'&&n.attributes.for==='manual-share-link'&&n.textContent.includes('Share link')));assert(!m.status.textContent.includes('PRIVATE'));assert.equal(m.d.activeElement,manual);
});
test('oversized links and missing file support preserve manual original fallback',async()=>{
 const m=mount({writeClipboard:async()=>{throw Error('denied');}});await decode(m,small+' '.repeat(9000));await share(m).click();assert(m.status.textContent.includes('too large'));assert.equal(id(m.root,'manual-share-link').value,'');await download(m).click();assert(m.status.textContent.includes('unavailable'));await m.copy.click();assert.equal(m.manual.value,small+' '.repeat(9000));assert.equal(m.copy.disabled,false);
});
test('file callback failure is bounded and preserves accepted original',async()=>{
 const m=mount({downloadFile(){throw Error('PRIVATE FILE');}});await decode(m);await download(m).click();assert(m.status.textContent.includes('unavailable'));assert(!m.root.textContent.includes('PRIVATE FILE'));assert.equal(m.copy.disabled,false);
});
test('late link clipboard completion cannot overwrite edited or newly decoded pane',async()=>{
 for(const reject of [false,true]){let settle;const m=mount({writeClipboard:()=>new Promise((r,j)=>{settle=reject?j:r;})});await decode(m,small);const pending=share(m).click();await decode(m,wire);const status=m.status.textContent;m.input.focus();settle(reject?Error('late'):undefined);await pending;assert.equal(m.status.textContent,status);assert.equal(id(m.root,'manual-share-link').value,'');assert.equal(m.d.activeElement,m.input);}
});
test('late download and closed Second sharing handlers cannot affect current state',async()=>{
 let resolve,calls=0;const m=mount({downloadFile:()=>new Promise(r=>{resolve=r;}),writeClipboard:async()=>{calls++;}});await decode(m);const pending=download(m).click();await m.clear.click();const status=m.status.textContent;resolve();await pending;assert.equal(m.status.textContent,status);await m.openComparison.click();await decode(m.right,small);const old=share(m,'compare-').listeners.click[0];await m.closeComparison.click();await old();assert.equal(calls,0);
});
test('catalog has no generated share authority and hidden completion cannot steal focus',async()=>{
 let reject;const m=mount({writeClipboard:()=>new Promise((_,j)=>{reject=j;})});await decode(m);const pending=share(m).click();await m.bundledNavigation.click();await all(m.root).find(n=>n.attributes['data-default-id']).click();m.bundledNavigation.focus();reject(Error('denied'));await pending;assert.equal(m.d.activeElement,m.bundledNavigation);assert.equal(all(m.result).some(n=>n.textContent==='Copy share link'||n.textContent==='Download original export'),false);assert(id(m.root,'manual-share-link').value.includes('#rm-import-v1='));
});
test('incoming link stages explicit replace notice and leaves both drafts and decode untouched',async()=>{
 const f=fragments('#rm-import-v1='+encodeURIComponent(small)),m=mount(f);assert(incoming(m));assert(incoming(m).textContent.includes('replaces'));assert.equal(m.input.value,'');assert.equal(m.copy.disabled,true);await decode(m,wire);await m.openComparison.click();m.right.input.value='Second draft';await button(m.root,'Load into first export').click();assert.equal(m.input.value,small);assert.equal(m.right.input.value,'Second draft');assert.equal(m.copy.disabled,true);assert.equal(m.result.textContent,'');assert.equal(m.d.activeElement,m.input);assert.equal(incoming(m).textContent,'');await m.form.fire('submit');assert.equal(m.copy.disabled,false);
});
test('fragment replacement retires stale Load and Dismiss without overwriting drafts',async()=>{
 const f=fragments('#rm-import-v1='+small),m=mount(f),oldLoad=button(m.root,'Load into first export').listeners.click[0],oldDismiss=button(m.root,'Dismiss').listeners.click[0];m.input.value='own draft';f.set('#rm-import-v1='+encodeURIComponent(wire));await oldLoad();await oldDismiss();assert.equal(m.input.value,'own draft');assert(button(m.root,'Load into first export'));await button(m.root,'Dismiss').click();assert.equal(incoming(m).textContent,'');assert.equal(m.input.value,'own draft');
});
test('malformed unsupported and unrelated fragments use fixed non-echo feedback',async()=>{
 const f=fragments('#rm-import-v2=PRIVATE'),m=mount(f);assert(incoming(m).textContent.includes('unsupported'));assert(!incoming(m).textContent.includes('PRIVATE'));assert(!button(m.root,'Load into first export'));f.set('#rm-import-v1=%GGPRIVATE');assert(incoming(m).textContent.includes('unavailable'));assert(!incoming(m).textContent.includes('PRIVATE'));f.set('#section');assert.equal(incoming(m).textContent,'');f.set('#rm-import-v1=error%28%22inert%22%29');await button(m.root,'Load into first export').click();assert.equal(m.copy.disabled,true);await m.form.fire('submit');assert.equal(m.copy.disabled,true);
});
test('incoming Load switches from bundled reader without changing Second or auto decoding',async()=>{
 const f=fragments(),m=mount(f);await decode(m,wire);await m.openComparison.click();await decode(m.right,small);await m.bundledNavigation.click();await all(m.root).find(n=>n.attributes['data-default-id']).click();f.set('#rm-import-v1='+small);await button(m.root,'Load into first export').click();assert.equal(m.importsNavigation.attributes['aria-pressed'],'true');assert.equal(m.input.value,small);assert.equal(m.right.input.value,small);assert.equal(m.copy.disabled,true);assert.equal(m.right.copy.disabled,false);assert.equal(m.result.textContent,'');
});
test('dispose cleans fragment subscription and retained callbacks cannot write or load',async()=>{
 const f=fragments('#rm-import-v1='+small),m=mount(f),old=f.callback,load=button(m.root,'Load into first export').listeners.click[0];m.dispose();assert.equal(f.cleanups,1);await old();await load();assert.equal(m.root.textContent,'');assert.equal(m.input.value,'');m.dispose();assert.equal(f.cleanups,1);
});
test('bootstrap reads latest fragment only after schema lease and old mount callbacks retire',async()=>{
 const h=host(),f=fragments('#rm-import-v1='+small);let resolve;const pending=bootstrapViewer(h.d,h.root,{loadCatalog:()=>new Promise(r=>{resolve=r;}),...f,pageURL});f.set('#rm-import-v1='+encodeURIComponent(wire));resolve(schema);const first=await pending;assert(button(h.root,'Load into first export'));await button(h.root,'Load into first export').click();assert.equal(first.input.value,wire);const old=f.callback,second=await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema,pageURL});old();assert.equal(first.input.value,'');assert.equal(second.input.value,'');assert.equal(f.cleanups,1);
});
test('superseded schema bootstrap never reads or subscribes to incoming fragments',async()=>{
 const h=host();let resolve,reads=0,listens=0;const first=bootstrapViewer(h.d,h.root,{loadCatalog:()=>new Promise(r=>{resolve=r;}),readFragment(){reads++;return'#rm-import-v1='+small;},listenFragment(){listens++;return()=>{};}});const second=await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema});resolve(schema);assert.equal(await first,null);assert.equal(reads,0);assert.equal(listens,0);assert.equal(second.input.value,'');
});

test('newer share or original-copy action owns feedback over an older pending share',async()=>{
 let settle,calls=0;const m=mount({writeClipboard:()=>++calls===1?new Promise(r=>{settle=r;}):Promise.resolve()});await decode(m,small);const old=share(m).click();await m.copy.click();const status=m.status.textContent;settle();await old;assert.equal(m.status.textContent,status);assert(status.includes('Original export copied'));
});
test('fragment reader reentry preserves newer notice and disposed reads remain inert',async()=>{
 let m,callback,fragment='#rm-import-v1='+small,armed=false,reads=0;
 m=mount({readFragment(){reads++;if(armed){armed=false;fragment='#rm-import-v1='+encodeURIComponent(wire);callback();return'#rm-import-v1=old';}return fragment;},listenFragment(fn){callback=fn;return()=>{};}});armed=true;callback();await button(m.root,'Load into first export').click();assert.equal(m.input.value,wire);m.dispose();const count=reads;callback();assert.equal(reads,count);
});
test('initial subscriber reentry cannot replace a newer notice with an older registration failure',async()=>{
 let fragment='#rm-import-v1='+small;const m=mount({readFragment:()=>fragment,listenFragment(callback){fragment='#rm-import-v1='+encodeURIComponent(wire);callback();throw Error('old registration failure');}});assert(button(m.root,'Load into first export'));await button(m.root,'Load into first export').click();assert.equal(m.input.value,wire);
});
test('default entry adapters keep transparent bytes fixed filename and revoke owned URLs on success and failure',async()=>{
 const names=['document','location','navigator','fetch','addEventListener','removeEventListener','Blob'];const descriptors=new Map(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
 const nativeBlob=globalThis.Blob,create=URL.createObjectURL,revoke=URL.revokeObjectURL,h=host(),copied=[],created=[],revoked=[],clicked=[],events=new Map();let fail=false,failCreate=false,options;
 h.root.setAttribute('id','viewer');const make=h.d.createElement.bind(h.d);h.d.createElement=tag=>{if(tag==='a'&&failCreate)throw Error('anchor unavailable');const e=make(tag);if(tag==='a')e.click=()=>{clicked.push({...e.attributes});if(fail)throw Error('download denied');};return e;};
 try{
  Object.assign(globalThis,{document:h.d,location:{href:pageURL,hash:'#rm-import-v1='+small},fetch:async()=>({ok:true,headers:{get:()=>null},body:{getReader(){let done=false;return{async read(){if(done)return{done:true};done=true;return{done:false,value:new TextEncoder().encode(schema)};},releaseLock(){},async cancel(){}};}}}),addEventListener:(name,fn)=>events.set(name,fn),removeEventListener:(name,fn)=>{if(events.get(name)===fn)events.delete(name);},Blob:class extends nativeBlob{constructor(parts,opts){super(parts,opts);options=opts;}}});
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{clipboard:{writeText:async s=>copied.push(s)}}});
  URL.createObjectURL=blob=>{created.push(blob);return'blob:controlled-'+created.length;};URL.revokeObjectURL=url=>revoked.push(url);
  await import('../Web/viewer/app.mjs?sharing-browser-adapter-control');await new Promise(setImmediate);
  const input=id(h.root,'import-text'),form=all(h.root).find(n=>n.tagName==='form');assert(input&&form);assert(events.has('hashchange'));assert(button(h.root,'Load into first export'));
  input.value='\r\n'+small+'\t\r';await form.fire('submit');await id(h.root,'share-link').click();assert.equal(copied[0],'https://example.invalid/viewer/#rm-import-v1=%0D%0AAV4xXlRedF5e%09%0D');await id(h.root,'download-original').click();
  assert.equal(options.endings,'transparent');assert.equal(options.type,'text/plain;charset=utf-8');assert.equal(new TextDecoder().decode(await created[0].arrayBuffer()),input.value);assert.deepEqual(clicked[0],{href:'blob:controlled-1',download:'rotation-master-export.txt'});assert.deepEqual(revoked,['blob:controlled-1']);assert.equal(h.d.body.children.length,1);
  fail=true;await id(h.root,'download-original').click();assert.deepEqual(revoked,['blob:controlled-1','blob:controlled-2']);assert.equal(h.d.body.children.length,1);assert(id(h.root,'import-status').textContent.includes('unavailable'));failCreate=true;await id(h.root,'download-original').click();assert.deepEqual(revoked,['blob:controlled-1','blob:controlled-2','blob:controlled-3']);
 }finally{URL.createObjectURL=create;URL.revokeObjectURL=revoke;for(const [key,value]of descriptors){if(value)Object.defineProperty(globalThis,key,value);else delete globalThis[key];}}
});
test('fragment read which starts a newer bootstrap cannot publish or subscribe an older mount',async()=>{
 const h=host();let newer,listens=0;const old=await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema,readFragment(){newer=bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema});return'#rm-import-v1='+small;},listenFragment(){listens++;return()=>{};}});const current=await newer;assert(old===null,'older mount must not publish after fragment-reader replacement');assert.equal(listens,0);assert.equal(current.input.value,'');assert(id(h.root,'import-text'));assert.equal(incoming(h).textContent,'');
});
test('subscription cleanup which reboots the host supersedes the older replacement before it loads',async()=>{
 const h=host();let newer,outerLoads=0;await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema,listenFragment(){return()=>{newer=bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schema});};}});
 const outer=await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>{outerLoads++;return schema;}});const current=await newer;assert(outer===null,'newer bootstrap during cleanup owns host');assert.equal(outerLoads,0);assert(id(h.root,'import-text'));assert.equal(current.input.value,'');
});
test('retained sharing and notice handlers cannot act after direct host replacement',async()=>{
 const h=host();let calls=0;const first=mountViewer(h.d,h.root,{analyze,pageURL,writeClipboard:async()=>{calls++;},readFragment:()=> '#rm-import-v1='+small});await decode(first,small);const oldShare=id(h.root,'share-link').listeners.click[0],oldLoad=button(h.root,'Load into first export').listeners.click[0];const second=mountViewer(h.d,h.root,{analyze,pageURL});second.input.focus();await oldShare();await oldLoad();assert.equal(calls,0);assert.equal(first.input.value,small);assert.equal(second.input.value,'');assert.equal(h.d.activeElement,second.input);
});
