import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const fixtures=JSON.parse(readFileSync(new URL('./fixtures/web_codec.json',import.meta.url)));
const module=await import('../Web/codec/import.mjs').catch(e=>{if(e.code==='ERR_MODULE_NOT_FOUND')return null;throw e;});
const data=await import('../Web/codec/lua-data.mjs').catch(e=>{if(e.code==='ERR_MODULE_NOT_FOUND')return null;throw e;});
function decode(text){assert.ok(module,'bounded browser codec is not implemented');return module.decodeImport(text);}
function typed(v){assert.ok(data,'Lua data model is not implemented');return data.toTypedTree(v);}
const bytes=s=>Uint8Array.from(s,c=>c.charCodeAt(0));
const b64=b=>Buffer.from(b).toString('base64');
const stored=raw=>b64(Uint8Array.from([1,...bytes(raw)]));
const valueRaw=(token)=>'^1^T^Sk'+token+'^t^^';
const expectReason=(text,reason)=>assert.deepEqual(decode(text),{ok:false,reason});
for(const v of fixtures.goldens)test('actual Lua golden '+v.id,()=>{
 const result=decode(v.text);assert.equal(result.ok,true,result.reason);assert.equal(result.original,v.text);
 assert.equal(result.kind,v.kind);assert.deepEqual(typed(result.value),v.expected);
});
test('actual Lua protocol edge cases retain values or fixed refusal',()=>{
 for(const v of fixtures.probes){const r=decode(v.text??stored(Buffer.from(v.rawHex,'hex').toString('latin1')));
  assert.equal(r.ok,v.accepted,v.id+':'+r.reason);if(r.ok)assert.deepEqual(typed(r.value),v.expected,v.id);else assert.equal(r.reason,v.reason,v.id);}
});
test('actual truncated Huffman oracle results',()=>{
 for(const v of fixtures.huffmanTruncations){const r=decode(v.text);assert.equal(r.ok,v.accepted,JSON.stringify(v));if(r.ok)assert.deepEqual(typed(r.value),v.expected);else assert.equal(r.reason,v.reason);}
});
test('Base64 wrapping preserves original and canonical padding rejects junk',()=>{
 const s=stored('^1^T^t^^');const wrapped=' \t\r\n'+s.slice(0,8)+'\n'+s.slice(8)+'\r';
 assert.equal(decode(wrapped).original,wrapped);
 for(const s of ['!','A===','AAAA=','AA=A','AB==','AAB=','_A==','-A==','AA==!'])assert.equal(decode(s).ok,false,s);
 expectReason('RM9:'+s,'unsupported-transport-version');expectReason('RM1:'+s,'envelope-marker-mismatch');
 assert.equal(decode('RM1:'+stored('^1^T^Sformat^SRotationMaster^t^^')).transportVersion,1);
});
test('Lua tables retain byte strings, numeric/string keys and prototype names',()=>{
 const result=decode(fixtures.goldens.find(v=>v.id==='Store-bytes-map').text);assert.ok(result.ok);
 assert.ok(result.value instanceof Map);assert.equal(result.value.get(1),'numeric');assert.equal(result.value.get('1'),'string');
 assert.equal(result.value.get('__proto__'),'inert');assert.equal(result.value.get('constructor'),'inert');
 assert.equal(result.value.get('bytes'),'\0\x1e\x1f ^~\x7f\x80\xff');assert.equal({}.inert,undefined);
 assert.equal(result.value.get('source'),'error("MUST NEVER EXECUTE")');
});
test('encoded bound is checked before normalization, with UTF-8 byte accounting',()=>{
 expectReason(' '.repeat(2097153),'import-size-limit');expectReason('é'.repeat(1048577),'import-size-limit');
 expectReason(' '.repeat(2097152),'invalid-base64');expectReason(null,'expected-import-string');
 expectReason('AA==\v','invalid-base64');
});
test('compressed, store and Huffman declared bounds refuse before expansion',()=>{
 expectReason(b64(new Uint8Array(1048578).fill(1)),'compressed-size-limit');
 expectReason(b64(Uint8Array.from([3,0,1,0,16])),'decompressed-size-limit');
 for(const tag of [0,4,5,6,65,130,255])expectReason(b64(Uint8Array.of(tag)),'unsupported-compression');
 expectReason(b64(Uint8Array.of(3)),'invalid-huffman-header');
 expectReason(b64(Uint8Array.of(3,0,1,0,0,0)),'invalid-huffman-codebook');
 expectReason(b64(Uint8Array.from([3,0,1,0,0,0,...new Uint8Array(2048)])),'invalid-huffman-codebook');
});
test('LZW literals, KwKwK, dictionary and malformed marker safety',()=>{
 expectReason(b64(Uint8Array.of(2)),'empty-lzw-stream');
 for(const a of [[2,255],[2,255,0],[2,254,2,2],[2,65,254,4,4]])expectReason(b64(Uint8Array.from(a)),'invalid-lzw-code');
 // Raw Store and all-literal LZW must agree without relying on an encoder.
 const raw='^1^T^Sk^Saaaaaaaaaaaa^t^^';assert.deepEqual(typed(decode(b64(Uint8Array.from([2,...bytes(raw)]))).value),typed(decode(stored(raw)).value));
});
test('serializer structural bounds precede constructing Lua tables',()=>{
 expectReason(stored('^2^T^t^^'),'unsupported-serializer');
 expectReason(stored('^1^N1^^'),'expected-root-table');
 expectReason(stored('^1^T^t^N2^^'),'serializer-multiple-values');
 expectReason(stored('^1^T^t^^^Smore'),'serializer-trailing-data');
 expectReason(stored('^1^T^t'),'serializer-missing-terminator');
 expectReason(stored('^1^T^Sk^Qbad^t^^'),'invalid-serializer-token');
 expectReason(stored('^1'+ '^T^Sk'.repeat(65)+'^N1'+'^t'.repeat(65)+'^^'),'serializer-depth-limit');
 expectReason(stored('^1^T'+'^Sk^N1'.repeat(10000)+'^t^^'),'serializer-token-limit');
 assert.equal(decode(stored('^1'+ '^T^Sk'.repeat(64)+'^N1'+'^t'.repeat(64)+'^^')).ok,true);
});
test('portable byte, node, type, key and cycle bounds use detached data',()=>{
 assert.ok(data);const check=data.checkPortable;
 assert.equal(check(new Map([['k','a'.repeat(262144)]])).ok,true);
 assert.equal(check(new Map([['k','a'.repeat(262145)]])).reason,'data-string-limit');
 const exact=new Map(Array.from({length:4},(_,i)=>[i+1,'a'.repeat(262144)]));assert.equal(check(exact).ok,true);
 exact.set(5,'a');assert.equal(check(exact).reason,'data-byte-limit');
 const nodes=new Map(Array.from({length:9999},(_,i)=>[i+1,false]));assert.equal(check(nodes).ok,true);nodes.set(10000,false);assert.equal(check(nodes).reason,'data-node-limit');
 for(const key of [0,-1,1.5,Infinity,NaN,true,new Map()])assert.equal(check(new Map([[key,'v']])).reason,'non-portable-key');
 for(const v of [NaN,Infinity,-Infinity])assert.equal(check(new Map([['k',v]])).reason,'non-finite-number');
 assert.equal(check({}).reason,'non-portable-type');assert.equal(check(new Map([['k',()=>{}]])).reason,'non-portable-type');
 const cycle=new Map();cycle.set('self',cycle);assert.equal(check(cycle).reason,'data-cycle');
 const alias=new Map([['v',false]]);assert.equal(check(new Map([['a',alias],['b',alias]])).ok,true);
});
test('portable table depth and diagnostic paths match Lua root depth zero',()=>{
 assert.ok(data);const nested=n=>{const root=new Map();let p=root;for(let i=0;i<n;i++){const q=new Map();p.set('a',q);p=q;}return root;};
 assert.equal(data.checkPortable(nested(64)).ok,true);assert.equal(data.checkPortable(nested(65)).reason,'data-depth-limit');
 assert.deepEqual(data.checkPortable(new Map([['x',new Map([[1,Infinity]])]])),{ok:false,reason:'non-finite-number',path:'$.x[1]'});
});
test('actual LuaJIT generated oracle decodes without executing custom source',()=>{
 const proc=spawnSync('luajit',['tools/export_web_codec_fixtures.lua'],{encoding:'utf8',maxBuffer:4*1024*1024});
 assert.equal(proc.status,0,proc.stderr);const live=JSON.parse(proc.stdout);
 for(const v of [...live.goldens,...live.probes,...live.huffmanTruncations,...live.generated,...live.compressedProbes]){
  const r=decode(v.text);if('accepted'in v)assert.equal(r.ok,v.accepted,v.id??v.bytesRemoved);else assert.equal(r.ok,true,r.reason);
  if(r.ok)assert.deepEqual(typed(r.value),v.expected);else assert.equal(r.reason,v.reason);
 }
});

test('actual Lua compressor special dictionaries and expansion refusal',()=>{
 for(const v of fixtures.compressedProbes){const r=decode(v.text);assert.equal(r.ok,v.accepted,v.id);if(r.ok)assert.deepEqual(typed(r.value),v.expected);else assert.equal(r.reason,v.reason);}
});
test('generated actual Lua byte/float/table differential corpus',()=>{
 const proc=spawnSync('luajit',['tools/export_web_codec_fixtures.lua','--differential'],{encoding:'utf8',maxBuffer:4*1024*1024});
 assert.equal(proc.status,0,proc.stderr);const generated=JSON.parse(proc.stdout).generated;assert.equal(generated.length,74);
 for(const v of generated){const r=decode(v.text);assert.equal(r.ok,true,v.id+':'+r.reason);assert.deepEqual(typed(r.value),v.expected,v.id);}
});
test('maximum Store output and token count remain accepted at the exact boundary',()=>{
 const raw='^1^T^t^^';assert.equal(decode(stored(raw+' '.repeat(1048576-raw.length))).ok,true);
 const entries=Array.from({length:9998},(_,i)=>'^N'+(i+1)+'^b').join('');assert.equal(decode(stored('^1^T'+entries+'^t^^')).ok,true);
 expectReason(stored('^1^T'+entries+'^N9999^b^t^^'),'serializer-token-limit');
});
test('portable validation never invokes properties attached to a Map',()=>{
 assert.ok(data);const map=new Map([['safe',false]]);let calls=0;
 map.get=()=>{calls++;throw Error('MUST NOT CALL');};map.keys=()=>{calls++;throw Error('MUST NOT CALL');};
 assert.deepEqual(data.checkPortable(map),{ok:true});assert.equal(calls,0);
});

test('typed oracle numbers preserve exact IEEE-754 including signed zero and ties',()=>{
 for(const [number,bits] of [[0,'0000000000000000'],[-0,'8000000000000000'],[1,'3ff0000000000000'],[2**-1074,'0000000000000001'],[0.117633819580078125,'3fbe1d4000000000']])assert.deepEqual(typed(number),{type:'number',bits});
});

test('actual Lua malformed stream differential preserves bounded acceptance and refusal',()=>{
 const proc=spawnSync('luajit',['tools/export_web_codec_fixtures.lua','--adversarial'],{encoding:'utf8',maxBuffer:4*1024*1024});
 assert.equal(proc.status,0,proc.stderr);const mutations=JSON.parse(proc.stdout).mutations;assert.equal(mutations.length,360);
 for(const v of mutations){const r=decode(v.text);assert.equal(r.ok,v.accepted,v.id+':'+r.reason+' vs '+v.reason);if(r.ok)assert.deepEqual(typed(r.value),v.expected,v.id);else assert.equal(r.reason,v.reason,v.id);}
});
test('portable validation refuses forged and Proxy maps without executing traps',()=>{
 assert.ok(data);let calls=0;
 const proxy=new Proxy(new Map(),{getPrototypeOf(){calls++;throw Error('MUST NOT EXECUTE');},get(){calls++;throw Error('MUST NOT EXECUTE');}});
 assert.equal(data.checkPortable(proxy).reason,'non-portable-type');assert.equal(calls,0);
 assert.equal(data.checkPortable(Object.create(Map.prototype)).reason,'non-portable-type');
 class Extended extends Map{}assert.equal(data.checkPortable(new Extended()).reason,'non-portable-type');
});
test('custom code and HTML payloads remain inert bytes without input mutation',()=>{
 const source='globalThis.__rmCodecSentinel=1;fetch("https://invalid.test/");<script>alert(1)</script>';
 globalThis.__rmCodecSentinel=0;const raw=valueRaw('^S'+source),text=stored(raw),snapshot=text;
 const result=decode(text);assert.equal(result.ok,true);assert.equal(result.value.get('k'),source);
 assert.equal(globalThis.__rmCodecSentinel,0);assert.equal(text,snapshot);delete globalThis.__rmCodecSentinel;
});
test('compression output is detached and input bytes are not mutated',async()=>{
 const {decodeLegacyCompression}=await import('../Web/codec/libcompress.mjs');
 const input=Uint8Array.from([1,...bytes('^1^T^t^^')]),snapshot=input.slice();
 const out=decodeLegacyCompression(input);assert.equal(out.ok,true);assert.deepEqual(input,snapshot);
 out.bytes[0]=0;assert.deepEqual(input,snapshot);
});
test('bounded arbitrary wire inputs return fixed failures without exception data',()=>{
 let seed=31337;const rand=n=>{seed=(seed*48271)%2147483647;return seed%n;};
 for(let i=0;i<600;i++){
  const wire=new Uint8Array(rand(300)+1);for(let j=0;j<wire.length;j++)wire[j]=rand(256);
  if(i%3===0)wire[0]=1;else if(i%3===1)wire[0]=2;else{wire[0]=3;if(wire.length>=5){wire[2]=rand(100);wire[3]=0;wire[4]=0;}}
  const result=decode(b64(wire));assert.equal(typeof result.ok,'boolean');
  if(!result.ok){assert.match(result.reason,/^[a-z][a-z-]+$/);assert.ok(result.reason.length<64);assert.deepEqual(Object.keys(result).sort(),['ok','reason']);}
 }
});
