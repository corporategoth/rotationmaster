import {decodeImport} from '../codec/import.mjs';
import {LIMITS,checkPortable} from '../codec/lua-data.mjs';
import {diffRotations} from '../schema/diff.mjs';
import {validateBody,validateEnvelope,indexRotationSteps} from '../schema/rotation.mjs';

// Compose the reviewed public I2 contract; never infer native/provider context.
export function createSchemaAnalyzer(catalogText){
  return decoded=>{
    const validation=decoded.kind==='envelope'?validateEnvelope(decoded.value,catalogText):validateBody(decoded.value,catalogText);
    if(validation.diagnostics.some(d=>d.code==='invalid-catalog'))throw Error('schema-unavailable');
    const value=decoded.kind==='envelope'?decoded.value.get('body'):decoded.value;
    const body=value instanceof Map?value:null;
    const recognized=decoded.kind!=='envelope'||decoded.value.get('schemaVersion')===1;
    const indexed=validation.valid&&body&&recognized?indexRotationSteps(body,{allowUnknownBranchFields:true}):null;
    return {validation,body,index:indexed?.ok?indexed.index:null,recognized};
  };
}
// This is a viewer-owned injection seam, not an implementation of I2 validation.
function analysisShape(value){
  const v=value?.validation;
  return v&&['valid','supported','resolved'].every(k=>typeof v[k]==='boolean')
    &&Array.isArray(v.diagnostics)&&v.diagnostics.length<=100
    &&(value.body===null||value.body instanceof Map)&&(value.index===null||Array.isArray(value.index?.rows)&&value.index.rows.length<=2000);
}
export function createViewerSession({analyze}={}){
  let input='',result=null,revision=0,oversized=false;
  return {
    edit(text){revision++;result=null;oversized=typeof text==='string'&&text.length>LIMITS.input;input=typeof text==='string'&&!oversized?text:'';},
    clear(){revision++;input='';oversized=false;result=null;},
    input(){return input;},view(){return result;},original(){return result?.decode.ok?result.decode.original:null;},
    decode(){
      const token=++revision;result=null;
      const decoded=oversized?{ok:false,reason:'import-size-limit'}:decodeImport(input);
      let analysis=null,structureMessage='Structure not checked: schema bridge not connected.';
      if(decoded.ok&&typeof analyze==='function'){
        try{const value=analyze(decoded);if(analysisShape(value)){analysis=value;structureMessage=value.recognized===false?'Unsupported envelope schema. Structure and references were not checked.':'Declarative structure only; native availability is unverified.';}
          else structureMessage='Structure unavailable: schema bridge result was not usable.';}
        catch{structureMessage='Structure unavailable: schema bridge could not inspect this data.';}
      }
      if(token!==revision)return null;
      result={decode:decoded,analysis,structureMessage};return result;
    }
  };
}
// Generated data has source authority, never transport/original-copy authority.
export function createBundledViewerSession({catalog,analyze}={}){
  let active=true,revision=0,result=null;
  const live=token=>active&&token===revision;
  const read=(object,key,token)=>{if(!live(token))throw Error('retired-selection');const value=object?.[key];if(!live(token))throw Error('retired-selection');return value;};
  function usableAnalysis(value,token){
    const validation=read(value,'validation',token);if(!validation)return false;
    for(const key of ['valid','supported','resolved'])if(typeof read(validation,key,token)!=='boolean')return false;
    const diagnostics=read(validation,'diagnostics',token);if(!Array.isArray(diagnostics)||diagnostics.length>100)return false;
    const body=read(value,'body',token);if(body!==null&&!(body instanceof Map))return false;
    const index=read(value,'index',token);if(index!==null){const rows=read(index,'rows',token);if(!Array.isArray(rows)||rows.length>2000)return false;}
    return true;
  }
  return {
    select(id){
      if(!active)return null;const token=++revision;result=null;
      try{
        const get=read(catalog,'get',token);if(!live(token)||typeof get!=='function')return null;
        const selected=get.call(catalog,id);if(!live(token))return null;
        const ok=read(selected,'ok',token);if(ok!==true)return null;
        const value=read(selected,'envelope',token);if(!(value instanceof Map)||!checkPortable(value).ok)return null;
        const rawSource=read(selected,'source',token),rawDisplay=read(selected,'display',token);
        const source={path:read(rawSource,'path',token),sha256:read(rawSource,'sha256',token)},display={};
        for(const key of ['nameKey','descriptionKey','name','description'])display[key]=read(rawDisplay,key,token);
        if(!live(token)||typeof source.path!=='string'||typeof source.sha256!=='string'||!Object.values(display).every(x=>typeof x==='string'))return null;
        let analysis=null,structureMessage='Structure unavailable: schema bridge not connected.';
        if(typeof analyze==='function'){
          let checked;try{checked=analyze({kind:'envelope',value});}catch{}if(!live(token))return null;
          if(usableAnalysis(checked,token)){const recognized=read(checked,'recognized',token);analysis=checked;structureMessage=recognized===false?'Unsupported envelope schema. Structure and references were not checked.':'Declarative structure only; native availability is unverified.';}
          else structureMessage='Structure unavailable: schema bridge result was not usable.';
        }
        if(!live(token))return null;
        result={sourceKind:'bundled',value,source,display,analysis,structureMessage};return result;
      }catch{if(live(token))result=null;return null;}
    },
    clear(){revision++;result=null;},view(){return active?result:null;},
    dispose(){active=false;revision++;result=null;}
  };
}
// Shared policy keeps the established import accessor/callback order. Only
// the new source controller supplies a guard around callback-capable reads.
const apply=Reflect.apply;
const retiredComparison={};
function comparisonField(object,key,guard){
  if(guard&&!guard())throw retiredComparison;const value=object[key];
  if(guard&&!guard())throw retiredComparison;return value;
}
function comparisonEvery(items,callback,guard){return apply(comparisonField(items,'every',guard),items,[callback]);}
function eligibleImport(view,side,guard){
  const f=(o,k)=>comparisonField(o,k,guard);
  if(!(view===null||view===undefined?undefined:f(f(view,'decode'),'ok')))return {status:'unavailable',reason:'decode-required',side};
  if(!f(view,'analysis'))return {status:'unavailable',reason:'schema-unavailable',side};
  if(f(f(view,'analysis'),'recognized')===false||f(f(view,'decode'),'kind')==='envelope'&&(Map.prototype.get.call(f(f(view,'decode'),'value'),'schemaVersion')!==1||f(f(view,'analysis'),'recognized')!==true))return {status:'unavailable',reason:'future-schema',side};
  if(f(f(f(view,'analysis'),'validation'),'valid')!==true)return {status:'unavailable',reason:'invalid-structure',side};
  if(f(f(view,'decode'),'kind')==='envelope')return {value:f(f(view,'decode'),'value'),legacy:false};
  const value=f(f(view,'decode'),'value');
  if(!(value instanceof Map)||!['rotation','cooldowns'].some(key=>Map.prototype.get.call(value,key) instanceof Map))return {status:'unavailable',reason:'unrecognized-legacy',side};
  return {value:new Map([['body',value]]),legacy:true};
}
function denseComparison(items,limit,guard){if(!Array.isArray(items)||comparisonField(items,'length',guard)>limit)return false;for(let i=0;i<comparisonField(items,'length',guard);i++)if(!Object.hasOwn(items,i))return false;return true;}
function usableComparison(diff,guard){
  const f=(o,k)=>comparisonField(o,k,guard);
  return diff&&typeof f(diff,'valid')==='boolean'&&typeof f(diff,'complete')==='boolean'
    &&denseComparison(f(diff,'changes'),500,guard)&&denseComparison(f(diff,'diagnostics'),100,guard)
    &&comparisonEvery(f(diff,'diagnostics'),d=>d&&typeof f(d,'code')==='string'&&typeof f(d,'path')==='string',guard)
    &&comparisonEvery(f(diff,'changes'),c=>c&&['added','removed','changed','moved'].includes(f(c,'kind'))&&typeof f(c,'path')==='string'&&f(c,'path').length<=4096
      &&denseComparison(f(c,'segments'),64,guard)&&comparisonEvery(f(c,'segments'),s=>s&&['field','step'].includes(f(s,'kind'))&&checkPortable(f(s,'key')).ok&&(typeof f(s,'key')==='string'||f(s,'kind')==='field'&&Number.isInteger(f(s,'key'))&&f(s,'key')>=1),guard)
      &&['fromIndex','toIndex'].every(k=>f(c,k)===undefined||Number.isInteger(f(c,k))&&f(c,k)>=1&&f(c,k)<=2000)
      &&(f(c,'stepId')===undefined||typeof f(c,'stepId')==='string')
      &&['before','after'].every(k=>!Object.hasOwn(c,k)||checkPortable(f(c,k)).ok),guard);
}
// Pair authority is separate from either source's accepted decode. No raw input
// is decoded by Compare, and no inspection-only index authorizes strict diff.
export function createComparisonSession({analyze,compare=diffRotations}={}){
  const sessions={left:createViewerSession({analyze}),right:createViewerSession({analyze})};
  let active=true,generation=0,result=null;
  const retire=()=>{generation++;result=null;};
  const panes={};for(const side of ['left','right']){const session=sessions[side];panes[side]={
    edit(text){if(active){retire();session.edit(text);}},clear(){if(active){retire();session.clear();}},
    decode(){if(!active)return null;retire();return session.decode();},
    input(){return active?session.input():'';},view(){return active?session.view():null;},original(){return active?session.original():null;}
  };}
  return {
    pane(side){if(!Object.hasOwn(panes,side))throw new TypeError('invalid-viewer-side');return panes[side];},
    view(){return active?result:null;},
    compare(){
      if(!active)return null;const token=++generation;result=null;
      const leftView=sessions.left.view(),rightView=sessions.right.view();
      let left,right;
      try{left=eligibleImport(leftView,'left');right=eligibleImport(rightView,'right');}catch{left={status:'unavailable',reason:'comparison-failed'};}
      if(!active||token!==generation||sessions.left.view()!==leftView||sessions.right.view()!==rightView)return null;
      if(left.status||right?.status){result=left.status?left:right;return result;}
      let value;
      try{const diff=compare(left.value,right.value);value=usableComparison(diff)?{status:diff.valid?(diff.complete?'complete':'partial'):'unavailable',diff,mixed:left.legacy!==right.legacy}: {status:'unavailable',reason:'comparison-failed'};}
      catch{value={status:'unavailable',reason:'comparison-failed'};}
      if(!active||token!==generation||sessions.left.view()!==leftView||sessions.right.view()!==rightView)return null;
      result=value;return result;
    },
    dispose(){if(!active)return;active=false;retire();sessions.left.clear();sessions.right.clear();}
  };
}
// First-import versus generated selection is a separate authority; it neither
// edits a source nor adopts the existing two-import comparison session.
export function createBundledComparisonSession({readImport,readBundled,compare=diffRotations}={}){
  let active=true,generation=0,pending=null;
  const live=token=>active&&token===generation;
  function observe(token){
    const snapshot={left:null,right:null,leftFailed:false,rightFailed:false};
    for(const [side,reader]of [['left',readImport],['right',readBundled]]){
      if(!live(token))throw retiredComparison;
      try{snapshot[side]=typeof reader==='function'?reader():null;}catch{snapshot[side+'Failed']=true;}
      if(!live(token))throw retiredComparison;
    }return snapshot;
  }
  const equalSources=(a,b)=>a.leftFailed===b.leftFailed&&a.rightFailed===b.rightFailed&&a.left===b.left&&a.right===b.right;
  function matches(token,snapshot){
    if(!live(token))return false;const current=observe(token);if(!equalSources(current,snapshot))return false;
    // A reader may reenter and change its opposite source. Confirm the pair
    // again after both callbacks rather than certifying an earlier left read.
    const confirmed=observe(token);return live(token)&&equalSources(confirmed,snapshot);
  }
  function bundledEligible(view,guard){
    const f=(o,k)=>comparisonField(o,k,guard),side='right';
    if(!view||f(view,'sourceKind')!=='bundled')return {status:'unavailable',reason:'decode-required',side};
    const value=f(view,'value');if(!(value instanceof Map))return {status:'unavailable',reason:'invalid-structure',side};
    const analysis=f(view,'analysis');if(!analysis)return {status:'unavailable',reason:'schema-unavailable',side};
    if(Map.prototype.get.call(value,'schemaVersion')!==1||f(analysis,'recognized')!==true)return {status:'unavailable',reason:'future-schema',side};
    const validation=f(analysis,'validation');if(!validation||f(validation,'valid')!==true)return {status:'unavailable',reason:'invalid-structure',side};
    return {value,legacy:false};
  }
  function context(view,guard){
    if(!view)return {importSide:'left',bundled:null};const f=(o,k)=>comparisonField(o,k,guard);
    if(f(view,'sourceKind')!=='bundled')return {importSide:'left',bundled:null};
    const value=f(view,'value');if(!(value instanceof Map))return {importSide:'left',bundled:null};
    const id=Map.prototype.get.call(value,'id'),revision=Map.prototype.get.call(value,'revision'),source=f(view,'source'),display=f(view,'display');
    if(!source||!display)return {importSide:'left',bundled:null};const path=f(source,'path'),name=f(display,'name');
    if(typeof id!=='string'||typeof path!=='string'||typeof name!=='string')return {importSide:'left',bundled:null};
    return {importSide:'left',bundled:{id,revision,path,name}};
  }
  const stamp=(value,sourceContext)=>({...value,comparisonKind:'import-bundled',sourceContext});
  return {
    compare(){
      if(!active)return null;const token=++generation;pending=null;let snapshot,sourceContext={importSide:'left',bundled:null},value;
      try{
        snapshot=observe(token);const guard=()=>matches(token,snapshot);if(!guard())return null;
        sourceContext=context(snapshot.right,guard);
        if(snapshot.leftFailed||snapshot.rightFailed)value={status:'unavailable',reason:'comparison-failed',side:snapshot.leftFailed?'left':'right'};
        else{
          const left=eligibleImport(snapshot.left,'left',guard),right=bundledEligible(snapshot.right,guard);if(!guard())return null;
          if(left.status||right.status)value=left.status?left:right;
          else{
            const diff=compare(left.value,right.value);if(!guard())return null;
            if(usableComparison(diff,guard))value={status:comparisonField(diff,'valid',guard)?(comparisonField(diff,'complete',guard)?'complete':'partial'):'unavailable',diff,mixed:left.legacy!==right.legacy};
            else value={status:'unavailable',reason:'comparison-failed'};
          }
        }
        if(!guard())return null;
      }catch(error){if(error===retiredComparison||!live(token))return null;value={status:'unavailable',reason:'comparison-failed'};}
      if(!live(token))return null;try{if(snapshot&&!matches(token,snapshot))return null;}catch{return null;}
      const result=stamp(value,sourceContext);pending={snapshot,result};return result;
    },
    clear(){generation++;pending=null;},
    view(){
      if(!active||!pending)return null;const current=pending,token=generation;
      try{if(!matches(token,current.snapshot)){if(live(token)&&pending===current){generation++;pending=null;}return null;}}
      catch{if(live(token)&&pending===current){generation++;pending=null;}return null;}
      return live(token)&&pending===current?current.result:null;
    },
    dispose(){active=false;generation++;pending=null;}
  };
}
const escaped=c=>{const n=c.codePointAt(0);return n<=255?'\\x'+n.toString(16).toUpperCase().padStart(2,'0'):'\\u{'+n.toString(16).toUpperCase()+'}';};
export function formatBytes(value,{offset=0,limit=1024}={}){
  if(typeof value!=='string')return {text:'Not a byte string',remaining:0};
  offset=Number.isInteger(offset)?Math.max(0,Math.min(value.length,offset)):0;
  limit=Number.isInteger(limit)?Math.max(1,Math.min(4096,limit)):1024;
  const part=value.slice(offset,offset+limit);let text;
  try{text=new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(part,c=>c.charCodeAt(0)));}
  catch{text=Array.from(part,c=>c.charCodeAt(0)<128?c:escaped(c)).join('');}
  text=text.replace(/[\x00-\x1F\x7F-\x9F\u061C\u200B-\u200F\u2028-\u202E\u2060-\u206F\uFEFF]/gu,escaped);
  return {text,remaining:Math.max(0,value.length-offset-part.length)};
}
// Human labels are Unicode JSON text, not Lua byte strings. Array.from keeps
// valid astral pairs whole while lone surrogate code units remain visible.
export function formatUnicode(value,{offset=0,limit=1024}={}){
  if(typeof value!=='string')return {text:'Not Unicode text',remaining:0,total:0};
  const points=Array.from(value);offset=Number.isInteger(offset)?Math.max(0,Math.min(points.length,offset)):0;
  limit=Number.isInteger(limit)?Math.max(1,Math.min(4096,limit)):1024;
  const part=points.slice(offset,offset+limit).join('');
  return {text:part.replace(/[\x00-\x1F\x7F-\x9F\u061C\u200B-\u200F\u2028-\u202E\u2060-\u206F\uFEFF\uD800-\uDFFF]/gu,escaped),remaining:Math.max(0,points.length-offset-limit),total:points.length};
}
export function keyText(key){return typeof key==='number'?'number '+String(key):'bytes "'+formatBytes(key,{limit:80}).text+(key.length>80?'…':'')+'"';}
export function pathText(path){return '$'+path.map(k=>'['+keyText(k)+']').join('');}
export function valueText(value,limit=256){
  if(value instanceof Map)return 'Table ('+value.size+' entries)';
  if(typeof value==='string'){const p=formatBytes(value,{limit});return p.text+(p.remaining?'… ('+p.remaining+' more bytes)':'');}
  if(value===null)return 'nil';if(Object.is(value,-0))return '-0';return String(value);
}
// Traverses only inert, already-portable data. Never converts Maps to JS objects.
export function rawEntries(value){
  if(!(value instanceof Map))return [{path:[],value}];
  const rows=[],tasks=[{path:[],value}];
  while(tasks.length&&rows.length<20000){
    const row=tasks.pop();if(row.path.length)rows.push(row);
    if(row.value instanceof Map){
      const keys=[...row.value.keys()].sort((a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1);
      for(let i=keys.length-1;i>=0;i--)tasks.push({path:[...row.path,keys[i]],value:row.value.get(keys[i])});
    }
  }
  return rows;
}
