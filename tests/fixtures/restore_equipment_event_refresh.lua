-- Exact complete cfce28f equipment stage inverse; author69c checkpoint stays frozen.
local changes={
{at=586,current=([========[!-- BEGIN EQUIPMENT EVENT LIFETIME
local equipmentSubscription
local equipmentCoordinator=addon.GetScopedRotationCoordinator
-- END EQUIPMENT EVENT LIFETIME
]========]):sub(2),previous=([========[!]========]):sub(2)},
{at=29026,current=([========[!    if type(validEvent)~='function' then return activeChangeCurrent(owner,change),false end
]========]):sub(2),previous=([========[!    if type(validEvent)~='function' then return activeChangeCurrent(owner,change) end
]========]):sub(2)},
{at=29228,current=([========[!    if ok and valid==true then local current=activeCall(owner,change,'RegisterEvent',event);return current,current end
    return true,false
]========]):sub(2),previous=([========[!    if ok and valid==true then return activeCall(owner,change,'RegisterEvent',event) end
    return true
]========]):sub(2)},
{at=29565,current=([========[!    -- BEGIN EQUIPMENT ENABLE LIFETIME
    equipmentSubscription=nil
    local equipmentProfile=self.db.profile
    local equipmentRegistered=false
    -- END EQUIPMENT ENABLE LIFETIME
]========]):sub(2),previous=([========[!]========]):sub(2)},
{at=30818,current=([========[!        -- BEGIN EQUIPMENT EVENT REGISTRATION
        local current,registered=registerOptionalEvent(self,change,'PLAYER_EQUIPMENT_CHANGED')
        if not current then return end
        equipmentRegistered=registered
        -- END EQUIPMENT EVENT REGISTRATION
]========]):sub(2),previous=([========[!]========]):sub(2)},
{at=31492,current=([========[!    -- BEGIN EQUIPMENT ENABLE COMMIT
    if not activeCall(self,change,'EnableRotation') then return end
    if equipmentRegistered and self.db.profile==equipmentProfile and activeChangeCurrent(self,change) then
        equipmentSubscription={}
    end
    -- END EQUIPMENT ENABLE COMMIT
]========]):sub(2),previous=([========[!    activeCall(self,change,'EnableRotation')
]========]):sub(2)},
{at=31959,current=([========[!    -- BEGIN EQUIPMENT DISABLE LIFETIME
    equipmentSubscription=nil
    -- END EQUIPMENT DISABLE LIFETIME
]========]):sub(2),previous=([========[!]========]):sub(2)},
{at=65946,current=([========[!    PLAYER_EQUIPMENT_CHANGED=true,
]========]):sub(2),previous=([========[!]========]):sub(2)},
{at=72227,current=([========[!-- BEGIN EQUIPMENT EVENT DISPATCH
local equipmentEvent = wrapEvent(function(self,_,subscription,profile,change)
    if self~=addon or equipmentSubscription~=subscription or self.db.profile~=profile
        or not activeChangeCurrent(self,change) then return end
    local coordinator
    if self.GetScopedRotationCoordinator~=equipmentCoordinator or not activeChangeCurrent(self,change) then return end
    if equipmentCoordinator then coordinator=equipmentCoordinator(self) end
    local function current()
        if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription
            or self.db.profile~=profile or self.GetScopedRotationCoordinator~=equipmentCoordinator then return false end
        if equipmentCoordinator and equipmentCoordinator(self)~=coordinator then return false end
        return self.db.profile==profile and self.GetScopedRotationCoordinator==equipmentCoordinator
            and activeChangeCurrent(self,change) and equipmentSubscription==subscription
    end
    if not current() or self.enabledState~=true or not current() then return end
    local switch=self.SwitchRotation
    if not current() or type(switch)~='function' then return end
    local _,nextChange=switch(self);change=nextChange or change
    if not current() or self.currentRotation==nil then return end
    local evaluate=self.EvaluateNextAction
    if current() and type(evaluate)=='function' then evaluate(self) end
end)
addon.PLAYER_EQUIPMENT_CHANGED=function(self,event)
    local subscription=equipmentSubscription
    if not rawequal(self,addon) or not subscription or self.enabledState~=true then return end
    local profile=self.db.profile
    if equipmentSubscription~=subscription or type(profile)~='table' then return end
    local change=beginActive(self)
    if not activeChangeCurrent(self,change) or equipmentSubscription~=subscription or self.db.profile~=profile then return end
    return equipmentEvent(self,event,subscription,profile,change)
end
-- END EQUIPMENT EVENT DISPATCH
]========]):sub(2),previous=([========[!]========]):sub(2)},
}
local function hash(s)local n=0;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
return function(text,path)
 if path=='main.lua'and text:find('local prepareChoiceSelection',1,true)then text=dofile('tests/fixtures/restore_rotation_choice_preferences.lua')(text,path)end
 if path~='main.lua'then return text end
 assert(#text==91122 and hash(text)=='1fbe6913','unrelated composed equipment-event source')
 for i=#changes,1,-1 do local c=changes[i];assert(text:sub(c.at,c.at+#c.current-1)==c.current,'composed equipment-event addition mismatch');text=text:sub(1,c.at-1)..c.previous..text:sub(c.at+#c.current)end
 assert(#text==88071 and hash(text)=='15dc9e89','composed equipment-event predecessor differs');return text
end
