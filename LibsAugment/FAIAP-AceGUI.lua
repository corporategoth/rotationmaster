--[[
-- For all Indents and Purposes
-- Copyright (c) 2007 Kristofer Karlsson <kristofer.karlsson@gmail.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--]]

-- Explicit compatibility registration for historical AceGUI LuaEditBox users.
local _,addon=...
local lib=addon.LuaSyntax

-- Add the edit box type.
local AceGUI = LibStub("AceGUI-3.0")
do
	local Type = "LuaEditBox"
	local Version = 1

	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("MultiLineEditBox")
		-- This explicit compatibility adapter owns the historical widget's
		-- native editor; ordinary controls never reach into Ace widget internals.
		---@cast self {editBox: EditBox}
		self.editBox:SetScript("OnTextSet", nil)
		lib.enable(self.editBox, nil, 4)
		return self
	end

	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
