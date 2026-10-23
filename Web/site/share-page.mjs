// Share page: decode the published export in the browser and show it with
// the same reader the standalone viewer uses. Nothing is executed.
import {decodeImport} from '../codec/import.mjs';
import {createSchemaAnalyzer} from '../viewer/model.mjs';
import {renderViewer} from '../viewer/render.mjs';
import {loadLocalCatalog} from '../viewer/app.mjs';
import {createShareLink} from '../viewer/share.mjs';
import {classifyExport} from './kinds.mjs';
import {renderKindSummary} from './kind-render.mjs';
import {api,copyText,errorMessage,el} from './client.mjs';

const article=document.querySelector('.share-view');
const field=document.getElementById('export-text');
const visual=document.getElementById('share-visual');

async function show(){
  const original=field.value;
  const decoded=decodeImport(original);
  if(!decoded.ok){visual.replaceChildren(el(document,'p','This export could not be decoded in your browser ('+decoded.reason+').','problem'));return;}
  const info=classifyExport(decoded.value);
  if(!info.ok){visual.replaceChildren(el(document,'p','Unrecognised export ('+info.reason+').','problem'));return;}
  const summary=el(document,'div','','kind-summary');
  visual.replaceChildren(summary);
  await renderKindSummary(document,summary,info,decoded.value);
  let analysis=null,structureMessage='Not a rotation: the rotation structure check does not apply. Raw decoded data follows.';
  if(info.kind==='rotation'){
    try{
      const catalog=await loadLocalCatalog();
      const analyze=createSchemaAnalyzer(catalog);
      analysis=analyze(decoded);
      structureMessage=analysis.recognized===false?'Unsupported envelope schema. Structure and references were not checked.':'Declarative structure only; whether each spell is available to your character is checked in game.';
    }catch{structureMessage='The structure checker could not be loaded; showing raw data.';}
  }
  const host=el(document,'div','','result');
  const wrap=el(document,'details','','viewer-embed');
  wrap.append(el(document,'summary',info.kind==='rotation'?'Structure check and raw decoded data (the export viewer)':'Raw decoded data'));
  wrap.append(host);visual.append(wrap);
  renderViewer(document,host,{decode:decoded,analysis,structureMessage});
  const link=createShareLink(original,location.origin+'/viewer');
  const open=document.getElementById('open-viewer');
  if(open){if(link.ok)open.setAttribute('href',link.url);else open.title='This export is too long for a viewer link; paste it into the viewer instead.';}
}
show().catch(()=>{visual.replaceChildren(el(document,'p','Could not display this export.','problem'));});

const status=document.getElementById('copy-status');
document.querySelector('[data-action="copy-export"]')?.addEventListener('click',async()=>{
  const copied=await copyText(field.value,field);
  status.textContent=copied?'Copied.':'Copy blocked by the browser; the text is selected, press Ctrl+C.';
});

const del=document.querySelector('[data-action="delete-share"]');
if(del){
  const deleteStatus=document.getElementById('delete-status');
  del.addEventListener('click',async()=>{
    if(!confirm('Delete this share for everyone? This cannot be undone.'))return;
    del.disabled=true;
    const result=await api('/api/shares/'+encodeURIComponent(article.dataset.shareId),{method:'DELETE'});
    if(result.status===204){location.assign('/shares');return;}
    deleteStatus.textContent=errorMessage(result.data);del.disabled=false;
  });
}

const report=document.getElementById('report-form');
if(report){
  const reportStatus=document.getElementById('report-status');
  report.addEventListener('submit',async event=>{
    event.preventDefault();
    const button=report.querySelector('button[type="submit"]');button.disabled=true;
    const result=await api('/api/shares/'+encodeURIComponent(article.dataset.shareId)+'/report',{method:'POST',body:{reason:report.elements.reason.value,details:report.elements.details.value}});
    if(result.ok){reportStatus.textContent=result.data?.alreadyReported?'You already reported this share. Thank you.':'Thank you. A moderator will look at it.';return;}
    reportStatus.textContent=errorMessage(result.data);button.disabled=false;
  });
}
