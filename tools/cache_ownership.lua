-- Offline-only ownership of the unchanged private cache closure. These are
-- retained saved-source identities, not additional public helper APIs.
return {
    module='Functions/cache.lua',
    bindings={
        getCachedInternal={kind='function',bindingID='builtin:utils.lua:getCachedInternal',captureBindings={
            _G='builtin:utils.lua:_G',cacheHits='builtin:utils.lua:cacheHits',cacheMisses='builtin:utils.lua:cacheMisses',
            nilArgument='builtin:utils.lua:nilArgument',cachedResult='builtin:utils.lua:cachedResult',packResults='builtin:utils.lua:packResults',
        }},
        packResults={kind='function',bindingID='builtin:utils.lua:packResults'},
        cacheHits={kind='number',bindingID='builtin:utils.lua:cacheHits'},
        cacheMisses={kind='number',bindingID='builtin:utils.lua:cacheMisses'},
        nilArgument={kind='table',bindingID='builtin:utils.lua:nilArgument'},
        cachedResult={kind='table',bindingID='builtin:utils.lua:cachedResult'},
    },
}
