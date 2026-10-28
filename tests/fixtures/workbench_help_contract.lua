-- Isolated subject-adapter tests use the agreed common-viewer contract. Once
-- composed, leave the actual viewer installed and exercise it instead.
return function(a, e)
    if type(a.OpenWorkbenchHelp) == 'function' then
        return false
    end

    a.rmHelpContractAdapter = true
    local request = 0
    local mounted

    a.OpenWorkbenchHelp = function(self, descriptor)
        request = request + 1
        local token = request

        local function current()
            return request == token and (not descriptor.valid or descriptor.valid())
        end

        if not current() then
            return
        end

        if mounted then
            mounted:Release()
            mounted = nil
        end

        local sections = descriptor.sections or {}

        if type(sections) == 'function' then
            local ok, value = pcall(sections)

            if not ok or not current() then
                return
            end

            sections = value
        end

        local parent = e.CreateFrame('Frame', nil, e.UIParent)
        local mount

        if descriptor.render then
            local ok, result = pcall(descriptor.render, parent, current, 0, 490)

            if not ok then
                return nil
            end

            mount = result
        end

        if not current() then
            if mount then
                mount:Release()
            end

            return
        end

        local d = self:ShowWorkbenchHelp(descriptor.heading, sections, descriptor.owner)
        d.contractMount = mount
        mounted = mount
        local close = d.close:GetScript('OnClick')

        self:SetUIScript(d.close, 'OnClick', function(...)
            if request == token then
                request = request + 1

                if mount then
                    mount:Release()
                end

                mounted = nil
                return close(...)
            end
        end)

        return d
    end

    return true
end
