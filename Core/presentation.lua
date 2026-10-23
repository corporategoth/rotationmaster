local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)

function addon:SpellLabel(spell)
    if self.Platform then
        local link=self.Platform:GetSpellLink(spell)
        if link then return link end
        local info=self.Platform:GetSpellInfo(spell)
        if info then return info.name end
    end
    if type(spell)=="string" then return spell end
    if type(spell)=="number" then return string.format(L["Unknown spell (%s)"],spell) end
    return L["<spell>"]
end
function addon:AuraSpellLabel(value)
    local label=self:SpellLabel(value.spell)
    if type(value.spell)=='number' and value.anyrank==true then return string.format(L['%s (any rank)'],label) end
    return label
end
-- A cast/channel spell picked by ID matches any rank unless `ranked`.
function addon:CastSpellLabel(value)
    local label=self:SpellLabel(value.spell)
    if type(value.spell)=='number' and value.ranked==true and self.SpellCatalog then
        local rank=self.SpellCatalog:SpellRank(value.spell)
        if type(rank)=='string' and rank~='' then return label..'|cFF888888 ('..rank..')|r' end
    end
    return label
end
local function supportedLink(link)
    return type(link)=="string" and link:match("^spell:%d+")~=nil
end
function addon:InstallSpellHyperlinks(frame)
    if not frame or not frame.SetHyperlinksEnabled or not frame.SetScript or not frame.GetScript or frame.rmSpellHyperlinks then return end
    frame.rmSpellHyperlinks=true
    frame:SetHyperlinksEnabled(true)
    if frame.EnableMouse then frame:EnableMouse(true) end
    local function install(event,callback)
        if frame.HookScript then frame:HookScript(event,callback)
        elseif not frame:GetScript(event) then frame:SetScript(event,callback) end
    end
    install("OnHyperlinkEnter",function(owner,link)
        if supportedLink(link) and GameTooltip then GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(link) end
    end)
    install("OnHyperlinkLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    install("OnHyperlinkClick",function(_,link,text,button)
        if supportedLink(link) and type(SetItemRef)=="function" then SetItemRef(link,text,button) end
    end)
end
function addon:CreateSpellLabel(parent,spell)
    local widget=self:CreateConditionLink()
    widget:SetFullWidth(true);parent:AddChild(widget);widget:SetText(self:SpellLabel(spell));widget:SetUserData("spell",spell)
    self:InstallSpellHyperlinks(widget.frame)
    -- Whole-label interactions also work when the client cannot enable native
    -- hyperlink regions on a widget frame.
    widget:SetCallback("OnEnter",function(control)
        local id=control:GetUserData("spell")
        local info=addon.Platform and addon.Platform:GetSpellInfo(id)
        if info and info.spellID and GameTooltip then
            GameTooltip:SetOwner(control.frame,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("spell:"..info.spellID)
        end
    end)
    widget:SetCallback("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    widget:SetCallback("OnClick",function(control,_,button)
        local id=control:GetUserData("spell")
        local info=addon.Platform and addon.Platform:GetSpellInfo(id)
        if info and info.spellID and type(SetItemRef)=="function" then SetItemRef("spell:"..info.spellID,addon:SpellLabel(id),button or "LeftButton") end
    end)
    return widget
end

-- Resolve inherited channels without materializing presentation defaults in saved steps.
function addon:ResolveHighlightColor(value)
    local profile=self.db and self.db.profile
    local fallback=profile and profile.color
    local function channel(source,key)
        local number=type(source)=="table" and source[key]
        if type(number)=="number" and number==number and number~=math.huge and number~=-math.huge then
            return math.max(0,math.min(1,number))
        end
    end
    local resolved={}
    for _,key in ipairs({"r","g","b","a"}) do resolved[key]=channel(value,key) or channel(fallback,key) or 1 end
    return resolved
end
