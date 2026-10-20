return function()
    local addon={}
    local env=setmetatable({}, {__index=function(_,key)
        assert(key~='LibStub' and key~='GetTime' and key~='CreateFrame','data layer requested '..key)
        return _G[key]
    end})
    for _,path in ipairs({'Data/plain.lua','Data/rotation_revision.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'}) do
        local load=assert(loadfile(path));setfenv(load,env);load('rotationmaster',addon)
    end
    local schemas={
        SPELL_KNOWN={fields={spell='number',pet='boolean'},requiredFields={'spell'}},
        BUFF={fields={unit='string',spell={'string','number'},ownbuff='boolean'},requiredFields={'unit','spell'}},
    }
    local function envelope()
        return {format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.leveling',revision=1,
            nameKey='Shaman Leveling',descriptionKey='A fixture, not a sourced recommendation',
            applicability={families={'tbc'},actionContext='player',class='SHAMAN',minLevel=1,maxLevel=70},
            tags={'leveling'},sources={{url='https://example.invalid/fixture',reviewedAt='2026-10-17'}},
            body={name='Shaman Leveling',switch={},rotation={{id='step-1',type='spell',action=403,
                conditions={type='SPELL_KNOWN',spell=403}}},cooldowns={}}}
    end
    return addon.RotationData,envelope,{conditions=schemas}
end
