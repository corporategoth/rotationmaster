-- Strict test-only inverse of exactly two ROLE evaluator repairs from087a686.
local original,repaired={},{}
original["inspect"]=[=[        evaluate = function(value, cache)
            if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
            local role = select(6, Functions.cache.getCached(cache, GetSpecializationInfoByID, Functions.cache.getCached(cache, GetInspectSpecialization, value.unit)))
            return role == value.value
        end,]=]
repaired["inspect"]=[=[        evaluate = function(value, cache)
            local role,reason=Functions.cache.getCached(cache, addon.Platform.GetInspectRoleObservation, addon.Platform, value.unit)
            if role==nil then return nil,reason end
            if role==false then return false end
            return role == value.value
        end,]=]
original["talent"]=[=[            evaluate = function(value, cache)
                return Functions.cache.getCached(cache, GetTalentGroupRole, addon.currentSpec) == value.value
            end,]=]
repaired["talent"]=[=[            evaluate = function(value, cache)
                local role,reason=Functions.cache.getCached(cache, addon.Platform.GetTalentGroupRoleObservation, addon.Platform, addon.currentSpec)
                if role==nil then return nil,reason end
                return role == value.value
            end,]=]
local oldBindings={
 ["inspect"]={
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
 },
 ["talent"]={
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
 },
}
local oldBodies,newBodies={},{}
for _,variant in ipairs({'inspect','talent'}) do
 oldBodies[variant]=assert(original[variant]:match('evaluate = function%(value, cache%)(.*)end,$'))
 newBodies[variant]=assert(repaired[variant]:match('evaluate = function%(value, cache%)(.*)end,$'))
end
return function(text,variant,callback)
 assert(type(text)=='string','expected ROLE source')
 if callback then assert(newBodies[variant] and text==newBodies[variant],'unexpected ROLE callback body/variant');return oldBodies[variant] end
 assert(variant==nil or repaired[variant],'unexpected ROLE variant')
 for _,selected in ipairs(variant and {variant} or {'inspect','talent'}) do
  local first,last=text:find(repaired[selected],1,true)
  assert(first and not text:find(repaired[selected],last+1,true),'unexpected ROLE evaluator count/body')
  text=text:sub(1,first-1)..original[selected]..text:sub(last+1)
 end
 return text
end,oldBodies,newBodies,oldBindings
