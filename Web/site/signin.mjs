import {api,errorMessage} from './client.mjs';

const form=document.getElementById('signin-form');
if(form){
  const status=document.getElementById('signin-status');
  form.addEventListener('submit',async event=>{
    event.preventDefault();
    const button=form.querySelector('button[type="submit"]');button.disabled=true;status.textContent='Signing in…';
    const result=await api('/api/auth/dev',{method:'POST',body:{displayName:form.elements.displayName.value}});
    if(result.ok){
      const next=form.dataset.next||'/';
      location.assign(/^\/(?!\/)/.test(next)?next:'/');
      return;
    }
    status.textContent=errorMessage(result.data);button.disabled=false;
  });
}
