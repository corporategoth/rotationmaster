-- /rm debug talents (Diagnostics/talents.lua): the report that says why the
-- Retail/Forever talent lists are short or empty. It must show what each call
-- answered (including a failing call's own error text), never throw on an
-- unreadable value, keep to its size caps and be saved for SavedVariables.
-- Driven with the Retail class tree model (tests/fixtures/retail_traits.lua).
local F=dofile('tests/fixtures/addon.lua')
local Tree=dofile('tests/fixtures/retail_traits.lua')
local test,finish=F.suite()
local FIRE,FROST=Tree.SPECS.Fire,Tree.SPECS.Frost

local function client(state,project)
    local f=F.new(project or 1,12,'MAGE');local e=f.env
    Tree.install(e,state)
    for _,path in ipairs({'Platform/spells.lua','Platform/talents.lua','Diagnostics/glow.lua','Diagnostics/talents.lua'}) do f.load(path) end
    e.RotationMasterDB={}
    local printed,shown={},{}
    f.addon.print=function(_,message,...) printed[#printed+1]=string.format(message,...) end
    f.addon.ShowConditionText=function(_,text,heading) shown.text,shown.heading=text,heading end
    return f,f.addon,e,printed,shown
end
local function find(lines,pattern) for _,line in ipairs(lines) do if line:find(pattern) then return line end end end

test('the report walks config, tree, nodes and the editor lists, and reads other specializations only on request',function()
    local state={spec=FIRE};local f,a,e,printed,shown=client(state)
    local lines=a:RunTalentDiagnostic()
    assert(find(lines,'^Rotation Master talent diagnostic'),'header')
    assert(find(lines,'^played specialization=63'),'played spec')
    assert(find(lines,'C_ClassTalents.GetActiveConfigID%(%) %-> ok 7'),'active config')
    assert(find(lines,'C_Traits.GetConfigInfo%(7%) %-> ok .*treeIDs=%[1001%]'),'config info')
    assert(find(lines,'^C_Traits.GetTreeNodes%(1001%) %-> ok n=22'),tostring(find(lines,'GetTreeNodes')))
    assert(find(lines,'^node records: readable=22 failed=0'),'node scan: '..tostring(find(lines,'^node records')))
    assert(find(lines,'C_Traits.GetEntryInfo%(') and find(lines,'C_Traits.GetDefinitionInfo%(') and find(lines,'C_Spell.GetSpellInfo%('),'sample talent chain')
    assert(find(lines,'GetHeroTalentSpecsForClassSpec%(7%) %-> ok %[41,43%] n=2'),tostring(find(lines,'GetHeroTalentSpecsForClassSpec')))
    assert(find(lines,'^played specialization: source=active'),'editor list summary')
    assert(find(lines,'Hero talents') or find(lines,'%[hero%]'),'hero group line')
    assert(find(lines,'Arcane %(62%): not read %(run /rm debug talents views%)') and not state.viewSpec,'another specialization was read without asking')
    assert(shown.heading=='Talent diagnostic' and shown.text==table.concat(lines,'\n'),'not opened in the copy window')
    local saved=e.RotationMasterDB.diagnostics.talents;assert(#saved==1 and saved[1].lines==lines,'not saved')
    lines=a:RunTalentDiagnostic('views')
    assert(state.viewSpec and find(lines,'^Arcane %(62%): source=view') and find(lines,'^Frost %(64%): source=view'),'views')
end)

test('a failing call shows its own error text, and an unreadable value is a word, never an error',function()
    local state={spec=FIRE,errors={GetNodeInfo=true}};local f,a,e=client(state)
    local lines=a:BuildTalentDiagnostic()
    assert(find(lines,'^first node failure: GetNodeInfo blocked'),tostring(find(lines,'first node failure')))
    assert(find(lines,'^played specialization: not listed, reason=api%-error'),tostring(find(lines,'^played')))
    state.errors=nil
    local opaque={};e.canaccessvalue=function(v) return v~=opaque end
    e.C_Traits.GetConfigInfo=function() return {ID=7,type=1,name=opaque,treeIDs={1001}} end
    lines=a:BuildTalentDiagnostic();assert(find(lines,'name=secret'),'a secret field was shown')
    state.noConfig=true;lines=a:BuildTalentDiagnostic();assert(find(lines,'GetActiveConfigID%(%) %-> ok nil'),tostring(find(lines,'GetActiveConfigID')))
    e.C_ClassTalents.GetActiveConfigID=function() error('no talents yet') end
    lines=a:BuildTalentDiagnostic();assert(find(lines,'GetActiveConfigID%(%) %-> ERROR .*no talents yet'),'the error text is missing')
    e.C_Traits=nil;e.C_ClassTalents=nil
    lines=a:BuildTalentDiagnostic();assert(find(lines,'C_Traits.GetTreeNodes=missing'),'a client without trait APIs')
end)

test('the report is capped, only the newest three are kept, and /rm debug talents routes here',function()
    local state={spec=FIRE};local f,a,e,printed,shown=client(state)
    for _=1,5 do a:HandleDebugCommand(' talents') end
    local saved=e.RotationMasterDB.diagnostics.talents;assert(#saved==3,'reports not capped: '..#saved)
    assert(#saved[3].lines<=401)
    a:HandleDebugCommand('nonsense');assert(printed[#printed]:find('/rm debug talents [views]',1,true),printed[#printed])
    state.viewSpec=nil;a:HandleDebugCommand('talents views');assert(state.viewSpec,'views argument ignored')
end)

test('the report works on Forever, whose trees are node groups, and needs no Blizzard window',function()
    local state={spec=FIRE};local f,a,e=client(state,18)
    e.C_Traits.GetGroupDisplayInfoByTreeID=function() return {{groupID=1,orderIndex=1,displayName='Arcane',icon=1,treeID=Tree.TREE}} end
    assert(e.PlayerSpellsFrame==nil)
    local lines=a:BuildTalentDiagnostic();assert(find(lines,"^Blizzard's talent window: not loaded"),tostring(find(lines,'talent window')))
    assert(find(lines,'C_Traits.GetGroupDisplayInfoByTreeID=present'))
end)

test('the report is stamped with a real date and time, not seconds in the month slot',function()
    local state={spec=FIRE};local f,a,e=client(state);e.date=os.date
    local lines=a:RunTalentDiagnostic()
    local stamp=find(lines,'^Rotation Master talent diagnostic ')
    assert(stamp and stamp:match('^Rotation Master talent diagnostic %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$'),'bad stamp: '..tostring(stamp))
    local saved=e.RotationMasterDB;local reports
    for _,value in pairs(saved) do if type(value)=='table' then for _,list in pairs(value) do if type(list)=='table' and list[1] and list[1].at then reports=list end end end end
    assert(not reports or tostring(reports[#reports].at):match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$'),'bad saved stamp')
end)

finish()
