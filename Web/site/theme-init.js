// Classic (non-module) script, loaded before styles so the saved theme applies
// without a flash. Storage can be unavailable (private mode); that is fine.
(function(){try{var t=localStorage.getItem('rm-theme');if(t==='light'||t==='dark')document.documentElement.setAttribute('data-theme',t);}catch(e){}})();
