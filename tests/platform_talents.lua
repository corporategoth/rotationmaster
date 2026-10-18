local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(project,expansion)
    local f=F.new(project,expansion);f.load('Platform/talents.lua');return f
end
local function record()
    return {talentID=101,name='Convection',icon=136170,tier=1,column=2,selected=false,available=false,spellID=0,
        isPVPTalentUnlocked=false,known=false,grantedByAura=false,rank=2,maxRank=5,meetsPrereq=true,
        previewRank=0,meetsPreviewPrereq=false,isExceptional=false,hasGoldBorder=false}
end
test('classic tree metadata and ranks prefer native tuples and records with explicit query identities',function()
    local f=fixture();local p=f.addon.Platform
    f.env.GetNumTalentTabs=function(inspect,pet) assert(inspect==false and pet==false);return 3 end
    f.env.GetNumTalents=function(tree,inspect,pet) assert(tree==1 and not inspect and not pet);return 20 end
    f.env.C_SpecializationInfo={GetSpecializationInfo=function(tree,inspect,pet,target,sex,group)
        assert(tree==1 and not inspect and not pet and target==nil and sex==nil and group==2)
        return 261,'Elemental','Description',136048,nil,nil,2,'background',0,true
    end,GetTalentInfo=function(query)
        assert(query.specializationIndex==1 and query.talentIndex==3 and query.groupIndex==2 and query.isInspect==false and query.isPet==false)
        return record()
    end}
    assert(p:GetTalentLayout()=='tree' and p:GetTalentTreeCount()==3 and p:GetTreeTalentCount(1)==20)
    local tree=p:GetTalentTreeInfo(1,2);assert(tree.name=='Elemental' and tree.pointsSpent==2 and tree.icon==136048)
    local talent=p:GetTreeTalentInfo(1,3,2);assert(talent.name=='Convection' and talent.rank==2 and talent.maxRank==5 and talent.talentID==101)
    talent.rank=5;assert(p:GetTreeTalentInfo(1,3,2).rank==2)
end)
test('legacy tree tuple layouts normalize names and points without confusing a modern wrapper ID for a name',function()
    local f=fixture();local p=f.addon.Platform
    f.env.GetTalentTabInfo=function() return 'Elemental',136048,2,'background' end
    f.env.GetTalentInfo=function(tree,talent,inspect,pet,group)
        assert(tree==1 and talent==3 and not inspect and not pet and group==nil)
        return 'Convection',136170,1,2,0,5,true,0,false,false,false,101
    end
    assert(p:GetTalentTreeInfo(1).name=='Elemental' and p:GetTalentTreeInfo(1).pointsSpent==2)
    assert(p:GetTreeTalentInfo(1,3).rank==0)
    f.env.GetTalentTabInfo=function() return 261,'Elemental','Description',136048,2,'background' end
    assert(p:GetTalentTreeInfo(1).name=='Elemental' and p:GetTalentTreeInfo(1).pointsSpent==2)
    f.env.C_SpecializationInfo={GetTalentInfo=function() error('not ready') end}
    local value,reason=p:GetTreeTalentInfo(1,3);assert(not value and reason=='api-error')
end)
test('invalid missing restricted and malformed tree observations remain unavailable without fabricated counts or ranks',function()
    local f=fixture();local p=f.addon.Platform;local opaque={}
    f.env.canaccessvalue=function(value) return value~=opaque end
    local calls=0;f.env.C_SpecializationInfo={GetTalentInfo=function() calls=calls+1;return record() end}
    for _,index in ipairs({0,-1,1.5,math.huge,opaque}) do assert(p:GetTreeTalentInfo(index,1)==nil) end
    assert(calls==0 and p:GetTalentTreeCount()==nil and p:GetTreeTalentCount(1)==nil)
    f.env.GetNumTalentTabs=function() return 0 end;assert(p:GetTalentTreeCount()==0)
    f.env.GetNumTalentTabs=function() return opaque end;assert(p:GetTalentTreeCount()==nil)
    for _,mutation in ipairs({{rank=-1},{rank=6},{maxRank=0},{rank=opaque},{name=opaque},{icon=opaque},{rank=false}}) do
        f.env.C_SpecializationInfo.GetTalentInfo=function() local value=record();for key,v in pairs(mutation) do value[key]=v end;return value end
        assert(p:GetTreeTalentInfo(1,3)==nil)
    end
    f.env.C_SpecializationInfo.GetTalentInfo=function() return nil end;assert(p:GetTreeTalentInfo(1,3)==nil)
    f.env.C_SpecializationInfo.GetTalentInfo=function() return opaque end;assert(p:GetTreeTalentInfo(1,3)==nil)
end)
test('Mists grid uses native selected state and correct final columns while tree and modern trait layouts cannot be confused',function()
    local f=fixture(19,4);local p=f.addon.Platform
    f.env.C_SpecializationInfo={GetTalentInfo=function(query)
        assert(query.tier==6 and query.column==3 and query.groupIndex==2 and not query.isInspect)
        assert(query.specializationIndex==nil and query.talentIndex==nil)
        local value=record();value.rank=0;value.maxRank=0;value.selected=false;value.spellID=108269;return value
    end}
    assert(p:GetTalentLayout()=='grid')
    local value=p:GetGridTalentInfo(18,2);assert(value.name=='Convection' and value.selected==false and value.spellID==108269)
    assert(value.rank==nil and p:GetTreeTalentInfo(1,3)==nil and p:GetTalentTreeCount()==nil)
    f.env.C_SpecializationInfo.GetTalentInfo=function() local data=record();data.selected=true;data.spellID=108269;return data end
    assert(p:GetGridTalentInfo(1).selected)
    f.env.C_SpecializationInfo=nil;f.env.GetTalentInfo=function() return 'Misleading rank',1,1,1,0,0 end
    assert(p:GetGridTalentInfo(1)==nil,'deprecated Mists rank placeholders became a grid selection')
    for _,client in ipairs({{1,12},{18,12},{999,12}}) do
        f=fixture(client[1],client[2]);assert(f.addon.Platform:GetTreeTalentInfo(1,1)==nil and f.addon.Platform:GetGridTalentInfo(1)==nil)
    end
end)
finish()
