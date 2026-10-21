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
local coldBlocks={
[====[
-- BEGIN COLD STORE STRING SHAPE
-- Current observations only: cached constructor identities/admission stay private.
local function storeStringShape()
 local ok,text=proofPcall(function()
  local meta=getmetatable('');if not readable(meta) then return 'unavailable' end
  local index;if proofType(meta)=='table' then index=proofRawget(meta,'__index') end
  if not readable(index) then return 'unavailable' end
  local find;if proofType(index)=='table' then find=proofRawget(index,'find') end
  if not readable(find) then return 'unavailable' end
  local repeated=getmetatable('');if not readable(repeated) then return 'unavailable' end
  local repeatedIndex;if proofType(repeated)=='table' then repeatedIndex=proofRawget(repeated,'__index') end
  if not readable(repeatedIndex) then return 'unavailable' end
  return 'meta='..proofType(meta)..'; index='..proofType(index)..'; raw-find='..proofType(find)
   ..'; repeat-meta='..(cacheSourceEqual(meta,repeated) and '1' or '0')
   ..'; repeat-index='..(cacheSourceEqual(index,repeatedIndex) and '1' or '0')
 end)
 return ok and text or 'unavailable'
end
local function appendStoreStringShape(report,started,ended)
 local lines={'Store string shape start: '..(started or 'unavailable'),'Store string shape end: '..ended,
  'Necessary shape only: table/table/function and stable reads; does not prove private-store use or cached factory identities/admission.'}
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Store string shape omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END COLD STORE STRING SHAPE
]====],
[====[
 -- BEGIN COLD STORE STRING START
 if active==run then
  run.storeStringShape=storeStringShape()
  if active~=run then return true end
 end
 -- END COLD STORE STRING START
]====],
[====[
   -- BEGIN COLD STORE STRING END
   local shapeEntered=workState and workState.current()
   appendStoreStringShape(report,run.storeStringShape,storeStringShape())
   if shapeEntered and not workState.current() then workClear(run);return end
   -- END COLD STORE STRING END
]====]
}
local function coldHash(s)local n=0;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
return function(text,coldOnly)
 if text:find('-- BEGIN COLD STORE STRING SHAPE',1,true) then
  assert(#text==57837 and coldHash(text)=='0be263f0','unrelated cold store string source')
  for _,block in ipairs(coldBlocks)do
   local a,b=text:find(block,1,true);assert(a and not text:find(block,b+1,true),'missing or duplicate cold store string block')
   text=text:sub(1,a-1)..text:sub(b+1)
  end
  assert(#text==55576 and coldHash(text)=='6a4b79c4','cold store string predecessor mismatch')
 elseif coldOnly then error('missing cold store string shape addition') end
 if coldOnly then return text end
 for _,hunk in ipairs(hunks)do
  local first,last=text:find(hunk,1,true)
  assert(first and not text:find(hunk,last+1,true),'native runtime inverse missing or duplicate hunk')
  text=text:sub(1,first-1)..text:sub(last+1)
 end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==55206 and string.format('%08x',hash)=='5eeec9b5','CPU source differs beyond two native runtime guards')
 return text
end
