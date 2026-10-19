-- External native EditBox events. Owned picker logic stays real.
return function(f,create)
    if not create then local _;_,create=dofile('tests/fixtures/native_ui.lua')(f.env) end
    -- Native WoW EditBoxes emit text/focus events; preserve that external
    -- boundary for RM's native reference inputs.
    local native=f.addon.CreateConditionEditBox
    f.addon.CreateConditionEditBox=function(self,...)
        local w=native(self,...);local field=w.editbox
        if not field.referenceFixtureEvents then
            field.referenceFixtureEvents=true
            local text,focus,blur=field.SetText,field.SetFocus,field.ClearFocus
            function field:SetText(value) text(self,value);if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
            function field:SetFocus() local changed=not self:HasFocus();focus(self);if changed and self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
            function field:ClearFocus() local changed=self:HasFocus();blur(self);if changed and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
        end
        return w
    end
    return create
end
