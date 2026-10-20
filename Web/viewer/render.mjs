import {formatBytes,formatUnicode,pathText,rawEntries,valueText} from './model.mjs';

// Shared bounded text-only drawing, raw paging and byte inspection. Both source
// readers and comparison details use these exact routines; no imported HTML.
function drawing(document,root,instance,ticket,current){
  let nodes=0,chars=0,contextID=0;
  const add=(parent,tag,content,cls)=>{
    if(!parent||nodes>=1900||chars>=90000)return null;
    content=String(content??'');content=content.slice(0,Math.max(0,90000-chars));nodes++;chars+=content.length;
    const e=document.createElement(tag);e.textContent=content;if(cls)e.setAttribute('class',cls);parent.append(e);return e;
  };
  const describe=e=>{if(!e)return;const id='rmv-context-'+instance+'-'+ticket+'-'+(++contextID);e.setAttribute('id',id);return id;};
  const button=(parent,label,fn,description)=>{const b=add(parent,'button',label);if(!b)return;b.setAttribute('type','button');if(description)b.setAttribute('aria-describedby',description);b.addEventListener('click',()=>{if(current())fn();});return b;};
  return {add,button,describe,atLimit:()=>nodes>=1900||chars>=90000};
}
function rawPage(ui,parent,rows,page,inspect,navigate,heading='Raw decoded data'){
  const {add,button,describe}=ui,section=add(parent,'section','','raw');const title=add(section,'h2',heading);title?.setAttribute('tabindex','-1');
  add(section,'p',rows.length+' entries; showing '+(rows.length?page*200+1:0)+'–'+Math.min(rows.length,(page+1)*200)+'. Byte and number keys remain distinct.');
  for(const row of rows.slice(page*200,(page+1)*200)){
    const line=add(section,'div','','raw-row');if(!line)break;
    const path=pathText(row.path),description=describe(add(line,'pre',(path.length>96?path.slice(0,96)+'…':path)+' = '+valueText(row.value,32)));
    button(line,'Inspect value',()=>inspect(row),description);
    const key=row.path[row.path.length-1];if(typeof key==='string'&&key.length>80)button(line,'Inspect key',()=>inspect({path:row.path.slice(0,-1),value:key}),description);
  }
  if(page>0)button(section,'Previous entries',()=>navigate(page-1));
  if((page+1)*200<rows.length)button(section,'Next entries',()=>navigate(page+1));
  return title;
}
function diagnosticList(ui,parent,diagnostics,page,navigate){
  if(!diagnostics.length)return;
  ui.add(parent,'p','Diagnostics '+(page*20+1)+'–'+Math.min(diagnostics.length,(page+1)*20)+' of '+diagnostics.length);
  const list=ui.add(parent,'ul','');for(const d of diagnostics.slice(page*20,(page+1)*20))ui.add(list,'li',valueText(d.path||'$',80)+': '+valueText(d.code||'structural-diagnostic',80));
  if(page>0)ui.button(parent,'Previous diagnostics',()=>navigate(page-1));
  if((page+1)*20<diagnostics.length)ui.button(parent,'Next diagnostics',()=>navigate(page+1));
}
function byteDetails(ui,parent,value,offset,navigate){
  const part=formatBytes(value,{offset,limit:1024});ui.add(parent,'pre',part.text);
  ui.add(parent,'p','Bytes '+(value.length?offset+1:0)+'–'+Math.min(value.length,offset+1024)+' of '+value.length+'. '+part.remaining+' remaining.');
  if(offset>0)ui.button(parent,'Previous bytes',()=>navigate(Math.max(0,offset-1024)));
  if(part.remaining)ui.button(parent,'Next bytes',()=>navigate(offset+1024));
}

let nextRenderer=0;
export function renderViewer(document,root,view){
  const instance=++nextRenderer;
  let active=true,revision=0,rawPageIndex=0,stepPage=0,diagnosticPage=0,selected=null,byteOffset=0;
  const bundled=view.sourceKind==='bundled',data=bundled?view.value:view.decode?.value,accepted=bundled?data instanceof Map:view.decode?.ok,raw=accepted?rawEntries(data):[];
  const rows=(!bundled||view.analysis?.recognized!==false)&&view.analysis?.validation.valid&&view.analysis.index?.rows||[];
  let mode=rows.length?'ordered':'raw';
  const shortPath=(path,limit)=>{const text=pathText(path);return text.length>limit?text.slice(0,limit)+'…':text;};
  function draw(focus){
    if(!active)return;const ticket=++revision;root.replaceChildren();let focusTarget;
    const ui=drawing(document,root,instance,ticket,()=>active&&ticket===revision),{add,button,describe}=ui;
    if(!accepted){add(root,'p','Could not decode: '+(view.decode?.reason||'unknown-transport-error'),'problem');return;}
    const status=add(root,'section','','status');const statusHeading=add(status,'h2',bundled?'Bundled rotation':'Import status');statusHeading.setAttribute('tabindex','-1');if(focus==='diagnostics')focusTarget=statusHeading;if(bundled){
      add(status,'p','Generated bundled data. Declared revision '+valueText(data.get('revision'))+'.');
      add(status,'p','Source '+valueText(view.source?.path,256)+'; SHA-256 '+valueText(view.source?.sha256,64)+'. Consistency metadata, not authenticated upstream content.');
      for(const [key,label]of [['name','Name'],['description','Description']]){const human=view.display?.[key];if(typeof human!=='string')continue;const part=formatUnicode(human,{limit:key==='name'?80:160});add(status,'p',label+': '+part.text+(part.remaining?'…':''));button(status,'Inspect '+key,()=>{selected={path:[],value:human,human:true,label};byteOffset=0;draw('inspection');});}
    }else add(status,'p','Decoded '+view.decode.kind+' transport.');
    add(status,'p',view.structureMessage);const validation=view.analysis?.validation;
    if(validation&&view.analysis.recognized!==false){add(status,'p','Structure '+(validation.valid?'valid':'invalid')+'; '+(validation.supported?'supported':'contains unsupported data')+'; References '+(validation.resolved?'found':'unresolved')+'.');}
    add(status,'p','Semantics not evaluated. Native readiness not checked. Gameplay quality unreviewed.','caution');
    if(validation)diagnosticList(ui,status,validation.diagnostics,diagnosticPage,page=>{diagnosticPage=page;draw('diagnostics');});
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
      const heading=rawPage(ui,content,raw,rawPageIndex,row=>{selected=row;byteOffset=0;draw('inspection');},page=>{rawPageIndex=page;draw('raw');},bundled?'Raw manifest data':'Raw decoded data');
      if(focus==='raw')focusTarget=heading;
    }
    if(selected){
      const detail=add(root,'section','','inspection');const inspectionHeading=add(detail,'h2','Value inspection');inspectionHeading.setAttribute('tabindex','-1');if(focus==='inspection')focusTarget=inspectionHeading;
      add(detail,'pre',shortPath(selected.path,4096));
      if(selected.human){
        const part=formatUnicode(selected.value,{offset:byteOffset,limit:1024});add(detail,'h3',selected.label);add(detail,'pre',part.text);add(detail,'p','Code points '+(part.total?byteOffset+1:0)+'–'+Math.min(part.total,byteOffset+1024)+' of '+part.total+'. '+part.remaining+' remaining.');
        if(byteOffset>0)button(detail,'Previous text',()=>{byteOffset=Math.max(0,byteOffset-1024);draw('inspection');});
        if(part.remaining)button(detail,'Next text',()=>{byteOffset+=1024;draw('inspection');});
      }else if(typeof selected.value==='string'){
        byteDetails(ui,detail,selected.value,byteOffset,offset=>{byteOffset=offset;draw('inspection');});
      }else if(selected.value instanceof Map){for(const row of rawEntries(selected.value).slice(0,20))add(detail,'pre',pathText(row.path).slice(0,256)+' = '+valueText(row.value));add(detail,'p','Nested values remain in the raw decoded data pages.');}
      else add(detail,'pre',valueText(selected.value));
      button(detail,'Close inspection',()=>{selected=null;draw(mode==='raw'?'raw':'ordered');});
    }
    if(focusTarget)focusTarget.focus();
    if(ui.atLimit())add(root,'p','Rendering limit reached. Use raw data pages to inspect remaining content.');
  }
  draw();return ()=>{active=false;revision++;selected=null;root.replaceChildren();};
}

const segmentText=segments=>'$'+segments.map(s=>'['+s.kind+' '+pathText([s.key]).slice(1)+']').join('');
export function renderComparison(document,root,view){
  const instance=++nextRenderer;let active=true,revision=0,page=0,diagnosticPage=0,selected=null,leaf=null,entryPage=0,byteOffset=0;
  function draw(focus){
    if(!active)return;const ticket=++revision;root.replaceChildren();
    const ui=drawing(document,root,instance,ticket,()=>active&&ticket===revision),{add,button,describe}=ui;
    const section=add(root,'section','','comparison');const heading=add(section,'h2',view.status==='partial'?'Partial comparison':view.status==='complete'?'Structural comparison':'Comparison unavailable');heading.setAttribute('tabindex','-1');let focusTarget=focus==='changes'?heading:null;
    if(view.comparisonKind==='import-bundled'){
      add(section,'h3','First export versus Bundled rotation');const source=view.sourceContext?.bundled;
      if(source){if(typeof source.name==='string'){const part=formatUnicode(source.name,{limit:80});add(section,'p',part.text+(part.remaining?'…':''));}add(section,'p','Declared '+valueText(source.id,128)+'; revision '+valueText(source.revision,32)+'; source '+valueText(source.path,160)+'.');}
      add(section,'p','Read bundled rotation for full declared information.');
    }
    add(section,'p','Literal data only. Native readiness, compatibility and gameplay quality are not checked.');
    const diff=view.diff;
    if(view.status==='unavailable'){
      const side=view.side==='left'?'First export':view.side==='right'?(view.comparisonKind==='import-bundled'?'Bundled rotation':'Second export'):'';
      const messages={'decode-required':'Decode this export before comparing.','schema-unavailable':'Local structural analysis is unavailable. Raw data and original copy remain available.','invalid-structure':'Inspect and resolve structural diagnostics before comparing.','future-schema':'Unsupported envelope schema. Compare is unavailable; inspect raw data instead.','unrecognized-legacy':'Legacy comparison requires a recognized rotation or cooldown list.','comparison-failed':'The comparison could not be completed. Original exports remain available.'};
      add(section,'p',(side?side+': ':'')+(messages[view.reason]||'The strict structural comparison is unavailable. Inspect its diagnostics.'),'problem');
    }
    if(view.mixed)add(section,'p','Comparing an envelope with a legacy body. Envelope metadata is included; missing legacy metadata is not inferred.');
    add(section,'p','Different step IDs are not paired automatically. No clone lineage is inferred.');
    diagnosticList(ui,section,diff?.diagnostics||[],diagnosticPage,n=>{diagnosticPage=n;draw('changes');});
    const changes=diff?.valid?diff.changes:[];
    if(view.status==='complete'&&diff?.valid&&diff.complete&&changes.length===0)add(section,'p','No structural differences.');
    else if(diff?.valid)add(section,'p',(diff.complete?'Complete comparison. ':'Partial comparison; additional differences may be omitted. ')+changes.length+' returned changes; showing '+(changes.length?page*25+1:0)+'–'+Math.min(changes.length,(page+1)*25)+'.');
    for(let i=page*25;i<Math.min(changes.length,(page+1)*25);i++){
      const c=changes[i],row=add(section,'article','','step');if(!row)break;
      const title=add(row,'h3',(i+1)+'. '+c.kind),description=describe(title),text=segmentText(c.segments);add(row,'pre',text.length>256?text.slice(0,256)+'…':text);
      if(c.fromIndex!==undefined)add(row,'p','From priority '+c.fromIndex);if(c.toIndex!==undefined)add(row,'p','To priority '+c.toIndex);
      function inspect(label,value,target){selected={label,value,path:text,target};leaf=null;entryPage=0;byteOffset=0;draw('inspection');}
      const pathValue=new Map(c.segments.map((s,n)=>[n+1,new Map([['kind',s.kind],['key',s.key]])]));
      const pathButton=button(row,'Inspect path',()=>inspect('Typed path',pathValue,'path-'+i),description);if(focus==='path-'+i)focusTarget=pathButton;
      for(const side of ['before','after']){
        const label=side==='before'?'Before':'After';add(row,'p',label+': '+(Object.hasOwn(c,side)?valueText(c[side],32):'Not present'));
        if(Object.hasOwn(c,side)){const b=button(row,'Inspect '+side,()=>inspect(label+' value',c[side],side+'-'+i),description);if(focus===side+'-'+i)focusTarget=b;}
      }
    }
    if(page>0)button(section,'Previous changes',()=>{page--;selected=null;draw('changes');});
    if((page+1)*25<changes.length)button(section,'Next changes',()=>{page++;selected=null;draw('changes');});
    if(selected){
      const detail=add(root,'section','','inspection'),title=add(detail,'h2',selected.label);title?.setAttribute('tabindex','-1');if(focus==='inspection')focusTarget=title;
      add(detail,'pre',selected.path.length>4096?selected.path.slice(0,4096)+'…':selected.path);const value=leaf?leaf.value:selected.value;
      if(leaf)add(detail,'pre',pathText(leaf.path));
      if(typeof value==='string')byteDetails(ui,detail,value,byteOffset,offset=>{byteOffset=offset;draw('inspection');});
      else if(value instanceof Map){const rows=rawEntries(value);rawPage(ui,detail,rows,entryPage,row=>{leaf={path:[...(leaf?.path||[]),...row.path],value:row.value};entryPage=0;byteOffset=0;draw('inspection');},n=>{entryPage=n;draw('inspection');},'Value entries');}
      else add(detail,'pre',valueText(value));
      if(leaf)button(detail,'Back to value',()=>{leaf=null;entryPage=0;byteOffset=0;draw('inspection');});
      button(detail,'Close inspection',()=>{const target=selected.target;selected=null;leaf=null;draw(target);});
    }
    focusTarget?.focus();
  }
  draw();return ()=>{active=false;revision++;selected=null;leaf=null;root.replaceChildren();};
}
