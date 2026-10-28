local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local widgets = {}

    a:ObserveConditionWidgets(function(widget)
        widgets[#widgets + 1] = widget
    end)

    for _, file in ipairs({
        'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/condition_draft.lua', 'Data/validation.lua',
        'Data/diff.lua', 'Core/conditions.lua', 'Core/condition_catalog.lua', 'Core/condition_editor.lua',
        'Core/condition_canvas.lua', 'UI/window.lua', 'UI/help.lua', 'UI/condition_picker.lua',
        'UI/condition_cards.lua', 'UI/condition_canvas.lua', 'UI/condition_editor.lua', 'UI/condition_entrypoints.lua'
    }) do
        f.load(file)
    end

    local h = io.open('UI/condition_text.lua')

    if h then
        h:close()
        f.load('UI/condition_text.lua')
    end

    a:RegisterCondition('NUMBER', {
        description = 'Number check',
        fields = { number = 'number' },
        requiredFields = { 'number' },
        valid = function(_, value) return type(value.number) == 'number' end,
        evaluate = function()
            error('editor must not evaluate combat')
        end,
        print = function()
            error('compact tree must not execute a printer')
        end,
        widget = function(parent, _, value)
            local slider = a:CreateConditionSlider()
            slider:SetLabel('Number')
            slider:SetValue(value.number)

            slider:SetCallback('OnValueChanged', function(_, _, amount)
                value.number = amount
                local top = parent:GetUserData('top')
                top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'), 0))
            end)

            parent:AddChild(slider)
        end,
        help = function(parent)
            local label = a:CreateConditionLabel()
            label:SetText('Number help')
            parent:AddChild(label)
        end,
    })

    a.listConditions = function() return { 'AND', 'OR', 'NOT', 'DELETE', 'NUMBER' } end

    function a:GetImportValidationOptions()
        return { conditions = self.conditionDefinitions }
    end

    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    a.configPaneGeneration = 1
    dofile('tests/fixtures/workbench_help_contract.lua')(a, f.env)
    return f, widgets
end

local function model(a, shell, path)
    return assert(shell.canvas.scene.cardsByKey[a.ConditionPathKey(path)])
end

local function expanded(a, shell, path)
    local c = model(a, shell, path)
    assert(c.invalid and c.expanded and not c.compact, 'invalid node did not open editable fields')
end

test('opening expands every invalid nested node but leaves valid cards normal', function()
    local f = fixture()
    local a = f.addon

    local root = {
        type = 'AND',
        value = {
            { type = 'NUMBER' },
            { type = 'OR', value = { { type = 'NOT', value = { type = 'NUMBER' } }, { type = 'NUMBER', number = 9 } } },
        },
    }

    local shell = a:EditCondition(1, 0, root)
    expanded(a, shell, {})
    expanded(a, shell, { 'value', 1 })
    expanded(a, shell, { 'value', 2 })
    expanded(a, shell, { 'value', 2, 'value', 1 })
    assert(not model(a, shell, { 'value', 2, 'value', 2 }).expanded, 'valid leaf changed its default')
    assert(root.value[1].number == nil and not shell.active.session:IsDirty(), 'opening changed saved data/history')
end)

test('invalid root opens field widget immediately and collapse remains a user choice', function()
    local f = fixture()
    local a = f.addon
    local shell = a:EditCondition(1, 0, { type = 'NUMBER' })
    expanded(a, shell, {})
    assert(shell.canvas.cards[1].pane and shell.canvas.cards[1].fields:IsShown())
    shell.canvas.cards[1].expand:Click()
    assert(not model(a, shell, {}).expanded)
    shell:Render()
    shell:Layout()
    assert(not model(a, shell, {}).expanded, 'redraw forced an invalid card open again')
    shell.collapseAll:Click()
    shell:Render()
    assert(model(a, shell, {}).compact)
end)

test('added invalid types open despite a previously compact destination', function()
    for _, command in ipairs({ 'Replace', 'Add', 'AddSibling', 'Insert' }) do
        local f = fixture()
        local a = f.addon
        local shell = a:EditCondition(1, 0, {})
        shell.collapseAll:Click()

        if command == 'Insert' then
            assert(shell:Command(command, { path = {} }, { type = 'NUMBER' }))
        else
            assert(shell:Command(command, {}, { type = 'NUMBER' }))
        end

        expanded(a, shell, {})
    end
end)

test('inserting invalid subtree opens its invalid descendants without reopening collapsed siblings', function()
    local f = fixture()
    local a = f.addon

    local shell = a:EditCondition(1, 0, {
        type = 'AND',
        value = { { type = 'NUMBER' }, { type = 'NUMBER', number = 1 } },
    })

    local old = shell.canvas.cards[2]
    old.expand:Click()
    assert(not model(a, shell, { 'value', 1 }).expanded)

    assert(shell:Command('Insert', { path = {} }, {
        type = 'OR',
        value = { { type = 'NUMBER' }, { type = 'NUMBER', number = 3 } },
    }))

    expanded(a, shell, { 'value', 3 })
    expanded(a, shell, { 'value', 3, 'value', 1 })
    assert(not model(a, shell, { 'value', 1 }).expanded and not model(a, shell, { 'value', 2 }).expanded)
    assert(not model(a, shell, { 'value', 3, 'value', 2 }).expanded)
end)

test('valid edits do not force expansion and later invalid edits do not override normal collapse', function()
    local f = fixture()
    local a = f.addon
    local shell = a:EditCondition(1, 0, { type = 'NUMBER', number = 2 })
    assert(not model(a, shell, {}).expanded)
    shell.canvas.cards[1].header:Click()
    assert(model(a, shell, {}).expanded)
    shell:Command('SetDisabled', {}, true)
    assert(model(a, shell, {}).expanded, 'valid preference lost')
    shell.canvas.cards[1].expand:Click()
    shell.active.working.number = nil
    shell:Render()
    assert(model(a, shell, {}).invalid and not model(a, shell, {}).expanded, 'ordinary editing forced expansion')
end)

test('adding to group targets the new child and duplicate expands only its invalid copy', function()
    local f = fixture()
    local a = f.addon
    local shell = a:EditCondition(1, 0, { type = 'AND', value = { { type = 'NUMBER' } } })
    shell.canvas.cards[2].expand:Click()
    assert(shell:Command('Add', {}, { type = 'NUMBER' }))
    expanded(a, shell, { 'value', 2 })
    assert(not model(a, shell, { 'value', 1 }).expanded)
    shell.canvas.cards[3].expand:Click()
    assert(shell:Command('Duplicate', { 'value', 2 }))
    expanded(a, shell, { 'value', 3 })
    assert(not model(a, shell, { 'value', 2 }).expanded)
end)

test('semantic validators without requiredFields open new invalid fields once on detached copies', function()
    local f = fixture()
    local a = f.addon
    local calls = 0

    a:RegisterCondition('SEMANTIC', {
        description = 'Needs choices',
        fields = { unit = 'string' },
        valid = function(_, value)
            calls = calls + 1
            return value.unit ~= nil
        end,
        widget = function(parent)
            local label = a:CreateConditionLabel()
            label:SetText('Unit')
            parent:AddChild(label)
        end,
    })

    local root = { type = 'SEMANTIC' }
    local shell = a:EditCondition(1, 0, root)
    assert(model(a, shell, {}).expanded and shell.canvas.cards[1].pane, 'semantic invalid root stayed closed')
    local count = calls
    shell.canvas.cards[1].expand:Click()
    shell:Render()
    assert(calls == count and not model(a, shell, {}).expanded)
    shell.cancel:Click()
    shell = a:EditCondition(1, 0, {})
    assert(shell:Command('Replace', {}, { type = 'SEMANTIC' }))
    assert(model(a, shell, {}).expanded)
    assert(root.unit == nil)
end)

test('throwing and mutating validation remains detached and opens editable fields', function()
    local f = fixture()
    local a = f.addon

    for _, tag in ipairs({ 'THROW', 'MUTATE' }) do
        a:RegisterCondition(tag, {
            description = tag,
            fields = {},
            valid = function(_, v)
                if tag == 'THROW' then
                    error('custom validation')
                end

                v.extra = true
                return true
            end,
        })
    end

    local root = { type = 'AND', value = { { type = 'THROW' }, { type = 'MUTATE' } } }
    local shell = a:EditCondition(1, 0, root)
    assert(model(a, shell, { 'value', 1 }).expanded and model(a, shell, { 'value', 2 }).expanded)
    assert(not root.value[2].extra and not shell.active.working.value[2].extra and not shell.active.session:IsDirty())
end)

test('semantic invalid children open containing groups and hidden destinations become editable', function()
    local f = fixture()
    local a = f.addon

    a:RegisterCondition('SEMANTIC', {
        description = 'Needs choice',
        fields = { unit = 'string' },
        valid = function(_, v) return v.unit ~= nil end,
    })

    local shell = a:EditCondition(1, 0, { type = 'AND', value = { { type = 'SEMANTIC' } } })
    assert(model(a, shell, {}).expanded and model(a, shell, { 'value', 1 }).expanded)
    shell.view.hiddenChildren[''] = true
    shell.view.cardStates[''] = 'compact'
    shell:Render()
    assert(#shell.canvas.scene.cards == 1)
    assert(shell:Command('Add', {}, { type = 'SEMANTIC' }))
    assert(model(a, shell, { 'value', 2 }).expanded and not model(a, shell, {}).collapsed)
end)

test('disabled incomplete fields open and reopening resets only invalid entry defaults', function()
    local f = fixture()
    local a = f.addon
    local root = { type = 'NUMBER', disabled = true }
    local shell = a:EditCondition(1, 0, root)
    expanded(a, shell, {})
    shell.canvas.cards[1].expand:Click()
    assert(not model(a, shell, {}).expanded)
    shell.cancel:Click()
    shell = a:EditCondition(1, 0, root)
    expanded(a, shell, {})
    assert(root.disabled and root.number == nil)
end)

test('validation retirement stops later callbacks and cannot show an obsolete modal', function()
    local f = fixture()
    local a = f.addon
    local later = 0

    a:RegisterCondition('RETIRE', {
        description = 'Retire',
        fields = {},
        valid = function()
            a.compactConditionEditor.cancel:Click()
            return false
        end,
    })

    a:RegisterCondition('LATER', {
        description = 'Later',
        fields = {},
        valid = function()
            later = later + 1
            return false
        end,
    })

    local shell = a:EditCondition(1, 0, { type = 'AND', value = { { type = 'RETIRE' }, { type = 'LATER' } } })
    assert(not shell.active and later == 0 and not shell.frame:IsShown(), 'retired validation resumed old modal work')
end)

test('valid announcement contextual units keep their ordinary collapsed preference', function()
    local f = fixture()
    local a = f.addon

    a:RegisterCondition('CONTEXT', {
        description = 'Contextual unit',
        fields = { unit = 'string' },
        valid = function(_, v) return v.unit == 'target' or v.unit == 'player' end,
    })

    local root = { type = 'CONTEXT', unit = 'announcementtarget' }
    local shell = a:ShowConditionEditor(0, 0, root, nil, nil, { announcement = true, announcementTarget = true })
    assert(not model(a, shell, {}).expanded, 'valid announcement alias treated as invalid ordinary unit')
    assert(root.unit == 'announcementtarget' and not shell.active.session:IsDirty())
end)

test('retired persistent parent stops later initial validator callbacks', function()
    local f = fixture()
    local a = f.addon
    local alive = true
    local later = 0

    a:RegisterCondition('RETIRE_PARENT', {
        description = 'Retire parent',
        fields = {},
        valid = function()
            alive = false
            return false
        end,
    })

    a:RegisterCondition('LATER_PARENT', {
        description = 'Later',
        fields = {},
        valid = function()
            later = later + 1
            return false
        end,
    })

    a:ShowConditionEditor(
        0,
        0,
        { type = 'AND', value = { { type = 'RETIRE_PARENT' }, { type = 'LATER_PARENT' } } },
        nil,
        function() return alive end,
        { persistentOwner = true }
    )

    assert(later == 0, 'old parent validator invoked after parent retirement')
end)

test('new validator cannot continue after nonpersistent configuration owner changes', function()
    local f = fixture()
    local a = f.addon
    local later = 0

    a:RegisterCondition('RETIRE_GENERATION', {
        description = 'Retire',
        fields = {},
        valid = function()
            a.configPaneGeneration = a.configPaneGeneration + 1
            return false
        end,
    })

    a:RegisterCondition('LATER_GENERATION', {
        description = 'Later',
        fields = {},
        valid = function()
            later = later + 1
            return false
        end,
    })

    a:ShowConditionEditor(0, 0, {
        type = 'AND',
        value = { { type = 'RETIRE_GENERATION' }, { type = 'LATER_GENERATION' } },
    })

    assert(later == 0, 'validator invoked after config owner generation changed')
end)

finish()
