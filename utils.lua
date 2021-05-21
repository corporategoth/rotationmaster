local addon_name, addon = ...

local AceConsole = LibStub("AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local libc = LibStub("LibCompress")

local _G, tostring, tonumber, pairs, color, unpack, type, string = _G, tostring, tonumber, pairs, color, unpack, type, string
local random, floor = math.random, math.floor

local operators = addon.operators

addon.PopupError = function(string, onaccept)
    StaticPopupDialogs["ROTATIONMASTER_ERROR"] = {
        text = string,
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

addon.compare = function(operator, left, right)
    if operator == "LESSTHAN" then
        return left < right
    elseif operator == "LESSTHANOREQUALS" then
        return left <= right
    elseif operator == "GREATERTHAN" then
        return left > right
    elseif operator == "GREATERTHANOREQUALS" then
        return left >= right
    elseif operator == "EQUALS" then
        return left == right
    elseif operator == "NOTEQUALS" then
        return left ~= right
    elseif operator == "DIVISIBLE" then
        return (left % right) == 0
    else
        addon:warn("Invalid Operator %s", operator)
    end
end

addon.nullable = function(value, default)
    if value == nil then
        if default ~= nil then
            return color.RED .. default .. color.RESET
        else
            return color.RED .. L["<value>"] .. color.RESET
        end
    end
    return value
end

addon.playerize = function(unit, player, nonplayer)
    if (unit == "player") then
        return player
    else
        return nonplayer
    end
end

addon.compareString = function(operator, left, right)
    return left .. " " .. addon.nullable(operators[operator], L["<operator>"]) .. " " .. right
end

addon.keys = function(array)
    local rv = {}
    for k,v in pairs(array) do
        table.insert(rv, k)
    end
    -- Sort the keys
    table.sort(rv, function (lhs, rhs) return array[lhs] < array[rhs] end)
    return rv
end

addon.spairs = function (t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

addon.tomap = function(array)
    local rv = {}
    for k,v in pairs(array) do
        rv[tostring(k)] = v
    end
    return rv
end

addon.isin = function(array, value)
    local idx = 1
    for k,v in pairs(array) do
        if (v == value) then
            return idx
        end
        idx = idx + 1
    end
    return 0
end

addon.round = function (num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return floor(num * mult + 0.5) / mult
end

addon.isint = function(num)
    if type(num) == "number" then
        return floor(num) == num
    elseif type(num) == "string" then
        local tmp = tonumber(num)
        if tmp ~= nil then
            return tostring(floor(tmp)) == num
        end
    end
    return false
end

addon.multiinsert = function(t, values)
    for i,v in ipairs(values) do
	    table.insert(t, i, v)
    end
end

addon.cleanArray = function(array, except, invert)
    if array == nil then
        return
    end
    if invert == nil then
        invert = false
    end

    for k,v in pairs(array) do
        local skip = invert
        if except ~= nil then
            for k2,v2 in pairs(except) do
                if (k == v2) then
                    skip = not invert
                    break
                end
            end
        end
        if not skip then
            array[k] = nil
        end
    end
end

addon.deepcopy = function(array, except, invert)
    if array == nil then
        return nil
    end
    if invert == nil then
        invert = false
    end

    local rv = {}
    for k,v in pairs(array) do
        local skip = invert
        if except ~= nil then
            for k2,v2 in pairs(except) do
                if (k == v2) then
                    skip = not invert
                    break
                end
            end
        end
        if not skip then
            rv[k] = v
        end
    end
    return rv
end

local cacheHits = 0
local cacheMisses = 0

local function getCachedInternal(cache, recordnil, func, ...)
    if func == nil then
        return
    end
    if cache == nil then
        return func(...)
    end

    local args = { ... }
    if cache[func] == nil then
        cache[func] = {}
    end

    local hash = libc:fcs16init()
    for i=1,#args do
        hash = libc:fcs16update(hash, tostring(args[i]))
    end
    hash = libc:fcs16final(hash)
    if cache[func][hash] ~= nil then
        cacheHits = cacheHits + 1
        return unpack(cache[func][hash])
    end

    cacheMisses = cacheMisses + 1
    local result
    if (type(func) == "function") then
        result = { func(...) }
    elseif type(func) == "string" then
        result = { _G[func](...) }
    else
        return nil
    end

    if #result > 0 or recordnil then
        cache[func][hash] = result
    end
    return unpack(result)
end

addon.getCached = function(cache, func, ...)
    return getCachedInternal(cache, true, func, ...)
end

addon.getRetryCached = function(cache, func, ...)
    return getCachedInternal(cache, false, func, ...)
end

function addon:ReportCacheStats()
    addon:debug(L["Cache hit rate at %.02f%%"], (cacheHits / (cacheHits + cacheMisses)) * 100)
    cacheHits = 0
    cacheMisses = 0
end

addon.isSpellOnSpec = function(spec, spellid, ispet)
    if not spellid then
        return false
    end
    if ispet or spec == addon.currentSpec then
        return FindSpellBookSlotBySpellID(spellid, ispet) ~= nil
    elseif addon.specSpells[spec] ~= nil then
        for name,id in pairs(addon.specSpells[spec]) do
            if spellid == id then
                return true
            end
        end
    end
    return false
end

function addon:verbose(message, ...)
    if self.db.profile.debug and self.db.profile.verbose then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.DEBUG .. message .. color.RESET, ...)
    end
end

function addon:debug(message, ...)
    if self.db.profile.debug then
        AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.DEBUG .. message .. color.RESET, ...)
    end
end

function addon:info(message, ...)
    AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.INFO .. message .. color.RESET, ...)
end

function addon:warn(message, ...)
    AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.WARN .. message .. color.RESET, ...)
end

function addon:announce(message, ...)
    AceConsole:Printf(color.WHITE .. "[" .. color.CYAN .. addon.pretty_name .. color.WHITE .. "] " .. color.ANNOUNCE .. message .. color.RESET, ...)
end

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

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
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function base64dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
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

function addon.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function addon.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- This will look at the damage done over damage_history, and gives progressively more weight
-- to more recent damage (so that theoretically if damage has decreased/increased it will adjust.)
function addon.calculate_trend_old(health)
    if not health then
        return 0
    end

    local damage_history = addon.db.profile.damage_history
    local now = GetTime()
    local total, count, seconds = 0, 0, 0

    local last_health, last_offs, last_max
    local offs_total = 0
    for k,v in ipairs(health) do
        if v.value >= v.max or v.value == 0 then
            break
        end

        if last_max ~= v.max then
            last_health = nil
            last_max = v.max
        end

        local offs = addon.round(now - v.time)
        if last_health ~= nil then
            offs_total = offs_total + (last_health - v.value)

            if last_offs ~= offs then
                local scale = damage_history - offs
                count = count + scale
                total = total + (offs_total * scale)
                seconds = seconds + 1
                offs_total = 0
            end
        end
        last_health = v.value
        last_offs = offs
    end

    if seconds then
        return total / count, seconds
    end
    return 0
end

function addon.calculate_trend(history, window, noheals, nodmg)
    if not history then
        return 0
    end

    if not window then
        window = addon.db.profile.damage_history
    end

    local now = GetTime()
    local damage_total, damage_count, damage_seconds = 0, 0, 0
    local heal_total, heal_count, heal_seconds = 0, 0, 0

    local maxoffs, data = 0, {}
    if not nodmg then
        for k,v in ipairs(history.damage) do
            local diff = now - v.time
            local scale = window - diff
            maxoffs = addon.round(diff)
            if maxoffs > window then
                break
            end

            if v.value then
                data[maxoffs] = (data[maxoffs] or 0) + (v.value * scale)
            end
        end
        damage_seconds = maxoffs
        for i=0,maxoffs do
            damage_total = damage_total + (data[i] or 0)
            damage_count = damage_count + (window - i)
        end
    end

    if not noheals then
        maxoffs, data = 0, {}
        for k,v in ipairs(history.heals) do
            local diff = now - v.time
            local scale = window - diff
            maxoffs = addon.round(diff)
            if maxoffs > window then
                break
            end

            if v.value then
                data[maxoffs] = (data[maxoffs] or 0) + (v.value * scale)
            end
        end
        heal_seconds = maxoffs
        for i=0,maxoffs do
            heal_total = heal_total + (data[i] or 0)
            heal_count = heal_count + (window - i)
        end
    end

    return (((damage_count > 0) and (-damage_total / damage_count) or 0) +
           ((heal_count > 0) and (heal_total / heal_count) or 0)),
           (damage_seconds > heal_seconds and damage_seconds or heal_seconds)
end

function addon.AddTooltip(frame, text)
    frame:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(frame.frame, "ANCHOR_BOTTOMRIGHT", 3)
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
    end)
    frame:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)
end

function addon:configure_frame(obj)
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

function addon:UpdateItem_ID_ID(item, text, icon, attempt)
    if not item then
        if text then
            text:SetText(nil)
        end
        if icon then
            icon:SetText(nil)
        end
        return
    end

    if not attempt then
        attempt = 1
        if text then
            text:SetText(item)
        end
        if icon then
            icon:SetText(nil)
        end
    end

    local itemid = self.getRetryCached(addon.longtermCache, GetItemInfoInstant, item)
    if itemid then
        if text then
            text:SetText(itemid)
        end
        if icon then
            icon:SetText(itemid)
        end
    elseif attempt < 4 then
        self:ScheduleTimer("UpdateItem_ID_ID", 0.5, item, text, icon, attempt + 1)
    end
end

function addon:UpdateItem_ID_Image(item, text, icon, attempt)
    if not item then
        if text then
            text:SetText(nil)
        end
        if icon then
            icon:SetImage(nil)
        end
        return
    end

    if not attempt then
        attempt = 1
        if text then
            text:SetText(item)
        end
        if icon then
            icon:SetImage(nil)
        end
    end

    local itemid, _, _, _, texture = self.getRetryCached(addon.longtermCache, GetItemInfoInstant, item)
    if itemid then
        if text then
            text:SetText(itemid)
        end
        if icon then
            icon:SetImage(texture)
        end
    elseif attempt < 4 then
        self:ScheduleTimer("UpdateItem_ID_Image", 0.5, item, text, icon, attempt + 1)
    end
end

function addon:UpdateItem_Name_ID(item, text, icon, attempt)
    if not item then
        if text then
            text:SetText(nil)
        end
        if icon then
            icon:SetText(nil)
        end
        return
    end

    if not attempt then
        attempt = 1
        if text then
            text:SetText(item)
        end
        if icon then
            icon:SetText(nil)
        end
    end

    local itemid = self.getRetryCached(addon.longtermCache, GetItemInfoInstant, item)
    local name
    if itemid then
        name = self.getRetryCached(addon.longtermCache, GetItemInfo, itemid)
    end
    if itemid and name then
        if text then
            text:SetText(name)
        end
        if icon then
            icon:SetText(itemid)
        end
    elseif attempt < 4 then
        self:ScheduleTimer("UpdateItem_Name_ID", 0.5, item, text, icon, attempt + 1)
    end
end

function addon:UpdateItem_Name_Image(item, text, icon, attempt)
    if not item then
        if text then
            text:SetText(nil)
        end
        if icon then
            icon:SetImage(nil)
        end
        return
    end

    if not attempt then
        attempt = 1
        if text then
            text:SetText(item)
        end
        if icon then
            icon:SetImage(nil)
        end
    end

    local itemid = self.getRetryCached(addon.longtermCache, GetItemInfoInstant, item)
    local name, texture, _
    if itemid then
        name = self.getRetryCached(addon.longtermCache, GetItemInfo, itemid)
        texture = select(10, self.getRetryCached(addon.longtermCache, GetItemInfo, itemid))
    end
    if name then
        if text then
            text:SetText(name)
        end
        if icon then
            icon:SetImage(texture)
        end
    elseif attempt < 4 then
        self:ScheduleTimer("UpdateItem_Name_Image", 0.5, item, text, icon, attempt + 1)
    end
end
