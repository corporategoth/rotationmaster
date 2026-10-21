-- Remove only the two native-runtime lifecycle guards before prior CPU proofs.
local hunks={
[=[ -- BEGIN NATIVE RUNTIME EXCLUSION
 if type(self.IsCPURuntimeCaptureRunning)=='function' and self:IsCPURuntimeCaptureRunning() then return false,'native-runtime-capture-running' end
 -- END NATIVE RUNTIME EXCLUSION
]=],
[=[ -- BEGIN NATIVE RUNTIME DISABLE
 if type(self.CancelCPURuntimeCapture)=='function' then self:CancelCPURuntimeCapture() end
 -- END NATIVE RUNTIME DISABLE
]=],
}
return function(text)
 for _,hunk in ipairs(hunks)do
  local first,last=text:find(hunk,1,true)
  assert(first and not text:find(hunk,last+1,true),'native runtime inverse missing or duplicate hunk')
  text=text:sub(1,first-1)..text:sub(last+1)
 end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==55206 and string.format('%08x',hash)=='5eeec9b5','CPU source differs beyond two native runtime guards')
 return text
end
