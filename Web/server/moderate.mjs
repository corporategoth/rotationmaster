#!/usr/bin/env node
// Moderation stub: operates directly on the share database. There is no
// moderator web UI yet (Web/DECISIONS.md lists the policy questions).
//
//   node Web/server/moderate.mjs [--db path] reports [--all]
//   node Web/server/moderate.mjs [--db path] hide <shareId> | unhide <shareId>
//   node Web/server/moderate.mjs [--db path] delete <shareId>
//   node Web/server/moderate.mjs [--db path] resolve <shareId>
//   node Web/server/moderate.mjs [--db path] ban <userId> | unban <userId>
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
import {openStore} from './storage/store.mjs';

const {values,positionals}=parseArgs({allowPositionals:true,options:{db:{type:'string'},all:{type:'boolean'}}});
const path=values.db??process.env.RM_DB??fileURLToPath(new URL('./data/site.sqlite',import.meta.url));
const [command,target]=positionals;
const store=openStore({kind:'sqlite',path});
const need=()=>{if(!target){console.error('missing id');process.exit(2);}};
let ok=true;
switch(command){
  case 'reports':
    for(const r of store.listReports({open:!values.all}))console.log([r.createdAt,r.shareId,r.reason,r.reporterId,r.hidden?'hidden':'visible',JSON.stringify(r.title),JSON.stringify(r.details)].join('\t'));
    break;
  case 'hide':need();ok=store.setHidden(target,true);break;
  case 'unhide':need();ok=store.setHidden(target,false);break;
  case 'delete':need();ok=store.deleteShare(target);break;
  case 'resolve':need();console.log(store.resolveReports(target)+' report(s) resolved');break;
  case 'ban':need();ok=store.setBanned(target,true);break;
  case 'unban':need();ok=store.setBanned(target,false);break;
  default:console.error('usage: moderate.mjs [--db path] reports [--all] | hide|unhide|delete|resolve <shareId> | ban|unban <userId>');ok=false;
}
store.close();
if(!ok){console.error('no change');process.exit(1);}
