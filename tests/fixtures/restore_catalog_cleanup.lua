-- Exact inverse of the 2026-10-25 integration catalog cleanup in
-- UI/settings_integrations.lua: the WowLua detection-only row is gone, the
-- notification group lists ForeverAuras, and the action-bar group lists the
-- current identities. Older historical page doubles (tests/questie_settings.lua
-- through restore_masque_preview.lua) are built from the page text before this
-- change, so this runs first in that chain. A source that does not carry the
-- change is returned untouched; a partial one is refused.
local edits = {
    {
        new = [====[
    local editorRows={editorRow(native)}
    for _,row in ipairs(rows)do editorRows[#editorRows+1]=editorRow(row)end
]====],
        old = [====[
    local editorRows={editorRow(native)};local found={}
    for _,row in ipairs(rows)do editorRows[#editorRows+1]=editorRow(row);found[row.id]=true end
]====],
    },
    {
        new = [====[
    end
    local groups={{key='integrations_editors']====],
        old = [====[
    end
    if metadata.WowLua and not found.WowLua then editorRows[#editorRows+1]=readonly(metadata.WowLua)end
    local groups={{key='integrations_editors']====],
    },
    { new = "{'WeakAuras','ForeverAuras'}", old = "{'WeakAuras'}" },
    {
        new = "{'ElvUI','Bartender4','ButtonForge','LUI','Dominos','AzeriteUI','AzeriteUI6','EllesmereUIActionBars','FarmingBar','TotemTimers'}",
        old = "{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'}",
    },
}

return function(source, path)
    if path ~= 'UI/settings_integrations.lua' then
        return source
    end

    local found = 0

    for _, edit in ipairs(edits) do
        if source:find(edit.new, 1, true) then
            found = found + 1
        end
    end

    if found == 0 then
        return source
    end

    assert(found == #edits, 'catalog cleanup inverse requires the exact complete successor: ' .. path)

    for _, edit in ipairs(edits) do
        local a, b = source:find(edit.new, 1, true)
        source = source:sub(1, a - 1) .. edit.old .. source:sub(b + 1)
    end

    return source
end
