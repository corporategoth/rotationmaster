-- Exact duplicate-context projection inverse before prior complete-source proofs.
local rows = {
    ['Platform/client.lua'] = {
        oldHash = 'acf406b2',
        newHash = '5ab1a8f2',
        oldSize = 5895,
        newSize = 5924,
        changes = {
            {
                current = [====[        if method~=ownedClientInfo then local value=method(current);return value,false end
]====],
                previous = [====[        if method~=ownedClientInfo then return method(current) end
]====],
            },
            {
                current = [====[        return context,true
]====],
                previous = [====[        return context
]====],
            },
        },
    },
    ['Core/rotation_library.lua'] = {
        oldHash = '20a94eb7',
        newHash = '5dd9f2e4',
        oldSize = 40922,
        newSize = 41871,
        changes = {
            {
                current = [====[local contextIpairs,contextRawget,contextEqual=ipairs,rawget,rawequal
---@type fun(f: number|function): table
local contextGetfenv=getfenv
local contextEnvironment=type(contextGetfenv)=="function" and contextGetfenv(1) or nil
]====],
                previous = [====[]====],
            },
            {
                current = [====[    if method~=ownedRotationContext or not clientContextReader then local value=method(owner,spec);return value,false end
    local context,private=clientContextReader(owner.Platform)
]====],
                previous = [====[    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
]====],
            },
            {
                current = [====[    return context,private==true
]====],
                previous = [====[    return context
]====],
            },
            {
                current = [====[    local function contextMethod(self,spec) return rotationContext(owner,spec) end
    reader.Context=contextMethod
    local function ownsPrivateContext(method,projection,dispatch)
        return contextGetfenv and contextEnvironment
            and contextEqual(method,contextMethod) and contextEqual(contextRawget(reader,'Context'),contextMethod)
            and contextEqual(contextGetfenv(contextMethod),contextEnvironment) and contextEqual(contextGetfenv(rotationContext),contextEnvironment)
            and contextEqual(contextGetfenv(projection),contextEnvironment) and contextEqual(contextGetfenv(dispatch),contextEnvironment)
            and contextEqual(contextRawget(contextEnvironment,'ipairs'),contextIpairs)
    end
]====],
                previous = [====[    function reader:Context(spec) return rotationContext(owner,spec) end
]====],
            },
            {
                current = [====[    bind(reader,provesGeneration,ownsPrivateContext);return true
]====],
                previous = [====[    bind(reader,provesGeneration);return true
]====],
            },
        },
    },
    ['Core/rotation_scope.lua'] = {
        oldHash = '3df81a51',
        newHash = 'af6f6739',
        oldSize = 60632,
        newSize = 60973,
        changes = {
            {
                current = [====[local libraryReader,libraryGenerationProof,libraryContextProof
]====],
                previous = [====[local libraryReader,libraryGenerationProof
]====],
            },
            {
                current = [====[    bindLibrary(addon,function(reader,proof,contextProof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
]====],
                previous = [====[    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
]====],
            },
            {
                current = [====[    if type(method)=='function' then local value,private=method(libraryReader,spec);return value,private,method end
]====],
                previous = [====[    if type(method)=='function' then return method(libraryReader,spec) end
]====],
            },
            {
                current = [====[    local value=fallback(owner,spec);return value,false
]====],
                previous = [====[    return fallback(owner,spec)
]====],
            },
            {
                current = [====[            local value,private,method=rotationContext(owner,number)
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then return value end
            local result={}
]====],
                previous = [====[            local value=rotationContext(owner,number);local result={}
]====],
            },
        },
    },
}

local function hash(text)
    local value = 5381

    for i = 1, #text do
        value = (value * 33 + text:byte(i)) % 4294967296
    end

    return string.format('%08x', value)
end

return function(text, path)
    if path == 'Core/rotation_library.lua' and text:find('local contextPairs=pairs', 1, true) or path
        == 'Core/rotation_scope.lua'
        and text:find('local evaluationRequest,contextVersion', 1, true) then
        text = dofile('tests/fixtures/restore_runtime_event_context.lua')(text, path)
    end

    local row = assert(rows[path], 'unknown duplicate context inverse path')
    assert(#text == row.newSize and hash(text) == row.newHash, 'context projection source differs: ' .. path)

    for _, change in ipairs(row.changes) do
        local first, last = text:find(change.current, 1, true)
        assert(first and not text:find(change.current, last + 1, true), 'context projection block missing/repeated')
        text = text:sub(1, first - 1) .. change.previous .. text:sub(last + 1)
    end

    assert(#text == row.oldSize and hash(text) == row.oldHash, 'context projection baseline differs: ' .. path)
    return text
end
