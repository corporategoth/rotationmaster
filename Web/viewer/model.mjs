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
  function eligible(view,side){
    if(!view?.decode.ok)return {status:'unavailable',reason:'decode-required',side};
    if(!view.analysis)return {status:'unavailable',reason:'schema-unavailable',side};
    if(view.analysis.recognized===false||view.decode.kind==='envelope'&&(Map.prototype.get.call(view.decode.value,'schemaVersion')!==1||view.analysis.recognized!==true))return {status:'unavailable',reason:'future-schema',side};
    if(view.analysis.validation.valid!==true)return {status:'unavailable',reason:'invalid-structure',side};
    if(view.decode.kind==='envelope')return {value:view.decode.value,legacy:false};
    const value=view.decode.value;
    if(!(value instanceof Map)||!['rotation','cooldowns'].some(key=>Map.prototype.get.call(value,key) instanceof Map))return {status:'unavailable',reason:'unrecognized-legacy',side};
    return {value:new Map([['body',value]]),legacy:true};
  }
  function dense(items,limit){if(!Array.isArray(items)||items.length>limit)return false;for(let i=0;i<items.length;i++)if(!Object.hasOwn(items,i))return false;return true;}
  function usable(diff){
    return diff&&typeof diff.valid==='boolean'&&typeof diff.complete==='boolean'
      &&dense(diff.changes,500)&&dense(diff.diagnostics,100)
      &&diff.diagnostics.every(d=>d&&typeof d.code==='string'&&typeof d.path==='string')
      &&diff.changes.every(c=>c&&['added','removed','changed','moved'].includes(c.kind)&&typeof c.path==='string'&&c.path.length<=4096
        &&dense(c.segments,64)&&c.segments.every(s=>s&&['field','step'].includes(s.kind)&&checkPortable(s.key).ok&&(typeof s.key==='string'||s.kind==='field'&&Number.isInteger(s.key)&&s.key>=1))
        &&['fromIndex','toIndex'].every(k=>c[k]===undefined||Number.isInteger(c[k])&&c[k]>=1&&c[k]<=2000)
        &&(c.stepId===undefined||typeof c.stepId==='string')
        &&['before','after'].every(k=>!Object.hasOwn(c,k)||checkPortable(c[k]).ok));
  }
  return {
    pane(side){if(!Object.hasOwn(panes,side))throw new TypeError('invalid-viewer-side');return panes[side];},
    view(){return active?result:null;},
    compare(){
      if(!active)return null;const token=++generation;result=null;
      const leftView=sessions.left.view(),rightView=sessions.right.view();
      let left,right;
      try{left=eligible(leftView,'left');right=eligible(rightView,'right');}catch{left={status:'unavailable',reason:'comparison-failed'};}
      if(!active||token!==generation||sessions.left.view()!==leftView||sessions.right.view()!==rightView)return null;
      if(left.status||right?.status){result=left.status?left:right;return result;}
      let value;
      try{const diff=compare(left.value,right.value);value=usable(diff)?{status:diff.valid?(diff.complete?'complete':'partial'):'unavailable',diff,mixed:left.legacy!==right.legacy}: {status:'unavailable',reason:'comparison-failed'};}
      catch{value={status:'unavailable',reason:'comparison-failed'};}
      if(!active||token!==generation||sessions.left.view()!==leftView||sessions.right.view()!==rightView)return null;
      result=value;return result;
    },
    dispose(){if(!active)return;active=false;retire();sessions.left.clear();sessions.right.clear();}
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
