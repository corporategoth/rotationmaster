import {checkPortable} from '../codec/lua-data.mjs';
import {encodeExport} from '../codec/export.mjs';
import {validateBody,validateEnvelope,indexRotationSteps} from '../schema/rotation.mjs';
import {diffRotations} from '../schema/diff.mjs';

const keys=Map.prototype.keys,get=Map.prototype.get,set=Map.prototype.set,has=Map.prototype.has,remove=Map.prototype.delete;
// Call only after portable bounds checking. Keep every key/value literal and
// keep shared subgraphs within a snapshot, never across snapshot owners.
function copy(value){
  const root=new Map(),copies=new Map([[value,root]]),pending=[[value,root]];
  while(pending.length){const [input,output]=pending.pop();for(const key of keys.call(input)){
    let v=get.call(input,key);
    if(v instanceof Map){if(!copies.has(v)){copies.set(v,new Map());pending.push([v,copies.get(v)]);}v=copies.get(v);}
    set.call(output,key,v);
  }}return root;
}
const body=(root,kind)=>kind==='envelope'?get.call(root,'body'):root;
const field=(root,key)=>({present:has.call(root,key),value:get.call(root,key)});
const failure=reason=>({ok:false,reason});
const editableTypes=new Set(['spell','item','pet','any','none','assisted']);
const editable=row=>editableTypes.has(get.call(row.step,'type'));
function actionSummary(step){
  const action=field(step,'action');if(!(action.value instanceof Map))return action;
  if(get.call(step,'type')!=='item')return {present:true,table:true,entries:action.value.size};
  const values=[];for(const key of keys.call(action.value)){if(values.length===8)break;values.push(get.call(action.value,key));}
  return {present:true,values,remaining:action.value.size-values.length};
}
const summary=row=>({id:get.call(row.step,'id'),type:get.call(row.step,'type'),section:row.section,ordinal:row.ordinal,depth:row.depth,parentId:row.parentId,arm:row.arm,unreachable:row.unreachable,editable:editable(row),disabled:field(row.step,'disabled'),action:actionSummary(row.step),suppressAttack:field(row.step,'suppress_attack')});
const shallow=value=>{const out=new Map();for(const key of keys.call(value))set.call(out,key,get.call(value,key));return out;};
// Copy only the selected structural spine. Off-path aliases keep their original
// values, including aliases to a list, branch, arm, step, or envelope body.
function stepCopy(root,path){
  const out=shallow(root);let input=root,output=out;
  for(const key of path){input=get.call(input,key);const child=shallow(input);set.call(output,key,child);output=child;}
  return {root:out,step:output};
}
function reviewPath(root,row){
  let selected=root;const segments=[{kind:'field',key:'body'}];
  for(const key of row.path){selected=get.call(selected,key);segments.push(typeof key==='number'?{kind:'step',key:get.call(selected,'id')}:{kind:'field',key});}
  return [...segments,{kind:'field',key:'disabled'}];
}
const samePath=(a,b)=>a.length===b.length&&a.every((s,i)=>s.kind===b[i].kind&&s.key===b[i].key);

// A private draft belongs to one accepted First-import identity. Nothing returned
// exposes its Maps; closed commands target body scalars or one indexed step.
export function createDraftEditor({schemaText,readSource}={}){
  let active=true,epoch=0,record=null,reason=null;
  const read=token=>{let value;try{value=readSource?.();}catch{return null;}return active&&token===epoch?value:null;};
  const retire=()=>{if(record){record.current=false;record.review=null;record.output=null;}epoch++;};
  function sync(){
    if(!active||!record?.current)return false;
    const token=epoch,source=read(token);if(!active||token!==epoch)return false;
    if(source!==record.source){retire();return false;}return true;
  }
  const clearOutput=()=>{epoch++;record.review=null;record.output=null;reason=null;};
  function mutate(key,present,value){
    if(!sync())return false;clearOutput();
    // Isolate the selected body edge even if an opaque field aliases that table.
    if(record.kind==='envelope')set.call(record.draft,'body',copy(body(record.draft,record.kind)));
    const selected=body(record.draft,record.kind);if(present)set.call(selected,key,value);else remove.call(selected,key);return true;
  }
  const index=()=>record?indexRotationSteps(body(record.draft,record.kind)).index:null;
  return {
    start(){
      if(!active||record)return false;const token=++epoch;reason=null;
      const source=read(token),decoded=source?.decode;
      try{
        if(!decoded?.ok||!['legacy','envelope'].includes(decoded.kind)||typeof decoded.original!=='string')throw Error('decode-first');
        if(typeof schemaText!=='string')throw Error('schema-unavailable');
        const value=decoded.value,portable=checkPortable(value);if(!portable.ok||!(value instanceof Map))throw Error('invalid-data');
        const kind=decoded.kind,selected=body(value,kind);
        if(kind==='envelope'&&get.call(value,'schemaVersion')!==1)throw Error('unsupported-schema');
        const validation=kind==='envelope'?validateEnvelope(value,schemaText):validateBody(value,schemaText);
        if(!validation.valid)throw Error('invalid-structure');
        if(kind==='legacy'&&!(get.call(value,'rotation') instanceof Map)&&!(get.call(value,'cooldowns') instanceof Map))throw Error('invalid-structure');
        if(!indexRotationSteps(selected).ok)throw Error('strict-index-required');
        const baseline=copy(value),draft=copy(value);
        if(read(token)!==source||!active||token!==epoch)return false;
        record={source,kind,baseline,draft,current:true,review:null,output:null};return true;
      }catch(error){if(active&&token===epoch)reason=['decode-first','schema-unavailable','invalid-data','unsupported-schema','invalid-structure','strict-index-required'].includes(error.message)?error.message:'draft-unavailable';return false;}
    },
    sync,retire,
    invalidateReview(){if(sync())clearOutput();},
    setPriority(present,value){if(typeof present!=='boolean'||present&&!(typeof value==='number'&&Number.isInteger(value)&&value>=-100000&&value<=100000))return false;return mutate('priority',present,value);},
    setDisabled(state){if(!['absent','false','true'].includes(state))return false;return mutate('disabled',state!=='absent',state==='true');},
    step(id){if(typeof id!=='string')return null;const row=index()?.byId.get(id);return row?summary(row):null;},
    listSteps(page=0){
      const rows=index()?.rows??[],pages=Math.ceil(rows.length/50),selected=Number.isInteger(page)?Math.max(0,Math.min(page,Math.max(0,pages-1))):0;
      return {page:selected,total:rows.length,pages,rows:rows.slice(selected*50,selected*50+50).map(summary)};
    },
    setStepDisabled(id,state,stillCurrent){
      if(typeof id!=='string'||!['absent','false','true'].includes(state)||stillCurrent!==undefined&&typeof stillCurrent!=='function')return false;
      const row=index()?.byId.get(id);if(!row||!editable(row)||!sync())return false;
      // The mounted row can retire while the final source read runs. A narrow
      // render guard adds no target/path authority. Reentry cannot authorize
      // this old command against a replacement owner, even with the same ID.
      if(stillCurrent){const token=epoch,owner=record,source=record.source;let valid;try{valid=stillCurrent();}catch{return false;}if(!active||token!==epoch||record!==owner||record.source!==source||!record.current||valid!==true)return false;}
      const selected=stepCopy(record.draft,record.kind==='envelope'?['body',...row.path]:row.path);
      if(state==='absent')remove.call(selected.step,'disabled');else set.call(selected.step,'disabled',state==='true');
      if(!indexRotationSteps(body(selected.root,record.kind)).ok)return false;
      clearOutput();record.draft=selected.root;return true;
    },
    review(){
      if(!sync())return failure('source-retired');clearOutput();
      const wrap=root=>record.kind==='legacy'?new Map([['body',root]]):root;
      const diff=diffRotations(wrap(record.baseline),wrap(record.draft));
      const currentBody=body(record.draft,record.kind),baselineBody=body(record.baseline,record.kind),steps=index();
      const bodyChange=c=>c.segments.length===2&&c.segments.every(s=>s.kind==='field')&&c.segments[0].key==='body'&&['priority','disabled'].includes(c.segments[1].key);
      const selectedStep=c=>{const id=c.segments.at(-2)?.kind==='step'?c.segments.at(-2).key:null,row=steps.byId.get(id);return row&&editable(row)&&samePath(c.segments,reviewPath(currentBody,row))?row:null;};
      const allowed=diff.valid&&diff.complete&&diff.changes.every(c=>bodyChange(c)||selectedStep(c));
      if(!allowed){reason='review-unavailable';return failure(reason);}
      // The comparator intentionally ignores body.revision. Closed commands and
      // private snapshots preserve it; the diff alone is not a preservation proof.
      const baselineSteps=indexRotationSteps(baselineBody).index;
      const changes=diff.changes.map(c=>{
        if(bodyChange(c))return {field:c.segments[1].key,before:field(baselineBody,c.segments[1].key),after:field(currentBody,c.segments[1].key)};
        const row=selectedStep(c),id=get.call(row.step,'id');return {field:'disabled',stepId:id,section:row.section,ordinal:row.ordinal,parentId:row.parentId,arm:row.arm,before:field(baselineSteps.byId.get(id).step,'disabled'),after:field(row.step,'disabled')};
      });
      // Structural comparison equates signed zeros. The editable priority's
      // literal presence and number bits still need explicit user review.
      const before=field(body(record.baseline,record.kind),'priority'),after=field(body(record.draft,record.kind),'priority');
      if((before.present!==after.present||before.present&&!Object.is(before.value,after.value))&&!changes.some(c=>c.field==='priority'))changes.push({field:'priority',before,after});
      record.review={ok:true,changes};
      return {ok:true,changes:record.review.changes.map(c=>({...c,before:{...c.before},after:{...c.after}}))};
    },
    generate(){
      if(!sync())return failure('source-retired');record.output=null;
      if(!record.review)return failure('review-required');
      const encoded=encodeExport(record.draft);if(!encoded.ok){reason=encoded.reason;return encoded;}
      record.output=encoded.text;reason=null;return encoded;
    },
    view(){
      if(!record)return {state:'empty',revision:epoch,fields:null,review:null,output:null,reason};
      const selected=body(record.draft,record.kind);
      return {state:record.current?'current':'retired',revision:epoch,kind:record.kind,fields:{priority:field(selected,'priority'),disabled:field(selected,'disabled')},review:record.review?{ok:true,changes:record.review.changes.map(c=>({...c,before:{...c.before},after:{...c.after}}))}:null,output:record.output,reason};
    },
    discard(){if(!active)return;epoch++;record=null;reason=null;},
    dispose(){active=false;epoch++;record=null;reason=null;}
  };
}
