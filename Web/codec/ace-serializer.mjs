// Bounded iterative data parser for observed AceSerializer rev1 wire semantics.
import {bytesToString,LIMITS} from './lua-data.mjs';
const failure=reason=>({ok:false,reason});
function hexadecimal(text){
  let sign=1;if(text[0]==='-'||text[0]==='+'){if(text[0]==='-')sign=-1;text=text.slice(1);}
  const [digits,powerText]=text.slice(2).toLowerCase().split('p');
  const parts=digits.split('.'),all=(parts.join('').replace(/^0+/,''));if(!all)return sign*0;
  const power=(powerText===undefined?0:Number(powerText))-4*(parts[1]?.length??0);
  const bitLength=(all.length-1)*4+Math.floor(Math.log2(parseInt(all[0],16)))+1;
  const high=power+bitLength-1;
  if(high>1023)return sign*Infinity;if(high<-1075)return sign*0;
  const integer=BigInt('0x'+all),shift=Math.max(0,bitLength-53,-1074-power);
  let rounded=integer>>BigInt(shift);
  if(shift>0){const remainder=integer-(rounded<<BigInt(shift)),half=1n<<BigInt(shift-1);
    if(remainder>half||(remainder===half&&(rounded&1n)))rounded++;}
  return sign*Number(rounded)*2**(power+shift);
}
function number(text,legacyInfinity=false){
  if(/^[+-]?(?:nan|inf(?:inity)?)$/i.test(text))return /nan/i.test(text)?NaN:(text[0]==='-'?-Infinity:Infinity);
  if(legacyInfinity&&(text==='1.#INF'||text==='-1.#INF'))return text[0]==='-'?-Infinity:Infinity;
  if(/^[+-]?0x(?:[0-9a-f]+(?:\.[0-9a-f]*)?|\.[0-9a-f]+)(?:p[+-]?\d+)?$/i.test(text))return hexadecimal(text);
  if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(text))return undefined;
  return Number(text);
}
function unescape(text){
  let out='';
  for(let i=0;i<text.length;i++){
    const c=text.charCodeAt(i);
    if(c!==126||i===text.length-1){out+=text[i];continue;}
    const next=text.charCodeAt(++i);let value;
    if(next<122)value=next-64;else value=({122:30,123:127,124:126,125:94})[next];
    if(value===undefined||value<0)throw new Error('deserialize-error');out+=String.fromCharCode(value);
  }
  return out;
}
export function parseAce1(input){
  if(!(input instanceof Uint8Array))return failure('invalid-serializer-data');
  if(input.length>LIMITS.serialized)return failure('serialized-size-limit');
  const clean=bytesToString(input).replace(/[\x00-\x20\x7f]/g,'');
  if(!clean.startsWith('^1'))return failure('unsupported-serializer');
  const tokens=[];let position=0,depth=0,root=false,closed=false,terminated=false;
  while(position<clean.length){
    const begin=clean.indexOf('^',position);if(begin<0||begin+1>=clean.length)break;
    const next=clean.indexOf('^',begin+2),control=clean.slice(begin,begin+2),text=clean.slice(begin+2,next<0?clean.length:next);
    position=next<0?clean.length:next;tokens.push({control,text});
    if(tokens.length>LIMITS.tokens)return failure('serializer-token-limit');
    if(tokens.length===1){if(control!=='^1')return failure('unsupported-serializer');}
    else if(terminated)return failure('serializer-trailing-data');
    else if(!root){if(control!=='^T')return failure('expected-root-table');root=true;depth=1;}
    else if(closed){if(control!=='^^')return failure('serializer-multiple-values');terminated=true;}
    else if(control==='^T'){if(++depth>LIMITS.tableDepth)return failure('serializer-depth-limit');}
    else if(control==='^t'){if(--depth===0)closed=true;}
    else if(control==='^^')return failure('serializer-unclosed-table');
    else if(!['^S','^N','^F','^f','^B','^b','^Z'].includes(control))return failure('invalid-serializer-token');
  }
  if(!terminated)return failure('serializer-missing-terminator');
  const stack=[];let result;
  const attach=value=>{
    if(!stack.length){result=value;return;}
    const frame=stack[stack.length-1];
    if(value===null||typeof value==='number'&&Number.isNaN(value)&&frame.wantsKey)throw new Error('deserialize-error');
    if(frame.wantsKey){frame.key=value;frame.wantsKey=false;}
    else{frame.value.set(frame.key,value);frame.wantsKey=true;}
  };
  try{
    for(let i=1;i<tokens.length-1;i++){
      const {control,text}=tokens[i];
      if(control==='^T'){
        const value=new Map();attach(value);stack.push({value,wantsKey:true});
      }else if(control==='^t'){
        if(!stack.length||!stack.pop().wantsKey)throw new Error('deserialize-error');
      }else{
        let value;
        if(control==='^S')value=unescape(text);
        else if(control==='^N')value=number(text,true);
        else if(control==='^F'){
          const exponent=tokens[++i];if(exponent?.control!=='^f')throw new Error('deserialize-error');
          const m=number(text),e=number(exponent.text);
          if(m===undefined||e===undefined)throw new Error('deserialize-error');value=m*2**e;
        }else if(control==='^B')value=true;
        else if(control==='^b')value=false;
        else if(control==='^Z')value=null;
        else throw new Error('deserialize-error');
        if(value===undefined)throw new Error('deserialize-error');attach(value);
      }
    }
    if(stack.length||!(result instanceof Map))return failure('deserialize-error');
    return {ok:true,value:result};
  }catch(error){if(error.message==='deserialize-error')return failure('deserialize-error');throw error;}
}
