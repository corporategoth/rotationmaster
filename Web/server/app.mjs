// HTTP application: static site, server-rendered pages and the JSON API.
// Built on node:http only. createApp() returns a request listener so tests can
// mount it on an ephemeral loopback port.
import {readFileSync,createReadStream,statSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {extname,join,normalize,sep} from 'node:path';
import {validateShareUpload,validateReport,inspectExport,bundledName,SHARE_LIMITS,REPORT_REASONS} from './validate.mjs';
import {createRateLimiter} from './ratelimit.mjs';
import {createSessions} from './identity/session.mjs';
import {assertProvider} from './identity/provider.mjs';
import {assertStore} from './storage/store.mjs';
import {KINDS,CLASSES,EDITIONS} from '../site/kinds.mjs';
import * as pages from './pages.mjs';

const WEB_ROOT=fileURLToPath(new URL('..',import.meta.url));
// Only these parts of Web/ are served. Server code, tests and docs are not.
const STATIC_DIRS=['codec','schema','catalog','viewer','editor','site'];
const STATIC_FILES=new Set(['viewer.css']);
const TYPES={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.js':'text/javascript; charset=utf-8',
  '.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.ico':'image/x-icon','.txt':'text/plain; charset=utf-8','.woff2':'font/woff2'};
const STATIC_EXCLUDE=/(^|\/)(README\.md|.*\.md)$/;

export const DEFAULT_LIMITS=Object.freeze({
  ...SHARE_LIMITS,
  requestBytes:SHARE_LIMITS.exportBytes+SHARE_LIMITS.descriptionMax*4+8192,
  uploadsPerUserPerHour:10,uploadsPerIpPerHour:30,
  reportsPerUserPerHour:20,signInsPerIpPerHour:30,deletesPerUserPerHour:60,
  checksPerIpPerMinute:60,
  pageSize:24,
  reportHideThreshold:0,// 0 = reports never auto-hide a share (moderation policy is a decision)
});

const SECURITY_HEADERS={
  'Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
  'X-Content-Type-Options':'nosniff',
  'Referrer-Policy':'strict-origin-when-cross-origin',
  'Cross-Origin-Opener-Policy':'same-origin',
  'Cross-Origin-Resource-Policy':'same-origin',
  'Permissions-Policy':'camera=(), microphone=(), geolocation=(), payment=()',
};

export function createApp({store,identity,sessions,catalogText,limits={},trustProxy=false,clock=()=>Date.now(),log=()=>{}}={}){
  assertStore(store);assertProvider(identity);
  const L={...DEFAULT_LIMITS,...limits};
  sessions=sessions||createSessions({clock});
  catalogText=catalogText??readFileSync(join(WEB_ROOT,'schema/catalog.json'),'utf8');
  const limiter=createRateLimiter({clock});

  const clientIp=req=>{
    if(trustProxy){const fwd=String(req.headers['x-forwarded-for']||'').split(',')[0].trim();if(fwd)return fwd;}
    return req.socket.remoteAddress||'unknown';
  };
  function headers(res,extra={}){for(const [k,v] of Object.entries({...SECURITY_HEADERS,...extra}))res.setHeader(k,v);}
  function send(res,status,data,extra={}){
    if(res.headersSent)return;
    const body=JSON.stringify(data);
    headers(res,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...extra});
    res.writeHead(status);res.end(body);
  }
  function html(res,status,text){
    headers(res,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});
    res.writeHead(status);res.end(text);
  }
  function limited(res,result){send(res,429,{error:'rate-limited',retryAfter:result.retryAfter},{'Retry-After':String(result.retryAfter)});}

  // Reads a JSON body up to maxBytes. Sends the error itself and returns undefined on failure.
  function readJSON(req,res,maxBytes=L.requestBytes){
    return new Promise(resolve=>{
      const type=String(req.headers['content-type']||'').split(';')[0].trim().toLowerCase();
      if(type!=='application/json'){send(res,415,{error:'expected-json'});req.resume();return resolve(undefined);}
      const declared=Number(req.headers['content-length']);
      if(Number.isFinite(declared)&&declared>maxBytes){send(res,413,{error:'request-too-large',limit:maxBytes},{Connection:'close'});req.resume();return resolve(undefined);}
      const chunks=[];let size=0,done=false;
      req.on('data',chunk=>{
        if(done)return;size+=chunk.length;
        if(size>maxBytes){done=true;send(res,413,{error:'request-too-large',limit:maxBytes},{Connection:'close'});req.resume();resolve(undefined);return;}
        chunks.push(chunk);
      });
      req.on('end',()=>{
        if(done)return;done=true;
        try{resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));}
        catch{send(res,400,{error:'invalid-json'});resolve(undefined);}
      });
      req.on('error',()=>{if(!done){done=true;resolve(undefined);}});
    });
  }
  // State-changing API calls must be same-origin: a custom header (which a
  // cross-site form cannot send without a CORS preflight we never grant) and,
  // when the browser sends one, a matching Origin.
  function sameOrigin(req,res){
    if(req.headers['x-requested-with']!=='rotationmaster'){send(res,403,{error:'missing-request-header'});return false;}
    const origin=req.headers.origin;
    if(origin){
      let host;try{host=new URL(origin).host;}catch{host=null;}
      if(!host||host!==req.headers.host){send(res,403,{error:'cross-origin-request'});return false;}
    }
    return true;
  }
  function currentUser(req){
    const session=sessions.read(req);if(!session)return null;
    const user=store.getUser(session.id);
    if(!user||user.banned)return null;
    return {id:user.id,name:user.name,provider:user.provider};
  }
  function signIn(res,user){
    const record=store.getUser(user.id);
    if(record?.banned){send(res,403,{error:'account-suspended'});return null;}
    const saved=store.upsertUser(user);sessions.issue(res,saved);
    return {id:saved.id,name:saved.name,provider:saved.provider};
  }
  const pageCtx=(req,user)=>({user,identity:identity.describe(),reportReasons:REPORT_REASONS});

  async function api(req,res,url,user){
    const path=url.pathname;
    if(path==='/api/health'){send(res,200,{ok:true});return;}
    if(path==='/api/me'){send(res,200,{user,identity:identity.describe(),limits:{exportBytes:L.exportBytes,descriptionMax:L.descriptionMax,titleMax:L.titleMax}});return;}
    if(path==='/api/auth/logout'){
      if(req.method!=='POST')return send(res,405,{error:'method-not-allowed'});
      if(!sameOrigin(req,res))return;
      sessions.clear(res);return send(res,200,{ok:true});
    }
    if(path.startsWith('/api/auth/')){
      if(req.method==='POST'){
        if(!sameOrigin(req,res))return;
        const rl=limiter.take('signin',clientIp(req),{limit:L.signInsPerIpPerHour,windowSeconds:3600});if(!rl.ok)return limited(res,rl);
      }
      if(await identity.handle(req,res,url,{send,readJSON,signIn}))return;
      return send(res,404,{error:'not-found'});
    }
    if(path==='/api/check'){
      // Lets the upload form show exactly what the server will decide, before sign-in.
      if(req.method!=='POST')return send(res,405,{error:'method-not-allowed'});
      if(!sameOrigin(req,res))return;
      const rl=limiter.take('check',clientIp(req),{limit:L.checksPerIpPerMinute,windowSeconds:60});if(!rl.ok)return limited(res,rl);
      const body=await readJSON(req,res);if(body===undefined)return;
      const result=inspectExport(body?.export,{catalogText,maxBytes:L.exportBytes});
      if(!result.ok)return send(res,result.status,{error:result.code,reason:result.reason,path:result.path});
      return send(res,200,{kind:result.info.kind,name:result.info.name||bundledName(result.info.summary?.nameKey),risks:result.risks,declared:result.info.declared,bytes:result.bytes});
    }
    if(path==='/api/shares'){
      if(req.method==='GET'){
        const query=readQuery(url);const page=query.page;
        const result=store.listShares({q:query.q,kind:query.kind,cls:query.cls,edition:query.edition,owner:query.owner,limit:L.pageSize,offset:(page-1)*L.pageSize});
        return send(res,200,{total:result.total,page,pageSize:L.pageSize,items:result.items});
      }
      if(req.method==='POST'){
        if(!sameOrigin(req,res))return;
        if(!user)return send(res,401,{error:'sign-in-required'});
        const byUser=limiter.take('upload-user',user.id,{limit:L.uploadsPerUserPerHour,windowSeconds:3600});if(!byUser.ok)return limited(res,byUser);
        const byIp=limiter.take('upload-ip',clientIp(req),{limit:L.uploadsPerIpPerHour,windowSeconds:3600});if(!byIp.ok)return limited(res,byIp);
        const body=await readJSON(req,res);if(body===undefined)return;
        const checked=validateShareUpload(body,{catalogText,limits:L});
        if(!checked.ok){const {ok,status,code,...rest}=checked;return send(res,status,{error:code,...rest});}
        const duplicate=store.findDuplicate(user.id,checked.value.sha256);
        if(duplicate)return send(res,409,{error:'duplicate-share',id:duplicate,url:'/s/'+duplicate});
        const id=store.createShare(user,checked.value);
        log('share-created',{id,owner:user.id,kind:checked.value.kind,bytes:checked.value.bytes});
        return send(res,201,{id,url:'/s/'+id,share:store.getShare(id,{withExport:false})},{Location:'/s/'+id});
      }
      return send(res,405,{error:'method-not-allowed'});
    }
    const m=path.match(/^\/api\/shares\/([A-Za-z0-9]{6,20})(\/report)?$/);
    if(m){
      const id=m[1];
      if(m[2]){
        if(req.method!=='POST')return send(res,405,{error:'method-not-allowed'});
        if(!sameOrigin(req,res))return;
        if(!user)return send(res,401,{error:'sign-in-required'});
        const rl=limiter.take('report',user.id,{limit:L.reportsPerUserPerHour,windowSeconds:3600});if(!rl.ok)return limited(res,rl);
        const body=await readJSON(req,res,8192);if(body===undefined)return;
        const share=store.getShare(id,{withExport:false});if(!share)return send(res,404,{error:'not-found'});
        const checked=validateReport(body,{limits:L});
        if(!checked.ok)return send(res,checked.status,{error:checked.code,field:checked.field});
        const outcome=store.addReport(id,user.id,checked.value);
        if(L.reportHideThreshold>0&&outcome.count>=L.reportHideThreshold)store.setHidden(id,true);
        log('share-reported',{id,reporter:user.id,reason:checked.value.reason,count:outcome.count});
        return send(res,outcome.created?201:200,{ok:true,alreadyReported:!outcome.created});
      }
      if(req.method==='GET'){
        const share=store.getShare(id);if(!share)return send(res,404,{error:'not-found'});
        return send(res,200,{share});
      }
      if(req.method==='DELETE'){
        if(!sameOrigin(req,res))return;
        if(!user)return send(res,401,{error:'sign-in-required'});
        const rl=limiter.take('delete',user.id,{limit:L.deletesPerUserPerHour,windowSeconds:3600});if(!rl.ok)return limited(res,rl);
        const share=store.getShare(id,{includeHidden:true,withExport:false});if(!share)return send(res,404,{error:'not-found'});
        if(share.owner.id!==user.id)return send(res,403,{error:'not-owner'});
        store.deleteShare(id);log('share-deleted',{id,owner:user.id});
        res.writeHead(204,SECURITY_HEADERS);res.end();return;
      }
      return send(res,405,{error:'method-not-allowed'});
    }
    return send(res,404,{error:'not-found'});
  }

  function readQuery(url){
    const p=url.searchParams,pick=(k,allowed)=>{const v=p.get(k)||'';return allowed.includes(v)?v:'';};
    const page=Math.min(1000,Math.max(1,parseInt(p.get('page')||'1',10)||1));
    return {q:(p.get('q')||'').slice(0,100),kind:pick('kind',Object.keys(KINDS)),cls:pick('class',[...CLASSES,'ANY']),edition:pick('edition',EDITIONS),owner:(p.get('owner')||'').slice(0,128),page};
  }

  function serveStatic(req,res,path){
    if(req.method!=='GET'&&req.method!=='HEAD')return false;
    const rel=decodeURIComponent(path.slice(1));
    if(rel.includes('\0'))return false;
    const top=rel.split('/')[0];
    if(!(STATIC_FILES.has(rel)||STATIC_DIRS.includes(top)&&rel.includes('/')))return false;
    if(STATIC_EXCLUDE.test(rel))return false;
    const full=normalize(join(WEB_ROOT,rel));
    if(!full.startsWith(WEB_ROOT.endsWith(sep)?WEB_ROOT:WEB_ROOT+sep))return false;
    const type=TYPES[extname(full)];if(!type)return false;
    let stat;try{stat=statSync(full);}catch{return false;}
    if(!stat.isFile())return false;
    headers(res,{'Content-Type':type,'Content-Length':String(stat.size),'Cache-Control':'no-cache'});
    res.writeHead(200);
    if(req.method==='HEAD'){res.end();return true;}
    createReadStream(full).pipe(res);return true;
  }

  async function route(req,res){
    const url=new URL(req.url,'http://localhost');
    const path=url.pathname;
    const user=currentUser(req);
    if(path.startsWith('/api/'))return api(req,res,url,user);
    if(path.startsWith('/auth/')){if(await identity.handle(req,res,url,{send,readJSON,signIn}))return;}
    if(serveStatic(req,res,path))return;
    if(req.method!=='GET'&&req.method!=='HEAD'){send(res,405,{error:'method-not-allowed'});return;}
    const ctx=pageCtx(req,user);
    if(path==='/'){return html(res,200,pages.homePage(ctx,{recent:store.listShares({limit:6}).items}));}
    if(path==='/help'||path==='/help/'){return html(res,200,pages.helpPage(ctx,'index'));}
    const help=path.match(/^\/help\/([a-z0-9-]{1,64})\/?$/);
    if(help){const page=pages.helpPage(ctx,help[1]);if(page)return html(res,200,page);}
    if(path==='/shares'){
      const query=readQuery(url);
      const owner=query.owner?store.getUser(query.owner):null;
      const result=store.listShares({q:query.q,kind:query.kind,cls:query.cls,edition:query.edition,owner:query.owner,limit:L.pageSize,offset:(query.page-1)*L.pageSize});
      return html(res,200,pages.browsePage(ctx,{query,result,owner,page:query.page,pageSize:L.pageSize}));
    }
    if(path==='/shares/new')return html(res,200,pages.newSharePage(ctx,{limits:L}));
    const share=path.match(/^\/s\/([A-Za-z0-9]{6,20})$/);
    if(share){
      const record=store.getShare(share[1]);
      if(record)return html(res,200,pages.sharePage(ctx,{share:record,isOwner:!!user&&record.owner.id===user.id}));
      return html(res,404,pages.errorPage(ctx,404,'That share does not exist or was removed.'));
    }
    if(path==='/viewer'||path==='/viewer/')return html(res,200,pages.viewerPage(ctx));
    if(path==='/signin'){
      const next=url.searchParams.get('next')||'/';
      return html(res,200,pages.signInPage(ctx,{next:/^\/(?!\/)[^\s]*$/.test(next)?next:'/'}));
    }
    return html(res,404,pages.errorPage(ctx,404,'There is no page at this address.'));
  }

  return async function handler(req,res){
    try{await route(req,res);}
    catch(error){
      log('error',{message:error?.message,stack:error?.stack});
      if(!res.headersSent)send(res,500,{error:'internal-error'});else res.end();
    }
  };
}
