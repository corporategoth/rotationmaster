-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for glyphs on the progression clients: GetNumGlyphSockets, GetGlyphSocketInfo and the glyph item
-- class of GetItemInfoInstant.
-- Owns the `value or nil, reason` readers for a glyph item and for the socket snapshot, and the table of verified
-- GlyphUI layouts per build; an unverified build is refused rather than guessed. It must not decide which glyph a
-- rotation wants. The readers and helpers in the generated block at the end of the file are Built In helpers and must
-- keep their exact text. Loaded from RotationMaster.toc after Platform/items.lua.
local _, addon = ...
local platform = addon.Platform

-- Whether a value is a finite whole number at or above a minimum.
-- @param value any  The value to test.
-- @param minimum number  The smallest accepted value.
-- @return boolean  True when value qualifies.
local function integer(value, minimum)
    return type(value)=='number' and value==value and value>=minimum and value<math.huge and value%1==0
end

-- Reads a glyph item and checks it is a glyph of a class.
-- @param itemID number  The item id, an integer of at least 1.
-- @param classID number|nil  The class id the glyph must belong to; nil means the player's class.
-- @return table|nil  The item record from GetItemInfoInstant; nil when it cannot be read or is not a glyph.
-- @return string|nil  The reason code when the first return is nil ("invalid-glyph-item" when the item is not a glyph
--   of that class); nil otherwise.
function platform:GetGlyphItemInfo(itemID, classID)
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

-- Finds which GetGlyphSocketInfo return holds the glyph spell id on this exact client build.
-- @param info table  The client info table from GetClientInfo.
-- @return number|nil  The position of the glyph spell id among the GetGlyphSocketInfo returns; nil when this exact
--   client version is not a verified layout.
--
-- Verified published Blizzard GlyphUI layouts: Wrath uses return three; Cata/Mists insert glyphTooltipIndex before
-- glyphSpellID. Future editions require verification rather than interpreting a tooltip index as a spell.
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

-- Reads one glyph socket.
-- @param self table  The platform table, used for its CanReadValue method.
-- @param fn function  The GetGlyphSocketInfo function.
-- @param index number  The socket index.
-- @param position number  Which return of fn holds the glyph spell id.
-- @return table  { slot, active, spellID } for a readable socket, or { slot, reason } when it cannot be read; a socket
--   that cannot be read is reported with its reason instead of failing the whole snapshot.
local function socket(self, fn, index, position)
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

-- Whether this client build has a verified glyph layout.
-- @return boolean  True when the layout is verified.
--
-- A fact of the client, read by condition support without observing sockets.
function platform:IsGlyphLayoutSupported()
    return layout(self:GetClientInfo()) ~= nil
end

-- Reads every glyph socket on the client.
-- @return table|nil  { slots, complete } for every glyph socket, where complete is false if any socket could not be
--   read; nil when the layout is unverified or the socket count cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
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
