local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(readonly, arguments)
    local f = F.new()
    local a = f.addon
    dofile('tests/fixtures/native_ui.lua')(f.env)
    a.db.char = {}
    a.db.global.custom_functions = {}

    for _, path in ipairs({
        'Core/function_data.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_layout.lua',
        'UI/settings_ordered.lua', 'UI/settings_roster_order.lua', 'UI/settings_form.lua',
        'UI/settings_collections.lua', 'UI/settings_transfer.lua', 'UI/lua_input_diagnostics.lua', 'UI/lua_editor.lua',
        'UI/settings_functions.lua', 'UI/function_bindings.lua', 'UI/function_source_pane.lua',
        'UI/function_bundle_transfer.lua'
    }) do
        f.load(path)
    end

    local src = {
        name = 'helper',
        description = string.rep('Readable description. ', 50),
        args = { { name = 'value', type = 'number | nil', description = string.rep('Argument documentation. ', 20) } },
        returns = { { type = 'RMResult | boolean', description = 'First result' } },
        code = '    return value',
        bindings = {},
    }

    if arguments then
        src.args = arguments
        src.code = 'return ...'
    end

    if readonly then
        a:RegisterBuiltinFunction('builtin:test', src, function() return function(v) return v end end)
    else
        a.db.global.custom_functions.HELPER = src
        a:InitializeFunctionRegistry()
    end

    local host = f.env.CreateFrame('Frame')
    host:SetSize(1100, 700)
    local p = a:OpenNativeSettings(host, 'Functions')
    return f, a, p, p.inlineFunction, src
end

test('packaged and custom metadata share named type selectors nullable and description widgets', function()
    for _, readonly in ipairs({ false, true }) do
        local _, _, _, d = fixture(readonly)
        local fields = d.form.fields

        assert(
            fields.arg_1_type and fields.arg_1_nullable and fields.return_1_type and fields.return_1_nullable,
            'metadata does not share type selectors'
        )

        assert(fields.arg_1_type:IsEnabled() ~= readonly and fields.arg_1_nullable:IsEnabled() ~= readonly)

        assert(
            fields.description.multiLine and fields.description.cursor == 0 and fields.description:GetHeight() > 24,
            'long descriptions are truncated or start at the end'
        )

        assert(fields.arg_1_description.multiLine and fields.arg_1_description:GetHeight() > 24)

        assert(
            d:PendingSource().args[1].type == 'number | nil'
                and d:PendingSource().returns[1].type == 'RMResult | boolean',
            'opening metadata rewrites its type'
        )
    end
end)

test('nullable toggling preserves existing union members and stages type edits', function()
    local _, _, _, d, original = fixture(false)
    d.form.fields.arg_1_nullable:Click()
    assert(d:PendingSource().args[1].type == 'number' and original.args[1].type == 'number | nil')
    d.form.fields.return_1_nullable:Click()
    assert(d:PendingSource().returns[1].type == 'RMResult | boolean | nil')
    d.form.fields.arg_1_type:Click()
    local menu = d.form.menu
    local chosen

    for _, row in ipairs(menu.rows) do
        if row:GetText() == 'string' then
            chosen = row
        end
    end

    if not chosen then
        for index, entry in ipairs(menu.entries or {}) do
            if entry.value == 'string' then
                chosen = menu.rows[index]
            end
        end
    end

    assert(chosen, 'type choices omit string')
    chosen:Click()
    assert(d:PendingSource().args[1].type == 'string' and d:IsDirty())
end)

test('code expansion preserves pending metadata code and editor provider', function()
    local _, _, p, d = fixture(false)
    local editor = d.code
    local name = d.form.fields.description
    name:SetText('Changed description')
    name.scripts.OnTextChanged(name, true)
    d.code.edit:SetText('return value + 1')
    d.code.edit.scripts.OnTextChanged(d.code.edit, true)
    assert(d.codeExpand, 'code corner expansion missing')
    d.codeExpand:Click()

    assert(
        d.codeExpanded
            and d.code == editor
            and d.code:GetText() == 'return value + 1'
            and d:PendingSource().description == 'Changed description'
    )

    assert(not d.form.fields.name, 'metadata still occupies the enlarged source view')
    d.codeExpand:Click()
    assert(not d.codeExpanded and d.form.fields.name and d.code == editor)
    p:Draw()
    assert(p.inlineFunction.code:GetText() == 'return value + 1' and p.inlineFunction:IsDirty())
end)

test('readonly code expansion never replaces original indented source with displayed code', function()
    local _, _, p, d, original = fixture(true)
    assert(d.codeExpand, 'readonly source lacks expansion')
    d.codeExpand:Click()
    d.codeExpand:Click()
    p:Draw()
    assert(p.inlineFunction:PendingSource().code == original.code and not p.inlineFunction:IsDirty())
end)

test('metadata controls fit a narrow pane and descriptions measure their displayed width', function()
    local _, _, _, d = fixture(false)
    d.frame:SetWidth(280)
    d.form:Draw()
    local form = d.form

    for _, key in ipairs({
        'arg_1_name',
        'arg_1_type',
        'arg_1_nullable',
        'arg_1_description',
        'return_1_type',
        'return_1_nullable',
        'return_1_description',
    }) do
        local control = assert(form.fields[key])
        assert(control.point[2] + control:GetWidth() <= form.width, key .. ' overflows the pane')
    end

    local input = form.fields.arg_1_description
    local lines = math.ceil(#input:GetText() / math.max(1, (input:GetWidth() - 10) / 7))
    assert(input:GetHeight() == math.max(28, lines * 12 + 8), 'description height used another field width')
    assert(input.textInsets[3] + input.textInsets[4] == 8, 'compact multiline padding exceeds the measured height')
    assert(form.fields.arg_1_type.rmUnsaved ~= true)
    form.fields.arg_1_nullable:Click()
    assert(form.fields.arg_1_type.rmUnsaved, 'type change lacks unsaved marker')
end)

test('nil-only result metadata stays a nil type without widening it to nullable any', function()
    local _, _, p, d = fixture(false)
    d.value.returns[1].type = 'nil'
    d.baseline.returns[1].type = 'nil'
    d.form:Draw()
    d:UpdateActions()
    assert(d.form.fields.return_1_type:GetText() == 'nil', 'nil-only return was displayed as any')
    assert(not d.form.fields.return_1_nullable:IsEnabled() and d:PendingSource().returns[1].type == 'nil')
end)

test('compact metadata omits explanatory blocks orders namespace first and aligns binding actions', function()
    local _, _, _, d = fixture(false)
    local form = d.form
    assert(form.fields.namespace.point[3] > form.fields.name.point[3], 'Namespace is not before Name')

    for _, text in ipairs(form.pool.text or {}) do
        if text:IsShown() then
            local value = text:GetText()

            assert(
                not value:find('Identifier:', 1, true)
                    and not value:find('Invoke:', 1, true)
                    and not value:find('Existing API:', 1, true)
                    and not value:find('Lua returns multiple', 1, true)
                    and not value:find('Namespaces group', 1, true),
                'explanatory prose still occupies the form'
            )
        end
    end

    local binding = form.fields.function_bindings

    assert(
        binding.point[3] == d.syntax.point[3] and binding.point[2] + binding:GetWidth() < d.syntax.point[2],
        'bindings are not directly before Check syntax'
    )

    d.codeExpand:Click()

    assert(
        d.form.fields.function_bindings and not d.form.fields.namespace,
        'expanded code loses bindings or keeps metadata'
    )
end)

test('argument and result headings collapse independently without changing drafts', function()
    local _, _, p, d = fixture(false)
    d.form.fields.section_args:Click()
    assert(not d.form.fields.arg_1_name and d.form.fields.return_1_type and not d:IsDirty())
    d.form.fields.section_returns:Click()
    assert(not d.form.fields.return_1_type and not d:IsDirty())
    p:Draw()
    d = p.inlineFunction
    assert(d.metadataCollapsed.args and d.metadataCollapsed.returns, 'collapse state did not survive redraw')
    d.form.fields.section_args:Click()
    assert(d.form.fields.arg_1_name and not d.form.fields.return_1_type)
end)

test('metadata uses shared row reordering and click or drag insertion stages only drafts', function()
    local _, _, _, d, original = fixture(false)
    d.form.fields.add_args:Click()
    assert(#d.value.args == 2 and #original.args == 1)
    local view = d.form.ordered.function_args

    assert(
        view and view.rows[1].decoration and view.rows[1].scripts.OnDragStart,
        'argument rows do not use shared draggable cards'
    )

    view.rows[2].up:Click()
    assert(d.value.args[1].name == 'value' and d.form.prompt.frame:IsShown(), 'argument order changed before warning')
    d.form.prompt.cancel:Click()
    assert(d.value.args[1].name == 'value')
    view.rows[2].up:Click()
    d.form.prompt.accept:Click()
    assert(d.value.args[1].name == 'argument1' and #original.args == 1)
    local add = d.form.fields.add_args
    add.scripts.OnDragStart(add)
    view = d.form.ordered.function_args
    assert(view.insertFactory and view.ghost:IsShown() and #d.value.args == 2)
    assert(view:Drop(1) and d.form.prompt.frame:IsShown() and #d.value.args == 2)
    d.form.prompt.accept:Click()
    assert(#d.value.args == 3 and d.value.args[1].name == 'argument2', 'drag insertion did not use the selected gap')
    d.form.fields.section_returns:Click()
    d.form.fields.add_returns:Click()

    assert(
        not d.metadataCollapsed.returns and #d.value.returns == 2,
        'click insertion does not append and expand its group'
    )

    view = d.form.ordered.function_returns
    view.rows[2].remove:Click()
    assert(#d.value.returns == 1 and #original.returns == 1)
end)

test('readonly metadata retains the shared inspection layout while blocking all row mutations', function()
    local _, _, _, d, original = fixture(true)
    local view = d.form.ordered.function_args

    assert(
        view
            and d.form.fields.arg_1_name
            and not d.form.fields.add_args:IsEnabled()
            and not view.rows[1].remove:IsEnabled()
    )

    view:BeginDrag(1)

    assert(
        not view.drag and not view:BeginInsert(function() return { name = 'oops' } end, 'Argument') and not view:Drop(1)
    )

    d.form.fields.section_args:Click()
    assert(not d.form.fields.arg_1_name)
    d.form.fields.section_args:Click()
    assert(d.form.fields.arg_1_name and d:PendingSource().args[1].name == original.args[1].name and not d:IsDirty())
end)

test('namespace suggestions select existing values while new typed namespaces remain supported', function()
    local _, a, _, d = fixture(false)

    a.db.global.custom_functions.OTHER = {
        name = 'other',
        namespace = 'other.tools',
        description = 'Other helper',
        args = {},
        returns = {},
        code = 'return nil',
        bindings = {},
    }

    d.form:Draw()
    local input = d.form.fields.namespace
    assert(input.suggestions, 'namespace input has no suggestions')
    input.scripts.OnEditFocusGained(input)
    local menu = input.suggestions
    local choice

    for _, row in ipairs(menu.rows) do
        if row:IsShown() and row:GetText() == 'other.tools' then
            choice = row
        end
    end

    assert(choice, 'existing namespace is not offered')
    choice:Click()

    assert(
        d.value.namespace == 'other.tools' and d:IsDirty() and not a.db.global.custom_functions.HELPER.namespace,
        'suggestion did not stage namespace metadata'
    )

    input:SetText('new.custom')
    input.scripts.OnTextChanged(input, true)
    input.scripts.OnEnterPressed(input)

    assert(
        d.value.namespace == 'new.custom' and not a.db.global.custom_functions.HELPER.namespace,
        'new namespace text was not kept as a draft'
    )
end)

test('saved return reordering warns before staging while new draft argument reordering needs no warning', function()
    local _, _, _, d, original = fixture(false)
    d.form.fields.add_returns:Click()
    local first = d.value.returns[1]
    local second = d.value.returns[2]
    local view = d.form.ordered.function_returns
    view:BeginDrag(1)
    view:Drop(3)

    assert(
        d.value.returns[1] == first and d.form.prompt.frame:IsShown(),
        'return drag changed positions before confirmation'
    )

    d.form.prompt.cancel:Click()
    assert(d.value.returns[1] == first)
    view:BeginDrag(1)
    view:Drop(3)
    d.form.prompt.accept:Click()
    assert(d.value.returns[1] == second and #original.returns == 1)
    local _, _, p = fixture(false)
    p.fields.new_function:Click()
    d = p.inlineFunction
    d.form.fields.add_args:Click()
    d.form.fields.add_args:Click()
    d.form.ordered.function_args.rows[2].up:Click()

    assert(
        d.value.args[1].name == 'argument2' and not (d.form.prompt and d.form.prompt.frame:IsShown()),
        'new unpublished function unnecessarily warned about callers'
    )
end)

test('selecting the current implicit namespace does not materialize a false change', function()
    local _, _, _, d = fixture(false)
    assert(d.value.namespace == nil and not d:IsDirty())
    local input = d.form.fields.namespace
    input:GetScript('OnEditFocusGained')(input)
    local menu = input.suggestions
    local choice

    for _, row in ipairs(menu.rows) do
        if row:IsShown() and row:GetText() == 'functions' then
            choice = row
        end
    end

    assert(choice)
    choice:Click()

    assert(
        d.value.namespace == nil and not d:IsDirty() and not d.apply:IsEnabled(),
        'selecting the displayed default fabricated metadata changes'
    )
end)

test('committed long qualified signatures reflow only their code geometry without rewriting source', function()
    local _, _, _, d = fixture(false)
    local code = d.code
    local source = code:GetText()
    code.edit:SetCursorPosition(5)
    local oldHeight = d.signature:GetHeight()
    local input = d.form.fields.namespace
    input:SetText(string.rep('a', 110) .. '.' .. string.rep('b', 110))
    input:GetScript('OnTextChanged')(input, true)
    input:GetScript('OnEnterPressed')(input)
    assert(d.signature:GetHeight() > oldHeight, 'long qualified signature stayed clipped')

    assert(
        d.code == code and code:GetText() == source and code.edit:GetCursorPosition() == 5,
        'signature layout rewrote code or its cursor'
    )

    assert(
        d.code.frame.point[3] == -d.codeTop and d.form.child:GetHeight() == d.form.y,
        'signature layout left code or scrolling at its previous position'
    )

    local top = d.codeTop
    d:UpdateActions()
    d:UpdateActions()
    assert(d.codeTop == top and code:GetText() == source, 'unchanged signature repeatedly reflowed')
end)

test(
    'argument cards keep type name nullable inline with compact descriptions and standard help duplicate delete controls',
    function()
        local _, a, _, d, original = fixture(false)
        d.value.args[1].description = 'Short'
        d.form:Draw()
        local fields = d.form.fields

        assert(
            fields.arg_1_type.point[2] < fields.arg_1_name.point[2]
                and fields.arg_1_nullable.point[2] > fields.arg_1_name.point[2],
            'argument field order is not Type Name Nullable'
        )

        assert(
            fields.arg_1_type.point[3] == fields.arg_1_name.point[3]
                and fields.arg_1_type.point[3] == fields.arg_1_nullable.point[3],
            'argument metadata does not share its first row'
        )

        assert(fields.arg_1_description:GetHeight() <= 32, 'short metadata description reserves excess rows')

        assert(
            fields.arg_1_type:GetFontString():GetWidth() <= fields.arg_1_type:GetWidth() - 26,
            'type caption overlaps neighboring fields'
        )

        assert(
            fields.arg_1_help and fields.arg_1_duplicate and fields.arg_1_remove,
            'card help duplicate or delete controls missing'
        )

        local help

        a.ShowWorkbenchHelp = function(_, heading, sections)
            help = { heading = heading, sections = sections }
        end

        fields.arg_1_help:Click()
        assert(help and #help.sections >= 3, 'argument help lacks editing details')
        fields.arg_1_duplicate:Click()

        assert(
            #d.value.args == 2 and #original.args == 1 and d.value.args[2].name ~= d.value.args[1].name,
            'argument duplicate changed saved source or reused its name'
        )

        local copy = d.value.args[2]

        assert(
            copy.type == d.value.args[1].type and copy.description == d.value.args[1].description,
            'duplicate lost typed documentation'
        )

        local _, _, _, readonly = fixture(true)

        assert(
            readonly.form.fields.arg_1_help:IsEnabled() and not readonly.form.fields.arg_1_duplicate:IsEnabled(),
            'readonly cards hide help or allow duplication'
        )
    end
)

test('saving a new function activates warnings on real card mouse drag handlers and raises the prompt', function()
    local f, a, p = fixture(false)
    f.env.UISpecialFrames = {}
    p.fields.new_function:Click()
    local d = p.inlineFunction
    d.form.fields.add_args:Click()
    d.form.fields.add_args:Click()
    assert(d.isNew and d:Apply(), 'new function could not be saved')
    d = p.inlineFunction
    assert(not d.isNew and not p.newFunctionSource, 'saved function retained new-draft warning bypass')
    local view = d.form.ordered.function_args
    local before = d.value.args[1]
    a.IsWorkbenchDropZoneUnderPointer = function(_, zone) return zone == view.zones[1] end
    local row = view.rows[2]
    row:GetScript('OnMouseDown')(row, 'LeftButton')
    row:GetScript('OnDragStart')(row)
    row:GetScript('OnDragStop')(row)

    assert(
        d.value.args[1] == before and d.form.prompt.frame:IsShown(),
        'native card drag reordered a saved function without warning'
    )

    assert(
        d.form.prompt.frame:GetFrameStrata() == 'FULLSCREEN_DIALOG' and not view.ghost:IsShown(),
        'warning is hidden under the drag preview'
    )

    d.form.prompt.accept:Click()
    assert(d.value.args[1] ~= before, 'confirmed saved reorder did not apply')
end)

test('inserting before saved parameters warns because existing argument positions shift', function()
    local _, _, _, d, original = fixture(false)
    local add = d.form.fields.add_args
    add:GetScript('OnDragStart')(add)
    local view = d.form.ordered.function_args
    assert(view:Drop(1))
    assert(#d.value.args == 1 and d.form.prompt.frame:IsShown(), 'insertion shifted a saved signature without warning')
    d.form.prompt.cancel:Click()
    assert(#d.value.args == 1 and d.value.args[1].name == 'value')
    add = d.form.fields.add_args
    add:GetScript('OnDragStart')(add)
    d.form.ordered.function_args:Drop(1)
    d.form.prompt.accept:Click()

    assert(
        #d.value.args == 2
            and d.value.args[1].name == 'argument1'
            and d.value.args[2].name == 'value'
            and #original.args == 1
    )

    add = d.form.fields.add_args
    add:GetScript('OnDragStart')(add)
    d.form.ordered.function_args:Drop(3)

    assert(
        #d.value.args == 3 and not d.form.prompt.frame:IsShown(),
        'append warned despite preserving existing positions'
    )
end)

test('binding caption keeps compact width and adjacent syntax action when resizing or expanding', function()
    for _, readonly in ipairs({ false, true }) do
        local _, _, _, d = fixture(readonly)

        for _, width in ipairs({ 1100, 280, 1800, 600 }) do
            d.frame:SetWidth(width)
            d.form:Draw()
            local binding = d.form.fields.function_bindings
            local natural = math.max(90, math.ceil(binding:GetFontString():GetStringWidth()) + 24)
            assert(binding:GetWidth() <= natural, 'Bindings stretches to fill the pane')

            assert(
                d.syntax.point[2] == binding.point[2] + binding:GetWidth() + 6
                    and d.syntax.point[3] == binding.point[3],
                'Check syntax is separated from Bindings'
            )

            assert(d.syntax.point[2] + d.syntax:GetWidth() <= d.form.width, 'binding actions overflow a narrow pane')
        end

        d.form.fields.function_bindings:Click()
        local binding = d.form.fields.function_bindings

        for _, label in ipairs(d.form.pool.bindingLabels or {}) do
            if label:IsShown() then
                assert(label.point[3] < binding.point[3], 'expanded binding content overlaps the compact toolbar')
            end
        end

        assert(not d:IsDirty(), 'opening or resizing binding actions changed source')
    end
end)

local function vararg()
    return { name = '...', type = 'any', description = 'Remaining values' }
end

for _, case in ipairs({
    { label = 'variadic only', args = { vararg() } },
    { label = 'named and variadic', args = { { name = 'value', type = 'number', description = 'First' }, vararg() } },
}) do
    test(
        'ordinary Add Argument warns before changing saved ' .. case.label .. ' and Cancel preserves its draft',
        function()
            local _, a, _, d, original = fixture(false, case.args)
            assert(a:ValidateCustomFunctionSource('HELPER', d:PendingSource()))
            local input = d.form.fields.description
            input:SetText('Pending description')
            input:GetScript('OnTextChanged')(input, true)
            assert(d:Flush())
            d.code.edit:SetText('return ... -- pending')
            d.code.edit:GetScript('OnTextChanged')(d.code.edit, true)
            local before = d:PendingSource()
            local saved = a:CopySettingsData(original)
            d.form.fields.add_args:Click()
            assert(d.form.prompt and d.form.prompt.frame:IsShown(), 'saved variadic append did not warn')

            assert(
                a:SettingsDataEqual(d:PendingSource(), before) and a:SettingsDataEqual(original, saved),
                'append mutated source before confirmation'
            )

            d.form.prompt.cancel:Click()

            assert(
                a:SettingsDataEqual(d:PendingSource(), before) and a:SettingsDataEqual(original, saved),
                'Cancel lost pending source'
            )

            d.form.fields.add_args:Click()
            d.form.prompt.accept:Click()
            local args = d.value.args
            assert(#args == #case.args + 1 and args[#args].name == '...' and args[#args - 1].name == 'argument1')

            assert(
                a:ValidateCustomFunctionSource('HELPER', d:PendingSource()) and a:SettingsDataEqual(original, saved),
                'confirmed insertion invalid or saved too early'
            )

            assert(d.value.description == 'Pending description' and d.code:GetText() == 'return ... -- pending')
            assert(d:Apply())
            local fn = assert(a:ResolveFunctionBinding('HELPER'))

            if #case.args == 1 then
                assert(fn('consumed', 'tail') == 'tail')
            else
                assert(fn('first', 'consumed', 'tail') == 'tail')
            end
        end
    )
end

test('ordinary Add Argument inserts immediately before a new unpublished trailing vararg', function()
    local _, a, p = fixture(false)
    p.fields.new_function:Click()
    local d = p.inlineFunction
    d.form.fields.add_args:Click()
    local name = d.form.fields.arg_1_name
    name:SetText('...')
    name:GetScript('OnTextChanged')(name, true)
    assert(d:Flush())
    assert(d.isNew and a:ValidateCustomFunctionSource(d.key, d:PendingSource()))
    d.form.fields.add_args:Click()
    assert(not d.form.prompt or not d.form.prompt.frame:IsShown())
    assert(#d.value.args == 2 and d.value.args[1].name == 'argument1' and d.value.args[2].name == '...')
    assert(a:ValidateCustomFunctionSource(d.key, d:PendingSource()) and not a.db.global.custom_functions[d.key])
end)

test('retired variadic append confirmation cannot mutate a rebuilt or closed Functions owner', function()
    for _, close in ipairs({ false, true }) do
        local _, a, p, d, original = fixture(false, { vararg() })
        d.form.fields.add_args:Click()
        assert(d.form.prompt and d.form.prompt.frame:IsShown(), 'saved variadic append did not warn')
        local accept = d.form.prompt.accept:GetScript('OnClick')
        local previous = d.value

        if close then
            d:Close()
        else
            p:Draw()
        end

        local successor = p.inlineFunction
        local before = a:CopySettingsData(successor.value)
        accept()

        assert(
            a:SettingsDataEqual(successor.value, before) and #previous.args == 1 and #original.args == 1,
            'stale confirmation appended an argument'
        )
    end
end)

test('ordinary nonvariadic Argument append and Return append retain immediate independent policies', function()
    local _, a, _, d, original = fixture(false)
    d.form.fields.add_args:Click()
    assert(#d.value.args == 2 and d.value.args[1].name == 'value' and d.value.args[2].name == 'argument1')
    assert(not d.form.prompt or not d.form.prompt.frame:IsShown())
    assert(#original.args == 1)
    local _, a, _, d, original = fixture(false, { vararg() })
    d.form.fields.add_returns:Click()
    assert(#d.value.returns == 2 and #d.value.args == 1 and d.value.args[1].name == '...' and #original.returns == 1)
    assert(not d.form.prompt or not d.form.prompt.frame:IsShown())
    assert(a:ValidateCustomFunctionSource('HELPER', d:PendingSource()))
end)

test('readonly variadic metadata leaves both Add controls disabled and source untouched', function()
    local _, a, _, d = fixture(true, { vararg() })
    local before = d:PendingSource()
    assert(not d.form.fields.add_args:IsEnabled() and not d.form.fields.add_returns:IsEnabled())
    d.form.fields.add_args:Click()
    d.form.fields.add_returns:Click()
    assert(a:SettingsDataEqual(d:PendingSource(), before))
end)

finish()
