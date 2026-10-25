-- Specialization and level can change mid-session (a level-up, a respec), so a shipped premade's
-- applicability holds only what cannot: edition, class, expansion, build and ruleset. Level is a
-- visible switch condition and specialization the premade's own body.specs, both re-read live, so
-- the right premade is chosen without a reload; another specialization's premade stays listed but
-- unavailable, as applicability.specs did; an imported or older pack that still declares
-- specs/minLevel/maxLevel is honoured as before.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()

local LOAD_TIME={families=true,actionContext=true,class=true,universal=true,minExpansion=true,maxExpansion=true,minBuild=true,maxBuild=true,rulesets=true}
test('every shipped premade declares only load-time facts in its applicability',function()
    local corpus=dofile('tests/fixtures/default_corpus.lua');local _,packs=corpus.load(5,1,'ROGUE');local bad={}
    for _,p in ipairs(packs) do for key in pairs(p.applicability) do if not LOAD_TIME[key] then bad[#bad+1]=p.id..'.'..key end end end
    assert(#packs>300 and #bad==0,'applicability may change mid-session: '..table.concat(bad,', '))
end)

test('Retail: the Brewmaster premade is filed under Brewmaster only; a level-up and respecs switch premades live',function()
    local M=dofile('tests/fixtures/retail_premade_model_a.lua')
    local f,s=M.new('monk','MONK',1450);local a=f.addon
    s.powerType=3;s.energy=50;s.points=2;s.setLevel(4)
    local P='rm.retail.monk.'
    local function row(spec,id) for _,r in ipairs(a:ListDefaultRotations(spec)) do if r.id==id then return r end end end
    local function runtime(spec,id) return a:GetRuntimeRotations(spec)[row(spec,id).runtimeKey]~=nil end
    -- By its body.specs: listed in every Monk slot, eligible and at runtime only under Brewmaster.
    for _,spec in ipairs({268,269,270,1450}) do
        local r=assert(row(spec,P..'brewmaster'),'not listed under '..spec)
        assert(r.eligible==(spec==268) and runtime(spec,P..'brewmaster')==(spec==268),'Brewmaster premade in slot '..spec..': '..tostring(r.eligibilityReason))
        if spec~=268 then assert(r.eligibilityReason=='specialization-mismatch',r.eligibilityReason) end
    end
    assert(M.selected(a)==P..'initial','level 4: '..tostring(M.selected(a)))
    -- Level 10, no specialization chosen yet: still the initial spec and its premade.
    s.setLevel(10);assert(M.selected(a)==P..'initial','level 10 before choosing: '..tostring(M.selected(a)))
    -- Choose Brewmaster, respec to Windwalker, then back, in one session (no library reload).
    s.respec(268);assert(M.selected(a)==P..'brewmaster','Brewmaster: '..tostring(M.selected(a)))
    s.respec(269);assert(M.selected(a)==P..'windwalker','Windwalker: '..tostring(M.selected(a)))
    s.respec(268);assert(M.selected(a)==P..'brewmaster','back to Brewmaster: '..tostring(M.selected(a)))
    -- Its specializations (body.specs) read the live specialization: Brewmaster's do not hold in Windwalker.
    s.respec(269);local body=row(268,P..'brewmaster').envelope.body
    assert(not a:RotationSpecsApply(body.specs,269),'Brewmaster premade in Windwalker')
end)

test('a pack that still declares specs, minLevel or maxLevel keeps those gates (imported or older packs)',function()
    local M=dofile('tests/fixtures/retail_premade_model_a.lua')
    local f,s=M.new('monk','MONK',269);local a=f.addon;s.setLevel(15)
    local envelope=a.RotationData.CopyData(assert(a:GetDefaultRotation('rm.retail.monk.windwalker')).envelope)
    envelope.id='test.older.windwalker';envelope.applicability.specs={269};envelope.applicability.minLevel=20;envelope.applicability.maxLevel=90
    envelope.body.switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1}
    assert(a:RegisterDefaultRotation(envelope));assert(a:InitializeRotationLibrary())
    local function row(spec) for _,r in ipairs(a:ListDefaultRotations(spec)) do if r.id=='test.older.windwalker' then return r end end end
    assert(not row(269).eligible and row(269).eligibilityReason=='level-mismatch',tostring(row(269).eligibilityReason))
    s.setLevel(20);assert(row(269).eligible,'level 20 in Windwalker: '..tostring(row(269).eligibilityReason))
    assert(row(268).eligibilityReason=='specialization-mismatch',tostring(row(268).eligibilityReason))
end)

test('Mists: below 10 the catch-all; at 10 the chosen specialization; a respec switches without a reload',function()
    local M=dofile('tests/fixtures/mop_premade_model_a.lua')
    local f,s=M.new('druid');local a=f.addon;s.setLevel(5);s.spec=nil
    assert(M.selected(a)=='rm.mop.druid.unspecialized','level 5: '..tostring(M.selected(a)))
    s.setLevel(10);assert(M.selected(a)=='rm.mop.druid.unspecialized','level 10 before choosing: '..tostring(M.selected(a)))
    s.specID(103);assert(M.selected(a)=='rm.mop.druid.feral','Feral: '..tostring(M.selected(a)))
    s.specID(104);assert(M.selected(a)=='rm.mop.druid.guardian','Guardian: '..tostring(M.selected(a)))
    s.specID(102);assert(M.selected(a)=='rm.mop.druid.balance','Balance: '..tostring(M.selected(a)))
end)

test('TBC: the tank premade takes over at level 10 in Defensive Stance, live, through the real publisher',function()
    local M=dofile('tests/fixtures/tbc_physical_premades.lua')
    local f,s=M.fixture('WARRIOR',{level=9});M.know(s,6603,78,6673,100,772,6343,1715,71);s.range[6603]=true
    local poll,selected=M.publisher(f,s)
    s.forms=3;s.shift(71);poll();assert(selected()=='rm.tbc.warrior.dps.wowsims','level 9 in Defensive Stance: '..tostring(selected()))
    s.level=10;poll();assert(selected()=='rm.tbc.warrior.protection.wowhead','level 10 in Defensive Stance: '..tostring(selected()))
    s.shift(2457);poll();assert(selected()=='rm.tbc.warrior.dps.wowsims','Battle Stance: '..tostring(selected()))
end)

test('Era: a level-up and a respec move a grouped Priest between the damage and healer premades live',function()
    local M=dofile('tests/fixtures/era_premade_model_a.lua')
    local f,s=M.new('priest');local a=f.addon;s.setLevel(5);s.group=true;s.setTalents({0,0,0})
    assert(M.selected(a)=='rm.era.priest.dps','level 5 grouped: '..tostring(M.selected(a)))
    s.setLevel(12);s.setTalents({0,3,0});assert(M.selected(a)=='rm.era.priest.healer','level 12, Holy: '..tostring(M.selected(a)))
    s.setTalents({0,0,3});assert(M.selected(a)=='rm.era.priest.dps','respec to Shadow: '..tostring(M.selected(a)))
    s.setTalents({3,0,0});assert(M.selected(a)=='rm.era.priest.healer','respec to Discipline: '..tostring(M.selected(a)))
end)
finish()
