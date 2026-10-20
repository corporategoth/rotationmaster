// Pure two-way data comparison, not validation of gameplay or executable source.
// Byte strings and table keys retain I1 semantics. Display paths deliberately
// use the actual LuaJIT oracle's %q spelling; typed segments carry identity.
import {checkPortable} from '../codec/lua-data.mjs';
import {indexRotationSteps} from './rotation.mjs';
const mapGet=Map.prototype.get,mapKeys=Map.prototype.keys,mapSet=Map.prototype.set;
const get=(v,k)=>{const x=mapGet.call(v,k);return x===null?undefined:x;};
const nil=v=>v===null||v===undefined;
const truth=v=>!nil(v)&&v!==false;
const isMap=v=>{try{mapKeys.call(v);return true;}catch{return false;}};
const kind=v=>nil(v)?'nil':isMap(v)?'table':typeof v;
const orderedKeys=v=>[...mapKeys.call(v)].sort((a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1);
const identifier=v=>typeof v==='string'&&v.length>0&&v.length<=128&&/^[A-Za-z0-9][A-Za-z0-9._:\-]*$/.test(v);
const failure=(code,path='$')=>({valid:false,complete:false,changes:[],diagnostics:[{code,path,severity:'error'}]});
function portable(v){
 const checked=checkPortable(v);if(checked.ok)return checked;
 // The held index replays failed portability to render original Lua numeric
 // diagnostic paths. It returns before inspecting a nonportable body.
 const result=indexRotationSteps(v);return {...checked,path:result.diagnostic.path};
}
function optionsFrom(value){
 if(value===undefined)return {};
 if(!value||typeof value!=='object')return null;
 try{
  if(Object.getPrototypeOf(value)!==Object.prototype)return null;
  const fields=Object.getOwnPropertyDescriptors(value),out={};
  for(const key of Reflect.ownKeys(fields)){
   if(!['leftOrigins','rightOrigins','ignoreIdentity'].includes(key)||!('value'in fields[key]))return null;
   const v=fields[key].value;
   if(key==='ignoreIdentity'&&typeof v!=='boolean'||key!=='ignoreIdentity'&&!nil(v)&&!isMap(v)&&typeof v==='object')return null;
   out[key]=v;
  }
  return out;
 }catch{return null;}
}
// Positive integral Lua keys use %.14g concatenation. Preserve represented
// integer bits before decimal rounding, including integers above 2^53.
function numberText(n){
 let value=BigInt(n),digits=value.toString(),exponent=digits.length-1;
 if(digits.length>14){const scale=10n**BigInt(digits.length-14);let rounded=value/scale;const rem=value%scale;if(rem*2n>scale||rem*2n===scale&&rounded%2n===1n)rounded++;
  digits=rounded.toString();if(digits.length>14){exponent++;digits=digits.slice(0,-1);}}
 if(exponent<14)return digits;
 digits=digits.replace(/0+$/,'');return digits[0]+(digits.length>1?'.'+digits.slice(1):'')+'e+'+String(exponent).padStart(2,'0');
}
function quote(bytes){
 let text='"';for(let i=0;i<bytes.length;i++){
  const c=bytes.charCodeAt(i);if(c===34||c===92||c===10)text+='\\'+bytes[i];
  else if(c<32||c===127){let digits=String(c);if(i+1<bytes.length&&/[0-9]/.test(bytes[i+1]))digits=digits.padStart(3,'0');text+='\\'+digits;}
  else text+=bytes[i];
 }return text+'"';
}
const suffix=k=>typeof k==='number'?'['+numberText(k)+']':/^[A-Za-z_][A-Za-z_0-9]*$/.test(k)?'.'+k:'['+quote(k)+']';
function copy(value,copies=new Map()){
 if(!isMap(value))return value;if(copies.has(value))return copies.get(value);
 const out=new Map();copies.set(value,out);for(const key of mapKeys.call(value))mapSet.call(out,key,copy(mapGet.call(value,key),copies));return out;
}
function index(list,origins,path){
 if(nil(list))list=new Map();if(!isMap(list))return {error:['invalid-priority-list',path]};
 if(!nil(origins)&&!isMap(origins))return {error:['invalid-origin-map',path]};
 const keys=orderedKeys(list);if(keys.some((k,i)=>typeof k!=='number'||k!==i+1))return {error:['invalid-priority-list',path]};
 const result={ordered:[],byId:new Map()};
 for(let i=1;i<=keys.length;i++){
  const step=get(list,i),id=isMap(step)?get(step,'id'):undefined;
  if(!identifier(id))return {error:['ambiguous-step-identity',path+'['+i+']']};
  const origin=origins&&get(origins,id),canonical=truth(origin)?origin:id;
  if(!identifier(canonical)||result.byId.has(canonical))return {error:['ambiguous-step-identity',path+'['+i+']']};
  const entry={id:canonical,index:i,value:step};result.ordered.push(entry);result.byId.set(canonical,entry);
 }
 return result;
}
function stationary(left,right){
 const sequence=[];for(const entry of right.ordered){const previous=left.byId.get(entry.id);if(previous)sequence.push({id:entry.id,position:previous.index});}
 const tails=[],tailIndices=[],previous=[];
 for(let i=0;i<sequence.length;i++){
  let low=0,high=tails.length-1;while(low<=high){const middle=Math.floor((low+high)/2);if(tails[middle]<sequence[i].position)low=middle+1;else high=middle-1;}
  previous[i]=tailIndices[low-1];tails[low]=sequence[i].position;tailIndices[low]=i;
 }
 const result=new Set();let cursor=tailIndices[tails.length-1];while(cursor!==undefined){result.add(sequence[cursor].id);cursor=previous[cursor];}return result;
}
// Inputs are envelope-like Maps, not auto-detected legacy-body wrappers. Missing
// or primitive .body is indexed as empty but still compared as an ordinary field.
// Only body.revision is always nonsemantic; root id/revision need ignoreIdentity.
// Options are a closed source-owned descriptor bag, not a proxy/security sandbox.
// Bounds: portable64/20k/1MiB per input, index2000/depth16, changes500/path4096.
// valid/complete describe comparison coverage, never native readiness/quality.
export function diffRotations(left,right,rawOptions){
 const options=optionsFrom(rawOptions);if(!options)return failure('invalid-options');
 for(const value of [left,right]){const checked=portable(nil(value)?null:value);if(!checked.ok)return failure(checked.reason,checked.path);if(!isMap(value))return failure('expected-rotation-object');}
 const lists={left:new Map(),right:new Map()},empty=index(undefined,undefined,'$');
 for(const side of ['left','right']){
  const envelope=side==='left'?left:right,origins=options[side+'Origins'];
  if(!portable(nil(origins)?null:origins).ok||!nil(origins)&&!isMap(origins))return failure('invalid-origin-map');
  const rawBody=get(envelope,'body'),body=isMap(rawBody)?rawBody:new Map();
  for(const section of ['rotation','cooldowns']){const indexed=index(get(body,section),origins,'$.body.'+section);if(indexed.error)return failure(...indexed.error);}
  const tree=indexRotationSteps(body);if(!tree.ok){let {code,path}=tree.diagnostic;if(code==='duplicate-step-id'||code==='invalid-step-id')code='ambiguous-step-identity';return failure(code,path);}
  const used=new Set();for(const owner of tree.index.lists){
   const indexed=index(owner.list,origins,'$.body');if(indexed.error)return failure(...indexed.error);
   for(const entry of indexed.ordered){if(used.has(entry.id))return failure('ambiguous-step-identity','$.body');used.add(entry.id);}lists[side].set(owner.list,indexed);
  }
 }
 const result={valid:true,complete:true,changes:[],diagnostics:[]},limits=new Set();
 const limited=code=>{result.complete=false;if(!limits.has(code)){limits.add(code);result.diagnostics.push({code,path:'$',severity:'warning'});}};
 const child=(segments,kind,key)=>[...segments,{kind,key}];
 function emit(kind,path,segments,before,after,extra={}){
  if(path.length>4096){limited('diff-path-limit');return;}if(result.changes.length>=500){limited('diff-change-limit');return;}
  const change={kind,path,segments:segments.map(s=>({...s}))};if(!nil(before))change.before=copy(before);if(!nil(after))change.after=copy(after);Object.assign(change,extra);result.changes.push(change);
 }
 function priorities(aList,bList,path,segments){
  const a=lists.left.get(aList)||empty,b=lists.right.get(bList)||empty,stable=stationary(a,b);
  for(const entry of a.ordered)if(!b.byId.has(entry.id))emit('removed',path+'['+entry.id+']',child(segments,'step',entry.id),entry.value,undefined,{stepId:entry.id,fromIndex:entry.index});
  for(const entry of b.ordered){const previous=a.byId.get(entry.id),at=path+'['+entry.id+']',where=child(segments,'step',entry.id);
   if(!previous)emit('added',at,where,undefined,entry.value,{stepId:entry.id,toIndex:entry.index});
   else{if(!stable.has(entry.id))emit('moved',at,where,undefined,undefined,{stepId:entry.id,fromIndex:previous.index,toIndex:entry.index});walk(previous.value,entry.value,at,where,true);}
  }
 }
 function walk(a,b,path,segments,step=false){
  if(path.length>4096){limited('diff-path-limit');return;}if(a===b||nil(a)&&nil(b))return;
  if(segments.length===2&&segments[0].kind==='field'&&segments[0].key==='body'&&segments[1].kind==='field'&&['rotation','cooldowns'].includes(segments[1].key)){priorities(a,b,path,segments);return;}
  if(kind(a)!=='table'||kind(b)!=='table'){emit(nil(a)?'added':nil(b)?'removed':'changed',path,segments,a,b);return;}
  const union=new Set([...mapKeys.call(a),...mapKeys.call(b)]),keys=[...union].sort((x,y)=>typeof x===typeof y?(x<y?-1:x>y?1:0):typeof x==='number'?-1:1);
  for(const key of keys){
   if(step&&key==='id'||segments.length===0&&options.ignoreIdentity&&(key==='id'||key==='revision')||segments.length===1&&segments[0].kind==='field'&&segments[0].key==='body'&&key==='revision')continue;
   const at=path+suffix(key),where=child(segments,'field',key);
   if(step&&(get(a,'type')==='branch'||get(b,'type')==='branch')&&(key==='onTrue'||key==='onFalse'))priorities(get(a,key),get(b,key),at,where);
   else walk(get(a,key),get(b,key),at,where);
  }
 }
 walk(left,right,'$',[]);return result;
}
