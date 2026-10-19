local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new()
    dofile('tests/fixtures/spell_editbox.lua')(f)
    f.load('UI/window.lua')
    for _,path in ipairs({'Platform/client.lua','Platform/spells.lua','Core/conditions.lua','Conditions/known_spell.lua'}) do f.load(path) end
    return f
end
test('an unlearned spell is valid and becomes known after training without a new rotation',function()
    local f=fixture()
    local known=false
    f.env.IsSpellKnown=function(id,pet) assert(id==974 and pet==false);return known end
    local v={type='SPELL_KNOWN',spell=974}
    assert(f.addon:validateCondition(v,0))
    assert(f.addon:evaluateConditionResult(v).status=='no-match')
    assert(f.addon:evaluateCondition({type='NOT',value=v}))
    known=true;assert(f.addon:evaluateCondition(v))
end)
test('pet learned state uses the actual pet bank',function()
    local f=fixture()
    f.env.Enum.SpellBookSpellBank={Player=0,Pet=1}
    f.env.C_SpellBook={IsSpellKnown=function(id,bank) assert(id==974);return bank==1 end}
    assert(f.addon:evaluateCondition({type='SPELL_KNOWN',spell=974,pet=true}))
    assert(not f.addon:evaluateCondition({type='SPELL_KNOWN',spell=974,pet=false}))
end)
test('unavailable learned state cannot become a positive NOT condition',function()
    local f=fixture()
    local v={type='NOT',value={type='SPELL_KNOWN',spell=974}}
    assert(f.addon:evaluateConditionResult(v).status=='unavailable')
    local opaque={}
    f.env.canaccessvalue=function(x) return not rawequal(x,opaque) end
    f.env.IsSpellKnown=function() return opaque end
    local result=f.addon:evaluateConditionResult(v)
    assert(result.status=='unavailable' and result.reason=='restricted-value')
end)
test('spell guards reject malformed identifiers without metadata API calls',function()
    local f=fixture()
    f.env.C_Spell={GetSpellInfo=function() error('validation must not require loaded spell metadata') end}
    for _,id in ipairs({0,-1,1.5,'974',{},math.huge}) do
        assert(not f.addon:validateCondition({type='SPELL_KNOWN',spell=id},0))
    end
    assert(not f.addon:validateCondition({type='SPELL_KNOWN',spell=974,pet='yes'},0))
    assert(f.addon:validateCondition({type='SPELL_KNOWN',spell=974},0))
end)
test('learned spell summaries and help render without the dropdown catalog',function()
    local f=fixture()
    local d=f.addon.conditionDefinitions.SPELL_KNOWN
    assert(d.print(0,{spell=974}):find('974',1,true))
    local frame=f.widget('Frame');d.help(frame)
    assert(#F.text(frame)>80)
    assert(f.translations['Spell Known'] and f.translations['You know %s'] and f.translations['Your pet knows %s'])
end)
test('the spell-search editor keeps canonical IDs while presenting names and native links',function()
    local f=fixture()
    f.env.C_Spell={
        GetSpellInfo=function(id)
            if id==403 then return {name='Lightning Bolt',spellID=403} end
            if id==974 or id=='Earth Shield' then return {name='Earth Shield',spellID=974} end
        end,
        GetSpellLink=function(id) if id==974 or id==403 then return '|Hspell:'..id..'|h[Named Spell]|h' end end,
    }
    local v={type='SPELL_KNOWN',spell=403}
    local top,parent=f.widget('Frame'),f.widget('Group')
    parent:SetUserData('top',top);top:SetUserData('root',v)
    top:SetUserData('funcs',{print=function(_,root,spec) return f.addon:printCondition(root,spec) end})
    f.addon.conditionDefinitions.SPELL_KNOWN.widget(parent,0,v)
    local edit,preview,pet=parent.children[1],parent.children[2],parent.children[3]
    assert(edit.type=='RM-ConditionEditBox' and edit:GetText()=='Lightning Bolt' and pet:GetValue()==false)
    assert(preview.text:find('|Hspell:403',1,true))
    edit:Fire('OnEnterPressed','Earth Shield')
    pet.button:Click()
    assert(v.spell==974 and v.pet==true and top.statusText:find('974',1,true))
    edit:Fire('OnEnterPressed','invalid')
    assert(v.spell==nil and not f.addon:validateCondition(v,0))
end)
test('rank-specific selections retain readable rank text and exact learned ID when confirmed again',function()
    local f=fixture()
    f.env.C_Spell={GetSpellInfo=function(id)
        if id==8042 then return {name='Earth Shock',spellID=8042} end
        if id==8045 then return {name='Earth Shock',spellID=8045} end
    end,GetSpellSubtext=function(id) return id==8042 and 'Rank 1' or 'Rank 3' end}
    f.env.IsSpellKnown=function(id) return id==8042 end
    local value={type='SPELL_KNOWN',spell=8042}
    local top,parent=f.widget('Frame'),f.widget('Group')
    parent:SetUserData('top',top);top:SetUserData('root',value)
    top:SetUserData('funcs',{print=function() return 'summary' end})
    f.addon.conditionDefinitions.SPELL_KNOWN.widget(parent,0,value)
    local edit=parent.children[1]
    assert(edit.text=='Earth Shock (Rank 1)','exact rank is hidden in selected display')
    edit:Fire('OnEnterPressed',edit:GetText())
    assert(value.spell==8042 and f.addon:evaluateCondition(value),'reconfirming the displayed rank changed its ID')
    edit:Fire('OnEnterPressed',8045)
    assert(value.spell==8045 and edit.text=='Earth Shock (Rank 3)' and not f.addon:evaluateCondition(value))
end)
test('the owned spell picker offers exact lower ranks without the shared scanner',function()
    local f=fixture();local value={spell=8042};local ranks={[8042]=1,[8044]=2,[8045]=3}
    f.env.C_Spell={GetSpellInfo=function(id)
        if ranks[id] then return {name='Earth Shock',subtext='Rank '..ranks[id],spellID=id,iconID=1} end
    end}
    for id in pairs(ranks) do f.addon.SpellCatalog:UpdateSpell(id) end
    local top,parent=f.widget('Frame'),f.widget('Group');parent:SetUserData('top',top)
    f.addon.conditionDefinitions.SPELL_KNOWN.widget(parent,0,value)
    local edit=parent.children[1];edit:SetFocus()
    local popup=edit.rmSpellPopup
    assert(popup.rows[1].spellID==8045 and popup.rows[2].spellID==8044 and popup.rows[3].spellID==8042)
    assert(f.libraries['AceGUI-3.0-SpellLoader'].spellList==nil)
end)
test('saved unlearned ranked references are indexed and reconfirm through the actual native Enter handler',function()
    local f=fixture();f.env.C_Spell={GetSpellInfo=function(id)
        if id==8042 then return {name='Earth Shock',subtext='Rank 1',spellID=id} end
    end}
    local value={spell=8042};local parent,top=f.widget('Group'),f.widget('Frame')
    parent:SetUserData('top',top);top:SetUserData('root',value)
    top:SetUserData('funcs',{print=function() return 'updated' end})
    f.addon.conditionDefinitions.SPELL_KNOWN.widget(parent,0,value)
    local edit=parent.children[1];edit:SetFocus();edit.editbox.scripts.OnEnterPressed(edit.editbox)
    assert(value.spell==8042 and top.statusText=='updated' and not edit.editbox:HasFocus(),'saved rank could not be reconfirmed')
    assert(f.addon.SpellCatalog:Search('Earth Shock')[1].id==8042,'explicit reference was absent from search')
end)
finish()
