-- Strict inverse of private diagnostics and the sole approved table-index qualification.
local changes={
 ["Data/plain.lua"]={bytes=5327,hash="c6694bc9",patches={
  {old=[=[    bind(portableOwned)
]=],new=[=[    bind(portableOwned,portableStatus)
]=]},
  {old=[=[function addon:BindRotationPortableReader(bind)
]=],new=[=[-- Capture-only explanation of the existing proof; never authorizes execution.
local function portableStatus(namespace)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local environment=portableType(portableEnvironment)=="table"
    local capability=portableType(portableGetfenv)=="function"
    check("namespace",portableEqual(namespace,data));check("capability",capability)
    check("env",environment)
    check("method",portableEqual(portableRawget(data,"CheckPortable"),ownedPortable))
    check("public-env",capability and portableEqual(portableGetfenv(ownedPortable),portableEnvironment))
    check("finite-env",capability and portableEqual(portableGetfenv(finite),portableEnvironment))
    check("diagnostic-env",capability and portableEqual(portableGetfenv(diagnostic),portableEnvironment))
    local keys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
    local pointers={portableType,portablePairs,portableIpairs,portableGetmetatable,portableGetfenv,portableMath,portableTable}
    for i=1,7 do
        local key=keys[i];local ok=environment and portableEqual(portableRawget(portableEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
        if key=="math" then check("math-huge",portableType(portableMath)=="table" and portableEqual(portableRawget(portableMath,"huge"),portableHuge)) end
        if key=="table" then check("table-sort",portableType(portableTable)=="table" and portableEqual(portableRawget(portableTable,"sort"),portableSort)) end
    end
    return result
end
function addon:BindRotationPortableReader(bind)
]=]},
 }},
 ["Data/rotation_tree.lua"]={bytes=10433,hash="b42ec0c8",patches={
  {old=[=[    check("string-index-global",indexEqual(indexStringMethods,indexString))
]=],new=[=[    result.globalString=indexEqual(indexStringMethods,indexString)
    check("string-index-table",indexType(indexStringMethods)=="table")
]=]},
  {old=[=[and indexType(indexStringMeta)=="table" and indexEqual(indexStringMethods,indexString)]=],new=[=[and indexType(indexStringMeta)=="table" and indexType(indexStringMethods)=="table"]=]},
  {old=[=[    bind(read,retire)
]=],new=[=[    bind(read,retire,indexStatus)
]=]},
  {old=[=[local function witness(body)
]=],new=[=[-- A pure explanation of captured ownership facts, sampled only by the profiler.
local function indexStatus(namespace)
    local portable=portableStatus and portableStatus(data) or {reason="unbound",raw={}}
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local environment=indexType(indexEnvironment)=="table"
    local capability=indexType(indexGetfenv)=="function"
    check("namespace",indexEqual(namespace,data));check("portable-proof",portable.reason=="ready")
    check("capability",capability);check("env",environment)
    check("method",indexEqual(indexRawget(data,"IndexRotationSteps"),ownedIndex))
    local functions={ownedIndex,child,location,failure,identifier,dense}
    local reasons={"public-env","child-env","location-env","failure-env","identifier-env","dense-env"}
    for i=1,6 do check(reasons[i],capability and indexEqual(indexGetfenv(functions[i]),indexEnvironment)) end
    local keys={"type","pairs","ipairs","getmetatable","getfenv","table","math"}
    local pointers={indexType,indexPairs,indexIpairs,indexGetmetatable,indexGetfenv,indexTable,indexMath}
    for i=1,7 do
        local key=keys[i];local ok=environment and indexEqual(indexRawget(indexEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
        if key=="table" then check("table-sort",indexType(indexTable)=="table" and indexEqual(indexRawget(indexTable,"sort"),indexSort)) end
        if key=="math" then
            check("math-max",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"max"),indexMax))
            check("math-huge",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"huge"),indexHuge))
        end
    end
    local currentMeta=indexGetmetatable("")
    local currentMethods=indexType(currentMeta)=="table" and indexRawget(currentMeta,"__index") or nil
    local function shape(value) local kind=indexType(value);return (kind=="table" or kind=="function") and kind or "other" end
    result.capturedIndex=shape(indexStringMethods);result.currentIndex=shape(currentMethods)
    check("string-anchor-table",indexType(indexStringMeta)=="table")
    check("string-index-global",indexEqual(indexStringMethods,indexString))
    check("string-match-callable",indexType(indexMatch)=="function")
    check("string-sub-callable",indexType(indexSub)=="function")
    check("string-anchor-current",indexEqual(currentMeta,indexStringMeta))
    check("string-index-current",indexType(indexStringMeta)=="table" and indexEqual(indexRawget(indexStringMeta,"__index"),indexStringMethods))
    check("string-match-current",indexType(indexStringMethods)=="table" and indexEqual(indexRawget(indexStringMethods,"match"),indexMatch))
    check("string-sub-current",indexType(indexStringMethods)=="table" and indexEqual(indexRawget(indexStringMethods,"sub"),indexSub))
    return {portable=portable,index=result}
end
local function witness(body)
]=]},
  {old=[=[    bindPortable(addon,function(reader) portableOwned=reader end)
]=],new=[=[    bindPortable(addon,function(reader,status) portableOwned,portableStatus=reader,status end)
]=]},
  {old=[=[local portableOwned
]=],new=[=[local portableOwned,portableStatus
]=]},
 }},
 ["Core/rotation_sequence.lua"]={bytes=5508,hash="433ab371",patches={
  {old=[=[    bind(rawMethod,run)
]=],new=[=[    bind(rawMethod,run,sequenceStatus)
]=]},
  {old=[=[function addon:BindRotationSequenceReader(bind)
]=],new=[=[-- Source-owned status carries no body, cache, method, or profile references.
local function sequenceStatus(owner)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local ownerTable=sequenceType(owner)=="table"
    local db=ownerTable and sequenceRawget(owner,"db") or nil
    local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
    local environment=sequenceType(sequenceEnvironment)=="table"
    local capability=sequenceType(sequenceGetfenv)=="function"
    check("owner",sequenceEqual(owner,addon))
    check("method",ownerTable and sequenceEqual(sequenceRawget(owner,"EvaluateRotationSequence"),ownedSequence))
    check("namespace",ownerTable and sequenceEqual(sequenceRawget(owner,"RotationData"),data))
    check("db",sequenceType(db)=="table");check("profile",sequenceType(profile)=="table")
    check("index-reader",sequenceType(readIndex)=="function")
    check("capability",capability);check("env",environment)
    check("public-env",capability and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment))
    local keys={"type","ipairs","getfenv"};local pointers={sequenceType,sequenceIpairs,sequenceGetfenv}
    for i=1,3 do
        local key=keys[i];local ok=environment and sequenceEqual(sequenceRawget(sequenceEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
    end
    local status=indexStatus and indexStatus(data) or {portable={reason="unbound"},index={reason="unbound"}}
    status.sequence=result;return status
end
function addon:BindRotationSequenceReader(bind)
]=]},
  {old=[=[    bindIndex(addon,function(read,retire) readIndex,retireIndex=read,retire end)
]=],new=[=[    bindIndex(addon,function(read,retire,status) readIndex,retireIndex,indexStatus=read,retire,status end)
]=]},
  {old=[=[local readIndex,retireIndex
]=],new=[=[local readIndex,retireIndex,indexStatus
]=]},
 }},
 ["main.lua"]={bytes=65745,hash="eb7c7581",patches={
  {old=[=[local DBIcon = LibStub("LibDBIcon-1.0")
]=],new=[=[-- One-time private handoff to the earlier-loaded optional CPU sampler.
local bindCPUStatus=addon.BindCPUExecutionIndexDiagnostic
if type(bindCPUStatus)=="function" then
    bindCPUStatus(addon,function()
        local status=sequenceStatus and sequenceStatus(addon) or {}
        status.main={reason=sequenceRawMethod and sequenceRun and sequenceStatus and "ready" or "unbound"}
        return status
    end)
    addon.BindCPUExecutionIndexDiagnostic=nil
end
local DBIcon = LibStub("LibDBIcon-1.0")
]=]},
  {old=[=[    bindSequence(addon,function(rawMethod,run) sequenceRawMethod,sequenceRun=rawMethod,run end)
]=],new=[=[    bindSequence(addon,function(rawMethod,run,status) sequenceRawMethod,sequenceRun,sequenceStatus=rawMethod,run,status end)
]=]},
  {old=[=[local sequenceRawMethod,sequenceRun
]=],new=[=[local sequenceRawMethod,sequenceRun,sequenceStatus
]=]},
 }},
 ["Diagnostics/cpu.lua"]={bytes=17351,hash="e89d3c97",patches={
  {old=[=[ run.timer=timer;run.executionIndexProof=executionIndexProof();lastReport=nil
]=],new=[=[ run.timer=timer;if active==run then run.executionIndexProof=executionIndexProof() end;lastReport=nil
]=]},
  {old=[=[ local first="Execution index proof start: "..started
]=],new=[=[ local first="Execution index proof start: "..(started or "probe-unavailable")
]=]},
  {old=[=[  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; string-index="..shape("capturedIndex").."/"..shape("currentIndex")
]=],new=[=[  local alias=proofType(index)=="table" and proofRawget(index,"globalString")
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; string-index="..shape("capturedIndex").."/"..shape("currentIndex").."; string-global="..(alias==true and "1" or alias==false and "0" or "?")
]=]},
  {old=[=["string-index-global"]=],new=[=["string-index-table"]=]},
  {old=[=[ run.timer=timer;lastReport=nil
]=],new=[=[ run.timer=timer;run.executionIndexProof=executionIndexProof();lastReport=nil
]=]},
  {old=[=[   text=table.concat(report,'\n')
]=],new=[=[   -- BEGIN EXECUTION INDEX DIAGNOSTICS
   appendExecutionIndexProof(report,run.executionIndexProof,executionIndexProof())
   -- END EXECUTION INDEX DIAGNOSTICS
   text=table.concat(report,'\n')
]=]},
  {old=[=[local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
]=],new=[=[-- Fixed, source-free proof snapshots. The installer is retired by main;
-- this reader is private and is never invoked outside capture boundaries.
local proofType,proofRawget,proofPcall=type,rawget,pcall
local executionIndexDiagnostic
function addon:BindCPUExecutionIndexDiagnostic(provider)
 if self~=addon or executionIndexDiagnostic or proofType(provider)~="function" then return end
 executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","string-anchor-table","string-index-global","string-match-callable","string-sub-callable","string-anchor-current","string-index-current","string-match-current","string-sub-current","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
 if not executionIndexDiagnostic then return "probe-unavailable" end
 local ok,text=proofPcall(function()
  local status=executionIndexDiagnostic()
  if proofType(status)~="table" then return "probe-unavailable" end
  local parts={}
  for i=1,4 do
   local name=proofOwners[i];local row=proofRawget(status,name)
   local reason=proofType(row)=="table" and proofRawget(row,"reason") or nil
   reason=proofType(reason)=="string" and proofRawget(proofReasons,reason) and reason or "unavailable"
   local part=name.."="..reason
   if reason~="ready" and name~="main" then
    local flags=proofType(row)=="table" and proofRawget(row,"raw") or nil
    part=part.."["
    for keyIndex=1,7 do
     local key=proofRawKeys[keyIndex]
     if name~="sequence" or key=="type" or key=="ipairs" or key=="getfenv" then
      local flag=proofType(flags)=="table" and proofRawget(flags,key)
      part=part..key.."="..(flag==true and "1" or flag==false and "0" or "?").."," end
    end
    part=part.."]"
   end
   parts[i]=part
  end
  local index=proofRawget(status,"index")
  local function shape(key)
   local value=proofType(index)=="table" and proofRawget(index,key)
   return (value=="table" or value=="function" or value=="other") and value or "unavailable"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; string-index="..shape("capturedIndex").."/"..shape("currentIndex")
 end)
 return ok and text or "probe-unavailable"
end
local function appendExecutionIndexProof(report,started,ended)
 local bytes=#report-1
 for i=1,#report do bytes=bytes+#report[i] end
 local first="Execution index proof start: "..started
 local last="Execution index proof end: "..ended
 if bytes+1+#first+1+#last<16000 then
  report[#report+1]=first;report[#report+1]=last
 else
  local omitted="Execution index proof omitted to keep report bounded."
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
]=]},
 }},
}
return function(text,path)
 local change=assert(changes[path],"unknown diagnostic source")
 for _,patch in ipairs(change.patches) do
  local first,last=text:find(patch.new,1,true)
  assert(first and not text:find(patch.new,last+1,true),"diagnostic delta missing/repeated: "..path)
  text=text:sub(1,first-1)..patch.old..text:sub(last+1)
 end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==change.bytes and string.format("%08x",hash)==change.hash,"unrelated diagnostic source delta: "..path)
 return text
end
