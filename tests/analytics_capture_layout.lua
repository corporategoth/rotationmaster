-- External regression: real settings/layout/buttons; font width is fixture7px/character.
-- This is reproducible offline geometry, not a native font/clipping certification.
local function read(path)local h=assert(io.open(path));local t=h:read('*a');h:close();return t end
local prefix=assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local fixture=assert(loadstring(prefix..'\nreturn fixture','@independent-geometry-settings'))()
local keys={'cast_capture','cast_report'}
local passed,failed=0,0
for _,width in ipairs({380,1000,1100,1200,1400,1800})do
 local ok,message=pcall(function()
  local f,parent=fixture();parent:SetSize(width,600);local a=f.addon
  a.RunCastCaptureAction=function()return true,''end;a.GetCastCaptureStatusText=function()return'Cast capture status: idle'end
  local p=a:OpenNativeSettings(parent,'General');local rects={}
  for _,key in ipairs(keys)do
   local b=assert(p.fields[key],'missing '..key);local caption=b:GetFontString();local extent=caption:GetStringWidth()+12
   assert(extent<=b:GetWidth(),string.format('%s caption+12=%g exceeds button=%g parent=%g column=%s',key,extent,b:GetWidth(),width,tostring(p.columnWidth or p.fullWidth)))
   local anchor=assert(b.point);assert(anchor[1]=='TOPLEFT'and type(anchor[2])=='number'and type(anchor[3])=='number','unknown button anchor shape')
   rects[#rects+1]={key=key,left=anchor[2],right=anchor[2]+b:GetWidth(),top=-anchor[3],bottom=-anchor[3]+b:GetHeight()}
  end
  assert(not p.fields.cast_stop and not p.fields.cast_clear,'cast Stop and Clear buttons are retired')
  assert(rects[2].left==rects[1].left and rects[2].top==rects[1].top+28,'Cast report is not under its capture')
  for i=1,#rects do for j=i+1,#rects do local x,y=rects[i],rects[j]
   assert(not(x.left<y.right and y.left<x.right and x.top<y.bottom and y.top<x.bottom),'overlapping '..x.key..' and '..y.key..' at parent'..width)
  end end
  p:Release()
 end)
 if ok then passed=passed+1;print('PASS parent width'..width)else failed=failed+1;print('FAIL parent width'..width..': '..tostring(message))end
end
print(passed..' passed, '..failed..' failed');os.exit(failed==0 and 0 or 1)
