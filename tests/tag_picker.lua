-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('Data/plain.lua')
    f.load('Data/tags.lua')
    local h = io.open('UI/tag_picker.lua')

    if h then
        h:close()
        f.load('UI/tag_picker.lua')
    end

    return f, create('Frame')
end

test('shared tag input suggests existing labels adds on Enter and removes individual pills', function()
    local f, parent = fixture()
    local a = f.addon
    assert(a.CreateRotationTagPicker)
    local saved = {}

    local picker = a:CreateRotationTagPicker(parent, {
        allowCustom = true,
        available = function() return { 'PVP', 'Frost' } end,
        valid = function() return true end,
        changed = function(tags)
            saved = tags
        end,
    })

    picker:SetWidth(350)
    picker:SetTags({ 'Solo' })
    picker.input:SetText('pv')
    picker.input.scripts.OnTextChanged(picker.input, true)
    assert(picker.menu.rows[1]:GetText() == 'PVP')
    picker.input:SetFocus()
    picker.menu.rows[1]:Click()
    assert(saved[2] == 'PVP' and not picker.input:HasFocus(), 'tag selection retained search focus')
    picker.input:SetText('MyLittlePony')
    picker.input.scripts.OnEnterPressed(picker.input)
    assert(saved[3] == 'MyLittlePony')
    picker.chips[2]:Click()
    assert(table.concat(saved, ',') == 'Solo,MyLittlePony')
end)

test('filter input cannot invent labels and stale selections cannot mutate another profile', function()
    local f, parent = fixture()
    local calls = 0
    local valid = true
    assert(f.addon.CreateRotationTagPicker)

    local picker = f.addon:CreateRotationTagPicker(parent, {
        allowCustom = false,
        available = function() return { 'PVP' } end,
        valid = function() return valid end,
        changed = function()
            calls = calls + 1
        end,
    })

    picker:SetWidth(240)
    picker.input:SetText('Unknown')
    picker.input.scripts.OnEnterPressed(picker.input)
    assert(calls == 0)
    picker.input:SetText('p')
    picker.input.scripts.OnTextChanged(picker.input, true)
    local stale = picker.menu.rows[1].scripts.OnClick
    valid = false
    stale()
    assert(calls == 0)
end)

test('dropdown tag colors remain editable for selected tags and tint the pill border', function()
    local f, parent = fixture()
    local a = f.addon
    f.load('UI/color_picker.lua')
    local rgba = { r = .2, g = .3, b = .4, a = 1 }

    local picker = a:CreateRotationTagPicker(parent, {
        allowCustom = false,
        available = function() return { 'PVP' } end,
        valid = function() return true end,
        color = function() return rgba end,
        setColor = function(_, value)
            rgba = value
        end,
    })

    picker:SetTags({ 'PVP' })
    picker:Suggest()
    local row = picker.menu.rows[1]

    assert(
        row.colorButton and row.colorButton:IsShown() and not picker.chips[1].colorButton,
        'color control is not confined to dropdown'
    )

    row.colorButton:Click()
    assert(picker.colorPicker.frame:IsShown())
    picker.colorPicker:Choose(0, 1, 1, 1)
    assert(rgba.r == 1 and rgba.g == 0 and rgba.b == 0 and #picker.tags == 1)

    assert(
        picker.chips[1].pillDecoration.border[1].color[1] == 1
            and picker.chips[1].pillDecoration.border[1].color[2] == 0
    )
end)

test('tag pill border retains the tag RGBA after layout and pointer leave', function()
    local f, parent = fixture()
    local rgba = { r = .2, g = .6, b = .9, a = .4 }

    local picker = f.addon:CreateRotationTagPicker(parent, {
        available = function() return { 'PVP' } end,
        color = function() return rgba end,
    })

    picker:SetTags({ 'PVP' })
    picker:SetWidth(280)
    local chip = picker.chips[1]
    chip.scripts.OnLeave()

    for _, edge in ipairs(chip.pillDecoration.border) do
        assert(
            edge.color[1] == rgba.r and edge.color[2] == rgba.g and edge.color[3] == rgba.b and edge.color[4] == rgba.a,
            'tag border does not match tag color'
        )
    end
end)

finish()
