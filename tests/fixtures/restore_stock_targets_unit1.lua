-- Strict inverse of Unit1 stock profile/schema changes only.
local changes={
 ['Core/profile_data.lua']={bytes=12032,hash='b82a5170',edits={
  {from=[====[-- Reject malformed optional stock before generic recursive profile copying.
local function validStockTargets(addon,profile)
    if type(profile)~='table' then return true end
    local plan=rawget(profile,'stockTargets')
    return plan==nil or addon.StockTargets.Validate(plan)==true
end
function addon:ValidateProfileTransfer(value)
]====],to=[====[function addon:ValidateProfileTransfer(value)
]====]},
  {from=[====[    if type(value)~='table' then return false end
    if not validStockTargets(self,value) then return false end
]====],to=[====[    if type(value)~='table' then return false end
]====]},
  {from=[====[        elseif key=='stockTargets' then
            -- Closed optional schema was checked before copying the profile.
]====],to=[====[]====]},
  {from=[====[function addon:ProfileToPortable(profile)
    if not validStockTargets(self,profile) then return nil end
]====],to=[====[function addon:ProfileToPortable(profile)
]====]},
  {from=[====[function addon:ProfileFromPortable(profile,options)
    if not validStockTargets(self,profile) then return nil end
]====],to=[====[function addon:ProfileFromPortable(profile,options)
]====]},
 }},
 ['validate.lua']={bytes=33937,hash='a4fe15ca',edits={
  {from=[====[        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
]====],to=[====[        validate_basic("profile:" .. profile, data, profile_template, fix,{rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
]====]},
  {from=[====[        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
]====],to=[====[]====]},
 }},
}
return function(text,path)
 local spec=assert(changes[path],'unknown stock source path')
 for _,edit in ipairs(spec.edits)do local a,b=text:find(edit.from,1,true);assert(a and not text:find(edit.from,b+1,true),'stock inverse source differs');text=text:sub(1,a-1)..edit.to..text:sub(b+1)end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==spec.bytes and string.format('%08x',hash)==spec.hash,'unrelated stock source delta')
 return text
end
