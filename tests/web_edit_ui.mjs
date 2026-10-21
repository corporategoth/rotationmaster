import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {mountViewer,bootstrapViewer} from '../Web/viewer/app.mjs';
import {createSchemaAnalyzer} from '../Web/viewer/model.mjs';
import {createBundledRotationCatalog} from '../Web/catalog/defaults.mjs';
import {decodeImport} from '../Web/codec/import.mjs';
import {encodeExport} from '../Web/codec/export.mjs';
import {toTypedTree} from '../Web/codec/lua-data.mjs';
const schemaText=readFileSync(new URL('../Web/schema/catalog.json',import.meta.url),'utf8');
const bundled=readFileSync(new URL('../Web/catalog/defaults.json',import.meta.url),'utf8');
const wire=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url),'utf8')).records[0].wire;
class Element{
 constructor(tag,doc){this.tagName=tag;this.doc=doc;this.children=[];this.attributes={};this.listeners={};this.value='';this.disabled=false;this.hidden=false;this.ownText='';}
 append(...nodes){for(const n of nodes){n.parentNode=this;this.children.push(n);}}replaceChildren(...nodes){for(const n of this.children)n.parentNode=null;this.children=[];this.ownText='';this.append(...nodes);}
 set textContent(v){this.replaceChildren();this.ownText=String(v);}get textContent(){return this.ownText+this.children.map(n=>n.textContent).join('');}set innerHTML(_){throw Error('HTML forbidden');}
 setAttribute(k,v){this.attributes[k]=String(v);}addEventListener(k,fn){(this.listeners[k]??=[]).push(fn);}removeEventListener(k,fn){this.listeners[k]=(this.listeners[k]??[]).filter(v=>v!==fn);}focus(){this.doc.activeElement=this;}select(){this.selected=true;}
 fire(name){return Promise.all((this.listeners[name]??[]).map(fn=>fn({preventDefault(){},target:this})));}click(){if(this.disabled)return Promise.resolve();this.focus();return this.fire('click');}
}
const all=e=>[e,...e.children.flatMap(all)],find=(e,id)=>all(e).find(n=>n.attributes.id===id);
function host(){const d={activeElement:null,createElement(t){return new Element(t,d);}},root=d.createElement('main');return {d,root};}
function mount(options={}){const h=host(),app=mountViewer(h.d,h.root,{schemaText,analyze:createSchemaAnalyzer(schemaText),loadBundled:async()=>createBundledRotationCatalog(bundled,schemaText).catalog,...options});return {...h,app,get(id){const e=find(h.root,id);assert(e,'control '+id+' exists');return e;}};}
async function decode(m,text=wire){m.app.input.value=text;await m.app.form.fire('submit');}
async function edit(m){await decode(m);await m.get('edit-copy').click();assert.equal(m.get('draft-fields').hidden,false);}
async function priority(m,value){m.get('draft-priority').value=value;m.get('draft-priority-presence').value='set';await m.get('draft-priority').fire('input');}
async function generate(m){await m.get('draft-review').click();await m.get('draft-generate').click();assert.equal(m.get('draft-output').hidden,false);return m.get('draft-output').value;}

test('mounted editor explicitly reviews and exports a copy while original and Second remain byte exact',async()=>{
 const copied=[],m=mount({writeClipboard:async text=>copied.push(text)});await edit(m);await priority(m,'-0');const text=await generate(m);
 const expected=decodeImport(wire).value;expected.get('body').set('priority',-0);assert.deepEqual(toTypedTree(decodeImport(text).value),toTypedTree(expected));
 await m.get('draft-copy').click();await m.app.copy.click();assert.deepEqual(copied,[text,wire]);
 await m.app.openComparison.click();m.app.right.input.value=wire;await m.app.right.form.fire('submit');await m.app.right.copy.click();assert.equal(copied.at(-1),wire);assert.equal(m.get('draft-output').value,text);
});
test('draft presence controls do not create default fields and invalid priority blocks previous output',async()=>{
 const m=mount();await edit(m);const original=decodeImport(wire).value.get('body');assert.equal(m.get('draft-priority-presence').value,original.has('priority')?'set':'absent');
 m.get('draft-disabled').value='false';await m.get('draft-disabled').fire('change');let value=decodeImport(await generate(m)).value.get('body');assert.equal(value.get('disabled'),false);
 m.get('draft-disabled').value='absent';await m.get('draft-disabled').fire('change');value=decodeImport(await generate(m)).value.get('body');assert.equal(value.has('disabled'),false);
 await priority(m,'100001');assert.equal(m.get('draft-output').value,'');assert.equal(m.get('draft-copy').disabled,true);assert.equal(m.get('draft-review').disabled,true);assert.equal(m.get('draft-priority').attributes['aria-invalid'],'true');
 m.get('draft-disabled').value='true';await m.get('draft-disabled').fire('change');assert.match(m.get('draft-status').textContent,/Enter an integer/);
 await priority(m,'7');await generate(m);assert.equal(decodeImport(m.get('draft-output').value).value.get('body').get('priority'),7);
});
test('First edits clear new output and retain retired draft values until explicit discard',async()=>{
 const m=mount();await edit(m);await priority(m,'42');await generate(m);m.app.input.value=wire+' ';await m.app.input.fire('input');
 assert.equal(m.get('draft-priority').value,'42');assert.equal(m.get('draft-priority').disabled,true);assert.equal(m.get('draft-output').value,'');assert.equal(m.get('draft-generate').disabled,true);
 await decode(m);assert.equal(m.get('edit-copy').disabled,true);await m.get('draft-discard').click();await m.get('edit-copy').click();assert.equal(m.get('draft-priority-presence').disabled,false);
});
test('programmatic text mismatch retires current output and matching text cannot revive it',async()=>{
 const m=mount();await edit(m);await generate(m);m.app.input.value='different';await m.get('draft-copy').click();assert.equal(m.get('draft-output').value,'');m.app.input.value=wire;await m.get('draft-review').click();assert.equal(m.get('draft-generate').disabled,true);
});
test('Clear and unsuccessful new Decode retire a draft and never replace the accepted original with generated data',async()=>{
 for(const action of ['clear','error']){const m=mount();await edit(m);await generate(m);if(action==='clear')await m.app.clear.click();else await decode(m,'invalid');assert.equal(m.get('draft-output').value,'');assert.equal(m.get('draft-priority').disabled,true);assert.equal(m.get('draft-copy').disabled,true);}
});
test('late clipboard failures cannot republish retired output or steal focus from a newer field',async()=>{
 let reject;const m=mount({writeClipboard:()=>new Promise((_,r)=>{reject=r;})});await edit(m);await generate(m);const pending=m.get('draft-copy').click();await priority(m,'8');m.app.input.focus();reject(Error('denied'));await pending;
 assert.equal(m.get('draft-output').value,'');assert.equal(m.d.activeElement,m.app.input);assert.doesNotMatch(m.get('draft-status').textContent,/Clipboard unavailable/);
});
test('clipboard denial provides only generated manual bytes; newer original copy owns feedback and focus',async()=>{
 let reject,calls=0;const m=mount({writeClipboard:()=>++calls===1?new Promise((_,r)=>{reject=r;}):Promise.resolve()});await edit(m);const text=await generate(m);const pending=m.get('draft-copy').click();await m.app.copy.click();reject(Error('late'));await pending;assert.equal(m.d.activeElement,m.app.copy);assert.doesNotMatch(m.get('draft-status').textContent,/Clipboard unavailable/);
 const denied=mount({writeClipboard:async()=>{throw Error('denied');}});await edit(denied);const generatedText=await generate(denied);await denied.get('draft-copy').click();assert.equal(denied.get('draft-output').value,generatedText);assert.notEqual(generatedText,wire);assert.match(denied.get('draft-status').textContent,/Clipboard unavailable/);assert.equal(denied.d.activeElement,denied.get('draft-output'));assert.equal(denied.get('draft-output').selected,true);assert.equal(m.get('draft-output').value,text);
});
test('bundled navigation preserves a current draft without edit or export authority over catalog data',async()=>{
 let resolve;const m=mount({writeClipboard:()=>new Promise(r=>{resolve=r;})});await edit(m);const text=await generate(m);const pending=m.get('draft-copy').click();await m.app.bundledNavigation.click();const focus=m.d.activeElement;resolve();await pending;assert.equal(m.d.activeElement,focus);assert.doesNotMatch(m.get('draft-status').textContent,/copied/);await m.app.importsNavigation.click();assert.equal(m.get('draft-output').value,text);assert.equal(m.get('draft-copy').disabled,false);
});
test('retained handlers and pending copies cannot act after disposal or direct host replacement',async()=>{
 for(const replace of [false,true]){let reject;const m=mount({writeClipboard:()=>new Promise((_,r)=>{reject=r;})});await edit(m);await generate(m);const old=m.get('draft-copy'),handler=old.listeners.click[0],status=m.get('draft-status');const pending=old.click();if(replace)m.root.replaceChildren(m.d.createElement('aside'));else m.app.dispose();reject(Error('late'));await pending;await handler({preventDefault(){}});assert.doesNotMatch(status.textContent,/Clipboard unavailable|copied/);}
});
test('bootstrap forwards its owned schema while missing schema disables editing without breaking reading',async()=>{
 const h=host(),app=await bootstrapViewer(h.d,h.root,{loadCatalog:async()=>schemaText});app.input.value=wire;await app.form.fire('submit');await find(h.root,'edit-copy').click();assert.equal(find(h.root,'draft-fields').hidden,false);app.dispose();
 const m=mount({schemaText:null});await decode(m);assert.equal(m.get('edit-copy').disabled,true);assert.equal(m.app.copy.disabled,false);
});
test('successful pending copy detects silent First mismatch and clears retired output without claiming copied',async()=>{
 let resolve;const m=mount({writeClipboard:()=>new Promise(r=>{resolve=r;})});await edit(m);await generate(m);const pending=m.get('draft-copy').click();m.app.input.value='silent replacement';resolve();await pending;
 assert.equal(m.get('draft-output').value,'');assert.equal(m.get('draft-copy').disabled,true);assert.doesNotMatch(m.get('draft-status').textContent,/copied/);
});
for(const [before,after]of [[0,-0],[-0,0]])test('mounted review displays literal priority '+(Object.is(before,-0)?'-0':'0')+' to '+(Object.is(after,-0)?'-0':'0')+' and encodes only that change',async()=>{
 const original=encodeExport(new Map([['rotation',new Map()],['cooldowns',new Map()],['priority',before],['disabled',false]])).text,copied=[],m=mount({writeClipboard:async text=>copied.push(text)});
 await decode(m,original);await m.get('edit-copy').click();await priority(m,Object.is(after,-0)?'-0':'0');await m.get('draft-review').click();
 assert.match(m.get('draft-changes').textContent,new RegExp('Priority: '+(Object.is(before,-0)?'-0':'0')+' → '+(Object.is(after,-0)?'-0':'0')));assert.doesNotMatch(m.get('draft-changes').textContent,/No structural differences/);
 await m.get('draft-generate').click();const output=m.get('draft-output').value;assert.notEqual(output,original);const expected=decodeImport(original).value;expected.set('priority',after);assert.deepEqual(toTypedTree(decodeImport(output).value),toTypedTree(expected));assert.equal(Object.is(decodeImport(output).value.get('priority'),after),true);
 await m.app.copy.click();assert.deepEqual(copied,[original]);
});
test('mounted unchanged zero bits and literal absence false preserve an empty review without materializing fields',async()=>{
 for(const value of [undefined,0,-0])for(const disabled of [undefined,false]){
  const source=new Map([['rotation',new Map()],['cooldowns',new Map()]]);if(value!==undefined)source.set('priority',value);if(disabled!==undefined)source.set('disabled',disabled);const original=encodeExport(source).text,m=mount();
  await decode(m,original);await m.get('edit-copy').click();if(value!==undefined)await priority(m,Object.is(value,-0)?'-0':'0');
  m.get('draft-disabled').value=disabled===undefined?'absent':'false';await m.get('draft-disabled').fire('change');await m.get('draft-review').click();assert.match(m.get('draft-changes').textContent,/No structural differences/);await m.get('draft-generate').click();assert.deepEqual(toTypedTree(decodeImport(m.get('draft-output').value).value),toTypedTree(source));
 }
});
