// Server-rendered pages. Every dynamic value goes through escapeHTML (or the
// safe Markdown renderer); imported export data is never interpolated here
// except as escaped text inside a read-only textarea.
import {readFileSync} from 'node:fs';
import {escapeHTML as h,parseMarkdown,toHTML,outline,excerpt} from '../site/markdown.mjs';
import {KINDS,CLASSES,CLASS_LABELS,EDITIONS,EDITION_LABELS} from '../site/kinds.mjs';

export const LINKS=Object.freeze({
  discord:'https://discord.gg/4aKZSpUMet',
  github:'https://github.com/corporategoth/rotationmaster',
  wiki:'https://github.com/corporategoth/rotationmaster/wiki',
  issues:'https://github.com/corporategoth/rotationmaster/issues',
});
const SITE_ROOT=new URL('../site/',import.meta.url);
const helpManifest=JSON.parse(readFileSync(new URL('help/index.json',SITE_ROOT),'utf8'));
export const HELP_PAGES=helpManifest.pages;
const conditionNames=JSON.parse(readFileSync(new URL('conditions.json',SITE_ROOT),'utf8'));

const icon={
  chat:'<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 5h16v10H9l-5 4z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><circle cx="9" cy="10" r="1.2" fill="currentColor"/><circle cx="15" cy="10" r="1.2" fill="currentColor"/></svg>',
  code:'<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 7l-5 5 5 5M16 7l5 5-5 5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  theme:'<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor"/></svg>',
  logo:'<svg class="logo" viewBox="0 0 32 32" aria-hidden="true" focusable="false"><rect x="9" y="9" width="14" height="14" rx="2" fill="var(--gold)"/><path d="M16 3a13 13 0 1 1-12.4 9" fill="none" stroke="var(--azure)" stroke-width="2.6" stroke-linecap="round"/><path d="M1.5 8.5l2.2 4.2 4.1-2.3" fill="none" stroke="var(--azure)" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

const NAV=[['help','/help/','Help'],['browse','/shares','Browse shares'],['share','/shares/new','Share an export'],['viewer','/viewer','Viewer & compare']];

/** Wrap content in the site shell. */
export function layout({title,description='',active='',user=null,identity=null,body,styles=[],scripts=[],meta=[],path='/'}){
  const nav=NAV.map(([key,href,label])=>`<a href="${href}"${key===active?' aria-current="page"':''}>${label}</a>`).join('');
  const account=user
    ?`<span class="account"><a href="/shares?owner=${encodeURIComponent(user.id)}" title="Your shares">${h(user.name)}</a><button type="button" class="link-button" data-action="sign-out">Sign out</button></span>`
    :`<a class="account" href="/signin?next=${encodeURIComponent(path)}">Sign in</a>`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${h(title?title+' · Rotation Master':'Rotation Master')}</title>
${description?`<meta name="description" content="${h(description)}">`:''}
<meta property="og:site_name" content="Rotation Master">
<meta property="og:title" content="${h(title||'Rotation Master')}">
${description?`<meta property="og:description" content="${h(description)}">`:''}
${meta.join('\n')}
<link rel="icon" href="/site/logo.svg" type="image/svg+xml">
<script src="/site/theme-init.js"></script>
${styles.map(s=>`<link rel="stylesheet" href="${h(s)}">`).join('\n')}
<link rel="stylesheet" href="/site/site.css">
<script type="module" src="/site/site.mjs"></script>
${scripts.map(s=>`<script type="module" src="${h(s)}"></script>`).join('\n')}
</head>
<body>
<a class="skip-link" href="#content">Skip to content</a>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="/">${icon.logo}<span>Rotation Master</span></a>
    <nav class="main-nav" aria-label="Main">${nav}</nav>
    <div class="header-actions">
      <a class="button discord" href="${LINKS.discord}" rel="noopener" aria-label="Rotation Master Discord">${icon.chat}<span>Discord</span></a>
      <button type="button" class="icon-button" data-action="theme" aria-label="Switch colour theme" title="Switch colour theme">${icon.theme}</button>
      ${account}
    </div>
  </div>
</header>
<main id="content" tabindex="-1">
${body}
</main>
<footer class="site-footer">
  <div class="footer-inner">
    <p><strong>Rotation Master</strong> is a World of Warcraft addon. Questions, ideas or a rotation to show off? <a href="${LINKS.discord}" rel="noopener">Join us on Discord</a>.</p>
    <p class="footer-links"><a href="${LINKS.github}" rel="noopener">${icon.code} Source on GitHub</a> <a href="${LINKS.issues}" rel="noopener">Report a bug</a> <a href="${LINKS.wiki}" rel="noopener">Wiki</a> <a href="/help/">Help</a></p>
    <p class="fine">Shared exports are published by the people who uploaded them and are shown as data only; this site never runs their code. Not affiliated with Blizzard Entertainment.${identity?.development?' <span class="dev-note">Development sign-in is active: anyone can use any name.</span>':''}</p>
  </div>
</footer>
</body>
</html>
`;
}

const dateText=iso=>{const d=new Date(iso);return isNaN(d)?'':d.toISOString().slice(0,10);};
const kindLabel=k=>KINDS[k]?.label||k;
function tagList(share){
  const tags=[`<span class="tag tag-kind">${h(kindLabel(share.kind))}</span>`];
  if(share.class)tags.push(`<span class="tag tag-class" data-class="${h(share.class)}">${h(CLASS_LABELS[share.class]||share.class)}</span>`);
  for(const e of share.editions)tags.push(`<span class="tag tag-edition">${h(EDITION_LABELS[e]||e)}</span>`);
  return `<p class="tags">${tags.join(' ')}</p>`;
}
const RISK_BADGES={'lua-code':'Lua code','chat-output':'Chat messages','macro-trigger':'Macro trigger','replaces-profile':'Replaces profile','needs-custom-conditions':'Needs custom conditions','unrecognized':'Unrecognised content'};
function riskBadges(share){
  const risks=share.summary?.risks||[];
  return risks.filter(r=>RISK_BADGES[r.code]).map(r=>`<span class="tag tag-risk tag-risk-${h(r.level)}">${h(RISK_BADGES[r.code])}</span>`).join(' ');
}
export function riskPanel(risks){
  if(!risks?.length)return '<aside class="risk-panel risk-none"><p>Nothing to warn about: no Lua code, no chat messages to other players, no unrecognised content.</p></aside>';
  return `<aside class="risk-panel" aria-label="Before you import"><h2>Before you import</h2><ul class="risk-list">${risks.map(r=>
    `<li class="risk risk-${h(r.level)}"><strong>${h(r.title)}</strong> <span>${h(r.detail)}</span>${r.where?.length?`<span class="risk-where"> Found in: ${h(r.where.join('; ')+(r.count>r.where.length?'; …':''))}.</span>`:''}</li>`).join('')}</ul></aside>`;
}
function shareCard(share){
  return `<li class="share-card">
  <h3><a href="/s/${h(share.id)}">${h(share.title)}</a></h3>
  ${tagList(share)}
  ${riskBadges(share)?`<p class="tags">${riskBadges(share)}</p>`:''}
  <p class="excerpt">${h(excerpt(share.description,180)||share.name||'')}</p>
  <p class="byline">by <a href="/shares?owner=${encodeURIComponent(share.owner.id)}">${h(share.owner.name)}</a> · <time datetime="${h(share.createdAt)}">${dateText(share.createdAt)}</time></p>
</li>`;
}

export function homePage(ctx,{recent}){
  const body=`
<section class="hero">
  <div class="hero-text">
    <h1>Your rotation, highlighted on your action bars.</h1>
    <p class="lead">Rotation Master is a World of Warcraft addon that watches your character and lights up the next spell or item to use, following a priority list you can read, edit and share. Start with a Built In rotation or write your own.</p>
    <p class="cta"><a class="button primary" href="/help/getting-started">Get started</a> <a class="button" href="/shares">Browse shares</a> <a class="button discord" href="${LINKS.discord}" rel="noopener">${icon.chat} Join the Discord</a></p>
  </div>
  <figure class="hero-figure" aria-label="How a recommendation is chosen">
<pre>Switch conditions ─► active rotation
        │
        ▼
1. Spell A  ✗ conditions not met
2. Spell B  ✓ ─► ready? ─► <span class="hl">HIGHLIGHT</span>
3. Branch ─► True arm / False arm
   …
Cooldowns: each one highlights alone</pre>
  </figure>
</section>
<section class="cards" aria-label="What you can do here">
  <article class="card"><h2><a href="/help/">Learn</a></h2><p>A player's guide to every part of the addon: rotations, conditions, cooldowns, item sets, announcements, slash commands and editions.</p></article>
  <article class="card"><h2><a href="/shares">Share</a></h2><p>Publish an export — a rotation, custom function, custom condition, item set, effect, announcement or profile — with a description, and find what others have shared.</p></article>
  <article class="card"><h2><a href="/viewer">Inspect</a></h2><p>Paste any export to read it without installing it, or compare two exports side by side. Nothing you paste leaves your browser.</p></article>
</section>
<section class="recent">
  <h2>Recently shared</h2>
  ${recent.length?`<ul class="share-list">${recent.map(shareCard).join('')}</ul><p><a href="/shares">See all shares →</a></p>`:`<p>Nothing has been shared yet. <a href="/shares/new">Be the first</a>.</p>`}
</section>`;
  return layout({...ctx,title:'',description:'Rotation Master: a World of Warcraft addon that highlights your next action. Help, guides and shared rotations.',body});
}

function conditionsReference(){
  const rows=[];
  rows.push('## Logical conditions\n\n| Condition | What it does |\n|---|---|\n| All of (AND) | Every child must match. An empty All group matches. |\n| Any of (OR) | At least one child must match. An empty Any group does not match. |\n| Not | Reverses its child. An unavailable reading stays unavailable. |\n');
  for(const group of conditionNames.groups){
    rows.push(`## ${group.name}\n\n| Condition | Identifier | Switch condition by default |\n|---|---|---|`);
    for(const id of group.conditions){
      const c=conditionNames.conditions[id];
      rows.push(`| ${c.name.replace(/\|/g,'\\|')} | \`${id}\` | ${conditionNames.switchDefaults.includes(id)?(conditionNames.switchOnly.includes(id)?'Yes (switch only)':'Yes'):''} |`);
    }
    rows.push('');
  }
  return rows.join('\n');
}

export function helpPage(ctx,slug){
  const index=HELP_PAGES.findIndex(p=>p.slug===slug);
  if(index<0)return null;
  const page=HELP_PAGES[index];
  let source=readFileSync(new URL('help/'+page.slug+'.md',SITE_ROOT),'utf8');
  if(page.generated==='conditions')source+='\n\n'+conditionsReference();
  const ast=parseMarkdown(source);
  const sections=outline(ast).filter(o=>o.level===2);
  const sidebar=helpManifest.sections.map(section=>`<h2>${h(section.title)}</h2><ul>${HELP_PAGES.filter(p=>p.section===section.id).map(p=>`<li><a href="/help/${p.slug==='index'?'':h(p.slug)}"${p.slug===slug?' aria-current="page"':''}>${h(p.title)}</a></li>`).join('')}</ul>`).join('');
  const prev=HELP_PAGES[index-1],next=HELP_PAGES[index+1];
  const body=`
<div class="help-layout">
  <nav class="help-nav" aria-label="Help topics"><details open><summary>Help topics</summary>${sidebar}</details></nav>
  <article class="help-article prose">
    ${toHTML(ast,{allowRelative:true,externalRel:'noopener'})}
    <nav class="pager" aria-label="Previous and next topic">${prev?`<a class="prev" href="/help/${prev.slug==='index'?'':h(prev.slug)}">← ${h(prev.title)}</a>`:'<span></span>'}${next?`<a class="next" href="/help/${h(next.slug)}">${h(next.title)} →</a>`:''}</nav>
    <p class="help-footer">Still stuck? Ask on <a href="${LINKS.discord}" rel="noopener">Discord</a> or <a href="${LINKS.issues}" rel="noopener">open an issue</a>.</p>
  </article>
  ${sections.length>2?`<nav class="help-outline" aria-label="On this page"><h2>On this page</h2><ul>${sections.map(s=>`<li><a href="#${h(s.id)}">${h(s.text)}</a></li>`).join('')}</ul></nav>`:''}
</div>`;
  return layout({...ctx,active:'help',title:page.slug==='index'?'Help':page.title,description:page.summary,body,path:'/help/'+page.slug});
}

function option(value,label,selected){return `<option value="${h(value)}"${value===selected?' selected':''}>${h(label)}</option>`;}
export function browsePage(ctx,{query,result,owner,page,pageSize}){
  const pages=Math.max(1,Math.ceil(result.total/pageSize));
  const link=p=>{const params=new URLSearchParams();for(const [k,v] of Object.entries({q:query.q,kind:query.kind,class:query.cls,edition:query.edition,owner:query.owner}))if(v)params.set(k,v);if(p>1)params.set('page',String(p));const s=params.toString();return '/shares'+(s?'?'+s:'');};
  const heading=owner?`Shared by ${h(owner.name)}`:'Browse shares';
  const body=`
<div class="page-head"><h1>${heading}</h1><p><a class="button primary" href="/shares/new">Share an export</a></p></div>
<form class="filters" method="get" action="/shares" role="search">
  <label>Search <input type="search" name="q" value="${h(query.q)}" maxlength="100" placeholder="Title, description, author"></label>
  <label>Kind <select name="kind">${option('','Any kind',query.kind)}${Object.entries(KINDS).map(([k,v])=>option(k,v.label,query.kind)).join('')}</select></label>
  <label>Class <select name="class">${option('','Any class',query.cls)}${CLASSES.map(c=>option(c,CLASS_LABELS[c],query.cls)).join('')}${option('ANY','Class-independent only',query.cls)}</select></label>
  <label>Edition <select name="edition">${option('','Any edition',query.edition)}${EDITIONS.map(e=>option(e,EDITION_LABELS[e],query.edition)).join('')}</select></label>
  ${query.owner?`<input type="hidden" name="owner" value="${h(query.owner)}">`:''}
  <button type="submit" class="button">Filter</button>
</form>
<p class="result-count" role="status">${result.total} ${result.total===1?'share':'shares'}${query.q||query.kind||query.cls||query.edition?' match':''}.${query.owner?` <a href="/shares">Show everyone's</a>`:''}</p>
${result.items.length?`<ul class="share-list">${result.items.map(shareCard).join('')}</ul>`:'<p class="empty">No shares found. Try fewer filters.</p>'}
${pages>1?`<nav class="pager" aria-label="Pages">${page>1?`<a class="prev" href="${h(link(page-1))}">← Newer</a>`:'<span></span>'}<span>Page ${page} of ${pages}</span>${page<pages?`<a class="next" href="${h(link(page+1))}">Older →</a>`:'<span></span>'}</nav>`:''}`;
  return layout({...ctx,active:'browse',title:heading.replace(/<[^>]*>/g,''),description:'Rotations, custom conditions, functions, item sets and more, shared by Rotation Master players.',body,path:'/shares'});
}

export function newSharePage(ctx,{limits}){
  const body=`
<div class="page-head"><h1>Share an export</h1></div>
<p class="lead">Paste an export from the addon's Import/Export dialog. It is checked here and again on the server; it is never run.</p>
${ctx.user?'':`<aside class="callout callout-note"><p><strong>Sign in to publish.</strong> You can check an export without signing in. <a href="/signin?next=%2Fshares%2Fnew">Sign in</a></p></aside>`}
<form id="share-form" class="share-form" novalidate data-signed-in="${ctx.user?'yes':'no'}" data-export-limit="${limits.exportBytes}" data-description-limit="${limits.descriptionMax}">
  <label for="share-export">Export string</label>
  <textarea id="share-export" name="export" rows="7" spellcheck="false" autocomplete="off" required placeholder="RM1:… or the text from any Import/Export dialog"></textarea>
  <p class="hint">Rotations, custom functions and conditions (with dependencies), condition categories, item sets, effects, announcements and profiles are all accepted. Up to ${Math.round(limits.exportBytes/1024)} KiB.</p>
  <p class="actions"><button type="button" class="button" id="share-check">Check export</button></p>
  <div id="share-detected" class="detected" role="status" aria-live="polite"></div>
  <fieldset id="share-details" disabled>
    <legend>About this share</legend>
    <label for="share-title">Title</label>
    <input id="share-title" name="title" maxlength="${120}" required>
    <label for="share-description">Description <span class="hint">(Markdown: **bold**, *italic*, lists, links, \`code\`. No HTML.)</span></label>
    <textarea id="share-description" name="description" rows="10" maxlength="${limits.descriptionMax}" placeholder="What is it for? Which level, spec or content? Anything people should know before importing it?"></textarea>
    <details class="preview-box"><summary>Preview description</summary><div id="share-preview" class="prose"></div></details>
    <div class="tag-fields">
      <label for="share-class">Class</label>
      <select id="share-class" name="class">${option('','Not stated','')}${option('ANY','Any class','')}${CLASSES.map(c=>option(c,CLASS_LABELS[c],'')).join('')}</select>
      <fieldset class="editions"><legend>Editions</legend>${EDITIONS.map(e=>`<label class="check"><input type="checkbox" name="editions" value="${e}"> ${h(EDITION_LABELS[e])}</label>`).join('')}</fieldset>
      <p class="hint" id="share-tag-note">When the export declares its class or editions, those are used and cannot be changed here.</p>
    </div>
    <p class="actions"><button type="submit" class="button primary" id="share-submit">Publish share</button></p>
    <div id="share-result" role="status" aria-live="polite"></div>
  </fieldset>
</form>
<noscript><p class="callout callout-warning">Publishing needs JavaScript so the export can be checked in your browser first.</p></noscript>`;
  return layout({...ctx,active:'share',title:'Share an export',description:'Publish a Rotation Master export with a description.',body,styles:['/viewer.css'],scripts:['/site/share-form.mjs'],path:'/shares/new'});
}

export function sharePage(ctx,{share,isOwner}){
  const desc=share.description?toHTML(parseMarkdown(share.description),{headingOffset:2,idPrefix:'d-',allowRelative:false}):'<p class="empty">No description.</p>';
  const structure=share.summary?.structure;
  const body=`
<article class="share-view" data-share-id="${h(share.id)}" data-kind="${h(share.kind)}">
  <header class="share-head">
    <p class="crumbs"><a href="/shares">Shares</a> / ${h(kindLabel(share.kind))}</p>
    <h1>${h(share.title)}</h1>
    ${tagList(share)}
    <p class="byline">Shared by <a href="/shares?owner=${encodeURIComponent(share.owner.id)}">${h(share.owner.name)}</a> <span class="user-id">(${h(share.owner.id)})</span> · <time datetime="${h(share.createdAt)}">${dateText(share.createdAt)}</time>${share.name&&share.name!==share.title?` · In-game name: <q>${h(share.name)}</q>`:''}</p>
    <p class="tag-source">${share.classSource==='export'||share.editionSource==='export'?'Class and edition tags come from the export itself.':share.class||share.editions.length?'Class and edition tags were stated by the uploader.':''}${structure?` Structure ${structure.valid?'valid':'invalid'}${structure.resolved?'':'; some references (such as custom conditions) are not in the standard catalog'}.`:''}</p>
  </header>
  ${riskPanel(share.summary?.risks)}
  <section class="share-description prose" aria-label="Description">${desc}</section>
  <section class="share-export">
    <h2>Import it</h2>
    <p>Copy the export, then in game open <code>/rm config</code>, choose the matching tab and use <strong>Import/Export</strong>. ${share.kind==='function'||share.kind==='condition'?'<strong>This export contains Lua code.</strong> Read it below and only import code you trust.':''}</p>
    <label for="export-text">Export string <span class="hint">(${share.bytes<1024?share.bytes+' bytes':Math.round(share.bytes/1024)+' KiB'})</span></label>
    <textarea id="export-text" rows="5" readonly spellcheck="false">${h(share.export)}</textarea>
    <p class="actions"><button type="button" class="button primary" data-action="copy-export">Copy export string</button> <a class="button" id="open-viewer" href="/viewer">Open in viewer</a> <span id="copy-status" role="status" aria-live="polite"></span></p>
  </section>
  <section class="share-visual">
    <h2>What's inside</h2>
    <p class="hint">Every step, branch arm, cooldown and condition, decoded in your browser. Spells and items are shown by their game ID.</p>
    <div id="share-visual"><p class="loading">Decoding in your browser…</p></div>
    <noscript><p>Enable JavaScript to see a breakdown of this export. The export string above is complete.</p></noscript>
  </section>
  <section class="share-manage">
    ${isOwner?`<p><button type="button" class="button danger" data-action="delete-share">Delete this share</button> <span id="delete-status" role="status" aria-live="polite"></span></p>`:''}
    <details class="report"><summary>Report this share</summary>
      ${ctx.user?`<form id="report-form" class="report-form">
        <label for="report-reason">Reason</label>
        <select id="report-reason" name="reason">${Object.entries(ctx.reportReasons).map(([k,v])=>option(k,v,'')).join('')}</select>
        <label for="report-details">Details <span class="hint">(optional)</span></label>
        <textarea id="report-details" name="details" rows="3" maxlength="1000"></textarea>
        <p class="actions"><button type="submit" class="button">Send report</button> <span id="report-status" role="status" aria-live="polite"></span></p>
      </form>`:`<p><a href="/signin?next=${encodeURIComponent('/s/'+share.id)}">Sign in</a> to report a share.</p>`}
    </details>
  </section>
</article>`;
  return layout({...ctx,active:'browse',title:share.title,description:excerpt(share.description,200)||`${kindLabel(share.kind)} shared by ${share.owner.name}`,body,
    styles:['/viewer.css'],scripts:['/site/share-page.mjs'],meta:['<meta property="og:type" content="article">'],path:'/s/'+share.id});
}

export function viewerPage(ctx){
  const body=`<div id="viewer" class="viewer-host"><h1>Rotation Master</h1><p>The local reader requires JavaScript modules. No import is sent to a service.</p></div>`;
  return layout({...ctx,active:'viewer',title:'Viewer & compare',description:'Read or compare Rotation Master exports in your browser. Nothing is uploaded and no code is run.',body,styles:['/viewer.css'],scripts:['/viewer/app.mjs'],path:'/viewer'});
}

export function signInPage(ctx,{next}){
  const d=ctx.identity;
  const body=`
<div class="page-head"><h1>Sign in</h1></div>
${ctx.user?`<p>You are signed in as <strong>${h(ctx.user.name)}</strong> (<span class="user-id">${h(ctx.user.id)}</span>).</p>`:''}
${d.kind==='form'?`
<form id="signin-form" class="signin-form" data-next="${h(next)}">
  <aside class="callout callout-warning"><p><strong>Warning:</strong> this is a development sign-in. There is no password: anyone can use any name. A real account system is chosen before the site is published.</p></aside>
  <label for="signin-name">Display name</label>
  <input id="signin-name" name="displayName" minlength="2" maxlength="32" required autocomplete="nickname">
  <p class="hint">Shown on everything you share. Using the same name again signs you back in as the same user.</p>
  <p class="actions"><button type="submit" class="button primary">Sign in</button> <span id="signin-status" role="status" aria-live="polite"></span></p>
</form>`:`<p><a class="button primary" href="${h(d.startPath)}?next=${encodeURIComponent(next)}">${h(d.label)}</a></p>`}`;
  return layout({...ctx,title:'Sign in',body,scripts:['/site/signin.mjs'],path:next});
}

export function errorPage(ctx,status,message){
  const body=`<div class="page-head"><h1>${status===404?'Not found':'Something went wrong'}</h1></div><p>${h(message)}</p><p><a href="/">Home</a> · <a href="/help/">Help</a> · <a href="/shares">Browse shares</a></p>`;
  return layout({...ctx,title:status===404?'Not found':'Error',body});
}
