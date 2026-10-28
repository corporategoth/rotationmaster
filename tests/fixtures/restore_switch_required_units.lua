-- Exact Switch followup stage. Current deployed UI bytes and older2a bytes
-- are qualified explicitly; all existing downstream whole-file proofs remain.
local function digest(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return n
end

local records = {}

records[ [====[main.lua]====] ] = {
    bytes = 94453,
    hash = 3541972621,
    oldBytes = 93471,
    oldHash = 3850154809,
    legacyBytes = 93471,
    legacyHash = 3850154809,
    changes = {
        {
            at = 38381,
            current = [====[        local matched=rotations[v] and switchConditionMatches(rotations[v].switch,switchOwnerCurrent)
        if not switchOwnerCurrent()then return end
        if matched then
]====],
            previous = [====[        if rotations[v] and addon:evaluateCondition(rotations[v].switch) then
]====],
        },
        {
            at = 38015,
            current = [====[        if not switchOwnerCurrent()then return end
]====],
            previous = [====[]====],
        },
        {
            at = 37272,
            current = [====[    -- BEGIN SWITCH OWNER LEASE
    local function switchOwnerCurrent()
        return activeChangeCurrent(self,change) and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
            and self.currentRotation==selectedRotation and not self.db.profile.disable_autoswitch and not self.manualRotation
    end
    -- END SWITCH OWNER LEASE
]====],
            previous = [====[]====],
        },
        {
            at = 234,
            current = [====[-- BEGIN SWITCH UNIT HANDOFF
local switchConditionEvaluator
local consumeSwitch=addon.ConsumeSwitchConditionEvaluator
if type(consumeSwitch)=='function'then
    switchConditionEvaluator=consumeSwitch(addon)
    addon.ConsumeSwitchConditionEvaluator=nil
end
local function switchConditionMatches(value,current)
    if switchConditionEvaluator then return switchConditionEvaluator(addon,value,current)end
    return addon:evaluateCondition(value)
end
-- END SWITCH UNIT HANDOFF
]====],
            previous = [====[]====],
        },
    },
}

records[ [====[Core/conditions.lua]====] ] = {
    bytes = 28924,
    hash = 823196556,
    oldBytes = 23874,
    oldHash = 18706008,
    legacyBytes = 21927,
    legacyHash = 4083199220,
    changes = {
        {
            at = 27647,
            current = [====[-- BEGIN SWITCH CONDITION EVALUATOR
local ownedConditionEvaluator=addon.evaluateCondition
local ownedConditionResult=addon.evaluateConditionResult
local switchEnvironment=getfenv(1)
---@type fun(f: number|function): table
local switchGetfenv=getfenv
local switchBound=false
function addon:ConsumeSwitchConditionEvaluator()
    if self~=addon or switchBound then return end
    switchBound=true
    return function(owner,value,current)
        local method=owner.evaluateCondition
        if current and not current()then return false end
        if method~=ownedConditionEvaluator or owner.evaluateConditionResult~=ownedConditionResult
            or switchGetfenv(ownedConditionEvaluator)~=switchEnvironment
            or switchGetfenv(ownedConditionResult)~=switchEnvironment then return method(owner,value) end
        local result=evaluate(value,{},GetTime(),{active={},count=0,switchUnits=true,switchCurrent=current},0,"switch")
        return result.status=="match"
    end
end
-- END SWITCH CONDITION EVALUATOR

]====],
            previous = [====[]====],
        },
        {
            at = 9717,
            current = [====[        elseif state.switchUnits then
            result=evaluateSwitchLeaf(value,definition,cache,start,state,path)
]====],
            previous = [====[]====],
        },
        {
            at = 2198,
            current = [====[

-- BEGIN SWITCH UNIT PRESENCE
local function switchReadable(platform,value,current)
    if current and not current()then return false end
    local method=platform and platform.CanReadValue
    if current and not current()then return false end
    if type(method)~='function'then return false end
    local ok,readable=pcall(method,platform,value)
    return (not current or current()) and ok and readable==true
end
local function switchUnitWitness(value,definition,state)
    local fields=definition.fields
    if type(fields)~='table' or rawget(fields,'unit')~='string' then return true end
    local platform=addon.Platform
    local unit,tag=value.unit,value.type
    if not switchReadable(platform,unit,state.switchCurrent)then return nil,'switch-unit-unavailable' end
    local function current()
        return (not state.switchCurrent or state.switchCurrent()) and addon.Platform==platform and switchReadable(platform,value.unit,state.switchCurrent) and switchReadable(platform,value.type,state.switchCurrent)
            and value.unit==unit and value.type==tag and conditions[tag]==definition and definition.fields==fields
            and rawget(fields,'unit')=='string' and (not state.switchCurrent or state.switchCurrent())
    end
    -- Player and legacy omitted-unit fields need identity fences, no presence API.
    if unit==nil or unit=='player'then return current end
    if type(unit)~='string' or not addon.units or addon.units[unit]==nil then return nil,'switch-unit-unavailable' end
    local method=platform.GetUnitPresenceObservation
    if type(method)~='function'then return nil,'switch-unit-unavailable' end
    local function present()
        if not current() or platform.GetUnitPresenceObservation~=method or state.switchCurrent and not state.switchCurrent() then return false end
        local ok,exists=pcall(method,platform,unit)
        return ok and switchReadable(platform,exists,state.switchCurrent) and exists==true and current()
            and platform.GetUnitPresenceObservation==method and (not state.switchCurrent or state.switchCurrent())
    end
    if not present()then return nil,'switch-unit-unavailable' end
    -- Valid/evaluate callbacks can change native unit state synchronously. Keep
    -- these cold checks fresh instead of retaining a positive snapshot.
    return present
end
local function evaluateSwitchLeaf(value,definition,cache,start,state,path)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    local witness,reason=switchUnitWitness(value,definition,state)
    if not witness then return outcome("unavailable",reason,path)end
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    local validOk,valid=callCondition(definition,"valid",value,cache,start,path,state.context)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    if type(witness)=='function' and not witness()then return outcome("unavailable","switch-unit-changed",path)end
    if not validOk then return outcome("unavailable","condition-callback-error",path)end
    if not valid then return outcome("unavailable","invalid-condition-fields",path)end
    local evalOk,matched,evalReason=callCondition(definition,"evaluate",value,cache,start,path,state.context)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    if type(witness)=='function' and not witness()then return outcome("unavailable","switch-unit-changed",path)end
    if not evalOk then return outcome("unavailable","condition-callback-error",path)end
    if matched==nil and evalReason~=nil then return outcome("unavailable",evalReason,path)end
    return outcome(matched and "match" or "no-match")
end
-- END SWITCH UNIT PRESENCE
]====],
            previous = [====[]====],
        },
    },
}

records[ [====[tools/check]====] ] = {
    bytes = 40229,
    hash = 3807220061,
    oldBytes = 40111,
    oldHash = 1154464806,
    legacyBytes = 39847,
    legacyHash = 93498584,
    changes = {
        {
            at = 24816,
            current = [====[            ['lua5.1', 'tests/switch_required_units.lua'],
            ['luajit', 'tests/switch_required_units.lua'],
]====],
            previous = [====[]====],
        },
    },
}

records[ [====[Web/schema/catalog.json]====] ] = {
    bytes = 32746,
    hash = 839979888,
    oldBytes = 32746,
    oldHash = 3340804948,
    legacyBytes = 32746,
    legacyHash = 4145159731,
    changes = {
        {
            at = 31523,
            current = [====[0ef42ff97889bb02cb5cdb951ef203803333fe777a4ca35b9254f93d44b0e17d]====],
            previous = [====[5992158fa0a143839b80e7280154d1d72ac0fd7aa09779dabae25a91dad1f6fe]====],
        },
    },
}

return function(value, path)
    local row = records[path]

    if not row then
        return value
    end
    if #value == row.oldBytes and digest(value) == row.oldHash then
        return value
    end
    if #value == row.legacyBytes and digest(value) == row.legacyHash then
        return value
    end

    assert(#value == row.bytes and digest(value) == row.hash, 'unrelated complete Switch followup source: ' .. path)

    for _, change in ipairs(row.changes) do
        assert(
            value:sub(change.at, change.at + #change.current - 1) == change.current,
            'Switch followup inverse hunk drift'
        )

        value = value:sub(1, change.at - 1) .. change.previous .. value:sub(change.at + #change.current)
    end

    assert(
        #value == row.oldBytes and digest(value) == row.oldHash,
        'Switch followup deployed predecessor differs: ' .. path
    )

    return value
end
