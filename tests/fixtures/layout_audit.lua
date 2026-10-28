-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Resolves native-frame mock anchors into rectangles so UI tests can prove
-- horizontal containment. Coordinates follow WoW: x grows right, y grows up.
-- Only frames that would be drawn are audited: shown, anchored and inside a
-- shown ancestry. Textures are decoration and are ignored; a FontString is
-- audited only when its width is explicit (two anchors or a set width).
local audit = {}

local horizontal = {
    TOPLEFT = 'LEFT',
    LEFT = 'LEFT',
    BOTTOMLEFT = 'LEFT',
    TOPRIGHT = 'RIGHT',
    RIGHT = 'RIGHT',
    BOTTOMRIGHT = 'RIGHT',
    TOP = 'CENTER',
    CENTER = 'CENTER',
    BOTTOM = 'CENTER',
}

local vertical = {
    TOPLEFT = 'TOP',
    TOP = 'TOP',
    TOPRIGHT = 'TOP',
    BOTTOMLEFT = 'BOTTOM',
    BOTTOM = 'BOTTOM',
    BOTTOMRIGHT = 'BOTTOM',
    LEFT = 'CENTER',
    CENTER = 'CENTER',
    RIGHT = 'CENTER',
}

local function normalize(frame, point)
    local name, relative, relativePoint, x, y = point[1], point[2], point[3], point[4], point[5]

    if type(relative) == 'number' then
        return name, frame.parent, name, relative, relativePoint or 0
    end
    if relative == nil then
        return name, frame.parent, name, 0, 0
    end
    if type(relativePoint) == 'number' then
        return name, relative, name, relativePoint, x or 0
    end

    return name, relative, relativePoint or name, x or 0, y or 0
end

local function anchorX(rect, point)
    local side = horizontal[point]

    if side == 'LEFT' then
        return rect.left
    elseif side == 'RIGHT' then
        return rect.right
    end

    return (rect.left + rect.right) / 2
end

local function anchorY(rect, point)
    local side = vertical[point]

    if side == 'TOP' then
        return rect.top
    elseif side == 'BOTTOM' then
        return rect.bottom
    end

    return (rect.top + rect.bottom) / 2
end

-- The mock's unsized default is 100; a FontString left at it sizes to text.
local function explicit(frame)
    return frame.width ~= 100
end

local function width(frame)
    if frame.kind == 'FontString' and not explicit(frame) then
        return frame:GetStringWidth()
    end

    return frame.width or 0
end

-- root is placed at the origin; every rectangle is relative to it.
function audit.resolver(root)
    local cache, visiting = {}, {}

    local function resolve(frame)
        if frame == nil then
            return nil
        end
        if frame == root then
            return { left = 0, right = root.width, top = 0, bottom = -root.height }
        end
        if cache[frame] ~= nil then
            return cache[frame] or nil
        end
        if visiting[frame] then
            return nil
        end

        visiting[frame] = true
        local rect

        if frame.allPoints then
            local owner = resolve(frame.allPoints)

            if owner then
                rect = { left = owner.left, right = owner.right, top = owner.top, bottom = owner.bottom }
            end
        elseif frame.points and #frame.points > 0 then
            local xs, ys = {}, {}

            for _, point in ipairs(frame.points) do
                local name, relative, relativePoint, x, y = normalize(frame, point)
                local base = resolve(relative)

                if not base then
                    visiting[frame] = nil
                    cache[frame] = false
                    return nil
                end

                xs[horizontal[name]] = anchorX(base, relativePoint) + x
                ys[vertical[name]] = anchorY(base, relativePoint) + y
            end

            local w, h = width(frame), frame.height or 0
            rect = {}

            if xs.LEFT and xs.RIGHT then
                rect.left, rect.right = xs.LEFT, xs.RIGHT
            elseif xs.LEFT then
                rect.left, rect.right = xs.LEFT, xs.LEFT + w
            elseif xs.RIGHT then
                rect.left, rect.right = xs.RIGHT - w, xs.RIGHT
            else
                rect.left, rect.right = (xs.CENTER or 0) - w / 2, (xs.CENTER or 0) + w / 2
            end

            if ys.TOP and ys.BOTTOM then
                rect.top, rect.bottom = ys.TOP, ys.BOTTOM
            elseif ys.TOP then
                rect.top, rect.bottom = ys.TOP, ys.TOP - h
            elseif ys.BOTTOM then
                rect.top, rect.bottom = ys.BOTTOM + h, ys.BOTTOM
            else
                rect.top, rect.bottom = (ys.CENTER or 0) + h / 2, (ys.CENTER or 0) - h / 2
            end
        elseif frame.kind ~= 'Texture' and frame.kind ~= 'FontString' and frame.parent then
            -- A scroll child is positioned by its ScrollFrame.
            local parent = frame.parent

            if parent.scrollChild == frame then
                local base = resolve(parent)

                if base then
                    rect = {
                        left = base.left,
                        right = base.left + width(frame),
                        top = base.top,
                        bottom = base.top - (frame.height or 0),
                    }
                end
            end
        end

        visiting[frame] = nil
        cache[frame] = rect or false
        return rect
    end

    return resolve
end

local function descends(frame, root)
    local current = frame

    for _ = 1, 200 do
        if current == root then
            return true
        end
        if current == nil or not current.visible then
            return false
        end

        current = current.parent
    end

    return false
end

-- Returns a list of {frame,rect,limit,owner} where a drawn control extends
-- outside the root or its nearest clipping ScrollFrame horizontally.
-- options.horizontalScroll: set of ScrollFrames that scroll horizontally.
-- options.container(frame): marks frames (cards) that bound their descendants.
-- options.captions: a Button's caption must stay within the Button.
-- options.ignore(frame): optional predicate.
function audit.overflows(root, frames, options)
    options = options or {}
    local tolerance = options.tolerance or .5
    local resolve = audit.resolver(root)
    local problems = {}

    for _, frame in ipairs(frames) do
        if
            frame ~= root
            and frame.kind ~= 'Texture'
            and frame.visible
            and descends(frame, root)
            and not (options.skipText
                and frame.kind == 'FontString'
                and not explicit(frame)
                and #(frame.points or {}) < 2)
            and not (options.ignore and options.ignore(frame))
        then
            local rect = resolve(frame)

            if rect and rect.right - rect.left > 0 then
                local limit = { left = 0, right = root.width }
                local owner = root
                -- A caption must also stay within the control that owns it.
                local parent = frame.parent

                if
                    options.captions
                    and frame.kind == 'FontString'
                    and parent
                    and (parent.kind == 'Button' or parent.kind == 'CheckButton')
                    and parent.fontString == frame
                then
                    local box = resolve(parent)

                    if box then
                        limit = { left = box.left, right = box.right }
                        owner = parent
                    end
                end

                local current, previous = frame.parent, frame
                local exempt = false

                -- Only a ScrollFrame's scroll child is clipped by it; its own
                -- bars and decorations are ordinary children.
                while owner == root and current and current ~= root do
                    -- options.container(frame) marks a bounded surface such as a card.
                    if options.container and options.container(current) then
                        local box = resolve(current)

                        if box then
                            limit = { left = box.left, right = box.right }
                            owner = current
                        end

                        break
                    end

                    if current.kind == 'ScrollFrame' and current.scrollChild == previous then
                        if options.horizontalScroll and options.horizontalScroll[current] then
                            exempt = true
                            break
                        end

                        local clip = resolve(current)

                        if clip then
                            limit = { left = clip.left, right = clip.right }
                            owner = current
                        end

                        break
                    end

                    previous = current
                    current = current.parent
                end

                if not exempt and (rect.right > limit.right + tolerance or rect.left < limit.left - tolerance) then
                    problems[#problems + 1] = { frame = frame, rect = rect, limit = limit, owner = owner }
                end
            end
        end
    end

    return problems
end

function audit.describe(problem)
    local frame = problem.frame
    local label = frame.text or (frame.fontString and frame.fontString.text) or frame.tooltip or ''

    return string.format(
        '%s %q [%.1f..%.1f] outside [%.1f..%.1f]',
        frame.kind,
        tostring(label):sub(1, 40),
        problem.rect.left,
        problem.rect.right,
        problem.limit.left,
        problem.limit.right
    )
end

function audit.assertContained(root, frames, message, options)
    local problems = audit.overflows(root, frames, options)

    if #problems > 0 then
        local lines = {}

        for index = 1, math.min(#problems, 12) do
            lines[#lines + 1] = audit.describe(problems[index])
        end

        error(
            (message or 'controls extend outside their pane') .. ' (' .. #problems .. '):\n  ' .. table.concat(
                lines,
                '\n  '
            ),
            2
        )
    end
end

-- Drawn controls (not containers or decoration) intersecting rect, a
-- rectangle in root coordinates; exclude(frame) skips the corner's owner.
local controls = { Button = true, CheckButton = true, EditBox = true, Slider = true, FontString = true }

function audit.intersecting(root, frames, rect, exclude)
    local resolve = audit.resolver(root)
    local found = {}

    for _, frame in ipairs(frames) do
        if
            controls[frame.kind]
            and frame.visible
            and descends(frame, root)
            and not (exclude and exclude(frame))
            and not (frame.kind == 'FontString' and (frame.text or '') == '')
        then
            local box = resolve(frame)

            if
                box
                and box.right - box.left > 0
                and box.left < rect.right - .5
                and rect.left < box.right - .5
                and box.bottom < rect.top - .5
                and rect.bottom < box.top - .5
            then
                found[#found + 1] = { frame = frame, rect = box, limit = rect, owner = root }
            end
        end
    end

    return found
end

function audit.assertCornerFree(root, frames, rect, message, exclude)
    local found = audit.intersecting(root, frames, rect, exclude)

    if #found > 0 then
        local lines = {}

        for index = 1, math.min(#found, 8) do
            lines[#lines + 1] = audit.describe(found[index])
        end

        error(
            (message or 'controls under the page Help corner') .. ' (' .. #found .. '):\n  ' .. table.concat(
                lines,
                '\n  '
            ),
            2
        )
    end
end

return audit
