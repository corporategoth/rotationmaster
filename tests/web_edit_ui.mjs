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

function stepWire(count=2){
 const leaf=id=>new Map([['id',id],['type','none']]),branch=new Map([['id','branch'],['type','branch'],['conditions',new Map()],['onTrue',new Map([[1,leaf('nested')]])],['onFalse',new Map()]]);
 return encodeExport(new Map([['rotation',new Map([[1,branch],...Array.from({length:count},(_,i)=>[i+2,leaf('row'+i)])])],['cooldowns',new Map()],['priority',-0],['revision',17],['opaque','\xff\x00']])).text;
}
async function selectStep(m,id){m.get('draft-step-select').value=id;await m.get('draft-step-select').fire('change');}
async function stepDisabled(m,state){m.get('draft-step-disabled').value=state;await m.get('draft-step-disabled').fire('change');}
test('mounted nested step disabled has exact reviewed context and tri-state export with original/Second unchanged',async()=>{
 const original=stepWire(),copied=[],m=mount({writeClipboard:async t=>copied.push(t)});await decode(m,original);await m.get('edit-copy').click();await selectStep(m,'nested');assert.equal(m.get('draft-step-disabled').value,'absent');assert.match(m.get('draft-step-context').textContent,/nested.*branch.*true/);
 for(const state of ['false','true','absent']){await stepDisabled(m,state);assert.equal(m.get('draft-output').value,'');assert.equal(m.get('draft-generate').disabled,true);await m.get('draft-review').click();if(state!=='absent')assert.match(m.get('draft-changes').textContent,/Step nested.*Disabled: Unset → (False|True)/);const output=await generate(m),expected=decodeImport(original).value,target=expected.get('rotation').get(1).get('onTrue').get(1);if(state!=='absent')target.set('disabled',state==='true');assert.deepEqual(toTypedTree(decodeImport(output).value),toTypedTree(expected));}
 await m.app.copy.click();await m.app.openComparison.click();m.app.right.input.value=original;await m.app.right.form.fire('submit');await m.app.right.copy.click();assert.deepEqual(copied,[original,original]);
});
test('branches remain read-only and step navigation leaves invalid priority and existing output ownership intact',async()=>{
 const m=mount();await decode(m,stepWire());await m.get('edit-copy').click();const text=await generate(m);await selectStep(m,'branch');assert.equal(m.get('draft-step-disabled').disabled,true);assert.match(m.get('draft-step-context').textContent,/read-only/);assert.equal(m.get('draft-output').value,text);await priority(m,'bad');await selectStep(m,'nested');await stepDisabled(m,'false');assert.equal(m.get('draft-priority').value,'bad');assert.equal(m.get('draft-review').disabled,true);assert.match(m.get('draft-status').textContent,/Enter an integer/);
});
test('step pages cap options at50 and stale retained row handlers cannot edit another page or new draft',async()=>{
 const m=mount();await decode(m,stepWire(105));await m.get('edit-copy').click();assert.equal(m.get('draft-step-select').children.length,51);await selectStep(m,'nested');const old=m.get('draft-step-disabled'),handler=old.listeners.change[0];await m.get('draft-step-next').click();assert.equal(m.get('draft-step-select').children.length,51);old.value='true';await handler({});let value=decodeImport(await generate(m)).value;assert.equal(value.get('rotation').get(1).get('onTrue').get(1).has('disabled'),false);
 await m.get('draft-step-next').click();assert.equal(m.get('draft-step-select').children.length,8);await selectStep(m,'row104');await stepDisabled(m,'false');value=decodeImport(await generate(m)).value;assert.equal(value.get('rotation').get(106).get('disabled'),false);await m.get('draft-discard').click();await m.get('edit-copy').click();await handler({});value=decodeImport(await generate(m)).value;assert.equal(value.get('rotation').get(1).get('onTrue').get(1).has('disabled'),false);
});
test('retired selected step values remain readable and retained handlers cannot revive authority',async()=>{
 const m=mount();await decode(m,stepWire());await m.get('edit-copy').click();await selectStep(m,'nested');await stepDisabled(m,'false');const old=m.get('draft-step-disabled'),handler=old.listeners.change[0];await generate(m);await m.app.clear.click();assert.equal(m.get('draft-step-disabled').value,'false');assert.equal(m.get('draft-step-disabled').disabled,true);assert.equal(m.get('draft-output').value,'');old.value='true';await handler({});assert.equal(m.get('draft-step-disabled').value,'false');assert.equal(m.get('draft-generate').disabled,true);
});
test('step edits supersede pending copy feedback and disposed or hidden step handlers remain inert',async()=>{
 let reject;const m=mount({writeClipboard:()=>new Promise((_,r)=>{reject=r;})});await decode(m,stepWire());await m.get('edit-copy').click();await selectStep(m,'nested');await generate(m);const pending=m.get('draft-copy').click();await stepDisabled(m,'true');m.app.input.focus();reject(Error('late'));await pending;assert.equal(m.d.activeElement,m.app.input);assert.doesNotMatch(m.get('draft-status').textContent,/Clipboard unavailable/);assert.equal(m.get('draft-output').value,'');
 const old=m.get('draft-step-disabled'),handler=old.listeners.change[0];await m.app.bundledNavigation.click();old.value='false';await handler({});await m.app.importsNavigation.click();const value=decodeImport(await generate(m)).value;assert.equal(value.get('rotation').get(1).get('onTrue').get(1).get('disabled'),true);m.app.dispose();await handler({});
});

test('new step handlers recheck render and draft lease after action visibility and source callbacks',async()=>{
 const {mountDraftEditor}=await import('../Web/editor/render.mjs');
 for(const boundary of ['action','visibility','source','redraw'])for(const event of ['select','next','previous','state']){
  const h=host();let sourceValue=decodeImport(stepWire(105)).value,source={decode:{ok:true,kind:'legacy',value:sourceValue,original:encodeExport(sourceValue).text}},armed=false,controller;
  const get=id=>{const e=find(h.root,id);assert(e,id);return e;},sentinel=h.d.createElement('input');
  const replace=()=>{if(!armed)return;armed=false;if(boundary==='redraw'){controller.refresh();sentinel.focus();return;}sourceValue=decodeImport(stepWire(105)).value;sourceValue.set('marker','replacement');source={decode:{ok:true,kind:'legacy',value:sourceValue,original:encodeExport(sourceValue).text}};controller.retire();get('draft-discard').click();get('edit-copy').click();sentinel.focus();};
  controller=mountDraftEditor(h.d,h.root,{schemaText,readSource(){if(boundary==='source'||boundary==='redraw')replace();return source;},onAction(){if(boundary==='action')replace();},isVisible(){if(boundary==='visibility')replace();return true;}});
  await get('edit-copy').click();if(event==='state'){get('draft-step-select').value='nested';await get('draft-step-select').fire('change');}if(event==='previous')await get('draft-step-next').click();
  const selected=get('draft-step-select'),state=get('draft-step-disabled');selected.value='nested';state.value='true';armed=true;
  if(event==='select')await selected.fire('change');else if(event==='state')await state.fire('change');else await get('draft-step-'+(event==='next'?'next':'prev')).click();
  assert.equal(h.d.activeElement,sentinel,boundary+'/'+event+' stale focus');
  if(boundary!=='redraw')assert.equal(get('draft-step-select').value,'',boundary+'/'+event+' stale selection');
  if(boundary!=='redraw')assert.equal(get('draft-step-prev').disabled,true,boundary+'/'+event+' stale page');
  await get('draft-review').click();await get('draft-generate').click();const output=decodeImport(get('draft-output').value).value;assert.equal(output.get('rotation').get(1).get('onTrue').get(1).has('disabled'),false,boundary+'/'+event+' stale write');controller.dispose();
 }
});
test('step context shows literal action and Stop suppression while imported bytes are bounded escaped data',async()=>{
 const importedType='FUTURE\xff\0'+('z'.repeat(1024)),action='Spell\xff\0'+('q'.repeat(1024));
 const value=new Map([['rotation',new Map([[1,new Map([['id','spell'],['type','spell'],['action',403]])],[2,new Map([['id','stop'],['type','none'],['suppress_attack',true]])],[3,new Map([['id','unknown'],['type',importedType]])],[4,new Map([['id','item'],['type','item'],['action',new Map([[1,action],[2,6948],[3,5512]])]])],[5,new Map([['id','stop-false'],['type','none'],['suppress_attack',false]])],[6,new Map([['id','stop-absent'],['type','none']])]])],['cooldowns',new Map()]]),original=encodeExport(value).text,m=mount();await decode(m,original);await m.get('edit-copy').click();
 await selectStep(m,'spell');const context=m.get('draft-step-context').textContent;assert.match(context,/action.*403/);assert(context.length<700);assert(!context.includes('\0'));assert.equal(m.get('draft-step-disabled').disabled,false);
 await selectStep(m,'stop');assert.match(m.get('draft-step-context').textContent,/Stop.*suppress_attack.*true/i);
 await selectStep(m,'stop-false');assert.match(m.get('draft-step-context').textContent,/Stop.*suppress_attack.*False/);await selectStep(m,'stop-absent');assert.match(m.get('draft-step-context').textContent,/Stop.*suppress_attack.*Unset/);
 await selectStep(m,'item');assert.match(m.get('draft-step-context').textContent,/action.*Spell\\xFF\\x00.*6948.*5512/);
 await selectStep(m,'unknown');assert.equal(m.get('draft-step-disabled').disabled,true);assert(!m.get('draft-step-context').textContent.includes('\0'));assert(m.get('draft-step-context').textContent.length<700);assert(m.get('draft-step-select').children.every(e=>e.textContent.length<700&&!e.textContent.includes('\0')));
 assert.deepEqual(toTypedTree(decodeImport(await generate(m)).value),toTypedTree(value));
});
test('last source read inside step write cannot reuse a superseded render or replacement source',async()=>{
 const {mountDraftEditor}=await import('../Web/editor/render.mjs');for(const replacement of [false,true]){
  const h=host(),get=id=>find(h.root,id),accepted=value=>({decode:{ok:true,kind:'legacy',value,original:encodeExport(value).text}});let source=accepted(decodeImport(stepWire()).value),controller,armed=false,reads=0;const sentinel=h.d.createElement('input');
  controller=mountDraftEditor(h.d,h.root,{schemaText,readSource(){if(armed&&++reads===2){armed=false;if(replacement){source=accepted(decodeImport(stepWire()).value);controller.retire();get('draft-discard').click();get('edit-copy').click();}else controller.refresh();sentinel.focus();}return source;}});
  await get('edit-copy').click();get('draft-step-select').value='nested';await get('draft-step-select').fire('change');get('draft-step-disabled').value='true';armed=true;await get('draft-step-disabled').fire('change');assert.equal(h.d.activeElement,sentinel);await get('draft-review').click();await get('draft-generate').click();assert.equal(decodeImport(get('draft-output').value).value.get('rotation').get(1).get('onTrue').get(1).has('disabled'),false);controller.dispose();
 }
});
test('new step handlers recheck visibility after action callbacks before selecting paging or writing',async()=>{
 const {mountDraftEditor}=await import('../Web/editor/render.mjs');for(const event of ['select','next','state']){
  const h=host(),get=id=>find(h.root,id),value=decodeImport(stepWire(105)).value,source={decode:{ok:true,kind:'legacy',value,original:encodeExport(value).text}};let armed=false,visible=true;const sentinel=h.d.createElement('input');const controller=mountDraftEditor(h.d,h.root,{schemaText,readSource:()=>source,isVisible:()=>visible,onAction(){if(armed){armed=false;visible=false;sentinel.focus();}}});await get('edit-copy').click();if(event==='state'){get('draft-step-select').value='nested';await get('draft-step-select').fire('change');}get('draft-step-select').value='nested';get('draft-step-disabled').value='true';armed=true;if(event==='select')await get('draft-step-select').fire('change');else if(event==='next')await get('draft-step-next').click();else await get('draft-step-disabled').fire('change');assert.equal(h.d.activeElement,sentinel);visible=true;await get('draft-review').click();await get('draft-generate').click();assert.equal(decodeImport(get('draft-output').value).value.get('rotation').get(1).get('onTrue').get(1).has('disabled'),false);assert.equal(get('draft-step-prev').disabled,true);controller.dispose();
 }
});
