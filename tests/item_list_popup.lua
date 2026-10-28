local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local a = f.addon
    a.pretty_name = 'Rotation Master'
    a.db.char = {}
    a.db.profile.itemsets = {}
    a.db.global.itemsets = {}

    f.env.GetItemInfo = function(id)
        id = tonumber(id)

        if id and id > 0 then
            return 'Item ' .. id, 'item:' .. id, nil, nil, nil, nil, nil, nil, nil, 100 + id
        end
    end

    f.env.GetItemCount = function() return 1 end

    for _, path in ipairs({
        'UI/settings_ordered.lua',
        'UI/settings_history.lua',
        'UI/settings_unsaved.lua',
        'UI/settings_form.lua',
        'UI/settings_transfer.lua',
    }) do
        f.load(path)
    end

    local file = io.open('UI/item_list_popup.lua')

    if file then
        file:close()
        f.load('UI/item_list_popup.lua')
    end

    return f, a
end

local function open(a, items, accept, changed, closed, options, kind)
    assert(a.OpenItemListPopup, 'native item list popup missing')

    return assert(a:OpenItemListPopup(
        'Selected list',
        kind or 'Item_EditBox',
        items,
        accept or function() return true end,
        changed,
        closed,
        options
    ))
end

local function enter(c, value)
    c:SetText(tostring(value))
    c.scripts.OnTextChanged(c, true)
    c.scripts.OnEnterPressed(c)
end

local function equal(a, b)
    for k, v in pairs(a) do
        assert(b[k] == v)
    end

    for k, v in pairs(b) do
        assert(a[k] == v)
    end
end

test('native popup edits detached arrays then applies once to the exact supplied table', function()
    local f, a = fixture()
    local lib = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'native popup requested retired GUI')
        return lib(name, ...)
    end

    local items = { 1, 2 }
    local calls, closes = 0, 0
    local original = items

    local d = open(
        a,
        items,
        nil,
        function()
            calls = calls + 1
        end,
        function(widget)
            closes = closes + 1
            assert(widget.rmWidget)
            a:ReleaseConditionWidget(widget)
        end
    )

    assert(d.rmActive and d.form and d.form.fields.apply and d.form.fields.cancel and not d.form.transactionKeys)
    local anchor = d.form.frame:GetParent().point
    assert(anchor[1] == 'BOTTOMRIGHT' and anchor[3] >= 28, 'form controls overlap the shared status bar')
    enter(d.form.fields.item1, 3)
    equal(items, { 1, 2 })
    assert(calls == 0)
    d.form.fields.apply:Click()
    assert(items == original)
    equal(items, { 3, 2 })
    assert(calls == 1 and closes == 1 and not d.rmActive)
end)

test('Discard and clean close leave custom and shared named-set arrays unchanged', function()
    local _, a = fixture()
    local items = { 1, 2 }
    a.db.global.itemsets.shared = { name = 'Shared', items = items }
    local calls, closed = 0, 0

    local d = open(
        a,
        items,
        nil,
        function()
            calls = calls + 1
        end,
        function()
            closed = closed + 1
        end
    )

    d.form.fields.item2up:Click()
    d.form.fields.cancel:Click()
    equal(items, { 1, 2 })
    assert(a.db.global.itemsets.shared.items == items and calls == 0 and closed == 1)

    d = open(a, items, nil, nil, function()
        closed = closed + 1
    end)

    d:Hide()
    assert(closed == 2 and not d.rmActive)
end)

test('dirty close offers Apply Discard Cancel and cancel keeps edits open', function()
    local _, a = fixture()
    local items = { 1 }
    local d = open(a, items)
    enter(d.form.fields.item1, 2)
    d:Hide()
    local prompt = d.form.prompt
    assert(prompt and prompt.frame:IsShown() and prompt.discard)
    prompt.cancel:Click()
    assert(d.rmActive and d.form.fields.item1:GetText() == 'Item 2')
    equal(items, { 1 })
    d:Hide()
    d.form.prompt.discard:Click()
    assert(not d.rmActive)
    equal(items, { 1 })
    d = open(a, items)
    enter(d.form.fields.item1, 2)
    d:Hide()
    d.form.prompt.accept:Click()
    equal(items, { 2 })
    assert(not d.rmActive)
end)

test('Apply rejects concurrent list changes and retired profile or owner callbacks', function()
    local _, a = fixture()
    local items = { 1 }
    local live = true
    local changes = 0

    local d = open(
        a,
        items,
        nil,
        function()
            changes = changes + 1
        end,
        nil,
        { valid = function() return live end }
    )

    enter(d.form.fields.item1, 2)
    items[1] = 3
    d.form.fields.apply:Click()
    equal(items, { 3 })
    assert(d.rmActive and changes == 0)
    d:Close()

    d = open(
        a,
        items,
        nil,
        function()
            changes = changes + 1
        end,
        nil,
        { valid = function() return live end }
    )

    enter(d.form.fields.item1, 2)
    local stale = d.form.fields.apply.scripts.OnClick
    live = false
    stale()
    equal(items, { 3 })
    assert(changes == 0)
    d:Hide()
    live = true
    d = open(a, items)
    enter(d.form.fields.item1, 2)
    stale = d.form.fields.apply.scripts.OnClick
    a.db.profile = {}
    stale()
    equal(items, { 3 })
    d:Hide()
    assert(not d.rmActive)
end)

test('ordered rows add remove move and history remain draft-only with unsaved review', function()
    local _, a = fixture()
    local items = { 1, 2 }
    local d = open(a, items)
    local p = d.form
    assert(not p.fields.item1up:IsEnabled() and not p.fields.item2down:IsEnabled())
    p.fields.item2up:Click()

    assert(
        d.draft[1] == 2
            and p.fields.undo:IsEnabled()
            and p.ordered.items_popup.rows[1].rmUnsaved
            and p.fields.apply.rmUnsaved
    )

    equal(items, { 1, 2 })
    p.fields.undo:Click()
    equal(d.draft, { 1, 2 })
    p.fields.redo:Click()
    equal(d.draft, { 2, 1 })
    p.fields.item1remove:Click()
    equal(d.draft, { 1 })
    enter(p.fields.new_item, 3)
    p.fields.add_item:Click()
    equal(d.draft, { 1, 3 })
    assert(p.fields.viewChanges and p.fields.viewChanges:IsEnabled())
    local reviewed = false

    a.ShowWorkbenchDraftChanges = function(_, owner, kind, before, after, valid)
        reviewed = true
        assert(owner == p and kind == 'profile' and valid())
        equal(before.items, { 1, 2 })
        equal(after.items, { 1, 3 })
    end

    p.fields.viewChanges:Click()
    assert(reviewed)
    p.fields.cancel:Click()
    equal(items, { 1, 2 })
end)

test('all text add selection and cursor paths honor supplied acceptance without deletion', function()
    local f, a = fixture()
    local items = { 1 }
    local d = open(a, items, function(id) return id ~= 2 end)
    local p = d.form
    enter(p.fields.item1, 2)
    assert(d.draft[1] == 1 and not p:FlushEdits())
    enter(p.fields.item1, 3)
    assert(d.draft[1] == 3)
    enter(p.fields.new_item, 2)
    p.fields.add_item:Click()
    equal(d.draft, { 3 })
    p.fields.new_item.scripts.OnEscapePressed(p.fields.new_item)
    f.env.GetCursorInfo = function() return 'item', 2 end
    local cleared = 0

    f.env.ClearCursor = function()
        cleared = cleared + 1
    end

    p.fields.item1.scripts.OnReceiveDrag(p.fields.item1)
    assert(d.draft[1] == 3 and cleared == 0)
    local provider = a:GetReferenceProvider('item')
    provider.index(2)
    local c = p.fields.item1
    c:SetText('Item 2')
    c.scripts.OnTextChanged(c, true)
    assert(p.menu and p.menu.rows[1])
    p.menu.rows[1]:Click()
    assert(d.draft[1] == 3 and not p:FlushEdits())
    d:Close()
    equal(items, { 1 })
end)

test('reference acceptance hook also enforces same-display parses and keeps cursor on rejection', function()
    local f, a = fixture()
    local frame = f.env.CreateFrame('Frame')
    frame:SetSize(700, 450)
    local p = a:CreateSettingsForm(frame)
    local changed = 0

    p:Open(function(form)
        form:Reference('item', 'Item', 1, 'Item_EditBox', { accept = function() return false end }, function()
            changed = changed + 1
        end)
    end)

    enter(p.fields.item, 1)
    assert(changed == 0 and not p:FlushEdits())
    f.env.GetCursorInfo = function() return 'item', 2 end

    f.env.ClearCursor = function()
        error('rejected cursor cleared')
    end

    p.fields.item.scripts.OnReceiveDrag(p.fields.item)
    assert(changed == 0)
    p:Release()
end)

test('inventory reference kind is retained on every popup row and add input', function()
    local _, a = fixture()
    local resolve = a.GetReferenceProvider
    local observed = 0

    a.GetReferenceProvider = function(self, kind)
        if kind == 'Inventory_EditBox' then
            observed = observed + 1
        end

        return resolve(self, kind)
    end

    local d = open(a, { 1, 2 }, nil, nil, nil, nil, 'Inventory_EditBox')
    assert(observed >= 3)
    d:Close()
end)

test('inventory restrictions and actual ordered drag remain local until Apply', function()
    local f, a = fixture()
    a.bagContents = { [1] = 1, [3] = 1, [4] = 1 }
    local items = { 1, 3, 4 }
    local d = open(a, items, nil, nil, nil, nil, 'Inventory_EditBox')
    local p = d.form
    enter(p.fields.new_item, 2)
    assert(not p:FlushEdits() and #d.draft == 3)
    p.fields.new_item.scripts.OnEscapePressed(p.fields.new_item)
    local view = p.ordered.items_popup
    view:BeginDrag(1)
    assert(view:Drop(4))
    equal(d.draft, { 3, 4, 1 })
    equal(items, { 1, 3, 4 })
    a.bagContents[1] = nil
    p.fields.apply:Click()
    assert(d.rmActive)
    equal(items, { 1, 3, 4 })
    d:Close()
end)

test('real View Changes remains read-only and closes with its popup owner', function()
    local _, a = fixture()
    local items = { 1 }
    local d = open(a, items)
    enter(d.form.fields.item1, 3)
    d.form.fields.viewChanges:Click()
    local comparison = d.form.draftComparisonOwner.comparison
    assert(comparison.frame:IsShown())
    equal(items, { 1 })
    d:Close()
    assert(not comparison.frame:IsShown())
end)

test('recycled leases and explicit release reject stale input close and metadata callbacks', function()
    local _, a = fixture()
    local items = { 1 }
    local closed = 0

    local d = open(a, items, nil, nil, function()
        closed = closed + 1
    end)

    local stale = d.form.fields.apply.scripts.OnClick
    local close = d.closeButton.scripts.OnClick
    local input = d.form.fields.item1.scripts.OnEditFocusGained
    d:Close()
    assert(closed == 1)
    local nextItems = { 3 }
    local reused = open(a, nextItems)
    assert(reused == d)
    stale()
    close()
    input()
    assert(reused.rmActive)
    equal(items, { 1 })
    equal(nextItems, { 3 })
    a:ReleaseConditionWidget(reused)
    assert(not reused.form.active)
end)

test('explicit release cannot commit through a queued native hide callback', function()
    local _, a = fixture()
    local items = { 1 }
    local calls = 0

    local d = open(a, items, nil, function()
        calls = calls + 1
    end)

    enter(d.form.fields.item1, 2)
    local apply = d.form.fields.apply:GetScript('OnClick')
    local hide = d.frame:GetScript('OnHide')

    d.frame:SetScript('OnHide', function(...)
        if hide then
            hide(...)
        end

        apply()
    end)

    a:ReleaseConditionWidget(d)
    assert(items[1] == 1 and calls == 0 and not d.rmActive, 'queued release committed abandoned edits')
end)

test('missing target disables editing and never materializes a replacement list', function()
    local _, a = fixture()
    local d = open(a, nil)
    assert(not d.form.fields.new_item and not d.form.fields.add_item and not d.form.fields.apply:IsEnabled())
    d.form.fields.cancel:Click()
    assert(not d.rmActive)
end)

test('native popup Help shows its scoped document and expires with the native lease', function()
    local _, a = fixture()
    local document = { { title = 'Native list', text = 'Scoped help' } }
    local calls = 0
    a.GetNativeItemListHelp = function() return document end

    a.ShowWorkbenchHelp = function(_, title, sections, owner)
        assert(title == 'Item Set' and sections == document and owner == 'Selected list')
        calls = calls + 1
    end

    local d = open(a, { 1 })
    assert(d.helpButton and d.helpButton:GetWidth() == 20 and d.helpButton:GetHeight() == 20)
    d.helpButton:Click()
    assert(calls == 1)
    local stale = d.helpButton.scripts.OnClick
    d:Close()
    stale()
    assert(calls == 1)
    local nextDialog = open(a, { 3 })
    assert(nextDialog == d)
    stale()
    assert(calls == 1)
    nextDialog.helpButton:Click()
    assert(calls == 2)
    nextDialog:Close()
end)

test('legacy six-argument item_list_popup delegates to the native owner', function()
    local f, a = fixture()
    assert(a.OpenItemListPopup)
    f.load('Core/itemset_services.lua')
    local items = { 1 }
    local d = assert(a:item_list_popup('Legacy', 'Item_EditBox', items, function() return true end))
    assert(d.rmWidget)
    d:Close()
end)

finish()
