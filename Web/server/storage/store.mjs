// Share store interface. The HTTP layer depends only on these methods, so a
// hosted deployment can swap SQLite for another database without touching
// app.mjs. All methods are synchronous in the SQLite implementation; an async
// implementation would need app.mjs to await them (every call site is already
// inside an async handler).
//
//   kind: string
//   upsertUser({id,name,provider}) -> User            create or refresh a user row
//   getUser(id) -> User|null                           User: {id,name,provider,banned,createdAt}
//   setBanned(id,banned) -> boolean
//   findDuplicate(ownerId,sha256) -> shareId|null      same owner, same export text
//   createShare(owner:{id,name}, value) -> shareId     value from validateShareUpload()
//   getShare(id,{includeHidden,withExport}) -> Share|null
//   listShares({q,kind,cls,edition,owner,limit,offset,includeHidden}) -> {total,items:Share[]}
//   deleteShare(id) -> boolean
//   setHidden(id,hidden) -> boolean
//   addReport(shareId,reporterId,{reason,details}) -> {created,count}
//   listReports({open}) -> Report[]
//   resolveReports(shareId) -> number
//   close()
//
// Share: {id,title,description,kind,format,name,class,classSource,editions[],
//         editionSource,owner:{id,name},bytes,sha256,createdAt,hidden,
//         reportCount,summary,export?}
import {openSqliteStore} from './sqlite.mjs';

export const STORE_METHODS=Object.freeze(['upsertUser','getUser','setBanned','findDuplicate','createShare','getShare','listShares',
  'deleteShare','setHidden','addReport','listReports','resolveReports','close']);

export function assertStore(store){
  for(const name of STORE_METHODS)if(typeof store?.[name]!=='function')throw TypeError('store is missing '+name+'()');
  return store;
}
export function openStore({kind='sqlite',path}={}){
  if(kind==='sqlite')return assertStore(openSqliteStore(path));
  throw Error('unknown store kind '+kind);
}
