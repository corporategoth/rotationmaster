local _, addon = ...

local string, pairs = string, pairs
local tablelength = addon.tablelength

local function Constructor()
    local rv = {
        total = 0.0,
        count = 0,
        min = 0.0,
        max = 0.0,
        children = {},

        startTime = 0.0,
        start = function(self)
            self.startTime = GetTime()
        end,

        stop = function(self)
            local runtime = GetTime() - self.startTime
            if self.min == 0.0 or runtime < min then
                self.min = runtime
            end
            if runtime > self.max then
                self.max = runtime
            end

            self.total = self.total + runtime
            self.count = self.count + 1
            self.startTime = 0.0
        end,

        report = function(self, full)
            if self.count == 0 then return end
            local rv = string.format("%d runs: %.03f min, %.03f avg, %.03f max", self.count, self.min, (self.total / self.count), self.max)
            if full and tablelength(self.children) > 0 then
                rv = rv .. " { "
                local first = true
                for name, child in pairs(self.children) do
                    if first then
                        first = false
                    else
                        rv = rv .. ", "
                    end
                    rv = rv .. name .. "[" .. child:report(full) .. "]"
                end
                rv = rv .. " }"
            end
            return rv
        end,

        reset = function(self)
            self.total = 0.0
            self.count = 0
            self.min = 0.0
            self.max = 0.0
            self.children = {}
        end,

        child = function(self, name)
            if self.children[name] == nil then
                self.children[name] = Constructor()
            end
            return self.children[name]
        end
    }

    return rv
end

function addon:ProfiledCode()
    return Constructor()
end
