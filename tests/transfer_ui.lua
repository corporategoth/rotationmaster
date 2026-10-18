local F=dofile('tests/fixtures/addon.lua');local make=dofile('tests/fixtures/rotation_data.lua');local test,finish=F.suite()
test('shared native rotation transfer invalidates previews and applies copy or selected replacement explicitly',function()
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local data,envelope,options=make();a.RotationData=data
    for _,path in ipairs({'Data/diff.lua','Data/import_session.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/rotation_comparison.lua','UI/transfer.lua'}) do f.load(path) end
    local body=envelope().body;a.GetRotationExportData=function() return data.CopyData(body) end;a.GetEditableRotation=function() return body end;a.GetDefaultIdForRuntime=function() end;a.GetImportValidationOptions=function() return options end
    a.NewRotationCodec=function() return {Encode=function() return 'export-text' end,Decode=function(_,text)
        if text=='bad' then return nil,'invalid-base64' end
        if text=='future' then local incoming=envelope();incoming.futureMetadata={coefficient=42};return {kind='envelope',original=text,value=incoming} end
        local incoming=data.CopyData(body);incoming.rotation[1].action=974;return {kind='legacy',original=text,value=incoming}
    end} end
    local renders,applied,target=0,0,nil;a.ShowComparisonReport=function(_,text) return text end;a.ShowNativeImportPreview=function(_,_,view) renders=renders+1;assert(view.right.body.rotation[1].action==974 or view.right.body.rotation[1].action==403) end
    a.ApplyRotationImport=function(_,session,token,spec,name,selected) assert(session:GetReady(token) and spec==0 and name~='');applied=applied+1;target=selected;return selected or 'new-copy' end;a.ShowConfig=function(_,section) assert(section=='Rotations') end
    local d=a:ShowRotationTransfer(0,'mine');assert(d.destination:GetChecked() and d.original and d.name and not d.apply:IsEnabled());d.copy:Click();assert(d.input.focused and d.input.selection[2]==-1)
    d.input:SetText('incoming');d.input.scripts.OnTextChanged(d.input,true);assert(renders==0);d.preview:Click();assert(renders==1 and d.apply:IsEnabled())
    d.clear:Click();assert(d.input:GetText()=='' and not d.apply:IsEnabled());d.apply:Click();assert(applied==0)
    d.input:SetText('bad');d.input.scripts.OnTextChanged(d.input,true);assert(not d.apply:IsEnabled());d.apply:Click();assert(applied==0);d.preview:Click();assert(not d.apply:IsEnabled())
    d.input:SetText('future');d.input.scripts.OnTextChanged(d.input,true);d.preview:Click();assert(not d.apply:IsEnabled());local details=d.inspect.scripts.OnClick();assert(details:find('futureMetadata',1,true))
    d.input:SetText('incoming');d.input.scripts.OnTextChanged(d.input,true);d.preview:Click();d.destination:Click();d.name:SetText('Copy');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();assert(applied==1 and not target and not d.frame:IsShown() and body.rotation[1].action==403)
    d=a:ShowRotationTransfer(0,'mine');d.preview:Click();d.apply:Click();assert(applied==2 and target=='mine')
end)
finish()
