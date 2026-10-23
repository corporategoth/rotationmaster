// Server-side validation of a share upload. Uses exactly the modules the
// browser viewer uses: the bounded codec, the declarative rotation schema and
// the export-kind classifier. Nothing here evaluates imported data; custom Lua
// and HTML inside an export stay inert strings.
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {decodeImport} from '../codec/import.mjs';
import {validateEnvelope,validateBody} from '../schema/rotation.mjs';
import {classifyExport,KINDS,CLASSES,EDITIONS} from '../site/kinds.mjs';
import {scanExport} from '../site/risks.mjs';

export const SHARE_LIMITS=Object.freeze({
  titleMin:3,titleMax:120,
  descriptionMax:20000,
  exportBytes:262144,// 256 KiB of export text; the codec itself allows 2 MiB
  reportDetails:1000,
});
export const REPORT_REASONS=Object.freeze({spam:'Spam or advertising',malicious:'Harmful or malicious code',broken:'Broken or mislabelled',offensive:'Offensive content',other:'Something else'});

// English names of the bundled (Built In) rotations, keyed by their locale
// key, so a shared copy of a Built In rotation gets a readable name.
let bundledNames=null;
export function bundledName(nameKey){
  if(typeof nameKey!=='string'||!nameKey)return '';
  if(!bundledNames){
    bundledNames=new Map();
    try{for(const pack of JSON.parse(readFileSync(new URL('../catalog/defaults.json',import.meta.url),'utf8')).packs||[])
      if(typeof pack?.display?.nameKey==='string'&&typeof pack.display.name==='string')bundledNames.set(pack.display.nameKey,pack.display.name);}
    catch{}
  }
  return bundledNames.get(nameKey)||'';
}
let knownConditions=null;
function conditionIds(){
  if(!knownConditions)knownConditions=new Set(Object.keys(JSON.parse(readFileSync(new URL('../site/conditions.json',import.meta.url),'utf8')).conditions));
  return knownConditions;
}
const utf8Length=text=>Buffer.byteLength(text,'utf8');
const fail=(status,code,field)=>({ok:false,status,code,field});

function cleanLine(value){
  return value.normalize('NFC').replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩]/g,' ').replace(/\s+/g,' ').trim();
}
function cleanText(value){
  // Keep newlines/tabs for Markdown; drop other control and bidi-override characters.
  return value.normalize('NFC').replace(/\r\n?/g,'\n').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f-\u009f‪-‮⁦-⁩]/g,'').replace(/\n{4,}/g,'\n\n\n').trim();
}

/** Decode and classify an export string. Returns {ok,decoded,info,validation?} or a failure. */
export function inspectExport(text,{catalogText,maxBytes=SHARE_LIMITS.exportBytes}={}){
  if(typeof text!=='string')return fail(400,'export-required','export');
  const trimmed=text.trim();
  if(!trimmed)return fail(400,'export-required','export');
  if(utf8Length(trimmed)>maxBytes)return fail(413,'export-too-large','export');
  const decoded=decodeImport(trimmed);
  if(!decoded.ok)return {...fail(400,'export-undecodable','export'),reason:decoded.reason};
  const info=classifyExport(decoded.value);
  if(!info.ok)return {...fail(400,'export-unrecognized','export'),reason:info.reason};
  let validation=null;
  if(info.kind==='rotation'){
    if(typeof catalogText!=='string')return fail(500,'schema-unavailable','export');
    validation=decoded.kind==='envelope'?validateEnvelope(decoded.value,catalogText):validateBody(decoded.value,catalogText);
    if(validation.diagnostics.some(d=>d.code==='invalid-catalog'))return fail(500,'schema-unavailable','export');
    if(decoded.kind==='envelope'&&decoded.value.get('schemaVersion')!==1)return {...fail(400,'export-unsupported-schema','export'),reason:'unsupported-schema-version'};
    if(!validation.valid){
      const first=validation.diagnostics.find(d=>d.severity==='error')||validation.diagnostics[0];
      return {...fail(400,'export-invalid-structure','export'),reason:first?.code||'invalid-structure',path:first?.path||'$'};
    }
  }
  const risks=scanExport(decoded.value,info,{knownConditions:conditionIds()});
  return {ok:true,text:trimmed,decoded,info,validation,risks,sha256:createHash('sha256').update(trimmed,'utf8').digest('hex'),bytes:utf8Length(trimmed)};
}

/**
 * Validate an upload request body. Declared class/edition tags are accepted
 * from the uploader only where the export does not declare them itself; a
 * declared kind must match the detected kind.
 */
export function validateShareUpload(body,{catalogText,limits=SHARE_LIMITS}={}){
  if(!body||typeof body!=='object'||Array.isArray(body))return fail(400,'invalid-body');
  for(const key of Object.keys(body))if(!['title','description','export','kind','class','editions'].includes(key))return fail(400,'unknown-field',key);
  if(typeof body.title!=='string')return fail(400,'title-required','title');
  const title=cleanLine(body.title);
  if([...title].length<limits.titleMin)return fail(400,'title-too-short','title');
  if([...title].length>limits.titleMax)return fail(400,'title-too-long','title');
  if(body.description!==undefined&&typeof body.description!=='string')return fail(400,'invalid-description','description');
  const description=cleanText(body.description||'');
  if(description.length>limits.descriptionMax)return fail(413,'description-too-long','description');
  const inspected=inspectExport(body.export,{catalogText,maxBytes:limits.exportBytes});
  if(!inspected.ok)return inspected;
  const {info}=inspected;
  const name=info.name||bundledName(info.summary?.nameKey)||info.summary?.nameKey||'';
  if(body.kind!==undefined&&body.kind!==null&&body.kind!==''){
    if(!Object.hasOwn(KINDS,body.kind))return fail(400,'invalid-kind','kind');
    if(body.kind!==info.kind)return {...fail(400,'kind-mismatch','kind'),detected:info.kind};
  }
  let cls=null,classSource=null;
  if(info.declared.class){cls=info.declared.class;classSource='export';}
  if(body.class!==undefined&&body.class!==null&&body.class!==''){
    if(body.class!=='ANY'&&!CLASSES.includes(body.class))return fail(400,'invalid-class','class');
    if(cls&&body.class!==cls)return {...fail(400,'class-conflicts-with-export','class'),declared:cls};
    if(!cls){cls=body.class;classSource='uploader';}
  }
  let editions=info.declared.editions.slice(),editionSource=editions.length?'export':null;
  if(body.editions!==undefined&&body.editions!==null){
    if(!Array.isArray(body.editions)||body.editions.length>EDITIONS.length||!body.editions.every(e=>EDITIONS.includes(e)))return fail(400,'invalid-editions','editions');
    const wanted=[...new Set(body.editions)].sort();
    if(editionSource==='export'){
      if(wanted.length&&wanted.join()!==[...new Set(editions)].sort().join())return {...fail(400,'editions-conflict-with-export','editions'),declared:editions};
    }else if(wanted.length){editions=wanted;editionSource='uploader';}
  }
  editions=EDITIONS.filter(e=>editions.includes(e));
  return {ok:true,value:{title,description,export:inspected.text,sha256:inspected.sha256,bytes:inspected.bytes,
    kind:info.kind,format:info.format,name,cls,classSource,editions,editionSource,
    summary:{...info.summary,name,risks:inspected.risks,structure:inspected.validation?{valid:inspected.validation.valid,supported:inspected.validation.supported,resolved:inspected.validation.resolved}:null}}};
}

export function validateReport(body,{limits=SHARE_LIMITS}={}){
  if(!body||typeof body!=='object'||Array.isArray(body))return fail(400,'invalid-body');
  if(!Object.hasOwn(REPORT_REASONS,body.reason))return fail(400,'invalid-reason','reason');
  if(body.details!==undefined&&typeof body.details!=='string')return fail(400,'invalid-details','details');
  const details=cleanText(body.details||'');
  if(details.length>limits.reportDetails)return fail(413,'details-too-long','details');
  return {ok:true,value:{reason:body.reason,details}};
}
