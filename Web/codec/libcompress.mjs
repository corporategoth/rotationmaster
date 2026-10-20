// Independently written reader for the observed legacy wire formats, not a library port.
import {LIMITS} from './lua-data.mjs';
const failure=reason=>({ok:false,reason});
function* lzwCodes(input){
  for(let p=1;p<input.length;){
    const marker=input[p++];if(marker<250){yield marker;continue;}
    const digits=256-marker;if(p+digits>input.length)throw new Error('invalid-lzw-code');
    let code=0,factor=1;
    for(let n=0;n<digits;n++){
      const digit=input[p++];if(digit===0)throw new Error('invalid-lzw-code');
      code+=(digit-1)*factor;factor*=255;
    }
    yield code;
  }
}
function lzw(input){
  // The first pass counts output and phrases without allocating their strings.
  const lengths=new Uint32Array(input.length+256);lengths.fill(1,0,256);
  let next=256,previous=-1,total=0;
  for(const code of lzwCodes(input)){
    let length;
    if(previous<0){if(code>255)throw new Error('invalid-lzw-code');length=1;}
    else if(code===next)length=lengths[previous]+1;
    else {if(code>=next)throw new Error('invalid-lzw-code');length=lengths[code];}
    total+=length;if(total>LIMITS.serialized)return failure('decompressed-size-limit');
    if(previous>=0)lengths[next++]=lengths[previous]+1;
    previous=code;
  }
  if(previous<0)return failure('empty-lzw-stream');
  const output=new Uint8Array(total),prefix=new Int32Array(next),suffix=new Uint8Array(next);
  for(let i=0;i<256;i++){prefix[i]=-1;suffix[i]=i;}
  let position=0;next=256;previous=-1;
  const emit=code=>{
    const end=position+lengths[code];let cursor=end,walk=code;
    while(walk>=256){output[--cursor]=suffix[walk];walk=prefix[walk];}
    output[--cursor]=walk;position=end;return output[cursor];
  };
  for(const code of lzwCodes(input)){
    let first;
    if(code===next){first=emit(previous);output[position++]=first;}
    else first=emit(code);
    if(previous>=0){prefix[next]=previous;suffix[next]=first;next++;}
    previous=code;
  }
  return {ok:true,bytes:output};
}
function huffman(input){
  if(input.length<5)return failure('invalid-huffman-header');
  const size=input[2]+input[3]*256+input[4]*65536;
  if(size>LIMITS.serialized)return failure('decompressed-size-limit');
  if(size===0)return {ok:true,bytes:new Uint8Array()};
  let offset=40;
  const bit=()=>{
    if(offset>=input.length*8)return null;
    return Math.floor(input[Math.floor(offset/8)]/2**(offset++%8))%2;
  };
  const byLength=Array.from({length:33},()=>new Map());let maximum=0,minimum=33;
  for(let entry=0;entry<input[1]+1;entry++){
    let symbol=0;
    for(let j=0;j<8;j++){const b=bit();if(b===null)return failure('invalid-huffman-codebook');symbol+=b*2**j;}
    let escaped=0,code=0,length=0;
    while(true){
      const first=bit();if(first===null)return failure('invalid-huffman-codebook');
      if(first===1){
        const second=bit();if(second===null)return failure('invalid-huffman-codebook');
        if(second===1){if(escaped===0)return failure('invalid-huffman-codebook');break;}
        escaped+=2;code+=2**length;
      }else escaped++;
      if(escaped>32)return failure('invalid-huffman-codebook');length++;
    }
    byLength[length].set(code,symbol);minimum=Math.min(minimum,length);maximum=Math.max(maximum,length);
  }
  const output=new Uint8Array(size);
  // The deployed reader can consume one zero-padding byte after the wire EOF.
  // This finite allowance preserves that behavior without an unbounded bit source.
  const end=input.length*8+8;
  for(let p=0;p<size;p++){
    let code=0,found=false;
    for(let length=1;length<=maximum;length++){
      if(offset>=end)return failure('decompression-size-mismatch');
      const b=offset<input.length*8?Math.floor(input[Math.floor(offset/8)]/2**(offset%8))%2:0;
      offset++;code+=b*2**(length-1);
      if(length>=minimum&&byLength[length].has(code)){output[p]=byLength[length].get(code);found=true;break;}
    }
    if(!found)return failure('decompress-error');
  }
  return {ok:true,bytes:output};
}
export function decodeLegacyCompression(input){
  if(!(input instanceof Uint8Array))return failure('invalid-compressed-data');
  if(input.length>LIMITS.compressed)return failure('compressed-size-limit');
  try{
    if(input[0]===1){if(input.length-1>LIMITS.serialized)return failure('decompressed-size-limit');return {ok:true,bytes:input.slice(1)};}
    if(input[0]===2)return lzw(input);
    if(input[0]===3)return huffman(input);
    return failure('unsupported-compression');
  }catch(error){if(error.message==='invalid-lzw-code')return failure('invalid-lzw-code');throw error;}
}
