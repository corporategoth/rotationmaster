import {formatBytes,pathText,rawEntries,valueText} from './model.mjs';

let nextRenderer=0;
export function renderViewer(document,root,view){
  const instance=++nextRenderer;
  let active=true,revision=0,rawPage=0,stepPage=0,diagnosticPage=0,selected=null,byteOffset=0;
  const data=view.decode?.value,raw=view.decode?.ok?rawEntries(data):[];
  const rows=view.analysis?.validation.valid&&view.analysis.index?.rows||[];
  let mode=rows.length?'ordered':'raw';
  const shortPath=(path,limit)=>{const text=pathText(path);return text.length>limit?text.slice(0,limit)+'…':text;};
  const node=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.setAttribute('class',cls);return e;};
  function draw(focus){
    if(!active)return;const ticket=++revision;root.replaceChildren();
    let nodes=0,chars=0,contextID=0,focusTarget;
    const add=(parent,tag,content,cls)=>{
      if(nodes>=1900||chars>=90000)return null;
      content=String(content??'');content=content.slice(0,Math.max(0,90000-chars));nodes++;chars+=content.length;
      const e=node(tag,content,cls);parent.append(e);return e;
    };
    const describe=e=>{if(!e)return;const id='rmv-context-'+instance+'-'+ticket+'-'+(++contextID);e.setAttribute('id',id);return id;};
    const button=(parent,label,fn,description)=>{const b=add(parent,'button',label);if(!b)return;b.setAttribute('type','button');if(description)b.setAttribute('aria-describedby',description);b.addEventListener('click',()=>{if(active&&ticket===revision)fn();});return b;};
    if(!view.decode?.ok){add(root,'p','Could not decode: '+(view.decode?.reason||'unknown-transport-error'),'problem');return;}
    const status=add(root,'section','','status');const statusHeading=add(status,'h2','Import status');statusHeading.setAttribute('tabindex','-1');if(focus==='diagnostics')focusTarget=statusHeading;add(status,'p','Decoded '+view.decode.kind+' transport.');
    add(status,'p',view.structureMessage);const validation=view.analysis?.validation;
    if(validation&&view.analysis.recognized!==false){add(status,'p','Structure '+(validation.valid?'valid':'invalid')+'; '+(validation.supported?'supported':'contains unsupported data')+'; References '+(validation.resolved?'found':'unresolved')+'.');}
    add(status,'p','Semantics not evaluated. Native readiness not checked. Gameplay quality unreviewed.','caution');
    if(validation?.diagnostics.length){
      add(status,'p','Diagnostics '+(diagnosticPage*20+1)+'–'+Math.min(validation.diagnostics.length,(diagnosticPage+1)*20)+' of '+validation.diagnostics.length);
      const list=add(status,'ul','');for(const d of validation.diagnostics.slice(diagnosticPage*20,(diagnosticPage+1)*20))add(list,'li',valueText(d.path||'$',80)+': '+valueText(d.code||'structural-diagnostic',80));
      if(diagnosticPage>0)button(status,'Previous diagnostics',()=>{diagnosticPage--;draw('diagnostics');});
      if((diagnosticPage+1)*20<validation.diagnostics.length)button(status,'Next diagnostics',()=>{diagnosticPage++;draw('diagnostics');});
    }
    const content=add(root,'div','','content');
    const declared=add(root,'section','','declared');add(declared,'h2','Declared information');
    let declaredLeaves=0;
    if(data instanceof Map){for(const key of ['name','nameKey','id','revision','applicability','sources','metadata'])if(data.has(key)){
      const value=data.get(key);add(declared,'p',key+': '+valueText(value,96));
      if(value instanceof Map)for(const row of rawEntries(value))if(!(row.value instanceof Map)&&declaredLeaves<12){declaredLeaves++;add(declared,'p',key+shortPath(row.path,64)+': '+valueText(row.value,96));}
    }}
    add(declared,'p','Declared metadata preview only. Inspect raw data for all fields and full byte values.');
    add(declared,'p','Missing legacy scope or provenance is not declared; it is not inferred from action IDs.');
    if(rows.length){const tools=add(content,'nav','','view-tools');tools.setAttribute('aria-label','Content view');button(tools,'Show ordered content',()=>{mode='ordered';selected=null;draw('ordered');});button(tools,'Show raw data',()=>{mode='raw';selected=null;draw('raw');});}
    if(rows.length&&mode==='ordered'){
      const ordered=add(content,'section','','ordered');const heading=add(ordered,'h2','Ordered actions');heading.setAttribute('tabindex','-1');if(focus==='ordered')focusTarget=heading;
      add(ordered,'p','Rows '+(stepPage*50+1)+'–'+Math.min(rows.length,(stepPage+1)*50)+' of '+rows.length+'. Authored order; no conditions are evaluated.');
      let section;
      for(const row of rows.slice(stepPage*50,(stepPage+1)*50)){
        if(row.section!==section){section=row.section;add(ordered,'h3',section==='cooldowns'?'Cooldowns':'Rotation');}
        const step=row.step;if(!(step instanceof Map))continue;
        const card=add(ordered,'article','','step');if(!card)break;
        const type=step.get('type');let label=String(row.index??'?')+'. '+valueText(type,24);
        if(type==='branch')label+=' · '+(step.get('mode')==='true'?'Forced true':step.get('mode')==='false'?'Forced false':'Evaluate guard');
        else if(step.has('action'))label+=' '+valueText(step.get('action'),48);
        if(row.arm)label+=' · '+(row.arm==='true'?'True arm':'False arm');
        if(step.get('disabled'))label+=' · Disabled';if(row.unreachable)label+=' · Forced-away arm';
        const description=describe(add(card,'h4',label));add(card,'p',shortPath(row.path||[],128),'path');
        for(const key of ['ranked','use_name','suppress_attack'])if(step.has(key))add(card,'p',key+': '+valueText(step.get(key)));
        const cond=step.get('conditions');if(cond instanceof Map){const lines=rawEntries(cond).slice(0,12).map(x=>pathText(x.path)+' = '+valueText(x.value,80));add(card,'pre','Guard preview (literal data)\n'+lines.join('\n').slice(0,256));add(card,'p','Inspect step for complete fields.');}
        button(card,'Inspect step',()=>{selected={path:row.path||[],value:step};byteOffset=0;draw('inspection');},description);
      }
      if(stepPage>0)button(ordered,'Previous actions',()=>{stepPage--;draw('ordered');});
      if((stepPage+1)*50<rows.length)button(ordered,'Next actions',()=>{stepPage++;draw('ordered');});
      const switching=view.analysis.body?.get('switch');if(switching instanceof Map){add(ordered,'h3','Switch conditions');add(ordered,'p','Literal switching guard; native state is not evaluated.');button(ordered,'Inspect switch',()=>{selected={path:['switch'],value:switching};byteOffset=0;draw('inspection');});}
    }else if(view.analysis&&!rows.length){add(content,'p','Ordered preview is unavailable or empty. Inspect the original structure below.');}
    if(mode==='raw'){
    const rawSection=add(content,'section','','raw');const rawHeading=add(rawSection,'h2','Raw decoded data');rawHeading.setAttribute('tabindex','-1');if(focus==='raw')focusTarget=rawHeading;
    add(rawSection,'p',raw.length+' entries; showing '+(raw.length?rawPage*200+1:0)+'–'+Math.min(raw.length,(rawPage+1)*200)+'. Byte and number keys remain distinct.');
    for(const row of raw.slice(rawPage*200,(rawPage+1)*200)){
      const line=add(rawSection,'div','','raw-row');if(!line)break;
      const description=describe(add(line,'pre',shortPath(row.path,96)+' = '+valueText(row.value,32)));
      button(line,'Inspect value',()=>{selected=row;byteOffset=0;draw('inspection');},description);
      const key=row.path[row.path.length-1];if(typeof key==='string'&&key.length>80)button(line,'Inspect key',()=>{selected={path:row.path.slice(0,-1),value:key};byteOffset=0;draw('inspection');},description);
    }
    if(rawPage>0)button(rawSection,'Previous entries',()=>{rawPage--;draw('raw');});
    if((rawPage+1)*200<raw.length)button(rawSection,'Next entries',()=>{rawPage++;draw('raw');});
    }
    if(selected){
      const detail=add(root,'section','','inspection');const inspectionHeading=add(detail,'h2','Value inspection');inspectionHeading.setAttribute('tabindex','-1');if(focus==='inspection')focusTarget=inspectionHeading;
      add(detail,'pre',shortPath(selected.path,4096));
      if(typeof selected.value==='string'){
        const part=formatBytes(selected.value,{offset:byteOffset,limit:1024});add(detail,'pre',part.text);
        add(detail,'p','Bytes '+(selected.value.length?byteOffset+1:0)+'–'+Math.min(selected.value.length,byteOffset+1024)+' of '+selected.value.length+'. '+part.remaining+' remaining.');
        if(byteOffset>0)button(detail,'Previous bytes',()=>{byteOffset=Math.max(0,byteOffset-1024);draw('inspection');});
        if(part.remaining)button(detail,'Next bytes',()=>{byteOffset+=1024;draw('inspection');});
      }else if(selected.value instanceof Map){for(const row of rawEntries(selected.value).slice(0,20))add(detail,'pre',pathText(row.path).slice(0,256)+' = '+valueText(row.value));add(detail,'p','Nested values remain in the raw decoded data pages.');}
      else add(detail,'pre',valueText(selected.value));
      button(detail,'Close inspection',()=>{selected=null;draw(mode==='raw'?'raw':'ordered');});
    }
    if(focusTarget)focusTarget.focus();
    if(nodes>=1900||chars>=90000)add(root,'p','Rendering limit reached. Use raw data pages to inspect remaining content.');
  }
  draw();return ()=>{active=false;revision++;selected=null;root.replaceChildren();};
}
