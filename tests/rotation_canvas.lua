local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local a={};for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua'}) do assert(loadfile(path))('rotationmaster',a) end
local file=io.open('Core/rotation_canvas.lua','r');if file then file:close();assert(loadfile('Core/rotation_canvas.lua'))('rotationmaster',a) end
local function leaf(id) return {id=id,type='spell',action=403} end
local function branch(id,mode,yes,no) return {id=id,type='branch',mode=mode,conditions={},onTrue=yes or {},onFalse=no or {}} end
local function scene(steps,optional,view) return assert(a:BuildRotationCanvas({rotation=steps or {},cooldowns=optional or {}},view)) end
local function byId(s,id) for _,card in ipairs(s.cards) do if card.id==id then return card end end end
local function exits(s,id)
    local result={};for _,line in ipairs(s.connectors) do if line.from==id and line.arm then result[line.arm]=line end end;return result
end
test('evaluated branch has white border and labeled red False on the left green True on the right',function()
    local s=scene({branch('b',nil,{leaf('yes')},{leaf('no')}),leaf('tail')})
    local b,yes,no,tail=byId(s,'b'),byId(s,'yes'),byId(s,'no'),byId(s,'tail')
    assert(b.border=='white' and not yes.inactive and not no.inactive)
    assert(no.x+no.width<yes.x and yes.y==no.y and tail.y>yes.y+yes.height)
    local lines=exits(s,'b')
    assert(lines['true'].tone=='green' and lines['true'].label=='true' and lines['true'].to=='yes')
    assert(lines['false'].tone=='red' and lines['false'].label=='false' and lines['false'].to=='no')
    assert(s.complete and b.width==340 and s.width>=yes.x+yes.width)
end)
test('forced branches gray every unreachable descendant without losing forced choice or arm identity',function()
    local source=branch('b','true',{leaf('yes')},{branch('n','false',{leaf('nt')},{leaf('nf')})})
    local s=scene({source},{leaf('upkeep')})
    assert(byId(s,'b').border=='green' and byId(s,'n').border=='gray' and byId(s,'n').mode=='false')
    assert(byId(s,'nt').inactive and byId(s,'nf').inactive and not byId(s,'yes').inactive and not byId(s,'upkeep').inactive)
    local lines=exits(s,'b');assert(lines['false'].tone=='red' and lines['false'].inactive and not lines['true'].inactive)
    assert(source.onFalse[1].disabled==nil)
    source.mode='false';s=scene({source});assert(byId(s,'b').border=='red' and byId(s,'yes').inactive and byId(s,'n').border=='red')
end)
test('optional cards have no sequence edges and retain their own enabled state',function()
    local disabled=leaf('disabled');disabled.disabled=true
    local s=scene({leaf('action')},{leaf('upkeep'),disabled})
    for _,line in ipairs(s.connectors) do assert(line.from~='upkeep' and line.from~='disabled' and line.to~='upkeep' and line.to~='disabled') end
    assert(byId(s,'disabled').border=='gray' and byId(s,'disabled').inactive and byId(s,'upkeep').section=='cooldowns')
end)
test('empty arms expose distinct typed insertion targets and labeled branch exits',function()
    local s=scene({branch('b')});local targets={}
    for _,target in ipairs(s.dropTargets) do
        local p=target.destination.path
        if #p==3 and p[1]=='rotation' and p[2]==1 then targets[p[3]]=target;assert(target.destination.index==1) end
    end
    assert(targets.onTrue and targets.onFalse and targets.onFalse.x<targets.onTrue.x)
    local lines=exits(s,'b');assert(lines['true'] and lines['false'] and lines['true'].to==nil)
end)
test('collapsed branches hide descendants but do not consume the following visible budget',function()
    local many={};for i=1,250 do many[i]=leaf('s'..i) end
    local s=scene({branch('b',nil,many),leaf('tail')},{},{collapsed={b=true}})
    assert(s.complete and #s.cards==2 and byId(s,'b').collapsed and byId(s,'tail'))
    s=scene({branch('b',nil,many),leaf('tail')});assert(not s.complete and #s.cards==200 and not byId(s,'tail'))
end)
test('scene copies all card values and paths and never invokes custom condition callbacks',function()
    local body={rotation={branch('b','evaluate',{leaf('x')})},cooldowns={}}
    body.rotation[1].conditions={type='CUSTOM',code='error("must not execute")'}
    local s=assert(a:BuildRotationCanvas(body));local b=byId(s,'b')
    b.step.conditions.code='changed';b.path[1]='changed';s.dropTargets[1].destination.path[1]='changed'
    assert(body.rotation[1].conditions.code=='error("must not execute")' and body.rotation[1].id=='b')
    assert(b.step.onTrue==nil and b.step.onFalse==nil,'branch payload duplicated entire subtrees')
end)
test('nested layout bounds include deep branches and expanded fields without overlapping the rejoin',function()
    local s=scene({branch('b',nil,{branch('n',nil,{leaf('deep')},{leaf('other')})},{leaf('f')}),leaf('tail')},nil,{detailsHeights={deep=180}})
    local deep,tail=byId(s,'deep'),byId(s,'tail');assert(deep.height>=208 and deep.width==340)
    assert(tail.y>deep.y+deep.height and s.height>=tail.y+tail.height)
    for _,card in ipairs(s.cards) do assert(card.x>=0 and card.y>=0 and card.x+card.width<=s.width and card.y+card.height<=s.height) end
    for _,line in ipairs(s.connectors) do for _,point in ipairs(line.points) do assert(point.x>=0 and point.x<=s.width and point.y>=0 and point.y<=s.height) end end
end)
test('invalid structures are refused before rendering and empty sections remain insertion-capable',function()
    local s,why=a:BuildRotationCanvas({rotation={branch('b','bad')},cooldowns={}});assert(not s and why.code=='invalid-branch-mode')
    s=scene();assert(s.complete and #s.cards==0 and #s.dropTargets==2 and s.width>=340 and s.height>0)
end)
test('cooldowns use a responsive independent grid above the separated rotation',function()
    local s=scene({leaf('action')},{leaf('c1'),leaf('c2'),leaf('c3')},{viewportWidth=720})
    local first,second,third=byId(s,'c1'),byId(s,'c2'),byId(s,'c3')
    assert(first.y==second.y and second.x>first.x and third.y>first.y)
    assert(s.sections.cooldowns.y<first.y and s.separatorY>third.y+third.height)
    assert(s.sections.rotation.y>s.separatorY and byId(s,'action').y>s.sections.rotation.y)
    s=scene({}, {leaf('c1'),leaf('c2')},{viewportWidth=400})
    assert(byId(s,'c2').y>byId(s,'c1').y)
end)
test('whole sections collapse and compact cards retain identity without action controls while preserving branch paths',function()
    local body={rotation={branch('b',nil,{leaf('yes')},{leaf('no')})},cooldowns={leaf('c')}}
    local s=assert(a:BuildRotationCanvas(body,{sectionsCollapsed={cooldowns=true}}));assert(not byId(s,'c') and byId(s,'yes'))
    s=assert(a:BuildRotationCanvas(body,{cardStates={b='compact'}}));assert(byId(s,'b').compact and byId(s,'b').height==28 and byId(s,'yes'))
    s=assert(a:BuildRotationCanvas(body,{sectionsCollapsed={rotation=true}}));assert(byId(s,'c') and not byId(s,'b'))
    assert(s.width>=500,'section controls extend beyond the scrollable canvas')
end)
test('rotation lists stay left aligned and compact branch names retain paths until explicitly folded',function()
    local s=scene({leaf('before'),branch('b',nil,{leaf('yes')},{leaf('no')}),leaf('after')},{},{cardStates={b='compact'}})
    assert(byId(s,'before').x==byId(s,'b').x and byId(s,'after').x==byId(s,'b').x)
    assert(byId(s,'yes') and byId(s,'no') and s.sections.cooldowns.y>=8)
    s=scene({branch('b',nil,{leaf('yes')},{leaf('no')})},{},{hiddenChildren={b=true}});assert(not byId(s,'yes'))
end)
test('empty branch arms have continuous colored paths through their empty spans',function()
    local s=scene({branch('b')});local through={}
    for _,edge in ipairs(s.connectors) do if #edge.points==2 and edge.tone~='neutral' then
        local p,q=edge.points[1],edge.points[2];if p.x==q.x and q.y-p.y==36 then through[edge.tone]=true end
    end end
    assert(through.green and through.red)
end)
test('True and False stems remain side by side until their split instead of overdrawing',function()
    local s=scene({branch('b',nil,{leaf('yes')},{leaf('no')})});local paths=exits(s,'b')
    assert(paths['false'].points[1].x+2<=paths['true'].points[1].x,'red path overdraws green before split')
    assert(paths['false'].points[1].y==paths['true'].points[1].y)
end)
test('empty False arm bypasses the populated True arm on its left and rejoins the spine',function()
    local s=scene({branch('b',nil,{leaf('yes')},{})});local b,yes=byId(s,'b'),byId(s,'yes');local center=b.x+b.width/2
    assert(yes.x+yes.width/2==center)
    local bypass
    for _,edge in ipairs(s.connectors) do if edge.arm=='false' then
        for _,point in ipairs(edge.points) do if point.x<yes.x then bypass=true end end
    end end
    assert(bypass,'empty False path does not go around the populated arm')
end)
test('list view uses a compact false-then-true hierarchy with linear width and exact typed arm destinations',function()
    local source={branch('b',nil,{branch('nested',nil,{leaf('deep')},{})},{leaf('no')}),leaf('tail')}
    local s=scene(source,nil,{layout='list'});local b,no,yes,deep,tail=byId(s,'b'),byId(s,'no'),byId(s,'nested'),byId(s,'deep'),byId(s,'tail')
    assert(s.layout=='list' and b.compact and b.height==28)
    assert(no.y<yes.y and no.x==yes.x and no.x>b.x and deep.x>yes.x)
    assert(tail.y>deep.y+deep.height and tail.x==b.x)
    assert(deep.x+deep.width<=s.width and s.width<800 and #s.armLabels==4)
    local arms={};for _,target in ipairs(s.dropTargets) do if target.destination.parentId=='nested' then arms[target.destination.path[#target.destination.path]]=true end end
    assert(arms.onFalse and arms.onTrue and no.arm=='false' and yes.arm=='true')
    assert(source[1].onFalse[1].id=='no' and source[1].onTrue[1].id=='nested')
end)
test('list view preserves forced reachability explicit details and independently folded subtrees',function()
    local s=scene({branch('b','true',{leaf('yes')},{leaf('no')})},nil,{layout='list',cardStates={yes='expanded'},detailsHeights={yes=100}})
    assert(byId(s,'no').inactive and not byId(s,'yes').inactive and byId(s,'yes').expanded)
    assert(s.armLabels[1].arm=='false' and s.armLabels[1].inactive and not s.armLabels[2].inactive)
    s=scene({branch('b',nil,{leaf('yes')},{leaf('no')}),leaf('tail')},nil,{layout='list',hiddenChildren={b=true}})
    assert(not byId(s,'yes') and #s.armLabels==0 and byId(s,'tail'))
end)
test('selected workspace projects only its section and list defaults do not compact cooldowns',function()
    local optional={leaf('c1'),leaf('c2')}
    local s=scene({leaf('r')},optional,{section='rotation',layout='diagram'})
    assert(byId(s,'r') and not byId(s,'c1') and s.section=='rotation')
    s=scene({leaf('r')},optional,{section='cooldowns',layout='list',viewportWidth=720})
    assert(not byId(s,'r') and not byId(s,'c1').compact and byId(s,'c1').height>28)
    local other=scene({leaf('r')},optional,{section='cooldowns',layout='diagram',viewportWidth=720})
    assert(byId(s,'c1').y==byId(other,'c1').y and byId(s,'c2').x==byId(other,'c2').x and s.height==other.height)
    for _,target in ipairs(s.dropTargets) do assert(target.destination.path[1]=='cooldowns') end
end)
test('list siblings touch and branch arms have nested passive bounds with exact destinations',function()
    local s=scene({leaf('before'),branch('b',nil,{leaf('t1'),leaf('t2')},{leaf('f1')}),leaf('after')},nil,{section='rotation',layout='list'})
    local before,b,t1,t2,f1,after=byId(s,'before'),byId(s,'b'),byId(s,'t1'),byId(s,'t2'),byId(s,'f1'),byId(s,'after')
    assert(before.y+before.height==b.y and t1.y+t1.height==t2.y,'list retained diagram gaps')
    local parent,yes,no
    for _,group in ipairs(s.groups or {}) do
        if group.id=='b' then if group.kind=='branch' then parent=group elseif group.arm=='true' then yes=group else no=group end end
    end
    assert(parent and yes and no and no.y+no.height==yes.y and parent.y+parent.height==after.y)
    assert(no.y<f1.y and f1.y+f1.height<=no.y+no.height and yes.y<t1.y and t2.y+t2.height<=yes.y+yes.height)
    assert(parent.x<=no.x and parent.x+parent.width>=yes.x+yes.width)
    local arms={};for _,target in ipairs(s.dropTargets) do if target.destination.parentId=='b' then arms[target.destination.path[3]]=true end end
    assert(arms.onTrue and arms.onFalse and #s.connectors==0)
end)
test('hidden content never consumes the active workspace card budget',function()
    local rotation,optional={},{};for i=1,200 do rotation[i]=leaf('r'..i);optional[i]=leaf('c'..i) end
    for _,section in ipairs({'rotation','cooldowns'}) do
        local s=scene(rotation,optional,{section=section,layout='list'})
        assert(s.complete and #s.cards==200 and byId(s,(section=='rotation' and 'r' or 'c')..200))
        for _,target in ipairs(s.dropTargets) do assert(target.destination.path[1]==section) end
    end
end)
test('diagram branch centers above two populated arms and aligns one populated arm straight below',function()
    for _,arms in ipairs({{{leaf('yes')},{leaf('no')}},{{leaf('yes')},{}},{{},{leaf('no')}}}) do
        local s=scene({leaf('before'),branch('b',nil,arms[1],arms[2]),leaf('after')},nil,{section='rotation'})
        local b,yes,no=byId(s,'b'),byId(s,'yes'),byId(s,'no');local center=b.x+b.width/2
        if yes and no then assert(center==(no.x+no.width/2+yes.x+yes.width/2)/2,'branch is not centered between arms')
        else local active=yes or no;assert(active.x+active.width/2==center,'populated arm does not continue straight') end
        assert(byId(s,'before').x==b.x and byId(s,'after').x==b.x,'root sequence shifts its spine')
        for _,edge in ipairs(s.connectors) do if edge.to=='yes' or edge.to=='no' then
            if not (yes and no) then for _,point in ipairs(edge.points) do assert(point.x==center,'active arm is bent') end end
        end end
    end
end)
test('independent arm folds keep the other arm and a typed insertion target without changing data',function()
    local value={branch('b',nil,{leaf('yes')},{leaf('no')}),leaf('tail')}
    for _,layout in ipairs({'diagram','list'}) do
        local s=scene(value,nil,{section='rotation',layout=layout,hiddenArms={b={['false']=true}}})
        assert(byId(s,'yes') and not byId(s,'no') and byId(s,'tail'))
        local label,target
        for _,arm in ipairs(s.armLabels or {}) do if arm.parentId=='b' and arm.arm=='false' then label=arm end end
        for _,gap in ipairs(s.dropTargets) do if gap.destination.parentId=='b' and gap.destination.path[3]=='onFalse' then target=gap end end
        assert(label and label.folded and label.count==1 and target)
        assert(value[1].onFalse[1].id=='no')
    end
end)
test('an asymmetric nested branch chain retains compact width and centered root lanes',function()
    local root=leaf('deep')
    for i=1,10 do root=branch('nested'..i,nil,{root},{leaf('side'..i)}) end
    local s=scene({root},nil,{section='rotation'})
    assert(#s.cards==21 and s.width<10000,'small nested tree produced an exponentially wide canvas')
    for _,card in ipairs(s.cards) do assert(card.x>=0 and card.x+card.width<=s.width) end
end)
test('arm fold controls stay inside the measured diagram bounds',function()
    for _,arms in ipairs({{{leaf('yes')},{}},{{},{leaf('no')}},{{},{}},{{},{branch('nested',nil,{}, {branch('inner',nil,{}, {leaf('deep')})})}}}) do
        local s=scene({branch('b',nil,arms[1],arms[2])},nil,{section='rotation'})
        for _,arm in ipairs(s.armLabels) do assert(arm.x>=0 and arm.x+100<=s.width,'arm control overflows scroll surface') end
    end
end)
test('diagram arm labels sit above split paths or beside the one straight populated path',function()
    for _,arms in ipairs({{{leaf('yes')},{leaf('no')}},{{leaf('yes')},{}},{{},{leaf('no')}}}) do
        local s=scene({branch('b',nil,arms[1],arms[2])},nil,{section='rotation'});local b=byId(s,'b');local center=b.x+b.width/2
        for _,label in ipairs(s.armLabels) do
            if #arms[1]>0 and #arms[2]>0 then assert(label.y+18<=b.y+b.height+20 and label.placement=='above')
            elseif label.arm=='true' and #arms[1]>0 then assert(label.x>center and label.placement=='right');assert(label.y+9==b.y+b.height+20,'side label is not centered at the split')
            elseif label.arm=='false' and #arms[2]>0 then assert(label.x+100<center and label.placement=='left');assert(label.y+9==b.y+b.height+20,'side label is not centered at the split')
            else assert(label.placement=='above' and label.y+18<=b.y+b.height+20) end
        end
    end
end)
test('straight-arm label midpoint aligns exactly with the other arm horizontal split',function()
    for _,arm in ipairs({'true','false'}) do
        local s=scene({branch('b',nil,arm=='true' and {leaf('t')} or {},arm=='false' and {leaf('f')} or {})})
        local other=arm=='true' and 'false' or 'true';local split;for _,edge in ipairs(s.connectors) do if edge.label==other then split=edge.points[2].y;break end end
        for _,label in ipairs(s.armLabels) do if label.arm==arm then assert(label.y+9==split,'label midpoint is not at other-arm split') end end
    end
end)
finish()
