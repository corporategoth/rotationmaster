// Safe Markdown subset shared by the server (help pages, share descriptions)
// and the browser (live description preview). Raw HTML is never passed
// through: every character of input ends up as escaped text or as one of the
// fixed element types below. Links are limited to http(s) (and, for trusted
// help content, same-site relative paths). There are no images.
//
// Supported: ATX headings, paragraphs, emphasis/strong, inline code, fenced
// code (```lang), bullet and numbered lists (nested by indentation),
// blockquotes (a leading **Note:**/**Tip:**/**Warning:** makes a callout),
// pipe tables, horizontal rules, hard line breaks, links and bare URLs.

export const MARKDOWN_LIMITS=Object.freeze({input:200000,depth:8,inlineDepth:6,nodes:20000});

const blankRe=/^\s*$/;
const fenceRe=/^ {0,3}(`{3,}|~{3,})\s*([A-Za-z0-9_+-]*)\s*$/;
const headingRe=/^ {0,3}(#{1,6})[ \t]+(.*?)[ \t]*#*[ \t]*$/;
const hrRe=/^ {0,3}((\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$/;
const quoteRe=/^ {0,3}> ?(.*)$/;
const listRe=/^( *)([-*+]|\d{1,9}[.)])([ \t]+)(.*)$/;
const tableDelimRe=/^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$/;

function expandTabs(line){return line.replace(/\t/g,'    ');}
function indentOf(line){return line.match(/^ */)[0].length;}
function splitRow(line){
  let s=line.trim();if(s.startsWith('|'))s=s.slice(1);if(s.endsWith('|')&&!s.endsWith('\\|'))s=s.slice(0,-1);
  const cells=[];let cur='';
  for(let i=0;i<s.length;i++){if(s[i]==='\\'&&s[i+1]==='|'){cur+='|';i++;}else if(s[i]==='|'){cells.push(cur.trim());cur='';}else cur+=s[i];}
  cells.push(cur.trim());return cells;
}

function startsBlock(line){
  return fenceRe.test(line)||headingRe.test(line)||hrRe.test(line)||quoteRe.test(line)||listRe.test(line);
}

function parseBlocks(lines,depth,budget){
  const out=[];let i=0;
  while(i<lines.length){
    if(--budget.nodes<0)break;
    const line=lines[i];
    if(blankRe.test(line)){i++;continue;}
    let m;
    if((m=line.match(fenceRe))){
      const fence=m[1],lang=m[2]||'';const body=[];i++;
      const closes=l=>{const c=l.match(/^ {0,3}(`{3,}|~{3,})\s*$/);return c&&c[1][0]===fence[0]&&c[1].length>=fence.length;};
      while(i<lines.length&&!closes(lines[i]))body.push(lines[i++]);
      i++;out.push({type:'code',lang,text:body.join('\n')});continue;
    }
    if((m=line.match(headingRe))){out.push({type:'heading',level:m[1].length,text:m[2]});i++;continue;}
    if(hrRe.test(line)){out.push({type:'hr'});i++;continue;}
    if(quoteRe.test(line)){
      const body=[];
      while(i<lines.length&&!blankRe.test(lines[i])){const q=lines[i].match(quoteRe);body.push(q?q[1]:lines[i]);i++;}
      out.push({type:'quote',children:depth<MARKDOWN_LIMITS.depth?parseBlocks(body,depth+1,budget):[{type:'paragraph',text:body.join('\n')}]});continue;
    }
    if((m=line.match(listRe))){
      const ordered=/\d/.test(m[2]),base=m[1].length,start=ordered?parseInt(m[2],10):1;const items=[];let loose=false;
      while(i<lines.length){
        const lm=lines[i].match(listRe);
        if(!lm||lm[1].length!==base||/\d/.test(lm[2])!==ordered)break;
        const contentIndent=lm[1].length+lm[2].length+Math.min(lm[3].length,4);
        const body=[lm[4]];i++;let sawBlank=false;
        while(i<lines.length){
          const next=lines[i];
          if(blankRe.test(next)){sawBlank=true;body.push('');i++;continue;}
          const ind=indentOf(next);
          if(ind>=contentIndent||(ind>base&&listRe.test(next))){body.push(next.slice(Math.min(ind,contentIndent)));sawBlank=false;i++;continue;}
          if(!sawBlank&&!startsBlock(next)&&ind>base-1&&!listRe.test(next)){body.push(next.trim());i++;continue;}// lazy continuation
          break;
        }
        while(body.length&&body[body.length-1]==='')body.pop();
        if(body.includes(''))loose=true;
        items.push(depth<MARKDOWN_LIMITS.depth?parseBlocks(body,depth+1,budget):[{type:'paragraph',text:body.join(' ')}]);
        // A blank line between items makes the list loose.
        if(i<lines.length&&blankRe.test(lines[i-1]||'x')&&listRe.test(lines[i]||''))loose=true;
      }
      out.push({type:'list',ordered,start,loose,items});continue;
    }
    if(line.includes('|')&&i+1<lines.length&&tableDelimRe.test(lines[i+1])&&lines[i+1].includes('-')){
      const header=splitRow(line),align=splitRow(lines[i+1]).map(c=>c.startsWith(':')&&c.endsWith(':')?'center':c.endsWith(':')?'right':c.startsWith(':')?'left':null);
      i+=2;const rows=[];
      while(i<lines.length&&!blankRe.test(lines[i])&&lines[i].includes('|')){rows.push(splitRow(lines[i]));i++;}
      out.push({type:'table',header,align,rows});continue;
    }
    const para=[];
    while(i<lines.length&&!blankRe.test(lines[i])&&!(para.length&&startsBlock(lines[i]))){
      if(para.length&&lines[i].includes('|')&&i+1<lines.length&&tableDelimRe.test(lines[i+1]))break;
      para.push(lines[i]);i++;
    }
    out.push({type:'paragraph',text:para.join('\n')});
  }
  return out;
}

// ---- inline ----
const punct=/[!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]/;
function parseInline(text,depth,budget){
  const nodes=[];let buf='';
  const flush=()=>{if(buf){nodes.push({type:'text',value:buf});buf='';}};
  let i=0;
  while(i<text.length){
    if(--budget.nodes<0){buf+=text.slice(i);break;}
    const c=text[i];
    if(c==='\\'&&i+1<text.length){
      if(text[i+1]==='\n'){flush();nodes.push({type:'br'});i+=2;continue;}
      if(punct.test(text[i+1])){buf+=text[i+1];i+=2;continue;}
    }
    if(c==='\n'){
      if(/ {2,}$/.test(buf)){buf=buf.replace(/ +$/,'');flush();nodes.push({type:'br'});}else buf+='\n';
      i++;continue;
    }
    if(c==='`'){
      const run=text.slice(i).match(/^`+/)[0];const end=text.indexOf(run,i+run.length);
      if(end>0){flush();nodes.push({type:'code',value:text.slice(i+run.length,end).replace(/\n/g,' ').replace(/^ (.*) $/,'$1')});i=end+run.length;continue;}
      buf+=run;i+=run.length;continue;
    }
    if(c==='['&&depth<MARKDOWN_LIMITS.inlineDepth){
      const close=findClose(text,i);
      if(close>0&&text[close+1]==='('){
        let paren=-1;for(let j=close+2,d=0;j<text.length&&j<close+2050;j++){if(text[j]==='\n')break;if(text[j]==='(')d++;else if(text[j]===')'){if(d===0){paren=j;break;}d--;}}
        if(paren>0){
          const target=text.slice(close+2,paren).trim().match(/^<?([^\s>]*)>?(?:\s+"[^"]*")?$/);
          if(target){flush();nodes.push({type:'link',href:target[1],children:parseInline(text.slice(i+1,close),depth+1,budget)});i=paren+1;continue;}
        }
      }
    }
    if(c==='<'){
      const auto=text.slice(i).match(/^<(https?:\/\/[^\s<>]+)>/i);
      if(auto){flush();nodes.push({type:'link',href:auto[1],children:[{type:'text',value:auto[1]}]});i+=auto[0].length;continue;}
    }
    if((c==='h'||c==='H')&&(i===0||/[\s(]/.test(text[i-1]))){
      const bare=text.slice(i).match(/^https?:\/\/[^\s<>()]+/i);
      if(bare){let url=bare[0].replace(/[.,;:!?'"]+$/,'');flush();nodes.push({type:'link',href:url,children:[{type:'text',value:url}]});i+=url.length;continue;}
    }
    if((c==='*'||c==='_')&&depth<MARKDOWN_LIMITS.inlineDepth){
      const run=text.slice(i).match(c==='*'?/^\*+/:/^_+/)[0];
      const leftOk=i+run.length<text.length&&!/\s/.test(text[i+run.length]);
      const intraword=c==='_'&&i>0&&/\w/.test(text[i-1]);
      if(leftOk&&!intraword){
        const strong=run.length>=2,marker=strong?c+c:c;
        const end=findDelimiter(text,i+marker.length,marker,c);
        if(end>0){flush();nodes.push({type:strong?'strong':'em',children:parseInline(text.slice(i+marker.length,end),depth+1,budget)});i=end+marker.length;continue;}
      }
      buf+=run;i+=run.length;continue;
    }
    buf+=c;i++;
  }
  flush();return nodes;
}
function findClose(text,open){
  let depth=0;
  for(let i=open;i<text.length;i++){
    if(text[i]==='\\'){i++;continue;}
    if(text[i]==='`'){const e=text.indexOf('`',i+1);if(e<0)return -1;i=e;continue;}
    if(text[i]==='[')depth++;
    else if(text[i]===']'&&--depth===0)return i;
  }
  return -1;
}
function findDelimiter(text,from,marker,ch){
  for(let i=from;i<text.length;i++){
    if(text[i]==='\\'){i++;continue;}
    if(text[i]==='`'){const run=text.slice(i).match(/^`+/)[0];const e=text.indexOf(run,i+run.length);if(e>0){i=e+run.length-1;continue;}}
    if(text.startsWith(marker,i)&&i>from&&!/\s/.test(text[i-1])){
      // For single-character emphasis skip a doubled marker (that is strong).
      if(marker.length===1&&text[i+1]===ch){i++;continue;}
      if(ch==='_'&&i+marker.length<text.length&&/\w/.test(text[i+marker.length]))continue;
      return i;
    }
  }
  return -1;
}

/** Parse Markdown text into an inert AST of plain objects. */
export function parseMarkdown(source){
  const text=typeof source==='string'?source.slice(0,MARKDOWN_LIMITS.input):'';
  const lines=text.replace(/\r\n?/g,'\n').split('\n').map(expandTabs);
  const budget={nodes:MARKDOWN_LIMITS.nodes};
  const blocks=parseBlocks(lines,0,budget);
  const inline=list=>{for(const b of list){
    if(b.type==='paragraph'){b.children=parseInline(b.text,0,budget);delete b.text;}
    else if(b.type==='heading'){b.children=parseInline(b.text,0,budget);}
    else if(b.type==='quote')inline(b.children);
    else if(b.type==='list')for(const item of b.items)inline(item);
    else if(b.type==='table'){b.header=b.header.map(c=>parseInline(c,0,budget));b.rows=b.rows.map(r=>r.map(c=>parseInline(c,0,budget)));}
  }};
  inline(blocks);return blocks;
}

/** Return a safe href or null. Relative URLs only when allowRelative. */
export function safeHref(raw,{allowRelative=false}={}){
  if(typeof raw!=='string')return null;
  const url=raw.replace(/[\u0000- \u007f-\u009f]/g,'');
  if(!url||url.length>2048)return null;
  const scheme=url.match(/^([a-z][a-z0-9+.-]*):/i);
  if(scheme){
    const s=scheme[1].toLowerCase();
    if(s!=='http'&&s!=='https')return null;
    return /^https?:\/\/[^/]/i.test(url)?url:null;
  }
  if(!allowRelative)return null;
  if(url.startsWith('//'))return null;
  return /^(\/|#|\.\/|\.\.\/|[A-Za-z0-9_-])/.test(url)?url:null;
}

export function plainText(nodes){
  let out='';
  for(const n of nodes||[]){
    if(n.type==='text'||n.type==='code')out+=n.value;
    else if(n.type==='br')out+=' ';
    else if(n.children)out+=plainText(n.children);
  }
  return out;
}
export function slugify(text){
  return String(text).toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,64)||'section';
}
/** First-level outline of a parsed document: [{level,text,id}]. */
export function outline(ast,{idPrefix=''}={}){
  const seen=new Map(),rows=[];
  for(const b of ast)if(b.type==='heading'){
    const text=plainText(b.children);let id=idPrefix+slugify(text);
    const n=seen.get(id)||0;seen.set(id,n+1);if(n)id+='-'+(n+1);
    rows.push({level:b.level,text,id});
  }
  return rows;
}
/** Short plain-text excerpt for listings. */
export function excerpt(source,limit=200){
  const ast=parseMarkdown(typeof source==='string'?source.slice(0,limit*8):'');
  let out='';
  const walk=list=>{for(const b of list){
    if(out.length>=limit)return;
    if(b.type==='paragraph'||b.type==='heading')out+=(out?' ':'')+plainText(b.children);
    else if(b.type==='quote')walk(b.children);
    else if(b.type==='list')for(const item of b.items)walk(item);
  }};
  walk(ast);out=out.replace(/\s+/g,' ').trim();
  return out.length>limit?out.slice(0,limit-1).replace(/\s+\S*$/,'')+'…':out;
}

const callout=/^(note|tip|warning|important)[:.]?$/i;
function calloutKind(block){
  const first=block.children?.[0];
  if(first?.type!=='paragraph')return null;
  const lead=first.children?.[0];
  if(lead?.type!=='strong')return null;
  const m=plainText(lead.children).trim().match(callout);
  return m?m[1].toLowerCase():null;
}

// ---- HTML string output ----
const escapeMap={'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'};
export function escapeHTML(value){return String(value).replace(/[&<>"']/g,c=>escapeMap[c]);}

/**
 * Render a parsed document to an HTML string. Options:
 *  headingOffset: add to heading levels (user content uses 2: # -> h3)
 *  allowRelative: permit same-site relative links (trusted help only)
 *  idPrefix: prefix for heading ids; headingIds=false to omit them
 *  externalRel: rel attribute for absolute links
 */
export function toHTML(ast,{headingOffset=0,allowRelative=false,idPrefix='',headingIds=true,externalRel='nofollow ugc noopener noreferrer'}={}){
  const ids=outline(ast,{idPrefix});let headingIndex=0;
  const inline=nodes=>nodes.map(n=>{
    switch(n.type){
      case 'text':return escapeHTML(n.value);
      case 'code':return '<code>'+escapeHTML(n.value)+'</code>';
      case 'br':return '<br>';
      case 'em':return '<em>'+inline(n.children)+'</em>';
      case 'strong':return '<strong>'+inline(n.children)+'</strong>';
      case 'link':{
        const href=safeHref(n.href,{allowRelative});
        if(!href)return inline(n.children);
        const external=/^https?:/i.test(href);
        return '<a href="'+escapeHTML(href)+'"'+(external?' rel="'+escapeHTML(externalRel)+'"':'')+'>'+inline(n.children)+'</a>';
      }
      default:return '';
    }
  }).join('');
  const block=list=>list.map(b=>{
    switch(b.type){
      case 'heading':{
        const level=Math.min(6,b.level+headingOffset),id=ids[headingIndex++]?.id;
        return '<h'+level+(headingIds&&id?' id="'+escapeHTML(id)+'"':'')+'>'+inline(b.children)+'</h'+level+'>';
      }
      case 'paragraph':return '<p>'+inline(b.children)+'</p>';
      case 'code':{
        if(b.lang==='diagram')return '<figure class="diagram"><pre>'+escapeHTML(b.text)+'</pre></figure>';
        return '<pre'+(b.lang?' data-lang="'+escapeHTML(b.lang)+'"':'')+'><code>'+escapeHTML(b.text)+'</code></pre>';
      }
      case 'hr':return '<hr>';
      case 'quote':{const kind=calloutKind(b);return kind?'<aside class="callout callout-'+kind+'">'+block(b.children)+'</aside>':'<blockquote>'+block(b.children)+'</blockquote>';}
      case 'list':{
        const tag=b.ordered?'ol':'ul',start=b.ordered&&b.start!==1?' start="'+b.start+'"':'';
        return '<'+tag+start+'>'+b.items.map(item=>'<li>'+(!b.loose&&item.length===1&&item[0].type==='paragraph'?inline(item[0].children):!b.loose&&item[0]?.type==='paragraph'?inline(item[0].children)+block(item.slice(1)):block(item))+'</li>').join('')+'</'+tag+'>';
      }
      case 'table':{
        const cell=(tag,content,i)=>'<'+tag+(b.align[i]?' class="align-'+b.align[i]+'"':'')+'>'+inline(content)+'</'+tag+'>';
        return '<div class="table-wrap"><table><thead><tr>'+b.header.map((c,i)=>cell('th',c,i)).join('')+'</tr></thead><tbody>'+
          b.rows.map(r=>'<tr>'+b.header.map((_,i)=>cell('td',r[i]||[],i)).join('')+'</tr>').join('')+'</tbody></table></div>';
      }
      default:return '';
    }
  }).join('\n');
  return block(ast);
}
export function renderMarkdownHTML(source,options){return toHTML(parseMarkdown(source),options);}

// ---- DOM output (browser preview); never touches innerHTML ----
export function renderMarkdownDOM(document,parent,source,{headingOffset=2,allowRelative=false,externalRel='nofollow ugc noopener noreferrer'}={}){
  const ast=parseMarkdown(source);
  const el=(tag,cls)=>{const e=document.createElement(tag);if(cls)e.setAttribute('class',cls);return e;};
  const inline=(target,nodes)=>{for(const n of nodes){
    if(n.type==='text')target.append(document.createTextNode(n.value));
    else if(n.type==='code'){const c=el('code');c.textContent=n.value;target.append(c);}
    else if(n.type==='br')target.append(el('br'));
    else if(n.type==='em'||n.type==='strong'){const e=el(n.type);inline(e,n.children);target.append(e);}
    else if(n.type==='link'){
      const href=safeHref(n.href,{allowRelative});
      if(!href){inline(target,n.children);continue;}
      const a=el('a');a.setAttribute('href',href);if(/^https?:/i.test(href))a.setAttribute('rel',externalRel);inline(a,n.children);target.append(a);
    }
  }};
  const block=(target,list)=>{for(const b of list){
    if(b.type==='heading'){const h=el('h'+Math.min(6,b.level+headingOffset));inline(h,b.children);target.append(h);}
    else if(b.type==='paragraph'){const p=el('p');inline(p,b.children);target.append(p);}
    else if(b.type==='code'){const pre=el('pre');const code=el('code');code.textContent=b.text;pre.append(code);target.append(pre);}
    else if(b.type==='hr')target.append(el('hr'));
    else if(b.type==='quote'){const kind=calloutKind(b);const q=kind?el('aside','callout callout-'+kind):el('blockquote');block(q,b.children);target.append(q);}
    else if(b.type==='list'){
      const l=el(b.ordered?'ol':'ul');if(b.ordered&&b.start!==1)l.setAttribute('start',String(b.start));
      for(const item of b.items){const li=el('li');if(!b.loose&&item[0]?.type==='paragraph'){inline(li,item[0].children);block(li,item.slice(1));}else block(li,item);l.append(li);}
      target.append(l);
    }else if(b.type==='table'){
      const wrap=el('div','table-wrap'),t=el('table'),head=el('thead'),hr=el('tr'),body=el('tbody');
      b.header.forEach((c,i)=>{const th=el('th',b.align[i]?'align-'+b.align[i]:null);inline(th,c);hr.append(th);});
      head.append(hr);for(const r of b.rows){const tr=el('tr');b.header.forEach((_,i)=>{const td=el('td',b.align[i]?'align-'+b.align[i]:null);inline(td,r[i]||[]);tr.append(td);});body.append(tr);}
      t.append(head,body);wrap.append(t);target.append(wrap);
    }
  }};
  block(parent,ast);
  return parent;
}
