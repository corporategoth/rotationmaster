-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rich AceGUI-style Table layout (column weights and widths, row and column spans, per-cell alignment, spacing) for the
-- native condition groups. addon:PrepareNativeConditionTable wraps a group's DoLayout; groups whose Table settings are
-- plain keep the older compact layout, and anything malformed or oversized raises an error before any frame is moved.
-- It must never mutate the caller's column or cell descriptors. Applied by UI/condition_widgets.lua when it acquires an
-- RM-ConditionGroup; loaded in the UI/ block of RotationMaster.toc, after UI/condition_layout.lua.
local _, addon = ...

-- Native rich Table geometry preserves the established column/cell behavior
-- without mutating the caller's descriptors. Adapted portions retain this notice:
--[[
Copyright (c) 2007, Ace3 Development Team

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Redistribution of a stand alone version is strictly prohibited without
      prior written authorization from the Lead of the Ace3 Development Team.
    * Neither the name of the Ace3 Development Team nor the names of its contributors
      may be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

-- ============================================================================
-- Descriptor validation
-- ============================================================================

-- True for a real, finite number; rejects NaN and both infinities so bad geometry cannot reach SetPoint.
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- True when an align value is absent, a name, a callback or a finite offset.
local function alignment(value)
    return value == nil or type(value) == 'string' or type(value) == 'function' or finite(value)
end

-- Checks the three alignment keys (align, alignH, alignV) of a settings, column or cell table.
local function alignments(value)
    return alignment(value.align) and alignment(value.alignH) and alignment(value.alignV)
end

-- True when a rowspan or colspan is absent or a whole number of at least one.
local function span(value)
    return value == nil or finite(value) and value >= 1 and value == math.floor(value)
end

-- Raises 'condition-table-work-limit' when a Table group has too many columns, children or span cells to lay out
-- cheaply. Runs before any geometry work so an oversized descriptor cannot freeze the client.
local function guardWork(group)
    if group.layout ~= 'Table' then
        return
    end

    local settings = group:GetUserData('table')
    local columns = type(settings) == 'table' and settings.columns

    if type(columns) == 'table' and #columns > 128 or #group.children > 2048 then
        error('condition-table-work-limit', 0)
    end

    for _, child in ipairs(group.children) do
        local cell = child:GetUserData('cell')

        if type(cell) == 'table' then
            for _, key in ipairs({ 'rowspan', 'colspan' }) do
                local value = cell[key]

                if value ~= nil and (not span(value) or value > 4096) then
                    error('condition-table-work-limit', 0)
                end
            end
        end
    end
end

-- Decides which route lays the group out. Returns true when the group uses a rich feature (spans, spacing, alignment,
-- table columns), false for the plain compact numeric Table, and raises on malformed settings, columns or cells.
local function supported(group)
    if group.layout ~= 'Table' then
        return false
    end

    local settings = group:GetUserData('table')

    if settings == nil and #group.children == 0 then
        return false
    end

    if type(settings) ~= 'table' or type(settings.columns) ~= 'table' or not alignments(settings) then
        error('invalid-condition-table-settings', 0)
    end

    local length = #settings.columns
    local entries = 0

    for key in pairs(settings.columns) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > length then
            error('invalid-condition-table-columns', 0)
        end

        entries = entries + 1
    end

    if entries ~= length or length == 0 and #group.children > 0 then
        error('invalid-condition-table-columns', 0)
    end

    if length == 0 then
        return false
    end

    local advanced = settings.align ~= nil or settings.alignH ~= nil or settings.alignV ~= nil

    for _, key in ipairs({ 'space', 'spaceH', 'spaceV' }) do
        if settings[key] ~= nil then
            if not finite(settings[key]) then
                error('invalid-condition-table-settings', 0)
            end

            advanced = true
        end
    end

    for _, column in ipairs(settings.columns) do
        if type(column) == 'table' then
            advanced = true

            if not alignments(column) then
                error('invalid-condition-table-settings', 0)
            end

            for _, key in ipairs({ 'width', 'weight', 'min', 'max', 1, 2 }) do
                if column[key] ~= nil and not finite(column[key]) then
                    error('invalid-condition-table-settings', 0)
                end
            end

            if column.weight and column.weight < 0 then
                error('invalid-condition-table-settings', 0)
            end
        elseif not finite(column) then
            error('invalid-condition-table-settings', 0)
        end
    end

    for _, child in ipairs(group.children) do
        local cell = child:GetUserData('cell')

        if cell ~= nil then
            if type(cell) ~= 'table' or not alignments(cell) or not span(cell.colspan) or not span(cell.rowspan) then
                error('invalid-condition-table-settings', 0)
            end

            if cell.colspan or cell.rowspan or cell.align or cell.alignH then
                advanced = true
            end

            -- Preserve the existing compact numeric Table's simple alignV path.
            if cell.alignV ~= nil then
                local value = type(cell.alignV) == 'string' and cell.alignV:lower()

                local compact = value
                    and (value == 'start'
                        or value == 'end'
                        or value == 'middle'
                        or value:sub(1, 3) == 'top'
                        or value:sub(1, 6) == 'bottom'
                        or value:sub(1, 6) == 'center')

                if not compact then
                    advanced = true
                end
            end
        end
    end

    return advanced
end

-- ============================================================================
-- Geometry
-- ============================================================================

-- Total size of lanes first..last (column widths or row heights) including the gaps between them.
local function dimension(lanes, first, last, spacing)
    local result = 0

    for index = first, last do
        result = result + (lanes[index] or 0)
    end

    return result + math.max(0, last - first) * spacing
end

-- Resolves a cell's alignment on one axis ('H' or 'V'). Precedence is cell, column, then table settings; names are
-- normalized to start, middle, end or fill. Returns the method and the clamped offset inside the available space.
local function offset(direction, settings, column, cell, available, size)
    local method = cell and (cell['align' .. direction] or cell.align)
        or column['align' .. direction]
        or column.align
        or settings['align' .. direction]
        or settings.align
        or 'CENTERLEFT'

    local result

    if type(method) == 'string' then
        method = method:lower()

        method = direction == 'V'
            and (method:sub(1, 3) == 'top' and 'start'
                or method:sub(1, 6) == 'bottom' and 'end'
                or method:sub(1, 6) == 'center' and 'middle')
            or direction == 'H'
                and (method:sub(-4) == 'left' and 'start'
                    or method:sub(-5) == 'right' and 'end'
                    or method:sub(-6) == 'center' and 'middle')
            or method

        result = (method == 'start' or method == 'fill') and 0
            or method == 'end' and available - size
            or (available - size) / 2
    elseif type(method) == 'function' then
        result = method(size, available, direction)
    else
        result = method
    end

    if not finite(result) then
        error('invalid-condition-table-alignment', 0)
    end

    return method, math.max(0, math.min(result, available))
end

-- Places every shown child of a Table group: assigns cells to a grid (honoring rowspan and colspan), sizes the
-- columns, then the rows, and anchors each child. Reuses a per-group scratch cache so a relayout allocates nothing
-- new; reports the final height through group:LayoutFinished.
local function layout(group)
    local content, children = group.content, group.children
    local settings = group:GetUserData('table')
    local spacingH = settings.spaceH or settings.space or 0
    local spacingV = settings.spaceV or settings.space or 0
    local count = #settings.columns
    local total = (content:GetWidth() or content.width or 0) - spacingH * (count - 1)
    local cache = group:GetUserData('rmNativeTableCache')

    if not cache then
        cache = { {}, {}, {}, {}, {}, {}, {} }
        group:SetUserData('rmNativeTableCache', cache)
    end

    for _, values in ipairs(cache) do
        for key in pairs(values) do
            values[key] = nil
        end
    end

    local grid, widths, heights, spanning, firstRow, firstColumn, columns = unpack(cache)
    local position = 0

    for index, child in ipairs(children) do
        if child:IsShown() then
            local found

            repeat
                position = position + 1
                local column = (position - 1) % count + 1
                local row = math.ceil(position / count)
                local across = spanning[column]
                local current = across and across.child or child
                local cell = current:GetUserData('cell')
                found = not across

                if not across and cell and cell.rowspan then
                    across = { child = child, from = row, to = row + cell.rowspan - 1 }
                    spanning[column] = across
                end

                if across and index == #children then
                    across.to = row
                end

                position = position + math.max(0, math.min((cell and cell.colspan or 1) - 1, count - column))

                if position > 65536 then
                    error('condition-table-work-limit', 0)
                end

                if not across or across.to == row then
                    grid[position] = current
                    firstRow[current] = across and across.from or row
                    firstColumn[current] = column

                    if across then
                        spanning[column] = nil
                    end
                end
            until found
        end
    end

    local rows = math.ceil(position / count)
    local remaining, weight = total, 0

    for index, source in ipairs(settings.columns) do
        local column = source

        if type(column) == 'number' then
            column = column >= 1 and column < 10 and { weight = column } or { width = column }
        end

        columns[index] = column
        widths[index] = 0

        if column.weight then
            weight = weight + column.weight
        else
            if not column.width or column.width <= 0 then
                for row = 1, rows do
                    local child = grid[(row - 1) * count + index]

                    if child then
                        child.frame:ClearAllPoints()

                        widths[index] = math.max(
                            widths[index],
                            (child.frame:GetWidth() or 0) - dimension(widths, firstColumn[child], index - 1, spacingH)
                        )
                    end
                end

                widths[index] = math.max(column.min or column[1] or 0, math.min(
                    widths[index],
                    column.max or column[2] or widths[index]
                ))
            else
                widths[index] = column.width < 1 and column.width * total or column.width
            end

            remaining = math.max(0, remaining - widths[index])
        end
    end

    local scale = weight > 0 and remaining / weight or 0

    for index, column in ipairs(columns) do
        if column.weight then
            widths[index] = scale * column.weight
        end
    end

    for row = 1, rows do
        local height = 0

        for column = 1, count do
            local child = grid[(row - 1) * count + column]

            if child then
                local start = firstColumn[child]
                local cell = child:GetUserData('cell')
                local frame = child.frame
                local left = dimension(widths, 1, start - 1, spacingH) + (start == 1 and 0 or spacingH)
                local available = dimension(widths, start, column, spacingH)
                frame:ClearAllPoints()
                local size = frame:GetWidth() or 0
                local method, align = offset('H', settings, columns[start], cell, available, size)
                frame:SetPoint('LEFT', content, left + align, 0)

                if child:IsFullWidth() or method == 'fill' or size > available then
                    frame:SetPoint('RIGHT', content, 'LEFT', left + align + available, 0)
                end
                if child.DoLayout then
                    child:DoLayout()
                end

                height = math.max(
                    height,
                    (frame:GetHeight() or 0) - dimension(heights, firstRow[child], row - 1, spacingV)
                )
            end
        end

        heights[row] = height

        for column = 1, count do
            local child = grid[(row - 1) * count + column]

            if child then
                local start = firstRow[child]
                local cell = child:GetUserData('cell')
                local frame = child.frame
                local top = dimension(heights, 1, start - 1, spacingV) + (start == 1 and 0 or spacingV)
                local available = dimension(heights, start, row, spacingV)

                local method, align = offset(
                    'V',
                    settings,
                    columns[firstColumn[child]],
                    cell,
                    available,
                    frame:GetHeight() or 0
                )

                if child:IsFullHeight() or method == 'fill' then
                    frame:SetHeight(available)
                end

                frame:SetPoint('TOP', content, 0, -(top + align))
            end
        end
    end

    group:LayoutFinished(nil, dimension(heights, 1, rows, spacingV))
end

-- ============================================================================
-- Group integration
-- ============================================================================

-- Install the native rich-table route once on each owned group. Replaces the group's DoLayout with a wrapper that
-- falls back to the original compact layout when the group is not a rich table.
function addon:PrepareNativeConditionTable(group)
    if not group.rmNativeTableOriginal then
        local original = group.DoLayout
        group.rmNativeTableOriginal = original

        function group:DoLayout()
            if self.paused or self.layingOut or self.isQueuedForRelease then
                return
            end

            -- Reject unsafe work before compact or rich geometry mutates frames.
            guardWork(self)

            if not supported(self) then
                return original(self)
            end

            self.layingOut = true
            local ok, why = pcall(layout, self)
            self.layingOut = false

            if not ok then
                self.paused = false
                error(why, 0)
            end

            if self.parent and self.parent.DoLayout then
                self.parent:DoLayout()
            end
        end
    end
end
