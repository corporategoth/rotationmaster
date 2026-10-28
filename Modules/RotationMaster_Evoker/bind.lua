-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation Master Built In module bootstrap; identical in every module (tests/verify.py).
-- A load-on-demand addon gets its own private namespace, not Rotation Master's. This hands
-- it to Rotation Master (Core/builtin_modules.lua), which gives it RegisterDefaultBlock and
-- RegisterDefaultRotation, so the packs that follow call addon:Register... unchanged.
local _,addon=...
local host=RotationMasterBuiltIns
if type(host)=='table' and type(host.Bind)=='function' then host.Bind(addon) end
