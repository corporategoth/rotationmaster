local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

test('hidden custom editor owns its children and cannot be resurrected after page release', function()
    local f = F.new()
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local h = io.open('Core/custom_condition_owner.lua')

    if h then
        h:close()
        f.load('Core/custom_condition_owner.lua')
    end

    assert(a.OwnCustomConditionDialog, 'missing dialog ownership')

    local function widget()
        local w = { frame = create('Frame') }

        function w:Show()
            self.frame:Show()
        end

        function w:Hide()
            self.frame:Hide()
        end

        return w
    end

    local valid = true
    local root, child = widget(), widget()
    local owner = a:OwnCustomConditionDialog(root, nil, function() return valid end)
    a:OwnCustomConditionDialog(child, root)
    root:Hide()

    child.frame:SetScript('OnHide', function()
        if a:CanResumeCustomConditionDialog(root, owner) then
            root:Show()
        end
    end)

    valid = false
    a:CloseCustomConditionEditor(root, owner)
    assert(not root.frame:IsShown() and not child.frame:IsShown() and not a:CanResumeCustomConditionDialog(root, owner))
    child:Show()
    child:Hide()
    assert(not root.frame:IsShown())
    local other = a:OwnCustomConditionDialog(root, nil, function() return true end)
    root:Show()
    a:CloseCustomConditionEditor(root, owner)
    assert(root.frame:IsShown() and other.active, 'old cleanup closed a reused editor')
end)

finish()
