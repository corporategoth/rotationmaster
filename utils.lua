local addon_name, addon = ...

local AceConsole = LibStub("AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local _G, tostring, tonumber, pairs, color, unpack, type, string = _G, tostring, tonumber, pairs, color, unpack, type, string
local random, floor = math.random, math.floor


addon.PopupError = function(s, onaccept)
    StaticPopupDialogs["ROTATIONMASTER_ERROR"] = {
        text = s,
        button1 = ACCEPT,
        OnAccept = onaccept,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    StaticPopup_Show("ROTATIONMASTER_ERROR")
end

addon.HideOnEscape = function(frame)
    if addon.MakeWindowOpaque then addon:MakeWindowOpaque(frame) end
    if addon.RegisterWindowForEscape and addon:RegisterWindowForEscape(frame) then return end
    frame.frame:EnableKeyboard(true)
    frame.frame:SetPropagateKeyboardInput(true)
    frame.frame:SetScript("OnKeyDown", function (self, key)
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            frame:Hide()
        end
    end)
end

addon.uuid = function()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Compatibility API for saved custom source; Functions.values owns the body.
addon.compare = addon.Functions.values.compare

-- Compatibility APIs for saved source; presentation owns these exact bodies.
addon.nullable = addon.Functions.presentation.nullable
addon.nullable_value = addon.Functions.presentation.nullable_value
addon.playerize = addon.Functions.presentation.playerize
addon.compareString = addon.Functions.presentation.compareString

addon.keys = addon.Functions.collections.keys

addon.spairs = addon.Functions.collections.spairs

addon.tomap = addon.Functions.collections.tomap

addon.index = addon.Functions.collections.index

-- Compatibility API for saved custom source; Functions.values owns the body.
addon.isin = addon.Functions.values.isin

addon.tablelength = addon.Functions.collections.tablelength

addon.round = addon.Functions.values.round

addon.isint = addon.Functions.values.isint

addon.starts_with = addon.Functions.text.starts_with

addon.ends_with = addon.Functions.text.ends_with

addon.multiinsert = addon.Functions.collections.multiinsert

addon.cleanArray = addon.Functions.collections.cleanArray

addon.deepcopy = addon.Functions.collections.deepcopy

addon.compareArray = addon.Functions.collections.compareArray

-- Compatibility APIs for saved custom source; cache owns their shared state.
addon.getCached = addon.Functions.cache.getCached
addon.getRetryCached = addon.Functions.cache.getRetryCached
addon.ReportCacheStats = addon.Functions.cache.ReportCacheStats

-- pass in the spec BOOKTYPE_PET ("pet") to get pet spells
addon.isSpellOnSpec = function(spec, spellid)
    if spec ~= nil and spellid ~= nil and addon.specSpells[spec] ~= nil then
        return addon.specSpells[spec][spellid] ~= nil
    end
    return false
end

addon.isActivePetSpell = function(spellid)
    return FindSpellBookSlotBySpellID(spellid, true) ~= nil
end

-- pass in the spec BOOKTYPE_PET ("pet") to get pet spells
addon.getSpecSpellID = function(spec, name)
    if spec ~= nil and name ~= nil and addon.specSpellsReverse[spec] ~= nil then
        local spellid = addon.specSpellsReverse[spec][name]
        if addon.isSpellOnSpec(spec, spellid) then
            return spellid
        end
    end
    return nil
end

local function getLogLevel(self)
    -- AceDB removes default-valued fields during shutdown; events may still
    -- arrive afterwards. Use the normal default without writing it back.
    local profile = self.db and self.db.profile
    return (profile and tonumber(profile.loglevel)) or 2
end

function addon:verbose(message, ...)
    if getLogLevel(self) >= 4 then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.DEBUG .. message .. color.RESET, ...)
    end
end

function addon:debug(message, ...)
    if getLogLevel(self) >= 3 then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.DEBUG .. message .. color.RESET, ...)
    end
end

function addon:info(message, ...)
    if getLogLevel(self) >= 2 then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.INFO .. message .. color.RESET, ...)
    end
end

function addon:warn(message, ...)
    if getLogLevel(self) >= 1 then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.WARN .. message .. color.RESET, ...)
    end
end

function addon:print(message, ...)
    AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.INFO .. message .. color.RESET, ...)
end

function addon:announce(message, ...)
    AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.ANNOUNCE .. message .. color.RESET, ...)
end

-- character table string
local b64_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function base64enc(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b64_chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function base64dec(data)
    data = string.gsub(data, '[^'..b64_chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b64_chars:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function width_split(s, sz)
    if s == nil then
        return nil
    end

    local rv = ""
    local offs = 1;
    while offs < s:len() do
        if (offs > 1) then
            rv = rv .. "\n"
        end
        rv = rv .. s:sub(offs, offs+sz)
        offs = offs + sz + 1
    end
    return rv
end

addon.split=addon.Functions.text.split
addon.wrap=addon.Functions.text.wrap
addon.trim=addon.Functions.text.trim

-- This will look at the damage done over damage_history, and gives progressively more weight
-- to more recent damage (so that theoretically if damage has decreased/increased it will adjust.)
addon.calculate_trend_old=addon.Functions.trends.calculateOld

addon.calculate_trend=addon.Functions.trends.calculate

function addon.AddTooltip(frame, text)
    frame:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(frame.frame, "ANCHOR_BOTTOMRIGHT", 3)
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
    end)
    frame:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(frame.frame) then
            GameTooltip:Hide()
        end
    end)
end

function addon:configure_frame(obj)
    if self.InstallSpellHyperlinks then
        if obj.label then self:InstallSpellHyperlinks(obj.frame) end
        if obj.statustext and obj.statustext.GetParent then self:InstallSpellHyperlinks(obj.statustext:GetParent()) end
    end
    if obj.children ~= nil then
        for _, child in pairs(obj.children) do
            addon:configure_frame(child)
        end
    end

    if (obj.configure ~= nil) then
        obj.configure()
        -- obj.configure = nil
    end
end

function addon:GetSpecialization()
    local selection,reason=self.Platform:GetRotationSpecialization()
    if not selection then return nil,reason end
    return selection.index
end

-- A delayed metadata retry belongs to a particular widget selection. Reusing
-- either widget or clearing it invalidates all older scheduled retries.
local itemUpdates=setmetatable({},{__mode='k'})
local itemReleases=setmetatable({},{__mode='k'})
local function watchItemRelease(widget)
    if not widget or itemReleases[widget]==widget.OnRelease and widget.OnRelease~=nil then return end
    local original=widget.OnRelease
    local release
    release=function(self,...)
        itemUpdates[self]=nil;itemReleases[self]=nil
        if self.OnRelease==release then self.OnRelease=original end
        if original then return original(self,...) end
    end
    itemReleases[widget]=release;widget.OnRelease=release
end
local function itemText(widget)
    if widget and type(widget.GetText)=='function' then return widget:GetText() end
end
local function itemTooltip(icon,id)
    if icon and GameTooltip and GameTooltip:IsOwned(icon.frame) and GameTooltip:IsVisible() then
        if id then GameTooltip:SetHyperlink('item:'..id) else GameTooltip:Hide() end
    end
end
local function sameItemText(widget,ticket)
    if widget.GetReferenceID then
        local current=widget:GetReferenceID()
        if current~=nil or ticket.referenceID~=nil then return current==ticket.referenceID end
    end
    return itemText(widget)==ticket.text
end
local function updateItem(self,method,named,image,item,text,icon,attempt,ticket)
    if not attempt then
        attempt=1;ticket={}
        if text then watchItemRelease(text);itemUpdates[text]=ticket end
        if icon then watchItemRelease(icon);itemUpdates[icon]=ticket end
    elseif not ticket or text and (itemUpdates[text]~=ticket or not sameItemText(text,ticket))
        or icon and (itemUpdates[icon]~=ticket or icon.rmActionIconRevision~=ticket.iconRevision) then return end
    if not self.Platform:CanReadValue(item) then item=nil end
    local id=item and self.Platform:GetItemID(item)
    local info=id and (named or image) and self.Platform:GetItemDisplayInfo(id)
    local complete=id and (not named or info) and (not image or info and info.iconID~=nil)
    if text then
        if text.rmSpellSearchActive and id then text:SetText(id)
        else text:SetText(item and (named and (info and info.name or L['Item data loading']) or id) or nil) end
    end
    if icon then
        if image then icon:SetImage(complete and info.iconID or nil)
        else icon:SetText(complete and id or nil) end
    end
    itemTooltip(icon,complete and id)
    ticket.text=itemText(text);ticket.referenceID=text and text.GetReferenceID and text:GetReferenceID();ticket.iconRevision=icon and icon.rmActionIconRevision
    if item and not complete and attempt<4 then self:ScheduleTimer(method,0.5,item,text,icon,attempt+1,ticket) end
end
function addon:UpdateItem_ID_ID(item,text,icon,attempt,ticket)
    updateItem(self,'UpdateItem_ID_ID',false,false,item,text,icon,attempt,ticket)
end
function addon:UpdateItem_ID_Image(item,text,icon,attempt,ticket)
    updateItem(self,'UpdateItem_ID_Image',false,true,item,text,icon,attempt,ticket)
end
function addon:UpdateItem_Name_ID(item,text,icon,attempt,ticket)
    updateItem(self,'UpdateItem_Name_ID',true,false,item,text,icon,attempt,ticket)
end
function addon:UpdateItem_Name_Image(item,text,icon,attempt,ticket)
    updateItem(self,'UpdateItem_Name_Image',true,true,item,text,icon,attempt,ticket)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="_G" then return _G end
        if name=="cacheHits" then return addon.builtinSourceModules["Functions/cache.lua"]("cacheHits") end
        if name=="cacheMisses" then return addon.builtinSourceModules["Functions/cache.lua"]("cacheMisses") end
        if name=="cachedResult" then return addon.builtinSourceModules["Functions/cache.lua"]("cachedResult") end
        if name=="color" then return color end
        if name=="compare" then return addon.Functions.values.compare end
        if name=="compareString" then return addon.Functions.presentation.compareString end
        if name=="getCached" then return addon.Functions.cache.getCached end
        if name=="getCachedInternal" then return addon.builtinSourceModules["Functions/cache.lua"]("getCachedInternal") end
        if name=="getRetryCached" then return addon.Functions.cache.getRetryCached end
        if name=="isin" then return addon.Functions.values.isin end
        if name=="nilArgument" then return addon.builtinSourceModules["Functions/cache.lua"]("nilArgument") end
        if name=="nullable" then return addon.Functions.presentation.nullable end
        if name=="nullable_value" then return addon.Functions.presentation.nullable_value end
        if name=="packResults" then return addon.builtinSourceModules["Functions/cache.lua"]("packResults") end
        if name=="playerize" then return addon.Functions.presentation.playerize end
        if name=="split" then return addon.Functions.text.split end
        if name=="string" then return string end
        if name=="trim" then return addon.Functions.text.trim end
        if name=="wrap" then return addon.Functions.text.wrap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("utils.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["utils.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
