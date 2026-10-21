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

// A private draft belongs to one accepted First-import identity. Nothing returned
// exposes its Maps; the only write commands target two literal body fields.
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
    review(){
      if(!sync())return failure('source-retired');clearOutput();
      const wrap=root=>record.kind==='legacy'?new Map([['body',root]]):root;
      const diff=diffRotations(wrap(record.baseline),wrap(record.draft));
      const allowed=diff.valid&&diff.complete&&diff.changes.every(c=>c.segments.length===2&&c.segments.every(s=>s.kind==='field')&&c.segments[0].key==='body'&&['priority','disabled'].includes(c.segments[1].key));
      if(!allowed){reason='review-unavailable';return failure(reason);}
      // The comparator intentionally ignores body.revision. Closed commands and
      // private snapshots preserve it; the diff alone is not a preservation proof.
      const changes=diff.changes.map(c=>({field:c.segments[1].key,before:field(body(record.baseline,record.kind),c.segments[1].key),after:field(body(record.draft,record.kind),c.segments[1].key)}));
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
