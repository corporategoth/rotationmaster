local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon
 for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Diagnostics/errors.lua','Core/conditions.lua','Core/announcements.lua'})do f.load(path)end
 a:RegisterCondition('FLAG',{fields={match='boolean'},valid=function()return true end,evaluate=function(v)return v.match end})
 return f,a
end
test('optional announcement condition preserves old behavior and applies ordinary logical semantics',function()
 local _,a=fixture();local calls=0;local evaluate=a.evaluateAnnouncementConditionResult
 a.evaluateAnnouncementConditionResult=function(...)calls=calls+1;return evaluate(...)end
 assert(a:AnnouncementConditionMatches({}));assert(calls==0)
 assert(a:AnnouncementConditionMatches({conditions={type='FLAG',match=true}}))
 assert(not a:AnnouncementConditionMatches({conditions={type='FLAG',match=false}}))
 assert(a:AnnouncementConditionMatches({conditions={type='NOT',value={type='FLAG',match=false}}}))
 assert(not a:AnnouncementConditionMatches({conditions={type='NOT',value={type='MISSING'}}}),'unavailable must not become true under NOT')
end)
test('event recipient cache is exact fresh and absent from ordinary condition evaluation',function()
 local _,a=fixture();local seen={}
 a:RegisterCondition('RECIPIENT',{fields={},valid=function()return true end,evaluate=function(_,cache)
  seen[#seen+1]={recipient=cache.announcementRecipient,cache=cache};return cache.announcementRecipient=='Healed-Realm'
 end})
 assert(a:AnnouncementConditionMatches({conditions={type='RECIPIENT'}},'Healed-Realm'))
 assert(not a:AnnouncementConditionMatches({conditions={type='RECIPIENT'}},nil))
 assert(not a:evaluateCondition({type='RECIPIENT'}))
 assert(seen[1].recipient=='Healed-Realm' and seen[2].recipient==nil and seen[3].recipient==nil)
 assert(seen[1].cache~=seen[2].cache and seen[2].cache~=seen[3].cache)
end)
test('a retired announcement owner cannot emit after custom evaluation returns',function()
 local _,a=fixture();local valid=true
 a:RegisterCondition('RETIRE',{fields={},valid=function()return true end,evaluate=function()valid=false;return true end})
 assert(not a:AnnouncementConditionMatches({conditions={type='RETIRE'}},nil,function()return valid end))
end)
test('newer reentrant announcement evaluation wins and errors fail closed',function()
 local _,a=fixture()
 a:RegisterCondition('REENTER',{fields={},valid=function()return true end,evaluate=function()
  assert(a:AnnouncementConditionMatches({conditions={type='FLAG',match=true}}));return true
 end})
 assert(not a:AnnouncementConditionMatches({conditions={type='REENTER'}}))
 a:RegisterCondition('THROW',{fields={},valid=function()return true end,evaluate=function()error('condition failure')end})
 assert(not a:AnnouncementConditionMatches({conditions={type='THROW'}}) and #a.Diagnostics:GetReports()==1)
end)
test('announcement structural validation preserves optional trees and never runs them on import',function()
 local _,a=fixture();a:RegisterCondition('NEVER_RUN',{fields={},valid=function()error('validator executed')end,evaluate=function()error('evaluator executed')end})
 local entry={type='spell',spell=547,event='START',announce='local',value='Message',conditions={type='NEVER_RUN'}}
 assert(a:IsValidAnnouncement(entry),'condition schema not accepted')
 entry.conditions='bad';assert(not a:IsValidAnnouncement(entry))
 entry.conditions={type='FLAG',match='bad'};assert(not a:IsValidAnnouncement(entry))
 entry.conditions={type='FLAG',match=true,extra=true};assert(not a:IsValidAnnouncement(entry))
 entry.conditions={};entry.conditions.value=entry.conditions;assert(not a:IsValidAnnouncement(entry))
end)
finish()
