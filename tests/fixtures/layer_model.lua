-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- A model of how the client orders frames, laid over the native_ui fakes.
--   * A frame is drawn by (strata, level) only. Levels are global within a strata, not relative to a parent.
--   * CreateFrame copies the parent's strata and takes parent level + 1.
--   * SetFrameStrata changes the frame and every descendant that is not fixed.
--   * SetFrameLevel moves the frame and every descendant by the same amount (0..10000).
--   * SetParent takes the new parent's strata and level + 1.
--   * A frame with SetToplevel(true) raises itself when it, or anything inside it, is clicked.
--   * Raise() is modelled two ways, because the exact client rule is not documented:
--       'siblings': above every sibling's own level (descendants of siblings are not compared)
--       'strata'  : above every frame in the strata
-- Nothing here knows about RM; it only supplies the engine so tests can assert what is drawn over what.
local RANK = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8,
}

return function(env, options)
    options = options or {}
    local model = { raiseMode = options.raise or 'siblings', frames = {}, raises = 0 }
    local baseCreate = env.CreateFrame

    local function install(frame, parent)
        local layer = {
            strata = parent and parent.layer.strata or 'MEDIUM',
            level = parent and parent.layer.level + 1 or 0,
            children = {},
            toplevel = false,
            id = #model.frames + 1,
        }

        frame.layer = layer
        frame.parent = parent
        model.frames[#model.frames + 1] = frame

        if parent then
            table.insert(parent.layer.children, frame)
        end

        local function descendants(root, visit)
            visit(root)

            for _, child in ipairs(root.layer.children) do
                descendants(child, visit)
            end
        end

        function frame:GetFrameStrata()
            return self.layer.strata
        end

        function frame:SetFrameStrata(value)
            assert(RANK[value], 'SetFrameStrata(): invalid strata ' .. tostring(value))

            local function apply(node)
                node.layer.strata = value

                for _, child in ipairs(node.layer.children) do
                    if not child.layer.fixedStrata then
                        apply(child)
                    end
                end
            end

            apply(self)
        end

        function frame:SetFixedFrameStrata(value)
            self.layer.fixedStrata = value
        end

        function frame:GetFrameLevel()
            return self.layer.level
        end

        function frame:SetFrameLevel(value)
            assert(
                type(value) == 'number' and value >= 0 and value <= 10000,
                'SetFrameLevel(): frame level must be between 0 and 10000, got ' .. tostring(value)
            )

            local delta = value - self.layer.level

            descendants(self, function(node)
                node.layer.level = math.max(0, math.min(10000, node.layer.level + delta))
            end)
        end

        function frame:SetToplevel(value)
            self.layer.toplevel = value == true
        end

        function frame:IsVisible()
            local node = self

            while node do
                if node.visible == false then
                    return false
                end

                node = node.parent
            end

            return true
        end

        function frame:GetChildren()
            return unpack(self.layer.children)
        end

        function frame:SetParent(owner)
            if self.parent then
                for index, child in ipairs(self.parent.layer.children) do
                    if child == self then
                        table.remove(self.parent.layer.children, index)
                        break
                    end
                end
            end

            self.parent = owner

            if owner then
                table.insert(owner.layer.children, self)

                local function apply(node)
                    node.layer.strata = owner.layer.strata

                    for _, child in ipairs(node.layer.children) do
                        if not child.layer.fixedStrata then
                            apply(child)
                        end
                    end
                end

                apply(self)
                local delta = owner.layer.level + 1 - self.layer.level

                descendants(self, function(node)
                    node.layer.level = math.max(0, math.min(10000, node.layer.level + delta))
                end)
            end
        end

        function frame:Raise()
            model.raises = model.raises + 1
            local top
            local inside = {}

            descendants(self, function(node)
                inside[node] = true
            end)

            for _, other in ipairs(model.frames) do
                if
                    other ~= self
                    and not inside[other]
                    and other.layer.strata == self.layer.strata
                    and (model.raiseMode == 'strata' or other.parent == self.parent)
                then
                    if not top or other.layer.level > top then
                        top = other.layer.level
                    end
                end
            end

            if top and top + 1 > self.layer.level then
                self:SetFrameLevel(math.min(10000, top + 1))
            end
        end

        return frame
    end

    model.install = install

    -- A frame made before the model was laid over the world joins it (with its ancestors) the first time it is used.
    local function ensure(frame)
        if frame == nil then
            return nil
        end

        if frame.layer == nil then
            install(frame, ensure(frame.parent))
        end

        return frame
    end

    model.ensure = ensure
    ensure(env.UIParent)

    function model.create(kind, name, parent, template)
        local frame = baseCreate(kind, name, parent, template)
        ensure(frame)
        return frame
    end

    env.CreateFrame = model.create

    -- What a click on `frame` (or a control inside it) does natively: the nearest toplevel frame raises itself.
    function model.click(frame)
        local node = frame

        while node do
            if node.layer and node.layer.toplevel then
                node:Raise()
                return node
            end

            node = node.parent
        end
    end

    function model.key(frame)
        return RANK[frame.layer.strata] * 100000 + frame.layer.level
    end

    -- True when `a` is drawn over `b` wherever they overlap (strictly: an equal key is a tie the client leaves undefined).
    function model.over(a, b)
        return model.key(a) > model.key(b)
    end

    function model.subtree(root)
        local list = {}

        local function walk(node)
            list[#list + 1] = node

            for _, child in ipairs(node.layer.children) do
                walk(child)
            end
        end

        walk(root)
        return list
    end

    -- Every frame that can be seen inside `window` (a hidden frame hides its descendants) and is not inside one of `except`.
    function model.content(window, except)
        local skip = {}

        for _, root in ipairs(except or {}) do
            for _, node in ipairs(model.subtree(root)) do
                skip[node] = true
            end
        end

        local list = {}

        local function walk(node)
            if skip[node] or node.visible == false then
                return
            end

            list[#list + 1] = node

            for _, child in ipairs(node.layer.children) do
                walk(child)
            end
        end

        walk(window)
        return list
    end

    -- popup (including all of its own content) is drawn over every frame of `window`'s content.
    function model.coversWindow(popup, window, except)
        local lowest

        for _, node in ipairs(model.subtree(popup)) do
            if not lowest or model.key(node) < lowest then
                lowest = model.key(node)
            end
        end

        for _, node in ipairs(model.content(window, except or { popup })) do
            if model.key(node) >= lowest then
                return false, node
            end
        end

        return true
    end

    return model
end
