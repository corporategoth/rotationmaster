local addon_name, addon = ...

local AceConsole = LibStub("AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local _G, tostring, tonumber, pairs, color = _G, tostring, tonumber, pairs, color
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

addon.getCached = function(cache, func, ...)
    local args = { ... }
    if cache[func] == nil then
        cache[func] = {}
    end

    local argsz = #args
    for idx,call in pairs(cache[func]) do
        if #call.args == argsz then
            local match = true
            for i=1,argsz do
                if args[i] ~= call.args[i] then
                    match = false
                    break
                end
            end
            if match then
                return unpack(call.result)
            end
        end
    end

    local result
    if (type(func) == "function") then
        result = { func(...) }
    elseif type(func) == "string" then
        result = { _G[func](...) }
    else
        return nil
    end

    table.insert(cache[func], {
        args = args,
        result = result
    })

    return unpack(result)
end

addon.isSpellOnSpec = function(spec, spellid)
    for i=1,GetNumSpellTabs() do
        local _, _, offset, numSpells, _, offspecId = GetSpellTabInfo(i)
        if i == 1 or (spec == addon.currentSpec and offspecId == 0) or spec == offspecId then
            for i=1,numSpells do
                local _, bookSpell = GetSpellBookItemInfo(i+offset, BOOKTYPE_SPELL)
                if spellid == bookSpell and not IsPassiveSpell(i+offset, BOOKTYPE_SPELL) then
                    return true
                end
            end
        end
    end
    return false
end

addon.updateIconOnDemands = function(frame, name)
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
