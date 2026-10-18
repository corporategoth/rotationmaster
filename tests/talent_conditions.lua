local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(project,expansion)
    local f=F.new(project,expansion);local a,e=f.addon,f.env
    local state={rank=2,selected=true,calls=0}
    local compress=f.libraries.LibCompress
    compress.fcs16init=function() return '' end;compress.fcs16update=function(_,hash,value) return hash..value end
    compress.fcs16final=function(_,hash) return hash end
    e.GetNumTalentTabs=function() return 3 end;e.GetNumTalents=function() return 2 end
    e.C_SpecializationInfo={GetSpecializationInfo=function(tree) return tree,'Elemental','Description',1,nil,nil,2 end,
        GetTalentInfo=function(query)
            state.calls=state.calls+1
            return {name='Convection',icon=1,rank=state.rank,maxRank=5,talentID=101,spellID=108269,
                tier=1,column=2,selected=state.selected,available=true,known=true,grantedByAura=false,
                previewRank=0,meetsPrereq=true,meetsPreviewPrereq=true,isExceptional=false,hasGoldBorder=false,isPVPTalentUnlocked=false}
        end}
    for _,path in ipairs({'Platform/talents.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'}) do f.load(path) end
    local ace=f.libraries['AceGUI-3.0'];local create=ace.Create
    ace.Create=function(self,kind)
        local w=create(self,kind);function w:SetList(values,order) self.list,self.order=values,order end;return w
    end
    return f,state
end
local function tree() return {type='TALENT',tree=1,talent=1,operator='EQUALS',value=2} end
test('real talent rank condition uses native records reuses each pass and sees newly spent points',function()
    local f,s=fixture();local a=f.addon;local value=tree()
    assert(a:evaluateConditionResult(value).status=='match')
    s.calls=0
    assert(a:evaluateCondition({type='AND',value={value,tree()}}) and s.calls==1,'rank was sampled inconsistently within one pass')
    s.rank=0;assert(a:evaluateConditionResult(value).status=='no-match','permanent talent cache hid a respec')
    assert(a:evaluateCondition({type='NOT',value=value}))
    local opaque={};f.env.canaccessvalue=function(v) return v~=opaque end;s.rank=opaque
    assert(a:evaluateConditionResult({type='NOT',value=value}).status=='unavailable','secret rank became unselected')
    f.env.C_SpecializationInfo.GetTalentInfo=function() error('native unavailable') end
    assert(a:evaluateConditionResult({type='NOT',value=value}).status=='unavailable')
end)
test('grid selection is explicit and historical tree or legacy retail slots remain unavailable under NOT',function()
    local f,s=fixture(19,4);local a=f.addon
    local value={type='TALENT',layout='grid',value=3}
    assert(a:evaluateCondition(value));s.selected=false;assert(not a:evaluateCondition(value))
    assert(a:evaluateCondition({type='NOT',value=value}))
    assert(a:evaluateConditionResult({type='NOT',value=tree()}).status=='unavailable','Mists placeholder ranks were interpreted as real tree state')
    f=fixture(1,12);a=f.addon
    f.env.C_SpecializationInfo.GetTalentInfo=function() error('modern trait tree must not query an old slot') end
    assert(a:evaluateConditionResult({type='NOT',value={type='TALENT',value=1}}).status=='unavailable')
    assert(a:evaluateConditionResult({type='NOT',value={type='TALENT',layout='grid',value=1}}).status=='unavailable')
end)
test('malformed rank and grid fields cannot call native APIs and metadata printers remain readable when absent',function()
    local f,s=fixture();local a=f.addon;local definition=a.conditionDefinitions.TALENT
    for _,mutation in ipairs({{tree=1.5},{talent=-1},{value=math.huge},{value=0/0},{operator='TYPO'},{layout='future'}}) do
        local value=tree();for key,v in pairs(mutation) do value[key]=v end
        assert(not definition.valid(0,value))
    end
    assert(s.calls==0)
    local text=definition.print(0,tree());assert(text:find('Convection',1,true) and text:find('Elemental',1,true))
    f.env.C_SpecializationInfo=nil;f.env.GetTalentInfo=nil;f.env.GetTalentTabInfo=nil
    text=definition.print(0,tree());assert(text:find('<talent>',1,true) and text:find('<talent tree>',1,true))
    local help=f.widget('help');definition.help(help);assert(#F.text(help)>20)
end)
local function fields(f,value,spec)
    local parent,top=f.widget('parent'),f.widget('top')
    top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'Updated condition' end})
    parent:SetUserData('top',top)
    f.addon.conditionDefinitions.TALENT.widget(parent,spec or 0,value)
    return parent
end
test('tree editor names native trees and clears former talent only on an explicit tree change',function()
    local f=fixture();local value=tree();local parent=fields(f,value)
    local trees
    for _,w in ipairs(parent.children) do if (w.caption and w.caption:GetText() or w.label)=='Talent Tree' then trees=w end end
    assert(trees);trees.configure();assert(trees.list[1]=='Elemental' and value.talent==1 and value.layout==nil)
    trees.callbacks.OnValueChanged(trees,nil,2)
    assert(value.tree==2 and value.talent==nil and value.layout=='tree')
    f.env.GetNumTalentTabs=nil;f.env.GetNumTalents=nil;f.env.C_SpecializationInfo=nil
    assert(fields(f,tree()),'missing metadata prevented opening an old condition')
end)
test('Mists picker does not silently convert historical references and writes grid identity only on explicit choice',function()
    local f=fixture(19,4);local value=tree();local parent=fields(f,value,2)
    assert(value.tree==1 and value.talent==1 and value.value==2 and value.layout==nil)
    local picker
    for _,w in ipairs(parent.children) do if (w.caption and w.caption:GetText() or w.label)=='Talent' then picker=w end end
    assert(picker);picker.configure();assert(picker.value==nil and #picker.order==18)
    picker.callbacks.OnValueChanged(picker,nil,3)
    assert(value.layout=='grid' and value.value==3 and value.tree==nil and value.talent==nil and value.operator==nil)
    assert(f.addon.conditionDefinitions.TALENT.valid(2,value))
    f=fixture(1,12);value={type='TALENT',value=1};assert(fields(f,value) and value.value==1 and value.layout==nil)
end)
finish()
