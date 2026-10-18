local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local AceGUI=LibStub("AceGUI-3.0")
local reasons={
    ["disabled"]=L["Disabled"], ["invalid-or-unsupported"]=L["Unavailable conditions or unsupported data"],
    ["edition-mismatch"]=L["Different WoW edition"], ["class-mismatch"]=L["Different class"],
    ["specialization-mismatch"]=L["Different specialization"], ["action-context-mismatch"]=L["Different action context"],
    ["missing-level"]=L["Character level is unavailable"], ["level-mismatch"]=L["Outside its level range"],
    ["missing-build"]=L["Game build is unavailable"], ["build-mismatch"]=L["Different game build"],
    ["unsupported-context-selector"]=L["Required context is not supported yet"],
    ["restricted-or-unsupported-client"]=L["Reference only on this client"],
}
local function label(parent,text,kind)
    local widget=AceGUI:Create(kind or "Label")
    widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)
    return widget
end
function addon:CreateDefaultRotationOptions(frame,spec,id,onClone,onRefresh)
    frame:ReleaseChildren()
    local rows,why=self:ListDefaultRotations(spec)
    local row
    for _,candidate in ipairs(rows) do if candidate.id==id then row=candidate;break end end
    if not row then label(frame,L["The default rotation is unavailable."]);return end
    label(frame,row.name,"Heading")
    label(frame,L["Default · read-only"])
    label(frame,row.description)
    local scope=row.applicability or {}
    label(frame,string.format(L["Level range: %s–%s; revision %s"],scope.minLevel or "1",scope.maxLevel or "?",row.revision or "?"))
    local status=label(frame,row.eligible and L["Available for this character"]
        or string.format(L["Not available for this character: %s"],reasons[row.eligibilityReason] or L["Unavailable"]))
    local enable=AceGUI:Create("CheckBox")
    enable:SetLabel(L["Enable default"]);enable:SetValue(row.enabled)
    enable:SetCallback("OnValueChanged",function(_,_,value)
        local ok,reason=addon:SetDefaultRotationEnabled(id,value)
        if not ok then status:SetText(string.format(L["Could not update this default: %s"],reason));return end
        if addon.currentSpec~=nil and addon.db.profile.enable then
            addon:UpdateAutoSwitch();addon:SwitchRotation();addon:EvaluateNextAction()
        end
        if onRefresh then onRefresh() end
    end)
    frame:AddChild(enable)
    local clone=AceGUI:Create("Button")
    clone:SetText(L["Clone to edit"])
    clone:SetCallback("OnClick",function()
        local generated,reason=addon:CloneDefaultRotation(spec,id,string.format(L["Copy of %s"],row.name))
        if generated then onClone(generated)
        else status:SetText(string.format(L["Could not clone this default: %s"],reason)) end
    end)
    frame:AddChild(clone)
    local export=AceGUI:Create("Button");export:SetText(L["Export default"])
    export:SetCallback("OnClick",function() return addon:ShowRotationTransfer(spec,row.runtimeKey) end)
    frame:AddChild(export)
    local scroll=AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List");scroll:SetFullWidth(true);scroll:SetFullHeight(true)
    local body=row.envelope and row.envelope.body or {}
    self:CreateRotationReference(scroll,body,spec)
    label(scroll,L["Sources"],"Heading")
    for _,source in ipairs(row.envelope and row.envelope.sources or {}) do
        label(scroll,source.title or source.url)
        if source.title then label(scroll,source.url) end
    end
    frame:AddChild(scroll)
end

function addon:ShowDefaultRotation(spec,id)
    local window=AceGUI:Create("Window")
    window:SetTitle(L["Default rotation reference"]);window:SetWidth(880);window:SetHeight(680);window:SetLayout("Flow")
    window:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)
    self.HideOnEscape(window)
    local function cloned(generated)
        window:Hide()
        addon:ShowConfig("Rotations",{spec=spec,id=generated})
    end
    local function refresh()
        addon:CreateDefaultRotationOptions(window,spec,id,cloned,refresh)
    end
    refresh()
    return window
end
