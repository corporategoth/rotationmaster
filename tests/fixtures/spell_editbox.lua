-- External AceGUI EditBox/native primitives. Owned picker logic stays real.
return function(f,create)
    if not create then local _;_,create=dofile('tests/fixtures/native_ui.lua')(f.env) end
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind)
        local w=original(self,kind)
        w.frame=w.frame or create('Frame')
        if kind=='EditBox' then
            local edit=create('EditBox',nil,w.frame);edit.text='';w.editbox=edit;w.button=create('Button',nil,w.frame)
            function edit:HasFocus() return self.focused==true end
            function edit:SetFocus() self.focused=true;if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
            function edit:ClearFocus() self.focused=false;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
            function edit:SetText(value)
                self.text=value or '';w.text=self.text
                if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
            end
            function w:SetText(value) self.lasttext=value or '';edit:SetText(value) end
            function w:GetText() return edit:GetText() end
            function w:ClearFocus() edit:ClearFocus() end
            function w:SetFocus() edit:SetFocus() end
            function w:DisableButton(value) self.disablebutton=value end
            function w:SetMaxLetters(value) edit.maxLetters=value end
            function w:Fire(event,...) if self.callbacks and self.callbacks[event] then return self.callbacks[event](self,event,...) end end
            edit:SetScript('OnTextChanged',function() w:Fire('OnTextChanged',edit:GetText()) end)
            w.OnRelease=function() w:ClearFocus();w.baseReleased=true end
        end
        return w
    end
    return create
end
