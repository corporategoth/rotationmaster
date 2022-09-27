local _, addon = ...

--[[-----------------------------------------------------------------------------
Help Widget
-------------------------------------------------------------------------------]]
local Type, Version = "DisablableInlineGroup", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local methods = {
    ["CheckRecurseDisabled"] = function(self, disabled)
        return true
    end,

    ["SetDisabled"] = function(self, disabled, recurse)
        if recurse then
            if disabled then
                self.titlebutton:Disable()
            else
                self.titlebutton:Enable()
            end
        end
        if recurse and not self:CheckRecurseDisabled(disabled) then
            return
        end

        self.disabled = disabled
        if disabled then
            --self.frame:Disable()
            self.titletext:SetFontObject("GameFontDisable")
        else
            --self.frame:Enable()
            self.titletext:SetFontObject("GameFontNormal")
        end
        self:Fire("OnSetDisabled", disabled, recurse)

        local function recurse_children(parent, disabled)
            if parent.children then
                for _, child in pairs(parent.children) do
                    if child.CheckRecurseDisabled then
                        child:SetDisabled(disabled, true)
                    else
                        if child.SetDisabled then
                            child:SetDisabled(disabled)
                        end
                        recurse_children(child, disabled)
                    end
                end
            end
        end
        recurse_children(self, disabled)
    end,
}

local function Constructor()
    local group = AceGUI:Create("InlineGroup")
    group.disabled = false

    local titlebutton = CreateFrame("Button", nil, group.frame)
    titlebutton:SetPoint("TOPLEFT", 14, 0)
    titlebutton:SetPoint("TOPRIGHT", -14, 0)
    titlebutton:SetHeight(18)
    titlebutton.obj = group
    titlebutton:SetScript("OnClick", function(widget)
        widget.obj:SetDisabled(not widget.obj.disabled)
    end)
    group.titlebutton = titlebutton

    for method, func in pairs(methods) do
        group[method] = func
    end

    return group
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
