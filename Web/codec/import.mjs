import {decodeLegacyCompression} from './libcompress.mjs';
import {parseAce1} from './ace-serializer.mjs';
import {checkPortable,LIMITS} from './lua-data.mjs';
const failure=reason=>({ok:false,reason});
const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function base64(text){
  if(!text.length||text.length%4||/[^A-Za-z0-9+/=]/.test(text))return failure('invalid-base64');
  const length=text.length/4*3-(text.endsWith('==')?2:text.endsWith('=')?1:0);
  // Validation precedes size refusal, matching the native codec's pipeline.
  for(let i=0;i<text.length;i+=4){
    const a=alphabet.indexOf(text[i]),b=alphabet.indexOf(text[i+1]),c=alphabet.indexOf(text[i+2]),d=alphabet.indexOf(text[i+3]);
    const padC=text[i+2]==='=',padD=text[i+3]==='=';
    if(a<0||b<0||padC&&!padD||(padC||padD)&&i!==text.length-4||padC&&b%16||padD&&!padC&&c%4)return failure('invalid-base64-padding');
    if(c<0&&!padC||d<0&&!padD)return failure('invalid-base64-padding');
  }
  if(length>LIMITS.compressed)return failure('compressed-size-limit');
  const result=new Uint8Array(length);let at=0;
  for(let i=0;i<text.length;i+=4){
    const code=alphabet.indexOf(text[i])*262144+alphabet.indexOf(text[i+1])*4096+
      Math.max(0,alphabet.indexOf(text[i+2]))*64+Math.max(0,alphabet.indexOf(text[i+3]));
    result[at++]=Math.floor(code/65536);if(at<length)result[at++]=Math.floor(code/256)%256;if(at<length)result[at++]=code%256;
  }
  return {ok:true,bytes:result};
}
export function decodeImport(text){
  if(typeof text!=='string')return failure('expected-import-string');
  if(text.length>LIMITS.input)return failure('import-size-limit');
  // Count UTF-8 without allocating a second unbounded input buffer.
  let size=0;
  for(let i=0;i<text.length;i++){
    const code=text.charCodeAt(i);
    if(code<128)size++;else if(code<2048)size+=2;
    else if(code>=0xd800&&code<=0xdbff&&text.charCodeAt(i+1)>=0xdc00&&text.charCodeAt(i+1)<=0xdfff){size+=4;i++;}
    else size+=3;
    if(size>LIMITS.input)return failure('import-size-limit');
  }
  let payload=text.replace(/[ \t\r\n]/g,'');
  const prefix=payload.match(/^RM\d+:/)?.[0]??null;
  if(prefix&&prefix!=='RM1:')return failure('unsupported-transport-version');
  if(prefix)payload=payload.slice(prefix.length);
  const compressed=base64(payload);if(!compressed.ok)return compressed;
  const raw=decodeLegacyCompression(compressed.bytes);if(!raw.ok)return raw;
  const parsed=parseAce1(raw.bytes);if(!parsed.ok)return parsed;
  const portable=checkPortable(parsed.value);if(!portable.ok)return failure(portable.reason);
  const envelope=parsed.value.get('format')==='RotationMaster';
  if(prefix&&!envelope)return failure('envelope-marker-mismatch');
  return {ok:true,value:parsed.value,kind:envelope?'envelope':'legacy',original:text,transportVersion:prefix?1:null};
}
