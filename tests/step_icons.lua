-- The icon on a rotation card: Stop has its own artwork (the condition icon
-- of whatever it checks is not its icon), and Blizzard's suggestion wears the
-- icon of Blizzard's one-button assistant. Either falls back to the condition
-- icon the card showed before when its artwork or the client's spell is absent.
local F=dofile('tests/fixtures/addon.lua')
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local prefix=assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local fixture,card=assert(loadstring(prefix..'\nreturn fixture,card','@step-icons-fixture'))()
local test,finish=F.suite()
local COMBAT={type='COMBAT',unit='player'}
local STOP='Interface\\AddOns\\rotationmaster\\Assets\\Conditions\\stop'
local ONE_BUTTON=7777777
local function editor(mutate)
    local f,parent=fixture();local a=f.addon
    local value=a:GetEditableRotation(0,'mine')
    value.rotation={{id='stop',type='stop',conditions={type='COMBAT',unit='player'}},{id='plain',type='stop',conditions={}},
        {id='assisted',type='assisted',conditions={type='COMBAT',unit='player'}},{id='assistedAlways',type='assisted',conditions={}},{id='spell',type='spell',action=403,conditions={type='COMBAT',unit='player'}}}
    value.cooldowns={}
    a.conditionIcons={COMBAT='Interface\\Icons\\Combat-Condition'}
    local platformInfo=a.Platform.GetSpellInfo
    a.Platform.GetSpellInfo=function(self,id)
        if id==1229376 then if mutate and mutate.assisted==false then return nil end;return {spellID=id,name='Single-Button Assistant',iconID=ONE_BUTTON} end
        if id==403 then return {spellID=id,name='Lightning Bolt',iconID=136048} end
        return platformInfo(self,id)
    end
    if mutate and mutate.stop~=nil then a.StepArtwork.stop.shipped=mutate.stop end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    return f,a,pane
end
local function icon(pane,id) return card(pane,id).icon:GetTexture() end

test('the Stop card has its own icon whatever its condition is',function()
    local _,a,pane=editor()
    assert(icon(pane,'stop')==STOP,'Stop icon: '..tostring(icon(pane,'stop')))
    assert(icon(pane,'stop')==icon(pane,'plain'),'the Stop icon follows its condition')
    assert(icon(pane,'spell')==136048,'a spell card changed: '..tostring(icon(pane,'spell')))
end)
test('Blizzard\'s suggestion wears the one-button assistant icon, from the client',function()
    local _,a,pane=editor()
    assert(icon(pane,'assisted')==ONE_BUTTON and icon(pane,'assistedAlways')==ONE_BUTTON,'assisted icon: '..tostring(icon(pane,'assisted')))
    assert(a:GetAssistedStepIcon()==ONE_BUTTON and a.AssistedCombatSpell==1229376)
end)
test('a client without that spell keeps the condition icon the card showed before',function()
    local _,_,pane=editor({assisted=false})
    assert(icon(pane,'assisted')=='Interface\\Icons\\Combat-Condition','fallback: '..tostring(icon(pane,'assisted')))
    assert(icon(pane,'assistedAlways')=='Interface\\Icons\\INV_Misc_QuestionMark','an Always suggestion has no fallback icon: '..tostring(icon(pane,'assistedAlways')))
end)
test('a copy without the Stop artwork keeps the condition icon',function()
    local _,_,pane=editor({stop=false})
    assert(icon(pane,'stop')=='Interface\\Icons\\Combat-Condition' and icon(pane,'plain')=='Interface\\Icons\\INV_Misc_QuestionMark','fallback: '..tostring(icon(pane,'stop')))
end)
test('the list view shows the same icons',function()
    local _,_,pane=editor();pane.view.layout='list';pane:Render()
    assert(icon(pane,'stop')==STOP and icon(pane,'assisted')==ONE_BUTTON)
end)
test('the Stop artwork the card names is in the addon, both sizes, and shipped says so',function()
    local f=fixture();local a=f.addon;local art=a.StepArtwork.stop
    assert(art.shipped==true and art.texture==STOP,'declaration: '..tostring(art.texture))
    for _,name in ipairs({'stop.tga','stop-64.tga'}) do local h=io.open('Assets/Conditions/'..name,'rb');assert(h,name..' is missing while Stop declares it shipped');h:close() end
end)
finish()
