-- An unavailable condition makes the rotation unusable: an action, Branch or
-- Stop whose condition cannot be read stops the rotation for that poll (no
-- lower step, implicit Attack suppressed), and an unavailable cooldown
-- condition hides that cooldown. Unavailable is never treated as false.
-- Both evaluation engines must agree, on the prepared (compiled condition
-- runtime) route and on the ordinary route used for custom definitions.
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local root=assert(io.popen('pwd'):read('*l'))

-- Tri-state probe for the ordinary route: a definition the compiled runtime
-- has no declaration for, so main evaluates it through evaluateCondition.
local probeState='true'
local function registerProbe(a)
 a:RegisterCondition('RM_TEST_TRISTATE',{description='Tri-state probe',fields={},
  valid=function()return true end,
  evaluate=function()if probeState=='unavailable' then return nil,'test-unavailable' end;return probeState=='true' end,
  print=function()return 'probe' end})
end
-- Prepared route: a real Built In condition on the target. A target level of
-- 0 is an invalid API result, so LEVEL is unavailable; 11 matches, 3 does
-- not. Target level is not a cached fact, so it is read every poll. The
-- fixture's own UnitLevel reads it, so native identities stay certified.
local targetLevel=11
local function level(c,state)
 targetLevel=state=='true' and 11 or state=='false' and 3 or 0
 c.fire('UNIT_LEVEL','target')
end
local fixtureSource
do
 local h=assert(io.open('tests/fixtures/wholepoll_shaman.lua'));fixtureSource=h:read('*a');h:close()
 local old="e.UnitLevel=function(unit) hit('UnitLevel',unit);return playerLevel end"
 local a,b=fixtureSource:find(old,1,true);assert(a,'fixture UnitLevel anchor missing')
 fixtureSource=fixtureSource:sub(1,a-1).."e.UnitLevel=function(unit) hit('UnitLevel',unit);if unit=='target' and options.targetLevel then return options.targetLevel() end;return playerLevel end"..fixtureSource:sub(b+1)
end
local routes={
 prepared={guard={type='LEVEL',unit='target',operator='GREATERTHAN',value=5},set=level},
 ordinary={guard={type='RM_TEST_TRISTATE'},set=function(c,state)probeState=state;c.fire('UNIT_AURA','player')end},
}

local function make(engine,options)
 local build=assert(loadstring(fixtureSource,'@tests/fixtures/wholepoll_shaman.lua'))('trace',root,true,root,true)
 options.buttons=true;options.poll=.15;options.targetLevel=function()return targetLevel end
 local c=build(options);c.a.db.profile.idle_poll=0;assert(c.a:SetEvaluationEngine(engine))
 registerProbe(c.a)
 for _=1,6 do c.tick()end;return c
end
local function commit(c,body)
 local key=c.a.currentRotation;local record,token=c.a:GetRotationRecordSnapshot(0,key);assert(record and token)
 record.body.rotation=body.rotation;record.body.cooldowns=body.cooldowns or {}
 local ref=assert(c.a:GetScopedRotationCoordinator():Resolve(0,key));assert(c.a:CommitRotationDraft(ref,token,record,'class'))
 for _=1,4 do c.tick()end
end
local function delivered(c)
 local _,rows=c.snapshot();local out={}
 for _,v in ipairs(rows)do if v:match('^WeakAuras|')or v:match('^SendMessage|')or v:match('^Texture%.')or v:match('^Preview%.')then out[#out+1]=v end end
 return out
end
local function observe(c,n)
 c.reset(true);local advice={}
 for i=1,n do c.tick();advice[i]=tostring(c.a.currentSpell) end
 local rows=delivered(c);c.reset(false);assert(not c.a.adviceErrorReport,'advice error');return advice,rows
end
local function same(x,y,what)
 assert(#x==#y,what..': '..#x..' vs '..#y..' rows ('..table.concat(x,',')..' / '..table.concat(y,',')..')')
 for i=1,#x do assert(x[i]==y[i],what..' row '..i..': '..tostring(x[i])..' vs '..tostring(y[i]))end
end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,conditions=conditions or{}}end

-- body(guard) -> rotation body; expect[state] -> currentSpell after polling.
local scenarios={
 {name='action step',body=function(g)return{rotation={spell('guarded',403,g),spell('lower',8042)}}end,
  expect={['true']='403',['false']='8042',unavailable='nil'}},
 {name='action step beneath a branch arm',body=function(g)return{rotation={{id='br',type='branch',mode='true',conditions={},onFalse={},onTrue={spell('guarded',403,g)}},spell('lower',8042)}}end,
  expect={['true']='403',['false']='8042',unavailable='nil'}},
 {name='branch',body=function(g)return{rotation={{id='br',type='branch',conditions=g,onTrue={spell('yes',403)},onFalse={spell('no',8042)}},spell('after',324)}}end,
  expect={['true']='403',['false']='8042',unavailable='nil'}},
 {name='stop',body=function(g)return{rotation={{id='halt',type='none',conditions=g},spell('lower',8042)}}end,
  expect={['true']='nil',['false']='8042',unavailable='nil'}},
 {name='cooldown does not stop the rotation',body=function(g)return{rotation={spell('main',8042)},cooldowns={spell('cd',324,g)}}end,
  expect={['true']='8042',['false']='8042',unavailable='8042'},cooldown={['true']=324,['false']=nil,unavailable=nil}},
}

for routeName,route in pairs(routes)do
 for _,scenario in ipairs(scenarios)do
  test(routeName..' '..scenario.name..': unavailable stops, lean matches standard',function()
   local s,l=make('standard',{target=true}),make('lean',{target=true})
   local body=scenario.body(route.guard);commit(s,body);commit(l,body)
   for _,state in ipairs({'true','unavailable','false','unavailable','true'})do
    route.set(s,state);route.set(l,state);for _=1,3 do s.tick();l.tick()end
    local a1,r1=observe(s,3);local a2,r2=observe(l,3)
    same(a1,a2,state..' advice');same(r1,r2,state..' outputs')
    assert(a1[3]==scenario.expect[state],state..': expected '..scenario.expect[state]..', got '..a1[3])
    if scenario.cooldown then
     assert(s.a.avail_announced.cd==scenario.cooldown[state],state..': standard cooldown '..tostring(s.a.avail_announced.cd))
     assert(l.a.avail_announced.cd==scenario.cooldown[state],state..': lean cooldown '..tostring(l.a.avail_announced.cd))
    end
   end
   assert(l.a:GetEvaluationEngine()=='lean','lean plan never engaged: '..l.a:GetEvaluationEngine())
   if routeName=='prepared' then
    local d=s.a:GetConditionRuntimeDiagnostic();assert(d.compiles>0 and d.legacyFallback==0,'prepared route not used: '..tostring(d.active)..' '..d.compiles..' '..d.legacyFallback)
   end
  end)
 end
 -- With a preview, steps above the unavailable one keep their places; nothing
 -- below it is added.
 test(routeName..' preview stops at the unavailable step',function()
  local s,l=make('standard',{target=true,preview=3}),make('lean',{target=true,preview=3})
  local body={rotation={spell('first',8042),spell('guarded',403,route.guard),spell('last',324)}}
  commit(s,body);commit(l,body)
  for _,state in ipairs({'true','unavailable','false'})do
   route.set(s,state);route.set(l,state);for _=1,3 do s.tick();l.tick()end
   local a1,r1=observe(s,3);local a2,r2=observe(l,3)
   same(a1,a2,state..' advice');same(r1,r2,state..' outputs')
   assert(a1[3]=='8042',state..': primary '..a1[3])
   local added=0;for _,row in ipairs(r1)do if row:match('^Preview%.AddRecommendation')then added=added+1 end end
   local want=state=='unavailable' and 1 or state=='true' and 3 or 2
   assert(added==3*want,state..': '..added..' preview rows, expected '..3*want)
  end
 end)
end

-- The sequence executor's public contract: a visitor returning "unavailable"
-- ends the walk as unavailable with Attack suppressed.
test('sequence executor honours an unavailable visit',function()
 local c=make('standard',{target=true})
 local visited={}
 local result=c.a:EvaluateRotationSequence({rotation={spell('one',403),spell('two',8042),spell('three',324)}},
  function()return{status='match'}end,
  function(step)visited[#visited+1]=step.id;if step.id=='two' then return 'unavailable' end;return true end)
 assert(result.status=='unavailable' and result.suppressAttack==true,'status '..tostring(result.status))
 assert(#visited==2 and visited[2]=='two','walk continued past the unavailable step')
end)

-- Public evaluators keep their first result and add the unavailable flag.
test('evaluateCondition reports unavailable as a second result',function()
 local c=make('standard',{target=true})
 for state,want in pairs({['true']={true,false},['false']={false,false},unavailable={false,true}})do
  probeState=state;local m,u=c.a:evaluateCondition({type='RM_TEST_TRISTATE'})
  assert(m==want[1] and u==want[2],state..': '..tostring(m)..','..tostring(u))
  m,u=c.a:evaluateCondition({type='NOT',value={type='RM_TEST_TRISTATE'}})
  assert(u==want[2] and m==(state=='false'),'NOT '..state..': '..tostring(m)..','..tostring(u))
 end
 probeState='true'
end)
print(pass..' passed, '..fail..' failed');if fail>0 then os.exit(1)end
