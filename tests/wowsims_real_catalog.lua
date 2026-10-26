-- The WowSims transport on the game's real condition catalog (the TBC class harness: every shipped condition and
-- Built In pack loaded): a converted WowSims rotation is valid, supported and resolved by the real validators; the
-- add-on's own Built In rotations export, and export to the very APL the website makes of its copy of them; and
-- what is exported comes back through the import as a valid rotation again.
local F = dofile('tests/fixtures/addon.lua')
local H = dofile('tests/fixtures/tbc_hybrid_premades.lua')
local W = dofile('tests/fixtures/wowsims.lua')
local test, finish = F.suite()
local _ = F

local reader = W.loadModule()
local json = reader.json
local goldenApl = W.decode(reader, W.dir .. 'export-golden.json')

local function harness(class)
    local f, s = H.new(class)
    local a = f.addon
    f.load('Core/condition_support.lua')
    f.load('Core/transfer_formats.lua')
    a.transferFormatLoader = function(name)
        local ns = {}
        for _, file in ipairs({'json', 'mapping', 'ids', 'import', 'export', 'render', 'api'}) do
            local chunk = assert(loadfile('Modules/RotationMaster_WowSims/' .. file .. '.lua'))
            setfenv(chunk, f.env)
            chunk(name, ns)
        end
        return true
    end
    return f, s, a
end
local function validate(a, body)
    return a.RotationData.ValidateBody(body, a:GetRotationValidationOptions())
end
local function lines(diagnostics)
    local out = {}
    for i, d in ipairs(diagnostics) do if i <= 6 then out[#out + 1] = d.code .. ' ' .. tostring(d.path) .. ' ' .. tostring(d.condition) .. ' ' .. tostring(d.reason) end end
    return table.concat(out, '; ')
end

local CASES = {
    SHAMAN = {'tbcnew_ele.apl.json', 'tbcnew_shaman_enhancement_default.apl.json'},
    DRUID = {'tbcnew_druid_balance_default.apl.json'},
}
for class, files in pairs(CASES) do
    local f, _, a = harness(class)
    for _, file in ipairs(files) do
        test(class .. ' ' .. file .. ': the converted rotation is valid, supported and resolved by the real validators', function()
            local converted, why = a:ConvertRotationFromFormat('wowsims', W.read(W.dir .. file), 0)
            assert(converted, tostring(why))
            local result = validate(a, converted.body)
            assert(result.valid and result.supported and result.resolved, lines(result.diagnostics))
            assert(#converted.body.rotation == converted.report.summary.steps and converted.body.name and converted.body.tags[1] == 'wowsims')
            -- Every step the importer left enabled runs on this client: the game's condition check accepts its conditions.
            local function walk(tree)
                if not tree then return end
                if tree.type == 'AND' or tree.type == 'OR' then for _, c in ipairs(tree.value) do walk(c) end return end
                if tree.type == 'NOT' then walk(tree.value) return end
                assert(a.conditionDefinitions[tree.type], tree.type .. ' is not a condition of the game')
                assert(not a:GetConditionSupport(tree.type, a.conditionDefinitions[tree.type], tree), tree.type .. ' is not supported on this client')
            end
            for _, step in ipairs(converted.body.rotation) do walk(step.conditions) end
            -- The report is plain words.
            assert(type(converted.text) == 'string' and converted.text:find('Items in the rotation', 1, true))
        end)
    end
    test(class .. ': every Built In rotation exports; the exported APL imports back as a valid rotation', function()
        local count = 0
        for _, row in ipairs(a:ListDefaultRotations(0)) do
            local exported, why = a:ConvertRotationToFormat('wowsims', row.envelope, 0)
            assert(exported, row.id .. ': ' .. tostring(why))
            assert(exported.report.summary.exported + exported.report.summary.dropped + exported.report.summary.skipped >= 0)
            local back, reason = a:ConvertRotationFromFormat('wowsims', exported.text, 0)
            assert(back, row.id .. ' does not import back: ' .. tostring(reason))
            local result = validate(a, back.body)
            assert(result.valid and result.supported and result.resolved, row.id .. ': ' .. lines(result.diagnostics))
            count = count + 1
        end
        assert(count > 0)
    end)
end
do
    local _, _, a = harness('SHAMAN')
    test('the add-on\'s own Enhancement Built In exports to the APL the website makes of it', function()
        local row
        for _, r in ipairs(a:ListDefaultRotations(0)) do if r.id == 'rm.tbc.shaman.enhancement.wowsims' then row = r end end
        assert(row)
        local exported = assert(a:ConvertRotationToFormat('wowsims', row.envelope, 0))
        local mine = json.parse(exported.aplText, W.BIG).value
        local differences = W.diff(mine, goldenApl['rm.tbc.shaman.enhancement.wowsims'].apl, 'apl')
        assert(#differences == 0, table.concat(differences, '\n'))
        local summary = json.parse(json.encode(exported.report.summary), W.BIG).value
        assert(#W.diff(summary, goldenApl['rm.tbc.shaman.enhancement.wowsims'].summary, 'summary') == 0)
    end)
    test('the settings text is what the window shows: pretty JSON with the class, ending in a newline', function()
        local row
        for _, r in ipairs(a:ListDefaultRotations(0)) do if r.id == 'rm.tbc.shaman.enhancement.wowsims' then row = r end end
        local exported = assert(a:ConvertRotationToFormat('wowsims', row.envelope, 0))
        assert(exported.text:sub(1, 1) == '{' and exported.text:sub(-2) == '}\n')
        local value = json.parse(exported.text, W.BIG).value
        assert(value.player.class == 'ClassShaman' and value.player.rotation.type == 'TypeAPL')
        assert(exported.reportText:find('Readable by: wowsims/tbc-new.', 1, true), exported.reportText)
    end)
end

finish()
