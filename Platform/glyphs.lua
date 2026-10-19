local _,addon=...
local platform=addon.Platform
local function integer(value,minimum)
    return type(value)=='number' and value==value and value>=minimum and value<math.huge and value%1==0
end
function platform:GetGlyphItemInfo(itemID,classID)
    if not self:CanReadValue(itemID) or not self:CanReadValue(classID) then return nil,'restricted-value' end
    if not integer(itemID,1) then return nil,'invalid-item' end
    if classID==nil then
        if type(UnitClass)~='function' then return nil,'missing-api' end
        local ok,tuple=pcall(function() return {UnitClass('player')} end)
        if not ok then return nil,'api-error' end
        classID=tuple[3]
        if not self:CanReadValue(classID) then return nil,'restricted-value' end
        if classID==nil then return nil,'class-data-unavailable' end
    end
    if not integer(classID,1) then return nil,'invalid-class' end
    local record,reason=self:GetItemInfoInstant(itemID)
    if not record then return nil,reason end
    if record.classID~=16 or record.subClassID~=classID then return nil,'invalid-glyph-item' end
    return record
end

-- Verified published Blizzard GlyphUI layouts: Wrath uses return three;
-- Cata/Mists insert glyphTooltipIndex before glyphSpellID. Future editions
-- require verification rather than interpreting a tooltip index as a spell.
local function layout(info)
    local editions={
        [11]={expansion=2,prefix='3.4.',last=3,base=30400,position=3},
        [14]={expansion=3,prefix='4.4.',last=2,base=40400,position=4},
        [19]={expansion=4,prefix='5.5.',last=4,base=50500,position=4},
    }
    local edition=editions[info.projectId]
    if not edition or info.family~='progression' or info.expansion~=edition.expansion then return nil end
    for patch=0,edition.last do
        if info.version==edition.prefix..patch and info.interface==edition.base+patch then return edition.position end
    end
end
local function socket(self,fn,index,position)
    local ok,tuple=pcall(function() return {fn(index)} end)
    if not ok then return {slot=index,reason='api-error'} end
    local enabled,kind,spell=tuple[1],tuple[2],tuple[position]
    if not self:CanReadValue(enabled) or not self:CanReadValue(kind) then return {slot=index,reason='restricted-value'} end
    if enabled==nil and kind==nil then return {slot=index,reason='glyph-socket-unavailable'} end
    if not integer(kind,1) or enabled~=nil and type(enabled)~='boolean' then return {slot=index,reason='invalid-api-result'} end
    if not enabled then return {slot=index,active=false} end
    if not self:CanReadValue(spell) then return {slot=index,reason='restricted-value'} end
    if spell==nil then return {slot=index,active=false} end
    if not integer(spell,1) then return {slot=index,reason='invalid-api-result'} end
    return {slot=index,active=true,spellID=spell}
end
function platform:GetGlyphSocketSnapshot()
    local position=layout(self:GetClientInfo())
    if not position then return nil,'unsupported-glyph-layout' end
    if type(GetNumGlyphSockets)~='function' then return nil,'missing-api' end
    local ok,count=pcall(GetNumGlyphSockets)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(count) then return nil,'restricted-value' end
    if count==nil then return nil,'glyph-data-unavailable' end
    if not integer(count,0) or count>64 then return nil,'invalid-api-result' end
    local fn=GetGlyphSocketInfo
    if count>0 and type(fn)~='function' then return nil,'missing-api' end
    local result={slots={},complete=true}
    for index=1,count do
        local record=socket(self,fn,index,position)
        result.slots[index]=record
        if record.active==nil then result.complete=false end
    end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetGlyphItemInfo" then return addon.Platform.GetGlyphItemInfo end
        if name=="Platform_GetGlyphSocketSnapshot" then return addon.Platform.GetGlyphSocketSnapshot end
        if name=="integer" then return integer end
        if name=="layout" then return layout end
        if name=="socket" then return socket end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/glyphs.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/glyphs.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
