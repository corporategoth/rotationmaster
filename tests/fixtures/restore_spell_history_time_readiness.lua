-- Strict inverses of only two consumed-timestamp readiness bodies against actual4d1c4a9.
local old={
SPELL_HISTORY_TIME=[====[ -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        for _, entry in pairs(addon.spellHistory) do
            local matches = entry.spell == spellid and Functions.values.compare(value.operator, (evalStart - entry.time), value.value)
            if matches ~= false then return matches end
        end
        return false
    ]====],
PETSPELL_HISTORY_TIME=[====[ -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        for _, entry in pairs(addon.spellHistory) do
            local matches = entry.spell == spellid and Functions.values.compare(value.operator, (evalStart - entry.time), value.value)
            if matches ~= false then return matches end
        end
        return false
    ]====],
}
local repaired={
SPELL_HISTORY_TIME=[====[ -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        for _, entry in pairs(addon.spellHistory) do
            if entry.spell == spellid then
                local compare,operator=Functions.values.compare,value.operator
                local recorded=entry.time
                if not addon.Platform:CanReadValue(evalStart) or not addon.Platform:CanReadValue(recorded) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart==math.huge or evalStart==-math.huge
                    or type(recorded)~='number' or recorded~=recorded or recorded==math.huge or recorded==-math.huge then return nil,'history-time-unavailable' end
                local elapsed=evalStart-recorded
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed==math.huge or elapsed==-math.huge then return nil,'history-time-unavailable' end
                local matches=compare(operator,elapsed,value.value)
                if matches ~= false then return matches end
            end
        end
        return false
    ]====],
PETSPELL_HISTORY_TIME=[====[ -- Cooldown until the spell is available
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        for _, entry in pairs(addon.spellHistory) do
            if entry.spell == spellid then
                local compare,operator=Functions.values.compare,value.operator
                local recorded=entry.time
                if not addon.Platform:CanReadValue(evalStart) or not addon.Platform:CanReadValue(recorded) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart==math.huge or evalStart==-math.huge
                    or type(recorded)~='number' or recorded~=recorded or recorded==math.huge or recorded==-math.huge then return nil,'history-time-unavailable' end
                local elapsed=evalStart-recorded
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed==math.huge or elapsed==-math.huge then return nil,'history-time-unavailable' end
                local matches=compare(operator,elapsed,value.value)
                if matches ~= false then return matches end
            end
        end
        return false
    ]====],
}
local signatures={
SPELL_HISTORY_TIME=[====[evaluate = function(value, _, evalStart)]====],
PETSPELL_HISTORY_TIME=[====[evaluate = function(value, cache, evalStart)]====],
}
local hashes={
SPELL_HISTORY_TIME=[====[1c2d995c]====],
PETSPELL_HISTORY_TIME=[====[90af9343]====],
}
local paths={['Conditions/spell.lua']='SPELL_HISTORY_TIME',['Conditions/petspell.lua']='PETSPELL_HISTORY_TIME'}
local function hash(text)local h=5381;for i=1,#text do h=(h*33+text:byte(i))%4294967296 end;return string.format('%08x',h)end
local function inverse(text,path,callback)
 assert(type(text)=='string','time readiness inverse requires text');local tag=paths[path] or path
 if callback then assert(repaired[tag] and text==repaired[tag],'unexpected time readiness callback');return old[tag]end
 if not tag then for key,body in pairs(repaired)do if text:find(signatures[key]..body..'end,',1,true)then assert(not tag,'ambiguous module');tag=key end end end
 assert(repaired[tag],'unknown readiness module')
 local from,to=signatures[tag]..repaired[tag]..'end,',signatures[tag]..old[tag]..'end,'
 local a,b=text:find(from,1,true);assert(a and not text:find(from,b+1,true),'missing or duplicate readiness callback')
 local restored=text:sub(1,a-1)..to..text:sub(b+1);assert(hash(restored)==hashes[tag],'unrelated module bytes changed');return restored
end
return inverse,old,repaired
