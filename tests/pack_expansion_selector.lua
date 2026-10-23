-- applicability.minExpansion/maxExpansion select packs by the client's
-- expansion (LE_EXPANSION_LEVEL_CURRENT). Build numbers are shared across
-- Blizzard products (2026-10-21/22: Era 70003, Titan Wrath 70522, Retail
-- 70529, MoP 70531), so minBuild/maxBuild cannot tell MoP from Wrath.
local F=dofile('tests/fixtures/addon.lua')
local corpus=dofile('tests/fixtures/default_corpus.lua')
local test,finish=F.suite()
local WRATH,CATA,MISTS,ERA,TBC=11,14,19,2,5

local function pack(id,scope)
    local applicability={families={'progression'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=90}
    for key,value in pairs(scope or {}) do applicability[key]=value end
    return {format='RotationMaster',schemaVersion=1,id=id,revision=1,nameKey='Test.'..id,descriptionKey='Test.'..id..'.Description',
        applicability=applicability,sources={{url='https://example.invalid/'..id,reviewedAt='2026-10-23'}},
        body={switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},cooldowns={},rotation={{id=id..'-step',type='spell',action=35395,conditions={}}}}}
end
-- A client with only the given synthetic packs; characterScope keeps
-- production registration filtering.
local function client(project,expansion,class,packs,scoped)
    local f,_,state=corpus.load(project,expansion,class or 'PALADIN',{modules=false,characterScope=scoped})
    local a=f.addon;state.level=60;local results={}
    for _,envelope in ipairs(packs) do local ok,why=a:RegisterDefaultRotation(envelope);results[envelope.id]=why or ok end
    assert(a:InitializeRotationLibrary())
    return f,a,results,state
end
local function rows(a,spec)
    local out={};local runtime=a:GetRuntimeRotations(spec or 1)
    for _,row in ipairs(a:ListDefaultRotations(spec or 1)) do
        out[row.id]=row
        assert((runtime[row.runtimeKey]~=nil)==row.eligible,row.id..': catalog and runtime eligibility differ')
    end
    return out
end
local function issues(a,envelope)
    local out={};for _,issue in ipairs(a.RotationData.ValidateEnvelope(envelope,(a:GetRotationValidationOptions())).diagnostics) do out[#out+1]=issue.code..'@'..issue.path end
    return table.concat(out,' ')
end

local MISTS_ONLY={minExpansion=4,maxExpansion=4}

test('validation: integer expansions from 0 are accepted; bad values and inverted ranges are errors',function()
    local _,a=client(MISTS,4,'PALADIN',{})
    local data=a.RotationData
    for _,scope in ipairs({MISTS_ONLY,{minExpansion=0},{maxExpansion=0},{minExpansion=2,maxExpansion=4},{minExpansion=4}}) do
        local envelope=pack('ok',scope);local result=data.ValidateEnvelope(envelope,(a:GetRotationValidationOptions()))
        assert(result.valid and result.supported and result.resolved,issues(a,envelope))
    end
    for _,case in ipairs({{{minExpansion=-1},'$.applicability.minExpansion'},{{maxExpansion=4.5},'$.applicability.maxExpansion'},
        {{minExpansion='4'},'$.applicability.minExpansion'},{{minExpansion=4,maxExpansion=2},'$.applicability.maxExpansion'}}) do
        local envelope=pack('bad',case[1]);local result=data.ValidateEnvelope(envelope,(a:GetRotationValidationOptions()))
        assert(not result.valid,issues(a,envelope));assert(issues(a,envelope):find(case[2],1,true),issues(a,envelope))
    end
    assert(issues(a,pack('inverted',{minExpansion=4,maxExpansion=3})):find('inverted-range@$.applicability.maxExpansion',1,true))
    -- The build range keeps its own minimum of 1.
    assert(not data.ValidateEnvelope(pack('build0',{minBuild=0})).valid)
end)

test('selection: a Mists pack is eligible on a Mists client and refused on Wrath and Cataclysm',function()
    local _,a,results=client(MISTS,4,'PALADIN',{pack('mists',MISTS_ONLY),pack('any')},true)
    assert(results.mists==true and results.any==true)
    local r=rows(a);assert(r.mists.eligible and r.any.eligible,tostring(r.mists.eligibilityReason))
    for _,c in ipairs({{WRATH,2},{CATA,3}}) do
        -- Cross-edition load (offline tools, the corpus): registered, listed, ineligible.
        _,a,results=client(c[1],c[2],'PALADIN',{pack('mists',MISTS_ONLY),pack('any')},false)
        r=rows(a);assert(not r.mists.eligible and r.mists.eligibilityReason=='expansion-mismatch',tostring(r.mists.eligibilityReason))
        assert(r.any.eligible,'an unscoped progression pack still selects')
    end
end)

test('registration: a character-scoped Wrath client never registers a Mists pack',function()
    local _,a,results=client(WRATH,2,'PALADIN',{pack('mists',MISTS_ONLY),pack('wrath',{maxExpansion=2}),pack('any')},true)
    assert(results.mists=='other-character' and results.wrath==true and results.any==true)
    assert(a:GetDefaultRotation('mists')==nil and a:GetDefaultRotation('wrath'))
    local r=rows(a);assert(r.wrath.eligible and r.any.eligible and r.mists==nil)
    _,a,results=client(MISTS,4,'PALADIN',{pack('mists',MISTS_ONLY),pack('wrath',{maxExpansion=2})},true)
    assert(results.mists==true and results.wrath=='other-character')
end)

test('ranges: open-ended bounds and Era expansion 0',function()
    local packs={pack('from3',{minExpansion=3}),pack('upto3',{maxExpansion=3}),pack('band',{minExpansion=2,maxExpansion=3})}
    local want={[2]={from3=false,upto3=true,band=true},[3]={from3=true,upto3=true,band=true},[4]={from3=true,upto3=false,band=false}}
    for _,c in ipairs({{WRATH,2},{CATA,3},{MISTS,4}}) do
        local _,a=client(c[1],c[2],'PALADIN',packs,false);local r=rows(a)
        for id,eligible in pairs(want[c[2]]) do assert(r[id].eligible==eligible,id..' on expansion '..c[2]) end
    end
    local era=pack('era',{minExpansion=0,maxExpansion=0});era.applicability.families={'era'};era.applicability.maxLevel=60
    local _,a,results=client(ERA,0,'PALADIN',{era},true);assert(results.era==true and rows(a).era.eligible)
    local tbc=pack('era-on-tbc',{maxExpansion=0});tbc.applicability.families={'tbc'};tbc.applicability.maxLevel=60
    _,a,results=client(TBC,1,'PALADIN',{tbc},true);assert(results['era-on-tbc']=='other-character')
end)

test('missing expansion: an unreadable client expansion registers but never selects',function()
    for _,value in ipairs({false,'4'}) do
        local f,_,state=corpus.load(MISTS,4,'PALADIN',{modules=false,characterScope=true})
        local a=f.addon;state.level=60;f.env.LE_EXPANSION_LEVEL_CURRENT=value or nil
        local ok,why=a:RegisterDefaultRotation(pack('mists',MISTS_ONLY));assert(ok and why==nil,'unprovable expansion must not filter registration')
        assert(a:RegisterDefaultRotation(pack('any')))
        assert(a:InitializeRotationLibrary())
        local r=rows(a);assert(not r.mists.eligible and r.mists.eligibilityReason=='missing-expansion',tostring(r.mists.eligibilityReason))
        assert(r.any.eligible,'packs without the selector are unaffected')
    end
end)

test('context: the public rotation context and the private reader both carry the expansion',function()
    local _,a=client(MISTS,4,'PALADIN',{})
    assert(a:GetRotationContext(1).expansion==4)
    local _,b=client(WRATH,2,'PALADIN',{})
    assert(b:GetRotationContext(1).expansion==2)
end)

finish()
