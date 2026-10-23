// Loaded on every page: theme switch and sign-out.
import {api} from './client.mjs';

const root=document.documentElement;
function effectiveTheme(){
  const set=root.getAttribute('data-theme');
  if(set==='light'||set==='dark')return set;
  return matchMedia('(prefers-color-scheme: light)').matches?'light':'dark';
}
for(const button of document.querySelectorAll('[data-action="theme"]')){
  const label=()=>{const next=effectiveTheme()==='dark'?'light':'dark';button.setAttribute('aria-label','Switch to '+next+' theme');button.title='Switch to '+next+' theme';};
  label();
  button.addEventListener('click',()=>{
    const next=effectiveTheme()==='dark'?'light':'dark';
    root.setAttribute('data-theme',next);
    try{localStorage.setItem('rm-theme',next);}catch{}
    label();
  });
}
for(const button of document.querySelectorAll('[data-action="sign-out"]')){
  button.addEventListener('click',async()=>{
    button.disabled=true;
    await api('/api/auth/logout',{method:'POST',body:{}});
    location.reload();
  });
}
// On narrow screens the help topic list starts folded so the article comes first.
const helpNav=document.querySelector('.help-nav details');
if(helpNav&&matchMedia('(max-width: 1000px)').matches)helpNav.open=false;
