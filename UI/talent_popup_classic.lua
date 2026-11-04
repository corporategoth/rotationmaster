-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The "classic" talent tree provider: shows one talent tree of the player's class on Era, Season of Discovery, TBC
-- Anniversary and Wrath Classic, laid out by Blizzard's own TalentFrame_Update on a frame RM owns (docs/talent-selector.md).
-- It draws nothing itself: Blizzard places the buttons by tier and column, picks the background, and draws the branches
-- and arrows. Afterwards RM undoes the graying Blizzard applies to talents the player cannot buy yet, marks the saved
-- talent and routes clicks to the condition. Blizzard's own talent window is never touched, because a click on one of its
-- buttons would spend a talent point. Loaded from RotationMaster.toc after UI/talent_popup.lua, whose window it fills.
local _, addon = ...
local platform = addon.Platform

local NAME = 'RotationMasterClassicTalentTree'
local WIDTH, TOP, COLUMN_SPACING, TIER_SPACING, BUTTON_SIZE = 320, 20, 63, 63, 32
local TALENT_BUTTONS, BRANCH_TEXTURES, ARROW_TEXTURES = 40, 30, 30
local GREEN, GOLD = { 0.1, 1.0, 0.1 }, { 1.0, 0.82, 0.0 }

local classic = { families = { era = true, tbc = true, progression = true }, priority = 50 }
local built

-- Whether the globals the tree needs are all present.
-- @return boolean  True when Blizzard's talent frame code and templates are loaded.
local function haveBlizzardCode()
    return type(TalentFrame_Update) == 'function'
        and type(TalentFrame_Load) == 'function'
        and type(PanelTemplates_GetSelectedTab) == 'function'
        and type(C_SpecializationInfo) == 'table'
        and type(C_SpecializationInfo.GetSpecializationInfo) == 'function'
end

-- Whether this provider can serve the client: a "tree" layout whose frame code is the Classic one (Era, TBC, Wrath).
-- @return boolean  True when the layout and Blizzard's code are right.
--
-- Cataclysm's tree uses another frame base, and Mists is a grid; neither is served here.
function classic.available()
    if platform:GetTalentLayout() ~= 'tree' then
        return false
    end

    local info = platform:GetClientInfo()

    if info.family == 'progression' and info.expansion ~= 2 then
        return false
    end

    return haveBlizzardCode()
end

-- Creates the frame the first time it is needed: the children Blizzard's TalentFrame_Update looks up by global name
-- (background pieces, talent buttons, branch and arrow textures, the points text and the scroll button it rewires).
-- @param parent table  The window's content frame.
-- @return table|nil  The frame; nil when a template is missing or creation fails.
local function build(parent)
    if built then
        built:SetParent(parent)
        return built
    end

    local ok, frame = pcall(CreateFrame, 'Frame', NAME, parent)

    if not ok or not frame then
        return nil
    end

    local pieces = {
        BackgroundTopLeft = { 'TOPLEFT', 256, 256 },
        BackgroundTopRight = { 'TOPRIGHT', 44, 256 },
        BackgroundBottomLeft = { 'BOTTOMLEFT', 256, 75 },
        BackgroundBottomRight = { 'BOTTOMRIGHT', 44, 75 },
    }

    for suffix, piece in pairs(pieces) do
        local texture = frame:CreateTexture(NAME .. suffix, 'BACKGROUND')
        texture:SetPoint(piece[1])
        texture:SetSize(piece[2], piece[3])
    end

    frame.pointsText = frame:CreateFontString(NAME .. 'TalentPointsText', 'OVERLAY', 'GameFontNormal')
    frame.pointsText:Hide()
    frame.scrollDown = CreateFrame('Button', NAME .. 'ScrollFrameScrollBarScrollDownButton', frame)
    frame.scrollDown:Hide()

    for index = 1, BRANCH_TEXTURES do
        frame:CreateTexture(NAME .. 'Branch' .. index, 'ARTWORK', 'TalentBranchTemplate'):Hide()
    end

    for index = 1, ARROW_TEXTURES do
        frame:CreateTexture(NAME .. 'Arrow' .. index, 'OVERLAY', 'TalentArrowTemplate'):Hide()
    end

    frame.buttons = {}

    for index = 1, TALENT_BUTTONS do
        local created, button = pcall(CreateFrame, 'Button', NAME .. 'Talent' .. index, frame, 'TalentButtonTemplate')

        if not created then
            return nil
        end

        button:SetID(index)
        button:Hide()
        button.chosen = button:CreateTexture(nil, 'OVERLAY')
        button.chosen:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
        button.chosen:SetBlendMode('ADD')
        button.chosen:SetPoint('CENTER')
        button.chosen:SetSize(BUTTON_SIZE * 2.2, BUTTON_SIZE * 2.2)
        button.chosen:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        button.chosen:Hide()
        frame.buttons[index] = button
    end

    TalentFrame_Load(frame)
    frame.inspect, frame.pet = false, false
    built = frame
    return frame
end

-- Gives the points Blizzard's TalentFrame_Update reads from the frame before it draws, as Blizzard's own talent window
-- does in its update function.
-- @param frame table  The frame.
local function readPoints(frame)
    local _, _, _, _, _, _, spent, _, preview = C_SpecializationInfo.GetSpecializationInfo(
        frame.selectedTab,
        false,
        false,
        nil,
        nil,
        frame.talentGroup
    )

    frame.pointsSpent, frame.previewPointsSpent = spent or 0, preview or 0
end

-- Undoes the gray of a branch or arrow texture: Blizzard picks the lower half of its sheet for "not reachable yet".
-- @param texture table|nil  The texture.
local function lighten(texture)
    if not texture or not texture:IsShown() or type(texture.GetTexCoord) ~= 'function' then
        return
    end

    local left, top, _, _, right, _, _, bottom = texture:GetTexCoord()
    local low = math.min(top, bottom)

    if low >= 0.5 then
        texture:SetTexCoord(left, right, top - low, bottom - low)
    end
end

-- Shows one talent button as selectable: not grayed, its rank visible, gold when it is the saved talent, green otherwise.
-- @param button table  The talent button.
-- @param chosen boolean  Whether it is the saved talent.
local function paint(button, chosen)
    if type(SetItemButtonDesaturated) == 'function' then
        SetItemButtonDesaturated(button, nil)
    end

    local color = chosen and GOLD or GREEN

    local slot, rank, border =
        _G[button:GetName() .. 'Slot'], _G[button:GetName() .. 'Rank'], _G[button:GetName() .. 'RankBorder']

    if slot then
        slot:SetVertexColor(color[1], color[2], color[3])
    end

    if border then
        border:SetVertexColor(1, 1, 1)
        border:Show()
    end

    if rank then
        rank:SetTextColor(color[1], color[2], color[3])
        rank:Show()
    end

    if chosen then
        button.chosen:Show()
    else
        button.chosen:Hide()
    end
end

-- Lays the tree out for a tree index and group and fixes up what Blizzard grayed.
-- @param frame table  The frame.
-- @param tree number  The tree (tab) index.
-- @param group number|nil  The talent group.
-- @param selection table|nil  The saved { tree, talent }.
-- @return number|nil  The height the frame needs; nil when Blizzard's code failed.
local function show(frame, tree, group, selection)
    frame.selectedTab = tree
    frame.talentGroup = group or C_SpecializationInfo.GetActiveSpecGroup(false, false)

    frame.updateFunction = function()
        readPoints(frame)
    end

    for _, button in ipairs(frame.buttons) do
        button:ClearAllPoints()
    end

    if not pcall(TalentFrame_Update, frame) then
        return nil
    end

    local lowest = 0

    for index, button in ipairs(frame.buttons) do
        if button:IsShown() then
            local _, _, _, _, y = button:GetPoint()
            lowest = math.min(lowest, y or 0)
            paint(button, selection and selection.tree == tree and selection.talent == index)
        end
    end

    for index = 1, BRANCH_TEXTURES do
        lighten(_G[NAME .. 'Branch' .. index])
    end

    for index = 1, ARROW_TEXTURES do
        lighten(_G[NAME .. 'Arrow' .. index])
    end

    return TOP - lowest + BUTTON_SIZE + 16
end

-- Opens the tree for the window.
-- @param ctx table  The provider context (Platform/talent_tree.lua); spec is the tree index.
-- @return table|nil  The handle { Reload, Close, spec }; nil when the tree cannot be shown.
-- @return string|nil  The failure code when the first value is nil.
function classic.open(ctx)
    local d = ctx.window
    local frame = build(d.content)

    if not frame then
        return nil, 'talent-window-unavailable'
    end

    d.mode = 'classic'
    local handle = { frame = frame }

    -- Draws the tree for a new context and tells the window how much room it needs.
    -- @param _ any  Unused (the handle).
    -- @param context table  The provider context.
    -- @return boolean|nil  True on success; nil on failure.
    -- @return string|nil  The failure code when the first value is nil.
    function handle.Reload(_, context)
        local tree = context.spec or context.selection and context.selection.tree or 1
        local count = platform:GetTalentTreeCount()

        if not count or tree < 1 or tree > count then
            tree = 1
        end

        local height = show(frame, tree, context.group, context.selection)

        if not height then
            return nil, 'talent-window-unavailable'
        end

        frame:ClearAllPoints()
        frame:SetPoint('TOP', d.content, 'TOP', 0, 0)
        frame:SetSize(WIDTH, height)
        frame:Show()

        for index, button in ipairs(frame.buttons) do
            button.talentButton_OnClick = function(self)
                local info = platform:GetTreeTalentInfo(tree, self:GetID(), context.group)

                if
                    context.selection and context.selection.tree == tree and context.selection.talent == self:GetID()
                then
                    context.onSelect(false)
                elseif info then
                    context.onSelect({ tree = tree, talent = self:GetID(), name = info.name, icon = info.icon })
                end
            end

            button.talentButton_OnEnter = function(self)
                local info = platform:GetTreeTalentInfo(tree, self:GetID(), context.group)

                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')

                if info and info.talentID and type(GameTooltip.SetTalent) == 'function' then
                    GameTooltip:SetTalent(info.talentID, false, false, frame.talentGroup)
                elseif info then
                    GameTooltip:SetText(info.name)
                end

                GameTooltip:Show()
            end
        end

        handle.spec = tree
        handle.canvasSize = { width = WIDTH, height = height }
        return true
    end

    -- Hides the tree and the tooltip it showed; the frame stays for the next session.
    function handle.Close()
        frame:Hide()

        for _, button in ipairs(frame.buttons) do
            button.talentButton_OnClick, button.talentButton_OnEnter = nil, nil
        end

        if GameTooltip and GameTooltip:GetOwner() and GameTooltip:GetOwner():GetParent() == frame then
            GameTooltip:Hide()
        end
    end

    local done, why = handle.Reload(nil, ctx)

    if not done then
        return nil, why
    end

    return handle
end

platform:RegisterTalentTreeProvider('classic', classic)
