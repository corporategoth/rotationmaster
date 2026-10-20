import {createViewerSession,createSchemaAnalyzer} from './model.mjs';
import {renderViewer} from './render.mjs';

// Structural analysis is local/declarative; no imported callback can run.
export function mountViewer(document,root,{analyze,writeClipboard}={}){
  const session=createViewerSession({analyze});let active=true,operation=0,release=()=>{};
  const make=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;};
  const heading=make('h1','Rotation Master');const subtitle=make('p','Export viewer');subtitle.setAttribute('class','subtitle');
  const intro=make('p','Read locally. Imported code is never run.');
  const form=make('form');const label=make('label','Paste export');label.setAttribute('for','import-text');
  const input=make('textarea');input.setAttribute('id','import-text');input.setAttribute('rows','7');input.setAttribute('spellcheck','false');input.setAttribute('aria-describedby','import-guidance import-status');
  const guidance=make('p','Maximum import: 2 MiB of UTF-8 text. Decode does not check native spell, target or resource readiness.');guidance.setAttribute('id','import-guidance');
  const decode=make('button','Decode');decode.setAttribute('type','submit');
  const clear=make('button','Clear');clear.setAttribute('type','button');
  const copy=make('button','Copy original export');copy.setAttribute('type','button');copy.disabled=true;
  const actions=make('div');actions.setAttribute('class','actions');actions.append(decode,clear,copy);
  const status=make('p','Paste an RM export to begin.');status.setAttribute('id','import-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  const manualLabel=make('label','Original export — select and copy manually');manualLabel.setAttribute('for','manual-export');manualLabel.hidden=true;
  const manual=make('textarea');manual.setAttribute('id','manual-export');manual.setAttribute('readonly','');manual.setAttribute('rows','4');manual.hidden=true;
  const result=make('div');result.setAttribute('class','result');
  form.append(label,input,guidance,actions);root.replaceChildren(heading,subtitle,intro,form,status,manualLabel,manual,result);
  const listeners=[];
  const on=(e,event,fn)=>{e.addEventListener(event,fn);listeners.push([e,event,fn]);};
  const retire=()=>{operation++;release();release=()=>{};copy.disabled=true;manual.hidden=true;manualLabel.hidden=true;manual.value='';};
  on(input,'input',()=>{if(!active)return;retire();session.edit(input.value);status.textContent='Input changed. Decode to inspect this export.';});
  on(form,'submit',event=>{
    event.preventDefault();if(!active)return;retire();session.edit(input.value);const current=operation,view=session.decode();
    if(!active||current!==operation||!view)return;
    release=renderViewer(document,result,view);copy.disabled=!view.decode.ok;
    status.textContent=view.decode.ok?'Decoded. '+view.structureMessage:'Could not decode: '+view.decode.reason;
    input.setAttribute('aria-invalid',view.decode.ok?'false':'true');
  });
  on(clear,'click',()=>{if(!active)return;retire();session.clear();input.value='';input.setAttribute('aria-invalid','false');status.textContent='Cleared. Paste an RM export to begin.';input.focus();});
  on(copy,'click',async()=>{
    if(!active)return;const original=session.original();if(original===null)return;const current=operation;
    try{if(typeof writeClipboard!=='function')throw Error('clipboard-unavailable');await writeClipboard(original);if(active&&current===operation)status.textContent='Original export copied.';}
    catch{if(!active||current!==operation)return;manual.value=original;manual.hidden=false;manualLabel.hidden=false;status.textContent='Clipboard unavailable. Select and copy the original export below.';manual.focus();manual.select();}
  });
  return {input,form,clear,copy,manual,result,status,dispose(){if(!active)return;active=false;retire();session.clear();for(const [e,event,fn]of listeners)e.removeEventListener(event,fn);root.replaceChildren();}};
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
