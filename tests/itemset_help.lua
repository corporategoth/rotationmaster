local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Help/itemsets.lua')
    return f
end

test('item-set and item-list documents translate whole paragraphs and headings', function()
    local f = fixture()

    for key in pairs(f.translations) do
        f.translations[key] = 'translated:' .. key
    end

    for _, method in ipairs({
        'GetDocument_layout_itemsets_options_help',
        'GetDocument_layout_item_list_help',
        'GetNativeItemListHelp',
    }) do
        local ids = {}
        local rows = f.addon[method](f.addon)
        assert(#rows >= 5)

        for _, entry in ipairs(rows) do
            assert(type(entry.id) == 'string' and not ids[entry.id], 'missing or duplicate help identity')
            ids[entry.id] = true
            assert(entry.title:match('^translated:'), 'untranslated heading')

            assert(
                entry.text == 'translated:Help.ItemSets.' .. entry.id,
                'fragment-built or untranslated paragraph: ' .. entry.id
            )
        end
    end
end)

test('both legacy renderers keep the same localized help records', function()
    local f = fixture()

    for _, pair in ipairs({
        { 'layout_itemsets_options_help', 'GetDocument_layout_itemsets_options_help' },
        { 'layout_item_list_help', 'GetDocument_layout_item_list_help' },
    }) do
        local frame = f.widget('SimpleGroup')
        f.addon[pair[1]](frame)
        local text = F.text(frame)
        local rows = f.addon[pair[2]](f.addon)

        for _, entry in ipairs(rows) do
            assert(text:find(entry.text, 1, true), 'lost ' .. entry.id)
        end

        assert(not text:find('Help.ItemSets.', 1, true), 'locale keys exposed')
        rows[1].text = 'changed'
        assert(f.addon[pair[2]](f.addon)[1].text ~= 'changed', 'shared mutable document')
    end
end)

test('macro examples retain exact button and target syntax without promising rank or readiness', function()
    local f = fixture()
    local rows = f.addon:GetDocument_layout_itemsets_options_help()
    local ids = {}

    for _, row in ipairs(rows) do
        ids[row.id] = row.text
    end

    assert(
        ids.macros and ids.macros:find('RM_Bandages_mouseover', 1, true) and ids.macros:find('/click', 1, true),
        'macro reference missing'
    )

    assert(ids.binding and ids.history and ids.save and ids.items and ids.collections)
end)

test(
    'native child list help documents local Apply and shared list ownership without legacy movement controls',
    function()
        local f = fixture()
        local text = ''
        local rows = f.addon:GetNativeItemListHelp()

        for _, entry in ipairs(rows) do
            text = text .. ' ' .. entry.title .. ' ' .. entry.text
        end

        assert(text:find('parent editor', 1, true) and text:find('shared', 1, true) and text:find('Ctrl-drag', 1, true))

        assert(
            text:find('View Changes', 1, true)
                and text:find('Discard', 1, true)
                and not text:find('Move to Top', 1, true)
        )

        rows[1].text = 'changed'
        assert(f.addon:GetNativeItemListHelp()[1].text ~= 'changed')
    end
)

finish()
