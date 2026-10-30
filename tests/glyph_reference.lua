-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    dofile('tests/fixtures/spell_editbox.lua')(f)

    local entries = {
        [101] = { name = 'Glyph of Lightning', class = 16, subclass = 7 },
        [102] = { name = 'Glyph of Water', class = 16, subclass = 7 },
        [103] = { name = 'Glyph of Frost', class = 16, subclass = 8 },
        [104] = { name = 'Ordinary Water', class = 0, subclass = 7 },
        [105] = { name = 'Unloaded Glyph' },
    }

    local state = { class = 7, entries = entries, clears = 0 }
    f.env.UnitClass = function() return 'Shaman', 'SHAMAN', state.class end

    f.env.GetNumGlyphSockets = function()
        error('editing consulted glyph runtime socket availability')
    end

    local function key(value)
        if type(value) == 'number' then
            return value
        end

        if type(value) == 'string' then
            local n = tonumber(value) or tonumber(value:match('item:(%d+)'))

            if n then
                return n
            end

            for id, entry in pairs(entries) do
                if entry.name == value then
                    return id
                end
            end
        end
    end

    f.env.C_Item = {
        GetItemInfoInstant = function(value)
            if state.instantFailure then
                error('native item classification failed')
            end

            if
                state.nameUnavailable
                and type(value) == 'string'
                and not tonumber(value)
                and not value:find('item:', 1, true)
            then
                return
            end

            local id = key(value)
            local entry = entries[id]

            if entry then
                return id, 'class', 'subclass', '', id + 1000, entry.class, entry.subclass
            end
        end,
        GetItemInfo = function(value)
            if state.displayFailure then
                error('native item display failed')
            end

            local id = key(value)
            local entry = entries[id]

            if entry then
                return entry.name,
                    '|Hitem:' .. id .. '|h[' .. entry.name .. ']|h',
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    id + 1000
            end
        end,
    }

    f.env.GetItemInfoInstant = function()
        error('failed native classification fell through to legacy')
    end

    f.env.GetItemInfo = function()
        error('failed native display fell through to legacy')
    end

    f.env.C_Spell = { GetSpellInfo = function(id) return { spellID = id, name = 'Unrelated Spell', iconID = 99 } end }
    f.load('Platform/spells.lua')

    f.env.ClearCursor = function()
        state.clears = state.clears + 1
    end

    local glyph = io.open('Platform/glyphs.lua')

    if glyph then
        glyph:close()
        f.load('Platform/glyphs.lua')
    end

    f.load('Core/reference_catalog.lua')

    for id in pairs(entries) do
        assert(a:UpdateReferenceItem(id))
    end

    local w = a:CreateItemEditBox('Glyph_EditBox', 101)
    w:SetText(101)
    local saved, calls = 101, 0

    w:SetCallback('OnEnterPressed', function(_, _, value)
        saved = tonumber(value)
        calls = calls + 1
    end)

    return f, w, state, function() return saved, calls end
end

local function enter(w, text)
    w:SetFocus()
    w.editbox:SetText(text)
    w.editbox:GetScript('OnEnterPressed')(w.editbox)
end

local function drop(f, w, kind, id)
    f.env.GetCursorInfo = function() return kind, id, 'spell', id end
    w.editbox:GetScript('OnReceiveDrag')(w.editbox)
end

test('glyph native field displays item metadata and accepts current-class item IDs names and links', function()
    local f, w, state, saved = fixture()

    assert(
        w:GetText() == 'Glyph of Lightning' and w:GetReferenceID() == 101,
        'glyph field did not display item identity'
    )

    assert(w.editbox.rmDropHint:GetText() == 'Search or drag an item here', 'glyph field advertised a spell cursor')

    for _, text in ipairs({ '102', 'Glyph of Water', '|cffabcdef|Hitem:102|h[Glyph of Water]|h|r', 'item:102' }) do
        enter(w, text)

        assert(
            saved() == 102 and w:GetReferenceID() == 102 and w:GetText() == 'Glyph of Water',
            'valid glyph input rejected: ' .. text
        )
    end
end)

test('glyph native suggestions contain only readable current-class glyph items and use item tooltips', function()
    local f, w, state, saved = fixture()
    local owner, link

    f.env.GameTooltip = {
        SetOwner = function(_, v)
            owner = v
        end,
        SetHyperlink = function(_, v)
            link = v
        end,
        IsOwned = function(_, v) return owner == v end,
        Hide = function()
            owner = nil
        end,
    }

    w:SetFocus()
    w.editbox:SetText('')
    local popup = w.rmSpellPopup

    assert(
        popup.rows[1].itemID == 101 and popup.rows[2].itemID == 102 and not popup.rows[3]:IsShown(),
        'glyph menu included other-class non-glyph or unknown metadata'
    )

    popup.rows[2]:GetScript('OnEnter')(popup.rows[2])
    assert(link == 'item:102')
    popup.rows[2]:GetScript('OnMouseDown')(popup.rows[2], 'LeftButton')
    assert(saved() == 102 and not popup:IsShown())
end)

test('glyph typed and cursor rejections preserve selection and do not consume spell or wrong-class cursors', function()
    local f, w, state, saved = fixture()

    for _, text in ipairs({
        '103',
        'Glyph of Frost',
        '|Hitem:103|h[Glyph of Frost]|h',
        '104',
        'Ordinary Water',
        '105',
        'Unloaded Glyph',
    }) do
        enter(w, text)
        assert(saved() == 101, 'invalid glyph text replaced saved selection: ' .. text)
        w:ClearFocus()
        assert(w:GetReferenceID() == 101)
    end

    for _, cursor in ipairs({
        { 'item', 103 },
        { 'item', 104 },
        { 'item', 105 },
        { 'spell', 102 },
        { 'petaction', 102 },
    }) do
        drop(f, w, unpack(cursor))
        assert(saved() == 101 and state.clears == 0)
    end

    drop(f, w, 'item', 102)
    assert(saved() == 102 and state.clears == 1)
end)

test(
    'fresh glyph classification rejects stale menu rows and loader records after native failure or class changes',
    function()
        local f, w, state, saved = fixture()
        w:SetFocus()
        w.editbox:SetText('Glyph of Water')
        local row = w.rmSpellPopup.rows[1]
        assert(row.itemID == 102)
        state.instantFailure = true
        row:GetScript('OnMouseDown')(row, 'LeftButton')
        assert(saved() == 101, 'stale glyph menu bypassed failed native classification')
        enter(w, '102')
        drop(f, w, 'item', 102)
        assert(saved() == 101 and state.clears == 0)
        w.editbox:SetText('Glyph')
        assert(not w.rmSpellPopup.rows[1]:IsShown(), 'index revived glyph choices after failed native classification')
        state.instantFailure = false
        state.class = nil
        enter(w, '102')
        drop(f, w, 'item', 102)

        assert(
            saved() == 101 and state.clears == 0 and not w.rmSpellPopup.rows[1]:IsShown(),
            'unknown player class accepted an indexed glyph'
        )

        state.class = 8
        w.editbox:SetText('Glyph')
        assert(w.rmSpellPopup.rows[1].itemID == 103 and not w.rmSpellPopup.rows[2]:IsShown())
        enter(w, '102')
        assert(saved() == 101, 'player class change retained old glyph acceptance')
        enter(w, '103')
        assert(saved() == 103)
    end
)

test('restricted glyph classification and native display failure cannot revive indexed item suggestions', function()
    local f, w, state, saved = fixture()
    local secret = {}
    f.env.canaccessvalue = function(value) return not rawequal(value, secret) end
    state.entries[102].subclass = secret
    enter(w, '102')
    drop(f, w, 'item', 102)
    assert(saved() == 101 and state.clears == 0)
    state.entries[102].subclass = 7
    state.displayFailure = true
    w:SetFocus()
    w.editbox:SetText('102')
    assert(not w.rmSpellPopup.rows[1]:IsShown(), 'index revived failed native display metadata')
    w:ClearFocus()
    assert(saved() == 101)
end)

test('glyph menu filters before the shared result limit and exact indexed-name fallback stays classified', function()
    local f, w, state, saved = fixture()

    for i = 1, 20 do
        local id = 200 + i
        local name = string.format('A wrong glyph %02d', i)
        state.entries[id] = { name = name, class = 16, subclass = 8 }
        assert(f.addon:UpdateReferenceItem(id))
    end

    w:SetFocus()
    w.editbox:SetText('')
    local popup = w.rmSpellPopup

    assert(
        popup.rows[1].itemID == 101 and popup.rows[2].itemID == 102 and not popup.rows[3]:IsShown(),
        'other-class rows consumed the shared menu limit'
    )

    state.nameUnavailable = true
    enter(w, 'Glyph of Water')
    assert(saved() == 102, 'readable indexed name did not resolve a classified glyph')
    enter(w, 'Glyph of Frost')
    assert(saved() == 102, 'indexed-name fallback bypassed glyph class filtering')
end)

test('glyph cursor remains owned when classification fails between drop preflight and commit', function()
    local f, w, state, saved = fixture()
    local instant = f.env.C_Item.GetItemInfoInstant
    local reads = 0

    f.env.C_Item.GetItemInfoInstant = function(...)
        reads = reads + 1

        if reads > 1 then
            error('classification became unavailable')
        end

        return instant(...)
    end

    drop(f, w, 'item', 102)
    local id, calls = saved()

    assert(
        reads == 2 and id == 101 and calls == 0 and state.clears == 0,
        'rejected glyph commit consumed the item cursor'
    )

    f.env.C_Item.GetItemInfoInstant = instant
    drop(f, w, 'item', 102)
    assert(saved() == 102 and state.clears == 1, 'valid glyph drop no longer consumed its cursor')
end)

test('glyph scope leaves ordinary item inventory and spell provider defaults unchanged', function()
    local f, w, state, saved = fixture()
    local a = f.addon
    assert(a:GetReferenceProvider('Glyph_EditBox').kind == 'item')
    assert(a:GetReferenceProvider('Item_EditBox').resolve('103') == 103)
    a.bagContents = { [104] = 1 }
    local inventory = a:GetReferenceProvider('Inventory_EditBox')
    assert(inventory.resolve('104', { inventory = true }) == 104 and not inventory.resolve('102', { inventory = true }))
    assert(a:GetReferenceProvider('Spell_EditBox').kind == 'spell' and a:GetReferenceProvider().kind == 'spell')
end)

finish()
