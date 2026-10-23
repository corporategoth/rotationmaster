// SQLite implementation of the share store, using Node's built-in node:sqlite
// (no npm dependency). See ./store.mjs for the interface every store must
// provide; tests/web_site_api.mjs exercises it through the HTTP API.
import {DatabaseSync} from 'node:sqlite';
import {randomBytes} from 'node:crypto';
import {mkdirSync} from 'node:fs';
import {dirname} from 'node:path';

const SCHEMA_VERSION=1;
const ID_ALPHABET='23456789abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';

export function newShareId(length=10){
  const bytes=randomBytes(length*2);let out='';
  for(let i=0;i<bytes.length&&out.length<length;i++){const b=bytes[i];if(b<ID_ALPHABET.length*4)out+=ID_ALPHABET[b%ID_ALPHABET.length];}
  return out.length===length?out:newShareId(length);
}
const likeEscape=s=>s.replace(/[\\%_]/g,c=>'\\'+c);

function rowToShare(row,{withExport=false}={}){
  if(!row)return null;
  const share={id:row.id,title:row.title,description:row.description,kind:row.kind,format:row.format,name:row.name,
    class:row.class_tag,classSource:row.class_source,editions:row.editions?row.editions.split(',').filter(Boolean):[],editionSource:row.edition_source,
    owner:{id:row.owner_id,name:row.owner_name},bytes:row.bytes,sha256:row.sha256,
    createdAt:row.created_at,hidden:!!row.hidden,reportCount:row.report_count,summary:JSON.parse(row.summary_json||'{}')};
  if(withExport)share.export=row.export_text;
  return share;
}

export function openSqliteStore(path=':memory:'){
  if(path!==':memory:')mkdirSync(dirname(path),{recursive:true});
  const db=new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys=ON');
  if(path!==':memory:')db.exec('PRAGMA journal_mode=WAL');
  db.exec(`CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS users(
      id TEXT PRIMARY KEY,display_name TEXT NOT NULL,provider TEXT NOT NULL,
      created_at TEXT NOT NULL,last_seen_at TEXT NOT NULL,banned INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS shares(
      id TEXT PRIMARY KEY,owner_id TEXT NOT NULL REFERENCES users(id),owner_name TEXT NOT NULL,
      title TEXT NOT NULL,description TEXT NOT NULL,kind TEXT NOT NULL,format TEXT,name TEXT NOT NULL,
      class_tag TEXT,class_source TEXT,editions TEXT NOT NULL,edition_source TEXT,
      export_text TEXT NOT NULL,sha256 TEXT NOT NULL,bytes INTEGER NOT NULL,summary_json TEXT NOT NULL,
      created_at TEXT NOT NULL,hidden INTEGER NOT NULL DEFAULT 0,report_count INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS shares_created ON shares(created_at DESC);
    CREATE INDEX IF NOT EXISTS shares_owner ON shares(owner_id);
    CREATE UNIQUE INDEX IF NOT EXISTS shares_owner_export ON shares(owner_id,sha256);
    CREATE TABLE IF NOT EXISTS reports(
      id INTEGER PRIMARY KEY AUTOINCREMENT,share_id TEXT NOT NULL REFERENCES shares(id) ON DELETE CASCADE,
      reporter_id TEXT NOT NULL,reason TEXT NOT NULL,details TEXT NOT NULL,created_at TEXT NOT NULL,
      resolved INTEGER NOT NULL DEFAULT 0,UNIQUE(share_id,reporter_id));`);
  const version=db.prepare('SELECT value FROM meta WHERE key=?').get('schema');
  if(!version)db.prepare('INSERT INTO meta(key,value) VALUES(?,?)').run('schema',String(SCHEMA_VERSION));
  else if(Number(version.value)!==SCHEMA_VERSION)throw Error('unsupported-store-schema '+version.value);

  const now=()=>new Date().toISOString();
  const q={
    upsertUser:db.prepare(`INSERT INTO users(id,display_name,provider,created_at,last_seen_at) VALUES(?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET display_name=excluded.display_name,last_seen_at=excluded.last_seen_at`),
    getUser:db.prepare('SELECT * FROM users WHERE id=?'),
    insertShare:db.prepare(`INSERT INTO shares(id,owner_id,owner_name,title,description,kind,format,name,class_tag,class_source,editions,edition_source,
      export_text,sha256,bytes,summary_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`),
    getShare:db.prepare('SELECT * FROM shares WHERE id=?'),
    findDuplicate:db.prepare('SELECT id FROM shares WHERE owner_id=? AND sha256=?'),
    deleteShare:db.prepare('DELETE FROM shares WHERE id=?'),
    setHidden:db.prepare('UPDATE shares SET hidden=? WHERE id=?'),
    setBanned:db.prepare('UPDATE users SET banned=? WHERE id=?'),
    insertReport:db.prepare('INSERT OR IGNORE INTO reports(share_id,reporter_id,reason,details,created_at) VALUES(?,?,?,?,?)'),
    countReports:db.prepare('SELECT COUNT(*) AS n FROM reports WHERE share_id=? AND resolved=0'),
    setReportCount:db.prepare('UPDATE shares SET report_count=? WHERE id=?'),
    resolveReports:db.prepare('UPDATE reports SET resolved=1 WHERE share_id=?'),
  };
  return {
    kind:'sqlite',
    upsertUser({id,name,provider}){const t=now();q.upsertUser.run(id,name,provider,t,t);return this.getUser(id);},
    getUser(id){const r=q.getUser.get(id);return r?{id:r.id,name:r.display_name,provider:r.provider,banned:!!r.banned,createdAt:r.created_at}:null;},
    setBanned(id,banned){return q.setBanned.run(banned?1:0,id).changes>0;},
    findDuplicate(ownerId,sha256){return q.findDuplicate.get(ownerId,sha256)?.id||null;},
    createShare(owner,v){
      for(let attempt=0;attempt<5;attempt++){
        const id=newShareId();
        try{
          q.insertShare.run(id,owner.id,owner.name,v.title,v.description,v.kind,v.format,v.name||'',v.cls,v.classSource,
            ','+v.editions.join(',')+',',v.editionSource,v.export,v.sha256,v.bytes,JSON.stringify(v.summary),now());
          return id;
        }catch(error){if(!/UNIQUE constraint failed: shares\.id/.test(error.message))throw error;}
      }
      throw Error('share-id-exhausted');
    },
    getShare(id,{includeHidden=false,withExport=true}={}){
      const row=q.getShare.get(String(id));
      if(!row||(row.hidden&&!includeHidden))return null;
      return rowToShare(row,{withExport});
    },
    listShares({q:text='',kind=null,cls=null,edition=null,owner=null,limit=24,offset=0,includeHidden=false}={}){
      const where=[],args=[];
      if(!includeHidden)where.push('hidden=0');
      if(kind){where.push('kind=?');args.push(kind);}
      if(cls){where.push(cls==='ANY'?"class_tag='ANY'":'(class_tag=? OR class_tag=\'ANY\')');if(cls!=='ANY')args.push(cls);}
      if(edition){where.push("editions LIKE ? ESCAPE '\\'");args.push('%,'+likeEscape(edition)+',%');}
      if(owner){where.push('owner_id=?');args.push(owner);}
      for(const word of String(text).split(/\s+/).filter(Boolean).slice(0,8)){
        where.push("(title LIKE ? ESCAPE '\\' OR description LIKE ? ESCAPE '\\' OR name LIKE ? ESCAPE '\\' OR owner_name LIKE ? ESCAPE '\\')");
        const like='%'+likeEscape(word)+'%';args.push(like,like,like,like);
      }
      const clause=where.length?' WHERE '+where.join(' AND '):'';
      const total=db.prepare('SELECT COUNT(*) AS n FROM shares'+clause).get(...args).n;
      const rows=db.prepare('SELECT * FROM shares'+clause+' ORDER BY created_at DESC, id LIMIT ? OFFSET ?').all(...args,limit,offset);
      return {total,items:rows.map(r=>rowToShare(r))};
    },
    deleteShare(id){return q.deleteShare.run(String(id)).changes>0;},
    setHidden(id,hidden){return q.setHidden.run(hidden?1:0,String(id)).changes>0;},
    addReport(shareId,reporterId,{reason,details}){
      const created=q.insertReport.run(shareId,reporterId,reason,details,now()).changes>0;
      const count=q.countReports.get(shareId).n;q.setReportCount.run(count,shareId);
      return {created,count};
    },
    listReports({open=true}={}){
      return db.prepare(`SELECT r.*,s.title,s.owner_id,s.hidden FROM reports r JOIN shares s ON s.id=r.share_id${open?' WHERE r.resolved=0':''} ORDER BY r.created_at`).all()
        .map(r=>({id:r.id,shareId:r.share_id,title:r.title,ownerId:r.owner_id,hidden:!!r.hidden,reporterId:r.reporter_id,reason:r.reason,details:r.details,createdAt:r.created_at,resolved:!!r.resolved}));
    },
    resolveReports(shareId){const n=q.resolveReports.run(shareId).changes;q.setReportCount.run(0,shareId);return n;},
    close(){db.close();},
  };
}
