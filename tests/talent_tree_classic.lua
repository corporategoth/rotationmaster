-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- "Show talent tree" on the Classic tree clients (Era, TBC, Wrath): the classic provider drives Blizzard's TalentFrame_Update
-- on a frame RM owns, undoes the gray on talents the player cannot buy yet, marks the saved talent and reports clicks.
-- NO REAL CLIENT WAS AVAILABLE: TalentFrame_Update is modeled below from the pinned Blizzard source
-- (Blizzard_FrameXML/Vanilla/TalentFrameBase.lua, Classic/TalentFrameBase_Shared.lua): it places each button by tier and
-- column, greys a talent whose tier is locked or that has no points to spend, and picks the lower half of the branch sheet
-- for an unreachable line. Clicking one of Blizzard's own buttons would spend a point, so the test also proves RM's frame
-- never touches Blizzard's talent window.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local LOAD = {
    'Platform/talents.lua',
    'Platform/talent_tree.lua',
    'UI/talent_popup.lua',
    'UI/talent_popup_classic.lua',
}

-- Tree 1: tier 1 has three talents, tier 2 one under column 2, tier 3 one under it in column 1. Tree 2 has one talent.
local TALENTS = {
    [1] = {
        { name = 'Convection', tier = 1, column = 1, maxRank = 5, id = 101 },
        { name = 'Concussion', tier = 1, column = 2, maxRank = 5, id = 102 },
        { name = 'Call of Flame', tier = 1, column = 3, maxRank = 3, id = 103 },
        { name = 'Elemental Focus', tier = 2, column = 2, maxRank = 1, id = 104 },
        { name = 'Reverberation', tier = 3, column = 1, maxRank = 5, id = 105 },
    },
    [2] = { { name = 'Enhancing Totems', tier = 1, column = 2, maxRank = 3, id = 201 } },
}

local function client(product, expansion, options)
    options = options or {}
    local f = F.new(product or 5, expansion or 1, 'SHAMAN')
    local e = f.env
    local made = { buttons = {}, textures = {} }
    local native = e.CreateFrame

    local function region(object, name)
        if name then
            e[name] = object
        end

        object.regionName = name
        object.points = {}
        object.id = 0

        function object:GetName()
            return self.regionName
        end

        function object:SetID(id)
            self.id = id
        end

        function object:GetID()
            return self.id
        end

        function object:ClearAllPoints()
            self.points = {}
        end

        function object:SetPoint(point, relative, relativePoint, x, y)
            if type(relative) == 'number' then
                x, y, relative, relativePoint = relative, relativePoint, nil, nil
            end

            self.points[#self.points + 1] = { point, relative, relativePoint, x or 0, y or 0 }
        end

        function object:GetPoint(index)
            local point = self.points[index or 1]

            if point then
                return point[1], point[2], point[3], point[4], point[5]
            end
        end

        function object:SetTexCoord(left, right, top, bottom)
            self.coords = { left, top, left, bottom, right, top, right, bottom }
        end

        function object:GetTexCoord()
            local c = self.coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
            return c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]
        end

        function object:SetBlendMode() end

        function object:SetParent(parent)
            self.parent = parent
        end

        function object:GetParent()
            return self.parent
        end

        return object
    end

    e.CreateFrame = function(kind, name, parent, template)
        local frame = region(native(kind, name, parent, template), name)
        local createTexture, createFontString = frame.CreateTexture, frame.CreateFontString

        function frame:CreateTexture(textureName, layer, inherits)
            local texture = region(createTexture(self, textureName, layer, inherits), textureName)
            texture.parent = self
            made.textures[#made.textures + 1] = texture
            return texture
        end

        function frame:CreateFontString(textureName, layer, inherits)
            return region(createFontString(self, textureName, layer, inherits), textureName)
        end

        function frame:RegisterEvent() end

        if template == 'PlayerTalentRowTemplate' then
            frame.level = region(native('FontString', name .. 'Level', frame), name .. 'Level')

            function frame.level:SetText(text)
                self.text = text
            end

            function frame.level:SetTextColor() end

            for column = 1, 3 do
                local button = region(native('Button', name .. 'Talent' .. column, frame), name .. 'Talent' .. column)

                button.icon, button.highlight = region(native('Texture', nil, button)), region(native(
                    'Texture',
                    nil,
                    button
                ))

                button.knownSelection, button.learnSelection = region(native('Texture', nil, button)), region(native(
                    'Texture',
                    nil,
                    button
                ))

                button.name = region(native('FontString', nil, button))

                function button.name:SetText(text)
                    self.text = text
                end

                function button.highlight:SetAlpha(alpha)
                    self.alpha = alpha
                end

                function button.knownSelection:SetDesaturated(flag)
                    self.desaturated = flag
                end

                button.knownSelection:Hide()
                button.learnSelection:Hide()
                frame['talent' .. column] = button
                made.mists = made.mists or {}
                made.mists[#made.mists + 1] = button
            end
        end

        if template == 'TalentButtonTemplate' then
            for _, suffix in ipairs({ 'Slot', 'Rank', 'RankBorder' }) do
                local child = region(native('Texture', name .. suffix, frame), name .. suffix)

                function child:SetTextColor(...)
                    self.textColor = { ... }
                end

                function child:SetVertexColor(...)
                    self.color = { ... }
                end

                function child:Show()
                    self.visible = true
                end

                function child:Hide()
                    self.visible = false
                end

                child.visible = false
            end

            made.buttons[#made.buttons + 1] = frame
        end

        return frame
    end

    e.UIParent = e.CreateFrame('Frame')
    local tip = { lines = {} }

    function tip:SetOwner(owner)
        self.owner = owner
    end

    function tip:IsOwned(owner)
        return self.owner == owner
    end

    function tip:GetOwner()
        return self.owner
    end

    function tip:SetTalent(id, inspect, pet, group)
        self.talent = { id, inspect, pet, group }
    end

    function tip:SetText(text)
        self.text = text
    end

    function tip:Show()
        self.shown = true
    end

    function tip:Hide()
        self.shown = false
        self.owner = nil
    end

    e.GameTooltip = tip
    local state = { unspent = 0, ranks = {}, group = 1 }

    e.GetNumTalentTabs = function()
        return 3
    end

    e.GetNumTalents = function(tree)
        return TALENTS[tree] and #TALENTS[tree] or 0
    end

    e.C_SpecializationInfo = {
        GetActiveSpecGroup = function()
            return state.group
        end,
        GetSpecializationInfo = function(tree)
            return 260 + tree,
                'Tree ' .. tree,
                'd',
                136000 + tree,
                nil,
                nil,
                state.ranks[tree] or 0,
                'ShamanElemental',
                0
        end,
        GetTalentInfo = function(query)
            local t = TALENTS[query.specializationIndex] and TALENTS[query.specializationIndex][query.talentIndex]

            if not t then
                return nil
            end

            return {
                talentID = t.id,
                name = t.name,
                icon = 136100 + t.id,
                tier = t.tier,
                column = t.column,
                rank = state.ranks[t.id] or 0,
                maxRank = t.maxRank,
                meetsPrereq = t.tier == 1,
                spellID = 0,
            }
        end,
    }

    -- Blizzard's contract, modeled: tab and group on the frame, points from updateFunction, buttons placed by tier and
    -- column, a locked or pointless talent grayed and its rank hidden, lines at the gray half of the sheet.
    e.PanelTemplates_GetSelectedTab = function(frame)
        return frame.selectedTab
    end

    e.SetItemButtonDesaturated = function(button, flag)
        button.desaturated = flag
    end

    e.TalentFrame_Load = function(frame)
        frame.loaded = true
    end

    e.TalentFrame_Update = function(frame)
        assert(frame.loaded and not frame.inspect and not frame.pet)
        frame.updateFunction()
        assert(frame.pointsSpent and frame.previewPointsSpent)
        state.updates = (state.updates or 0) + 1
        local tab = frame.selectedTab

        for index = 1, 40 do
            local button = e[frame:GetName() .. 'Talent' .. index]
            local info = e.C_SpecializationInfo.GetTalentInfo({ specializationIndex = tab, talentIndex = index })

            if info then
                button:ClearAllPoints()
                button:SetPoint('TOPLEFT', frame, 'TOPLEFT', (info.column - 1) * 63 + 35, -((info.tier - 1) * 63) - 20)
                button:Show()
                button.desaturated = info.tier > 1
                e[button:GetName() .. 'Slot'].color = { 0.5, 0.5, 0.5 }
                e[button:GetName() .. 'Rank'].visible = false
                e[button:GetName() .. 'RankBorder'].visible = false
            else
                button:Hide()
            end
        end

        local branch = e[frame:GetName() .. 'Branch1']
        branch:SetTexCoord(0.12890625, 0.25390625, 0.515625, 1.0)
        branch:Show()
        local arrow = e[frame:GetName() .. 'Arrow1']
        arrow:SetTexCoord(0, 0.5, 0.5, 1.0)
        arrow:Show()
    end

    for _, path in ipairs(LOAD) do
        f.load(path)
    end

    f.tip, f.made, f.state = tip, made, state
    return f, f.addon, e
end

-- A Mists client: six tiers of three, the second tier's first talent learned, tiers 3 and up not yet open. The model of
-- TalentFrame_Update follows the pinned Mists/TalentFrameBase.lua: it numbers each button with its talent id, grays the
-- icon of a locked tier or of an unchosen talent in a tier that has a choice, and shows the learned one.
local function mistsClient(group)
    local f, a, e = client(19, 4)
    local state = f.state

    e.SetDesaturation = function(texture, flag)
        texture.desaturated = flag
    end

    e.C_SpecializationInfo.GetTalentInfo = function(query)
        local slot = (query.tier - 1) * 3 + query.column

        return {
            talentID = 1000 + slot,
            spellID = 2000 + slot,
            name = 'Talent ' .. slot,
            icon = 5000 + slot,
            selected = slot == 4,
            available = query.tier > 2,
        }
    end

    e.GetTalentTierInfo = function(tier)
        return tier <= 2, tier == 2 and 1004 or 0, tier * 15
    end

    e.TalentFrame_Update = function(frame, unit)
        assert(unit == 'player' and not frame.inspect and frame.tier1.talent1 and frame.tier6.talent3)
        state.updates = (state.updates or 0) + 1

        for tier = 1, 6 do
            for column = 1, 3 do
                local button = frame['tier' .. tier]['talent' .. column]
                local info = e.C_SpecializationInfo.GetTalentInfo({ tier = tier, column = column })
                button:SetID(info.talentID)
                button.tier, button.column = tier, column
                button.icon.desaturated = tier > 2 or info.talentID ~= 1004 and tier == 2
                button.knownSelection:Hide()
                button.learnSelection:Show()
                button.highlight.alpha = 0
            end
        end
    end

    return f, a, e
end

local function open(f, request)
    request = request or {}
    local picks = {}

    local window = f.addon:OpenTalentTree({
        owner = {},
        spec = request.spec or 1,
        specs = { { id = 1, name = 'Elemental' }, { id = 2, name = 'Enhancement' }, { id = 3, name = 'Restoration' } },
        specLabel = 'Talent Tree',
        selection = request.selection,
        selectionName = request.selectionName,
        rank = request.rank,
        operator = request.operator,
        ranked = true,
        onAccept = function(pick)
            picks[#picks + 1] = pick
        end,
    })

    return window, picks
end

-- Clicks a button the way the game does.
-- @param button table  The button.
-- @param mouse string|nil  The mouse button; left by default.
local function click(button, mouse)
    button.scripts.OnClick(button, mouse or 'LeftButton')
end

local function shown(f, tab)
    local out = {}

    for _, button in ipairs(f.made.buttons) do
        if button:IsShown() then
            out[#out + 1] = button
        end
    end

    return out
end

test('the classic provider serves Era, TBC, Wrath and Cataclysm; Mists belongs to the grid provider', function()
    for _, case in ipairs({ { 2, 1 }, { 5, 1 }, { 11, 2 }, { 14, 3 } }) do
        local f, a = client(case[1], case[2])
        local list = a.Platform:GetTalentTreeProviders()
        assert(#list == 1 and list[1].id == 'classic', 'product ' .. case[1])
        assert(a.Platform:HasTalentTreeProvider())
    end

    local _, mists = client(19, 4)
    local list = mists.Platform:GetTalentTreeProviders()
    assert(#list == 0 or list[1].id == 'grid', 'Mists never gets the tree provider')

    local _, a, e = client(5, 1)
    e.TalentFrame_Update = nil
    assert(not a.Platform:HasTalentTreeProvider(), 'a client without Blizzard\'s frame code has no tree')
end)

test(
    'the tree is laid out by Blizzard for the chosen tab, with every talent selectable and the saved one marked',
    function()
        local f, a = client(5, 1)
        local window = open(f, { selection = { tree = 1, talent = 4 } })
        assert(window.mode == 'classic' and window.handle.spec == 1)
        local buttons = shown(f)
        assert(#buttons == 5, #buttons)

        for _, button in ipairs(buttons) do
            assert(button.desaturated == nil, button:GetName() .. ' stays grayed')
            assert(f.env[button:GetName() .. 'Rank'].visible and f.env[button:GetName() .. 'RankBorder'].visible)
            assert(button.chosen:IsShown() == (button:GetID() == 4), 'only the saved talent is marked')
        end

        local gold = f.env[buttons[4]:GetName() .. 'Slot'].color
        assert(gold[1] == 1 and gold[2] > 0.8 and gold[3] == 0)
        local plain = f.env[buttons[1]:GetName() .. 'Slot'].color
        assert(plain[1] == plain[2] and plain[2] == plain[3] and plain[1] < 1, 'unchosen talents have a plain frame')
        local _, _, _, left, top = buttons[3]:GetPoint()
        assert(left == 2 * 63 + 35 and top == -20)
        -- Blizzard grayed the line (the lower half of its sheet); the first half is used.
        local _, branchTop, _, branchBottom = f.env.RotationMasterClassicTalentTreeBranch1:GetTexCoord()
        assert(branchTop == 0 and branchBottom < 0.5 and branchBottom > 0.4)
        local _, arrowTop, _, arrowBottom = f.env.RotationMasterClassicTalentTreeArrow1:GetTexCoord()
        assert(arrowTop == 0 and arrowBottom == 0.5)
        assert(window.canvasHeight and window.canvasHeight >= 20 + 2 * 63 + 32, 'the window is as tall as the tree')
    end
)

test('left-click adds a rank, choosing the talent first; right-click removes one; Accept reports the choice', function()
    local f = client(5, 1)

    local window, picks = open(f, {
        selection = { tree = 1, talent = 4 },
        selectionName = 'Elemental Focus',
        rank = 1,
        operator = 'GREATERTHAN',
    })

    assert(window.pick.rank == 1 and window.pick.operator == 'GREATERTHAN', 'the saved comparison is shown')
    local buttons = shown(f)

    click(buttons[4])
    assert(window.pick.rank == 1, 'a one rank talent stops at its maximum')

    click(buttons[2])
    assert(window.pick.selection.talent == 2 and window.pick.rank == 1 and window.pick.name == 'Concussion')
    assert(buttons[2].chosen:IsShown() and not buttons[4].chosen:IsShown(), 'the earlier talent is cleared')

    click(buttons[2])
    click(buttons[2])
    assert(window.pick.rank == 3)
    click(buttons[2], 'RightButton')
    assert(window.pick.rank == 2)

    for _ = 1, 9 do
        click(buttons[2], 'RightButton')
    end

    assert(window.pick.rank == 0 and window.pick.selection.talent == 2, 'rank zero keeps the talent chosen')

    for _ = 1, 9 do
        click(buttons[2])
    end

    assert(window.pick.rank == 5, 'a talent stops at its maximum rank')
    click(buttons[1], 'RightButton')
    assert(window.pick.selection.talent == 2, 'a right click on another talent does nothing')

    -- Nothing is below rank zero or above a talent's last rank: those comparisons are off there.
    local buttons_ = window.operatorButtons
    assert(window.pick.rank == 5 and not buttons_.GREATERTHAN:IsEnabled() and buttons_.LESSTHAN:IsEnabled())
    window.pick.operator = 'GREATERTHAN'
    click(buttons[2], 'RightButton')
    assert(window.pick.rank == 4 and buttons_.GREATERTHAN:IsEnabled() and window.pick.operator == 'GREATERTHAN')

    for _ = 1, 4 do
        click(buttons[2], 'RightButton')
    end

    assert(window.pick.rank == 0 and not buttons_.LESSTHAN:IsEnabled() and buttons_.GREATERTHAN:IsEnabled())
    window.pick.operator = 'LESSTHAN'
    click(buttons[2])

    for _ = 1, 9 do
        click(buttons[2])
    end

    assert(window.pick.rank == 5 and window.pick.operator == 'LESSTHAN' and buttons_.LESSTHAN:IsEnabled())
    window.pick.operator = 'GREATERTHAN'
    click(buttons[2])
    assert(window.pick.operator == 'EQUALS', 'a comparison that is off at this rank falls back to equals')
    window.pick.operator = 'EQUALS'
    assert(#picks == 0, 'nothing is written until Accept')
    window.OnAccept()
    local pick = picks[1]
    assert(pick and pick.selection.tree == 1 and pick.selection.talent == 2 and pick.rank == 5)
    assert(pick.operator == 'EQUALS' and pick.name == 'Concussion' and pick.icon == 136202)
    assert(not window.frame:IsShown(), 'accepting closes the window')

    window, picks = open(f, { selection = { tree = 1, talent = 4 } })
    assert(window.pick.operator == 'EQUALS', 'the comparison starts at equals')
    window.frame:Hide()
    assert(#picks == 0, 'closing without Accept writes nothing')
end)

test('another tab loads that tree and a pick on it names the tab', function()
    local f = client(5, 1)
    local window, picks = open(f, { selection = { tree = 1, talent = 1 } })
    window.OnSpec(2)
    local buttons = shown(f)
    assert(#buttons == 1 and window.handle.spec == 2)
    assert(not buttons[1].chosen:IsShown(), 'the saved talent belongs to tree 1')
    click(buttons[1])
    window.OnAccept()
    assert(picks[1].selection.tree == 2 and picks[1].selection.talent == 1)
end)

test('the tooltip is the game\'s own talent tooltip, and closing hides the tree and drops the handlers', function()
    local f = client(5, 1)
    local window = open(f)
    local button = shown(f)[1]
    button.scripts.OnEnter(button)
    assert(f.tip.talent[1] == 101 and f.tip.talent[2] == false and f.tip.talent[3] == false and f.tip.shown)
    window.frame:Hide()
    assert(button.scripts.OnClick == nil and button.scripts.OnEnter == nil)
    assert(not f.tip.shown, 'the tooltip does not outlive the window')
end)

test('a failing Blizzard update leaves the window with the reason and no tree', function()
    local f, _, e = client(5, 1)

    e.TalentFrame_Update = function()
        error('boom')
    end

    local window = open(f)
    assert(window.handle == nil and window.failure == 'talent-window-unavailable')
end)

test('on Mists, Blizzard\'s rows are laid out, every talent is selectable and a click names the slot', function()
    local f, a = mistsClient()
    local list = a.Platform:GetTalentTreeProviders()
    assert(#list == 1 and list[1].id == 'grid')
    local picks = {}

    local window = a:OpenTalentTree({
        owner = {},
        selection = { slot = 4 },
        selectionName = 'Talent 4',
        ranked = false,
        onAccept = function(pick)
            picks[#picks + 1] = pick
        end,
    })

    assert(window.mode == 'grid' and window.handle and window.canvasHeight >= 5 * 58 + 50)
    local buttons = f.made.mists
    assert(#buttons == 18)

    for index, button in ipairs(buttons) do
        assert(button.icon.desaturated == false, 'slot ' .. index .. ' stays gray')
        assert(button.highlight.alpha == 1 and not button.learnSelection:IsShown())
        assert(button.knownSelection:IsShown() == (index == 4), 'only the saved slot is marked')
    end

    buttons[5].scripts.OnClick(buttons[5], 'LeftButton')

    assert(window.pick.selection.slot == 5)

    window.OnAccept()
    assert(#picks == 1 and picks[1].selection.slot == 5 and picks[1].name == 'Talent 5' and picks[1].icon == 5005)
    assert(not window.frame:IsShown())

    window = a:OpenTalentTree({
        owner = {},
        selection = { slot = 4 },
        selectionName = 'Talent 4',
        ranked = false,
        onAccept = function(pick)
            picks[#picks + 1] = pick
        end,
    })

    assert(buttons[4].scripts.OnEvent == nil and buttons[4].scripts.OnDragStart == nil)
    buttons[4].scripts.OnEnter(buttons[4])
    assert(f.tip.talent[1] == 1004 and f.tip.talent[2] == false)
    buttons[4].scripts.OnClick(buttons[4], 'RightButton')
    assert(window.pick.selection == nil, 'a right click clears the choice')
end)

finish()
