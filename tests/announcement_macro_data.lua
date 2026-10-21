local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'})do f.load(path)end
 return f,f.addon,{id='11111111-1111-1111-1111-111111111111',type='macro',identifier='FOO',announce='local',value='Ready'}
end
test('closed macro schema retains strict automatic action event and destination validation',function()
 local _,a,entry=fixture();assert(a:IsValidAnnouncement(entry,true))
 for _,key in ipairs({'spell','item','event','ranked','unexpected'})do local copy=a.RotationData.CopyData(entry);copy[key]=key=='spell' and 403 or 'bad';assert(not a:IsValidAnnouncement(copy),key)end
 for _,mode in ipairs({'say','yell','whisper'})do entry.announce=mode;assert(a:IsValidAnnouncement(entry))end
 assert(not a:IsValidAnnouncement({type='spell',spell=403,event='START',announce='whisper'}));assert(not a:IsValidAnnouncement({type='spell',event='START',announce='local'}));assert(not a:IsValidAnnouncement({type='spell',spell=403,announce='local'}))
end)
test('profile transfer rejects duplicate macro identifiers even if disabled while retaining UUID rules',function()
 local _,a,entry=fixture();local other=a.RotationData.CopyData(entry);other.id='22222222-2222-2222-2222-222222222222';other.identifier='BAR'
 assert(a:ValidateProfileTransfer({announces={entry,other}}));other.identifier='FOO';other.disabled=true;assert(not a:ValidateProfileTransfer({announces={entry,other}}))
 other.identifier='foo';assert(a:ValidateProfileTransfer({announces={entry,other}}));other.id=entry.id;assert(not a:ValidateProfileTransfer({announces={entry,other}}))
end)
test('macro imports validate optional condition trees without invoking code and reject malformed input',function()
 local f,a,entry=fixture();f.load('Core/conditions.lua');a:RegisterCondition('IMPORT_ONLY',{fields={},valid=function()error('import ran custom validator')end,evaluate=function()error('import evaluated')end})
 entry.conditions={type='IMPORT_ONLY'};assert(a:IsValidAnnouncement(entry));entry.conditions.extra=true;assert(not a:IsValidAnnouncement(entry))
end)
finish()
