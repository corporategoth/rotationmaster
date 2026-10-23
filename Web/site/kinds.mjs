// Classify a decoded Rotation Master export and extract inert display
// metadata. Shared by the server (upload validation, listing summaries) and
// the browser (share pages). Input is the codec's Map/byte-string model; no
// value is ever evaluated. Custom Lua source is returned as text only.
//
// Export kinds, from the addon's own encoders:
//   RotationMaster envelope ........ UI/transfer.lua (GetRotationExportData)
//   legacy rotation body ........... older exports / custom bodies
//   RM-FunctionBundle v1 ........... Core/function_data.lua (function | condition root)
//   RM-CustomCondition v1 .......... UI/custom_condition_transfer.lua (legacy single)
//   RM-CustomFunction v1 ........... legacy single function
//   RM-ConditionCategory v1 ........ UI/settings_conditions.lua
//   RM-ItemSet v1 .................. UI/settings_items.lua
//   effect table (no format) ....... UI/settings_effects.lua
//   RM-Announcement v1/v2 .......... UI/settings_announces.lua
//   RM-Profile v1 .................. UI/settings_profiles.lua

export const KINDS=Object.freeze({
  rotation:{label:'Rotation',plural:'Rotations'},
  function:{label:'Custom function',plural:'Custom functions'},
  condition:{label:'Custom condition',plural:'Custom conditions'},
  'condition-category':{label:'Condition category',plural:'Condition categories'},
  'item-set':{label:'Item set',plural:'Item sets'},
  effect:{label:'Effect',plural:'Effects'},
  announcement:{label:'Announcement',plural:'Announcements'},
  profile:{label:'Profile',plural:'Profiles'},
});
export const CLASSES=Object.freeze(['WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','DEATHKNIGHT','SHAMAN','MAGE','WARLOCK','MONK','DRUID','DEMONHUNTER','EVOKER']);
export const CLASS_LABELS=Object.freeze({WARRIOR:'Warrior',PALADIN:'Paladin',HUNTER:'Hunter',ROGUE:'Rogue',PRIEST:'Priest',DEATHKNIGHT:'Death Knight',SHAMAN:'Shaman',MAGE:'Mage',WARLOCK:'Warlock',MONK:'Monk',DRUID:'Druid',DEMONHUNTER:'Demon Hunter',EVOKER:'Evoker',ANY:'Any class'});
// Edition families as declared by rotation envelopes (Data/validation.lua).
export const EDITIONS=Object.freeze(['era','tbc','progression','forever','retail']);
export const EDITION_LABELS=Object.freeze({era:'Classic Era',tbc:'TBC Anniversary',progression:'Classic progression',forever:'Forever',retail:'Retail'});
export const EFFECT_TYPES=Object.freeze({texture:'Texture',pixel:'Pixel',autocast:'Auto Cast',blizzard:'Glow',dazzle:'Dazzle',animate:'Animate',pulse:'Pulse',rotate:'Rotate',custom:'Custom',proc:'Proc Glow'});
export const CONDITION_CALLBACKS=Object.freeze(['evaluate','valid','print','widget','help','on_register','on_unregister']);

const MAX_TEXT=4096;
const decoder=typeof TextDecoder==='function'?new TextDecoder('utf-8'):null;
const isMap=v=>v instanceof Map;
const get=(m,k)=>isMap(m)?m.get(k):undefined;

/** Lua byte string -> displayable Unicode (invalid UTF-8 becomes U+FFFD). */
export function luaText(value,limit=MAX_TEXT){
  if(typeof value!=='string')return '';
  const slice=value.length>limit*4?value.slice(0,limit*4):value;
  let out;
  if(decoder){const bytes=new Uint8Array(slice.length);for(let i=0;i<slice.length;i++)bytes[i]=slice.charCodeAt(i)&255;out=decoder.decode(bytes);}
  else out=slice;
  out=out.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g,'').replace(/\|c[0-9a-fA-F]{8}|\|r/g,'');
  return out.length>limit?out.slice(0,limit-1)+'…':out;
}
/** Lua source as text: keeps newlines and tabs, decodes UTF-8, bounded. */
export function luaSource(value,limit=262144){
  if(typeof value!=='string')return '';
  const slice=value.slice(0,limit);
  let out=slice;
  if(decoder){const bytes=new Uint8Array(slice.length);for(let i=0;i<slice.length;i++)bytes[i]=slice.charCodeAt(i)&255;out=decoder.decode(bytes);}
  return out.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g,'');
}
/** Dense Lua array (Map with numeric keys 1..n) -> JS array, else null. */
export function denseList(value,limit=10000){
  if(!isMap(value))return null;
  const out=[];
  for(let i=1;i<=value.size&&i<=limit;i++){if(!value.has(i))return null;out.push(value.get(i));}
  return out.length===value.size?out:null;
}
function countSteps(list,depth=0,state={steps:0,branches:0}){
  if(!isMap(list)||depth>16)return state;
  for(const step of list.values()){
    if(!isMap(step))continue;
    state.steps++;
    if(get(step,'type')==='branch'){state.branches++;countSteps(get(step,'onTrue'),depth+1,state);countSteps(get(step,'onFalse'),depth+1,state);}
  }
  return state;
}
function rotationInfo(value,envelope){
  const body=envelope?get(value,'body'):value;
  const scope=envelope?get(value,'applicability'):null;
  const families=denseList(get(scope,'families'))||[];
  const cls=get(scope,'class');
  const name=luaText(get(body,'name'))||'';
  const steps=countSteps(get(body,'rotation'));
  const tags=(denseList(get(body,'tags'))||denseList(get(value,'tags'))||[]).filter(t=>typeof t==='string').map(t=>luaText(t,64)).slice(0,64);
  const meta=get(body,'metadata');
  const minLevel=get(scope,'minLevel'),maxLevel=get(scope,'maxLevel');
  return {
    name,
    description:luaText(get(body,'description')),
    declared:{
      class:typeof cls==='string'&&CLASSES.includes(cls)?cls:get(scope,'universal')===true?'ANY':null,
      editions:families.filter(f=>EDITIONS.includes(f)),
      minLevel:typeof minLevel==='number'?minLevel:null,maxLevel:typeof maxLevel==='number'?maxLevel:null,
    },
    summary:{
      envelope,
      id:envelope?luaText(get(value,'id'),128):null,
      nameKey:envelope?luaText(get(value,'nameKey'),256)||null:null,
      revision:envelope&&typeof get(value,'revision')==='number'?get(value,'revision'):null,
      actions:steps.steps,branches:steps.branches,
      cooldowns:isMap(get(body,'cooldowns'))?get(body,'cooldowns').size:0,
      hasSwitch:isMap(get(body,'switch')),
      tags,
      author:luaText(get(meta,'author'),128)||null,
      version:luaText(get(meta,'version'),64)||null,
    },
  };
}
function functionSource(id,name,source,role){
  const args=(denseList(get(source,'args'))||[]).filter(isMap).map(a=>({name:luaText(get(a,'name'),64),type:luaText(get(a,'type'),128),description:luaText(get(a,'description'),512)}));
  const returns=(denseList(get(source,'returns'))||[]).filter(isMap).map(a=>({type:luaText(get(a,'type'),128),description:luaText(get(a,'description'),512)}));
  const bindings=[];
  if(isMap(get(source,'bindings')))for(const [alias,target] of get(source,'bindings'))if(typeof alias==='string'&&typeof target==='string')bindings.push({alias:luaText(alias,128),target:luaText(target,256)});
  return {role,kind:'function',id:luaText(id,256),name:luaText(name,256),namespace:luaText(get(source,'namespace'),128)||null,
    description:luaText(get(source,'description')),args,returns,bindings,
    code:[{label:'Lua',text:luaSource(get(source,'code'))}]};
}
function conditionSource(id,name,source,role){
  const code=[];
  for(const callback of CONDITION_CALLBACKS){const text=get(source,callback);if(typeof text==='string'&&text.length)code.push({label:callback,text:luaSource(text)});}
  const fields=get(source,'fields');
  return {role,kind:'condition',id:luaText(id,256),name:luaText(name,256),description:luaText(get(source,'description')),
    fields:typeof fields==='string'?luaSource(fields,32768):null,code};
}
function bundleInfo(value){
  const root=get(value,'root');
  if(!isMap(root))return null;
  const kind=get(root,'kind'),source=get(root,'source');
  if((kind!=='function'&&kind!=='condition')||typeof get(root,'id')!=='string'||typeof get(root,'name')!=='string'||!isMap(source))return null;
  const dependencies=denseList(get(value,'dependencies')),requirements=denseList(get(value,'requirements'));
  if(!dependencies||!requirements)return null;
  const sources=[kind==='function'?functionSource(get(root,'id'),get(root,'name'),source,'root'):conditionSource(get(root,'id'),get(root,'name'),source,'root')];
  for(const dep of dependencies)if(isMap(dep)&&isMap(get(dep,'source')))sources.push(functionSource(get(dep,'id'),get(dep,'name'),get(dep,'source'),'dependency'));
  return {kind,name:luaText(get(root,'name'),256),
    summary:{id:luaText(get(root,'id'),256),dependencies:dependencies.length,
      requirements:requirements.filter(isMap).map(r=>({id:luaText(get(r,'id'),256),name:luaText(get(r,'name'),256),builtin:get(r,'builtin')===true}))},
    sources};
}

/**
 * Classify a decoded value. Returns
 *   {ok:true,kind,format,name,description,declared:{class,editions,...},summary,sources}
 * or {ok:false,reason}. `declared` holds class/edition facts only when the
 * export itself states them (rotation envelopes); other kinds declare none.
 */
export function classifyExport(value){
  if(!isMap(value))return {ok:false,reason:'expected-table'};
  const format=get(value,'format'),version=get(value,'version');
  const none={class:null,editions:[],minLevel:null,maxLevel:null};
  const result=(kind,extra)=>({ok:true,kind,format:typeof format==='string'?format:null,name:'',description:'',declared:none,summary:{},sources:[],...extra});
  if(format==='RotationMaster')return result('rotation',rotationInfo(value,true));
  if(format==='RM-FunctionBundle'){
    if(version!==1)return {ok:false,reason:'unsupported-bundle-version'};
    const info=bundleInfo(value);if(!info)return {ok:false,reason:'invalid-function-bundle'};
    return result(info.kind,{name:info.name,summary:info.summary,sources:info.sources});
  }
  if(format==='RM-CustomCondition'){
    if(version!==1||typeof get(value,'name')!=='string'||!isMap(get(value,'condition')))return {ok:false,reason:'invalid-custom-condition'};
    return result('condition',{name:luaText(get(value,'name'),256),summary:{id:luaText(get(value,'name'),256),dependencies:0,requirements:[]},sources:[conditionSource(get(value,'name'),get(value,'name'),get(value,'condition'),'root')]});
  }
  if(format==='RM-CustomFunction'){
    const source=get(value,'source')??get(value,'function');
    if(version!==1||typeof get(value,'name')!=='string'||!isMap(source))return {ok:false,reason:'invalid-custom-function'};
    const id=get(value,'id')??get(value,'name');
    return result('function',{name:luaText(get(value,'name'),256),summary:{id:luaText(id,256),dependencies:0,requirements:[]},sources:[functionSource(id,get(value,'name'),source,'root')]});
  }
  if(format==='RM-ConditionCategory'){
    const tags=denseList(get(value,'conditions'));
    if(version!==1||!tags||!tags.every(t=>typeof t==='string'))return {ok:false,reason:'invalid-condition-category'};
    return result('condition-category',{name:luaText(get(value,'name'),256),summary:{conditions:tags.slice(0,512).map(t=>luaText(t,128))}});
  }
  if(format==='RM-ItemSet'){
    const items=denseList(get(value,'items'));const name=get(value,'name');
    if(version!==1||typeof name!=='string'||!/\S/.test(name)||name.length>256||!items||!items.every(i=>typeof i==='number'||typeof i==='string'))return {ok:false,reason:'invalid-item-set'};
    return result('item-set',{name:luaText(name,256),summary:{items:items.slice(0,512).map(i=>typeof i==='number'?i:luaText(i,256))}});
  }
  if(format==='RM-Announcement'){
    const entry=get(value,'announcement');
    if((version!==1&&version!==2)||!isMap(entry)||(version===2)!==isMap(get(entry,'outputs')))return {ok:false,reason:'invalid-announcement'};
    const outputs=version===2?(denseList(get(entry,'outputs'))||[]).filter(isMap):[entry];
    const action=v=>typeof v==='number'?v:typeof v==='string'?luaText(v,128):isMap(v)?'custom item list':null;
    return result('announcement',{name:luaText(get(entry,'name'),256)||luaText(get(entry,'identifier'),64),summary:{
      type:luaText(get(entry,'type'),32),event:luaText(get(entry,'event'),32)||null,identifier:luaText(get(entry,'identifier'),64)||null,
      spell:action(get(entry,'spell')),item:action(get(entry,'item')),ranked:get(entry,'ranked')===true,
      outputs:outputs.slice(0,32).map(o=>({channel:luaText(get(o,'announce'),64),channelName:luaText(get(o,'channel_name'),256)||null,
        text:luaText(get(o,'value'),512),sound:luaText(get(o,'announce_sound'),256)||null,emote:luaText(get(o,'emote'),64)||null,
        conditions:isMap(get(o,'conditions')),disabled:get(o,'disabled')===true}))}});
  }
  if(format==='RM-Profile'){
    const profile=get(value,'profile');
    if(version!==1||!isMap(profile))return {ok:false,reason:'invalid-profile'};
    const count=key=>isMap(get(profile,key))?get(profile,key).size:0;
    return result('profile',{name:luaText(get(value,'name'),256),summary:{keys:[...profile.keys()].filter(k=>typeof k==='string').slice(0,64).map(k=>luaText(k,64)),itemsets:count('itemsets'),announces:count('announces')}});
  }
  if(format===undefined){
    const type=get(value,'type');
    if(typeof type==='string'&&Object.hasOwn(EFFECT_TYPES,type)&&typeof get(value,'name')==='string'&&!value.has('rotation')){
      const fields=[];for(const [k,v] of value)if(typeof k==='string'&&k!=='name'&&k!=='type'&&k!=='sequence'&&(typeof v==='number'||typeof v==='string'||typeof v==='boolean'))fields.push({key:luaText(k,64),value:typeof v==='string'?luaText(v,256):v});
      const sequence=get(value,'sequence');
      return result('effect',{name:luaText(get(value,'name'),256),summary:{type,typeLabel:EFFECT_TYPES[type],fields:fields.slice(0,32),sequence:isMap(sequence)?sequence.size:0}});
    }
    if(isMap(get(value,'rotation'))||isMap(get(value,'cooldowns')))return result('rotation',rotationInfo(value,false));
  }
  return {ok:false,reason:'unrecognized-export'};
}
