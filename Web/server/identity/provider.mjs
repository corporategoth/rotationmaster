// Identity provider interface.
//
// A provider establishes who a visitor is; sessions (./session.mjs) remember
// it. The app only talks to a provider through this shape:
//
//   id:        short provider name stored with each user ('dev', 'discord', ...)
//   label:     human name for the sign-in button ("Sign in with Discord")
//   describe() -> {id,label,kind:'form'|'redirect',startPath?,development:boolean}
//              tells the browser how to sign in: 'form' posts a display name
//              to /api/auth/<id>; 'redirect' sends the browser to startPath
//   handle(req,res,url,ctx) -> Promise<boolean>
//              handles the provider's own routes under /auth/<id>/... and
//              /api/auth/<id>; returns false for anything else. On success
//              it calls ctx.signIn(res,{id,name,provider}) which records the
//              user and issues the session cookie.
//
// User ids MUST be namespaced by provider ('dev:alice', 'discord:80351110224678912')
// so two providers can never collide. Display names are what other people see.
//
// Production auth is not implemented here; see Web/DECISIONS.md. A Discord
// OAuth2 provider would implement kind:'redirect', startPath:'/auth/discord/start',
// redirect to https://discord.com/oauth2/authorize with scope "identify" and a
// signed state value, exchange the code at /auth/discord/callback, read
// GET /users/@me, and call ctx.signIn with id 'discord:'+user.id and the
// user's global_name/username. Nothing else in the server needs to change.
import {createDevIdentity} from './dev.mjs';

export function assertProvider(provider){
  for(const key of ['id','label'])if(typeof provider?.[key]!=='string')throw TypeError('identity provider needs '+key);
  for(const key of ['describe','handle'])if(typeof provider?.[key]!=='function')throw TypeError('identity provider needs '+key+'()');
  return provider;
}
export function createIdentity(kind){
  if(kind==='dev')return assertProvider(createDevIdentity());
  throw Error(`identity provider "${kind}" is not implemented; see Web/DECISIONS.md`);
}
