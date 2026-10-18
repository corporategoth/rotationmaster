local _,addon=...

-- This index belongs to RM. Metadata is useful for reference/search even when
-- a spell is not learned; only a fresh spellbook snapshot populates specSpells.
local catalog={}
addon.SpellCatalog=catalog
local entries,byName={},{}

local function rankNumber(entry)
    return tonumber((entry.rank or ""):match("%d+")) or 0
end
local function preferred(left,right)
    local a,b=rankNumber(entries[left]),rankNumber(entries[right])
    if a~=b then return a>b end
    return left>right
end
function catalog:UpdateSpell(id)
    if type(id)~="number" or id<1 or id==math.huge or id%1~=0 then return nil end
    local info,reason=addon.Platform:GetSpellInfo(id)
    if not info then return nil,reason end
    local old=entries[id]
    if old and old.name~=info.name then
        byName[string.lower(old.name)][id]=nil
    end
    local entry={name=info.name,rank=info.subtext,icon=info.iconID,link=addon.Platform:GetSpellLink(id)}
    entries[id]=entry
    local key=string.lower(entry.name)
    byName[key]=byName[key] or {};byName[key][id]=true
    return true
end
function catalog:GetAllSpellIds(spell)
    local name
    if type(spell)=="number" then
        if not entries[spell] then self:UpdateSpell(spell) end
        name=entries[spell] and entries[spell].name
    elseif type(spell)=="string" then name=spell end
    if not name then return nil end
    local group=byName[string.lower(name)]
    if not group then return nil end
    local result={}
    for id in pairs(group) do result[#result+1]=id end
    table.sort(result,preferred)
    return result
end
function catalog:GetSpellId(spell,rank)
    local ids=self:GetAllSpellIds(spell)
    if not ids and type(spell)=="string" then
        local info,why=addon.Platform:GetSpellInfo(spell)
        if info and type(info.spellID)=="number" then self:UpdateSpell(info.spellID);ids=self:GetAllSpellIds(info.spellID)
        elseif why=="restricted-value" or why=="api-error" then return nil,why end
    end
    -- Preserve the native name resolver's canonical/override choice rather
    -- than assuming the highest indexed metadata rank is currently learned.
    if ids and rank==nil then
        local info,why=addon.Platform:GetSpellInfo(entries[ids[1]].name)
        if info and type(info.spellID)=="number" then
            local indexed,problem=self:UpdateSpell(info.spellID)
            if indexed then return info.spellID end
            return nil,problem or "spell-data-unavailable"
        elseif why=="restricted-value" or why=="api-error" then return nil,why end
    end
    if ids then
        for _,id in ipairs(ids) do
            if rank==nil or entries[id].rank==rank then return id end
        end
    end
end
function catalog:SpellName(id,norank)
    if not entries[id] then self:UpdateSpell(id) end
    local entry=entries[id]
    if entry then
        if not norank and entry.rank and entry.rank~="" then
            return entry.name.."|cFF888888 ("..entry.rank..")|r"
        end
        return entry.name
    end
end
function catalog:SpellLink(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and entries[id].link or addon.Platform:GetSpellLink(id)
end
function catalog:SpellRank(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and entries[id].rank
end
function catalog:SpellRankNum(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and rankNumber(entries[id]) or 0
end

function addon:RefreshSpellCatalog()
    local snapshot=self.Platform:GetSpellBookSnapshot()
    local petKey=BOOKTYPE_PET or "pet"
    local spells,reverse={[petKey]={}},{[petKey]={}}
    if self.currentSpec~=nil then spells[self.currentSpec]={};reverse[self.currentSpec]={} end
    for _,bank in ipairs({"player","pet"}) do
        local state=snapshot[bank]
        if state.complete then
            for _,entry in ipairs(state.entries) do
                catalog:UpdateSpell(entry.spellID)
                local spec
                if bank=="pet" then spec=petKey
                elseif entry.offSpecID then spec=entry.offSpecID
                elseif not entry.isOffSpec then spec=self.currentSpec end
                -- Unknown passivity/offspec identity is not evidence that an
                -- entry can be used as an action for the selected spec.
                if spec~=nil and entry.isPassive==false then
                    spells[spec]=spells[spec] or {};reverse[spec]=reverse[spec] or {}
                    spells[spec][entry.spellID]=true
                    local name=catalog:SpellName(entry.spellID,true)
                    if name then
                        local previous=reverse[spec][name]
                        if not previous or preferred(entry.spellID,previous) then reverse[spec][name]=entry.spellID end
                    end
                end
            end
        end
    end
    -- Replace rather than merge: old pets, lost spells and former offspecs
    -- must not survive a new snapshot, including a failed bank observation.
    self.specSpells,self.specSpellsReverse=spells,reverse
    self.spellBookStatus={player={complete=snapshot.player.complete,reason=snapshot.player.reason,
        coverage=snapshot.player.coverage,hasOtherItems=snapshot.player.hasOtherItems},
        pet={complete=snapshot.pet.complete,reason=snapshot.pet.reason,
        coverage=snapshot.pet.coverage,hasOtherItems=snapshot.pet.hasOtherItems}}
    return self.spellBookStatus
end

-- Detached metadata snapshots support owned search without exposing the index.
function catalog:GetIndexedSpells()
    local result={}
    for id,entry in pairs(entries) do
        result[#result+1]={id=id,name=entry.name,rank=entry.rank,icon=entry.icon,link=entry.link}
    end
    return result
end
