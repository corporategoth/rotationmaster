local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local codecData,codecDeps=dofile('tests/fixtures/codec.lua')();a.RotationData=codecData;a.NewRotationCodec=function() return codecData.NewCodec(codecDeps) end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
    for _,path in ipairs({'Platform/spells.lua','Help/general.lua','Help/conditions.lua','Help/effects.lua','Help/itemsets.lua','Help/announce.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/settings_general.lua','UI/settings_profiles.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_announces.lua','UI/settings_effects.lua','UI/settings_items.lua','UI/settings_conditions.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    local parent=create('Frame');parent:SetSize(1000,600)
    return f,parent
end
local function remove(p,key)
    p.fields[key or 'delete']:Click();if p.prompt and p.prompt.frame:IsShown() then p.prompt.accept:Click() end
end
local function pending(p)
    assert(p.pendingDeletion and p.roster.entries[1].value=='pending-delete','removed entity did not remain as a pending tombstone')
    assert(p.fields.apply:IsEnabled() and p.fields.viewChanges:IsEnabled(),'pending deletion has no apply or review path')
end
for _,kind in ipairs({'Effects','ItemSets','Announces','Categories'}) do
    test(kind..' staged removal does not mark a successor as edited and Discard restores selection',function()
        local f,parent=fixture();local a=f.addon;local p
        if kind=='Effects' then a.db.global.effects={A={name='A',type='pixel'},B={name='B',type='pixel'}};p=a:OpenNativeSettings(parent,kind)
        elseif kind=='ItemSets' then a.db.profile.itemsets={A={name='A',items={1}},B={name='B',items={2}}};p=a:OpenNativeSettings(parent,kind)
        elseif kind=='Announces' then a.db.profile.announces={{id='A',name='A',type='spell',spell=403,event='SUCCEEDED',announce='local',value='A'},{id='B',name='B',type='spell',spell=403,event='SUCCEEDED',announce='local',value='B'}};p=a:OpenNativeSettings(parent,kind)
        else a.conditionDefinitions={};a.conditionSpecials={};a.listConditions=function() return {} end;a.db.profile.condition_groups={{id='A',name='A',conditions={}},{id='B',name='B',conditions={}}};p=a:OpenNativeSettings(parent,'Conditions');p.mode='categories';p:Draw() end
        local field=kind=='Categories' and 'delete_category' or 'delete';local old=p.selection;local oldCategory=p.categorySelection
        remove(p,field);pending(p);p.fields.cancel:Click();assert(not p.pendingDeletion and p.selection==old and p.categorySelection==oldCategory and not p:IsSettingsDraftDirty(),'Discard left a removed-entry transaction')
        remove(p,field);pending(p);p.fields.apply:Click();assert(not p.pendingDeletion and not p:IsSettingsDraftDirty() and not p.fields.apply:IsEnabled(),'committed removal marked successor dirty')
        if kind=='Categories' then assert(a.db.profile.condition_groups[1].id=='B' and p.categorySelection=='B')
        elseif kind=='Announces' then assert(#a.db.profile.announces==1 and a.db.profile.announces[1].id=='B')
        elseif kind=='ItemSets' then assert(not a.db.profile.itemsets.A and a.db.profile.itemsets.B and p.selection=='B')
        else assert(not a.db.global.effects.A and a.db.global.effects.B and p.selection=='B') end
    end)
end
test('committing the last collection entry leaves an empty page without creating another draft',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={A={name='A',type='pixel'}};local p=a:OpenNativeSettings(parent,'Effects');remove(p);pending(p);p.fields.apply:Click()
    assert(not next(a.db.global.effects) and not p.creating and not p.fields.new_name and not p:IsSettingsDraftDirty() and not p.fields.apply:IsEnabled())
end)
test('releasing a pending deletion restores its selection and cannot leak a tombstone into another tab',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={A={name='A',type='pixel'}};local p=a:OpenNativeSettings(parent,'Effects');remove(p);pending(p);p:Release()
    assert(not p.pendingDeletion and a.db.global.effects.A);a:OpenNativeSettings(parent,'Announces',p);assert(not p.pendingDeletion and p.settingsKey=='Announces')
end)
finish()
