-- Animated glow effects run as native stepped AnimationGroups: one texture per
-- step, shown by alpha keyframes, no Lua timer. Without the animation API, or
-- for malformed sequences, the Lua timer path is unchanged.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(animations)
    local f = F.new(5, 1, 'SHAMAN')
    local a, e = f.addon, f.env
    local calls = { timers = {}, groups = 0 }

    local library = {
        PixelGlow_Stop = function() end,
        AutoCastGlow_Stop = function() end,
        ButtonGlow_Stop = function() end,
        PixelGlow_Start = function() end,
    }

    local stub = e.LibStub

    e.LibStub = setmetatable({ GetLibrary = function() return nil end }, {
        __call = function(_, name, ...)
            if name == 'LibCustomGlow-1.0' then
                return library
            end

            return stub(name, ...)
        end,
    })

    e.C_AddOns = { IsAddOnLoaded = function() return false end }
    e.tinsert, e.tremove = table.insert, table.remove
    local create = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = create(...)
        local texture = frame.CreateTexture

        function frame:CreateTexture(...)
            local region = texture(self, ...)

            function region:SetBlendMode(v)
                self.blend = v
            end

            function region:SetRotation(v)
                self.rotation = v
            end

            function region:SetAlpha(v)
                self.alpha = v
            end

            function region:SetVertexColor(r, g, b, al)
                self.color = { r, g, b, al }
            end

            function region:SetTexture(v)
                self.file = v
            end

            function region:SetSize(w, h)
                self.w, self.h = w, h
            end

            function region:GetSize()
                return self.w, self.h
            end

            return region
        end

        if animations then
            function frame:CreateAnimationGroup()
                calls.groups = calls.groups + 1
                local group = { animations = {}, playing = false }

                function group:SetLooping(v)
                    self.looping = v
                end

                function group:Play()
                    self.playing = true
                end

                function group:Stop()
                    self.playing = false
                end

                function group:CreateAnimation(kind)
                    local anim = { kind = kind }
                    self.animations[#self.animations + 1] = anim

                    for _, m in ipairs({
                        'SetTarget',
                        'SetFromAlpha',
                        'SetToAlpha',
                        'SetDuration',
                        'SetStartDelay',
                        'SetOrder',
                    }) do
                        anim[m] = function(s, v)
                            s[m:sub(4)] = v
                        end
                    end

                    return anim
                end

                return group
            end
        end

        return frame
    end

    a.db.profile.color = { r = .2, g = .3, b = .4, a = .5 }

    function a:ScheduleRepeatingTimer(callback, frequency, ...)
        local token = {}
        calls.timers[token] = true
        return token
    end

    function a:CancelTimer(token)
        calls.timers[token] = nil
    end

    for _, path in ipairs({ 'Platform/spells.lua', 'Platform/macros.lua', 'buttons.lua', 'Core/function_data.lua' }) do
        f.load(path)
    end

    local button = e.CreateFrame('Button', nil, e.UIParent)
    button:SetSize(40, 30)
    return a, calls, button
end

local function timers(calls)
    local n = 0

    for _ in pairs(calls.timers) do
        n = n + 1
    end

    return n
end

local white = { r = 1, g = 1, b = 1, a = 1 }
local pulse = { type = 'pulse', texture = 'ping4', sequence = { .4, .6, .8, 1, 1.2, 1.4 }, frequency = .1 }

test('pulse becomes six native steps with exact sizes and alpha keyframes', function()
    local a, calls, b = fixture(true)
    a:Glow(b, 'next', pulse, white, 1, 'CENTER', 0, 0)
    local overlay = b.rmOverlays.next
    assert(overlay:IsShown() and timers(calls) == 0, 'Lua timer still scheduled')
    local native = assert(overlay.rmNative, 'native animation not started')
    assert(native.count == 6 and native.group.playing and native.group.looping == 'REPEAT')

    for i, mag in ipairs(pulse.sequence) do
        local t = overlay.rmStepTextures[i]
        assert(t.file == 'ping4' and t.blend == 'ADD' and t.alpha == 0 and t:IsShown())
        local w, h = t:GetSize()
        assert(math.abs(w - 40 * mag) < 1e-9 and math.abs(h - 30 * mag) < 1e-9, 'step ' .. i .. ' size')
    end

    local anims = native.group.animations
    assert(#anims == 12)

    for i = 1, 6 do
        local on, off = anims[2 * i - 1], anims[2 * i]

        assert(
            on.Target == overlay.rmStepTextures[i]
                and on.FromAlpha == 0
                and on.ToAlpha == 1
                and math.abs(on.StartDelay - (i - 1) * .1) < 1e-9
        )

        assert(
            off.Target == on.Target
                and off.FromAlpha == 1
                and off.ToAlpha == 0
                and math.abs(off.StartDelay - i * .1) < 1e-9
        )
    end

    assert(not overlay.texture:IsShown(), 'single texture still drawn')
end)

test('rotate steps keep their angles, including reverse', function()
    for _, reverse in ipairs({ false, true }) do
        local a, _, b = fixture(true)

        a:Glow(
            b,
            'x',
            { type = 'rotate', texture = 'star4', steps = 16, frequency = .1, reverse = reverse },
            white,
            1.2,
            'CENTER',
            0,
            0
        )

        local o = b.rmOverlays.x
        assert(o.rmNative.count == 16)

        for i = 1, 16 do
            local step = reverse and (16 - (i - 1)) or (i - 1)
            assert(math.abs(o.rmStepTextures[i].rotation - 2 * math.pi / 16 * step) < 1e-9)
        end
    end
end)

test('custom steps carry their own texture, color, size and angle', function()
    local a, _, b = fixture(true)
    local red, blue = { r = 1, g = 0, b = 0, a = 1 }, { r = 0, g = 0, b = 1, a = 1 }

    a:Glow(
        b,
        'x',
        {
            type = 'custom',
            frequency = .2,
            sequence = {
                { texture = 'a', color = red, magnification = 1, angle = 90 },
                { texture = 'b', color = blue, magnification = 2, angle = 0 },
            },
        },
        white,
        1,
        'CENTER',
        0,
        0
    )

    local t1, t2 = b.rmOverlays.x.rmStepTextures[1], b.rmOverlays.x.rmStepTextures[2]

    assert(
        t1.file == 'a'
            and t1.color[1] == 1
            and math.abs(t1.rotation - math.pi / 2) < 1e-9
            and t2.file == 'b'
            and t2.color[3] == 1
    )

    assert(select(1, t2:GetSize()) == 80)
end)

test('hiding stops the group and a new glow reuses textures and the group', function()
    local a, calls, b = fixture(true)
    a:Glow(b, 'next', pulse, white, 1, 'CENTER', 0, 0)
    local o = b.rmOverlays.next
    local group = o.rmNative.group
    a:HideGlow(b, 'next')
    assert(not group.playing and not o.rmNative and not o.rmStepTextures[1]:IsShown())
    a:Glow(b, 'next', pulse, white, 1, 'CENTER', 0, 0)
    local again = b.rmOverlays.next
    assert(again.rmNative.group == group and calls.groups == 1, 'animation group was not reused')
end)

test('without the animation API, or for a malformed step, the Lua timer runs as before', function()
    local a, calls, b = fixture(false)
    a:Glow(b, 'next', pulse, white, 1, 'CENTER', 0, 0)
    assert(timers(calls) == 1 and not b.rmOverlays.next.rmNative)
    a, calls, b = fixture(true)
    a:Glow(b, 'x', { type = 'custom', frequency = .2, sequence = { { texture = 'a' } } }, white, 1, 'CENTER', 0, 0)
    assert(not b.rmOverlays.x.rmNative, 'malformed custom step went native')
end)

finish()
