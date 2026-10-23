// Signed session cookie shared by every identity provider. The cookie holds
// {sub,name,prov,iat,exp} signed with HMAC-SHA256; it is HttpOnly and
// SameSite=Lax. Providers only decide WHO the user is; this module remembers it.
import {createHmac,randomBytes,timingSafeEqual} from 'node:crypto';

export const SESSION_COOKIE='rm_session';
const b64=buf=>Buffer.from(buf).toString('base64url');

export function createSessions({secret,ttlSeconds=30*24*3600,secure=false,clock=()=>Date.now()}={}){
  const key=secret?Buffer.from(secret,'utf8'):randomBytes(32);
  if(key.length<16)throw Error('session secret must be at least 16 bytes');
  const sign=data=>createHmac('sha256',key).update(data).digest();
  return {
    issue(res,user){
      const now=Math.floor(clock()/1000);
      const payload=b64(JSON.stringify({sub:user.id,name:user.name,prov:user.provider,iat:now,exp:now+ttlSeconds}));
      const value=payload+'.'+b64(sign(payload));
      appendCookie(res,`${SESSION_COOKIE}=${value}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${ttlSeconds}${secure?'; Secure':''}`);
    },
    clear(res){appendCookie(res,`${SESSION_COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0${secure?'; Secure':''}`);},
    read(req){
      const raw=parseCookies(req.headers.cookie||'')[SESSION_COOKIE];
      if(!raw||raw.length>2048)return null;
      const [payload,signature]=raw.split('.');
      if(!payload||!signature)return null;
      const expected=sign(payload),given=Buffer.from(signature,'base64url');
      if(given.length!==expected.length||!timingSafeEqual(given,expected))return null;
      let data;try{data=JSON.parse(Buffer.from(payload,'base64url').toString('utf8'));}catch{return null;}
      if(typeof data?.sub!=='string'||typeof data.name!=='string'||typeof data.exp!=='number'||data.exp<Math.floor(clock()/1000))return null;
      return {id:data.sub,name:data.name,provider:data.prov};
    },
  };
}
export function parseCookies(header){
  const out={};
  for(const part of header.split(';')){const i=part.indexOf('=');if(i<0)continue;const k=part.slice(0,i).trim();if(k&&!(k in out))out[k]=part.slice(i+1).trim();}
  return out;
}
function appendCookie(res,value){
  const prior=res.getHeader('Set-Cookie');
  res.setHeader('Set-Cookie',prior?[].concat(prior,value):value);
}
