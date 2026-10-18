local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);local a=f.addon
    a.db.profile.preview_spells=3;a.db.profile.preview_opacity=1
    a.Platform.GetSpellInfo=function(_,id) return {name='Spell '..id,iconID=id+10} end
    f.env.C_Item={GetItemInfo=function(id) return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,id+20 end}
    local h=io.open('UI/preview.lua');if h then h:close();f.load('UI/preview.lua') end
    return f,a
end
test('native preview fits square icons in either direction and resizes with fixed proportions',function()
    local _,a=fixture();assert(a.CreateNativePreviewWindow,'native preview missing');local w=a:CreateNativePreviewWindow()
    assert(w.frame:GetWidth()==200 and w.frame:GetHeight()==92 and not w.status)
    w:AddRecommendation(403);w:AddRecommendation(8042);assert(w.icons[1]:GetWidth()==64 and w.icons[1].texture:GetTexture()==413)
    w:Resize(296,124);assert(w.iconSize==96 and w.frame:GetWidth()==296 and w.frame:GetHeight()==124 and w.icons[1]:GetWidth()==96)
    a.db.profile.preview_vertical=true;w:Configure();assert(w.frame:GetWidth()==104 and w.frame:GetHeight()==316)
    assert(w.icons[2].point[4]==4 and w.icons[2].point[5]==-120)
end)
test('transparent and locked previews retain icons without blank mouse intercepts or resize callbacks',function()
    local _,a=fixture();assert(a.CreateNativePreviewWindow);local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
    local moves,resizes=0,0;w.frame.StartMoving=function() moves=moves+1 end;w.frame.StartSizing=function() resizes=resizes+1 end
    a.db.profile.preview_locked=true;w:Configure();w.header.scripts.OnDragStart(w.header);w.grip.scripts.OnMouseDown(w.grip,'LeftButton');assert(moves==0 and resizes==0)
    a.db.profile.preview_opacity=0;w:Configure();assert(not w.header:IsShown() and not w.grip:IsShown() and w.icons[1]:IsShown() and w.icons[1]:GetAlpha()==1 and w.frame:GetHeight()==64)
end)
test('native preview pools icons handles item identity and rejects stale profile callbacks',function()
    local f,a=fixture();assert(a.CreateNativePreviewWindow);local w=a:CreateNativePreviewWindow();w:AddRecommendation(6603,123)
    local icon=w.icons[1];assert(icon.itemId==123 and icon.texture:GetTexture()==143)
    w:ReleaseChildren();assert(not icon:IsShown() and not icon.scripts.OnEnter);w:AddRecommendation(403);assert(w.icons[1]==icon and not icon.itemId)
    local close=w.close.scripts.OnClick;a.db.profile={preview_spells=2};close();assert(a.db.profile.preview_spells==2)
    w:Release();assert(not w.frame:IsShown() and not icon.scripts.OnEnter)
    w=a:CreateNativePreviewWindow();assert(w.active and w.profile==a.db.profile);w.close:Click();assert(a.db.profile.preview_spells==0 and not a.nextWindow)
end)
test('preview count direction axis resizing and saved movement remain consistent across profiles',function()
    local f,a=fixture();local profile=a.db.profile
    for n=1,5 do for _,vertical in ipairs({false,true}) do
        profile.preview_spells=n;profile.preview_vertical=vertical;profile.preview_icon_size=64
        local w=a:CreateNativePreviewWindow();assert(w.frame:GetWidth()==(vertical and 1 or n)*64+8 and w.frame:GetHeight()==(vertical and n or 1)*64+28)
        w:Resize(w.frame:GetWidth(),(vertical and n or 1)*80+28);assert(w.iconSize==80)
    end end
    local w=a.nextWindow;w.frame.GetPoint=function() return 'TOPLEFT',f.env.UIParent,'TOPLEFT',100,-50 end;w.header.scripts.OnDragStop();assert(profile.preview_window.xoffs==100 and profile.preview_window.yoffs==-50)
    w:Release();w=a:CreateNativePreviewWindow();assert(w.frame.point[1]=='TOPLEFT' and w.frame.point[4]==100 and w.frame.point[5]==-50)
    local stale=w.header.scripts.OnDragStop;a.db.profile={preview_spells=1};stale();assert(not a.db.profile.preview_window)
    a:RefreshPreviewWindow();assert(a.nextWindow.profile==a.db.profile);a.db.profile.preview_spells=0;a:RefreshPreviewWindow();assert(not a.nextWindow and not w.frame:IsShown())
end)
finish()
