-- The English source files of every catalog (Locales/enUS.lua and each text bundle's enUS.lua, named in Locales/bundles.json).
-- Fixtures that model the locale as one table load all of them: a key reads the same wherever its text lives.
local files = { 'Locales/enUS.lua' }
local manifest = io.open('Locales/bundles.json')

if manifest then
    local text = manifest:read('*a')
    manifest:close()

    for module in text:gmatch('"module"%s*:%s*"([^"]+)"') do
        files[#files + 1] = 'Modules/' .. module .. '/enUS.lua'
    end
end

return files
