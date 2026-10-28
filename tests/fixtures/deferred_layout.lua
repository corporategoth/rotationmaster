-- Client-faithful frame sizing for the native UI mock. In the WoW client a
-- frame's rect is resolved on the next layout pass: GetWidth()/GetHeight()
-- keep returning the previous size after SetWidth/SetSize, and OnSizeChanged
-- fires only then, with the new size. Install before loading UI files:
--   local frames,create=dofile('tests/fixtures/native_ui.lua')(env)
--   local layout=dofile('tests/fixtures/deferred_layout.lua')(env,create)
-- then use layout.create in place of create and layout.step()/settle() as
-- the client's next frame(s). Textures and FontStrings keep mock sizing.
return function(env, create)
    local layout = { frames = {} }

    local function defer(frame)
        if frame.rmDeferred or frame.kind == 'Texture' or frame.kind == 'FontString' then
            return frame
        end

        frame.rmDeferred = true
        frame.shownWidth, frame.shownHeight = frame.width, frame.height
        layout.frames[#layout.frames + 1] = frame

        function frame:SetSize(width, height)
            self.width, self.height = width, height
        end

        function frame:SetWidth(value)
            self.width = value
        end

        function frame:SetHeight(value)
            self.height = value
        end

        function frame:GetWidth()
            return self.shownWidth
        end

        function frame:GetHeight()
            return self.shownHeight
        end

        function frame:GetSize()
            return self.shownWidth, self.shownHeight
        end

        return frame
    end

    function layout.create(...)
        return defer(create(...))
    end

    env.CreateFrame = layout.create

    if env.UIParent then
        defer(env.UIParent)
    end

    -- layout.sizeHandlers counts OnSizeChanged handler invocations (script
    -- and hooks), for the reflow cost benchmark.
    layout.sizeHandlers = 0

    local function fire(frame, event, ...)
        local script = frame.scripts[event]

        if script then
            if event == 'OnSizeChanged' then
                layout.sizeHandlers = layout.sizeHandlers + 1
            end

            script(frame, ...)
        end

        for _, hook in ipairs(frame.hooks and frame.hooks[event] or {}) do
            if event == 'OnSizeChanged' then
                layout.sizeHandlers = layout.sizeHandlers + 1
            end

            hook(frame, ...)
        end
    end

    local function visible(frame)
        for _ = 1, 200 do
            if not frame then
                return true
            end
            if not frame.visible then
                return false
            end

            frame = frame.parent
        end

        return true
    end

    -- One client frame: resolve every pending size (firing OnSizeChanged with
    -- the new size, which may queue more), then run each shown OnUpdate once.
    function layout.step(options)
        options = options or {}

        for _ = 1, 50 do
            local changed = {}

            for _, frame in ipairs(layout.frames) do
                if frame.shownWidth ~= frame.width or frame.shownHeight ~= frame.height then
                    frame.shownWidth, frame.shownHeight = frame.width, frame.height
                    changed[#changed + 1] = frame
                end
            end

            if #changed == 0 then
                break
            end

            for _, frame in ipairs(changed) do
                fire(frame, "OnSizeChanged", frame.width, frame.height)
            end
        end

        if options.updates ~= false then
            local snapshot = {}

            for _, frame in ipairs(layout.frames) do
                snapshot[#snapshot + 1] = frame
            end

            for _, frame in ipairs(snapshot) do
                if frame.scripts.OnUpdate and visible(frame) then
                    frame.scripts.OnUpdate(frame, .016)
                end
            end
        end
    end

    -- The client resizing a frame itself (a sizing drag on its grip): only
    -- the rect changes; no RM setter runs before OnSizeChanged.
    function layout.userResize(frame, width, height)
        frame.width, frame.height = width, height
    end

    function layout.settle(count, options)
        for _ = 1, count or 4 do
            layout.step(options)
        end
    end

    return layout
end
