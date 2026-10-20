-- Exact whole-module inverse for the persisted rotation revision slice (61ad6ad).
local rows={
 ['Data/validation.lua']={old=[======[local _, addon = ...
local data = addon.RotationData

local families = {retail=true, era=true, progression=true, tbc=true, forever=true}
local contexts = {player=true, pet=true, vehicle=true, possession=true, override=true, petbattle=true}
local classes = {WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true, DEATHKNIGHT=true,
    SHAMAN=true, MAGE=true, WARLOCK=true, MONK=true, DRUID=true, DEMONHUNTER=true, EVOKER=true}
function data.IsRotationClassToken(value) return type(value)=="string" and classes[value]==true end
local function integer(value, minimum)
    return type(value) == "number" and value >= minimum and value % 1 == 0
end
function data.GetRotationPriority(value)
    if value==nil then return 0 end
    if integer(value,-100000) and value<=100000 then return value end
end
local function nonempty(value) return type(value) == "string" and #value > 0 end
local function identifier(value)
    return nonempty(value) and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end
local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end
local function dense(value)
    if type(value) ~= "table" then return false end
    local count, maximum = 0, 0
    for key in pairs(value) do
        if not integer(key, 1) then return false end
        count, maximum = count+1, math.max(maximum, key)
    end
    return maximum == count
end

-- Match the documented primitive/union/nested-list/record declarations without
-- invoking a live valid/evaluate callback. Missing fields are handled separately.
local matchesType, matchesTable
matchesTable = function(value, schema, depth)
    if depth > 32 or type(value) ~= "table" then return false end
    if schema[1] ~= nil then
        if not dense(value) then return false end
        for _, child in ipairs(value) do if not matchesType(child, schema, depth+1) then return false end end
    else
        for key, child in pairs(value) do
            if schema[key] == nil or not matchesType(child, schema[key], depth+1) then return false end
        end
    end
    return true
end
matchesType = function(value, schema, depth)
    depth = depth or 0
    if depth > 32 then return false end
    if type(schema) == "string" then
        if schema == "condition" then return type(value) == "table" end
        local base = schema:match("^(.-)%[%]$")
        if base then
            if not dense(value) then return false end
            for _, child in ipairs(value) do if not matchesType(child, base, depth+1) then return false end end
            return true
        end
        return type(value) == schema
    end
    if type(schema) ~= "table" then return false end
    if schema[1] == nil then return matchesTable(value, schema, depth+1) end
    for _, alternative in ipairs(schema) do
        if type(alternative) == "table" then
            if matchesTable(value, alternative, depth+1) then return true end
        elseif matchesType(value, alternative, depth+1) then return true end
    end
    return false
end

local function validate(envelope, options, bodyOnly)
    options = options or {}
    local result = {valid=true, supported=true, resolved=true, diagnostics={},
        semanticStatus="not-evaluated", executionStatus="unchecked", qualityStatus="unreviewed"}
    local function issue(code, path, severity, kind)
        severity = severity or "error"
        if severity == "error" then result.valid = false end
        if kind == "unsupported" then result.supported = false end
        if kind == "unresolved" then result.resolved = false end
        if #result.diagnostics < 100 then
            result.diagnostics[#result.diagnostics+1] = {code=code, path=path, severity=severity or "error"}
        end
    end
    local function finish()
        if not result.valid or not result.supported or not result.resolved then result.executionStatus = "unavailable" end
        return result
    end
    local portable, why = data.CheckPortable(envelope)
    if not portable then issue(why.code, why.path, "error");return finish() end
    if type(envelope) ~= "table" then issue("expected-object", "$", "error");return finish() end
    local function object(value, path)
        if type(value) == "table" then return true end
        issue(value == nil and "missing-field" or "expected-object", path, "error")
        return false
    end
    local function list(value, path, required)
        if value == nil and not required then return false end
        if value == nil then issue("missing-field", path, "error");return false end
        if not dense(value) then issue(type(value) == "table" and "sparse-list" or "expected-list", path, "error");return false end
        return true
    end
    local function check(value, predicate, path)
        if not predicate(value) then issue(value == nil and "missing-field" or "invalid-field-value", path, "error");return false end
        return true
    end
    local function unknown(value, allowed, path)
        for _, key in ipairs(sortedKeys(value)) do
            if not allowed[key] then issue("unknown-field", path.."."..key, "warning", "unsupported") end
        end
    end
    local function optionalType(value, kind, path)
        if value ~= nil and type(value) ~= kind then issue("invalid-field-type", path, "error") end
    end
    if not bodyOnly then
        if envelope.format ~= "RotationMaster" then issue("unsupported-format", "$.format", "warning", "unsupported") end
        if not check(envelope.schemaVersion, function(v) return integer(v, 1) end, "$.schemaVersion") then return finish() end
        if envelope.schemaVersion ~= 1 then issue("unsupported-schema-version", "$.schemaVersion", "warning", "unsupported");return finish() end
        unknown(envelope, {format=true,schemaVersion=true,id=true,revision=true,nameKey=true,descriptionKey=true,
            applicability=true,tags=true,sources=true,body=true,dependencies=true}, "$")
        check(envelope.id, identifier, "$.id")
        check(envelope.revision, function(v) return integer(v, 1) end, "$.revision")
        check(envelope.nameKey, nonempty, "$.nameKey")
        check(envelope.descriptionKey, nonempty, "$.descriptionKey")
        local scope = envelope.applicability
        if object(scope, "$.applicability") then
            unknown(scope, {families=true,actionContext=true,class=true,universal=true,specs=true,minLevel=true,maxLevel=true,
                roles=true,intent=true,minBuild=true,maxBuild=true,rulesets=true}, "$.applicability")
            if list(scope.families, "$.applicability.families", true) then
                if #scope.families == 0 then issue("empty-edition-scope", "$.applicability.families", "error") end
                for i, family in ipairs(scope.families) do
                    local path = "$.applicability.families["..i.."]"
                    if check(family, nonempty, path) and not families[family] then issue("unknown-edition", path, "warning", "unsupported") end
                end
            end
            if check(scope.actionContext, nonempty, "$.applicability.actionContext") and not contexts[scope.actionContext] then
                issue("unknown-action-context", "$.applicability.actionContext", "warning", "unsupported")
            end
            if scope.class ~= nil and check(scope.class, nonempty, "$.applicability.class") and not classes[scope.class] then
                issue("unknown-class", "$.applicability.class", "warning", "unsupported")
            end
            optionalType(scope.universal,"boolean","$.applicability.universal")
            if scope.universal==true and scope.class~=nil then issue("conflicting-class-scope","$.applicability.universal","error") end
            for _, pair in ipairs({{"minLevel","maxLevel"},{"minBuild","maxBuild"}}) do
                for _, key in ipairs(pair) do
                    if scope[key] ~= nil then check(scope[key], function(v) return integer(v, 1) end, "$.applicability."..key) end
                end
                if integer(scope[pair[1]], 1) and integer(scope[pair[2]], 1) and scope[pair[1]] > scope[pair[2]] then
                    issue("inverted-range", "$.applicability."..pair[2], "error")
                end
            end
            for _, key in ipairs({"specs","roles","rulesets"}) do
                if list(scope[key], "$.applicability."..key, false) then
                    if #scope[key] == 0 then issue("empty-selector", "$.applicability."..key, "error") end
                    for i, value in ipairs(scope[key]) do
                        check(value, key == "specs" and function(v) return integer(v, 0) end or nonempty, "$.applicability."..key.."["..i.."]")
                    end
                end
            end
            optionalType(scope.intent, "string", "$.applicability.intent")
        end
        if envelope.tags~=nil and not data.NormalizeRotationTags(envelope.tags) then issue("invalid-tags","$.tags","error") end
        if list(envelope.tags, "$.tags", false) then
            for i, tag in ipairs(envelope.tags) do check(tag, nonempty, "$.tags["..i.."]") end
        end
        if list(envelope.sources, "$.sources", false) then
            for i, source in ipairs(envelope.sources) do
                local path = "$.sources["..i.."]"
                if object(source, path) then
                    unknown(source, {url=true,title=true,reviewedAt=true,revision=true,notes=true}, path)
                    check(source.url, function(v) return nonempty(v) and v:match("^https?://[^%s]+$") ~= nil end, path..".url")
                    optionalType(source.title, "string", path..".title")
                    optionalType(source.reviewedAt, "string", path..".reviewedAt")
                    optionalType(source.revision, "string", path..".revision")
                    optionalType(source.notes, "string", path..".notes")
                end
            end
        end
        if list(envelope.dependencies, "$.dependencies", false) and #envelope.dependencies > 0 then
            issue("unsupported-dependencies", "$.dependencies", "warning", "unsupported")
        end
    end
    local condition, declaredConditions
    local function tableConditions(value, schema, path)
        if schema[1] ~= nil then
            for i, child in ipairs(value) do declaredConditions(child, schema, path.."["..i.."]") end
        else
            for _, key in ipairs(sortedKeys(value)) do declaredConditions(value[key], schema[key], path.."."..key) end
        end
    end
    declaredConditions = function(value, schema, path)
        if schema == "condition" then condition(value, path)
        elseif schema == "condition[]" then
            for i, child in ipairs(value) do condition(child, path.."["..i.."]") end
        elseif type(schema) == "table" then
            if schema[1] == nil then tableConditions(value, schema, path)
            else
                for _, alternative in ipairs(schema) do
                    if type(alternative) == "table" then
                        if matchesTable(value, alternative, 0) then tableConditions(value, alternative, path);return end
                    elseif matchesType(value, alternative) then declaredConditions(value, alternative, path);return end
                end
            end
        end
    end
    condition = function(value, path)
        if value == nil then return end
        if not object(value, path) then return end
        if next(value) == nil then return end
        if not check(value.type, nonempty, path..".type") then return end
        optionalType(value.disabled, "boolean", path..".disabled")
        if value.type=="AND" or value.type=="OR" or value.type=="NOT" then
            if value.name~=nil and (type(value.name)~="string" or #value.name>512 or value.name:find("%c")) then
                issue("invalid-group-name",path..".name","error")
            end
        end
        if value.type == "AND" or value.type == "OR" then
            unknown(value, {type=true,disabled=true,value=true,name=true}, path)
            if list(value.value, path..".value", true) then
                for i, child in ipairs(value.value) do condition(child, path..".value["..i.."]") end
            end
        elseif value.type == "NOT" then
            unknown(value, {type=true,disabled=true,value=true,name=true}, path)
            if object(value.value, path..".value") then condition(value.value, path..".value") end
        else
            local definition = options.conditions and options.conditions[value.type]
            if type(definition) ~= "table" or type(definition.fields) ~= "table" then
                issue("unknown-condition", path..".type", "warning", "unresolved");return
            end
            if definition.disabled then issue('disabled-condition',path..'.type','warning','unresolved') end
            if definition.functionUnavailable then issue('unavailable-function',path..'.type','warning','unresolved') end
            for _, key in ipairs(sortedKeys(value)) do
                if key ~= "type" and key ~= "disabled" then
                    if definition.fields[key] == nil then issue("unknown-field", path.."."..key, "warning", "unsupported")
                    elseif not matchesType(value[key], definition.fields[key]) then issue("invalid-field-type", path.."."..key, "error")
                    else declaredConditions(value[key], definition.fields[key], path.."."..key) end
                end
            end
            for _, key in ipairs(definition.requiredFields or {}) do
                if value[key] == nil then issue("missing-field", path.."."..key, "error") end
            end
        end
    end
    if not object(envelope.body, "$.body") then return finish() end
    local body = envelope.body
    unknown(body, {name=true,description=true,metadata=true,tags=true,priority=true,disabled=true,switch=true,rotation=true,cooldowns=true}, "$.body")
    if not data.GetRotationPriority(body.priority) then issue('invalid-priority','$.body.priority','error') end
    optionalType(body.name, "string", "$.body.name")
    optionalType(body.description,"string","$.body.description")
    if body.tags~=nil and not data.NormalizeRotationTags(body.tags) then issue("invalid-tags","$.body.tags","error") end
    if body.metadata~=nil and object(body.metadata,"$.body.metadata") then
        local allowed={author=true,realm=true,email=true,website=true,version=true}
        unknown(body.metadata,allowed,"$.body.metadata")
        for key in pairs(allowed) do optionalType(body.metadata[key],"string","$.body.metadata."..key) end
    end
    optionalType(body.disabled, "boolean", "$.body.disabled")
    condition(body.switch, "$.body.switch")
    local rootsValid=true
    for _,key in ipairs({"rotation","cooldowns"}) do if not list(body[key],"$.body."..key,true) then rootsValid=false end end
    if not rootsValid then return finish() end
    -- Pure validation preserves future branch metadata as unsupported. Runtime
    -- indexing remains strict, so these records cannot silently execute.
    local tree,problem=data.IndexRotationSteps(body,{allowUnknownBranchFields=true})
    if not tree then issue(problem.code,"$.body"..problem.path:sub(2),"error");return finish() end
    for _,row in ipairs(tree.rows) do
        local step,where=row.step,"$.body"
        for _,key in ipairs(row.path) do where=where..(type(key)=="number" and "["..key.."]" or "."..key) end
        if step.type=="branch" then
            unknown(step,{id=true,type=true,mode=true,name=true,conditions=true,onTrue=true,onFalse=true},where)
            optionalType(step.name,"string",where..".name")
        else
            unknown(step, {id=true,type=true,action=true,ranked=true,name=true,use_name=true,disabled=true,conditions=true,suppress_attack=true,
                effect=true,color=true,magnification=true,setpoint=true,xoffs=true,yoffs=true,announce=true,announce_sound=true}, where)
            if check(step.type, nonempty, where..".type") then
                if step.type == "spell" or step.type == "pet" or step.type == "any" then
                    check(step.action, function(v) return integer(v, 1) end, where..".action")
                elseif step.type == "item" then
                    if type(step.action) == "string" then
                        if check(step.action, identifier, where..".action") and not (options.itemsets and options.itemsets[step.action]) then
                            issue("missing-itemset", where..".action", "warning", "unresolved")
                        end
                    elseif list(step.action, where..".action", true) then
                        if #step.action == 0 then issue("empty-item-list", where..".action", "error") end
                        for j, item in ipairs(step.action) do check(item,function(v) return integer(v,1) or nonempty(v) end,where..".action["..j.."]") end
                    end
                elseif step.type ~= "none" then issue("unknown-action-type", where..".type", "warning", "unsupported") end
            end
            for _,flag in ipairs({"ranked","use_name","disabled"}) do optionalType(step[flag],"boolean",where.."."..flag) end
            optionalType(step.suppress_attack,"boolean",where..".suppress_attack")
            if step.suppress_attack~=nil and step.type~="none" then issue("unexpected-stop-option",where..".suppress_attack","warning","unsupported") end
            for _,label in ipairs({"name","effect","setpoint","announce","announce_sound"}) do optionalType(step[label],"string",where.."."..label) end
            for _,number in ipairs({"magnification","xoffs","yoffs"}) do optionalType(step[number],"number",where.."."..number) end
            if step.effect and not (options.effects and options.effects[step.effect]) then issue("missing-effect",where..".effect","warning","unresolved") end
            if step.color~=nil and object(step.color,where..".color") then
                unknown(step.color,{r=true,g=true,b=true,a=true},where..".color")
                for _,channel in ipairs({"r","g","b","a"}) do check(step.color[channel],function(v) return type(v)=="number" and v>=0 and v<=1 end,where..".color."..channel) end
            end
        end
        condition(step.conditions,where..".conditions")
    end
    return finish()
end

function data.ValidateEnvelope(envelope,options)
    return validate(envelope,options,false)
end
function data.ValidateBody(body,options)
    return validate({body=body},options,true)
end
]======],current=[======[local _, addon = ...
local data = addon.RotationData

local families = {retail=true, era=true, progression=true, tbc=true, forever=true}
local contexts = {player=true, pet=true, vehicle=true, possession=true, override=true, petbattle=true}
local classes = {WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true, DEATHKNIGHT=true,
    SHAMAN=true, MAGE=true, WARLOCK=true, MONK=true, DRUID=true, DEMONHUNTER=true, EVOKER=true}
function data.IsRotationClassToken(value) return type(value)=="string" and classes[value]==true end
local function integer(value, minimum)
    return type(value) == "number" and value >= minimum and value % 1 == 0
end
function data.GetRotationPriority(value)
    if value==nil then return 0 end
    if integer(value,-100000) and value<=100000 then return value end
end
local function nonempty(value) return type(value) == "string" and #value > 0 end
local function identifier(value)
    return nonempty(value) and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end
local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end
local function dense(value)
    if type(value) ~= "table" then return false end
    local count, maximum = 0, 0
    for key in pairs(value) do
        if not integer(key, 1) then return false end
        count, maximum = count+1, math.max(maximum, key)
    end
    return maximum == count
end

-- Match the documented primitive/union/nested-list/record declarations without
-- invoking a live valid/evaluate callback. Missing fields are handled separately.
local matchesType, matchesTable
matchesTable = function(value, schema, depth)
    if depth > 32 or type(value) ~= "table" then return false end
    if schema[1] ~= nil then
        if not dense(value) then return false end
        for _, child in ipairs(value) do if not matchesType(child, schema, depth+1) then return false end end
    else
        for key, child in pairs(value) do
            if schema[key] == nil or not matchesType(child, schema[key], depth+1) then return false end
        end
    end
    return true
end
matchesType = function(value, schema, depth)
    depth = depth or 0
    if depth > 32 then return false end
    if type(schema) == "string" then
        if schema == "condition" then return type(value) == "table" end
        local base = schema:match("^(.-)%[%]$")
        if base then
            if not dense(value) then return false end
            for _, child in ipairs(value) do if not matchesType(child, base, depth+1) then return false end end
            return true
        end
        return type(value) == schema
    end
    if type(schema) ~= "table" then return false end
    if schema[1] == nil then return matchesTable(value, schema, depth+1) end
    for _, alternative in ipairs(schema) do
        if type(alternative) == "table" then
            if matchesTable(value, alternative, depth+1) then return true end
        elseif matchesType(value, alternative, depth+1) then return true end
    end
    return false
end

local function validate(envelope, options, bodyOnly)
    options = options or {}
    local result = {valid=true, supported=true, resolved=true, diagnostics={},
        semanticStatus="not-evaluated", executionStatus="unchecked", qualityStatus="unreviewed"}
    local function issue(code, path, severity, kind)
        severity = severity or "error"
        if severity == "error" then result.valid = false end
        if kind == "unsupported" then result.supported = false end
        if kind == "unresolved" then result.resolved = false end
        if #result.diagnostics < 100 then
            result.diagnostics[#result.diagnostics+1] = {code=code, path=path, severity=severity or "error"}
        end
    end
    local function finish()
        if not result.valid or not result.supported or not result.resolved then result.executionStatus = "unavailable" end
        return result
    end
    local portable, why = data.CheckPortable(envelope)
    if not portable then issue(why.code, why.path, "error");return finish() end
    if type(envelope) ~= "table" then issue("expected-object", "$", "error");return finish() end
    local function object(value, path)
        if type(value) == "table" then return true end
        issue(value == nil and "missing-field" or "expected-object", path, "error")
        return false
    end
    local function list(value, path, required)
        if value == nil and not required then return false end
        if value == nil then issue("missing-field", path, "error");return false end
        if not dense(value) then issue(type(value) == "table" and "sparse-list" or "expected-list", path, "error");return false end
        return true
    end
    local function check(value, predicate, path)
        if not predicate(value) then issue(value == nil and "missing-field" or "invalid-field-value", path, "error");return false end
        return true
    end
    local function unknown(value, allowed, path)
        for _, key in ipairs(sortedKeys(value)) do
            if not allowed[key] then issue("unknown-field", path.."."..key, "warning", "unsupported") end
        end
    end
    local function optionalType(value, kind, path)
        if value ~= nil and type(value) ~= kind then issue("invalid-field-type", path, "error") end
    end
    if not bodyOnly then
        if envelope.format ~= "RotationMaster" then issue("unsupported-format", "$.format", "warning", "unsupported") end
        if not check(envelope.schemaVersion, function(v) return integer(v, 1) end, "$.schemaVersion") then return finish() end
        if envelope.schemaVersion ~= 1 then issue("unsupported-schema-version", "$.schemaVersion", "warning", "unsupported");return finish() end
        unknown(envelope, {format=true,schemaVersion=true,id=true,revision=true,nameKey=true,descriptionKey=true,
            applicability=true,tags=true,sources=true,body=true,dependencies=true}, "$")
        check(envelope.id, identifier, "$.id")
        check(envelope.revision, function(v) return integer(v, 1) end, "$.revision")
        check(envelope.nameKey, nonempty, "$.nameKey")
        check(envelope.descriptionKey, nonempty, "$.descriptionKey")
        local scope = envelope.applicability
        if object(scope, "$.applicability") then
            unknown(scope, {families=true,actionContext=true,class=true,universal=true,specs=true,minLevel=true,maxLevel=true,
                roles=true,intent=true,minBuild=true,maxBuild=true,rulesets=true}, "$.applicability")
            if list(scope.families, "$.applicability.families", true) then
                if #scope.families == 0 then issue("empty-edition-scope", "$.applicability.families", "error") end
                for i, family in ipairs(scope.families) do
                    local path = "$.applicability.families["..i.."]"
                    if check(family, nonempty, path) and not families[family] then issue("unknown-edition", path, "warning", "unsupported") end
                end
            end
            if check(scope.actionContext, nonempty, "$.applicability.actionContext") and not contexts[scope.actionContext] then
                issue("unknown-action-context", "$.applicability.actionContext", "warning", "unsupported")
            end
            if scope.class ~= nil and check(scope.class, nonempty, "$.applicability.class") and not classes[scope.class] then
                issue("unknown-class", "$.applicability.class", "warning", "unsupported")
            end
            optionalType(scope.universal,"boolean","$.applicability.universal")
            if scope.universal==true and scope.class~=nil then issue("conflicting-class-scope","$.applicability.universal","error") end
            for _, pair in ipairs({{"minLevel","maxLevel"},{"minBuild","maxBuild"}}) do
                for _, key in ipairs(pair) do
                    if scope[key] ~= nil then check(scope[key], function(v) return integer(v, 1) end, "$.applicability."..key) end
                end
                if integer(scope[pair[1]], 1) and integer(scope[pair[2]], 1) and scope[pair[1]] > scope[pair[2]] then
                    issue("inverted-range", "$.applicability."..pair[2], "error")
                end
            end
            for _, key in ipairs({"specs","roles","rulesets"}) do
                if list(scope[key], "$.applicability."..key, false) then
                    if #scope[key] == 0 then issue("empty-selector", "$.applicability."..key, "error") end
                    for i, value in ipairs(scope[key]) do
                        check(value, key == "specs" and function(v) return integer(v, 0) end or nonempty, "$.applicability."..key.."["..i.."]")
                    end
                end
            end
            optionalType(scope.intent, "string", "$.applicability.intent")
        end
        if envelope.tags~=nil and not data.NormalizeRotationTags(envelope.tags) then issue("invalid-tags","$.tags","error") end
        if list(envelope.tags, "$.tags", false) then
            for i, tag in ipairs(envelope.tags) do check(tag, nonempty, "$.tags["..i.."]") end
        end
        if list(envelope.sources, "$.sources", false) then
            for i, source in ipairs(envelope.sources) do
                local path = "$.sources["..i.."]"
                if object(source, path) then
                    unknown(source, {url=true,title=true,reviewedAt=true,revision=true,notes=true}, path)
                    check(source.url, function(v) return nonempty(v) and v:match("^https?://[^%s]+$") ~= nil end, path..".url")
                    optionalType(source.title, "string", path..".title")
                    optionalType(source.reviewedAt, "string", path..".reviewedAt")
                    optionalType(source.revision, "string", path..".revision")
                    optionalType(source.notes, "string", path..".notes")
                end
            end
        end
        if list(envelope.dependencies, "$.dependencies", false) and #envelope.dependencies > 0 then
            issue("unsupported-dependencies", "$.dependencies", "warning", "unsupported")
        end
    end
    local condition, declaredConditions
    local function tableConditions(value, schema, path)
        if schema[1] ~= nil then
            for i, child in ipairs(value) do declaredConditions(child, schema, path.."["..i.."]") end
        else
            for _, key in ipairs(sortedKeys(value)) do declaredConditions(value[key], schema[key], path.."."..key) end
        end
    end
    declaredConditions = function(value, schema, path)
        if schema == "condition" then condition(value, path)
        elseif schema == "condition[]" then
            for i, child in ipairs(value) do condition(child, path.."["..i.."]") end
        elseif type(schema) == "table" then
            if schema[1] == nil then tableConditions(value, schema, path)
            else
                for _, alternative in ipairs(schema) do
                    if type(alternative) == "table" then
                        if matchesTable(value, alternative, 0) then tableConditions(value, alternative, path);return end
                    elseif matchesType(value, alternative) then declaredConditions(value, alternative, path);return end
                end
            end
        end
    end
    condition = function(value, path)
        if value == nil then return end
        if not object(value, path) then return end
        if next(value) == nil then return end
        if not check(value.type, nonempty, path..".type") then return end
        optionalType(value.disabled, "boolean", path..".disabled")
        if value.type=="AND" or value.type=="OR" or value.type=="NOT" then
            if value.name~=nil and (type(value.name)~="string" or #value.name>512 or value.name:find("%c")) then
                issue("invalid-group-name",path..".name","error")
            end
        end
        if value.type == "AND" or value.type == "OR" then
            unknown(value, {type=true,disabled=true,value=true,name=true}, path)
            if list(value.value, path..".value", true) then
                for i, child in ipairs(value.value) do condition(child, path..".value["..i.."]") end
            end
        elseif value.type == "NOT" then
            unknown(value, {type=true,disabled=true,value=true,name=true}, path)
            if object(value.value, path..".value") then condition(value.value, path..".value") end
        else
            local definition = options.conditions and options.conditions[value.type]
            if type(definition) ~= "table" or type(definition.fields) ~= "table" then
                issue("unknown-condition", path..".type", "warning", "unresolved");return
            end
            if definition.disabled then issue('disabled-condition',path..'.type','warning','unresolved') end
            if definition.functionUnavailable then issue('unavailable-function',path..'.type','warning','unresolved') end
            for _, key in ipairs(sortedKeys(value)) do
                if key ~= "type" and key ~= "disabled" then
                    if definition.fields[key] == nil then issue("unknown-field", path.."."..key, "warning", "unsupported")
                    elseif not matchesType(value[key], definition.fields[key]) then issue("invalid-field-type", path.."."..key, "error")
                    else declaredConditions(value[key], definition.fields[key], path.."."..key) end
                end
            end
            for _, key in ipairs(definition.requiredFields or {}) do
                if value[key] == nil then issue("missing-field", path.."."..key, "error") end
            end
        end
    end
    if not object(envelope.body, "$.body") then return finish() end
    local body = envelope.body
    unknown(body, {name=true,description=true,metadata=true,tags=true,revision=true,priority=true,disabled=true,switch=true,rotation=true,cooldowns=true}, "$.body")
    if not data.GetRotationPriority(body.priority) then issue('invalid-priority','$.body.priority','error') end
    if body.revision~=nil then check(body.revision, function(v) return type(v)=="number" and v>=1 and v<=9007199254740991 and v%1==0 end, "$.body.revision") end
    optionalType(body.name, "string", "$.body.name")
    optionalType(body.description,"string","$.body.description")
    if body.tags~=nil and not data.NormalizeRotationTags(body.tags) then issue("invalid-tags","$.body.tags","error") end
    if body.metadata~=nil and object(body.metadata,"$.body.metadata") then
        local allowed={author=true,realm=true,email=true,website=true,version=true}
        unknown(body.metadata,allowed,"$.body.metadata")
        for key in pairs(allowed) do optionalType(body.metadata[key],"string","$.body.metadata."..key) end
    end
    optionalType(body.disabled, "boolean", "$.body.disabled")
    condition(body.switch, "$.body.switch")
    local rootsValid=true
    for _,key in ipairs({"rotation","cooldowns"}) do if not list(body[key],"$.body."..key,true) then rootsValid=false end end
    if not rootsValid then return finish() end
    -- Pure validation preserves future branch metadata as unsupported. Runtime
    -- indexing remains strict, so these records cannot silently execute.
    local tree,problem=data.IndexRotationSteps(body,{allowUnknownBranchFields=true})
    if not tree then issue(problem.code,"$.body"..problem.path:sub(2),"error");return finish() end
    for _,row in ipairs(tree.rows) do
        local step,where=row.step,"$.body"
        for _,key in ipairs(row.path) do where=where..(type(key)=="number" and "["..key.."]" or "."..key) end
        if step.type=="branch" then
            unknown(step,{id=true,type=true,mode=true,name=true,conditions=true,onTrue=true,onFalse=true},where)
            optionalType(step.name,"string",where..".name")
        else
            unknown(step, {id=true,type=true,action=true,ranked=true,name=true,use_name=true,disabled=true,conditions=true,suppress_attack=true,
                effect=true,color=true,magnification=true,setpoint=true,xoffs=true,yoffs=true,announce=true,announce_sound=true}, where)
            if check(step.type, nonempty, where..".type") then
                if step.type == "spell" or step.type == "pet" or step.type == "any" then
                    check(step.action, function(v) return integer(v, 1) end, where..".action")
                elseif step.type == "item" then
                    if type(step.action) == "string" then
                        if check(step.action, identifier, where..".action") and not (options.itemsets and options.itemsets[step.action]) then
                            issue("missing-itemset", where..".action", "warning", "unresolved")
                        end
                    elseif list(step.action, where..".action", true) then
                        if #step.action == 0 then issue("empty-item-list", where..".action", "error") end
                        for j, item in ipairs(step.action) do check(item,function(v) return integer(v,1) or nonempty(v) end,where..".action["..j.."]") end
                    end
                elseif step.type ~= "none" then issue("unknown-action-type", where..".type", "warning", "unsupported") end
            end
            for _,flag in ipairs({"ranked","use_name","disabled"}) do optionalType(step[flag],"boolean",where.."."..flag) end
            optionalType(step.suppress_attack,"boolean",where..".suppress_attack")
            if step.suppress_attack~=nil and step.type~="none" then issue("unexpected-stop-option",where..".suppress_attack","warning","unsupported") end
            for _,label in ipairs({"name","effect","setpoint","announce","announce_sound"}) do optionalType(step[label],"string",where.."."..label) end
            for _,number in ipairs({"magnification","xoffs","yoffs"}) do optionalType(step[number],"number",where.."."..number) end
            if step.effect and not (options.effects and options.effects[step.effect]) then issue("missing-effect",where..".effect","warning","unresolved") end
            if step.color~=nil and object(step.color,where..".color") then
                unknown(step.color,{r=true,g=true,b=true,a=true},where..".color")
                for _,channel in ipairs({"r","g","b","a"}) do check(step.color[channel],function(v) return type(v)=="number" and v>=0 and v<=1 end,where..".color."..channel) end
            end
        end
        condition(step.conditions,where..".conditions")
    end
    return finish()
end

function data.ValidateEnvelope(envelope,options)
    return validate(envelope,options,false)
end
function data.ValidateBody(body,options)
    return validate({body=body},options,true)
end
]======]},
 ['Data/diff.lua']={old=[======[local _, addon = ...
local data = addon.RotationData

local function failure(code, path)
    return {valid=false,complete=false,changes={},diagnostics={{code=code,path=path or "$",severity="error"}}}
end
local function keys(left, right)
    local seen, result = {}, {}
    for key in pairs(left) do seen[key]=true;result[#result+1]=key end
    for key in pairs(right) do if not seen[key] then result[#result+1]=key end end
    table.sort(result, function(a,b)
        if type(a)==type(b) then return a<b end
        return type(a)=="number"
    end)
    return result
end
local function validId(value)
    return type(value)=="string" and #value>0 and #value<=128 and value:match("^[%w][%w._:%-]*$")~=nil
end
local function index(list, origins, path)
    if list == nil then list={} end
    if type(list)~="table" then return nil,"invalid-priority-list",path end
    if origins~=nil and type(origins)~="table" then return nil,"invalid-origin-map",path end
    local count, maximum = 0, 0
    for key in pairs(list) do
        if type(key)~="number" or key<1 or key%1~=0 then return nil,"invalid-priority-list",path end
        count,maximum=count+1,math.max(maximum,key)
    end
    if maximum~=count then return nil,"invalid-priority-list",path end
    local result={ordered={},byId={}}
    for i, step in ipairs(list) do
        if type(step)~="table" or not validId(step.id) then return nil,"ambiguous-step-identity",path.."["..i.."]" end
        local canonical=origins and origins[step.id] or step.id
        if not validId(canonical) or result.byId[canonical] then return nil,"ambiguous-step-identity",path.."["..i.."]" end
        local entry={id=canonical,index=i,value=step}
        result.ordered[#result.ordered+1]=entry;result.byId[canonical]=entry
    end
    return result
end

-- Unique IDs reduce the common subsequence problem to a longest increasing
-- subsequence of original positions: bounded O(n log n), no n-by-n matrix.
local function stationary(left, right)
    local sequence={}
    for _,entry in ipairs(right.ordered) do
        local original=left.byId[entry.id]
        if original then sequence[#sequence+1]={id=entry.id,position=original.index} end
    end
    local tails,tailIndices,previous={},{},{}
    for i,entry in ipairs(sequence) do
        local low,high=1,#tails
        while low<=high do
            local middle=math.floor((low+high)/2)
            if tails[middle]<entry.position then low=middle+1 else high=middle-1 end
        end
        previous[i]=tailIndices[low-1]
        tails[low],tailIndices[low]=entry.position,i
    end
    local result,cursor={},tailIndices[#tails]
    while cursor do result[sequence[cursor].id]=true;cursor=previous[cursor] end
    return result
end

-- Structural segments drive list dispatch and ancestry. Rendered text is only
-- for display: a literal dotted key must never impersonate a nested field.
local function child(segments, kind, key)
    local result={}
    for i,segment in ipairs(segments) do result[i]=segment end
    result[#result+1]={kind=kind,key=key}
    return result
end
local function fieldSuffix(key)
    if type(key)=="number" then return "["..key.."]" end
    if key:match("^[%a_][%w_]*$") then return "."..key end
    return "["..string.format("%q",key).."]"
end
local function ancestor(a,b)
    if #a>=#b then return false end
    for i,segment in ipairs(a) do
        if segment.kind~=b[i].kind or segment.key~=b[i].key then return false end
    end
    return true
end

function data.DiffRotations(left, right, options)
    options=options or {}
    for _,value in ipairs({left,right}) do
        local ok,why=data.CheckPortable(value)
        if not ok then return failure(why.code,why.path) end
        if type(value)~="table" then return failure("expected-rotation-object") end
    end
    if left==nil or right==nil then return failure("expected-rotation-object") end
    local lists={left={},right={}}
    local empty=index(nil,nil,"$")
    for _,side in ipairs({"left","right"}) do
        local envelope=side=="left" and left or right
        local origins=options[side.."Origins"]
        if not data.CheckPortable(origins) or origins~=nil and type(origins)~="table" then return failure("invalid-origin-map") end
        local body=type(envelope.body)=="table" and envelope.body or {}
        -- Keep the established diagnostics for malformed flat priority lists.
        for _,kind in ipairs({"rotation","cooldowns"}) do
            local indexed,code,path=index(body[kind],origins,"$.body."..kind)
            if not indexed then return failure(code,path) end
        end
        local tree,problem=data.IndexRotationSteps(body)
        if not tree then
            local code=problem.code
            if code=="duplicate-step-id" or code=="invalid-step-id" then code="ambiguous-step-identity" end
            return failure(code,problem.path)
        end
        local used={}
        for _,list in ipairs(tree.lists) do
            local indexed,code,path=index(list.list,origins,"$.body")
            if not indexed then return failure(code,path) end
            for _,entry in ipairs(indexed.ordered) do
                if used[entry.id] then return failure("ambiguous-step-identity","$.body") end
                used[entry.id]=true
            end
            lists[side][list.list]=indexed
        end
    end
    local result={valid=true,complete=true,changes={},diagnostics={}}
    local limits={}
    local function limited(code)
        result.complete=false
        if not limits[code] then
            limits[code]=true
            result.diagnostics[#result.diagnostics+1]={code=code,path="$",severity="warning"}
        end
    end
    local function emit(kind,path,segments,before,after,extra)
        if #path>4096 then limited("diff-path-limit");return end
        if #result.changes>=500 then limited("diff-change-limit");return end
        local change={kind=kind,path=path,segments=data.CopyData(segments)}
        if before~=nil then change.before=data.CopyData(before) end
        if after~=nil then change.after=data.CopyData(after) end
        for key,value in pairs(extra or {}) do change[key]=value end
        result.changes[#result.changes+1]=change
    end
    local walk
    local function priorities(leftList,rightList,path,segments)
        local a,b=lists.left[leftList] or empty,lists.right[rightList] or empty
        local stable=stationary(a,b)
        for _,entry in ipairs(a.ordered) do
            if not b.byId[entry.id] then emit("removed",path.."["..entry.id.."]",child(segments,"step",entry.id),entry.value,nil,{stepId=entry.id,fromIndex=entry.index}) end
        end
        for _,entry in ipairs(b.ordered) do
            local original=a.byId[entry.id]
            local where=path.."["..entry.id.."]"
            local location=child(segments,"step",entry.id)
            if not original then emit("added",where,location,nil,entry.value,{stepId=entry.id,toIndex=entry.index})
            else
                if not stable[entry.id] then emit("moved",where,location,nil,nil,{stepId=entry.id,fromIndex=original.index,toIndex=entry.index}) end
                walk(original.value,entry.value,where,location,true)
            end
        end
    end
    walk=function(a,b,path,segments,step)
        if #path>4096 then limited("diff-path-limit");return end
        if a==b then return end
        if #segments==2 and segments[1].kind=="field" and segments[1].key=="body"
            and segments[2].kind=="field" and (segments[2].key=="rotation" or segments[2].key=="cooldowns") then
            priorities(a,b,path,segments);return
        end
        if type(a)~="table" or type(b)~="table" then
            emit(a==nil and "added" or b==nil and "removed" or "changed",path,segments,a,b)
            return
        end
        for _,key in ipairs(keys(a,b)) do
            if not (step and key=="id") and not (#segments==0 and options.ignoreIdentity and (key=="id" or key=="revision")) then
                local where,location=path..fieldSuffix(key),child(segments,"field",key)
                if step and (a.type=="branch" or b.type=="branch") and (key=="onTrue" or key=="onFalse") then
                    priorities(a[key],b[key],where,location)
                else walk(a[key],b[key],where,location,false) end
            end
        end
    end
    walk(left,right,"$",{},false)
    return result
end

local function equal(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for _,key in ipairs(keys(a,b)) do if not equal(a[key],b[key]) then return false end end
    return true
end

function data.CompareClone(clone, source)
    if type(clone)~="table" or type(source)~="table" or getmetatable(clone) or getmetatable(source) then return failure("invalid-comparison-view") end
    for _,view in ipairs({clone,source}) do
        local ok,why=data.CheckPortable(view.envelope)
        if not ok then return failure(why.code,why.path) end
        if type(view.envelope)~="table" then return failure("expected-rotation-object") end
    end
    local lineage,problem=data.CopyData(clone.lineage)
    if problem or type(lineage)~="table" or type(lineage.baseline)~="table" or type(lineage.stepOrigins)~="table" then
        return failure("invalid-lineage")
    end
    local reference=source.reference
    if type(reference)~="table" or getmetatable(reference) or reference.kind~=lineage.sourceKind
        or reference.id~=lineage.sourceId or source.envelope.id~=lineage.sourceId then return failure("source-lineage-mismatch") end
    if lineage.baseline.id~=lineage.sourceId or lineage.baseline.revision~=lineage.sourceRevision then return failure("invalid-lineage") end
    local fromSource=data.DiffRotations(lineage.baseline,source.envelope,{ignoreIdentity=true})
    local fromCustom=data.DiffRotations(lineage.baseline,clone.envelope,{rightOrigins=lineage.stepOrigins,ignoreIdentity=true})
    local current=data.DiffRotations(source.envelope,clone.envelope,{rightOrigins=lineage.stepOrigins,ignoreIdentity=true})
    local result={valid=fromSource.valid and fromCustom.valid and current.valid,
        complete=fromSource.complete and fromCustom.complete and current.complete,
        sourceChanges=fromSource,customChanges=fromCustom,currentDifferences=current,conflicts={},
        conflictCoverage="field-edits",diagnostics={}}
    -- Highlight overlapping field edits for review. Ordered changes remain
    -- explicit in all three diffs; this is not an automatic merge algorithm.
    for _,a in ipairs(fromSource.changes) do
        for _,b in ipairs(fromCustom.changes) do
            local conflict=false
            if a.kind~="moved" and b.kind~="moved" then
                if a.path==b.path then conflict=a.kind~=b.kind or not equal(a.after,b.after)
                elseif ancestor(a.segments,b.segments) or ancestor(b.segments,a.segments) then conflict=true end
            end
            if conflict then
                if #result.conflicts>=100 then
                    result.complete=false
                    if #result.diagnostics==0 then result.diagnostics[1]={code="conflict-limit",path="$",severity="warning"} end
                else result.conflicts[#result.conflicts+1]={path=a.path,source=data.CopyData(a),custom=data.CopyData(b)} end
            end
        end
    end
    return result
end
]======],current=[======[local _, addon = ...
local data = addon.RotationData

local function failure(code, path)
    return {valid=false,complete=false,changes={},diagnostics={{code=code,path=path or "$",severity="error"}}}
end
local function keys(left, right)
    local seen, result = {}, {}
    for key in pairs(left) do seen[key]=true;result[#result+1]=key end
    for key in pairs(right) do if not seen[key] then result[#result+1]=key end end
    table.sort(result, function(a,b)
        if type(a)==type(b) then return a<b end
        return type(a)=="number"
    end)
    return result
end
local function validId(value)
    return type(value)=="string" and #value>0 and #value<=128 and value:match("^[%w][%w._:%-]*$")~=nil
end
local function index(list, origins, path)
    if list == nil then list={} end
    if type(list)~="table" then return nil,"invalid-priority-list",path end
    if origins~=nil and type(origins)~="table" then return nil,"invalid-origin-map",path end
    local count, maximum = 0, 0
    for key in pairs(list) do
        if type(key)~="number" or key<1 or key%1~=0 then return nil,"invalid-priority-list",path end
        count,maximum=count+1,math.max(maximum,key)
    end
    if maximum~=count then return nil,"invalid-priority-list",path end
    local result={ordered={},byId={}}
    for i, step in ipairs(list) do
        if type(step)~="table" or not validId(step.id) then return nil,"ambiguous-step-identity",path.."["..i.."]" end
        local canonical=origins and origins[step.id] or step.id
        if not validId(canonical) or result.byId[canonical] then return nil,"ambiguous-step-identity",path.."["..i.."]" end
        local entry={id=canonical,index=i,value=step}
        result.ordered[#result.ordered+1]=entry;result.byId[canonical]=entry
    end
    return result
end

-- Unique IDs reduce the common subsequence problem to a longest increasing
-- subsequence of original positions: bounded O(n log n), no n-by-n matrix.
local function stationary(left, right)
    local sequence={}
    for _,entry in ipairs(right.ordered) do
        local original=left.byId[entry.id]
        if original then sequence[#sequence+1]={id=entry.id,position=original.index} end
    end
    local tails,tailIndices,previous={},{},{}
    for i,entry in ipairs(sequence) do
        local low,high=1,#tails
        while low<=high do
            local middle=math.floor((low+high)/2)
            if tails[middle]<entry.position then low=middle+1 else high=middle-1 end
        end
        previous[i]=tailIndices[low-1]
        tails[low],tailIndices[low]=entry.position,i
    end
    local result,cursor={},tailIndices[#tails]
    while cursor do result[sequence[cursor].id]=true;cursor=previous[cursor] end
    return result
end

-- Structural segments drive list dispatch and ancestry. Rendered text is only
-- for display: a literal dotted key must never impersonate a nested field.
local function child(segments, kind, key)
    local result={}
    for i,segment in ipairs(segments) do result[i]=segment end
    result[#result+1]={kind=kind,key=key}
    return result
end
local function fieldSuffix(key)
    if type(key)=="number" then return "["..key.."]" end
    if key:match("^[%a_][%w_]*$") then return "."..key end
    return "["..string.format("%q",key).."]"
end
local function ancestor(a,b)
    if #a>=#b then return false end
    for i,segment in ipairs(a) do
        if segment.kind~=b[i].kind or segment.key~=b[i].key then return false end
    end
    return true
end

function data.DiffRotations(left, right, options)
    options=options or {}
    for _,value in ipairs({left,right}) do
        local ok,why=data.CheckPortable(value)
        if not ok then return failure(why.code,why.path) end
        if type(value)~="table" then return failure("expected-rotation-object") end
    end
    if left==nil or right==nil then return failure("expected-rotation-object") end
    local lists={left={},right={}}
    local empty=index(nil,nil,"$")
    for _,side in ipairs({"left","right"}) do
        local envelope=side=="left" and left or right
        local origins=options[side.."Origins"]
        if not data.CheckPortable(origins) or origins~=nil and type(origins)~="table" then return failure("invalid-origin-map") end
        local body=type(envelope.body)=="table" and envelope.body or {}
        -- Keep the established diagnostics for malformed flat priority lists.
        for _,kind in ipairs({"rotation","cooldowns"}) do
            local indexed,code,path=index(body[kind],origins,"$.body."..kind)
            if not indexed then return failure(code,path) end
        end
        local tree,problem=data.IndexRotationSteps(body)
        if not tree then
            local code=problem.code
            if code=="duplicate-step-id" or code=="invalid-step-id" then code="ambiguous-step-identity" end
            return failure(code,problem.path)
        end
        local used={}
        for _,list in ipairs(tree.lists) do
            local indexed,code,path=index(list.list,origins,"$.body")
            if not indexed then return failure(code,path) end
            for _,entry in ipairs(indexed.ordered) do
                if used[entry.id] then return failure("ambiguous-step-identity","$.body") end
                used[entry.id]=true
            end
            lists[side][list.list]=indexed
        end
    end
    local result={valid=true,complete=true,changes={},diagnostics={}}
    local limits={}
    local function limited(code)
        result.complete=false
        if not limits[code] then
            limits[code]=true
            result.diagnostics[#result.diagnostics+1]={code=code,path="$",severity="warning"}
        end
    end
    local function emit(kind,path,segments,before,after,extra)
        if #path>4096 then limited("diff-path-limit");return end
        if #result.changes>=500 then limited("diff-change-limit");return end
        local change={kind=kind,path=path,segments=data.CopyData(segments)}
        if before~=nil then change.before=data.CopyData(before) end
        if after~=nil then change.after=data.CopyData(after) end
        for key,value in pairs(extra or {}) do change[key]=value end
        result.changes[#result.changes+1]=change
    end
    local walk
    local function priorities(leftList,rightList,path,segments)
        local a,b=lists.left[leftList] or empty,lists.right[rightList] or empty
        local stable=stationary(a,b)
        for _,entry in ipairs(a.ordered) do
            if not b.byId[entry.id] then emit("removed",path.."["..entry.id.."]",child(segments,"step",entry.id),entry.value,nil,{stepId=entry.id,fromIndex=entry.index}) end
        end
        for _,entry in ipairs(b.ordered) do
            local original=a.byId[entry.id]
            local where=path.."["..entry.id.."]"
            local location=child(segments,"step",entry.id)
            if not original then emit("added",where,location,nil,entry.value,{stepId=entry.id,toIndex=entry.index})
            else
                if not stable[entry.id] then emit("moved",where,location,nil,nil,{stepId=entry.id,fromIndex=original.index,toIndex=entry.index}) end
                walk(original.value,entry.value,where,location,true)
            end
        end
    end
    walk=function(a,b,path,segments,step)
        if #path>4096 then limited("diff-path-limit");return end
        if a==b then return end
        if #segments==2 and segments[1].kind=="field" and segments[1].key=="body"
            and segments[2].kind=="field" and (segments[2].key=="rotation" or segments[2].key=="cooldowns") then
            priorities(a,b,path,segments);return
        end
        if type(a)~="table" or type(b)~="table" then
            emit(a==nil and "added" or b==nil and "removed" or "changed",path,segments,a,b)
            return
        end
        for _,key in ipairs(keys(a,b)) do
            if not (step and key=="id") and not (#segments==0 and options.ignoreIdentity and (key=="id" or key=="revision"))
                and not (#segments==1 and segments[1].kind=="field" and segments[1].key=="body" and key=="revision") then
                local where,location=path..fieldSuffix(key),child(segments,"field",key)
                if step and (a.type=="branch" or b.type=="branch") and (key=="onTrue" or key=="onFalse") then
                    priorities(a[key],b[key],where,location)
                else walk(a[key],b[key],where,location,false) end
            end
        end
    end
    walk(left,right,"$",{},false)
    return result
end

local function equal(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for _,key in ipairs(keys(a,b)) do if not equal(a[key],b[key]) then return false end end
    return true
end

function data.CompareClone(clone, source)
    if type(clone)~="table" or type(source)~="table" or getmetatable(clone) or getmetatable(source) then return failure("invalid-comparison-view") end
    for _,view in ipairs({clone,source}) do
        local ok,why=data.CheckPortable(view.envelope)
        if not ok then return failure(why.code,why.path) end
        if type(view.envelope)~="table" then return failure("expected-rotation-object") end
    end
    local lineage,problem=data.CopyData(clone.lineage)
    if problem or type(lineage)~="table" or type(lineage.baseline)~="table" or type(lineage.stepOrigins)~="table" then
        return failure("invalid-lineage")
    end
    local reference=source.reference
    if type(reference)~="table" or getmetatable(reference) or reference.kind~=lineage.sourceKind
        or reference.id~=lineage.sourceId or source.envelope.id~=lineage.sourceId then return failure("source-lineage-mismatch") end
    if lineage.baseline.id~=lineage.sourceId or lineage.baseline.revision~=lineage.sourceRevision then return failure("invalid-lineage") end
    local fromSource=data.DiffRotations(lineage.baseline,source.envelope,{ignoreIdentity=true})
    local fromCustom=data.DiffRotations(lineage.baseline,clone.envelope,{rightOrigins=lineage.stepOrigins,ignoreIdentity=true})
    local current=data.DiffRotations(source.envelope,clone.envelope,{rightOrigins=lineage.stepOrigins,ignoreIdentity=true})
    local result={valid=fromSource.valid and fromCustom.valid and current.valid,
        complete=fromSource.complete and fromCustom.complete and current.complete,
        sourceChanges=fromSource,customChanges=fromCustom,currentDifferences=current,conflicts={},
        conflictCoverage="field-edits",diagnostics={}}
    -- Highlight overlapping field edits for review. Ordered changes remain
    -- explicit in all three diffs; this is not an automatic merge algorithm.
    for _,a in ipairs(fromSource.changes) do
        for _,b in ipairs(fromCustom.changes) do
            local conflict=false
            if a.kind~="moved" and b.kind~="moved" then
                if a.path==b.path then conflict=a.kind~=b.kind or not equal(a.after,b.after)
                elseif ancestor(a.segments,b.segments) or ancestor(b.segments,a.segments) then conflict=true end
            end
            if conflict then
                if #result.conflicts>=100 then
                    result.complete=false
                    if #result.diagnostics==0 then result.diagnostics[1]={code="conflict-limit",path="$",severity="warning"} end
                else result.conflicts[#result.conflicts+1]={path=a.path,source=data.CopyData(a),custom=data.CopyData(b)} end
            end
        end
    end
    return result
end
]======]},
 ['Data/catalog.lua']={old=[======[local _, addon = ...
local data = addon.RotationData

local function id(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end
local function steps(envelope, callback)
    if type(envelope) ~= "table" or type(envelope.body) ~= "table" then return end
    local index,why=data.IndexRotationSteps(envelope.body)
    if not index then return nil,why end
    for _,row in ipairs(index.rows) do callback(row.step) end
    return true
end
local function validLineage(value)
    if type(value) ~= "table" or not id(value.sourceId) or
        (value.sourceKind ~= "builtin" and value.sourceKind ~= "custom") or
        type(value.sourceRevision) ~= "number" or value.sourceRevision < 1 or value.sourceRevision % 1 ~= 0 or
        type(value.baseline) ~= "table" or value.baseline.format ~= "RotationMaster" or value.baseline.schemaVersion ~= 1 or
        value.baseline.id ~= value.sourceId or
        value.baseline.revision ~= value.sourceRevision or type(value.stepOrigins) ~= "table" then return false end
    -- Validate historical envelope structure independently of today's condition
    -- catalog. An unavailable old condition must not erase source evidence.
    if not data.ValidateEnvelope(value.baseline).valid then return false end
    local baselineIds = {}
    if not steps(value.baseline, function(step) baselineIds[step.id] = true end) then return false end
    for key, origin in pairs(value.stepOrigins) do
        if not id(key) or not id(origin) or not baselineIds[origin] then return false end
    end
    return true
end

-- State is the catalog's SavedVariables namespace, not an entire legacy profile.
-- Validation catalogs/newId are trusted application dependencies.
function data.NewCatalog(options)
    options = options or {}
    local state = options.state
    if state == nil then state = {} end
    if type(state) ~= "table" or getmetatable(state) ~= nil then return nil, "invalid-catalog-state" end
    for _, key in ipairs({"custom", "preferences", "lineage"}) do
        if state[key] ~= nil and (type(state[key]) ~= "table" or getmetatable(state[key]) ~= nil) then return nil, "invalid-catalog-state" end
    end
    if state.custom then
        for key in pairs(state.custom) do if not id(key) then return nil, "invalid-custom-id" end end
    end
    state.custom, state.preferences, state.lineage = state.custom or {}, state.preferences or {}, state.lineage or {}
    local builtins, withdrawn = {}, {}
    local catalog = {}

    local function resolve(reference)
        if type(reference) == "table" then
            if (reference.kind == "builtin" or reference.kind == "custom") and id(reference.id) then
                return reference.kind, reference.id
            end
        elseif id(reference) then
            return builtins[reference] and "builtin" or "custom", reference
        end
    end
    local function owned(reference)
        local kind, key = resolve(reference)
        if kind == "builtin" then return nil, "read-only" end
        if not key or state.custom[key] == nil then return nil, "unknown-rotation" end
        return key
    end
    local function enabled(kind, key, envelope)
        if kind == "builtin" then
            if withdrawn[key] then return false end
            local preference = state.preferences[key]
            if preference ~= nil then
                if type(preference) ~= "table" or getmetatable(preference) ~= nil or type(preference.enabled) ~= "boolean" then return false end
                return preference.enabled
            end
        end
        return type(envelope) == "table" and type(envelope.body) == "table" and envelope.body.disabled ~= true
    end
    local function snapshot(kind, key, summary)
        local source
        if kind == "builtin" then source = builtins[key] else source = state.custom[key] end
        if source == nil then return nil end
        local validation = data.ValidateEnvelope(source, options.validation)
        local cleanSource, copyError = data.CopyData(source)
        if type(cleanSource) == "table" and cleanSource.id ~= key then
            validation.valid, validation.executionStatus = false, "unavailable"
            if #validation.diagnostics < 100 then
                validation.diagnostics[#validation.diagnostics+1] = {code="catalog-id-mismatch",path="$.id",severity="error"}
            end
        end
        local view = {id=key, reference={kind=kind,id=key}, builtin=kind == "builtin", readOnly=kind == "builtin",
            enabled=validation.valid and not copyError and enabled(kind,key,cleanSource), validation=validation,
            withdrawn=withdrawn[key] ~= nil and kind == "builtin"}
        if view.withdrawn then view.withdrawalReason = withdrawn[key] end
        if type(cleanSource) == "table" then
            view.nameKey = type(cleanSource.nameKey) == "string" and cleanSource.nameKey ~= "" and cleanSource.nameKey or nil
            view.descriptionKey = type(cleanSource.descriptionKey) == "string" and cleanSource.descriptionKey ~= "" and cleanSource.descriptionKey or nil
            local revision = cleanSource.revision
            view.revision = type(revision) == "number" and revision >= 1 and revision % 1 == 0 and revision or nil
            if validation.valid and cleanSource.schemaVersion == 1 then
                view.applicability, view.tags = data.CopyData(cleanSource.applicability), data.CopyData(cleanSource.tags)
            end
        end
        if not summary then
            view.envelope, view.dataError = cleanSource, copyError
            if kind == "custom" and state.lineage[key] ~= nil then
                local lineage, problem = data.CopyData(state.lineage[key])
                if not problem and validLineage(lineage) then view.lineage = lineage
                else view.lineageError = {code="invalid-lineage",path="lineage",severity="error"} end
            end
        end
        return view
    end
    local function storable(envelope, structuralOnly)
        local validation = data.ValidateEnvelope(envelope, not structuralOnly and options.validation or nil)
        if not validation.valid or not id(envelope.id) or type(envelope.revision) ~= "number"
            or envelope.revision < 1 or envelope.revision % 1 ~= 0 then return nil, "invalid-envelope", validation end
        local copy, why = data.CopyData(envelope)
        if not copy then return nil, why.code, validation end
        return copy
    end

    function catalog:RegisterBuiltin(envelope)
        -- A changed extension schema can invalidate an otherwise intact shipped
        -- definition. Retain its source; snapshots expose current diagnostics and
        -- runtime eligibility keeps it inert. Custom saves remain strictly checked.
        local copy, why, validation = storable(envelope, true)
        if not copy then return false, why, validation end
        local previous = builtins[copy.id]
        if previous and copy.revision <= previous.revision then return false, "revision-not-newer" end
        builtins[copy.id] = copy
        return true
    end
    function catalog:Get(reference)
        local kind, key = resolve(reference)
        if not key then return nil end
        return snapshot(kind, key, false)
    end
    function catalog:List()
        local rows = {}
        for key in pairs(builtins) do rows[#rows+1] = snapshot("builtin", key, true) end
        for key in pairs(state.custom) do rows[#rows+1] = snapshot("custom", key, true) end
        table.sort(rows, function(a,b)
            if a.id == b.id then return a.builtin and not b.builtin end
            return a.id < b.id
        end)
        return rows
    end
    function catalog:SetEnabled(reference, value)
        if type(value) ~= "boolean" then return false, "invalid-enabled-value" end
        local kind, key = resolve(reference)
        if not key then return false, "unknown-rotation" end
        if kind == "builtin" then
            if not builtins[key] then return false, "unknown-rotation" end
            if withdrawn[key] then return false, "withdrawn-built-in" end
            if type(state.preferences[key]) == "table" and getmetatable(state.preferences[key]) ~= nil then
                return false, "invalid-preference"
            end
            if type(state.preferences[key]) ~= "table" then state.preferences[key] = {} end
            state.preferences[key].enabled = value
            return true
        end
        local view = self:Get(reference)
        if not view then return false, "unknown-rotation" end
        if not view.validation.valid or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.body.disabled = not value
        return self:Save(reference, view.envelope)
    end
    function catalog:Save(reference, envelope)
        local key, why = owned(reference)
        if not key then return false, why end
        local copy, reason, validation = storable(envelope)
        if not copy then return false, reason, validation end
        if copy.id ~= key then return false, "id-mismatch" end
        local previous = state.custom[key]
        if copy.schemaVersion == 1 then
            local revision = type(previous) == "table" and previous.revision
            if type(revision) == "number" and revision >= 1 and revision < 9007199254740991 and revision % 1 == 0 then
                copy.revision = revision+1
            else copy.revision = 1 end
        end
        state.custom[key] = copy
        return true
    end
    function catalog:AddCustom(envelope)
        local copy, why, validation = storable(envelope)
        if not copy then return false, why, validation end
        if builtins[copy.id] then return false, "read-only" end
        if state.custom[copy.id] ~= nil then return false, "duplicate-id" end
        state.custom[copy.id] = copy
        return true
    end
    function catalog:Rename(reference, name)
        local key, why = owned(reference)
        if not key then return false, why end
        if type(name) ~= "string" or name == "" then return false, "invalid-name" end
        local view = self:Get({kind="custom",id=key})
        if not view.envelope or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.nameKey, view.envelope.body.name = name, name
        return self:Save({kind="custom",id=key}, view.envelope)
    end
    function catalog:Delete(reference)
        local key, why = owned(reference)
        if not key then return false, why end
        state.custom[key], state.lineage[key] = nil, nil
        return true
    end
    function catalog:WithdrawBuiltin(reference, reason)
        local kind, key = resolve(reference)
        if kind ~= "builtin" or not builtins[key] then return false, "unknown-built-in" end
        if type(reason) ~= "string" or reason == "" then return false, "missing-withdrawal-reason" end
        withdrawn[key] = reason
        return true
    end
    function catalog:Clone(reference, name)
        local source = self:Get(reference)
        if not source then return nil, "unknown-rotation" end
        if source.lineageError then return nil, "invalid-lineage" end
        if not source.validation.valid or not source.envelope or source.envelope.schemaVersion ~= 1 then return nil, "unsupported-source" end
        if type(options.newId) ~= "function" then return nil, "missing-id-provider" end
        if name ~= nil and (type(name) ~= "string" or name == "") then return nil, "invalid-name" end
        local used = {}
        for _, rows in ipairs({builtins,state.custom}) do
            for key, envelope in pairs(rows) do
                used[key] = true
                if data.CheckPortable(envelope) then
                    data.ReserveRotationIdentities(envelope,used)
                end
            end
        end
        for key,retained in pairs(state.lineage) do
            used[key]=true;data.ReserveRotationIdentities(retained,used)
        end
        if source.lineage and type(source.lineage.stepOrigins) == "table" then
            for _, origin in pairs(source.lineage.stepOrigins) do if id(origin) then used[origin] = true end end
        end
        local function fresh()
            local ok, value = pcall(options.newId)
            if not ok or not id(value) then return nil, "invalid-id-provider" end
            if used[value] then return nil, "id-collision" end
            used[value] = true
            return value
        end
        local newId, why = fresh()
        if not newId then return nil, why end
        local clone = source.envelope
        local baseline = source.lineage and source.lineage.baseline or data.CopyData(source.envelope)
        local lineage = {sourceId=source.lineage and source.lineage.sourceId or source.id,
            sourceKind=source.lineage and source.lineage.sourceKind or source.reference.kind,
            sourceRevision=source.lineage and source.lineage.sourceRevision or clone.revision,
            baseline=baseline, stepOrigins={}, clonedFrom=source.id}
        clone.id, clone.revision = newId, 1
        if name then clone.nameKey, clone.body.name = name, name end
        local failed
        local indexed,indexError=steps(clone, function(step)
            if failed then return end
            local original = step.id
            local generated, reason = fresh()
            if not generated then failed = reason;return end
            step.id = generated
            if source.lineage then lineage.stepOrigins[generated] = source.lineage.stepOrigins and source.lineage.stepOrigins[original]
            else lineage.stepOrigins[generated] = original end
        end)
        if not indexed then return nil,indexError and indexError.code or "invalid-priority-list" end
        if failed then return nil, failed end
        local cleanLineage, problem = data.CopyData(lineage)
        if not cleanLineage then return nil, problem.code end
        local ok, reason = self:AddCustom(clone)
        if not ok then return nil, reason end
        state.lineage[newId] = cleanLineage
        return newId
    end
    return catalog
end
]======],current=[======[local _, addon = ...
local data = addon.RotationData

local function id(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end
local function steps(envelope, callback)
    if type(envelope) ~= "table" or type(envelope.body) ~= "table" then return end
    local index,why=data.IndexRotationSteps(envelope.body)
    if not index then return nil,why end
    for _,row in ipairs(index.rows) do callback(row.step) end
    return true
end
local function validLineage(value)
    if type(value) ~= "table" or not id(value.sourceId) or
        (value.sourceKind ~= "builtin" and value.sourceKind ~= "custom") or
        type(value.sourceRevision) ~= "number" or value.sourceRevision < 1 or value.sourceRevision % 1 ~= 0 or
        type(value.baseline) ~= "table" or value.baseline.format ~= "RotationMaster" or value.baseline.schemaVersion ~= 1 or
        value.baseline.id ~= value.sourceId or
        value.baseline.revision ~= value.sourceRevision or type(value.stepOrigins) ~= "table" then return false end
    -- Validate historical envelope structure independently of today's condition
    -- catalog. An unavailable old condition must not erase source evidence.
    if not data.ValidateEnvelope(value.baseline).valid then return false end
    local baselineIds = {}
    if not steps(value.baseline, function(step) baselineIds[step.id] = true end) then return false end
    for key, origin in pairs(value.stepOrigins) do
        if not id(key) or not id(origin) or not baselineIds[origin] then return false end
    end
    return true
end

-- State is the catalog's SavedVariables namespace, not an entire legacy profile.
-- Validation catalogs/newId are trusted application dependencies.
function data.NewCatalog(options)
    options = options or {}
    local state = options.state
    if state == nil then state = {} end
    if type(state) ~= "table" or getmetatable(state) ~= nil then return nil, "invalid-catalog-state" end
    for _, key in ipairs({"custom", "preferences", "lineage"}) do
        if state[key] ~= nil and (type(state[key]) ~= "table" or getmetatable(state[key]) ~= nil) then return nil, "invalid-catalog-state" end
    end
    if state.custom then
        for key in pairs(state.custom) do if not id(key) then return nil, "invalid-custom-id" end end
    end
    state.custom, state.preferences, state.lineage = state.custom or {}, state.preferences or {}, state.lineage or {}
    local builtins, withdrawn = {}, {}
    local catalog = {}

    local function resolve(reference)
        if type(reference) == "table" then
            if (reference.kind == "builtin" or reference.kind == "custom") and id(reference.id) then
                return reference.kind, reference.id
            end
        elseif id(reference) then
            return builtins[reference] and "builtin" or "custom", reference
        end
    end
    local function owned(reference)
        local kind, key = resolve(reference)
        if kind == "builtin" then return nil, "read-only" end
        if not key or state.custom[key] == nil then return nil, "unknown-rotation" end
        return key
    end
    local function enabled(kind, key, envelope)
        if kind == "builtin" then
            if withdrawn[key] then return false end
            local preference = state.preferences[key]
            if preference ~= nil then
                if type(preference) ~= "table" or getmetatable(preference) ~= nil or type(preference.enabled) ~= "boolean" then return false end
                return preference.enabled
            end
        end
        return type(envelope) == "table" and type(envelope.body) == "table" and envelope.body.disabled ~= true
    end
    local function snapshot(kind, key, summary)
        local source
        if kind == "builtin" then source = builtins[key] else source = state.custom[key] end
        if source == nil then return nil end
        local validation = data.ValidateEnvelope(source, options.validation)
        local cleanSource, copyError = data.CopyData(source)
        if type(cleanSource) == "table" and cleanSource.id ~= key then
            validation.valid, validation.executionStatus = false, "unavailable"
            if #validation.diagnostics < 100 then
                validation.diagnostics[#validation.diagnostics+1] = {code="catalog-id-mismatch",path="$.id",severity="error"}
            end
        end
        local view = {id=key, reference={kind=kind,id=key}, builtin=kind == "builtin", readOnly=kind == "builtin",
            enabled=validation.valid and not copyError and enabled(kind,key,cleanSource), validation=validation,
            withdrawn=withdrawn[key] ~= nil and kind == "builtin"}
        if view.withdrawn then view.withdrawalReason = withdrawn[key] end
        if type(cleanSource) == "table" then
            view.nameKey = type(cleanSource.nameKey) == "string" and cleanSource.nameKey ~= "" and cleanSource.nameKey or nil
            view.descriptionKey = type(cleanSource.descriptionKey) == "string" and cleanSource.descriptionKey ~= "" and cleanSource.descriptionKey or nil
            local revision = cleanSource.revision
            view.revision = type(revision) == "number" and revision >= 1 and revision % 1 == 0 and revision or nil
            if validation.valid and cleanSource.schemaVersion == 1 then
                view.applicability, view.tags = data.CopyData(cleanSource.applicability), data.CopyData(cleanSource.tags)
            end
        end
        if not summary then
            view.envelope, view.dataError = cleanSource, copyError
            if kind == "custom" and state.lineage[key] ~= nil then
                local lineage, problem = data.CopyData(state.lineage[key])
                if not problem and validLineage(lineage) then view.lineage = lineage
                else view.lineageError = {code="invalid-lineage",path="lineage",severity="error"} end
            end
        end
        return view
    end
    local function storable(envelope, structuralOnly)
        local validation = data.ValidateEnvelope(envelope, not structuralOnly and options.validation or nil)
        if not validation.valid or not id(envelope.id) or type(envelope.revision) ~= "number"
            or envelope.revision < 1 or envelope.revision % 1 ~= 0 then return nil, "invalid-envelope", validation end
        local copy, why = data.CopyData(envelope)
        if not copy then return nil, why.code, validation end
        return copy
    end

    function catalog:RegisterBuiltin(envelope)
        -- A changed extension schema can invalidate an otherwise intact shipped
        -- definition. Retain its source; snapshots expose current diagnostics and
        -- runtime eligibility keeps it inert. Custom saves remain strictly checked.
        local copy, why, validation = storable(envelope, true)
        if not copy then return false, why, validation end
        local previous = builtins[copy.id]
        if previous and copy.revision <= previous.revision then return false, "revision-not-newer" end
        builtins[copy.id] = copy
        return true
    end
    function catalog:Get(reference)
        local kind, key = resolve(reference)
        if not key then return nil end
        return snapshot(kind, key, false)
    end
    function catalog:List()
        local rows = {}
        for key in pairs(builtins) do rows[#rows+1] = snapshot("builtin", key, true) end
        for key in pairs(state.custom) do rows[#rows+1] = snapshot("custom", key, true) end
        table.sort(rows, function(a,b)
            if a.id == b.id then return a.builtin and not b.builtin end
            return a.id < b.id
        end)
        return rows
    end
    function catalog:SetEnabled(reference, value)
        if type(value) ~= "boolean" then return false, "invalid-enabled-value" end
        local kind, key = resolve(reference)
        if not key then return false, "unknown-rotation" end
        if kind == "builtin" then
            if not builtins[key] then return false, "unknown-rotation" end
            if withdrawn[key] then return false, "withdrawn-built-in" end
            if type(state.preferences[key]) == "table" and getmetatable(state.preferences[key]) ~= nil then
                return false, "invalid-preference"
            end
            if type(state.preferences[key]) ~= "table" then state.preferences[key] = {} end
            state.preferences[key].enabled = value
            return true
        end
        local view = self:Get(reference)
        if not view then return false, "unknown-rotation" end
        if not view.validation.valid or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.body.disabled = not value
        return self:Save(reference, view.envelope)
    end
    -- Authority seals never enter live copy/iteration callbacks. The plain-data
    -- limits match Data/plain; ordinary preparation still uses public helpers.
    local sealType,sealNext,sealRaw,sealMeta,sealEqual,sealInfinity=type,next,rawget,getmetatable,rawequal,math.huge
    local function savedSeal(value)
        local copies,visiting,nodes={},{},0
        local function copy(current,depth)
            nodes=nodes+1
            if nodes>20000 or depth>64 then return nil end
            local kind=sealType(current)
            if kind~='table' then
                if kind=='nil' or kind=='boolean' or kind=='string' then return current end
                if kind=='number' and current==current and current~=sealInfinity and current~=-sealInfinity then return current end
                return nil
            end
            if sealMeta(current)~=nil or visiting[current] then return nil end
            if copies[current] then return copies[current] end
            local result={};copies[current]=result;visiting[current]=true
            for key in sealNext,current do
                nodes=nodes+1
                local keyType=sealType(key)
                if nodes>20000 or not (keyType=='string' or keyType=='number' and key>=1 and key%1==0) then return nil end
                local child=copy(sealRaw(current,key),depth+1)
                if child==nil then return nil end
                result[key]=child
            end
            visiting[current]=nil;return result
        end
        return copy(value,0)
    end
    -- A revision preparation can call overridable copy helpers. Keep the
    -- canonical body exact until that new stage has completed.
    local function sameSavedValue(a,b,mode)
        if sealType(a)~=sealType(b) then return false end
        if sealType(a)~='table' then return a==b end
        if sealMeta(a)~=nil or sealMeta(b)~=nil then return false end
        for key,value in sealNext,a do
            if not (key=='revision' and (mode=='envelope' or mode=='body')) then
                local child=mode=='envelope' and key=='body' and 'body' or 'exact'
                if not sameSavedValue(value,sealRaw(b,key),child) then return false end
            end
        end
        for key in sealNext,b do if not (key=='revision' and (mode=='envelope' or mode=='body')) and sealRaw(a,key)==nil then return false end end
        return true
    end
    function catalog:Save(reference, envelope)
        local key, why = owned(reference)
        if not key then return false, why end
        local copy, reason, validation = storable(envelope)
        if not copy then return false, reason, validation end
        if copy.id ~= key then return false, "id-mismatch" end
        local custom=state.custom
        local previous = custom[key]
        if copy.schemaVersion == 1 then
            local oldBody=sealType(previous)=='table' and sealRaw(previous,'body')
            local baseline
            if type(oldBody)=='table' then
                baseline=savedSeal(previous)
                if not baseline then return false,'invalid-rotation-body' end
            end
            local function unchanged()
                return sealEqual(sealRaw(state,'custom'),custom)
                    and (sealEqual(sealRaw(custom,key),previous) or sealType(previous)=='number' and previous~=previous and sealType(sealRaw(custom,key))=='number' and sealRaw(custom,key)~=sealRaw(custom,key))
                    and (not baseline or sameSavedValue(previous,baseline,'exact'))
            end
            local comparison
            if baseline then
                local problem;comparison,problem=data.CopyData(oldBody)
                if not comparison then return false,problem and problem.code or 'invalid-rotation-body' end
                if not unchanged() then return false,'rotation-changed-externally' end
            end
            local changed=baseline and not sameSavedValue(baseline,copy,'envelope') or false
            local body,problem=data.PrepareRotationContentRevision(copy.body,comparison,type(oldBody)=='table' and 'edit' or 'create',changed)
            if not body then return false,problem end
            if not unchanged() then return false,'rotation-changed-externally' end
            copy.body=body
            local revision = type(previous) == "table" and previous.revision
            if type(revision) == "number" and revision >= 1 and revision < 9007199254740991 and revision % 1 == 0 then
                copy.revision = revision+1
            else copy.revision = 1 end
        end
        state.custom[key] = copy
        return true
    end
    function catalog:AddCustom(envelope)
        local copy, why, validation = storable(envelope)
        if not copy then return false, why, validation end
        if builtins[copy.id] then return false, "read-only" end
        if state.custom[copy.id] ~= nil then return false, "duplicate-id" end
        local custom=state.custom
        if copy.schemaVersion==1 then
            local body,reason=data.PrepareRotationContentRevision(copy.body,nil,'import')
            if not body then return false,reason end
            copy.body=body
        end
        if not rawequal(state.custom,custom) then return false,'rotation-changed-externally' end
        if builtins[copy.id] then return false,'read-only' end
        if state.custom[copy.id]~=nil then return false,'duplicate-id' end
        state.custom[copy.id] = copy
        return true
    end
    function catalog:Rename(reference, name)
        local key, why = owned(reference)
        if not key then return false, why end
        if type(name) ~= "string" or name == "" then return false, "invalid-name" end
        local view = self:Get({kind="custom",id=key})
        if not view.envelope or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.nameKey, view.envelope.body.name = name, name
        return self:Save({kind="custom",id=key}, view.envelope)
    end
    function catalog:Delete(reference)
        local key, why = owned(reference)
        if not key then return false, why end
        state.custom[key], state.lineage[key] = nil, nil
        return true
    end
    function catalog:WithdrawBuiltin(reference, reason)
        local kind, key = resolve(reference)
        if kind ~= "builtin" or not builtins[key] then return false, "unknown-built-in" end
        if type(reason) ~= "string" or reason == "" then return false, "missing-withdrawal-reason" end
        withdrawn[key] = reason
        return true
    end
    function catalog:Clone(reference, name)
        local source = self:Get(reference)
        if not source then return nil, "unknown-rotation" end
        if source.lineageError then return nil, "invalid-lineage" end
        if not source.validation.valid or not source.envelope or source.envelope.schemaVersion ~= 1 then return nil, "unsupported-source" end
        if type(options.newId) ~= "function" then return nil, "missing-id-provider" end
        if name ~= nil and (type(name) ~= "string" or name == "") then return nil, "invalid-name" end
        local used = {}
        for _, rows in ipairs({builtins,state.custom}) do
            for key, envelope in pairs(rows) do
                used[key] = true
                if data.CheckPortable(envelope) then
                    data.ReserveRotationIdentities(envelope,used)
                end
            end
        end
        for key,retained in pairs(state.lineage) do
            used[key]=true;data.ReserveRotationIdentities(retained,used)
        end
        if source.lineage and type(source.lineage.stepOrigins) == "table" then
            for _, origin in pairs(source.lineage.stepOrigins) do if id(origin) then used[origin] = true end end
        end
        local function fresh()
            local ok, value = pcall(options.newId)
            if not ok or not id(value) then return nil, "invalid-id-provider" end
            if used[value] then return nil, "id-collision" end
            used[value] = true
            return value
        end
        local newId, why = fresh()
        if not newId then return nil, why end
        local clone = source.envelope
        local baseline = source.lineage and source.lineage.baseline or data.CopyData(source.envelope)
        local lineage = {sourceId=source.lineage and source.lineage.sourceId or source.id,
            sourceKind=source.lineage and source.lineage.sourceKind or source.reference.kind,
            sourceRevision=source.lineage and source.lineage.sourceRevision or clone.revision,
            baseline=baseline, stepOrigins={}, clonedFrom=source.id}
        clone.id, clone.revision = newId, 1
        clone.body.revision=1
        if name then clone.nameKey, clone.body.name = name, name end
        local failed
        local indexed,indexError=steps(clone, function(step)
            if failed then return end
            local original = step.id
            local generated, reason = fresh()
            if not generated then failed = reason;return end
            step.id = generated
            if source.lineage then lineage.stepOrigins[generated] = source.lineage.stepOrigins and source.lineage.stepOrigins[original]
            else lineage.stepOrigins[generated] = original end
        end)
        if not indexed then return nil,indexError and indexError.code or "invalid-priority-list" end
        if failed then return nil, failed end
        local cleanLineage, problem = data.CopyData(lineage)
        if not cleanLineage then return nil, problem.code end
        local ok, reason = self:AddCustom(clone)
        if not ok then return nil, reason end
        state.lineage[newId] = cleanLineage
        return newId
    end
    return catalog
end
]======]},
 ['Core/rotation_scope.lua']={old=[======[local addon_name,addon=...
local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
function addon:BindRotationProfile()
    if current then current:Retire() end
    local owner=self;local profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else store,problem=data.NewRotationStore({state=state,fallbackID=profile.rotationFallbackID,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end}) end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if token then expected[token]=nil end
        local target={kind='custom',address=destination};local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        keyFor(target);return target
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil;return true
    end
    function coordinator:Cleanup(number,value)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then return assets[referenceKey(reference)].body end
        local pass=self:RuntimePass(number);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        local reference={kind='custom',address=copy(adoption.target)}
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference);return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason=self:Commit(reference,token,record,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposed[record.body]=true;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local function eligibilityContext()
            local value=rotationContext(owner,number);local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        return pass
    end
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]======],current=[======[local addon_name,addon=...
local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
function addon:BindRotationProfile()
    if current then current:Retire() end
    local owner=self;local profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else store,problem=data.NewRotationStore({state=state,fallbackID=profile.rotationFallbackID,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end}) end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope,revisionPolicy)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if revisionPolicy~=nil and revisionPolicy~='import' then return nil,'invalid-rotation-revision-policy' end
        if not plain(record) then return nil,'invalid-record' end
        if token and (not issued or not same(issued.reference,reference) or not same(issued.context,c)) then return nil,'stale-rotation-record' end
        local moved=a.scope~=destination.scope or a.owner~=destination.owner
        local previous
        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot,snapshotProblem=store:Get(a,c)
            if not snapshot then return nil,snapshotProblem end
            previous=snapshot.body
            if plain(previous) and plain(record.body) then
                if previous.rotation==nil and record.body.rotation~=nil then previous.rotation={} end
                if previous.cooldowns==nil and record.body.cooldowns~=nil then previous.cooldowns={} end
            end
        end
        local body,problem=data.PrepareRotationContentRevision(record.body,previous,
            token and 'edit' or revisionPolicy=='import' and 'import' or 'create',moved or revisionPolicy=='import')
        if not body then return nil,problem end
        local detached=copy(record);if not detached then return nil,'invalid-record' end
        record=detached;record.body=body
        local now,contextProblem=context()
        local current,currentProblem=ready();if not current then return nil,currentProblem end
        if not now then return nil,contextProblem end
        if not same(now,c) then return nil,'rotation-owner-changed' end
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if token then expected[token]=nil end
        local target={kind='custom',address=destination};local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        keyFor(target);return target
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil;return true
    end
    function coordinator:Cleanup(number,value)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then return assets[referenceKey(reference)].body end
        local pass=self:RuntimePass(number);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        local reference={kind='custom',address=copy(adoption.target)}
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference);return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason=self:Commit(reference,token,record,scope,'import');if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposed[record.body]=true;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local function eligibilityContext()
            local value=rotationContext(owner,number);local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        return pass
    end
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]======]},
 ['Core/rotation_library.lua']={old=[======[local addon_name, addon = ...
local data = addon.RotationData
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local definitions, definitionVersion = {}, 0
local active
local readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable
local bindValidation=addon.BindRotationValidationReader
if type(bindValidation)=='function' then
    bindValidation(addon,function(read,check,raw,identity,kind,meta)
        if type(read)=='function' and type(check)=='function' and type(raw)=='function'
            and type(identity)=='function' and type(kind)=='function' and type(meta)=='function' then
            readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable=read,check,raw,identity,kind,meta
        end
    end)
    addon.BindRotationValidationReader=nil
end
local function validationPlain(value)
    return validationType(value)=='table' and validationGetmetatable(value)==nil
end

local function contains(list, value)
    for _,entry in ipairs(list or {}) do if entry==value then return true end end
    return false
end
local function matchesClass(view,context)
    local scope=view.applicability
    return not scope or not scope.class or scope.class==context.class
end
local function eligible(view, context, candidates)
    if not view.enabled then return false,"disabled" end
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then return false,"invalid-or-unsupported" end
    if not matchesClass(view,context) then return false,"class-mismatch" end
    if candidates then return true end
    local scope=view.applicability
    if not scope or not contains(scope.families,context.family) then return false,"edition-mismatch" end
    if scope.specs and not contains(scope.specs,context.spec) then return false,"specialization-mismatch" end
    if scope.actionContext~=context.actionContext then return false,"action-context-mismatch" end
    for _,range in ipairs({{"minLevel","maxLevel","level"},{"minBuild","maxBuild","build"}}) do
        local value=context[range[3]]
        if scope[range[1]] or scope[range[2]] then
            if type(value)~="number" then return false,"missing-"..range[3] end
            if scope[range[1]] and value<scope[range[1]] or scope[range[2]] and value>scope[range[2]] then return false,range[3].."-mismatch" end
        end
    end
    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.rulesets or scope.intent or scope.roles then return false,"unsupported-context-selector" end
    if context.combatDataPolicy~="probe" then return false,"restricted-or-unsupported-client" end
    return true
end
local function plainTable(value)
    return type(value)=="table" and getmetatable(value)==nil
end

function addon:RegisterDefaultRotation(envelope)
    local copy,why=data.CopyData(envelope)
    if not copy then return false,why.code end
    if copy.format~="RotationMaster" or copy.schemaVersion~=1 or not data.ValidateEnvelope(copy).valid then return false,"invalid-envelope" end
    if not copy.applicability.class and copy.applicability.universal~=true then return false,"missing-class-scope" end
    if definitions[copy.id] then return false,"duplicate-default-id" end
    definitions[copy.id]=copy;definitionVersion=definitionVersion+1
    return true
end

function addon:InitializeRotationLibrary()
    local profile=self.db.profile
    local validation,referenceStamp=self:GetRotationValidationOptions()
    local state=profile.rotationLibrary
    if state==nil then state={};profile.rotationLibrary=state end
    if not plainTable(state) then active=nil;return false,"invalid-library-state" end
    for _,key in ipairs({"preferences","origins","comparisons","imports"}) do
        if state[key]~=nil and not plainTable(state[key]) then active=nil;return false,"invalid-library-state" end
    end
    state.preferences,state.origins,state.comparisons,state.imports=state.preferences or {},state.origins or {},state.comparisons or {},state.imports or {}
    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog,why=data.NewCatalog({state={preferences=state.preferences},
        validation=validation,newId=self.uuid})
    if not catalog then active=nil;return false,why end
    local views,bodies={},{}
    for id,envelope in pairs(definitions) do
        local ok,reason=catalog:RegisterBuiltin(envelope)
        if not ok then active=nil;return false,reason end
        views[id]=catalog:Get({kind="builtin",id=id})
        bodies[id]=data.CopyData(views[id].envelope.body)
        bodies[id].name=L[views[id].nameKey]
    end
    active={profile=profile,state=state,catalog=catalog,views=views,bodies=bodies,cloneScopes={},version=definitionVersion,referenceStamp=referenceStamp,generation={}}
    for spec,origins in pairs(state.origins) do
        if type(spec)=="number" and plainTable(origins) then
            active.cloneScopes[spec]={}
            for id in pairs(origins) do
                local view=self:GetSourcedRotationView(spec,id)
                if view then
                    view.validation=data.ValidateEnvelope(view.envelope,validation)
                    view.enabled=true
                end
                active.cloneScopes[spec][id]=view or false
            end
        end
    end
    return true
end
local ownedInitializeRotationLibrary=addon.InitializeRotationLibrary
local function ensure(self,needProof)
    local referenceStamp,method,db,profile,global,conditions,shared,personal,effects,version,state
    local plainStamps=false
    if needProof and readValidationStamp then
        local entryMethod=validationType(self)=='table' and validationRawget(self,'GetRotationValidationStamp') or nil
        method=self.GetRotationValidationStamp
        referenceStamp,db,profile,global,conditions,shared,personal,effects,version,state=readValidationStamp(self,method,entryMethod)
        plainStamps=db~=nil and validationPlain(referenceStamp) and active~=nil
            and validationPlain(active.referenceStamp) and validationPlain(active.generation)
    else referenceStamp=self:GetRotationValidationStamp() end
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then local ok,why=self:InitializeRotationLibrary();return ok,why end
        return self:InitializeRotationLibrary()
    end
    -- An initializer call never issues proof, even if it returns the same generation.
    if plainStamps and validationRawequal(validationRawget(self,'InitializeRotationLibrary'),ownedInitializeRotationLibrary)
        and checkValidationLayout(self,method,db,profile,global,conditions,shared,personal,effects,version,state) then
        return true,nil,referenceStamp,true
    end
    return true
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context=self.Platform:GetClientInfo()
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and self.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local ownedRotationContext=addon.GetRotationContext
local clientContextReader
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local function runtimeKey(id, custom)
    local key="RM-BUILTIN:"..id
    while custom[key]~=nil do key=":"..key end
    return key
end
-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind)~='function' then return nil,'invalid-library-reader-binder' end
    local owner=self;local reader={}
    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    function reader:Context(spec) return rotationContext(owner,spec) end
    local function generationMethod(self)
        local ok,why,checked,proof=ensure(owner,true);if not ok then return nil,why end
        return active.generation,nil,checked,proof
    end
    reader.Generation=generationMethod
    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method,reference,generation)
        return validationRawget~=nil and validationPlain(reader) and validationPlain(reference) and validationPlain(generation)
            and validationRawequal(validationRawget(reader,'Generation'),generationMethod)
            and (method==nil or validationRawequal(method,generationMethod))
    end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local view=active.views[id];if not view then return nil,'unknown-rotation' end
        local context=rotationContext(owner,spec);context.spec=spec
        if not matchesClass(view,context) then return nil,'class-mismatch' end
        local allowed,reason=eligible(view,context,candidates)
        return true,project(view,active.bodies[id],allowed,reason),active.generation
    end
    function reader:List(spec,project)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
        for id,view in pairs(active.views) do if matchesClass(view,context) then rows[#rows+1]=project(id,view,active.bodies[id]) end end
        return rows,active.generation
    end
    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration);return true
end

function addon:ListDefaultRotations(spec)
    local ok,why=ensure(self)
    if not ok then return {},why end
    local context=self:GetRotationContext(spec);context.spec=spec
    local custom=(self.db.profile.rotations or {})[spec] or {}
    local rows={}
    for id,view in pairs(active.views) do
        if matchesClass(view,context) then
            local row=data.CopyData(view)
            local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey=scoped and scoped:Key({kind='builtin',id=id}) or runtimeKey(id,custom)
            row.eligible,row.eligibilityReason=eligible(view,context)
            row.name=L[row.nameKey or id]
            row.description=L[row.descriptionKey or ""]
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function addon:GetDefaultRotation(id)
    if not ensure(self) then return nil end
    return active.catalog:Get({kind="builtin",id=id})
end
function addon:SetDefaultRotationEnabled(id,value)
    local ok,why=ensure(self);if not ok then return false,why end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
    return saved,reason
end
function addon:GetEditableRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:GetEditableRotation(spec,id) end
    local rotations=self.db.profile.rotations[spec]
    return rotations and rotations[id]
end
function addon:OwnsRotationCondition(spec,id,step,condition)
    local body=self:GetEditableRotation(spec,id)
    local tree=body and data.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return false end
    for _,row in ipairs(tree.rows) do if row.step==step and step.conditions==condition then return true end end
    return false
end
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then local pass,why=scoped:RuntimePass(spec);if not pass then return {},why end;local rows,reason=pass:Candidates(candidates==true);for key,body in pairs(rows) do local ref=scoped:Resolve(spec,key);if ref and ref.kind=='custom' then rows[key]=scoped:GetEditableRotation(spec,key) else rows[key]=data.CopyData(body) end end;return rows,reason end
    local rotations={}
    if spec==nil then return rotations end
    local ready=ensure(self)
    local context=self:GetRotationContext(spec);context.spec=spec
    -- Editing/export use the saved-data facade independently. Legacy bodies
    -- must obey the same client execution policy as packaged/scoped rotations.
    if context.combatDataPolicy~="probe" then return rotations end
    local origins=ready and active.state.origins[spec]
    local scopes=ready and active.cloneScopes[spec]
    for id,body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped=scopes and scopes[id]
        local imported,importError
        if self.GetImportedRotationView then imported,importError=self:GetImportedRotationView(spec,id) end
        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body=body
            scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
            scoped.applicability=scoped.envelope.applicability
        end
        if not origins or plainTable(origins) and origins[id]==nil
            or scoped and eligible(scoped,context,candidates) then
            if (not self.GetImportedRotationView or importError=="not-imported" or imported and eligible(imported,context,candidates))
                and not self:HasDisabledRotationDependency(body) then rotations[id]=body end
        end
    end
    if not ready then return rotations end
    for id,view in pairs(active.views) do
        if eligible(view,context,candidates) then
            local body=internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id,rotations)]=body
        end
    end
    return rotations
end
function addon:GetRuntimeRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local pass,why=scoped:RuntimePass(spec);if not pass then return nil,why end
        local body,bodyReason=pass:Get(id);if not body then return nil,bodyReason end
        local reference=scoped:Resolve(spec,id);if reference.kind=='custom' then return scoped:GetEditableRotation(spec,reference) end
        return data.CopyData(body)
    end
    return self:GetRuntimeRotations(spec,true)[id]
end
function addon:CloneDefaultRotation(spec,id,name,options)
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if coordinator then return coordinator:Copy(spec,{kind='builtin',id=id},name,options) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
    local rotations=self.db.profile.rotations[spec] or {}
    if rotations[generated]~=nil then return nil,"id-collision" end
    local view=temporary:Get({kind="custom",id=generated})
    local manifest=view.envelope;local body=manifest.body;manifest.body=nil
    if manifest.applicability.universal then
        manifest.applicability.universal=nil;manifest.applicability.class=context.class
    end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    origins=origins or {}
    if origins[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec]=rotations;rotations[generated]=body
    active.state.origins[spec]=origins;origins[generated]={manifest=manifest,lineage=view.lineage}
    local scoped=self:GetSourcedRotationView(spec,generated)
    scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
    scoped.enabled=true
    active.cloneScopes[spec]=active.cloneScopes[spec] or {};active.cloneScopes[spec][generated]=scoped
    return generated
end
function addon:GetSourcedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,false) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins==nil then return nil,"no-source-baseline" end
    if not plainTable(origins) then return nil,"invalid-origin-state" end
    if origins[id]==nil then return nil,"no-source-baseline" end
    local origin,problem=data.CopyData(origins[id])
    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id~=id then return nil,"invalid-origin-state" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local envelope=data.CopyData(origin.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-custom-body" end
    -- Catalog validates both current structure and retained historical lineage.
    local state={custom={[id]=envelope},lineage={[id]=origin.lineage}}
    local catalog,reason=data.NewCatalog({state=state})
    if not catalog then return nil,reason end
    local view=catalog:Get({kind="custom",id=id})
    if view.lineageError then return nil,"invalid-origin-state" end
    return view
end

function addon:IsDefaultRuntimeRotation(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return self:GetDefaultIdForRuntime(spec,key)~=nil end
    if not ensure(self) then return false end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return true end end
    return false
end

function addon:GetDefaultIdForRuntime(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then local ref=scoped:Resolve(spec,key);return ref and ref.kind=='builtin' and ref.id or nil end
    if not ensure(self) then return nil end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return id end end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec,true,true)
end
function addon:GetRotationForCleanup(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Cleanup(spec,key) end
    local custom=self:GetEditableRotation(spec,key)
    if custom then return custom end
    if not ensure(self) then return nil end
    local saved=self.db.profile.rotations[spec] or {}
    for id,body in pairs(active.bodies) do if runtimeKey(id,saved)==key then return body end end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:ComparisonIdentity(spec,id) end
    if not ensure(self) then return nil,"invalid-library-state" end
    local rows=active.state.comparisons[spec]
    if rows~=nil and not plainTable(rows) then return nil,"invalid-comparison-origin" end
    local identity
    if rows and rows[id]~=nil then
        local why
        identity,why=data.CopyData(rows[id])
        if why or not plainTable(identity) or (identity.kind~="custom" and identity.kind~="builtin")
            or type(identity.id)~="string" or not plainTable(identity.origins) then return nil,"invalid-comparison-origin" end
    end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if view then
        if identity and (identity.kind~=view.lineage.sourceKind or identity.id~=view.lineage.sourceId) then return nil,"invalid-comparison-origin" end
        identity=identity or {kind=view.lineage.sourceKind,id=view.lineage.sourceId,origins={}}
        for key,origin in pairs(view.lineage.stepOrigins) do identity.origins[key]=origin end
        return identity
    end
    if self.GetImportedRotationView then
        local imported,why=self:GetImportedRotationView(spec,id)
        if imported then return {kind="import",id=imported.sourceId,origins=imported.stepOrigins}
        elseif why~="not-imported" then return nil,why end
    end
    return identity or {kind="custom",id=id}
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec,id,name,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Copy(spec,id,name,options) end
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            prepared.manifest.body=nil
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    local sourceView
    if origins and origins[id]~=nil then
        sourceView,why=self:GetSourcedRotationView(spec,id)
        if not sourceView then return nil,why end
    end
    local identity,identityError=self:GetRotationComparisonIdentity(spec,id)
    if not identity then return nil,identityError end
    local correspondence={kind=identity.kind,id=identity.id,origins={}}
    local comparisonRows=active.state.comparisons[spec]
    if comparisonRows~=nil and not plainTable(comparisonRows) then return nil,"invalid-comparison-origin" end
    local used={}
    for _,rotations in pairs(self.db.profile.rotations) do
        if type(rotations)=="table" then
            for key,rotation in pairs(rotations) do
                used[key]=true
                data.ReserveRotationIdentities(rotation,used)
            end
        end
    end
    local function reserve(value) if type(value)=="string" then used[value]=true end end
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope,used)
    end
    for _,envelope in pairs(definitions) do reserveEnvelope(envelope) end
    for _,rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local entry=data.CopyData(raw)
                local retained=type(entry)=="table" and entry.lineage
                if type(retained)=="table" then
                    reserve(retained.sourceId);reserve(retained.clonedFrom)
                    if type(retained.baseline)=="table" then reserveEnvelope(retained.baseline) end
                    if type(retained.stepOrigins)=="table" then for step,origin in pairs(retained.stepOrigins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    for _,rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local retained=data.CopyData(raw)
                if type(retained)=="table" then
                    reserve(retained.id)
                    if type(retained.origins)=="table" then for step,origin in pairs(retained.origins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    local function fresh()
        local generatedOk,value=pcall(self.uuid)
        if not generatedOk or type(value)~="string" or #value>128 or not value:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[value] or definitions[value] then return nil,"id-collision" end
        used[value]=true;return value
    end
    local generated,reason=fresh();if not generated then return nil,reason end
    local lineage=sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins=lineage and lineage.stepOrigins
    if lineage then lineage.clonedFrom=id;lineage.stepOrigins={} end
    local indexed,indexError=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not indexed then return nil,indexError.code end
    for _,row in ipairs(indexed.rows) do
        local entry=row.step
        local stepId,errorCode=fresh();if not stepId then return nil,errorCode end
        if lineage then lineage.stepOrigins[stepId]=previousOrigins[entry.id] end
        correspondence.origins[stepId]=identity.origins and identity.origins[entry.id] or entry.id
        entry.id=stepId
    end
    body.name=name
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec][generated]=body
    if metadata then origins[generated]=metadata end
    comparisonRows=comparisonRows or {};active.state.comparisons[spec]=comparisonRows
    comparisonRows[generated]=correspondence
    self:InitializeRotationLibrary()
    return generated
end

function addon:BuildRotationComparison(spec,id,target)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if not target then return nil,'missing-comparison-target' end
        local targetReference
        if type(target)=='table' and target.kind=='custom' and not target.address then targetReference,why=scoped:Resolve(spec,target.id)
        else targetReference,why=scoped:Resolve(spec,target) end
        if not targetReference then return nil,why end
        local function sameAddress(a,b)
            if a.kind~=b.kind then return false end;if a.kind=='builtin' then return a.id==b.id end
            for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end;return true
        end
        if sameAddress(reference,targetReference) then return nil,'self-comparison' end
        local current,currentReason=scoped:Snapshot(spec,reference);if not current then return nil,currentReason end
        local other,targetReason=scoped:Snapshot(spec,targetReference);if not other then return nil,targetReason end
        local view=scoped:SourceView(spec,reference,false)
        if view and targetReference.kind=='builtin' and view.lineage.sourceKind=='builtin' and view.lineage.sourceId==targetReference.id then
            local source=other.source;local result=data.CompareClone(view,source)
            result.views={{key='current',left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key='source',left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key='custom',left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges}}
            return result
        end
        local left,leftError=scoped:ComparisonIdentity(spec,targetReference);local right,rightError=scoped:ComparisonIdentity(spec,reference)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        local exact=left.kind=='builtin' or left.kind=='import' or left.kind=='custom' and left.sourceAddress and right.sourceAddress and sameAddress({kind='custom',address=left.sourceAddress},{kind='custom',address=right.sourceAddress})
        if exact and left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other.body,self:GetRotationTags(spec,targetReference))
        local rightValue=data.RotationComparisonValue(current.body,self:GetRotationTags(spec,reference))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key='current',left=leftValue,right=rightValue,leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    if target and target.kind=="custom" and target.id==id then return nil,"self-comparison" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if target and target.kind=="builtin" then
        local source=self:GetDefaultRotation(target.id)
        if not source then return nil,"unknown-rotation" end
        if view and view.lineage.sourceKind=="builtin" and view.lineage.sourceId==target.id then
            local result=data.CompareClone(view,source)
            result.views={
                {key="current",left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key="source",left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key="custom",left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges},
            }
            return result
        end
        local leftValue=data.RotationComparisonValue(source.envelope.body,source.envelope.tags)
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue)
        leftValue.nameKey=source.envelope.nameKey
        result.views={{key="current",left=leftValue,right=rightValue,diff=data.CopyData(result)}}
        return result
    elseif target and target.kind=="custom" then
        local other=self:GetEditableRotation(spec,target.id)
        if not other then return nil,"unknown-rotation" end
        local left,leftError=self:GetRotationComparisonIdentity(spec,target.id)
        local right,rightError=self:GetRotationComparisonIdentity(spec,id)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        if left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other,self:GetRotationTags(spec,target.id))
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key="current",left=leftValue,right=rightValue,
            leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    return nil,"missing-comparison-target"
end

function addon:DeleteCustomRotation(spec,id,expected)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent then
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            self.currentRotation=nil;self.manualRotation=false
        end
        return true
    end
    if id==(DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec,id) then return nil,'read-only-rotation' end
    local body=self:GetEditableRotation(spec,id)
    if type(body)~='table' then return nil,'unknown-rotation' end
    local ready,why=ensure(self);if not ready then return nil,why end
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec]~=nil and not plainTable(active.state[key][spec]) then return nil,'invalid-library-state' end
    end
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        self.currentRotation=nil;self.manualRotation=false
    end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]======],current=[======[local addon_name, addon = ...
local data = addon.RotationData
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local definitions, definitionVersion = {}, 0
local active
local readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable
local bindValidation=addon.BindRotationValidationReader
if type(bindValidation)=='function' then
    bindValidation(addon,function(read,check,raw,identity,kind,meta)
        if type(read)=='function' and type(check)=='function' and type(raw)=='function'
            and type(identity)=='function' and type(kind)=='function' and type(meta)=='function' then
            readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable=read,check,raw,identity,kind,meta
        end
    end)
    addon.BindRotationValidationReader=nil
end
local function validationPlain(value)
    return validationType(value)=='table' and validationGetmetatable(value)==nil
end

local function contains(list, value)
    for _,entry in ipairs(list or {}) do if entry==value then return true end end
    return false
end
local function matchesClass(view,context)
    local scope=view.applicability
    return not scope or not scope.class or scope.class==context.class
end
local function eligible(view, context, candidates)
    if not view.enabled then return false,"disabled" end
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then return false,"invalid-or-unsupported" end
    if not matchesClass(view,context) then return false,"class-mismatch" end
    if candidates then return true end
    local scope=view.applicability
    if not scope or not contains(scope.families,context.family) then return false,"edition-mismatch" end
    if scope.specs and not contains(scope.specs,context.spec) then return false,"specialization-mismatch" end
    if scope.actionContext~=context.actionContext then return false,"action-context-mismatch" end
    for _,range in ipairs({{"minLevel","maxLevel","level"},{"minBuild","maxBuild","build"}}) do
        local value=context[range[3]]
        if scope[range[1]] or scope[range[2]] then
            if type(value)~="number" then return false,"missing-"..range[3] end
            if scope[range[1]] and value<scope[range[1]] or scope[range[2]] and value>scope[range[2]] then return false,range[3].."-mismatch" end
        end
    end
    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.rulesets or scope.intent or scope.roles then return false,"unsupported-context-selector" end
    if context.combatDataPolicy~="probe" then return false,"restricted-or-unsupported-client" end
    return true
end
local function plainTable(value)
    return type(value)=="table" and getmetatable(value)==nil
end

function addon:RegisterDefaultRotation(envelope)
    local copy,why=data.CopyData(envelope)
    if not copy then return false,why.code end
    if copy.format~="RotationMaster" or copy.schemaVersion~=1 or not data.ValidateEnvelope(copy).valid then return false,"invalid-envelope" end
    if not copy.applicability.class and copy.applicability.universal~=true then return false,"missing-class-scope" end
    if definitions[copy.id] then return false,"duplicate-default-id" end
    definitions[copy.id]=copy;definitionVersion=definitionVersion+1
    return true
end

function addon:InitializeRotationLibrary()
    local profile=self.db.profile
    local validation,referenceStamp=self:GetRotationValidationOptions()
    local state=profile.rotationLibrary
    if state==nil then state={};profile.rotationLibrary=state end
    if not plainTable(state) then active=nil;return false,"invalid-library-state" end
    for _,key in ipairs({"preferences","origins","comparisons","imports"}) do
        if state[key]~=nil and not plainTable(state[key]) then active=nil;return false,"invalid-library-state" end
    end
    state.preferences,state.origins,state.comparisons,state.imports=state.preferences or {},state.origins or {},state.comparisons or {},state.imports or {}
    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog,why=data.NewCatalog({state={preferences=state.preferences},
        validation=validation,newId=self.uuid})
    if not catalog then active=nil;return false,why end
    local views,bodies={},{}
    for id,envelope in pairs(definitions) do
        local ok,reason=catalog:RegisterBuiltin(envelope)
        if not ok then active=nil;return false,reason end
        views[id]=catalog:Get({kind="builtin",id=id})
        bodies[id]=data.CopyData(views[id].envelope.body)
        bodies[id].name=L[views[id].nameKey]
    end
    active={profile=profile,state=state,catalog=catalog,views=views,bodies=bodies,cloneScopes={},version=definitionVersion,referenceStamp=referenceStamp,generation={}}
    for spec,origins in pairs(state.origins) do
        if type(spec)=="number" and plainTable(origins) then
            active.cloneScopes[spec]={}
            for id in pairs(origins) do
                local view=self:GetSourcedRotationView(spec,id)
                if view then
                    view.validation=data.ValidateEnvelope(view.envelope,validation)
                    view.enabled=true
                end
                active.cloneScopes[spec][id]=view or false
            end
        end
    end
    return true
end
local ownedInitializeRotationLibrary=addon.InitializeRotationLibrary
local function ensure(self,needProof)
    local referenceStamp,method,db,profile,global,conditions,shared,personal,effects,version,state
    local plainStamps=false
    if needProof and readValidationStamp then
        local entryMethod=validationType(self)=='table' and validationRawget(self,'GetRotationValidationStamp') or nil
        method=self.GetRotationValidationStamp
        referenceStamp,db,profile,global,conditions,shared,personal,effects,version,state=readValidationStamp(self,method,entryMethod)
        plainStamps=db~=nil and validationPlain(referenceStamp) and active~=nil
            and validationPlain(active.referenceStamp) and validationPlain(active.generation)
    else referenceStamp=self:GetRotationValidationStamp() end
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then local ok,why=self:InitializeRotationLibrary();return ok,why end
        return self:InitializeRotationLibrary()
    end
    -- An initializer call never issues proof, even if it returns the same generation.
    if plainStamps and validationRawequal(validationRawget(self,'InitializeRotationLibrary'),ownedInitializeRotationLibrary)
        and checkValidationLayout(self,method,db,profile,global,conditions,shared,personal,effects,version,state) then
        return true,nil,referenceStamp,true
    end
    return true
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context=self.Platform:GetClientInfo()
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and self.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local ownedRotationContext=addon.GetRotationContext
local clientContextReader
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local function runtimeKey(id, custom)
    local key="RM-BUILTIN:"..id
    while custom[key]~=nil do key=":"..key end
    return key
end
-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind)~='function' then return nil,'invalid-library-reader-binder' end
    local owner=self;local reader={}
    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    function reader:Context(spec) return rotationContext(owner,spec) end
    local function generationMethod(self)
        local ok,why,checked,proof=ensure(owner,true);if not ok then return nil,why end
        return active.generation,nil,checked,proof
    end
    reader.Generation=generationMethod
    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method,reference,generation)
        return validationRawget~=nil and validationPlain(reader) and validationPlain(reference) and validationPlain(generation)
            and validationRawequal(validationRawget(reader,'Generation'),generationMethod)
            and (method==nil or validationRawequal(method,generationMethod))
    end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local view=active.views[id];if not view then return nil,'unknown-rotation' end
        local context=rotationContext(owner,spec);context.spec=spec
        if not matchesClass(view,context) then return nil,'class-mismatch' end
        local allowed,reason=eligible(view,context,candidates)
        return true,project(view,active.bodies[id],allowed,reason),active.generation
    end
    function reader:List(spec,project)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
        for id,view in pairs(active.views) do if matchesClass(view,context) then rows[#rows+1]=project(id,view,active.bodies[id]) end end
        return rows,active.generation
    end
    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration);return true
end

function addon:ListDefaultRotations(spec)
    local ok,why=ensure(self)
    if not ok then return {},why end
    local context=self:GetRotationContext(spec);context.spec=spec
    local custom=(self.db.profile.rotations or {})[spec] or {}
    local rows={}
    for id,view in pairs(active.views) do
        if matchesClass(view,context) then
            local row=data.CopyData(view)
            local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey=scoped and scoped:Key({kind='builtin',id=id}) or runtimeKey(id,custom)
            row.eligible,row.eligibilityReason=eligible(view,context)
            row.name=L[row.nameKey or id]
            row.description=L[row.descriptionKey or ""]
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function addon:GetDefaultRotation(id)
    if not ensure(self) then return nil end
    return active.catalog:Get({kind="builtin",id=id})
end
function addon:SetDefaultRotationEnabled(id,value)
    local ok,why=ensure(self);if not ok then return false,why end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
    return saved,reason
end
function addon:GetEditableRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:GetEditableRotation(spec,id) end
    local rotations=self.db.profile.rotations[spec]
    return rotations and rotations[id]
end
function addon:OwnsRotationCondition(spec,id,step,condition)
    local body=self:GetEditableRotation(spec,id)
    local tree=body and data.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return false end
    for _,row in ipairs(tree.rows) do if row.step==step and step.conditions==condition then return true end end
    return false
end
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then local pass,why=scoped:RuntimePass(spec);if not pass then return {},why end;local rows,reason=pass:Candidates(candidates==true);for key,body in pairs(rows) do local ref=scoped:Resolve(spec,key);if ref and ref.kind=='custom' then rows[key]=scoped:GetEditableRotation(spec,key) else rows[key]=data.CopyData(body) end end;return rows,reason end
    local rotations={}
    if spec==nil then return rotations end
    local ready=ensure(self)
    local context=self:GetRotationContext(spec);context.spec=spec
    -- Editing/export use the saved-data facade independently. Legacy bodies
    -- must obey the same client execution policy as packaged/scoped rotations.
    if context.combatDataPolicy~="probe" then return rotations end
    local origins=ready and active.state.origins[spec]
    local scopes=ready and active.cloneScopes[spec]
    for id,body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped=scopes and scopes[id]
        local imported,importError
        if self.GetImportedRotationView then imported,importError=self:GetImportedRotationView(spec,id) end
        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body=body
            scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
            scoped.applicability=scoped.envelope.applicability
        end
        if not origins or plainTable(origins) and origins[id]==nil
            or scoped and eligible(scoped,context,candidates) then
            if (not self.GetImportedRotationView or importError=="not-imported" or imported and eligible(imported,context,candidates))
                and not self:HasDisabledRotationDependency(body) then rotations[id]=body end
        end
    end
    if not ready then return rotations end
    for id,view in pairs(active.views) do
        if eligible(view,context,candidates) then
            local body=internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id,rotations)]=body
        end
    end
    return rotations
end
function addon:GetRuntimeRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local pass,why=scoped:RuntimePass(spec);if not pass then return nil,why end
        local body,bodyReason=pass:Get(id);if not body then return nil,bodyReason end
        local reference=scoped:Resolve(spec,id);if reference.kind=='custom' then return scoped:GetEditableRotation(spec,reference) end
        return data.CopyData(body)
    end
    return self:GetRuntimeRotations(spec,true)[id]
end
function addon:CloneDefaultRotation(spec,id,name,options)
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if coordinator then return coordinator:Copy(spec,{kind='builtin',id=id},name,options) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local rotations=self.db.profile.rotations[spec] or {}
    if rotations[generated]~=nil then return nil,"id-collision" end
    local view=temporary:Get({kind="custom",id=generated})
    local manifest=view.envelope;local body=manifest.body;manifest.body=nil
    if manifest.applicability.universal then
        manifest.applicability.universal=nil;manifest.applicability.class=context.class
    end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    origins=origins or {}
    if origins[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec]=rotations;rotations[generated]=body
    active.state.origins[spec]=origins;origins[generated]={manifest=manifest,lineage=view.lineage}
    local scoped=self:GetSourcedRotationView(spec,generated)
    scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
    scoped.enabled=true
    active.cloneScopes[spec]=active.cloneScopes[spec] or {};active.cloneScopes[spec][generated]=scoped
    return generated
end
function addon:GetSourcedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,false) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins==nil then return nil,"no-source-baseline" end
    if not plainTable(origins) then return nil,"invalid-origin-state" end
    if origins[id]==nil then return nil,"no-source-baseline" end
    local origin,problem=data.CopyData(origins[id])
    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id~=id then return nil,"invalid-origin-state" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local envelope=data.CopyData(origin.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-custom-body" end
    -- Catalog validates both current structure and retained historical lineage.
    local state={custom={[id]=envelope},lineage={[id]=origin.lineage}}
    local catalog,reason=data.NewCatalog({state=state})
    if not catalog then return nil,reason end
    local view=catalog:Get({kind="custom",id=id})
    if view.lineageError then return nil,"invalid-origin-state" end
    return view
end

function addon:IsDefaultRuntimeRotation(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return self:GetDefaultIdForRuntime(spec,key)~=nil end
    if not ensure(self) then return false end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return true end end
    return false
end

function addon:GetDefaultIdForRuntime(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then local ref=scoped:Resolve(spec,key);return ref and ref.kind=='builtin' and ref.id or nil end
    if not ensure(self) then return nil end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return id end end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec,true,true)
end
function addon:GetRotationForCleanup(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Cleanup(spec,key) end
    local custom=self:GetEditableRotation(spec,key)
    if custom then return custom end
    if not ensure(self) then return nil end
    local saved=self.db.profile.rotations[spec] or {}
    for id,body in pairs(active.bodies) do if runtimeKey(id,saved)==key then return body end end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:ComparisonIdentity(spec,id) end
    if not ensure(self) then return nil,"invalid-library-state" end
    local rows=active.state.comparisons[spec]
    if rows~=nil and not plainTable(rows) then return nil,"invalid-comparison-origin" end
    local identity
    if rows and rows[id]~=nil then
        local why
        identity,why=data.CopyData(rows[id])
        if why or not plainTable(identity) or (identity.kind~="custom" and identity.kind~="builtin")
            or type(identity.id)~="string" or not plainTable(identity.origins) then return nil,"invalid-comparison-origin" end
    end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if view then
        if identity and (identity.kind~=view.lineage.sourceKind or identity.id~=view.lineage.sourceId) then return nil,"invalid-comparison-origin" end
        identity=identity or {kind=view.lineage.sourceKind,id=view.lineage.sourceId,origins={}}
        for key,origin in pairs(view.lineage.stepOrigins) do identity.origins[key]=origin end
        return identity
    end
    if self.GetImportedRotationView then
        local imported,why=self:GetImportedRotationView(spec,id)
        if imported then return {kind="import",id=imported.sourceId,origins=imported.stepOrigins}
        elseif why~="not-imported" then return nil,why end
    end
    return identity or {kind="custom",id=id}
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec,id,name,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Copy(spec,id,name,options) end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            local revision,problem=data.GetRotationContentRevision(prepared.body);if not revision then return nil,problem end
            prepared.manifest.body=nil;prepared.body.revision=1
            if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    local revision,revisionError=data.GetRotationContentRevision(body);if not revision then return nil,revisionError end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local ok,why=ensure(self);if not ok then return nil,why end
    if library==nil then library=profile.rotationLibrary end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    local sourceView
    if origins and origins[id]~=nil then
        sourceView,why=self:GetSourcedRotationView(spec,id)
        if not sourceView then return nil,why end
    end
    local identity,identityError=self:GetRotationComparisonIdentity(spec,id)
    if not identity then return nil,identityError end
    local correspondence={kind=identity.kind,id=identity.id,origins={}}
    local comparisonRows=active.state.comparisons[spec]
    if comparisonRows~=nil and not plainTable(comparisonRows) then return nil,"invalid-comparison-origin" end
    local used={}
    for _,rotations in pairs(self.db.profile.rotations) do
        if type(rotations)=="table" then
            for key,rotation in pairs(rotations) do
                used[key]=true
                data.ReserveRotationIdentities(rotation,used)
            end
        end
    end
    local function reserve(value) if type(value)=="string" then used[value]=true end end
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope,used)
    end
    for _,envelope in pairs(definitions) do reserveEnvelope(envelope) end
    for _,rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local entry=data.CopyData(raw)
                local retained=type(entry)=="table" and entry.lineage
                if type(retained)=="table" then
                    reserve(retained.sourceId);reserve(retained.clonedFrom)
                    if type(retained.baseline)=="table" then reserveEnvelope(retained.baseline) end
                    if type(retained.stepOrigins)=="table" then for step,origin in pairs(retained.stepOrigins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    for _,rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local retained=data.CopyData(raw)
                if type(retained)=="table" then
                    reserve(retained.id)
                    if type(retained.origins)=="table" then for step,origin in pairs(retained.origins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    local function fresh()
        local generatedOk,value=pcall(self.uuid)
        if not generatedOk or type(value)~="string" or #value>128 or not value:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[value] or definitions[value] then return nil,"id-collision" end
        used[value]=true;return value
    end
    local generated,reason=fresh();if not generated then return nil,reason end
    local lineage=sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins=lineage and lineage.stepOrigins
    if lineage then lineage.clonedFrom=id;lineage.stepOrigins={} end
    local indexed,indexError=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not indexed then return nil,indexError.code end
    for _,row in ipairs(indexed.rows) do
        local entry=row.step
        local stepId,errorCode=fresh();if not stepId then return nil,errorCode end
        if lineage then lineage.stepOrigins[stepId]=previousOrigins[entry.id] end
        correspondence.origins[stepId]=identity.origins and identity.origins[entry.id] or entry.id
        entry.id=stepId
    end
    body.name=name;body.revision=1
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    self.db.profile.rotations[spec][generated]=body
    if metadata then origins[generated]=metadata end
    comparisonRows=comparisonRows or {};active.state.comparisons[spec]=comparisonRows
    comparisonRows[generated]=correspondence
    self:InitializeRotationLibrary()
    return generated
end

function addon:BuildRotationComparison(spec,id,target)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if not target then return nil,'missing-comparison-target' end
        local targetReference
        if type(target)=='table' and target.kind=='custom' and not target.address then targetReference,why=scoped:Resolve(spec,target.id)
        else targetReference,why=scoped:Resolve(spec,target) end
        if not targetReference then return nil,why end
        local function sameAddress(a,b)
            if a.kind~=b.kind then return false end;if a.kind=='builtin' then return a.id==b.id end
            for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end;return true
        end
        if sameAddress(reference,targetReference) then return nil,'self-comparison' end
        local current,currentReason=scoped:Snapshot(spec,reference);if not current then return nil,currentReason end
        local other,targetReason=scoped:Snapshot(spec,targetReference);if not other then return nil,targetReason end
        local view=scoped:SourceView(spec,reference,false)
        if view and targetReference.kind=='builtin' and view.lineage.sourceKind=='builtin' and view.lineage.sourceId==targetReference.id then
            local source=other.source;local result=data.CompareClone(view,source)
            result.views={{key='current',left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key='source',left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key='custom',left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges}}
            return result
        end
        local left,leftError=scoped:ComparisonIdentity(spec,targetReference);local right,rightError=scoped:ComparisonIdentity(spec,reference)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        local exact=left.kind=='builtin' or left.kind=='import' or left.kind=='custom' and left.sourceAddress and right.sourceAddress and sameAddress({kind='custom',address=left.sourceAddress},{kind='custom',address=right.sourceAddress})
        if exact and left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other.body,self:GetRotationTags(spec,targetReference))
        local rightValue=data.RotationComparisonValue(current.body,self:GetRotationTags(spec,reference))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key='current',left=leftValue,right=rightValue,leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    if target and target.kind=="custom" and target.id==id then return nil,"self-comparison" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if target and target.kind=="builtin" then
        local source=self:GetDefaultRotation(target.id)
        if not source then return nil,"unknown-rotation" end
        if view and view.lineage.sourceKind=="builtin" and view.lineage.sourceId==target.id then
            local result=data.CompareClone(view,source)
            result.views={
                {key="current",left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key="source",left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key="custom",left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges},
            }
            return result
        end
        local leftValue=data.RotationComparisonValue(source.envelope.body,source.envelope.tags)
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue)
        leftValue.nameKey=source.envelope.nameKey
        result.views={{key="current",left=leftValue,right=rightValue,diff=data.CopyData(result)}}
        return result
    elseif target and target.kind=="custom" then
        local other=self:GetEditableRotation(spec,target.id)
        if not other then return nil,"unknown-rotation" end
        local left,leftError=self:GetRotationComparisonIdentity(spec,target.id)
        local right,rightError=self:GetRotationComparisonIdentity(spec,id)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        if left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other,self:GetRotationTags(spec,target.id))
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key="current",left=leftValue,right=rightValue,
            leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    return nil,"missing-comparison-target"
end

function addon:DeleteCustomRotation(spec,id,expected)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent then
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            self.currentRotation=nil;self.manualRotation=false
        end
        return true
    end
    if id==(DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec,id) then return nil,'read-only-rotation' end
    local body=self:GetEditableRotation(spec,id)
    if type(body)~='table' then return nil,'unknown-rotation' end
    local ready,why=ensure(self);if not ready then return nil,why end
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec]~=nil and not plainTable(active.state[key][spec]) then return nil,'invalid-library-state' end
    end
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        self.currentRotation=nil;self.manualRotation=false
    end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]======]},
 ['Core/rotation_workspace.lua']={old=[======[local _,addon=...
local data=addon.RotationData
local profiles={}
local function equal(a,b)
    if not data.CheckPortable(a) or not data.CheckPortable(b) then return false end
    local function compare(x,y)
        if type(x)~=type(y) then return false end
        if type(x)~='table' then return x==y end
        for key,value in pairs(x) do if not compare(value,y[key]) then return false end end
        for key in pairs(y) do if x[key]==nil then return false end end
        return true
    end
    return compare(a,b)
end
local function originalAt(profile,spec,id)
    local list=profile.rotations and profile.rotations[spec]
    return type(list)=='table' and list[id] or nil
end
local function retained(profile,spec,id)
    local result={};local library=profile.rotationLibrary
    if type(library)=='table' then
        for _,kind in ipairs({'origins','comparisons','imports'}) do
            local all=library[kind];local scope=type(all)=='table' and all[spec]
            if type(scope)=='table' then result[kind]=scope[id] end
        end
    end
    return result
end
local function scopedWorkspace(owner,coordinator,spec,value)
    local reference,why=coordinator:Resolve(spec,value)
    if not reference and why=='unknown-rotation' and type(value)=='string' then reference,why=coordinator:LegacyDraft(spec,value) end
    if not reference then return nil,why end
    local profile=owner.db.profile;local key=coordinator:Key(reference)
    local cache=profiles[profile];if not cache then cache={};profiles[profile]=cache end
    for _,w in ipairs(cache) do if w.spec==spec and w.id==key and w:ValidTarget() then return w end end
    local pending=coordinator:IsPending(reference)
    local record,expected,status
    if not pending then record,expected,status=coordinator:Snapshot(spec,reference);if not record then return nil,expected end end
    local builtin=reference.kind=='builtin' and reference.id or nil
    record=record or {body={name=reference.address.id==profile.rotationFallbackID and profile.rotationFallbackID or NEW,switch={},rotation={},cooldowns={}}}
    local sourceReference=data.CopyData(reference)
    local workspace={spec=spec,id=key,canonicalId=builtin or reference.address.id,reference=data.CopyData(reference),builtin=builtin,readOnly=builtin~=nil,
        fallback=not builtin and reference.address.id==profile.rotationFallbackID or false,pending=pending,
        original=pending and nil or data.CopyData(record.body),title=record.body.name or NEW,description=record.body.description or ''}
    workspace.source=record.source
    local baseline=data.CopyData(record.body)
    local function flags()
        workspace.scope=workspace.session and workspace.session:Ownership() or (not builtin and workspace.reference.address.scope)
        if workspace.pending and workspace.session then local staged=coordinator:StagePending(sourceReference,workspace.scope);if staged then workspace.reference=staged end end
        local effective=coordinator:Resolve(spec,DEFAULT)
        workspace.effectiveFallback=effective and equal(effective,workspace.reference) or false
    end
    function workspace:ValidTarget()
        if owner:GetScopedRotationCoordinator()~=coordinator then return false end
        if builtin then return coordinator:Resolve(spec,sourceReference)~=nil end
        if self.pending then return coordinator:IsPending(sourceReference) and coordinator:Resolve(spec,sourceReference)~=nil end
        return coordinator:TokenCurrent(expected)
    end
    local function sessionFor(body)
        workspace.reserved={origins=data.CopyData(record.origin),imports=data.CopyData(record.imported),comparisons=data.CopyData(record.comparison)}
        local used={};for _,component in pairs(workspace.reserved) do local ok,problem=data.ReserveRotationIdentities(component,used);if not ok then return nil,problem.code end end
        local function fresh()
            for _=1,100 do local id=owner.uuid();if not used[id] then used[id]=true;return id end end
        end
        return owner:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=fresh,
            ownership=not builtin and sourceReference.address.scope or nil,setOwnershipAllowed=not builtin,
            targetValid=function() return workspace:ValidTarget() end,
            commit=function(candidate,scope)
                local replacement={body=candidate,origin=record.origin,imported=record.imported,comparison=record.comparison}
                local saved,problem=coordinator:Commit(sourceReference,expected,replacement,scope)
                if not saved then return nil,problem end
                return true,saved
            end})
    end
    local session,problem=sessionFor(baseline);if not session then return nil,problem end;workspace.session=session;flags()
    function workspace:Snapshot() flags();return self.session:Snapshot() end
    function workspace:TargetReference()
        local result=data.CopyData(self.reference)
        if not self.readOnly then
            local c=owner:GetRotationOwnerContext();if not c then return nil,'missing-owner-context' end
            result.address.scope=self.session:Ownership();result.address.owner=result.address.scope=='class' and c.class or c.character
            if not result.address.owner then return nil,'missing-owner-context' end
        end
        return result
    end
    function workspace:Metadata() return {id=self.id,reference=self:TargetReference(),scope=self.session:Ownership(),kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),source=self.source or self.reserved} end
    function workspace:IsDirty() flags();return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if self.fallback and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        if name=='SetOwnership' and (...)=='character' then local c=owner:GetRotationOwnerContext();if not c or not c.character then return nil,'missing-owner-context' end end
        local ok,result=self.session:Command(name,...);flags();return ok,result
    end
    function workspace:Apply()
        if self.pending and not self.fallback then local name=self:Snapshot().name;if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end end
        local ok,why,saved=self.session:Apply();if not ok then return nil,why,saved end
        sourceReference=data.CopyData(saved);self.reference=data.CopyData(saved);self.id=coordinator:Key(saved);self.canonicalId=saved.address.id;self.pending=false
        record,expected,status=coordinator:Snapshot(spec,saved);baseline=data.CopyData(record.body);self.original=data.CopyData(record.body)
        self.title=record.body.name or self.canonicalId;self.description=record.body.description or ''
        local nextSession,problem=sessionFor(baseline);if not nextSession then return nil,problem end;self.session=nextSession;flags();return true,nil,data.CopyData(saved)
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,why=sessionFor(baseline);if not replacement then return nil,why end
        self.session:Cancel();self.session=replacement;flags();return true
    end
    function workspace:ConditionEditorTarget(target)
        local captured=self.session
        local function condition()
            local body=captured:Snapshot();if type(target)=='table' and target.kind=='switch' then return body.switch or {} end
            local tree=data.IndexRotationSteps(body);local row=tree and tree.byId[target];return row and (row.step.conditions or {})
        end
        local baselineCondition=condition();if not baselineCondition then return nil,'missing-rotation-step' end
        local committed=false
        local function valid() return not committed and workspace.session==captured and workspace:ValidTarget() and equal(baselineCondition,condition()) end
        return {condition=data.CopyData(baselineCondition),readOnly=self.readOnly,valid=valid,commit=function(edited)
            if workspace.readOnly then return nil,'readonly-rotation' end;if not valid() then return nil,'condition-target-changed' end
            local ok,why=workspace:Command('SetCondition',target,edited);if ok then committed=true end;return ok,why
        end}
    end
    cache[#cache+1]=workspace;return workspace
end

function addon:GetRotationEditWorkspace(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scopedWorkspace(self,scoped,spec,id) end
    if type(spec)~='number' or spec<0 or spec%1~=0 or type(id)~='string' or id=='' then return nil,'invalid-rotation-target' end
    local profile=self.db.profile
    if type(profile.rotations)~='table' then return nil,'invalid-rotation-storage' end
    local builtin=self:GetDefaultIdForRuntime(spec,id)
    local source,original
    if builtin then
        for _,entry in ipairs(self:ListDefaultRotations(spec)) do if entry.id==builtin then source=entry;break end end
        if not source or not source.envelope then return nil,'unknown-default-rotation' end
    else original=originalAt(profile,spec,id) end
    local cache=profiles[profile]
    if not cache then cache={};profiles[profile]=cache end
    for _,workspace in ipairs(cache) do
        if workspace.spec==spec and workspace.id==id and workspace.builtin==builtin and
            (builtin or workspace.original==original) and workspace:ValidTarget() then return workspace end
    end
    local workspace={spec=spec,id=id,canonicalId=id,builtin=builtin,readOnly=builtin~=nil,fallback=not builtin and id==DEFAULT or false,
        title=source and source.name or id==DEFAULT and DEFAULT or original and original.name or NEW,
        description=source and source.description or original and original.description or '',source=source,original=original,pending=not builtin and original==nil}
    local capturedRoot=profile.rotations
    local value=source and data.CopyData(source.envelope.body) or original
    if not value then value={name=id==DEFAULT and DEFAULT or NEW,switch={},rotation={},cooldowns={}} end
    if builtin then value.name=source.name end
    function workspace:ValidTarget()
        if addon.db.profile~=profile or profile.rotations~=capturedRoot then return false end
        if self.builtin then return addon:GetDefaultIdForRuntime(spec,id)==self.builtin end
        return originalAt(profile,spec,id)==self.original and not addon:GetDefaultIdForRuntime(spec,id)
    end
    local function sessionFor(body)
        return addon:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=addon.uuid,
            reserved=workspace.reserved,targetValid=function() return workspace:ValidTarget() end})
    end
    local reservations,copyError=data.CopyData(retained(profile,spec,id))
    if not reservations then return nil,copyError.code end
    workspace.reserved=reservations
    local session,why=sessionFor(value);if not session then return nil,why end
    workspace.session=session
    function workspace:Snapshot() return self.session:Snapshot() end
    function workspace:Metadata()
        return {id=id,kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),
            source=self.source and data.CopyData(self.source.envelope) or data.CopyData(self.reserved)}
    end
    function workspace:IsDirty() return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if id==DEFAULT and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        return self.session:Command(name,...)
    end
    function workspace:Apply()
        if self.pending and id~=DEFAULT then
            local name=self:Snapshot().name
            if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end
        end
        local ok,reason,details=self.session:Apply();if not ok then return nil,reason,details end
        if self.pending then
            local list=profile.rotations[spec] or {};profile.rotations[spec]=list
            list[id]=value;self.original=value;self.pending=false
        end
        self.title=value.name or id
        local replacement,problem=sessionFor(value)
        if not replacement then return nil,problem end
        self.session=replacement;return true
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,problem=sessionFor(value);if not replacement then return nil,problem end
        self.session:Cancel();self.session=replacement;return true
    end
    function workspace:ConditionEditorTarget(target)
        local sessionToken=self.session
        local function condition()
            local snapshot=sessionToken:Snapshot()
            if type(target)=='table' and target.kind=='switch' then return snapshot.switch or {} end
            local tree=data.IndexRotationSteps(snapshot);local row=tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end
        local baseline=condition();if not baseline then return nil,'missing-rotation-step' end
        local committed=false
        local function valid()
            return not committed and workspace.session==sessionToken and workspace:ValidTarget() and equal(baseline,condition())
        end
        return {condition=data.CopyData(baseline),readOnly=self.readOnly,valid=valid,
            commit=function(edited)
                if workspace.readOnly then return nil,'readonly-rotation' end
                if not valid() then return nil,'condition-target-changed' end
                local ok,reason=workspace:Command('SetCondition',target,edited)
                if ok then committed=true end
                return ok,reason
            end}
    end
    cache[#cache+1]=workspace
    return workspace
end

function addon:GetRotationWorkspace(spec,value)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local reference=scoped and scoped:Resolve(spec,value)
    for _,w in ipairs(profiles[self.db.profile] or {}) do if w.spec==spec and (w.id==value or scoped and reference and equal(w.reference,reference)) and w:ValidTarget() then return w end end
end
function addon:ListPendingRotationDrafts(spec)
    local result={}
    for _,workspace in ipairs(profiles[self.db.profile] or {}) do
        if workspace.spec==spec and workspace.pending and workspace.id~=DEFAULT and workspace:ValidTarget() then
            local snapshot=workspace:Snapshot();result[#result+1]={id=workspace.id,key=workspace.id,reference=workspace.TargetReference and workspace:TargetReference(),canonicalId=workspace.canonicalId,scope=workspace.scope,pending=true,fallback=workspace.fallback,effectiveFallback=false,name=snapshot.name or NEW,presentation={name=snapshot.name,description=snapshot.description,priority=snapshot.priority,tags=snapshot.tags,metadata=snapshot.metadata}}
        end
    end
    return result
end
]======],current=[======[local _,addon=...
local data=addon.RotationData
local profiles={}
local function equal(a,b)
    if not data.CheckPortable(a) or not data.CheckPortable(b) then return false end
    local function compare(x,y)
        if type(x)~=type(y) then return false end
        if type(x)~='table' then return x==y end
        for key,value in pairs(x) do if not compare(value,y[key]) then return false end end
        for key in pairs(y) do if x[key]==nil then return false end end
        return true
    end
    return compare(a,b)
end
local function originalAt(profile,spec,id)
    local list=profile.rotations and profile.rotations[spec]
    return type(list)=='table' and list[id] or nil
end
local function retained(profile,spec,id)
    local result={};local library=profile.rotationLibrary
    if type(library)=='table' then
        for _,kind in ipairs({'origins','comparisons','imports'}) do
            local all=library[kind];local scope=type(all)=='table' and all[spec]
            if type(scope)=='table' then result[kind]=scope[id] end
        end
    end
    return result
end
local function scopedWorkspace(owner,coordinator,spec,value)
    local reference,why=coordinator:Resolve(spec,value)
    if not reference and why=='unknown-rotation' and type(value)=='string' then reference,why=coordinator:LegacyDraft(spec,value) end
    if not reference then return nil,why end
    local profile=owner.db.profile;local key=coordinator:Key(reference)
    local cache=profiles[profile];if not cache then cache={};profiles[profile]=cache end
    for _,w in ipairs(cache) do if w.spec==spec and w.id==key and w:ValidTarget() then return w end end
    local pending=coordinator:IsPending(reference)
    local record,expected,status
    if not pending then record,expected,status=coordinator:Snapshot(spec,reference);if not record then return nil,expected end end
    local builtin=reference.kind=='builtin' and reference.id or nil
    record=record or {body={name=reference.address.id==profile.rotationFallbackID and profile.rotationFallbackID or NEW,switch={},rotation={},cooldowns={}}}
    local sourceReference=data.CopyData(reference)
    local workspace={spec=spec,id=key,canonicalId=builtin or reference.address.id,reference=data.CopyData(reference),builtin=builtin,readOnly=builtin~=nil,
        fallback=not builtin and reference.address.id==profile.rotationFallbackID or false,pending=pending,
        original=pending and nil or data.CopyData(record.body),title=record.body.name or NEW,description=record.body.description or ''}
    workspace.source=record.source
    local baseline=data.CopyData(record.body)
    local function flags()
        workspace.scope=workspace.session and workspace.session:Ownership() or (not builtin and workspace.reference.address.scope)
        if workspace.pending and workspace.session then local staged=coordinator:StagePending(sourceReference,workspace.scope);if staged then workspace.reference=staged end end
        local effective=coordinator:Resolve(spec,DEFAULT)
        workspace.effectiveFallback=effective and equal(effective,workspace.reference) or false
    end
    function workspace:ValidTarget()
        if owner:GetScopedRotationCoordinator()~=coordinator then return false end
        if builtin then return coordinator:Resolve(spec,sourceReference)~=nil end
        if self.pending then return coordinator:IsPending(sourceReference) and coordinator:Resolve(spec,sourceReference)~=nil end
        return coordinator:TokenCurrent(expected)
    end
    local function sessionFor(body)
        workspace.reserved={origins=data.CopyData(record.origin),imports=data.CopyData(record.imported),comparisons=data.CopyData(record.comparison)}
        local used={};for _,component in pairs(workspace.reserved) do local ok,problem=data.ReserveRotationIdentities(component,used);if not ok then return nil,problem.code end end
        local function fresh()
            for _=1,100 do local id=owner.uuid();if not used[id] then used[id]=true;return id end end
        end
        return owner:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=fresh,
            ownership=not builtin and sourceReference.address.scope or nil,setOwnershipAllowed=not builtin,
            targetValid=function() return workspace:ValidTarget() end,
            commit=function(candidate,scope)
                local replacement={body=candidate,origin=record.origin,imported=record.imported,comparison=record.comparison}
                local saved,problem=coordinator:Commit(sourceReference,expected,replacement,scope)
                if not saved then return nil,problem end
                return true,saved
            end})
    end
    local session,problem=sessionFor(baseline);if not session then return nil,problem end;workspace.session=session;flags()
    function workspace:Snapshot() flags();return self.session:Snapshot() end
    function workspace:TargetReference()
        local result=data.CopyData(self.reference)
        if not self.readOnly then
            local c=owner:GetRotationOwnerContext();if not c then return nil,'missing-owner-context' end
            result.address.scope=self.session:Ownership();result.address.owner=result.address.scope=='class' and c.class or c.character
            if not result.address.owner then return nil,'missing-owner-context' end
        end
        return result
    end
    function workspace:Metadata() return {id=self.id,reference=self:TargetReference(),scope=self.session:Ownership(),kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),source=self.source or self.reserved} end
    function workspace:IsDirty() flags();return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if self.fallback and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        if name=='SetOwnership' and (...)=='character' then local c=owner:GetRotationOwnerContext();if not c or not c.character then return nil,'missing-owner-context' end end
        local ok,result=self.session:Command(name,...);flags();return ok,result
    end
    function workspace:Apply()
        if self.pending and not self.fallback then local name=self:Snapshot().name;if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end end
        local ok,why,saved=self.session:Apply();if not ok then return nil,why,saved end
        sourceReference=data.CopyData(saved);self.reference=data.CopyData(saved);self.id=coordinator:Key(saved);self.canonicalId=saved.address.id;self.pending=false
        record,expected,status=coordinator:Snapshot(spec,saved);baseline=data.CopyData(record.body);self.original=data.CopyData(record.body)
        self.title=record.body.name or self.canonicalId;self.description=record.body.description or ''
        local nextSession,problem=sessionFor(baseline);if not nextSession then return nil,problem end;self.session=nextSession;flags();return true,nil,data.CopyData(saved)
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,why=sessionFor(baseline);if not replacement then return nil,why end
        self.session:Cancel();self.session=replacement;flags();return true
    end
    function workspace:ConditionEditorTarget(target)
        local captured=self.session
        local function condition()
            local body=captured:Snapshot();if type(target)=='table' and target.kind=='switch' then return body.switch or {} end
            local tree=data.IndexRotationSteps(body);local row=tree and tree.byId[target];return row and (row.step.conditions or {})
        end
        local baselineCondition=condition();if not baselineCondition then return nil,'missing-rotation-step' end
        local committed=false
        local function valid() return not committed and workspace.session==captured and workspace:ValidTarget() and equal(baselineCondition,condition()) end
        return {condition=data.CopyData(baselineCondition),readOnly=self.readOnly,valid=valid,commit=function(edited)
            if workspace.readOnly then return nil,'readonly-rotation' end;if not valid() then return nil,'condition-target-changed' end
            local ok,why=workspace:Command('SetCondition',target,edited);if ok then committed=true end;return ok,why
        end}
    end
    cache[#cache+1]=workspace;return workspace
end

function addon:GetRotationEditWorkspace(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scopedWorkspace(self,scoped,spec,id) end
    if type(spec)~='number' or spec<0 or spec%1~=0 or type(id)~='string' or id=='' then return nil,'invalid-rotation-target' end
    local profile=self.db.profile
    if type(profile.rotations)~='table' then return nil,'invalid-rotation-storage' end
    local builtin=self:GetDefaultIdForRuntime(spec,id)
    local source,original
    if builtin then
        for _,entry in ipairs(self:ListDefaultRotations(spec)) do if entry.id==builtin then source=entry;break end end
        if not source or not source.envelope then return nil,'unknown-default-rotation' end
    else original=originalAt(profile,spec,id) end
    local cache=profiles[profile]
    if not cache then cache={};profiles[profile]=cache end
    for _,workspace in ipairs(cache) do
        if workspace.spec==spec and workspace.id==id and workspace.builtin==builtin and
            (builtin or workspace.original==original) and workspace:ValidTarget() then return workspace end
    end
    local workspace={spec=spec,id=id,canonicalId=id,builtin=builtin,readOnly=builtin~=nil,fallback=not builtin and id==DEFAULT or false,
        title=source and source.name or id==DEFAULT and DEFAULT or original and original.name or NEW,
        description=source and source.description or original and original.description or '',source=source,original=original,pending=not builtin and original==nil}
    local capturedRoot=profile.rotations
    local value=source and data.CopyData(source.envelope.body) or original
    if not value then value={name=id==DEFAULT and DEFAULT or NEW,switch={},rotation={},cooldowns={}} end
    if builtin then value.name=source.name end
    function workspace:ValidTarget()
        if addon.db.profile~=profile or profile.rotations~=capturedRoot then return false end
        if self.builtin then return addon:GetDefaultIdForRuntime(spec,id)==self.builtin end
        return originalAt(profile,spec,id)==self.original and not addon:GetDefaultIdForRuntime(spec,id)
    end
    local function sessionFor(body)
        return addon:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=addon.uuid,
            reserved=workspace.reserved,newRecord=workspace.pending,targetValid=function() return workspace:ValidTarget() end})
    end
    local reservations,copyError=data.CopyData(retained(profile,spec,id))
    if not reservations then return nil,copyError.code end
    workspace.reserved=reservations
    local session,why=sessionFor(value);if not session then return nil,why end
    workspace.session=session
    function workspace:Snapshot() return self.session:Snapshot() end
    function workspace:Metadata()
        return {id=id,kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),
            source=self.source and data.CopyData(self.source.envelope) or data.CopyData(self.reserved)}
    end
    function workspace:IsDirty() return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if id==DEFAULT and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        return self.session:Command(name,...)
    end
    function workspace:Apply()
        if self.pending and id~=DEFAULT then
            local name=self:Snapshot().name
            if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end
        end
        local ok,reason,details=self.session:Apply();if not ok then return nil,reason,details end
        if self.pending then
            local list=profile.rotations[spec] or {};profile.rotations[spec]=list
            list[id]=value;self.original=value;self.pending=false
        end
        self.title=value.name or id
        local replacement,problem=sessionFor(value)
        if not replacement then return nil,problem end
        self.session=replacement;return true
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,problem=sessionFor(value);if not replacement then return nil,problem end
        self.session:Cancel();self.session=replacement;return true
    end
    function workspace:ConditionEditorTarget(target)
        local sessionToken=self.session
        local function condition()
            local snapshot=sessionToken:Snapshot()
            if type(target)=='table' and target.kind=='switch' then return snapshot.switch or {} end
            local tree=data.IndexRotationSteps(snapshot);local row=tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end
        local baseline=condition();if not baseline then return nil,'missing-rotation-step' end
        local committed=false
        local function valid()
            return not committed and workspace.session==sessionToken and workspace:ValidTarget() and equal(baseline,condition())
        end
        return {condition=data.CopyData(baseline),readOnly=self.readOnly,valid=valid,
            commit=function(edited)
                if workspace.readOnly then return nil,'readonly-rotation' end
                if not valid() then return nil,'condition-target-changed' end
                local ok,reason=workspace:Command('SetCondition',target,edited)
                if ok then committed=true end
                return ok,reason
            end}
    end
    cache[#cache+1]=workspace
    return workspace
end

function addon:GetRotationWorkspace(spec,value)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local reference=scoped and scoped:Resolve(spec,value)
    for _,w in ipairs(profiles[self.db.profile] or {}) do if w.spec==spec and (w.id==value or scoped and reference and equal(w.reference,reference)) and w:ValidTarget() then return w end end
end
function addon:ListPendingRotationDrafts(spec)
    local result={}
    for _,workspace in ipairs(profiles[self.db.profile] or {}) do
        if workspace.spec==spec and workspace.pending and workspace.id~=DEFAULT and workspace:ValidTarget() then
            local snapshot=workspace:Snapshot();result[#result+1]={id=workspace.id,key=workspace.id,reference=workspace.TargetReference and workspace:TargetReference(),canonicalId=workspace.canonicalId,scope=workspace.scope,pending=true,fallback=workspace.fallback,effectiveFallback=false,name=snapshot.name or NEW,presentation={name=snapshot.name,description=snapshot.description,priority=snapshot.priority,tags=snapshot.tags,metadata=snapshot.metadata}}
        end
    end
    return result
end
]======]},
 ['Core/rotation_editor.lua']={old=[======[local _,addon=...
local data=addon.RotationData

local function equal(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    local function compare(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not compare(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return compare(left,right)
end
local function weight(value)
    if type(value)=='string' then return 32+#value end
    if type(value)~='table' then return 16 end
    local total=64;for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end;return total
end

function addon:NewRotationEditSession(spec,original,options)
    options=options or {}
    if type(options)~='table' or getmetatable(options)~=nil or
        options.targetValid~=nil and type(options.targetValid)~='function' or
        options.readOnly~=nil and type(options.readOnly)~='boolean' or
        options.commit~=nil and type(options.commit)~='function' or
        options.ownership~=nil and options.ownership~='class' and options.ownership~='character' or
        options.setOwnershipAllowed~=nil and type(options.setOwnershipAllowed)~='boolean' then return nil,'invalid-rotation-editor-options' end
    local newId=options.newId or self.uuid
    local draft,why=data.NewRotationDraft(original,newId,options.reserved)
    if not draft then return nil,why end
    local baseline=data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline=data.CopyData(original)
    if dirtyBaseline.rotation==nil then dirtyBaseline.rotation={} end
    if dirtyBaseline.cooldowns==nil then dirtyBaseline.cooldowns={} end
    local ownership,originalOwnership=options.ownership,options.ownership
    local readOnly=options.readOnly==true
    local targetValid=options.targetValid
    local closed,busy=false,false
    local undo,redo,bytes={},{},0
    local function push(stack,value)
        local size=weight(value);stack[#stack+1]={value=value,bytes=size};bytes=bytes+size
    end
    local function pop(stack,at)
        local entry=table.remove(stack,at or #stack);if entry then bytes=bytes-entry.bytes end;return entry
    end
    local function trim()
        while #undo+#redo>100 or bytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function writable()
        if closed then return nil,'rotation-editor-closed' end
        if busy then return nil,'rotation-editor-busy' end
        if readOnly then return nil,'readonly-rotation' end
        return true
    end
    local function owner()
        if not targetValid then return true end
        local ok,valid=pcall(targetValid);return ok and valid==true
    end
    local function close() closed=true;undo={};redo={};bytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:Baseline() return data.CopyData(dirtyBaseline) end
    function session:Ownership() return ownership end
    function session:BaselineOwnership() return originalOwnership end
    function session:IsDirty() return ownership~=originalOwnership or not equal(dirtyBaseline,draft:Snapshot()) end
    function session:HistoryState()
        return {canUndo=not closed and not busy and not readOnly and #undo>0,
            canRedo=not closed and not busy and not readOnly and #redo>0}
    end
    function session:Command(name,...)
        local ok,reason=writable();if not ok then return nil,reason end
        local before={body=draft:Snapshot(),ownership=ownership}
        local changed,result
        if name=='SetOwnership' then
            local scope=(...);if not options.setOwnershipAllowed or (scope~='class' and scope~='character') then return nil,'invalid-owner-scope' end
            changed=true;ownership=scope
        else changed,result=draft:Command(name,...) end
        if changed and (before.ownership~=ownership or not equal(before.body,draft:Snapshot())) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return changed,result
    end
    local function travel(source,destination)
        local ok,reason=writable();if not ok then return nil,reason end
        if #source==0 then return nil,'rotation-history-empty' end
        local previous={body=draft:Snapshot(),ownership=ownership}
        local frame=source[#source].value
        local restored,problem=draft:Restore(frame.body)
        if not restored then return nil,problem end
        ownership=frame.ownership
        pop(source);push(destination,previous);trim()
        return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel()
        if busy then return nil,'rotation-editor-busy' end
        close();return true
    end
    function session:Apply()
        local writableOk,reason=writable();if not writableOk then return nil,reason end
        busy=true
        local function finish(ok,problem,details) busy=false;return ok,problem,details end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        local snapshot=draft:Snapshot()
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions())
        if not validation.valid then return finish(nil,'invalid-rotation-data',validation) end
        if not validation.supported then return finish(nil,'unsupported-rotation-data',validation) end
        if not validation.resolved then return finish(nil,'unresolved-rotation-data',validation) end
        local candidate=data.CopyData(snapshot)
        local tree=data.IndexRotationSteps(candidate)
        local function validate()
            local valid=addon:validateCondition(candidate.switch or {},spec)
            for _,row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {},spec) then valid=false end
            end
            return valid
        end
        local ok,valid
        if addon.Diagnostics then ok,valid=addon.Diagnostics:Call({module='rotation-editor',operation='validate',customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return finish(nil,'rotation-validation-error') end
        if not equal(snapshot,candidate) then return finish(nil,'validation-mutated-rotation') end
        if not valid then return finish(nil,'invalid-condition-fields') end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        if options.commit then
            local success,committed,problem,details=pcall(options.commit,snapshot,ownership)
            if not success then return finish(nil,'rotation-commit-error') end
            if not committed then return finish(nil,problem,details) end
            close();return finish(true,nil,problem)
        end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(snapshot) do original[key]=value end
        close();return finish(true)
    end
    return session
end
]======],current=[======[local _,addon=...
local data=addon.RotationData

local function equal(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    local function compare(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not compare(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return compare(left,right)
end
local function weight(value)
    if type(value)=='string' then return 32+#value end
    if type(value)~='table' then return 16 end
    local total=64;for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end;return total
end

function addon:NewRotationEditSession(spec,original,options)
    options=options or {}
    if type(options)~='table' or getmetatable(options)~=nil or
        options.targetValid~=nil and type(options.targetValid)~='function' or
        options.readOnly~=nil and type(options.readOnly)~='boolean' or
        options.newRecord~=nil and type(options.newRecord)~='boolean' or
        options.commit~=nil and type(options.commit)~='function' or
        options.ownership~=nil and options.ownership~='class' and options.ownership~='character' or
        options.setOwnershipAllowed~=nil and type(options.setOwnershipAllowed)~='boolean' then return nil,'invalid-rotation-editor-options' end
    local newId=options.newId or self.uuid
    local draft,why=data.NewRotationDraft(original,newId,options.reserved)
    if not draft then return nil,why end
    local baseline=data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline=data.CopyData(original)
    if dirtyBaseline.rotation==nil then dirtyBaseline.rotation={} end
    if dirtyBaseline.cooldowns==nil then dirtyBaseline.cooldowns={} end
    local ownership,originalOwnership=options.ownership,options.ownership
    local readOnly=options.readOnly==true
    local targetValid=options.targetValid
    local closed,busy=false,false
    local undo,redo,bytes={},{},0
    local function push(stack,value)
        local size=weight(value);stack[#stack+1]={value=value,bytes=size};bytes=bytes+size
    end
    local function pop(stack,at)
        local entry=table.remove(stack,at or #stack);if entry then bytes=bytes-entry.bytes end;return entry
    end
    local function trim()
        while #undo+#redo>100 or bytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function writable()
        if closed then return nil,'rotation-editor-closed' end
        if busy then return nil,'rotation-editor-busy' end
        if readOnly then return nil,'readonly-rotation' end
        return true
    end
    local function owner()
        if not targetValid then return true end
        local ok,valid=pcall(targetValid);return ok and valid==true
    end
    local function close() closed=true;undo={};redo={};bytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:Baseline() return data.CopyData(dirtyBaseline) end
    function session:Ownership() return ownership end
    function session:BaselineOwnership() return originalOwnership end
    function session:IsDirty() return ownership~=originalOwnership or not data.SameRotationContent(dirtyBaseline,draft:Snapshot()) end
    function session:HistoryState()
        return {canUndo=not closed and not busy and not readOnly and #undo>0,
            canRedo=not closed and not busy and not readOnly and #redo>0}
    end
    function session:Command(name,...)
        local ok,reason=writable();if not ok then return nil,reason end
        local before={body=draft:Snapshot(),ownership=ownership}
        local changed,result
        if name=='SetOwnership' then
            local scope=(...);if not options.setOwnershipAllowed or (scope~='class' and scope~='character') then return nil,'invalid-owner-scope' end
            changed=true;ownership=scope
        else changed,result=draft:Command(name,...) end
        if changed and (before.ownership~=ownership or not equal(before.body,draft:Snapshot())) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return changed,result
    end
    local function travel(source,destination)
        local ok,reason=writable();if not ok then return nil,reason end
        if #source==0 then return nil,'rotation-history-empty' end
        local previous={body=draft:Snapshot(),ownership=ownership}
        local frame=source[#source].value
        local restored,problem=draft:Restore(frame.body)
        if not restored then return nil,problem end
        ownership=frame.ownership
        pop(source);push(destination,previous);trim()
        return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel()
        if busy then return nil,'rotation-editor-busy' end
        close();return true
    end
    function session:Apply()
        local writableOk,reason=writable();if not writableOk then return nil,reason end
        busy=true
        local function finish(ok,problem,details) busy=false;return ok,problem,details end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        local snapshot=draft:Snapshot()
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions())
        if not validation.valid then return finish(nil,'invalid-rotation-data',validation) end
        if not validation.supported then return finish(nil,'unsupported-rotation-data',validation) end
        if not validation.resolved then return finish(nil,'unresolved-rotation-data',validation) end
        local candidate=data.CopyData(snapshot)
        local tree=data.IndexRotationSteps(candidate)
        local function validate()
            local valid=addon:validateCondition(candidate.switch or {},spec)
            for _,row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {},spec) then valid=false end
            end
            return valid
        end
        local ok,valid
        if addon.Diagnostics then ok,valid=addon.Diagnostics:Call({module='rotation-editor',operation='validate',customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return finish(nil,'rotation-validation-error') end
        if not equal(snapshot,candidate) then return finish(nil,'validation-mutated-rotation') end
        if not valid then return finish(nil,'invalid-condition-fields') end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        if options.commit then
            local success,committed,problem,details=pcall(options.commit,snapshot,ownership)
            if not success then return finish(nil,'rotation-commit-error') end
            if not committed then return finish(nil,problem,details) end
            close();return finish(true,nil,problem)
        end
        local previous
        if not options.newRecord then
            previous=data.CopyData(original)
            if not previous then return finish(nil,'invalid-rotation-data') end
            if previous.rotation==nil then previous.rotation={} end
            if previous.cooldowns==nil then previous.cooldowns={} end
        end
        local saved,problem=data.PrepareRotationContentRevision(snapshot,previous,options.newRecord and 'create' or 'edit',ownership~=originalOwnership)
        if not saved then return finish(nil,problem) end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(saved) do original[key]=value end
        close();return finish(true)
    end
    return session
end
]======]},
 ['Core/imports.lua']={old=[======[local _,addon=...
local data=addon.RotationData
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
local function settings(self)
    local options=self:GetRotationValidationOptions();return options
end
function addon:GetImportValidationOptions() return settings(self) end
function addon:GetImportedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,true) end
    local state=self.db.profile.rotationLibrary
    if state==nil then return nil,"not-imported" end
    if not plain(state) then return nil,"invalid-import-state" end
    if state.imports==nil then return nil,"not-imported" end
    if not plain(state.imports) then return nil,"invalid-import-state" end
    local rows=state.imports[spec]
    if rows==nil then return nil,"not-imported" end
    if not plain(rows) then return nil,"invalid-import-state" end
    if rows[id]==nil then return nil,"not-imported" end
    local record,why=data.CopyData(rows[id])
    if why or not plain(record) or not plain(record.manifest) or record.manifest.id~=id
        or type(record.sourceId)~="string" or not plain(record.stepOrigins) then return nil,"invalid-import-state" end
    local body=self:GetEditableRotation(spec,id)
    local envelope=data.CopyData(record.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-import-state" end
    return {envelope=envelope,applicability=envelope.applicability,enabled=true,
        validation=data.ValidateEnvelope(envelope,settings(self)),sourceId=record.sourceId,
        sourceRevision=record.sourceRevision,stepOrigins=record.stepOrigins}
end
function addon:CreateImportedRotation(prepared,spec,name,replacement,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Import(prepared,spec,name,replacement,options) end
    if type(spec)~="number" or spec<0 or spec%1~=0 then return nil,"invalid-specialization" end
    if type(name)~="string" or #name==0 or #name>256 then return nil,"invalid-name" end
    local rotationsRoot=self.db.profile.rotations
    if rotationsRoot~=nil and not plain(rotationsRoot) then return nil,"invalid-rotation-storage" end
    if rotationsRoot and rotationsRoot[spec]~=nil and not plain(rotationsRoot[spec]) then return nil,"invalid-rotation-storage" end
    local body,problem=data.CopyData(prepared.body)
    if problem or not plain(body) then return nil,"invalid-import" end
    local manifest=prepared.manifest and data.CopyData(prepared.manifest)
    if prepared.manifest and not manifest then return nil,"invalid-import" end
    local result
    if manifest then
        local envelope=data.CopyData(manifest);envelope.body=body
        result=data.ValidateEnvelope(envelope,settings(self))
    else result=data.ValidateBody(body,settings(self)) end
    if not result.valid or not result.supported or not result.resolved then return nil,"import-not-ready" end
    local ok,why=self:InitializeRotationLibrary();if not ok then return nil,why end
    local state=self.db.profile.rotationLibrary
    for _,kind in ipairs({"origins","comparisons","imports"}) do if state[kind][spec]~=nil and not plain(state[kind][spec]) then return nil,"invalid-import-state" end end
    local used={}
    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    local function reserve(value)
        if type(value)=="string" then used[value]=true
        elseif type(value)=="table" then for key,child in pairs(value) do reserve(key);reserve(child) end end
    end
    for _,rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id,rotation in pairs(rotations) do
                used[id]=true
                local copy=data.CopyData(rotation);if copy then reserve(copy) end
            end
        end
    end
    for _,kind in ipairs({"origins","comparisons","imports"}) do
        for _,rows in pairs(state[kind]) do
            if plain(rows) then for id,record in pairs(rows) do
                used[id]=true;local copy=data.CopyData(record);if copy then reserve(copy) end
            end end
        end
    end
    for _,row in ipairs(self:ListDefaultRotations(spec)) do reserve(row.envelope) end
    reserve(body);reserve(manifest)
    local function fresh()
        local success,id=pcall(self.uuid)
        if not success or type(id)~="string" or #id>128 or not id:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[id] then return nil,"id-collision" end
        used[id]=true;return id
    end
    local id,errorCode;if replacement then id=replacement.id else id,errorCode=fresh() end;if not id then return nil,errorCode end
    local sourceId=prepared.sourceId or manifest and manifest.id
    local sourceRevision=prepared.sourceRevision or manifest and manifest.revision
    local origins={}
    local tree,treeError=data.IndexRotationSteps(body)
    if not tree then return nil,treeError.code end
    for _,row in ipairs(tree.rows) do
        local step=row.step
        local stepId,reason=fresh();if not stepId then return nil,reason end
        origins[stepId]=prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id=stepId
    end
    body.name=name
    if manifest then manifest.id=id;manifest.revision=1;manifest.nameKey=name end
    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then return nil,'rotation-changed-externally' end
    local rotations=rotationsRoot and rotationsRoot[spec] or {}
    self.db.profile.rotations=rotationsRoot or {}
    self.db.profile.rotations[spec]=rotations;rotations[id]=body
    if replacement then
        for _,kind in ipairs({'origins','comparisons','imports'}) do if type(state[kind][spec])=='table' then state[kind][spec][id]=nil end end
    end
    if manifest then
        local rows=state.imports[spec] or {};state.imports[spec]=rows
        rows[id]={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
    end
    return id
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:ApplyRotationImport(session,token,spec,name,target,expected,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local prepared,why=session:GetReady(token);if not prepared then return nil,why end
        if not target then return self:CreateImportedRotation(prepared,spec,name,nil,options) end
        local reference,referenceReason=scoped:Resolve(spec,target);if not reference then return nil,referenceReason end
        if reference.kind~='custom' then return nil,'read-only-rotation' end
        if type(expected)~='table' or expected.profile~=self.db.profile then return nil,'rotation-changed-externally' end
        local workspace=self.GetRotationWorkspace and self:GetRotationWorkspace(spec,reference);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end
        local record,token=scoped:Snapshot(spec,reference);if not record then return nil,token end
        if expected.recordToken then
            if not equal(expected.reference,reference) then return nil,'rotation-changed-externally' end;token=expected.recordToken
        else
            local original=self:GetEditableRotation(spec,reference)
            if expected.target~=original or not data.CheckPortable(original) or not equal(original,expected.body) then return nil,'rotation-changed-externally' end
        end
        local id,commitReason,saved=self:CreateImportedRotation(prepared,spec,record.body.name or name,{profile=self.db.profile,reference=reference,recordToken=token},options)
        if not id then return nil,commitReason end
        if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
        return id,nil,saved
    end
    local prepared,why=session:GetReady(token);if not prepared then return nil,why end
    if not target then return self:CreateImportedRotation(prepared,spec,name) end
    local profile=self.db.profile;local original=self:GetEditableRotation(spec,target)
    local function valid()
        return self.db.profile==profile and type(expected)=='table' and expected.profile==profile and expected.target==original and original~=nil and self:GetEditableRotation(spec,target)==original and equal(original,expected.body) and not self:GetDefaultIdForRuntime(spec,target)
    end
    if not valid() then return nil,'rotation-changed-externally' end
    if self.GetRotationWorkspace then local workspace=self:GetRotationWorkspace(spec,target);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end end
    local id,reason=self:CreateImportedRotation(prepared,spec,original.name or name,{id=target,valid=valid})
    if not id then return nil,reason end
    if self.currentSpec==spec and self.currentRotation==target then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() elseif self.GlowClear then self:GlowClear() end
        self.currentSpell=nil;self.avail_announced={};self.announced={};self.skipAnnounce=true
    end
    if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
    return id
end

function addon:GetRotationExportData(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local record,why=scoped:Snapshot(spec,id);if not record then return nil,why end
        local result
        if record.source then result=record.source.envelope
        elseif record.origin or record.imported then local retained=record.origin or record.imported;result=data.CopyData(retained.manifest);result.body=record.body
        else return record.body end
        if result.body.tags~=nil then result.tags=data.CopyData(result.body.tags) end;return result
    end
    local function currentTags(envelope)
        if type(envelope)=='table' and type(envelope.body)=='table' and envelope.body.tags~=nil then
            local copy,why=data.CopyData(envelope);if not copy then return nil,why end
            copy.tags=data.CopyData(copy.body.tags);return copy
        end
        return envelope
    end
    local defaultId=self:GetDefaultIdForRuntime(spec,id)
    if defaultId then return currentTags(self:GetDefaultRotation(defaultId).envelope) end
    local source,why=self:GetSourcedRotationView(spec,id)
    if source then return currentTags(source.envelope) end
    if why~="no-source-baseline" then return nil,why end
    local imported,reason=self:GetImportedRotationView(spec,id)
    if imported then return currentTags(imported.envelope) end
    if reason~="not-imported" then return nil,reason end
    return data.CopyData(self:GetEditableRotation(spec,id))
end
]======],current=[======[local _,addon=...
local data=addon.RotationData
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
local function settings(self)
    local options=self:GetRotationValidationOptions();return options
end
function addon:GetImportValidationOptions() return settings(self) end
function addon:GetImportedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,true) end
    local state=self.db.profile.rotationLibrary
    if state==nil then return nil,"not-imported" end
    if not plain(state) then return nil,"invalid-import-state" end
    if state.imports==nil then return nil,"not-imported" end
    if not plain(state.imports) then return nil,"invalid-import-state" end
    local rows=state.imports[spec]
    if rows==nil then return nil,"not-imported" end
    if not plain(rows) then return nil,"invalid-import-state" end
    if rows[id]==nil then return nil,"not-imported" end
    local record,why=data.CopyData(rows[id])
    if why or not plain(record) or not plain(record.manifest) or record.manifest.id~=id
        or type(record.sourceId)~="string" or not plain(record.stepOrigins) then return nil,"invalid-import-state" end
    local body=self:GetEditableRotation(spec,id)
    local envelope=data.CopyData(record.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-import-state" end
    return {envelope=envelope,applicability=envelope.applicability,enabled=true,
        validation=data.ValidateEnvelope(envelope,settings(self)),sourceId=record.sourceId,
        sourceRevision=record.sourceRevision,stepOrigins=record.stepOrigins}
end
function addon:CreateImportedRotation(prepared,spec,name,replacement,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Import(prepared,spec,name,replacement,options) end
    if type(spec)~="number" or spec<0 or spec%1~=0 then return nil,"invalid-specialization" end
    if type(name)~="string" or #name==0 or #name>256 then return nil,"invalid-name" end
    local profile=self.db.profile
    local rotationsRoot=profile.rotations
    if rotationsRoot~=nil and not plain(rotationsRoot) then return nil,"invalid-rotation-storage" end
    if rotationsRoot and rotationsRoot[spec]~=nil and not plain(rotationsRoot[spec]) then return nil,"invalid-rotation-storage" end
    local body,problem=data.CopyData(prepared.body)
    if problem or not plain(body) then return nil,"invalid-import" end
    local manifest=prepared.manifest and data.CopyData(prepared.manifest)
    if prepared.manifest and not manifest then return nil,"invalid-import" end
    local result
    if manifest then
        local envelope=data.CopyData(manifest);envelope.body=body
        result=data.ValidateEnvelope(envelope,settings(self))
    else result=data.ValidateBody(body,settings(self)) end
    if not result.valid or not result.supported or not result.resolved then return nil,"import-not-ready" end
    local ok,why=self:InitializeRotationLibrary();if not ok then return nil,why end
    local state=self.db.profile.rotationLibrary
    for _,kind in ipairs({"origins","comparisons","imports"}) do if state[kind][spec]~=nil and not plain(state[kind][spec]) then return nil,"invalid-import-state" end end
    local used={}
    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    local function reserve(value)
        if type(value)=="string" then used[value]=true
        elseif type(value)=="table" then for key,child in pairs(value) do reserve(key);reserve(child) end end
    end
    for _,rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id,rotation in pairs(rotations) do
                used[id]=true
                local copy=data.CopyData(rotation);if copy then reserve(copy) end
            end
        end
    end
    for _,kind in ipairs({"origins","comparisons","imports"}) do
        for _,rows in pairs(state[kind]) do
            if plain(rows) then for id,record in pairs(rows) do
                used[id]=true;local copy=data.CopyData(record);if copy then reserve(copy) end
            end end
        end
    end
    for _,row in ipairs(self:ListDefaultRotations(spec)) do reserve(row.envelope) end
    reserve(body);reserve(manifest)
    local function fresh()
        local success,id=pcall(self.uuid)
        if not success or type(id)~="string" or #id>128 or not id:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[id] then return nil,"id-collision" end
        used[id]=true;return id
    end
    local id,errorCode;if replacement then id=replacement.id else id,errorCode=fresh() end;if not id then return nil,errorCode end
    local sourceId=prepared.sourceId or manifest and manifest.id
    local sourceRevision=prepared.sourceRevision or manifest and manifest.revision
    local origins={}
    local tree,treeError=data.IndexRotationSteps(body)
    if not tree then return nil,treeError.code end
    for _,row in ipairs(tree.rows) do
        local step=row.step
        local stepId,reason=fresh();if not stepId then return nil,reason end
        origins[stepId]=prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id=stepId
    end
    body.name=name
    local previous=replacement and self:GetEditableRotation(spec,id) or nil
    local revised,revisionError=data.PrepareRotationContentRevision(body,previous,replacement and 'edit' or 'import',replacement~=nil)
    if not revised then return nil,revisionError end
    body=revised
    if manifest then manifest.id=id;manifest.revision=1;manifest.nameKey=name end
    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then return nil,'rotation-changed-externally' end
    if self.db.profile~=profile or profile.rotations~=rotationsRoot or profile.rotationLibrary~=state then return nil,'rotation-changed-externally' end
    local rotations=rotationsRoot and rotationsRoot[spec] or {}
    if replacement and rotations[id]~=previous then return nil,'rotation-changed-externally' end
    if not replacement and rotations[id]~=nil then return nil,'id-collision' end
    self.db.profile.rotations=rotationsRoot or {}
    self.db.profile.rotations[spec]=rotations;rotations[id]=body
    if replacement then
        for _,kind in ipairs({'origins','comparisons','imports'}) do if type(state[kind][spec])=='table' then state[kind][spec][id]=nil end end
    end
    if manifest then
        local rows=state.imports[spec] or {};state.imports[spec]=rows
        rows[id]={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
    end
    return id
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:ApplyRotationImport(session,token,spec,name,target,expected,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local prepared,why=session:GetReady(token);if not prepared then return nil,why end
        if not target then return self:CreateImportedRotation(prepared,spec,name,nil,options) end
        local reference,referenceReason=scoped:Resolve(spec,target);if not reference then return nil,referenceReason end
        if reference.kind~='custom' then return nil,'read-only-rotation' end
        if type(expected)~='table' or expected.profile~=self.db.profile then return nil,'rotation-changed-externally' end
        local workspace=self.GetRotationWorkspace and self:GetRotationWorkspace(spec,reference);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end
        local record,token=scoped:Snapshot(spec,reference);if not record then return nil,token end
        if expected.recordToken then
            if not equal(expected.reference,reference) then return nil,'rotation-changed-externally' end;token=expected.recordToken
        else
            local original=self:GetEditableRotation(spec,reference)
            if expected.target~=original or not data.CheckPortable(original) or not equal(original,expected.body) then return nil,'rotation-changed-externally' end
        end
        local id,commitReason,saved=self:CreateImportedRotation(prepared,spec,record.body.name or name,{profile=self.db.profile,reference=reference,recordToken=token},options)
        if not id then return nil,commitReason end
        if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
        return id,nil,saved
    end
    local prepared,why=session:GetReady(token);if not prepared then return nil,why end
    if not target then return self:CreateImportedRotation(prepared,spec,name) end
    local profile=self.db.profile;local original=self:GetEditableRotation(spec,target)
    local function valid()
        return self.db.profile==profile and type(expected)=='table' and expected.profile==profile and expected.target==original and original~=nil and self:GetEditableRotation(spec,target)==original and equal(original,expected.body) and not self:GetDefaultIdForRuntime(spec,target)
    end
    if not valid() then return nil,'rotation-changed-externally' end
    if self.GetRotationWorkspace then local workspace=self:GetRotationWorkspace(spec,target);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end end
    local id,reason=self:CreateImportedRotation(prepared,spec,original.name or name,{id=target,valid=valid})
    if not id then return nil,reason end
    if self.currentSpec==spec and self.currentRotation==target then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() elseif self.GlowClear then self:GlowClear() end
        self.currentSpell=nil;self.avail_announced={};self.announced={};self.skipAnnounce=true
    end
    if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
    return id
end

function addon:GetRotationExportData(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local record,why=scoped:Snapshot(spec,id);if not record then return nil,why end
        local result
        if record.source then result=record.source.envelope
        elseif record.origin or record.imported then local retained=record.origin or record.imported;result=data.CopyData(retained.manifest);result.body=record.body
        else return record.body end
        if result.body.tags~=nil then result.tags=data.CopyData(result.body.tags) end;return result
    end
    local function currentTags(envelope)
        if type(envelope)=='table' and type(envelope.body)=='table' and envelope.body.tags~=nil then
            local copy,why=data.CopyData(envelope);if not copy then return nil,why end
            copy.tags=data.CopyData(copy.body.tags);return copy
        end
        return envelope
    end
    local defaultId=self:GetDefaultIdForRuntime(spec,id)
    if defaultId then return currentTags(self:GetDefaultRotation(defaultId).envelope) end
    local source,why=self:GetSourcedRotationView(spec,id)
    if source then return currentTags(source.envelope) end
    if why~="no-source-baseline" then return nil,why end
    local imported,reason=self:GetImportedRotationView(spec,id)
    if imported then return currentTags(imported.envelope) end
    if reason~="not-imported" then return nil,reason end
    return data.CopyData(self:GetEditableRotation(spec,id))
end
]======]},
 ['validate.lua']={old=[======[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]======],current=[======[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        revision = 1,
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]======]},
}
return function(text,path)
 local row=rows[path];assert(row,'unknown persistent-revision inverse path: '..tostring(path))
 assert(text==row.current,'unrelated persistent-revision source delta: '..path)
 return row.old
end
