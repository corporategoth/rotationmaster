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
test('empty False arm remains straight beside True until the rejoin',function()
    local s=scene({branch('b',nil,{leaf('yes')},{})});local paths=exits(s,'b');local stem=paths['false'].points[1].x
    for _,edge in ipairs(s.connectors) do if edge.arm=='false' then
        for _,point in ipairs(edge.points) do assert(point.x==stem,'empty False arm shifts sideways') end
    end end
end)
finish()
