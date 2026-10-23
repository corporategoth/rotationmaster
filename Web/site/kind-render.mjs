// Friendly, text-only rendering of a classified export (see kinds.mjs).
// Everything goes through textContent; Lua source is displayed, never run.
import {KINDS,CLASS_LABELS,EDITION_LABELS} from './kinds.mjs';
import {scanExport} from './risks.mjs';
import {createTreeRenderer} from './tree-render.mjs';
import {el} from './client.mjs';

let conditionNames=null;
export async function loadConditionNames(){
  if(conditionNames)return conditionNames;
  try{const r=await fetch('/site/conditions.json',{credentials:'omit',redirect:'error'});conditionNames=r.ok?await r.json():{conditions:{}};}
  catch{conditionNames={conditions:{}};}
  return conditionNames;
}
const CHANNELS={partyraid:'Raid or party',party:'Party',raidwarn:'Raid warning',emote:'Emote (text)',gesture:'Named emote',local:'Local chat frame',audible:'Sound',say:'Say',yell:'Yell',whisper:'Whisper',channel:'Joined channel'};
const EVENTS={START:'Cast started',STOP:'Cast stopped',SUCCEEDED:'Cast succeeded',INTERRUPTED:'Cast interrupted',FAILED:'Cast failed',DELAYED:'Cast delayed'};
const TRIGGERS={spell:'Spell',pet:'Pet spell',item:'Item',macro:'Via Script/Macro'};

function facts(document,parent,rows){
  const dl=el(document,'dl','', 'facts');
  for(const [term,value] of rows){
    if(value===null||value===undefined||value==='')continue;
    dl.append(el(document,'dt',term),el(document,'dd',value));
  }
  parent.append(dl);return dl;
}
function codeBlock(document,parent,label,text){
  const box=el(document,'details','','code-block');box.open=true;
  box.append(el(document,'summary',label+' · '+text.split('\n').length+' lines'));
  const pre=el(document,'pre'),code=el(document,'code',text);pre.append(code);box.append(pre);
  parent.append(box);
}

/** Import warnings, worded identically to the server-rendered share page. */
export function renderRisks(document,parent,risks){
  parent.replaceChildren();
  if(!risks.length){const ok=el(document,'aside','','risk-panel risk-none');ok.append(el(document,'p','Nothing to warn about: no Lua code, no chat messages to other players, no unrecognised content.'));parent.append(ok);return;}
  const box=el(document,'aside','','risk-panel');box.setAttribute('aria-label','Before you import');
  box.append(el(document,'h2','Before you import'));
  const ul=el(document,'ul','','risk-list');
  for(const r of risks){
    const li=el(document,'li','','risk risk-'+r.level);
    li.append(el(document,'strong',r.title),document.createTextNode(' '),el(document,'span',r.detail));
    if(r.where?.length)li.append(el(document,'span',' Found in: '+r.where.join('; ')+(r.count>r.where.length?'; …':'')+'.','risk-where'));
    ul.append(li);
  }
  box.append(ul);parent.append(box);
}
export async function scanWithNames(value,info){
  const names=await loadConditionNames();
  return scanExport(value,info,{knownConditions:names.conditions&&Object.keys(names.conditions).length?new Set(Object.keys(names.conditions)):null});
}

export async function renderKindSummary(document,parent,info,value){
  parent.replaceChildren();
  const names=await loadConditionNames();
  const tree=createTreeRenderer(document,{conditionNames:names});
  const isMap=v=>v instanceof Map;
  const s=info.summary||{},d=info.declared||{};
  const head=el(document,'p','', 'kind-line');
  head.append(el(document,'strong',KINDS[info.kind]?.label||info.kind),document.createTextNode(info.name?' · '+info.name:''));
  parent.append(head);
  if(info.kind==='rotation'){
    const levels=d.minLevel||d.maxLevel?`${d.minLevel??1}–${d.maxLevel??'max'}`:null;
    facts(document,parent,[
      ['Format',s.envelope?`Rotation envelope${s.revision?' (revision '+s.revision+')':''}`:'Rotation body'],
      ['Identifier',s.id],
      ['Name key',info.name?null:s.nameKey],
      ['Class',d.class?CLASS_LABELS[d.class]||d.class:'Not declared'],
      ['Editions',d.editions?.length?d.editions.map(e=>EDITION_LABELS[e]||e).join(', '):'Not declared'],
      ['Levels',levels],
      ['Ordered actions',`${s.actions??0}${s.branches?` (including ${s.branches} branch${s.branches===1?'':'es'})`:''}`],
      ['Cooldowns',String(s.cooldowns??0)],
      ['Switch condition',s.hasSwitch?'Yes':'None (selected manually or as the fallback)'],
      ['Tags',s.tags?.length?s.tags.join(', '):null],
      ['Author',s.author],['Version',s.version],
    ]);
    if(info.description){const p=el(document,'p',info.description,'in-game-description');parent.append(el(document,'h3','In-game description'),p);}
    if(isMap(value)){
      const body=s.envelope?value.get('body'):value;
      const full=el(document,'section','','full-decode');full.append(el(document,'h3','The whole rotation'));parent.append(full);
      tree.rotation(full,body,{heading:4});
      if(s.envelope){
        const meta=new Map([...value].filter(([k])=>k!=='body'));
        const box=el(document,'details','','envelope-fields');box.append(el(document,'summary','Envelope fields (identity, applicability, sources)'));tree.value(box,meta);parent.append(box);
      }
    }
    return;
  }
  if(info.kind==='function'||info.kind==='condition'){
    const warn=el(document,'aside','','callout callout-warning');
    const p=el(document,'p');p.append(el(document,'strong','Lua code.'),document.createTextNode(' This export contains Lua that runs inside the game if you import and apply it. It is shown here as text only. Read it, and import only code you trust.'));
    warn.append(p);parent.append(warn);
    if(s.requirements?.length){
      parent.append(el(document,'h3','Requires'));
      const ul=el(document,'ul');for(const r of s.requirements)ul.append(el(document,'li',`${r.name} (${r.id})${r.builtin?' · Built In':''}`));parent.append(ul);
    }
    for(const source of info.sources){
      const section=el(document,'section','','source');
      section.append(el(document,'h3',`${source.role==='root'?(source.kind==='function'?'Function':'Condition'):'Included dependency'}: ${source.name||source.id}`));
      facts(document,section,[['Identifier',source.id],['Namespace',source.namespace],['Description',source.description]]);
      if(source.args?.length){
        section.append(el(document,'h4','Arguments'));const ul=el(document,'ul');
        for(const a of source.args)ul.append(el(document,'li',`${a.name}${a.type?' ('+a.type+')':''}${a.description?' — '+a.description:''}`));section.append(ul);
      }
      if(source.returns?.length){
        section.append(el(document,'h4','Returns'));const ul=el(document,'ul');
        for(const r of source.returns)ul.append(el(document,'li',`${r.type||'value'}${r.description?' — '+r.description:''}`));section.append(ul);
      }
      if(source.bindings?.length){
        section.append(el(document,'h4','Uses helpers'));const ul=el(document,'ul');
        for(const b of source.bindings)ul.append(el(document,'li',b.alias===b.target?b.target:`${b.alias} → ${b.target}`));section.append(ul);
      }
      if(source.fields){section.append(el(document,'h4','Fields'));const pre=el(document,'pre');pre.append(el(document,'code',source.fields));section.append(pre);}
      if(!source.code.length)section.append(el(document,'p','No code.','empty'));
      for(const block of source.code)codeBlock(document,section,block.label,block.text);
      parent.append(section);
    }
    return;
  }
  if(info.kind==='condition-category'){
    const names=await loadConditionNames();
    parent.append(el(document,'p',`${s.conditions.length} condition type${s.conditions.length===1?'':'s'}, in this order:`));
    const ol=el(document,'ol','', 'condition-list');
    for(const tag of s.conditions){const li=el(document,'li');const known=names.conditions?.[tag];li.append(document.createTextNode(known?known.name+' '
      :'Custom or unknown condition '),el(document,'code',tag));ol.append(li);}
    parent.append(ol);
    parent.append(el(document,'p','A category export carries only the condition identifiers. Custom conditions it lists must be imported separately.','hint'));
    return;
  }
  if(info.kind==='item-set'){
    parent.append(el(document,'p','Priority order: the first item you carry (or wear, where requested) is the one used.'));
    const ol=el(document,'ol','', 'item-list');
    for(const item of s.items)ol.append(el(document,'li',typeof item==='number'?'Item '+item:item));
    parent.append(ol);
    return;
  }
  if(info.kind==='effect'){
    facts(document,parent,[['Type',s.typeLabel||s.type],['Sequence steps',s.sequence?String(s.sequence):null],
      ...s.fields.map(f=>[f.key,typeof f.value==='boolean'?(f.value?'Yes':'No'):String(f.value)])]);
    if(isMap(value)&&isMap(value.get('sequence'))){const box=el(document,'section','','full-decode');box.append(el(document,'h3','Sequence'));tree.value(box,value.get('sequence'));parent.append(box);}
    return;
  }
  if(info.kind==='announcement'){
    facts(document,parent,[['Trigger',TRIGGERS[s.type]||s.type],['Identifier',s.identifier],['Spell',s.spell!==null&&s.spell!==''?String(s.spell)+(s.ranked?' (exact rank)':''):null],
      ['Item',s.item!==null&&s.item!==''?String(s.item):null],['Event',s.event?EVENTS[s.event]||s.event:null]]);
    parent.append(el(document,'h3',`Output${s.outputs.length===1?'':'s'}`));
    const ol=el(document,'ol','', 'output-list');
    for(const o of s.outputs){
      const li=el(document,'li');
      li.append(el(document,'strong',(CHANNELS[o.channel]||o.channel)+(o.channelName?' · '+o.channelName:'')));
      if(o.text)li.append(document.createTextNode(' — '),el(document,'q',o.text));
      if(o.emote)li.append(document.createTextNode(' — /'+o.emote.toLowerCase()));
      if(o.sound)li.append(document.createTextNode(' — sound: '+o.sound));
      if(o.conditions)li.append(document.createTextNode(' (with conditions)'));
      if(o.disabled)li.append(document.createTextNode(' (disabled)'));
      ol.append(li);
    }
    parent.append(ol);
    if(isMap(value)){const box=el(document,'section','','full-decode');box.append(el(document,'h3','Every stored field, including output conditions'));tree.value(box,value.get('announcement'));parent.append(box);}
    return;
  }
  if(info.kind==='profile'){
    facts(document,parent,[['Profile name',info.name],['Item sets',String(s.itemsets)],['Announcements',String(s.announces)],['Settings stored',s.keys.join(', ')]]);
    parent.append(el(document,'p','Importing a profile can replace a whole profile, including its rotations. Use a new profile name if you want to keep your own.','hint'));
    const profile=isMap(value)?value.get('profile'):null;
    if(isMap(profile)){
      const full=el(document,'section','','full-decode');full.append(el(document,'h3','Everything in this profile'));parent.append(full);
      for(const [key,part] of profile){
        const box=el(document,'details','','profile-part');box.append(el(document,'summary',String(key)));
        tree.value(box,part,0,typeof key==='string'?key:null);full.append(box);
      }
    }
  }
}
