// Full, readable rendering of decoded export data: every step, branch arm,
// cooldown and nested condition, with every stored field. Text only
// (createElement/textContent); nothing is evaluated. Spell and item IDs are
// shown as numbers because the site has no game data.
import {luaText} from './kinds.mjs';
import {CHAT_CHANNELS} from './risks.mjs';

const isMap=v=>v instanceof Map;
const get=(m,k)=>isMap(m)?m.get(k):undefined;
const LOGICAL={AND:'All of',OR:'Any of',NOT:'Not'};
const STEP_LABELS={spell:'Spell',pet:'Pet spell',any:'Any spell',item:'Item',none:'Stop',branch:'Branch'};
const MODES={true:'Always true (guard skipped)',false:'Always false (guard skipped)'};
const STEP_SKIP=new Set(['type','action','conditions','onTrue','onFalse','mode','id','name','ranked','disabled','suppress_attack']);
const LIMIT=40000;

function orderedEntries(map){
  const entries=[...map];
  const numeric=entries.filter(([k])=>typeof k==='number').sort((a,b)=>a[0]-b[0]);
  const other=entries.filter(([k])=>typeof k!=='number').sort((a,b)=>String(a[0])<String(b[0])?-1:1);
  return [...numeric,...other];
}
function keyLabel(k){return typeof k==='number'?'['+k+']':luaText(k,128);}

export function createTreeRenderer(document,{conditionNames=null}={}){
  let count=0;
  const el=(tag,text,cls)=>{count++;const e=document.createElement(tag);if(text!==undefined&&text!==null)e.textContent=String(text);if(cls)e.setAttribute('class',cls);return e;};
  const over=()=>count>LIMIT;

  function scalar(key,v){
    if(typeof v==='boolean')return v?'yes':'no';
    if(typeof v==='number'){
      if(key==='spell'||key==='action')return 'Spell #'+v;
      if(key==='item')return 'Item #'+v;
      return String(v);
    }
    if(typeof v==='string')return luaText(v,1024);
    return String(v);
  }
  // Generic key/value rendering for any value, nesting Maps.
  function value(parent,v,depth=0,key=null){
    if(over())return;
    if(!isMap(v)){parent.append(document.createTextNode(scalar(key,v)));count++;return;}
    if(v.size===0){parent.append(el('span','(empty)','muted'));return;}
    if(isRotationBody(v)){renderRotationBody(parent,v,{heading:4});return;}
    const allScalar=[...v.values()].every(x=>!isMap(x));
    const dense=[...v.keys()].every((k,i)=>k===i+1);
    if(dense&&allScalar&&v.size<=64){parent.append(document.createTextNode(orderedEntries(v).map(([,x])=>scalar(key,x)).join(', ')));count++;return;}
    if(depth>14){parent.append(el('span','(nested data: see raw view)','muted'));return;}
    const dl=el('dl','','kv');
    for(const [k,x] of orderedEntries(v)){
      if(over())break;
      dl.append(el('dt',keyLabel(k)));const dd=el('dd');value(dd,x,depth+1,typeof k==='string'?k:key);dl.append(dd);
    }
    parent.append(dl);
  }
  function fieldsLine(parent,node,skip){
    const rest=orderedEntries(node).filter(([k])=>!skip.has(k));
    if(!rest.length)return;
    const dl=el('dl','','kv inline');
    for(const [k,x] of rest){dl.append(el('dt',keyLabel(k)));const dd=el('dd');value(dd,x,1,typeof k==='string'?k:null);dl.append(dd);}
    parent.append(dl);
  }
  function condition(parent,node,depth=0){
    if(over())return;
    const ul=el('ul','','cond-tree');parent.append(ul);
    conditionItem(ul,node,depth);
  }
  function conditionItem(ul,node,depth){
    const li=el('li');ul.append(li);
    if(!isMap(node)){li.append(el('span','(not a condition) ','flag'));value(li,node);return;}
    const type=get(node,'type');
    if(typeof type==='string'&&Object.hasOwn(LOGICAL,type)){
      li.append(el('span',LOGICAL[type],'cond-op'));
      const disabled=get(node,'disabled')===true;if(disabled)li.append(el('span',' (disabled)','muted'));
      fieldsLine(li,node,new Set(['type','value','disabled']));
      const children=el('ul','','cond-tree');li.append(children);
      const v=get(node,'value');
      if(depth>64){children.append(el('li','(nested too deeply: see raw view)','muted'));return;}
      if(type==='NOT')conditionItem(children,v,depth+1);
      else if(isMap(v))for(const [,child] of orderedEntries(v))conditionItem(children,child,depth+1);
      if(!children.childNodes.length)children.append(el('li',type==='AND'?'(empty: always matches)':'(empty: never matches)','muted'));
      return;
    }
    const known=typeof type==='string'?conditionNames?.conditions?.[type]:null;
    li.append(el('span',known?known.name:'Custom or unknown condition',known?'cond-name':'cond-name flag'),document.createTextNode(' '),el('code',typeof type==='string'?luaText(type,128):'(no type)'));
    if(get(node,'disabled')===true)li.append(el('span',' (disabled)','muted'));
    fieldsLine(li,node,new Set(['type','disabled']));
  }
  function stepAction(step){
    const type=get(step,'type'),action=get(step,'action');
    if(type==='none')return get(step,'suppress_attack')===true?'Stop, and suppress implicit Attack':'Stop';
    if(type==='branch')return 'Branch · '+(MODES[get(step,'mode')]||'Evaluate guard');
    let text=STEP_LABELS[type]||('Unknown step type '+luaText(String(type),32));
    if(typeof action==='number')text+=' #'+action;
    else if(typeof action==='string')text+=type==='item'?' from item set '+luaText(action,128):' '+luaText(action,128);
    else if(isMap(action))text+=' from list: '+orderedEntries(action).map(([,x])=>typeof x==='number'?'#'+x:luaText(String(x),64)).join(', ');
    if(get(step,'ranked')===true)text+=' (exact rank)';
    return text;
  }
  function steps(parent,list,depth=0,cooldowns=false){
    const ol=el('ol','','steps'+(cooldowns?' cooldown-steps':''));parent.append(ol);
    if(!isMap(list)||list.size===0){ol.append(el('li','(none)','muted'));return;}
    for(const [index,step] of orderedEntries(list)){
      if(over()){ol.append(el('li','Display limit reached; use the raw view for the rest.','muted'));break;}
      const li=el('li','','tree-step'+(get(step,'disabled')===true?' disabled':'')+(get(step,'type')==='branch'?' branch':''));ol.append(li);
      if(!isMap(step)){value(li,step);continue;}
      const head=el('p','','tree-step-head');
      head.append(el('span',typeof index==='number'?index+'.':keyLabel(index),'step-index'),document.createTextNode(' '),el('strong',stepAction(step)));
      const name=get(step,'name');if(typeof name==='string'&&name)head.append(document.createTextNode(' — '),el('q',luaText(name,256)));
      if(get(step,'disabled')===true)head.append(el('span',' disabled','badge'));
      const channel=get(step,'announce');
      if(typeof channel==='string'&&Object.hasOwn(CHAT_CHANNELS,channel))head.append(el('span',' announces to '+CHAT_CHANNELS[channel],'badge warn'));
      li.append(head);
      fieldsLine(li,step,STEP_SKIP);
      const cond=get(step,'conditions');
      if(isMap(cond)){li.append(el('p',get(step,'type')==='branch'?'Guard:':'Used when:','cond-label'));condition(li,cond);}
      else if(get(step,'type')!=='branch')li.append(el('p','No conditions: always eligible.','muted'));
      if(get(step,'type')==='branch'){
        if(depth>16){li.append(el('p','(nested too deeply: see raw view)','muted'));continue;}
        const arms=el('div','','arms');li.append(arms);
        for(const [key,label,cls] of [['onFalse','False arm','arm arm-false'],['onTrue','True arm','arm arm-true']]){
          const arm=el('div','',cls);arm.append(el('p',label+(MODES[get(step,'mode')]&&((get(step,'mode')==='true')===(key==='onFalse'))?' (unreachable)':''),'arm-label'));
          steps(arm,get(step,key),depth+1);arms.append(arm);
        }
      }
    }
  }
  function isRotationBody(v){return isMap(v)&&(isMap(get(v,'rotation'))||isMap(get(v,'cooldowns')));}
  function renderRotationBody(parent,body,{heading=3}={}){
    const box=el('div','','rotation-tree');parent.append(box);
    const h=n=>'h'+Math.min(6,heading+n);
    const name=get(body,'name');
    if(heading>3&&typeof name==='string')box.append(el(h(0),'Rotation: '+luaText(name,256)));
    box.append(el(h(heading>3?1:0),'Switch condition'));
    if(isMap(get(body,'switch')))condition(box,get(body,'switch'));
    else box.append(el('p','None: chosen by hand, or as the fallback rotation.','muted'));
    const count=m=>isMap(m)?m.size:0;
    box.append(el(h(heading>3?1:0),`Rotation: ordered actions (${count(get(body,'rotation'))} at the top level)`));
    steps(box,get(body,'rotation'));
    box.append(el(h(heading>3?1:0),`Cooldowns (${count(get(body,'cooldowns'))})`));
    steps(box,get(body,'cooldowns'),0,true);
    const other=orderedEntries(body).filter(([k])=>!['rotation','cooldowns','switch','name'].includes(k));
    if(other.length){box.append(el(h(heading>3?1:0),'Other stored fields'));const holder=el('div');box.append(holder);value(holder,new Map(other));}
    return box;
  }
  return {
    rotation:renderRotationBody,
    condition,
    value,
    outputConditions(parent,node){condition(parent,node);},
    limited:over,
  };
}
