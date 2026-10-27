-- First file in RotationMaster.toc: defines the global `color` table of chat color codes (|cAARRGGBB strings) that the
-- rest of the addon uses wherever it colors text.
-- This file should NOT rely on the addon.  It loads BEFORE everything else, so it cannot use the addon table, the
-- locale or any Platform adapter; only `NORMAL_FONT_COLOR_CODE` from the client's own globals.
-- `RESET` ends any of the other codes.

color = {
    RED = "|cFFFF0000",
    GREEN = "|cFF00FF00",
    BLUE = "|cFF0000FF",
    YELLOW = "|cFFFFFF00",
    MAGENTA = "|cFFFF00FF",
    CYAN = "|cFF00FFFF",
    WHITE = "|cFFFFFFFF",
    BLACK = "|cFF000000",
    GRAY = "|cFF888888",
    RESET = "|r",
    DEBUG = "|cFF6E7B84",
    INFO = "|cFF7BC653",
    WARN = "|cFFB212B7",
    ANNOUNCE = "|cFFF8FC03",
    BLIZ_YELLOW = NORMAL_FONT_COLOR_CODE,
}
