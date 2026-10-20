import {createComparisonSession,createSchemaAnalyzer} from './model.mjs';
import {renderViewer,renderComparison} from './render.mjs';

// Structural analysis is local/declarative; no imported callback can run.
export function mountViewer(document,root,{analyze,writeClipboard,compare:compareData}={}){
  const pair=createComparisonSession({analyze,compare:compareData});let active=true,viewOperation=0,release=()=>{},mode='left',right=null,panelLease=0,controls=null;
  const make=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;};
  const heading=make('h1','Rotation Master'),subtitle=make('p','Export viewer');subtitle.setAttribute('class','subtitle');
  const intro=make('p','Read locally. Imported code is never run.');
  const openComparison=make('button','Compare another export');openComparison.setAttribute('type','button');openComparison.setAttribute('aria-expanded','false');
  const panel=make('section');panel.setAttribute('class','compare-input');panel.hidden=true;
  const result=make('div');result.setAttribute('class','result');
  const primaryHost=make('section');primaryHost.setAttribute('class','import-pane');
  root.replaceChildren(heading,subtitle,intro,primaryHost,openComparison,panel,result);
  const clearViewport=()=>{release();release=()=>{};};
  function navState(){if(!controls)return;for(const [key,b]of Object.entries(controls.nav))b.setAttribute('aria-pressed',String(mode===key));controls.nav.diff.disabled=pair.view()===null;}
  function show(side,focus=false){
    if(!active)return;viewOperation++;clearViewport();mode=side;
    if(side==='diff'){const value=pair.view();if(value)release=renderComparison(document,result,value);}
    else{const value=pair.pane(side).view();if(value)release=renderViewer(document,result,value);}
    navState();if(focus){const h=result.children[0]?.children[0];if(h?.focus){h.setAttribute('tabindex','-1');h.focus();}}
  }
  function invalidate(side){
    viewOperation++;
    if(mode==='diff'||mode===side)clearViewport();
    if(controls){controls.status.textContent='Inputs changed. Decode each export and compare again.';controls.nav.diff.disabled=true;}
  }
  function pane(side,owner){
    const session=pair.pane(side),prefix=side==='left'?'':'compare-';let live=true,operation=0;
    const form=make('form');form.setAttribute('aria-label',side==='left'?'First export':'Second export');const label=make('label',side==='left'?'Paste export':'Paste second export');label.setAttribute('for',prefix+'import-text');
    const input=make('textarea');input.setAttribute('id',prefix+'import-text');input.setAttribute('rows','7');input.setAttribute('spellcheck','false');input.setAttribute('aria-describedby',prefix+'import-guidance '+prefix+'import-status');
    const guidance=make('p','Maximum import: 2 MiB of UTF-8 text. Decode does not check native spell, target or resource readiness.');guidance.setAttribute('id',prefix+'import-guidance');
    const decode=make('button','Decode');decode.setAttribute('type','submit');
    const clear=make('button','Clear');clear.setAttribute('type','button');
    const copy=make('button','Copy original export');copy.setAttribute('type','button');copy.disabled=true;
    const actions=make('div');actions.setAttribute('class','actions');actions.append(decode,clear,copy);form.append(label,input,guidance,actions);
    const status=make('p','Paste an RM export to begin.');status.setAttribute('id',prefix+'import-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const manualLabel=make('label','Original export — select and copy manually');manualLabel.setAttribute('for',prefix+'manual-export');manualLabel.hidden=true;
    const manual=make('textarea');manual.setAttribute('id',prefix+'manual-export');manual.setAttribute('readonly','');manual.setAttribute('rows','4');manual.hidden=true;
    owner.append(form,status,manualLabel,manual);
    const listeners=[],on=(e,event,fn)=>{e.addEventListener(event,fn);listeners.push([e,event,fn]);};
    const retire=()=>{operation++;copy.disabled=true;manual.hidden=true;manualLabel.hidden=true;manual.value='';};
    const synchronize=()=>{if(!active||!live)return;invalidate(side);retire();session.edit(input.value);status.textContent='Input changed. Decode to inspect this export.';};
    on(input,'input',synchronize);
    on(form,'submit',event=>{
      event.preventDefault();if(!active||!live)return;invalidate(side);retire();session.edit(input.value);const token=viewOperation,current=operation,view=session.decode();
      if(!active||!live||current!==operation||token!==viewOperation||!view)return;
      copy.disabled=!view.decode.ok;status.textContent=view.decode.ok?'Decoded. '+view.structureMessage:'Could not decode: '+view.decode.reason;input.setAttribute('aria-invalid',view.decode.ok?'false':'true');show(side);
    });
    on(clear,'click',()=>{if(!active||!live)return;invalidate(side);retire();session.clear();input.value='';input.setAttribute('aria-invalid','false');status.textContent='Cleared. Paste an RM export to begin.';input.focus();});
    on(copy,'click',async()=>{
      if(!active||!live)return;const original=session.original();if(original===null)return;const current=operation,focusToken=viewOperation;
      try{if(typeof writeClipboard!=='function')throw Error('clipboard-unavailable');await writeClipboard(original);if(active&&live&&current===operation)status.textContent='Original export copied.';}
      catch{if(!active||!live||current!==operation)return;manual.value=original;manual.hidden=false;manualLabel.hidden=false;status.textContent='Clipboard unavailable. Select and copy the original export below.';if(focusToken===viewOperation){manual.focus();manual.select();}}
    });
    return {input,form,clear,copy,manual,result,status,synchronize,dispose(){if(!live)return;live=false;retire();session.clear();input.value='';for(const [e,event,fn]of listeners)e.removeEventListener(event,fn);owner.replaceChildren();}};
  }
  const left=pane('left',primaryHost);
  const open=()=>{
    if(!active)return;if(right){right.input.focus();return;}const lease=++panelLease;viewOperation++;panel.hidden=false;openComparison.setAttribute('aria-expanded','true');
    const title=make('h2','Second export'),rightHost=make('div');panel.append(title,rightHost);right=pane('right',rightHost);
    const compare=make('button','Compare');compare.setAttribute('type','button');const close=make('button','Close comparison');close.setAttribute('type','button');
    const status=make('p','Decode both exports, then compare.');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const nav=make('nav');nav.setAttribute('aria-label','Result view');const buttons={};for(const [key,text]of [['left','First export'],['right','Second export'],['diff','Differences']]){const b=make('button',text);b.setAttribute('type','button');buttons[key]=b;nav.append(b);}
    const listeners=[],on=(e,event,fn)=>{const guarded=event=>{if(active&&lease===panelLease&&right)fn(event);};e.addEventListener(event,guarded);listeners.push([e,event,guarded]);};
    controls={compare,close,status,nav:buttons,dispose(){for(const [e,event,fn]of listeners)e.removeEventListener(event,fn);}};
    panel.append(compare,close,status,nav);navState();
    on(compare,'click',()=>{
      // Accepted authority cannot be revived just by programmatic text equality.
      for(const [side,record]of [['left',left],['right',right]])if(record.input.value!==pair.pane(side).input()){
        record.synchronize();
      }
      const token=++viewOperation,value=pair.compare();if(!active||lease!==panelLease||token!==viewOperation||!value)return;
      status.textContent=value.reason==='decode-required'?'Decode both current exports before comparing.':value.status==='unavailable'?'Comparison unavailable. Inspect the feedback below.':value.status==='partial'?'Partial comparison. Some differences are omitted.':'Comparison complete.';
      show('diff',true);
    });
    on(close,'click',()=>{
      panelLease++;viewOperation++;clearViewport();const old=right;right=null;old.dispose();controls.dispose();controls=null;panel.replaceChildren();panel.hidden=true;openComparison.setAttribute('aria-expanded','false');show('left');openComparison.focus();
    });
    for(const [key,b]of Object.entries(buttons))on(b,'click',()=>{if(key!=='diff'||pair.view())show(key,true);});
    right.input.focus();
  };
  openComparison.addEventListener('click',open);
  return {...left,openComparison,get right(){return right;},get compare(){return controls?.compare;},get closeComparison(){return controls?.close;},get comparisonStatus(){return controls?.status;},dispose(){if(!active)return;active=false;panelLease++;viewOperation++;clearViewport();left.dispose();right?.dispose();right=null;controls?.dispose();controls=null;pair.dispose();openComparison.removeEventListener('click',open);root.replaceChildren();}};
}

const hosts=new WeakMap();
export async function loadLocalCatalog(fetcher=globalThis.fetch){
  if(typeof fetcher!=='function')throw Error('schema-unavailable');
  const response=await fetcher(new URL('../schema/catalog.json',import.meta.url),{credentials:'omit',redirect:'error'});
  if(!response.ok||!response.body)throw Error('schema-unavailable');
  const declared=Number(response.headers.get('content-length'));
  if(declared>524288)throw Error('schema-unavailable');
  const reader=response.body.getReader(),parts=[];let size=0;
  try{
    while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>524288)throw Error('schema-unavailable');parts.push(value);}
  }catch{try{await reader.cancel();}catch{}throw Error('schema-unavailable');}
  finally{reader.releaseLock();}
  const bytes=new Uint8Array(size);let at=0;for(const part of parts){bytes.set(part,at);at+=part.length;}
  return new TextDecoder('utf-8',{fatal:true}).decode(bytes);
}
export async function bootstrapViewer(document,root,{loadCatalog=loadLocalCatalog,writeClipboard}={}){
  const previous=hosts.get(root);if(previous?.dispose)previous.dispose();
  const lease={};hosts.set(root,lease);root.textContent='Loading the local declaration catalog…';
  let analyze;
  try{analyze=createSchemaAnalyzer(await loadCatalog());}
  catch{analyze=()=>{throw Error('schema-unavailable');};}
  if(hosts.get(root)!==lease)return null;
  const mounted=mountViewer(document,root,{analyze,writeClipboard});const dispose=mounted.dispose;
  lease.dispose=()=>{if(hosts.get(root)===lease)hosts.delete(root);dispose();};mounted.dispose=lease.dispose;return mounted;
}
if(typeof document!=='undefined'){
  const host=document.getElementById('viewer');
  if(host)bootstrapViewer(document,host,{writeClipboard:text=>{
    if(typeof navigator==='undefined'||typeof navigator.clipboard?.writeText!=='function')return Promise.reject(Error('clipboard-unavailable'));
    return navigator.clipboard.writeText(text);
  }});
}
