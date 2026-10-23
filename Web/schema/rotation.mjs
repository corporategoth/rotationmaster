// Declarative structure only. Never executes callbacks or certifies native facts.
// catalog is generated JSON TEXT, not an executable JS object. I1 byte strings
// and genuine Map tables remain unchanged. Reference sets describe data only.
import {checkPortable,LIMITS} from '../codec/lua-data.mjs';
const mapGet=Map.prototype.get,mapKeys=Map.prototype.keys,mapHas=Map.prototype.has;
const get=(v,k)=>{const x=mapGet.call(v,k);return x===null?undefined:x;};
const keys=v=>[...mapKeys.call(v)].sort((a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1);
const isMap=v=>{try{mapHas.call(v,0);return true;}catch{return false;}};
// Portable numeric keys are finite positive integers. Lua concatenation uses
// %.14g: decimal rounding to nearest/even, then general-format exponent rules.
// BigInt preserves the represented integer exactly, including halfway cases.
function keyText(key){
 if(typeof key!=='number')return key;
 let digits=BigInt(key).toString(),exponent=digits.length-1;
 if(digits.length>14){
  const scale=10n**BigInt(digits.length-14),value=BigInt(key);let head=value/scale;
  const remainder=value%scale;if(remainder*2n>scale||remainder*2n===scale&&head%2n===1n)head++;
  digits=head.toString();if(digits.length>14){exponent++;digits=digits.slice(0,-1);}
 }
 if(exponent<14)return digits;
 digits=digits.replace(/0+$/,'');
 return digits[0]+(digits.length>1?'.'+digits.slice(1):'')+'e+'+String(exponent).padStart(2,'0');
}
const location=(path,truncate=false)=>'$'+path.map(k=>typeof k==='number'?'['+keyText(k)+']':'.'+(truncate?k.slice(0,80):k)).join('');
// I1 remains the portability authority. Its rendered diagnostic path loses key
// boundaries, so replay only failures with the same finite counters/order to
// render Lua number text from the original keys; never parse opaque key strings.
function portable(value){
 const original=checkPortable(value);if(original.ok)return original;
 const active=new Set(),path=[],tasks=[{value,depth:0}];let nodes=0,bytes=0;
 const fail=()=>({...original,path:location(path,true)});
 const text=s=>{if(s.length>LIMITS.string)return false;for(let i=0;i<s.length;i++)if(s.charCodeAt(i)>255)return false;bytes+=s.length;return bytes<=LIMITS.bytes;};
 while(tasks.length){
  const task=tasks.pop();if(task.exit){active.delete(task.exit);continue;}if(task.pop){path.pop();continue;}
  if('key'in task){if(typeof task.key==='string'&&!text(task.key))return fail();path.push(task.key);tasks.push({pop:true},{value:mapGet.call(task.parent,task.key),depth:task.depth});continue;}
  if(++nodes>LIMITS.nodes||task.depth>LIMITS.depth)return fail();
  const v=task.value,t=typeof v;if(v===null||t==='boolean')continue;
  if(t==='string'){if(!text(v))return fail();continue;}
  if(t==='number'){if(!Number.isFinite(v))return fail();continue;}
  let iterator;try{iterator=mapKeys.call(v);}catch{return fail();}
  if(Object.getPrototypeOf(v)!==Map.prototype||active.has(v))return fail();active.add(v);
  const ks=[];for(const k of iterator){if(++nodes>LIMITS.nodes||typeof k!=='string'&&!(typeof k==='number'&&Number.isFinite(k)&&k>=1&&Number.isInteger(k)))return fail();ks.push(k);}
  ks.sort((a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1);tasks.push({exit:v});
  for(let i=ks.length-1;i>=0;i--)tasks.push({key:ks[i],parent:v,depth:task.depth+1});
 }
 return original;
}
const nil=v=>v===undefined||v===null;
const luaType=v=>nil(v)?'nil':isMap(v)?'table':typeof v;
const own=(v,k)=>Object.hasOwn(v,k);
const nonempty=v=>typeof v==='string'&&v.length>0;
const integer=(v,min)=>typeof v==='number'&&v>=min&&v%1===0;
const identifier=v=>nonempty(v)&&v.length<=128&&/^[A-Za-z0-9][A-Za-z0-9._:\-]*$/.test(v);
const dense=v=>isMap(v)&&keys(v).every((k,i)=>integer(k,1)&&k===i+1);
const values=v=>keys(v).map(k=>get(v,k));
const allowed=s=>new Set(s.split(' '));
const scopeLabel='declarative-structure-only';
function result(){return {valid:true,supported:true,resolved:true,diagnostics:[],semanticStatus:'not-evaluated',executionStatus:'unchecked',qualityStatus:'unreviewed',scope:scopeLabel,nativeAvailability:'unverified'};}
function failure(code,path='$'){const r=result();r.valid=false;r.supported=false;r.resolved=false;r.executionStatus='unavailable';r.diagnostics.push({code,path,severity:'error'});return r;}
function exact(v,names){return v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).every(k=>names.includes(k));}
function schemaOkay(value,root=false,depth=0,state={nodes:0}){
 if(depth>32||root&&(!value||typeof value!=='object'||Array.isArray(value)))return false;
 if(typeof value==='string')return ['string','number','boolean','condition','condition[]'].includes(value);
 if(!value||typeof value!=='object')return false;
 const names=Object.keys(value);state.nodes+=names.length;if(state.nodes>4096)return false;
 if(Array.isArray(value)){if(root||!value.length)return false;}
 else if(names.some(k=>!(/^[A-Za-z_][A-Za-z_0-9]*$/).test(k))||(!root&&!names.length))return false;
 return names.every(k=>schemaOkay(value[k],false,depth+1,state));
}
function catalogFrom(text){
 if(typeof text!=='string'||text.length>1048576)return null;
 let c;try{c=JSON.parse(text);}catch{return null;}
 if(!exact(c,['format','version','nativeAvailability','cases','conditions','logical','uiOnly','sourceFiles'])||c.format!=='RotationMasterDeclarativeCatalog'||c.version!==1||c.nativeAvailability!=='unverified')return null;
 if(!Array.isArray(c.logical)||c.logical.length!==3||c.logical[0]!=='AND'||c.logical[1]!=='OR'||c.logical[2]!=='NOT'||!Array.isArray(c.uiOnly)||c.uiOnly.length!==1||c.uiOnly[0]!=='DELETE')return null;
 if(!exact(c.sourceFiles,Object.keys(c.sourceFiles||{}))||!Object.keys(c.sourceFiles).length||Object.entries(c.sourceFiles).some(([p,h])=>!/^\w[\w./-]*$/.test(p)||p.split('/').includes('..')||typeof h!=='string'||!/^[0-9a-f]{64}$/.test(h)))return null;
 if(!Array.isArray(c.cases)||!c.cases.length||c.cases.length>64)return null;
 const cases=new Set();
 for(const row of c.cases){
  if(!exact(row,['id','project','expansion','class','mobInfoProbe'])||!nonempty(row.id)||cases.has(row.id)||!integer(row.project,1)||!integer(row.expansion,0)||!nonempty(row.class)||typeof row.mobInfoProbe!=='boolean')return null;
  cases.add(row.id);
 }
 if(!Array.isArray(c.conditions)||c.conditions.length!==125)return null;
 const byID=new Map();
 for(const row of c.conditions){
  if(!exact(row,['id','module','declarations'])||!nonempty(row.id)||byID.has(row.id)||['AND','OR','NOT','DELETE'].includes(row.id)||typeof row.module!=='string'||!/^Conditions\/[A-Za-z0-9_-]+\.lua$/.test(row.module)||!Array.isArray(row.declarations)||!row.declarations.length||row.declarations.length>64)return null;
  const observed=new Set(),variants=new Set();
  for(const d of row.declarations){
   if(!exact(d,['fields','requiredFields','cases','builtinSourceVariant','provider'])||!schemaOkay(d.fields,true)||!Array.isArray(d.requiredFields)||d.requiredFields.some(k=>typeof k!=='string'||!own(d.fields,k))||new Set(d.requiredFields).size!==d.requiredFields.length)return null;
   if(!Array.isArray(d.cases)||!d.cases.length||d.cases.some(id=>!cases.has(id)||observed.has(id)))return null;
   for(const id of d.cases)observed.add(id);
   const variant=d.builtinSourceVariant;
   if(variant!==undefined&&(typeof variant!=='string'||! /^[A-Za-z_][A-Za-z_0-9]{0,63}$/.test(variant))||variants.has(variant))return null;
   variants.add(variant);
   if(d.provider!==undefined&&!nonempty(d.provider))return null;
  }
  byID.set(row.id,row);
 }
 return {cases,byID};
}
function optionData(value,names){
 if(value===undefined)return {};
 if(!value||typeof value!=='object')return null;
 try{
  if(Object.getPrototypeOf(value)!==Object.prototype)return null;
  const descriptors=Object.getOwnPropertyDescriptors(value),out={};
  for(const[k,d]of Object.entries(descriptors)){if(!names.includes(k)||!('value'in d))return null;out[k]=d.value;}
  return out;
 }catch{return null;}
}
function optionsFrom(options,catalog){
 const out=optionData(options,['declarationCase','itemsets','effects']);if(!out)return null;
 if(out.declarationCase!==undefined&&(!catalog.cases.has(out.declarationCase)))return null;
 for(const k of ['itemsets','effects'])if(out[k]!==undefined){
  let iterator;try{iterator=Set.prototype.values.call(out[k]);if(Object.getPrototypeOf(out[k])!==Set.prototype)return null;}catch{return null;}
  let count=0;for(const id of iterator)if(typeof id!=='string'||id.length>262144||++count>20000)return null;
 }
 return out;
}
function declaration(catalog,id,which){
 const row=catalog.byID.get(id);if(!row)return {};
 const ds=which?row.declarations.filter(d=>d.cases.includes(which)):row.declarations;
 if(ds.length!==1)return {ambiguous:ds.length>1};
 if(ds[0].provider)return {};
 return {definition:ds[0]};
}
function matchesTable(value,schema,depth){
 if(depth>32||!isMap(value))return false;
 if(Array.isArray(schema))return dense(value)&&values(value).every(v=>matchesType(v,schema,depth+1));
 return keys(value).every(k=>own(schema,k)&&matchesType(get(value,k),schema[k],depth+1));
}
function matchesType(value,schema,depth=0){
 if(depth>32)return false;
 if(typeof schema==='string'){
  if(schema==='condition')return isMap(value);
  if(schema.endsWith('[]'))return dense(value)&&values(value).every(v=>matchesType(v,schema.slice(0,-2),depth+1));
  return luaType(value)===schema;
 }
 if(!Array.isArray(schema))return matchesTable(value,schema,depth+1);
 return schema.some(alt=>typeof alt==='object'?matchesTable(value,alt,depth+1):matchesType(value,alt,depth+1));
}
function tagsOkay(tags){
 if(!dense(tags)||keys(tags).length>64)return false;
 for(const tag of values(tags)){
  if(typeof tag!=='string'||/[\x00-\x1f\x7f]/.test(tag))return false;
  const s=tag.replace(/^[\x09-\x0d ]+|[\x09-\x0d ]+$/g,'');let count=0;
  for(let i=0;i<s.length;){
   const a=s.charCodeAt(i),b=s.charCodeAt(i+1);const width=a<128?1:a>=194&&a<=223?2:a>=224&&a<=239?3:a>=240&&a<=244?4:0;
   if(!width||i+width>s.length)return false;
   for(let j=i+1;j<i+width;j++)if(s.charCodeAt(j)<128||s.charCodeAt(j)>191)return false;
   if(a===194&&b>=128&&b<=159||width===3&&(a===224&&b<160||a===237&&b>=160)||width===4&&(a===240&&b<144||a===244&&b>=144))return false;
   count++;i+=width;
  }
  if(!count||count>64)return false;
 }
 return true;
}
const branchFields=allowed('id type mode name conditions onTrue onFalse');
const incompatible=allowed('action disabled ranked use_name suppress_attack effect color magnification setpoint xoffs yoffs announce announce_sound');
// Success retains input table references, matching Lua's read-only structural
// index. Rows/lists and their paths are fresh; no execution/owner seal is issued.
export function indexRotationSteps(body,options){
 options=optionData(options,['allowMissingIds','allowUnknownBranchFields']);
 if(!options||Object.values(options).some(v=>typeof v!=='boolean'))return {ok:false,diagnostic:{code:'invalid-options',path:'$',severity:'error'}};
 const checked=portable(body);if(!checked.ok)return {ok:false,diagnostic:{code:checked.reason,path:checked.path,severity:'error'}};
 const fail=(code,path)=>({ok:false,diagnostic:{code,path:location(path),severity:'error'}});
 if(!isMap(body))return fail('expected-rotation-object',[]);
 const index={rows:[],byId:new Map(),lists:[]};
 function walk(list,path,section,depth,parentId,arm,unreachable){
  if(!dense(list))return fail('invalid-priority-list',path);
  const owner={list,path:[...path],section,depth,unreachable:unreachable===true};if(parentId!==undefined)owner.parentId=parentId;if(arm!==undefined)owner.arm=arm;index.lists.push(owner);
  for(const key of keys(list)){
   const step=get(list,key),at=[...path,key];if(index.rows.length>=2000)return fail('rotation-node-limit',at);
   if(!isMap(step))return fail('expected-step-object',at);
   const id=get(step,'id');if(!identifier(id)&&!(nil(id)&&options.allowMissingIds===true))return fail('invalid-step-id',[...at,'id']);
   if(id!==undefined&&index.byId.has(id))return fail('duplicate-step-id',[...at,'id']);
   const row={step,path:at,section,index:key,ordinal:index.rows.length+1,depth,unreachable:unreachable===true};if(parentId!==undefined)row.parentId=parentId;if(arm!==undefined)row.arm=arm;
   index.rows.push(row);if(id!==undefined)index.byId.set(id,row);
   if(get(step,'type')==='branch'){
    if(section!=='rotation')return fail('branch-in-optional-list',at);if(depth>=16)return fail('rotation-depth-limit',at);
    const mode=get(step,'mode')??'evaluate';if(!['evaluate','true','false'].includes(mode))return fail('invalid-branch-mode',[...at,'mode']);
    for(const k of keys(step))if(!branchFields.has(k)&&(incompatible.has(k)||options.allowUnknownBranchFields!==true))return fail('unexpected-branch-field',[...at,k]);
    for(const[field,choice,excluded]of [['onTrue','true',mode==='false'],['onFalse','false',mode==='true']]){
     const child=get(step,field);if(nil(child))return fail('missing-branch-arm',[...at,field]);
     const bad=walk(child,[...at,field],section,depth+1,id,choice,unreachable||excluded);if(bad)return bad;
    }
   }
  }
 }
 for(const section of ['rotation','cooldowns']){const bad=walk(get(body,section)??new Map(),[section],section,0,undefined,undefined,false);if(bad)return bad;}
 return {ok:true,index};
}
function validate(envelope,catalogText,rawOptions,bodyOnly){
 const catalog=catalogFrom(catalogText);if(!catalog)return failure('invalid-catalog');
 const options=optionsFrom(rawOptions,catalog);if(!options)return failure('invalid-options');
 const r=result();
 function issue(code,path,severity='error',kind){if(severity==='error')r.valid=false;if(kind==='unsupported')r.supported=false;if(kind==='unresolved')r.resolved=false;if(r.diagnostics.length<100)r.diagnostics.push({code,path,severity});}
 const finish=()=>{if(!r.valid||!r.supported||!r.resolved)r.executionStatus='unavailable';return r;};
 const checked=portable(envelope);if(!checked.ok){issue(checked.reason,checked.path);return finish();}
 if(!isMap(envelope)){issue('expected-object','$');return finish();}
 function object(v,path){if(isMap(v))return true;issue(nil(v)?'missing-field':'expected-object',path);return false;}
 function list(v,path,required=false){if(nil(v)&&!required)return false;if(nil(v)){issue('missing-field',path);return false;}if(!dense(v)){issue(isMap(v)?'sparse-list':'expected-list',path);return false;}return true;}
 function check(v,predicate,path){if(!predicate(v)){issue(nil(v)?'missing-field':'invalid-field-value',path);return false;}return true;}
 function unknown(v,set,path){for(const k of keys(v))if(!set.has(k))issue('unknown-field',path+'.'+keyText(k),'warning','unsupported');}
 function optional(v,kind,path){if(!nil(v)&&luaType(v)!==kind)issue('invalid-field-type',path);}
 if(!bodyOnly){
  if(get(envelope,'format')!=='RotationMaster')issue('unsupported-format','$.format','warning','unsupported');
  const version=get(envelope,'schemaVersion');if(!check(version,v=>integer(v,1),'$.schemaVersion'))return finish();
  if(version!==1){issue('unsupported-schema-version','$.schemaVersion','warning','unsupported');return finish();}
  unknown(envelope,allowed('format schemaVersion id revision nameKey descriptionKey applicability tags sources body dependencies'),'$');
  check(get(envelope,'id'),identifier,'$.id');check(get(envelope,'revision'),v=>integer(v,1),'$.revision');check(get(envelope,'nameKey'),nonempty,'$.nameKey');check(get(envelope,'descriptionKey'),nonempty,'$.descriptionKey');
  const scope=get(envelope,'applicability');
  if(object(scope,'$.applicability')){
   unknown(scope,allowed('families actionContext class universal specs minLevel maxLevel roles intent minBuild maxBuild rulesets'),'$.applicability');
   const families=get(scope,'families');if(list(families,'$.applicability.families',true)){
    if(!keys(families).length)issue('empty-edition-scope','$.applicability.families');
    for(const k of keys(families)){const v=get(families,k),path=`$.applicability.families[${k}]`;if(check(v,nonempty,path)&&!['retail','era','progression','tbc','forever'].includes(v))issue('unknown-edition',path,'warning','unsupported');}
   }
   const context=get(scope,'actionContext');if(check(context,nonempty,'$.applicability.actionContext')&&!['player','pet','vehicle','possession','override','petbattle'].includes(context))issue('unknown-action-context','$.applicability.actionContext','warning','unsupported');
   const klass=get(scope,'class');if(!nil(klass)&&check(klass,nonempty,'$.applicability.class')&&!['WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','DEATHKNIGHT','SHAMAN','MAGE','WARLOCK','MONK','DRUID','DEMONHUNTER','EVOKER'].includes(klass))issue('unknown-class','$.applicability.class','warning','unsupported');
   optional(get(scope,'universal'),'boolean','$.applicability.universal');if(get(scope,'universal')===true&&!nil(klass))issue('conflicting-class-scope','$.applicability.universal');
   for(const[lo,hi]of [['minLevel','maxLevel'],['minBuild','maxBuild']]){
    for(const k of [lo,hi])if(!nil(get(scope,k)))check(get(scope,k),v=>integer(v,1),'$.applicability.'+k);
    if(integer(get(scope,lo),1)&&integer(get(scope,hi),1)&&get(scope,lo)>get(scope,hi))issue('inverted-range','$.applicability.'+hi);
   }
   for(const k of ['specs','roles','rulesets']){const v=get(scope,k);if(list(v,'$.applicability.'+k)){
    if(!keys(v).length)issue('empty-selector','$.applicability.'+k);
    for(const i of keys(v))check(get(v,i),k==='specs'?v=>integer(v,0):nonempty,`$.applicability.${k}[${i}]`);
   }}optional(get(scope,'intent'),'string','$.applicability.intent');
  }
  if(!nil(get(envelope,'tags'))&&!tagsOkay(get(envelope,'tags')))issue('invalid-tags','$.tags');
  if(list(get(envelope,'tags'),'$.tags'))for(const i of keys(get(envelope,'tags')))check(get(get(envelope,'tags'),i),nonempty,`$.tags[${i}]`);
  if(list(get(envelope,'sources'),'$.sources'))for(const i of keys(get(envelope,'sources'))){const source=get(get(envelope,'sources'),i),path=`$.sources[${i}]`;if(object(source,path)){
   unknown(source,allowed('url title reviewedAt revision notes'),path);check(get(source,'url'),v=>nonempty(v)&&/^https?:\/\/[^\x09-\x0d ]+$/.test(v),path+'.url');
   for(const k of ['title','reviewedAt','revision','notes'])optional(get(source,k),'string',path+'.'+keyText(k));
  }}
  const dependencies=get(envelope,'dependencies');if(list(dependencies,'$.dependencies')&&keys(dependencies).length)issue('unsupported-dependencies','$.dependencies','warning','unsupported');
 }
 let condition;
 function tableConditions(value,schema,path){
  if(Array.isArray(schema))for(const i of keys(value))declared(get(value,i),schema,`${path}[${i}]`);
  else for(const k of keys(value))declared(get(value,k),schema[k],path+'.'+keyText(k));
 }
 function declared(value,schema,path){
  if(schema==='condition')condition(value,path);
  else if(schema==='condition[]')for(const i of keys(value))condition(get(value,i),`${path}[${i}]`);
  else if(schema&&typeof schema==='object'){
   if(!Array.isArray(schema))tableConditions(value,schema,path);
   else for(const alt of schema){if(typeof alt==='object'){if(matchesTable(value,alt,0)){tableConditions(value,alt,path);return;}}else if(matchesType(value,alt)){declared(value,alt,path);return;}}
  }
 }
 condition=(value,path)=>{
  if(nil(value)||!object(value,path))return;if(!keys(value).length)return;
  const type=get(value,'type');if(!check(type,nonempty,path+'.type'))return;
  optional(get(value,'disabled'),'boolean',path+'.disabled');
  if(['AND','OR','NOT'].includes(type)){const name=get(value,'name');if(!nil(name)&&(typeof name!=='string'||name.length>512||/[\x00-\x1f\x7f]/.test(name)))issue('invalid-group-name',path+'.name');}
  if(type==='AND'||type==='OR'){
   unknown(value,allowed('type disabled value name'),path);const v=get(value,'value');if(list(v,path+'.value',true))for(const i of keys(v))condition(get(v,i),`${path}.value[${i}]`);
  }else if(type==='NOT'){
   unknown(value,allowed('type disabled value name'),path);const v=get(value,'value');if(object(v,path+'.value'))condition(v,path+'.value');
  }else{
   const found=declaration(catalog,type,options.declarationCase),d=found.definition;
   if(!d){issue(found.ambiguous?'unresolved-condition-variant':'unknown-condition',path+'.type','warning','unresolved');return;}
   for(const k of keys(value))if(k!=='type'&&k!=='disabled'){
    if(!own(d.fields,k))issue('unknown-field',path+'.'+keyText(k),'warning','unsupported');
    else if(!matchesType(get(value,k),d.fields[k]))issue('invalid-field-type',path+'.'+keyText(k));
    else declared(get(value,k),d.fields[k],path+'.'+keyText(k));
   }
   for(const k of d.requiredFields)if(nil(get(value,k)))issue('missing-field',path+'.'+keyText(k));
  }
 };
 const body=get(envelope,'body');if(!object(body,'$.body'))return finish();
 unknown(body,allowed('name description metadata tags revision priority disabled switch rotation cooldowns'),'$.body');
 const priority=get(body,'priority');if(!nil(priority)&&!(integer(priority,-100000)&&priority<=100000))issue('invalid-priority','$.body.priority');
 const revision=get(body,'revision');if(!nil(revision))check(revision,v=>integer(v,1)&&v<=9007199254740991,'$.body.revision');
 optional(get(body,'name'),'string','$.body.name');optional(get(body,'description'),'string','$.body.description');
 if(!nil(get(body,'tags'))&&!tagsOkay(get(body,'tags')))issue('invalid-tags','$.body.tags');
 const metadata=get(body,'metadata');if(!nil(metadata)&&object(metadata,'$.body.metadata')){
  const fields=allowed('author realm email website version');unknown(metadata,fields,'$.body.metadata');
  // Lua pairs(allowed) has VM-dependent order here; JS uses this fixed order.
  for(const k of ['author','realm','email','website','version'])optional(get(metadata,k),'string','$.body.metadata.'+k);
 }
 optional(get(body,'disabled'),'boolean','$.body.disabled');condition(get(body,'switch'),'$.body.switch');
 let rootsValid=true;for(const k of ['rotation','cooldowns'])if(!list(get(body,k),'$.body.'+k,true))rootsValid=false;
 if(!rootsValid)return finish();
 const tree=indexRotationSteps(body,{allowUnknownBranchFields:true});if(!tree.ok){issue(tree.diagnostic.code,'$.body'+tree.diagnostic.path.slice(1));return finish();}
 for(const row of tree.index.rows){const step=row.step,path='$.body'+location(row.path).slice(1);
  if(get(step,'type')==='branch'){unknown(step,branchFields,path);optional(get(step,'name'),'string',path+'.name');}
  else{
   unknown(step,allowed('id type action ranked name use_name disabled conditions suppress_attack effect color magnification setpoint xoffs yoffs announce announce_sound'),path);
   const type=get(step,'type'),action=get(step,'action');if(check(type,nonempty,path+'.type')){
    if(['spell','pet','any'].includes(type))check(action,v=>integer(v,1),path+'.action');
    else if(type==='item'){
     if(typeof action==='string'){if(check(action,identifier,path+'.action')&&!(options.itemsets&&Set.prototype.has.call(options.itemsets,action)))issue('missing-itemset',path+'.action','warning','unresolved');}
     else if(list(action,path+'.action',true)){if(!keys(action).length)issue('empty-item-list',path+'.action');for(const i of keys(action))check(get(action,i),v=>integer(v,1)||nonempty(v),`${path}.action[${i}]`);}
    }else if(type==='assisted'){
     if(!nil(action))issue('unexpected-assisted-action',path+'.action','warning','unsupported');
     if(row.section!=='rotation')issue('assisted-in-optional-list',path+'.type','warning','unsupported');
    }else if(type!=='none')issue('unknown-action-type',path+'.type','warning','unsupported');
   }
   for(const k of ['ranked','use_name','disabled','suppress_attack'])optional(get(step,k),'boolean',path+'.'+keyText(k));
   if(!nil(get(step,'suppress_attack'))&&type!=='none')issue('unexpected-stop-option',path+'.suppress_attack','warning','unsupported');
   for(const k of ['name','effect','setpoint','announce','announce_sound'])optional(get(step,k),'string',path+'.'+keyText(k));
   for(const k of ['magnification','xoffs','yoffs'])optional(get(step,k),'number',path+'.'+keyText(k));
   const effect=get(step,'effect');if(!nil(effect)&&effect!==false&&!(options.effects&&Set.prototype.has.call(options.effects,effect)))issue('missing-effect',path+'.effect','warning','unresolved');
   const color=get(step,'color');if(!nil(color)&&object(color,path+'.color')){unknown(color,allowed('r g b a'),path+'.color');for(const k of ['r','g','b','a'])check(get(color,k),v=>typeof v==='number'&&v>=0&&v<=1,path+'.color.'+k);}
  }
  condition(get(step,'conditions'),path+'.conditions');
 }
 return finish();
}
export function validateBody(body,catalog,options){return validate(nil(body)?new Map():new Map([['body',body]]),catalog,options,true);}
export function validateEnvelope(envelope,catalog,options){return validate(envelope,catalog,options,false);}
