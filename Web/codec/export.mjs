import {checkPortable,LIMITS} from './lua-data.mjs';

// Original bounded writer for the existing Ace1/Store wire contract. This is
// data transport only: no schema repair, source execution or original rewrite.
const mapKeys=Map.prototype.keys,mapGet=Map.prototype.get;
const numberText=Number.prototype.toString,charCode=String.prototype.charCodeAt;
const apply=Reflect.apply,alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const failure=reason=>({ok:false,reason});
const order=(a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1;
function serialize(root,output){
  let bytes=0,tokens=0,reason=null;
  const byte=value=>{if(++bytes>LIMITS.serialized){reason='serialized-size-limit';return false;}if(output)output[bytes]=value;return true;};
  const text=value=>{for(let i=0;i<value.length;i++)if(!byte(apply(charCode,value,[i])))return false;return true;};
  const token=kind=>{if(++tokens>LIMITS.tokens){reason='serializer-token-limit';return false;}return byte(94)&&byte(kind);};
  if(!token(49))return failure(reason);
  const stack=[{value:root,depth:1}];
  while(stack.length){
    const task=stack.pop();
    if(task.close){if(!token(116))return failure(reason);continue;}
    const value=task.value,type=typeof value;
    if(value===null)return failure('non-roundtrippable-nil');
    if(type==='string'){
      if(!token(83))return failure(reason);
      for(let i=0;i<value.length;i++){
        const code=apply(charCode,value,[i]);let escape;
        if(code<=32)escape=code===30?122:code+64;
        else if(code===94)escape=125;else if(code===126)escape=124;else if(code===127)escape=123;
        if(escape!==undefined){if(!byte(126)||!byte(escape))return failure(reason);}
        else if(!byte(code))return failure(reason);
      }
    }else if(type==='number'){
      const spelling=value===0&&1/value===-Infinity?'-0':apply(numberText,value,[]);
      if(!token(78)||!text(spelling))return failure(reason);
    }else if(type==='boolean'){
      if(!token(value?66:98))return failure(reason);
    }else{
      if(task.depth>LIMITS.tableDepth)return failure('serializer-depth-limit');
      if(!token(84))return failure(reason);
      const keys=[...apply(mapKeys,value,[])].sort(order);stack.push({close:true});
      for(let i=keys.length-1;i>=0;i--){const key=keys[i];stack.push({value:apply(mapGet,value,[key]),depth:task.depth+1},{value:key,depth:task.depth+1});}
    }
  }
  if(!token(94))return failure(reason);return {ok:true,bytes};
}
function base64(bytes){
  const parts=[];let part='';
  for(let i=0;i<bytes.length;i+=3){
    const a=bytes[i],b=bytes[i+1],c=bytes[i+2];
    part+=alphabet[a>>>2]+alphabet[((a&3)<<4)|((b??0)>>>4)]+(b===undefined?'=':alphabet[((b&15)<<2)|((c??0)>>>6)])+(c===undefined?'=':alphabet[c&63]);
    if(part.length>=8192){parts.push(part);part='';}
  }
  parts.push(part);return parts.join('');
}
export function encodeExport(value){
  const portable=checkPortable(value);if(!portable.ok)return failure(portable.reason);
  if(!(value instanceof Map))return failure('expected-root-table');
  // Count first. Traversal uses owned native primitives and has no callback or
  // asynchronous handoff where the input can change between these two passes.
  const measured=serialize(value);if(!measured.ok)return measured;
  const stored=new Uint8Array(measured.bytes+1);stored[0]=1;
  const written=serialize(value,stored);if(!written.ok)return written;
  const prefix=apply(mapGet,value,['format'])==='RotationMaster'?'RM1:':'';
  return {ok:true,text:prefix+base64(stored)};
}
