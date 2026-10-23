// What a player should think twice about before importing an export.
// Shared by the server (stored with each share, shown at the top of its page
// and as badges in listings) and the browser (upload preview), so uploaders
// see exactly the warnings viewers will see. Pure data walk; nothing runs.
import {luaText} from './kinds.mjs';

// Destinations that put text (or an emote) in front of other players today.
export const CHAT_CHANNELS=Object.freeze({partyraid:'raid or party chat',party:'party chat',raidwarn:'raid warnings',emote:'emotes',gesture:'emotes',
  say:'/say',yell:'/yell',whisper:'whispers',channel:'a joined chat channel'});
const LOCAL_CHANNELS=new Set(['local','audible','none','']);
const STEP_TYPES=new Set(['spell','pet','any','item','none','branch','assisted']);
const LOGICAL=new Set(['AND','OR','NOT']);
const CALLBACKS=['evaluate','valid','print','widget','help','on_register','on_unregister'];
const isMap=v=>v instanceof Map;
const get=(m,k)=>isMap(m)?m.get(k):undefined;
const MAX_VISITS=50000;

const TEXT={
  'lua-code':{level:'danger',title:'Contains Lua code',detail:'Custom functions and custom conditions run inside your game when you import and apply them. They can do anything an addon can. The code is shown on this page as text and never runs here; read it, and import it only if you trust it.'},
  'lua-on-register':{level:'danger',title:'Code runs as soon as it is applied',detail:'An "on register" callback runs the moment the custom condition is applied, before it is used in any rotation.'},
  'chat-output':{level:'caution',title:'Sends messages other players see',detail:'Some announcements or cooldown alerts post to chat, emote, whisper or warn other players. Check where each one goes before importing; you can change or remove them after importing.'},
  'macro-trigger':{level:'caution',title:'Can be triggered from macros',detail:'Via Script/Macro announcements run whenever a macro or script calls RM_Announce with their identifier.'},
  'replaces-profile':{level:'caution',title:'Can replace a whole profile',detail:'Importing a profile over an existing one replaces its settings and rotations. Import it as a new profile to keep yours.'},
  'needs-custom-conditions':{level:'info',title:'Needs custom conditions that are not included',detail:'It refers to condition types that are not built in. Import those custom conditions first, or the rotation cannot be imported.'},
  'unrecognized':{level:'info',title:'Content this site does not recognise',detail:'Some steps or announcement destinations are not known to this site. They may come from a newer version of Rotation Master, and could do things this page cannot describe. They are shown as raw data.'},
};
export const RISK_TEXT=TEXT;
export const RISK_ORDER=['lua-code','lua-on-register','chat-output','macro-trigger','replaces-profile','needs-custom-conditions','unrecognized'];

/**
 * Scan a decoded export. `info` is classifyExport()'s result. `knownConditions`
 * (a Set of built-in condition identifiers) enables the custom-condition check.
 * Returns [{code,level,title,detail,count,where:[...]}] in RISK_ORDER.
 */
export function scanExport(value,info,{knownConditions=null}={}){
  const found=new Map();let visits=0;
  const note=(code,where)=>{let r=found.get(code);if(!r){r={code,...TEXT[code],count:0,where:[]};found.set(code,r);}r.count++;if(where&&r.where.length<8&&!r.where.includes(where))r.where.push(where);};
  const budget=()=>++visits<MAX_VISITS;

  if(info?.kind==='function'||info?.kind==='condition'){
    for(const s of info.sources||[]){
      if(s.code?.some(c=>/\S/.test(c.text)))note('lua-code',(s.kind==='function'?'function ':'condition ')+(s.name||s.id));
      if(s.code?.some(c=>c.label==='on_register'&&/\S/.test(c.text)))note('lua-on-register',s.name||s.id);
    }
  }
  if(info?.kind==='profile')note('replaces-profile',info.name?'profile '+info.name:null);

  function condition(node,where,depth=0){
    if(!isMap(node)||depth>64||!budget())return;
    const type=get(node,'type');
    if(typeof type!=='string')return;
    if(LOGICAL.has(type)){
      const v=get(node,'value');
      if(type==='NOT')condition(v,where,depth+1);
      else if(isMap(v))for(const child of v.values())condition(child,where,depth+1);
      return;
    }
    if(knownConditions&&!knownConditions.has(type)&&type!=='DELETE')note('needs-custom-conditions',luaText(type,64));
    // Condition fields may nest further conditions (custom schemas allow condition[]).
    for(const [k,v] of node)if(k!=='type'&&isMap(v)){if(typeof get(v,'type')==='string')condition(v,where,depth+1);else for(const c of v.values())condition(c,where,depth+1);}
  }
  function output(o,where,macro){
    if(!isMap(o))return;
    const channel=get(o,'announce');
    if(typeof channel!=='string')return;
    if(Object.hasOwn(CHAT_CHANNELS,channel))note('chat-output',where+' → '+CHAT_CHANNELS[channel]+(channel==='channel'&&get(o,'channel_name')?' "'+luaText(get(o,'channel_name'),64)+'"':''));
    else if(!LOCAL_CHANNELS.has(channel))note('unrecognized',where+': destination '+luaText(channel,32));
    if(isMap(get(o,'conditions')))condition(get(o,'conditions'),where);
  }
  function announcement(entry,where){
    if(!isMap(entry))return;
    const label=luaText(get(entry,'name'),64)||luaText(get(entry,'identifier'),64)||where;
    if(get(entry,'type')==='macro')note('macro-trigger','announcement '+label);
    const outputs=get(entry,'outputs');
    if(isMap(outputs))for(const o of outputs.values())output(o,'announcement '+label,get(entry,'type')==='macro');
    else output(entry,'announcement '+label,get(entry,'type')==='macro');
  }
  function steps(list,where,depth=0){
    if(!isMap(list)||depth>16)return;
    for(const [index,step] of list){
      if(!isMap(step)||!budget())continue;
      const type=get(step,'type'),here=where+' step '+index;
      if(typeof type!=='string'||!STEP_TYPES.has(type))note('unrecognized',here+': step type '+luaText(String(type),32));
      const channel=get(step,'announce');
      if(typeof channel==='string'){
        if(Object.hasOwn(CHAT_CHANNELS,channel))note('chat-output',here+' → '+CHAT_CHANNELS[channel]);
        else if(!LOCAL_CHANNELS.has(channel))note('unrecognized',here+': announce '+luaText(channel,32));
      }
      if(isMap(get(step,'conditions')))condition(get(step,'conditions'),here);
      if(type==='branch'){steps(get(step,'onTrue'),here+' True arm',depth+1);steps(get(step,'onFalse'),here+' False arm',depth+1);}
    }
  }
  function rotationBody(body,where){
    if(!isMap(body))return;
    if(isMap(get(body,'switch')))condition(get(body,'switch'),where+' switch condition');
    steps(get(body,'rotation'),where);
    steps(get(body,'cooldowns'),where+' cooldown');
  }
  // Walk the whole value: rotation bodies, announcements and custom sources can
  // sit anywhere inside a profile.
  function walk(node,path,depth=0){
    if(!isMap(node)||depth>24||!budget())return;
    if(isMap(get(node,'rotation'))||isMap(get(node,'cooldowns'))){rotationBody(node,path||'rotation');return;}
    for(const [k,v] of node){
      if(!isMap(v))continue;
      const key=typeof k==='string'?k:String(k);
      if(key==='announces'||key==='announcements'){for(const entry of v.values())announcement(entry,'announcement');continue;}
      if(key==='custom_conditions'||key==='custom_functions'){
        for(const [id,src] of v)if(isMap(src)&&[...CALLBACKS,'code'].some(c=>typeof get(src,c)==='string'&&/\S/.test(get(src,c))))note('lua-code',key.replace('custom_','custom ').replace(/s$/,'')+' '+luaText(String(id),64));
        continue;
      }
      walk(v,path?path+'.'+key:key,depth+1);
    }
  }
  if(info?.kind==='announcement')announcement(get(value,'announcement'),'announcement');
  else if(info?.kind==='rotation')rotationBody(info.format==='RotationMaster'?get(value,'body'):value,'rotation');
  else if(info?.kind==='profile')walk(get(value,'profile'),'');
  else if(info?.kind==='condition-category'&&knownConditions){
    for(const tag of info.summary?.conditions||[])if(!knownConditions.has(tag)&&!LOGICAL.has(tag))note('needs-custom-conditions',tag);
  }
  return RISK_ORDER.filter(c=>found.has(c)).map(c=>found.get(c));
}
