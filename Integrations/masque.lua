-- Optional Masque integration for the recommendation preview window: skins the preview icons through Masque's public
-- Group API (AddButton, RemoveButton, ReSkin) and lets the user pick a Masque skin from Rotation Master's settings.
-- Owns the per-window Masque state (masqueOwner on each icon, masqueEpoch and masqueBusy on the window), the
-- status published for the settings page and the skin choice calls. Must not copy Masque's saved data or store its
-- own skin choice (Masque owns the selection), and must not call into the provider on the hot path: a window or
-- profile change during any provider call invalidates the work through the epoch and generation checks.
-- Loaded from RotationMaster.toc after Integrations/encounters.lua; the preview window calls Configure/Release/Resize.
local _, addon = ...
-- Optional separately installed provider. All provider calls are cold lifecycle
-- work except ReSkin on an actual dimension change; publications only set art.
local status = { state = 'disabled', reason = 'disabled', enabled = false }
local bindSkinCallback
local skinBusy = false
local configNotifyBusy = false

-- ============================================================================
-- Status and window lifecycle
-- ============================================================================

-- Replaces the published status.
-- @param window table|nil  The preview window; its profile gives whether the preview option is on and its Masque
--   version fields give the version and whether that version has been tested against the source. May be nil.
-- @param state string  'disabled', 'connected', 'missing', 'incompatible', 'unavailable' or 'error'.
-- @param reason string  The reason code for the state.
local function publish(window, state, reason)
    status = {
        state = state,
        reason = reason,
        enabled = window and window.profile.preview_masque == true or false,
        version = window and window.masqueVersion,
        apiMinor = window and window.masqueMinor,
        nativeAcceptance = 'unverified',
        versionStatus = window and window.masqueVersion == '12.1.0' and window.masqueMinor == 110210 and 'source-tested'
            or 'unverified',
    }
end

-- Opens or closes Masque's own settings panel through its documented /masque entry point.
-- @return boolean  True when the dispatch completed, not necessarily that a settings window became visible; false for a
--   foreign caller or when Masque has no slash command.
--
-- User action only.
function addon:ToggleMasqueSettings()
    if not rawequal(self, addon) then
        return false
    end

    local ok, dispatched = pcall(function()
        local commands = SlashCmdList

        if type(commands) ~= 'table' then
            return false
        end

        local toggle = commands.MASQUE

        if type(toggle) ~= 'function' then
            return false
        end

        toggle('')
        return true
    end)

    return ok and dispatched == true
end

-- Returns a copy of the published status table for the settings page.
-- @return table  {state, reason, enabled, version, apiMinor, nativeAcceptance, versionStatus}.
function addon:GetMasquePreviewStatus()
    local copy = {}

    for key, value in pairs(status) do
        copy[key] = value
    end

    return copy
end

-- Shows the icon's own texture again and hides its Masque surface (the unskinned look).
-- @param icon table  The preview icon.
local function baseline(icon)
    if icon.masqueSurface then
        icon.masqueSurface:Hide()
    end

    icon.texture:Show()
end

-- Detaches one icon from its Masque group and restores the baseline.
-- @param icon table  The preview icon.
--
-- A failed detach quarantines the icon for good.
local function remove(icon)
    local owner = icon.masqueOwner
    icon.masqueOwner = nil
    baseline(icon)

    if owner then
        -- Clear ownership before crossing the provider boundary. A failed detach is
        -- terminal for this surface: never allocate more frames or hand it elsewhere.
        local ok = pcall(owner.remove, owner.group, icon.masqueSurface)

        if not ok then
            icon.masqueQuarantined = true
        end

        baseline(icon)
    end
end

-- Releases every icon of the window from Masque and invalidates any work still in flight for it (new epoch).
-- @param window table  The preview window.
--
-- Safe to call at any time, including from inside provider callbacks.
function addon:ReleaseMasquePreview(window)
    window.masqueEpoch = (window.masqueEpoch or 0) + 1

    if window.masqueSkinLink then
        window.masqueSkinLink.window = nil
        window.masqueSkinLink.profile = nil
        window.masqueSkinLink = nil
    end

    window.masqueProvider = nil
    window.masqueGroup = nil
    local busy = window.masqueBusy
    window.masqueBusy = true

    for _, icon in ipairs(window.icons) do
        remove(icon)
    end

    window.masqueBusy = busy
    publish(window, 'disabled', 'released')
end

-- Returns the icon's Masque surface button (creating it once), hidden until the skin is applied.
-- @param icon table  The preview icon.
-- @return table  The surface button.
local function surface(icon)
    local child = icon.masqueSurface

    if not child then
        child = CreateFrame('Button', nil, icon)
        child:SetPoint('TOPLEFT', icon, 'TOPLEFT', 0, 0)
        child:EnableMouse(false)
        child.texture = child:CreateTexture(nil, 'ARTWORK')
        child.texture:SetAllPoints(child)
        child.normal = child:CreateTexture(nil, 'ARTWORK')
        child.normal:SetAllPoints(child)
        icon.masqueSurface = child
    end

    child:Hide()
    return child
end

-- Reads Masque's version string from its addon metadata.
-- @return string|nil  The version (at most 64 characters); nil when it cannot be read.
local function nativeVersion()
    local namespace = C_AddOns
    local get = namespace and namespace.GetAddOnMetadata or GetAddOnMetadata

    if type(get) == 'function' then
        local value = get('Masque', 'Version')

        if type(value) == 'string' then
            return value:sub(1, 64)
        end
    end
end

-- Attaches (or detaches, when the option is off or Masque is missing or incompatible) the window's icons to a Masque
-- group named "RecommendationPreview", and publishes the outcome.
-- @param window table  The preview window.
--
-- Every step re-checks that the window, profile and epoch are unchanged, because the provider can call back into this
-- addon synchronously.
function addon:ConfigureMasquePreview(window)
    -- Reentry invalidates the outer lease. It cannot attach a competing owner
    -- while an AddButton/RemoveButton call is still on the provider's stack.
    if window.masqueBusy then
        self:ReleaseMasquePreview(window)
        publish(window, 'unavailable', 'reentry')
        return
    end

    window.masqueBusy = true
    window.masqueEpoch = (window.masqueEpoch or 0) + 1
    local epoch = window.masqueEpoch
    local generation, profile = window.generation, window.profile

    -- Tells whether this configure call is still the current one for the same window, generation and profile.
    -- @return boolean  True while it is.
    local function valid()
        return window:Valid()
            and window.generation == generation
            and rawequal(window.profile, profile)
            and window.masqueEpoch == epoch
    end

    -- Releases the window and publishes the failure, unless the call was already superseded.
    -- @param state string  The state to publish.
    -- @param reason string  The reason code to publish.
    local function fail(state, reason)
        if not valid() then
            return
        end

        self:ReleaseMasquePreview(window)
        publish(window, state, reason)
    end

    local ok = pcall(function()
        if not valid() then
            return
        end

        if window.profile.preview_masque ~= true then
            fail('disabled', 'disabled')
            return
        end

        local provider, minor = LibStub('Masque', true)

        if not valid() then
            return
        end

        window.masqueVersion = nativeVersion()
        window.masqueMinor = type(minor) == 'number' and minor or nil

        if not valid() then
            return
        end

        if provider == nil then
            fail('missing', 'missing')
            return
        end

        if type(provider) ~= 'table' then
            fail('incompatible', 'group-api')
            return
        end

        local groupFn = provider.Group

        if not valid() then
            return
        end

        if type(groupFn) ~= 'function' then
            fail('incompatible', 'group-api')
            return
        end

        local group = window.masqueGroup

        if not rawequal(provider, window.masqueProvider) then
            self:ReleaseMasquePreview(window)
            epoch = epoch + 1

            if not valid() then
                return
            end

            group = groupFn(provider, 'Rotation Master', 'RecommendationPreview')

            if not valid() then
                return
            end
        end

        if type(group) ~= 'table' then
            fail('incompatible', 'button-api')
            return
        end

        local add = group.AddButton

        if not valid() then
            return
        end

        local detach = group.RemoveButton

        if not valid() then
            return
        end

        local reskin = group.ReSkin

        if not valid() then
            return
        end

        if type(add) ~= 'function' or type(detach) ~= 'function' or type(reskin) ~= 'function' then
            fail('incompatible', 'button-api')
            return
        end

        -- Captured public function identity is the removal contract for that owner.
        for _, icon in ipairs(window.icons) do
            local owner = icon.masqueOwner

            if
                owner
                and (not rawequal(owner.group, group)
                    or owner.add ~= add
                    or owner.remove ~= detach
                    or owner.reskin ~= reskin)
            then
                fail('incompatible', 'changed-api')
                return
            end

            if icon.masqueQuarantined then
                fail('unavailable', 'detach-failed')
                return
            end
        end

        window.masqueProvider, window.masqueGroup = provider, group

        for i = 1, window.slots do
            local icon = window:EnsureIcon(i)

            if icon.masqueQuarantined then
                fail('unavailable', 'detach-failed')
                return
            end

            if not icon.masqueOwner then
                local child = surface(icon)
                child:SetSize(window.iconSize, window.iconSize)
                child.texture:SetTexture(icon.texture:GetTexture())
                local owner = { group = group, add = add, remove = detach, reskin = reskin }
                icon.masqueOwner = owner

                local added = pcall(
                    owner.add,
                    group,
                    child,
                    { Icon = child.texture, Normal = child.normal },
                    'Action',
                    true
                )

                if not valid() then
                    -- AddButton may finish after a synchronous release. Remove again after
                    -- that late completion, without touching a newly acquired baseline.
                    icon.masqueOwner = nil
                    baseline(icon)

                    if not pcall(owner.remove, group, child) then
                        icon.masqueQuarantined = true
                    end

                    baseline(icon)
                    return
                end

                if not added then
                    fail('error', 'add-failed')
                    return
                end
            end

            icon.texture:Hide()
            icon.masqueSurface:Show()
        end

        if bindSkinCallback then
            bindSkinCallback(provider, group, window)
        end

        if not valid() then
            return
        end

        publish(window, 'connected', 'attached')
    end)

    if not ok then
        fail('error', 'provider-error')
    end

    window.masqueBusy = false
end

-- Resizes one icon's surface and asks Masque to reskin it, only when the size really changed.
-- @param window table  The preview window.
-- @param icon table  The preview icon.
--
-- This is the one provider call that is not cold lifecycle work. A failed reskin releases the window and publishes an
-- error.
function addon:ResizeMasquePreviewIcon(window, icon)
    local owner = icon.masqueOwner
    local child = icon.masqueSurface

    if not owner or not child then
        return
    end
    if math.abs(child:GetWidth() - window.iconSize) <= .1 and math.abs(child:GetHeight() - window.iconSize) <= .1 then
        return
    end

    local epoch = window.masqueEpoch
    child:SetSize(window.iconSize, window.iconSize)

    if not window:Valid() or epoch ~= window.masqueEpoch then
        return
    end

    window.masqueBusy = true
    local ok = pcall(owner.reskin, owner.group, child)
    window.masqueBusy = false

    if not ok and window:Valid() and epoch == window.masqueEpoch then
        self:ReleaseMasquePreview(window)
        publish(window, 'error', 'reskin-failed')
    end
end

-- ============================================================================
-- Skin choice
-- ============================================================================

-- Cold native skin controls consume Masque's public AceConfig option contract.
-- Masque owns the selection; RM neither copies its DB nor stores another skin.
local defaultSkin = 'Blizzard Classic'
local skinLinks = setmetatable({}, { __mode = 'k' })

-- Tells the preview (addon.previewSkinChanged, when set) that the skin changed, under pcall.
local function notifySkin()
    pcall(function()
        local notify = addon.previewSkinChanged

        if type(notify) == 'function' then
            notify()
        end
    end)
end

-- An external options setter does not invalidate AceConfig's cached widgets.
-- Notify only the separately installed provider's existing registry, on a user
-- skin action. No GUI library is bundled or loaded by this optional refresh.
local function notifyMasqueOptions()
    if configNotifyBusy then
        return
    end

    configNotifyBusy = true

    pcall(function()
        local registry = LibStub('AceConfigRegistry-3.0', true)

        if type(registry) == 'table' and type(registry.NotifyChange) == 'function' then
            registry:NotifyChange('Masque')
        end
    end)

    configNotifyBusy = false
end

-- Reskins every attached icon of the current preview window for a group (or restores the baseline when disabled).
-- @param provider table  The Masque library.
-- @param group table  The Masque group.
-- @param disabled boolean|nil  True to restore the baseline instead of reskinning.
-- @return boolean  True when nothing needed doing or the refresh worked; false when the window was busy, changed or
--   failed.
local function refreshSkin(provider, group, disabled)
    local window = addon.nextWindow

    if
        not window
        or not window:Valid()
        or window.profile.preview_masque ~= true
        or not rawequal(window.masqueProvider, provider)
        or not rawequal(window.masqueGroup, group)
    then
        return true
    end
    if window.masqueBusy then
        return false
    end

    local epoch, generation = window.masqueEpoch, window.generation

    -- Tells whether the window is the same one, in the same epoch and generation, as when the refresh started.
    -- @return boolean  True while it is.
    local function valid()
        return window:Valid() and window.masqueEpoch == epoch and window.generation == generation
    end

    window.masqueBusy = true

    local ok = pcall(function()
        for _, icon in ipairs(window.icons) do
            local owner = icon.masqueOwner

            if owner and rawequal(owner.group, group) then
                if disabled then
                    baseline(icon)
                else
                    local child = icon.masqueSurface
                    child.texture:SetTexture(icon.texture:GetTexture())
                    owner.reskin(group, child)

                    if not valid() then
                        return
                    end

                    -- Parent visibility belongs to recommendations/samples, including empties.
                    child.texture:Show()
                    child:Show()
                    icon.texture:Hide()
                end
            end
        end
    end)

    window.masqueBusy = false

    if not valid() then
        return false
    end

    if not ok then
        addon:ReleaseMasquePreview(window)
        publish(window, 'error', 'reskin-failed')
        return false
    end

    return true
end

-- Registers (once per group) the callback that follows the user's skin changes made in Masque's own options, and links
-- it to a window.
-- @param provider table  The Masque library.
-- @param group table  The Masque group.
-- @param window table|nil  The preview window to link the callback to.
-- @param disabled boolean|nil  Masque's current "Disable" value when the caller already read it.
-- @return boolean  True when the link is in place; false when the provider or the window changed during the work or the
--   registration failed.
bindSkinCallback = function(provider, group, window, disabled)
    local profile = addon.db.profile
    local currentWindow = addon.nextWindow
    local currentGeneration = currentWindow and currentWindow.generation
    local currentActive = currentWindow and currentWindow.active
    local epoch, generation = window and window.masqueEpoch, window and window.generation

    -- Tells whether the profile, the preview window and the Masque link are all the ones this call started with.
    -- @return boolean  True while they are.
    local function valid()
        if addon.db.profile ~= profile or profile.preview_masque ~= true or addon.nextWindow ~= currentWindow then
            return false
        end
        if
            currentWindow and (currentWindow.generation ~= currentGeneration or currentWindow.active ~= currentActive)
        then
            return false
        end

        return not window or window:Valid()
            and window.masqueEpoch == epoch
            and window.generation == generation
            and rawequal(window.masqueProvider, provider)
            and rawequal(window.masqueGroup, group)
    end

    if not valid() then
        return false
    end

    local register = group.RegisterCallback

    if not valid() or type(register) ~= 'function' then
        return false
    end

    local link = skinLinks[group]

    if not link then
        link = { provider = provider, register = register, failed = true }
        skinLinks[group] = link

        local ok = pcall(
            register,
            group,
            function(changed, option, value)
                if
                    skinBusy or link.refreshing or not rawequal(changed, group) or not rawequal(link.provider, provider)
                then
                    return
                end

                local current = link.window

                if not link.profile or addon.db.profile ~= link.profile or link.profile.preview_masque ~= true then
                    return
                end

                if current then
                    if
                        not current:Valid()
                        or current.masqueBusy
                        or current.masqueEpoch ~= link.epoch
                        or current.generation ~= link.generation
                        or not rawequal(current.masqueProvider, provider)
                        or not rawequal(current.masqueGroup, group)
                    then
                        return
                    end
                elseif addon.nextWindow then
                    return
                end

                if option == 'Disabled' then
                    link.disabled = value == true
                end

                link.refreshing = true
                local refreshed = refreshSkin(provider, group, link.disabled)
                link.refreshing = false

                if refreshed then
                    notifySkin()
                end
            end,
            'SkinID',
            'Reset',
            'Disabled'
        )

        if not valid() then
            return false
        end

        link.failed = not ok

        if not ok then
            return false
        end
    end

    if link.failed or link.register ~= register or not rawequal(link.provider, provider) then
        return false
    end

    if disabled == nil then
        local optionsFn = group.GetOptions

        if not valid() then
            return false
        end

        if type(optionsFn) == 'function' then
            local ok, value = pcall(function()
                local options = optionsFn(group)

                if not valid() then
                    return
                end

                local option = options.args.Disable
                local get = option.get

                if not valid() then
                    return
                end

                local value = get({ 'Disable', arg = option.arg })

                if not valid() then
                    return
                end

                return value
            end)

            if not valid() then
                return false
            end

            if ok and type(value) == 'boolean' then
                disabled = value
            end
        end
    end

    if disabled == nil then
        disabled = link.disabled
    end

    if not valid() then
        return false
    end

    link.disabled = disabled == true
    link.window = window
    link.profile = profile
    link.epoch = epoch
    link.generation = generation

    if window then
        window.masqueSkinLink = link
    end

    if window and link.disabled then
        for _, icon in ipairs(window.icons) do
            baseline(icon)
        end
    end

    return true
end

-- Reads Masque's option table for the preview group.
-- @return table|nil  The context {disabled, provider, group, option, skins, info, valid, window} for the skin calls;
--   nil when the option is off or Masque's API is not the expected shape.
--
-- valid() reports whether the context is still current; every caller must check it after each provider call.
local function skinContext()
    local profile = addon.db and addon.db.profile

    if type(profile) ~= 'table' or profile.preview_masque ~= true then
        return
    end

    local window = addon.nextWindow
    local generation = window and window.generation
    local epoch = window and window.masqueEpoch

    -- Tells whether the profile option, preview window, generation and epoch are unchanged.
    -- @return boolean  True while they are.
    local function valid()
        return addon.db.profile == profile
            and profile.preview_masque == true
            and addon.nextWindow == window
            and (not window or window:Valid() and window.generation == generation and window.masqueEpoch == epoch)
    end

    if not valid() then
        return
    end

    local provider = LibStub('Masque', true)

    if
        not valid()
        or type(provider) ~= 'table'
        or type(provider.Group) ~= 'function'
        or type(provider.GetSkins) ~= 'function'
    then
        return
    end

    local group = provider:Group('Rotation Master', 'RecommendationPreview')

    if not valid() or type(group) ~= 'table' or type(group.GetOptions) ~= 'function' then
        return
    end

    local options = group:GetOptions()

    if not valid() then
        return
    end

    local option = type(options) == 'table' and type(options.args) == 'table' and options.args.SkinID

    if
        type(option) ~= 'table'
        or type(option.get) ~= 'function'
        or type(option.set) ~= 'function'
        or type(option.values) ~= 'table'
    then
        return
    end

    local disable = options.args.Disable

    if type(disable) ~= 'table' or type(disable.get) ~= 'function' then
        return
    end

    local disabled = disable.get({ 'Disable', arg = disable.arg })

    if not valid() or type(disabled) ~= 'boolean' then
        return
    end

    local skins = provider:GetSkins()

    if not valid() or type(skins) ~= 'table' then
        return
    end

    local attached = window
        and rawequal(window.masqueProvider, provider)
        and rawequal(window.masqueGroup, group)
        and window
        or nil

    if not bindSkinCallback(provider, group, attached, disabled) or not valid() then
        return
    end

    return {
        disabled = disabled,
        provider = provider,
        group = group,
        option = option,
        skins = skins,
        info = { 'SkinID', arg = option.arg },
        valid = valid,
        window = window,
    }
end

-- Tells whether an id is a selectable skin.
-- @param context table  The skin context from skinContext.
-- @param id any  The skin id to test.
-- @return boolean  True when id is a short string that Masque lists as a selectable skin.
local function validSkin(context, id)
    return type(id) == 'string'
        and #id > 0
        and #id <= 128
        and context.option.values[id] ~= nil
        and type(context.skins[id]) == 'table'
end

-- Lists the selectable Masque skins.
-- @return table[]  The skins as {value=string, text=string} rows, default skin first; just the default skin when Masque
--   is unavailable, disabled for the group or busy. Pipes and control characters are escaped in the text.
-- @return boolean  True when the rows come from Masque; false for the fallback.
function addon:GetPreviewSkinChoices()
    local fallback = { { value = defaultSkin, text = defaultSkin } }

    if not rawequal(self, addon) or skinBusy then
        return fallback, false
    end

    skinBusy = true

    local ok, rows = pcall(function()
        local context = skinContext()

        if not context or context.disabled then
            return
        end

        local result = {}

        for id in pairs(context.option.values) do
            if validSkin(context, id) then
                result[#result + 1] = { value = id, text = id:gsub('|', '||'):gsub('[%z\1-\31\127]', '?') }
            end

            if #result > 512 then
                return
            end
        end

        if not context.valid() or #result == 0 then
            return
        end

        table.sort(result, function(a, b)
            if a.value == defaultSkin then
                return b.value ~= defaultSkin
            elseif b.value == defaultSkin then
                return false
            else
                return a.value < b.value
            end
        end)

        return result
    end)

    skinBusy = false

    if ok and rows then
        return rows, true
    end

    return fallback, false
end

-- Returns the skin Masque has selected for the preview group.
-- @return string  The skin id, or the default skin when it cannot be read.
function addon:GetPreviewSkin()
    if not rawequal(self, addon) or skinBusy then
        return defaultSkin
    end

    skinBusy = true

    local ok, id = pcall(function()
        local context = skinContext()

        if not context or context.disabled then
            return
        end

        local value = context.option.get(context.info)

        if context.valid() and validSkin(context, value) then
            return value
        end
    end)

    skinBusy = false
    return ok and id or defaultSkin
end

-- Selects a skin through Masque's own option setter, verifies it by reading it back, then reskins the preview and
-- notifies Masque's options registry.
-- @param id string  The skin id.
-- @return boolean  True only when the new skin is confirmed in effect.
function addon:SetPreviewSkin(id)
    if not rawequal(self, addon) or skinBusy or configNotifyBusy then
        return false
    end

    skinBusy = true
    local context

    local ok, changed = pcall(function()
        context = skinContext()

        if not context or context.disabled or not validSkin(context, id) then
            return false
        end

        context.option.set(context.info, id)

        if not context.valid() then
            return false
        end

        local selected = context.option.get(context.info)
        return context.valid() and selected == id
    end)

    skinBusy = false

    if not ok or changed ~= true then
        return false
    end

    if
        context.window
        and (not rawequal(context.window.masqueProvider, context.provider)
            or not rawequal(context.window.masqueGroup, context.group))
    then
        self:ConfigureMasquePreview(context.window)

        if
            not context.valid()
            or not rawequal(context.window.masqueProvider, context.provider)
            or not rawequal(context.window.masqueGroup, context.group)
        then
            return false
        end
    end

    if not refreshSkin(context.provider, context.group) or not context.valid() then
        return false
    end

    notifyMasqueOptions()

    if not context.valid() then
        return false
    end

    notifySkin()
    return true
end
