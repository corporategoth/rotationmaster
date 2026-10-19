local addon_name, addon = ...

local AceConsole = LibStub("AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local _G, tostring, tonumber, pairs, color, unpack, type, string = _G, tostring, tonumber, pairs, color, unpack, type, string
local random, floor = math.random, math.floor

local operators = addon.operators

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

addon.nullable_value = function(value, array, default)
    if value == nil or array == nil or type(array) ~= "table" then
        if default ~= nil then
            return color.RED .. default .. color.RESET
        else
            return color.RED .. L["<value>"] .. color.RESET
        end
    end
    return addon.nullable(array[value], default)
end

addon.playerize = function(unit, player, nonplayer)
    if (unit == "player") then
        return player
    else
        return nonplayer
    end
end

addon.compareString = function(operator, left, right, primary)
    local positive=addon.nullable(operators[operator], L["<operator>"])
    local negative=(addon.negatedOperators or {})[operator]
    local predicate=negative and ('{{'..(primary and '!' or '')..positive..'|'..negative..'}}') or positive
    return left .. " " .. predicate .. " " .. right
end

addon.keys = function(array)
    local rv = {}
    for k,_ in pairs(array) do
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

addon.index = function(array, value)
    if not array then return nil end

    for idx,v in pairs(array) do
        if (v == value) then
            return idx
        end
    end
end

addon.isin = function(array, value)
    return array[value] ~= nil
end

addon.tablelength = function(T)
    if T == nil then return 0 end
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
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

addon.starts_with = function(str, start)
    return str:sub(1, #start) == start
end

addon.ends_with = function(str, ending)
    return ending == "" or str:sub(-#ending) == ending
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

    for k,_ in pairs(array) do
        local skip = invert
        if except ~= nil then
            for _,v2 in pairs(except) do
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
            for _,v2 in pairs(except) do
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

addon.compareArray = function(lhs, rhs)
    for k,v in pairs(lhs) do
        if rhs[k] ~= v then
            return false
        end
    end
    for k,v in pairs(rhs) do
        if lhs[k] ~= v then
            return false
        end
    end
    return true
end

local cacheHits = 0
local cacheMisses = 0
local nilArgument, cachedResult = {}, {}

local function packResults(...)
    return { n = select('#', ...), ... }
end

local function getCachedInternal(cache, recordnil, func, ...)
    if type(func) == 'string' then func = _G[func] end
    if type(func) ~= 'function' then return end
    if cache == nil then return func(...) end

    -- Exact keys preserve argument types, identity and arity. Hashing concatenated
    -- strings allowed unrelated observations to collide, even for numeric IDs.
    local args, count = { ... }, select('#', ...)
    for i = 1, count do
        local value = args[i]
        if addon.Platform and addon.Platform.CanReadValue and not addon.Platform:CanReadValue(value) then
            return func(...)
        end
        if type(value) == 'number' and value ~= value then return func(...) end
        if value == nil then args[i] = nilArgument end
    end
    local node = cache[func]
    for i = 1, count do
        if not node then break end
        node = node[args[i]]
    end
    local result = node and node[cachedResult]
    if result then
        cacheHits = cacheHits + 1
        return unpack(result, 1, result.n)
    end

    cacheMisses = cacheMisses + 1
    result = packResults(func(...))
    local store = recordnil
    if not store then
        -- Inspect the packed keys, not potentially restricted return values.
        for key in pairs(result) do
            if type(key) == 'number' then store = true; break end
        end
    end
    if store then
        -- Retry misses and thrown calls must not accumulate empty paths.
        if not cache[func] then cache[func] = {} end
        node = cache[func]
        for i = 1, count do
            local key = args[i]
            if not node[key] then node[key] = {} end
            node = node[key]
        end
        node[cachedResult] = result
    end
    return unpack(result, 1, result.n)
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

function addon.wrap(str, limit)
    limit = limit or 72
    local here = 1

    -- the "".. is there because :gsub returns multiple values
    return ""..str:gsub("(%s+)()(%S+)()",
            function(_, st, word, fi)
                if fi-here > limit then
                    here = st
                    return "\n"..word
                end
            end)
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
    for _,v in ipairs(health) do
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
        for _,v in ipairs(history.damage) do
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
        for _,v in ipairs(history.heals) do
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
        if name=="cacheHits" then return cacheHits end
        if name=="cacheMisses" then return cacheMisses end
        if name=="cachedResult" then return cachedResult end
        if name=="color" then return color end
        if name=="compare" then return addon.compare end
        if name=="getCached" then return addon.getCached end
        if name=="getCachedInternal" then return getCachedInternal end
        if name=="getRetryCached" then return addon.getRetryCached end
        if name=="isin" then return addon.isin end
        if name=="nilArgument" then return nilArgument end
        if name=="nullable" then return addon.nullable end
        if name=="nullable_value" then return addon.nullable_value end
        if name=="packResults" then return packResults end
        if name=="split" then return addon.split end
        if name=="string" then return string end
        if name=="trim" then return addon.trim end
        if name=="wrap" then return addon.wrap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("utils.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["utils.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
