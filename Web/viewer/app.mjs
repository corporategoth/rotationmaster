import {createComparisonSession,createSchemaAnalyzer,createBundledViewerSession,createBundledComparisonSession,formatUnicode,formatBytes} from './model.mjs';
import {createBundledRotationCatalog} from '../catalog/defaults.mjs';
import {renderViewer,renderComparison} from './render.mjs';
import {createShareLink,parseShareFragment,prepareOriginalDownload} from './share.mjs';
import {mountDraftEditor} from '../editor/render.mjs';

// Structural analysis is local/declarative; no imported callback can run.
export function mountViewer(document,root,{analyze,schemaText,writeClipboard,compare:compareData,loadBundled,pageURL,downloadFile,readFragment,listenFragment}={}){
  const pair=createComparisonSession({analyze,compare:compareData});let active=true,viewOperation=0,release=()=>{},mode='left',right=null,panelLease=0,controls=null;
  let draftEditor=null;
  const make=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;};
  let area='imports',bundleFacade=null,bundleSession=null,bundleRows=[],bundlePending=null,bundleFailure=false,bundleRequest=0,catalogPaint=0,catalogClass='',selectedID=null,catalogMode='read',catalogComparison=null;
  const heading=make('h1','Rotation Master'),subtitle=make('p','Export viewer');subtitle.setAttribute('class','subtitle');
  const intro=make('p','Read locally. Imported code is never run.');
  const openComparison=make('button','Compare another export');openComparison.setAttribute('type','button');openComparison.setAttribute('aria-expanded','false');
  const panel=make('section');panel.setAttribute('class','compare-input');panel.hidden=true;
  const result=make('div');result.setAttribute('class','result');
  const primaryHost=make('section');primaryHost.setAttribute('class','import-pane');
  const sourceNav=make('nav');sourceNav.setAttribute('aria-label','Data source');sourceNav.setAttribute('class','source-navigation');
  const importsNavigation=make('button','Imports'),bundledNavigation=make('button','Bundled rotations');for(const b of [importsNavigation,bundledNavigation])b.setAttribute('type','button');sourceNav.append(importsNavigation,bundledNavigation);
  const importsArea=make('section'),draftHost=make('section');importsArea.append(primaryHost,draftHost,openComparison,panel);const catalogArea=make('section');catalogArea.setAttribute('class','bundled-browser');catalogArea.hidden=true;
  const incoming=make('section');incoming.setAttribute('id','incoming-share');incoming.setAttribute('role','status');incoming.setAttribute('aria-live','polite');incoming.hidden=true;
  let incomingOperation=0,fragmentCleanup=null;
  root.replaceChildren(heading,subtitle,intro,sourceNav,incoming,importsArea,catalogArea,result);
  const clearViewport=()=>{release();release=()=>{};};
  function navState(){if(!controls)return;for(const [key,b]of Object.entries(controls.nav))b.setAttribute('aria-pressed',String(mode===key));controls.nav.diff.disabled=pair.view()===null;}
  function show(side,focus=false){
    if(!active||area!=='imports')return;viewOperation++;clearViewport();mode=side;
    if(side==='diff'){const value=pair.view();if(value)release=renderComparison(document,result,value);}
    else{const value=pair.pane(side).view();if(value)release=renderViewer(document,result,value);}
    navState();if(focus){const h=result.children[0]?.children[0];if(h?.focus){h.setAttribute('tabindex','-1');h.focus();}}
  }
  function invalidate(side){
    if(side==='left'){draftEditor?.retire();retireCatalogComparison();}
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
    const share=make('button','Copy share link'),download=make('button','Download original export');
    for(const [button,name]of [[share,'share-link'],[download,'download-original']]){button.setAttribute('type','button');button.setAttribute('id',prefix+name);button.disabled=true;}
    const actions=make('div');actions.setAttribute('class','actions');actions.append(decode,clear,copy,share,download);form.append(label,input,guidance,actions,make('p','Share links contain the complete original export; anyone with the link can read it.'));
    const status=make('p','Paste an RM export to begin.');status.setAttribute('id',prefix+'import-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const manualLabel=make('label','Original export — select and copy manually');manualLabel.setAttribute('for',prefix+'manual-export');manualLabel.hidden=true;
    const manual=make('textarea');manual.setAttribute('id',prefix+'manual-export');manual.setAttribute('readonly','');manual.setAttribute('rows','4');manual.hidden=true;
    const shareLabel=make('label','Share link — select and copy manually');shareLabel.setAttribute('for',prefix+'manual-share-link');shareLabel.hidden=true;
    const shareManual=make('textarea');shareManual.setAttribute('id',prefix+'manual-share-link');shareManual.setAttribute('readonly','');shareManual.setAttribute('rows','4');shareManual.hidden=true;
    owner.append(form,status,manualLabel,manual,shareLabel,shareManual);
    const listeners=[],on=(e,event,fn)=>{e.addEventListener(event,fn);listeners.push([e,event,fn]);};
    const retire=()=>{operation++;copy.disabled=true;share.disabled=true;download.disabled=true;manual.hidden=true;manualLabel.hidden=true;manual.value='';shareManual.hidden=true;shareLabel.hidden=true;shareManual.value='';};
    const synchronize=()=>{if(!active||!live||area!=='imports')return;invalidate(side);retire();session.edit(input.value);status.textContent='Input changed. Decode to inspect this export.';if(side==='left')draftEditor?.refresh();};
    on(input,'input',synchronize);
    on(form,'submit',event=>{
      event.preventDefault();if(!active||!live||area!=='imports')return;invalidate(side);retire();session.edit(input.value);const token=viewOperation,current=operation,view=session.decode();
      if(!active||!live||area!=='imports'||current!==operation||token!==viewOperation||!view)return;
      copy.disabled=share.disabled=download.disabled=!view.decode.ok;status.textContent=view.decode.ok?'Decoded. '+view.structureMessage:'Could not decode: '+view.decode.reason;input.setAttribute('aria-invalid',view.decode.ok?'false':'true');show(side);if(side==='left')draftEditor?.refresh();
    });
    on(clear,'click',()=>{if(!active||!live||area!=='imports')return;invalidate(side);retire();session.clear();input.value='';input.setAttribute('aria-invalid','false');status.textContent='Cleared. Paste an RM export to begin.';if(side==='left')draftEditor?.refresh();input.focus();});
    on(copy,'click',async()=>{
      if(!active||!live||area!=='imports')return;const original=session.original();if(original===null)return;draftEditor?.supersedeClipboard();const current=++operation,focusToken=viewOperation;
      try{if(typeof writeClipboard!=='function')throw Error('clipboard-unavailable');await writeClipboard(original);if(active&&live&&current===operation)status.textContent='Original export copied.';}
      catch{if(!active||!live||current!==operation)return;manual.value=original;manual.hidden=false;manualLabel.hidden=false;status.textContent='Clipboard unavailable. Select and copy the original export below.';if(focusToken===viewOperation){manual.focus();manual.select();}}
    });
    const acceptedOriginal=()=>{
      if(!active||!live||area!=='imports'||root.children[0]!==heading)return null;
      if(input.value!==session.input()){status.textContent='Decode the current input before sharing or downloading.';return null;}
      const original=session.original();if(original===null)status.textContent='Decode this export before sharing or downloading.';return original;
    };
    const currentAction=(token,original)=>active&&live&&root.children[0]===heading&&token===operation&&input.value===session.input()&&session.original()===original;
    on(share,'click',async()=>{
      const original=acceptedOriginal();if(original===null)return;draftEditor?.supersedeClipboard();const token=++operation,focusToken=viewOperation;
      shareManual.hidden=true;shareLabel.hidden=true;shareManual.value='';
      const link=createShareLink(original,pageURL);
      if(!link.ok){status.textContent=link.reason==='share-size-limit'?'This export is too large for a share link. Copy or download the original instead.':'Share link unavailable for this page. Copy or download the original instead.';return;}
      try{if(typeof writeClipboard!=='function')throw Error('clipboard-unavailable');await writeClipboard(link.url);if(currentAction(token,original))status.textContent='Share link copied.';}
      catch{if(!currentAction(token,original))return;shareManual.value=link.url;shareManual.hidden=false;shareLabel.hidden=false;status.textContent='Clipboard unavailable. Select and copy the share link below.';if(area==='imports'&&focusToken===viewOperation){shareManual.focus();shareManual.select();}}
    });
    on(download,'click',async()=>{
      const original=acceptedOriginal();if(original===null)return;draftEditor?.supersedeClipboard();const token=++operation,file=prepareOriginalDownload(original);
      if(!file.ok){status.textContent='Download unavailable. Copy the original export instead.';return;}
      try{if(typeof downloadFile!=='function')throw Error('download-unavailable');await downloadFile(file);if(currentAction(token,original))status.textContent='Original export download requested.';}
      catch{if(currentAction(token,original))status.textContent='Download unavailable. Copy the original export instead.';}
    });
    return {input,form,clear,copy,manual,result,status,synchronize,dispose(){if(!live)return;live=false;retire();session.clear();input.value='';for(const [e,event,fn]of listeners)e.removeEventListener(event,fn);owner.replaceChildren();}};
  }
  const left=pane('left',primaryHost);
  draftEditor=mountDraftEditor(document,draftHost,{schemaText,writeClipboard,
    readSource:()=>active&&root.children[0]===heading&&left.input.value===pair.pane('left').input()?pair.pane('left').view():null,
    isVisible:()=>active&&area==='imports'&&root.children[0]===heading,
    onAction:()=>{viewOperation++;},focusLease:()=>viewOperation});
  catalogComparison=createBundledComparisonSession({readImport:()=>left.input.value===pair.pane('left').input()?pair.pane('left').view():null,readBundled:()=>bundleSession?.view()??null,compare:compareData});
  function retireCatalogComparison(){catalogComparison?.clear();catalogMode='read';}
  function focusCatalogResult(token){if(!active||area!=='bundled'||token!==viewOperation)return;const h=result.children[0]?.children[0];if(h?.focus){h.setAttribute('tabindex','-1');h.focus();}}
  const open=()=>{
    if(!active||area!=='imports')return;if(right){right.input.focus();return;}const lease=++panelLease;viewOperation++;panel.hidden=false;openComparison.setAttribute('aria-expanded','true');
    const title=make('h2','Second export'),rightHost=make('div');panel.append(title,rightHost);right=pane('right',rightHost);
    const compare=make('button','Compare');compare.setAttribute('type','button');const close=make('button','Close comparison');close.setAttribute('type','button');
    const status=make('p','Decode both exports, then compare.');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const nav=make('nav');nav.setAttribute('aria-label','Result view');const buttons={};for(const [key,text]of [['left','First export'],['right','Second export'],['diff','Differences']]){const b=make('button',text);b.setAttribute('type','button');buttons[key]=b;nav.append(b);}
    const listeners=[],on=(e,event,fn)=>{const guarded=event=>{if(active&&area==='imports'&&lease===panelLease&&right)fn(event);};e.addEventListener(event,guarded);listeners.push([e,event,guarded]);};
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
  function sourceState(){importsArea.hidden=area!=='imports';catalogArea.hidden=area!=='bundled';importsNavigation.setAttribute('aria-pressed',String(area==='imports'));bundledNavigation.setAttribute('aria-pressed',String(area==='bundled'));}
  const sameRequest=token=>active&&token===bundleRequest;
  async function acquireBundle(retry=false){
    if(bundleFacade)return true;if(bundlePending)return bundlePending;if(bundleFailure&&!retry)return false;
    const token=++bundleRequest;bundleFailure=false;let complete;const reserved=new Promise(resolve=>{complete=resolve;});bundlePending=reserved;
    const work=(async()=>{
      try{
        if(typeof loadBundled!=='function')throw Error('bundled-unavailable');
        const facade=await loadBundled();if(!sameRequest(token))return false;
        const list=facade?.list,get=facade?.get;if(!sameRequest(token)||typeof list!=='function'||typeof get!=='function')throw Error('bundled-unavailable');
        const rows=list.call(facade);if(!sameRequest(token))return false;
        if(!Array.isArray(rows)||rows.length>64)throw Error('bundled-unavailable');
        const seen=new Set(),owned=[];for(let i=0;i<rows.length;i++){
          if(!Object.hasOwn(rows,i))throw Error('bundled-unavailable');const row=rows[i],id=row?.id,applicability=row?.applicability,name=row?.display?.name;
          if(typeof id!=='string'||!/^[A-Za-z0-9][A-Za-z0-9._:\-]*$/.test(id)||id.length>128||seen.has(id)||!(applicability instanceof Map)||typeof name!=='string'||name.length>262144)throw Error('bundled-unavailable');
          const classToken=Map.prototype.get.call(applicability,'class');seen.add(id);owned.push({id,classToken,name});
        }
        if(!sameRequest(token))return false;
        bundleSession=createBundledViewerSession({catalog:facade,analyze});bundleRows=owned;bundleFacade=facade;return true;
      }catch{if(sameRequest(token))bundleFailure=true;return false;}
    })();
    const ok=await work;complete(ok);if(sameRequest(token)&&bundlePending===reserved)bundlePending=null;return bundleFacade!==null;
  }
  function drawCatalog(focusFilter=false){
    if(!active||area!=='bundled')return;const ticket=++catalogPaint;clearViewport();catalogArea.replaceChildren();
    const current=()=>active&&area==='bundled'&&ticket===catalogPaint;
    const title=make('h2','Bundled rotations'),status=make('p');status.setAttribute('id','catalog-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');catalogArea.append(title,status);
    if(!bundleFacade){
      status.textContent=bundleFailure?'Bundled rotations are unavailable. Imports remain available.':'Loading bundled rotations…';
      if(bundleFailure){const retry=make('button','Retry');retry.setAttribute('type','button');retry.addEventListener('click',async()=>{if(!current())return;const token=++viewOperation;const pending=acquireBundle(true);drawCatalog();await pending;if(active&&area==='bundled'&&token===viewOperation)drawCatalog();});catalogArea.append(retry);}return;
    }
    status.textContent='Declared source data only. Native readiness is unverified.';
    const label=make('label','Declared class');label.setAttribute('for','catalog-filter');const filter=make('select');filter.setAttribute('id','catalog-filter');
    const tokens=[...new Set(bundleRows.map(r=>r.classToken).filter(x=>typeof x==='string'))].sort();
    for(const [value,text]of [['','All declarations'],...tokens.map(x=>[x,formatBytes(x,{limit:80}).text])]){const option=make('option',text);option.value=value;filter.append(option);}filter.value=catalogClass;catalogArea.append(label,filter);
    filter.addEventListener('change',()=>{if(!current())return;catalogClass=tokens.includes(filter.value)?filter.value:'';const selected=bundleRows.find(r=>r.id===selectedID);if(selected&&catalogClass&&selected.classToken!==catalogClass){retireCatalogComparison();selectedID=null;bundleSession.clear();}viewOperation++;drawCatalog(true);});
    const list=make('ul');list.setAttribute('id','catalog-list');const rows=bundleRows.filter(r=>!catalogClass||r.classToken===catalogClass);catalogArea.append(make('p',rows.length+' declarations. Select one to inspect its data.'),list);
    for(const row of rows){const item=make('li'),part=formatUnicode(row.name,{limit:80}),choice=make('button',part.text+(part.remaining?'…':''));choice.setAttribute('type','button');choice.setAttribute('data-default-id',row.id);choice.setAttribute('aria-pressed',String(row.id===selectedID));
      choice.addEventListener('click',()=>{if(!current())return;const token=++viewOperation;retireCatalogComparison();const view=bundleSession.select(row.id);if(!current()||token!==viewOperation)return;selectedID=view?row.id:null;drawCatalog();if(view){const h=result.children[0]?.children[0];if(h?.focus){h.setAttribute('tabindex','-1');h.focus();}}});item.append(choice);list.append(item);}
    const view=bundleSession.view();if(!current())return;
    if(view){
      const actions=make('div');actions.setAttribute('class','actions');const compare=make('button','Compare with first export'),read=make('button','Read bundled rotation');compare.setAttribute('id','compare-first-bundled');read.setAttribute('id','read-bundled');for(const b of [compare,read])b.setAttribute('type','button');read.disabled=catalogMode==='read';actions.append(compare,read);catalogArea.append(actions);
      compare.addEventListener('click',()=>{if(!current())return;const token=++viewOperation,value=catalogComparison.compare();if(!current()||token!==viewOperation)return;catalogMode=value?'comparison':'read';drawCatalog();focusCatalogResult(token);});
      read.addEventListener('click',()=>{if(!current())return;const token=++viewOperation;retireCatalogComparison();drawCatalog();focusCatalogResult(token);});
      const comparison=catalogMode==='comparison'?catalogComparison.view():null;if(!current())return;
      if(comparison)release=renderComparison(document,result,comparison);else{catalogMode='read';read.disabled=true;release=renderViewer(document,result,view);}
    }
    if(focusFilter&&current())filter.focus();
  }
  const showImports=()=>{if(!active)return;retireCatalogComparison();viewOperation++;catalogPaint++;clearViewport();area='imports';sourceState();show(mode);};
  const showBundled=async()=>{if(!active)return;const token=++viewOperation;catalogPaint++;clearViewport();area='bundled';sourceState();const pending=acquireBundle();drawCatalog();await pending;if(active&&area==='bundled'&&token===viewOperation)drawCatalog();};
  importsNavigation.addEventListener('click',showImports);bundledNavigation.addEventListener('click',showBundled);sourceState();
  openComparison.addEventListener('click',open);
  function refreshIncoming(){
    if(!active||root.children[0]!==heading)return;const token=++incomingOperation;let candidate;
    try{candidate=typeof readFragment==='function'?parseShareFragment(readFragment()):{ok:false,reason:'no-share-fragment'};}
    catch{candidate={ok:false,reason:'invalid-share-fragment'};}
    if(!active||token!==incomingOperation||root.children[0]!==heading)return;
    incoming.replaceChildren();incoming.hidden=candidate.reason==='no-share-fragment';if(incoming.hidden)return;
    const current=()=>active&&token===incomingOperation&&root.children[0]===heading;
    if(candidate.ok){
      incoming.append(make('p','A shared export is available. Load replaces the first input; Decode remains required.'));
      const load=make('button','Load into first export');load.setAttribute('type','button');
      load.addEventListener('click',()=>{if(!current())return;incomingOperation++;incoming.replaceChildren();incoming.hidden=true;showImports();left.input.value=candidate.original;left.synchronize();show('left');left.input.setAttribute('aria-invalid','false');left.input.focus();});incoming.append(load);
    }else incoming.append(make('p',candidate.reason==='unsupported-share-version'?'This shared export version is unsupported.':'The shared export link is unavailable. Imports remain available.'));
    const dismiss=make('button','Dismiss');dismiss.setAttribute('type','button');dismiss.addEventListener('click',()=>{if(!current())return;incomingOperation++;incoming.replaceChildren();incoming.hidden=true;});incoming.append(dismiss);
  }
  refreshIncoming();
  if(active&&root.children[0]===heading&&typeof listenFragment==='function'){
    const token=incomingOperation;
    try{const cleanup=listenFragment(refreshIncoming);if(active)fragmentCleanup=typeof cleanup==='function'?cleanup:null;else if(typeof cleanup==='function')cleanup();}catch{if(active&&token===incomingOperation&&root.children[0]===heading){incoming.append(make('p','Shared export updates are unavailable. Imports remain available.'));incoming.hidden=false;}}
  }
  return {...left,openComparison,importsNavigation,bundledNavigation,get right(){return right;},get compare(){return controls?.compare;},get closeComparison(){return controls?.close;},get comparisonStatus(){return controls?.status;},dispose(){if(!active)return;active=false;draftEditor?.dispose();incomingOperation++;const cleanup=fragmentCleanup;fragmentCleanup=null;if(cleanup)try{cleanup();}catch{}catalogComparison.dispose();bundleRequest++;catalogPaint++;bundleSession?.dispose();bundleRows=[];bundleFacade=null;panelLease++;viewOperation++;clearViewport();left.dispose();right?.dispose();right=null;controls?.dispose();controls=null;pair.dispose();openComparison.removeEventListener('click',open);importsNavigation.removeEventListener('click',showImports);bundledNavigation.removeEventListener('click',showBundled);if(root.children[0]===heading)root.replaceChildren();}};
}

const hosts=new WeakMap();
const schemaResource=Object.freeze({url:new URL('../schema/catalog.json',import.meta.url).href,limit:524288,error:'schema-unavailable'});
const bundledResource=Object.freeze({url:new URL('../catalog/defaults.json',import.meta.url).href,limit:2097152,error:'bundled-unavailable'});
async function readResource(fetcher,spec){
  let body,reader,cancelled=false;
  const cancel=async()=>{if(cancelled)return;cancelled=true;try{if(reader)await reader.cancel();else if(body)await body.cancel();}catch{}};
  try{
    if(typeof fetcher!=='function')throw Error(spec.error);
    const response=await fetcher(new URL(spec.url),{credentials:'omit',redirect:'error'});body=response.body;
    if(!response.ok||!body||Number(response.headers.get('content-length'))>spec.limit)throw Error(spec.error);
    reader=body.getReader();const parts=[];let size=0;
    while(true){const {done,value}=await reader.read();if(done)break;if(!(value instanceof Uint8Array))throw Error(spec.error);size+=value.byteLength;if(size>spec.limit)throw Error(spec.error);parts.push(value);}
    const bytes=new Uint8Array(size);let at=0;for(const part of parts){bytes.set(part,at);at+=part.length;}
    return new TextDecoder('utf-8',{fatal:true}).decode(bytes);
  }catch{await cancel();throw Error(spec.error);}
  finally{if(reader)try{reader.releaseLock();}catch{}}
}
export async function loadLocalCatalog(fetcher=globalThis.fetch){return readResource(fetcher,schemaResource);}
export async function loadBundledCatalog(fetcher=globalThis.fetch){return readResource(fetcher,bundledResource);}
export async function bootstrapViewer(document,root,{loadCatalog=loadLocalCatalog,loadBundled=loadBundledCatalog,writeClipboard,pageURL,downloadFile,readFragment,listenFragment}={}){
  const previous=hosts.get(root),lease={};hosts.set(root,lease);if(previous?.dispose)previous.dispose();
  if(hosts.get(root)!==lease)return null;root.textContent='Loading the local declaration catalog…';
  let analyze,schemaText=null;
  try{schemaText=await loadCatalog();analyze=createSchemaAnalyzer(schemaText);analyze({kind:'envelope',value:new Map()});}
  catch{schemaText=null;analyze=()=>{throw Error('schema-unavailable');};}
  if(hosts.get(root)!==lease)return null;
  const current=()=>hosts.get(root)===lease;
  const ownedFragmentRead=typeof readFragment==='function'?()=>current()?readFragment():'':readFragment;
  const ownedFragmentListen=typeof listenFragment==='function'?callback=>current()?listenFragment(callback):undefined:listenFragment;
  const mounted=mountViewer(document,root,{analyze,schemaText,writeClipboard,pageURL,downloadFile,readFragment:ownedFragmentRead,listenFragment:ownedFragmentListen,loadBundled:async()=>{if(schemaText===null)throw Error('bundled-unavailable');const parsed=createBundledRotationCatalog(await loadBundled(),schemaText);if(!parsed.ok)throw Error('bundled-unavailable');return parsed.catalog;}});const dispose=mounted.dispose;
  if(!current()){dispose();return null;}
  lease.dispose=()=>{if(hosts.get(root)===lease)hosts.delete(root);dispose();};mounted.dispose=lease.dispose;return mounted;
}
if(typeof document!=='undefined'){
  const host=document.getElementById('viewer');
  if(host)bootstrapViewer(document,host,{
    pageURL:globalThis.location?.href,
    readFragment:()=>globalThis.location?.hash??'',
    listenFragment:callback=>{globalThis.addEventListener('hashchange',callback);return()=>globalThis.removeEventListener('hashchange',callback);},
    downloadFile:file=>{
      const blob=new Blob([file.bytes],{type:file.mediaType,endings:'transparent'}),url=URL.createObjectURL(blob);let link;
      try{link=document.createElement('a');link.setAttribute('href',url);link.setAttribute('download',file.filename);document.body.append(link);link.click();}
      finally{try{link?.remove();}finally{URL.revokeObjectURL(url);}}
    },
    writeClipboard:text=>{
    if(typeof navigator==='undefined'||typeof navigator.clipboard?.writeText!=='function')return Promise.reject(Error('clipboard-unavailable'));
    return navigator.clipboard.writeText(text);
  }});
}
