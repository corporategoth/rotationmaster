// Small browser helpers shared by the site's page scripts.

/** Same-origin JSON API call. Returns {ok,status,data}. */
export async function api(path,{method='GET',body}={}){
  const init={method,credentials:'same-origin',redirect:'error',headers:{'X-Requested-With':'rotationmaster'}};
  if(body!==undefined){init.headers['Content-Type']='application/json';init.body=JSON.stringify(body);}
  let response;
  try{response=await fetch(path,init);}catch{return {ok:false,status:0,data:{error:'network-error'}};}
  let data=null;
  if(response.status!==204){try{data=await response.json();}catch{data=null;}}
  return {ok:response.ok,status:response.status,data};
}

export async function copyText(text,fallbackField){
  try{
    if(!navigator.clipboard?.writeText)throw Error('clipboard-unavailable');
    await navigator.clipboard.writeText(text);return true;
  }catch{
    if(fallbackField){fallbackField.focus();fallbackField.select();}
    return false;
  }
}

const MESSAGES={
  'network-error':'Could not reach the site. Check your connection and try again.',
  'sign-in-required':'Please sign in first.',
  'rate-limited':'Too many requests. Please wait a little and try again.',
  'request-too-large':'That is too large to upload.',
  'export-required':'Paste an export string first.',
  'export-too-large':'That export is larger than this site accepts.',
  'export-undecodable':'That text is not a Rotation Master export (it could not be decoded).',
  'export-unrecognized':'That decoded, but it is not an export kind this site recognises.',
  'export-unsupported-schema':'That rotation uses a newer format than this site understands yet.',
  'export-invalid-structure':'That rotation is structurally invalid, so it cannot be shared.',
  'title-required':'Give your share a title.',
  'title-too-short':'The title is too short.',
  'title-too-long':'The title is too long.',
  'description-too-long':'The description is too long.',
  'kind-mismatch':'The selected kind does not match the export.',
  'class-conflicts-with-export':'The export already declares a different class.',
  'editions-conflict-with-export':'The export already declares different editions.',
  'duplicate-share':'You have already shared this exact export.',
  'not-owner':'Only the person who shared this can delete it.',
  'not-found':'That share no longer exists.',
  'account-suspended':'This account cannot sign in.',
  'invalid-display-name':'Use 2 to 32 characters, including at least one letter or number.',
};
export function errorMessage(data,fallback='Something went wrong.'){
  const code=data?.error;
  let text=MESSAGES[code]||fallback;
  if(data?.reason&&(code==='export-undecodable'||code==='export-invalid-structure'||code==='export-unrecognized'))text+=` (${data.reason})`;
  return text;
}
export function el(document,tag,text,cls){
  const e=document.createElement(tag);
  if(text!==undefined&&text!==null)e.textContent=String(text);
  if(cls)e.setAttribute('class',cls);
  return e;
}
