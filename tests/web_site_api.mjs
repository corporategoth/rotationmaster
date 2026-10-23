// Website service: upload validation, limits, ownership, moderation stub and
// the guarantee that imported source and description HTML stay inert.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFileSync} from 'node:fs';
import {createApp} from '../Web/server/app.mjs';
import {openStore} from '../Web/server/storage/store.mjs';
import {createIdentity} from '../Web/server/identity/provider.mjs';
import {createSessions} from '../Web/server/identity/session.mjs';
import {encodeExport} from '../Web/codec/export.mjs';

const goldens=JSON.parse(readFileSync(new URL('./fixtures/web_codec.json',import.meta.url))).goldens;
const ENVELOPE=JSON.parse(readFileSync(new URL('./fixtures/web_defaults.json',import.meta.url))).records.find(r=>r.id==='rm.tbc.shaman.enhancement.icyveins').wire;// packaged TBC Shaman Enhancement (Icy Veins), declares SHAMAN/tbc
const LEGACY=goldens.find(g=>g.id==='original90083-store').text;      // valid legacy body
const INVALID=goldens.find(g=>g.id==='Store-bytes-map').text;         // decodes, but invalid rotation structure
const m=(...e)=>new Map(e),list=(...v)=>new Map(v.map((x,i)=>[i+1,x]));
const enc=value=>{const r=encodeExport(value);assert.equal(r.ok,true,r.reason);return r.text;};
const PWN="globalThis.__rmPwned=1; os.execute('rm -rf /') </script><script>globalThis.__rmPwned=2</script>";
const EXPORTS={
  function:enc(m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','function'],['id','custom.f'],['name','f'],['source',m(['code',PWN],['description','helper'])])],['dependencies',new Map()],['requirements',new Map()])),
  condition:enc(m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','condition'],['id','MY_COND'],['name','My condition'],['source',m(['evaluate',PWN],['on_register','print(1)'])])],['dependencies',new Map()],['requirements',new Map()])),
  'item-set':enc(m(['format','RM-ItemSet'],['version',1],['name','Bandages'],['items',list(21991,14530)])),
  'condition-category':enc(m(['format','RM-ConditionCategory'],['version',1],['name','Mine'],['conditions',list('BUFF','MY_COND')])),
  effect:enc(m(['name','Gold pulse'],['type','pulse'],['frequency',0.25],['sequence',list(1,1.2)])),
  announcement:enc(m(['format','RM-Announcement'],['version',2],['announcement',m(['type','macro'],['identifier','FOO'],['outputs',list(m(['id','11111111-2222-3333-4444-555555555555'],['announce','whisper'],['value','hi']))])])),
  profile:enc(m(['format','RM-Profile'],['version',1],['name','Alt'],['profile',m(['poll',0.2],['announces',m(['a',m(['type','spell'],['spell',1],['event','SUCCEEDED'],['announce','yell'],['value','x'])])])])),
};

async function start(options={}){
  const store=openStore({kind:'sqlite',path:':memory:'});
  const app=createApp({store,identity:createIdentity('dev'),sessions:createSessions({secret:'test-secret-0123456789abcdef'}),log:()=>{},...options});
  const server=createServer(app);
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const base='http://127.0.0.1:'+server.address().port;
  const call=async(path,{method='GET',body,cookie,headers={},raw}={})=>{
    const h={...headers};
    if(method!=='GET'&&!('x-requested-with' in h))h['x-requested-with']='rotationmaster';
    if(body!==undefined&&!('content-type' in h))h['content-type']='application/json';
    if(cookie)h.cookie=cookie;
    const response=await fetch(base+path,{method,headers:h,body:raw??(body===undefined?undefined:JSON.stringify(body)),redirect:'manual'});
    const text=await response.text();let json=null;try{json=JSON.parse(text);}catch{}
    return {status:response.status,headers:response.headers,text,json};
  };
  const signIn=async name=>{const r=await call('/api/auth/dev',{method:'POST',body:{displayName:name}});assert.equal(r.status,200,r.text);return r.headers.get('set-cookie').split(';')[0];};
  return {store,call,signIn,base,close:()=>new Promise(r=>{server.closeAllConnections?.();server.close(()=>{store.close();r();});})};
}
const upload=(s,cookie,body)=>s.call('/api/shares',{method:'POST',cookie,body:{title:'A test share',description:'',...body}});

test('pages render with security headers; server source and Markdown are not served',async()=>{
  const s=await start();
  try{
    const help=JSON.parse(readFileSync(new URL('../Web/site/help/index.json',import.meta.url))).pages;
    for(const path of ['/','/help/','/shares','/shares/new','/viewer','/signin','/api/health',...help.filter(p=>p.slug!=='index').map(p=>'/help/'+p.slug)]){
      const r=await s.call(path);assert.equal(r.status,200,path);
      assert.match(r.headers.get('content-security-policy'),/script-src 'self'/,path);
      assert.equal(r.headers.get('x-content-type-options'),'nosniff');
    }
    for(const path of ['/server/app.mjs','/site/help/index.md','/Web/server/app.mjs','/site/../server/app.mjs','/site/%2e%2e/server/app.mjs','/README.md','/nope','/help/nope'])
      assert.equal((await s.call(path)).status,404,path);
    assert.equal((await s.call('/viewer/app.mjs')).status,200);
    assert.equal((await s.call('/schema/catalog.json')).status,200);
  }finally{await s.close();}
});

test('state changes need sign-in, the request header, JSON and a same-origin Origin',async()=>{
  const s=await start();
  try{
    assert.equal((await upload(s,null,{export:ENVELOPE})).status,401);
    const cookie=await s.signIn('Thrall');
    assert.equal((await s.call('/api/shares',{method:'POST',cookie,headers:{'x-requested-with':''},body:{title:'x',export:ENVELOPE}})).status,403);
    assert.equal((await s.call('/api/shares',{method:'POST',cookie,headers:{origin:'https://evil.example'},body:{title:'abc',export:ENVELOPE}})).status,403);
    assert.equal((await s.call('/api/shares',{method:'POST',cookie,headers:{'content-type':'text/plain'},raw:'{}'})).status,415);
    assert.equal((await s.call('/api/shares',{method:'POST',cookie,headers:{'content-type':'application/json'},raw:'{not json'})).status,400);
    // A tampered session cookie is just anonymous. Flip the FIRST signature
    // character: the last one of a 32-byte base64url MAC carries two padding
    // bits, so 'A'<->'B' there decodes to the same bytes (a ~1-in-16 flake).
    const forged=cookie.replace(/\.(.)/,(_,c)=>'.'+(c==='A'?'B':'A'));assert.notEqual(forged,cookie);
    assert.equal((await upload(s,forged,{export:ENVELOPE})).status,401);
    assert.equal((await s.call('/api/me',{cookie:forged})).json.user,null);
    assert.equal((await s.call('/api/me',{cookie})).json.user.id,'dev:thrall');
  }finally{await s.close();}
});

test('every export kind uploads, is classified on the server, and is listed and filterable',async()=>{
  const s=await start();
  try{
    const cookie=await s.signIn('Jaina');
    const env=await upload(s,cookie,{title:'Shaman enhancement',export:ENVELOPE,description:'Leveling.'});
    assert.equal(env.status,201,env.text);
    assert.equal(env.json.share.kind,'rotation');assert.equal(env.json.share.class,'SHAMAN');assert.deepEqual(env.json.share.editions,['tbc']);
    assert.equal(env.json.share.classSource,'export');assert.equal(env.json.share.name,'Shaman: Enhancement (Icy Veins)');
    const legacy=await upload(s,cookie,{title:'Old shaman',export:LEGACY,class:'SHAMAN',editions:['era','tbc']});
    assert.equal(legacy.status,201,legacy.text);assert.equal(legacy.json.share.classSource,'uploader');assert.deepEqual(legacy.json.share.editions,['era','tbc']);
    for(const [kind,text] of Object.entries(EXPORTS)){
      const r=await upload(s,cookie,{title:'Kind '+kind,export:text,kind});
      assert.equal(r.status,201,kind+': '+r.text);assert.equal(r.json.share.kind,kind);
    }
    const all=(await s.call('/api/shares')).json;assert.equal(all.total,2+Object.keys(EXPORTS).length);
    assert.equal(all.items.some(i=>'export' in i),false,'listings never carry export text');
    assert.equal((await s.call('/api/shares?kind=item-set')).json.total,1);
    assert.equal((await s.call('/api/shares?class=SHAMAN')).json.total,2);
    assert.equal((await s.call('/api/shares?edition=era')).json.total,1);
    assert.equal((await s.call('/api/shares?q=bandages')).json.total,1,'search covers the in-game name too');
    assert.equal((await s.call('/api/shares?q=jaina')).json.total,2+Object.keys(EXPORTS).length,'and the uploader name');
    assert.equal((await s.call('/api/shares?q=Kind%20item')).json.total,1);
    assert.equal((await s.call('/api/shares?q=%25')).json.total,0,'LIKE wildcards are escaped');
    assert.equal((await s.call('/api/shares?owner=dev%3Ajaina')).json.total,2+Object.keys(EXPORTS).length);
    const one=(await s.call('/api/shares/'+env.json.id)).json.share;assert.equal(one.export,ENVELOPE);
    const page=await s.call('/s/'+env.json.id);assert.equal(page.status,200);assert.match(page.text,/Shaman enhancement/);
    const browse=await s.call('/shares?kind=function');assert.match(browse.text,/Kind function/);assert.match(browse.text,/Lua code/);
  }finally{await s.close();}
});

test('invalid, mismatched and oversized uploads are refused with a reason',async()=>{
  const s=await start({limits:{exportBytes:9000,descriptionMax:100,requestBytes:20000,uploadsPerUserPerHour:100}});
  try{
    const cookie=await s.signIn('Uther');
    const expect=async(body,status,error)=>{const r=await upload(s,cookie,body);assert.equal(r.status,status,JSON.stringify(body).slice(0,80)+' '+r.text);assert.equal(r.json.error,error);return r.json;};
    await expect({export:'not an export'},400,'export-undecodable');
    await expect({export:''},400,'export-required');
    await expect({export:enc(m(['hello','world']))},400,'export-unrecognized');
    await expect({export:INVALID},400,'export-invalid-structure');
    await expect({export:enc(m(['format','RM-ItemSet'],['version',9],['name','x'],['items',list(1)]))},400,'export-unrecognized');
    await expect({export:EXPORTS['item-set'],kind:'rotation'},400,'kind-mismatch');
    await expect({export:EXPORTS['item-set'],kind:'bogus'},400,'invalid-kind');
    await expect({export:ENVELOPE,class:'MAGE'},400,'class-conflicts-with-export');
    await expect({export:ENVELOPE,editions:['retail']},400,'editions-conflict-with-export');
    await expect({export:EXPORTS['item-set'],class:'GNOME'},400,'invalid-class');
    await expect({export:EXPORTS['item-set'],editions:['tbc','moon']},400,'invalid-editions');
    await expect({export:EXPORTS['item-set'],title:'ab'},400,'title-too-short');
    await expect({export:EXPORTS['item-set'],title:'x'.repeat(121)},400,'title-too-long');
    await expect({export:EXPORTS['item-set'],description:'x'.repeat(101)},413,'description-too-long');
    await expect({export:EXPORTS['item-set'],surprise:1},400,'unknown-field');
    await expect({export:'A'.repeat(10000)},413,'export-too-large');// over this server's 9000-byte export limit, under its request limit
    const big=await s.call('/api/shares',{method:'POST',cookie,headers:{'content-type':'application/json'},raw:JSON.stringify({title:'big',export:'A'.repeat(30000)})});
    assert.equal(big.status,413);assert.equal(big.json.error,'request-too-large');
    assert.equal((await s.call('/api/shares')).json.total,0);
  }finally{await s.close();}
});

test('the same uploader cannot publish the same export twice',async()=>{
  const s=await start();
  try{
    const cookie=await s.signIn('Arthas');
    const first=await upload(s,cookie,{export:EXPORTS.effect});assert.equal(first.status,201);
    const again=await upload(s,cookie,{export:'\n'+EXPORTS.effect+'\n',title:'Again'});
    assert.equal(again.status,409);assert.equal(again.json.id,first.json.id);
    const other=await s.signIn('Sylvanas');assert.equal((await upload(s,other,{export:EXPORTS.effect})).status,201);
  }finally{await s.close();}
});

test('uploads, sign-ins and reports are rate limited',async()=>{
  const s=await start({limits:{uploadsPerUserPerHour:2,signInsPerIpPerHour:3,reportsPerUserPerHour:1}});
  try{
    const cookie=await s.signIn('Garrosh');
    assert.equal((await upload(s,cookie,{export:EXPORTS.effect})).status,201);
    assert.equal((await upload(s,cookie,{export:EXPORTS['item-set']})).status,201);
    const limited=await upload(s,cookie,{export:EXPORTS.announcement});
    assert.equal(limited.status,429);assert.equal(limited.json.error,'rate-limited');assert.ok(Number(limited.headers.get('retry-after'))>0);
    await s.signIn('A1');await s.signIn('A2');
    assert.equal((await s.call('/api/auth/dev',{method:'POST',body:{displayName:'A3'}})).status,429);
    const id=(await s.call('/api/shares')).json.items[0].id;
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',cookie,body:{reason:'spam'}})).status,201);
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',cookie,body:{reason:'spam'}})).status,429);
  }finally{await s.close();}
});

test('only the uploader can delete a share',async()=>{
  const s=await start();
  try{
    const owner=await s.signIn('Anduin'),other=await s.signIn('Varian');
    const id=(await upload(s,owner,{export:EXPORTS['item-set']})).json.id;
    assert.equal((await s.call('/api/shares/'+id,{method:'DELETE'})).status,401);
    assert.equal((await s.call('/api/shares/'+id,{method:'DELETE',cookie:other})).status,403);
    assert.equal((await s.call('/api/shares/'+id,{method:'DELETE',cookie:owner,headers:{'x-requested-with':''}})).status,403);
    assert.equal((await s.call('/api/shares/'+id)).status,200);
    const page=await s.call('/s/'+id,{cookie:owner});assert.match(page.text,/data-action="delete-share"/);
    assert.doesNotMatch((await s.call('/s/'+id,{cookie:other})).text,/data-action="delete-share"/);
    assert.equal((await s.call('/api/shares/'+id,{method:'DELETE',cookie:owner})).status,204);
    assert.equal((await s.call('/api/shares/'+id)).status,404);
    assert.equal((await s.call('/s/'+id)).status,404);
    assert.equal((await s.call('/api/shares/'+id,{method:'DELETE',cookie:owner})).status,404);
  }finally{await s.close();}
});

test('reports are recorded once per user; optional threshold hides; banned users cannot sign in',async()=>{
  const s=await start({limits:{reportHideThreshold:2}});
  try{
    const owner=await s.signIn('Illidan'),a=await s.signIn('Tyrande'),b=await s.signIn('Malfurion');
    const id=(await upload(s,owner,{export:EXPORTS.function})).json.id;
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',body:{reason:'spam'}})).status,401);
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',cookie:a,body:{reason:'nope'}})).status,400);
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',cookie:a,body:{reason:'malicious',details:'<b>bad</b>'}})).status,201);
    const again=await s.call(`/api/shares/${id}/report`,{method:'POST',cookie:a,body:{reason:'malicious'}});
    assert.equal(again.status,200);assert.equal(again.json.alreadyReported,true);
    assert.equal((await s.call('/api/shares/'+id)).status,200,'one reporter does not reach the threshold of two');
    assert.equal((await s.call(`/api/shares/${id}/report`,{method:'POST',cookie:b,body:{reason:'spam'}})).status,201);
    assert.equal((await s.call('/api/shares/'+id)).status,404,'hidden after two distinct reports');
    assert.equal(s.store.listReports().length,2);
    assert.equal(s.store.listReports()[0].details,'<b>bad</b>','stored as plain text for moderators');
    s.store.setBanned('dev:tyrande',true);
    assert.equal((await s.call('/api/auth/dev',{method:'POST',body:{displayName:'Tyrande'}})).status,403);
    assert.equal((await s.call('/api/me',{cookie:a})).json.user,null,'an existing session of a banned user stops working');
  }finally{await s.close();}
});

test('imported source is never executed and description HTML is neutralised',async()=>{
  delete globalThis.__rmPwned;
  const s=await start();
  try{
    const cookie=await s.signIn('Kel\'Thuzad');
    const description=`Hi <script>globalThis.__rmPwned=3</script> <img src=x onerror="alert(1)"> [click](javascript:alert(1)) [ok](https://example.com) <iframe src="https://evil.example"></iframe>`;
    const fn=await upload(s,cookie,{title:'<b>Title</b> <script>x</script>',export:EXPORTS.function,description});
    assert.equal(fn.status,201,fn.text);
    const cond=await upload(s,cookie,{export:EXPORTS.condition});assert.equal(cond.status,201);
    const api=await s.call('/api/shares/'+fn.json.id);
    assert.equal(api.json.share.export,EXPORTS.function,'export text is returned exactly as data');
    const page=(await s.call('/s/'+fn.json.id)).text;
    assert.equal(globalThis.__rmPwned,undefined,'nothing from the export or description ran on the server');
    assert.doesNotMatch(page,/<script>globalThis|<script>x|<img|<iframe|href="javascript:/i);
    // No element anywhere carries an event-handler attribute (values are quoted and escaped).
    for(const tag of page.match(/<[a-z][a-z0-9]*(?:\s+[a-z:-]+(?:="[^"]*")?)*\s*\/?>/gi)){
      for(const [,name] of tag.matchAll(/\s([a-z:-]+)(?:="[^"]*")?/gi))assert.doesNotMatch(name,/^on/i,tag);
    }
    assert.match(page,/&lt;script&gt;globalThis\.__rmPwned=3&lt;\/script&gt;/);
    assert.match(page,/&lt;b&gt;Title&lt;\/b&gt;/);
    assert.match(page,/<a href="https:\/\/example\.com" rel="nofollow ugc noopener noreferrer">ok<\/a>/);
    // The only script elements are the site's own same-origin modules.
    for(const tag of page.match(/<script\b[^>]*>/g))assert.match(tag,/^<script (type="module" )?src="\/(site|viewer)\//,tag);
    // Risk warnings are computed on the server and shown first.
    assert.match(page,/Before you import/);assert.match(page,/Contains Lua code/);
    assert.ok(page.indexOf('Before you import')<page.indexOf('share-description'),'warnings precede the description');
    const condPage=(await s.call('/s/'+cond.json.id)).text;assert.match(condPage,/Code runs as soon as it is applied/);
    assert.equal(globalThis.__rmPwned,undefined);
  }finally{await s.close();}
});

test('the check endpoint reports kind and import warnings without signing in',async()=>{
  const s=await start();
  try{
    const r=await s.call('/api/check',{method:'POST',body:{export:EXPORTS.announcement}});
    assert.equal(r.status,200);assert.equal(r.json.kind,'announcement');
    assert.deepEqual(r.json.risks.map(x=>x.code),['chat-output','macro-trigger']);
    const p=await s.call('/api/check',{method:'POST',body:{export:EXPORTS.profile}});
    assert.deepEqual(p.json.risks.map(x=>x.code),['chat-output','replaces-profile']);
    assert.equal((await s.call('/api/check',{method:'POST',body:{export:'zzz'}})).json.error,'export-undecodable');
  }finally{await s.close();}
});

test('the dev identity refuses a public bind',async()=>{
  const {startServer}=await import('../Web/server/server.mjs');
  await assert.rejects(startServer({host:'0.0.0.0',port:0,db:':memory:',env:{}}),/Refusing to bind/);
  const running=await startServer({host:'127.0.0.1',port:0,db:':memory:',env:{},log:()=>{}});
  try{assert.match(running.url,/^http:\/\/127\.0\.0\.1:\d+\/$/);assert.equal((await fetch(running.url+'api/health')).status,200);}
  finally{await running.close();}
});
