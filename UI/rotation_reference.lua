-- Read-only rendering of a rotation: a reference view (switch, cooldown and sequential sections, implicit auto-attack
-- fallback) and the step cards, breadcrumbs and condition text it is built from. It works on snapshots and registers no
-- callback that can change a rotation; UI/rotation_comparison.lua reuses the cards, UI/defaults.lua the whole view.
-- Loaded from RotationMaster.toc after UI/rotation_view.lua; item names go through Platform:CanReadValue.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Adds a full-width condition label to parent and returns it; kind 'Heading' uses the workbench header font and color.
local function label(parent, text, kind)
    local widget = addon:CreateConditionLabel()

    if kind == 'Heading' then
        widget:SetFontObject(addon.WorkbenchHeaderFont)
        widget:SetColor(unpack(addon.WorkbenchHeaderColor))
    end

    widget:SetFullWidth(true)
    widget:SetText(text)
    parent:AddChild(widget)
    return widget
end

-- Returns a display name for an item id or name, falling back to 'Item <id>' when the item is not cached or its name
-- is a restricted value that must not be read.
local function itemName(item)
    if type(item) ~= "number" and type(item) ~= "string" then
        return L["Unknown item"]
    end

    local fn = C_Item and C_Item.GetItemInfo or GetItemInfo

    if type(fn) == "function" then
        local ok, name = pcall(fn, item)

        if ok and (not addon.Platform or addon.Platform:CanReadValue(name)) and type(name) == "string" then
            return name
        end
    end

    return string.format(L["Item %s"], item)
end

-- Adds the prose description of condition (for spec) as a label, with spell hyperlinks wired up; returns the label.
function addon:CreateConditionReference(parent, condition, spec)
    local widget = label(parent, self:DescribeCondition(condition, spec))
    self:InstallSpellHyperlinks(widget.frame)
    return widget
end

-- The same read-only cards are used for reference and comparison. They receive
-- snapshots and register no callbacks that can change a rotation.
-- Adds one read-only card for step to parent and returns it. kind is 'cooldowns' or 'rotation' and picks the title;
-- status, when given, prefixes the title (used by comparisons). The pooled card's OnRelease is wrapped so the rounded
-- decoration is hidden again when the card returns to the widget pool.
function addon:CreateRotationStepCard(parent, step, spec, position, kind, status)
    local card = addon:CreateConditionGroup()
    card:SetFullWidth(true)
    card:SetLayout("List")
    card:SetUserData('padding', 8)
    parent:AddChild(card)
    local art = card.rmReferenceDecoration or addon:CreateRoundedCardDecoration(card.frame)
    card.rmReferenceDecoration = art
    art:SetColors(.48, .5, .53, .85, .6)

    for _, parts in ipairs({ art.fill, art.border }) do
        for _, part in ipairs(parts) do
            part:Show()
        end
    end

    local release = card.OnRelease

    -- Hides the decoration before the pooled card is released, then restores the original OnRelease.
    card.OnRelease = function(self, ...)
        for _, parts in ipairs({ art.fill, art.border }) do
            for _, part in ipairs(parts) do
                part:Hide()
            end
        end

        self.OnRelease = release
        return release(self, ...)
    end

    local title = kind == "cooldowns" and L["Optional highlight"] or string.format(L["Priority %s"], position)

    if status then
        title = status .. " · " .. title
    end

    label(card, title, "Heading")

    if step.type == "spell" or step.type == "pet" or step.type == "any" then
        label(
            card,
            step.type == "pet" and L["Pet spell"]
                or step.type == "any" and L["Player or pet spell"]
                or L["Player spell"]
        )

        local identity = self:CreateSpellLabel(card, step.action)
        local info = self.Platform and self.Platform:GetSpellInfo(step.action)

        if info and info.iconID then
            identity:SetImage(info.iconID)
            identity:SetImageSize(24, 24)
        end
    elseif step.type == "branch" then
        label(card, L["Conditional branch"])
        local mode = step.mode or "evaluate"

        label(
            card,
            mode == "evaluate" and L["Evaluate condition"]
                or mode == "true" and L["Always true"]
                or mode == "false" and L["Always false"]
                or L["Unknown branch mode"]
        )
    elseif step.type == "assisted" then
        label(card, L["Recommends the spell Blizzard's Assisted Combat suggests"])
    elseif step.type == "stop" then
        label(card, L["Stop the sequence here"])

        label(
            card,
            step.suppress_attack and L["Implicit auto-attack (Attack or Shoot) is suppressed by this Stop."]
                or L["Implicit auto-attack (Attack or Shoot) may still be recommended after this Stop."]
        )
    elseif step.type == "item" then
        if step.name and step.name ~= "" then
            label(card, step.name)
        end

        if type(step.action) == "table" then
            for _, item in ipairs(step.action) do
                label(card, itemName(item))
            end
        elseif type(step.action) == "string" then
            label(card, string.format(L["Item set: %s"], step.action))
        else
            label(card, itemName(step.action))
        end
    else
        label(card, L["Unknown action type"])
    end

    if step.use_name ~= nil then
        label(card, step.use_name and L["Custom step name"] or L["Automatic step name"])
    end
    if step.disabled then
        label(card, L["Disabled"])
    end
    if step.ranked and addon:ClientHasSpellRanks() then
        label(card, L["Use this exact spell rank"])
    end
    if step.name and step.name ~= "" and step.type ~= "item" then
        label(card, step.name)
    end

    self:CreateConditionReference(card, step.conditions, spec)
    return card
end

-- Adds a 'name → arm' trail for a step nested inside Branches; path is a list of { name, arm }. Returns the label, or
-- nil when the path is empty.
function addon:CreateRotationBranchBreadcrumb(parent, path)
    local parts = {}

    for _, entry in ipairs(path or {}) do
        parts[#parts + 1] = entry.name and entry.name ~= "" and entry.name or L["Conditional branch"]
        parts[#parts + 1] = entry.arm == "true" and L["True"] or L["False"]
    end

    if #parts > 0 then
        return label(parent, table.concat(parts, " → "))
    end
end

-- Builds the whole reference view for a rotation body into parent: switch, optional highlights, the priority list and
-- the fixed auto-attack fallback note. A tree that cannot be indexed shows its problem code instead of the sections.
local function renderReference(self, parent, body, spec)
    label(
        parent,
        L["Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions."]
    )

    label(parent, L["Switch conditions"], "Heading")
    self:CreateConditionReference(parent, body.switch, spec)
    local tree, problem = self.RotationData.IndexRotationSteps(body, { allowMissingIds = true })

    if not tree then
        label(parent, L["Rotation tree cannot be displayed."] .. " " .. problem.code)
        return
    end

    -- Renders one step section, putting a breadcrumb of its parent Branches before each step's card.
    local function section(kind, title, explanation)
        label(parent, title, "Heading")
        label(parent, explanation)
        local list = body[kind] or {}

        if #list == 0 then
            label(parent, L["No steps in this section."])
        end

        for _, entry in ipairs(tree.rows) do
            if entry.section == kind then
                local path = {}
                local current = entry

                while current.parentId do
                    local ancestor = tree.byId[current.parentId]
                    table.insert(path, 1, { name = ancestor.step.name, arm = current.arm })
                    current = ancestor
                end

                self:CreateRotationBranchBreadcrumb(parent, path)
                self:CreateRotationStepCard(parent, entry.step, spec, entry.index, kind)
            end
        end
    end

    section(
        "cooldowns",
        L["Optional highlights"],
        L["These reminders highlight independently whenever their conditions are met."]
    )

    section(
        "rotation",
        L["Sequential priority"],
        L["The first eligible step is recommended. Later steps provide alternatives."]
    )

    label(parent, L["Implicit final fallback"], "Heading")
    local attack = self:CreateSpellLabel(parent, 6603)
    local info = self.Platform and self.Platform:GetSpellInfo(6603)

    if info and info.iconID then
        attack:SetImage(info.iconID)
        attack:SetImageSize(24, 24)
    end

    label(
        parent,
        L["When no priority action is ready, auto-attack (Attack or Shoot) is the implicit final fallback against a living hostile target in combat: Attack in melee range; beyond it, Auto Shot or wand Shoot while the target is in range and that button is on your action bars. Nothing is recommended while that auto-attack is already running. It uses the normal rotation highlight and never presses a button."]
    )
end

-- Public entry: renders the reference with layout paused for speed. The pause is always resumed, then any render error
-- is rethrown unchanged so callers see the original failure.
function addon:CreateRotationReference(parent, body, spec)
    local paused = type(parent.PauseLayout) == 'function' and type(parent.ResumeLayout) == 'function'

    if paused then
        parent:PauseLayout()
    end

    local ok, why = pcall(renderReference, self, parent, body, spec)

    if paused then
        parent:ResumeLayout()
    end
    if not ok then
        error(why, 0)
    end
end
