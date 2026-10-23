// Local development identity: anyone can sign in as any display name. The
// user id is derived from the name ('dev:' + slug), so signing in again with
// the same name gives you the same shares back after a restart. This is
// deliberately NOT authentication; server.mjs refuses to expose it on a
// non-loopback address unless explicitly overridden.
export function createDevIdentity(){
  return {
    id:'dev',
    label:'Development sign-in',
    describe(){return {id:'dev',label:'Development sign-in',kind:'form',development:true};},
    async handle(req,res,url,ctx){
      if(url.pathname!=='/api/auth/dev')return false;
      if(req.method!=='POST'){ctx.send(res,405,{error:'method-not-allowed'});return true;}
      const body=await ctx.readJSON(req,res,4096);if(body===undefined)return true;
      const raw=typeof body?.displayName==='string'?body.displayName:'';
      const name=raw.normalize('NFC').replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩]/g,'').replace(/\s+/g,' ').trim();
      if([...name].length<2||[...name].length>32){ctx.send(res,400,{error:'invalid-display-name',field:'displayName'});return true;}
      const slug=name.toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'');
      if(!slug){ctx.send(res,400,{error:'invalid-display-name',field:'displayName'});return true;}
      const user=ctx.signIn(res,{id:'dev:'+slug,name,provider:'dev'});
      if(user)ctx.send(res,200,{user});
      return true;
    },
  };
}
