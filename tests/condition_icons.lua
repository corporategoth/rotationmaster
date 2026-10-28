local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local prefix = 'Interface\\AddOns\\rotationmaster\\Assets\\Conditions\\'

local function packaged(icon)
    assert(
        type(icon) == 'string' and icon:sub(1, #prefix) == prefix,
        'condition still uses an unrelated texture: ' .. tostring(icon)
    )

    local name = icon:sub(#prefix + 1)

    assert(
        name:match('^[a-z_]+$') or name:match('^v2/[a-z][a-z0-9%-]*$') or name:match('^v2\\[a-z][a-z0-9%-]*$'),
        'invalid packaged icon name'
    )

    name = name:gsub('\\', '/')
    local file = assert(io.open('Assets/Conditions/' .. name .. '.tga', 'rb'), 'packaged TGA missing: ' .. name)
    local header = file:read(18)
    file:close()
    local width = header:byte(13) + 256 * header:byte(14)
    local height = header:byte(15) + 256 * header:byte(16)

    assert(
        header:byte(3) == 2 and header:byte(17) == 32 and header:byte(18) % 16 == 8,
        'icon is not uncompressed RGBA TGA'
    )

    assert(width == 128 and height == 128, 'icon dimensions are not the expected power of two')
end

-- Conditions that borrow the artwork of a condition of a related meaning until a design of their own exists
-- (Conditions/raid_marks.lua). They are the only conditions allowed to share an icon.
local borrowed = { MARKED = 'CLASSIFICATION', MARK_COUNT = 'DISTANCE_COUNT' }

test('all reviewed Built In declarations use bundled original semantic icons', function()
    local seen, icons = {}, {}

    for _, case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local f = F.new(unpack(case[1]))
        f.addon.delayed_condition = {}

        if case[3] then
            f.env.MI2_GetMobData = function() end
        end

        for path in io.lines('RotationMaster.toc') do
            if path:match('^Conditions/') then
                f.load(path)
            end
        end

        local function inspect(tag, definition)
            packaged(definition.icon)
            assert(definition.icon == f.addon.Artwork.condition[tag], 'declaration bypasses selected artwork: ' .. tag)

            if borrowed[tag] then
                assert(
                    definition.icon == f.addon.Artwork.condition[borrowed[tag]],
                    'a borrowed icon must be the lender icon: ' .. tag
                )

                seen[tag] = true
            else
                assert(
                    not icons[definition.icon] or icons[definition.icon] == tag,
                    'conditions share one icon: ' .. tag
                )

                icons[definition.icon] = tag
                seen[tag] = true
            end
        end

        for tag, definition in pairs(f.addon.definitions) do
            inspect(tag, definition)
        end

        for _, group in pairs(f.addon.delayed_condition) do
            for tag, definition in pairs(group) do
                inspect(tag, definition)
            end
        end
    end

    local count = 0

    for _ in pairs(seen) do
        count = count + 1
    end

    assert(count == 143, 'reviewed icon inventory changed: ' .. count)
end)

test('category defaults follow stable identity while saved custom choices remain exact', function()
    local f = F.new()
    local a = f.addon
    local category = { id = 'b3d7df2c-f257-4a2d-961e-66e49336d109', name = 'Renamed category', conditions = {} }

    assert(
        a:GetConditionCategoryIcon(category) == prefix .. 'v2\\category-combat' and category.icon == nil,
        'default icon required mutating saved category'
    )

    category.icon = 123
    assert(a:GetConditionCategoryIcon(category) == 123, 'explicit saved icon was replaced')
    category.icon = 'My\\CustomIcon'
    assert(a:GetConditionCategoryIcon(category) == category.icon)
    a.conditionDefinitions = { TEST = { icon = 'Custom\\ConditionIcon' } }

    assert(
        a:GetConditionCategoryIcon({ id = 'custom', conditions = { 'TEST' } }) == 'Custom\\ConditionIcon',
        'custom category fallback changed'
    )

    packaged(a:GetConditionCategoryIcon(nil))
    local distinct = {}

    for _, id in ipairs({
        'ALL', 'SWITCH', 'DEFAULT', 'b3d7df2c-f257-4a2d-961e-66e49336d109', 'b8136123-2bda-4230-a77a-89ea2aed3a1a',
        '8034819e-26f5-4f4e-9153-d8cab5e65f31', 'fca4ff75-4085-458a-b5bf-27a6b52f2092',
        'e618608c-92ec-4ae9-9dde-40a397d7beb9', 'fa10aaf8-bc71-480f-9062-c949fd7c74e9'
    }) do
        local icon = a:GetConditionCategoryIcon({ id = id })
        packaged(icon)
        assert(not distinct[icon], 'category icons repeat')
        distinct[icon] = true
    end
end)

test('structural groups have three distinct selected icons', function()
    local f = F.new()
    f.load('Core/conditions.lua')
    local seen = {}

    for _, tag in ipairs({ 'AND', 'OR', 'NOT' }) do
        local icon = f.addon.conditionSpecials[tag].icon
        packaged(icon)
        assert(not seen[icon], 'logic icons repeat')
        seen[icon] = true
    end
end)

test('shared icon chooser exposes all original families and preserves its owner guard', function()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('UI/icon_picker.lua')
    local a = f.addon
    local chosen
    local alive = true

    local picker = a:ShowWorkbenchIconPicker(
        nil,
        function(texture)
            chosen = texture
        end,
        function() return alive end
    )

    local index

    for i, category in ipairs(picker.categories) do
        if category.name == 'Rotation Master' then
            index = i
            assert(#category.icons == 169)

            for _, entry in ipairs(category.icons) do
                packaged(entry.texture)
            end
        end
    end

    assert(index, 'original family category missing')
    picker.categoryButtons[index]:Click()
    picker.buttons[1]:Click()
    assert(chosen and chosen:sub(1, #prefix) == prefix, 'original choice did not commit its packaged path')
    chosen = nil

    picker = a:ShowWorkbenchIconPicker(
        nil,
        function(texture)
            chosen = texture
        end,
        function() return alive end
    )

    picker.categoryButtons[index]:Click()
    alive = false
    picker.buttons[1]:Click()
    assert(chosen == nil, 'stale owner committed an original icon')
end)

finish()
