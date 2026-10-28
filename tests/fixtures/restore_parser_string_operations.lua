-- Exact complete-module inverse of captured parser operations from92c8fe8.
local records = {
    ["Data/plain.lua"] = {
        bytes = 6991,
        hash = [=[a52b3fe6]=],
        patches = {
            {
                old = [=[local _, addon = ...
local data = addon.RotationData or {}
addon.RotationData = data

-- Inputs are decoded/packaged data, never unsanitized game observations.
local maxDepth, maxNodes, maxBytes, maxString = 64, 20000, 1048576, 262144
local function diagnostic(code, path)
    local location = "$"
    for _, key in ipairs(path) do
        location = location .. (type(key)=="number" and "["..key.."]" or "."..key:sub(1,80))
    end
    return {code=code, path=location, severity="error"}
end
]=],
                current = [=[local _, addon = ...
local data = addon.RotationData or {}
addon.RotationData = data
-- Owned plain-data diagnostics use standard byte slicing captured at load.
-- Literal string metatables and later library patches do not define this API.
local parserString=string
local parserSub=type(parserString)=="table" and rawget(parserString,"sub") or nil
if type(parserSub)~="function" then parserSub=nil end

-- Inputs are decoded/packaged data, never unsanitized game observations.
local maxDepth, maxNodes, maxBytes, maxString = 64, 20000, 1048576, 262144
local function diagnostic(code, path)
    local location = "$"
    for _, key in ipairs(path) do
        location = location .. (type(key)=="number" and "["..key.."]" or "."..parserSub(key,1,80))
    end
    return {code=code, path=location, severity="error"}
end
]=],
            },
            {
                old = [=[local ownedPortable=data.CheckPortable
local function portableOwned(namespace)
    return portableEqual(namespace,data) and portableType(portableEnvironment)=="table"
        and portableEqual(portableRawget(data,"CheckPortable"),ownedPortable)
        and portableEqual(portableGetfenv(ownedPortable),portableEnvironment)
        and portableEqual(portableGetfenv(finite),portableEnvironment)
]=],
                current = [=[local ownedPortable=data.CheckPortable
local function portableOwned(namespace)
    return portableEqual(namespace,data) and portableType(portableEnvironment)=="table"
        and portableType(parserSub)=="function"
        and portableEqual(portableRawget(data,"CheckPortable"),ownedPortable)
        and portableEqual(portableGetfenv(ownedPortable),portableEnvironment)
        and portableEqual(portableGetfenv(finite),portableEnvironment)
]=],
            },
            {
                old = [=[    check("public-env",capability and portableEqual(portableGetfenv(ownedPortable),portableEnvironment))
    check("finite-env",capability and portableEqual(portableGetfenv(finite),portableEnvironment))
    check("diagnostic-env",capability and portableEqual(portableGetfenv(diagnostic),portableEnvironment))
    local keys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
    local pointers={portableType,portablePairs,portableIpairs,portableGetmetatable,portableGetfenv,portableMath,portableTable}
    for i=1,7 do
]=],
                current = [=[    check("public-env",capability and portableEqual(portableGetfenv(ownedPortable),portableEnvironment))
    check("finite-env",capability and portableEqual(portableGetfenv(finite),portableEnvironment))
    check("diagnostic-env",capability and portableEqual(portableGetfenv(diagnostic),portableEnvironment))
    result.parserSub=portableType(parserSub)=="function"
    check("parser-sub-unavailable",result.parserSub)
    local keys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
    local pointers={portableType,portablePairs,portableIpairs,portableGetmetatable,portableGetfenv,portableMath,portableTable}
    for i=1,7 do
]=],
            },
        },
    },
    ["Data/rotation_tree.lua"] = {
        bytes = 13683,
        hash = [=[cd786a20]=],
        patches = {
            {
                old = [=[local _,addon=...
local data=addon.RotationData
local function child(path,key)
    local result={};for i,part in ipairs(path) do result[i]=part end
    result[#result+1]=key;return result
]=],
                current = [=[local _,addon=...
local data=addon.RotationData
-- The identifier grammar uses the standard pattern operation captured at load,
-- independently of mutable literal-string method dispatch.
local parserString=string
local parserMatch=type(parserString)=="table" and rawget(parserString,"match") or nil
if type(parserMatch)~="function" then parserMatch=nil end
local function child(path,key)
    local result={};for i,part in ipairs(path) do result[i]=part end
    result[#result+1]=key;return result
]=],
            },
            {
                old = [=[end
local function failure(code,path) return nil,{code=code,path=location(path),severity="error"} end
local function identifier(value)
    return type(value)=="string" and #value>0 and #value<=128 and value:match("^[%w][%w._:%-]*$")~=nil
end
local function dense(value)
    if type(value)~="table" then return false end
]=],
                current = [=[end
local function failure(code,path) return nil,{code=code,path=location(path),severity="error"} end
local function identifier(value)
    return type(value)=="string" and #value>0 and #value<=128 and parserMatch(value,"^[%w][%w._:%-]*$")~=nil
end
local function dense(value)
    if type(value)~="table" then return false end
]=],
            },
            {
                old = [=[---@type fun(f: number|function): table
local indexGetfenv=getfenv
local indexPairs,indexIpairs=pairs,ipairs
local indexTable,indexMath,indexString=table,math,string
local indexSort,indexMax,indexHuge=table.sort,math.max,math.huge
local indexEnvironment=indexType(indexGetfenv)=="function" and indexGetfenv(1) or nil
local indexStringMeta=indexGetmetatable("")
local indexStringMethods=indexType(indexStringMeta)=="table" and indexRawget(indexStringMeta,"__index") or nil
local indexMatch=indexType(indexStringMethods)=="table" and indexRawget(indexStringMethods,"match") or nil
local indexSub=indexType(indexStringMethods)=="table" and indexRawget(indexStringMethods,"sub") or nil
local ownedIndex=data.IndexRotationSteps
local portableOwned,portableStatus
local bindPortable=addon.BindRotationPortableReader
]=],
                current = [=[---@type fun(f: number|function): table
local indexGetfenv=getfenv
local indexPairs,indexIpairs=pairs,ipairs
local indexTable,indexMath=table,math
local indexSort,indexMax,indexHuge=table.sort,math.max,math.huge
local indexEnvironment=indexType(indexGetfenv)=="function" and indexGetfenv(1) or nil
local ownedIndex=data.IndexRotationSteps
local portableOwned,portableStatus
local bindPortable=addon.BindRotationPortableReader
]=],
            },
            {
                old = [=[        and indexEqual(indexRawget(indexEnvironment,"math"),indexMath)
        and indexEqual(indexRawget(indexMath,"max"),indexMax)
        and indexEqual(indexRawget(indexMath,"huge"),indexHuge)
        and indexType(indexStringMeta)=="table" and indexType(indexStringMethods)=="table"
        and indexType(indexMatch)=="function" and indexType(indexSub)=="function"
        and indexEqual(indexGetmetatable(""),indexStringMeta)
        and indexEqual(indexRawget(indexStringMeta,"__index"),indexStringMethods)
        and indexEqual(indexRawget(indexStringMethods,"match"),indexMatch)
        and indexEqual(indexRawget(indexStringMethods,"sub"),indexSub)
end
-- A pure explanation of captured ownership facts, sampled only by the profiler.
local function indexStatus(namespace)
]=],
                current = [=[        and indexEqual(indexRawget(indexEnvironment,"math"),indexMath)
        and indexEqual(indexRawget(indexMath,"max"),indexMax)
        and indexEqual(indexRawget(indexMath,"huge"),indexHuge)
        and indexType(parserMatch)=="function"
end
-- A pure explanation of captured ownership facts, sampled only by the profiler.
local function indexStatus(namespace)
]=],
            },
            {
                old = [=[            check("math-huge",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"huge"),indexHuge))
        end
    end
    local currentMeta=indexGetmetatable("")
    local currentMethods=indexType(currentMeta)=="table" and indexRawget(currentMeta,"__index") or nil
    local function shape(value) local kind=indexType(value);return (kind=="table" or kind=="function") and kind or "other" end
    result.capturedIndex=shape(indexStringMethods);result.currentIndex=shape(currentMethods)
    check("string-anchor-table",indexType(indexStringMeta)=="table")
    result.globalString=indexEqual(indexStringMethods,indexString)
    check("string-index-table",indexType(indexStringMethods)=="table")
    check("string-match-callable",indexType(indexMatch)=="function")
    check("string-sub-callable",indexType(indexSub)=="function")
    check("string-anchor-current",indexEqual(currentMeta,indexStringMeta))
    check("string-index-current",indexType(indexStringMeta)=="table" and indexEqual(indexRawget(indexStringMeta,"__index"),indexStringMethods))
    check("string-match-current",indexType(indexStringMethods)=="table" and indexEqual(indexRawget(indexStringMethods,"match"),indexMatch))
    check("string-sub-current",indexType(indexStringMethods)=="table" and indexEqual(indexRawget(indexStringMethods,"sub"),indexSub))
    return {portable=portable,index=result}
end
local function witness(body)
]=],
                current = [=[            check("math-huge",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"huge"),indexHuge))
        end
    end
    result.parserMatch=indexType(parserMatch)=="function"
    check("parser-match-unavailable",result.parserMatch)
    return {portable=portable,index=result}
end
local function witness(body)
]=],
            },
            {
                old = [=[        if indexEqual(attempt,token) and indexOwned() then entry={body=body,profile=profile,db=db,index=index,graph=graph} end
        return true,materialize(index)
    end
    local reader=read
    if indexType(indexStringMethods)~="table" then
        reader=function(body,profile,namespace,db) retire();return false end
    end
    bind(reader,retire,indexStatus)
end
]=],
                current = [=[        if indexEqual(attempt,token) and indexOwned() then entry={body=body,profile=profile,db=db,index=index,graph=graph} end
        return true,materialize(index)
    end
    bind(read,retire,indexStatus)
end
]=],
            },
        },
    },
    ["Diagnostics/cpu.lua"] = {
        bytes = 34620,
        hash = [=[c13abe87]=],
        patches = {
            {
                old = [=[ executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","string-anchor-table","string-index-table","string-match-callable","string-sub-callable","string-anchor-current","string-index-current","string-match-current","string-sub-current","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
]=],
                current = [=[ executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","parser-match-unavailable","parser-sub-unavailable","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
]=],
            },
            {
                old = [=[   end
   parts[i]=part
  end
  local index=proofRawget(status,"index")
  local function shape(key)
   local value=proofType(index)=="table" and proofRawget(index,key)
   return (value=="table" or value=="function" or value=="other") and value or "unavailable"
  end
  local alias=proofType(index)=="table" and proofRawget(index,"globalString")
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; string-index="..shape("capturedIndex").."/"..shape("currentIndex").."; string-global="..(alias==true and "1" or alias==false and "0" or "?")
 end)
 return ok and text or "probe-unavailable"
end
]=],
                current = [=[   end
   parts[i]=part
  end
  local function parserFlag(owner,key)
   local row=proofRawget(status,owner)
   local value=proofType(row)=="table" and proofRawget(row,key)
   return value==true and "1" or value==false and "0" or "?"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; parser-match="..parserFlag("index","parserMatch").."; parser-sub="..parserFlag("portable","parserSub")
 end)
 return ok and text or "probe-unavailable"
end
]=],
            },
        },
    },
}

local function hash(text)
    local value = 5381

    for i = 1, #text do
        value = (value * 33 + string.byte(text, i)) % 4294967296
    end

    return string.format('%08x', value)
end

return function(text, path)
    local record = records[path]
    assert(type(text) == 'string' and record, 'unknown parser inverse input')

    for _, patch in ipairs(record.patches) do
        local first, last = text:find(patch.current, 1, true)
        assert(first and not text:find(patch.current, last + 1, true), 'missing or repeated captured-parser change')
        text = text:sub(1, first - 1) .. patch.old .. text:sub(last + 1)
    end

    assert(#text == record.bytes and hash(text) == record.hash, 'module changed outside captured-parser scope')
    return text
end
