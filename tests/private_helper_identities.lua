-- The private helpers a Built In condition shares (builtin:<module>:<name>) are what saved custom copies, exported bundles
-- and requirement hashes bind to (Core/function_data.lua: a bundle names each Built In dependency by id and source hash).
-- Their source identity therefore changes only on purpose: edit a helper, run this suite, read the failure, and record the new
-- hash here in the same commit, knowing that a bundle exported with the old hash will report the requirement as changed.
--
-- This replaces the identity assertions that used to sit inside byte-exact "strict inverse" tests of whole modules; those proofs
-- are retired, the property they protected is kept.
local T=dofile('tests/fixtures/toc_addon.lua')
local passed,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end

local identities={
    ['Conditions/combat.lua']={color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'},
    ['Conditions/character.lua']={character_class='f9f4e4b5',color='3f9fe631',helpers='2e9a81e7',unit_class_num='33645816'},
    ['Conditions/misc.lua']={color='89a5436e',helpers='3ab28a24'},
    ['Conditions/stats.lua']={color='89107d36',helpers='c19dbbac'},
    ['Conditions/spatial.lua']={RangeCheck='272f05e0',booleanRead='3b3ceeb2',finite='9e1e3ece',color='158ebd8f',helpers='9485f785',rcf='a7ab75e4',protectedRead='cc49d134'},
    ['Conditions/spell.lua']={color='906341b8',helpers='769a506e'},
    ['Conditions/petspell.lua']={color='fedaa3e7',helpers='60920b9d'},
    ['Conditions/anyspell.lua']={color='f35f4765',helpers='47f6d2db',SpellData='bd968be4'},
    ['Conditions/buffs.lua']={color='89c33f24',helpers='e55d7b5a'},
    ['Conditions/debuffs.lua']={color='cd0b6691',helpers='785d08c7'},
    ['Conditions/ext_stats.lua']={color='bcd5d295',ecs_state='f87297b5',helpers='8c6f9acb'},
    -- Six of the talent picker's helpers changed on purpose: tree names instead of numbers (c584ed30), the icon-left two-row block
    -- (126b58e3), the drawn tree (97274eb1).
    ['Conditions/talent.lua']={dropdown='fc359881',gridWidget='e72d8427',group='d6f4e415',icon='96cba83c',info='06ddaa40',integer='e1bd3b0e',legacySlot='b8bfb514',platform='7a51cfaa',text='6cd18802',treeExists='85703f5a',treeName='7472cbbc',treePicker='6ac3f081',treeShape='f0ba2bf9',treeWidget='0865edd9'},
    ['Conditions/weapon.lua']={enchantObservation='5abf63f3',numericObservation='02dee6a9',swingSpeed='cf9027ac',color='63742be5',helpers='e831a1db'},
    ['Conditions/totem.lua']={observe='e59e23eb',remaining='b96f5341',element='5fbfedcc',amount='3bd67a6b',specific='fdeca8ba',findSpecific='f753db9d',platform='c9ee8d33',color='b1a3d66a',helpers='f15cbb60'},
    -- calculateOld changed once on purpose: a legacy health trend returns zero, not NaN (dcd35b9f).
    ['Functions/trends.lua']={calculate='26e53807',calculateOld='04e973c3'},
    -- Public helpers whose documentation was corrected on purpose (3c7a4136: policies, record fields, parents).
    ['Platform/threat.lua']={Platform_GetUnitThreatObservation='55eecf7e'},
    ['Platform/health_forecast.lua']={Platform_GetHealthForecastIdentityObservation='bd7603d7'},
}

-- Helpers exist per client (the totem conditions are Classic ones), so every helper is looked up on each of these clients.
local clients={{project=1,class='MONK'},{project=5,expansion=1,class='SHAMAN',level=70}}
test('every private helper keeps its recorded source hash and resolves to the shipped getter',function()
    local addons={};for _,o in ipairs(clients)do addons[#addons+1]=T.new(o).addon end
    local checked,problems=0,{}
    for module,entries in pairs(identities)do
        for name,hash in pairs(entries)do
            local id='builtin:'..module..':'..name
            local a;for _,candidate in ipairs(addons)do if candidate.builtinFunctions[id]then a=candidate;break end end
            if not a then problems[#problems+1]=id..' is no longer a Built In helper on any modelled client'
            else
                local current=a:FunctionSourceHash(a.builtinFunctions[id].source)
                if current~=hash then problems[#problems+1]=id..' source identity changed: recorded '..hash..', now '..current end
                local getter=a.builtinSourceModules[module]
                if not getter or not rawequal(a:ResolveFunctionBinding(id),getter(name)) then problems[#problems+1]=id..' no longer resolves to the shipped value' end
                checked=checked+1
            end
        end
    end
    table.sort(problems);assert(#problems==0,table.concat(problems,'; '))
    assert(checked==64,'recorded helper count changed: '..checked)
end)

print(passed..' passed, '..failed..' failed')
if failed>0 then os.exit(1) end
