local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product)
    local f=F.new(product);local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local codecData,codecDeps=dofile('tests/fixtures/codec.lua')();a.RotationData=codecData;a.NewRotationCodec=function() return codecData.NewCodec(codecDeps) end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
    for _,path in ipairs({'Platform/spells.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/general.lua','Help/conditions.lua','Help/effects.lua','Help/itemsets.lua','Help/announce.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/cpu_profile.lua','UI/settings_general.lua','UI/settings_profiles.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_announces.lua','UI/settings_effects.lua','UI/settings_items.lua','UI/settings_conditions.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    local parent=create('Frame');parent:SetSize(1000,600)
    return f,parent
end
test('native settings reject invalid text and block navigation without losing the field',function()
    local f,parent=fixture();local a=f.addon;assert(a.CreateSettingsForm,'native form missing')
    local form=a:CreateSettingsForm(parent);local saved=2
    form:Open(function(p) p:Edit('number','Amount',saved,function(text) local n=tonumber(text);if not n then return nil end;return n end,function(v) saved=v end) end)
    local field=form.fields.number;field:SetText('bad');field.scripts.OnTextChanged(field,true)
    local left=false;assert(not form:RequestLeave(function() left=true end));assert(not left and saved==2 and field:GetText()=='bad')
    field:SetText('3');field.scripts.OnTextChanged(field,true);assert(form:RequestLeave(function() left=true end));assert(left and saved==3)
end)
test('pooled native callbacks cannot mutate a new page or replaced profile',function()
    local f,parent=fixture();local a=f.addon;assert(a.CreateSettingsForm,'native form missing')
    local form=a:CreateSettingsForm(parent);local n=0
    form:Open(function(p) p:Check('flag','Flag',false,function() n=n+1 end) end)
    local stale=form.fields.flag.scripts.OnClick;form:Open(function(p) p:Check('other','Other',false,function() n=n+10 end) end)
    stale();assert(n==0);form.fields.other:Click();assert(n==10)
    a.db.profile={};form.fields.other:Click();assert(n==10);form:Release();stale();assert(n==10)
end)
test('General controls preserve live callbacks and close their effect preview',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildGeneralSettings,'native General missing')
    a.db.profile={enable=true,poll=.1,minimap={hide=false},live_config_update=1,color={r=1,g=1,b=1,a=1},effect='e'};a.db.global.effects={e={name='Pixel',type='pixel'}}
    local enabled,cleared,scheduled=0,0,0;a.enable=function() enabled=enabled+1 end;a.disable=function() enabled=enabled-1 end
    a.Glow=function() end;a.HideGlow=function() cleared=cleared+1 end;a.RemoveAllCurrentGlows=function() end
    a.ScheduleRepeatingTimer=function() scheduled=scheduled+1;return 9 end;a.CancelTimer=function() end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildGeneralSettings(form) end)
    p.fields.enable:Click();assert(not a.db.profile.enable and enabled==-1)
    -- The live dots run only while the rotation editor is open: with none
    -- open, a new frequency schedules nothing; an open one is restarted.
    local restarted=0;a.RestartLiveStatus=function() restarted=restarted+1 end
    p.fields.live_config_update:SetValue(3);assert(a.db.profile.live_config_update==3 and scheduled==0 and restarted==1)
    local stale=p.fields.enable.scripts.OnClick;p:Release();assert(cleared>0);stale();assert(enabled==-1)
end)
test('General CPU capture controls bypass pending edits and retain callback leases',function()
    local f,parent=fixture();local a=f.addon
    a.db.profile.poll=.15
    local calls={};a.print=function() end
    a.StartCPUProfile=function(_,duration) calls[#calls+1]='start:'..duration;return true end
    local running=false
    a.StartCPUProfile=function(_,duration) calls[#calls+1]='start:'..duration;running=true;return true end
    a.IsCPUProfileRunning=function() return running end
    a.StopCPUProfile=function() calls[#calls+1]='stop';running=false;return true end
    a.GetCPUProfileReport=function() return 'CPU report data' end
    a.ShowConditionText=function(_,text,title) assert(text=='CPU report data' and title=='CPU profile');calls[#calls+1]='report' end
    local p=a:OpenNativeSettings(parent,'General')
    -- An uncommitted native input must neither block a diagnostic nor change live polling.
    local edit=p:Edit('unrelated','Unrelated','',function() return nil end,function() error('must not flush') end)
    edit:SetText('invalid');edit.scripts.OnTextChanged(edit,true)
    local wasDirty=p:IsSettingsDraftDirty()
    assert(p.fields.cpu_capture and p.fields.cpu_report and not p.fields.cpu_cancel and not p.fields.cpu_probe,'capture column controls differ')
    -- Capture becomes Stop while running; the report waits for a finished capture.
    p.fields.cpu_capture:Click();assert(p.fields.cpu_capture:GetText()=='Stop CPU capture' and not p.fields.cpu_report:IsEnabled())
    p.fields.cpu_capture:Click();assert(p.fields.cpu_capture:GetText()=='Capture CPU (10s)' and p.fields.cpu_report:IsEnabled())
    p.fields.cpu_report:Click()
    assert(table.concat(calls,',')=='start:10,stop,report' and a.db.profile.poll==.15)
    assert(p:IsSettingsDraftDirty()==wasDirty,'diagnostics must not change pending edits')
    local stale=p.fields.cpu_capture.scripts.OnClick;p:Release();stale();assert(#calls==3)
end)
test('profile replacement brackets runtime lifecycle and stale confirmations do not execute',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildProfileSettings,'native Profiles missing')
    local current='One';local calls={};a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() return {'One','Two'} end
    a.db.SetProfile=function(_,name) calls[#calls+1]='set:'..name;current=name;a.db.profile={} end
    a.DisableRotation=function() calls[#calls+1]='disable' end;a.EnableRotation=function() calls[#calls+1]='enable' end;a.RefreshConfiguration=function() calls[#calls+1]='refresh' end
    a.db.ResetProfile=function() calls[#calls+1]='reset' end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildProfileSettings(form) end)
    p.fields.reset:Click();local stale=p.prompt.accept.scripts.OnClick;p:Release();stale();assert(#calls==0)
    p:Open(function(form) a:BuildProfileSettings(form) end);p.roster.rows[2]:Click();p.fields.activate:Click()
    assert(table.concat(calls,',')=='disable,set:Two,enable,refresh')
end)
test('Announces opens without writes and validates a new action before adding it',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildAnnounceSettings,'native Announces missing')
    a.db.profile.announces={};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end)
    assert(#a.db.profile.announces==0);p.fields.add:Click();assert(#a.db.profile.announces==0)
    a.Platform.GetSpellInfo=function(_,id) return tonumber(id)==403 and {name='Lightning Bolt',spellID=403,iconID=10} end;a.SpellCatalog:UpdateSpell(403);a.specSpells={[0]={[403]=true}};a.spellBookStatus={player={complete=true}}
    local input=p.fields.new_action;input:SetText('403');input.scripts.OnTextChanged(input,true);p.fields.add:Click()
    assert(#a.db.profile.announces==1 and a.db.profile.announces[1].spell==403)
    local toggle=p.fields.enabled1;toggle:Click();assert(a.db.profile.announces[1].disabled)
    local stale=p.fields.delete1.scripts.OnClick;p:Release();stale();assert(#a.db.profile.announces==1)
end)
test('Effects opens without filling defaults and supports native edit and sequence actions',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildEffectSettings,'native Effects missing')
    a.db.global.effects={pixel={name='Outline',type='pixel'},pulse={name='Pulse',type='pulse',sequence={1,.5}}};a.RemoveAllCurrentGlows=function() end;a.HideGlow=function() end;a.Glow=function() end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    assert(a.db.global.effects.pixel.lines==nil,'opening Effects wrote defaults')
    p.fields.lines:SetValue(10);assert(a.db.global.effects.pixel.lines==10)
    p.roster.rows[2]:Click();assert(p.selection=='pulse')
    p.fields.seq1up:Click();assert(a.db.global.effects.pulse.sequence[1]==1)
    p.fields.seq2up:Click();assert(a.db.global.effects.pulse.sequence[1]==.5)
end)
test('Item Sets preserves global moves ordering and clears binding only after confirmation',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildItemSettings,'native Item Sets missing')
    a.db.char={bindings={set={1}}};a.db.profile.itemsets={set={name='Consumables',items={1,2}}};a.db.global.itemsets={};a.UpdateItemSetButtons=function() end;a.UpdateBoundButton=function() end;a.EndHighlightSlot=function() end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildItemSettings(form) end)
    p.fields.global:Click();assert(a.db.global.itemsets.set and not a.db.profile.itemsets.set)
    p.fields.item2up:Click();assert(a.db.global.itemsets.set.items[1]==2)
    p.fields.delete:Click();assert(a.db.global.itemsets.set);p.prompt.accept:Click();assert(not a.db.global.itemsets.set and not a.db.char.bindings.set)
end)
test('Conditions manages membership hidden flags and category order without writing on open',function()
    local f,parent=fixture();local a=f.addon;assert(a.BuildConditionSettings,'native Conditions missing')
    a.conditionDefinitions={A={description='Alpha'},B={description='Beta'}};a.conditionSpecials={}
    a.db.global.custom_conditions={};a.db.profile.condition_groups={{id='g',name='Group',conditions={'A'}}};a.db.profile.switch_conditions={'A'};a.db.profile.disabled_conditions={}
    a.listConditions=function(_,group) if group=='g' then return {'A'} elseif group=='SWITCH' then return {'A'} else return {'A','B'} end end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end)
    assert(p.roster.footerManage and p.roster.manage:IsShown() and p.roster.manage:GetText()=='Manage categories');assert(p.roster.actionButtons[3].point[3]>p.roster.manage.point[3],'Manage categories must sit below Import/Export and Compare')
    assert(#a.db.profile.disabled_conditions==0);p.fields.hidden:Click();assert(a.db.profile.disabled_conditions[1]=='A')
    p.fields.switch:Click();assert(#a.db.profile.switch_conditions==0)
    p.fields.move_to:Click();p.menu.rows[2]:Click();assert(#a.db.profile.condition_groups[1].conditions==1);p.fields.apply_move:Click();assert(#a.db.profile.condition_groups[1].conditions==0)
end)
test('the shell routes every built-in settings tab to reusable native forms',function()
    local f,parent=fixture();local a=f.addon;a.SetupOptions=function() end
    a.db.profile={rotations={},announces={},itemsets={},condition_groups={},switch_conditions={},disabled_conditions={},other_conditions_order={}};a.db.global={effects={},itemsets={},custom_conditions={}};a.db.char={bindings={}}
    a.conditionDefinitions={};a.conditionSpecials={};a.listConditions=function() return {} end
    a.db.GetCurrentProfile=function() return 'One' end;a.db.GetProfiles=function() return {'One'} end
    a.CreateRotationBrowser=nil;a.BuildConfigurationPane=function() error('legacy built-in page opened') end
    f.load('UI/config.lua')
    local shell=a:ShowConfig('General');assert(shell.nativePane and shell.pane.fields.poll)
    local initial=shell.pane;local stale=initial.fields.enable.scripts.OnClick
    for _,key in ipairs({'Conditions','Effects','ItemSets','Announces','Profiles','General'}) do shell:SelectSection(key);assert(shell.nativePane and shell.pane.active and shell.settingsPanes[key]==shell.pane) end
    assert(shell.pane==initial);stale();assert(a.db.profile.enable==nil)
    shell:Hide();assert(not initial.active and not initial.frame:IsShown())
end)
test('reopening a different selector invalidates prior menu rows',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);local calls=0
    p:Open(function(form) form:Choice('first','First',nil,{{value=1,text='One'}},function() calls=calls+1 end);form:Choice('second','Second',nil,{{value=2,text='Two'}},function() calls=calls+10 end) end)
    p.fields.first:Click();local stale=p.menu.rows[1].scripts.OnClick;p.fields.second:Click();stale();assert(calls==0)
    p.menu.rows[1]:Click();assert(calls==10 and p.fields.second:GetText()=='Two')
end)
test('invalid settings text can be cancelled without changing saved values',function()
    local f,parent=fixture();local p=f.addon:CreateSettingsForm(parent);local value=1
    p:Open(function(form) form:Edit('n','Number',value,tonumber,function(v) value=v end) end)
    local c=p.fields.n;c:SetText('bad');c.scripts.OnTextChanged(c,true);c.scripts.OnEscapePressed(c)
    assert(c:GetText()=='1' and value==1 and p:FlushEdits())
end)
test('native transfer validates without writes and its released import callback is inert',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);p:Open(function() end);local saved='old'
    a:ShowSettingsTextTransfer(p,'Items','old',function(text) if text=='bad' then return false,'Invalid' end;saved=text;return true end)
    local d=p.textDialog;d.input:SetText('bad');d.apply:Click();assert(saved=='old' and d.status:GetText()=='Invalid' and d.frame:IsShown())
    local stale=d.apply.scripts.OnClick;p:Release();d.input:SetText('new');stale();assert(saved=='old' and not d.frame:IsShown())
end)
test('help is a formatted native article without report or duplicate close controls',function()
    local f=fixture();local a=f.addon;local d=a:ShowWorkbenchHelp('Cooldown',a:WorkbenchInteractionHelp('cooldown'),'Mine')
    assert(d.chrome.version:GetText()=='Help' and d.chrome.author:GetText()=='Mine' and #d.rows>=6)
    assert(d.copy==nil and d.edit==nil and d.closeButton==nil and d.close)
    d.close:Click();assert(not d.frame:IsShown())
end)
test('closing native settings commits valid text and keeps invalid edits visible',function()
    local f,parent=fixture();local a=f.addon;a.SetupOptions=function() end
    a.db.profile={announces={},itemsets={},rotations={},condition_groups={}};a.db.global={effects={},itemsets={},custom_conditions={}};a.db.char={};a.listConditions=function() return {} end
    f.load('UI/config.lua');local shell=a:ShowConfig('General');local p=shell.pane
    local c=p.fields.xoffs;c:SetText('bad');c.scripts.OnTextChanged(c,true);shell:Hide();assert(shell.frame:IsShown() and p.active)
    c:SetText('12');c.scripts.OnTextChanged(c,true);shell:Hide();assert(p.prompt.frame:IsShown() and a.db.profile.xoffs==nil);p.prompt.accept:Click();assert(not shell.frame:IsShown() and a.db.profile.xoffs==12)
end)
test('the real special-frame Escape path obeys invalid settings validation',function()
    local f,parent=fixture();local a=f.addon;f.env.UISpecialFrames={};a.SetupOptions=function() end
    f.load('UI/config.lua');local shell=a:ShowConfig('General');local p=shell.pane;local c=p.fields.xoffs
    c:SetText('bad');c.scripts.OnTextChanged(c,true)
    local function escape() local frame=f.env[f.env.UISpecialFrames[1]];assert(frame and frame:IsShown());frame:Hide() end
    escape();assert(shell.frame:IsShown() and p.active,'native Escape discarded invalid text')
    p.prompt.cancel:Click();c:SetText('9');c.scripts.OnTextChanged(c,true);escape();assert(p.prompt.frame:IsShown() and a.db.profile.xoffs==nil);p.prompt.accept:Click();assert(not shell.frame:IsShown() and a.db.profile.xoffs==9)
end)
test('reselecting the same announcement type preserves its action and exact rank',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.announces={{type='spell',spell=403,ranked=true,event='SUCCEEDED',announce='local',value='Cast'}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end);p.fields.entry1type:Click();p.menu.rows[1]:Click()
    assert(a.db.profile.announces[1].spell==403 and a.db.profile.announces[1].ranked)
end)
test('incompatible effect type changes prepare a valid sequence before saving or previewing',function()
    local f,parent=fixture();local a=f.addon;local effect={name='Pulse',type='pulse',frequency=.25,sequence={1,.5}};a.db.global.effects={pulse=effect}
    a.Glow=function(_,_,_,v) if v.type=='custom' then for _,entry in ipairs(v.sequence) do assert(type(entry)=='table') end end end;a.HideGlow=function() end;a.RemoveAllCurrentGlows=function() end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end);p.fields.type:Click()
    for _,row in ipairs(p.menu.rows) do if row:GetText()=='Custom' then row:Click();break end end
    local saved=a.db.global.effects.pulse;assert(saved.type=='custom' and #saved.sequence==0 and p.fields.sequence_add)
end)
test('Other category can order implicit conditions without materializing on open',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'},B={description='Beta'}};a.conditionSpecials={};a.db.global.custom_conditions={}
    a.db.profile.condition_groups={};a.db.profile.other_conditions_order={};a.listConditions=function() return {'A','B'} end
    local p=a:CreateSettingsForm(parent);p.category='DEFAULT';p:Open(function(form) p.category='DEFAULT';a:BuildConditionSettings(form) end)
    assert(#a.db.profile.other_conditions_order==0 and p.roster.rows[1].down and p.roster.rows[1].down:IsEnabled())
    p.roster.rows[1].down:Click();assert(a.db.profile.other_conditions_order[1]=='B' and a.db.profile.other_conditions_order[2]=='A')
end)
test('RGBA Escape restores committed display without rounding the saved color',function()
    local f,parent=fixture();local a=f.addon;local saved={r=.12345678,g=.87654321,b=.25,a=1};local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:Color('c','Color',saved,function(v) saved=v end) end)
    local c=p.fields.c_r;c:SetText('bad');c.scripts.OnTextChanged(c,true);assert(c.scripts.OnEscapePressed,'color has no Escape cancellation');c.scripts.OnEscapePressed(c)
    assert(c:GetText()=='0.123' and saved.r==.12345678 and p:FlushEdits())
end)
test('RGBA cancellation follows the last picker color rather than an obsolete baseline',function()
    local f,parent=fixture();local a=f.addon;local saved={r=.1,g=.2,b=.3,a=1};local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:Color('c','Color',saved,function(v) saved=v end) end)
    p.fields.c:Click();p.fields.c.picker:Choose(0,1,.5,1);p.fields.c.picker:Close(true)
    local c=p.fields.c_r;c:SetText('bad');c.scripts.OnTextChanged(c,true);c.scripts.OnEscapePressed(c)
    assert(c:GetText()=='0.500' and saved.r==.5)
end)
test('native selectors are owned above the form outside its scrolling content',function()
    local f,parent=fixture();local p=f.addon:CreateSettingsForm(parent)
    p:Open(function(form) form:Choice('pick','Pick',nil,{{value='A',text='Alpha'}},function() end) end)
    p.fields.pick:Click();assert(p.menu.frame:GetParent()==f.env.UIParent and p.menu.frame:IsShown(),'selector must be outside scroll clipping')
    p.menu.rows[1]:Click();assert(not p.menu.frame:IsShown())
end)
test('collection rosters search select and refuse navigation with invalid pending edits',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);assert(p.UseRoster,'missing collection roster');local selected='A'
    p:Open(function(form)
        form:UseRoster({{value='A',text='Alpha'},{value='B',text='Beta'}},selected,function(id) selected=id;form:Draw() end)
        form:Edit('n','Number',1,tonumber,function() end)
    end)
    assert(#p.roster.matches==2);local n=p.fields.n;n:SetText('bad');n.scripts.OnTextChanged(n,true);p.roster.rows[2]:Click();assert(selected=='A')
    n.scripts.OnEscapePressed(n);p.roster.search:SetText('Beta');p.roster.search.scripts.OnTextChanged(p.roster.search,true);assert(#p.roster.matches==1)
    p.roster.rows[1]:Click();assert(selected=='B')
end)
test('General keeps whole categories in responsive columns and sliders accept numeric values',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildGeneralSettings(form) end)
    assert(p.columns and p.fields.enable:GetParent()==p.columns[1] and p.fields.effect:GetParent()==p.columns[2])
    local raw=assert(p.fields.poll_value,'slider has no numeric field');raw:SetText('0.25');raw.scripts.OnTextChanged(raw,true);raw.scripts.OnEnterPressed(raw);assert(a.db.profile.poll==.25)
    p:SetWidth(700);a:FlushWorkbenchReflow();assert(p.fields.enable:GetParent()==p.child and p.fields.effect:GetParent()==p.child)
end)
test('native spell and item references display names icons and commit exact IDs',function()
    local f,parent=fixture();local a=f.addon
    a.Platform.GetSpellInfo=function(_,id) return tonumber(id)==403 and {name='Lightning Bolt',spellID=403,iconID=10} end;a.SpellCatalog:UpdateSpell(403)
    f.env.GetItemInfo=function(id) local name=tonumber(id)==1 and 'Water';return name,nil,nil,nil,nil,nil,nil,nil,nil,11 end
    local p=a:CreateSettingsForm(parent);local chosen
    p:Open(function(form) form:Spell('s','Spell',403,nil,function() end);form:Item('i','Item',1,function(v) chosen=v end) end)
    assert(p.fields.s:GetText()=='Lightning Bolt' and p.fields.s.referenceIcon.texture==10)
    local c=p.fields.i;assert(c:GetText()=='Water' and c.referenceIcon.texture==11)
    c:SetText('1');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c);assert(chosen==1)
end)
test('selectors dismiss on outside click without changing the selected value',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);local selected='A';local down=false
    f.env.IsMouseButtonDown=function() return down end;f.env.MouseIsOver=function() return false end
    p:Open(function(form) form:Choice('e','Effect',selected,{{value='A',text='A'},{value='B',text='B'}},function(v) selected=v end) end)
    p.fields.e:Click();local menu=p.menu;assert(menu.frame:IsShown());assert(menu.frame.scripts.OnUpdate,'no outside-click observer')
    down=true;menu.frame.scripts.OnUpdate();assert(not menu.frame:IsShown() and selected=='A')
end)
test('General page help retains authored explanations without scattering question marks',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildGeneralSettings(form) end)
    assert(not p.fields.poll_help)
    local all=a:WorkbenchPageHelp('General');local fields={};for _,entry in ipairs(all) do fields[entry.title]=entry.text end
    for _,caption in ipairs({'Enable','Polling Interval (seconds)','Idle Re-check Interval (seconds)','Auto-Switch Re-check Interval (seconds)','Live Status Update Frequency (seconds)','Minimap Icon','Default rotation view','Disable Bar Highlighting','Spell History Memory (seconds)','Combat History Memory (seconds)','Damage History Memory (seconds)','Preview Spells','Effect','Magnification','Highlight Color','Anchor','V','H','Log Level','Detailed Profiling'}) do assert(fields[caption],caption..' missing help') end
    local order={};for i,entry in ipairs(all) do order[entry.title]=i end;assert(order['Disable Bar Highlighting']==order['Enable']+1 and order['Minimap Icon']==order['Disable Bar Highlighting']+1 and order['Polling Interval (seconds)']==order['Minimap Icon']+1 and order['Magnification']==order['Effect']+1)
end)

test('General help localizes whole field explanations in the visible control order',function()
    local f,parent=fixture();local a=f.addon;local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
    local controls={'enable','disable_buttons','minimap','poll','idle_poll','autoswitch_poll','live_config_update','rotation_view',
        'spell_history','combat_history','damage_history','preview_spells','preview_opacity','preview_locked','preview_vertical','preview_reset',
        'effect','magnification','color','setpoint','yoffs','xoffs','loglevel','detailed_profiling','cpu_capture','cpu_report'}
    for _,key in ipairs(controls) do L['Help.General.'..key]='Translated field '..key end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildGeneralSettings(form) end)
    local found,last={},0
    for index,entry in ipairs(a:GetGeneralOptionHelp()) do if entry.id then found[entry.id]={entry=entry,index=index} end end
    for _,key in ipairs(controls) do
        assert(p.fields[key],'test fixture did not expose actual control '..key)
        local row=assert(found[key],'missing authored help for '..key)
        assert(row.entry.text=='Translated field '..key,'field explanation bypassed localization: '..key)
        assert(row.index>last,'help order differs from controls: '..key);last=row.index
    end
end)

test('General lists the tooltip options, defaults them on, and applies them through the draft',function()
    local f,parent=fixture();local a=f.addon
    local refreshed=0;a.RefreshTooltipIntegration=function() refreshed=refreshed+1 end
    local p=a:OpenNativeSettings(parent,'General')
    local keys={'tooltips','tooltip_itemsets','tooltip_rotations','tooltip_conditions','tooltip_limit'}
    for _,key in ipairs(keys) do assert(p.fields[key],key..' missing') end
    assert(p.fields.tooltips:GetChecked() and p.fields.tooltip_itemsets:GetChecked() and p.fields.tooltip_rotations:GetChecked(),'on by default')
    assert(not p.fields.tooltip_conditions:GetChecked(),'conditions off by default')
    assert(p.fields.tooltip_limit:GetValue()==3,'three names by default')
    -- Everything is staged until Apply.
    p.fields.tooltip_limit:SetValue(5);p.fields.tooltip_conditions:Click()
    assert(a.db.profile.tooltip_limit==nil and a.db.profile.tooltip_conditions==nil and refreshed==0,'staged, not applied')
    p.fields.tooltips:Click()
    assert(not p.fields.tooltip_itemsets:IsEnabled() and not p.fields.tooltip_rotations:IsEnabled() and not p.fields.tooltip_conditions:IsEnabled(),'master off disables the others')
    assert(p:SaveSettingsDraft());assert(a.db.profile.tooltips==false and a.db.profile.tooltip_conditions==true and a.db.profile.tooltip_limit==5 and refreshed==1,'applied once, the integration refreshed')
    -- Discard leaves the saved values alone.
    p=a:OpenNativeSettings(parent,'General');p.fields.tooltips:Click();p:DiscardSettingsDraft()
    assert(a.db.profile.tooltips==false and refreshed==1)
    -- The scope of the General draft carries every tooltip key, or Apply would drop them.
    local source=io.open('UI/settings_collections.lua'):read('*a')
    for _,key in ipairs(keys) do assert(source:find("'"..key.."'",1,true),key..' not in the General transaction scope') end
end)
test('the tooltip options have help text in the General help, after the highlight options and before the debug options',function()
    local f=fixture();local a=f.addon;local order,entries={},{}
    for index,entry in ipairs(a:GetGeneralOptionHelp()) do if entry.id then order[entry.id]=index;entries[entry.id]=entry end end
    for _,key in ipairs({'tooltips','tooltip_itemsets','tooltip_rotations','tooltip_conditions','tooltip_limit'}) do
        assert(entries[key] and entries[key].text~='' and not entries[key].text:find('^Help%.General'),key..' has no help text')
    end
    assert(order.tooltips<order.tooltip_itemsets and order.tooltip_itemsets<order.tooltip_rotations and order.tooltip_rotations<order.tooltip_conditions and order.tooltip_conditions<order.tooltip_limit)
    assert(order.xoffs<order.tooltips and order.tooltip_limit<order.loglevel)
end)
test('item announcements preserve item-set and custom-list storage and new announcements get an identity',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={potions={name='Potions',items={1}}};a.db.global.itemsets={}
    a.db.profile.announces={{id='old',type='item',item='potions',event='SUCCEEDED',announce='local',value='Used'}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end)
    assert(p.fields.entry1action_set and p.fields.entry1action_set:GetText()=='Potions' and a.db.profile.announces[1].item=='potions')
    p.fields.entry1action_set:Click();p.menu.rows[1]:Click();local c=p.fields.entry1action_new
    c:SetText('1');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c)
    assert(type(a.db.profile.announces[1].item)=='table' and a.db.profile.announces[1].item[1]==1)
    p.roster.new:Click();p.fields.new_type:Click();p.menu.rows[3]:Click();p.fields.new_action_new:SetText('1');p.fields.new_action_new.scripts.OnTextChanged(p.fields.new_action_new,true);p.fields.add:Click()
    assert(type(a.db.profile.announces[2].id)=='string' and type(a.db.profile.announces[2].item)=='table')
end)
test('other settings Help pages retain their authored field descriptions',function()
    local f=fixture();local a=f.addon
    for topic,title in pairs({Conditions='Hidden',Effects='Thickness',ItemSets='Global',Announces='Event'}) do
        local found=false;for _,entry in ipairs(a:WorkbenchPageHelp(topic)) do if entry.title==title and #entry.text>15 then found=true end end;assert(found,topic..' lost '..title..' help')
    end
end)
test('Effects help covers every real effect type and its sequence controls with whole translations',function()
    local f,parent=fixture();local a=f.addon;local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
    local variants={
        texture={texture='texture'},
        pixel={lines='pixel.lines',frequency='pixel.frequency',length='pixel.length',thickness='pixel.thickness'},
        autocast={particles='autocast.particles',frequency='autocast.frequency',scale='autocast.scale'},
        blizzard={frequency='blizzard.frequency'},
        proc={duration='proc.duration',startAnim='proc.startAnim'},
        dazzle={texture='texture',frequency='dazzle.frequency',seq1='sequence.color'},
        animate={frequency='animate.frequency',seq1='sequence.texture'},
        pulse={texture='texture',frequency='pulse.frequency',seq1='sequence.magnification'},
        rotate={texture='texture',frequency='rotate.frequency',steps='rotate.steps',reverse='rotate.reverse'},
        custom={frequency='custom.frequency',seq1texture='sequence.texture',seq1angle='sequence.angle',seq1mag='sequence.magnification',seq1color='sequence.color'},
    }
    for _,id in ipairs({'name','type','save','delete','collections','sequence','sequence.texture','sequence.color','sequence.magnification','sequence.angle'}) do L['Help.Effects.'..id]='Translated effect '..id end
    for kind,fields in pairs(variants) do
        L['Help.Effects.type.'..kind]='Translated type '..kind
        for _,id in pairs(fields) do L['Help.Effects.'..id]='Translated effect '..id end
    end
    for kind,fields in pairs(variants) do
        local entry=kind=='animate' and 'texture' or kind=='pulse' and 1 or kind=='dazzle' and {r=1,g=1,b=1,a=1} or {texture='texture',angle=0,magnification=1,color={r=1,g=1,b=1,a=1}}
        a.db.global.effects={e={name='Effect',type=kind,texture='texture',sequence={entry}}}
        local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
        local docs={};for _,row in ipairs(a:GetDocument_layout_effects_options_help()) do if row.id then docs[row.id]=row.text end end
        assert(docs['type.'..kind]=='Translated type '..kind,'missing localized type documentation: '..kind)
        for control,id in pairs(fields) do
            assert(p.fields[control],'fixture did not render '..kind..'.'..control)
            assert(docs[id]=='Translated effect '..id,'missing localized field help: '..kind..'.'..control)
        end
        for _,id in ipairs({'name','type','save','delete','collections'}) do assert(docs[id]=='Translated effect '..id,'missing effect control help: '..id) end
        p:Release()
    end
end)

test('category maintenance is separate from condition details and deletion keeps definitions',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.conditionSpecials={};a.db.global.custom_conditions={};a.db.profile.condition_groups={{id='g',name='Group',conditions={'A'}}};a.listConditions=function() return {'A'} end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end)
    assert(not p.fields.new_group_name and not p.fields.group_name and p.roster.manage,'category maintenance is mixed into condition details')
    p.roster.manage:Click();assert(p.fields.group_name and not p.fields.hidden)
    local c=p.fields.group_name;c:SetText('Renamed');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c);assert(a.db.profile.condition_groups[1].name=='Renamed')
    p.fields.delete_category:Click();assert(#a.db.profile.condition_groups==1);p.prompt.accept:Click();assert(#a.db.profile.condition_groups==0 and a.conditionDefinitions.A)
    p.roster.manage:Click();assert(p.fields.hidden and not p.fields.new_group_name)
end)
test('successive announcement item edits and add/delete keep the current sequence',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.announces={{id='old',type='item',item={1,2},event='SUCCEEDED',announce='local',value='Used'}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end)
    local function edit(key,value) local c=p.fields[key];c:SetText(value);c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c) end
    edit('entry1action1','3');edit('entry1action2','4');assert(table.concat(a.db.profile.announces[1].item,',')=='3,4')
    edit('entry1action_new','5');assert(table.concat(a.db.profile.announces[1].item,',')=='3,4,5')
    edit('entry1action1','6');p.fields.entry1action_delete2:Click();assert(table.concat(a.db.profile.announces[1].item,',')=='6,5')
end)
test('category imports move membership between named groups and Other using the real list implementation',function()
    local f,parent=fixture();local a=f.addon;f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');a:RegisterCondition('A',{description='Alpha'});a.conditionSpecials={}
    a.db.profile.condition_groups={{id='g',name='Group',conditions={}}};a.db.profile.other_conditions_order={'A'};a.db.profile.switch_conditions={};a.db.profile.disabled_conditions={};a.db.global.custom_conditions={}
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end)
    p.fields.transfer:Click();p.textDialog.input:SetText('A');p.textDialog.apply:Click();assert(a:listConditions('g',true)[1]=='A' and not a:SettingsContains(a:listConditions('DEFAULT',true),'A'))
    p.categorySelection='DEFAULT';p:Draw();p.fields.transfer:Click();p.textDialog.input:SetText('A');p.textDialog.apply:Click();assert(#a:listConditions('g',true)==0 and a:listConditions('DEFAULT',true)[1]=='A')
end)
test('collection rename refreshes searchable rows without rebuilding pending details',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Before',type='pixel'}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    local c=p.fields.name;c:SetText('After');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c)
    local lines=p.fields.lines_value;lines:SetText('bad');lines.scripts.OnTextChanged(lines,true)
    p.roster.search:SetText('After');p.roster.search.scripts.OnTextChanged(p.roster.search,true);assert(#p.roster.matches==1 and p.roster.matches[1].text=='After');assert(p.fields.lines_value==lines and lines:GetText()=='bad')
    p:Release();a.db.profile.itemsets={s={name='Set before',items={1}}};p:Open(function(form) a:BuildItemSettings(form) end);c=p.fields.name;c:SetText('Set after');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c)
    p.roster.search:SetText('Set after');p.roster.search.scripts.OnTextChanged(p.roster.search,true);assert(#p.roster.matches==1)
end)
test('typed reference commit refreshes the displayed icon',function()
    local f,parent=fixture();local a=f.addon;f.env.GetItemInfo=function(id) id=tonumber(id);return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,id*10 end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) form:Item('i','Item',1,function() end) end);local c=p.fields.i;c:SetText('2');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c)
    assert(c:GetText()=='Item 2' and c.referenceIcon.texture==20)
end)
test('Conditions Help describes category management separately from condition ordering',function()
    local f=fixture();local entries=f.addon:WorkbenchPageHelp('Conditions');local text={};for _,entry in ipairs(entries) do text[#text+1]=entry.title..' '..entry.text end;text=table.concat(text,'\n')
    assert(text:find('Manage categories',1,true) and text:find('condition ordering',1,true) and not text:find('Select which condition group you wish to modify',1,true))
end)
test('ordered native rows drag through one gap and reject no-op stale or invalid moves',function()
    local f,parent=fixture();local a=f.addon;local values={'one','two','three'};local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:OrderedCollection('rows',values,function(i) return values[i] end,function(form,i) form:Edit('n'..i,'Value',i,tonumber,function() end) end,function() end) end)
    local view=p.ordered.rows;assert(not view.rows[1].up:IsEnabled() and not view.rows[3].down:IsEnabled())
    -- The whole card is the drag source; there is no separate grip.
    local card=view.rows[1];assert(not card.header:IsShown(),'card still shows a title or grip');card.scripts.OnDragStart(card);assert(view.ghost:IsShown() and view.drag==1)
    assert(not view:CanDrop(1) and not view:CanDrop(2) and view:CanDrop(4));view:Drop(4);assert(table.concat(values,',')=='two,three,one' and not view.ghost:IsShown())
    local stale=view;p:Draw();stale:Drop(1);assert(table.concat(values,',')=='two,three,one')
    local c=p.fields.n1;c:SetText('bad');c.scripts.OnTextChanged(c,true);p.ordered.rows.rows[1].down:Click();assert(values[1]=='two')
    p:Release();assert(not p.ordered.rows.ghost:IsShown())
end)
test('all effect sequence variants and item entries use the shared ordered controls',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent)
    for kind,sequence in pairs({animate={'a','b'},pulse={1,.5},dazzle={{r=1,g=1,b=1,a=1},{r=0,g=0,b=0,a=1}},custom={{texture='a',color={r=1,g=1,b=1,a=1},magnification=1},{texture='b',color={r=0,g=0,b=0,a=1},magnification=.5}}}) do
        a.db.global.effects={e={name='Effect',type=kind,sequence=sequence}};p:Open(function(form) a:BuildEffectSettings(form) end);assert(p.ordered['sequence_e']);local second=sequence[2];p.fields.seq2up:Click();assert(a.db.global.effects.e.sequence[1]==second)
    end
    p:Release();a.db.profile.itemsets={s={name='Items',items={1,2}}};p:Open(function(form) a:BuildItemSettings(form) end);assert(p.ordered.items_s.compact);p.fields.item2up:Click();assert(a.db.profile.itemsets.s.items[1]==2)
end)
test('effects and item sets expose one roster action grid with self-excluding comparisons',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={a={name='Alpha',type='pixel'},b={name='Beta',type='pixel'}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    assert(p.roster.actionButtons and #p.roster.actionButtons==4 and p.fields.compare)
    p.fields.compare:Click();assert(p.menu.rows[1]:GetText()=='Beta' and (not p.menu.rows[2] or not p.menu.rows[2]:IsShown()));p.menu.rows[1]:Click();assert(p.comparison and p.comparison.frame:IsShown())
    local comparison=p.comparison;p:Release();assert(not comparison.frame:IsShown())
    a.db.profile.itemsets={a={name='One',items={1}},b={name='Two',items={2}}};p:Open(function(form) a:BuildItemSettings(form) end);assert(p.fields.compare and p.fields.duplicate and p.fields.transfer)
end)
test('announcement creation has explicit Apply Cancel and no collapsible creation wrapper',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.announces={};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end)
    assert(p.fields.apply and p.fields.cancel and p.fields.add==p.fields.apply and not p.fields.section_new_announce,'missing creation actions')
end)
test('collection comparison is readonly hides equal rows and ignores obsolete dialog callbacks',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);p:Open(function() end)
    local left={name='Same',type='pixel',lines=8};local right={name='Same',type='pixel',lines=9}
    local d=a:ShowCollectionComparison(p,'effect',left,right);assert(#d.rows==1 and d.rows[1].label=='Lines')
    local old=d.toggle.scripts.OnClick;a:ShowCollectionComparison(p,'effect',left,{name='Same',type='pixel',lines=8});old();assert(#d.rows==0,'obsolete comparison callback replaced the new comparison')
    d.toggle:Click();assert(#d.rows>=3 and left.lines==8 and right.lines==9)
end)
test('an obsolete ordered-row release cannot hide a new pooled drag preview',function()
    local f,parent=fixture();local p=f.addon:CreateSettingsForm(parent);local values={1,2}
    p:Open(function(form) form:OrderedCollection('r',values,function(i) return tostring(i) end,function() end,function() end) end)
    local old=p.ordered.r;old:BeginDrag(1);p:Draw();local current=p.ordered.r;current:BeginDrag(2);assert(current.ghost:IsShown());old:Drop(1);assert(current.ghost:IsShown() and current.drag==2,'old view cancelled the new drag')
end)
test('comparison retains exact same-name and loading item identities',function()
    local f=fixture();local a=f.addon;f.env.GetItemInfo=function(id) return 'Shared name',nil,nil,nil,nil,nil,nil,nil,nil,55 end
    local rows=a:CollectionComparisonRows('itemset',{name='Same',items={1}},{name='Same',items={2}},false)
    assert(#rows==1 and rows[1].left~=rows[1].right and rows[1].left:find('1',1,true) and rows[1].right:find('2',1,true))
    f.env.GetItemInfo=function() end;rows=a:CollectionComparisonRows('itemset',{name='Same',items={1001}},{name='Same',items={1002}},false)
    assert(rows[1].left~=rows[1].right and rows[1].left:find('1001',1,true))
end)
test('Compare keeps its action caption and expanded announcements retain root Delete',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={a={name='Alpha',type='pixel'},b={name='Beta',type='pixel'}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    p.fields.compare:Click();p.menu.rows[1]:Click();assert(p.fields.compare:GetText()=='Compare','comparison selection renamed the action')
    p:Release();a.db.profile.announces={{id='a',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'}};p:Open(function(form) a:BuildAnnounceSettings(form) end)
    assert(not p.fields.section_announce1 and p.fields.entry1text and p.fields.delete and p.fields.delete1 and p.fields.delete:IsShown(),'expanded announcement lost controls')
end)
test('category maintenance has footer actions member cells icon selection and sidebar ordering',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha',icon='a'},B={description='Beta',icon='b'}};a.conditionSpecials={};a.db.global.custom_conditions={B={}};a.db.profile.condition_groups={{id='a',name='First',conditions={'A'}},{id='b',name='Second',conditions={'B'}}};a.listConditions=function(_,id) return id=='a' and {'A'} or id=='b' and {'B'} or {'A','B'} end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end)
    assert(p.roster.entries[1].custom==false and p.roster.entries[2].custom==true)
    p.roster.manage:Click();assert(p.roster.manage:GetText()=='Manage conditions' and p.roster.actionButtons[1]:GetText()=='New' and p.roster.actionButtons[1].icon:GetTexture()==f.addon:ControlTexture('plus') and p.roster.actionButtons[2]:GetText()=='Import/Export')
    assert(p.fields.member_A and p.fields.category_icon and p.fields.delete_category);assert(not p.roster.rows[1].up:IsEnabled());p.roster.rows[2].up:Click();assert(a.db.profile.condition_groups[1].id=='b')
    p.categorySelection='a';p:Draw();p.fields.member_A:Click();assert(p.mode==nil and p.condition=='A' and p.fields.hidden)
end)
test('native categorized icon picker cancels safely and commits only for its current owner',function()
    local f=fixture();local a=f.addon;local selected;local alive=true
    local d=a:ShowWorkbenchIconPicker(nil,function(value) selected=value end,function() return alive end)
    assert(d.categories and #d.categories>1 and #d.matches>0);local old=d.buttons[1].scripts.OnClick;d.close:Click();assert(not selected)
    d=a:ShowWorkbenchIconPicker(nil,function(value) selected=value end,function() return alive end);old();assert(not selected,'previous picker callback committed into new owner');d.buttons[1]:Click();assert(selected)
    selected=nil;d=a:ShowWorkbenchIconPicker(nil,function(value) selected=value end,function() return alive end);alive=false;d.buttons[1]:Click();assert(not selected)
end)
test('category icons survive actual startup repair while invalid icons are rejected',function()
    local f=fixture();local a=f.addon;a.warn=function() end;f.load('validate.lua')
    for _,icon in ipairs({'Interface\\Icons\\INV_Misc_Book_09',12345}) do local group={id='g',name='Group',conditions={'A'},icon=icon};a:validate_condition_group('p',1,group,true);assert(group.icon==icon) end
    local group={id='g',name='Group',conditions={},icon={}};a:validate_condition_group('p',1,group,true);assert(group.icon==nil)
end)
test('category metadata transfers roundtrip with the real codec and reject malformed data',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.conditionSpecials={};a.db.profile.condition_groups={{id='g',name='Before',conditions={'A'},icon=12}};a.listConditions=function() return {'A'} end
    local data,deps=dofile('tests/fixtures/codec.lua')();local codec=data.NewCodec(deps);a.NewRotationCodec=function() return codec end
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end);p.fields.transfer:Click()
    local decoded=codec:Decode(p.textDialog.input:GetText());assert(decoded and decoded.value.icon==12 and decoded.value.name=='Before','export lost category metadata')
    p.textDialog.input:SetText(assert(codec:Encode({format='RM-ConditionCategory',version=1,name='After',icon='path',conditions={'A'}})));p.textDialog.apply:Click();assert(a.db.profile.condition_groups[1].name=='Before' and a.db.profile.condition_groups[1].icon=='path')
    p.fields.transfer:Click();p.textDialog.input:SetText(assert(codec:Encode({format='RM-ConditionCategory',version=1,name='Bad',icon={},conditions={'A'}})));p.textDialog.apply:Click();assert(a.db.profile.condition_groups[1].name=='Before' and p.textDialog.frame:IsShown())
end)
test('category sidebar filtered drag preserves identities and rejects stale and invalid moves',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={};a.listConditions=function() return {} end;a.db.profile.condition_groups={{id='a',name='Alpha',conditions={}},{id='b',name='Beta',conditions={}},{id='c',name='Gamma',conditions={}}}
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end)
    local old=p.roster.orderView;old:Begin('a','Alpha');assert(old.ghost:IsShown() and not old:CanDrop(1) and not old:CanDrop(2));old:Drop(4);assert(a.db.profile.condition_groups[3].id=='a')
    local current=p.roster.orderView;current:Begin('b','Beta');old:Cancel();assert(current.ghost:IsShown());p.roster.search:SetText('Alpha');p.roster.search.scripts.OnTextChanged(p.roster.search,true);assert(not current.ghost:IsShown() and not current:Drop(1));assert(p.roster.orderZones[1].gap==3)
    p.roster.orderView:Begin('a','Alpha');p.roster.orderView:Drop(1);assert(a.db.profile.condition_groups[1].id=='a');p:Release();assert(not p.roster.orderGhost:IsShown())
end)
test('icon search invalidates recycled callbacks and optional public icon APIs may fail',function()
    local f=fixture();local a=f.addon;f.env.GetMacroIcons=function() error('unavailable') end;f.env.GetMacroItemIcons=function(out) out[1]='path/';out[2]=123 end
    local selected;local d=a:ShowWorkbenchIconPicker(nil,function(value) selected=value end,function() return true end);local old=d.buttons[1].scripts.OnClick
    d.search:SetText('not found');d.search.scripts.OnTextChanged(d.search,true);old();assert(not selected and #d.matches==0)
    assert(d.categories[#d.categories].name=='Item icons' and #d.categories[#d.categories].icons==2)
end)
test('creation Cancel discards an invalid draft without writing effects or item sets',function()
    for _,kind in ipairs({'Effects','ItemSets'}) do local f,parent=fixture();local a=f.addon;a.db.global.effects={};a.db.profile.itemsets={};local p=a:OpenNativeSettings(parent,kind)
        assert(p.fields.apply and p.fields.cancel);local input=p.fields.new_name;input:SetText('Draft');input.scripts.OnTextChanged(input,true);p.fields.cancel:Click();assert(not next(a.db.global.effects) and not next(a.db.profile.itemsets) and not p.creating)
        p.fields.new_collection:Click();p.fields.new_name:SetText('Saved');p.fields.new_name.scripts.OnTextChanged(p.fields.new_name,true);p.fields.apply:Click();assert(next(kind=='Effects' and a.db.global.effects or a.db.profile.itemsets))
    end
end)
test('effect sequence cards preview selected textures without ordinal headers',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Animate',type='animate',sequence={'a'}}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    assert(p.ordered.sequence_e.rows[1].header:GetText()=='');assert(p.fields.seq1.texturePreview.texture=='a');local c=p.fields.seq1;c:SetText('b');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c);assert(c.texturePreview.texture=='b')
end)
test('announcements share collection actions and audible channel preserves text while showing sound controls',function()
    local f,parent=fixture();local a=f.addon;a.events={SUCCEEDED='Success'};a.db.profile.announces={{id='a',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Keep text'}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildAnnounceSettings(form) end)
    assert(p.fields.duplicate and p.fields.transfer and p.fields.compare and p.fields.new_collection);p.fields.duplicate:Click();assert(#a.db.profile.announces==2 and a.db.profile.announces[1].id~=a.db.profile.announces[2].id)
    p.fields.entry2channel:Click();for _,row in ipairs(p.menu.rows) do if row:GetText()=='Audible' then row:Click();break end end
    assert(p.fields.entry2sound and p.fields.entry2play and not p.fields.entry2text and a.db.profile.announces[2].value=='Keep text')
    p.fields.transfer:Click();local codec=a:NewRotationCodec();local decoded=codec:Decode(p.textDialog.input:GetText());assert(decoded and decoded.value.format=='RM-Announcement')
    local before=a.db.profile.announces[2];p.textDialog.input:SetText(assert(codec:Encode({format='RM-Announcement',version=1,announcement={type='bad'}})));p.textDialog.apply:Click();assert(a.db.profile.announces[2]==before and p.textDialog.frame:IsShown())
end)
test('pending category rename preserves the requested arrow move or drag',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={};a.listConditions=function() return {} end;a.db.profile.condition_groups={{id='a',name='Alpha',conditions={}},{id='b',name='Beta',conditions={}}}
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end)
    local c=p.fields.group_name;c:SetText('Renamed');c.scripts.OnTextChanged(c,true);p.roster.rows[1].down:Click();assert(a.db.profile.condition_groups[2].id=='a' and a.db.profile.condition_groups[2].name=='Renamed')
    c=p.fields.group_name;c:SetText('Again');c.scripts.OnTextChanged(c,true);p.roster.orderView:Begin('a','Again');assert(p.roster.orderView.ghost:IsShown() and p.roster.orderView.drag=='a');p.roster.orderView:Drop(1);assert(a.db.profile.condition_groups[1].id=='a')
end)
test('metadata category import clears absent optional icon while legacy list preserves it',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='A'}};a.listConditions=function() return {'A'} end;local g={id='g',name='Before',icon=12,conditions={'A'}};a.db.profile.condition_groups={g}
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end);p.fields.transfer:Click();p.textDialog.input:SetText('A');p.textDialog.apply:Click();assert(g.icon==12)
    p.fields.transfer:Click();p.textDialog.input:SetText(assert(a:NewRotationCodec():Encode({format='RM-ConditionCategory',version=1,name='Iconless',conditions={'A'}})));p.textDialog.apply:Click();assert(g.name=='Before' and g.icon==nil)
end)
test('native references accept matching cursor drops without changing on mismatched cursor',function()
    local f,parent=fixture();local a=f.addon;f.env.GetItemInfo=function(id) return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,10 end;local cursor='item';f.env.GetCursorInfo=function() if cursor=='item' then return 'item',42 elseif cursor=='spell' then return 'spell',1,'book',403 end end
    local cleared=0;f.env.ClearCursor=function() cleared=cleared+1 end;local saved;local p=a:CreateSettingsForm(parent);p:Open(function(form) form:Item('i','Item',nil,function(v) saved=v end,true) end)
    assert(p.fields.i.scripts.OnReceiveDrag);p.fields.i.scripts.OnReceiveDrag();assert(saved==42 and cleared==1 and p.fields.i:GetText()=='Item 42');cursor='spell';p.fields.i.scripts.OnReceiveDrag();assert(saved==42 and cleared==1)
end)
test('item bindings show top pills and refresh when runtime binding callback changes',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1}}};a.db.char={bindings={s={1,2}}};a.getDefaultItemset=function() return {1} end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildItemSettings(form) end);assert(p.fields.binding and p.fields.binding.pillDecoration and p.fields.reset.pillDecoration)
    a.db.char.bindings.s={3};a.itemSetCallback('s');assert(p.fields.binding:GetText():find('3',1,true) and not p.fields.binding:GetText():find('2',1,true));p.fields.binding:Click();assert(a.db.char.bindings.s==nil and p.fields.binding:GetText()=='Bind')
end)
test('profile roster inspects without activating and provides create duplicate transfer compare',function()
    local f,parent=fixture();local a=f.addon;local current='One';local profiles={One={enable=true,poll=.1},Two={enable=false,poll=.2}};a.db.profile=profiles.One;a.db.profiles=profiles
    a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() local list={};for name in pairs(profiles) do list[#list+1]=name end;return list end;a.db.SetProfile=function(_,name) current=name;profiles[name]=profiles[name] or {};a.db.profile=profiles[name] end
    a.db.CopyProfile=function(_,name) profiles[current]=a.deepcopy(profiles[name]);a.db.profile=profiles[current] end;a.DisableRotation=function() end;a.EnableRotation=function() end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildProfileSettings(form) end)
    assert(p.roster and p.fields.duplicate and p.fields.transfer and p.fields.compare);p.roster.rows[2]:Click();assert(current=='One' and p.selection=='Two');p.fields.activate:Click();assert(current=='Two')
    p.fields.duplicate:Click();assert(p.fields.apply and p.fields.cancel);p.fields.new_name:SetText('Three');p.fields.new_name.scripts.OnTextChanged(p.fields.new_name,true);p.fields.apply:Click();assert(current=='Two' and profiles.Three.poll==.2 and p.selection=='Three')
end)
test('native collection pages stage edits until Apply and Cancel discards them',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Original',type='pixel'}};local p=a:OpenNativeSettings(parent,'Effects')
    assert(p.fields.apply and p.fields.cancel and not p.fields.apply:IsEnabled(),'initial apply state');local c=p.fields.name;c:SetText('Draft');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c);assert(a.db.global.effects.e.name=='Original','saved before apply: '..a.db.global.effects.e.name)
    p.fields.cancel:Click();assert(p.fields.name:GetText()=='Original');c=p.fields.name;c:SetText('Saved');c.scripts.OnTextChanged(c,true);p.fields.apply:Click();assert(a.db.global.effects.e.name=='Saved')
    c=p.fields.name;c:SetText('Conflict');c.scripts.OnTextChanged(c,true);a.db.global.effects.e.name='External';p.fields.apply:Click();assert(a.db.global.effects.e.name=='External' and p.message:GetText()~='')
end)
test('condition assignment is staged and current category opens management while ordering lives in sidebar',function()
    local f,parent=fixture();local a=f.addon;f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');a:RegisterCondition('A',{description='Alpha'});a:RegisterCondition('B',{description='Beta'});a.conditionSpecials={};a.db.global.custom_conditions={};a.db.profile={condition_groups={{id='g',name='Group',conditions={'A','B'}}},other_conditions_order={},switch_conditions={},disabled_conditions={}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end);p.category='g';p:Draw();assert(p.roster.rows[1].up and not p.roster.rows[1].up:IsEnabled());p.roster.rows[2].up:Click();assert(a.db.profile.condition_groups[1].conditions[1]=='B')
    p.fields.move_to:Click();for _,row in ipairs(p.menu.rows) do if row:GetText()=='Other' then row:Click();break end end;assert(#a.db.profile.condition_groups[1].conditions==2);p.fields.apply_move:Click();assert(#a.db.profile.condition_groups[1].conditions==1)
    p.fields.current_category:Click();assert(p.mode=='categories' and p.categorySelection=='DEFAULT')
end)
test('new effects expose type-specific fields before naming and sequence cards drag by their surface',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={};local p=a:OpenNativeSettings(parent,'Effects');assert(p.fields.type and p.fields.lines and p.fields.name:GetText()=='')
    p.fields.type:Click();for _,row in ipairs(p.menu.rows) do if row:GetText()=='Animate' then row:Click();break end end;assert(p.fields.sequence_add and not p.fields.section_sequence_draft)
    p.fields.sequence_add:Click();p.fields.seq1:SetText('a');p.fields.seq1.scripts.OnTextChanged(p.fields.seq1,true);p.fields.seq1.scripts.OnEnterPressed(p.fields.seq1);p.fields.sequence_add:Click();local view=p.ordered.sequence_draft;assert(view.rows[1].scripts.OnDragStart);view.rows[1].scripts.OnDragStart();assert(view.ghost:IsShown() and view.ghost.texture.texture=='a');view:Drop(3);assert(p.newEffect.sequence[2]=='a')
    p.fields.apply:Click();assert(not next(a.db.global.effects));local name=p.fields.name;name:SetText('Saved');name.scripts.OnTextChanged(name,true);p.fields.apply:Click();assert(next(a.db.global.effects))
end)
test('profile comparison includes settings and nested changes and import validation rejects malformed shapes',function()
    local f=fixture();local a=f.addon;assert(a:ValidateProfileTransfer({enable=true,poll=.15,rotations={},rotationLibrary={preferences={},origins={},comparisons={},imports={}}}))
    for _,profile in ipairs({{poll=-1},{announces={{type='bad'}}},{condition_groups={{id='x',name='X',conditions={'A'},icon={}}}},{rotationLibrary={preferences='bad'}},{rotations={bad={}}},{unknown=true}}) do assert(not a:ValidateProfileTransfer(profile)) end
    local rows=a:CollectionComparisonRows('profile',{name='One',profile={enable=true,poll=.1}},{name='Two',profile={enable=true,poll=.2}},false);assert(#rows>=1);local found=false;for _,row in ipairs(rows) do if row.label:find('Polling',1,true) then found=row.left~=row.right end end;assert(found)
end)
test('General side effects wait for Apply and nested Cancel restores the saved settings',function()
    local f,parent=fixture();local a=f.addon;a.db.profile={enable=true,poll=.1,minimap={hide=false},color={r=1,g=1,b=1,a=1}};a.db.char={};local enabled=0;a.enable=function() enabled=enabled+1 end;a.disable=function() enabled=enabled-1 end
    local p=a:OpenNativeSettings(parent,'General');p.fields.enable:Click();assert(enabled==0 and a.db.profile.enable);p.fields.cancel:Click();assert(p.fields.enable:GetChecked());p.fields.enable:Click();p.fields.apply:Click();assert(enabled==-1 and not a.db.profile.enable)
end)
test('profile transfer preserves specialization zero and duplicate creation keeps the original active',function()
    local f,parent=fixture();local a=f.addon;local current='Default';local profiles={Default={rotations={[0]={DEFAULT={name='Default rotation',rotation={},cooldowns={},switch={}}}},rotationLibrary={preferences={},origins={[0]={}},comparisons={[0]={}},imports={[0]={}}}}};a.db.profiles=profiles;a.db.profile=profiles.Default
    a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() local names={};for name in pairs(profiles) do names[#names+1]=name end;return names end
    a.db.SetProfile=function(_,name) current=name;profiles[name]=profiles[name] or {};a.db.profile=profiles[name] end;a.db.CopyProfile=function(_,name) profiles[current]=a:CopySettingsData(profiles[name]);a.db.profile=profiles[current] end;a.db.DeleteProfile=function(_,name) assert(name~=current);profiles[name]=nil end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildProfileSettings(form) end);p.fields.transfer:Click();assert(p.textDialog and p.textDialog.frame:IsShown());local decoded=a:NewRotationCodec():Decode(p.textDialog.input:GetText());assert(decoded and decoded.value.profile.rotations['0'])
    p.textDialog.cancel:Click();p.fields.duplicate:Click();p.fields.apply:Click();assert(current=='Default' and profiles['Copy of Default'] and p.selection=='Copy of Default' and p.fields.delete:IsEnabled());p.fields.delete:Click();p.prompt.accept:Click();assert(not profiles['Copy of Default'] and profiles.Default)
end)
test('applying an item-set draft does not validate unrelated existing effects',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Items',items={1}}};a.db.global.effects={old={name='',type='pixel'}};local p=a:OpenNativeSettings(parent,'ItemSets');local c=p.fields.name;c:SetText('Updated');c.scripts.OnTextChanged(c,true);p.fields.apply:Click();assert(a.db.profile.itemsets.s.name=='Updated')
end)
test('effect card surface mouse grab starts the floating preview without waiting for native drag start',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Pulse',type='pulse',texture='pulse',sequence={1,.5}}};local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildEffectSettings(form) end)
    local view=p.ordered.sequence_e;view.rows[1].body.scripts.OnMouseDown(view.rows[1].body,'LeftButton');assert(view.drag==1 and view.ghost:IsShown());view:Drop(3);assert(a.db.global.effects.e.sequence[2]==1 and not view.ghost:IsShown())
end)
test('profile duplication persists through real AceDB logout and reinitialization',function()
    local _,_,_,_,_,env=dofile('tests/fixtures/codec.lua')();local logout
    env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) logout=fn end} end
    env.UnitFactionGroup=function() return 'Horde' end;env.GetLocale=function() return 'enUS' end;env.UnitClass=function() return 'Shaman','SHAMAN' end;env.UnitRace=function() return 'Orc','Orc' end;env.GetRealmName=function() return 'Realm' end;env.UnitNameUnmodified=function() return 'Player' end;env.GetCurrentRegionName=function() return 'US' end;env.GetCurrentRegion=function() return 1 end;env.strlenutf8=string.len
    local chunk=assert(loadfile('Libs/AceDB-3.0/AceDB-3.0.lua'));setfenv(chunk,env);chunk()
    local f,parent=fixture();local a=f.addon;local defaults={profile={enable=true,poll=.15,rotations={}},global={effects={},itemsets={}},char={bindings={}}};local db=env.LibStub('AceDB-3.0'):New('RMTestDB',defaults,true);a.db=db;db.profile.poll=.2;db.profile.rotations[0]={DEFAULT={name='Rotation',rotation={},cooldowns={}}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildProfileSettings(form) end);p.fields.duplicate:Click();p.fields.apply:Click();assert(db:GetCurrentProfile()=='Default' and p.selection=='Copy of Default');logout(nil,'PLAYER_LOGOUT')
    local restarted=env.LibStub('AceDB-3.0'):New(a:CopySettingsData(env.RMTestDB),defaults,true);assert(restarted:GetCurrentProfile()=='Default' and restarted.profiles['Copy of Default'].poll==.2 and restarted.profiles['Copy of Default'].rotations[0].DEFAULT.name=='Rotation')
end)
test('custom condition duplicate applies normally and confirmed deletion commits registry immediately',function()
    local f,parent=fixture();local a=f.addon;a.db.global.custom_conditions={C={description='Custom',icon=1,fields={}}};a.conditionDefinitions={C={description='Custom',icon=1,fields={}}};a.conditionSpecials={};a.db.profile={condition_groups={},disabled_conditions={},switch_conditions={},other_conditions_order={}};a.listConditions=function(_,_,_,store) local keys={};for key in pairs((store or a.db).global.custom_conditions) do keys[#keys+1]=key end;return keys end
    local registered,removed=0,0;a.register_custom_condition=function(_,key,value) registered=registered+1;a.conditionDefinitions[key]=value;return true end;a.UnregisterCondition=function(_,key) removed=removed+1;a.conditionDefinitions[key]=nil end
    local p=a:OpenNativeSettings(parent,'Conditions');p.fields.duplicate_custom:Click();assert(registered==0 and a.db.global.custom_conditions.C and p:IsSettingsDraftDirty());p.fields.apply:Click();assert(registered==1)
    p.fields.delete_custom:Click();p.prompt.cancel:Click();assert(removed==0);p.fields.delete_custom:Click();p.prompt.accept:Click();assert(removed==1 and not p:IsSettingsDraftDirty());p.fields.cancel:Click();assert(removed==1)
end)
test('item set deletion keeps bindings until confirmation and unbinds immediately',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1}}};a.db.char={bindings={s={1,2}}};local unbound=0;a.UnbindItemSet=function(_,id,items) assert(id=='s' and items[1]==1);unbound=unbound+1;a.db.char.bindings[id]=nil;return true end
    local p=a:OpenNativeSettings(parent,'ItemSets');p.fields.delete:Click();p.prompt.cancel:Click();assert(a.db.char.bindings.s and a.db.profile.itemsets.s)
    p.fields.delete:Click();p.prompt.accept:Click();assert(unbound==1 and not a.db.char.bindings.s and not a.db.profile.itemsets.s and not p:IsSettingsDraftDirty())
end)
test('Bind does not touch cursor or pending binding during combat',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1}}};a.db.char={bindings={}};a.FindFirstItemInItems=function() return 1 end;local picked=0;f.env.PickupItem=function() picked=picked+1 end;f.env.InCombatLockdown=function() return true end
    local p=a:OpenNativeSettings(parent,'ItemSets');p.fields.binding:Click();assert(picked==0 and not a.bindingItemSet)
end)
test('profile import requires unique announcement identities and rejects malformed categories without throwing',function()
    local f=fixture();local a=f.addon;a.events={SUCCEEDED='Success'};local ann={type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'}
    assert(not a:ValidateProfileTransfer({announces={ann}}));ann.id=a:uuid();assert(a:ValidateProfileTransfer({announces={ann}}));assert(not a:ValidateProfileTransfer({announces={ann,a:CopySettingsData(ann)}}));assert(not a:ValidateProfileTransfer({condition_groups={false}}))
end)
test('starting a fresh profile clears an abandoned import source',function()
    local f,parent=fixture();local a=f.addon;local profiles={Default={poll=.15}};local current='Default';a.db.profiles=profiles;a.db.profile=profiles.Default;a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() local names={};for name in pairs(profiles) do names[#names+1]=name end;return names end;a.db.SetProfile=function(_,name) profiles[name]=profiles[name] or {poll=.15};current=name;a.db.profile=profiles[name] end
    local p=a:OpenNativeSettings(parent,'Profiles');p.importProfile={poll=.5};p.creating=true;p:Draw();p.fields.new_collection:Click();p.fields.new_name:SetText('Fresh');p.fields.new_name.scripts.OnTextChanged(p.fields.new_name,true);p.fields.apply:Click();assert(profiles.Fresh.poll==.15)
end)
test('creation leave offers Apply Discard Cancel and honors invalid Apply without leaving',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={};local p=a:OpenNativeSettings(parent,'Effects');local c=p.fields.name;c:SetText('Draft');c.scripts.OnTextChanged(c,true);local left=0;p:RequestLeave(function() left=left+1 end);assert(left==0 and p.prompt and p.prompt.discard and p.prompt.cancel)
    p.prompt.cancel:Click();assert(left==0 and p.fields.name:GetText()=='Draft');p:RequestLeave(function() left=left+1 end);p.prompt.discard:Click();assert(left==1 and not next(a.db.global.effects))
end)
test('pooled drag preview restores overlay layering when presented after reparenting',function()
    local f,parent=fixture();local ghost=f.addon:CreateWorkbenchDragCard();ghost:SetParent(parent);ghost:SetFrameStrata('MEDIUM');ghost:SetFrameLevel(1);ghost:Present('Item','Drag',parent);assert(ghost:GetFrameStrata()=='TOOLTIP' and ghost:GetFrameLevel()>parent:GetFrameLevel())
end)
test('item-set history restores nested edits and ordering without touching saved data until Apply',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1,2}}};f.env.GetItemInfo=function(id) return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,10 end;local p=a:OpenNativeSettings(parent,'ItemSets');assert(p.fields.undo and p.fields.redo and not p.fields.undo:IsEnabled())
    p.fields.item2up:Click();assert(a.db.profile.itemsets.s.items[1]==1 and p.fields.undo:IsEnabled());p.fields.undo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==1 and p.fields.redo:IsEnabled());p.fields.redo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==2)
    p.fields.undo:Click();local c=p.fields.name;c:SetText('Renamed');c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c);assert(not p.fields.redo:IsEnabled());p.fields.undo:Click();assert(p.fields.name:GetText()=='Set');p.fields.redo:Click();p.fields.apply:Click();assert(a.db.profile.itemsets.s.name=='Renamed' and not p.fields.undo:IsEnabled())
end)
test('themed transfer right-click closes over its text field but ignores unrelated focus and an opening held click',function()
    local f,parent=fixture();local a=f.addon;local down=false;local focus;f.env.IsMouseButtonDown=function() return down end;f.env.GetMouseFoci=function() return {focus} end
    local p=a:CreateSettingsForm(parent);p:Open(function() end);a:ShowSettingsTextTransfer(p,'Transfer','Data',function() return true end);local d=p.textDialog;assert(d.frame.rmRightClickWatcher)
    focus=d.input;down=true;d.frame.rmRightClickWatcher.scripts.OnUpdate();assert(not d.frame:IsShown());a:ShowSettingsTextTransfer(p,'Transfer','Data',function() return true end);d.frame.rmRightClickWatcher.scripts.OnUpdate();assert(d.frame:IsShown());down=false;d.frame.rmRightClickWatcher.scripts.OnUpdate();focus=parent;down=true;d.frame.rmRightClickWatcher.scripts.OnUpdate();assert(d.frame:IsShown())
end)
test('shared effect import exposes original name and copy or overwrite destination with explicit rename',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Selected',type='pixel'}};local p=a:OpenNativeSettings(parent,'Effects');p.fields.transfer:Click();local d=p.textDialog;assert(d.destination and d.name and d.original)
    local codec=a:NewRotationCodec();d.input:SetText(assert(codec:Encode({name='Source',type='pixel',lines=5})));d.input.scripts.OnTextChanged(d.input,true);assert(d.original:GetText():find('Source',1,true));d.destination:Click();assert(not d.destination:GetChecked())
    d.name:SetText('Renamed import');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();assert(a.db.global.effects.e.name=='Selected');p.fields.apply:Click();local found=false;for id,effect in pairs(a.db.global.effects) do if id~='e' and effect.name=='Renamed import' then found=effect.lines==5 end end;assert(found)
end)
test('shared Clear empties pasted data and invalidates preview without changing saved settings',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent);p:Open(function() end);local invalidated=0
    local d=a:ShowSettingsTextTransfer(p,'Transfer','Exported',function() error('unexpected import') end,{canReplace=false,fallbackName='Copy',originalName=function() return 'Source' end,requirePreview=true,preview=function() end,inspect=function() end,invalidate=function() invalidated=invalidated+1 end})
    assert(d.clear,'Clear button missing');d.clear:Click();assert(d.input:GetText()=='' and invalidated==1 and not d.apply:IsEnabled() and d.frame:IsShown())
end)
test('profile imports accept the real initialization schema and preserve selected identity or create a named copy',function()
    local f,parent=fixture();local a=f.addon;f.load('init.lua');local defaults={profile={poll=.15,rotations={}},global={},char={}};a:augmentDefaults(defaults)
    local current='Default';local profiles={Default=defaults.profile,Other={poll=.2}};a.db.profiles=profiles;a.db.profile=profiles.Default;a.db.global=defaults.global
    a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() local n={};for name in pairs(profiles) do n[#n+1]=name end;return n end
    a.db.SetProfile=function(_,name) profiles[name]=profiles[name] or {poll=.15};current=name;a.db.profile=profiles[name] end
    a.db.ResetProfile=function() profiles[current]={poll=.15};a.db.profile=profiles[current] end
    local p=a:OpenNativeSettings(parent,'Profiles');p.fields.transfer:Click();local d=p.textDialog;local exported=d.input:GetText();d.destination:Click();d.name:SetText('Imported');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click()
    assert(not d.frame:IsShown(),'profile import rejected: '..tostring(d.status:GetText()));assert(p.creating and not profiles.Imported);p.fields.apply:Click();assert(current=='Default' and profiles.Imported and profiles.Imported.version==3 and profiles.Imported.rotationStore.version==1 and profiles.Imported.rotationFallbackID==f.env.DEFAULT)
    p.fields.transfer:Click();d.input:SetText(exported);d.apply:Click();assert(not d.frame:IsShown() and profiles.Imported.version==3 and profiles.Imported.rotationStore.version==1 and profiles.Imported.rotationFallbackID==f.env.DEFAULT and current=='Default')
end)
test('named item-set imports and legacy lists share destination controls and undo history',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Selected',items={1}}};a.db.global.itemsets={};local p=a:OpenNativeSettings(parent,'ItemSets');p.fields.transfer:Click();local d=p.textDialog
    d.input:SetText('2,3');d.apply:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==2 and a.db.profile.itemsets.s.items[1]==1);p.fields.undo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==1);p.fields.redo:Click()
    p.fields.transfer:Click();d.input:SetText(assert(a:NewRotationCodec():Encode({format='RM-ItemSet',version=1,name='Source',items={4,5}})));d.input.scripts.OnTextChanged(d.input,true);assert(d.original:GetText():find('Source',1,true));d.destination:Click();d.name:SetText('Imported items');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();p.fields.apply:Click();local found;for id,set in pairs(a.db.profile.itemsets) do if id~='s' then found=set.name=='Imported items' and set.items[2]==5 end end;assert(found and a.db.profile.itemsets.s.name=='Selected')
end)
test('announcement imports create fresh identities and keep the selected name when replacing',function()
    local f,parent=fixture();local a=f.addon;a.events={SUCCEEDED='Success'};local entry={id=a:uuid(),name='Selected',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'};a.db.profile.announces={entry}
    local p=a:OpenNativeSettings(parent,'Announces');p.fields.transfer:Click();local d=p.textDialog;local source=a:CopySettingsData(entry);source.name='Source';source.spell=8042;local text=assert(a:NewRotationCodec():Encode({format='RM-Announcement',version=1,announcement=source}));d.input:SetText(text);d.apply:Click();p.fields.apply:Click();assert(a.db.profile.announces[1].name=='Selected' and a.db.profile.announces[1].spell==8042 and a.db.profile.announces[1].id==entry.id)
    p.fields.transfer:Click();d.input:SetText(text);d.destination:Click();d.name:SetText('Copy');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();p.fields.apply:Click();assert(#a.db.profile.announces==2 and a.db.profile.announces[2].name=='Copy' and a.db.profile.announces[2].id~=entry.id)
end)
test('custom condition imports validate code as data without evaluating it and retain legacy definitions',function()
    local f=fixture();local a=f.addon;local codec=a:NewRotationCodec();local value={description='Condition',icon=1,fields={unit='string'}};for _,key in ipairs({'valid','evaluate','print','widget','help','on_register','on_unregister'}) do value[key]='error("MUST NOT EXECUTE")' end
    local parsed=assert(a:ParseCustomConditionImport(assert(codec:Encode({format='RM-CustomCondition',version=1,name='SOURCE',condition=value})),codec));assert(parsed.name=='SOURCE' and parsed.condition.evaluate==value.evaluate);assert(a:ParseCustomConditionImport(assert(codec:Encode(value)),codec));value.fields.unit='function';assert(not a:ParseCustomConditionImport(assert(codec:Encode(value)),codec))
end)
test('profile replacement rejects changes made while the import dialog is open',function()
    local f,parent=fixture();local a=f.addon;local profile={version=2,poll=.15};a.db.profile=profile;a.db.profiles={Default=profile};a.db.GetCurrentProfile=function() return 'Default' end;a.db.GetProfiles=function() return {'Default'} end;local reset=0;a.db.ResetProfile=function() reset=reset+1 end
    local p=a:OpenNativeSettings(parent,'Profiles');p.fields.transfer:Click();local d=p.textDialog;profile.poll=.3;d.apply:Click();assert(d.frame:IsShown() and reset==0 and profile.poll==.3)
end)
test('custom Lua transfer requires trust and rejects a stale pasted candidate before opening code',function()
    local f,parent=fixture();local a=f.addon;f.load('Core/custom_condition_owner.lua');f.load('UI/custom_condition_transfer.lua');local root={frame=parent,nativeCustomEditor=true};function root:SetCallback(event,fn) self[event]=fn end;function root:Show() self.frame:Show() end;function root:Hide() self.frame:Hide() end
    local alive=true;local owner=a:OwnCustomConditionDialog(root,nil,function() return alive end);local value={description='Custom',icon=1,fields={}};for _,key in ipairs({'valid','evaluate','print','widget','help','on_register','on_unregister'}) do value[key]='return true' end
    a.db.global.custom_conditions={CUSTOM=value};a.describeCondition=function(_,key) return key=='CUSTOM' and value.description end;local opened=0;a.LayoutCustomConditionEditor=function(_,_,_,key,definition) assert(key=='CUSTOM' and definition.evaluate=='return true');opened=opened+1 end
    local d=assert(a:ShowCustomConditionTransfer(root,function() end,'CUSTOM',value));d.apply:Click();local p=root.rmCustomTransferForm;assert(p.prompt.frame:IsShown() and opened==0);p.prompt.cancel:Click();assert(opened==0 and d.frame:IsShown());d.apply:Click();d.input:SetText('changed');p.prompt.accept:Click();assert(opened==0)
    d.input:SetText(assert(a:NewRotationCodec():Encode(value)));d.apply:Click();p.prompt.accept:Click();assert(opened==1 and root.frame:IsShown())
    d=a:ShowCustomConditionTransfer(root,function() end,'CUSTOM',value);d.apply:Click();alive=false;a:CloseCustomConditionEditor(root,owner);assert(not d.frame:IsShown());p.prompt.accept:Click();assert(opened==1 and not root.frame:IsShown())
end)
test('new category imports keep original category and move membership into the named copy',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.conditionSpecials={};a.db.profile.condition_groups={{id='g',name='Original',conditions={'A'},icon=12}};a.listConditions=function() return {'A'} end
    local p=a:OpenNativeSettings(parent,'Conditions');p.mode='categories';p.categorySelection='g';p:Draw();p.fields.transfer:Click();local d=p.textDialog;d.destination:Click();d.name:SetText('Copied category');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();p.fields.apply:Click();assert(#a.db.profile.condition_groups==2 and a.db.profile.condition_groups[1].name=='Original' and #a.db.profile.condition_groups[1].conditions==0 and a.db.profile.condition_groups[2].name=='Copied category' and a.db.profile.condition_groups[2].icon==12)
end)
test('releasing an item form clears history for the next page owner',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1,2}}};local p=a:OpenNativeSettings(parent,'ItemSets');p.fields.item2up:Click();assert(#p.historyUndo==1);p:Release();assert(#p.historyUndo==0 and #p.historyRedo==0)
end)
test('active profile replacement uses runtime lifecycle and retains defaulted fields',function()
    local f,parent=fixture();local a=f.addon;local current='Default';local profiles={Default={version=2,poll=.15,color={r=1,g=1,b=1,a=1}}};a.db.profiles=profiles;a.db.profile=profiles.Default;a.db.GetCurrentProfile=function() return current end;a.db.GetProfiles=function() return {'Default'} end
    local events={};a.DisableRotation=function() events[#events+1]='disable' end;a.EnableRotation=function() events[#events+1]='enable' end;a.db.ResetProfile=function() events[#events+1]='reset';profiles.Default={version=2,poll=.15,color={r=1,g=1,b=1,a=1}};a.db.profile=profiles.Default end
    local p=a:OpenNativeSettings(parent,'Profiles');p.fields.transfer:Click();local d=p.textDialog;d.input:SetText(assert(a:NewRotationCodec():Encode({format='RM-Profile',version=1,name='Source',profile={version=2,poll=.4,color={r=.2}}})));d.apply:Click();assert(not d.frame:IsShown() and a.db.profile.poll==.4 and a.db.profile.color.r==.2 and a.db.profile.color.g==1 and table.concat(events,',')=='disable,reset,enable')
end)
test('unchanged legacy profile exports with an empty Default placeholder remain importable',function()
    local f,parent=fixture();local a=f.addon;local source={version=2,rotations={[0]={Default={},custom={name='Custom',rotation={},cooldowns={}}}}};local encoded=assert(a:NewRotationCodec():Encode({format='RM-Profile',version=1,name='Default',profile=a:ProfileToPortable(source)}));local decoded=assert(a:NewRotationCodec():Decode(encoded));local candidate=a:ProfileFromPortable(decoded.value.profile)
    assert(a:ValidateProfileTransfer(candidate),'legacy empty placeholder rejected');assert(candidate.rotations[0].Default.rotation and candidate.rotations[0].Default.cooldowns and next(source.rotations[0].Default)==nil);assert(candidate.rotations[0].custom.name=='Custom')
    assert(not a:ValidateProfileTransfer(a:ProfileFromPortable({version=2,rotations={['0']={Broken={rotation='invalid'}}}})))
end)
test('custom definition imports accept the actual legacy editor Item Set schema',function()
    local f=fixture();local a=f.addon;f.load('Core/custom_condition_services.lua');f.load('UI/custom_condition_editor.lua');local value=a:CopySettingsData(a.empty_condition);value.description='Item condition';value.fields={items='{ string, { string, number } }'};local codec=a:NewRotationCodec();assert(a:ParseCustomConditionImport(assert(codec:Encode(value)),codec),'editor schema rejected');assert(type(a.LayoutCustomConditionEditor)=='function','production editor entry point missing')
end)
test('item autocomplete selection participates in draft undo and redo',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Set',items={1}}};a.db.global.itemsets={};f.env.GetItemInfo=function(id) return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,1 end;a:GetReferenceProvider('item').index(2)
    local p=a:OpenNativeSettings(parent,'ItemSets');local c=p.fields.item1;c:SetText('Item 2');c.scripts.OnTextChanged(c,true);assert(p.menu and p.menu.frame:IsShown(),'picker missing');p.menu.rows[1]:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==2 and p.fields.undo:IsEnabled(),'autocomplete bypassed history');p.fields.undo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==1);p.fields.redo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==2 and a.db.profile.itemsets.s.items[1]==1);p.fields.undo:Click();a:GetReferenceProvider('item').index(3);c=p.fields.item1;c:SetText('Item 3');c.scripts.OnTextChanged(c,true);p.menu.rows[1]:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==3 and not p.fields.redo:IsEnabled(),'new autocomplete selection retained redo')
end)
test('announcement help follows real visible fields and documents all offered choices',function()
    for _,kind in ipairs({'spell','pet','item'}) do for _,channel in ipairs({'local','audible'}) do
        local f,parent=fixture();local a=f.addon;a.db.profile.announces={{id='a',name='Example',type=kind,spell=403,item={},event='SUCCEEDED',announce=channel,value='Cast',announce_sound='Bell'}}
        local p=a:CreateSettingsForm(parent);local controls,choices={},{}
        for _,method in ipairs({'Edit','Choice','Check','Spell','ItemSequence','Sound'}) do
            local original=p[method]
            p[method]=function(self,key,caption,...)
                local suffix=key:match('^entry1(.*)$');if method=='Sound' and key=='entry1' then suffix='action' end
                if suffix and ({name=true,type=true,action=true,ranked=true,event=true,channel=true,text=true})[suffix] then
                    -- Reference and sound controls call Edit/Choice internally;
                    -- only record the outer public control once.
                    local id=suffix=='action' and (method=='ItemSequence' and 'items' or method=='Sound' and 'sound' or 'spell') or suffix
                    if controls[#controls]~=id then controls[#controls+1]=id end
                    if method=='Choice' then local args={...};for _,option in ipairs(args[2] or {}) do choices[#choices+1]=option.text end end
                end
                return original(self,key,caption,...)
            end
        end
        p:Open(function(form) a:BuildAnnounceSettings(form) end)
        local sections=a:GetDocument_layout_announce_options_help();local positions,titles={},{}
        for i,entry in ipairs(sections) do positions[entry.id]=i;titles[entry.title]=true end
        local previous=0
        for _,id in ipairs(controls) do id=id=='channel' and 'announce' or id;assert(positions[id],'visible control missing help: '..id);assert(positions[id]>previous,'help differs from visible order: '..id);previous=positions[id] end
        for _,caption in ipairs(choices) do assert(titles[caption],'choice missing help: '..caption) end
        p:Release()
    end end
end)
test('item-set help covers every real native field and collection action',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Supplies',items={1,2}}};a.db.global.itemsets={}
    local p=a:CreateSettingsForm(parent);local documented={};for _,entry in ipairs(a:GetDocument_layout_itemsets_options_help()) do documented[entry.id]=true end
    for _,method in ipairs({'Edit','Check','Item','Slider','Choice','Sound','Button'}) do
        local original=p[method]
        p[method]=function(self,key,...)
            local id=key=='new_item' or key:match('^item%d+$')
            id=id and 'item' or key=='add_item' and 'add' or key=='new_name' and 'name' or key
            assert(documented[id],'item-set control lacks help: '..key)
            return original(self,key,...)
        end
    end
    a:OpenNativeSettings(parent,'ItemSets',p)
    for key,id in pairs({binding='binding',reset='reset',delete='delete',new_collection='collections',duplicate='collections',transfer='collections',compare='collections'}) do assert(p.fields[key] and documented[id],'action lacks help: '..key) end
    p.fields.new_collection:Click();local input=assert(p.fields.new_name);input:SetText('Named empty set');input.scripts.OnTextChanged(input,true);p.fields.apply:Click()
    local created=a.db.profile.itemsets[p.selection];assert(created and created.name=='Named empty set' and #created.items==0 and not p:IsSettingsDraftDirty(),'first Apply did not save creation')
    p.fields.cancel:Click();assert(a.db.profile.itemsets[p.selection]==created,'later Cancel removed saved creation')
    local nameHelp;for _,entry in ipairs(a:GetDocument_layout_itemsets_options_help()) do if entry.id=='name' then nameHelp=entry.text end end
    assert(nameHelp and nameHelp:find('first Apply saves',1,true),'help does not explain the creation save')
    p:Release()
end)
test('General default rotation view is staged and portable with an enum guard',function()
    local f,parent=fixture();local a=f.addon
    a.db.profile={poll=.1,rotation_view='diagram'};a.db.global.effects={}
    local p=a:OpenNativeSettings(parent,'General')
    assert(p.fields.rotation_view,'missing default rotation view')
    p.fields.rotation_view:Click();p.menu.rows[2]:Click()
    assert(a.db.profile.rotation_view=='diagram' and p:SettingsData().profile.rotation_view=='list')
    p.fields.cancel:Click();assert(a.db.profile.rotation_view=='diagram' and p:SettingsData().profile.rotation_view=='diagram')
    p.fields.rotation_view:Click();p.menu.rows[2]:Click();p.fields.apply:Click();assert(a.db.profile.rotation_view=='list')
    assert(a:ValidateProfileTransfer({rotation_view='list'}) and a:ValidateProfileTransfer({}))
    assert(not a:ValidateProfileTransfer({rotation_view='table'}) and not a:ValidateProfileTransfer({rotation_view=true}))
    assert(a:ProfileFromPortable(a:ProfileToPortable(a.db.profile)).rotation_view=='list')
end)
test('ordered rows capture Ctrl suffix moves while manual arrows always move one',function()
    local f,parent=fixture();local a=f.addon;local values={'one','two','three','four'};local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:OrderedCollection('rows',values,function(i) return values[i] end,function() end,function() end) end)
    f.env.IsControlKeyDown=function() return true end;local view=p.ordered.rows;view:BeginDrag(3)
    assert(not view:CanDrop(4) and not view:CanDrop(5) and view:CanDrop(1))
    assert(view.ghost.label:GetWidth()<=230,'multiple count overlaps preview title')
    f.env.IsControlKeyDown=function() return false end;assert(view:Drop(1));assert(table.concat(values,',')=='three,four,one,two')
    f.env.IsControlKeyDown=function() return true end;p.ordered.rows.rows[3].up:Click();assert(table.concat(values,',')=='three,one,four,two')
    p:Release()
end)
test('category sidebar Ctrl drag carries hidden following siblings and arrows stay single',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={};a.listConditions=function() return {} end
    a.db.profile.condition_groups={{id='a',name='Alpha',conditions={}},{id='b',name='Beta',conditions={}},{id='c',name='Gamma',conditions={}},{id='d',name='Delta',conditions={}}}
    local p=a:CreateSettingsForm(parent);p.mode='categories';p:Open(function(form) a:BuildConditionSettings(form) end)
    p.roster.search:SetText('Gamma');p.roster.search.scripts.OnTextChanged(p.roster.search,true)
    f.env.IsControlKeyDown=function() return true end;local view=p.roster.orderView;view:Begin('c','Gamma')
    assert(not view:CanDrop(4) and not view:CanDrop(5) and view:CanDrop(1));f.env.IsControlKeyDown=function() return false end
    assert(view:Drop(1));assert(a.db.profile.condition_groups[1].id=='c' and a.db.profile.condition_groups[2].id=='d')
    p.roster.search:SetText('');p.roster.search.scripts.OnTextChanged(p.roster.search,true)
    f.env.IsControlKeyDown=function() return true end;p.roster.rows[3].up:Click()
    assert(a.db.profile.condition_groups[2].id=='a' and a.db.profile.condition_groups[3].id=='d');p:Release()
end)
test('item-set Ctrl range reorder is one undoable draft change and released drag stays inert',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Items',items={1,2,3,4}}};a.db.global.itemsets={}
    local p=a:OpenNativeSettings(parent,'ItemSets');f.env.IsControlKeyDown=function() return true end
    local old=p.ordered.items_s;old:BeginDrag(3);assert(old:Drop(1));local items=p:SettingsData().profile.itemsets.s.items
    assert(items[1]==3 and items[2]==4 and a.db.profile.itemsets.s.items[1]==1)
    p.fields.undo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==1)
    p.fields.redo:Click();assert(p:SettingsData().profile.itemsets.s.items[1]==3)
    p:Release();assert(not old:Drop(1) and not old.ghost:IsShown())
end)
test('ordered row drag lifts the actual controls and canceled previews restore every row',function()
    local f,parent=fixture();local a=f.addon;local values={'a','b','c'};local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:OrderedCollection('rows',values,function(i) return values[i] end,function(form,i) form:Edit('field'..i,'Value',values[i],nil,function(v) values[i]=v end) end,function() end) end)
    local view=p.ordered.rows;local owner=view.rows[2]:GetParent();f.env.IsControlKeyDown=function() return true end
    view:BeginDrag(2);assert(view.rows[2]:GetParent()==view.ghost and view.rows[3]:GetParent()==view.ghost)
    view:CancelDrag();assert(view.rows[2]:GetParent()==owner and view.rows[3]:GetParent()==owner and table.concat(values)=='abc')
    p:Release()
end)
test('collection sidebar footer uses the full body while detail Apply has its own reserved space',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={s={name='Items',items={1}}};a.db.global.itemsets={}
    local p=a:OpenNativeSettings(parent,'ItemSets');assert(p.roster.frame:GetHeight()==a:GetWorkbenchRosterGeometry(p.frame:GetWidth(),p.frame:GetHeight()).sidebarHeight,'sidebar differs from shared roster geometry')
    assert(p.scroll:GetHeight()<p.roster.frame:GetHeight() and p.fields.apply)
    p:Release()
end)
test('shared unsaved rails follow General controls pending text Apply and discarded changes',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.enable=true;a.db.profile.poll=.1;a.db.global.effects={}
    a.enable=function() end;a.disable=function() end
    local p=a:OpenNativeSettings(parent,'General');assert(not p.fields.enable.rmUnsaved and not p.fields.poll.rmUnsaved)
    p.fields.enable:Click();assert(p.fields.enable.rmUnsaved and a.db.profile.enable)
    local raw=p.fields.poll_value;raw:SetText('bad');raw.scripts.OnTextChanged(raw,true);assert(raw.rmUnsaved and p.fields.poll.rmUnsaved)
    raw.scripts.OnEscapePressed(raw);assert(not raw.rmUnsaved and not p.fields.poll.rmUnsaved)
    p.fields.apply:Click();assert(not p.fields.enable.rmUnsaved and not a.db.profile.enable)
    p.fields.enable:Click();p.fields.cancel:Click();assert(not p.fields.enable.rmUnsaved and not a.db.profile.enable)
end)
test('effect and item rows show edits and reordering relative to the saved entries',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Pulse',type='pulse',sequence={1,.5}}};a.Glow=function() end;a.HideGlow=function() end
    local p=a:OpenNativeSettings(parent,'Effects');assert(not p.fields.seq1.rmUnsaved)
    p.fields.seq1:SetValue(.7);assert(p.fields.seq1.rmUnsaved and p.ordered.sequence_e.rows[1].rmUnsaved and p.roster.rows[1].rmUnsaved)
    p.fields.cancel:Click();assert(not p.fields.seq1.rmUnsaved)
    a.db.profile.itemsets={i={name='Items',items={1,2}}};p=a:OpenNativeSettings(parent,'ItemSets');p.fields.item1down:Click()
    assert(p.fields.item1.rmUnsaved and p.ordered.items_i.rows[1].rmUnsaved)
    p.fields.undo:Click();assert(not p.fields.item1.rmUnsaved)
end)
test('preview spell count rounds drag values and rejects fractional raw input',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.preview_spells=1;local p=a:OpenNativeSettings(parent,'General')
    p.fields.preview_spells:SetValue(2.4);assert(p:SettingsData().profile.preview_spells==2 and p.fields.preview_spells_value:GetText()=='2')
    local field=p.fields.preview_spells_value;field:SetText('2.5');field.scripts.OnTextChanged(field,true);assert(not p:FlushEdits())
end)
test('category filtering keeps search above its category selector',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.listConditions=function() return {'A'} end;local p=a:OpenNativeSettings(parent,'Conditions')
    assert(p.roster.search.point[3]==0 and p.roster.category.point[3]==-56)
end)
test('tag color palette is portable bounded data',function()
    local f=fixture();local a=f.addon
    assert(a:ValidateProfileTransfer({rotationTagColors={pvp={r=.2,g=.3,b=.4,a=1}}}))
    assert(not a:ValidateProfileTransfer({rotationTagColors={pvp={r=2,g=0,b=0,a=1}}}))
    assert(not a:ValidateProfileTransfer({rotationTagColors={pvp={r=.2,g=.3,b=.4}}}))
end)
test('duplicate effect fields and invalid pending sequence mark their full unsaved ownership',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Pulse',type='pulse',sequence={1,.5}}};a.Glow=function() end;a.HideGlow=function() end
    local p=a:OpenNativeSettings(parent,'Effects');local field=p.fields.seq1_value;field:SetText('bad');field.scripts.OnTextChanged(field,true)
    assert(field.rmUnsaved and p.ordered.sequence_e.rows[1].rmUnsaved and p.roster.rows[1].rmUnsaved,'pending input did not reach row/roster')
    field.scripts.OnEscapePressed(field);p.fields.duplicate:Click();assert(p.fields.name.rmUnsaved and p.fields.seq1.rmUnsaved,'new duplicated fields were treated as saved')
end)
test('category reordering marks the rows whose saved positions changed',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.listConditions=function() return {'A'} end
    a.db.profile.condition_groups={{id='g1',name='First',conditions={'A'}},{id='g2',name='Second',conditions={}}}
    local p=a:OpenNativeSettings(parent,'Conditions');p.roster.manage:Click();p.roster.orderView:Begin('g2','Second',false);assert(p.roster.orderView:Drop(1))
    local marked=0;for i,entry in ipairs(p.roster.matches) do if entry.value=='g1' or entry.value=='g2' then assert(p.roster.rows[i].rmUnsaved);marked=marked+1 end end;assert(marked==2)
end)
test('preview orientation opacity and count stage while lock is immediate and profile transfers preserve them',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.preview_spells=2;local calls=0;a.RefreshPreviewWindow=function() calls=calls+1 end
    local p=a:OpenNativeSettings(parent,'General');p.fields.preview_vertical:Click();p.fields.preview_locked:Click();p.fields.preview_opacity:SetValue(.5)
    assert(not a.db.profile.preview_vertical and a.db.profile.preview_locked and calls==1);p.fields.apply:Click();assert(a.db.profile.preview_vertical and a.db.profile.preview_locked and a.db.profile.preview_opacity==.5 and calls==2)
    local portable=a:ProfileToPortable(a.db.profile);local restored=a:ProfileFromPortable(portable);assert(a:ValidateProfileTransfer(restored) and restored.preview_vertical and restored.preview_locked)
    for _,patch in ipairs({{preview_spells=2.5},{preview_opacity=1.1},{preview_icon_size=12}}) do assert(not a:ValidateProfileTransfer(patch)) end
end)
test('settings View Changes inspects invalid pending input without flushing it or saving settings',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.poll=.1;local p=a:OpenNativeSettings(parent,'General');assert(p.fields.viewChanges and not p.fields.viewChanges:IsEnabled())
    local field=p.fields.poll_value;field:SetText('bad');field.scripts.OnTextChanged(field,true);assert(p.fields.viewChanges:IsEnabled());p.fields.viewChanges:Click()
    local d=p.draftComparisonOwner.comparison;assert(d.frame:IsShown() and d.rows[#d.rows].right=='bad' and a.db.profile.poll==.1 and p:SettingsData().profile.poll==.1)
    assert(field:GetText()=='bad' and p.edits[1].dirty);p:Release();d.frame.scripts.OnUpdate();assert(not d.frame:IsShown())
end)
test('selected dropdown icons persist and preview row divides into lock direction reset thirds',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent)
    p:Open(function(form) form:Choice('choice','Choice',1,{{value=1,text='First',icon=11},{value=2,text='Second',icon=22}},function() end) end)
    local field=p.fields.choice;assert(field.valueIcon:GetTexture()==11);field:Click();p.menu.rows[2]:Click();assert(field.valueIcon:GetTexture()==22)
    p=a:OpenNativeSettings(parent,'General');local left,middle,right=p.fields.preview_locked,p.fields.preview_vertical,p.fields.preview_reset
    assert(left:GetWidth()==middle:GetWidth() and middle:GetWidth()==right:GetWidth() and left.point[3]==middle.point[3] and middle.point[3]==right.point[3])
    assert(left.point[2]==0 and middle.point[2]==p.columnWidth/3 and right.point[2]==p.columnWidth*2/3)
    assert(p.fields.preview_opacity.point[3]>left.point[3],'opacity must sit above the control row')
end)
test('condition source filters precede categories and transfer only editable custom definitions',function()
    local f,parent=fixture();local a=f.addon;a.conditionDefinitions={A={description='Alpha'},B={description='Beta'}};a.conditionSpecials={};a.db.global.custom_conditions={B={description='Beta',fields={}}};a.db.profile.condition_groups={{id='one',name='One',conditions={'A','B'}}};a.listConditions=function() return {'A','B'} end
    local opened;a.OpenSettingsCustomCondition=function(_,_,key) opened=key;return {transfer={Click=function() opened=opened..':transfer' end}} end
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end)
    assert(p.fields.add_custom:GetText()=='Add' and not p.fields.transfer:IsEnabled())
    assert(p.roster.search.point[3]>p.roster.sourceButtons[1].point[3] and p.roster.sourceButtons[1].point[3]>p.roster.category.point[3])
    p.roster.sourceButtons[3]:Click();assert(#p.roster.entries==1 and p.condition=='B' and p.fields.transfer:IsEnabled());p.fields.transfer:Click();assert(opened=='B:transfer')
    p.roster.sourceButtons[2]:Click();assert(#p.roster.entries==1 and p.condition=='A' and not p.fields.transfer:IsEnabled())
    assert(p.roster.sourceButtons[2].selected and not p.roster.sourceButtons[3].selected)
    for _,entry in ipairs(p.roster.options.categories) do assert(entry.value~='BUILTIN' and entry.value~='CUSTOM') end
end)
test('shared search hints hide while focused or populated and return on empty blur',function()
    local f,parent=fixture();local a=f.addon;local input=a:CreateWorkbenchEditBox(parent);a:AttachWorkbenchSearchHint(input)
    assert(input.searchHint:GetText()=='Search...' and input.searchHint:IsShown())
    input.hooks.OnEditFocusGained[1]();assert(not input.searchHint:IsShown());input.hooks.OnEditFocusLost[1]();assert(input.searchHint:IsShown())
    input:SetText('word');input.hooks.OnTextChanged[1]();assert(not input.searchHint:IsShown());input:SetText('');input.hooks.OnTextChanged[1]();assert(input.searchHint:IsShown())
end)
test('preview Reset immediately changes saved and staged geometry without requiring Apply',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.preview_spells=2;a.db.profile.preview_icon_size=96;a.db.profile.preview_window={point='LEFT',relpoint='LEFT',xoffs=10,yoffs=20}
    local configured,centered=0,0;a.RefreshPreviewWindow=function() end;a.nextWindow={Configure=function() configured=configured+1 end,ClearAllPoints=function() end,SetPoint=function() centered=centered+1 end}
    local p=a:OpenNativeSettings(parent,'General');assert(not p.fields.apply:IsEnabled());p.fields.preview_reset:Click()
    assert(not a.db.profile.preview_window and a.db.profile.preview_icon_size==64 and configured==1 and centered==1 and not p.fields.apply:IsEnabled())
    assert(not p:IsSettingsDraftDirty());p.fields.preview_opacity:SetValue(.4);p.fields.preview_reset:Click();assert(p:IsSettingsDraftDirty() and a.db.profile.preview_opacity~=.4 and p:SettingsData().profile.preview_opacity==.4)
    assert(p:SaveSettingsDraft(),'immediate Reset must synchronize only its owned baselines')
end)
test('Integrations lists actual editor providers and stages the preference with profile portability',function()
    local f,parent=fixture();local a=f.addon;f.load('UI/lua_editor.lua');local h=io.open('UI/settings_integrations.lua');if h then h:close();f.load('UI/settings_integrations.lua') end
    assert(a.BuildIntegrationSettings,'Integrations page missing');a:RegisterLuaEditorProvider('Example',function() error('not created while browsing settings') end)
    a.db.profile.lua_editor='native'
    local p=a:OpenNativeSettings(parent,'Integrations');p.fields.lua_native_highlighting:Click();assert(p:SettingsData().profile.lua_editor=='plain' and a.db.profile.lua_editor=='native')
    p.fields.apply:Click();assert(a.db.profile.lua_editor=='plain' and a:ValidateProfileTransfer(a:ProfileToPortable(a.db.profile)) and not p.fields.lua_native_highlighting.rmUnsaved and not p:IsSettingsDraftDirty())
    local entries=a:ListLuaEditorProviders();assert(entries[#entries].value=='Example');local code=a:CreateWorkbenchLuaEditor(parent,function() end,function() return true end);assert(not code.syntax and code.provider=='native')
end)
test('icon picker preset labels all exist in the actual base locale',function()
    local f=fixture();f.load('Locales/enUS.lua');local locale=setmetatable({}, {__index=function(_,key) assert(f.translations[key], 'Missing translation: '..key);return f.translations[key] end})
    f.libraries['AceLocale-3.0'].GetLocale=function() return locale end;f.load('UI/icon_picker.lua');local d=f.addon:ShowWorkbenchIconPicker(nil,function() end,function() return true end)
    assert(#d.categories>=4 and d.categories[3].icons[2].name==locale.Weapon)
end)
test('spell rank options share wide inputs and align underneath narrow inputs',function()
    local f,parent=fixture();local a=f.addon;local p=a:CreateSettingsForm(parent)
    local spell,rank
    local function build(form)
        form:Spell('spell','Spell',403,0,function(value) spell=value end)
        form:InlineCheck('spell','ranked','Use this exact spell rank',false,function(value) rank=value end)
    end
    p:Open(build);local input,check=p.fields.spell,p.fields.ranked
    assert(input.point[3]==check.point[3] and check.point[2]>input.point[2]+input:GetWidth(),'wide rank option is not to the right')
    assert(input:GetWidth()>=200);check:Click();assert(rank==true and not spell,'rank toggled the selected spell')
    p:SetWidth(500);f.addon:FlushWorkbenchReflow();input,check=p.fields.spell,p.fields.ranked
    assert(check.point[2]==input.point[2] and check.point[3]<input.point[3],'narrow rank option does not align with the input')
end)
test('item set Global shares the wide Name row without mutating scope on open',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.itemsets={set={name='Consumables',items={1}}};a.db.global.itemsets={};a.db.char={bindings={}}
    local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildItemSettings(form) end)
    assert(p.fields.global.point[3]==p.fields.name.point[3] and p.fields.global.point[2]>p.fields.name.point[2]+p.fields.name:GetWidth(),'Global is not beside Name')
    assert(a.db.profile.itemsets.set and not a.db.global.itemsets.set)
end)
test('unset exact rank is not marked changed when first viewing an announcement',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.announces={{type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'}}
    local p=a:OpenNativeSettings(parent,'Announces');local rank=p.fields.entry1ranked
    assert(rank and not rank.rmUnsaved and not p.fields.apply:IsEnabled() and not p.fields.viewChanges:IsEnabled(),'untouched exact rank has an unsaved marker')
    rank:Click();assert(rank.rmUnsaved and p.fields.apply:IsEnabled(),'rank change lost its marker')
end)
test('unset reverse is not marked changed when first viewing a rotating starburst effect',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={star={name='Star',type='rotate',texture='Interface\\Icons\\INV_Misc_QuestionMark'}}
    local p=a:OpenNativeSettings(parent,'Effects');assert(p.fields.reverse and not p.fields.reverse.rmUnsaved,'untouched reverse has an unsaved marker');assert(not p.fields.apply:IsEnabled())
    p.fields.reverse:Click();assert(p.fields.reverse.rmUnsaved and p.fields.apply:IsEnabled())
end)
test('all text transfer variants can share one themed shell with Copy Clear and close controls',function()
    local f,parent=fixture();local a=f.addon;assert(a.CreateWorkbenchTransferShell,'shared transfer shell missing')
    local d=a:CreateWorkbenchTransferShell(880,720);assert(d.input and d.scroll and d.copy and d.clear and d.apply and d.cancel and d.close and d.frame.rmRightClickWatcher)
    assert(d.frame:GetWidth()==880 and d.sharedTransferShell)
    local p=a:CreateSettingsForm(parent);p:Open(function() end);local legacy=a:ShowSettingsTextTransfer(p,'Transfer','text',function() return true end);assert(legacy.sharedTransferShell,'simple transfer bypassed the shared shell')
end)
test('line-number preference applies to all code editors and travels with a profile',function()
    local f,parent=fixture();local a=f.addon;f.load('UI/lua_editor.lua');f.load('UI/settings_integrations.lua')
    local p=a:OpenNativeSettings(parent,'Integrations');assert(p.fields.lua_line_numbers and p.fields.lua_line_numbers:GetChecked(),'line numbers must default to visible')
    p.fields.lua_line_numbers:Click();assert(p:SettingsData().profile.lua_line_numbers==false and a.db.profile.lua_line_numbers==nil,'line-number preference bypassed Apply')
    p.fields.apply:Click();assert(a.db.profile.lua_line_numbers==false and a:ValidateProfileTransfer(a:ProfileToPortable(a.db.profile)))
    local bad=a:CopySettingsData(a.db.profile);bad.lua_line_numbers='false';assert(not a:ValidateProfileTransfer(a:ProfileToPortable(bad)))
end)
test('ordered additions insert only on a valid drop and readonly collections reject every mutation',function()
    local f,parent=fixture();local a=f.addon;local values={'one','two'};local p=a:CreateSettingsForm(parent);local made=0;local readonly=false
    p:Open(function(form) form:OrderedCollection('rows',values,function(i) return values[i] end,function(form,i) form:Text(values[i]) end,function() end,{readOnly=readonly}) end)
    local function factory() made=made+1;return 'added' end
    local view=p.ordered.rows;assert(view:BeginInsert(factory,'Argument') and made==0 and view.ghost:IsShown())
    assert(view:Drop(2) and made==1 and table.concat(values,',')=='one,added,two')
    view=p.ordered.rows;view:BeginInsert(factory,'Argument');view:CancelDrag();assert(made==1 and not view.ghost:IsShown())
    view:BeginInsert(factory,'Argument');assert(not view:Drop(99) and made==1)
    readonly=true;p:Draw();view=p.ordered.rows;assert(not view:BeginInsert(factory,'Argument'));view:BeginDrag(1);assert(not view.drag and not view.rows[1].remove:IsEnabled())
    assert(not view:Drop(3) and table.concat(values,',')=='one,added,two');p:Release()
end)
test('editable suggestions show known values allow typed new values and expire with their form',function()
    local f,parent=fixture();local a=f.addon;local value='utils';local p=a:CreateSettingsForm(parent);local input,menu
    p:Open(function(form)
        input=form:Edit('namespace','Namespace',value,nil,function(nextValue) value=nextValue end)
        local token=form.generation;menu=a:AttachWorkbenchEditSuggestions(form,input,{{value='utils',text='utils'},{value='custom.tools',text='custom.tools'}},function(nextValue) value=nextValue end,function() return form:Valid(token) end)
    end)
    input:SetFocus();input:GetScript('OnEditFocusGained')(input);assert(menu.frame:IsShown() and menu.rows[2]:IsShown(),'focus did not offer all known namespaces')
    input:SetText('cust');input:GetScript('OnTextChanged')(input,true);assert(menu.rows[1]:GetText()=='custom.tools' and not menu.rows[2]:IsShown())
    menu.rows[1]:Click();assert(value=='custom.tools' and input:GetText()==value and not input:HasFocus() and not menu.frame:IsShown())
    input:SetText('brandNew');input:GetScript('OnTextChanged')(input,true);input:GetScript('OnEnterPressed')(input);assert(value=='brandNew','typed new namespace was replaced by suggestions')
    local old=menu;p:Draw();old.rows[1]:Click();assert(value=='brandNew','stale suggestion mutated a replacement form');p:Release();assert(not menu.frame:IsShown())
end)
test('ordered reorder confirmation defers changes and rejects stale accepted moves',function()
    local f,parent=fixture();local a=f.addon;local values={'one','two'};local p=a:CreateSettingsForm(parent);local accept
    p:Open(function(form) form:OrderedCollection('rows',values,function(i) return values[i] end,function(form,i) form:Text(values[i]) end,function() end,{confirmReorder=function(apply) accept=apply end}) end)
    local view=p.ordered.rows;view:BeginDrag(1);assert(view:Drop(3) and values[1]=='one','order changed before confirmation')
    assert(accept() and values[1]=='two');view=p.ordered.rows;view:BeginDrag(1);view:Drop(3);p:Draw();assert(not accept() and values[1]=='two','stale accepted confirmation changed new form')
    p:Release()
end)
test('Profiles Help documents actual controls creation and immediate actions with localized field order',function()
    local f,parent=fixture();local a=f.addon;local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
    assert(a.GetProfileOptionHelp,'Profiles lacks structured field Help')
    local order={'activate','copy','reset','delete','new_name','collections'}
    for _,key in ipairs(order) do L['Help.Profiles.'..key]='Translated profile '..key end
    local rows=a:GetProfileOptionHelp();local documented,position={},{}
    for i,row in ipairs(rows) do documented[row.id]=row;position[row.id]=i end
    for i,key in ipairs(order) do assert(documented[key] and documented[key].text=='Translated profile '..key);if i>1 then assert(position[key]>position[order[i-1]]) end end
    a.db.GetCurrentProfile=function() return 'One' end;a.db.GetProfiles=function() return {'One','Two'} end;a.db.profiles={Two={}}
    local p=a:OpenNativeSettings(parent,'Profiles')
    for _,key in ipairs({'activate','copy','reset','delete'}) do assert(p.fields[key] and documented[key],'visible Profile control lacks Help: '..key) end
    for _,key in ipairs({'new_collection','duplicate','transfer','compare'}) do assert(p.fields[key] and documented.collections) end
    p.fields.new_collection:Click();assert(p.fields.new_name and documented.new_name)
    local help=a:WorkbenchPageHelp('Profiles');local found={};for _,row in ipairs(help) do if row.id then found[row.id]=row.text end end
    assert(found.activate=='Translated profile activate' and found.new_name=='Translated profile new_name')
end)
test('Integrations Help covers provider choices line numbers and loaded versus connected status',function()
    local f,parent=fixture();local a=f.addon;f.load('UI/lua_editor.lua');f.load('UI/settings_integrations.lua')
    assert(a.GetIntegrationOptionHelp,'Integrations lacks structured field Help')
    local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
    local order={'lua_editor','lua_line_numbers','optional_addons'}
    for _,key in ipairs(order) do L['Help.Integrations.'..key]='Translated integration '..key end
    local rows=a:GetIntegrationOptionHelp();for i,key in ipairs(order) do assert(rows[i].id==key and rows[i].text=='Translated integration '..key) end
    local p=a:OpenNativeSettings(parent,'Integrations');assert(p.fields.integration_status_editor_native and p.fields.lua_native_highlighting and p.fields.lua_line_numbers)
    local all=a:WorkbenchPageHelp('Integrations');local found={};for _,row in ipairs(all) do if row.id then found[row.id]=row.text end end
    for _,key in ipairs(order) do assert(found[key]=='Translated integration '..key) end
end)
test('rotation navigation Help no longer claims a200card truncation and saving names actual choices',function()
    local f=fixture();local a=f.addon;local function text(topic) local parts={};for _,row in ipairs(a:WorkbenchPageHelp(topic)) do parts[#parts+1]=row.text end;return table.concat(parts,'\n') end
    local rotations=text('Rotations');assert(not rotations:find('at most 200 cards',1,true) and rotations:find('2,000',1,true),'rotation navigation Help describes obsolete truncation')
    local general=text('General');assert(general:find('Apply, Discard or Cancel',1,true),'Help omits actual navigation choices')
end)
test('literal AceDB Default is protected independently of the localized Default label',function()
    local f,parent=fixture();local a=f.addon;f.env.DEFAULT='Défaut'
    a.db.GetCurrentProfile=function() return 'Other' end;a.db.GetProfiles=function() return {'Default','Other','Défaut'} end
    a.db.profiles={Default={},Other=a.db.profile,['Défaut']={}}
    local p=a:OpenNativeSettings(parent,'Profiles');p.selection='Default';p:Draw()
    assert(not p.fields.delete:IsEnabled(),'localized client can delete the true AceDB Default')
    p.selection='Défaut';p:Draw();assert(p.fields.delete:IsEnabled(),'custom profile matching translated label was incorrectly protected')
end)
test('supported editor inventory distinguishes loaded metadata from available connection',function()
    local f,parent=fixture();local a=f.addon;f.load('UI/lua_editor.lua');f.load('UI/settings_integrations.lua');f.load('Integrations/catalog.lua')
    f.load('Integrations/lua_workbench.lua')
    -- Addon state comes from C_AddOns on every current client.
    f.env.C_AddOns={IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end,
        GetAddOnMetadata=function(name,key) assert(key=='Version');if name=='!!!LuaWorkbench' then return '1.2.3' end end}
    local p=a:CreateSettingsForm(parent)
    p:Open(function(form) a:BuildIntegrationSettings(form) end)
    local function cardText()
        local card=assert(p.fields.integration_card_editor_LuaWorkbench);local rows={}
        for _,label in ipairs(p.pool.integrationLabels or {})do if label:GetParent()==card then rows[#rows+1]=label:GetText()end end
        return table.concat(rows,'\n')
    end
    assert(cardText():find('1.2.3',1,true) and p.fields.integration_status_editor_LuaWorkbench:GetText()=='Not loaded','loaded addon falsely advertised an available integration')
    a:RegisterLuaEditorProvider('LuaWorkbench',function() error('must not create editor from settings') end)
    p:Draw();assert(p.fields.integration_status_editor_LuaWorkbench:GetText()=='Not loaded','registration alone fabricated native availability')
    a.CreateLuaWorkbenchControl=function()error('must not construct editor from inventory')end;f.env.LuaWorkbench={}
    p:Draw();assert(p.fields.integration_status_editor_LuaWorkbench:GetText()=='Selected')
end)
test('saved settings pages use Discard while new profile drafts keep Cancel',function()
    local f,parent=fixture();local a=f.addon;local p=a:OpenNativeSettings(parent,'General')
    assert(p.fields.cancel:GetText()=='Discard','saved-page footer does not match navigation and Help')
    a.db.GetCurrentProfile=function() return 'One' end;a.db.GetProfiles=function() return {'One'} end
    p=a:OpenNativeSettings(parent,'Profiles');p.fields.new_collection:Click()
    assert(p.fields.cancel:GetText()=='Cancel','new creation lost its Cancel action')
end)
test('collection Help describes confirmed immediate entity deletion and staged row edits separately',function()
    local f=fixture();local a=f.addon;local item={};for _,row in ipairs(a:GetDocument_layout_itemsets_options_help()) do item[row.id]=row.text end
    local announce={};for _,row in ipairs(a:GetDocument_layout_announce_options_help()) do announce[row.id]=row.text end
    assert(item.delete:find('permanently',1,true) and not item.delete:find('staged',1,true),'item-set entity deletion Help still describes old pending deletes')
    assert(announce.collections:find('permanently',1,true) and not announce.collections:find('draft; Cancel',1,true),'announcement entity deletion Help still describes old pending deletes')
    assert(item.save:find('Discard',1,true) and announce.save:find('Discard',1,true))
end)
test('profile transport preserves optional LibDBIcon state without inventing absent values',function()
    local f=fixture();local a=f.addon
    local profile={minimap={hide=false,minimapPos=123.5,lock=true,showInCompartment=true,radius=8}}
    assert(a:ValidateProfileTransfer(profile),'valid library-owned minimap flag rejected')
    local restored=a:ProfileFromPortable(a:ProfileToPortable(profile))
    assert(a:ValidateProfileTransfer(restored) and restored.minimap.showInCompartment and restored.minimap.minimapPos==123.5 and restored.minimap.lock and restored.minimap.radius==8)
    local absent=a:ProfileFromPortable(a:ProfileToPortable({minimap={hide=false}}))
    assert(absent.minimap.minimapPos==nil and absent.minimap.lock==nil and absent.minimap.showInCompartment==nil and absent.minimap.radius==nil)
    for _,bad in ipairs({{showInCompartment=1},{lock='yes'},{minimapPos='123'},{unexpected=true}}) do assert(not a:ValidateProfileTransfer({minimap=bad})) end
end)
test('native condition rosters distinguish switch entries and hide the internal delete operation',function()
    local f,parent=fixture();local a=f.addon;f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua')
    a:RegisterCondition('LEVEL',{description='Level',fields={}});a:RegisterCondition('SELF_LEVEL',{description='Level',fields={}})
    a.db.profile.condition_groups={{id='g',name='Group',conditions={'LEVEL','SELF_LEVEL','DELETE'}}};a.db.profile.other_conditions_order={};a.db.profile.switch_conditions={'SELF_LEVEL','DELETE'};a.db.profile.disabled_conditions={};a.db.global.custom_conditions={}
    local before=a:CopySettingsData(a.db.profile);local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildConditionSettings(form) end)
    local rows={};for _,row in ipairs(p.roster.rows) do if row.rosterLease then rows[row.rosterEntry.value]=row end end
    assert(not rows.DELETE,'legacy Delete operation leaked into native roster')
    local normal,switch=assert(rows.LEVEL):GetFontString().textColor,assert(rows.SELF_LEVEL):GetFontString().textColor
    assert(normal[1]==.4 and normal[2]==.7 and normal[3]==1,'ordinary condition should stay blue')
    assert(switch[1]==1 and switch[2]==.82 and switch[3]==.25,'switch condition should be gold')
    assert(a.conditionSpecials.DELETE and a:SettingsDataEqual(before,a.db.profile),'presentation removed legacy operation or changed saved categories')
    p.mode='categories';p.categorySelection='g';p:Draw();assert(p.fields.member_LEVEL and p.fields.member_SELF_LEVEL and not p.fields.member_DELETE)
    assert(p.fields.member_SELF_LEVEL:GetFontString().textColor[1]==1 and p.fields.member_LEVEL:GetFontString().textColor[3]==1)
    p.mode=nil;p.category='SWITCH';p:Draw();for _,entry in ipairs(p.roster.entries) do assert(entry.value~='DELETE') end
end)
test('profile export rejects failed scoped conversion instead of encoding a missing profile',function()
    local f,parent=fixture();local a=f.addon;f.load('Data/catalog.lua');f.load('Data/rotation_store.lua')
    a.db.profile={rotationStore={version=999,classes={},characters={},legacy={}}};a.db.GetCurrentProfile=function() return 'One' end;a.db.GetProfiles=function() return {'One'} end
    local before=a:CopySettingsData(a.db.profile);local p=a:CreateSettingsForm(parent);p:Open(function(form) a:BuildProfileSettings(form) end)
    p.fields.transfer:Click();assert(not p.textDialog or not p.textDialog.frame:IsShown(),'export encoded a wrapper with its profile missing')
    assert(p.message:GetText()=='Invalid profile.' and a:SettingsDataEqual(before,a.db.profile),'failed export lost original data or feedback')
end)
test('Proc effects show unsupported fallback without dirty defaults and stage portable controls',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={e={name='Proc',type='proc'}}
    a.GetProcGlowSupport=function() return false end;a.Glow=function() end;a.HideGlow=function() end
    local before=a:CopySettingsData(a.db.global.effects);local p=a:OpenNativeSettings(parent,'Effects')
    assert(p.fields.duration and p.fields.duration_value and p.fields.startAnim,'Proc controls missing')
    assert(p.fields.proc_support and p.fields.proc_support:GetText():find('Pixel',1,true),'unsupported effect has no fallback explanation')
    assert(not p:IsSettingsDraftDirty() and not p.fields.apply:IsEnabled())
    assert(not p.fields.startAnim.unsavedMarker or not p.fields.startAnim.unsavedMarker:IsShown())
    assert(a:SettingsDataEqual(before,a.db.global.effects),'opening Proc wrote defaults')
    p.fields.startAnim:Click();assert(p.draft.global.effects.e.startAnim==true and a.db.global.effects.e.startAnim==nil)
    p.fields.duration:SetValue(1.75);local value=p.draft.global.effects.e
    local codec=a:NewRotationCodec();local decoded=assert(codec:Decode(assert(codec:Encode(value))));assert(a:SettingsDataEqual(value,decoded.value))
    a.GetProcGlowSupport=function() return true end;p:Draw();assert(not p.fields.proc_support)
end)
test('overlay catalog stages exact texture paths across effect fields and rejects stale choices',function()
    local f,parent=fixture();local a=f.addon
    a.db.global.effects={e={name='A Overlay',type='texture',texture='existing'},other={name='Other',type='pixel'}}
    a.Glow=function() end;a.HideGlow=function() end
    local p=a:OpenNativeSettings(parent,'Effects')
    assert(p.selection=='e' and not p:IsSettingsDraftDirty())
    p.fields.texture_catalog:Click();assert(#p.menu.entries==9)
    local entry=p.menu.entries[2];local row=p.menu.rows[2];row:Click()
    assert(p.draft.global.effects.e.texture==entry.value and a.db.global.effects.e.texture=='existing')
    assert(p.fields.texture:GetText()==entry.value and p:IsSettingsDraftDirty())
    local decoded=assert(a:NewRotationCodec():Decode(assert(a:NewRotationCodec():Encode(p.draft.global.effects.e))))
    assert(decoded.value.texture==entry.value)
    p.fields.texture_catalog:Click();local stale=p.menu.rows[3].scripts.OnClick
    p.fields.cancel:Click();stale();assert(a.db.global.effects.e.texture=='existing' and not p:IsSettingsDraftDirty())
    p:Release();a.db.global.effects={e={name='Sequence',type='animate',frequency=.25,sequence={'old'}}};p=a:OpenNativeSettings(parent,'Effects')
    p.fields.seq1_catalog:Click();local selected=p.menu.entries[1].value;p.menu.rows[1]:Click()
    assert(p.draft.global.effects.e.sequence[1]==selected and p.fields.seq1.texturePreview.texture==selected)
    assert(a.db.global.effects.e.sequence[1]=='old')
end)
test('item sequence callbacks use canonical shallow copies without editing the supplied list',function()
    local f,parent=fixture();local a=f.addon;local nested={marker='retained'};local supplied={1,2,metadata=nested};local current=supplied;local changes=0
    local p=a:CreateSettingsForm(parent);p:Open(function(form) form:ItemSequence('items',current,function(value) changes=changes+1;current=value end) end)
    a.deepcopy=function() error('retired addon.deepcopy used by item sequence') end
    local function edit(key,text) local c=p.fields[key];c:SetText(text);c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c) end
    edit('items1','3');assert(current~=supplied and current[1]==3 and current[2]==2 and current.metadata==nested and supplied[1]==1)
    local previous=current;edit('items_new','4');assert(current~=previous and current[1]==3 and current[2]==2 and current[3]==4 and current.metadata==nested and previous[3]==nil)
    previous=current;p.fields.items_delete2:Click();assert(current~=previous and current[1]==3 and current[2]==4 and current[3]==nil and current.metadata==nested and previous[2]==2)
    local stale=p.fields.items1;local count=changes;p:Release();stale:SetText('5');stale.scripts.OnEnterPressed(stale)
    assert(changes==count and current[1]==3 and supplied[1]==1 and supplied[2]==2)
end)
test('help on a non-frame field wrapper never breaks redraw, hover or release',function()
    local f,parent=fixture();local a=f.addon;local owner
    -- WoW's tooltip owner APIs reject anything that is not a frame.
    f.env.GameTooltip={IsOwned=function(_,o) if o.rmWrapper then error('Wrong object type for function') end;return owner==o end,
        SetOwner=function(_,o) if o.rmWrapper then error('Wrong object type for function') end;owner=o end,
        SetText=function() end,AddLine=function() end,Show=function() end,Hide=function() owner=nil end}
    local scripts={};local wrapper={rmWrapper=true,GetScript=function(_,k) return scripts[k] end,SetScript=function(_,k,v) scripts[k]=v end}
    local form=a:CreateSettingsForm(parent)
    form:Open(function(p) p.fields.code=wrapper;p:Check('flag','Flag',false,function() end) end)
    assert(scripts.OnEnter and scripts.OnLeave,'wrapper received no help binding')
    scripts.OnEnter(wrapper);scripts.OnLeave(wrapper)
    form:Open(function(p) p:Check('other','Other',false,function() end) end)
    assert(form.fields.other and form.fields.other:IsShown(),'redraw after a wrapper field failed')
    form:Release()
end)
test('one failing cleanup does not leave the old page behind',function()
    local f,parent=fixture();local a=f.addon;local reported,ran={},false
    f.env.geterrorhandler=function() return function(message) reported[#reported+1]=message end end
    local form=a:CreateSettingsForm(parent)
    form:Open(function(p) p:Check('flag','Flag',false,function() end);p.cleanups[#p.cleanups+1]=function() error('cleanup failed') end;p.cleanups[#p.cleanups+1]=function() ran=true end end)
    local old=form.fields.flag
    form:Open(function(p) p:Check('other','Other',false,function() end) end)
    assert(ran,'later cleanup skipped');assert(#reported==1 and tostring(reported[1]):find('cleanup failed'),'failure not reported')
    assert(form.fields.other and form.fields.other:IsShown(),'new page did not draw')
    assert(old==form.fields.other or not old:IsShown(),'old page control left on screen')
end)
finish()
