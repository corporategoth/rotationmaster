-- Strict test-only inverse of three MobInfo2 evaluators from d8918d1.
local original,repaired={},{}
original["RUNNER"]=[=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        return (data.lowHpAction and true or false)
    end,]=]
repaired["RUNNER"]=[=[    evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"runner",nil,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        return observation.runner
    end,]=]
original["RESIST"]=[=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] > 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return Functions.values.compare(value.operator, (data.resists[value.school] / hits), value.value)
        end
        return false
    end,]=]
repaired["RESIST"]=[=[    evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"resist",value.school,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        return Functions.values.compare(value.operator,observation.ratio,value.value)
    end,]=]
original["IMMUNE"]=[=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local data = MI2_GetMobData(UnitName(value.unit), UnitLevel(value.unit), value.unit)
        if data.resists[value.school] ~= nil and data.resists[value.school] < 0 then
            local hits = data.resists[value.school .. 'Hits'] or 1
            return value.partial or (hits < 1)
        end
        return false
    end,]=]
repaired["IMMUNE"]=[=[    evaluate = function(value, cache)
        local observation,reason=addon.Platform:GetMobInfo2Observation(value.unit,"immune",value.school,cache)
        if observation==nil then return nil,reason end
        if not observation.exists or observation.recorded==false then return false end
        if value.partial then return value.partial end
        if observation.hits==nil then return nil,observation.hitsReason end
        return observation.hits < 1
    end,]=]
-- whole ea9510de
local oldHashes,oldBindings={},{}
oldHashes["RUNNER"]="47b926a6"
oldBindings["RUNNER"]={
 ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
 ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
 ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
 ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
 ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
 ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
 ["Functions.values.compare"]="builtin:utils.lua:compare",
 ["Functions.values.isin"]="builtin:utils.lua:isin",
 ["color"]="builtin:Conditions/character.lua:color",
 ["helpers"]="builtin:Conditions/character.lua:helpers",
}
oldHashes["RESIST"]="72839c13"
oldBindings["RESIST"]={
 ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
 ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
 ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
 ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
 ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
 ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
 ["Functions.values.compare"]="builtin:utils.lua:compare",
 ["Functions.values.isin"]="builtin:utils.lua:isin",
 ["color"]="builtin:Conditions/character.lua:color",
 ["helpers"]="builtin:Conditions/character.lua:helpers",
}
oldHashes["IMMUNE"]="b6f236ba"
oldBindings["IMMUNE"]={
 ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
 ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
 ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
 ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
 ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
 ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
 ["Functions.values.compare"]="builtin:utils.lua:compare",
 ["Functions.values.isin"]="builtin:utils.lua:isin",
 ["color"]="builtin:Conditions/character.lua:color",
 ["helpers"]="builtin:Conditions/character.lua:helpers",
}
local oldBodies,newBodies={},{}
for _,tag in ipairs({'RUNNER','RESIST','IMMUNE'}) do
 oldBodies[tag]=assert(original[tag]:match('evaluate = function%(value, cache%)(.*)end,$'))
 newBodies[tag]=assert(repaired[tag]:match('evaluate = function%(value, cache%)(.*)end,$'))
end
return function(text,tag,callback)
 assert(type(text)=='string','expected MobInfo2 source')
 if callback then assert(newBodies[tag] and text==newBodies[tag],'unexpected MobInfo2 callback body/tag');return oldBodies[tag] end
 assert(tag==nil or repaired[tag],'unexpected MobInfo2 tag')
 for _,selected in ipairs(tag and {tag} or {'RUNNER','RESIST','IMMUNE'}) do
  local first,last=text:find(repaired[selected],1,true)
  assert(first and not text:find(repaired[selected],last+1,true),'unexpected MobInfo2 evaluator count/body')
  text=text:sub(1,first-1)..original[selected]..text:sub(last+1)
 end
 return text
end,oldBodies,newBodies,oldBindings,oldHashes
