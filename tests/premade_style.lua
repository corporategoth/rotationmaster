-- Built In premade style rules that hold for every edition. A Branch whose whole condition is a NOT
-- is not allowed: test the condition itself and put the steps in the other arm ("you are in combat"
-- with the pull in onFalse, never "you are not in combat"). NOT inside AND/OR stays allowed; Stops
-- and switches are out of scope (a Stop has no false arm). Inverting is behaviour-identical,
-- including when the condition is unavailable, which the last two tests prove on the real executor.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local corpus=dofile('tests/fixtures/default_corpus.lua')
local modules=dofile('tools/builtin_modules.lua')

local function negated(c) return type(c)=='table' and c.type=='NOT' end
-- Every Branch in a step list, nested arms included: fn(step).
local function branches(list,fn)
    for _,step in ipairs(list or {}) do
        if type(step)=='table' and step.type=='branch' then fn(step);branches(step.onTrue,fn);branches(step.onFalse,fn) end
    end
end
-- Every authored block and pack (before expansion), with the module file that registered it.
local function authored()
    local f=corpus.load(5,1,'ROGUE',{modules=false});local a=f.addon;local out={blocks={},packs={}};local current
    local registerBlock,registerRotation=a.RegisterDefaultBlock,a.RegisterDefaultRotation
    a.RegisterDefaultBlock=function(self,b) out.blocks[#out.blocks+1]={def=a.RotationData.CopyData(b),path=current};return registerBlock(self,b) end
    a.RegisterDefaultRotation=function(self,p) out.packs[#out.packs+1]={def=a.RotationData.CopyData(p),path=current};return registerRotation(self,p) end
    for _,path in ipairs(modules.paths()) do current=path;f.load(path) end
    assert(#out.blocks>0 and #out.packs>0)
    return out,f
end

test('no Built In Branch has NOT as its whole condition (every edition, blocks, overrides and packs)',function()
    local defs=authored();local offences={}
    local function scan(owner,path,list)
        branches(list,function(step)
            if negated(step.conditions) then offences[#offences+1]=path..': '..owner..'/'..tostring(step.id) end
        end)
    end
    for _,row in ipairs(defs.blocks) do local b=row.def
        scan(b.id,row.path,b.steps)
        for _,override in ipairs(b.overrides or {}) do scan(b.id,row.path,override.steps) end
    end
    for _,row in ipairs(defs.packs) do local p=row.def;scan(p.id,row.path,p.body.rotation);scan(p.id,row.path,p.body.cooldowns) end
    assert(#offences==0,'Branch condition is a NOT (drop the outer NOT and swap onTrue/onFalse): '..table.concat(offences,', '))
end)

test('no composed Built In expands to a Branch whose condition is a NOT',function()
    local f,packs=corpus.load(5,1,'ROGUE');local bad={}
    for _,p in ipairs(packs) do
        branches(p.body.rotation,function(step) if negated(step.conditions) then bad[#bad+1]=p.id..'/'..step.id end end)
        branches(p.body.cooldowns,function(step) if negated(step.conditions) then bad[#bad+1]=p.id..'/'..step.id end end)
    end
    assert(#bad==0,table.concat(bad,', '))
end)

-- The negated form of a Branch: NOT(its condition, the same table) with the arms swapped back.
local function negatedCopy(a,body,id)
    local copy=a.RotationData.CopyData(body);local original,target
    branches(body.rotation,function(step) if step.id==id then original=step end end)
    branches(copy.rotation,function(step) if step.id==id then target=step end end)
    assert(original and target,'no branch '..id)
    target.conditions={type='NOT',value=original.conditions};target.onTrue,target.onFalse=target.onFalse,target.onTrue
    return copy,original.conditions
end
-- Leaves of a condition tree (identity), so a forced result reaches exactly this Branch.
local function leaves(c,out,seen)
    out,seen=out or {},seen or {}
    if c.type=='AND' or c.type=='OR' then for _,child in ipairs(c.value) do leaves(child,out,seen) end
    elseif c.type=='NOT' then leaves(c.value,out,seen) elseif not seen[c] then seen[c]=true;out[#out+1]=c end
    return out
end
-- forced[leaf] is what a leaf condition callback returns: true, false or 'unavailable'.
local forced={}
local function force(leaf) local v=forced[leaf];if v=='unavailable' then return nil,'forced-unavailable' end;return v end
-- Sets the leaves so the whole condition evaluates to status (match, no-match or unavailable),
-- searching leaf assignments with the real evaluator (a NOT inside AND/OR flips a leaf).
local function setter(a,condition)
    local list=leaves(condition)
    return function(status)
        for k in pairs(forced) do forced[k]=nil end
        if status=='unavailable' then for _,leaf in ipairs(list) do forced[leaf]='unavailable' end
        else
            assert(#list<=16,'too many leaves')
            for bits=0,2^#list-1 do
                local n=bits;for _,leaf in ipairs(list) do forced[leaf]=n%2==1;n=math.floor(n/2) end
                if a:evaluateConditionResult(condition).status==status then break end
            end
        end
        assert(a:evaluateConditionResult(condition).status==status,'cannot force '..status)
    end
end

-- Every shipped Branch, on the real sequence executor and condition evaluator:
-- the walk (each step offered, then the outcome) is the same for the authored form and its negated
-- form, when the condition is true, false and unavailable.
test('negating any shipped Branch and swapping its arms gives the same walk when true, false or unavailable',function()
    local f,packs=corpus.load(5,1,'ROGUE');local a=f.addon;f.load('Core/rotation_sequence.lua');local set
    for _,definition in pairs(a.conditionDefinitions) do
        definition.evaluate=function(value) if forced[value]~=nil then return force(value) end;return false end
    end
    local function walk(body)
        local offered={};local result=a:EvaluateRotationSequence(body,function(c,ctx) return a:evaluateConditionResult(c,ctx) end,
            function(step) offered[#offered+1]=step.id end)
        return table.concat(offered,' ')..' => '..result.status..(result.suppressAttack and ' suppress' or '')
    end
    local count,decided=0,0
    local function find(body,id) local found;branches(body.rotation,function(step) if step.id==id then found=step end end);return found end
    for _,p in ipairs(packs) do
        local ids={};branches(p.body.rotation,function(step) ids[#ids+1]=step.id end)
        for _,id in ipairs(ids) do
            local before,condition=negatedCopy(a,p.body,id);set=setter(a,condition);count=count+1
            -- The whole premade (other conditions false), then the Branch alone, so a Stop ahead of
            -- it cannot hide its arms.
            local alone,aloneBefore={rotation={find(p.body,id)}},{rotation={find(before,id)}}
            local outcomes={}
            for _,m in ipairs({'match','no-match','unavailable'}) do
                set(m)
                for _,pair in ipairs({{p.body,before},{alone,aloneBefore}}) do
                    local x,y=walk(pair[1]),walk(pair[2])
                    assert(x==y,p.id..'/'..id..' '..m..': '..x..' | negated: '..y)
                end
                outcomes[m]=walk(alone)
            end
            assert(outcomes.unavailable==' => unavailable suppress',p.id..'/'..id..' unavailable did not pause: '..outcomes.unavailable)
            if outcomes.match~=outcomes['no-match'] then decided=decided+1 end
        end
    end
    assert(decided==count,(count-decided)..' of '..count..' branches walk the same either way')
    assert(count>500,'only '..count..' branches walked')
end)

-- A few inverted TBC Branches on the full physical world model (real predicates, readiness and
-- the spells the scenario suites train): the advice is the same spell, or the same stop, before
-- and after, and the two arms really do advise differently.
test('inverted TBC Branches give the same advice as their negated form (true, false, unavailable)',function()
    local M=dofile('tests/fixtures/tbc_physical_premades.lua')
    local cases={
        {'WARRIOR','rm.tbc.warrior.dps.wowsims','warrior-dps-pull',function(s) M.know(s,6603,78,6673,100,772,6343,1715);s.range[6603]=true end},
        {'ROGUE','rm.tbc.rogue.dps.wowsims','rogue-behind',function(s) M.know(s,6603,1752,2098,53,1329);s.range[6603]=true;s.usable[14251]=false end},
        {'HUNTER','rm.tbc.hunter.ranged.wowsims','hunter-melee',function(s) M.know(s,75,6603,2973,1978,3044,2974);s.range[6603]=false;s.autorepeat=true;s.debuffs={{id=1130,source='party1'}} end},
        {'HUNTER','rm.tbc.hunter.ranged.wowsims','hunter-pull',function(s) M.know(s,75,6603,2973,1978,3044);s.range[6603]=false;s.autorepeat=true;s.debuffs={{id=1130,source='party1'}} end},
    }
    for _,case in ipairs(cases) do
        local f,s=M.fixture(case[1],{level=60});case[4](s);local a=f.addon
        local body=M.body(a,case[2]);local id
        branches(body.rotation,function(step) if step.id==case[3] then id=step.id end end)
        assert(id,case[2]..' has no branch '..case[3]..'; branch ids: '..(function() local t={};branches(body.rotation,function(x) t[#t+1]=x.id end);return table.concat(t,' ') end)())
        local before,condition=negatedCopy(a,body,id);local set=setter(a,condition);local wrapped={}
        for _,leaf in ipairs(leaves(condition)) do
            local definition=a.conditionDefinitions[leaf.type]
            if not wrapped[definition] then
                wrapped[definition]=true;local evaluate=definition.evaluate
                definition.evaluate=function(value,...) if forced[value]~=nil then return force(value) end;return evaluate(value,...) end
            end
        end
        local function advice(tree)
            f.sync();local ready=a:NewActionReadiness(100);local selected
            local result=a:EvaluateRotationSequence(tree,function(c,ctx) return a:evaluateConditionResult(c,ctx) end,function(step)
                if a:evaluateCondition(step.conditions) then
                    for _,spell in ipairs(a:GetSpellIds(step)) do if s.mapped[spell]~=false and ready(step.type,spell) then selected=spell;return false end end
                end
            end)
            return tostring(selected)..' '..result.status..(result.suppressAttack and ' suppress' or '')
        end
        local seen={}
        for _,m in ipairs({'match','no-match','unavailable'}) do
            set(m);local x,y=advice(body),advice(before)
            assert(x==y,case[2]..'/'..id..' '..m..': '..x..' | negated: '..y);seen[m]=x
        end
        assert(seen.match~=seen['no-match'],case[2]..'/'..id..' both arms advise '..seen.match)
        assert(seen.unavailable=='nil unavailable suppress',case[2]..'/'..id..' unavailable: '..seen.unavailable)
    end
end)
-- Efficient rotations: never two consecutive Stops (at the same level) where one Stop with an OR of
-- their conditions does the same job, and never two consecutive Branches with the same arms (one
-- Branch with an OR). Two Stops that differ in suppress_attack, or with only one disabled, cannot be
-- one Stop and stay allowed. Checked on every authored block (and override) and pack, and on every
-- composed pack, where the two Stops may come from different blocks.
local function canonical(v,noid)
    local t=type(v)
    if t=='string' then return string.format('%q',v) elseif t=='number' then return string.format('%.17g',v) elseif t~='table' then return tostring(v) end
    local keys={};for k in pairs(v) do if not (noid and k=='id') then keys[#keys+1]=k end end
    table.sort(keys,function(x,y) if type(x)==type(y) then return x<y end;return type(x)=='number' end)
    local out={};for _,k in ipairs(keys) do out[#out+1]=canonical(k)..'='..canonical(v[k],noid) end
    return '{'..table.concat(out,',')..'}'
end
local function isStop(step) return type(step)=='table' and step.type=='none' end
local function mergeable(a,b)
    return isStop(a) and isStop(b) and (a.suppress_attack==true)==(b.suppress_attack==true) and (a.disabled==true)==(b.disabled==true)
end
local function sameArms(a,b)
    return type(a)=='table' and type(b)=='table' and a.type=='branch' and b.type=='branch'
        and canonical(a.onTrue or {},true)==canonical(b.onTrue or {},true) and canonical(a.onFalse or {},true)==canonical(b.onFalse or {},true)
end
local function redundancies(owner,list,out)
    for i,step in ipairs(list or {}) do
        local nxt=list[i+1]
        if mergeable(step,nxt) then out[#out+1]=owner..': Stops '..tostring(step.id)..' + '..tostring(nxt.id) end
        if sameArms(step,nxt) then out[#out+1]=owner..': Branches '..tostring(step.id)..' + '..tostring(nxt.id)..' (same arms)' end
        if type(step)=='table' and step.type=='branch' then redundancies(owner,step.onTrue,out);redundancies(owner,step.onFalse,out) end
    end
    return out
end

test('no authored Built In block, override or pack has two consecutive mergeable Stops or same-arm Branches',function()
    local defs=authored();local out={}
    for _,row in ipairs(defs.blocks) do local b=row.def
        redundancies(row.path..': '..b.id,b.steps,out)
        for i,override in ipairs(b.overrides or {}) do redundancies(row.path..': '..b.id..' override '..i,override.steps,out) end
    end
    for _,row in ipairs(defs.packs) do local p=row.def
        redundancies(row.path..': '..p.id..' rotation',p.body.rotation,out);redundancies(row.path..': '..p.id..' cooldowns',p.body.cooldowns,out)
    end
    assert(#out==0,'merge into one step with an OR condition: '..table.concat(out,'; '))
end)

test('no composed Built In expands to two consecutive mergeable Stops or same-arm Branches',function()
    local _,packs=corpus.load(5,1,'ROGUE');local out={}
    for _,p in ipairs(packs) do redundancies(p.id..' rotation',p.body.rotation,out);redundancies(p.id..' cooldowns',p.body.cooldowns,out) end
    assert(#out==0,'merge into one step with an OR condition (a shared block can take the extra condition, or a block variant): '..table.concat(out,'; '))
end)

-- A fixture of the two rules, so the checks above cannot pass vacuously.
test('the efficiency check names consecutive Stops and same-arm Branches, and allows what cannot merge',function()
    local cast,chan={type='CASTING',unit='player'},{type='CHANNELING',unit='player'}
    local list={{id='a',type='none',suppress_attack=true,conditions=cast},{id='b',type='none',suppress_attack=true,conditions=chan},
        {id='c',type='none',suppress_attack=false,conditions=cast},
        {id='x',type='branch',conditions=cast,onTrue={{id='x1',type='spell',action=1}},onFalse={}},
        {id='y',type='branch',conditions=chan,onTrue={{id='y1',type='spell',action=1}},onFalse={}}}
    local out=redundancies('fixture',list,{})
    assert(#out==2 and out[1]=='fixture: Stops a + b' and out[2]=='fixture: Branches x + y (same arms)',table.concat(out,'; '))
end)

-- OR evaluates its children in order and stops at the first that matches or is unavailable
-- (Core/conditions.lua evaluate() and its condition plans alike). So one Stop on OR(c1..cn) ends the
-- walk exactly when the consecutive Stops c1..cn would, with the same status: the first child that
-- is not a no-match decides (match: stopped; unavailable: unavailable and Attack suppressed). Proved
-- here for every shipped Stop whose condition is an OR, for every combination of its children being
-- true, false or unavailable, on the real sequence executor, the ordinary evaluator and the
-- condition plans the lean engine runs.
test('every shipped OR Stop walks exactly like consecutive Stops on its children (true, false, unavailable)',function()
    local f,packs=corpus.load(5,1,'ROGUE');local a=f.addon;f.load('Core/rotation_sequence.lua')
    local compile,evaluatePlan=a:ConsumeConditionPlans()
    for _,definition in pairs(a.conditionDefinitions) do
        definition.evaluate=function(value) if forced[value]~=nil then return force(value) end;return false end
    end
    local function walk(list)
        local result=a:EvaluateRotationSequence({rotation=list},function(c,ctx) return a:evaluateConditionResult(c,ctx) end,function() end)
        return result.status..(result.suppressAttack and ' suppress' or '')
    end
    -- Leaves of one child forced so the child evaluates to status; false when no assignment does.
    local function forceChild(child,status)
        local list=leaves(child)
        if status=='unavailable' then for _,leaf in ipairs(list) do forced[leaf]='unavailable' end;return a:evaluateConditionResult(child).status==status end
        if #list>12 then return false end
        for bits=0,2^#list-1 do
            local n=bits;for _,leaf in ipairs(list) do forced[leaf]=n%2==1;n=math.floor(n/2) end
            if a:evaluateConditionResult(child).status==status then return true end
        end
        return false
    end
    local stops,combos=0,0
    local function visit(list)
        for _,step in ipairs(list or {}) do
            if step.type=='branch' then visit(step.onTrue);visit(step.onFalse)
            elseif isStop(step) and type(step.conditions)=='table' and step.conditions.type=='OR' and not step.disabled then
                local children=step.conditions.value;stops=stops+1
                local split={};for i,child in ipairs(children) do split[i]={id=step.id..'-split-'..i,type='none',suppress_attack=step.suppress_attack,conditions=child} end
                local merged={step};local plan=compile(step.conditions);local plans={};for i,child in ipairs(children) do plans[i]=compile(child) end
                local statuses={'match','no-match','unavailable'}
                for code=0,3^#children-1 do
                    for k in pairs(forced) do forced[k]=nil end
                    local n,reachable,wanted=code,true,{}
                    for i,child in ipairs(children) do wanted[i]=statuses[n%3+1];if not forceChild(child,wanted[i]) then reachable=false end;n=math.floor(n/3) end
                    -- A leaf shared between children can undo an earlier child's forcing.
                    for i,child in ipairs(children) do if a:evaluateConditionResult(child).status~=wanted[i] then reachable=false end end
                    if reachable then
                        combos=combos+1
                        local x,y=walk(merged),walk(split)
                        assert(x==y,step.id..' code '..code..': merged '..x..' | split '..y)
                        local sequential='no-match'
                        for i in ipairs(children) do local s=evaluatePlan(plans[i],{},0,step.id);if s~='no-match' then sequential=s;break end end
                        assert(evaluatePlan(plan,{},0,step.id)==sequential,step.id..' code '..code..': plan differs')
                    end
                end
            end
        end
    end
    for _,p in ipairs(packs) do visit(p.body.rotation) end
    assert(stops>200 and combos>2000,stops..' OR Stops, '..combos..' combinations')
end)

-- One enabled premade per spec (the user, 2026-10-24): a same-spec alternative ships disabled and the
-- recommended premade (highest priority) stays enabled. Judged by the engine's own switch-overlap
-- analysis (Core/rotation_selection.lua): within one load scope (families, expansion, class,
-- rulesets), an enabled Built In whose switch another enabled one matches identically or subsumes at
-- an equal or higher priority could only ever be chosen by priority, so it is an alternative and must
-- ship disabled. Deliberate layering passes by construction: a catch-all under a spec premade subsumes
-- it at a LOWER priority; Season of Discovery packs (rulesets season:2) and vanilla packs are separate
-- load scopes; Retail initial-spec premades name another specialization.
local function overlapRows()
    local f,packs=corpus.load(5,1,'ROGUE');local a=f.addon;f.load('Core/rotation_selection.lua')
    local scopes={}
    for _,p in ipairs(packs) do
        local ap=p.applicability
        local key=table.concat(ap.families or {},',')..'@'..tostring(ap.minExpansion)..'-'..tostring(ap.maxExpansion)
            ..'/'..tostring(ap.class)..'/'..table.concat(ap.rulesets or {},',')
        scopes[key]=scopes[key] or {}
        table.insert(scopes[key],{id=p.id,priority=p.body.priority or 0,disabled=p.body.disabled==true,region=a:GetSwitchRegion(p.body.switch,ap)})
    end
    return a,scopes
end
local function alternativeOffences(a,scopes)
    local shadowed,outranked={},{}
    for key,list in pairs(scopes) do
        for _,q in ipairs(list) do for _,p in ipairs(list) do
            if p~=q and not p.disabled then
                local kind=a:CompareSwitchRegions(p.region,q.region)
                if not q.disabled and p.priority>=q.priority and (kind=='identical' or kind=='subsumes') then
                    shadowed[#shadowed+1]=key..': '..q.id..' ('..q.priority..') under '..p.id..' ('..p.priority..', '..kind..')'
                elseif q.disabled and kind=='identical' and q.priority>p.priority then
                    outranked[#outranked+1]=key..': disabled '..q.id..' ('..q.priority..') outranks enabled '..p.id..' ('..p.priority..')'
                end
            end
        end end
    end
    table.sort(shadowed);table.sort(outranked)
    return shadowed,outranked
end

test('one enabled premade per switch in every edition, class and spec: alternatives ship disabled, the recommended one does not',function()
    local a,scopes=overlapRows()
    local shadowed,outranked=alternativeOffences(a,scopes)
    assert(#shadowed==0,'enabled same-spec alternatives (ship them disabled=true, or give them their own switch): '..table.concat(shadowed,'; '))
    assert(#outranked==0,'a disabled premade outranks the enabled one with the same switch: '..table.concat(outranked,'; '))
    local count,off=0,0;for _,list in pairs(scopes) do for _,row in ipairs(list) do count=count+1;if row.disabled then off=off+1 end end end
    assert(count>300 and off>130,count..' Built Ins, '..off..' disabled')
end)

-- The rule on shipped data, so the check above cannot pass vacuously: an enabled lower duplicate and a
-- disabled higher duplicate are named; a catch-all under a spec premade and a SoD pack over a vanilla
-- pack with the same switch are not.
test('the alternative check names enabled duplicates and disabled recommendations, and allows the documented layering',function()
    local a,scopes=overlapRows()
    local function find(id) for key,list in pairs(scopes) do for _,row in ipairs(list) do if row.id==id then return key,list,row end end end end
    local key,list,feral=find('rm.tbc.druid.feral.icyveins')
    local _,_,catchall=find('rm.tbc.druid.balance');local _,_,alternative=find('rm.tbc.druid.feral.wowhead')
    assert(not feral.disabled and not catchall.disabled and alternative.disabled and catchall.priority<feral.priority,'TBC Druid layering changed')
    assert(a:CompareSwitchRegions(catchall.region,feral.region)=='subsumes','the Balance catch-all no longer subsumes Feral')
    local only={[key]=list}
    local s0,o0=alternativeOffences(a,only);assert(#s0==0 and #o0==0,table.concat(s0,'; ')..table.concat(o0,'; '))
    alternative.disabled=false
    local s1,o1=alternativeOffences(a,only)
    assert(#s1==1 and #o1==0 and s1[1]:find('rm.tbc.druid.feral.wowhead (20) under rm.tbc.druid.feral.icyveins (30, identical)',1,true),table.concat(s1,'; '))
    feral.disabled=true
    local s2,o2=alternativeOffences(a,only)
    assert(#s2==0 and #o2==1 and o2[1]:find('disabled rm.tbc.druid.feral.icyveins (30) outranks enabled rm.tbc.druid.feral.wowhead (20)',1,true),table.concat(o2,'; '))
    feral.disabled,alternative.disabled=false,true
    -- SoD over vanilla: both Balance premades are catch-alls, in separate load scopes.
    local sodKey,sodList,sod=find('rm.sod.druid.balance');local eraKey,eraList,era=find('rm.era.druid.balance')
    assert(sodKey~=eraKey and not sod.disabled and not era.disabled and a:CompareSwitchRegions(sod.region,era.region)=='identical','Druid Balance layering changed')
    local s3,o3=alternativeOffences(a,{[sodKey]=sodList,[eraKey]=eraList});assert(#s3==0 and #o3==0,table.concat(s3,'; ')..table.concat(o3,'; '))
end)
finish()
