-- Detail fields for a cooldown (optional highlight) step's visual and audible effect: effect choice, magnification,
-- RGBA color, glow offsets, announce channel and sound. It only builds controls on a rotation card and stages edits
-- through the owner (StageField, patch); it never writes the draft or the saved effects itself. Called once per
-- cooldown card from UI/rotation_fields.lua, which supplies the row helpers in ctx. Loaded from RotationMaster.toc just
-- before that file. The live glow preview uses only the step's own values and the saved effect definitions.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Serializes a color table as the 'r,g,b,a' text staged in the color field (missing channels default to 1).
-- @param c table  The color ({ r, g, b, a }, each a number or nil).
-- @return string  The four channels joined with commas.
local function colorString(c)
    return table.concat({ c.r or 1, c.g or 1, c.b or 1, c.a or 1 }, ',')
end

-- Parses 'r,g,b,a' text into a color table.
-- @param text string  The comma-separated channels.
-- @return table|nil  { r, g, b, a }; nil unless there are exactly four numbers in the range 0 to 1.
local function parseColor(text)
    local values = {}

    for part in (text .. ','):gmatch('(.-),') do
        local n = tonumber(part)

        if not n or n ~= n or n < 0 or n > 1 then
            return
        end

        values[#values + 1] = n
    end

    if #values == 4 then
        return { r = values[1], g = values[2], b = values[3], a = values[4] }
    end
end

-- Builds the effect rows for a cooldown step on its card: effect, magnification, color, position, announce channel and
-- sound. Controls come from the card's pool and are registered in ctx.controls so the card can hide them on release.
-- Also installs card.RefreshHighlightPreview, which redraws the live glow on the step's icon and is cleared by the
-- card's releaseFields.
-- @param owner table  The rotation editor view (field staging, flush, render, messages).
-- @param card table  The card control that holds the fields.
-- @param model table  The cooldown card model (model.step is the step shown).
-- @param alive function  Says the card is still current.
-- @param ctx table  The shared row helpers (acquire, label, choice, input, patch, active, getY/setY), the layout
--   metrics
-- (width, valueX, valueWidth) and readOnly.
-- @return number  The y position below the rows.
function addon:BuildRotationEffectFields(owner, card, model, alive, ctx)
    local step = model.step
    local profile = addon.db.profile
    local controls = ctx.controls
    local width, x = ctx.width, ctx.valueX

    -- Acquires a pooled control (an icon button unless build is given), records it under key and in the card's control
    -- list.
    -- @param key string  The name the control is recorded under.
    -- @param kind string|nil  The icon name for the default icon button.
    -- @param build function|nil  Creates the control when the pool has none; nil builds an icon button.
    -- @return table  The control.
    local function extra(key, kind, build)
        local control = ctx.acquire(
            'extras',
            build or function() return addon:CreateWorkbenchIconButton(card.fields, kind) end
        )

        controls[key] = control
        controls[#controls + 1] = control
        return control
    end

    -- Reserves a labeled row of the given height.
    -- @param caption string  The row label text.
    -- @param height number  The row height to reserve.
    -- @return number  The top y of the row.
    -- @return table  The label.
    local function row(caption, height)
        local label = ctx.label(caption)
        local y = ctx.getY()
        ctx.setY(y + height)
        return y, label
    end

    -- Returns the x and y glow offsets, preferring a staged field edit, then the step, then the profile default.
    -- @return number  The x offset.
    -- @return number  The y offset.
    local function offsets()
        return tonumber(owner:FieldText(model.id, 'xoffs', step.xoffs or '')) or profile.xoffs or 0,
            tonumber(owner:FieldText(model.id, 'yoffs', step.yoffs or '')) or profile.yoffs or 0
    end

    local baseColor = addon:ResolveHighlightColor(step.color)
    local baseline = step.color and colorString(step.color) or ''
    local demo = { target = card.fieldSpellIcon or card.preview }
    card.effectDemo = demo

    -- Returns the color to show: the staged text if it parses, otherwise the step's color or the resolved highlight
    -- color.
    -- @return table  The color { r, g, b, a }.
    local function currentColor()
        return parseColor(owner:FieldText(model.id, 'color', step.color and baseline or colorString(baseColor)))
            or baseColor
    end

    -- Redraws the demo glow on the step's icon (or the card preview) from the staged field values; the pooled card may
    -- have been recycled, so it does nothing once alive() is false.
    card.RefreshHighlightPreview = function()
        if not alive() then
            return
        end

        local effect = (addon.db.global.effects or {})[step.effect or profile.effect]
        local ox, oy = offsets()
        local color = currentColor()
        demo.color = color

        if addon.HideGlow then
            addon:HideGlow(demo.target, 'rotation-effect-preview')
        end
        if effect and addon.Glow then
            addon:Glow(
                demo.target,
                'rotation-effect-preview',
                effect,
                color,
                tonumber(owner:FieldText(model.id, 'magnification', step.magnification or ''))
                    or profile.magnification
                    or 1,
                step.setpoint or profile.setpoint or 'CENTER',
                ox,
                oy,
                step.angle
            )
        end
    end

    local effects = { { value = '', text = L['Use profile effect'] } }

    for id, effect in pairs(addon.db.global.effects or {}) do
        if type(id) == 'string' and type(effect) == 'table' then
            effects[#effects + 1] = { value = id, text = effect.name or id }
        end
    end

    ctx.choice('effect', L['Effect'], effects, step.effect or '', function(value)
        if value == '' then
            ctx.patch(nil, { 'effect' })
        else
            ctx.patch({ effect = value })
        end
    end)

    local magY = row(L['Magnification'], 28)

    local mag = extra('magnification', nil, function()
        return addon:CreateWorkbenchSlider(card.fields, .1, 2, .1, 120)
    end)

    mag:ClearAllPoints()
    mag:SetPoint('TOPLEFT', x, -magY - 4)
    mag:SetWidth(math.max(50, ctx.valueWidth - 44))
    addon:SetUIScript(mag, 'OnValueChanged', nil)

    local currentMag = tonumber(owner:FieldText(model.id, 'magnification', step.magnification or ''))
        or profile.magnification
        or 1

    -- The range widens to include the current value so an out-of-range magnification is shown, not clamped.
    mag:SetMinMaxValues(math.min(.1, currentMag), math.max(2, currentMag))
    mag:SetValue(currentMag)
    local magNumber = extra('magnificationValue', nil, function() return addon:CreateWorkbenchEditBox(card.fields) end)
    magNumber:ClearAllPoints()
    magNumber:SetPoint('TOPLEFT', width - 46, -magY)
    magNumber:SetSize(46, 24)
    magNumber:SetText(owner:FieldText(model.id, 'magnification', string.format('%.3g', currentMag)))
    magNumber:EnableMouse(not ctx.readOnly)

    -- Stages a magnification edit and, when the text is a usable positive number, moves the slider to match and redraws
    -- the preview. The loading flag stops the slider's OnValueChanged from echoing back into the text box.
    -- @param text string  The text typed in the magnification box.
    local function stageMag(text)
        local n = tonumber(text)
        local valid = n and n == n and n > 0 and n < math.huge
        magNumber:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
        owner:StageField(model.id, 'magnification', text, step.magnification or '', L['Magnification'])

        if valid then
            mag.loading = true
            mag:SetMinMaxValues(math.min(.1, n), math.max(2, n))
            mag:SetValue(n)
            mag.loading = false
        end

        if card.RefreshHighlightPreview then
            card.RefreshHighlightPreview()
        end
    end

    addon:SetUIScript(magNumber, 'OnTextChanged', function(_, user)
        if ctx.active() and user then
            stageMag(magNumber:GetText())
        end
    end)

    addon:SetUIScript(magNumber, 'OnEnterPressed', function()
        if ctx.active() then
            local ok, why = owner:FlushFieldEdits()

            if ok then
                owner:Render()
            else
                owner:Message(why)
            end
        end
    end)

    addon:SetUIScript(magNumber, 'OnEscapePressed', function()
        if ctx.active() then
            stageMag(tostring(step.magnification or profile.magnification or 1))
            magNumber:SetText(tostring(step.magnification or profile.magnification or 1))
            magNumber:ClearFocus()
        end
    end)

    addon:SetUIScript(mag, 'OnValueChanged', function(_, value)
        if not mag.loading and ctx.active() then
            magNumber:SetText(string.format('%.3g', value))
            stageMag(tostring(value))
        end
    end)

    mag:EnableMouse(not ctx.readOnly)

    local colorY, colorLabel = row(L['Color'], 54)
    colorLabel:SetWidth(56)
    colorLabel:SetHeight(24)
    local colorX = 64
    local swatch = extra('colorSwatch', nil, function() return addon:CreateWorkbenchButton(card.fields, '', 24) end)
    swatch:ClearAllPoints()
    swatch:SetPoint('TOPLEFT', colorX, -colorY)
    swatch:SetSize(50, 50)

    local reset = extra('colorReset', nil, function()
        return addon:CreateWorkbenchButton(card.fields, L['Default'], 54)
    end)

    reset:ClearAllPoints()
    reset:SetPoint('TOPLEFT', 0, -colorY - 28)
    reset.tooltip = L['Use profile color']
    local fields = {}
    local c = currentColor()
    -- Raw text of each channel box, kept so a half-typed value such as '0.' is not rewritten while the player types.
    local rawChannels = {}
    local rawColor = owner:FieldText(model.id, 'color', baseline)

    if rawColor ~= '' then
        for part in (rawColor .. ','):gmatch('(.-),') do
            rawChannels[#rawChannels + 1] = part
        end
    end

    for index, key in ipairs({ 'r', 'g', 'b', 'a' }) do
        local input = extra('color_' .. key, nil, function() return addon:CreateWorkbenchEditBox(card.fields) end)
        fields[key] = input
        input:ClearAllPoints()

        input:SetPoint(
            'TOPLEFT',
            colorX + 54 + ((index - 1) % 2) * math.floor((width - colorX - 54) / 2),
            -colorY - math.floor((index - 1) / 2) * 26
        )

        input:SetSize(math.floor((width - colorX - 54) / 2) - 2, 24)
        input:SetMaxLetters(10)
        local raw = rawChannels[index] or tostring(c[key])
        rawChannels[index] = raw
        local n = tonumber(raw)
        input:SetText(n and n >= 0 and n <= 1 and string.format('%.3f', n) or raw)
        local valid = n and n >= 0 and n <= 1
        input:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
        input:SetTextInsets(13, 2, 0, 0)
        input.channel = input.channel or input:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
        input.channel:SetPoint('LEFT', 2, 0)
        input.channel:SetText(key:upper())
        input:EnableMouse(not ctx.readOnly)
    end

    -- Fills the swatch with a color.
    -- @param color table  The color { r, g, b, a }.
    local function paint(color)
        swatch.art:SetColorTexture(color.r, color.g, color.b, color.a)
    end

    paint(c)

    addon:SetUIScript(swatch, 'OnEnter', function(control)
        if not alive() then
            return
        end

        paint(currentColor())

        if GameTooltip then
            GameTooltip:SetOwner(control, 'ANCHOR_RIGHT')
            GameTooltip:SetText(L['RGBA channels accept decimal values from 0 to 1.'], 1, 1, 1, 1, true)
        end
    end)

    addon:SetUIScript(swatch, 'OnLeave', function(control)
        if alive() then
            paint(currentColor())
        end
        if GameTooltip and GameTooltip:IsOwned(control) then
            GameTooltip:Hide()
        end
    end)

    local popupBaseline, popupInputs

    -- Color picker callback: stages the chosen color, mirrors it into the four channel boxes and the swatch. On cancel
    -- it restores the text the fields had when the picker opened.
    -- @param r number  The red channel, 0 to 1.
    -- @param g number  The green channel, 0 to 1.
    -- @param b number  The blue channel, 0 to 1.
    -- @param a number  The alpha channel, 0 to 1.
    -- @param canceled boolean|nil  True when the picker was cancelled.
    local function stageColor(r, g, b, a, canceled)
        if not ctx.active() then
            return
        end

        local color = { r = r, g = g, b = b, a = a }
        local restored = canceled and popupBaseline or colorString(color)
        rawChannels = {}

        for part in (restored .. ','):gmatch('(.-),') do
            rawChannels[#rawChannels + 1] = part
        end

        if #rawChannels ~= 4 then
            rawChannels = { tostring(r), tostring(g), tostring(b), tostring(a) }
        end

        for key, input in pairs(fields) do
            local text = canceled and popupInputs and popupInputs[key] or string.format('%.3f', color[key])
            input:SetText(text)
            local n = tonumber(text)
            local valid = n and n >= 0 and n <= 1
            input:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
        end

        owner:StageField(model.id, 'color', canceled and popupBaseline or colorString(color), baseline, L['Color'])
        paint(color)
    end

    for index, key in ipairs({ 'r', 'g', 'b', 'a' }) do
        local input = fields[key]

        addon:SetUIScript(input, 'OnTextChanged', function(_, userInput)
            if not ctx.active() or not userInput then
                return
            end

            if card.colorPicker and card.colorPicker.frame:IsShown() then
                card.colorPicker:Close(true)
            end

            rawChannels[index] = input:GetText()
            local text = table.concat(rawChannels, ',')
            local color = parseColor(text)
            owner:StageField(model.id, 'color', text, baseline, L['Color'])
            input:SetTextColor(1, color and 1 or .35, color and 1 or .35)

            if color then
                paint(color)
            end
        end)

        addon:SetUIScript(input, 'OnEnterPressed', function()
            if ctx.active() then
                local ok, why = owner:FlushFieldEdits()

                if ok then
                    owner:Render()
                else
                    owner:Message(why)
                end
            end
        end)
    end

    card.colorPicker = card.colorPicker or addon:CreateWorkbenchColorPicker(card.fields)

    addon:SetUIScript(swatch, 'OnClick', function()
        if ctx.active() then
            popupBaseline = owner:FieldText(model.id, 'color', baseline)
            popupInputs = {}

            for key, input in pairs(fields) do
                popupInputs[key] = input:GetText()
            end

            card.colorPicker:Open(currentColor(), stageColor, alive, swatch)
        end
    end)

    addon:SetUIScript(reset, 'OnClick', function()
        if ctx.active() then
            local pending = owner.view.pendingFields or {}

            if pending[model.id] then
                pending[model.id].color = nil
            end

            ctx.patch(nil, { 'color' })
        end
    end)

    if ctx.readOnly then
        swatch:Disable()
        reset:Disable()
    else
        swatch:Enable()
        reset:Enable()
    end

    local positionY, positionLabel = row(L['Position'], 58)
    positionLabel:ClearAllPoints()
    positionLabel:SetPoint('TOPLEFT', 0, -positionY - 3)
    local pad = extra('positionPad', nil, function() return addon:CreateWorkbenchPositionPad(card.fields) end)
    pad:ClearAllPoints()
    pad:SetPoint('TOPLEFT', x, -positionY)

    -- Position pad handler: flushes pending edits, then patches the step to the centre (when `center`) or moves the
    -- glow offsets by dx and dy times `amount`.
    -- @param dx number  The horizontal direction (-1, 0 or 1).
    -- @param dy number  The vertical direction (-1, 0 or 1).
    -- @param center boolean  True for the centre button, which resets the point and offsets.
    -- @param amount number  The step size.
    pad:Bind(function(dx, dy, center, amount)
        if not ctx.active() then
            return
        end

        local ox, oy = offsets()
        local ok, why = owner:FlushFieldEdits()

        if not ok then
            owner:Message(why)
            return
        end

        if center then
            ctx.patch({ setpoint = 'CENTER', xoffs = 0, yoffs = 0 })
        else
            ctx.patch({ xoffs = ox + dx * amount, yoffs = oy + dy * amount })
        end
    end, alive, ctx.readOnly)

    for name, button in pairs(pad.buttons) do
        controls['position' .. name] = button
    end

    local inherit = extra('positionReset', nil, function()
        return addon:CreateWorkbenchButton(card.fields, L['Default'], 54)
    end)

    inherit:ClearAllPoints()
    inherit:SetPoint('TOPLEFT', 0, -positionY - 25)
    inherit.tooltip = L['Use profile position']

    addon:SetUIScript(inherit, 'OnClick', function()
        if ctx.active() then
            local ok, why = owner:FlushFieldEdits()

            if ok then
                ctx.patch(nil, { 'setpoint', 'xoffs', 'yoffs' })
            else
                owner:Message(why)
            end
        end
    end)

    if ctx.readOnly then
        inherit:Disable()
    else
        inherit:Enable()
    end

    local afterPosition = ctx.getY()
    -- Horizontal and Vertical side by side, splitting the row beside the pad
    -- (50/50 with a small gap); the letters name them, the tooltips say it in full.
    local fromX, gap, letter = x + 54, 6, 14
    local half = math.max(letter + 30, math.floor((width - fromX - gap) / 2))

    for i, key in ipairs({ 'xoffs', 'yoffs' }) do
        local caption = key == 'yoffs' and L['Vertical offset'] or L['Horizontal offset']
        local left = fromX + (i - 1) * (half + gap)
        ctx.setY(positionY + 14)
        local input = ctx.input(key, caption, step[key] or '', nil, true)
        input:ClearAllPoints()
        input:SetPoint('TOPLEFT', left + letter, -positionY - 14)
        input:SetSize(half - letter, 20)
        input.tooltip = caption

        local axis = extra('axis' .. key, nil, function()
            return card.fields:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        end)

        axis:ClearAllPoints()
        axis:SetPoint('TOPLEFT', left, -positionY - 18)
        axis:SetText(key == 'yoffs' and L['V'] or L['H'])
        axis.tooltip = caption
    end

    ctx.setY(math.max(afterPosition, positionY + 54))
    local announces = {}

    for _, entry in ipairs({
        { 'none', L['None'] },
        { 'partyraid', L['Raid or Party'] },
        { 'party', L['Party Only'] },
        { 'raidwarn', L['Raid Warning'] },
        { 'emote', L['Emote'] },
        { 'local', L['Local Only'] },
    }) do
        announces[#announces + 1] = { value = entry[1], text = entry[2] }
    end

    ctx.choice('announce', L['Announce'], announces, step.announce or 'none', function(value)
        ctx.patch({ announce = value })
    end)

    local ok, media = pcall(LibStub, 'LibSharedMedia-3.0', true)
    local sounds = {}

    if ok and media and media.HashTable then
        local success, found = pcall(media.HashTable, media, 'sound')

        if success and type(found) == 'table' then
            sounds = found
        end
    end

    local entries = { { value = '', text = L['None'] } }
    local names = {}

    for name in pairs(sounds) do
        if type(name) == 'string' then
            names[#names + 1] = name
        end
    end

    table.sort(names)

    for _, name in ipairs(names) do
        entries[#entries + 1] = { value = name, text = name }
    end

    if step.announce_sound and sounds[step.announce_sound] == nil then
        entries[#entries + 1] = { value = step.announce_sound, text = step.announce_sound }
    end

    local sound = ctx.choice('sound', L['Audible Announce'], entries, step.announce_sound or '', function(value)
        if value == '' then
            ctx.patch(nil, { 'announce_sound' })
        else
            ctx.patch({ announce_sound = value })
        end
    end)

    sound:SetWidth(math.max(40, ctx.valueWidth - 26))
    addon:AlignWorkbenchTextLeft(sound, 6)
    local play = extra('soundPreview', 'play')
    play:ClearAllPoints()
    play:SetPoint('LEFT', sound, 'RIGHT', 4, 0)
    play.tooltip = L['Preview sound']

    addon:SetUIScript(play, 'OnClick', function()
        if not alive() then
            return
        end

        local path = step.announce_sound and sounds[step.announce_sound]

        if (type(path) == 'string' or type(path) == 'number') and type(PlaySoundFile) == 'function' then
            local played = PlaySoundFile(path, 'Master')

            if not played then
                owner:Message(L['Sound preview is unavailable.'])
            end
        else
            owner:Message(L['Choose an available sound to preview.'])
        end
    end)

    card.RefreshHighlightPreview()
    return ctx.getY()
end
