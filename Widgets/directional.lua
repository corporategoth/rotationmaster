--[[-----------------------------------------------------------------------------
Help Widget
-------------------------------------------------------------------------------]]
local Type, Version = "Directional", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Control_OnEnter(frame)
    frame.obj:Fire("OnEnter")
end

local function Control_OnLeave(frame)
    frame.obj:Fire("OnLeave")
end

local function Button_OnClick(frame, button)
    frame.obj:Fire("OnClick", button, frame.direction)
    AceGUI:ClearFocus()
end

local recurse_lockout = false
--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(48)
        self:SetSquare(true)
        self:SetDisabled(false)
    end,

    -- ["OnRelease"] = nil,
    ["SetWidth"] = function(self, width)
        self.frame:SetWidth(width)
        self.up:SetWidth(width / 3)
        self.left:SetWidth(width / 3)
        self.center:SetWidth(width / 3)
        self.right:SetWidth(width / 3)
        self.down:SetWidth(width / 3)
        self.frame.width = width
        if self.OnWidthSet then
            self:OnWidthSet(width)
        end
        if self.square and not recurse_lockout then
            recurse_lockout = true
            --local screenw = GetScreenWidth()
            --local screenh = GetScreenHeight()
            --self:SetHeight(width * (screenh / screenw * 2))
            self:SetHeight(width)
            recurse_lockout = false
        end
    end,

    ["SetHeight"] = function(self, height)
        self.frame:SetHeight(height)
        self.up:SetHeight(height / 3)
        self.left:SetHeight(height / 3)
        self.center:SetHeight(height / 3)
        self.right:SetHeight(height / 3)
        self.down:SetHeight(height / 3)
        self.frame.height = height
        if self.OnHeightSet then
            self:OnHeightSet(height)
        end
        if self.square and not recurse_lockout then
            recurse_lockout = true
            --local screenw = GetScreenWidth()
            --local screenh = GetScreenHeight()
            --self:SetWidth(height * (screenw / screenh))
            self:SetWidth(height)
            recurse_lockout = false
        end
    end,

    ["SetSquare"] = function(self, square)
        self.square = square
        if square then
            self:SetWidth(self.frame.width)
        end
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            --self.frame:Disable()
            self.up:Disable()
            self.up_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
            self.left:Disable()
            self.left_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
            self.center:Disable()
            self.center_image:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Disabled")
            self.right:Disable()
            self.right_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
            self.down:Disable()
            self.down_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
        else
            --self.frame:Enable()
            self.up:Enable()
            self.up_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            self.left:Enable()
            self.left_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            self.center:Enable()
            self.center_image:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
            self.right:Enable()
            self.right_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            self.down:Enable()
            self.down_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        end
    end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", Control_OnEnter)
    frame:SetScript("OnLeave", Control_OnLeave)

    local angle = math.rad(90)

    local up = CreateFrame("Button", nil, frame)
    up:EnableMouse(true)
    up:SetScript("OnClick", Button_OnClick)
    up.direction = "UP"

    local up_image = up:CreateTexture(nil, "BACKGROUND")
    up_image:SetAllPoints(up)
    up_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    up_image:SetTexCoord(0.25, 0.75, 0.25, 0.75)
    --up_image:SetBlendMode("ADD")
    local up_highlight = up:CreateTexture(nil, "HIGHLIGHT")
    up_highlight:SetAllPoints(up_image)
    up_highlight:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
    up_highlight:SetBlendMode("ADD")

    local left = CreateFrame("Button", nil, frame)
    left:EnableMouse(true)
    left:SetScript("OnClick", Button_OnClick)
    left.direction = "LEFT"

    local left_image = left:CreateTexture(nil, "BACKGROUND")
    left_image:SetAllPoints(left)
    left_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    left_image:SetTexCoord(0.25, 0.75, 0.25, 0.75)
    left_image:SetRotation(angle)
    --left_image:SetBlendMode("ADD")
    local left_highlight = left:CreateTexture(nil, "HIGHLIGHT")
    left_highlight:SetAllPoints(left_image)
    left_highlight:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
    left_highlight:SetRotation(angle)
    left_highlight:SetBlendMode("ADD")

    local center = CreateFrame("Button", nil, frame)
    center:EnableMouse(true)
    center:SetScript("OnClick", Button_OnClick)
    center.direction = "CENTER"

    local center_image = center:CreateTexture(nil, "BACKGROUND")
    center_image:SetAllPoints(center)
    center_image:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
    --center_image:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    --center_image:SetBlendMode("ADD")
    --local center_highlight = center:CreateTexture(nil, "HIGHLIGHT")
    --center_highlight:SetAllPoints(center_image)
    --center_highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Highlight")
    --center_highlight:SetBlendMode("ADD")

    local right = CreateFrame("Button", nil, frame)
    right:EnableMouse(true)
    right:SetScript("OnClick", Button_OnClick)
    right.direction = "RIGHT"

    local right_image = right:CreateTexture(nil, "BACKGROUND")
    right_image:SetAllPoints(right)
    right_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    right_image:SetTexCoord(0.25, 0.75, 0.25, 0.75)
    right_image:SetRotation(angle)
    --right_image:SetBlendMode("ADD")
    local right_highlight = right:CreateTexture(nil, "HIGHLIGHT")
    right_highlight:SetAllPoints(right_image)
    right_highlight:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    right_highlight:SetRotation(angle)
    right_highlight:SetBlendMode("ADD")

    local down = CreateFrame("Button", nil, frame)
    down:EnableMouse(true)
    down:SetScript("OnClick", Button_OnClick)
    down.direction = "DOWN"

    local down_image = down:CreateTexture(nil, "BACKGROUND")
    down_image:SetAllPoints(down)
    down_image:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    down_image:SetTexCoord(0.25, 0.75, 0.25, 0.75)
    --down_image:SetBlendMode("ADD")
    local down_highlight = down:CreateTexture(nil, "HIGHLIGHT")
    down_highlight:SetAllPoints(down_image)
    down_highlight:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    down_highlight:SetBlendMode("ADD")

--    makebox(frame,  1, 1, 1, 1)
--    makebox(up,     1, 1, 1, 1)
--    makebox(left,   1, 1, 1, 1)
--    makebox(right,  1, 1, 1, 1)
--    makebox(down,   1, 1, 1, 1)
--    makebox(center, 1, 0, 0, 1)

    center:SetPoint("CENTER", frame, "CENTER", 0, 0)
    up:SetPoint("TOP", frame, "TOP", 0, 0)
    up:SetPoint("BOTTOM", center, "TOP", 0, 0)
    left:SetPoint("LEFT", frame, "LEFT", 0, 0)
    left:SetPoint("RIGHT", center, "LEFT", 0, 0)
    right:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    right:SetPoint("LEFT", center, "RIGHT", 0, 0)
    down:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    down:SetPoint("TOP", center, "BOTTOM", 0, 0)

    local widget = {
        frame = frame,
        type  = Type,
        up = up,
        left = left,
        center = center,
        right = right,
        down = down,
        up_image = up_image,
        left_image = left_image,
        center_image = center_image,
        right_image = right_image,
        down_image = down_image,
        square = false,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    frame.obj = widget
    up.obj = widget
    left.obj = widget
    center.obj = widget
    right.obj = widget
    down.obj = widget

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
