-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/transfer_subject_help.lua'))
local source = h:read('*a')
h:close()
local prefix = assert(source:match('^(.-)\ntest%('))
local setup = assert(loadstring(prefix .. '\nreturn setup', '@report-help-current-fixture'))()
local newer = { heading = 'Current report help', sections = { { title = 'Current', text = 'current report subject' } } }
local older = { heading = 'Retired report help', sections = { { title = 'Old', text = 'retired report subject' } } }

local function document(a, d)
    d.help:Click()
    assert(a.helpWindow and a.helpWindow.heading == 'Current report help', 'old report Help displaced new subject')
    assert(d.text == 'new bytes' and d.input:GetText() == 'new bytes', 'old report continuation replaced newer bytes')
end

for _, phase in ipairs({'context', 'text', 'layout', 'show', 'escape', 'focus', 'cursor', 'selection', 'scroll'}) do
    test('newer report wins reentry from ' .. phase, function()
        local _, a = setup()
        local d = a:CreateWorkbenchTextReport()
        local target, key

        if phase == 'context' then
            target, key = d.chrome, 'SetContext'
        elseif phase == 'text' then
            target, key = d.input, 'SetText'
        elseif phase == 'layout' then
            target, key = d, 'Layout'
        elseif phase == 'show' then
            target, key = d.frame, 'Show'
        elseif phase == 'escape' then
            target, key = a, 'OpenPopup'
        elseif phase == 'focus' then
            target, key = d.input, 'SetFocus'
        elseif phase == 'cursor' then
            target, key = d.input, 'SetCursorPosition'
        elseif phase == 'selection' then
            target, key = d.input, 'HighlightText'
        else
            target, key = d.scroll.workbenchBar, 'SetValue'
        end

        local original = target[key]
        local entered = false

        target[key] = function(self, ...)
            local result = original(self, ...)

            if not entered then
                entered = true
                d:SetReport('New report', 'new bytes', nil, newer)
            end

            return result
        end

        d:SetReport('Old report', 'old bytes', nil, older)
        assert(entered, 'callback was not reached')
        document(a, d)
    end)
end

test('report request cannot adopt a database root replaced during focus callback', function()
    for _, root in ipairs({ 'profile', 'global', 'char' }) do
        local _, a = setup()
        local d = a:CreateWorkbenchTextReport()
        local focus = d.input.SetFocus

        d.input.SetFocus = function(self, ...)
            focus(self, ...)
            a.db[root] = {}
        end

        d:SetReport('Old report', 'old bytes', nil, older)
        assert(not d.help, 'retired report admitted Help after ' .. root .. ' replacement')
    end
end)

-- A report close retires setup before it can Show again. The final case
-- protects a newer report created by the real OnHide ClearFocus cleanup.
for _, kind in ipairs({ 'close-visible', 'frame-hide-visible', 'close-hidden' }) do
    test('report setup cancellation wins for ' .. kind, function()
        local _, a = setup()
        local d = a:CreateWorkbenchTextReport()
        d:SetReport('Original', 'original', nil, older)

        if kind == 'close-hidden' then
            d:Hide()
        end

        local original = d.chrome.SetContext
        local entered = false

        d.chrome.SetContext = function(self, ...)
            original(self, ...)

            if not entered then
                entered = true

                if kind == 'frame-hide-visible' then
                    d.frame:Hide()
                else
                    d.close:Click()
                end
            end
        end

        d:SetReport('Cancelled', 'cancelled', nil, newer)
        assert(entered and not d.frame:IsShown(), 'cancelled report setup reopened its frame')

        if d.help then
            d.help:Click()
        end

        assert(not a.helpWindow or not a.helpWindow.frame:IsShown(), 'cancelled report setup admitted Help')
    end)
end

test('report OnHide retirement preserves a newer request created by ClearFocus cleanup', function()
    local _, a = setup()
    local d = a:CreateWorkbenchTextReport()
    d:SetReport('Original', 'original', nil, older)
    local original = d.input.ClearFocus
    local entered = false

    d.input.ClearFocus = function(self, ...)
        original(self, ...)

        if not entered then
            entered = true
            d:SetReport('Newer', 'new bytes', nil, newer)
        end
    end

    d:Hide()
    assert(entered and d.frame:IsShown(), 'newer cleanup report was hidden by older retirement')
    document(a, d)
end)

finish()
