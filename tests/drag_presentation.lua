local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local file=io.open('UI/drag_presentation.lua');if file then file:close();f.load('UI/drag_presentation.lua') end
    local parent=create('Frame');parent:SetSize(1000,800)
    local entries={}
    for i=1,2 do local card=create('Frame',nil,parent);card:SetSize(300,80);card:SetFrameLevel(7);card:SetPoint('TOPLEFT',parent,'TOPLEFT',10+(i-1)*20,-20-(i-1)*100);entries[i]={frame=card,x=10+(i-1)*20,y=20+(i-1)*100,width=300,height=80} end
    return f,parent,entries
end
test('live drag uses the real frames and gray placeholders and Hide restores their exact owners',function()
    local f,parent,entries=fixture();local ghost=f.addon:CreateWorkbenchDragCard();assert(ghost.PresentCards,'live card presentation missing')
    ghost:Present('Title','Summary',parent,2);assert(ghost:PresentCards(entries,parent,{{points={{x=160,y=100},{x=180,y=120}},tone='neutral'}}))
    assert(ghost.label:IsShown()==false and ghost.summary:IsShown()==false)
    for i,entry in ipairs(entries) do assert(entry.frame:GetParent()==ghost and ghost.placeholders[i]:IsShown() and ghost.placeholders[i]:GetParent()==parent) end
    assert(ghost:GetWidth()==320 and ghost:GetHeight()==180 and ghost.previewLines[1]:IsShown())
    ghost:Hide()
    for i,entry in ipairs(entries) do assert(entry.frame:GetParent()==parent and entry.frame.point[4]==entry.x and entry.frame.point[5]==-entry.y and entry.frame:GetFrameLevel()==7 and not ghost.placeholders[i]:IsShown()) end
    assert(not ghost.previewLines[1]:IsShown() and not ghost.liveEntries)
end)
test('live card motion retains the grab offset and a replacement presentation restores old cards',function()
    local f,parent,entries=fixture();local ghost=f.addon:CreateWorkbenchDragCard();assert(ghost.PresentCards)
    local x,y=400,450;f.env.GetCursorPosition=function() return x,y end
    entries[1].frame.GetLeft=function() return 300 end;entries[1].frame.GetTop=function() return 500 end
    ghost:Present('Title','Summary',parent,2);ghost:PresentCards(entries,parent)
    assert(ghost.point[4]==300 and ghost.point[5]==500,'grab point jumped to a tooltip offset')
    x=450;y=475;ghost:FollowPointer();assert(ghost.point[4]==350 and ghost.point[5]==525)
    ghost:Present('Palette','Insert',parent,1)
    assert(entries[1].frame:GetParent()==parent and not ghost.liveEntries and ghost.label:IsShown() and ghost:GetWidth()==340)
end)
test('a partial native reparent failure restores every earlier card before reporting failure',function()
    local f,parent,entries=fixture();local ghost=f.addon:CreateWorkbenchDragCard();assert(ghost.PresentCards)
    local original=entries[2].frame.SetParent
    entries[2].frame.SetParent=function(self,nextParent) if nextParent==ghost then error('native reparent failed') end;original(self,nextParent) end
    ghost:Present('Title','Summary',parent,2);local ok=pcall(ghost.PresentCards,ghost,entries,parent)
    assert(not ok and entries[1].frame:GetParent()==parent and entries[2].frame:GetParent()==parent and not ghost.liveEntries)
end)
test('drag cancellation owns Escape and preserves all original native anchors',function()
    local f,parent,entries=fixture();f.env.UISpecialFrames={};local a=f.addon;local ghost=a:CreateWorkbenchDragCard();local frame=entries[1].frame
    local anchor={'TOPRIGHT',parent,'TOPRIGHT',-15,-20};frame.GetNumPoints=function() return 1 end;frame.GetPoint=function() return unpack(anchor) end
    ghost:Present('Palette','Insert',parent);ghost:PresentSource(frame);local canceled=false;ghost:CaptureCancel(function() canceled=true;ghost:Hide() end)
    ghost.cancelOwner:Hide();assert(canceled and frame:GetParent()==parent and frame.point[1]=='TOPRIGHT' and frame.point[4]==-15 and not ghost.liveEntries)
end)
finish()
