-- QA-only exact inverse of the "Font not set" repair (LuaWorkbench measuring and
-- overlay strings that were created without a font, the editor release that
-- emptied them, the reflow driver's stack report, and the runner entry for its
-- regression suite). Exactly the current bytes of each touched file map back to
-- their predecessor, so the closed historical proofs that pin those files keep
-- running against the source they were written for. Any other text, including
-- every older stage, passes through unchanged.
local function digest(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return n
end

local records = {}

records["Libs/LuaWorkbench-Embed/modules.lua"] = {
    bytes = 658868,
    hash = 3387373398,
    oldBytes = 658712,
    oldHash = 836060462,
    changes = {
        {
            at = 349403,
            current = "  state.overlay = box:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')\n",
            previous = "  state.overlay = box:CreateFontString(nil, 'OVERLAY')\n",
        },
        {
            at = 393539,
            current = "\t\t\t\trow = state.gutter:CreateFontString(nil, \"OVERLAY\", 'GameFontHighlightSmall')\n",
            previous = "\t\t\t\trow = state.gutter:CreateFontString(nil, \"OVERLAY\")\n",
        },
        {
            at = 395097,
            current = "\t\tstate.measure = state.gutter:CreateFontString(nil, \"OVERLAY\", 'GameFontHighlightSmall')\n",
            previous = "\t\tstate.measure = state.gutter:CreateFontString(nil, \"OVERLAY\")\n",
        },
        {
            at = 401304,
            current = " local label = parent:CreateFontString(nil, \"OVERLAY\", 'GameFontHighlightSmall')\n",
            previous = " local label = parent:CreateFontString(nil, \"OVERLAY\")\n",
        },
        {
            at = 532279,
            current = "  local overlay = input.editBox:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')\n",
            previous = "  local overlay = input.editBox:CreateFontString(nil, 'OVERLAY')\n",
        },
        {
            at = 533776,
            current = "  self.snapshotMeasure = box:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')\n",
            previous = "  self.snapshotMeasure = box:CreateFontString(nil, 'OVERLAY')\n",
        },
    },
}

records["Integrations/lua_workbench.lua"] = {
    bytes = 37887,
    hash = 2672600905,
    oldBytes = 37344,
    oldHash = 3312868261,
    changes = {
        {
            at = 8920,
            current = "        -- A FontString or EditBox with no font raises \"Font not set\" from\n        -- :SetText(), even for ''. One the editor never painted has none yet,\n        -- so it gets the plain font first; it is being emptied, not shown.\n        local function clearText(widget)\n            if not widget then return end\n            if widget.GetFont and widget.SetFontObject then\n                local ok,font=pcall(widget.GetFont,widget)\n                if not ok or not font then attempt(widget.SetFontObject,widget,GameFontHighlightSmall or 'GameFontHighlightSmall') end\n            end\n            attempt(widget.SetText,widget,'')\n        end\n",
            previous = "        local function clearText(widget) if widget then attempt(widget.SetText,widget,'') end end\n",
        },
    },
}

records["UI/controls.lua"] = {
    bytes = 55235,
    hash = 1023222187,
    oldBytes = 54813,
    oldHash = 3025820838,
    changes = {
        {
            at = 36506,
            current = "-- A relayout that fails is reported with the stack it failed in. pcall alone\n-- loses it, leaving only the message and this driver's own frame.\nlocal function reflowFailure(why)\n    if type(why)~='string' or type(debugstack)~='function' then return why end\n    local ok,stack=pcall(function() return debugstack(2) end)\n    return ok and type(stack)=='string' and why..'\\n'..stack or why\nend\n",
            previous = "",
        },
        {
            at = 37366,
            current = "            local ok,why=xpcall(request.run,reflowFailure)\n",
            previous = "            local ok,why=pcall(request.run)\n",
        },
        {
            at = 37997,
            current = "        local ok,why=xpcall(request.run,reflowFailure)\n",
            previous = "        local ok,why=pcall(request.run)\n",
        },
    },
}

records["tools/check"] = {
    bytes = 52261,
    hash = 2014961058,
    oldBytes = 52207,
    oldHash = 1073016197,
    changes = {
        { at = 33784, current = "            ['luajit', 'tests/font_enforcement.lua'],\n", previous = "" },
    },
}

return function(value, path)
    assert(path ~= 'tests/fixtures/restore_function_fonts.lua', 'font inverse cannot normalize itself')
    local row = type(value) == 'string' and records[path]

    if not row or #value ~= row.bytes or digest(value) ~= row.hash then
        return value
    end

    for i = #row.changes, 1, -1 do
        local c = row.changes[i]
        assert(value:sub(c.at, c.at + #c.current - 1) == c.current, 'font inverse literal drift: ' .. path)
        value = value:sub(1, c.at - 1) .. c.previous .. value:sub(c.at + #c.current)
    end

    assert(#value == row.oldBytes and digest(value) == row.oldHash, 'font inverse predecessor differs: ' .. path)
    return value
end
