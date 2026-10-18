local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local a={};for _,path in ipairs({'Data/plain.lua','Data/rotation_tree.lua'}) do assert(loadfile(path))('rotationmaster',a) end
local file=io.open('Core/rotation_sequence.lua','r');if file then file:close();assert(loadfile('Core/rotation_sequence.lua'))('rotationmaster',a) end
local function action(id) return {id=id,type='spell',action=403} end
local function branch(id,mode,yes,no) return {id=id,type='branch',mode=mode,conditions={type=id},onTrue=yes or {},onFalse=no or {}} end
local function body(steps,optional) return {rotation=steps,cooldowns=optional or {}} end
local function run(b,gates,maximum)
    local seen,contexts={},{}
    local result=a:EvaluateRotationSequence(b,function(condition,context)
        contexts[#contexts+1]={condition=condition,context=context}
        return {status=gates and gates[condition and condition.type] or 'unavailable'}
    end,function(step,ordinal,path)
        seen[#seen+1]={id=step.id,ordinal=ordinal,path=path}
        return not maximum or #seen<maximum
    end)
    return result,seen,contexts
end
test('evaluated arms rejoin following priorities in all-arms preorder without visiting unchosen actions',function()
    local b=body({branch('b',nil,{action('t1'),action('t2')},{action('f')}),action('tail')})
    local r,seen,contexts=run(b,{b='match'})
    assert(r.status=='complete' and not r.suppressAttack and r.fallbackOrdinal==6)
    assert(#seen==3 and seen[1].id=='t1' and seen[1].ordinal==2 and seen[2].id=='t2' and seen[3].id=='tail' and seen[3].ordinal==5)
    assert(contexts[1].context.stepId=='b' and table.concat(contexts[1].context.stepPath,'/')=='rotation/1')
    r,seen=run(b,{b='no-match'});assert(#seen==2 and seen[1].id=='f' and seen[1].ordinal==4 and seen[2].id=='tail')
end)
test('forced branches skip their guard evaluator and inherit chosen ancestry',function()
    local b=body({branch('outer','true',{branch('inner','false',{action('wrong')},{action('right')})},{action('excluded')})})
    local seen={}
    local r=a:EvaluateRotationSequence(b,function() error('forced guard was evaluated') end,function(step) seen[#seen+1]=step.id end)
    assert(r.status=='complete' and #seen==1 and seen[1]=='right')
end)
test('Stop in a nested arm ends the entire sequence and preserves explicit Attack policy',function()
    local stop={id='stop',type='none',conditions={type='stop'}}
    local b=body({branch('b',nil,{action('before'),branch('n','true',{stop,action('excluded')})},{action('false')}),action('tail')})
    local r,seen=run(b,{b='match',stop='match'})
    assert(r.status=='stopped' and not r.suppressAttack and #seen==1 and seen[1].id=='before')
    stop.suppress_attack=true;r=run(b,{b='match',stop='match'});assert(r.suppressAttack)
    r,seen=run(b,{b='match',stop='no-match'});assert(r.status=='complete' and #seen==3 and seen[2].id=='excluded' and seen[3].id=='tail')
end)
test('unavailable guards never select False or fall through to later actions or Attack',function()
    local b=body({branch('b',nil,{action('yes')},{action('no')}),action('tail')},{action('optional')})
    for _,status in ipairs({'unavailable','unexpected'}) do
        local r,seen=run(b,{b=status});assert(r.status=='unavailable' and r.suppressAttack and #seen==0)
    end
    local r=a:EvaluateRotationSequence(b,function() return nil end,function() error('unknown guard fell through') end)
    assert(r.status=='unavailable' and r.suppressAttack)
    b.rotation={branch('b','true',{{id='stop',type='none',conditions={type='stop'}}}),action('tail')}
    r,seen=run(b,{stop='unavailable'});assert(r.status=='unavailable' and r.suppressAttack and #seen==0)
end)
test('preview selection stops traversal before later guards and optional actions are not visited',function()
    local b=body({branch('b','true',{action('first'),branch('later',nil,{action('unneeded')})}),action('tail')},{action('upkeep')})
    local r,seen,contexts=run(b,{},1)
    assert(r.status=='selected' and #seen==1 and seen[1].id=='first' and #contexts==0)
    b.rotation[1].onTrue[2].mode='true';r,seen=run(b,{},3)
    assert(r.status=='selected' and #seen==3 and seen[3].id=='tail')
end)
test('flat legacy bodies retain ordinal positions and disabled Stops never evaluate',function()
    local stop={id='stop',type='none',disabled=true,conditions={type='stop'}}
    local disabled=action('disabled');disabled.disabled=true
    local b=body({disabled,stop,{type='spell',action=403}})
    local r,seen,contexts=run(b)
    assert(r.status=='complete' and r.fallbackOrdinal==4 and #seen==1 and seen[1].ordinal==3 and #contexts==0)
end)
test('malformed nested structures fail closed before any condition or action callback',function()
    local bad=branch('b','true',{action('same')},{action('same')})
    local r=a:EvaluateRotationSequence(body({bad}),function() error('evaluated invalid data') end,function() error('visited invalid data') end)
    assert(r.status=='unavailable' and r.suppressAttack and r.diagnostic.code=='duplicate-step-id')
end)
test('callback path changes cannot corrupt later contexts or saved tree structure',function()
    local b=body({branch('b','evaluate',{{id='stop',type='none',conditions={type='stop'}}})})
    local r=a:EvaluateRotationSequence(b,function(condition,context)
        if condition.type=='b' then context.stepPath[1]='changed';return {status='match'} end
        assert(table.concat(context.stepPath,'/')=='rotation/1/onTrue/1');return {status='no-match'}
    end,function() error('Stop treated as an action') end)
    assert(r.status=='complete' and b.rotation[1].onTrue[1].id=='stop')
end)
finish()
