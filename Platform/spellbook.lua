local _,addon=...
local platform=addon.Platform
local function failure(reason) return {complete=false,reason=reason,entries={}} end
local function number(value,minimum,maximum)
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge or value%1~=0 or value<minimum then
        return nil,value==nil and "spellbook-data-unavailable" or "invalid-api-result"
    end
    if maximum and value>maximum then return nil,"spellbook-limit" end
    return value
end
local function call(fn,...)
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"api-error" end
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    return value
end
local function readLine(index,modern)
    local record,why
    if modern then record,why=call(C_SpellBook.GetSpellBookSkillLineInfo,index)
    else
        if type(GetSpellTabInfo)~="function" then return nil,"missing-api" end
        local ok,name,icon,offset,count,guild,offSpecID=pcall(GetSpellTabInfo,index)
        if not ok then return nil,"api-error" end
        record={itemIndexOffset=offset,numSpellBookItems=count,offSpecID=offSpecID}
    end
    if why then return nil,why end
    if type(record)~="table" then return nil,"spellbook-data-unavailable" end
    local offset,errorCode=number(record.itemIndexOffset,0,4096);if not offset then return nil,errorCode end
    local count,reason=number(record.numSpellBookItems,0,4096);if not count then return nil,reason end
    local offSpecID=record.offSpecID
    if not platform:CanReadValue(offSpecID) then return nil,"restricted-value" end
    if offSpecID~=nil then
        local checked,problem=number(offSpecID,0);if not checked then return nil,problem end
        if offSpecID==0 then offSpecID=nil end
    end
    if offset+count>4096 then return nil,"spellbook-limit" end
    return {offset=offset,count=count,offSpecID=offSpecID}
end
local function readItem(slot,pet,line)
    local native=C_SpellBook and C_SpellBook.GetSpellBookItemInfo
    local modern=type(native)=="function"
    local banks=Enum and Enum.SpellBookSpellBank
    local types=Enum and Enum.SpellBookItemType
    if modern and (not platform:CanReadValue(banks) or not platform:CanReadValue(types)) then return nil,"restricted-value" end
    local bank,spellType
    if type(banks)=="table" then if pet then bank=banks.Pet else bank=banks.Player end end
    if type(types)=="table" then spellType=types.Spell end
    if modern and (not platform:CanReadValue(bank) or not platform:CanReadValue(spellType)) then return nil,"restricted-value" end
    if modern and (type(bank)~="number" or type(spellType)~="number") then
        if type(GetSpellBookItemInfo)=="function" then modern=false
        elseif type(bank)~="number" then return nil,"missing-spell-bank"
        else return nil,"missing-spell-type" end
    end
    local id,baseID,passive,offspec
    if modern then
        local record,why=call(native,slot,bank)
        if why then return nil,why end
        if type(record)~="table" then return nil,"spellbook-data-unavailable" end
        if not platform:CanReadValue(record.itemType) then return nil,"restricted-value" end
        if type(record.itemType)~="number" then return nil,"invalid-api-result" end
        if record.itemType~=spellType then return false end
        id,baseID,passive,offspec=record.spellID,record.actionID,record.isPassive,record.isOffSpec
        for _,value in pairs({passive=passive,offspec=offspec}) do
            if not platform:CanReadValue(value) then return nil,"restricted-value" end
            if type(value)~="boolean" then return nil,"invalid-api-result" end
        end
        if type(passive)~="boolean" or type(offspec)~="boolean" then return nil,"invalid-api-result" end
    else
        if type(GetSpellBookItemInfo)~="function" then return nil,"missing-api" end
        local kind,ok
        ok,kind,id=pcall(GetSpellBookItemInfo,slot,pet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell"))
        if not ok then return nil,"api-error" end
        if not platform:CanReadValue(kind) then return nil,"restricted-value" end
        if type(kind)~="string" then return nil,"spellbook-data-unavailable" end
        if kind~="SPELL" then return false end
        if type(IsPassiveSpell)=="function" then
            local why
            passive,why=call(IsPassiveSpell,slot,pet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell"))
            if why then return nil,why end
            if type(passive)~="boolean" then return nil,"invalid-api-result" end
        end
        baseID=id;offspec=line and line.offSpecID~=nil or false
    end
    local spellID,why=number(id,1);if not spellID then return nil,why end
    local base,reason=number(baseID,1);if not base then return nil,reason end
    return {spellID=spellID,baseSpellID=base,slot=slot,bank=pet and "pet" or "player",
        isPassive=passive,isOffSpec=offspec,offSpecID=line and line.offSpecID or nil}
end
local function scanPlayer()
    local modern=C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines)=="function"
    local count,why=call(modern and C_SpellBook.GetNumSpellBookSkillLines or GetNumSpellTabs)
    if why then return failure(why) end
    local lines,reason=number(count,0,128);if not lines then return failure(reason) end
    local result={complete=true,entries={},coverage="direct-spells"}
    local total,seen=0,{}
    for index=1,lines do
        local line,errorCode=readLine(index,modern);if not line then return failure(errorCode) end
        total=total+line.count;if total>4096 then return failure("spellbook-limit") end
        for slot=line.offset+1,line.offset+line.count do
            if seen[slot] then return failure("overlapping-spellbook-lines") end;seen[slot]=true
            local entry,problem=readItem(slot,false,line)
            if entry==nil then return failure(problem) end
            if entry then result.entries[#result.entries+1]=entry else result.hasOtherItems=true end
        end
    end
    return result
end
local function scanPet()
    local fn=C_SpellBook and C_SpellBook.HasPetSpells or HasPetSpells
    local count,why=call(fn)
    if why then return failure(why) end
    if count==nil then return {complete=true,entries={},coverage="direct-spells"} end
    local maximum,reason=number(count,0,4096);if not maximum then return failure(reason) end
    local result={complete=true,entries={},coverage="direct-spells"}
    for slot=1,maximum do
        local entry,problem=readItem(slot,true)
        if entry==nil then return failure(problem) end
        if entry then result.entries[#result.entries+1]=entry else result.hasOtherItems=true end
    end
    return result
end
function platform:GetSpellBookSnapshot()
    return {player=scanPlayer(),pet=scanPet()}
end
