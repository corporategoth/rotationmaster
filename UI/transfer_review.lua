-- Preview, Compare and Check helpers for the direct-import transfer windows (item sets, effects, announcements,
-- profiles, condition categories, custom conditions). It is read-only: it parses the pasted text with each kind's own
-- parser and shows or reports the result, never saving or touching the destination. Loaded from RotationMaster.toc
-- after UI/collection_compare.lua, whose ShowCollectionComparison it uses; UI/settings_transfer.lua is the only caller.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Hides the import comparison window if it is the one this review opened (fromImport), leaving any other comparison
-- open.
-- @param p table|nil  The settings pane that owns the comparison.
function addon:CloseTransferReview(p)
    local d = p and p.comparison

    if d and d.fromImport and d.frame:IsShown() then
        d.frame:Hide()
    end
end

-- Builds the Preview and Check helpers for a transfer window. Every review callback is wrapped in pcall so a bad import
-- text reports an error instead of raising. The rotation has its own review, which also gates Import; these only let
-- you look, so no flow gets stricter.
-- @param p table  The settings pane that owns the transfer window.
-- @param review table  The review definition: kind (collection kind for the rows), parse(text) -> candidate or nil and
--   a
-- reason, record(candidate) -> the record shown (default: the candidate), current() -> the record of the entry being
-- replaced, rows (custom rows function), problems(candidate, dialog) and notes(candidate, dialog) -> lists of texts,
-- and maxRows (cap on rows drawn).
-- @return function  preview(dialog): opens a comparison (or a single-record view).
-- @return function  inspect(dialog): shows a problems and notes report.
--
-- Preview / Compare / Check for the transfer windows that import directly (item sets, effects, announcements, profiles,
-- condition categories, custom conditions). Nothing here saves anything: it parses the text with the kind's own import
-- parser, shows the result and never touches the candidate's destination.
function addon:BuildTransferReview(p, review)
    local owner = self

    -- Runs review.parse on the dialog's input text.
    -- @param d table  The transfer dialog.
    -- @return any  The candidate; nil when the text does not parse.
    -- @return string|nil  The reason when the first value is nil.
    local function parse(d)
        local ok, candidate, why = pcall(review.parse, d.input:GetText())

        if not ok then
            return nil, tostring(candidate)
        end
        if candidate == nil then
            return nil, why or L['Invalid import.']
        end

        return candidate
    end

    -- Opens a comparison against the selected entry in replace mode, otherwise a single-record preview; failures are
    -- shown in the dialog status line.
    -- @param d table  The transfer dialog.
    local function preview(d)
        local candidate, why = parse(d)
        owner:CloseTransferReview(p)

        if not candidate then
            d.status:SetText(string.format(L['Import preview unavailable: %s'], tostring(why)))
            return
        end

        local record = review.record and review.record(candidate) or candidate
        local current = d.mode == 'replace' and d.options.canReplace and review.current and review.current() or nil
        local shown, problem

        local ok, err = pcall(function()
            if current then
                shown = owner:ShowCollectionComparison(p, review.kind, current, record, {
                    title = L['Import comparison'],
                    leftHeading = L['Selected entry'],
                    rightHeading = L['Incoming'],
                    rows = review.rows,
                    fromImport = true,
                    maxRows = review.maxRows,
                })
            else
                shown = owner:ShowCollectionComparison(p, review.kind, record, record, {
                    single = true,
                    title = L['Import preview'],
                    leftHeading = type(record.name) == 'string' and record.name ~= '' and record.name or L['Incoming'],
                    rows = review.rows,
                    fromImport = true,
                    maxRows = review.maxRows,
                })
            end
        end)

        if not ok then
            problem = tostring(err)
        end

        if not shown then
            d.status:SetText(string.format(
                L['This import cannot be shown in full (%s). Use Check import for details.'],
                tostring(problem or L['Invalid import.'])
            ))
        end
    end

    -- Builds the Check import report: the first blocking problem as the verdict, then the problems and notes lists, in
    -- a reused text report window.
    -- @param d table  The transfer dialog.
    -- @return any  Whatever the report's SetReport returns.
    local function inspect(d)
        local candidate, why = parse(d)
        local problems, notes = {}, {}

        if not candidate then
            problems[1] = tostring(why)
        else
            if review.problems then
                local ok, list = pcall(review.problems, candidate, d)

                if ok then
                    problems = list or {}
                else
                    problems = { tostring(list) }
                end
            end

            if review.notes then
                local ok, list = pcall(review.notes, candidate, d)

                if ok then
                    notes = list or {}
                end
            end
        end

        local lines = {}

        lines[1] = #problems == 0 and L['This import can be applied.'] or string.format(
            L['This import cannot be applied: %s'],
            tostring(problems[1])
        )

        lines[#lines + 1] = ''
        lines[#lines + 1] = L['Problems']

        if #problems == 0 then
            lines[#lines + 1] = L['No problems found.']
        else
            for _, text in ipairs(problems) do
                lines[#lines + 1] = '- ' .. tostring(text)
            end
        end

        if #notes > 0 then
            lines[#lines + 1] = ''
            lines[#lines + 1] = L['Notes']

            for _, text in ipairs(notes) do
                lines[#lines + 1] = '- ' .. tostring(text)
            end
        end

        local report = owner.transferCheckReport

        if not report then
            report = owner:CreateWorkbenchTextReport(640, 360)
            owner.transferCheckReport = report
        end

        return report:SetReport(L['Check import'], table.concat(lines, '\n'), owner.pretty_name)
    end

    return preview, inspect
end
