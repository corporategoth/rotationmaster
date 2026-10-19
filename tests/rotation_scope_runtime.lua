local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
-- Reuse the existing real-main/real-AceDB setup without executing its suite.
-- Keep this boundary in one fixture rather than duplicating its client shims.
local file=assert(io.open('tests/startup.lua'));local source=file:read('*a');file:close()
local common=assert(source:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
local persistent=assert(source:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'))
local make=assert(loadstring(common..'\n'..persistent..'\nreturn persistentFixture','@scoped-runtime-fixture'))()
local function fixture()
    local env,a,_,load=make(nil,nil,true);a.currentSpec=0;a.units={};env.GetTime=function() return 100 end;a.lastCacheReport=100
    local events={};local function event(kind,...) events[#events+1]={kind,...} end
    env.LibStub('AceEvent-3.0').SendMessage=function(_,kind,...) event(kind,...) end
    env.WeakAuras={ScanEvents=function(...) event('weak',...) end}
    a.NewActionReadiness=function() return function() return true end end
    a.FindSpell=function(_,ids) return ids[1] end;a.IsGlowing=function() return false end
    a.GlowNextSpell=function(_,id) event('glow',id) end;a.GlowClear=function() event('clear') end
    a.GlowCooldown=function(_,id,on) event('cooldown',id,on) end
    a.DispatchAnnouncement=function(_,condition) event('announce',condition.id) end
    a.Platform.GetSpellLink=function(_,id) return 'spell:'..id end
    a.Platform.IsMeleeAttackNeeded=function() return false end
    a.db.profile.preview_spells=2;a.nextWindow={ReleaseChildren=function() event('preview-clear') end,PauseLayout=function() end,
        ResumeLayout=function() end,DoLayout=function() end,AddRecommendation=function(_,id) event('preview',id) end}
    a.skipAnnounce=false
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id='runtime'}}
    local function save(body)
        local existing,token=a:GetRotationRecordSnapshot(0,reference);if not existing then token=nil end
        assert(a:CommitRotationDraft(reference,token,{body=body},'class'))
    end
    local body={name='Runtime',switch={},rotation={{id='action',type='spell',action=403,ranked=true,conditions={}}},
        cooldowns={{id='cooldown',type='spell',action=324,ranked=true,conditions={}}}}
    save(body);a.currentRotation=a:GetScopedRotationCoordinator():Key(reference)
    return env,a,events,body,reference,save,load
end
local function gate(a,callback)
    a:RegisterCondition('TEST_RUNTIME_MUTATION',{description='Runtime mutation',fields={},requiredFields={},valid=function() return true end,
        evaluate=callback,print=function() return 'Runtime mutation' end,widget=function() end,help=function() end})
end
test('real scoped evaluation publishes one current pass after staging recommendations and cooldowns',function()
    local _,a,events=fixture();local acquire=a.AcquireRotationRuntimePass;local count=0
    a.AcquireRotationRuntimePass=function(self,...) count=count+1;return acquire(self,...) end
    a:EvaluateNextActionInternal();assert(count==1,'evaluation acquired multiple independent passes')
    local seen={};for _,entry in ipairs(events) do seen[entry[1]]=true end
    assert(seen.glow and seen.preview and seen.cooldown and seen.announce and a.currentSpell==403)
end)
test('selected replacement during an action condition publishes no stale advice or preview',function()
    local _,a,events,body,reference,save=fixture();local mutated=false
    gate(a,function() if not mutated then mutated=true;local nextBody=a.RotationData.CopyData(body);nextBody.name='Replacement';save(nextBody) end;return true end)
    body.rotation[1].conditions={type='TEST_RUNTIME_MUTATION'};save(body)
    a:EvaluateNextActionInternal();assert(mutated and #events==0,'stale action pass emitted '..(#events)..' effects')
    assert(a.currentSpell==nil and next(a.avail_announced)==nil and a:GetRotationRecordSnapshot(0,reference).body.name=='Replacement')
end)
test('profile retirement during an action condition publishes no old recommendation',function()
    local _,a,events,body,_,save=fixture();local changed=false
    gate(a,function() if not changed then changed=true;a.db.profile=a.RotationData.CopyData(a.db.profile);assert(a:BindRotationProfile()) end;return true end)
    body.rotation[1].conditions={type='TEST_RUNTIME_MUTATION'};save(body)
    a:EvaluateNextActionInternal();assert(changed and #events==0,'retired profile pass emitted advice')
end)
test('cooldown condition mutation discards the whole staged cycle including earlier rotation advice',function()
    local _,a,events,body,_,save=fixture();local mutated=false
    gate(a,function() if not mutated then mutated=true;local nextBody=a.RotationData.CopyData(body);nextBody.name='Cooldown replacement';save(nextBody) end;return true end)
    body.cooldowns[1].conditions={type='TEST_RUNTIME_MUTATION'};save(body)
    a:EvaluateNextActionInternal();assert(mutated and #events==0,'cooldown invalidation allowed partial advice')
    assert(a.currentSpell==nil and next(a.avail_announced)==nil)
end)
test('cooldown profile retirement discards earlier staged rotation and optional outputs',function()
    local _,a,events,body,_,save=fixture();local changed=false
    gate(a,function() if not changed then changed=true;a.db.profile=a.RotationData.CopyData(a.db.profile);assert(a:BindRotationProfile()) end;return true end)
    body.cooldowns[1].conditions={type='TEST_RUNTIME_MUTATION'};save(body)
    a:EvaluateNextActionInternal();assert(changed and #events==0 and next(a.avail_announced)==nil)
end)
test('retirement by a publishing callback stops later messages previews and cooldown output',function()
    local _,a,events=fixture();a.GlowNextSpell=function(_,id)
        events[#events+1]={'glow',id};a.db.profile=a.RotationData.CopyData(a.db.profile);assert(a:BindRotationProfile())
    end
    a:EvaluateNextActionInternal()
    assert(#events==2 and events[1][1]=='preview-clear' and events[2][1]=='glow','publisher retirement did not stop subsequent output')
    assert(next(a.avail_announced)==nil)
end)
test('missing selected issued keys retire manual mode so automatic fallback is not blocked',function()
    local _,a=fixture();a.currentRotation=string.char(1)..'rm:rotation:retired';a.manualRotation=true
    a.DestroyAllGlows=function() end
    a:EvaluateNextActionInternal();assert(not a.currentRotation and not a.manualRotation)
end)
test('scoped Built In headers expose actual eligibility without exposing runtime bodies',function()
    local _,a=fixture();local header
    local rows,initialStamp=a:ListRotationHeaders(0)
    for _,row in ipairs(rows) do if row.kind=='builtin' then header=row;break end end
    assert(header and header.eligible==true and header.body==nil,'eligible Built In header is marked unavailable')
    local context=a.GetRotationContext;a.GetRotationContext=function(self,spec) local value=context(self,spec);value.level=99;return value end
    local unavailable,changedStamp=a:ListRotationHeaders(0);assert(changedStamp~=initialStamp)
    for _,row in ipairs(unavailable) do if row.kind=='builtin' then assert(row.eligible==false and row.eligibilityReason=='level-mismatch') end end
    local _,stableStamp=a:ListRotationHeaders(0);assert(stableStamp==changedStamp)
end)
test('automatic selection rejects records replaced by their own switch condition before publication',function()
    local _,a,events,body,_,save=fixture();local key=a.currentRotation;local changed=false
    gate(a,function() if not changed then changed=true;local replacement=a.RotationData.CopyData(body);replacement.name='New switch';save(replacement) end;return true end)
    body.switch={type='TEST_RUNTIME_MUTATION'};save(body);a.currentRotation=nil;a.autoswitchRotation={key}
    a.RemoveAllCurrentGlows=function() events[#events+1]={'cleanup'} end;a.EnableRotationTimer=function() events[#events+1]={'timer'} end
    a:SwitchRotation();assert(changed and a.currentRotation==nil and #events==0,'stale switch condition published a selection')
end)
test('automatic selection rejects a profile retired by its switch condition',function()
    local _,a,events,body,_,save=fixture();local key=a.currentRotation;local changed=false
    gate(a,function() if not changed then changed=true;a.db.profile=a.RotationData.CopyData(a.db.profile);assert(a:BindRotationProfile()) end;return true end)
    body.switch={type='TEST_RUNTIME_MUTATION'};save(body);a.currentRotation=nil;a.autoswitchRotation={key}
    a.RemoveAllCurrentGlows=function() events[#events+1]={'cleanup'} end;a.EnableRotationTimer=function() events[#events+1]={'timer'} end
    a:SwitchRotation();assert(changed and a.currentRotation==nil and #events==0,'retired switch condition published a selection')
end)
test('automatic selection publishes a current candidate from one captured pass',function()
    local _,a,events=fixture();local key=a.currentRotation;a.currentRotation=nil;a.autoswitchRotation={key}
    a.RemoveAllCurrentGlows=function() events[#events+1]={'cleanup'} end;a.EnableRotationTimer=function() events[#events+1]={'timer'} end
    local original=a.AcquireRotationRuntimePass;local count=0;a.AcquireRotationRuntimePass=function(self,...) count=count+1;return original(self,...) end
    a:SwitchRotation();assert(a.currentRotation==key and count==1,'automatic selection used incoherent passes')
end)
finish()
