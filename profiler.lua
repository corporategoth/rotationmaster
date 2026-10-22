local _, addon = ...

local string, pairs, protect, kind = string, pairs, pcall, type
local function clock()
    if kind(GetTimePreciseSec)=='function' then return GetTimePreciseSec,1 end
    if kind(debugprofilestop)=='function' then return debugprofilestop,.001 end
    if kind(GetTime)=='function' then return GetTime,1 end
    return nil,1
end
local function readClock(fn)
    if not fn then return end
    local ok,value=protect(fn)
    if ok and kind(value)=='number' and value==value and value>=0 and value<math.huge then return value end
end
local function noop()end
local function nopChild(self)return self end

local function Constructor(enabled)
    if enabled==false then
        return {total=0,count=0,min=0,max=0,startTime=0,children={},start=noop,stop=noop,report=noop,reset=noop,child=nopChild}
    end
    -- Resolve capability once per profiler, never probe/reset a shared clock.
    local timer,scale=clock()
    local rv = {
        -- Public numeric timing fields remain seconds for existing consumers.
        total = 0.0,
        count = 0,
        min = 0.0,
        max = 0.0,
        unavailable = 0,
        children = {},

        startTime = 0.0,
        start = function(self)
            local value=readClock(timer)
            self._started,self._clockValid=true,value~=nil
            self.startTime=value and value*scale or 0
        end,

        stop = function(self)
            if not self._started then return end
            self._started=false
            local ending=readClock(timer)
            local runtime=self._clockValid and ending and ending*scale-self.startTime
            self.startTime=0.0
            if not runtime or runtime<0 or runtime~=runtime or runtime==math.huge then
                self.unavailable=self.unavailable+1
                return
            end
            if self.count == 0 or runtime < self.min then self.min=runtime end
            if runtime > self.max then self.max=runtime end
            self.total=self.total+runtime
            self.count=self.count+1
        end,

        report = function(self, full)
            if self.count == 0 then
                if self.unavailable>0 then return string.format('0 measured runs; %d unavailable',self.unavailable)end
                return
            end
            local rv=string.format('%d runs (inclusive): total=%.3f ms, min=%.3f ms, avg=%.3f ms, max=%.3f ms',
                self.count,self.total*1000,self.min*1000,(self.total/self.count)*1000,self.max*1000)
            if self.unavailable>0 then rv=rv..string.format('; %d unavailable',self.unavailable)end
            if full then
                local parts={}
                for name,child in pairs(self.children) do
                    local summary=child:report(full)
                    if summary then parts[#parts+1]=name..'['..summary..']'end
                end
                if #parts>0 then rv=rv..' { '..table.concat(parts,', ')..' }; child scopes overlap and are not additive' end
            end
            return rv
        end,

        reset = function(self)
            self.total = 0.0
            self.count = 0
            self.min = 0.0
            self.max = 0.0
            self.unavailable=0
            self.startTime=0.0
            self._started,self._clockValid=false,false
            self.children = {}
        end,

        child = function(self, name)
            if self.children[name] == nil then self.children[name] = Constructor() end
            return self.children[name]
        end
    }
    return rv
end

function addon:ProfiledCode(enabled)
    return Constructor(enabled)
end

-- Main owns only roots built from this literal factory. Public nil remains FULL.
local ownedFactory=addon.ProfiledCode
local ownedRoot,ownedMode,ownedMethods,consumed
local refreshVersion=0
local methods={'start','stop','child','report','reset'}
local function collecting(owner)
    local level=owner.db and owner.db.profile and owner.db.profile.loglevel
    return type(level)=='number'and level>=3
end
local function unmodified(owner)
    if owner.evaluationProfile~=ownedRoot or not ownedRoot or owner.ProfiledCode~=ownedFactory then return false end
    for _,name in ipairs(methods)do if ownedRoot[name]~=ownedMethods[name]then return false end end
    return true
end
local function build(owner,mode,initial)
    refreshVersion=refreshVersion+1;local version=refreshVersion
    local before,db=owner.evaluationProfile,owner.db;local profile=db and db.profile
    local factory=owner.ProfiledCode
    if not initial and (not unmodified(owner)or mode==ownedMode)then return false end
    if initial and factory~=ownedFactory then
        -- Exact predecessor initialization for a foreign factory, including its
        -- nil argument, callouts and returned root. Never claim ownership.
        owner.evaluationProfile=factory(owner);return true
    end
    local root=factory(owner,mode)
    if refreshVersion~=version or owner.evaluationProfile~=before or owner.db~=db or db.profile~=profile
        or owner.ProfiledCode~=factory or collecting(owner)~=mode then return false end
    owner.evaluationProfile=root
    if factory==ownedFactory then
        ownedRoot,ownedMode,ownedMethods=root,mode,{}
        for _,name in ipairs(methods)do ownedMethods[name]=root[name]end
    end
    owner.lastCacheReport=GetTime()
    return true
end
function addon:RefreshEvaluationProfilerPolicy()
    if self~=addon then return false end
    return build(self,collecting(self),false)
end
function addon:ConsumeLegacyEvaluationProfilerPolicy()
    if self~=addon or consumed then return end;consumed=true
    return function(owner)if owner==addon then return build(owner,collecting(owner),true)end end,
        function(owner)
            -- Foreign report/reset callbacks retain predecessor dispatch.
            if not ownedRoot or owner.evaluationProfile~=ownedRoot or owner.ProfiledCode~=ownedFactory
                or ownedRoot.report~=ownedMethods.report or ownedRoot.reset~=ownedMethods.reset then return true end
            return collecting(owner)and ownedMode
        end
end
