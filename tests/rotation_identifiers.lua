-- Rotation identifiers (ID in the editor): a short, case-insensitive name for /rm set and lists.
-- The user's report: "/rm set Blizzard Assisted with brews" is
-- hard to type and case sensitive. Built Ins derive theirs from the pack id (unique per
-- class and edition across the whole corpus); your rotations store an editable one (made
-- from the name until you change it); /rm set takes an identifier first, then the exact name.
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

test('identifier format: letter first, letters digits _ -, 32 at most, case-insensitive, auto/default reserved',function()
    local f=T.new{level=10,specIndex=1};local data=f.addon.RotationData
    assert(data.NormalizeRotationIdentifier('BrewMaster')=='brewmaster' and data.NormalizeRotationIdentifier('a_b-9')=='a_b-9')
    for _,bad in ipairs({'','9lives','has space','dot.ted',string.rep('a',33),'auto','Default',5}) do assert(data.NormalizeRotationIdentifier(bad)==nil,tostring(bad)) end
    assert(data.SlugRotationIdentifier('Monk: Brewmaster (Retail)')=='monk-brewmaster-retail')
    assert(data.SlugRotationIdentifier('  2 Target Cleave!! ')=='r-2-target-cleave' and data.SlugRotationIdentifier('')=='rotation' and data.SlugRotationIdentifier('Auto')=='auto-rotation')
    assert(#data.SlugRotationIdentifier(string.rep('Long name ',10))<=32)
    local body={name='x',identifier='Bad Identifier',rotation={},cooldowns={}}
    local result=data.ValidateBody(body,f.addon:GetRotationValidationOptions());assert(not result.valid and result.diagnostics[1].code=='invalid-identifier')
    body.identifier='good';assert(data.ValidateBody(body,f.addon:GetRotationValidationOptions()).valid)
end)

test('every shipped Built In has a valid identifier, unique within its class and edition',function()
    local f,packs=corpus.load(5,1,'SHAMAN');local a=f.addon;local data=a.RotationData
    local groups,count={},0
    for _,pack in ipairs(packs) do
        local identifier=assert(a:GetBuiltinIdentifier(pack.id),pack.id..' has no identifier')
        assert(data.NormalizeRotationIdentifier(identifier)==identifier,pack.id..' identifier invalid: '..identifier)
        local group=table.concat(pack.applicability.families,'+')..':'..tostring(pack.applicability.class)
        groups[group]=groups[group] or {}
        assert(not groups[group][identifier],pack.id..' repeats '..identifier..' of '..tostring(groups[group][identifier]));groups[group][identifier]=pack.id;count=count+1
    end
    assert(count==#packs and count>100,'corpus too small: '..count)
    assert(a:GetBuiltinIdentifier('rm.retail.monk.brewmaster')=='brewmaster' and a:GetBuiltinIdentifier('rm.retail.monk.brewmaster.guide')=='brewmaster-guide')
    assert(a:GetBuiltinIdentifier('rm.retail.monk.initial')=='initial')
end)

test('/rm set takes an identifier in any case, names it with its identifier, and explains the rest',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    command(f,'set BrewMaster')
    assert(a.manualRotation and a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster','identifier did not select')
    assert(chat(f):find('manually switched to |cFFFFFFFFBlizzard Assisted with brews [brewmaster]',1,true),chat(f))
    assert(chat(f):find('automatically switched to |cFFFFFFFFBlizzard Assisted with brews [brewmaster]',1,true),'auto message lacks the identifier')
    command(f,'set auto');assert(not a.manualRotation)
    -- A rotation that cannot be selected says why; an unknown identifier lists the usable ones.
    command(f,'set brewmaster-GUIDE');assert(chat(f):find('[brewmaster-guide] cannot be selected',1,true) and chat(f):find('ships disabled',1,true),chat(f))
    command(f,'set nothing-here');assert(chat(f):find('Identifiers you can use now: brewmaster (or auto)',1,true),chat(f))
    -- The exact name still works.
    command(f,'set Blizzard Assisted with brews');assert(a.manualRotation and a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster')
    command(f,'set default');assert(a.manualRotation~=nil)
    -- /rm list: identifier — name — status for the live specialization.
    local list=table.concat(a:GetRotationIdentifierReport(),'\n')
    assert(list:find('brewmaster — Blizzard Assisted with brews (Built In) — active',1,true),list)
    assert(list:find('default — Default (fallback) — cannot be selected',1,true),list)
    assert(list:find('brewmaster-guide — ',1,true) and list:find('ships disabled',1,true) and list:find('windwalker — ',1,true) and list:find('not for this character now',1,true),list)
    assert(table.concat(a:GetRotationEligibilityReport(),'\n'):find('(Built In) [brewmaster]: ready',1,true))
    -- The minimap menu shows the identifier in brackets.
    local rows={};f.env.UIDropDownMenu_AddButton=function(r) rows[#rows+1]=r.text end;f.env.minimapInitialize()
    assert(table.concat(rows,'\n'):find('|cff5bc0ebBlizzard Assisted with brews [brewmaster]|r',1,true),table.concat(rows,'\n'))
end)

test('your rotations: an identifier made from the name until set, validated, unique, and /rm set finds it',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local aoe=custom(f,268,'AoE Cleave',{priority=50,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1}})
    assert(a:GetRotationIdentifier(268,aoe)=='aoe-cleave','derived identifier '..tostring(a:GetRotationIdentifier(268,aoe)))
    -- A name that slugs to a Built In's identifier takes a suffix.
    local clash=custom(f,268,'Brewmaster');assert(a:GetRotationIdentifier(268,clash)=='brewmaster-2')
    command(f,'set AOE-cleave');assert(a.manualRotation and a.currentRotation==aoe)
    -- Checks: format, reserved, and an identifier another rotation already uses (named).
    assert(a:CheckRotationIdentifier(268,aoe,'9x'):find('starts with a letter',1,true))
    assert(a:CheckRotationIdentifier(268,aoe,'auto'):find('reserved',1,true))
    assert(a:CheckRotationIdentifier(268,aoe,'BrewMaster'):find('Blizzard Assisted with brews already uses the identifier brewmaster',1,true))
    assert(a:CheckRotationIdentifier(268,aoe,'aoe-cleave')==nil and a:CheckRotationIdentifier(268,aoe,'Mine')==nil)
    -- The editor: Identifier, Priority, Enabled on one line; an invalid or taken identifier blocks Apply and says why.
    local parent=f.env.CreateFrame('Frame');parent:SetSize(1000,700)
    local pane=assert(a:CreateRotationEditor(parent,268,aoe))
    local _,toPriority=pane.identifier:GetPoint(1);assert(toPriority==pane.priorityLabel,'identifier is not left of priority')
    assert(pane.identifierLabel:GetText()=='ID','the editor labels the identifier ID')
    assert(pane.identifier:GetText()=='aoe-cleave')
    pane.identifier:SetText('brewmaster');pane.identifier.scripts.OnTextChanged(pane.identifier,true)
    assert(not pane.apply:IsEnabled() and pane.status:GetText():find('already uses the identifier brewmaster',1,true),'a taken identifier did not block Apply')
    pane.identifier:SetText('Big-Pull');pane.identifier.scripts.OnTextChanged(pane.identifier,true);assert(pane.apply:IsEnabled())
    assert(pane:Apply());assert(a:GetEditableRotation(268,aoe).identifier=='big-pull','identifier not stored lower-case')
    command(f,'set big-PULL');assert(a.currentRotation==aoe)
    -- A Built In's identifier is shown, fixed.
    local builtin=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),268,key(a,'rm.retail.monk.brewmaster')))
    assert(builtin.identifier:GetText()=='brewmaster');builtin.identifier.scripts.OnTextChanged(builtin.identifier,true);assert(not builtin.identifierDirty)
    -- A new rotation's identifier follows its name until edited.
    local draft=assert(a:NewRotationDraftTarget(268,'class',false))
    local newPane=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),268,a:GetScopedRotationCoordinator():Key(draft)))
    newPane.name:SetText('Single Target');newPane.name.scripts.OnTextChanged(newPane.name,true)
    assert(newPane.identifier:GetText()=='single-target' and newPane.identifierDirty)
end)

test('copies and imports carry their own identifier; exports carry the identifier',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon;local data=a.RotationData
    local copyKey=assert(a:CloneDefaultRotation(268,'rm.retail.monk.brewmaster','My Brew'))
    assert(a:GetEditableRotation(268,copyKey).identifier==nil and a:GetRotationIdentifier(268,a:GetScopedRotationCoordinator():Key(a:ResolveRotationReference(268,copyKey)))=='my-brew','copy identifier')
    -- A rotation with a stored identifier exports it.
    local key=custom(f,268,'Burst',{identifier='burst'})
    local exported=assert(a:GetRotationExportData(268,key));assert((exported.body or exported).identifier=='burst','export lost the identifier')
    local function import(name)
        local session=data.NewImportSession({Decode=function(_,v) return {kind=exported.format=='RotationMaster' and 'envelope' or 'legacy',original=v,value=data.CopyData(exported)} end},a:GetImportValidationOptions())
        local candidate=assert(session:Stage('copied'))
        local imported=assert(a:ApplyRotationImport(session,candidate.token,268,name))
        return a:GetEditableRotation(268,imported)
    end
    -- Importing it here: burst is taken, so the import's identifier comes from its name.
    local body=import('Burst again');assert(body.identifier==nil,'a taken imported identifier was kept: '..tostring(body.identifier))
    -- In another profile it is free and kept.
    a.db:SetProfile('Other')
    body=import('Burst');assert(body.identifier=='burst','a free imported identifier was dropped: '..tostring(body.identifier))
end)

test('a rotation saved with body.handle (the old name) keeps it as body.identifier after a one-time move',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local _,oldRef=custom(f,268,'Old Burst');local _,bothRef=custom(f,268,'Both Fields')
    local function stored(name)
        for _,map in pairs(a.db.profile.rotationStore.classes) do for _,rows in pairs(map) do for _,record in pairs(rows) do
            if record.body.name==name then return record.body end
        end end end
    end
    -- As a profile saved before the rename holds them.
    local old,both=stored('Old Burst'),stored('Both Fields');old.identifier=nil;old.handle='old-burst-x';both.identifier='both';both.handle='ignored'
    a.db.profile.rotationStore.legacy.rotations={[268]={flat={name='Legacy',handle='legacy-one',rotation={},cooldowns={}}}}
    assert(a:RefreshRotationProfileStorage())
    old,both=stored('Old Burst'),stored('Both Fields')
    assert(old.handle==nil and old.identifier=='old-burst-x' and both.handle==nil and both.identifier=='both','handle was not moved to identifier')
    local legacy=a.db.profile.rotationStore.legacy.rotations[268].flat;assert(legacy.handle==nil and legacy.identifier=='legacy-one','legacy body not moved')
    -- A refresh retires earlier keys; take them again.
    local coordinator=a:GetScopedRotationCoordinator();local oldKey,bothKey=coordinator:Key(oldRef),coordinator:Key(bothRef)
    assert(a:GetRotationIdentifier(268,oldKey)=='old-burst-x' and a:GetRotationIdentifier(268,bothKey)=='both')
    assert(a.RotationData.ValidateBody(old,a:GetRotationValidationOptions()).supported,'the moved body does not validate')
    command(f,'set OLD-burst-x');assert(a.manualRotation and a.currentRotation==oldKey,'/rm set does not find the moved identifier')
    -- Idempotent: a second refresh changes nothing.
    assert(a:RefreshRotationProfileStorage());assert(stored('Old Burst').identifier=='old-burst-x' and stored('Old Burst').handle==nil)
end)

finish()
