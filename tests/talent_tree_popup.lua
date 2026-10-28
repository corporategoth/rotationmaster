-- "Show talent tree": the provider registry, the loadout string Blizzard's talent
-- window is driven with, the two providers (Blizzard's window in view mode and
-- the drawn tree), the button beside the Talent list and its sync with the
-- condition. NO REAL CLIENT WAS AVAILABLE: Blizzard's window is modeled in
-- tests/fixtures/blizzard_talent_window.lua from the pinned Blizzard source and
-- reads our loadout strings with its own decoder.
local F = dofile('tests/fixtures/addon.lua')
local Tree = dofile('tests/fixtures/retail_traits.lua')
local Window = dofile('tests/fixtures/blizzard_talent_window.lua')
local test, finish = F.suite()
local ARCANE, FIRE, FROST = Tree.SPECS.Arcane, Tree.SPECS.Fire, Tree.SPECS.Frost

local LOAD = {
    'Platform/spells.lua', 'Platform/talents.lua', 'Platform/talent_tree.lua', 'Core/build_context.lua',
    'Core/conditions.lua', 'Conditions/common.lua', 'Conditions/character.lua', 'UI/talent_popup.lua',
    'Conditions/talent.lua'
}

-- options: product (default Retail), ui=false (no popup code), blizzard=false (no talent window),
-- window = options for the window model, tooltip=false
local function client(state, options)
    options = options or {}
    local f = F.new(options.product or 1, 12, 'MAGE')
    local e = f.env
    local native = e.CreateFrame
    local atlases = {}

    e.C_Texture = {
        GetAtlasInfo = function(name)
            if options.atlases and (name:find('^talents%-node%-') or name:find('^talents%-background%-')) then
                return { width = 40, height = 40 }
            end
        end,
    }

    e.CreateFrame = function(...)
        local frame = native(...)
        local createTexture = frame.CreateTexture

        local function decorate(texture)
            function texture:SetAtlas(name)
                self.atlas = name
            end

            function texture:AddMaskTexture(mask)
                self.maskedBy = mask
            end

            function texture:RemoveMaskTexture()
                self.maskedBy = nil
            end

            return texture
        end

        function frame:CreateTexture(...)
            return decorate(createTexture(self, ...))
        end

        function frame:CreateMaskTexture()
            return decorate(createTexture(self))
        end

        f.frames = f.frames or {}
        f.frames[#f.frames + 1] = frame

        function frame:RegisterEvent(event)
            self.events = self.events or {}
            self.events[event] = true
        end

        function frame:UnregisterEvent(event)
            if self.events then
                self.events[event] = nil
            end
        end

        function frame:CreateLine()
            local line = { kind = 'Line' }

            function line:SetThickness(value)
                self.thickness = value
            end

            function line:SetColorTexture() end

            function line:SetStartPoint(...)
                self.start = { ... }
            end

            function line:SetEndPoint(...)
                self.finish = { ... }
            end

            function line:Show()
                self.visible = true
            end

            function line:Hide()
                self.visible = false
            end

            f.lines = f.lines or {}
            f.lines[#f.lines + 1] = line
            return line
        end

        return frame
    end

    e.UIParent = e.CreateFrame('Frame')
    local tip = { owner = nil, lines = {} }

    function tip:SetOwner(owner)
        self.owner = owner
        self.lines = {}
        self.spell = nil
    end

    function tip:IsOwned(owner)
        return self.owner == owner
    end

    function tip:SetSpellByID(spell)
        self.spell = spell
    end

    function tip:SetText(text)
        self.text = text
    end

    function tip:AddLine(text)
        self.lines[#self.lines + 1] = text
    end

    function tip:Show()
        self.shown = true
    end

    function tip:Hide()
        self.shown = false
        self.owner = nil
    end

    e.GameTooltip = tip

    if options.provider ~= false then
        f.addon.db.global.talent_popup_provider = options.provider or 'blizzard'
    end

    local model = Tree.install(e, state)
    local window

    if options.blizzard ~= false then
        window = Window.install(e, Tree, state, options.window)
    end

    for _, path in ipairs(LOAD) do
        if options.ui ~= false or path ~= 'UI/talent_popup.lua' then
            f.load(path)
        end
    end

    f.addon.definitions = f.addon.conditionDefinitions or f.addon.definitions
    f.tip, f.window, f.model = tip, window, model
    return f, f.addon, e
end

local function names(list)
    local out = {}

    for _, v in ipairs(list) do
        out[#out + 1] = v.id
    end

    return out
end

local function treeOrder()
    local list = {}

    for _, node in ipairs(Tree.nodes) do
        list[#list + 1] = node.id
    end

    table.sort(list)
    return list
end

test(
    'providers are chosen per client: Retail and Forever get Blizzard\'s window then the drawn tree, the classic clients none yet',
    function()
        local f, a = client({ spec = FIRE })
        local p = a.Platform

        assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'blizzard,drawn', table.concat(
            names(p:GetTalentTreeProviders()),
            ','
        ))

        assert(p:HasTalentTreeProvider())
        f = client({ spec = FIRE }, { product = 18 })
        p = f.addon.Platform
        assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'blizzard,drawn')

        for _, product in ipairs({ 2, 5, 19 }) do
            f = client({ spec = FIRE }, { product = product })
            p = f.addon.Platform

            assert(
                not p:HasTalentTreeProvider() and #p:GetTalentTreeProviders() == 0,
                'a provider answered for product ' .. product
            )
        end

        -- Without Blizzard's window the drawn tree still serves; without the trait API nothing does.
        f = client({ spec = FIRE }, { blizzard = false })
        p = f.addon.Platform
        assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'drawn')
        f.env.C_Traits.GetNodeInfo = nil
        assert(not p:HasTalentTreeProvider())
    end
)

test(
    'the trait view lists the tree in Blizzard\'s node order with positions, edges and the hero trees the specialization can choose',
    function()
        local f, a = client({ spec = FIRE })
        local p = a.Platform
        local view = assert(p:GetTraitView(FIRE))
        assert(view.source == 'active' and view.spec == FIRE)
        local order = treeOrder()
        assert(#view.order == #order)

        for index, id in ipairs(view.order) do
            assert(view.nodes[id] and view.index[id] == index)
        end

        assert(view.nodes[2001].edges[1] == 2002 and view.nodes[2001].edges[2] == 2003 and view.nodes[2002].kind == 2)

        assert(
            #view.heroes == 2
                and view.heroes[1].id == 41
                and view.heroes[1].name == 'Frostfire'
                and view.heroes[2].id == 43
        )

        assert(view.heroes[1].node == 2400 and view.heroes[1].position == 1 and view.heroes[2].position == 3)
        -- Another specialization is read from the view loadout, with its own heroes; never in combat.
        local frost = assert(p:GetTraitView(FROST))
        assert(frost.source == 'view' and frost.spec == FROST and frost.heroes[2].id == 42)
        f.model.combat = true
        local none, why = p:GetTraitView(ARCANE)
        assert(none == nil and why == 'in-combat', tostring(why))
    end
)

test(
    'the loadout string is read by Blizzard\'s own decoder as the header and the picked nodes, in tree order',
    function()
        local f, a = client({ spec = FIRE })
        local p = a.Platform
        local view = assert(p:GetTraitView(FROST))

        local text = assert(p:EncodeTraitView(view, {
            { node = 2400, position = 2 },
            { node = 2002, position = 2 },
            { node = 2301, position = 1 },
            { node = 2004, position = 1 },
        }))

        assert(text:match('^[A-Za-z0-9+/]+$'))
        local decoded = assert(Window.decode(text, #view.order))
        assert(decoded.version == 2 and decoded.spec == FROST)

        for _, byte in ipairs(decoded.hash) do
            assert(byte == 0, 'the tree hash is zero-filled')
        end

        local picked = 0

        for position, record in pairs(decoded.selected) do
            picked = picked + 1
            local id = view.order[position]
            assert(record.purchased and not record.partial)

            if id == 2400 then
                assert(record.choice and record.entry == 2)
            elseif id == 2002 then
                assert(record.choice and record.entry == 2)
            elseif id == 2301 or id == 2004 then
                assert(not record.choice and record.entry == nil)
            else
                error('unexpected node ' .. id)
            end
        end

        assert(picked == 4)
        -- The empty tree is still a valid header.
        local bare = assert(p:EncodeTraitView(view, {}))
        local decodedBare = assert(Window.decode(bare, #view.order))
        assert(next(decodedBare.selected) == nil)
        -- Anything that cannot be written is refused, not guessed.
        local bad, why = p:EncodeTraitView(view, { { node = 999999 } })
        assert(bad == nil and why == 'talent-node-unavailable')
        bad, why = p:EncodeTraitView(view, { { node = 2002 } })
        assert(bad == nil and why == 'talent-entry-unavailable', 'a choice node needs its entry')
        bad, why = p:EncodeTraitView(view, { { node = 2002, position = 3 } })
        assert(bad == nil and why == 'talent-entry-unavailable')
        f.env.C_Traits.GetLoadoutSerializationVersion = nil
        bad, why = p:EncodeTraitView(view, {})
        assert(bad == nil and why == 'missing-api')
    end
)

test(
    'a saved selection is found in the view, by node and entry or by its spell when the node was renumbered',
    function()
        local f, a = client({ spec = FIRE })
        local p = a.Platform
        local view = assert(p:GetTraitView(FIRE))
        local found = p:FindTraitViewSelection(view, { node = 2203, spell = 257541 })
        assert(found.node == 2203 and found.entry == nil and found.position == 1)
        found = p:FindTraitViewSelection(view, { node = 2204, entry = Tree.entryID({ id = 2204 }, 2), spell = 155148 })
        assert(found.node == 2204 and found.position == 2 and found.entry == Tree.entryID({ id = 2204 }, 2))
        found = p:FindTraitViewSelection(view, { node = 2411, spell = 431044 })
        assert(found.hero == 41)
        found = p:FindTraitViewSelection(view, { node = 777777, spell = 190319 })
        assert(found and found.node == 2202, 'found again by spell')
        found = p:FindTraitViewSelection(view, { node = 2203, spell = 190319 })
        assert(found and found.node == 2202, 'the node holds another talent now')
        assert(p:FindTraitViewSelection(view, { node = 777777 }) == nil and p:FindTraitViewSelection(view, nil) == nil)
    end
)

local function open(a, request)
    request.onSelect = request.onSelect or function(selection)
        request.picked = selection
    end

    local d = a:OpenTalentTree(request)
    return d
end

test(
    'Blizzard\'s window is opened in view mode on the wanted specialization and hero tree, with a ring on the selected talent',
    function()
        local state = { spec = FIRE }
        local f, a, e = client(state)

        local request = {
            spec = FROST,
            hero = 42,
            selection = { node = 2301, spell = 84714 },
            selectionName = 'Frozen Orb',
            specs = { { id = ARCANE, name = 'Arcane' }, { id = FIRE, name = 'Fire' }, { id = FROST, name = 'Frost' } },
        }

        local d = open(a, request)
        local w = f.window

        assert(
            d.mode == 'blizzard' and w.frame.inspecting and w.frame.shown and w.frame.tab == 2,
            'the window is in view mode on the talents tab'
        )

        assert(state.viewSpec == FROST and state.viewLevel >= 80)
        local decoded = Window.decode(w.lastString, #treeOrder())
        assert(decoded.spec == FROST)
        local picked = {}

        for position, record in pairs(decoded.selected) do
            picked[treeOrder()[position]] = record
        end

        assert(
            picked[2400] and picked[2400].entry == 2,
            'the Spellslinger hero tree is chosen: ' .. tostring(picked[2400] and picked[2400].entry)
        )

        assert(
            picked[2301] and picked[2301].purchased and not picked[2301].choice,
            'the selected talent is in the loadout'
        )

        assert(w.frame.strata == 'FULLSCREEN_DIALOG', 'above the RM windows')
        assert(d.frame:GetFrameLevel() > w.frame:GetFrameLevel(), 'the control strip is beneath Blizzard\'s window')
        assert(w.buttons[2301].glowing == true, 'Blizzard\'s own glow marks the selected talent too')
        local ring = a.talentTreeRing

        assert(
            ring and ring:IsShown() and ring.points[1][2] == w.buttons[2301],
            'the ring sits on the selected talent\'s button'
        )

        assert(d.handle.spec == FROST and d.handle.hero == 42 and #d.handle.heroes == 2)

        assert(
            d.status.text:find('Click a talent', 1, true) and d.status.text:find('Frozen Orb', 1, true),
            d.status.text
        )

        assert(w.registry:Count() == 3, 'click, button and close callbacks registered')
        -- Closing puts Blizzard's window back.
        local watcher

        for _, frame in ipairs(f.frames) do
            if frame.events and frame.events.PLAYER_REGEN_DISABLED then
                watcher = frame
            end
        end

        assert(watcher, 'combat ends the session: the event is watched while it is open')
        d.frame:Hide()

        assert(
            w.buttons[2301].glowing == false and not watcher.events.PLAYER_REGEN_DISABLED,
            'the glow is cleared and the event no longer watched'
        )

        assert(not w.frame.inspecting and not w.frame.shown and w.frame.strata == 'MEDIUM', 'closed and restored')
        assert(w.registry:Count() == 0, 'every callback is removed')
        assert(request.picked == nil)
    end
)

test(
    'picking a talent in Blizzard\'s window takes it, closes the window and gives Blizzard\'s window back as it was',
    function()
        local state = { spec = FIRE }
        local f, a = client(state, { window = { shown = true, tab = 3 } })
        local request = { spec = FIRE, selection = { node = 2202, spell = 190319 } }
        local d = open(a, request)
        local w = f.window
        assert(d.mode == 'blizzard' and w.frame.inspecting and w.frame.shown)
        -- A talent button, a choice entry button, the hero node and a right click.
        w.registry:TriggerEvent('TalentButton.OnClick', w.buttons[2203], 'RightButton')
        assert(request.picked == nil and d.frame:IsShown(), 'only a left click picks')
        w.registry:TriggerEvent('TalentButton.OnClick', w.buttons[2400], 'LeftButton')
        assert(request.picked == nil, 'the hero selection node is not a talent')
        w.registry:TriggerEvent('TalentButton.OnClick', w.buttons[2002], 'LeftButton')
        assert(request.picked == nil, 'a choice node is picked through one of its entries')
        w.registry:TriggerEvent('TalentButton.OnClick', w.entryButton(2204, 2), 'LeftButton')
        local picked = request.picked

        assert(
            picked
                and picked.node == 2204
                and picked.entry == Tree.entryID({ id = 2204 }, 2)
                and picked.spell == 155148,
            'the choice entry is picked'
        )

        assert(
            not d.frame:IsShown() and not w.frame.inspecting and w.frame.shown and w.frame.tab == 3,
            'Blizzard\'s window stays open on its old tab, out of view mode'
        )

        assert(w.registry:Count() == 0)
        -- A plain talent.
        request = { spec = FIRE }
        d = open(a, request)
        w.registry:TriggerEvent('TalentButton.OnClick', w.buttons[2203], 'LeftButton')

        assert(
            request.picked.node == 2203
                and request.picked.entry == nil
                and request.picked.spell == 257541
                and request.picked.name == 'Phoenix Flames'
        )

        -- Closing the picker twice or clicking afterwards does nothing more.
        w.registry:TriggerEvent('TalentButton.OnClick', w.buttons[2203], 'LeftButton')
    end
)

test('closing Blizzard\'s window by hand (Escape) ends the session without a pick', function()
    local f, a = client({ spec = FIRE })
    local closed = 0

    local request = {
        spec = FIRE,
        onClose = function()
            closed = closed + 1
        end,
    }

    local d = open(a, request)
    local w = f.window
    assert(d.mode == 'blizzard')
    w.registry:TriggerEvent('PlayerSpellsFrame.CloseFrame')
    assert(not d.frame:IsShown() and closed == 1 and request.picked == nil)
    assert(w.registry:Count() == 0 and not w.frame.inspecting)
end)

test('entering combat while Blizzard\'s window is open closes the session', function()
    local f, a = client({ spec = FIRE })
    local d = open(a, { spec = FIRE })
    assert(d.mode == 'blizzard')
    local watcher

    for _, frame in ipairs(f.frames) do
        if frame.events and frame.events.PLAYER_REGEN_DISABLED then
            watcher = frame
        end
    end

    watcher.scripts.OnEvent(watcher, 'PLAYER_REGEN_DISABLED')

    assert(
        not d.frame:IsShown()
            and not f.window.frame.inspecting
            and not f.window.frame.shown
            and f.window.registry:Count() == 0
    )
end)

test(
    'a loadout the client refuses falls back to the hero choice alone, then to the bare tree, then to the drawn tree',
    function()
        local f, a = client({ spec = FIRE }, {
            window = {
                refuse = function(decoded)
                    for _, record in pairs(decoded.selected) do
                        if record.entry == nil then
                            return true
                        end
                    end

                    return false
                end,
            },
        })

        local d = open(a, { spec = FIRE, selection = { node = 2203, spell = 257541 } })

        assert(
            d.mode == 'blizzard' and f.window.SetInspectString == 2,
            'the hero choice alone worked on the second try: ' .. tostring(f.window.SetInspectString)
        )

        d.frame:Hide()
        f, a = client({ spec = FIRE }, { window = { refuse = function() return true end } })
        d = open(a, { spec = FIRE, selection = { node = 2203, spell = 257541 } })

        assert(
            d.mode == 'drawn' and not f.window.frame.inspecting and f.window.SetInspectString == 3,
            'every string refused: the drawn tree serves'
        )

        assert(
            f.window.registry:Count() == 0 and not f.window.frame.shown,
            'nothing of Blizzard\'s window is left changed'
        )
    end
)

test(
    'Blizzard\'s window is left alone in combat, while someone inspects, or with staged changes: the drawn tree or a reason serves',
    function()
        local f, a = client({ spec = FIRE }, { window = { inspecting = true } })
        local d = open(a, { spec = FIRE })

        assert(
            d.mode == 'drawn' and f.window.SetInspectString == nil and f.window.frame.inspecting,
            'an inspected build is not disturbed'
        )

        d.frame:Hide()
        assert(f.window.frame.inspecting, 'still the inspector\'s')
        f, a = client({ spec = FIRE }, { window = { shown = true, changes = true } })
        d = open(a, { spec = FIRE })
        assert(d.mode == 'drawn' and f.window.SetInspectString == nil)
        local state = { spec = FIRE, combat = true }
        f, a = client(state)
        d = open(a, { spec = FIRE })

        assert(
            d.handle == nil and d.mode == nil and f.window.SetInspectString == nil and f.window.registry:Count() == 0
        )

        assert(d.status.text:find('during combat', 1, true), d.status.text)

        assert(
            (state.calls.GetNodeInfo or 0) == 0 and (state.calls.InitializeViewLoadout or 0) == 0,
            'no talent API is read in combat'
        )

        -- A client without the window, or without EventRegistry, draws the tree.
        f, a = client({ spec = FIRE }, { blizzard = false })
        d = open(a, { spec = FIRE })
        assert(d.mode == 'drawn')
        f, a = client({ spec = FIRE })
        f.env.EventRegistry = nil
        d = open(a, { spec = FIRE })
        assert(d.mode == 'drawn' and f.window.SetInspectString == nil)
    end
)

test(
    'the drawn tree lays the talents out at their positions, highlights the saved one, links the edges and keeps its frames',
    function()
        local state = { spec = FIRE, scale = 600 }
        local f, a = client(state, { blizzard = false })

        local request = {
            spec = FIRE,
            hero = 43,
            selection = { node = 2204, entry = Tree.entryID({ id = 2204 }, 2), spell = 155148 },
        }

        local d = open(a, request)
        assert(d.mode == 'drawn' and d.canvas:IsShown() and d.handle.hero == 43)
        local visible = {}

        for _, slot in ipairs(d.slots) do
            if slot:IsShown() then
                visible[#visible + 1] = slot
            end
        end

        local byNode, selected = {}, {}

        for _, slot in ipairs(visible) do
            byNode[slot.data.node] = (byNode[slot.data.node] or 0) + 1

            if slot.selected then
                selected[#selected + 1] = slot
            end
        end

        assert(byNode[2204] == 2 and byNode[2002] == 2, 'a choice node is drawn as two entries')
        assert(byNode[2203] == 1 and byNode[2431] == 1 and byNode[2411] == nil, 'only the chosen hero tree is drawn')

        assert(
            byNode[2301] == nil and byNode[2101] == nil and byNode[2400] == nil,
            'other specializations and the hero selection node are not drawn'
        )

        assert(
            #selected == 1 and selected[1].data.node == 2204 and selected[1].data.entry == Tree.entryID({
                id = 2204,
            }, 2),
            'only the saved choice entry is highlighted'
        )

        local live = 0

        for _, line in ipairs(f.lines or {}) do
            if line.visible then
                live = live + 1
            end
        end

        assert(live >= 3, 'edges are linked: ' .. live)
        -- The tree fits its canvas.
        assert(d.content:GetScale() < 1 and d.content:GetScale() >= .35)
        -- Tooltips are the spell's own.
        local slot

        for _, candidate in ipairs(visible) do
            if candidate.data.node == 2203 then
                slot = candidate
            end
        end

        slot.scripts.OnEnter(slot)
        assert(f.tip.spell == 257541 and f.tip.lines[1]:find('2', 1, true), 'spell tooltip with the ranks')
        slot.scripts.OnLeave(slot)
        assert(f.tip.shown == false)
        -- Choosing a hero tree redraws; the frames are reused.
        local before = #d.slots
        d.OnHero(41)
        local heroNodes = {}

        for _, candidate in ipairs(d.slots) do
            if candidate:IsShown() then
                heroNodes[candidate.data.node] = true
            end
        end

        assert(heroNodes[2411] and not heroNodes[2431] and #d.slots >= before)
        d.frame:Hide()
        d = open(a, request)
        assert(#d.slots == before, 'reopening reuses the frames: ' .. before .. ' ' .. #d.slots)

        -- Clicking a talent picks it and closes.
        for _, candidate in ipairs(d.slots) do
            if candidate:IsShown() and candidate.data.node == 2203 then
                slot = candidate
            end
        end

        slot.scripts.OnClick(slot)
        assert(request.picked.node == 2203 and request.picked.spell == 257541 and not d.frame:IsShown())

        -- Closed: nothing is shown or registered.
        for _, candidate in ipairs(d.slots) do
            assert(not candidate:IsShown())
        end
    end
)

test('the specialization and hero switchers reload the tree and tell the editor', function()
    local state = { spec = FIRE }
    local f, a = client(state)
    local told

    local request = {
        spec = FIRE,
        specs = { { id = ARCANE, name = 'Arcane' }, { id = FIRE, name = 'Fire' }, { id = FROST, name = 'Frost' } },
        onSpec = function(spec)
            told = spec
        end,
    }

    local d = open(a, request)
    assert(d.specButtons[2].selected and not d.specButtons[3].selected and d.specButtons[3]:IsShown())
    d.OnSpec(FROST)
    assert(told == FROST and state.viewSpec == FROST and d.handle.spec == FROST and d.specButtons[3].selected)
    assert(Window.decode(f.window.lastString, #treeOrder()).spec == FROST)
    assert(#d.heroButtons >= 2 and d.heroButtons[2]:IsShown())
    d.OnHero(42)
    local decoded = Window.decode(f.window.lastString, #treeOrder())
    local hero

    for position, record in pairs(decoded.selected) do
        if treeOrder()[position] == 2400 then
            hero = record.entry
        end
    end

    assert(hero == 2, 'the second hero tree of Frost is Spellslinger: ' .. tostring(hero))
    -- Combat while the window is open: the switch says why and keeps the tree.
    state.combat = true
    d.OnSpec(ARCANE)
    assert(d.status.text:find('during combat', 1, true), d.status.text)
    d.frame:Hide()
end)

test('on Forever the loadout is the character\'s own: the specialization comes from Blizzard\'s PlayerUtil', function()
    local state = { spec = FIRE }
    local f, a, e = client(state, { product = 18 })
    e.PlayerUtil = { GetCurrentSpecID = function() return FIRE end }
    local d = open(a, {})
    assert(d.mode == 'blizzard', tostring(d.failure))
    assert(Window.decode(f.window.lastString, #treeOrder()).spec == FIRE)
    d.frame:Hide()
    e.PlayerUtil = nil
    d = open(a, {})
    assert(d.mode == 'drawn', 'no specialization to name: the drawn tree')
    d.frame:Hide()
end)

-- The condition editor ---------------------------------------------------------
local function child(parent, label)
    for _, w in ipairs(parent.children) do
        if (w.caption and w.caption:GetText() or w.label) == label then
            return w
        end

        if w.children then
            local nested = child(w, label)

            if nested then
                return nested
            end
        end
    end
end

local function editor(f, value, spec)
    local parent, top = f.widget('parent'), f.widget('top')
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated condition' end })
    parent:SetUserData('top', top)
    f.addon.definitions.TALENT.widget(parent, spec or 0, value)
    return parent, top
end

local function treeButton(parent)
    for _, w in ipairs(parent.children) do
        if w.layout == 'RM-IconRows' then
            local last = w.children[#w.children]

            if last and last.text == 'Show talent tree' then
                return last, w
            end
        end
    end
end

test(
    'the button sits beside the Talent list on Retail and Forever and is absent where no provider can show a tree',
    function()
        local f = client({ spec = FIRE })
        local parent = editor(f, {}, FIRE)
        local button, box = treeButton(parent)
        assert(button and box.children[3] == child(parent, 'Talent'), 'beside the list')

        assert(
            button.frame.tooltip:find('talent tree', 1, true)
                and button:GetUserData('side') == true
                and button.disabled == false
        )

        f = client({ spec = FIRE }, { product = 18 })
        parent = editor(f, {}, FIRE)
        assert(treeButton(parent))
        f = client({ spec = FIRE }, { product = 2 })
        parent = editor(f, {}, FIRE)
        assert(not treeButton(parent), 'no provider on Classic Era')
        f = client({ spec = FIRE }, { ui = false })
        parent = editor(f, {}, FIRE)
        assert(not treeButton(parent) and child(parent, 'Talent'), 'without the popup code the editor is unchanged')
    end
)

test(
    'opening from the button shows the rotation\'s specialization with the saved talent; picking writes the same fields as the list and keeps both in sync',
    function()
        local state = { spec = FIRE }
        local f, a = client(state)
        local value = { layout = 'traits', node = 2203, spell = 257541, operator = 'EQUALS', value = 2 }
        local parent, top = editor(f, value, FROST)
        local button = treeButton(parent)
        button:Fire('OnClick')
        local d = a.talentTreeWindow

        assert(
            d.frame:IsShown()
                and d.request.spec == FROST
                and d.request.selection.node == 2203
                and d.request.specs
                and #d.request.specs == 3
        )

        assert(f.window.frame.inspecting and Window.decode(f.window.lastString, #treeOrder()).spec == FROST)
        -- The tree's specialization switch moves the list too.
        d.OnSpec(FIRE)
        local specs = child(parent, 'Specialization')
        assert(specs.value == FIRE)
        local talents = child(parent, 'Talent')
        talents.configure()
        local combustion

        for index, entry in ipairs(talents.list) do
            if entry.text == 'Combustion' then
                combustion = index
            end
        end

        assert(combustion, 'the list follows the tree\'s specialization')
        -- Picking a choice entry in the tree.
        f.window.registry:TriggerEvent('TalentButton.OnClick', f.window.entryButton(2204, 2), 'LeftButton')
        assert(not d.frame:IsShown())

        assert(
            value.layout == 'traits'
                and value.node == 2204
                and value.entry == Tree.entryID({ id = 2204 }, 2)
                and value.spell == 155148
                and value.tree == nil
        )

        assert(value.operator == 'EQUALS' and value.value == 2, 'an existing comparison is kept')
        assert(top.statusText == 'Updated condition')

        assert(
            child(parent, 'Talent Node ID').text == '2204' and child(parent, 'Choice Entry ID').text == tostring(
                Tree.entryID({ id = 2204 }, 2)
            )
        )

        talents.configure()
        assert(talents.list[talents.value].text:find('Kindling', 1, true), 'the list shows the picked talent')
        -- A first pick adopts the default comparison, like the list does.
        value = {}
        parent, top = editor(f, value, FIRE)
        treeButton(parent):Fire('OnClick')
        f.window.registry:TriggerEvent('TalentButton.OnClick', f.window.buttons[2202], 'LeftButton')

        assert(
            value.node == 2202
                and value.spell == 190319
                and value.operator == 'GREATERTHANOREQUALS'
                and value.value == 1
                and a.definitions.TALENT.valid(0, value)
        )
    end
)

test(
    'changing the talent in the list or the node box while the tree is open moves the tree\'s highlight; another editor\'s tree is not touched',
    function()
        local state = { spec = FIRE, scale = 600 }
        local f, a = client(state, { window = { shown = false }, blizzard = false })
        local value = { layout = 'traits', node = 2203, spell = 257541, operator = 'EQUALS', value = 1 }
        local parent = editor(f, value, FIRE)
        treeButton(parent):Fire('OnClick')
        local d = a.talentTreeWindow

        local function selected()
            for _, slot in ipairs(d.slots) do
                if slot:IsShown() and slot.selected then
                    return slot.data.node
                end
            end
        end

        assert(selected() == 2203)
        local talents = child(parent, 'Talent')
        talents.configure()
        local combustion

        for index, entry in ipairs(talents.list) do
            if entry.text == 'Combustion' then
                combustion = index
            end
        end

        talents:Fire('OnValueChanged', combustion)
        assert(value.node == 2202 and selected() == 2202, 'the list moved the highlight')
        child(parent, 'Talent Node ID'):Fire('OnEnterPressed', '2201')
        assert(selected() == 2201, 'a typed node moved it too')
        -- Another editor's refresh does not reach this tree.
        local other = {}
        a:RefreshTalentTree(other, { node = 2203, spell = 257541 }, 'Phoenix Flames')
        assert(selected() == 2201)
        a:CloseTalentTree(other)
        assert(d.frame:IsShown())
        -- Releasing the button (the editor closing) closes the tree.
        local button = treeButton(parent)
        a:ReleaseConditionWidget(button)
        assert(not d.frame:IsShown())
    end
)

test('nothing runs while the tree is closed: no OnUpdate of its own, no callbacks, no tooltip', function()
    local f, a = client({ spec = FIRE })
    local parent = editor(f, {}, FIRE)
    local button = treeButton(parent)
    local d = open(a, { spec = FIRE })
    d.frame:Hide()
    assert(f.window.registry:Count() == 0 and not f.tip.shown)
    -- The window's only script is the close hook; nothing polls.
    assert(d.frame.scripts.OnUpdate == nil and d.canvas.scripts.OnUpdate == nil)

    for _, slot in ipairs(d.slots) do
        assert(slot.scripts.OnUpdate == nil)
    end
end)

test('the default is the drawn tree: Blizzard\'s window is an opt-in setting and is never touched otherwise', function()
    local f, a = client({ spec = FIRE }, { provider = false })
    local p = a.Platform

    assert(
        table.concat(names(p:GetTalentTreeProviders()), ',') == 'drawn',
        'default chain: ' .. table.concat(names(p:GetTalentTreeProviders()), ',')
    )

    local d = open(a, { spec = FIRE, selection = { node = 2203, spell = 257541 } })

    assert(
        d.mode == 'drawn'
            and f.window.SetInspectString == nil
            and f.window.registry:Count() == 0
            and not f.window.frame.shown
    )

    d.frame:Hide()
    assert(f.window.SetInspectString == nil and (f.window.HideUIPanel or 0) == 0 and (f.window.ShowUIPanel or 0) == 0)
    f.addon.db.global.talent_popup_provider = 'drawn'
    assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'drawn')
    f.addon.db.global.talent_popup_provider = 'nonsense'
    assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'drawn')
    f.addon.db.global.talent_popup_provider = 'blizzard'
    assert(table.concat(names(p:GetTalentTreeProviders()), ',') == 'blizzard,drawn')
end)

test(
    'the drawn tree is Blizzard\'s look with every talent choosable: green frames, the chosen one gold, no locked greying, pane titles',
    function()
        local state = { spec = FIRE, scale = 600 }
        local f, a, e = client(state, { blizzard = false, atlases = true, provider = false })

        e.ClassTalentUtil = {
            GetVisualsForSpecID = function(spec)
                if spec == FIRE then
                    return { background = 'talents-background-mage-fire' }
                end
            end,
        }

        e.UnitClass = function() return 'Mage', 'MAGE', 8 end

        local request = {
            spec = FIRE,
            hero = 41,
            selection = { node = 2203, spell = 257541 },
            specs = { { id = ARCANE, name = 'Arcane' }, { id = FIRE, name = 'Fire' }, { id = FROST, name = 'Frost' } },
        }

        local d = open(a, request)
        assert(d.mode == 'drawn')
        local selected, others = 0, 0

        for _, slot in ipairs(d.slots) do
            if slot:IsShown() then
                assert(slot.art.atlas and slot.art.atlas:find('^talents%-node%-'), 'every node wears Blizzard\'s frame')

                if slot.selected then
                    selected = selected + 1

                    assert(
                        slot.art.atlas:find('%-yellow$') and slot.glow:IsShown(),
                        'the chosen talent is gold with a glow: ' .. slot.art.atlas
                    )
                else
                    others = others + 1

                    assert(
                        slot.art.atlas:find('%-green$'),
                        'the others read as choosable, never grey or locked: ' .. slot.art.atlas
                    )

                    assert(not slot.art.atlas:find('gray') and not slot.art.atlas:find('locked'))
                end
            end
        end

        assert(selected == 1 and others >= 8)
        -- Hovering adds the green glow; leaving removes it.
        local hovered

        for _, slot in ipairs(d.slots) do
            if slot:IsShown() and not slot.selected then
                hovered = slot
                break
            end
        end

        hovered.scripts.OnEnter(hovered)
        assert(hovered.hover:IsShown() and hovered.hover.atlas:find('greenglow'))
        hovered.scripts.OnLeave(hovered)
        assert(not hovered.hover:IsShown())
        -- Circles for passives are masked; squares are not.
        local circle, square

        for _, slot in ipairs(d.slots) do
            if slot:IsShown() then
                if slot.shape == 'circle' then
                    circle = slot
                else
                    square = slot
                end
            end
        end

        assert(
            circle
                and circle.mask
                and circle.icon.maskedBy == circle.mask
                and circle.mask.atlas == 'talents-node-circle-mask'
        )

        -- Titles over the panes and the spec's backdrop.
        local titles = {}

        for _, text in ipairs(d.paneLabels) do
            if text:IsShown() then
                titles[#titles + 1] = text.text
            end
        end

        table.sort(titles)
        assert(table.concat(titles, ',') == 'Fire,Frostfire,Mage', 'pane titles: ' .. table.concat(titles, ','))
        assert(d.background:IsShown() and d.background.atlas == 'talents-background-mage-fire')
        -- Another specialization: its own backdrop is absent (plain), its trees drawn, Blizzard's window not touched.
        d.OnSpec(FROST)
        assert(not d.background:IsShown() and d.handle.spec == FROST)
        -- Choice entries are both drawn at half size.
        d.OnSpec(FIRE)
        local halves = 0

        for _, slot in ipairs(d.slots) do
            if slot:IsShown() and slot.data.choice then
                halves = halves + 1
                assert(slot:GetWidth() < 34)
            end
        end

        assert(halves >= 4, 'two choice nodes of two entries each: ' .. halves)
        d.frame:Hide()
    end
)

test('clicking the chosen talent again clears the condition\'s talent; clicking another replaces it', function()
    local state = { spec = FIRE, scale = 600 }
    local f, a = client(state, { blizzard = false, provider = false })
    local value = { layout = 'traits', node = 2203, spell = 257541, operator = 'EQUALS', value = 2 }
    local parent = editor(f, value, FIRE)
    treeButton(parent):Fire('OnClick')
    local d = a.talentTreeWindow
    local chosen, other

    for _, slot in ipairs(d.slots) do
        if slot:IsShown() then
            if slot.selected then
                chosen = slot
            elseif slot.data.node == 2202 then
                other = slot
            end
        end
    end

    chosen.scripts.OnClick(chosen)
    assert(not d.frame:IsShown() and value.node == nil and value.entry == nil and value.spell == nil)
    assert(child(parent, 'Talent Node ID').text == '' and value.operator == 'EQUALS')
    treeButton(parent):Fire('OnClick')

    for _, slot in ipairs(d.slots) do
        if slot:IsShown() and slot.data.node == 2202 then
            other = slot
        end
    end

    other.scripts.OnClick(other)
    assert(value.node == 2202 and value.spell == 190319 and a.definitions.TALENT.valid(0, value))
end)

test(
    'reading another specialization leaves a linked build in Blizzard\'s window alone, and the played one is always readable',
    function()
        local state = { spec = FIRE }
        local f, a = client(state, { provider = false, window = { shown = true, inspecting = true } })
        local p = a.Platform
        local view, why = p:GetTraitView(FROST)
        assert(view == nil and why == 'talent-window-inspecting', tostring(why))
        assert((state.calls.InitializeViewLoadout or 0) == 0, 'the shared view config was not touched')
        assert(p:GetTraitView(FIRE), 'the played specialization reads the active config')
        local d = open(a, { spec = FROST })
        assert(d.handle == nil and d.status.text:find('Close the build shown', 1, true), d.status.text)
        f.window.frame.inspecting = false
        assert(p:GetTraitView(FROST) and state.calls.InitializeViewLoadout == 1)
    end
)

-- The drawn tree sizes itself from the screen, and the window is drawn at the user's UI scale (70 to 130 percent), so the
-- room it may take is the screen divided by that scale.
test('the drawn tree window fits the screen at every UI scale', function()
    for _, case in ipairs({
        { screen = { 1366, 768 }, scale = 1, height = 688, width = 1240 },
        { screen = { 1366, 768 }, scale = 1.3, height = 529, width = 1020 },
        { screen = { 1366, 768 }, scale = .7, height = 820, width = 1240 },
        { screen = { 1024, 768 }, scale = 1.3, height = 529, width = 756 },
        { screen = { 2560, 1440 }, scale = 1.3, height = 820, width = 1240 },
    }) do
        local f, a, e = client({ spec = FIRE, scale = 600 }, { blizzard = false })
        e.UIParent:SetSize(case.screen[1], case.screen[2])
        a.db.global.uiScale = case.scale
        f.load('UI/window.lua')
        local d = open(a, { spec = FIRE })
        assert(d.mode == 'drawn')
        local name = string.format('%dx%d at %d%%', case.screen[1], case.screen[2], case.scale * 100)
        local scale = d.frame:GetScale()

        assert(
            math.abs(d.frame:GetHeight() - case.height) <= 1 and math.abs(d.frame:GetWidth() - case.width) <= 1,
            name .. ': window is ' .. d.frame:GetWidth() .. 'x' .. d.frame:GetHeight()
        )

        assert(
            d.frame:GetHeight() * scale <= case.screen[2] - 80 + 1
                and d.frame:GetWidth() * scale <= case.screen[1] - 40 + 1,
            name .. ': the drawn window is larger than the screen'
        )

        assert(scale == case.scale, name .. ': the scale was reduced although the window fits: ' .. scale)
    end
end)

finish()
