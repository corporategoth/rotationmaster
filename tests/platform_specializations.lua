local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(project,expansion)
    local f=F.new(project,expansion)
    f.env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5;f.env.WOW_PROJECT_MISTS_CLASSIC=19
    f.env.WOW_PROJECT_WRATH_CLASSIC=11;f.env.WOW_PROJECT_CAMELOT=18
    f.load('Platform/client.lua');f.load('Platform/specializations.lua');return f
end
test('current rotation keys preserve specialization IDs groups and the single classic namespace',function()
    for _,project in ipairs({1,18}) do
        local f=fixture(project,12)
        f.env.C_SpecializationInfo={GetSpecialization=function() return 2 end,
            GetSpecializationInfo=function(index) assert(index==2);return 264,'Restoration','Healing',123,'HEALER',4,0,nil,0,true end}
        local selection=f.addon.Platform:GetRotationSpecialization()
        assert(selection.key==264 and selection.index==2 and selection.kind=='specialization')
        assert(f.addon:GetSpecialization()==2,'compatibility method changed index to saved namespace')
        selection.key=999;assert(f.addon.Platform:GetRotationSpecialization().key==264)
    end
    local f=fixture(19,4);f.env.C_SpecializationInfo={GetActiveSpecGroup=function() return 2 end}
    assert(f.addon.Platform:GetRotationSpecialization().key==2 and f.addon:GetSpecialization()==2)
    for _,client in ipairs({{5,1},{2,0}}) do
        f=fixture(client[1],client[2]);f.env.GetActiveTalentGroup=function() error('not a group client') end
        local selection=f.addon.Platform:GetRotationSpecialization();assert(selection.key==0 and selection.index==0)
    end
end)
test('legacy methods are used only when the corresponding native specialization method is absent',function()
    local f=fixture(1,12);local p=f.addon.Platform
    f.env.GetSpecialization=function() return 1 end
    f.env.GetSpecializationInfo=function(index) assert(index==1);return 262,'Elemental' end
    assert(p:GetRotationSpecialization().key==262)
    f.env.C_SpecializationInfo={GetSpecialization=function() error('not ready') end}
    local selection,reason=p:GetRotationSpecialization();assert(not selection and reason=='api-error')
    f.env.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return nil end}
    assert(p:GetRotationSpecialization()==nil)
    f=fixture(11,2);f.env.GetActiveTalentGroup=function() return 1 end
    assert(f.addon.Platform:GetRotationSpecialization().key==1)
end)
test('unavailable malformed or restricted selection never becomes namespace zero',function()
    local f=fixture(1,12);local p=f.addon.Platform
    local opaque={};f.env.canaccessvalue=function(value) return value~=opaque end
    for _,value in ipairs({false,0,-1,1.5,math.huge,opaque}) do
        f.env.C_SpecializationInfo={GetSpecialization=function() return value end,GetSpecializationInfo=function() error('invalid index consumed') end}
        local selection,reason=p:GetRotationSpecialization();assert(not selection and reason)
    end
    f.env.C_SpecializationInfo={GetSpecialization=function() return nil end}
    assert(p:GetRotationSpecialization()==nil)
    for _,value in ipairs({false,0,-1,1.5,math.huge,opaque}) do
        f.env.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return value,'Elemental' end}
        assert(p:GetRotationSpecialization()==nil)
    end
    f=fixture(999,12);assert(f.addon.Platform:GetRotationSpecialization()==nil)
    f=fixture(19,4);f.env.C_SpecializationInfo={GetActiveSpecGroup=function() return 0 end}
    assert(f.addon.Platform:GetRotationSpecialization()==nil)
end)
test('editor choices are copied complete bounded namespaces with modern count and legacy class metadata',function()
    local f=fixture(1,12);local p=f.addon.Platform
    f.env.C_SpecializationInfo={GetNumSpecializationsForClassID=function(class) assert(class==7);return 2 end}
    f.env.GetSpecializationInfoForClassID=function(class,index)
        assert(class==7);if index==1 then return 262,'Elemental','Damage',123,'DAMAGER',false,true end
        return 264,'Restoration','Healing',124,'HEALER',false,true
    end
    local choices=p:GetRotationSpecializations(7);assert(#choices==2 and choices[1].id==262 and choices[2].name=='Restoration')
    choices[1].id=999;assert(p:GetRotationSpecializations(7)[1].id==262)
    f.env.C_SpecializationInfo=nil;f.env.GetNumSpecializationsForClassID=function() return 2 end
    assert(#p:GetRotationSpecializations(7)==2)
    f=fixture(19,4);f.env.GetNumTalentGroups=function(inspect,pet) assert(not inspect and not pet);return 2 end
    choices=f.addon.Platform:GetRotationSpecializations();assert(#choices==2 and choices[1].id==1 and choices[2].id==2)
    f=fixture(5,1);choices=f.addon.Platform:GetRotationSpecializations();assert(#choices==1 and choices[1].id==0)
end)
test('incomplete invalid duplicate or unreadable editor choices stay unavailable rather than presenting partial namespaces',function()
    local f=fixture(1,12);local p=f.addon.Platform
    local opaque={};f.env.canaccessvalue=function(value) return value~=opaque end
    f.env.C_SpecializationInfo={GetNumSpecializationsForClassID=function() return 2 end}
    f.env.GetSpecializationInfoForClassID=function(_,index) if index==1 then return 262,'Elemental' end end
    assert(p:GetRotationSpecializations(7)==nil)
    for _,count in ipairs({0,-1,1.5,math.huge,17,opaque}) do
        f.env.C_SpecializationInfo.GetNumSpecializationsForClassID=function() return count end
        assert(p:GetRotationSpecializations(7)==nil)
    end
    f.env.C_SpecializationInfo.GetNumSpecializationsForClassID=function() return 2 end
    f.env.GetSpecializationInfoForClassID=function() return 262,'Elemental' end
    assert(p:GetRotationSpecializations(7)==nil,'duplicate IDs became distinct choices')
    f.env.GetSpecializationInfoForClassID=function(_,index) return index==1 and 262 or 264,opaque end
    assert(p:GetRotationSpecializations(7)==nil)
    f.env.GetNumSpecializationsForClassID=function() return 1 end
    f.env.C_SpecializationInfo.GetNumSpecializationsForClassID=function() error('unavailable') end
    local choices,reason=p:GetRotationSpecializations(7);assert(not choices and reason=='api-error')
    assert(p:GetRotationSpecializations(0)==nil)
end)
finish()
