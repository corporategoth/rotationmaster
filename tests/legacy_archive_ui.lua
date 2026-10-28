-- The Recover window adopts many unassigned rotations at once, and the settings
-- window shows a banner while archived rotations wait. Models only the UI;
-- tests/legacy_archive.lua runs the same paths on a real 1.4.3e profile.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function body(name)
    return { name = name, switch = {}, rotation = {}, cooldowns = {} }
end

local function fixture(rows)
    local f = F.new()
    local a = f.addon
    local data, _, validation = make()
    a.RotationData = data
    a.conditionDefinitions = validation.conditions

    a.db = {
        keys = { char = 'A - Realm' },
        global = { effects = {} },
        char = {},
        profile = {
            rotationFallbackID = 'Saved fallback',
            rotationStore = { version = 1, classes = {}, characters = {}, legacy = { rotations = rows } },
        },
        sv = { char = { ['A - Realm'] = {} } },
    }

    local context = { class = 'SHAMAN', family = 'tbc', spec = 0, combatDataPolicy = 'probe' }

    for _, path in ipairs({
        'Data/catalog.lua', 'Data/diff.lua', 'Data/rotation_store.lua', 'Core/rotation_references.lua',
        'Core/rotation_library.lua', 'Core/rotation_tags.lua', 'Core/rotation_scope.lua', 'Core/rotation_migration.lua',
        'Core/legacy_archive.lua', 'UI/settings_layout.lua', 'UI/settings_roster_order.lua', 'UI/settings_history.lua',
        'UI/settings_ordered.lua', 'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/rotation_comparison.lua',
        'UI/rotation_adoption.lua'
    }) do
        f.load(path)
    end

    a.GetRotationContext = function() return context end
    assert(a:BindRotationProfile())
    return f, a, context
end

local function open(a, ...)
    return assert(a:ShowRotationAdoption(...))
end

local function select(w, id)
    for _, entry in ipairs(w.form.roster.entries) do
        if entry.selection.id == id then
            w.form.roster.choose(entry.value)
            return
        end
    end

    error('missing recovery row ' .. id)
end

local function threeAcrossTwoKeys()
    return { [0] = { A = body('Alpha'), B = body('Beta') }, [1] = { C = body('Gamma') } }
end

local function confirm(w)
    local prompt = w.form.prompt
    assert(prompt and prompt.frame:IsShown(), 'no confirmation was asked')
    prompt.accept:Click()
end

test('with several records the window offers Adopt all, and one specialization when it is a real subset', function()
    local _, a = fixture(threeAcrossTwoKeys())
    local w = open(a)
    select(w, 'A')
    assert(w.form.fields.adoptAll and w.form.fields.adoptGroup, 'bulk buttons are missing')

    assert(
        w.form.fields.adoptAll:GetText():find('3', 1, true) and w.form.fields.adoptGroup:GetText():find('2', 1, true),
        'the buttons do not say how many'
    )

    select(w, 'C')
    assert(not w.form.fields.adoptGroup, 'a group of one is the single adoption')
    local _, single = fixture({ [0] = { A = body('Alpha') } })
    local one = open(single)
    select(one, 'A')
    assert(not one.form.fields.adoptAll and one.form.fields.adopt, 'one record needs no bulk button')
end)

test('Adopt all asks first, and a refusal leaves everything in the archive', function()
    local _, a = fixture(threeAcrossTwoKeys())
    local w = open(a)
    select(w, 'A')
    w.form.fields.adoptAll:Click()
    assert(next(a.db.profile.rotationStore.classes) == nil, 'adopted without asking')
    assert(w.form.prompt.frame:IsShown() and w.form.prompt.accept, 'no confirmation')
    assert(#a:ListUnassignedRotations() == 3)
end)

test('confirmed Adopt all moves every record to the class owner and reports the last one to the caller', function()
    local _, a = fixture(threeAcrossTwoKeys())
    local applied

    local w = open(a, nil, function(reference)
        applied = reference
    end)

    select(w, 'A')
    w.form.fields.adoptAll:Click()
    confirm(w)

    assert(
        not w.frame:IsShown() and applied and applied.address.scope == 'class',
        'the window did not close on success'
    )

    local owned = a.db.profile.rotationStore.classes.SHAMAN
    assert(owned[0].A and owned[0].B and owned[1].C and #a:ListUnassignedRotations() == 0, 'not all moved')
end)

test('Adopt all from one specialization leaves the other key in the archive', function()
    local _, a = fixture(threeAcrossTwoKeys())
    local w = open(a)
    select(w, 'A')
    w.form.fields.adoptGroup:Click()
    confirm(w)
    local owned = a.db.profile.rotationStore.classes.SHAMAN
    assert(owned[0].A and owned[0].B and not owned[1], 'the wrong records were adopted')
    local rows = a:ListUnassignedRotations()
    assert(#rows == 1 and rows[1].id == 'C')
end)

test('This character is honored by the bulk buttons', function()
    local _, a = fixture(threeAcrossTwoKeys())
    local w = open(a)
    select(w, 'A')
    w.form.fields.character:Click()
    w.form.fields.adoptAll:Click()
    confirm(w)

    assert(
        next(a.db.profile.rotationStore.classes) == nil and a.db.profile.rotationStore.characters['A - Realm'],
        'the character owner did not receive them'
    )
end)

test('a record that is refused stays in the archive and the window names it', function()
    local rows = threeAcrossTwoKeys()
    local _, a = fixture(rows)
    -- The class owner already holds C's address.
    a.db.profile.rotationStore.classes.SHAMAN = { [1] = { C = { body = body('Existing') } } }
    assert(a:BindRotationProfile())
    local w = open(a)
    select(w, 'A')
    w.form.fields.adoptAll:Click()
    confirm(w)
    assert(w.frame:IsShown(), 'the window closed although a record was refused')
    local left = a:ListUnassignedRotations()
    assert(#left == 1 and left[1].id == 'C')

    assert(
        a.db.profile.rotationStore.classes.SHAMAN[0].A and w.form.message:GetText():find('Gamma', 1, true),
        'the refused record was not named'
    )
end)

-- A settings shell with the real config window and banner; General stands in as a page that may hold unsaved edits.
local function bannerFixture(waiting)
    local f = F.new()
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local state = { dismissed = false, opened = 0 }
    a.GetLegacyArchiveBanner = function() return not state.dismissed and waiting > 0 and waiting or nil end

    a.DismissLegacyArchiveBanner = function()
        state.dismissed = true
    end

    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.SetupOptions = function() end

    a.OpenNativeSettings = function(_, parent, key)
        local p = { frame = create('Frame', nil, parent) }

        function p:SetWidth(v)
            self.frame:SetWidth(v)
        end

        function p:SetHeight(v)
            self.frame:SetHeight(v)
        end

        function p:Release()
            self.frame:Hide()
        end

        if state.leave then
            function p:RequestLeave(callback)
                state.leave(callback)
                return false
            end
        end

        p:SetWidth(parent:GetWidth())
        p:SetHeight(parent:GetHeight())
        p.frame:Show()
        return p
    end

    a.CreateRotationBrowser = function(_, parent)
        local pane = { frame = create('Frame', nil, parent) }

        function pane:SetWidth(v)
            self.frame:SetWidth(v)
        end

        function pane:SetHeight(v)
            self.frame:SetHeight(v)
        end

        function pane:Release()
            self.frame:Hide()
        end

        function pane:OpenRecovery()
            state.opened = state.opened + 1
        end

        pane:SetWidth(parent:GetWidth())
        pane:SetHeight(parent:GetHeight())
        pane.frame:Show()
        return pane
    end

    f.load('UI/window.lua')
    f.load('UI/help.lua')
    f.load('UI/legacy_archive_banner.lua')
    f.load('UI/config.lua')
    return a, state
end

test('the settings banner follows the archive, opens Recover and can be dismissed', function()
    local a, state = bannerFixture(2)
    local shell = a:ShowConfig('General')

    assert(
        shell.banner and shell.banner.frame:IsShown() and shell.banner.text:GetText():find('2', 1, true),
        'no banner while rotations wait'
    )

    local without = shell.content:GetHeight()
    shell.banner.open:Click()
    assert(shell.section == 'Rotations' and state.opened == 1, 'the banner did not open Recover')
    shell.banner.open:Click()
    assert(state.opened == 2, 'the banner did not open Recover on the Rotations page itself')
    shell.banner.dismiss:Click()
    assert(not shell.banner.frame:IsShown() and state.dismissed, 'the banner was not dismissed')
    assert(shell.content:GetHeight() > without, 'the content did not take the space back')
    shell:Hide(true)
    state.dismissed = false
    a.GetLegacyArchiveBanner = function() return nil end
    a:ShowConfig('General')
    assert(not shell.banner.frame:IsShown(), 'a banner for an empty archive')
end)

test('Recover opens after the unsaved-edits prompt is answered, and not when the edits are kept', function()
    local a, state = bannerFixture(2)
    local pending

    state.leave = function(callback)
        pending = callback
    end

    local shell = a:ShowConfig('General')
    shell.banner.open:Click()

    assert(
        pending and shell.section == 'General' and state.opened == 0,
        'the page was left without asking about its edits'
    )

    -- Keeping the edits (the callback never runs) leaves everything as it was.
    shell.banner.open:Click()
    assert(shell.section == 'General' and state.opened == 0)
    pending()
    assert(shell.section == 'Rotations' and state.opened == 1, 'Recover did not open once the prompt was answered')
end)

finish()
