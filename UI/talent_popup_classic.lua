-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The "classic" and "grid" talent tree providers: they show the player's own class on Era, Season of Discovery, TBC
-- Anniversary, Wrath, Cataclysm (three trees) and Mists (six tiers of three), laid out by Blizzard's own
-- TalentFrame_Update on a frame RM owns (docs/talent-selector.md). RM draws no talent itself: Blizzard places the
-- buttons, picks the backdrop and draws the branches. Afterwards RM undoes the graying Blizzard applies to talents the
-- player cannot buy yet, marks the saved talent and routes clicks to the condition. Blizzard's own talent window is never
-- touched, because a click on one of its buttons would spend a talent point; RM's buttons carry RM's scripts only.
-- Loaded from RotationMaster.toc after UI/talent_popup.lua, whose window it fills.
local _, addon = ...
local platform = addon.Platform

local NAME = 'RotationMasterClassicTalentTree'
local WIDTH, TOP, BUTTON_SIZE = 320, 20, 32
local BRANCH_TEXTURES, ARROW_TEXTURES = 30, 30
local GREEN, GOLD = { 0.1, 1.0, 0.1 }, { 1.0, 0.82, 0.0 }

local classic = { families = { era = true, tbc = true, progression = true }, priority = 50 }
local grid = { families = { progression = true }, priority = 50 }
local built, builtGrid

-- Records the room a tree needs, for the window's layout.
-- @param handle table  The provider handle.
-- @param width number  The tree's width.
-- @param height number  The tree's height.
local function size(handle, width, height)
    handle.canvasSize = { width = width, height = height }
end

-- Whether Blizzard's talent frame code is present.
-- @return boolean  True when the update function and the info reader exist.
local function haveBlizzardCode()
    return type(TalentFrame_Update) == 'function'
        and type(C_SpecializationInfo) == 'table'
        and type(C_SpecializationInfo.GetTalentInfo) == 'function'
end

-- Shows or hides a texture.
-- @param texture table|nil  The texture.
-- @param flag any  Truthy shows it.
local function visible(texture, flag)
    if not texture then
        return
    end

    if flag then
        texture:Show()
    else
        texture:Hide()
    end
end

-- Loads Blizzard's load-on-demand talent UI, whose templates the Mists rows come from.
local function loadBlizzardTalentUI()
    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn

    if type(loader) == 'function' then
        pcall(loader, 'Blizzard_TalentUI')
    end
end

-- ============================================================================
-- Trees: Era, Season of Discovery, TBC Anniversary, Wrath, Cataclysm
-- ============================================================================

-- Whether this provider can serve the client: a "tree" layout whose frame code is Blizzard's.
-- @return boolean  True when the layout and Blizzard's code are right.
function classic.available()
    if platform:GetTalentLayout() ~= 'tree' then
        return false
    end

    return haveBlizzardCode()
        and type(TalentFrame_Load) == 'function'
        and type(PanelTemplates_GetSelectedTab) == 'function'
end

-- Creates the frame the first time it is needed: the children Blizzard's TalentFrame_Update looks up by global name
-- (backdrop pieces, talent buttons, branch and arrow textures, the points text and the scroll button it rewires).
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

    for index = 1, tonumber(MAX_NUM_TALENTS) or 40 do
        local created, button = pcall(CreateFrame, 'Button', NAME .. 'Talent' .. index, frame, 'TalentButtonTemplate')

        if not created then
            return nil
        end

        button:SetID(index)
        button:Hide()
        button:RegisterForClicks('LeftButtonUp')
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
    local slot, rank = _G[button:GetName() .. 'Slot'], _G[button:GetName() .. 'Rank']
    local border = _G[button:GetName() .. 'RankBorder']

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

    visible(button.chosen, chosen)
end

-- Lays the tree out for a tree index and group and fixes up what Blizzard grayed.
-- @param frame table  The frame.
-- @param tree number  The tree (tab) index.
-- @param group number|nil  The talent group.
-- @param selection table|nil  The saved { tree, talent }.
-- @return number|nil  The height the frame needs; nil when Blizzard's code failed.
local function show(frame, tree, group, selection)
    frame.selectedTab = tree
    frame.talentTree = tree
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

        for _, button in ipairs(frame.buttons) do
            -- Chooses this talent, or clears the choice when it is the saved one.
            -- @param self table  The button.
            addon:SetUIScript(button, 'OnClick', function(self)
                local info = platform:GetTreeTalentInfo(tree, self:GetID(), context.group)

                if
                    context.selection and context.selection.tree == tree and context.selection.talent == self:GetID()
                then
                    context.onSelect(false)
                elseif info then
                    context.onSelect({ tree = tree, talent = self:GetID(), name = info.name, icon = info.icon })
                end
            end)

            -- Shows the game's own talent tooltip.
            -- @param self table  The button.
            addon:SetUIScript(button, 'OnEnter', function(self)
                local info = platform:GetTreeTalentInfo(tree, self:GetID(), context.group)

                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')

                if info and info.talentID and type(GameTooltip.SetTalent) == 'function' then
                    GameTooltip:SetTalent(info.talentID, false, false, frame.talentGroup)
                elseif info then
                    GameTooltip:SetText(info.name)
                end

                GameTooltip:Show()
            end)
        end

        handle.spec = tree
        size(handle, WIDTH, height)
        return true
    end

    -- Hides the tree and the tooltip it showed; the frame stays for the next session.
    function handle.Close()
        frame:Hide()

        for _, button in ipairs(frame.buttons) do
            addon:SetUIScript(button, 'OnClick', nil)
            addon:SetUIScript(button, 'OnEnter', nil)
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

-- ============================================================================
-- Tiers: Mists of Pandaria
-- ============================================================================

local ROW_WIDTH, ROW_HEIGHT, ROW_SPACING, TIERS = 627, 50, 58, 6

-- Whether this provider can serve the client: the Mists grid with Blizzard's update function.
-- @return boolean  True on the Mists layout when Blizzard's code is present.
function grid.available()
    return platform:GetTalentLayout() == 'grid' and haveBlizzardCode()
end

-- Creates the Mists frame the first time: six rows from Blizzard's row template, each holding Blizzard's three talent
-- buttons, as TalentFrame_Update expects (frame.tier1 .. frame.tier6, each with talent1 .. talent3).
-- @param parent table  The window's content frame.
-- @return table|nil  The frame; nil when a template is missing or creation fails.
local function buildGrid(parent)
    if builtGrid then
        builtGrid:SetParent(parent)
        return builtGrid
    end

    loadBlizzardTalentUI()
    local ok, frame = pcall(CreateFrame, 'Frame', NAME .. 'Grid', parent)

    if not ok or not frame then
        return nil
    end

    frame.rows = {}

    for tier = 1, TIERS do
        local created, row = pcall(CreateFrame, 'Frame', NAME .. 'GridRow' .. tier, frame, 'PlayerTalentRowTemplate')

        if not created or not row.talent1 or not row.talent2 or not row.talent3 then
            return nil
        end

        row:SetID(tier)
        row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -(tier - 1) * ROW_SPACING)
        frame['tier' .. tier] = row
        frame.rows[tier] = row

        for column = 1, 3 do
            row['talent' .. column]:RegisterForClicks('LeftButtonUp')
        end
    end

    frame.inspect = false
    builtGrid = frame
    return frame
end

-- Lays the grid out and fixes up what Blizzard grayed.
-- @param frame table  The frame.
-- @param group number|nil  The talent group.
-- @param selection table|nil  The saved { slot } (1 to 18).
-- @return boolean  True when Blizzard's update ran.
local function showGrid(frame, group, selection)
    frame.talentGroup = group or C_SpecializationInfo.GetActiveSpecGroup(false)

    if not pcall(TalentFrame_Update, frame, 'player') then
        return false
    end

    for tier, row in ipairs(frame.rows) do
        for column = 1, 3 do
            local button = row['talent' .. column]
            local chosen = selection and selection.slot == (tier - 1) * 3 + column

            if type(SetDesaturation) == 'function' and button.icon then
                SetDesaturation(button.icon, false)
            end
            if button.highlight then
                button.highlight:SetAlpha(1)
            end

            visible(button.learnSelection, false)
            visible(button.knownSelection, chosen)

            if chosen and button.knownSelection and button.knownSelection.SetDesaturated then
                button.knownSelection:SetDesaturated(false)
            end
        end
    end

    return true
end

-- Opens the grid for the window.
-- @param ctx table  The provider context (Platform/talent_tree.lua); selection is { slot }.
-- @return table|nil  The handle { Reload, Close }; nil when the grid cannot be shown.
-- @return string|nil  The failure code when the first value is nil.
function grid.open(ctx)
    local d = ctx.window
    local frame = buildGrid(d.content)

    if not frame then
        return nil, 'talent-window-unavailable'
    end

    d.mode = 'classic'
    local handle = { frame = frame }

    -- Draws the grid for a new context and tells the window how much room it needs.
    -- @param _ any  Unused (the handle).
    -- @param context table  The provider context.
    -- @return boolean|nil  True on success; nil on failure.
    -- @return string|nil  The failure code when the first value is nil.
    function handle.Reload(_, context)
        if not showGrid(frame, context.group, context.selection) then
            return nil, 'talent-window-unavailable'
        end

        local height = (TIERS - 1) * ROW_SPACING + ROW_HEIGHT
        frame:ClearAllPoints()
        frame:SetPoint('TOP', d.content, 'TOP', 0, 0)
        frame:SetSize(ROW_WIDTH, height)
        frame:Show()

        for _, row in ipairs(frame.rows) do
            for column = 1, 3 do
                local button = row['talent' .. column]

                -- Chooses this talent, or clears the choice when it is the saved one.
                addon:SetUIScript(button, 'OnClick', function()
                    local slot = (row:GetID() - 1) * 3 + column
                    local info = platform:GetGridTalentInfo(slot, context.group)

                    if context.selection and context.selection.slot == slot then
                        context.onSelect(false)
                    elseif info then
                        context.onSelect({ slot = slot, name = info.name, icon = info.icon })
                    end
                end)

                -- Shows the game's own talent tooltip.
                -- @param self table  The button.
                addon:SetUIScript(button, 'OnEnter', function(self)
                    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')

                    if type(GameTooltip.SetTalent) == 'function' then
                        GameTooltip:SetTalent(self:GetID(), false, frame.talentGroup)
                    end

                    GameTooltip:Show()
                end)

                -- Blizzard's row buttons would otherwise run its talent handlers, which can learn a talent.
                addon:SetUIScript(button, 'OnEvent', nil)
                addon:SetUIScript(button, 'OnDragStart', nil)
                addon:SetUIScript(button, 'OnReceiveDrag', nil)
            end
        end

        size(handle, ROW_WIDTH, height)
        return true
    end

    -- Hides the grid and the tooltip it showed; the frame stays for the next session.
    function handle.Close()
        frame:Hide()

        for _, row in ipairs(frame.rows) do
            for column = 1, 3 do
                addon:SetUIScript(row['talent' .. column], 'OnClick', nil)
                addon:SetUIScript(row['talent' .. column], 'OnEnter', nil)
            end
        end

        local owner = GameTooltip and GameTooltip:GetOwner()

        if owner and owner:GetParent() and owner:GetParent():GetParent() == frame then
            GameTooltip:Hide()
        end
    end

    local done, why = handle.Reload(nil, ctx)

    if not done then
        return nil, why
    end

    return handle
end

platform:RegisterTalentTreeProvider('grid', grid)
