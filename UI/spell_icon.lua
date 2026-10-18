local _,addon=...
local AceGUI=LibStub("AceGUI-3.0")
local function spellID(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end

-- Configuration-only spell display/drop control. The ordinary Icon remains a
-- field-layout bridge; spell identity and metadata belong to RM's adapters.
function addon:CreateSpellActionIcon(kind,initialSpell,accept)
    local widget=AceGUI:Create("Icon")
    -- The pinned ordinary Icon constructor creates a native Button.
    ---@type Button
    local frame=widget.frame
    local alive=true
    local originalText,originalRelease=widget.SetText,widget.OnRelease
    local originalClick,originalDrag,originalHide=frame:GetScript("OnClick"),frame:GetScript("OnReceiveDrag"),frame:GetScript("OnHide")
    widget.rmSpellIconActive=true
    widget:SetImageSize(36,36)
    local function hideTooltip()
        if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    end
    widget.SetText=function(self,value)
        local id
        if type(value)=="string" then id=tonumber(value) elseif type(value)=="number" then id=value end
        if not spellID(id) then id=nil end
        self:SetUserData("spell",id)
        local info=id and addon.Platform:GetSpellInfo(id)
        self:SetUserData("spellMetadata",info~=nil)
        self:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    widget:SetCallback("OnEnter",function()
        local id=widget:GetUserData("spell")
        if alive and id and widget:GetUserData("spellMetadata") and GameTooltip then
            GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("spell:"..id)
        end
    end)
    widget:SetCallback("OnLeave",hideTooltip)
    local function drop()
        if not alive or widget.disabled or type(GetCursorInfo)~="function" then return end
        local cursor={pcall(GetCursorInfo)}
        if not cursor[1] or not addon.Platform:CanReadValue(cursor[2]) then return end
        local action=cursor[2]
        if kind=="pet" and action~="petaction" or kind~="pet" and action~="spell" then return end
        local id=action=="petaction" and cursor[3] or cursor[5]
        if not addon.Platform:CanReadValue(id) or not spellID(id) or not addon.Platform:GetSpellInfo(id) then return end
        if accept and not accept(id) then return end
        -- The cursor has been validated before any data callback can rebuild
        -- this field. Never touch a newly acquired owner after that callback.
        if type(ClearCursor)=="function" then ClearCursor() end
        widget:Fire("OnEnterPressed",tostring(id))
    end
    local function click(_,button)
        if not alive or widget.disabled then return end
        if button=="RightButton" then widget:Fire("OnEnterPressed","")
        elseif button=="LeftButton" then drop() end
    end
    local function hide(self,...)
        hideTooltip()
        if originalHide then return originalHide(self,...) end
    end
    frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
    local installedClick=addon:SetUIScript(frame,"OnClick",click)
    local installedDrop=addon:SetUIScript(frame,"OnReceiveDrag",drop)
    local installedHide=addon:SetUIScript(frame,"OnHide",hide)
    widget.OnRelease=function(self,...)
        alive=false;hideTooltip();self.rmSpellIconActive=nil
        if frame:GetScript("OnClick")==installedClick then frame:SetScript("OnClick",originalClick) end
        if frame:GetScript("OnReceiveDrag")==installedDrop then frame:SetScript("OnReceiveDrag",originalDrag) end
        if frame:GetScript("OnHide")==installedHide then frame:SetScript("OnHide",originalHide) end
        frame:RegisterForClicks("LeftButtonUp")
        self.SetText,self.OnRelease=originalText,originalRelease
        self:SetUserData("spell",nil);self:SetUserData("spellMetadata",nil)
        if originalRelease then return originalRelease(self,...) end
    end
    widget:SetText(initialSpell)
    return widget
end
