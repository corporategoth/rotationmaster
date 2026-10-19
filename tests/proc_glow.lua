local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local startAtlas='UI-HUD-ActionBar-Proc-Start-Flipbook';local loopAtlas='UI-HUD-ActionBar-Proc-Loop-Flipbook'
local function fixture(mode)
    local f=F.new();local a,e=f.addon,f.env;local calls={start={},stop={},pixel={}};local probes=0
    local glow={PixelGlow_Stop=function() end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end,
        PixelGlow_Start=function(...) calls.pixel[#calls.pixel+1]={...} end,
        ProcGlow_Start=function(frame,options)
            if mode=='start-error' then error('start failed') end
            calls.start[#calls.start+1]={frame=frame,options=options};frame['proc:'..options.key]=true
            setmetatable(options,{__index={duration=1}}) -- actual library owns this transient options table
        end,
        ProcGlow_Stop=function(frame,key) calls.stop[#calls.stop+1]=key;frame['proc:'..key]=nil end}
    f.libraries['LibCustomGlow-1.0']=glow
    local stub=e.LibStub;e.LibStub=function(name,...) if name=='LibCustomGlow-1.0' then return glow end;return stub(name,...) end
    e.C_Texture={GetAtlasInfo=function(name)
        if mode=='atlas-error' then error('atlas unavailable') end
        if mode=='no-atlas' and name==loopAtlas then return nil end
        assert(name==startAtlas or name==loopAtlas);return {width=150,height=150}
    end}
    if mode=='no-api' then e.C_Texture=nil;e.GetAtlasInfo=nil end
    if mode=='legacy-api' then e.GetAtlasInfo=e.C_Texture.GetAtlasInfo;e.C_Texture=nil end
    local create=e.CreateFrame
    e.CreateFrame=function(...)
        probes=probes+1;local frame=create(...)
        function frame:GetSize() return self:GetWidth(),self:GetHeight() end
        local texture=frame.CreateTexture;function frame:CreateTexture(...)
            local region=texture(self,...);function region:SetAtlas(name) assert(name==startAtlas or name==loopAtlas);self.atlas=name end
            function region:SetDesaturated(value) self.desaturated=value end
            function region:SetBlendMode(value) self.blend=value end;return region
        end
        function frame:CreateAnimationGroup()
            local group={scripts={}}
            function group:Stop() self.playing=false end
            function group:Play() self.playing=true;self.plays=(self.plays or 0)+1 end
            function group:IsPlaying() return self.playing==true end
            function group:GetParent() return frame end
            function group:SetLooping(value) self.loop=value end
            function group:SetToFinalAlpha(value) self.finalAlpha=value end
            function group:SetScript(event,callback) self.scripts[event]=callback end
            function group:CreateAnimation(kind)
                if mode=='no-flipbook' and kind=='FlipBook' then error('unsupported animation') end
                local animation={}
                for _,key in ipairs({'SetChildKey','SetDuration','SetOrder','SetFromAlpha','SetToAlpha','SetFlipBookRows','SetFlipBookColumns','SetFlipBookFrames','SetFlipBookFrameWidth','SetFlipBookFrameHeight'}) do
                    local field=key;animation[key]=function(self,value) self[field..'Value']=value end
                end
                return animation
            end
            return group
        end
        return frame
    end
    f.load('Core/presentation.lua');f.load('buttons.lua')
    a.index=function(values,want) for i,value in ipairs(values) do if value==want then return i end end end
    return f,a,calls,function() return probes end
end
test('Proc capability checks atlases and native animation once per unchanged provider',function()
    local _,a,_,probes=fixture();assert(a.GetProcGlowSupport,'Proc Glow support service missing')
    assert(a:GetProcGlowSupport());local count=probes();assert(count==1)
    for _=1,20 do assert(a:GetProcGlowSupport()) end;assert(probes()==count,'warm support queries allocated probes')
end)
test('legacy atlas lookup is probed and changed API identities invalidate support cache',function()
    local f,a=fixture('legacy-api');assert(a:GetProcGlowSupport())
    f.env.GetAtlasInfo=function() return nil end;assert(not a:GetProcGlowSupport(),'stale capability survived API replacement')
end)
test('missing atlas API or FlipBook support selects keyed Pixel fallback without throwing',function()
    for _,mode in ipairs({'no-api','no-atlas','atlas-error','no-flipbook'}) do
        local _,a,calls=fixture(mode);assert(a.GetProcGlowSupport,'Proc Glow support service missing');assert(not a:GetProcGlowSupport())
        local frame={};a:ApplyCustomGlow({type='proc'},frame,'next',{r=.1,g=.2,b=.3,a=.4},2,-3)
        assert(#calls.start==0 and #calls.pixel==1 and calls.pixel[1][1]==frame and calls.pixel[1][10]=='next')
    end
end)
test('Proc start carries complete appearance and timing without mutating stored effect',function()
    local _,a,calls=fixture();local frame={};local effect={type='proc',duration=1.75,startAnim=true}
    a:ApplyCustomGlow(effect,frame,'cooldown',{r=.1,g=.2,b=.3,a=.4},2,-3)
    local call=assert(calls.start[1],'Proc effect never started');local options=call.options
    assert(call.frame==frame and options.key=='cooldown' and options.duration==1.75 and options.startAnim==true)
    assert(options.color[1]==.1 and options.color[4]==.4 and options.xOffset==2 and options.yOffset==-3)
    assert(getmetatable(effect)==nil and effect.key==nil and effect.color==nil)
end)
test('keyed Proc refresh preserves animation while hide stops only that key',function()
    local _,a,calls=fixture();local frame={};local effect={type='proc'}
    a:Glow(frame,'first',effect,{r=1,g=1,b=1,a=1},1,'CENTER',0,0)
    a:Glow(frame,'second',effect,{r=1,g=1,b=1,a=1},1,'CENTER',0,0)
    local count=#calls.stop;a:Glow(frame,'first',effect,{r=0,g=1,b=1,a=1},1,'CENTER',0,0)
    assert(#calls.stop==count and #calls.start==3,'refresh restarted a running Proc key')
    a:HideGlow(frame,'first');assert(not frame['proc:first'] and frame['proc:second'] and calls.stop[#calls.stop]=='first')
end)
test('switching away from Proc stops its key and keeps the existing effect route',function()
    local _,a,calls=fixture();local frame={}
    a:Glow(frame,'next',{type='proc'},nil,1,'CENTER',0,0);assert(frame['proc:next'])
    a:Glow(frame,'next',{type='pixel'},nil,1,'CENTER',0,0)
    assert(not frame['proc:next'] and #calls.pixel==1)
end)
test('failed Proc start retires support and falls back without retrying every poll',function()
    local _,a,calls=fixture('start-error');local frame={}
    local effect={type='proc'};a:ApplyCustomGlow(effect,frame,'next',nil,0,0)
    assert(#calls.pixel==1 and not a:GetProcGlowSupport())
    a:ApplyCustomGlow(effect,frame,'next',nil,0,0);assert(#calls.pixel==2)
end)
test('global capability retirement clears an old Proc key before its Pixel fallback',function()
    local f,a,calls=fixture();local glow=f.libraries['LibCustomGlow-1.0'];local start=glow.ProcGlow_Start
    local first,failed={},{};glow.ProcGlow_Start=function(frame,options) if frame==failed then error('provider failed') end;return start(frame,options) end
    local effect={type='proc'};a:Glow(first,'next',effect,nil,1,'CENTER',0,0);a:Glow(first,'other',effect,nil,1,'CENTER',0,0)
    a:Glow(failed,'next',effect,nil,1,'CENTER',0,0);assert(not a:GetProcGlowSupport())
    a:Glow(first,'next',effect,nil,1,'CENTER',0,0)
    assert(not first['proc:next'] and first['proc:other'],'Pixel fallback retained old Proc or removed another key')
    assert(#calls.pixel==2)
end)
test('actual bundled Proc library reuses keyed frames and keeps the active loop on refresh',function()
    local f,a=fixture();local e=f.env;local glow=f.libraries['LibCustomGlow-1.0'];local stub=e.LibStub
    e.LibStub=setmetatable({NewLibrary=function(_,name) assert(name=='LibCustomGlow-1.0');return glow,0 end},{__call=function(_,name,...) if name=='Masque' then return nil end;return stub(name,...) end})
    e.tinsert,e.tremove=table.insert,table.remove;e.min,e.max,e.floor=math.min,math.max,math.floor
    e.CreateTexturePool=function() return {} end
    e.CreateFramePool=function(kind,parent,template,reset)
        local pool={active={},inactive={},created=0}
        function pool:Acquire()
            local frame=table.remove(self.inactive);local new=frame==nil
            if new then frame=e.CreateFrame(kind,nil,parent,template);self.created=self.created+1;reset(self,frame) end
            self.active[frame]=true;return frame,new
        end
        function pool:Release(frame) assert(self.active[frame],'double pool release');self.active[frame]=nil;reset(self,frame);self.inactive[#self.inactive+1]=frame end
        return pool
    end
    f.load('Libs/LibCustomGlow-1.0/LibCustomGlow-1.0.lua')
    local target=e.CreateFrame('Frame',nil,e.UIParent);target:SetSize(40,40)
    local effect={type='proc',duration=1.75};a:Glow(target,'first',effect,nil,1,'CENTER',2,3)
    local first=assert(target._ProcGlowfirst,'actual library did not attach Proc frame')
    assert(first.ProcLoopAnim:IsPlaying() and first.ProcLoopAnim.flipbookRepeat.SetDurationValue==1.75)
    local plays=first.ProcLoopAnim.plays
    a:Glow(target,'first',effect,{r=.2,g=.3,b=.4,a=.5},1,'CENTER',2,3)
    assert(target._ProcGlowfirst==first and first.ProcLoopAnim.plays==plays,'refresh restarted actual loop')
    assert(first.ProcLoop.color[1]==.2 and first.ProcLoop.color[4]==.5)
    a:Glow(target,'second',effect,nil,1,'CENTER',0,0);local second=assert(target._ProcGlowsecond)
    a:HideGlow(target,'first');assert(not target._ProcGlowfirst and target._ProcGlowsecond==second and not first.ProcLoopAnim:IsPlaying())
    a:Glow(target,'first',effect,nil,1,'CENTER',0,0);assert(target._ProcGlowfirst==first and glow.ProcGlowPool.created==2)
    a:HideGlow(target,'first');a:HideGlow(target,'second');assert(next(glow.ProcGlowPool.active)==nil)
    effect.startAnim=true;a:Glow(target,'burst',effect,nil,1,'CENTER',0,0)
    local burst=assert(target._ProcGlowburst);assert(burst.ProcStartAnim:IsPlaying() and not burst.ProcLoopAnim:IsPlaying())
    burst.ProcStartAnim:Stop();burst.ProcStartAnim.scripts.OnFinished(burst.ProcStartAnim)
    assert(burst.ProcLoopAnim:IsPlaying());a:HideGlow(target,'burst');assert(next(glow.ProcGlowPool.active)==nil)
end)
finish()
