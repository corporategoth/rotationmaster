-- Real pinned editor/completion engine with external native frame primitives.
local F=dofile('tests/fixtures/addon.lua')
return function()
 local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);f.env.C_Timer={After=function(_,callback) callback() end};f.env.GetLocale=function() return "enUS" end;f.env.SlashCmdList={};f.env.StaticPopupDialogs={}
 local create=f.env.CreateFrame;local function augmented(frame) function frame:RegisterEvent() end;function frame:SetShown(value) if value then self:Show() else self:Hide() end end
 function frame:SetEnabled(value) if value then self:Enable() else self:Disable() end end
 function frame:GetTextColor() return unpack(self.textColor or {1,1,1,1}) end
 function frame:GetFont() return 'Fonts\\FRIZQT__.TTF',12,'' end
 function frame:SetFont() end
 function frame:SetSpacing(value) self.spacing=value end;function frame:GetSpacing() return self.spacing or 0 end
 function frame:SetJustifyH(value) self.justifyH=value end
 function frame:SetNonSpaceWrap() end
 function frame:GetTextInsets() return unpack(self.textInsets or {0,0,0,0}) end
 function frame:GetVerticalScroll() return self.scrollOffset or 0 end
 function frame:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight()) end
 function frame:GetPoint() return unpack(self.point or {'CENTER'}) end
 function frame:GetTop() return 500 end;function frame:GetBottom() return 200 end;function frame:GetLeft() return 0 end;function frame:SetClipsChildren() end;function frame:IsMouseOver() return false end;function frame:GetAltArrowKeyMode() return self.altArrowKeyMode end;function frame:SetHistoryLines() end;function frame:SetObeyStepOnDrag() end;function frame:GetFontObject() return "ChatFontNormal" end
 function frame:UnregisterAllEvents() self.eventsCleared=true end;local texture,fontstring=frame.CreateTexture,frame.CreateFontString
 function frame:CreateTexture(...) return augmented(texture(self,...)) end
 function frame:CreateFontString(...) return augmented(fontstring(self,...)) end
 function frame:CreateLine(...) return self:CreateTexture(...) end;function frame:SetStartPoint() end;function frame:SetEndPoint() end;function frame:SetThickness() end
 function frame:CreateMaskTexture(...) return self:CreateTexture(...) end;function frame:AddMaskTexture() end
 return frame end
 f.env.CreateFrame=function(...) return augmented(create(...)) end
 f.load('Core/custom_authoring.lua');f.load('Core/lua_symbols.lua');f.load('UI/settings_transfer.lua');f.load('UI/condition_source_preview.lua');f.load('UI/lua_debug_output.lua');f.load('UI/lua_completion.lua');do local lines=io.open('UI/line_numbers.lua');if lines then lines:close();f.load('UI/line_numbers.lua') end end;f.load('UI/lua_editor.lua');f.load('Libs/LuaWorkbench-Embed/modules.lua');local file=io.open('Integrations/lua_workbench.lua');if file then file:close();f.load('Integrations/lua_workbench.lua') end
 f.env.LuaWorkbench={db={options={autocomplete=true},drafts={user={source='KEEP'}}}};f.env.LuaWorkbenchDB={drafts={user={source='KEEP'}}}
 return f,f.addon
end
