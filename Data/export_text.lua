-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Export/import text presentation: wraps an encoded export string into 76-character lines and strips wrapping and
-- invisible copy artifacts from pasted text before it is decoded.
-- It owns only the text shape (docs/quality/export-text-format.md; the website follows the same rule) and must never
-- alter the encoded characters themselves or decode anything.
-- Loaded from RotationMaster.toc between Data/rotation_draft.lua and Data/codec.lua; the transfer windows and the codec
-- call it as addon:FormatExportText and addon:NormalizeImportText.
local _, addon = ...

-- Presentation of an encoded export string. The encoded data is never changed:
-- formatting inserts newlines only, and normalizing removes whitespace only.
-- docs/quality/export-text-format.md is the specification; the website follows
-- the same rule, so change both together.
--
--   Export: the whole string, marker included ("RM1:" + Base64), is cut into
--           lines of exactly 76 characters joined by "\n". The last line holds
--           the remainder (1-76 characters). No trailing newline.
--   Import: every whitespace and invisible formatting character is removed
--           before decoding. The encoding's alphabet (A-Z a-z 0-9 + / = and the
--           ":" of the marker) contains none, so nothing significant is lost.
local EXPORT_WIDTH = 76

-- Multi-byte UTF-8 sequences that chat clients, browsers and word processors
-- add or substitute when text is copied. Single-byte whitespace is one class.
local sequences = {
    "\194[\133\160\173]",  -- U+0085 NEL, U+00A0 no-break space, U+00AD soft hyphen
    "\225\154\128",  -- U+1680 Ogham space mark
    "\225\160\142",  -- U+180E Mongolian vowel separator
    "\226\128[\128-\143]",  -- U+2000-U+200F spaces, zero-width space/joiners, LRM/RLM
    "\226\128[\168-\175]",  -- U+2028-U+202F line/paragraph separators, bidi controls, narrow no-break space
    "\226\129[\159-\164\166-\169]",  -- U+205F medium space, U+2060-U+2064 joiners, U+2066-U+2069 bidi isolates
    "\227\128\128",  -- U+3000 ideographic space
    "\239\187\191",  -- U+FEFF zero-width no-break space / byte order mark
}

-- Returns pasted text with all whitespace and invisible formatting characters removed, ready for decoding; anything
-- that is not a string gives "". Text already made of only the encoding alphabet is returned without a copy.
function addon:NormalizeImportText(text)
    if type(text) ~= "string" then
        return ""
    end

    -- Text that is already nothing but the alphabet (an unwrapped export) costs
    -- one scan and no copy of a string that can be megabytes.
    if not text:find("[^A-Za-z0-9%+/=:]") then
        return text
    end

    text = text:gsub("[ \t\n\v\f\r]+", "")

    if text:find("[\194\225\226\227\239]") then
        for _, pattern in ipairs(sequences) do
            text = text:gsub(pattern, "")
        end
    end

    return text
end

-- Returns the encoded text cut into lines of width characters (76 when width is missing or below 1) joined by
-- newlines, with no trailing newline. Existing line breaks are dropped first, so formatting twice gives the same text.
function addon:FormatExportText(text, width)
    if type(text) ~= "string" then
        return ""
    end

    -- Only line breaks are touched, so wrapping twice is stable and any other
    -- character of the text is left exactly as it was.
    text = text:gsub("[\r\n]+", "")

    if type(width) ~= "number" or width < 1 then
        width = EXPORT_WIDTH
    end

    width = math.floor(width)

    if #text <= width then
        return text
    end

    local lines = {}

    for position = 1, #text, width do
        lines[#lines + 1] = text:sub(position, position + width - 1)
    end

    return table.concat(lines, "\n")
end

addon.ExportTextWidth = EXPORT_WIDTH
