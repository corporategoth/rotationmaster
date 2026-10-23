#!/usr/bin/env node
// Rotation Master website: one command, no npm install.
//
//   node Web/server/server.mjs                 # http://127.0.0.1:8790/
//   node Web/server/server.mjs --port 9000 --db /tmp/rm.sqlite
//
// Options (flag or environment variable):
//   --host  RM_HOST            bind address (default 127.0.0.1)
//   --port  RM_PORT            port (default 8790; 0 picks a free one)
//   --db    RM_DB              SQLite file (default Web/server/data/site.sqlite; ":memory:" for throwaway)
//   --identity RM_IDENTITY     identity provider (default "dev"; see Web/DECISIONS.md)
//   RM_SESSION_SECRET          HMAC key for session cookies (random per start if unset)
//   RM_COOKIE_SECURE=1         mark cookies Secure (set when served over HTTPS)
//   RM_TRUST_PROXY=1           take the client address from X-Forwarded-For
//   RM_ALLOW_DEV_IDENTITY_PUBLIC=1  allow the dev identity on a non-loopback address (do not)
//   RM_REPORT_HIDE_THRESHOLD   hide a share automatically after N open reports (default 0 = never)
import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
import {createApp} from './app.mjs';
import {openStore} from './storage/store.mjs';
import {createIdentity} from './identity/provider.mjs';
import {createSessions} from './identity/session.mjs';

const LOOPBACK=new Set(['127.0.0.1','::1','localhost']);

export async function startServer(options={}){
  const env=options.env||process.env;
  const host=options.host??env.RM_HOST??'127.0.0.1';
  const port=Number(options.port??env.RM_PORT??8790);
  const dbPath=options.db??env.RM_DB??fileURLToPath(new URL('./data/site.sqlite',import.meta.url));
  const identityKind=options.identity??env.RM_IDENTITY??'dev';
  if(identityKind==='dev'&&!LOOPBACK.has(host)&&env.RM_ALLOW_DEV_IDENTITY_PUBLIC!=='1')
    throw Error('The development identity lets anyone sign in as anyone. Refusing to bind '+host+'; choose a real provider (Web/DECISIONS.md).');
  if(env.RM_SESSION_SECRET!==undefined&&env.RM_SESSION_SECRET.length<32)throw Error('RM_SESSION_SECRET must be at least 32 characters');
  const store=openStore({kind:'sqlite',path:dbPath});
  const identity=createIdentity(identityKind);
  const sessions=createSessions({secret:env.RM_SESSION_SECRET,secure:env.RM_COOKIE_SECURE==='1'});
  const log=options.log||((event,data)=>console.log(new Date().toISOString(),event,JSON.stringify(data)));
  const app=createApp({store,identity,sessions,trustProxy:env.RM_TRUST_PROXY==='1',log,
    limits:{reportHideThreshold:Number(env.RM_REPORT_HIDE_THRESHOLD||0)}});
  const server=createServer({requestTimeout:30000,headersTimeout:15000},app);
  server.maxHeadersCount=64;
  return new Promise((resolve,reject)=>{
    server.once('error',reject);
    server.listen(port,host,()=>{
      const address=server.address();
      resolve({server,store,url:`http://${address.family==='IPv6'?'['+address.address+']':address.address}:${address.port}/`,
        close:()=>new Promise(done=>server.close(()=>{store.close();done();}))});
    });
  });
}

if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
  const {values}=parseArgs({options:{host:{type:'string'},port:{type:'string'},db:{type:'string'},identity:{type:'string'},help:{type:'boolean',short:'h'}}});
  if(values.help){console.log('Usage: node Web/server/server.mjs [--host 127.0.0.1] [--port 8790] [--db path|:memory:] [--identity dev]');process.exit(0);}
  try{
    const running=await startServer(values);
    console.log(`Rotation Master site: ${running.url}  (database ${values.db??process.env.RM_DB??'Web/server/data/site.sqlite'})`);
    const stop=()=>{running.close().then(()=>process.exit(0));};
    process.on('SIGINT',stop);process.on('SIGTERM',stop);
  }catch(error){console.error(error.message);process.exit(1);}
}
