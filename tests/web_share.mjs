import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {decodeImport} from '../Web/codec/import.mjs';
const share=await import('../Web/viewer/share.mjs').catch(()=>null);
const make=(...args)=>{assert.equal(typeof share?.createShareLink,'function','share link builder is available');return share.createShareLink(...args);};
const parse=(...args)=>{assert.equal(typeof share?.parseShareFragment,'function','fragment parser is available');return share.parseShareFragment(...args);};
const download=(...args)=>{assert.equal(typeof share?.prepareOriginalDownload,'function','exact download preparation is available');return share.prepareOriginalDownload(...args);};
const small='AV4xXlRedF5e'; // Actual Store/Ace1 empty table.
const base='https://example.invalid/viewer/';
const fixtures=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url),'utf8')).records;

test('outgoing link drops unrelated query/hash and preserves exact wrapping',()=>{
 assert.deepEqual(make(' \t'+small+'\r\n',base+'?token=private#old'),{ok:true,url:base+'#rm-import-v1=%20%09AV4xXlRedF5e%0D%0A'});
 assert.deepEqual(parse('#rm-import-v1=%20%09AV4xXlRedF5e%0D%0A'),{ok:true,original:' \t'+small+'\r\n'});
});
test('all twenty actual codec wires roundtrip without changing typed data',()=>{
 assert.equal(fixtures.length,20);
 for(const row of fixtures)for(const original of [row.wire,' \r\n'+row.wire+'\t']){
  assert.ok(original.includes('+'),row.id);
  const link=make(original,base);assert.equal(link.ok,true,row.id);
  const candidate=parse(new URL(link.url).hash);assert.deepEqual(candidate,{ok:true,original});
  assert.deepEqual(decodeImport(candidate.original).value,decodeImport(row.wire).value);
 }
});
test('raw plus survives and percent decoding happens once only',()=>{
 assert.deepEqual(parse('#rm-import-v1=a+b%2Bc%252B'),{ok:true,original:'a+b+c%2B'});
 assert.equal(decodeImport(parse('#rm-import-v1=%252B').original).ok,false);
});
test('unrelated fragments are ignored and unsupported transport versions are explicit',()=>{
 assert.deepEqual(parse(''),{ok:false,reason:'no-share-fragment'});
 assert.deepEqual(parse('#section'),{ok:false,reason:'no-share-fragment'});
 assert.deepEqual(parse('#rm-import-v2='+small),{ok:false,reason:'unsupported-share-version'});
});
test('malformed percent and UTF8 refuse with fixed feedback rather than echoing input',()=>{
 for(const tail of ['%','%0','%GG','%C0%AF','%ED%A0%80','%FF'])assert.deepEqual(parse('#rm-import-v1='+tail),{ok:false,reason:'invalid-share-fragment'});
 assert.deepEqual(parse(null),{ok:false,reason:'invalid-share-fragment'});
});
test('incoming fragment is a candidate only and never grants decode authority',()=>{
 const incoming=parse('#rm-import-v1=error%28%22inert%22%29');
 assert.deepEqual(incoming,{ok:true,original:'error("inert")'});
 assert.equal(decodeImport(incoming.original).ok,false);
});
test('incoming raw fragment is bounded before decoding',()=>{
 assert.deepEqual(parse('#rm-import-v1='+'a'.repeat(8192)),{ok:false,reason:'share-size-limit'});
 assert.deepEqual(parse('#rm-import-v1='+'a'.repeat(8178)),{ok:true,original:'a'.repeat(8178)});
});
test('invalid transport cannot acquire an outgoing link or download',()=>{
 for(const value of [null,'','wrong','RM9:'+small,small+'\v']){
  assert.deepEqual(make(value,base),{ok:false,reason:'invalid-import'});
  assert.deepEqual(download(value),{ok:false,reason:'invalid-import'});
 }
});
test('source structure support is independent of original transport sharing',()=>{
 const source=fixtures[0].wire;assert.equal(make(source,base).ok,true);assert.equal(download(source).ok,true);
 // A valid legacy empty table has no known rotation priority list.
 assert.equal(make(small,base).ok,true);
});
test('HTTP(S) page bases only; credentials never enter outgoing links',()=>{
 for(const page of ['javascript:alert(1)','file:///tmp/viewer','data:text/html,a','//example.invalid/a','https://name:secret@example.invalid/a',null])assert.deepEqual(make(small,page),{ok:false,reason:'invalid-page-url'});
 assert.equal(make(small,'http://127.0.0.1:8765/viewer?secret=x#other').url,'http://127.0.0.1:8765/viewer#rm-import-v1='+small);
});
test('full URL accepts 8192 bytes and refuses the next byte without truncation',()=>{
 // Prefix length is 24 plus a path; fragment is 14 plus the 12 byte fixture.
 const page='https://example.invalid/'+'p'.repeat(8142);
 const link=make(small,page);assert.equal(link.ok,true);assert.equal(link.url.length,8192);
 assert.deepEqual(make(small,page+'p'),{ok:false,reason:'share-size-limit'});
});
test('discarded query/hash and normalized path do not consume the outgoing link budget',()=>{
 const expected={ok:true,url:base+'#rm-import-v1='+small};
 for(const suffix of ['?old='+'a'.repeat(9000),'#old-'+'a'.repeat(9000),'?old='+'a'.repeat(4500)+'#old-'+'a'.repeat(4500)])assert.deepEqual(make(small,base+suffix),expected);
 assert.deepEqual(make(small,'https://example.invalid/'+('a/../'.repeat(2000))+'viewer/'),expected);
});
test('exact 2MiB import remains a downloadable original when its link is too large',()=>{
 const original=small+' '.repeat(2097152-small.length);assert.equal(decodeImport(original).ok,true);
 assert.deepEqual(make(original,base),{ok:false,reason:'share-size-limit'});
 const file=download(original);assert.equal(file.ok,true);assert.equal(file.bytes.byteLength,2097152);
 assert.equal(new TextDecoder().decode(file.bytes),original);
 assert.deepEqual(download(original+' '),{ok:false,reason:'invalid-import'});
});
test('download bytes are detached and line endings remain exact',()=>{
 const original='\r\n'+small+'\t\r';const first=download(original),second=download(original);
 assert.equal(first.filename,'rotation-master-export.txt');assert.equal(first.mediaType,'text/plain;charset=utf-8');
 assert.equal(new TextDecoder().decode(first.bytes),original);first.bytes[0]=65;
 assert.equal(new TextDecoder().decode(second.bytes),original);
});
