local _,addon=...

-- Keep the legacy snapshot shape for custom/UI consumers while publishing only
-- complete, normalized bag observations. Runtime item predicates query Platform.
function addon:UpdateBagContents(cache)
    local snapshot,reason=self.getCached(cache,self.Platform.GetBagSnapshot,self.Platform)
    if not snapshot then
        self.bagContents={};self.bagContentsUnavailable=reason or 'inventory-unavailable'
        return false,self.bagContentsUnavailable
    end
    local contents={}
    for id,record in pairs(snapshot) do
        local use=self.Platform:GetItemUseSpell(id)
        local entry={count=record.count,spell=use and use.name,slots={},locations={}}
        for index,location in ipairs(record.slots) do
            entry.slots[index]=location.slot
            entry.locations[index]={bag=location.bag,slot=location.slot}
        end
        contents[id]=entry
    end
    self.bagContents=contents;self.bagContentsUnavailable=nil
    return true
end
