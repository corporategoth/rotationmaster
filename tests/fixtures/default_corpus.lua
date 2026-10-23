-- Authoring/schema fixtures only: this does not simulate combat recommendations.
local F=dofile('tests/fixtures/addon.lua')
local C={}
function C.contains(values,wanted) for _,value in ipairs(values or {}) do if value==wanted then return true end end;return false end
local function paths(prefix)
    local result={}
    for line in io.lines('RotationMaster.toc') do
        local path=line:gsub('\r',''):match('^%s*('..prefix..'/.-%.lua)%s*$')
        if path then result[#result+1]=path end
    end
    assert(#result>0,'no '..prefix..' files in TOC');return result
end
function C.load(project,expansion,class)
    local f=F.new(project,expansion,class);local a,e=f.addon,f.env
    local state={level=1,context='player',build=70006}
    e.UnitLevel=function() return state.level end
    -- FORM validation consumes the native form count; model an unshifted character with no trained forms.
    e.GetNumShapeshiftForms=function(...) assert(select('#',...)==0);return 0 end
    e.UnitHasVehicleUI=function() return state.context=='vehicle' end
    e.C_PetBattles={IsInBattle=function() return state.context=='petbattle' end}
    e.GetBuildInfo=function() return 'fixture',tostring(state.build),'',1 end
    a.delayed_condition={}
    f.load('init.lua');local defaults={char={},profile={},global={}};a:augmentDefaults(defaults)
    a.db=defaults;a.db.profile.rotations={};a.db.profile.itemsets={}
    f.load('Core/conditions.lua')
    for _,path in ipairs(paths('Conditions')) do f.load(path) end
    for tag,definition in pairs(a.conditionDefinitions) do
        definition.evaluate=function() error('corpus validation must not evaluate '..tag) end
    end
    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua'}) do f.load(path) end
    local register=a.RegisterDefaultRotation;local packs={};local ids={}
    a.RegisterDefaultRotation=function(self,pack)
        assert(not ids[pack.id],'duplicate shipped ID '..tostring(pack.id));ids[pack.id]=true
        -- Corpus checks see the expanded tree registration consumes (Built In composition).
        local ok,why=register(self,pack);assert(ok,why);packs[#packs+1]=assert(a:ExpandDefaultRotation(pack));return ok
    end
    for _,path in ipairs(paths('Defaults')) do
        local count=#packs;f.load(path);assert(path:match('^Defaults/blocks/') or #packs>count,path..' registered no defaults')
    end
    assert(a:InitializeRotationLibrary())
    return f,packs,state
end
local function date(value)
    if type(value)~='string' then return false end
    local y,m,d=value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$');y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or y<2004 or not m or m<1 or m>12 or not d or d<1 then return false end
    local days={31,(y%400==0 or y%4==0 and y%100~=0) and 29 or 28,31,30,31,30,31,31,30,31,30,31}
    return d<=days[m]
end
local function sourceURL(value)
    if type(value)~='string' or value:find('%s') then return false end
    local authority=value:match('^https?://([^/?#]+)');if not authority then return false end
    local host,port=authority:match('^([^:]+):(%d+)$')
    if host then if tonumber(port)<1 or tonumber(port)>65535 then return false end
    elseif authority:find(':',1,true) then return false else host=authority end
    host=host:lower()
    if #host>253 or host:find('..',1,true) or not host:find('.',1,true) or host:sub(1,1)=='.' or host:sub(-1)=='.' then return false end
    for label in host:gmatch('[^.]+') do
        if #label>63 or not label:match('^[%a%d][%a%d%-]*$') or label:sub(-1)=='-' then return false end
    end
    local suffix=host:match('%.([^.]+)$')
    if not (suffix:match('^%a%a+$') or suffix:match('^xn%-%-[%a%d%-]+$')) then return false end
    return not ({localhost=true,['local']=true,internal=true,test=true,invalid=true,example=true})[suffix]
end
function C.check(f,pack,strict)
    local a=f.addon
    local options=a:GetRotationValidationOptions();if not strict then options.conditions=nil end
    local report=a.RotationData.ValidateEnvelope(pack,options)
    local diagnostics={};for _,issue in ipairs(report.diagnostics) do diagnostics[#diagnostics+1]=issue.path..':'..issue.code end
    local label=tostring(pack.id)..' '..table.concat(diagnostics,', ')
    assert(report.valid,label)
    if strict then assert(report.supported and report.resolved,label) end
    for _,key in ipairs({'nameKey','descriptionKey'}) do
        local value=f.translations[pack[key]];assert(type(value)=='string' and value:find('%S'),tostring(pack.id)..' untranslated '..key)
    end
    assert(type(pack.sources)=='table' and #pack.sources>0,tostring(pack.id)..' missing sources')
    for index,source in ipairs(pack.sources) do
        assert(type(source.title)=='string' and source.title:find('%S') and sourceURL(source.url) and date(source.reviewedAt),tostring(pack.id)..' invalid source '..index)
    end
    local tree,why=a.RotationData.IndexRotationSteps(pack.body);assert(tree,why and why.code)
    if strict then
        local spec=pack.applicability.specs and pack.applicability.specs[1] or 0
        assert(a:validateCondition(pack.body.switch,spec),pack.id..' invalid switch condition')
        for _,row in ipairs(tree.rows) do assert(a:validateCondition(row.step.conditions,spec),pack.id..' invalid condition '..row.step.id) end
    end
    return true
end
return C
