--[[-----------------------------------------------------------------------------
Help Widget
-------------------------------------------------------------------------------]]
local Type, Version = "Help", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local select, pairs, print = select, pairs, print

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Control_OnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT", 3)
    if frame.obj.tooltip then
        GameTooltip:SetText(frame.obj.tooltip, 1, 1, 1, 1, true)
    else
        GameTooltip:SetText("Help", 1, 1, 1, 1, true)
    end
    frame.obj:Fire("OnEnter")
end

local function Control_OnLeave(frame)
    GameTooltip:Hide()
    frame.obj:Fire("OnLeave")
end

local function Button_OnClick(frame, button)
    frame.obj:Fire("OnClick", button)
    AceGUI:ClearFocus()
    if frame.obj.layout then
        local window = AceGUI:Create("Window")

        window.frame:EnableKeyboard(true)
        window.frame:SetPropagateKeyboardInput(true)
        window.frame:SetScript("OnKeyDown", function (self, key)
            self:SetPropagateKeyboardInput(key ~= "ESCAPE")
            if key == "ESCAPE" then
                window:Hide()
            end
        end)

        --window:SetParent(frame.obj)
        window.frame:SetFrameLevel(frame:GetFrameLevel() + 1)
        if frame.obj.title then
            window:SetTitle(frame.obj.title)
        end
        window:SetWidth(frame.obj.frame_width)
        window:SetHeight(frame.obj.frame_height)
        window:PauseLayout()
        window:SetLayout("Fill")

        local scrollwin = AceGUI:Create("ScrollFrame")
        scrollwin:SetFullWidth(true)
        scrollwin:SetFullHeight(true)
        scrollwin:SetLayout("List")
        window:AddChild(scrollwin)

        frame.obj.layout(scrollwin)

        window:ResumeLayout()
        window:DoLayout()
        window.frame:Raise()
    end
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetHeight(32)
        self:SetWidth(32)
        self:SetDisabled(false)
    end,

    -- ["OnRelease"] = nil,
    ["SetWidth"] = function(self, width)
        self.float_frame:SetWidth(width)
        self.frame:SetWidth(0)
        self.width = 0
    end,

    ["SetRelativeWidth"] = function(self, width)
    end,

    ["SetHeight"] = function(self, height)
        self.float_frame:SetHeight(height)
        self.frame:SetHeight(0)
        self.height = 0
    end,

    ["SetRelativeHeight"] = function(self, width)
    end,

    ["SetTooltip"] = function(self, tooltip)
        self.tooltip = tooltip
    end,

    ["SetLayout"] = function(self, layoutfunc)
        self.layout = layoutfunc
    end,

    ["SetTitle"] = function(self, title)
        self.title = title
    end,

    ["SetFrameSize"] = function(self, width, height)
        self.frame_width = width
        self.frame_height = height
    end,

    ["SetPoint"] = function(self, anchor, xoffs, yoffs)
        if self.frame:GetParent() then
            self.float_frame:ClearAllPoints()
            return self.float_frame:SetPoint(anchor, self.frame:GetParent(), anchor, xoffs, yoffs)
        end
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.float_frame:Disable()
            self.image:SetTexCoord(0.5, 0.5, 0.5, 0.5)
        else
            self.float_frame:Enable()
            self.image:SetTexCoord(0, 0.5, 0, 0.5)
        end
    end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    local float_frame = CreateFrame("Button", nil, frame)
    float_frame:Hide()
    frame:SetScript("OnHide", function(widget)
        float_frame:Hide()
    end)
    frame:SetScript("OnShow", function(widget)
        float_frame:Show()
    end)

    float_frame:EnableMouse(true)
    float_frame:SetScript("OnEnter", Control_OnEnter)
    float_frame:SetScript("OnLeave", Control_OnLeave)
    float_frame:SetScript("OnClick", Button_OnClick)

    local image = float_frame:CreateTexture(nil, "BACKGROUND")
    image:SetAllPoints(float_frame)
    image:SetTexture("Interface\\WorldMap\\UI-WorldMap-QuestIcon")
    image:SetTexCoord(0, 0.5, 0, 0.5)
    --image:SetBlendMode("ADD")

    local highlight = float_frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(image)
    highlight:SetTexture("Interface\\WorldMap\\UI-WorldMap-QuestIcon")
    highlight:SetTexCoord(0.5, 1, 0, 0.5)
    highlight:SetBlendMode("ADD")

    local widget = {
        image = image,
        frame = frame,
        float_frame = float_frame,
        type  = Type,
        tooltip = nil,
        title = nil,
        layout = nil,
        frame_width = 600,
        frame_height = 400,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    frame.obj = widget
    float_frame.obj = widget

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
