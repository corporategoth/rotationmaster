-- Bulk selection in the rotation editor: Ctrl/Shift-click and Shift-drag box
-- selection, then move, duplicate, enable/disable and delete the selected
-- cards together, each as one undo step. The draft commands behind them
-- (Batch, MoveMany) are exercised directly first.
local F=dofile('tests/fixtures/addon.lua')
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local prefix=assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local fixture,card=assert(loadstring(prefix..'\nreturn fixture,card','@rotation-bulk-fixture'))()
local test,finish=F.suite()

local data
do
    local a={};for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/rotation_draft.lua'}) do assert(loadfile(file))('rotationmaster',a) end
    data=a.RotationData
end
local function leaf(id) return {id=id,type='spell',action=403,conditions={}} end
local function ids(list) local out={};for i,step in ipairs(list) do out[i]=step.id end;return table.concat(out,',') end
local function allocator() local i=0;return function() i=i+1;return 'new-'..i end end

test('MoveMany carries cards to one gap in document order and fails as a whole',function()
    local d=assert(data.NewRotationDraft({rotation={leaf('a'),leaf('b'),leaf('c'),leaf('d'),leaf('e')},cooldowns={}},allocator()))
    assert(d:Command('MoveMany',{'d','b'},{path={'rotation'},index=1}));assert(ids(d:Snapshot().rotation)=='b,d,a,c,e','carried cards are not in document order at the gap')
    assert(d:Command('MoveMany',{'b','a'},{path={'rotation'},index=6}));assert(ids(d:Snapshot().rotation)=='d,c,e,b,a','same-list gap was not adjusted for the removed cards')
    local body={rotation={{id='br',type='branch',conditions={},onTrue={leaf('t1')},onFalse={}},leaf('x'),leaf('y')},cooldowns={}}
    d=assert(data.NewRotationDraft(body,allocator()))
    assert(d:Command('MoveMany',{'x','br','t1'},{path={'rotation'},index=4}))
    local v=d:Snapshot();assert(ids(v.rotation)=='y,br,x' and v.rotation[2].onTrue[1].id=='t1','a card inside a carried branch did not travel with it')
    local before=d:Snapshot()
    assert(not d:Command('MoveMany',{'br','y'},{path={'rotation',2,'onTrue'},parentId='br',index=1}),'a branch moved into itself')
    assert(not d:Command('MoveMany',{'y','missing'},{path={'rotation'},index=1}),'a missing card was accepted')
    local after=d:Snapshot();assert(ids(after.rotation)==ids(before.rotation),'a refused move changed the draft')
end)

test('Batch applies every operation or none',function()
    local d=assert(data.NewRotationDraft({rotation={leaf('a'),leaf('b'),leaf('c')},cooldowns={}},allocator()))
    local ok,results=d:Command('Batch',{{'Duplicate','a'},{'UpdateStep','c',{disabled=true}}})
    assert(ok and results[1]=='new-1' and ids(d:Snapshot().rotation)=='a,new-1,b,c' and d:Snapshot().rotation[4].disabled==true)
    local before=ids(d:Snapshot().rotation)
    assert(not d:Command('Batch',{{'Remove','a'},{'Remove','missing'}}),'a failing batch reported success')
    assert(ids(d:Snapshot().rotation)==before,'a failing batch left part of its edit')
    assert(not d:Command('Batch',{{'Batch',{}}}) and not d:Command('Batch',{}),'nested or empty batches were accepted')
end)

local function editor(extra)
    local f,parent=fixture();local a=f.addon;local value=a:GetEditableRotation(0,'mine')
    for i,id in ipairs({'s1','s2','s3','s4'}) do value.rotation[#value.rotation+1]={id=id,type='spell',action=403,conditions={}} end
    if extra then extra(value) end
    local keys={ctrl=false,shift=false};f.env.IsControlKeyDown=function() return keys.ctrl end;f.env.IsShiftKeyDown=function() return keys.shift end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    return f,a,pane,keys
end
local function click(c,keys,ctrl,shift) keys.ctrl,keys.shift=ctrl or false,shift or false;local frame=c.frame;frame.scripts.OnMouseUp(frame,'LeftButton');keys.ctrl,keys.shift=false,false end
local function selection(pane) return table.concat(pane.canvas:SelectedIds(false),',') end

test('clicks select cards: body click, Ctrl toggle, Shift range, empty canvas clears',function()
    local _,_,pane,keys=editor()
    click(card(pane,'s1'),keys);assert(selection(pane)=='s1' and card(pane,'s1').selected,'a body click did not select the card')
    click(card(pane,'s3'),keys,true);assert(selection(pane)=='s1,s3','Ctrl-click did not add')
    click(card(pane,'s1'),keys,true);assert(selection(pane)=='s3' and not card(pane,'s1').selected,'Ctrl-click did not toggle off')
    click(card(pane,'s3'),keys);keys.shift=true;local title=card(pane,'s4').title;title.scripts.OnClick(title,'LeftButton');keys.shift=false
    assert(selection(pane)=='s3,s4','Shift-click on a title did not select the sibling range')
    assert(pane.selectionBar:IsShown() and pane.selectionBar.label:GetText()=='2 selected','the selection bar does not count the selection')
    local background=pane.canvas.frame;background.scripts.OnMouseUp(background,'LeftButton')
    assert(selection(pane)=='' and not pane.selectionBar:IsShown(),'clicking empty canvas did not clear the selection')
    click(card(pane,'s4'),keys);keys.shift=true;title=card(pane,'s1').title;title.scripts.OnClick(title,'LeftButton');keys.shift=false
    assert(selection(pane)=='s1,s2,s3,s4','Shift-click does not range from the last clicked card')
end)

test('bulk Duplicate, Disable, Enable and Delete each undo in one step and leave branches alone',function()
    local _,_,pane,keys=editor()
    click(card(pane,'s1'),keys);click(card(pane,'s2'),keys,true);click(card(pane,'branch'),keys,true)
    local function rotation() return pane.workspace:Snapshot().rotation end
    local count=#rotation()
    pane.selectionBar.buttons.disable:Click()
    local v=rotation();assert(v[2].disabled==true and v[3].disabled==true and v[1].mode==nil and v[1].disabled==nil,'Disable did not disable just the steps')
    pane.undo:Click();v=rotation();assert(not v[2].disabled and not v[3].disabled,'one Undo did not restore every disabled card')
    pane.selectionBar.buttons.disable:Click();pane.selectionBar.buttons.enable:Click();v=rotation();assert(not v[2].disabled and not v[3].disabled)
    pane.selectionBar.buttons.duplicate:Click();assert(#rotation()==count+3,'Duplicate did not copy every selected card')
    pane.undo:Click();assert(#rotation()==count,'one Undo did not remove every duplicate')
    pane.selectionBar.buttons.remove:Click();v=rotation();assert(#v==count-3 and selection(pane)=='','Delete did not remove the selection')
    pane.undo:Click();assert(#rotation()==count,'one Undo did not restore every deleted card')
end)

test('dragging a selected card moves the selection to one gap as one undo step',function()
    local _,_,pane,keys=editor()
    click(card(pane,'s1'),keys);click(card(pane,'s3'),keys,true)
    pane.canvas:BeginDrag('s3');assert(pane.canvas.drag.ids and #pane.canvas.drag.ids==2,'the drag does not carry the selection')
    local destination,noop
    for _,target in ipairs(pane.canvas.scene.dropTargets) do
        local d=target.destination
        if d.parentId==nil and #d.path==1 and d.path[1]=='rotation' then
            if d.index==6 then destination=target end
            if d.index==2 then noop=target end
        end
    end
    assert(destination and pane.canvas:CanDrop(destination),'the end gap refuses the selection')
    assert(pane.canvas:Drop(destination))
    local order={};for i,step in ipairs(pane.workspace:Snapshot().rotation) do order[i]=step.id end
    assert(table.concat(order,',')=='branch,s2,s4,s1,s3','the selection did not land together at the gap')
    pane.undo:Click();order={};for i,step in ipairs(pane.workspace:Snapshot().rotation) do order[i]=step.id end
    assert(table.concat(order,',')=='branch,s1,s2,s3,s4','one Undo did not restore the order')
end)

test('Shift-drag on empty canvas boxes cards, and Ctrl+Shift adds to the selection',function()
    local f,_,pane,keys=editor()
    local canvas=pane.canvas;local byId={};for _,model in ipairs(canvas.scene.cards) do byId[model.id]=model end
    local s1,s2=byId.s1,byId.s2
    canvas:SelectBox(s1.x+1,s1.y+1,s2.x+1,s2.y+1);assert(selection(pane)=='s1,s2','the box did not select the cards it touches')
    -- The pointer path: Shift-down on the background starts a box, release selects.
    local cursor={x=0,y=0};f.env.GetCursorPosition=function() return cursor.x,cursor.y end
    local child=canvas.child;child.GetLeft=function() return 0 end;child.GetTop=function() return 0 end;child.GetEffectiveScale=function() return 1 end
    local s4=byId.s4;cursor.x,cursor.y=s4.x+2,-(s4.y+2)
    keys.shift=true;keys.ctrl=true;canvas.frame.scripts.OnMouseDown(canvas.frame,'LeftButton');keys.shift=false;keys.ctrl=false
    assert(canvas.box and canvas.boxFrame:IsShown(),'Shift-drag did not start a box')
    cursor.x,cursor.y=s4.x+10,-(s4.y+10);canvas.frame.scripts.OnUpdate(canvas.frame,.01)
    canvas.frame.scripts.OnMouseUp(canvas.frame,'LeftButton')
    assert(not canvas.box and not canvas.boxFrame:IsShown() and selection(pane)=='s1,s2,s4','Ctrl+Shift box did not add to the selection')
end)

test('a read-only rotation can select but offers no bulk edit',function()
    local f,parent=fixture();local a=f.addon;local keys={ctrl=false,shift=false};f.env.IsControlKeyDown=function() return keys.ctrl end;f.env.IsShiftKeyDown=function() return keys.shift end
    local pane=assert(a:CreateRotationEditor(parent,0,'builtin'));assert(pane.workspace.readOnly)
    click(card(pane,'branch'),keys);assert(pane.selectionBar:IsShown())
    for key,button in pairs(pane.selectionBar.buttons) do assert(button:IsEnabled()==(key=='clear'),key..' is available on a read-only rotation') end
    pane.selectionBar.buttons.remove:Click();assert(#pane.workspace:Snapshot().rotation==1)
end)

-- The condition editor already selects with Ctrl/Shift and groups the
-- selection; it gains the same box and Duplicate/Enable/Disable/Delete.
local conditionPrefix=assert(read('tests/condition_editor_ui.lua'):match('^(.-)\ntest%('))
local conditionFixture=assert(loadstring(conditionPrefix..'\nreturn fixture','@condition-bulk-fixture'))()
local function conditions()
    local f=conditionFixture();local a=f.addon
    local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2},{type='NUMBER',number=3}}}
    local shell=a:EditCondition(1,0,root,function() end);return f,a,shell
end
test('condition selection: Duplicate, Disable, Enable and Delete act on every selected card, one undo each',function()
    local _,_,shell=conditions();local canvas=shell.canvas
    canvas:Select({'value',1},false,false);canvas:Select({'value',3},true,false)
    assert(shell.selection_duplicate:IsShown() and shell.selection_remove:IsShown(),'the selection strip has no bulk actions')
    local function values() return shell.active.working.value end
    shell.selection_disable:Click();assert(values()[1].disabled and values()[3].disabled and not values()[2].disabled,'Disable missed a selected card')
    shell.undo:Click();assert(not values()[1].disabled and not values()[3].disabled,'one Undo did not re-enable every card')
    canvas:Select({'value',1},false,false);canvas:Select({'value',3},true,false)
    shell.selection_disable:Click();shell.selection_enable:Click();assert(not values()[1].disabled and not values()[3].disabled)
    canvas:Select({'value',1},false,false);canvas:Select({'value',3},true,false)
    shell.selection_duplicate:Click();assert(#values()==5 and values()[2].number==1 and values()[5].number==3,'Duplicate did not copy each card after itself')
    shell.undo:Click();assert(#values()==3)
    canvas:Select({'value',1},false,false);canvas:Select({'value',3},true,false)
    shell.selection_remove:Click();assert(#values()==1 and values()[1].number==2,'Delete did not remove the selection')
    shell.undo:Click();assert(#values()==3,'one Undo did not restore every deleted card')
end)
test('condition canvas: Shift-drag boxes the cards it touches, Ctrl+Shift adds',function()
    local f,_,shell=conditions();local canvas=shell.canvas
    local byKey={};for _,model in ipairs(canvas.scene.cards) do byKey[table.concat(model.path,'/')]=model end
    local one,two=byKey['value/1'],byKey['value/2']
    canvas:SelectBox(one.x+1,one.y+1,two.x+1,two.y+1);assert(#canvas:Selection()==2,'the box did not select the two cards')
    local cursor={};f.env.GetCursorPosition=function() return cursor.x,cursor.y end
    local child=canvas.child;child.GetLeft=function() return 0 end;child.GetTop=function() return 0 end;child.GetEffectiveScale=function() return 1 end
    local three=byKey['value/3'];cursor.x,cursor.y=three.x+2,-(three.y+2)
    f.env.IsShiftKeyDown=function() return true end;f.env.IsControlKeyDown=function() return true end
    canvas.frame.scripts.OnMouseDown(canvas.frame,'LeftButton');f.env.IsShiftKeyDown=function() return false end;f.env.IsControlKeyDown=function() return false end
    assert(canvas.box,'Shift-drag did not start a box');cursor.x,cursor.y=three.x+20,-(three.y+10);canvas.frame.scripts.OnUpdate(canvas.frame,.01)
    canvas.frame.scripts.OnMouseUp(canvas.frame,'LeftButton')
    assert(not canvas.box and #canvas:Selection()==3,'Ctrl+Shift box did not add the third card')
end)
finish()
