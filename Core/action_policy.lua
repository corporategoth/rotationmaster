-- Spell and item readiness for the poll, and the implicit auto-attack fallback. It owns the per-poll readiness memo
-- (known, usable, off cooldown, in range) that conditions and both evaluation engines share; it must not decide what to
-- recommend, only whether something can be used now. Every game value goes through addon.Platform, which applies the
-- restricted-client rules; an unreadable answer reads as not ready. Loaded from RotationMaster.toc after
-- Core/custom_condition_owner.lua; main.lua and Diagnostics/glow.lua call into it and tests/action_policy.lua tests it.

local _, addon = ...

-- ============================================================================
-- Readiness memo
-- ============================================================================

-- Observations live for one evaluation only. Conditions can still inspect
-- other spells; a condition never overrides the action's own availability.
-- One memo per evaluation: each observation is made at most once per poll.
-- Entries carry the stamp of the poll that made them, so reset() starts a new
-- poll without discarding (and reallocating) the tables.
local function buildReadiness(platform)
    local spells, spellStamps, items, itemStamps, availability, availableStamps = {}, {}, {}, {}, {}, {}
    local marks, markStamps = {}, {}
    local range, resetRange = platform:NewSpellRangeReader()
    local stamp, now = 0, nil
    -- Profile options read once per poll (reset): "Ignore Mana" lets a spell
    -- the game calls unusable only for want of mana through, "Ignore Range"
    -- skips the range read of spells and items alike.
    local ignoreMana, ignoreRange = false, false

    -- True for a readable positive whole number; restricted or malformed ids are never ready.
    local function validID(id)
        return platform:CanReadValue(id) and type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
    end

    -- The readiness answer handed to conditions and the sequence executor: true when the spell (kind spell, pet, any,
    -- ranged or assisted) or item can be used right now, honoring Ignore Mana and Ignore Range. Memoized per poll by
    -- id, so the platform is read at most once per id per poll; every unreadable answer reads as not ready.
    local function ready(kind, id, itemID)
        if not validID(id) then
            return false
        end

        if kind == "item" then
            if not validID(itemID) then
                return false
            end

            if itemStamps[itemID] ~= stamp then
                local ready = platform:IsItemReady(itemID, now)

                if ignoreRange then
                    items[itemID] = ready == true
                else
                    local observed = ready == true and platform:GetItemRangeState(itemID, "target")

                    items[itemID] = type(observed) == "table"
                        and (observed.applicable == false or observed.inRange == true)
                end

                itemStamps[itemID] = stamp
            end

            return items[itemID]
        end

        -- A Set Mark step is ready while its unit exists, does not carry the mark yet and you may place marks
        -- (Platform/raid_mark_actions.lua); an unreadable answer is not ready.
        if kind == "mark" then
            if markStamps[id] ~= stamp then
                marks[id] = platform:IsMarkActionReady(id) == true
                markStamps[id] = stamp
            end

            return marks[id]
        end

        -- "ranged" is the implicit Shoot or Auto Shot: a player spell whose
        -- range is read from its action button first (addon:ResolveImplicitAttack).
        local ranged = kind == "ranged"

        if kind ~= "spell" and kind ~= "pet" and kind ~= "any" and not ranged then
            -- An assisted step resolves to Blizzard's suggested player spell
            -- and is held to exactly the readiness of a spell step.
            if kind ~= "assisted" then
                return false
            end

            kind = "spell"
        end

        local results, stamps = spells[kind], spellStamps[kind]

        if not results then
            results, stamps = {}, {}
            spells[kind], spellStamps[kind] = results, stamps
        end

        if stamps[id] ~= stamp then
            local known = kind ~= "pet" and platform:IsSpellKnown(id, false) == true

            if not known and kind ~= "spell" and not ranged then
                known = platform:IsSpellKnown(id, true) == true
            end

            -- Vehicle, override and possession abilities are in neither
            -- spellbook; while such a bar is up, the bound button decides.
            if
                not known
                and not ranged
                and addon.GetActionContext
                and addon:GetActionContext() ~= "player"
                and addon.IsBoundActionReady
            then
                results[id] = addon:IsBoundActionReady(id, now) == true
                stamps[id] = stamp
                return results[id]
            end

            if known and availableStamps[id] ~= stamp then
                local usable, power = platform:IsSpellUsable(id)
                -- IsUsableSpell answers false, true when only the resource is
                -- missing (the same pair the action bars color blue), so the
                -- option accepts that pair as well as a plainly usable spell.
                -- An unreadable answer (usable is nil) is never accepted.
                local affordable = usable == true and power == false or ignoreMana and (usable == true or power == true)
                availability[id] = affordable == true and platform:IsSpellReady(id, now) == true
                availableStamps[id] = stamp
            end

            local result = false

            if known and availability[id] then
                if ignoreRange then
                    result = true
                elseif id == 6603 and kind ~= "pet" then
                    local beyond = platform:IsBeyondMeleeRange("target")
                    result = beyond ~= nil and beyond == false
                else
                    local bar

                    if ranged and addon.GetBoundActionRange then
                        bar = addon:GetBoundActionRange(id)
                    end

                    if bar ~= nil then
                        result = bar == true
                    else
                        local observed = range(id, "target", ranged and "spell" or kind)

                        result = type(observed) == "table"
                            and (observed.applicable == false or observed.inRange == true)
                    end
                end
            end

            results[id] = result
            stamps[id] = stamp
        end

        return results[id]
    end

    -- Starts a new poll on the same memo: bumping the stamp invalidates every entry without reallocating, and the
    -- profile options are re-read so a settings change takes effect on the next poll.
    local function reset(at)
        stamp, now = stamp + 1, at
        local db = addon.db
        local profile = db and db.profile

        ignoreMana, ignoreRange =
            profile ~= nil and profile.ignore_mana == true, profile ~= nil and profile.ignore_range == true

        if resetRange then
            resetRange()
        end
    end

    return ready, reset
end

-- Returns a fresh readiness function with its own memo for one evaluation at time now. Callers that evaluate outside
-- the steady poll (previews, glow diagnostics) use this so they never disturb the shared poll memo.
function addon:NewActionReadiness(now)
    local ready, reset = buildReadiness(self.Platform)
    reset(now)
    return ready
end

-- Steady-state polling keeps one memo and starts a new poll on it.
local shared

-- Returns the shared readiness function after starting a new poll on it. The memo is rebuilt only when the platform
-- object is replaced (tests do this); steady-state polls reuse the same tables to avoid per-poll allocation.
function addon:ResetActionReadiness(now)
    if not shared or shared.platform ~= self.Platform then
        shared = { platform = self.Platform }
        shared.ready, shared.reset = buildReadiness(self.Platform)
    end

    shared.reset(now)
    return shared.ready
end

-- Ranged auto-attacks in preference order: Auto Shot, then wand Shoot.
local RANGED_ATTACKS = { 75, 5019 }
local scratch = {}

-- Asks addon:FindSpell (buttons.lua) whether the spell id is on the action bars and returns its answer, nil when it
-- is not. Reuses one scratch table so the poll path does not allocate.
local function bound(self, id)
    scratch[1] = id
    local found = self:FindSpell(scratch)
    scratch[1] = nil
    return found
end

-- ============================================================================
-- Implicit auto-attack
-- ============================================================================

-- The implicit auto-attack (Attack or Shoot), for a poll whose rotation
-- recommends nothing and whose Stop (if any) did not suppress it. Both
-- engines call it only then, so its range reads cost nothing on other polls.
-- ready is the poll's readiness memo. Returns the spell to highlight, or nil.
--   In melee range: Attack (6603), on the same checks as before.
--   Beyond melee range: Auto Shot (75), else wand Shoot (5019) while a wand
--   is equipped, if it is on the action bars, ready and the target is in its
--   range, and no ranged auto-attack is already repeating.
--   Melee range unknown (unreadable, uncertain or unsupported): nothing.
-- IsMeleeAttackNeeded gates the client policy and the target (combat,
-- attackable, alive, no vehicle), so restricted clients never get here.
function addon:ResolveImplicitAttack(ready)
    local platform = self.Platform
    local need, _, why = platform:IsMeleeAttackNeeded("target")

    if need == true then
        if ready("spell", 6603) then
            return bound(self, 6603)
        end

        return nil
    end

    if need ~= false or (why ~= "beyond-melee" and why ~= "attack-active") then
        return nil
    end

    local beyond = why == "beyond-melee" or nil

    for i = 1, #RANGED_ATTACKS do
        local id = RANGED_ATTACKS[i]
        local spell = bound(self, id)

        if spell then
            -- Attack is already on: the range was not read yet. Read it only
            -- for a character with a ranged auto-attack on the bars.
            if beyond == nil then
                beyond = platform:IsBeyondMeleeRange("target") == true
            end

            if not beyond then
                return nil
            end

            if id ~= 5019 or platform:IsWandEquipped() == true then
                if platform:IsAutoRepeatActive(id) ~= false then
                    return nil
                end
                if ready("ranged", id) then
                    return spell
                end
            end
        end
    end

    return nil
end
