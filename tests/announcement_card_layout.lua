-- Actual announcement settings/cards; native frame primitives are modeled.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/announcement_series_ui.lua'))
local text = h:read('*a')
h:close()

local fixture, id, card, entry, open, data, view = assert(loadstring(
    assert(text:match('^(.-)\ntest%(')) .. '\nreturn fixture,id,card,entry,open,data,view',
    '@announcement-card-layout-fixture'
))()

local function anchor(frame)
    local point, owner, relative, x, y = frame:GetPoint(1)

    if type(owner) == 'number' then
        x, y, owner, relative = owner, relative, frame:GetParent(), point
    end

    return point, owner or frame:GetParent(), relative or point, x or 0, y or 0
end

local function entered(field, value)
    field:SetText(value)
    field:GetScript('OnTextChanged')(field, true)
end

local function rightBox(frame, row)
    local point, parent, _, x, y = anchor(frame)
    assert(point == 'TOPRIGHT' and parent == row, 'control is not in the card right rail')
    return row:GetWidth() + x - frame:GetWidth(), row:GetWidth() + x, -y, -y + frame:GetHeight()
end

test('output Help copy and trash form a nonoverlapping right rail inside the card', function()
    local _, a, parent = fixture()
    local p = open(a, parent, entry({ card(2, 'A'), card(3, 'B') }))

    for i, row in ipairs(view(p).rows) do
        local key = 'entry1output' .. i
        local help, copy, trash = p.fields[key .. 'help'], p.fields[key .. 'duplicate'], p.fields[key .. 'remove']
        local hl, hr, ht, hb = rightBox(help, row)
        local cl, cr, ct, cb = rightBox(copy, row)
        local tl, tr, tt, tb = rightBox(trash, row)

        assert(
            math.abs(hr - cr) <= 1 and math.abs(cr - tr) <= 1 and hb <= ct and cb <= tt,
            'card actions remain a horizontal cluster'
        )

        assert(ht >= 0 and tb <= row:GetHeight() and hl >= 0 and tl >= 0 and help.icon:GetWidth() == 18)
        assert(row.body:GetWidth() + 26 < hl, 'body fields enter the action rail')
    end
end)

test('green gray Enabled pill sits directly left of Help with no caption row or header overlap', function()
    local _, a, parent = fixture()
    local p = open(a, parent, entry({ card(2, 'A') }))
    local row = view(p).rows[1]
    local pill = p.fields.entry1enabled
    local help = p.fields.entry1output1help

    assert(
        pill:GetParent() == row and pill.pillDecoration and pill.selected == true,
        'Enabled remains a detached body toggle'
    )

    local l, r, t, b = rightBox(pill, row)
    local hl, _, ht, hb = rightBox(help, row)
    assert(r < hl and hl - r <= 6 and math.abs((t + b) - (ht + hb)) <= 2, 'Enabled is not immediately left of Help')

    assert(
        not row.header:IsShown() and not (row.header.grip and row.header.grip:IsShown()),
        'card still shows a title or grip'
    )

    for _, label in ipairs(p.pool.labels or {}) do
        assert(not label:IsShown() or label:GetText() ~= 'Output state', 'separate state caption row remains')
    end

    pill:Click()

    assert(
        data(p).outputs[1].disabled == true
            and p.fields.entry1enabled.selected == false
            and p.fields.entry1enabled:GetText() == 'Disabled'
    )

    assert(a.db.profile.announces[1].outputs[1].disabled == nil)
    p.fields.entry1enabled:Click()
    assert(data(p).outputs[1].disabled == false and p.fields.entry1enabled.selected == true and not view(p).drag)
end)

test('the selected announcement has no title: Name is the first row beside Enabled and the trash', function()
    local _, a, parent = fixture()
    local value = entry({ card(2, 'A') })
    value.name = 'Resurrected'
    local p = open(a, parent, value)

    for _, t in ipairs(p.pool.text or {}) do
        assert(not t:IsShown() or t:GetText() ~= 'Resurrected', 'the announcement name is repeated as a heading')
    end

    local name, pill, trash = p.fields.entry1name, p.fields.enabled1, p.fields.delete1
    local point, _, _, x, y = anchor(name)
    local _, _, _, px, py = anchor(pill)
    local _, _, _, tx, ty = anchor(trash)

    assert(
        point == 'TOPLEFT' and y >= -6 and math.abs(y - py) <= 6 and math.abs(y - ty) <= 6,
        'Name is not on the first row with Enabled and the trash'
    )

    assert(x + name:GetWidth() <= p.width + px - pill:GetWidth() - 4, 'Name runs under the Enabled pill')
end)

test('condition summary is the full width clickable wrapped box rather than a separate Edit action', function()
    local _, a, parent = fixture()
    local output = card(2, 'A')
    output.conditions = { type = 'AND', value = {} }
    local p = open(a, parent, entry({ output }))
    local c = p.fields.entry1conditions
    local row = view(p).rows[1]

    assert(
        c:GetText() ~= 'Edit announcement conditions' and c:GetText() ~= '' and c:GetParent() == row.body,
        'summary still lives outside the condition control'
    )

    assert(
        c:GetWidth() == row.body:GetWidth() and c:GetHeight() >= 24 and c:GetFontString().wordWrap,
        'condition box does not span/wrap the card body'
    )

    assert(select(1, c:GetFontString():GetPoint(1)) == 'LEFT', 'condition summary is not left anchored')
    local pending

    a.ShowConditionEditor = function(_, _, _, draft, callback, current, options)
        pending = { draft = draft, callback = callback, current = current, options = options }
    end

    c:Click()
    assert(pending and pending.current() and pending.options.announcementTarget and not view(p).drag)
end)

test('pill and condition click flush pending text only into draft and Apply or Discard stays authoritative', function()
    local _, a, parent = fixture()
    local saved = entry({ card(2, 'Original') })
    local p = open(a, parent, saved)
    entered(p.fields.entry1text, 'Edited')
    p.fields.entry1enabled:Click()
    assert(data(p).outputs[1].value == 'Edited' and data(p).outputs[1].disabled == true)
    assert(saved.outputs[1].value == 'Original' and saved.outputs[1].disabled == nil)
    p.fields.cancel:Click()
    assert(a.db.profile.announces[1].outputs[1].value == 'Original' and not p:IsSettingsDraftDirty())
    entered(p.fields.entry1text, 'Applied')
    local pending

    a.ShowConditionEditor = function(_, _, _, draft, callback, current)
        pending = { draft = draft, callback = callback, current = current }
    end

    p.fields.entry1conditions:Click()
    assert(pending and pending.current() and data(p).outputs[1].value == 'Applied')
    pending.draft.type = 'AND'
    pending.draft.value = {}
    pending.callback(true)
    assert(data(p).outputs[1].conditions.type == 'AND' and not a.db.profile.announces[1].outputs[1].conditions)
    p.fields.apply:Click()

    assert(
        a.db.profile.announces[1].outputs[1].value == 'Applied'
            and a.db.profile.announces[1].outputs[1].conditions.type == 'AND'
    )
end)

test('pooled pill and child callbacks cannot mutate replacement cards or a retired redraw', function()
    local _, a, parent = fixture()
    local p = open(a, parent, entry({ card(2, 'A'), card(3, 'B') }))
    local old = p.fields.entry1enabled:GetScript('OnClick')
    p:Draw()
    old()
    assert(not data(p).outputs[1].disabled)
    local pending

    a.ShowConditionEditor = function(_, _, _, draft, callback, current)
        pending = { draft = draft, callback = callback, current = current }
    end

    p.fields.entry1conditions:Click()
    local replacement = card(9, 'New')
    data(p).outputs[1] = replacement
    assert(not pending.current())
    pending.draft.type = 'AND'
    pending.draft.value = {}
    pending.callback(true)
    assert(not replacement.conditions)
    p:Draw()
    old = p.fields.entry1enabled:GetScript('OnClick')

    p.FlushEdits = function()
        data(p).outputs[1] = card(10, 'After flush')
        return true
    end

    old()
    assert(data(p).outputs[1].disabled == nil)
end)

test('legacy draw and Help stay clean while rail duplicate delete arrows and drag keep staged order', function()
    local _, a, parent = fixture()
    local saved = { id = id(1), type = 'spell', spell = 403, event = 'SUCCEEDED', announce = 'local', value = 'Legacy' }
    local p = open(a, parent, saved)
    assert(not data(p).outputs and not p:IsSettingsDraftDirty())
    local flush = p.FlushEdits

    p.FlushEdits = function()
        error('Help must not flush')
    end

    p.fields.entry1output1help:Click()
    p.FlushEdits = flush
    assert(not data(p).outputs and not p:IsSettingsDraftDirty())
    p.fields.entry1output1duplicate:Click()
    assert(#data(p).outputs == 2 and saved.outputs == nil)
    p.fields.entry1output2up:Click()
    local v = view(p)
    v:BeginDrag(1)
    assert(v:Drop(3))
    p.fields.entry1output1remove:Click()
    assert(#data(p).outputs == 1 and saved.outputs == nil)
end)

test('parent header orders Enabled then Delete at the right edge at wide and narrow widths', function()
    for _, width in ipairs({ 1000, 560 }) do
        local _, a, parent = fixture()
        parent:SetWidth(width)
        local p = open(a, parent, entry({ card(2, 'A') }))
        local trash, pill = p.fields.delete1, p.fields.enabled1
        assert(not p.fields.announce_help, 'Announces still draws its own page Help')
        local tl, tr = rightBox(trash, p.child)
        local pl, pr = rightBox(pill, p.child)
        assert(tr == p.child:GetWidth() and pr <= tl - 3, 'parent header controls remain in the wrong order')
        assert(pl >= 0 and pill:GetHeight() == 18)
        pill:Click()

        assert(
            data(p).disabled == true
                and data(p).outputs[1].disabled == nil
                and a.db.profile.announces[1].disabled == nil
        )

        p.fields.apply:Click()
        assert(a.db.profile.announces[1].disabled == true)
    end
end)

test('creation and empty panes leave retired parent controls inert', function()
    local _, a, parent = fixture()
    local p = open(a, parent, entry({ card(2, 'A') }))
    local oldEnabled = p.fields.enabled1:GetScript('OnClick')
    local oldDelete = p.fields.delete1:GetScript('OnClick')
    local confirmations = 0

    a.ConfirmSettingsDeletion = function()
        confirmations = confirmations + 1
    end

    p.fields.new_collection:Click()
    assert(p.creating and not p.fields.enabled1 and not p.fields.delete1)
    oldEnabled()
    oldDelete()
    assert(not data(p).disabled and confirmations == 0)
    local _, b, other = fixture()
    local empty = open(b, other, nil)
    empty.fields.cancel:Click()
    assert(not empty.fields.delete and not empty.fields.enabled1)
end)

test('long condition summary grows its box and card without entering the following card', function()
    local _, a, parent = fixture()
    a.DescribeCondition = function() return string.rep('Long condition summary ', 60) end
    local p = open(a, parent, entry({ card(2, 'A'), card(3, 'B') }))
    local first = view(p).rows[1]
    local box = p.fields.entry1conditions

    assert(
        box:GetHeight() >= box:GetFontString():GetStringHeight() + 8 and box:GetHeight() > 24,
        'wrapped summary is clipped by a fixed box'
    )

    local _, _, _, _, y = anchor(box)
    assert(-y + box:GetHeight() + 8 <= first:GetHeight(), 'summary extends outside its own card')
    assert(view(p).rows[2].dragY >= first.dragY + first:GetHeight() + 12, 'following card overlaps wrapped summary')
end)

test(
    'data-only custom condition literal color link and texture tokens survive in the box without executing code',
    function()
        for _, case in ipairs({
            { 'literal |cffff0000red|r', 'literal ||cffff0000red||r' },
            { 'literal |Hspell:403|h[Lightning Bolt]|h', 'literal ||Hspell:403||h[Lightning Bolt]||h' },
            {
                'literal |TInterface\\Icons\\Spell_Nature_Lightning:16|t',
                'literal ||TInterface\\Icons\\Spell_Nature_Lightning:16||t',
            },
        }) do
            local _, a, parent = fixture()
            local callbacks = 0

            local function forbidden()
                callbacks = callbacks + 1
                error('CUSTOM_DESCRIPTION_CALLBACK_MUST_NOT_RUN')
            end

            a:RegisterCondition('CUSTOM', {
                customCode = true,
                description = 'Custom saved value',
                print = forbidden,
                valid = forbidden,
                evaluate = forbidden,
                widget = forbidden,
                help = forbidden,
            })

            a.printCondition = forbidden
            local output = card(2, 'A')
            output.conditions = { type = 'CUSTOM', value = case[1] }
            local p = open(a, parent, entry({ output }))
            local box = p.fields.entry1conditions

            assert(
                box:GetText():find(case[2], 1, true),
                'literal escaped tokens were removed from the condition summary'
            )

            assert(
                callbacks == 0
                    and data(p).outputs[1].conditions.value == case[1]
                    and a.db.profile.announces[1].outputs[1].conditions.value == case[1]
                    and not p:IsSettingsDraftDirty()
            )
        end
    end
)

finish()
