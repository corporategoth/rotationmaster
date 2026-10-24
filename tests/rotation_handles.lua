-- Rotation handles: a short, case-insensitive identifier for /rm set and lists.
-- The user's report: "/rm set Monk: Brewmaster (Retail, Blizzard Assisted with brews)" is
-- hard to type and case sensitive. Built Ins derive theirs from the pack id (unique per
-- class and edition across the whole corpus); your rotations store an editable one (made
-- from the name until you change it); /rm set takes a handle first, then the exact name.
local T=dofile('tests/fixtures/toc_addon.lua')
local F=dofile('tests/fixtures/addon.lua')
local corpus=dofile('tests/fixtures/default_corpus.lua')
local test,finish=F.suite()

local function chat(f) return table.concat(f.state.chat,'\n') end
local function command(f,text) f.env.LibStub('AceConsole-3.0').GetArgs=function(_,s) return s:match('^(%S+)'),(s:find(' ',1,true) or #s)+1 end;f.addon:HandleCommand(text) end
local function key(a,id) return a:GetScopedRotationCoordinator():Key({kind='builtin',id=id}) end
local function custom(f,spec,name,body)
    local a=f.addon;local ref=assert(a:NewRotationDraftTarget(spec,'class',false))
    body=body or {};body.name=name;body.rotation=body.rotation or {{id='a1',type='assisted',conditions={}}};body.cooldowns=body.cooldowns or {}
    assert(a:CommitRotationDraft(ref,nil,{body=body},'class'))
    return a:GetScopedRotationCoordinator():Key(ref),ref
end

test('handle format: letter first, letters digits _ -, 32 at most, case-insensitive, auto/default reserved',function()
    local f=T.new{level=10,specIndex=1};local data=f.addon.RotationData
    assert(data.NormalizeRotationHandle('BrewMaster')=='brewmaster' and data.NormalizeRotationHandle('a_b-9')=='a_b-9')
    for _,bad in ipairs({'','9lives','has space','dot.ted',string.rep('a',33),'auto','Default',5}) do assert(data.NormalizeRotationHandle(bad)==nil,tostring(bad)) end
    assert(data.SlugRotationHandle('Monk: Brewmaster (Retail)')=='monk-brewmaster-retail')
    assert(data.SlugRotationHandle('  2 Target Cleave!! ')=='r-2-target-cleave' and data.SlugRotationHandle('')=='rotation' and data.SlugRotationHandle('Auto')=='auto-rotation')
    assert(#data.SlugRotationHandle(string.rep('Long name ',10))<=32)
    local body={name='x',handle='Bad Handle',rotation={},cooldowns={}}
    local result=data.ValidateBody(body,f.addon:GetRotationValidationOptions());assert(not result.valid and result.diagnostics[1].code=='invalid-handle')
    body.handle='good';assert(data.ValidateBody(body,f.addon:GetRotationValidationOptions()).valid)
end)

test('every shipped Built In has a valid handle, unique within its class and edition',function()
    local f,packs=corpus.load(5,1,'SHAMAN');local a=f.addon;local data=a.RotationData
    local groups,count={},0
    for _,pack in ipairs(packs) do
        local handle=assert(a:GetBuiltinHandle(pack.id),pack.id..' has no handle')
        assert(data.NormalizeRotationHandle(handle)==handle,pack.id..' handle invalid: '..handle)
        local group=table.concat(pack.applicability.families,'+')..':'..tostring(pack.applicability.class)
        groups[group]=groups[group] or {}
        assert(not groups[group][handle],pack.id..' repeats '..handle..' of '..tostring(groups[group][handle]));groups[group][handle]=pack.id;count=count+1
    end
    assert(count==#packs and count>100,'corpus too small: '..count)
    assert(a:GetBuiltinHandle('rm.retail.monk.brewmaster')=='brewmaster' and a:GetBuiltinHandle('rm.retail.monk.brewmaster.guide')=='brewmaster-guide')
    assert(a:GetBuiltinHandle('rm.retail.monk.initial')=='initial')
end)

test('/rm set takes a handle in any case, names it with its handle, and explains the rest',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    command(f,'set BrewMaster')
    assert(a.manualRotation and a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster','handle did not select')
    assert(chat(f):find('manually switched to |cFFFFFFFFMonk: Brewmaster (Retail, Blizzard Assisted with brews) [brewmaster]',1,true),chat(f))
    assert(chat(f):find('automatically switched to |cFFFFFFFFMonk: Brewmaster (Retail, Blizzard Assisted with brews) [brewmaster]',1,true),'auto message lacks the handle')
    command(f,'set auto');assert(not a.manualRotation)
    -- A rotation that cannot be selected says why; an unknown handle lists the usable ones.
    command(f,'set brewmaster-GUIDE');assert(chat(f):find('[brewmaster-guide] cannot be selected',1,true) and chat(f):find('ships disabled',1,true),chat(f))
    command(f,'set nothing-here');assert(chat(f):find('Handles you can use now: brewmaster (or auto)',1,true),chat(f))
    -- The exact name still works.
    command(f,'set Monk: Brewmaster (Retail, Blizzard Assisted with brews)');assert(a.manualRotation and a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster')
    command(f,'set default');assert(a.manualRotation~=nil)
    -- /rm list: handle — name — status for the live specialization.
    local list=table.concat(a:GetRotationHandleReport(),'\n')
    assert(list:find('brewmaster — Monk: Brewmaster (Retail, Blizzard Assisted with brews) (Built In) — active',1,true),list)
    assert(list:find('default — Default (fallback) — cannot be selected',1,true),list)
    assert(list:find('brewmaster-guide — ',1,true) and list:find('ships disabled',1,true) and list:find('windwalker — ',1,true) and list:find('not for this character now',1,true),list)
    assert(table.concat(a:GetRotationEligibilityReport(),'\n'):find('(Built In) [brewmaster]: ready',1,true))
    -- The minimap menu shows the handle in brackets.
    local rows={};f.env.UIDropDownMenu_AddButton=function(r) rows[#rows+1]=r.text end;f.env.minimapInitialize()
    assert(table.concat(rows,'\n'):find('|cff5bc0ebMonk: Brewmaster (Retail, Blizzard Assisted with brews) [brewmaster]|r',1,true),table.concat(rows,'\n'))
end)

test('your rotations: a handle made from the name until set, validated, unique, and /rm set finds it',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local aoe=custom(f,268,'AoE Cleave',{priority=50,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1}})
    assert(a:GetRotationHandle(268,aoe)=='aoe-cleave','derived handle '..tostring(a:GetRotationHandle(268,aoe)))
    -- A name that slugs to a Built In's handle takes a suffix.
    local clash=custom(f,268,'Brewmaster');assert(a:GetRotationHandle(268,clash)=='brewmaster-2')
    command(f,'set AOE-cleave');assert(a.manualRotation and a.currentRotation==aoe)
    -- Checks: format, reserved, and a handle another rotation already uses (named).
    assert(a:CheckRotationHandle(268,aoe,'9x'):find('starts with a letter',1,true))
    assert(a:CheckRotationHandle(268,aoe,'auto'):find('reserved',1,true))
    assert(a:CheckRotationHandle(268,aoe,'BrewMaster'):find('Monk: Brewmaster (Retail, Blizzard Assisted with brews) already uses the handle brewmaster',1,true))
    assert(a:CheckRotationHandle(268,aoe,'aoe-cleave')==nil and a:CheckRotationHandle(268,aoe,'Mine')==nil)
    -- The editor: Handle, Priority, Enabled on one line; an invalid or taken handle blocks Apply and says why.
    local parent=f.env.CreateFrame('Frame');parent:SetSize(1000,700)
    local pane=assert(a:CreateRotationEditor(parent,268,aoe))
    local _,toPriority=pane.handle:GetPoint(1);assert(toPriority==pane.priorityLabel,'handle is not left of priority')
    assert(pane.handle:GetText()=='aoe-cleave')
    pane.handle:SetText('brewmaster');pane.handle.scripts.OnTextChanged(pane.handle,true)
    assert(not pane.apply:IsEnabled() and pane.status:GetText():find('already uses the handle brewmaster',1,true),'a taken handle did not block Apply')
    pane.handle:SetText('Big-Pull');pane.handle.scripts.OnTextChanged(pane.handle,true);assert(pane.apply:IsEnabled())
    assert(pane:Apply());assert(a:GetEditableRotation(268,aoe).handle=='big-pull','handle not stored lower-case')
    command(f,'set big-PULL');assert(a.currentRotation==aoe)
    -- A Built In's handle is shown, fixed.
    local builtin=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),268,key(a,'rm.retail.monk.brewmaster')))
    assert(builtin.handle:GetText()=='brewmaster');builtin.handle.scripts.OnTextChanged(builtin.handle,true);assert(not builtin.handleDirty)
    -- A new rotation's handle follows its name until edited.
    local draft=assert(a:NewRotationDraftTarget(268,'class',false))
    local newPane=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),268,a:GetScopedRotationCoordinator():Key(draft)))
    newPane.name:SetText('Single Target');newPane.name.scripts.OnTextChanged(newPane.name,true)
    assert(newPane.handle:GetText()=='single-target' and newPane.handleDirty)
end)

test('copies and imports carry their own handle; exports carry the handle',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon;local data=a.RotationData
    local copyKey=assert(a:CloneDefaultRotation(268,'rm.retail.monk.brewmaster','My Brew'))
    assert(a:GetEditableRotation(268,copyKey).handle=='my-brew','copy handle '..tostring(a:GetEditableRotation(268,copyKey).handle))
    local exported=assert(a:GetRotationExportData(268,copyKey));assert((exported.body or exported).handle=='my-brew','export lost the handle')
    -- Importing it again: the handle is taken here, so the import gets a free one.
    local session=data.NewImportSession({Decode=function(_,v) return {kind=exported.format=='RotationMaster' and 'envelope' or 'legacy',original=v,value=data.CopyData(exported)} end},a:GetImportValidationOptions())
    local candidate=assert(session:Stage('copied'))
    local imported=assert(a:ApplyRotationImport(session,candidate.token,268,'My Brew again'))
    local importedKey=type(imported)=='table' and a:GetScopedRotationCoordinator():Key(imported) or imported
    local handle=a:GetEditableRotation(268,importedKey).handle
    assert(handle and handle~='my-brew' and handle:find('^my%-brew'),'imported handle '..tostring(handle))
end)

finish()
