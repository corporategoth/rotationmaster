-- Only the exact nameplate span changes; adjacent BAG_UPDATE is preserved.
local old=[====[addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        self.unitsInRange[guid].unit = unit
    else
        self.unitsInRange[guid] = CreateUnitInfo({}, unit)
    end
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local guid = UnitGUID(unit)
    if self.unitsInRange[guid] then
        local handled = false
        for u, _ in pairs(addon.units) do
            if UnitIsUnit(unit, u) then
                self.unitsInRange[guid].unit = u
                handled = true
                break
            end
        end
        if not handled then
            self.unitsInRange[guid] = nil
        end
    end
end)

]====]
local new=[====[-- Nameplate removal can arrive after its token stops resolving. Retire by the
-- stored token; preserve only a positively identified canonical replacement.
local nameplateEvent
local function nameplateCurrent(self,snapshot,ticket)
    return self.unitsInRange==snapshot and nameplateEvent==ticket
end
local function nameplateReadable(self,snapshot,ticket,value)
    local readable=self.Platform:CanReadValue(value)
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    return not not readable
end
local function nameplateGUID(self,snapshot,ticket,unit)
    local ok,guid=pcall(UnitGUID,unit)
    if not nameplateCurrent(self,snapshot,ticket) or not ok then return nil end
    if not nameplateReadable(self,snapshot,ticket,guid) then return nil end
    if canaccessvalue and type(canaccessvalue)~="function" then return nil end
    if canaccessvalue and not canaccessvalue(guid) then return nil end
    if not nameplateCurrent(self,snapshot,ticket) then return nil end
    if type(guid)=="string" and guid~="" then return guid end
end
local function nameplateChanges(self,snapshot,ticket,unit,keep)
    -- Provider calls can reenter these handlers and mutate public maps. Finish
    -- copying their keys before calling any provider or readability function.
    local entries,changes={},{}
    for guid,entry in pairs(snapshot) do entries[#entries+1]={guid=guid,entry=entry} end
    for _,change in ipairs(entries) do
        local entry=change.entry
        if type(entry)=="table" and getmetatable(entry)==nil then
            local stored=rawget(entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return nil end
            if readable and type(stored)=="string" and stored==unit then
                readable=nameplateReadable(self,snapshot,ticket,change.guid)
                if readable==nil then return nil end
                if readable and type(change.guid)=="string" and change.guid~=keep then changes[#changes+1]=change end
            end
        end
    end
    if #changes==0 then return changes end
    local units,aliases={},{}
    for alias in pairs(addon.units) do units[#units+1]=alias end
    for _,alias in ipairs(units) do
        local readable=nameplateReadable(self,snapshot,ticket,alias)
        if readable==nil then return nil end
        if readable and type(alias)=="string" and alias~=unit then
            local guid=nameplateGUID(self,snapshot,ticket,alias)
            if not nameplateCurrent(self,snapshot,ticket) then return nil end
            if guid and not aliases[guid] then aliases[guid]=alias end
        end
    end
    for _,change in ipairs(changes) do change.alias=aliases[change.guid] end
    return changes
end
local function nameplateStoredMatches(entry,stored)
    return rawget(entry,"unit")==stored
end
local function applyNameplateChanges(self,snapshot,ticket,unit,changes)
    for _,change in ipairs(changes) do
        if rawget(snapshot,change.guid)==change.entry then
            local stored=rawget(change.entry,"unit")
            local readable=nameplateReadable(self,snapshot,ticket,stored)
            if readable==nil then return false end
            if readable and type(stored)=="string" and stored==unit then
                -- A readability callback may directly replace the field. Never
                -- compare a newly restricted value outside a protected read.
                local ok,unchanged=pcall(nameplateStoredMatches,change.entry,stored)
                if ok and unchanged and rawget(snapshot,change.guid)==change.entry then
                    if change.alias then rawset(change.entry,"unit",change.alias)
                    else rawset(snapshot,change.guid,nil) end
                end
            end
        end
    end
    return true
end

addon.NAME_PLATE_UNIT_ADDED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local guid=nameplateGUID(self,snapshot,ticket,unit);if not guid then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit,guid);if not changes then return end
    local previous=rawget(snapshot,guid)
    if previous~=nil and (type(previous)~="table" or getmetatable(previous)~=nil) then return end
    local previousUnit=previous and rawget(previous,"unit")
    if previous and (not nameplateReadable(self,snapshot,ticket,previousUnit) or type(previousUnit)~="string") then return end
    local entry=previous or CreateUnitInfo({},unit)
    if not nameplateCurrent(self,snapshot,ticket) then return end
    if not applyNameplateChanges(self,snapshot,ticket,unit,changes) then return end
    local current=rawget(snapshot,guid)
    if type(current)~=type(previous) or not rawequal(current,previous) then return end
    if previous then
        local ok,unchanged=pcall(nameplateStoredMatches,previous,previousUnit)
        if not ok or not unchanged then return end
    end
    rawset(entry,"unit",unit);rawset(snapshot,guid,entry)
end)

addon.NAME_PLATE_UNIT_REMOVED = wrapCombatEvent(function(self, _, unit)
    local ticket={};nameplateEvent=ticket
    local snapshot=self.unitsInRange
    if type(snapshot)~="table" or getmetatable(snapshot)~=nil then return end
    if not nameplateReadable(self,snapshot,ticket,unit) or type(unit)~="string" or unit=="" then return end
    local changes=nameplateChanges(self,snapshot,ticket,unit);if not changes then return end
    if not nameplateCurrent(self,snapshot,ticket) then return end
    applyNameplateChanges(self,snapshot,ticket,unit,changes)
end)

]====]
local function hash(s)local h=0;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.format('%08x',h)end
return function(text,path)
 assert(path=='main.lua','unknown nameplate inverse path')
 if #text==77591 and hash(text)=='7780dabb' then return text end
 assert(#text==82628 and hash(text)=='bf460225','unrelated nameplate module change')
 local first,last=assert(text:find(new,1,true));assert(not text:find(new,last+1,true),'duplicate nameplate span')
 text=text:sub(1,first-1)..old..text:sub(last+1)
 assert(#text==77591 and hash(text)=='7780dabb','nameplate predecessor mismatch')
 return text
end
