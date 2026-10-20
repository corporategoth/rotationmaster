import {decodeImport} from '../codec/import.mjs';
import {LIMITS} from '../codec/lua-data.mjs';
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
