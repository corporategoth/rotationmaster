-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- A model of Blizzard's talent window (PlayerSpellsFrame) in the parts Rotation
-- Master drives: view (inspect) mode through SetInspectString, the tab, the
-- talent buttons and the EventRegistry events they fire. NO REAL CLIENT WAS
-- AVAILABLE: this follows the pinned Blizzard source (Gethe/wow-ui-source live
-- b9be937, Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua,
-- ClassTalents/Blizzard_ClassTalentImportExport.lua ViewLoadout/ReadLoadout*,
-- Blizzard_SharedXMLBase/ExportUtil.lua, Blizzard_SharedTalentUI buttons) and
-- decodes the loadout string independently of the addon's encoder, so a string
-- the addon builds is judged by Blizzard's own reading of the format.
local M = {}

-- Blizzard's ImportDataStream: six bits per base64 character, least significant first.
local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function stream(text)
    local values = {}

    for index = 1, #text do
        local found = ALPHABET:find(text:sub(index, index), 1, true)

        if not found then
            return nil
        end

        values[index] = found - 1
    end

    local self = { values = values, index = 1, extracted = 0, remaining = values[1] }

    function self:bits()
        return 6 * #values
    end

    function self:extract(width)
        if self.index > #values then
            return nil
        end

        local value, needed, done = 0, width, 0

        while needed > 0 do
            local remainingBits = 6 - self.extracted
            local take = math.min(remainingBits, needed)
            self.extracted = self.extracted + take
            local limit = 2 ^ take
            local part = self.remaining % limit
            self.remaining = math.floor(self.remaining / limit)
            value = value + part * 2 ^ done
            done = done + take
            needed = needed - take

            if take < remainingBits then
                break
            end

            self.index = self.index + 1
            self.extracted = 0
            self.remaining = values[self.index]
        end

        return value
    end

    return self
end

M.stream = stream

-- Reads a loadout string the way ViewLoadout does. Returns {version, spec, hash, selected = {[position]={purchased, partial, choice, entry}}}.
function M.decode(text, nodeCount)
    local s = stream(text)

    if not s or s:bits() < 8 + 16 + 128 then
        return nil, 'bad-string'
    end

    local result = { version = s:extract(8), spec = s:extract(16), hash = {}, selected = {} }

    for index = 1, 16 do
        result.hash[index] = s:extract(8)
    end

    for position = 1, nodeCount do
        local selected = s:extract(1) == 1

        if selected then
            local record = {}
            record.purchased = s:extract(1) == 1

            if record.purchased then
                record.partial = s:extract(1) == 1

                if record.partial then
                    record.ranks = s:extract(6)
                end

                record.choice = s:extract(1) == 1

                if record.choice then
                    record.entry = s:extract(2) + 1
                end
            end

            result.selected[position] = record
        end
    end

    return result
end

-- env: the fixture environment; Tree: tests/fixtures/retail_traits.lua; state: its state.
-- options: shown, tab, inspecting, changes, refuse(function(decoded) -> boolean).
function M.install(env, Tree, state, options)
    options = options or {}
    local window = { calls = {} }
    M.window = window

    local frame = {
        shown = options.shown == true,
        tab = options.tab or 3,
        strata = 'MEDIUM',
        level = 5000,
        inspecting = options.inspecting == true,
    }

    window.frame = frame

    local function note(name, ...)
        window.calls[#window.calls + 1] = name
        window[name] = (window[name] or 0) + 1
    end

    local buttons = {}
    local talents = {}

    function talents:GetTalentButtonByNodeID(node)
        return buttons[node]
    end

    function talents:HasAnyConfigChanges()
        return options.changes == true
    end

    frame.TalentsFrame = talents

    local function nodeButton(node)
        local record

        for _, candidate in ipairs(Tree.nodes) do
            if candidate.id == node then
                record = candidate
            end
        end

        local button = { node = node, shown = true, strata = 'MEDIUM', level = 5010 }
        button.talentFrame = talents

        function button:GetNodeID()
            return node
        end

        function button:GetTalentFrame()
            return talents
        end

        function button:GetNodeInfo()
            return {
                ID = node,
                type = ({ single = 0, tiered = 1, selection = 2, subtree = 3 })[record.kind or 'single'],
            }
        end

        -- Blizzard's base button names its node's ACTIVE entry: a choice node nobody picked has none.
        function button:GetEntryID()
            if record.kind == 'selection' then
                local decoded = frame.decoded
                local order = {}

                for _, candidate in ipairs(Tree.nodes) do
                    order[#order + 1] = candidate.id
                end

                table.sort(order)

                for position, id in ipairs(order) do
                    if id == node and decoded and decoded.selected[position] and decoded.selected[position].entry then
                        return Tree.entryID(record, decoded.selected[position].entry)
                    end
                end

                return nil
            end

            return Tree.entryID(record, 1)
        end

        function button:GetSpellID()
            local entry = self:GetEntryID()

            if entry then
                for position = 1, #record.entries do
                    if Tree.entryID(record, position) == entry then
                        return record.entries[position]
                    end
                end
            end
        end

        function button:SetGlowing(flag)
            self.glowing = flag
        end

        function button:IsShown()
            return self.shown
        end

        function button:GetFrameStrata()
            return self.strata
        end

        function button:GetFrameLevel()
            return self.level
        end

        return button
    end

    for _, record in ipairs(Tree.nodes) do
        buttons[record.id] = nodeButton(record.id)
    end

    window.buttons = buttons

    -- A choice node's entry button: answers for its base button.
    function window.entryButton(node, position)
        local record

        for _, candidate in ipairs(Tree.nodes) do
            if candidate.id == node then
                record = candidate
            end
        end

        local base = buttons[node]
        local button = {}

        function button:GetBaseButton()
            return base
        end

        function button:GetEntryID()
            return Tree.entryID(record, position)
        end

        function button:GetSpellID()
            return record.entries[position]
        end

        function button:GetNodeInfo()
            return base:GetNodeInfo()
        end

        return button
    end

    function frame:IsShown()
        return self.shown
    end

    function frame:Show()
        self.shown = true
    end

    function frame:Hide()
        if self.shown then
            self.shown = false
            self:ClearInspectUnit()
        end
    end

    function frame:GetTab()
        return self.tab
    end

    function frame:SetTab(tab)
        note('SetTab')
        self.tab = tab
    end

    function frame:IsInspecting()
        return self.inspecting
    end

    function frame:GetFrameStrata()
        return self.strata
    end

    function frame:SetFrameStrata(value)
        self.strata = value
    end

    function frame:GetFrameLevel()
        return self.level
    end

    function frame:ClearInspectUnit()
        if not self.inspecting then
            return
        end

        note('ClearInspectUnit')
        self.inspecting = false
        self.inspectString = nil
        self.decoded = nil
    end

    function frame:SetInspectString(text, level)
        note('SetInspectString')
        window.lastString, window.lastLevel = text, level
        local nodes = env.C_Traits.GetTreeNodes(Tree.TREE)
        local decoded = M.decode(text, #nodes)

        if not decoded then
            self.inspecting = false
            return
        end

        if decoded.version ~= env.C_Traits.GetLoadoutSerializationVersion() then
            self.inspecting = false
            return
        end

        env.C_ClassTalents.InitializeViewLoadout(decoded.spec, level)

        if options.refuse and options.refuse(decoded, window) then
            self.inspecting = false
            self.inspectString = nil
            return
        end

        self.inspecting, self.inspectString, self.decoded = true, text, decoded
        self.tab = 2
    end

    env.PlayerSpellsFrame = frame

    function env.ShowUIPanel(target)
        note('ShowUIPanel')
        target.shown = true
    end

    function env.HideUIPanel(target)
        note('HideUIPanel')
        target:Hide()
    end

    -- EventRegistry: callbacks run as callback(owner, ...).
    local registry = { callbacks = {} }

    function registry:RegisterCallback(event, callback, owner)
        self.callbacks[event] = self.callbacks[event] or {}
        table.insert(self.callbacks[event], { callback = callback, owner = owner })
    end

    function registry:UnregisterCallback(event, owner)
        local list = self.callbacks[event] or {}

        for index = #list, 1, -1 do
            if list[index].owner == owner then
                table.remove(list, index)
            end
        end
    end

    function registry:TriggerEvent(event, ...)
        for _, entry in ipairs({ unpack(self.callbacks[event] or {}) }) do
            entry.callback(entry.owner, ...)
        end
    end

    function registry:Count()
        local total = 0

        for _, list in pairs(self.callbacks) do
            total = total + #list
        end

        return total
    end

    env.EventRegistry = registry
    window.registry = registry
    return window
end

return M
