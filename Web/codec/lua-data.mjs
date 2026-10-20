// Lua tables are Maps; strings contain bytes (one code unit per byte), not UTF-16 text.
export const LIMITS=Object.freeze({input:2097152,compressed:1048577,serialized:1048576,
  tokens:20000,tableDepth:64,depth:64,nodes:20000,string:262144,bytes:1048576});
const mapKeys=Map.prototype.keys,mapGet=Map.prototype.get;
const isByteString=s=>{for(let i=0;i<s.length;i++)if(s.charCodeAt(i)>255)return false;return true;};
export function bytesToString(bytes){
  const chunks=[];
  for(let i=0;i<bytes.length;i+=8192)chunks.push(String.fromCharCode(...bytes.subarray(i,i+8192)));
  return chunks.join('');
}
const keyOrder=(a,b)=>typeof a===typeof b?(a<b?-1:a>b?1:0):typeof a==='number'?-1:1;
export function checkPortable(value){
  const active=new Set(),path=[],tasks=[{value,depth:0}];let nodes=0,bytes=0;
  const fail=reason=>({ok:false,reason,path:'$'+path.map(k=>typeof k==='number'?`[${k}]`:'.'+k.slice(0,80)).join('')});
  const text=s=>{if(s.length>LIMITS.string)return 'data-string-limit';
    if(!isByteString(s))return 'non-portable-type';bytes+=s.length;
    if(bytes>LIMITS.bytes)return 'data-byte-limit';};
  while(tasks.length){
    const task=tasks.pop();
    if(task.exit){active.delete(task.exit);continue;}
    if(task.pop){path.pop();continue;}
    if('key'in task){
      if(typeof task.key==='string'){const why=text(task.key);if(why)return fail(why);}
      path.push(task.key);tasks.push({pop:true},{value:mapGet.call(task.parent,task.key),depth:task.depth});continue;
    }
    if(++nodes>LIMITS.nodes)return fail('data-node-limit');
    if(task.depth>LIMITS.depth)return fail('data-depth-limit');
    const v=task.value,t=typeof v;
    if(v===null||t==='boolean')continue;
    if(t==='string'){const why=text(v);if(why)return fail(why);continue;}
    if(t==='number'){if(!Number.isFinite(v))return fail('non-finite-number');continue;}
    let iterator;
    // Native Map brand checking rejects proxies/forgeries before prototype traps.
    try{iterator=mapKeys.call(v);}catch{return fail('non-portable-type');}
    if(Object.getPrototypeOf(v)!==Map.prototype)return fail('non-portable-type');
    if(active.has(v))return fail('data-cycle');active.add(v);
    const keys=[];
    for(const k of iterator){
      if(++nodes>LIMITS.nodes)return fail('data-node-limit');
      if(typeof k!=='string'&&!(typeof k==='number'&&Number.isFinite(k)&&k>=1&&Number.isInteger(k)))return fail('non-portable-key');
      keys.push(k);
    }
    keys.sort(keyOrder);tasks.push({exit:v});
    for(let i=keys.length-1;i>=0;i--)tasks.push({key:keys[i],parent:v,depth:task.depth+1});
  }
  return {ok:true};
}
function numberBits(value){
  const bytes=new DataView(new ArrayBuffer(8));bytes.setFloat64(0,value);
  return bytes.getUint32(0).toString(16).padStart(8,'0')+bytes.getUint32(4).toString(16).padStart(8,'0');
}
// Typed, deterministic data for the Lua oracle, not a JSON conversion of Lua table keys.
export function toTypedTree(value){
  const portable=checkPortable(value);if(!portable.ok)throw new TypeError(portable.reason);
  const convert=v=>{
    if(v instanceof Map)return {type:'table',entries:[...mapKeys.call(v)].sort(keyOrder).map(k=>[convert(k),convert(mapGet.call(v,k))])};
    if(typeof v==='string')return {type:'bytes',hex:Array.from(v,c=>c.charCodeAt(0).toString(16).padStart(2,'0')).join('')};
    if(typeof v==='number')return {type:'number',bits:numberBits(v)};
    if(typeof v==='boolean')return {type:'boolean',value:v};return {type:'nil'};
  };
  return convert(value);
}
