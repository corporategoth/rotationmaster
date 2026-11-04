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

local function open(f, request)
    request = request or {}
    local picks = {}

    local window = f.addon:OpenTalentTree({
        owner = {},
        spec = request.spec or 1,
        specs = { { id = 1, name = 'Elemental' }, { id = 2, name = 'Enhancement' }, { id = 3, name = 'Restoration' } },
        specLabel = 'Talent Tree',
        selection = request.selection,
        onSelect = function(pick)
            picks[#picks + 1] = pick
        end,
    })

    return window, picks
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

test('the classic provider serves Era, TBC and Wrath, and no other client', function()
    for _, case in ipairs({ { 2, 1 }, { 5, 1 }, { 11, 2 } }) do
        local f, a = client(case[1], case[2])
        local list = a.Platform:GetTalentTreeProviders()
        assert(#list == 1 and list[1].id == 'classic', 'product ' .. case[1])
        assert(a.Platform:HasTalentTreeProvider())
    end

    for _, case in ipairs({ { 14, 3 }, { 19, 4 } }) do
        local _, a = client(case[1], case[2])
        assert(#a.Platform:GetTalentTreeProviders() == 0, 'no classic tree on product ' .. case[1])
    end

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
        local green = f.env[buttons[1]:GetName() .. 'Slot'].color
        assert(green[2] == 1 and green[1] < 0.2)
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

test('a click chooses the talent and closes the window; clicking the saved talent again clears it', function()
    local f = client(5, 1)
    local window, picks = open(f, { selection = { tree = 1, talent = 4 } })
    local buttons = shown(f)
    buttons[2].talentButton_OnClick(buttons[2])
    assert(#picks == 1 and picks[1].tree == 1 and picks[1].talent == 2 and picks[1].name == 'Concussion')
    assert(picks[1].icon == 136202)
    assert(not window.frame:IsShown(), 'choosing closes the window')

    window, picks = open(f, { selection = { tree = 1, talent = 4 } })
    shown(f)[4].talentButton_OnClick(shown(f)[4])
    assert(#picks == 1 and picks[1] == false)
end)

test('another tab loads that tree and a pick on it names the tab', function()
    local f = client(5, 1)
    local window, picks = open(f, { selection = { tree = 1, talent = 1 } })
    window.OnSpec(2)
    local buttons = shown(f)
    assert(#buttons == 1 and window.handle.spec == 2)
    assert(not buttons[1].chosen:IsShown(), 'the saved talent belongs to tree 1')
    buttons[1].talentButton_OnClick(buttons[1])
    assert(picks[1].tree == 2 and picks[1].talent == 1)
end)

test('the tooltip is the game\'s own talent tooltip, and closing hides the tree and drops the handlers', function()
    local f = client(5, 1)
    local window = open(f)
    local button = shown(f)[1]
    button.talentButton_OnEnter(button)
    assert(f.tip.talent[1] == 101 and f.tip.talent[2] == false and f.tip.talent[3] == false and f.tip.shown)
    window.frame:Hide()
    assert(button.talentButton_OnClick == nil and button.talentButton_OnEnter == nil)
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

finish()
