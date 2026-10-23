// Website content and browser modules: safe Markdown, export classification,
// import warnings, the full decoded tree, help pages and static safety rules.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,statSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {parseMarkdown,renderMarkdownHTML,renderMarkdownDOM,safeHref,outline,excerpt} from '../Web/site/markdown.mjs';
import {classifyExport,luaText} from '../Web/site/kinds.mjs';
import {scanExport,RISK_TEXT,RISK_ORDER} from '../Web/site/risks.mjs';
import {createTreeRenderer} from '../Web/site/tree-render.mjs';
import {decodeImport} from '../Web/codec/import.mjs';
import {encodeExport} from '../Web/codec/export.mjs';

const root=new URL('..',import.meta.url);
const read=path=>readFileSync(new URL(path,root),'utf8');
const m=(...e)=>new Map(e),list=(...v)=>new Map(v.map((x,i)=>[i+1,x]));
const roundtrip=value=>{const r=encodeExport(value);assert.equal(r.ok,true);const d=decodeImport(r.text);assert.equal(d.ok,true);return d.value;};
const names=JSON.parse(read('Web/site/conditions.json'));
const known=new Set(Object.keys(names.conditions));

// Minimal DOM: enough for createElement/textContent/append, and it records
// every element and attribute created so tests can check what was produced.
function fakeDocument(){
  const created=[];
  class Node{
    constructor(tag,text){this.tagName=tag;this.childNodes=[];this.attributes=new Map();this._text=text??'';this.open=false;if(tag)created.push(this);}
    setAttribute(k,v){this.attributes.set(k,String(v));}
    getAttribute(k){return this.attributes.get(k)??null;}
    append(...nodes){for(const n of nodes)this.childNodes.push(typeof n==='string'?new Node(null,n):n);}
    prepend(...nodes){this.childNodes.unshift(...nodes);}
    replaceChildren(...nodes){this.childNodes=[];this.append(...nodes);}
    set textContent(v){this.childNodes=[];this._text=String(v);}
    get textContent(){return this.tagName?this._text+this.childNodes.map(c=>c.textContent).join(''):this._text;}
    set innerHTML(_){throw Error('innerHTML must never be used');}
  }
  return {created,createElement:tag=>new Node(tag),createTextNode:text=>new Node(null,text)};
}

test('Markdown keeps raw HTML as text and only emits safe elements and links',()=>{
  const hostile=['<script>alert(1)</script>','<img src=x onerror=alert(1)>','<a href="javascript:alert(1)">x</a>','[x](javascript:alert(1))','[x](JaVaScRiPt:alert(1))',
    '[x](data:text/html,<b>)','[x](vbscript:msgbox)','[x]( java\tscript:alert(1))','<iframe src=//evil>','<svg onload=alert(1)>','[x](//evil.example/path)','<style>*{}</style>','"><b>'].join('\n\n');
  const html=renderMarkdownHTML(hostile);
  assert.doesNotMatch(html,/<(script|img|iframe|svg|style|b)\b|href="(javascript|data|vbscript|\/\/)/i);
  const tags=new Set([...html.matchAll(/<([a-z0-9]+)/gi)].map(x=>x[1].toLowerCase()));
  for(const t of tags)assert.ok(['p','a','code','pre','em','strong','ul','ol','li','h1','h2','h3','h4','h5','h6','blockquote','aside','hr','br','table','thead','tbody','tr','th','td','div','figure'].includes(t),t);
  for(const url of ['javascript:x','JAVASCRIPT:x','data:x','vbscript:x','//evil','file:///etc','mailto:a@b'])assert.equal(safeHref(url),null,url);
  assert.equal(safeHref('/help/x'),null,'relative links are refused for user content');
  assert.equal(safeHref('/help/x',{allowRelative:true}),'/help/x');
  assert.equal(safeHref('https://example.com/a?b=1'),'https://example.com/a?b=1');
  const user=renderMarkdownHTML('# Big\n\n**b** _i_ `<c>` [ok](https://e.example) https://bare.example/x.\n\n- a\n  - b\n\n1. one\n2. two\n\n> **Tip:** hi\n\n| a | b |\n|---|--:|\n| 1 | 2 |\n\n```\n<pre>\n```',{headingOffset:2});
  assert.match(user,/<h3[^>]*>Big<\/h3>/);
  assert.match(user,/<code>&lt;c&gt;<\/code>/);
  assert.match(user,/<a href="https:\/\/e\.example" rel="nofollow ugc noopener noreferrer">ok<\/a>/);
  assert.match(user,/<a href="https:\/\/bare\.example\/x" rel="nofollow ugc noopener noreferrer">https:\/\/bare\.example\/x<\/a>\./);
  assert.match(user,/<ul><li>a<ul><li>b<\/li><\/ul><\/li><\/ul>/);
  assert.match(user,/<aside class="callout callout-tip">/);
  assert.match(user,/<th class="align-right">b<\/th>/);
  assert.match(user,/<pre><code>&lt;pre&gt;<\/code><\/pre>/);
  assert.equal(excerpt('# T\n\nSome **bold** text <b>x</b>',100),'T Some bold text <b>x</b>');
  // Deep nesting and huge input stay bounded.
  assert.doesNotThrow(()=>renderMarkdownHTML('>'.repeat(5000)+' x\n'+'- '.repeat(5000)+'y\n'+'*'.repeat(10000)+'['.repeat(10000)));
});

test('Markdown DOM output never uses innerHTML and only creates allowed elements',()=>{
  const doc=fakeDocument(),parent=doc.createElement('div');
  renderMarkdownDOM(doc,parent,'<script>x</script> **b** [x](javascript:1) [y](https://y.example)\n\n```\ncode\n```');
  const tags=new Set(doc.created.map(n=>n.tagName));
  for(const t of tags)assert.ok(['div','p','strong','a','pre','code'].includes(t),t);
  const links=doc.created.filter(n=>n.tagName==='a');
  assert.deepEqual(links.map(a=>a.getAttribute('href')),['https://y.example']);
  assert.match(parent.textContent,/<script>x<\/script>/,'raw HTML is plain text');
});

test('every export kind is classified from its envelope; unknown data is refused',()=>{
  const goldens=JSON.parse(read('tests/fixtures/web_codec.json')).goldens;
  const env=classifyExport(decodeImport(goldens.find(g=>g.id.startsWith('current-reviewed')).text).value);
  assert.equal(env.kind,'rotation');assert.equal(env.declared.class,'SHAMAN');assert.deepEqual(env.declared.editions,['tbc']);
  assert.equal(env.summary.nameKey,'Default.TBC.Shaman.Starter.Name');
  assert.equal(classifyExport(decodeImport(goldens[0].text).value).kind,'rotation');
  const cases=[
    [m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','function'],['id','x.y'],['name','y'],['source',m(['code','return 1'])])],['dependencies',new Map()],['requirements',new Map()]),'function'],
    [m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','condition'],['id','C'],['name','C'],['source',m(['evaluate','return true'])])],['dependencies',new Map()],['requirements',new Map()]),'condition'],
    [m(['format','RM-CustomCondition'],['version',1],['name','LEGACY'],['condition',m(['evaluate','return 1'])]),'condition'],
    [m(['format','RM-CustomFunction'],['version',1],['name','f'],['source',m(['code','return 1'])]),'function'],
    [m(['format','RM-ConditionCategory'],['version',1],['name','c'],['conditions',list('BUFF')]),'condition-category'],
    [m(['format','RM-ItemSet'],['version',1],['name','i'],['items',list(1,'Linen Bandage')]),'item-set'],
    [m(['name','e'],['type','pixel']),'effect'],
    [m(['format','RM-Announcement'],['version',1],['announcement',m(['type','spell'],['announce','local'])]),'announcement'],
    [m(['format','RM-Profile'],['version',1],['name','p'],['profile',m(['poll',1])]),'profile'],
  ];
  for(const [value,kind] of cases){const r=classifyExport(roundtrip(value));assert.equal(r.ok,true,kind+' '+r.reason);assert.equal(r.kind,kind);}
  for(const bad of [m(['x',1]),m(['format','RM-ItemSet'],['version',2],['name','i'],['items',list(1)]),m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','shell'])]),
    m(['format','RM-Announcement'],['version',2],['announcement',m(['type','spell'])]),m(['name','e'],['type','laser'])])
    assert.equal(classifyExport(bad).ok,false);
  // Byte strings are decoded as UTF-8 for display, with control characters and WoW colour codes removed.
  assert.equal(luaText(Buffer.from('Héllo|cff00ff00 green|r\u0007','utf8').toString('latin1')),'Héllo green');
});

test('import warnings flag Lua, chat output to other players, macro triggers, profiles, custom conditions and unknown content',()=>{
  const scan=value=>{const v=roundtrip(value);return scanExport(v,classifyExport(v),{knownConditions:known});};
  const codes=risks=>risks.map(r=>r.code);
  assert.deepEqual(codes(scan(m(['format','RM-FunctionBundle'],['version',1],['root',m(['kind','condition'],['id','C'],['name','C'],['source',m(['evaluate','return true'],['on_register','x()'])])],['dependencies',new Map()],['requirements',new Map()]))),['lua-code','lua-on-register']);
  const rotation=m(['rotation',list(
      m(['type','spell'],['action',1],['conditions',m(['type','AND'],['value',list(m(['type','BUFF'],['unit','player']),m(['type','NOT'],['value',m(['type','MY_CUSTOM'])]))])]),
      m(['type','branch'],['conditions',m(['type','COMBAT'])],['onTrue',list(m(['type','teleport']))],['onFalse',list(m(['type','none']))]))],
    ['cooldowns',list(m(['type','spell'],['action',2],['announce','raidwarn']),m(['type','spell'],['action',3],['announce','local']))]);
  const r=scan(rotation);
  assert.deepEqual(codes(r),['chat-output','needs-custom-conditions','unrecognized']);
  assert.deepEqual(r.find(x=>x.code==='needs-custom-conditions').where,['MY_CUSTOM']);
  assert.match(r.find(x=>x.code==='unrecognized').where[0],/True arm step 1: step type teleport/);
  assert.match(r.find(x=>x.code==='chat-output').where[0],/cooldown step 1 → raid warnings/);
  const ann=scan(m(['format','RM-Announcement'],['version',2],['announcement',m(['type','macro'],['identifier','X'],['outputs',list(m(['announce','whisper']),m(['announce','audible']),m(['announce','pigeon']))])]));
  assert.deepEqual(codes(ann),['chat-output','macro-trigger','unrecognized']);
  assert.deepEqual(codes(scan(m(['format','RM-Announcement'],['version',1],['announcement',m(['type','spell'],['announce','local'])]))),[],'local output is not a warning');
  const body=m(['rotation',list(m(['type','spell'],['announce','yell']))]);
  const store=m(['class',m(['WARRIOR',m(['x',body])])]);
  const profile=scan(m(['format','RM-Profile'],['version',1],['name','p'],['profile',m(['rotationStore',store])]));
  assert.deepEqual(codes(profile),['chat-output','replaces-profile']);
  assert.deepEqual(codes(scan(m(['name','e'],['type','pixel']))),[]);
  // Every risk has player-facing text, in display order.
  for(const code of RISK_ORDER)assert.ok(RISK_TEXT[code]?.title&&RISK_TEXT[code].detail&&['danger','caution','info'].includes(RISK_TEXT[code].level),code);
});

test('the full tree shows every step, branch arm, cooldown and nested condition field',()=>{
  const doc=fakeDocument(),parent=doc.createElement('div');
  const body=roundtrip(m(['name','Full'],['switch',m(['type','OR'],['value',list(m(['type','GROUP'],['value','raid']))])],
    ['rotation',list(
      m(['id','a'],['type','spell'],['action',133],['name','Fireball'],['conditions',m(['type','AND'],['value',list(m(['type','BUFF'],['unit','player'],['spell',12536],['anyrank',true]),m(['type','NOT'],['value',m(['type','MY_CUSTOM'],['threshold',0.5])]))])]),
      m(['id','b'],['type','branch'],['mode','false'],['conditions',m(['type','MOVING'],['unit','player'])],
        ['onTrue',list(m(['id','c'],['type','none'],['suppress_attack',true]))],
        ['onFalse',list(m(['id','d'],['type','item'],['action',list(5512,19004)]),m(['id','e'],['type','branch'],['onTrue',list(m(['id','f'],['type','any'],['action',99]))],['onFalse',new Map()]))]))],
    ['cooldowns',list(m(['id','g'],['type','spell'],['action',12042],['announce','partyraid'],['magnification',1.5],['color',m(['r',1],['g',0.5],['b',0],['a',1])]))]));
  createTreeRenderer(doc,{conditionNames:names}).rotation(parent,body);
  const text=parent.textContent;
  for(const expected of ['Spell #133','Fireball','All of','Buff Present','BUFF','12536','anyrank','yes','Not','Custom or unknown condition','MY_CUSTOM','threshold','0.5',
    'Branch · Always false','Moving','Stop, and suppress implicit Attack','True arm (unreachable)','False arm','Item from list: #5512, #19004','Any spell #99',
    'Cooldowns (1)','Spell #12042','announces to raid or party chat','magnification','1.5','Any of','In Group','raid'])
    assert.ok(text.includes(expected),'missing: '+expected);
  assert.ok(!doc.created.some(n=>n.tagName==='script'));
});

test('help pages exist, link only to real pages and anchors, and cover every condition type',()=>{
  const manifest=JSON.parse(read('Web/site/help/index.json'));
  const slugs=new Set(manifest.pages.map(p=>p.slug));
  const anchors=new Map();
  for(const page of manifest.pages){
    let src=read('Web/site/help/'+page.slug+'.md');
    assert.ok(src.startsWith('# '),page.slug+' starts with a title');
    anchors.set(page.slug,new Set(outline(parseMarkdown(src)).map(o=>o.id)));
    assert.ok(manifest.sections.some(s=>s.id===page.section),page.slug);
  }
  for(const page of manifest.pages){
    const src=read('Web/site/help/'+page.slug+'.md');
    for(const [,href] of src.matchAll(/\]\((\/[^)\s]*)\)/g)){
      const [path,hash]=href.split('#');
      if(path.startsWith('/help/')){
        const slug=path.slice(6)||'index';
        assert.ok(slugs.has(slug),`${page.slug}: link to missing page ${href}`);
        if(hash&&!(page.generated&&slug===page.slug))assert.ok(anchors.get(slug).has(hash),`${page.slug}: link to missing anchor ${href}`);
      }else assert.ok(['/shares','/shares/new','/viewer'].includes(path),`${page.slug}: unknown site link ${href}`);
    }
  }
  const catalog=JSON.parse(read('Web/schema/catalog.json'));
  const grouped=new Set(names.groups.flatMap(g=>g.conditions));
  for(const c of catalog.conditions){assert.ok(names.conditions[c.id]?.name,c.id);assert.ok(grouped.has(c.id),c.id);}
  // The generated names file is current with the addon sources.
  execFileSync('python3',['tools/export_web_conditions.py','--check'],{cwd:root,encoding:'utf8'});
  // Slash commands documented match the in-game /rm help list.
  const help=read('Web/site/help/slash-commands.md'),main=read('main.lua');
  for(const [,cmd] of main.matchAll(/L\[["']\/rm (\w+)/g))assert.ok(help.includes('/rm '+cmd),'/rm '+cmd+' is documented');
});

test('site and server code never evaluate data or write HTML strings into the DOM',()=>{
  const files=[];
  const walk=dir=>{for(const name of readdirSync(new URL(dir,root))){const path=dir+name;if(statSync(new URL(path,root)).isDirectory())walk(path+'/');else if(/\.(m?js)$/.test(name))files.push(path);}};
  walk('Web/site/');walk('Web/server/');
  assert.ok(files.length>10);
  for(const file of files){
    const src=read(file);
    assert.doesNotMatch(src,/\beval\s*\(|new\s+Function\s*\(|\.innerHTML\b|\.outerHTML\b|insertAdjacentHTML|document\.write|setTimeout\s*\(\s*['"`]/,file);
    assert.doesNotMatch(src,/from\s+['"]node:(vm|child_process|worker_threads)['"]/,file);
  }
});
