-- Exact capture-only additions before unchanged historical whole-source proofs.
local rows={['main.lua']={bytes=87884,hash='28b84d73',oldBytes=86781,oldHash='5c9d4420',changes={{at=31,current=[====[-- BEGIN ANALYTICS ADVICE HANDOFF
local adviceCapture
if addon.BindAnalyticsAdviceCapture then
 addon:BindAnalyticsAdviceCapture(function(sink)adviceCapture=sink end)
end
-- END ANALYTICS ADVICE HANDOFF
]====],previous=[====[]====]},{at=38438,current=[====[    -- BEGIN ANALYTICS DISABLE
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return nil,nil,false end
    end
    -- END ANALYTICS DISABLE
]====],previous=[====[]====]},{at=42231,current=[====[    -- BEGIN ANALYTICS ERROR
    if adviceCapture then
        adviceCapture("retire")
        if not activeChangeCurrent(self,change) then return end
    end
    -- END ANALYTICS ERROR
]====],previous=[====[]====]},{at=50107,current=[====[                    -- BEGIN ANALYTICS PRIMARY ADVICE
                    if adviceCapture then
                        adviceCapture("advice",previewWindow,current,cond.type,spellid)
                        if not current() then return end
                    end
                    -- END ANALYTICS PRIMARY ADVICE
]====],previous=[====[]====]},{at=52217,current=[====[                -- BEGIN ANALYTICS EMPTY ADVICE
                if adviceCapture then adviceCapture("retire");if not current() then return end end
                -- END ANALYTICS EMPTY ADVICE
]====],previous=[====[]====]}}},
['UI/preview.lua']={bytes=18254,hash='e169468f',oldBytes=14343,oldHash='0e5de5c8',changes={{at=83,current=[====[-- BEGIN ANALYTICS PREVIEW HANDOFF
local previewCapture
local previewEnvironment=getfenv(1)
local previewType,previewRaw=type,rawget
---@type any
local previewFunctionEnvironment=getfenv
if addon.BindAnalyticsPreviewCapture then
 addon:BindAnalyticsPreviewCapture(function(sink)previewCapture=sink end)
end
-- END ANALYTICS PREVIEW HANDOFF
]====],previous=[====[]====]},{at=3231,current=[====[        local nativeValid=window.Valid
]====],previous=[====[]====]},{at=9237,current=[====[        local nativeAddRecommendation
]====],previous=[====[]====]},{at=9611,current=[====[            local captureGeneration,captureProfile,captureFrame,captureIcons,captureTexture
            if previewCapture then
                captureGeneration,captureProfile=self.generation,self.profile
                captureFrame,captureIcons,captureTexture=self.frame,self.icons,icon.texture
            end
]====],previous=[====[]====]},{at=10897,current=[====[            -- BEGIN ANALYTICS PREVIEW DELIVERY
            if previewCapture and index==1 and self.AddRecommendation==nativeAddRecommendation then
                local owner,profile,generation=self,captureProfile,captureGeneration
                local frame,icons,texture=captureFrame,captureIcons,captureTexture
                local frameVisible,iconVisible,textureGet,displayId,observed
                -- Pure captured-state checks run again after every native read.
                -- Initial property reads are inside the collector's protected call.
                local function eligible()
                    return owner.Valid==nativeValid and previewFunctionEnvironment(nativeAddRecommendation)==previewEnvironment
                        and nativeValid(owner) and owner.profile==profile and owner.generation==generation
                        and owner.AddRecommendation==nativeAddRecommendation and owner.frame==frame and owner.icons==icons
                        and icons[1]==icon and icon.texture==texture and not icon.sample and icon.spellId==spellId
                        and icon.itemId==nil and itemId==nil and previewType(info)=='table'
                        and previewType(displayId)=='number' and displayId==displayId and displayId>0 and displayId<math.huge
                        and previewRaw(info,'iconID')==displayId and frame.IsVisible==frameVisible and icon.IsVisible==iconVisible
                        and previewType(frameVisible)=='function' and previewType(iconVisible)=='function'
                        and texture.GetTexture==textureGet and previewType(textureGet)=='function'
                end
                previewCapture("delivery",self,function()
                    if not observed then
                        frameVisible,iconVisible,textureGet=frame.IsVisible,icon.IsVisible,texture.GetTexture
                        if previewType(info)=='table' then displayId=previewRaw(info,'iconID') end
                        observed=true
                    end
                    if not eligible() then return 'retired' end
                    local frameShown,iconShown=frameVisible(frame),iconVisible(icon)
                    local rendered=textureGet(texture)
                    if not eligible() or rendered~=displayId then return 'retired' end
                    if frameShown==true and iconShown==true then return 'visible' end
                    if frameShown==false or iconShown==false then return 'hidden' end
                    return 'unknown'
                end,nil,spellId)
            end
            -- END ANALYTICS PREVIEW DELIVERY
]====],previous=[====[]====]},{at=13523,current=[====[        nativeAddRecommendation=window.AddRecommendation
]====],previous=[====[]====]},{at=13910,current=[====[        function window:Hide()
            if previewCapture then
                local generation,profile=self.generation,self.profile;previewCapture("retire",self)
                if self.generation~=generation or self.profile~=profile then return end
            end
            self.frame:Hide()
        end
        function window:Release()
            if previewCapture then
                local generation,profile=self.generation,self.profile;previewCapture("retire",self)
                if self.generation~=generation or self.profile~=profile then return end
            end
            if sampleProfile==self.profile then sampleProfile=nil end;self.sampleBatch=false;self:ReleaseChildren();self.active=false;self.frame:StopMovingOrSizing();self.frame:Hide();if addon.ReleaseMasquePreview then addon:ReleaseMasquePreview(self) end end
]====],previous=[====[        function window:Hide() self.frame:Hide() end
        function window:Release() if sampleProfile==self.profile then sampleProfile=nil end;self.sampleBatch=false;self:ReleaseChildren();self.active=false;self.frame:StopMovingOrSizing();self.frame:Hide();if addon.ReleaseMasquePreview then addon:ReleaseMasquePreview(self) end end
]====]}}},
['Platform/analytics_casts.lua']={bytes=18603,hash='58d88fbc',oldBytes=14129,oldHash='27eda69e',changes={{at=535,current=[====[-- BEGIN ANALYTICS PREVIEW HANDOFF
-- Two fixed source producers, consumed during normal TOC startup. No listeners.
local installAdvice,installPreview,armed
function addon:BindAnalyticsAdviceCapture(install)
 if not rawequal(self,addon)or installAdvice or type(install)~='function'then return false end
 installAdvice=install;addon.BindAnalyticsAdviceCapture=nil;return true
end
function addon:BindAnalyticsPreviewCapture(install)
 if not rawequal(self,addon)or installPreview or type(install)~='function'then return false end
 installPreview=install;addon.BindAnalyticsPreviewCapture=nil;return true
end
local function disarm(s)
 if armed~=s then return end
 armed=nil
 if installAdvice then installAdvice(nil)end
 if installPreview then installPreview(nil)end
 s.advice=nil
end
-- END ANALYTICS PREVIEW HANDOFF
]====],previous=[====[]====]},{at=3743,current=[====[  nativeAcceptance='unverified',runtimeVerified=false,advice=s.adviceProducer and'primary-publisher-receipts'or'not-wired',presentation=s.previewProducer and'owned-native-preview-boundaries'or'not-wired',ordinary='unavailable',autorepeat='unassociated',damage='unavailable',capture=capture}
]====],previous=[====[  nativeAcceptance='unverified',runtimeVerified=false,advice='not-wired',presentation='not-wired',ordinary='unavailable',autorepeat='unassociated',damage='unavailable',capture=capture}
]====]},{at=5699,current=[====[ -- BEGIN ANALYTICS PREVIEW RETIRE
 disarm(s)
 -- END ANALYTICS PREVIEW RETIRE
]====],previous=[====[]====]},{at=8437,current=[====[-- BEGIN ANALYTICS PREVIEW RECEIPTS
local function pushEvidence(s,row)
 local seq,why=s.builder:Push(s.builderLease,s.elapsed,row);fence(s)
 if active~=s or s.phase~='running'then fail('retired-operation')end
 if not seq then fail(why or'builder-error')end
 return seq
end
local function retireEvidence(s)
 local a=s.advice
 clock(s)
 if not rawequal(s.advice,a)then return end
 s.advice=nil;s.epoch=(s.epoch or 1)+1
 pushEvidence(s,{type='retire',reason='context'})
end
local function checkAdvice(s)
 local a=s.advice
 if not a then return end
 local valid=call(s,a.current)
 if not rawequal(s.advice,a)then return end
 if valid~=true then retireEvidence(s);return end
 if a.visible then
  local visible=call(s,a.visible)
  if not rawequal(s.advice,a)then return end
  if visible~='visible'then retireEvidence(s)end
 end
end
local function producer(s,event,window,witness,kind,spell)
 if active~=s or s.phase~='running'then return end
 local ok,why=pcall(function()
  if event=='retire'then
   if s.advice and(window==nil or rawequal(window,s.advice.window))then retireEvidence(s)end
  elseif event=='advice'then
   if type(witness)~='function'or call(s,witness)~=true then return end
   clock(s);if call(s,witness)~=true then return end
   local action=kind=='spell'and'spell'or'unmodeled'
   if action=='spell'and(not finite(spell)or spell<=0 or spell%1~=0)then fail('invalid-receipt')end
   local row={type='advice',epoch=s.epoch or 1,action=action};if action=='spell'then row.spell=spell end
   local seq=pushEvidence(s,row)
   s.advice={seq=seq,spell=spell,window=window,current=witness,action=action}
  elseif event=='delivery'then
   local a=s.advice
   if not a or a.action~='spell'or not rawequal(a.window,window)or a.spell~=spell or a.ack then return end
   local valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   local state=call(s,witness)
   if not rawequal(s.advice,a)then return end
   if state=='retired'then retireEvidence(s);return end
   if state~='visible'and state~='hidden'then state='unknown'end
   clock(s)
   if not rawequal(s.advice,a)then return end
   valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   -- Visibility callbacks may themselves retire a window or start a new poll.
   local repeated=call(s,witness)
   if not rawequal(s.advice,a)then return end
   if repeated=='retired'then retireEvidence(s);return end
   if repeated~=state then state='unknown'end
   valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   pushEvidence(s,{type='presentation',adviceSeq=a.seq,state=state})
   a.ack=true;if state=='visible'then a.visible=witness end
  end
 end)
 if not ok and current(s)and active==s then abort(s,issue(why))end
end
local function arm(s)
 if not installAdvice then return end
 armed=s;s.previewProducer=installPreview~=nil;s.adviceProducer=true
 local sink=function(...)producer(s,...)end
 installAdvice(sink);if installPreview then installPreview(sink)end
end
-- END ANALYTICS PREVIEW RECEIPTS
]====],previous=[====[]====]},{at=12119,current=[====[  -- BEGIN ANALYTICS PREVIEW ATTEMPT
  checkAdvice(s)
  -- END ANALYTICS PREVIEW ATTEMPT
]====],previous=[====[]====]},{at=12386,current=[====[   r.type='attempt';r.epoch=s.epoch or 1;r.phase=event=='UNIT_SPELLCAST_SENT'and'sent'or'start'
]====],previous=[====[   r.type='attempt';r.epoch=1;r.phase=event=='UNIT_SPELLCAST_SENT'and'sent'or'start'
]====]},{at=13895,current=[====[  s.builder=assert(newCapture());s.builderLease=assert(s.builder:Start({family='tbc',actor='player',ordinaryEvidence='unavailable',presentationEvidence=installAdvice and installPreview and'trusted-receipt'or'unavailable'}));fence(s)
]====],previous=[====[  s.builder=assert(newCapture());s.builderLease=assert(s.builder:Start({family='tbc',actor='player',ordinaryEvidence='unavailable',presentationEvidence='unavailable'}));fence(s)
]====]},{at=17004,current=[====[  -- BEGIN ANALYTICS PREVIEW ARM
  arm(s)
  -- END ANALYTICS PREVIEW ARM
]====],previous=[====[]====]},{at=17853,current=[====[ -- BEGIN ANALYTICS PREVIEW CLEAR
 if s then disarm(s)end
 -- END ANALYTICS PREVIEW CLEAR
]====],previous=[====[]====]}}},
['UI/analytics_capture.lua']={bytes=9682,hash='605a47d3',oldBytes=8006,oldHash='239897df',changes={{at=3514,current=[====[  snapshot.advice=='primary-publisher-receipts'and L['Advice/presentation rows describe observed delivery boundaries only; ordinary-cast proof: not available.']or L['Advice: not available; presentation: not available; ordinary-cast proof: not available.'],
]====],previous=[====[  L['Advice: not available; presentation: not available; ordinary-cast proof: not available.'],
]====]},{at=4978,current=[====[ local coverage={advice=0,presentation=0,visible=0,hidden=0,unknown=0,retired=0}
]====],previous=[====[]====]},{at=5196,current=[====[  if row.type=='advice'then coverage.advice=coverage.advice+1
  elseif row.type=='retire'then coverage.retired=coverage.retired+1
  elseif row.type=='presentation'then coverage.presentation=coverage.presentation+1;local state=token(row.state,{visible=true,hidden=true,unknown=true});coverage[state]=coverage[state]+1 end
]====],previous=[====[]====]},{at=6359,current=[====[ if snapshot.advice=='primary-publisher-receipts'then
  lines[#lines+1]=string.format(L['Coverage rows: advice=%d presentation=%d visible=%d hidden=%d unknown=%d retired=%d (not opportunities).'],coverage.advice,coverage.presentation,coverage.visible,coverage.hidden,coverage.unknown,coverage.retired)
  lines[#lines+1]=L['Visible means RM-owned preview frame state at a delivery boundary; it does not prove perception or native pixel rendering.']
 end
]====],previous=[====[]====]},{at=6863,current=[====[  if row.type=='advice'then
   lines[#lines+1]=string.format('seq=%s time=%s advice action=%s spell=%s epoch=%s',number(row.seq),number(row.time),token(row.action,{spell=true,unmodeled=true,none=true,unknown=true}),number(row.spell),number(row.epoch))
  elseif row.type=='presentation'then
   lines[#lines+1]=string.format('seq=%s time=%s presentation adviceSeq=%s state=%s',number(row.seq),number(row.time),number(row.adviceSeq),token(row.state,{visible=true,hidden=true,unknown=true}))
  elseif row.type=='retire'then
   lines[#lines+1]=string.format('seq=%s time=%s retire reason=%s',number(row.seq),number(row.time),token(row.reason,reasons))
  else
]====],previous=[====[]====]},{at=7832,current=[====[  end
]====],previous=[====[]====]}}}}
local function hash(s)local n=0;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
return function(text,path)
 text=dofile('tests/fixtures/restore_analytics_start_witness.lua')(text,path)
 if path=='main.lua' and text:find('self:DispatchAnnouncement(ent,nil,currentSpells[castguid])',1,true) then text=dofile('tests/fixtures/restore_announcement_emotes.lua')(text,path) end
 local r=rows[path];if not r then return text end
 assert(#text==r.bytes and hash(text)==r.hash,'unrelated analytics-preview source: '..path)
 for i=#r.changes,1,-1 do local c=r.changes[i];assert(text:sub(c.at,c.at+#c.current-1)==c.current,'analytics-preview addition mismatch');text=text:sub(1,c.at-1)..c.previous..text:sub(c.at+#c.current)end
 assert(#text==r.oldBytes and hash(text)==r.oldHash,'analytics-preview predecessor mismatch')
 return text
end
