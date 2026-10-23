// Upload form: decode and classify the export locally (same modules the server
// uses), prefill title and tags, preview the description, then publish.
import {decodeImport} from '../codec/import.mjs';
import {classifyExport,KINDS} from './kinds.mjs';
import {renderMarkdownDOM} from './markdown.mjs';
import {renderKindSummary,renderRisks,scanWithNames} from './kind-render.mjs';
import {api,errorMessage,el} from './client.mjs';

const form=document.getElementById('share-form');
const exportField=document.getElementById('share-export');
const detected=document.getElementById('share-detected');
const details=document.getElementById('share-details');
const title=document.getElementById('share-title');
const description=document.getElementById('share-description');
const preview=document.getElementById('share-preview');
const classSelect=document.getElementById('share-class');
const editionBoxes=[...form.querySelectorAll('input[name="editions"]')];
const result=document.getElementById('share-result');
const signedIn=form.dataset.signedIn==='yes';
const exportLimit=Number(form.dataset.exportLimit)||262144;
let current=null;

function lockTags(info){
  const declaredClass=info.declared.class,declaredEditions=info.declared.editions;
  classSelect.disabled=!!declaredClass;
  classSelect.value=declaredClass||'';
  for(const box of editionBoxes){box.disabled=declaredEditions.length>0;box.checked=declaredEditions.includes(box.value);}
}
let checkSerial=0;
async function check(){
  const serial=++checkSerial;
  localCheck();
  if(!current)return;
  // Ask the server for its verdict too (it runs the same modules), so problems
  // such as an invalid rotation structure show up before you write a description.
  const pending=current;
  const verdict=await api('/api/check',{method:'POST',body:{export:pending.text}});
  if(serial!==checkSerial||current!==pending)return;
  if(!verdict.ok){current=null;details.disabled=true;detected.prepend(el(document,'p',errorMessage(verdict.data),'problem'));return;}
  if(!title.value.trim()&&verdict.data?.name)title.value=verdict.data.name.slice(0,120);
}
function localCheck(){
  current=null;result.textContent='';
  const text=exportField.value.trim();
  if(!text){detected.replaceChildren(el(document,'p','Paste an export string first.','problem'));details.disabled=true;return;}
  if(new TextEncoder().encode(text).byteLength>exportLimit){detected.replaceChildren(el(document,'p',errorMessage({error:'export-too-large'}),'problem'));details.disabled=true;return;}
  const decoded=decodeImport(text);
  if(!decoded.ok){detected.replaceChildren(el(document,'p',errorMessage({error:'export-undecodable',reason:decoded.reason}),'problem'));details.disabled=true;return;}
  const info=classifyExport(decoded.value);
  if(!info.ok){detected.replaceChildren(el(document,'p',errorMessage({error:'export-unrecognized',reason:info.reason}),'problem'));details.disabled=true;return;}
  current={text,info};
  const box=el(document,'div','','kind-summary'),risks=el(document,'div','','risk-host');
  detected.replaceChildren(el(document,'p','Recognised: '+(KINDS[info.kind]?.label||info.kind)+(info.name?' “'+info.name+'”':'')+'.','ok'),
    el(document,'p','Viewers of your share will see these warnings at the top of its page:','hint'),risks,box);
  scanWithNames(decoded.value,info).then(found=>renderRisks(document,risks,found)).catch(()=>{});
  renderKindSummary(document,box,info,decoded.value).catch(()=>{});
  if(!title.value.trim()&&info.name)title.value=info.name.slice(0,120);
  lockTags(info);
  details.disabled=!signedIn;
  if(!signedIn)detected.append(el(document,'p','Sign in to publish it.','hint'));
}
document.getElementById('share-check').addEventListener('click',check);
exportField.addEventListener('input',()=>{if(current){current=null;details.disabled=true;detected.replaceChildren(el(document,'p','Export changed. Check it again.','hint'));}});

function renderPreview(){preview.replaceChildren();renderMarkdownDOM(document,preview,description.value,{headingOffset:2});if(!description.value.trim())preview.append(el(document,'p','Nothing to preview yet.','empty'));}
description.addEventListener('input',renderPreview);
renderPreview();

form.addEventListener('submit',async event=>{
  event.preventDefault();
  if(!current){await check();if(!current)return;}
  const submit=document.getElementById('share-submit');submit.disabled=true;result.textContent='Publishing…';
  const body={title:title.value,description:description.value,export:current.text,kind:current.info.kind};
  if(!classSelect.disabled&&classSelect.value)body.class=classSelect.value;
  if(!editionBoxes.some(b=>b.disabled)){const chosen=editionBoxes.filter(b=>b.checked).map(b=>b.value);if(chosen.length)body.editions=chosen;}
  const response=await api('/api/shares',{method:'POST',body});
  if(response.ok&&response.data?.url){location.assign(response.data.url);return;}
  if(response.status===409&&response.data?.url){
    result.replaceChildren(document.createTextNode(errorMessage(response.data)+' '));
    const a=el(document,'a','Open it');a.setAttribute('href',response.data.url);result.append(a);
  }else result.textContent=errorMessage(response.data);
  submit.disabled=false;
});
