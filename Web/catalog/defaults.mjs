// Bundled source declarations only. Hash/display metadata is provenance, not
// authentication. No native facts, callbacks, DOM, fetch, Lua or encoder.
import {checkPortable} from '../codec/lua-data.mjs';
import {validateEnvelope,indexRotationSteps} from '../schema/rotation.mjs';
const get=Map.prototype.get,set=Map.prototype.set,has=Map.prototype.has,keys=Map.prototype.keys;
const LIMIT=Object.freeze({text:8388608,packs:256,sources:512,depth:64,nodes:20000,string:262144,bytes:1048576});
const bad=()=>{throw new Error('invalid-bundled-catalog');};
const record=v=>v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.getPrototypeOf(v)===Object.prototype;
function closed(v,names){if(!record(v))return false;const fields=Object.keys(v);return fields.length===names.length&&fields.every(k=>names.includes(k));}
const ascii=s=>typeof s==='string'&&s.length>0&&/^[\x00-\x7f]+$/.test(s);
const id=s=>typeof s==='string'&&s.length>0&&s.length<=128&&/^[A-Za-z0-9][A-Za-z0-9._:\-]*$/.test(s);
const hash=s=>typeof s==='string'&&/^[0-9a-f]{64}$/.test(s);
function path(s){return typeof s==='string'&&s.length>0&&s.length<=LIMIT.string&&/^[A-Za-z0-9_./\-]+$/.test(s)&&!s.startsWith('/')&&s.split('/').every(x=>x!==''&&x!=='.'&&x!=='..');}
const textBytes=s=>new TextEncoder().encode(s).length;
function typed(root){
 let result,nodes=0,bytes=0;const tasks=[{node:root,depth:0,assign:v=>{result=v;}}];
 function scalar(node,key=false){
  if(!record(node)||typeof node.type!=='string')bad();
  if(node.type==='bytes'){
   if(!closed(node,['type','hex'])||typeof node.hex!=='string'||node.hex.length%2||node.hex.length/2>LIMIT.string||!/^[0-9a-f]*$/.test(node.hex))bad();
   const size=node.hex.length/2;bytes+=size;if(bytes>LIMIT.bytes)bad();
   const chunks=[];for(let i=0;i<node.hex.length;i+=8192){let part='';for(let j=i;j<Math.min(node.hex.length,i+8192);j+=2)part+=String.fromCharCode(Number.parseInt(node.hex.slice(j,j+2),16));chunks.push(part);}return chunks.join('');
  }
  if(node.type==='number'){
   if(!closed(node,['type','bits'])||typeof node.bits!=='string'||!/^[0-9a-f]{16}$/.test(node.bits))bad();
   const buf=new DataView(new ArrayBuffer(8));buf.setUint32(0,Number.parseInt(node.bits.slice(0,8),16));buf.setUint32(4,Number.parseInt(node.bits.slice(8),16));const n=buf.getFloat64(0);if(!Number.isFinite(n)||key&&(!Number.isInteger(n)||n<1))bad();return n;
  }
  if(key)bad();
  if(node.type==='boolean'){if(!closed(node,['type','value'])||typeof node.value!=='boolean')bad();return node.value;}
  if(node.type==='nil'){if(!closed(node,['type']))bad();return null;}
  bad();
 }
 while(tasks.length){
  const task=tasks.pop(),node=task.node;if(++nodes>LIMIT.nodes||task.depth>LIMIT.depth||!record(node))bad();
  if(node.type!=='table'){task.assign(scalar(node));continue;}
  if(!closed(node,['type','entries'])||!Array.isArray(node.entries))bad();
  nodes+=node.entries.length;if(nodes>LIMIT.nodes)bad();const out=new Map(),seen=new Set();task.assign(out);
  for(let i=node.entries.length-1;i>=0;i--){const pair=node.entries[i];if(!Array.isArray(pair)||pair.length!==2)bad();const key=scalar(pair[0],true);if(seen.has(key))bad();seen.add(key);tasks.push({node:pair[1],depth:task.depth+1,assign:v=>{set.call(out,key,v);}});}
 }
 if(!checkPortable(result).ok)bad();return result;
}
function copy(v,memo=new Map()){
 if(v instanceof Map){if(memo.has(v))return memo.get(v);const out=new Map();memo.set(v,out);for(const k of keys.call(v))set.call(out,k,copy(get.call(v,k),memo));return out;}
 if(Array.isArray(v))return v.map(x=>copy(x,memo));
 if(v!==null&&typeof v==='object'){const out={};for(const[k,x]of Object.entries(v))out[k]=copy(x,memo);return out;}return v;
}
function build(text,schema){
 if(typeof text!=='string'||text.length>LIMIT.text||textBytes(text)>LIMIT.text)bad();
 const input=JSON.parse(text);
 if(!closed(input,['format','version','scope','displayLocale','nativeAvailability','sourceFiles','packs'])||input.format!=='RotationMasterBundledDefaults'||input.version!==1||input.scope!=='declared-data-only'||input.displayLocale!=='enUS'||input.nativeAvailability!=='unverified'||!record(input.sourceFiles)||!Array.isArray(input.packs)||input.packs.length>LIMIT.packs)bad();
 const sourceNames=Object.keys(input.sourceFiles);if(sourceNames.length>LIMIT.sources||sourceNames.some(p=>!path(p)||!hash(input.sourceFiles[p])))bad();
 const items=new Map(),sources=new Set();
 for(const item of input.packs){
  if(!closed(item,['id','sourcePath','sourceSHA','display','envelope'])||!id(item.id)||items.has(item.id)||!path(item.sourcePath)||!item.sourcePath.startsWith('Defaults/')||!item.sourcePath.endsWith('.lua')||sources.has(item.sourcePath)||!hash(item.sourceSHA)||!Object.hasOwn(input.sourceFiles,item.sourcePath)||input.sourceFiles[item.sourcePath]!==item.sourceSHA)bad();
  const display=item.display;if(!closed(display,['nameKey','descriptionKey','name','description'])||!ascii(display.nameKey)||!ascii(display.descriptionKey)||typeof display.name!=='string'||typeof display.description!=='string'||display.name.length>LIMIT.string||display.description.length>LIMIT.string||textBytes(display.name)>LIMIT.string||textBytes(display.description)>LIMIT.string)bad();
  const envelope=typed(item.envelope);if(!(envelope instanceof Map)||get.call(envelope,'format')!=='RotationMaster'||get.call(envelope,'schemaVersion')!==1||get.call(envelope,'id')!==item.id||get.call(envelope,'nameKey')!==display.nameKey||get.call(envelope,'descriptionKey')!==display.descriptionKey)bad();
  const validation=validateEnvelope(envelope,schema);if(validation.diagnostics.some(d=>d.code==='invalid-catalog'))throw new Error('schema-unavailable');
  if(!validation.valid||!indexRotationSteps(get.call(envelope,'body')).ok)bad();
  items.set(item.id,{envelope,display,validation,source:{path:item.sourcePath,sha256:item.sourceSHA}});sources.add(item.sourcePath);
 }
 const names=[...items.keys()].sort();
 // All private bases came from bounded JSON and actual I1/I2 validation. No
 // caller receives them or supplies a copying/iteration callback.
 const catalog=Object.freeze({
  list(){return names.map(name=>{const x=items.get(name);return{id:name,revision:get.call(x.envelope,'revision'),applicability:copy(get.call(x.envelope,'applicability')),tags:copy(get.call(x.envelope,'tags')??null),source:copy(x.source),display:copy(x.display),validation:copy(x.validation)};});},
  get(name){if(typeof name!=='string'||!items.has(name))return{ok:false,reason:'unknown-default'};const x=items.get(name);return{ok:true,envelope:copy(x.envelope),source:copy(x.source),display:copy(x.display),validation:copy(x.validation)};}
 });
 return {ok:true,catalog};
}
export function createBundledRotationCatalog(text,declarationCatalogText){
 if(typeof declarationCatalogText!=='string')return{ok:false,reason:'schema-unavailable'};
 try{
  const probe=validateEnvelope(new Map(),declarationCatalogText);if(probe.diagnostics.some(d=>d.code==='invalid-catalog'))return{ok:false,reason:'schema-unavailable'};
  return build(text,declarationCatalogText);
 }catch(error){return{ok:false,reason:error?.message==='schema-unavailable'?'schema-unavailable':'invalid-bundled-catalog'};}
}
