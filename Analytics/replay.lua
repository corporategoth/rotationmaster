-- Pure v1 replay of validated normalized evidence. No native capture or API calls.
-- Exact selected-spell agreement is not native adherence/visibility certification.
-- Caller supplies TBC/player evidence; aliases are local numeric keys, never GUIDs.
local _,addon=...
local type,pairs,rawget,getmetatable=type,pairs,rawget,getmetatable
local huge,max=math.huge,math.max
local LIMIT_RECORDS,LIMIT_CASTS,LIMIT_PENDING,LIMIT_BYTES=4096,1024,128,524288
local function finite(v)return type(v)=='number'and v==v and v~=huge and v~=-huge end
local function integer(v,minimum)return finite(v)and v>=minimum and v<=2147483647 and v%1==0 end
local function plain(v)return type(v)=='table'and getmetatable(v)==nil end
local function member(v,set)return type(v)=='string'and set[v]==true end
local actors={player=true,pet=true,other=true,unknown=true}
local kinds={ordinary=true,channel=true,autorepeat=true,unmodeled=true}
local actions={spell=true,unmodeled=true,none=true,unknown=true}
local states={visible=true,hidden=true,unknown=true}
local retires={context=true,disabled=true,error=true,stop=true,['end']=true,unknown=true}
local statuses={success=true,failed=true,interrupted=true,stop=true}
local subtypes={swing=true,range=true,spell=true,periodic=true,unmodeled=true}
local coverageStates={available=true,unavailable=true}
local headerKeys={format=true,model=true,family=true,actor=true,duration=true,records=true}
local fields={
 advice={epoch=true,action=true,spell=true,validUntil=true},presentation={adviceSeq=true,state=true},retire={reason=true},
 attempt={cast=true,actor=true,castKind=true,spell=true,epoch=true,phase=true},
 result={cast=true,actor=true,castKind=true,spell=true,status=true},
 damage={actor=true,subtype=true,known=true,amount=true,overkill=true},damageCoverage={state=true},
}
-- Deterministic normalized payload charge, not a Lua heap or wire-size claim.
local function charge(v)local t=type(v);if t=='string'then return 2+#v elseif t=='number'then return 8 elseif t=='boolean'then return 1 end;return 2 end
local function keys(value,allowed,common)
 local bytes=2
 for k,v in pairs(value)do
  if type(k)~='string'or not(allowed[k]or common and(k=='type'or k=='seq'or k=='time'))then return nil,'unknown-field'end
  bytes=bytes+2+#k+charge(v)
 end
 return bytes
end
local function validate(trace)
 if not plain(trace)then return nil,'unsafe-table'end
 local bytes,why=keys(trace,headerKeys);if not bytes then return nil,why end
 if trace.format~=1 or trace.model~=1 or trace.family~='tbc'or trace.actor~='player'or not finite(trace.duration)or trace.duration<0 or trace.duration>600 then return nil,'invalid-header'end
 local rows=trace.records;if not plain(rows)then return nil,'unsafe-table'end
 local count,largest=0,0
 for k in pairs(rows)do
  if not integer(k,1)then return nil,'dense-records-required'end
  count=count+1;largest=max(largest,k);if count>LIMIT_RECORDS then return nil,'record-limit'end
 end
 if count~=largest then return nil,'dense-records-required'end
 local sequence,time=0,0
 for i=1,count do
  local r=rawget(rows,i);if not plain(r)then return nil,'unsafe-table'end
  local allowed=type(r.type)=='string'and fields[r.type];if not allowed then return nil,'invalid-record'end
  local extra,issue=keys(r,allowed,true);if not extra then return nil,issue end
  bytes=bytes+8+extra;if bytes>LIMIT_BYTES then return nil,'payload-limit'end
  if not integer(r.seq,1)or not finite(r.time)or r.time<0 or r.time>trace.duration then return nil,'invalid-record'end
  if r.seq<=sequence then return nil,'duplicate-or-decreasing-sequence'end
  if r.time<time then return nil,'decreasing-time'end;sequence,time=r.seq,r.time
  local kind=r.type
  if kind=='advice'then
   if not integer(r.epoch,1)or not member(r.action,actions)then return nil,'invalid-record'end
   if r.action=='spell'then
    if not integer(r.spell,1)or not finite(r.validUntil)or r.validUntil<r.time or r.validUntil>trace.duration then return nil,'invalid-record'end
   elseif r.spell~=nil or r.validUntil~=nil then return nil,'invalid-record'end
  elseif kind=='presentation'then
   if not integer(r.adviceSeq,1)or not member(r.state,states)then return nil,'invalid-record'end
  elseif kind=='retire'then
   if not member(r.reason,retires)then return nil,'invalid-record'end
  elseif kind=='attempt'or kind=='result'then
   if not integer(r.cast,0)or not integer(r.spell,0)or not member(r.actor,actors)or not member(r.castKind,kinds)then return nil,'invalid-record'end
   if kind=='attempt'then
    if not integer(r.epoch,1)or(r.phase~='sent'and r.phase~='start')then return nil,'invalid-record'end
   elseif not member(r.status,statuses)then return nil,'invalid-record'end
  elseif kind=='damage'then
   if not member(r.actor,actors)or not member(r.subtype,subtypes)or type(r.known)~='boolean'then return nil,'invalid-record'end
   if r.known then
    if not finite(r.amount)or r.amount<0 or r.overkill~=nil and not finite(r.overkill)then return nil,'invalid-record'end
   elseif r.amount~=nil or r.overkill~=nil then return nil,'invalid-record'end
  elseif not member(r.state,coverageStates)then return nil,'invalid-record'end
 end
 return count,bytes
end
local function blank()
 return{format=1,model=1,status='complete',nativeCertified=false,
  agreement={metric='exact-selected-spell-agreement',status='unavailable',matched=0,different=0,unobservable=0,scorable=0,reasons={}},
  counts={attempts=0,duplicateAttempts=0,duplicateResults=0,distinctCasts=0,pending=0,expired=0,failed=0,interrupted=0,stop=0,excludedCasts=0,unkeyedRows=0},
  coverage={adviceRows=0,visibleAcknowledgements=0,unqualifiedAcknowledgements=0},
  outcome={attribution='capture-only',encounter='unavailable',roleEffectiveness='unavailable',coveredSeconds=0,readableRows=0,unknownRows=0,excludedRows=0,unsupportedRows=0,unknownActorRows=0,uncoveredRows=0,
   raw={status='unavailable'},net={status='unavailable'},rate={status='unavailable',denominator='covered-capture-seconds'}},
  alternatives='unavailable',intent='unavailable',latency='unavailable',quality='unavailable'}
end
local function refused(reason)local r=blank();r.status='unavailable';r.reason=reason;return r end
addon.Analytics=addon.Analytics or{}
function addon.Analytics.Replay(trace)
 local count,bytes=validate(trace);if not count then return refused(bytes)end
 local report=blank();report.bytes=bytes;report.records=count
 local totals,agreement,covered=report.counts,report.agreement,report.coverage
 local casts,pending={},0;local latest,acknowledged,epoch
 local damageState,damageTime='unavailable',0
 local outcome=report.outcome;local raw,net,rawOK,netOK,netMissing=0,0,true,true,0
 local function finishPending(reason)
  for _,c in pairs(casts)do if c.pending then c.pending=false;pending=pending-1;c.reason=reason end end
 end
 local function expire(now)
  for _,c in pairs(casts)do if c.pending and now-c.time>30 then c.pending=false;pending=pending-1;c.reason='attempt-expired';totals.expired=totals.expired+1 end end
 end
 local function remember(row)
  local c=casts[row.cast]
  if not c then
   totals.distinctCasts=totals.distinctCasts+1;if totals.distinctCasts>LIMIT_CASTS then return nil end
   c={actor=row.actor,kind=row.castKind,spell=row.spell};casts[row.cast]=c
  end
  return c
 end
 local function identity(c,row)return c.actor==row.actor and c.kind==row.castKind and c.spell==row.spell end
 for i=1,count do
  local r=trace.records[i];expire(r.time)
  local kind=r.type
  if kind=='advice'then
   covered.adviceRows=covered.adviceRows+1
   if epoch~=nil and epoch~=r.epoch then finishPending('segment-retired')end
   epoch=r.epoch;latest=r;acknowledged=false
  elseif kind=='presentation'then
   if latest and r.adviceSeq==latest.seq and latest.seq<r.seq then
    acknowledged=r.state=='visible';if acknowledged then covered.visibleAcknowledgements=covered.visibleAcknowledgements+1 end
   else covered.unqualifiedAcknowledgements=covered.unqualifiedAcknowledgements+1 end
  elseif kind=='retire'then
   latest=nil;acknowledged=false;epoch=nil;finishPending('segment-retired')
  elseif kind=='attempt'or kind=='result'then
   if r.cast==0 then
    totals.unkeyedRows=totals.unkeyedRows+1
    if kind=='result'and r.status=='success'and r.actor=='player'and r.castKind=='ordinary'then agreement.unobservable=agreement.unobservable+1;agreement.reasons['unknown-cast-key']=(agreement.reasons['unknown-cast-key']or 0)+1 end
   else
    local c=remember(r);if not c then return refused('cast-limit')end
    if not identity(c,r)then c.conflict=true end
    if kind=='attempt'then
     if c.started or c.resultSeen then
      totals.duplicateAttempts=totals.duplicateAttempts+1
      if c.started and c.epoch~=r.epoch then c.conflict=true end
     else
      c.started=true;c.epoch=r.epoch;c.time=r.time;c.pending=true;pending=pending+1;totals.attempts=totals.attempts+1
      if pending>LIMIT_PENDING then return refused('pending-limit')end
      if r.actor~='player'or r.castKind~='ordinary'then c.excluded=true
      elseif r.spell==0 then c.reason='unknown-spell'
      elseif not latest then c.reason='missing-advice'
      elseif latest.epoch~=r.epoch then c.reason='epoch-mismatch'
      elseif latest.action~='spell'then c.reason='unmodeled-advice'
      elseif not acknowledged then c.reason='unacknowledged-advice'
      elseif r.time>=latest.validUntil then c.reason='stale-advice'
      else c.selectedSpell=latest.spell end
     end
    else
     if c[r.status]then totals.duplicateResults=totals.duplicateResults+1 end
     c.resultSeen=true
     if r.status=='success'then
      if r.actor=='player'and r.castKind=='ordinary'then c.ordinarySuccess=true end
      if not c.success then c.success=true;if c.pending then c.pending=false;pending=pending-1 end end
     elseif r.status=='stop'then
      if not c.stop then c.stop=true;totals.stop=totals.stop+1 end
     else
      if not c[r.status]then c[r.status]=true;totals[r.status]=totals[r.status]+1 end
      if c.pending then c.pending=false;pending=pending-1 end
     end
     if not c.started and not c.reason then c.reason='missing-attempt'end
     if r.actor~='player'or r.castKind~='ordinary'then c.excluded=true end
    end
   end
  elseif kind=='damageCoverage'then
   if damageState=='available'then outcome.coveredSeconds=outcome.coveredSeconds+r.time-damageTime end
   damageTime=r.time;damageState=r.state
  elseif kind=='damage'then
   if r.actor=='pet'or r.actor=='other'then outcome.excludedRows=outcome.excludedRows+1
   elseif r.actor=='unknown'then outcome.unknownActorRows=outcome.unknownActorRows+1
   elseif damageState~='available'then outcome.uncoveredRows=outcome.uncoveredRows+1
   elseif r.subtype=='unmodeled'then outcome.unsupportedRows=outcome.unsupportedRows+1
   elseif not r.known then outcome.unknownRows=outcome.unknownRows+1
   else
    outcome.readableRows=outcome.readableRows+1
    if rawOK then raw=raw+r.amount;rawOK=finite(raw)end
    if r.overkill==nil then netMissing=netMissing+1
    else
     local value=r.amount-max(r.overkill,0)
     if value<0 then netMissing=netMissing+1
     elseif netOK then net=net+value;netOK=finite(net)end
    end
   end
  end
 end
 expire(trace.duration);totals.pending=pending
 for _,c in pairs(casts)do
  if c.excluded then totals.excludedCasts=totals.excludedCasts+1 end
  if c.success and(c.ordinarySuccess or c.conflict and c.actor=='player'and c.kind=='ordinary')then
   local reason=c.conflict and'cast-identity-conflict'or c.failed and'failed-cast'or c.interrupted and'interrupted-cast'or c.reason
   if not reason and not c.selectedSpell then reason='missing-attempt'end
   if reason then agreement.unobservable=agreement.unobservable+1;agreement.reasons[reason]=(agreement.reasons[reason]or 0)+1
   elseif c.spell==c.selectedSpell then agreement.matched=agreement.matched+1
   else agreement.different=agreement.different+1 end
  end
 end
 agreement.scorable=agreement.matched+agreement.different
 if agreement.scorable>0 then agreement.status='available';agreement.percentage=100*agreement.matched/agreement.scorable end
 if damageState=='available'then outcome.coveredSeconds=outcome.coveredSeconds+trace.duration-damageTime end
 local partial=outcome.coveredSeconds<trace.duration or outcome.unknownRows>0 or outcome.unknownActorRows>0 or outcome.unsupportedRows>0 or outcome.uncoveredRows>0
 if outcome.readableRows>0 and rawOK then outcome.raw.status=partial and'partial'or'available';outcome.raw.value=raw end
 if outcome.readableRows>0 and netOK and netMissing==0 then outcome.net.status=partial and'partial'or'available';outcome.net.value=net end
 if outcome.raw.status=='available'and outcome.coveredSeconds>0 then
  local rate=raw/outcome.coveredSeconds;if finite(rate)then outcome.rate.status='available';outcome.rate.value=rate end
 end
 return report
end
