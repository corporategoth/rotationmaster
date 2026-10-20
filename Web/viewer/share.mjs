import {decodeImport} from '../codec/import.mjs';

// This is a product limit, not a promise about every browser or message client.
const linkLimit=8192,prefix='#rm-import-v1=';
const failure=reason=>({ok:false,reason});
const utf8=new TextEncoder();

export function createShareLink(original,pageURL){
  if(!decodeImport(original).ok)return failure('invalid-import');
  if(typeof pageURL!=='string')return failure('invalid-page-url');
  let page;
  try{page=new URL(pageURL);}catch{return failure('invalid-page-url');}
  if(!['http:','https:'].includes(page.protocol)||page.username||page.password)return failure('invalid-page-url');
  page.search='';page.hash='';
  const base=page.href;let size=base.length+prefix.length;
  // Successful I1 originals contain only ASCII transport and wrapping bytes.
  // Count first, so a valid 2 MiB original never creates an oversized escaped URL.
  for(let i=0;i<original.length;i++){
    size+=/[A-Za-z0-9\-_.!~*'()]/.test(original[i])?1:3;
    if(size>linkLimit)return failure('share-size-limit');
  }
  return {ok:true,url:base+prefix+encodeURIComponent(original)};
}

export function parseShareFragment(fragment){
  if(typeof fragment!=='string')return failure('invalid-share-fragment');
  if(fragment.length>linkLimit||utf8.encode(fragment).byteLength>linkLimit)return failure('share-size-limit');
  if(!fragment.startsWith(prefix))return failure(fragment.startsWith('#rm-import-')?'unsupported-share-version':'no-share-fragment');
  try{return {ok:true,original:decodeURIComponent(fragment.slice(prefix.length))};}
  catch{return failure('invalid-share-fragment');}
}

export function prepareOriginalDownload(original){
  if(!decodeImport(original).ok)return failure('invalid-import');
  return {ok:true,bytes:utf8.encode(original),filename:'rotation-master-export.txt',mediaType:'text/plain;charset=utf-8'};
}
