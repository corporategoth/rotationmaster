-- Run from repository root: lua5.1 tests/buttons.lua
local passed, failed = 0, 0
local function test(name, body)
    local ok, err = pcall(body)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function fixture(attributes, methods, legacy)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5, 1, 5
    env.tinsert = table.insert
    local loaded={}
    env.C_AddOns = {IsAddOnLoaded = function(name) return loaded[name]==true end}
    local L = setmetatable({}, {__index = function(_, key) return key end})
    env.LibStub = setmetatable({GetLibrary = function() return nil end}, {
        __call = function(_, name)
            if name == 'AceLocale-3.0' then return {GetLocale = function() return L end} end
            if name == 'LibCustomGlow-1.0' then return {PixelGlow_Stop=function() end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end} end
            if name == 'AceGUI-3.0' then return {} end
            error('Unexpected library ' .. name)
        end,
    })
    local button = methods or {}
    function button:GetAttribute(key) return attributes[key] end
    env.ActionButton1 = button
    env.HasAction = function(slot) assert(slot and slot > 0, 'invalid action slot'); return slot == 73 end
    env.GetActionInfo = function(slot) assert(slot == 73); return 'spell', 133 end
    env.GetSpellInfo = function(id) assert(id == 133); return 'Fireball', nil, nil, nil, nil, nil, 133 end
    if legacy then
        env.ActionButton_GetPagedID = legacy.paged
        env.ActionButton_CalculateAction = legacy.calculate
    end
    local addon = {db = {profile = {}, global = {effects = {}}}}
    function addon:debug() end
    function addon:verbose() end
    local presentation=assert(loadfile('Core/presentation.lua'));setfenv(presentation,env);presentation('rotationmaster',addon)
    for _,path in ipairs({'Platform/client.lua','Platform/spells.lua','Platform/items.lua','Platform/macros.lua','Functions/collections.lua'}) do
        local load=assert(loadfile(path));setfenv(load,env);load('rotationmaster',addon)
    end
    local chunk = assert(loadfile('buttons.lua')); setfenv(chunk, env); chunk('rotationmaster', addon)
    addon.index = function(list, value)
        for i, entry in ipairs(list) do if entry == value then return i end end
    end
    return env, addon, button, loaded
end
local function assertMappedAndHighlighted(addon, button)
    addon:Fetch()
    assert(addon:FindSpell({999, 133}) == 133, 'spell was not mapped to its button')
    local highlighted = false
    function addon:Glow(frame, kind)
        assert(frame == button and kind == 'highlight'); highlighted = true
    end
    addon:HighlightSlots({73})
    assert(highlighted, 'highlight did not use the resolved action slot')
end

test('TBC method-based paging works for discovery and highlighting', function()
    local _, addon, button = fixture({type = 'action'}, {GetPagedID = function() return 73 end})
    assertMappedAndHighlighted(addon, button)
end)
test('method-based calculation resolves zero paging result', function()
    local _, addon, button = fixture({type = 'action', action = 0}, {
        GetPagedID = function() return 0 end, CalculateAction = function() return 73 end,
    })
    assertMappedAndHighlighted(addon, button)
end)
test('legacy paging globals remain usable', function()
    local _, addon, button = fixture({type = 'action'}, {}, {paged = function() return 73 end})
    assertMappedAndHighlighted(addon, button)
end)
test('legacy calculation resolves zero paging result', function()
    local _, addon, button = fixture({type = 'action'}, {}, {
        paged = function() return 0 end, calculate = function() return 73 end,
    })
    assertMappedAndHighlighted(addon, button)
end)
test('secure action attribute takes precedence', function()
    local _, addon, button = fixture({type = 'action', action = 73}, {
        GetPagedID = function() error('should not override explicit action') end,
    })
    assertMappedAndHighlighted(addon, button)
end)
test('button action field supports frames without paging helpers', function()
    local _, addon, button = fixture({type = 'action'}, {action = 73})
    assertMappedAndHighlighted(addon, button)
end)
test('unresolved slots and absent optional frames are skipped', function()
    local _, addon = fixture({type = 'action'}, {})
    addon:Fetch()
    assert(addon:FindSpell({133}) == nil)
end)
test('optional textured highlights inherit complete profile color without modifying the rotation',function()
    local env,addon,button=fixture({type='action',action=73},{})
    env.tremove=table.remove
    local rgba,overlayStrata,overlayLevel
    function button:GetFrameStrata() return "FULLSCREEN_DIALOG" end
    function button:GetFrameLevel() return 420 end
    local texture={SetBlendMode=function() end,SetAllPoints=function() end,
        SetVertexColor=function(_,r,g,b,a) assert(r and g and b and a,'incomplete glow color');rgba={r,g,b,a} end,
        SetTexture=function() end}
    env.CreateFrame=function(_,_,parent)
        local frame
        frame={GetParent=function() return parent end,ClearAllPoints=function() end,
            SetPoint=function() end,SetWidth=function(_,value) frame.width=value end,SetHeight=function(_,value) frame.height=value end,
            GetWidth=function() return frame.width end,GetHeight=function() return frame.height end,
            SetFrameStrata=function(_,value) overlayStrata=value end,SetFrameLevel=function(_,value) overlayLevel=value end,CreateTexture=function() return texture end,Show=function() end,
            -- The overlay hooks Show/Hide to pause when hidden (e61adb18) and samples its size script every tick.
            HookScript=function() end,GetScript=function() return nil end}
        return frame
    end
    function button:GetWidth() return 36 end
    function button:GetHeight() return 36 end
    addon.HideGlow=function() end;addon.uuid=function() return 'fixture' end
    addon.db.profile={effect='base',color={r=.2,g=.3,b=.4,a=.5},setpoint='CENTER',magnification=1,xoffs=0,yoffs=0}
    addon.db.global.effects.base={type='texture',texture='test'}
    addon:Fetch()
    local step={id='optional'}
    addon:GlowCooldown(133,true,step)
    assert(table.concat(rgba,',')=='0.2,0.3,0.4,0.5' and step.color==nil)
    assert(overlayStrata=='FULLSCREEN_DIALOG' and overlayLevel==421,'preview glow is under the dialog icon')
    addon:Glow(button,'partial',addon.db.global.effects.base,{r=0},1,'CENTER',0,0)
    assert(rgba[1]==0 and rgba[2]==.3 and rgba[4]==.5)
    addon.db.profile.color=nil
    addon:Glow(button,'missing',addon.db.global.effects.base,nil,1,'CENTER',0,0)
    assert(table.concat(rgba,',')=='1,1,1,1')
end)
test('modern-only spell and optional totem-button metadata never call removed globals',function()
    local env,addon,_,loaded=fixture({type='action'},{GetPagedID=function() return 73 end})
    env.ActionButton1=nil;loaded.TotemTimers=true
    env.GetSpellInfo=nil
    env.C_Spell={GetSpellInfo=function(id) assert(id==133);return {name='Fireball',spellID=133} end}
    env.XiTimers_Timer1={GetAttribute=function(_,key) if key=='*spell1' then return 133 end end}
    addon:Fetch();assert(addon:FindSpell({133})==133)
end)
test('modern-only item and macro-item buttons map the canonical use spell',function()
    for _,kind in ipairs({'item','macro'}) do
        local env,addon=fixture({type=kind,[kind]=kind=='item' and 5512 or 1},{})
        env.GetItemSpell=nil
        env.C_Item={GetItemSpell=function(item) assert(item==5512 or item=='item:5512');return 'Healthstone',234 end,
            GetItemInfoInstant=function() return 5512 end}
        env.GetMacroItem=function() return 'Healthstone','item:5512' end
        addon:Fetch();assert(addon:FindSpell({234})==234,kind..' use spell was not mapped')
    end
end)
test('restricted client fetch clears previous mappings and never scans combat action APIs',function()
    local env,addon=fixture({type='action'},{GetPagedID=function() return 73 end})
    addon:Fetch();assert(addon:FindSpell({133})==133)
    env.WOW_PROJECT_ID=1
    env.GetActionInfo=function() error('restricted client scanned combat action information') end
    addon:Fetch();assert(addon:FindSpell({133})==nil,'restricted client retained old combat mappings')
end)
test('items sharing a use spell require the exact mapped item for lookup and both highlight channels',function()
    local env,a,first=fixture({type='item',item=5512},{})
    env.C_Item={GetItemSpell=function() return 'Shared use',234 end}
    a:Fetch();assert(a:FindSpell({234},{5512})==234)
    assert(a:FindSpell({234},{5513})==nil,'ready unmapped item borrowed a different item button')
    local second={GetAttribute=function(_,key) if key=='type' then return 'item' elseif key=='item' then return 5513 end end}
    env.ActionButton2=second;a:Fetch()
    local lit={}
    a.Glow=function(_,button,key) lit[button]=lit[button] or {};lit[button][key]=true end
    a.HideGlow=function(_,button,key) if lit[button] then lit[button][key]=nil end end
    a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    a:GlowNextSpell(234,5513)
    assert(lit[second] and lit[second].next and not(lit[first] and lit[first].next))
    assert(a:IsGlowing(234,5513) and not a:IsGlowing(234,5512),'same use spell hid a changed selected item')
    local step={id='shared-optional'}
    a:GlowCooldown(234,true,step,5512)
    assert(lit[first][234] and not lit[second][234])
    a:GlowCooldown(234,true,step,5513)
    assert(not lit[first][234] and lit[second][234],'optional item change retained the outgoing item glow')
    a:GlowClear();a:GlowCooldown(234,false,step)
    assert(not lit[second].next and not lit[second][234])
end)
test('spell macro buttons normalize current and historical spell identities',function()
    for _,legacyTuple in ipairs({false,true}) do
        local env,a=fixture({type='macro',macro=1},{})
        env.GetMacroItem=function() return nil,nil end
        env.GetMacroSpell=function(id) assert(id==1);if legacyTuple then return 'Fireball','Rank 1',133 end;return 133 end
        a:Fetch();assert(a:FindSpell({133})==133,'macro spell return shape was not mapped')
    end
end)
test('unavailable macro observations skip one button without stopping ordinary discovery or reviving old mappings',function()
    local env,a,bad=fixture({type='macro',macro=1},{})
    env.GetMacroItem=function() return nil,nil end;env.GetMacroSpell=function() return 133 end
    a:Fetch();assert(a:FindSpell({133})==133)
    local second={GetAttribute=function(_,key) if key=='type' then return 'spell' elseif key=='spell' then return 133 end end}
    env.ActionButton2=second
    env.GetMacroItem=nil
    a:Fetch();assert(a:FindSpell({133})==133)
    local lit={};a.Glow=function(_,button) lit[button]=true end;a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    a:GlowNextSpell(133);assert(lit[second] and not lit[bad],'uncertain macro was retained as a spell action')
    env.GetMacroItem=function() error('temporary failure') end;a:Fetch();assert(a:FindSpell({133})==133)
    env.GetMacroItem=function() return nil,nil end;env.ActionButton2=nil;a:Fetch();assert(a:FindSpell({133})==133)
end)
test('macro observations refresh mappings and retire old highlights without scanning ordinary buttons',function()
    local env,a,macro=fixture({type='macro',macro=1},{})
    local observed=133
    env.GetMacroItem=function() return nil,nil end
    env.GetMacroSpell=function() return observed end
    local ordinary={GetAttribute=function(_,key) if key=='type' then return 'spell' elseif key=='spell' then return 133 end end}
    env.ActionButton2=ordinary
    a:Fetch()
    local lit={}
    a.Glow=function(_,button,key) lit[button]=lit[button] or {};lit[button][key]=true end
    a.HideGlow=function(_,button,key) if lit[button] then lit[button][key]=nil end end
    a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    a:GlowNextSpell(133);a:GlowCooldown(133,true,{id='cooldown'})
    assert(lit[macro].next and lit[macro][133])
    env.GetSpellInfo=function() error('ordinary spell metadata must not be rescanned') end
    observed=116
    assert(a.RefreshMacroButtons,'dynamic refresh is missing');a:RefreshMacroButtons()
    assert(a:FindSpell({116})==116 and a:FindSpell({133})==133,'changed macro displaced ordinary mapping')
    assert(not lit[macro].next and not lit[macro][133],'outgoing macro highlights survived')
    assert(not a:IsGlowing(133),'old highlight identity suppressed reapplication')
    a:GlowNextSpell(116);a:GlowCooldown(116,true,{id='cooldown'})
    assert(lit[macro].next and lit[macro][116] and not lit[ordinary][116])
    a:RefreshMacroButtons()
    assert(lit[macro].next and lit[macro][116] and a:IsGlowing(116),'unchanged macro reset highlights')
end)
test('unavailable macro buttons recover and exact item changes cannot borrow previous ownership',function()
    local env,a,button=fixture({type='macro',macro=1},{})
    local item
    env.GetMacroItem=function() if item then return 'Item','item:'..item end end
    env.GetMacroSpell=function() return nil end
    env.C_Item={GetItemSpell=function() return 'Shared use',234 end,GetItemInfoInstant=function(link) return tonumber(link:match('item:(%d+)')) end}
    a:Fetch();assert(not a:FindSpell({234}))
    assert(a.RefreshMacroButtons,'dynamic refresh is missing')
    item=5512;a:RefreshMacroButtons();assert(a:FindSpell({234},{5512})==234)
    item=5513;a:RefreshMacroButtons();assert(a:FindSpell({234},{5513})==234 and not a:FindSpell({234},{5512}))
    env.GetMacroItem=function() error('temporary API failure') end
    a:RefreshMacroButtons();assert(not a:FindSpell({234}),'failed observation retained stale action')
    env.GetMacroItem=function() return 'Item','item:5512' end
    a:RefreshMacroButtons();assert(a:FindSpell({234},{5512})==234)
    env.WOW_PROJECT_ID=1;env.GetMacroItem=function() error('restricted policy queried a macro') end
    a:RefreshMacroButtons();assert(not a:FindSpell({234}),'policy transition retained action mappings')
end)
test('duplicate bar registrations share one macro observation and one highlight per button',function()
    local env,a,button,loaded=fixture({type='macro',macro=1},{})
    env.ButtonForge1=button;loaded.ButtonForge=true
    local calls=0
    env.GetMacroItem=function() return nil,nil end
    env.GetMacroSpell=function() calls=calls+1;return 133 end
    local other={GetAttribute=function(_,key) if key=='type' then return 'macro' elseif key=='macro' then return 1 end end}
    env.ActionButton2=other;a:Fetch()
    assert(a.RefreshMacroButtons,'dynamic refresh is missing');calls=0;a:RefreshMacroButtons()
    assert(calls==1,'one macro was observed repeatedly in a pass')
    local glows={};a.Glow=function(_,b) glows[b]=(glows[b] or 0)+1 end
    a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    a:GlowNextSpell(133);assert(glows[button]==1 and glows[other]==1,'duplicate scanner registration repeated a highlight')
    env.ActionButton1=nil;env.ActionButton2=nil;env.ButtonForge1=nil;a:Fetch()
    calls=0;a:RefreshMacroButtons();assert(calls==0 and not a:FindSpell({133}),'full scan retained old macro records')
end)
test('duplicate scans cannot leave a button indexed under an earlier exposed macro action',function()
    local env,a,button,loaded=fixture({type='macro',macro=1},{})
    loaded.ButtonForge=true;env.ButtonForge1=button
    local reads=0;env.GetMacroItem=function() return nil,nil end
    env.GetMacroSpell=function() reads=reads+1;return reads==1 and 133 or 116 end
    a:Fetch();a:RefreshMacroButtons()
    assert(a:FindSpell({116})==116 and not a:FindSpell({133}),'duplicate discovery retained old ownership')
end)
test('unreadable macro attributes and failed button reads recover without a bar rescan',function()
    local secret={};local attributes={type='macro',macro=secret}
    local env,a,button=fixture(attributes,{})
    env.canaccessvalue=function(value) return value~=secret end
    env.GetMacroItem=function() return nil,nil end;env.GetMacroSpell=function() return 133 end
    a:Fetch();assert(not a:FindSpell({133}))
    attributes.macro=1;a:RefreshMacroButtons();assert(a:FindSpell({133})==133,'initial restricted observation was not retained for recovery')
    local read=button.GetAttribute;button.GetAttribute=function() error('temporarily unavailable') end
    a:RefreshMacroButtons();assert(not a:FindSpell({133}),'failed button read retained stale action')
    button.GetAttribute=read;a:RefreshMacroButtons();assert(a:FindSpell({133})==133)
end)
-- Restricted clients run complete rotations, so their bars are scanned too.
-- Every slot read is guarded: a secret slot is skipped, never compared.
test('restricted clients map action slots; secret slots are skipped',function()
    local env,a,button=fixture({type='action'},{GetPagedID=function() return 73 end})
    env.WOW_PROJECT_ID=1
    assert(a.Platform:GetCombatDataPolicy()=='restricted')
    assertMappedAndHighlighted(a,button)
    local secret={}
    local native=a.Platform.CanReadValue
    a.Platform.CanReadValue=function(self,value) if value==secret then return false end return native(self,value) end
    env.GetActionInfo=function() return 'spell',secret end
    a:Fetch();assert(not a:FindSpell({133}),'a secret slot was mapped')
    env.HasAction=function() return secret end
    a:Fetch();assert(not a:FindSpell({133}),'a secret presence flag was tested')
end)
print(string.format('%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
