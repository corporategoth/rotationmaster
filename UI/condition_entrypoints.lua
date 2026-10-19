local _,addon=...

-- Ordinary editors dispatch without initializing the historical Ace renderer.
-- Noncompact legacy frames and installations without the native editor retain
-- their original compatibility route, supplied separately by Options/conditional.
function addon.LayoutConditionFrame(frame)
    if frame.rmCompactRefresh then return frame.rmCompactRefresh() end
    return addon:GetLegacyConditionRenderer().LayoutConditionFrame(frame)
end

function addon:EditCondition(index,spec,value,callback,targetValid)
    if self.ShowConditionEditor then return self:ShowConditionEditor(index,spec,value,callback,targetValid) end
    return addon:GetLegacyConditionRenderer().EditCondition(self,index,spec,value,callback,targetValid)
end
