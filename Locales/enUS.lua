local addon_name = ...

local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true)
if not L then return end
L['CPU capture complete. Use General > CPU report or /rm perf cpu report to view and copy it.'] = true
L['Runtime capture complete. Use General > Runtime report or /rm perf runtime report to view and copy it.'] = true
L['Memory capture complete. Use General > Memory report or /rm perf memory report to view and copy it.'] = true
L['Usage: /rm perf cpu|runtime|memory [seconds|start|stop|report], or /rm perf probe'] = 'Usage: /rm perf cpu||runtime||memory [seconds||start||stop||report], or /rm perf probe'
L['Capture stopped. Use /rm perf %s report to view and copy it.'] = true
L['Capture started for %g seconds. Close configuration, then use /rm perf %s report.'] = true
L['Choose a duration from 1 to %d seconds.'] = true
L['/rm perf probe - Check native profiler access.'] = true
L['/rm perf engine [lean|standard] - Show or choose the rotation evaluation engine.'] = '/rm perf engine [lean||standard] - Show or choose the rotation evaluation engine.'
L['Usage: /rm perf engine [lean|standard]'] = 'Usage: /rm perf engine [lean||standard]'
L['Evaluation engine: %s'] = true
L['%s is running. Stop it or wait for completion.'] = true
L['No %s report is available. Start a capture first.'] = true
L['No %s is running.'] = true
L['%s is unavailable: %s'] = true
L['/rm perf cpu|runtime|memory [seconds|stop|report] - Capture performance observations.'] = '/rm perf cpu||runtime||memory [seconds||stop||report] - Capture performance observations.'
L['Capture memory (10m)'] = true
L['Memory report'] = true
L['Stop memory capture'] = true
L['Memory capture'] = true
L['Memory capture started for 10 minutes. Normal polling is unchanged; attribution refreshes every 30 seconds and their cost is reported.'] = 'Memory capture started for 10 minutes. Normal polling is unchanged; attribution refreshes at capture start and completion, with their cost reported.'
L['Memory capture is unavailable: %s'] = true
L['Memory capture stopped. Open Memory report to copy the observations.'] = true
L['Memory capture ended with unavailable observations. Open Memory report for details.'] = true
L["Help.General.memory_capture"] = "Observe memory for ten minutes without changing polling or forcing garbage collection. /rm perf memory accepts 1–1800 seconds (default 600), plus stop and report. Whole-Lua heap is sampled each second; bounded retained counts every thirty seconds. Addon attribution refreshes only at start and completion; intermediate values are cached with unknown age. Stop completes the final boundary before you open the report. Refreshes can hitch, and their cost is reported. Heap decreases do not prove collection or a leak."
L["Help.General.memory_report"] = "Open the copyable lifetime report: whole-heap range and decreases, start/end addon attribution, explicitly cached intermediate values, retained key/row counts and capture overhead. Counts are not bytes; unavailable and capped observations stay explicit. Viewing the report never resamples memory."
L["Help.General.memory_stop"] = "Stop this explicit memory capture and retain its completed observations. Normal polling and garbage collection remain unchanged."
L["Capture runtime (10s)"] = true
L["Runtime report"] = true
L["Runtime profile"] = true
L["Runtime capture started for 10 seconds. Close configuration, then open Runtime report."] = true
L["Runtime capture is unavailable: %s"] = true
L["Runtime capture ended without complete measurements. Open Runtime report for details."] = true
L["Help.General.cpu_runtime_capture"] = "Measure normal rotation evaluation calls for ten seconds with the native profiler. /rm perf runtime accepts 1–60 seconds (default 10), plus stop and report. The 512-dispatch safety limit can end a longer capture sooner. Polling stays unchanged. Stop finalizes partial measurements; the legacy Cancel capture action still cancels. Close configuration after starting. Instrumentation adds overhead; allocation is not retained memory or proof of a leak. Cumulative CPU captures cannot overlap this capture."
L["Help.General.cpu_runtime_report"] = "Open the copyable runtime report: measured evaluation calls, native elapsed time and gross allocation/deallocation counters. Missing metrics remain unavailable. Measurement covers evaluation calls only, not all addon events or rendering. Reading the report does not sample gameplay."
L["Report"] = true
L["CPU profile"] = true
L["Capture CPU (10s)"] = true
L["CPU report"] = true
L["Native profiler probe"] = true
L["Callback arguments"] = true
L["Callback calls"] = true
L["Callback returns"] = true
L["Capability probe only; no evaluator or gameplay was measured."] = true
L["Native profiler probe is already running."] = true
L["Native profiler probe is unavailable while CPU capture is running."] = true
L["Native profiler probe is unavailable."] = true
L["call completed"] = true
L["call failed"] = true
L["disabled"] = true
L["enabled"] = true
L["exact"] = true
L["malformed"] = true
L["mismatch"] = true
L["more than one"] = true
L["not run"] = true
L["present"] = true
L["restricted"] = true
L["unavailable (context changed)"] = true
L["Bypass observation cache (reload required)"] = true
L["Enable observation cache"] = true
L["Enable observation cache (reload required)"] = true
L["Enable observation cache (pending)"] = true
L["Observation caching can reduce repeated lookups but increases table allocations. Off by default; reload to change the running mode."] = true
L["Observation cache: %s\nNext reload: %s"] = true
L["cached"] = true
L["direct"] = true
L["Cache diagnostic saved for the next reload. Active mode: %s."] = true
L["Cache diagnostic is unavailable."] = true
L["Help.General.cpu_cache_bypass"] = "Optional reuse of repeated getCached and getRetryCached lookups. Observation caching is off by default to reduce table allocations; enabling it can help conditions that repeat the same lookup. Compiled condition facts are independent of this option. The checkbox shows the saved choice for the next reload. Pending means it differs from the running mode. Use /reload to apply it; no full game restart is needed. This choice saves immediately without applying or discarding other pending settings."
L["Cancel capture"] = true
L["CPU capture requires WoW scriptProfile to be enabled before a reload. RM does not change this setting."] = true
L["CPU capture is running. Open the report after it finishes."] = true
L["No CPU capture is available. Start a capture first."] = true
L["No CPU capture is running."] = true
L["CPU capture is unavailable: %s"] = true
L["CPU capture started for 10 seconds. Close configuration to measure normal gameplay, then open CPU report."] = true
L["CPU capture cancelled."] = true
L["CPU capture could not produce valid measurements. Open CPU report for details."] = true
L["Help.General.cpu_capture"] = "Capture native cumulative function CPU costs and call counts for ten seconds. /rm perf cpu starts the same capture; /rm perf cpu 30 chooses 30 seconds (range 1–60). /rm perf cpu stop finalizes partial counters; /rm perf cpu report opens the copyable result. Capture uses live settings and does not apply pending changes. Close configuration after starting. WoW scriptProfile must already be enabled before a reload; RM never changes it or resets shared counters. Profiling itself adds overhead."
L["Help.General.cpu_report"] = "Open a selectable, copyable report with total addon CPU, measured function costs and calls, sample boundaries, and unavailable or replaced functions. Inclusive costs overlap and must not be added together. Boundary state does not prove configuration or combat stayed unchanged throughout the capture. Untracked functions and native work may account for remaining costs."
L["Help.General.cpu_cancel"] = "Cancel the active diagnostic capture without changing settings, gameplay polling, or shared profiler counters."
L["Help.General.cpu_probe"] = "Run one inert callback to check native CPU profiler capabilities and open a copyable report. This checks API access only; it does not measure gameplay, change profiling settings, reset counters, or start or cancel a capture. /rm perf probe runs the same check."
L["Invalid rotation ownership data in profile %s (%s); record preserved."] = true
L["the number of {item} you are carrying {comparison} {quantity}"] = true
L['View source'] = true
L['Change source helper'] = true
L['Dependencies (%d)'] = true
L['Function dependencies'] = true
L['Add dependency'] = true
L['Remove dependency'] = true
L['Arcane Ring'] = true
L['Ember Corners'] = true
L['Frost Shards'] = true
L['Nature Vines'] = true
L['Lightning Sweep'] = true
L['Holy Rays'] = true
L['Shadow Claws'] = true
L['Rune Diamond'] = true
L['Neutral Arcane Ring'] = true
L['Choose overlay'] = true
L['This character'] = true
L['Applies to'] = true
L['Legacy character %s data conflicts with the active profile; character data preserved.'] = true
L['Invalid rotation fallback configuration in profile %s; data preserved.'] = true
L['Help.Functions.bindings'] = 'Choose a source helper and its name in this Lua body, such as custom.ready or utils.getCached. These are dependency records even when the source and local names match; a different local name is an optional alias. The records identify helpers for loading, export and availability checks. Accepting a completion records the dependency automatically. Typing a call does not infer a dependency: add its qualified name explicitly or accept a completion. WoW globals and existing addon APIs remain directly available. Namespaces are private to this callback and do not supply self. Pass a method receiver explicitly in a namespaced dot call; object:method(x) is shorthand for object.method(object, x). Click the bound source name to open its function; the adjacent arrow changes the mapping. Pending edits offer Apply, Discard or Cancel before navigation. Renaming a function, namespace or binding does not rewrite code. Missing, disabled or invalid dependencies keep consumers unavailable.'
L['Condition summary unavailable: invalid template or values.'] = true
L['{stat} {comparison} {value}'] = true
L['{stat} {comparison} {value}%'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose health defecit {qualifier} {threshold} {comparison} {value}'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose health percentage {qualifier} {threshold}% {comparison} {value}'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose health {qualifier} {threshold} {comparison} {value}'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose mana defecit {qualifier} {threshold} {comparison} {value}'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose mana percentage {qualifier} {threshold}% {comparison} {value}'] = true
L['The number {members} members{pets} within {distance} yards of {unit} whose mana {qualifier} {threshold} {comparison} {value}'] = true
L['The {operation} health defecit of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}'] = true
L['The {operation} health of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}'] = true
L['The {operation} health percentage of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}%'] = true
L['The {operation} mana defecit of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}'] = true
L['The {operation} mana of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}'] = true
L['The {operation} mana percentage of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}%'] = true
L['A readable string, or a transient named phrase from Functions.presentation.phrase. Named values remain literal; typed predicates choose positive or negative wording. The legacy string format remains supported.'] = true
L['Test opens one condition-level dialog from any callback tab. It renders Fields UI and Help together with detached values. Committing a field value validates and evaluates once. Run test refreshes the current values, while only valid values are evaluated. Opening the dialog does not evaluate defaults. Live is opt-in and stops when the dialog closes. Committed test values are available to the debugger and stay separate from source, exports and rotation edits. Check syntax never runs a callback.'] = true
L['Test values changed. Updating results.'] = true
L['Complete the highlighted test inputs before testing.'] = true
L['The current source could not be compiled. Fix it before testing again.'] = true
L['Refresh'] = true
L['Debug output'] = true
L['Output'] = true
L['View and copy full debugger output and errors.'] = true
L['Arguments from Test'] = true
L['Set values in Test before debugging this condition.'] = true
L['Rotation Master addon instance. Public helper functions are documented in Functions.'] = true
L['Localized Rotation Master text, indexed by its English key.'] = true
L["Undo"] = true
L["Redo"] = true
L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."] = true
L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."] = true
L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."] = true
L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."] = true
L["Non-finite minimap value in profile %s: %s."] = true
L["Invalid effect ID for rotation step %s:%s:%d."] = true
L["Unknown effect type for %s:%s (%s); record preserved."] = true

local color = color

-- from main.lua

L["/rm help                - This text."] = true
L["/rm config              - Open the config dialog."] = true
L["/rm disable             - Disable battle rotation."] = true
L["/rm enable              - Enable battle rotation."] = true
L["/rm toggle              - Toggle between enabled and disabled."] = true
L["/rm current             - Print out the name of the current rotation."] = true
L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."] = "/rm set [auto||profile]  - Switch to a specific rotation, or use automatic switching again."
L["                          Manual choices are remembered for this character, specialization and action context."] = true
L["/rm check               - Check the database integrity."] = true
L["/rm repair              - Fix any DB errors found in the data with internal validation."] = true

L["No rotation is currently active."] = true
L["The current rotation is " .. color.WHITE .. "%s" .. color.INFO] = true
L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO] = true
L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."] = true
L["Invalid option " .. color.WHITE .. "%s" .. color.WARN] = true

L["Starting up version %s"] = true
L["Rotaion " .. color.WHITE .. "%s" .. color.DEBUG .. " is now available for auto-switching."] = true
L["Active rotation automatically switched to " .. color.WHITE .. "%s" .. color.INFO] = true
L["No rotation is active as there is none suitable to automatically switch to."] = true
L["Battle rotation enabled"] = true
L["Battle rotation disabled"] = true
L["Current Rotation"] = true
L["Automatic Switching"] = true
L["Toggle %s " .. color.CYAN .. "/rm toggle" .. color.RESET] = true
L["Validating database integrity"] = true

L["[Tier: %d, Column: %d]"] = true
L["Autoswitch rotation list has been updated."] = true

L["Button Fetch triggered."] = true
L["Notified configuration to update it's status."] = true
L["Removing all glows."] = true
L["Active rotation is incomplete and may not work correctly!"] = true
L["Cache hit rate at %.02f%%"] = true

-- from constants.lua

L["Spells"] = true
L["Items"] = true
L["Buffs"] = true
L["Combat"] = true
L["Character"] = true
L["Other"] = true
L["Spatial"] = true
L["Custom"] = true

L["Bind"] = true
L["Unbind"] = true
L["Own Buff"] = true
L["Own Debuff"] = true
L["Dispellable"] = true
L["your own %s"] = true
L["{unit} {{!have|do not have}} {aura}"] = true
L["{unit} {{!has|does not have}} {aura}"] = true
L["{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}"] = true
L["{unit} {stacks} {comparison} {quantity}"] = true
L["that is dispellable"] = true

L["is less than"] = true
L["is less than or equal to"] = true
L["is greater than"] = true
L["is greater than or equal to"] = true
L["is equal to"] = true
L["is not equal to"] = true
L["is evenly divisible by"] = true

L["you"] = true
L["your pet"] = true
L["your target"] = true
L["your focus target"] = true
L["your mouseover target"] = true
L["your pet's target"] = true
L["your target's target"] = true
L["your focus target's target"] = true
L["your mouseover target's target"] = true

L["your"] = true
L["your pet's"] = true
L["your target's"] = true
L["your focus target's"] = true
L["your mouseover target's"] = true
L["your pet's target's"] = true
L["your target's target's"] = true
L["your focus target's target's"] = true
L["your mouseover target's target's"] = true

L["healed"] = true
L["dodged"] = true
L["blocked"] = true
L["hit"] = true
L["critically hit"] = true
L["hit with a crushing blow"] = true
L["hit with a glancing blow"] = true
L["missed"] = true
L["parried"] = true
L["resisted"] = true

L["Center"] = true
L["Top Left"] = true
L["Top Right"] = true
L["Bottom Left"] = true
L["Bottom Right"] = true
L["Top Center"] = true
L["Bottom Center"] = true
L["Left Center"] = true
L["Right Center"] = true

L["Select Icon"] = true
L["Key"] = true
L["Custom Condition"] = true
L["Edit Condition"] = true
L["Description"] = true
L["Validity Function"] = true
L["Evaluation Function"] = true
L["Print Function"] = true
L["Widget Function"] = true
L["Help Function"] = true
L["Post-Registration Function"] = true
L["Pre-Unregistration Function"] = true

L["Warrior"] = true
L["Paladin"] = true
L["Hunter"] = true
L["Rogue"] = true
L["Priest"] = true
L["Death Knight"] = true
L["Shaman"] = true
L["Mage"] = true
L["Warlock"] = true
L["Monk"] = true
L["Druid"] = true
L["Demon Hunter"] = true

L["Beast"] = true
L["Dragonkin"] = true
L["Demon"] = true
L["Elemental"] = true
L["Giant"] = true
L["Undead"] = true
L["Humanoid"] = true
L["Critter"] = true
L["Mechanical"] = true
L["Not specified"] = true
L["Totem"] = true
L["Non-combat Pet"] = true
L["Gas Cloud"] = true

L["World Boss"] = true
L["Rare Elite"] = true
L["Elite"] = true
L["Rare"] = true
L["Normal"] = true
L["Trivial"] = true
L["Minus"] = true

L["Tank"] = true
L["DPS"] = true
L["Healer"] = true
L["Enemy"] = true

L["Magic"] = true
L["Disease"] = true
L["Poison"] = true
L["Curse"] = true
L["Enrage"] = true

L["Arena"] = true
L["Controlled by your faction"] = true
L["Contested"] = true
L["Controlled by opposing faction"] = true
L["Sanctuary (no PVP)"] = true
L["Combat (auto-flagged)"] = true

L["Outside"] = true
L["Battleground"] = true
L["Arena"] = true
L["Dungeon"] = true
L["Raid"] = true

L["Fire"] = true
L["Earth"] = true
L["Water"] = true
L["Air"] = true

L["Minimum"] = true
L["Maximum"] = true
L["Average"] = true

L["no threat risk"] = true
L["higher threat than tank"] = true
L["tanking, at risk"] = true
L["tanking, secure"] = true

-- from utils.lua

L["<value>"] = true
L["<operator>"] = true

-- from Options/general.lua

L["Enable Rotation Master"] = true
L["Polling Interval (seconds)"] = true
L["Idle Re-check Interval (seconds)"] = true
L["Auto-Switch Re-check Interval (seconds)"] = true
L["Ignore Mana"] = true
L["Ignore Range"] = true
L["Skip rotation entries or disable cooldown highlights because you don't have enough to cast them."] = true
L["Effect Options"] = true
L["Magnification"] = true
L["Highlight Color"] = true
L["Position"] = true
L["Specialization Names"] = true
L["Debugging Options"] = true
L["Log Level"] = true
L["Quiet"] = true
L["Debug"] = true
L["Verbose"] = true
L["Detailed Profiling"] = true
L["Disable Auto-Switching"] = true
L["Minimap Icon"] = true
L["Spell History Memory (seconds)"] = true
L["Combat History Memory (seconds)"] = true
L["Damage History Memory (seconds)"] = true
L["Live Status Update Frequency (seconds)"] = true
L["Disable Bar Highlighting"] = true
L["Preview Spells"] = true
L["This is specifically how often the configuration pane will receive updates about live status.  Too frequently could make your configuration pane unusable.  0 = Disabled."] = true
L["Are you sure you wish to delete this rotation?"] = true
L["This item set is in use, are you sure you wish to delete it?"] = true
L["Default effects have changed since the previous release, do you want to reset the effect list?"] = true
L["Import/Export Rotation"] = true
L["Import/Export Item Set"] = true
L["Import/Export Effect"] = true
L["Import/Export Condition"] = true
L["Import/Export Condition Group"] = true
L["Copy and paste this text share your rotation with others, or import someone else's."] = true
L["Copy and paste this text share your effect with others, or import someone else's."] = true
L["Copy and paste this text share your item set with others, or import someone else's."] = true
L["Copy and paste this text share your custom condition with others, or import someone else's."] = true
L["bytes"] = true
L["lines"] = true
L["Parse Error"] = true
L["Copy of %s"] = true
L["Imported on %c"] = true
L["Import/Export"] = true
L["Import"] = true
L["Switch Condition"] = true
L["No other rotations match."] = true
L["Manual switch only."] = true
L["THIS CONDITION DOES NOT VALIDATE"] = true
L["THIS ROTATION WILL NOT BE USED AS IT IS INCOMPLETE"] = true
L["Cooldowns"] = true
L["Rotation"] = true
L["Switch"] = true
L["Condition Options"] = true
L["Rotations"] = true
L["Search"] = true
L["Type"] = true
L["Texture"] = true
L["Effect"] = true
L["Pixel"] = true
L["Auto Cast"] = true
L["Glow"] = true
L["Dazzle"] = true
L["Animate"] = true
L["Pulse"] = true
L["Rotate"] = true
L["Sequence"] = true
L["Event"] = true
L["Effects"] = true
L["Item Sets"] = true
L["Announces"] = true
L["Profiles"] = true
L["About"] = true
L["Lines"] = true
L["Frequency"] = true
L["Steps"] = true
L["Reverse"] = true
L["Angle"] = true
L["Length"] = true
L["Thickness"] = true
L["Particles"] = true
L["Scale"] = true
L["Level"] = true
L["<level>"] = true
L["%s's level"] = true
L["your level"] = true
L["Disabled"] = true
L["Enabled"] = true
L["Invalid"] = true
L["Relative"] = true
L["Help"] = true
L["Time Until Health"] = true
L["Time Until Health Percentage"] = true
L["Runner"] = true
L["%s will run"] = true
L["Resistant"] = true
L["Resistance"] = true
L["Immune"] = true
L["Spell School"] = true
L["Partial"] = true

L["Started"] = true
L["Stopped"] = true
L["Succeeded"] = true
L["Interrupted"] = true
L["Failed"] = true
L["Delayed"] = true
-- from Options/rotations.lua and Options/rotations.lua

L["Arcane"] = true
L["Fire"] = true
L["Frost"] = true
L["Holy"] = true
L["Nature"] = true
L["Shadow"] = true

L["Spells that you wish to conditionally highlight independent of your rotation.  Any or all of these may be highlighted at the same time."] = true
L["Your main spell rotation.  Only one spell will be highlighted at once, which spell being based on the first satisfied condition."] = true
L["Move Up"] = true
L["Move to Top"] = true
L["Move to Bottom"] = true
L["Move Down"] = true
L["Move To"] = true
L["Hidden"] = true
L["Duplicate"] = true
L["Action Type"] = true
L["No Action"] = true
L["Spell"] = true
L["Rank"] = true
L["Pet Spell"] = true
L["Any Spell"] = true
L["Item"] = true
L["Conditions"] = true
L["Currently satisfied"] = true
L["Not currently satisfied"] = true
L["NOTE: Some spells can not be selected (even if auto-completed) due to WoW internals.  It may reequire you to switch specs or summon the requisite pet first before being able to populate this field."] = true
L["%s is now available!"] = true
L["Announce"] = true
L["Audible Announce"] = true
L["None"] = true
L["Raid or Party"] = true
L["Party Only"] = true
L["Raid Warning"] = true
L["Say"] = true
L["Yell"] = true
L["Emote"] = true
L["Local Only"] = true
L["Text"] = true
L["Item Set"] = true
L["%s or %d others"] = true
L["a %s item set item"] = true
L["Click the icon above to bind to your action bar"] = true
L["time until %s is at %s%% health"] = true
L["time until %s is at %s health"] = true
L["time until %s is at %s health defecit"] = true
L["including pets"] = true
L["The %s health defecit of %s members%s within %d yards of %s"] = true
L["The %s health of %s members%s within %d yards of %s"] = true
L["The number %s members%s within %d yards of %s whose"] = true
L["The %s health percentage of %s members%s within %d yards of %s"] = true
L["The number %s members%s within %d yards of %s whose health percentage"] = true
L["The %s mana defecit of %s members%s within %d yards of %s"] = true
L["The %s mana of %s members%s within %d yards of %s"] = true
L["The number %s members%s within %d yards of %s whose"] = true
L["The %s mana percentage of %s members%s within %d yards of %s"] = true
L["The number %s members%s within %d yards of %s whose mana percentage"] = true

-- from Options/conditional.lua

L["AND"] = true
L["OR"] = true
L["NOT"] = true
L["<INVALID CONDITION>"] = true
L["Please Choose ..."] = true
L["Condition Type"] = true
L["Edit Condition #%d"] = true
L["Edit Condition"] = true
L["Up"] = true
L["Down"] = true

-- From the Conditions

L["<unit>"] = true
L["<spell>"] = true
L["<action>"] = true
L["<item>"] = true
L["<role>"] = true
L["<class>"] = true
L["<creature type>"] = true
L["<classification>"] = true
L["<talent>"] = true
L["<talent tree>"] = true
L["<glyph>"] = true
L["<rune type>"] = true
L["<buff>"] = true
L["<debuff>"] = true
L["<element>"] = true
L["<totem>"] = true
L["<threat>"] = true
L["<form>"] = true
L["<zone>"] = true
L["<name>"] = true
L["<distance>"] = true
L["<quantity>"] = true
L["<school>"] = true
L["<operation>"] = true
L["<stat>"] = true

L["Your talent is a %s role"] = true
L["%s is in a %s role"] = true
L["%s is a %s"] = true
L["%s are a %s"] = true
L["%s have %s"] = true
L["%s has %s"] = true
L["%s is %s"] = true
L["%s are %s"] = true
L["%s were %s"] = true
L["%s was %s"] = true
L["%s with %s"] = true
L["%s have %s where %s"] = true
L["%s has %s where %s"] = true
L["you are talented in %s"] = true
L["talent points in %s (%s)"] = true
L["%s's resistance to %s"] = true
L["%s is sometimes immune to %s"] = true
L["%s is immune to %s"] = true
L["you have %s glyph"] = true

L["Unit"] = true
L["Role"] = true
L["Class"] = true
L["Class In Group"] = true
L["Is Same As"] = true
L["Creature Type"] = true
L["Unit Classification"] = true
L["Talent"] = true
L["Glyph"] = true
L["Talent Tree"] = true
L["Operator"] = true
L["Operation"] = true
L["Count"] = true
L["Quantity"] = true
L["Distance"] = true
L["Distance Count"] = true
L["yards"] = true
L["Same Group"] = true
L["Include Pets"] = true

L["Health"] = true
L["%s health"] = true
L["%s health defecit"] = true
L["Health Percentage"] = true

L["Mana"] = true
L["%s mana"] = true
L["%s mana defecit"] = true
L["Mana Percentage"] = true

L["Power"] = true
L["%s power"] = true
L["%s power defecit"] = true
L["Power Percentage"] = true

L["Points"] = true
L["%s points"] = true
L["%s point defecit"] = true

L["Rune Type"] = true
L["Runes"] = true
L["Rune Cooldown"] = true
L["%s runes available"] = true
L["cooldown on %s rune"] = true

L["Blood"] = true
L["Frost"] = true
L["Unholy"] = true
L["Death"] = true

L["Character Stat"] = true
L["Extended Character Stat"] = true
L["Extended Character Stat Percentage"] = true

L["Spell Available"] = true
L["Pet Spell Available"] = true
L["%s is available"] = true
L["Spell In Range"] = true
L["Pet Spell In Range"] = true
L["%s is in range"] = true
L["Spell Cooldown"] = true
L["Pet Spell Cooldown"] = true
-- This is used for things like "the cooldown on <spell> is less than 5 seconds"
L["the %s"] = true
L["cooldown on %s"] = true
L["%s seconds"] = true
L["Seconds"] = true
L["Boss Mod Encounter"] = true
L["Boss Mod Encounter Stage"] = true
L["Boss Mod Timer"] = true
L["Stage"] = true
L["none"] = true
L["Encounter ID (blank for any)"] = true
L["Boss ability spell ID"] = true
L["Running timers:"] = true
L["No boss-mod timers are running."] = true
L["No boss-mod encounter is in progress."] = true
L["Boss mod data unavailable: %s"] = true
L["Current encounter: %s (ID %s), stage %s"] = true
L["your boss mod reports encounter %s {{!is|is not}} in progress"] = true
L["your boss mod {{!reports|does not report}} an encounter in progress"] = true
L["the boss-mod encounter stage"] = true
L["the boss-mod timer for %s"] = true
L["Seconds until the boss mod expects the ability. A paused timer keeps its remaining time."] = true
L["Help.Conditions.BOSSMOD_ENCOUNTER"] = "True while your enabled boss mod (DBM or BigWigs, chosen on the Integrations page) reports a boss encounter in progress. Leave Encounter ID blank for any encounter, or enter the game's encounter ID, which DBM and BigWigs share, to match one boss; while an encounter is active the editor shows its name and ID. This is the boss mod's report, not game state: it starts when the boss mod engages and ends when it records a win, wipe or reset. Use it as a switch condition for encounter-specific rotations; automatic switching picks it up on its normal re-check interval. Unavailable, never simply false, when no boss mod is enabled or loaded."
L["Help.Conditions.BOSSMOD_STAGE"] = "The stage (phase) your boss mod reports for the current encounter. An encounter whose boss mod has not reported a stage counts as stage 1, and some intermissions are reported as half stages such as 1.5. False when no encounter is in progress; unavailable when no boss mod is enabled or loaded."
L["Help.Conditions.BOSSMOD_TIMER"] = "Compares the time left on your boss mod's timer for one boss ability, identified by the ability's spell ID; while timers run, the editor lists them with their IDs. Timers are the boss mod's predictions and can shift, pause or be cancelled. When no timer for that ability is running the condition is false, so 'is less than 5 seconds' is only true while a timer is actually counting down. Bars without a spell ID, such as pull or respawn timers, are not tracked. Unavailable when no boss mod is enabled or loaded."
L["Spell Active or Pending"] = true
L["Pet Spell Active or Pending"] = true
L["%s is active or pending"] = true

L["Spell Time Remaining"] = true
L["Pet Spell Time Remaining"] = true
L["remaining time on %s"] = true
L["Spell Charges"] = true
L["Pet Spell Charges"] = true
L["number of charges on %s"] = true
L["Charges"] = true

L["Spell Cast History Time"] = true
L["Spell Cast History"] = true
L["Pet Spell Cast History Time"] = true
L["Pet Spell Cast History"] = true
L["%s was cast"] = true
L["%s casts ago"] = true
L["%s seconds ago"] = true
L["Combat Action History Time"] = true
L["Combat Action History"] = true
L["%s actions ago"] = true

L["Any Spell Available"] = true
L["Any Spell In Range"] = true
L["Any Spell Cooldown"] = true
L["Any Spell Time Remaining"] = true
L["Any Spell Charges"] = true

L["Buff Present"] = true
L["Buff Time Remaining"] = true
L["the remaining time"] = true
L["Buff Stacks"] = true
L["stacks of %s"] = true
L["Stacks"] = true
L["stacks"] = true
L["Has Stealable Buff"] = true
L["%s has a stealable buff"] = true

L["Debuff Present"] = true
L["Debuff Time Remaining"] = true
L["Debuff Stacks"] = true
L["Debuff Type Present"] = true
L["%s have a %s debuff"] = true
L["%s has a %s debuff"] = true
L["<debuff type>"] = true
L["Debuff Type"] = true

L["Totem Present"] = true
L["%s totem is active"] = true
L["%s is active"] = true
L["Totem"] = true
L["Specific Totem Present"] = true
L["Totem Time Remaining"] = true
L["Specific Totem Time Remaining"] = true
L["you have a %s totem active with %s"] = true
L["%s is active with %s"] = true

L["Have Item Equipped"] = true
L["you have %s equipped"] = true
L["Have Item In Bags"] = true
L["the number of %s you are carrying"] = true
L["Item Available"] = true
L["Item In Range"] = true
L["Item Cooldown"] = true
L["Check If Not Carrying"] = true
L[", even if you do not currently have one"] = true

L["In Combat"] = true
L["%s are in combat"] = true
L["%s is in combat"] = true
L["Have Pet"] = true
L["you have a pet"] = true
L["Have Named Pet"] = true
L["you have a pet named %s"] = true
L["Stealth"] = true
L["you are stealthed"] = true
L["In Control"] = true
L["you are in control of your character"] = true
L["Loss Of Control Type"] = true
L["Control Type"] = true
L["Loss Of Control Type"] = true
L["time remaining on %s"] = true
L["School Blocked"] = true
L["time remaining on block of your %s abilities"] = true
L["Loss Of Control Blocked"] = true
L["Moving"] = true
L["you are moving"] = true
L["Threat"] = true
L["Threat Count"] = true
L["you are at least %s on %s"] = true
L["Shapeshift Form"] = true
L["humanoid"] = true
L["Form"] = true
L["Attackable"] = true
L["Hostile"] = true
L["Allies Within Range"] = true
L["Health Within Range"] = true
L["Health Count Within Range"] = true
L["Health Percentage Within Range"] = true
L["Health Percentage Count Within Range"] = true
L["Mana Within Range"] = true
L["Mana Count Within Range"] = true
L["Mana Percentage Within Range"] = true
L["Mana Percentage Count Within Range"] = true
L["%s is an enemy"] = true
L["%s is attackable"] = true
L["number of %s members%s within %d yards"] = true
L["number of %s members%s within %s yards"] = true
L["number of enemies you are at least %s"] = true
L["closer than %s yards"] = true
L["allies"] = true
L["enemies"] = true
L["Number of %s within %s yards"] = true
L["Number of %ss in the %s"] = true
L["you are in %s form"] = true

L["Channeling"] = true
L["Specific Spell Channeling"] = true
L["%s are currently channeling"] = true
L["%s is currently channeling"] = true
L["%s are currently channeling %s"] = true
L["%s is currently channeling %s"] = true
L["Channel Time Remaining"] = true
L["time remaining on spell channel"] = true
L["Channel Interruptable"] = true
L["%s's channeled spell is interruptable"] = true

L["Casting"] = true
L["Specific Spell Casting"] = true
L["%s are currently casting"] = true
L["%s is currently casting"] = true
L["%s are currently casting %s"] = true
L["%s is currently casting %s"] = true
L["Cast Time Remaining"] = true
L["time remaining on spell cast"] = true
L["Cast Interruptable"] = true
L["%s's spell is interruptable"] = true

L["PVP Flagged"] = true
L["%s are PVP flagged"] = true
L["%s is PVP flagged"] = true
L["Zone PVP"] = true
L["zone is a %s zone"] = true
L["no PVP"] = true
L["Mode"] = true
L["Instance"] = true
L["you are in a %s instance"] = true
L["Other (scenario)"] = true
L["in %s"] = true
L["Zone"] = true
L["SubZone"] = true
L["In Group"] = true
L["you are in a group"] = true
L["In Raid"] = true
L["you are in a raid"] = true
L["Outdoors"] = true
L["Scenario"] = true
L["you are in a outdoors"] = true

L["Weapon Enchant Present"] = true
L["Different season or game rules"] = true
-- Action and build contexts
L["%s (set %d)"] = true
L["%s, %d equipped"] = true
L["<action bar>"] = true
L["<enchant>"] = true
L["<item set>"] = true
L["A rotation of your own is used only on your own bar unless its switch condition requires another action context with this condition; it is then used, and its buttons found, while that bar is up."] = true
L["Action Context"] = true
L["Advice is suspended: no rotation applies while you are using another action bar."] = true
L["Currently: no temporary enchant"] = true
L["Currently: temporary enchant %d"] = true
L["Enchant ID"] = true
L["Equipped Sets"] = true
L["Item Set ID"] = true
L["Item Set Pieces Equipped"] = true
L["Matches the bar you are acting through: your own, a vehicle, a possessed (mind controlled) unit, an override bar, or a pet battle. Vehicles and override bars exist from Wrath, pet battles only on Retail."] = true
L["Pieces"] = true
L["The game's item set (for example a tier set). Sets you are wearing are offered in the list; the count is taken from your equipped items' metadata and stays unavailable while any of it is still loading."] = true
L["The number of pieces of that set you have equipped."] = true
L["The temporary enchant on the weapon: a poison, oil, sharpening stone or weapon imbue. The current enchant ID of the selected hand is shown below the field."] = true
L["Weapon Enchant Type"] = true
L["a pet battle"] = true
L["a possessed unit"] = true
L["a vehicle"] = true
L["an override action bar"] = true
L["item set %d"] = true
L["the number of {set} pieces you have equipped {comparison} {quantity}"] = true
L["you {{!are|are not}} acting through %s"] = true
L["your %s weapon {{!has|does not have}} temporary enchant %s"] = true
L["your own action bar"] = true
L["Weapon Enchant Time Remaining"] = true
L["Weapon Enchant Stacks"] = true
L["Your %s weapon buff has %s"] = true
L["Your %s weapon is enchanted"] = true
L["Your %s weapon %s"] = true
L["off hand"] = true
L["main hand"] = true
L["Off Hand"] = true
L["attack speed"] = true
L["Attack Speed"] = true
L["Weapon Swing Time"] = true
L["Weapon Swing Time Remaining"] = true
L["swing time remaining"] = true
L["Swing Time Remaining"] = true

L["Global"] = true

L["Damage and Heals"] = true
L["Damage Only"] = true
L["Heals Only"] = true

-- Condition help and elapsed-combat summaries.
L["Action"] = true
L["Pet Spell History Memory (seconds)"] = true
L["Sound Alert"] = true
L["Matches while your character is moving, based on current movement speed. It does not test the movement of your target."] = true
L["Matches when your pet unit exists. This does not check whether the pet is alive, in range or able to use an ability."] = true
L["Matches when the game reports that you are outdoors. Being outdoors is different from being outside an instance."] = true
L["Matches when the game reports that you have full control of your character. This does not guarantee that a particular spell is usable."] = true
L["Matches while the game reports your character as stealthed. It does not test whether an enemy can detect you."] = true
L["Time Since Combat Start"] = true
L["Time in combat is %s %s seconds"] = true
L["This condition matches if any sub-condition matches. With no sub-conditions, it does not match."] = "Any (OR) checks children in order and stops at the first match. An empty group does not match. Encountered unavailable data remains unavailable; later children are skipped."

-- Native diagnostic report access.
L["Rotation Master errors"] = true
L["Review the report, then select Copy and press Ctrl+C. Reload after fixing a paused callback."] = true
L["Previous error"] = true
L["Next error"] = true
L["Copy report"] = true
L["Clear RM errors"] = true
L["Close"] = true
L["Resize"] = true
L["No Rotation Master errors have been captured this session."] = true
L["/rm errors              - View and copy Rotation Master errors."] = true
L["Use redacted error text"] = true
L["Include original text (may contain names or code)"] = true
L["Spell Known"] = true
L["You know %s"] = true
L["Your pet knows %s"] = true
L["%s (spell ID %s)"] = true
L["Spell ID"] = true
L["Pet spell"] = true
L["Check whether you or your pet know this exact spell ID. An unlearned spell is a valid condition that returns false, so the same rotation can adapt as you learn abilities. This does not check cooldown, resources, range, or whether the spell can currently be cast. Missing or restricted learned-state data stays unavailable under NOT."] = true
L["Only consider auras that you applied yourself."] = true
L["Remaining aura time is measured in seconds. Permanent auras have no expiration and do not satisfy a finite refresh threshold. An absent aura does not satisfy this condition. Restricted or unknown timing is unavailable, including under NOT."] = true
L["Compare the application count of a matching aura, including charges such as Earth Shield. An absent aura does not satisfy this condition; an unreadable count is unavailable."] = true
L["Only consider debuffs returned by the game's dispellable aura filter. This does not guarantee your dispel is ready or in range."] = true

-- Packaged rotation browser
L["Unavailable conditions or unsupported data"] = true
L["%s is not available on this client (%s)."] = true
L["the combat log is not available to addons on this client"] = true
L["health is secret on this client"] = true
L["this power is secret on this client"] = true
-- Rotation eligibility: why a rotation cannot be selected (/rm why, editor, roster)
L["Active rotation: %s"] = true
L["a fallback saved for this character takes precedence"] = true
L["automatic"] = true
L["Cooldown %d"] = true
L["%d Built In rotations are disabled."] = true
L["%d other Built In rotations are disabled (for another specialization, level or edition)."] = true
L["%s: disabled by you (turn it back on in Rotations, in its Built In view)."] = true
L["%s: ships disabled, an alternative to the recommended one (turn it on in Rotations, in its Built In view)."] = true
L["then the fallback (%s)"] = true
L["Automatic switching tries: %s. Higher numbers are tried first; equal priorities go by name."] = true
L["Automatic switching would choose: %s"] = true
L["%d Built In disabled: %s"] = true
L["Disabled by you"] = true
L["level %d+"] = true
L["Season of Mastery"] = true
L["Season of Discovery"] = true
L["Hardcore"] = true
L["Anniversary"] = true
L["Anniversary Hardcore"] = true
L["Self-Found"] = true
L["Standard realms"] = true
L["Season %s"] = true
L["Game mode %s"] = true
L["%s: ready, manual only: no switch condition (choose it with /rm set or the minimap menu)."] = true
L["Automatic switching tries nothing else, then the fallback (%s): no enabled rotation here has a switch condition it can use."] = true
L["manual only (no switch condition)"] = true
L["Revision %s"] = true
L["Every rotation has a handle, shown beside its priority: type /rm set <handle> to choose it (any case), /rm set auto to go back to automatic switching, and /rm list to see every handle. A Built In's handle is fixed; yours is made from its name until you change it."] = true
L["you switched it off (turn it back on in Rotations)"] = true
L["it ships disabled, an alternative to the recommended one (turn it on in Rotations)"] = true
L["Handle: %s (/rm set %s)"] = true
L["The fallback is always /rm set default."] = true
L["A Built In handle is fixed. Use it with /rm set."] = true
L["Use it with /rm set. Letters, digits, _ or -, starting with a letter; not case sensitive."] = true
L["Made from the name until you change it. Use it with /rm set."] = true
L["has an invalid handle"] = true
L["%s is reserved for /rm set."] = true
L["A handle starts with a letter, then letters, digits, _ or -, up to 32 characters."] = true
L["%s already uses the handle %s."] = true
L["Rotations for %s (use /rm set <handle>):"] = true
L["disabled by you"] = true
L["ships disabled"] = true
L["not for this character now"] = true
L["cannot be selected: %s"] = true
L["active"] = true
L["ready"] = true
L["fallback"] = true
L["yours"] = true
L["The rotation list opened in a window you can copy from."] = true
L["Rotations and their handles"] = true
L["More than one rotation uses the handle %s. Give one of them another handle in Rotations."] = true
L["Handles you can use now: %s (or auto). /rm list shows every rotation."] = true
L["Handle"] = true
L["Choosing a rotation"] = true
L["Automatic switching tries the enabled rotations in priority order, yours and Built Ins alike: higher numbers are tried first, equal priorities by name. It picks the first whose switch condition matches. The fallback (Default) is used only when none matches. The rotation list is sorted in this same order and shows each priority."] = true
L["Priority sits beside Enabled at the top of the editor. A Built In cannot be edited, but its Enabled setting and priority are yours to change for this profile: they are saved at once, shown in amber when they differ from how it ships, and Reset to default puts it back. Copy a Built In to your rotations to edit anything else."] = true
L["A Built In loads only for the edition and class it was written for (shown under the switch). Its specialization and level are part of its switch condition, so the switch decides the rest."] = true
L["In the list, a red border means the rotation cannot be selected (the tooltip names why), grey means it is switched off, and an amber bar means its switch condition can match at the same time as another rotation (yours or Built In), so only priority decides between them; a wider bar means they also have the same priority and the name decides. /rm why lists the order and what automatic switching would choose now."] = true
L["You are playing %s; this rotation is saved for %s, so it is not selectable now."] = true
L["Priority"] = true
L["Reset to default"] = true
L["Use the Built In as it ships: its own Enabled setting and priority."] = true
L["Built In: read-only. Click to copy it to your rotations and edit the copy. Enabled and Priority are your own settings for this profile."] = true
L["Your setting for this profile. The Built In ships %s."] = true
L["As the Built In ships. Click to change it for this profile."] = true
L["Your priority for this profile; the Built In ships with %d."] = true
L["Turn on"] = true
L["Turn this Built In back on for this profile."] = true
L["Disabled by you: automatic switching skips it. Select it and click Disabled to turn it back on."] = true
L["Ships disabled (an alternative to the recommended Built In): automatic switching skips it until you turn it on."] = true
L["Disabled: automatic switching skips it."] = true
L["Higher numbers are tried first; equal priorities go by name. Your rotations and Built Ins compete on priority alone."] = true
L["Same priority as %s: their switch conditions can match together, and the tie is decided by name."] = true
L["Can match together with %s: only priority decides which is chosen."] = true
L["expansions %s–%s"] = true
L["Loads only for: %s. The switch condition decides the rest."] = true
L["Ships disabled"] = true
L["Built In rotations turned back on (they had been switched off without your choice): %s"] = true
L["Disabled Built In rotations"] = true
L["Open Rotations, select the Built In and turn it back on to make it selectable."] = true
L["Fallback (%s)"] = true
L["has an action type this version does not understand (%s)"] = true
L["has an invalid setting (%s)"] = true
L["has an invalid switch priority"] = true
L["has a problem (%s)"] = true
L["has a setting this version does not understand (%s)"] = true
L["has no items"] = true
L["is missing a required setting (%s)"] = true
L["it has incomplete or unsupported data"] = true
L["It has incomplete or unsupported data"] = true
L["it is disabled"] = true
L["it is for another class"] = true
L["it is for another expansion"] = true
L["it is for another game build"] = true
L["it is for another season or game rules"] = true
L["it is for another specialization"] = true
L["it is for another WoW edition"] = true
L["it is unavailable (%s)"] = true
L["it needs context Rotation Master cannot read yet"] = true
L["it uses a condition, item set or function that is disabled"] = true
L["manual"] = true
L["No %d"] = true
L["no fallback rotation is saved for %s"] = true
L["No rotation can run until your specialization is available."] = true
L["Reason: %s. Type /rm why to check every rotation."] = true
L["/rm why                 - Explain why each rotation can or cannot be selected."] = true
L["Rotation eligibility opened in a window you can copy from."] = true
-- Glow diagnostic (/rm debug glow, Diagnostics/glow.lua)
L["/rm debug glow [seconds] - Explain why a recommendation does or does not light a button."] = true
L['/rm debug editor        - Copy native Lua input diagnostics.'] = true
L['Glow diagnostic'] = true
L['Glow diagnostic saved.'] = true
L['Glow diagnostic saved. Watching for %d seconds.'] = true
L['Glow watch finished. Run /rm debug glow show to view it.'] = true
L['Glow stops at: %s'] = true
L['No glow diagnostic is saved yet. Run /rm debug glow.'] = true
L['Usage: /rm debug glow [seconds|show] or /rm debug editor'] = 'Usage: /rm debug glow [seconds||show] or /rm debug editor'
L["rotations cannot be read (%s)"] = true
L["Rotation %s cannot be selected."] = true
L["Rotation settings"] = true
L["Rotation step %d"] = true
L["%s (Built In)"] = true
L["%s: cannot be selected, %s."] = true
L["Specialization: %s (%s), level %s"] = true
L["Spell %d"] = true
L["%s: ready"] = true
L["the game build is unavailable"] = true
L["(there is one for %s)"] = true
L["This rotation cannot be selected. %s."] = true
L["uses a condition that is disabled in Settings (%s)"] = true
L["uses a condition this client does not have (%s)"] = true
L["uses a custom condition whose function is unavailable (%s)"] = true
L["uses a highlight effect that no longer exists"] = true
L["uses an item set that no longer exists"] = true
L["uses Blizzard's suggestion, which only works in the rotation list"] = true
L["Why rotations are or are not selected"] = true
L["Yes %d"] = true
L["you are using another action bar"] = true
L["your level is outside its level range"] = true
L["your level is unavailable"] = true
L["your specialization is not available yet"] = true
L["No specialization (levels 1-9)"] = true
L["you have not chosen a specialization yet, so Rotation Master uses %s, which the Rotations editor does not offer"] = true
L["You have not chosen a specialization yet (Retail characters below level 10 have none), so Rotation Master uses %s (%s). The Rotations editor only offers %s, so rotations saved there cannot run until you choose a specialization."] = true
L["this client has no ranged slot"] = true
L["this client has no specializations for your class"] = true
L["With no off-hand weapon equipped, an off-hand check is false (and true under NOT)."] = true
L["combat data is restricted on this client"] = true
L["the game API it needs is missing"] = true
L["this client is not supported"] = true
L["this client uses a different talent system"] = true
L["glyphs are not supported on this client build"] = true
L["this edition has no point resource"] = true
L["Different WoW edition"] = true
L["Different class"] = true
L["Different specialization"] = true
L["Different action context"] = true
L["Character level is unavailable"] = true
L["Outside its level range"] = true
L["Game build is unavailable"] = true
L["Different game build"] = true
L["Required context is not supported yet"] = true
L["Reference only on this client"] = true
L["The Built In rotation is unavailable."] = true
L["Built In · read-only"] = true
L["Level range: %s–%s; revision %s"] = true
L["Available for this character"] = true
L["Not available for this character: %s"] = true
L["Enable Built In"] = true
L["Could not update this Built In rotation: %s"] = true
L["Clone to edit"] = true
L["Could not duplicate this Built In rotation: %s"] = true
L["%d. %s"] = true
L["Condition preview unavailable"] = true
L["Sources"] = true
L["Unavailable"] = true

L["Default.TBC.Shaman.Enhancement.IcyVeins.Name"] = "Shaman: Enhancement (Icy Veins)"
L["Default.TBC.Shaman.Enhancement.IcyVeins.Description"] = "Melee Enhancement from level 1 to 70, and the default for any Shaman no other premade fits. Pulls with Lightning Bolt from range, interrupts with Earth Shock, drops Fire Nova and Magma Totems on three or more nearby enemies, then Stormstrike, Earth Shock while Stormstrike's debuff is up, Flame Shock on a target that will live, Earth Shock on cooldown, and Lightning Bolt while the target is out of reach. Separate reminders: weapon imbues, Water or Lightning Shield, Strength of Earth, Windfury (group) or Grace of Air (solo), Searing on long fights, water totems, Shamanistic Rage, Bloodlust/Heroism on bosses, Stoneclaw and Earth Elemental when solo. Fire Elemental is an optional step that starts off. Totem placement, Ghost Wolf and healing stay with you."
L["Default.TBC.Shaman.Enhancement.Wowsims.Name"] = "Shaman: Enhancement (Wowhead & wowsims)"
L["Default.TBC.Shaman.Enhancement.Wowsims.Description"] = "The level-70 raid model for totem twisting, an alternative to the recommended Icy Veins Enhancement premade, off by default: enable it and disable that one, or raise its priority. Stormstrike, a Fire Nova Totem weave, Flame Shock whenever it has fallen off, and Earth Shock as the main shock, with Lightning Bolt only out of reach. Reminders twist Windfury and Grace of Air Totems, keep Searing down, use Shamanistic Rage when mana runs low, and share the Icy Veins variant's imbue, shield and totem upkeep."
L["Default.TBC.Shaman.Elemental.IcyVeins.Name"] = "Shaman: Elemental (Icy Veins & wowsims)"
L["Default.TBC.Shaman.Elemental.IcyVeins.Description"] = "Caster Elemental for the Elemental talent tree. Lightning Bolt is the filler; Chain Lightning goes out with Elemental Mastery, on Clearcasting while you have 40% mana, or freely above 80%; Flame Shock only while moving; Earth Shock interrupts; Fire Nova, Chain Lightning and Magma for packs. Before Chain Lightning a target in melee is left to auto-attack to save mana. Reminders: Water or Lightning Shield, a weapon imbue, Totem of Wrath (or Searing on long fights), Wrath of Air, Mana Spring, Totemic Call after the fight, Elemental Mastery and Bloodlust/Heroism."
L["Default.TBC.Shaman.Elemental.Wowhead.Name"] = "Shaman: Elemental (Wowhead)"
L["Default.TBC.Shaman.Elemental.Wowhead.Description"] = "Wowhead's Elemental, an alternative to the recommended Icy Veins Elemental premade, off by default: enable it and disable that one, or raise its priority. At 70 Chain Lightning on cooldown with Lightning Bolts in between (while leveling only with Elemental Mastery or Clearcasting), Flame Shock only while moving, Earth Shock to finish a target that would die before a cast lands. Same totem, shield and cooldown reminders as the Icy Veins variant."
L["Default.TBC.Shaman.Elemental.NextAction.Name"] = "Shaman: Elemental (NextActionTBC)"
L["Default.TBC.Shaman.Elemental.NextAction.Description"] = "NextActionTBC's Elemental, an alternative to the recommended Icy Veins Elemental premade, off by default: enable it and disable that one, or raise its priority. Keeps Flame Shock on the target, Chain Lightning only against two or more enemies while above 30% mana, Lightning Bolt otherwise. Reminds you of Lightning Shield, a weapon imbue, Elemental Mastery and Bloodlust/Heroism; totems stay manual."
L["Default.TBC.Shaman.Restoration.Name"] = "Shaman: Restoration"
L["Default.TBC.Shaman.Restoration.Description"] = "Healing for the Restoration talent tree, on your friendly target (or yourself with no target): Nature's Swiftness and Healing Wave or Lesser Healing Wave in emergencies, Cure Poison and Cure Disease, Earth Shield on your focus, Chain Heal when three nearby allies are hurt, Healing Wave otherwise. With a hostile target it switches to Flame Shock and Lightning Bolt for soloing. Reminders: Water Shield, Earth Shield on your focus (set the tank as focus), Mana Tide, Mana Spring and Strength of Earth in a group, Bloodlust/Heroism. Choosing whom to heal and which rank stays with you."

L["Could not duplicate this rotation: %s"] = true
L["Could not duplicate this step: %s"] = true

-- Rotation comparisons
L["absent"] = true
L["This comparison could not be completed."] = true
L["This comparison is incomplete; some changes are omitted."] = true
L["No differences."] = true
L["Added %s: %s"] = true
L["Removed %s: %s"] = true
L["Moved %s: priority %s → %s"] = true
L["Changed %s: %s → %s"] = true
L["Read-only comparison. Priority moves are listed; rotations are not merged."] = true
L["Changes in the Built In rotation since cloning"] = true
L["Your changes since cloning"] = true
L["Differences from the current Built In rotation"] = true
L["Overlapping field edits"] = true
L["No overlapping field edits detected. Priority order still needs review."] = true
L["Selected rotation → your rotation"] = true
L["Some display text was truncated. Rotation data has not been changed."] = true
L["Compare rotations"] = true
L["Your rotation: %s"] = true
L["Compare against"] = true
L["Copy comparison"] = true
L["Review the differences, then select Copy and press Ctrl+C."] = true
L["Comparison unavailable: %s"] = true

L["Unknown spell (%s)"] = true

L["Beyond Melee Range"] = true
L["%s is beyond melee range"] = true
L["Uses the native Attack range check when available. Otherwise it uses LibRangeCheck's public interval to distinguish close range from beyond five yards; that estimate does not prove exact melee geometry for every target. An interval spanning the boundary, missing data or restricted data stays unavailable, including under NOT."] = true

L["Switch conditions"] = true
L["Optional highlight"] = true
L["Priority %s"] = true
L["Stop the sequence here"] = true
L["Item or item set: %s"] = true
L["Use this exact spell rank"] = true
L["No steps in this section."] = true
L["Optional highlights"] = true
L["These reminders highlight independently whenever their conditions are met."] = true
L["Sequential priority"] = true
L["The first eligible step is recommended. Later steps provide alternatives."] = true
L["View full rotation"] = true
L["Built In rotation reference"] = true

L["Read-only comparison. Rotations are not merged."] = true
L["Additional settings changed. Copy diagnostic details to inspect all fields."] = true
L["At cloning"] = true
L["Selected rotation"] = true
L["Your rotation"] = true
L["No corresponding step"] = true
L["Added"] = true
L["Removed"] = true
L["Changed"] = true
L["Moved"] = true
L["Unchanged"] = true
L["Comparison diagnostic details"] = true
L["Press Ctrl+C to copy the selected diagnostic details."] = true
L["Comparison view"] = true
L["Copy diagnostic details"] = true
L["Built In updates since cloning"] = true
L["Your edits since cloning"] = true
L["Current Built In rotation"] = true

L["Unknown item"] = true
L["Item %s"] = true
L["Item set: %s"] = true
L["Unknown action type"] = true

L["Player spell"] = true
L["Player or pet spell"] = true
L["General"] = true

L["Copy this export, or paste a rotation and preview it. Import creates a new editable copy."] = true
L["Rotation text"] = true
L["Name for imported copy"] = true
L["Imported rotation"] = true
L["Copy export"] = true
L["Preview import"] = true
L["Import as new rotation"] = true
L["Export unavailable: %s"] = true
L["Preview a pasted rotation before importing it."] = true
L["Text changed. Preview again before importing."] = true
L["Import preview unavailable: %s"] = true
L["Ready to import as a new copy."] = true
L["This import cannot be applied: %s"] = true
L["Legacy export: WoW edition and class scope were not supplied."] = true
L["Could not import this rotation: %s"] = true
L["Incoming rotation"] = true

L["Always"] = true
L["Condition reference (code is not run)."] = true
L["Inspect import"] = true

L["Export Built In"] = true

L["Comparison"] = true

-- Compact condition editor
L["A condition could not be validated. Use /rm errors for details."] = true
L["A custom validator changed the condition while checking it. Fix the validator before applying."] = true
L["AND requires every child; OR requires any child; NOT reverses its child. Unavailable data remains unavailable."] = "AND stops at the first non-match; OR stops at the first match. NOT reverses a known result. Encountered unavailable data remains unavailable. Skipped children are not evaluated."
L["Add condition"] = true
L["All (AND)"] = true
L["Any (OR)"] = true
L["Apply"] = true
L["Apply or cancel the open condition before editing another."] = true
L["Cancel"] = true
L["Changes not applied."] = true
L["Choose a condition"] = true
L["Complete the selected condition's fields before applying."] = true
L["Disable condition"] = true
L["Enable condition"] = true
L["Find condition type"] = true
L["Group with %s"] = true
L["Invalid disabled flag"] = true
L["Not (NOT)"] = true
L["Only the first 200 conditions are shown. Other conditions are preserved."] = true
L["Remove condition"] = true
L["Select a child on the left to edit its fields. Use Add condition to extend this group."] = true
L["Some condition fields have invalid values. Check them before applying."] = true
L["That change could not be applied. Check the selected condition."] = true
L["The condition editor could not display these fields. Use /rm errors for details."] = true
L["This condition changed in another editor. Cancel and reopen it before applying."] = true
L["This condition has no adjacent sibling in that direction."] = true
L["This draft contains conditions or fields that this version cannot apply."] = true
L["This draft refers to missing data. Resolve those references before applying."] = true
L["Ungroup"] = true
L["Ungroup requires a group with at most one child."] = true
L["Unknown condition: %s"] = true
L["Always (no condition)"] = true
L["An empty AND group always matches. Add a condition to restrict it."] = true
L["An empty OR group never matches. Add a condition that can match."] = true
L["An empty condition always matches. Choose a type to restrict it."] = true
L["The original rotation or step was removed or replaced. Cancel this draft and reopen the current one."] = true

L["Show unchanged steps"] = true
L["%s unchanged steps hidden."] = true
L["No other rotations to compare."] = true

L["Spell Recharge Time"] = true
L["Pet Spell Recharge Time"] = true
L["Any Spell Recharge Time"] = true
L["recharge time on %s"] = true
L["Seconds until the next spell charge. Full charges and inactive recharge timers report zero. Missing, restricted, or non-charge spell data stays unavailable."] = true

L["Rotation names"] = true
L["Custom step name"] = true
L["Automatic step name"] = true

L["Spell search data is unavailable."] = true
L["No matching spells."] = true
L["More matches available. Keep typing to narrow the search."] = true
L["Spells from this spellbook. Click a result or press Enter."] = true
L["Known and referenced spells. Enter a spell ID or link to find another spell."] = true

-- Native rotation roster
L["Search rotations"] = true
L["All"] = true
L["Built In"] = true
L["No rotations match this search."] = true
L["New rotation"] = true
L["Fallback rotation"] = true
L["Custom rotation"] = true
L["Not available"] = true
L["%d of %d rotations"] = true

-- Totem observation semantics
L["The elemental slot to check: Fire, Earth, Water or Air. Empty, zero-duration and expired totems do not match."] = true
L["The active totem to check. Unranked checks match its localized name across ranks. Exact-rank checks require the native spell ID; name-only observations are unavailable."] = true
L["Compare the active totem's remaining seconds with this amount. An absent or expired totem does not match; unavailable observations stay unavailable."] = true

L["Stop"] = true
L["Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions."] = true
L["Stop ends lower priority actions. Implicit Attack remains eligible unless you suppress it. An unavailable Stop condition also suppresses Attack. Optional reminders remain independent."] = true
L["When no priority action is ready, Attack is the implicit final fallback for a living hostile target in melee combat, if autoattack is inactive. It uses the normal rotation highlight and never presses a button."] = true
L["Implicit final fallback"] = true

L["This reference belongs to another talent layout. Selecting a talent explicitly replaces it; viewing does not convert it."] = true
L["Historical talent slot %s (unavailable)"] = true
L["This client uses a different talent system. This reference is preserved but cannot be evaluated."] = true
L["Classic conditions compare points spent in a tree talent. Mists selections use six tiers with three choices. Historical references from another talent system remain unavailable and are never automatically converted."] = true

L["Also suppress implicit Attack"] = true
L["Implicit Attack is suppressed by this Stop."] = true
L["Implicit Attack may still be recommended after this Stop."] = true

-- Native condition cards
L["Group name"] = true
L["All categories"] = true
L["Choose or search condition type"] = true
L["Incomplete: %s is required"] = true
L["Invalid or unsupported condition fields"] = true
L["%d conditions"] = true
L["Expand to edit fields"] = true
L["Negate each"] = true

L["All (AND) requires every child to match. An empty group always matches. Unavailable data remains unavailable."] = "All (AND) checks children in order and stops at the first non-match. An empty group matches. Encountered unavailable data remains unavailable; later children are skipped."
L["Select cards with Ctrl-click or Shift-click. Group with All or Any, negate each, move or drag, and remove. Undo and Redo affect only the draft until Apply. Groups can be named and collapsed."] = true

L["Version: %s  ·  Author: %s"] = true
L["Configure rotations, conditions and highlights in the Rotation Master window."] = true
L["Open Options"] = true
L["Unknown"] = true

L["Scale: %d%%"] = true
L["Right-click the title bar to close."] = true
L["Choose a tab to configure Rotation Master. Rotations contains the library and editors. Changes in the condition editor remain a draft until Apply; Cancel abandons them."] = true
L["Drag the title bar to move this window; right-click it to close. Resize from the lower-right corner and adjust Scale in the footer."] = true

L["Click to add group name"] = true
L["Negate condition"] = true
L["Enable or disable condition"] = true
L["Switch All / Any"] = true
L["Off"] = true
L["On"] = true

L["Negated"] = true
L["New condition"] = true
L["New All group"] = true
L["New Any group"] = true
L["Drag into the tree to insert"] = true
L["Collapse all"] = true
L["Expand all"] = true
L["Group as All"] = true
L["Group as Any"] = true
L["Move %d conditions"] = true
L["Insert condition"] = true
L["Duplicate condition"] = true
L["Copy"] = true
L["Any"] = true
L["Resolve the wrapper's name or unsupported fields before removing its negation."] = true
L["Not evaluated: an enclosing group is disabled"] = true
L["%d selected"] = true

L["Conditional branch"] = true
L["Evaluate condition"] = true
L["Always true"] = true
L["Always false"] = true
L["Unknown branch mode"] = true
L["True"] = true
L["False"] = true
L["Rotation tree cannot be displayed."] = true

L["If"] = true
L["Unless"] = true
L["If matches this condition; Unless negates it."] = true

L["Condition description unavailable: invalid data."] = true
L["Condition description truncated; the draft is unchanged."] = true

L["New group"] = true
L["Drag card headers to move; drag New into a gap."] = true

L["Incomplete condition group: choose its conditions."] = true
L["Always (empty All group)"] = true
L["Never (empty Any group)"] = true

L["Browse, view and edit rotations."] = true
L["Configure recommendations and display."] = true
L["Organize condition types and custom conditions."] = true
L["Configure highlight effects."] = true
L["Manage interchangeable items and consumables."] = true
L["Configure optional announcements."] = true
L["Manage saved configuration profiles."] = true
L["Rotation Master information and credits."] = true
L["TBC"] = true
L["Classic Era"] = true
L["Classic Progression"] = true
L["Retail"] = true
L["Forever"] = true
L["Development"] = true
L["Right-click to close"] = true
L["Drag to resize the list. Double-click to reset."] = true
L["Drag onto any action bar slot (it swaps with what is there), or click Bind and then click an empty slot."] = true
L["English"] = true
L["Website"] = true
L["English is the installed translation; other languages use English until translated."] = true
L["Drag the title bar to move. Adjust Scale at the top left; right-click the content to close."] = true
L["Optional addon settings."] = true
L["Automatic (game language)"] = true
L["Language of Rotation Master's text. Automatic follows the game's language (%s). A change shows after the interface reloads; text not yet translated appears in English."] = true
L["%s shows after the interface reloads."] = true
L["This game version loads settings after Rotation Master's text, so some names keep the game's language."] = true
L["Rotation Master shows %s after the interface reloads. Reload now?"] = true
L["Reload now"] = true
L["Later"] = true
L["Read-only condition"] = true

L["Delete"] = true
L["Only the first 200 rotation cards are shown. Other cards are preserved."] = true
L["Branches select one arm, then rejoin the following priority. Forced modes skip condition evaluation."] = true
L["New action"] = true
L["New branch"] = true
L["New optional"] = true
L["Drag into a gap, or click to append."] = true
L["Discard"] = true
L["Changes applied."] = true
L["Choose"] = true
L["Items: separate item IDs or names with commas"] = true
L["Use profile effect"] = true
L["Color: red, green, blue, alpha (0–1); blank inherits"] = true
L["Use profile position"] = true
L["Horizontal offset"] = true
L["Vertical offset"] = true
L["Created by %s"] = true
L["Unsaved rotation changes"] = true
L["Apply this draft, discard its changes, or keep editing."] = true
L["The draft could not be applied. Complete the marked fields or Cancel to keep editing."] = true

L["Drag to place"] = true
L["Copy full condition"] = true
L["Full condition text"] = true

L["Default"] = true

L["Click to add branch name"] = true

L["Switch condition"] = true

L["Edit"] = true

L["Delete rotation"] = true

L["Add action"] = true

L["Add branch"] = true

L["Add cooldown"] = true

L["Delete this custom rotation and its unsaved draft? This cannot be undone."] = true

L['Rotation details'] = true

L["Built In and custom rotations use the same cards. Built In rotations are read-only; enable or disable them, inspect their conditions, or Duplicate to edit."] = true

L["Custom edits stay in a private draft. Apply saves; Discard restores the saved rotation. Undo and Redo include card deletion, movement, fields and conditions. Apply before reloading or logging out."] = true

L["Closing the window retains drafts for this session. Switching rotations or opening comparison or transfer asks whether to Apply, Discard or Cancel when changes are pending."] = true

L["The switch condition selects the rotation automatically. Edit changes its condition tree. The fallback rotation is selected when no other rotation matches."] = true

L["Cooldown cards have their own scrolling workspace and highlight independently of the sequence. Add cooldown creates a reminder; clicking its action shows local highlight settings."] = true

L["Add action appends a priority action. Drag an Add control into a gap to insert there. Click a card name to rename it, expand for action fields, or click its condition text to edit the guard."] = true

L["Adding a branch moves following steps into its True arm. False is on the left in red; True is on the right in green. The mode pill cycles Evaluate condition, Always true and Always false. Unreachable cards are gray."] = true

L["Ordinary dragging moves one card and its own subtree. Hold Ctrl when starting a drag to carry that card and every following sibling, including their branch subtrees. Drop into a branch arm gap to move there. Up / Down always moves one card. A group cannot be dropped into itself or a carried descendant."] = true

L["An evaluated branch follows one arm, then rejoins later siblings. Stop ends the sequence. Independent cooldowns still apply; implicit Attack remains available unless the Stop suppresses it."] = true

L["Invalid or incomplete cards remain editable. Apply validates both branch arms without running custom condition code. Deleting a whole custom rotation requires confirmation and cannot be undone."] = true

L["List and Cooldowns use flat scrollbars or the mouse wheel. Diagram uses wheel zoom and dragging empty space to pan. Window scaling applies when the slider is released and also affects RM child windows."] = true

L['Complete the highlighted input fields before applying.'] = true

L['Drop in a highlighted gap.'] = true

L['Name'] = true

L['Incomplete input: %s'] = true

L['Click condition text on any card to view or edit its conditions.'] = true
L['View condition'] = true
L['Edit condition'] = true

L['Cycle between summary, fields and name only. Drag the name to move the card.'] = true

L['Metadata'] = true
L['This rotation cannot run until its incomplete or unavailable data is resolved.'] = true
L['Rotation validation'] = true

L['Preview effect'] = true
L['Show or hide branch paths'] = true

L['Expand or collapse the card. Click action or condition text for details.'] = true

L["Click to expand"] = "Click to expand"

L["Add group"] = "Add group"

L["Click to append; drag into a gap to insert."] = "Click to append; drag into a gap to insert."

L["Preview highlight"] = "Preview highlight"

L["This previews the glow used on action buttons. Click the preview icon again to close."] = "This previews the glow used on action buttons. Click the preview icon again to close."

L["Choose a highlight effect in the action details or General settings."] = "Choose a highlight effect in the action details or General settings."

L["Rotation metadata"] = "Rotation metadata"

L["Author"] = "Author"

L["Realm"] = "Realm"

L["Email"] = "Email"

L["Version"] = "Version"

L["Use changes"] = "Use changes"

L["Use changes updates the draft. Apply the rotation to save it."] = "Use changes updates the draft. Apply the rotation to save it."

L["Built In rotation: duplicate it to edit its metadata."] = "Built In rotation: duplicate it to edit its metadata."

L["Source"] = "Source"

L["Saved metadata is invalid (%s). Editing these fields replaces it."] = "Saved metadata is invalid (%s). Editing these fields replaces it."

L["Color"] = "Color"

L["Highlight preview"] = "Highlight preview"

L["Choose an effect"] = "Choose an effect"

L["Use profile color"] = "Use profile color"

L["Center the highlight"] = "Center the highlight"

L["Move highlight; hold Shift for ten pixels"] = "Move highlight; hold Shift for ten pixels"

L["Preview sound"] = "Preview sound"

L["Sound preview is unavailable."] = "Sound preview is unavailable."

L["Choose an available sound to preview."] = "Choose an available sound to preview."

L["Use color"] = "Use color"

L["Offsets"] = "Offsets"
L["V"] = "V"
L["H"] = "H"

L["RGBA channels accept decimal values from 0 to 1."] = true

L["%s: %s"] = true
L["Rotation Master"] = true
L["Condition"] = true
L["Cooldown"] = true

L["Sources"] = true

L["All of"] = true
L["Any of"] = true

-- Native settings pages
L["Action bar binding"] = true
L["Add announcement"] = true
L["Add category"] = true
L["Add custom condition"] = true
L["Add effect"] = true
L["Add item"] = true
L["Add item set"] = true
L["Add step"] = true
L["An item from this set must be available before binding."] = true
L["Bind item set"] = true
L["Category"] = true
L["Choose an action first."] = true
L["Choose an item first."] = true
L["Commands"] = true
L["Confirm"] = true
L["Copy and reset"] = true
L["Copy from profile"] = true
L["Copy this text to export. Import replaces the selected settings."] = true
L["Create profile"] = true
L["Current profile"] = true
L["Delete profile"] = true
L["Delete profile %s? This cannot be undone."] = true
L["Delete this custom condition? Existing rotations using it will become unavailable."] = true
L["Delete this effect? Rotations using it will need another effect."] = true
L["Delete this item set and its binding? Rotations referencing it will need another item set."] = true
L["Enable"] = true
L["Enter a name first."] = true
L["Enter a profile name first."] = true
L["History and preview"] = true
L["Identifier"] = true
L["Invalid effect."] = true
L["Invalid import."] = true
L["Invalid item list."] = true
L["Item %d"] = true
L["Items in priority order"] = true
L["Links"] = true
L["New profile name"] = true
L["Not bound"] = true
L["Profile changes apply immediately. Rotations and settings belong to the active profile."] = true
L["Recommendations"] = true
L["Remove binding"] = true
L["Replace the current profile with %s?"] = true
L["Reset"] = true
L["Reset current profile"] = true
L["Reset preview position"] = true
L["Reset this profile to its defaults? Custom rotations and settings in it will be replaced."] = true
L["Select"] = true
L["Step %d"] = true
L["This name is already in use."] = true

-- Contextual native help
L["Branch"] = true
L["Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To changes its category; order arrows arrange category entries. Custom conditions can be edited, duplicated or deleted."] = true
L["Choose a current profile or enter a new profile name and create it. Copy replaces the current profile’s settings; Reset restores defaults. Delete removes another saved profile. Copy, Reset and Delete ask for confirmation."] = true
L["Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; Remove binding unlinks it. Reset restores a packaged set. Import replaces its item list."] = true
L["Choose and edit"] = true
L["Click a condition type to search or browse categories. Dismissing the picker or choosing the same type keeps its fields. Click the condition summary to edit its fields. The chevron switches between name only and summary; the double chevron closes the fields."] = true
L["Click a name to rename it. Clear a custom step name to restore its action name. Click a collapsed title to show its summary. Click action or condition text to open its details; the double chevron returns from fields to the summary."] = true
L["Click condition text to edit when this card can run. Enabled / Disabled preserves the card while switching its participation. Actions also require known or carried actions, usable resources, cooldown readiness and valid range."] = true
L["Click the action to edit its type, spell or item. The leading icon previews the effect. Effect selects a style; Magnification changes its size. Click the swatch or edit RGBA on the 0–1 scale. Arrows adjust position; V / H show offsets. Default restores profile values. Sound selection and Play preview an audible reminder."] = true
L["Click the guard text to edit the branch condition. Evaluate uses that condition; Always true / Always false skips it. False is left and red; True is right and green. The branch icon hides both arms without changing them. Click True or False to fold only that arm; its hidden count remains visible. Gray cards in a forced arm are unreachable."] = true
L["Condition editor"] = true
L["Conditions and state"] = true
L["Configure recommendation timing, automatic switching, history, preview and profile highlight defaults. Labels are on the left. Checkboxes toggle options, sliders show numeric values, and fields validate before saving."] = true
L["Description and attribution"] = true
L["Drag one card into a highlighted gap; hold Ctrl when starting the drag to carry that card and all following siblings. A branch always carries its children. Use Up / Down on the left to move one card. Duplicate copies the card and the red trash can deletes it. Cooldowns are independent, so they have no move arrows."] = true
L["Drag a card into one highlighted gap, or use the left-side Up / Down arrows. Hold Ctrl when starting a drag to carry the card and all following siblings. Groups always carry their children. Unavailable moves are gray. Ctrl-click or Shift-click selects several cards for grouping; dragging an existing selection moves that selection. Duplicate copies a card; Split group removes its wrapper; the red trash can deletes it. Add condition and Add group append when clicked or insert where dropped."] = true
L["Drag the title bar to move. Set Scale with the top-left slider; child windows follow it. The question mark toggles Help. Close with X, Escape, or right-click in the content area."] = true
L["Edit the description, author, realm, email, website and version. Source citations remain separate from your attribution. Use changes updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values."] = true
L["Editing settings"] = true
L["Expand an announcement to choose its action, event, channel and text. Spell fields search the catalog; exact rank limits matching to that rank. Enabled toggles the announcement. Add announcement creates a new entry after an action is selected."] = true
L["Groups and toggles"] = true
L["Help and saving"] = true
L["Highlight effects"] = true
L["If / Unless toggles negation. Enabled / Disabled keeps the saved fields while skipping evaluation. All / Any changes AND / OR. Click a group name to rename it; the branch icon hides or shows its children. Gray descendants cannot be reached."] = true
L["Move, copy and remove"] = true
L["Names and details"] = true
L["Search or filter the rotation roster, then select a rotation. Blue Built In rotations use the same editor but remain read-only; Duplicate makes an editable copy. The name and Metadata describe the rotation. Switch condition selects when it applies. Use the Rotation and Cooldowns tabs to select the content below the switch condition. Cooldowns highlight independently of the ordered rotation."] = true
L["Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Import replaces the selected effect after validation."] = true
L["The question mark explains the visible controls. With condition fields open, it adds that condition’s help below the fields. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data."] = "The question mark opens full Help for its subject. Hover controls for brief tips. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data."
L["These settings apply immediately. Press Enter or leave a text field to commit it. Invalid text stays red and blocks navigation until corrected. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents."] = true
L["Using this page"] = true
L["Version, author, credits and project links are shown here. Click a link field to select its text for copying."] = true
L["Window controls"] = true

L["Unknown spell"] = true

L["Item data loading"] = true

L["Primary"] = true

L["Secondary"] = true

L["No matches."] = true

L["New"] = true

L["No matching items."] = true

L["Click a result or enter an item name, ID or link."] = true

L["Anchor"] = true

L["Return the preview window to the center of the screen."] = true

L["The icon shows your selected profile effect, color, size, anchor and offsets."] = true

L["Vertical offset in pixels. Up and Down change it; hold Shift for ten pixels. Center resets both offsets."] = true

L["Horizontal offset in pixels. Left and Right change it; hold Shift for ten pixels. Center resets both offsets."] = true

L["Manage categories"] = true

L["Back to conditions"] = true

L["Built-in category"] = true

L["Delete category"] = true

L["Delete this category? Its conditions will remain available under Other."] = true

L["Filter the condition list by All, Switch, Custom, Other or a named category. Search narrows the visible conditions without changing their category."] = true

L["Open Manage categories below the list for category maintenance. Back to conditions returns to individual condition settings."] = true

L["Name"] = true

L["Rename the selected category in Manage categories. Built-in categories cannot be renamed or deleted."] = true

L["Add an empty named category from the category-management list. Move To in condition settings assigns a condition to it."] = true

L["In Manage categories, move the selected category earlier in the category list."] = true

L["In Manage categories, move the selected category later in the category list."] = true

L["Delete a named category after confirmation. Its conditions remain available under Other; their definitions are preserved."] = true

L["In Manage categories, copy or replace a category’s ordered condition identifiers. Named categories and Other are exclusive destinations. Switch membership is independent."] = true

L["Filter the visible condition list by name or identifier. The category filter still applies."] = true

L["Allow this condition type to be used when automatically selecting a rotation."] = true

L["Hide this condition from the Other picker category. Explicit named-category and Switch membership remain available."] = true

L["Condition order"] = true

L["The condition ordering controls in condition settings move the selected condition to the top, up, down or to the bottom within its current category. These are separate from the Up and Down controls for category order."] = true

L["Move the selected condition to a named category or Other. Use Switch Condition separately for automatic-switch availability."] = true

L["Yes"] = true

L["No"] = true

L["Show unchanged"] = true

L["Changed fields: %d"] = true

L["Compare"] = true

L["Read-only"] = true

L["Imported item set"] = true

L["Drag to reorder"] = true

L["Item ID: %s"] = true
L["Item reference: %s"] = true

L['Built-in'] = true

L['Built-in condition'] = true

L['Custom condition'] = true

L['Game icon'] = true

L['Game icons'] = true

L['Icon'] = true

L['Item icons'] = true

L['Known spells'] = true

L['Manage conditions'] = true

L['Next'] = true

L['Page %d of %d'] = true

L['Previous'] = true

L['Activate profile'] = true

L['Active profile'] = true

L['Apply / Cancel'] = true

L['Apply pending changes before leaving? Use Cancel on the page to discard them.'] = true

L['Audible'] = true

L['Categories'] = true

L['Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To stages a category destination; its Apply button confirms the move. The assigned category opens category management. Sidebar arrows and dragging order entries. Page Apply saves the draft; Cancel discards it. Custom conditions can be edited, duplicated or deleted.'] = true

L['Choose a named category or Other, then use Apply beside the destination to stage the move. Page Apply saves all pending changes. Use Switch Condition separately for automatic-switch availability.'] = true

L['Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; The binding pill removes matching bound bar actions when unbinding, outside combat. Reset restores a packaged set. Search or drag items into reference fields. Apply saves settings; Cancel discards them. Binding changes are explicit action-bar operations.'] = true

L['Clone sources'] = true

L['Comparison history'] = true

L['Complete the effect settings before applying.'] = true

L['Credits'] = true

L['Built In preferences'] = true

L['Edits stay in a draft until Apply. Cancel restores saved settings. Changing tabs or closing asks to apply pending changes; Cancel on the page discards them. Effect previews do not save changes. Action-bar binding operations are explicit and immediate.'] = true

L['Expand an announcement to choose its action, event, channel and text. Spell fields search the catalog; exact rank limits matching to that rank. Enabled toggles the announcement. New opens a draft with Apply and Cancel. Audible replaces text with sound selection and Play. Duplicate, Import/Export and Compare are below the list; imports are validated and never execute code. Apply saves changes.'] = true

L['Ignore mana'] = true

L['Ignore range'] = true

L['Imports'] = true

L['Invalid announcement.'] = true

L['Invalid profile.'] = true

L['Leave combat before applying these settings.'] = true

L['Leave combat before changing action bar bindings.'] = true

L['License'] = true

L['Localizations'] = true

L['No rotations in this profile.'] = true

L['Preview position'] = true

L['Rotation library'] = true

L['Search or drag a spell here'] = true
L['Move %d selected cards'] = true
L['Duplicate selected cards'] = true
L['Enable selected cards'] = true
L['Disable selected cards'] = true
L['Delete selected cards'] = true
L['Clear selection'] = true
L['Select several cards'] = true
L['Ctrl-click cards to add or remove them from the selection; Shift-click selects the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). With several cards selected, the strip above the canvas groups them as All or Any, and Duplicate, Enable, Disable and Delete act on every selected card; one Undo reverses each. Drag any selected card to move the selection.'] = true
L['Ctrl-click cards to add or remove them from the selection; Shift-click a title or condition to select the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). Drag any selected card to move the whole selection to one gap. Beside Apply, Duplicate, Enable, Disable and Delete act on every selected card, and one Undo reverses each. Branches keep their Evaluate / Always mode. Click empty canvas to clear the selection.'] = true
L['Target casting: %s'] = true
L['Focus casting: %s'] = true
L['Target channeling: %s'] = true
L['Focus channeling: %s'] = true
L['Recently cast: %s'] = true
L['Trinket 1: %s'] = true
L['Trinket 2: %s'] = true
L['No equipped trinket to insert.'] = true
L['Nothing to insert: no target or focus cast and no recent casts.'] = true
L['Click to insert. Right-click the field again to close.'] = true
L['Right-click to insert an equipped trinket.'] = true
L["Right-click to insert your target's cast or a recent cast."] = true

L['Search or drag an item here'] = true

L['Select a profile in the sidebar to inspect it, then Activate profile to switch. New and Duplicate open a named draft with Apply and Cancel. Import stages a validated new profile; Compare shows setting differences. Copy and Reset replace the active profile after confirmation; the red trash deletes an inactive profile.'] = true

L['Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Drag a sequence card surface to reorder it; fields remain editable. New effects can be configured before naming. Apply saves the draft; Cancel discards it. Import stages a validated replacement.'] = true

L['Settings changed elsewhere. Cancel to reload them before applying.'] = true

L['Slots %s · Unbind'] = true

L['Sound'] = true

L['Structured settings'] = true

L['Unnamed rotation'] = true

L['Use arrows or drag rows in the condition sidebar to reorder within the selected category. In Manage categories, the same controls order the categories themselves.'] = true

L['Value'] = true

L['Choose an action and complete the announcement before applying.'] = true

L['The condition ordering controls are arrows and draggable rows in the sidebar of the selected category. In Manage categories, the same controls order the categories themselves.'] = true

L['Apply changes before leaving this page?'] = true

L['Apply or discard current settings before opening the custom code editor.'] = true

-- Shared import destinations and editing history.
L['Apply item-set changes before binding it to an action bar.'] = true
L['Choose a new named copy or replace the selected editable entry. Review the destination before importing.'] = true
L['Clear'] = true
L['Confirm the Lua import, then review it before saving.'] = true
L['IMPORTED_CONDITION'] = true
L['Import comparison'] = true
L['Imported announcement'] = true
L['Imported category'] = true
L['Imported effect'] = true
L['Imported profile'] = true
L['Invalid custom condition.'] = true
L['Name not supplied'] = true
L['Original name'] = true
L['Ready to import. Choose replacement or a named copy.'] = true
L['Replace selected entry'] = true
L['That condition identifier already exists.'] = true
L['The selected profile changed. Reopen the import window.'] = true
L['This import contains Lua code. Only continue if you trust its author. Import opens the code for review; saving the condition can execute it.'] = true
L['Use letters, numbers and underscores for the condition identifier.'] = true

-- Native custom condition authoring.
L['Check %s: %s'] = true
L['Check syntax'] = true
L['Choose icon'] = true
L['Custom Lua has the same access as the addon. Only import code you trust. Syntax validation cannot establish that a callback is safe or correct. Existing custom widget callbacks still use their original UI contract.'] = true
L['Declare named fields, primitive types, nested records and unions. Example: { spell = { string, number }, unit = string, tests = condition[] }. Schema text is parsed as data and never evaluated as Lua.'] = true
L['Definition'] = true
L['Editing code'] = true
L['Evaluate'] = true
L['Field schema'] = true
L['Fields UI'] = true
L['Function tabs edit separate callbacks. Changes stay in a draft. Check syntax compiles every callback without running it. Apply registers the callbacks and can run registration code. Cancel discards the draft. Undo and Redo work across function tabs.'] = true
L['On register'] = true
L['On unregister'] = true
L['Summary'] = true
L['Syntax checked. No custom code was executed.'] = true
L['The custom condition changed elsewhere. Reopen it before saving.'] = true
L['Trusted code'] = true
L['Validate'] = true

-- Rotation tags and roster filtering.
L['All tags'] = true
L['Edit the description, tags, author, realm, email, website and version. Source citations remain separate from your attribution. Use changes updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values.'] = true
L['Invalid tags. Use up to 64 tags of 64 characters, separated by commas.'] = true
L['Separate tags with commas. Use quotes for tags containing commas. Any personal label is allowed.'] = true
L['Tags'] = true

-- Explicit auto-switch precedence.
L["Switch priority"] = true
L["Priority %d"] = true
L["Invalid priority"] = true
L["Switch priority must be a whole number between -100000 and 100000."] = true
L["Edit the description, tags, switch priority, author, realm, email, website and version. Source citations remain separate from your attribution. Use changes updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values."] = true
L["Higher numbers are tried first; your rotations and Built Ins compete on priority alone. The fallback is used only when no switch condition of another rotation matches. Equal priorities use name, then identity. Blank means zero."] = true
L["Invalid switch priority for %s:%s; explicit repair resets it to zero."] = true

-- Rank-aware aura families.
L["Match all ranks"] = true
L["%s (any rank)"] = true
L["For a numeric spell selection, also recognize auras with the same readable localized spell name. Exact IDs remain the default. Spell names already match by name. Unavailable metadata or restricted aura identity stays unavailable, including under NOT. Different spells sharing a name can match; use exact IDs when that distinction matters."] = true

-- Spell ID identity for casts, channels and forms.
L["A spell picked in the editor is matched by its spell ID, so the condition works on every client language. Any rank of that spell matches unless Use this exact spell rank is ticked. Conditions saved with a spell name keep matching by that name. If the client cannot read the spell being cast, the condition is unavailable, including under NOT."] = true
L["A form is chosen by its spell, so the condition keeps working as new forms are learned and on every client language. Any rank of the form matches. The list shows the forms on your stance bar, then your class's other forms on this client. A condition saved by stance bar slot keeps that slot until you choose a form. If the client cannot read the active form, the condition is unavailable, including under NOT."] = true
L["Stance bar slot %s (%s)"] = true
L["Cast Progress"] = true
L["Channel Progress"] = true
L["%s cast progress"] = true
L["%s channel progress"] = true
L["Progress"] = true
L["How much of the current cast of {unit} is done, from 0% when it starts to 100% when it completes. It follows haste and pushback, because it is measured against the cast's own start and end. If the unit is not casting, this condition is not successful, whatever the operator; if the cast's times cannot be read, it is unavailable, including under NOT."] = true
L["How much of the current channel of {unit} is done, from 0% when it starts to 100% when it ends. Ticks are evenly spaced through a channel, so tick N of a K-tick channel lands at N/K whatever your haste: to clip Mind Flay (3 ticks) after its second tick, use at least 66%. Pushback shortens a channel and the progress follows it. If the unit is not channeling, this condition is not successful, whatever the operator; if the channel's times cannot be read, it is unavailable, including under NOT."] = true

-- Classic tree selection for adaptive rotations.
L["Talent tree %s"] = true
L["This client does not expose a Classic talent-tree layout. The saved tree reference is preserved."] = true
L["Talent tree"] = true
L["Talent Tree Points"] = true
L["points spent in %s"] = true
L["Talent tree selects the Classic tree whose spent points are compared. Public points are read again on the next evaluation; missing or restricted points are unavailable, including under NOT. Grids and trait trees are unsupported."] = true
L["Compare whole points spent from zero to 512. An explicit comparison with zero can describe an unspent tree."] = true
L["Primary Talent Tree"] = true
L["your primary talent tree is %s"] = true
L["Talent tree selects the unique Classic tree with the most positive spent points. Equal maxima, no spent points, missing records and restricted points are unavailable, including under NOT."] = true
L["The primary tree is derived from readable points, not the saved rotation slot. Hybrid builds may need tree-point or individual-talent conditions instead; the primary tree does not assign a tank or healer role. Grids and trait trees are unsupported."] = true

-- Protected item observations
L["Item sets are checked in priority order. Bag counts use the first carried candidate, not the sum. Availability, range and cooldown checks use the first carried or equipped candidate. Missing or restricted observations stay unavailable, including under NOT."] = true
L["Item Available checks the required level and enabled item cooldown. An active cooldown qualifies only when it ends with the readable global cooldown. This condition does not bypass the action's implicit ownership, usability and range checks."] = true

-- TBC early Frost Mage preview.
L["Default.TBC.Mage.Frost.Name"] = "Mage: Frost"
L["Default.TBC.Mage.Frost.Description"] = "Frost from level 1 to 70, and the Mage default before talents. Frostbolt (Fireball before level 4), Frost Nova when something hits you, Cone of Cold with Blizzard or Arcane Explosion when three or more enemies are engaged, Ice Lance on frozen targets and while moving, wand when out of mana. Reminders: armor, Arcane Intellect, mana gem, Evocation, Counterspell, Spellsteal, Ice Barrier, Icy Veins, Cold Snap and Water Elemental. Blink, Ice Block, kiting and target choice stay with you."
L["Default.TBC.Mage.FireIcyVeins.Name"] = "Mage: Fire (Icy Veins)"
L["Default.TBC.Mage.FireIcyVeins.Description"] = "Fire after Icy Veins, chosen when Fire is your main talent tree. Pyroblast opens a pull once learned, Improved Scorch keeps five Fire Vulnerability stacks, Fireball fills, Fire Blast is for moving; Blast Wave, Dragon's Breath and Flamestrike for three or more enemies. Reminders: Molten, Mage or Ice Armor, Combustion below 20% target health, mana gem, Evocation and the shared Mage utilities."
L["Default.TBC.Mage.FireWowhead.Name"] = "Mage: Fire (Wowhead)"
L["Default.TBC.Mage.FireWowhead.Description"] = "Fire after Wowhead and wowsims. Like the Icy Veins Fire premade, but it weaves Fire Blast whenever it is ready while you stand still (more damage, more mana) and opens with Fireball instead of Pyroblast. An alternative to the recommended Icy Veins Fire premade, off by default: enable it and disable that one, or raise its priority."
L["Default.TBC.Mage.Arcane.Name"] = "Mage: Arcane"
L["Default.TBC.Mage.Arcane.Description"] = "Arcane, chosen when Arcane is your main talent tree. Before level 64: Arcane Missiles, with Frostbolt when mana runs low. From 64: Arcane Blast while burning (Arcane Power, Bloodlust or above 35% mana), otherwise three Arcane Blast stacks and Frostbolt until they are about to drop. Arcane Explosion and Cone of Cold for three or more enemies. Reminders include Arcane Power, Presence of Mind, mana gem and Evocation."

-- Alternate rotation presentation.
L["Diagram view"] = true
L["List view"] = true
L["Switch between the diagram and compact tree list. This changes only the view."] = true

-- Independent rotation viewport navigation.
L["Zoom out"] = true
L["Zoom in"] = true
L["Reset canvas zoom to 100%. Drag empty canvas space to pan. Window scale is unchanged."] = true
L["Navigating rotations"] = true
L["Diagram / List changes only the rotation view; General settings choose the default. Diagram has floating minus, percentage and plus controls at the bottom right. Scroll to zoom from 25% to 200%; click the percentage or middle-click to reset to 100%. Drag empty diagram space to pan. List uses normal scrollbars with touching cards and boxed branch arms, False before True. Cooldowns use a separate scrolling grid. Dragging cards reorders them in every view. Each workspace currently shows at most 200 cards; the remaining saved cards are preserved."] = true

-- Current native announcement help: whole paragraphs, not English fragments.
L["Enabled / Disabled"] = true
L["Announcement substitutions"] = true
L["New, Duplicate, Import/Export and Compare"] = true
L["Help.Announces.editing"] = "Announcement details stay always expanded while editing. Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid fields must be corrected before Apply; Discard abandons pending changes. Searchable selectors open on click and filter as you type. The page Help icon explains every option and text substitution."
L["Help.Announces.overview"] = "Announce selected spell casts or item uses independently of your active rotation, or invoke a configured Via Script/Macro entry directly. Select an entry in the sidebar, or use New to prepare one. The trigger applies to every ordered output card; each card has its own destination and conditions. These settings do not cast spells or use items. Cast-triggered announcements follow RM's combat-data policy and do not run on reference-only clients."
L["Help.Announces.name"] = "An optional name identifies this announcement in the sidebar. Without one, the action name or Via Script/Macro identifier is used. Changing this display name does not change the watched action or callable identifier."
L["Help.Announces.type"] = "Choose Spell, Pet Spell, Item or Via Script/Macro. Changing type clears the previous action and exact-rank choice. Via Script/Macro uses an Identifier instead of a cast event or stored action; switching back restores the event selector. Choosing the current type keeps its fields."
L["Help.Announces.type.spell"] = "Watch one of your spells. Choose the spell in the searchable field below Action Type."
L["Help.Announces.type.pet"] = "Watch a spell from your pet spellbook. The spell selector uses the pet catalog for this action type."
L["Help.Announces.type.item"] = "Watch item-use spells from a reusable item set or a custom list. This is an announcement trigger; it does not choose an item to use for you."
L["Help.Announces.spell"] = "Search by spell name, select a result, or drag a spell from your spellbook or action bar into the field. The icon and name identify the selected spell. Spell and pet spell choices keep their respective catalog scope."
L["Help.Announces.ranked"] = "Checked limits matching to the selected rank. Unchecked includes the known ranks in that spell family. This checkbox is shown only for Spell and Pet Spell."
L["Help.Announces.items"] = "Choose a reusable set, or Custom to edit this announcement's own list. For a custom list, search for or drag items into the fields; Add item appends one and a red trash can removes an entry. Any matching item-use spell in the list can trigger the announcement; list order does not limit announcements to the first carried item. Changes to a shared set belong on the Item Sets page."
L["Help.Announces.event"] = "For automatic action types, choose which observed cast event triggers this entry. A start, stop, interruption, failure or delay is different from a successful cast. Client support determines which events and observations are available. Via Script/Macro has no cast event."
L["Help.Announces.event.START"] = "The cast or channel started. This event does not mean it will finish successfully."
L["Help.Announces.event.STOP"] = "The cast or channel stopped. A stop alone does not establish whether it succeeded."
L["Help.Announces.event.SUCCEEDED"] = "The client reported a successful spell cast or item-use spell. For a channel, this can occur as channeling begins rather than after its final tick."
L["Help.Announces.event.INTERRUPTED"] = "The client reported that the cast was interrupted. This can include cancelling a cast yourself."
L["Help.Announces.event.FAILED"] = "The client reported that the cast failed. This is separate from the successful-cast event."
L["Help.Announces.event.DELAYED"] = "The client reported a delay to the cast. This event is not a completion or success notification."
L["Help.Announces.announce"] = "Choose a chat destination, local output, a named Emote or Audible. Emote replaces Text with an emote selector and optional recipient. Audible replaces Text with Sound. Text is retained when switching modes. Say, Yell, Whisper and named joined channels are offered only for Via Script/Macro and remain subject to native restrictions."
L["Help.Announces.channel.audible"] = "Play the selected sound locally on the Master audio channel; no chat message is sent. Choose an available sound before applying the announcement."
L["Help.Announces.channel.partyraid"] = "Use raid chat while in a raid, party chat while in a party, or your local chat frame while solo."
L["Help.Announces.channel.party"] = "Use party chat when grouped, including your party within a raid. This destination produces no solo chat message."
L["Help.Announces.channel.raidwarn"] = "Request group warning output. Depending on group membership and permissions, RM may use raid chat, party chat, or local output instead."
L["Help.Announces.channel.emote"] = "A saved free-text emote keeps its original message. Select Emote to use a named client emote instead."
L["Custom emote"] = true
L["Use spell recipient ({{target}})"] = true
L["Automatic Say and Yell are unavailable. Choose another announcement destination."] = true
L["Help.Announces.channel.gesture"] = "Choose a named emote from this client's slash commands, such as /cheer. This does not send the Text field as a custom emote."
L["Help.Announces.emote"] = "Choose the emote to perform when the configured cast event is observed. The client may restrict an emote or require a hardware action; RM does not retry through another output path."
L["Help.Announces.emote_target"] = "For cast entries, checked directs the emote to the recipient recorded for this exact cast, including click casting. It does not use your current target or a previous cast's recipient. For Via Script/Macro, checked uses the supplied macro unit. A missing recipient skips targeted output. Unchecked performs the emote without a target."
L["Help.Announces.channel.local"] = "Write to your own chat frame. Other players do not receive this message."
L["Help.Announces.text"] = "Enter the message for a chat destination. The substitutions below insert action and cast information when it is available. This text is not used for Audible or named Emote output."
L["Help.Announces.substitutions"] = "For cast entries, {{spell}} is a spell link, {{item}} an item link and {{event}} the localized event name. {{target}} uses the recorded cast target, with the last recorded target for that spell as a fallback; it does not automatically use your selected target or your name. Unavailable cast substitutions can remain unchanged. Via Script/Macro instead uses its supplied target and spell, {{event}} becomes Via Script/Macro, and required missing inputs skip output; this API supplies no {{item}}."
L["Help.Announces.sound"] = "Choose a sound supplied by the shared-media catalog, then click Play to preview it. Preview is local and does not save the draft. An unavailable sound cannot be previewed; Audible announcements require a nonempty sound selection."
L["Help.Announces.state"] = "The pill turns this entry on or off while keeping its fields. Disabled entries do not announce matching casts or macro invocations. Apply saves the changed state."
L["Help.Announces.save"] = "Edits stay in a draft until Apply. Complete the action or Via Script/Macro identifier and other required fields before saving. Discard abandons changes to saved announcements; Cancel closes a new creation draft. Leaving pending changes offers Apply, Discard or Cancel navigation."
L["Help.Announces.collections"] = "Use the sidebar buttons to create, duplicate, transfer or compare announcements. Apply saves the imported draft; Compare does not merge entries. Via Script/Macro Duplicate assigns a distinct identifier and every copied output gets a fresh identity. Series exports use version 2; version 1 remains available for legacy single-output entries. Imports and Apply reject ambiguous identifiers. The red trash permanently deletes the selected saved entry after confirmation. Resolve pending edits first; deletion does not carry into the next selected draft."
L["Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid text stays red and blocks navigation until corrected. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents."] = true

-- Item-set and item-list help: translate each paragraph as a whole.
L["Help.ItemSets.overview"] = "An item set is an ordered list of alternatives, such as different mana potions. Runtime selection checks the list from the top for a carried or, where requested, equipped item. Priority comes from the order you choose, not the item level. Selecting an item does not by itself prove that it is usable, off cooldown, or in range; action readiness is checked separately."
L["Help.ItemSets.name"] = "Name the selected set so it can be found in the sidebar and referenced by rotations or conditions. New opens a name form; its first Apply saves an empty named set. Add items afterward and Apply again to save them. Discarding later item edits keeps that already saved set. Renaming a set does not change its identity in saved references."
L["Help.ItemSets.global"] = "Checked stores this set in the shared global collection, available to other profiles and characters using this addon database. Unchecked stores it in the current profile, which can itself be shared by characters. This is a staged move; Apply saves it. A profile set takes precedence if a global set has the same saved identity."
L["Help.ItemSets.items"] = "The list of item cards is the priority order. Put preferred items first. RM can leave a selection unavailable when required inventory or identity observations are missing; it does not treat unknown data as proof that a lower-priority item should be used. The sidebar icon represents the first defined item and need not be the currently carried or highlighted one."
L["Help.ItemSets.item"] = "Search by item name and choose a result, or drag an item from your bags or action bar into its field. The icon identifies the item; metadata can take time to load. Edit a row to replace that entry. Use its red trash can to remove it rather than clearing a required item field."
L["Help.ItemSets.add"] = "Choose or drag an item into the empty item field above the list, then click Add item to append it to the priority list, or drag Add item into a gap between cards to insert it there. Entering an item in this field alone does not add a row."
L["Move Up / Move Down"] = true
L["Help.ItemSets.order"] = "Use the arrows on the left, or drag an item row into a highlighted insertion gap. Ctrl-drag moves that row and all following entries together. The floating preview identifies what you are moving. Moves past the beginning or end are unavailable. Reordering changes priority and stays in the draft until Apply."
L["Bind / Unbind"] = true
L["Help.ItemSets.binding"] = "Outside combat, apply pending item-set edits before binding. Drag the set (its row in the list, or the Bind pill) onto any action bar slot; an occupied slot swaps, leaving its previous action on the cursor. Or click Bind and then click an empty slot. Both pick up the first available item of the set. RM records the slot and updates it as item availability changes. The pill shows bound slot numbers; click it to unbind and remove still-matching bar items. Replaced bar actions are preserved. Binding changes are immediate action-bar operations, independent of the draft and its history."
L["Help.ItemSets.reset"] = "Restore the packaged item list for this set. Reset is available only for a set with a packaged default. The restored list is staged until Apply; the name is kept."
L["Help.ItemSets.delete"] = "The red trash can at the top right permanently removes the selected saved set after confirmation. Resolve pending edits before the final warning. References in rotations or conditions then need another set. Deletion reconciles still-matching bound bar actions and keeps the set if unbinding fails; the next selection opens without an unsaved deletion marker."
L["Undo / Redo"] = true
L["Help.ItemSets.history"] = "Undo and Redo travel through recent item-set draft edits, including replacements, additions, ordering and row removals. They are unavailable when that direction has no history. Apply, Discard or leaving the page clears this bounded history. They do not reverse confirmed entity deletion or explicit action-bar binding operations."
L["Apply / Cancel"] = true
L["Help.ItemSets.save"] = "Ordinary item-set edits stay in a draft until Apply. Discard restores the saved item sets. Cancel closes a new creation draft. Leaving with pending changes offers Apply, Discard or Cancel navigation. Invalid fields must be corrected before Apply; Discard can abandon them."
L["Help.ItemSets.collections"] = "Use the buttons below the sidebar to create, duplicate, transfer, or compare sets. Duplicate makes an independent profile copy. Import shows the source name and can create a renamed copy or replace the selected list; Apply saves the staged result. Compare inspects differences without merging or modifying either set."
L["Legacy macro buttons"] = true
L["Help.ItemSets.macros"] = "Legacy clients may allow /click to invoke an RM item-set button separately from action-bar binding. The name is RM_ followed by the set name with non-alphanumeric characters removed, then an underscore and unit token. For a set named Bandages, an example is /click [@mouseover,nodead,help] RM_Bandages_mouseover. Other unit suffixes include player, pet, target, focus, pettarget, targettarget, focustarget, and mouseovertarget. These buttons contain item-use macro lines and do not provide the same readiness or first-item guarantee as the recommendation engine. Availability is subject to the client's secure-button and macro restrictions; reference-only support does not promise executable macro buttons."
L["Help.ItemSets.list.item"] = "Search for an item or drag it into the item field or icon. Choose the result to retain its exact item identity. The icon and name may be unavailable until metadata loads. Field clearing and save behavior belong to the editor that contains this list; use Delete when you intend to remove an entry."
L["Help.ItemSets.list.top"] = "Move this entry to the first position in the item priority list, when that control is offered."
L["Help.ItemSets.list.up"] = "Move this entry one position earlier. A move before the first entry is unavailable."
L["Help.ItemSets.list.down"] = "Move this entry one position later. A move past the final entry is unavailable."
L["Help.ItemSets.list.bottom"] = "Move this entry to the final position in the item priority list, when that control is offered."
L["Help.ItemSets.list.delete"] = "Remove this entry from the list. In a draft editor this remains pending until Apply, and Discard abandons the row edit. Undo is available where the containing editor provides draft history. This differs from permanently deleting the entire set after confirmation."

L["Default rotation view"] = true

L["Choose Diagram or List as the starting rotation view. This profile preference applies when opening a rotation; changing the view inside the editor does not change this setting. Cooldowns always use a scrolling grid."] = true

L["Reset diagram zoom to 100%. Scroll to zoom; middle-click to reset. Drag empty space to pan."] = true

L["Move this and following entries"] = true
L["Drag one entry; Ctrl-drag moves it and all following siblings."] = true

L["%d cards"] = true
L[" (%d hidden)"] = true
L["Click to fold or unfold this branch arm. Other cards and conditions are unchanged."] = true

L["%s totem {{!is|is not}} active"] = true

L["%s {{!are|are not}} %s"] = true

L["%s {{!are|are not}} PVP flagged"] = true

L["%s {{!are|are not}} a %s"] = true

L["%s {{!are|are not}} currently casting"] = true

L["%s {{!are|are not}} currently casting %s"] = true
L["{unit} {{!are|are not}} currently casting {spell}"] = true

L["%s {{!are|are not}} currently channeling"] = true

L["%s {{!are|are not}} currently channeling %s"] = true
L["{unit} {{!are|are not}} currently channeling {spell}"] = true

L["%s {{!are|are not}} in combat"] = true

L["%s {{!has|does not have}} %s"] = true

L["%s {{!has|does not have}} a %s debuff"] = true

L["%s {{!has|does not have}} a stealable buff"] = true

L["%s {{!have|do not have}} %s"] = true

L["%s {{!have|do not have}} %s where %s"] = true

L["%s {{!have|do not have}} a %s debuff"] = true

L["%s {{!is|is not}} %s"] = true

L["%s {{!is|is not}} PVP flagged"] = true

L["%s {{!is|is not}} a %s"] = true

L["%s {{!is|is not}} active"] = true

L["%s {{!is|is not}} active or pending"] = true

L["%s {{!is|is not}} active with %s"] = true

L["%s {{!is|is not}} an enemy"] = true

L["%s {{!is|is not}} attackable"] = true

L["%s {{!is|is not}} available"] = true

L["%s {{!is|is not}} beyond melee range"] = true

L["%s {{!is|is not}} currently casting"] = true
L["%s {{!is|is not}} currently channeling"] = true

L["%s {{!is|is not}} currently casting %s"] = true
L["{unit} {{!is|is not}} currently casting {spell}"] = true
L["{unit} {{!is|is not}} currently channeling {spell}"] = true

L["%s {{!is|is not}} immune to %s"] = true

L["%s {{!is|is not}} in a %s role"] = true

L["%s {{!is|is not}} in combat"] = true

L["%s {{!is|is not}} in range"] = true

L["%s {{!is|is not}} sometimes immune to %s"] = true

L["%s {{!will|will not}} run"] = true

L["%s's channeled spell {{!is|is not}} interruptable"] = true

L["%s's spell {{!is|is not}} interruptable"] = true



L["You {{!know|do not know}} %s"] = true

L["Your %s weapon {{!is|is not}} enchanted"] = true

L["Your pet {{!knows|does not know}} %s"] = true

L["Your talent {{!is|is not}} a %s role"] = true

L["is not evenly divisible by"] = true

L["is not greater than"] = true

L["is not greater than or equal to"] = true

L["is not less than"] = true

L["is not less than or equal to"] = true

L["not (%s)"] = true


L["you {{!are|are not}} at least %s on %s"] = true

L["you {{!are|are not}} in %s form"] = true

L["you {{!are|are not}} in a %s instance"] = true

L["you {{!are|are not}} in a group"] = true

L["you {{!are|are not}} in a outdoors"] = true

L["you {{!are|are not}} in a raid"] = true

L["you {{!are|are not}} in control of your character"] = true

L["you {{!are|are not}} moving"] = true

L["you {{!are|are not}} stealthed"] = true

L["you {{!are|are not}} talented in %s"] = true

L["you {{!have|do not have}} %s equipped"] = true

L["you {{!have|do not have}} %s glyph"] = true

L["you {{!have|do not have}} a %s totem active with %s"] = true

L["you {{!have|do not have}} a pet"] = true

L["you {{!have|do not have}} a pet named %s"] = true
L["you {{!have|do not have}} a pet named {name}"] = true

L["your primary talent tree {{!is|is not}} %s"] = true

L["zone {{!is|is not}} a %s zone"] = true

L["{{!in|not in}} %s"] = true
L["{{!in|not in}} {zone}"] = true

L["Time in combat"] = true

L['Type a tag and press Enter, or choose an existing tag. Click a tag to remove it; right-click to choose its color.'] = true
L['Search existing tags and select any number of them. Click a selected tag to remove it; right-click to choose its color.'] = true

L['Decrease priority'] = true
L['Increase priority'] = true

L["Horizontal"] = true

L["Vertical"] = true

L["Lock preview position and size"] = true

L["Preview window opacity"] = true

L["Choose a whole number of upcoming recommendations, from zero (hidden) to five. The preview shows the current priority results, not a full simulation of future cooldowns or combat. Icons start at 64 pixels; resizing scales all icons while preserving their square shape and the window ratio."] = true

L["Arrange preview icons horizontally (default) or vertically. Below the opacity slider, Lock, Direction and Reset share one row."] = true

L["Prevent moving the preview by its title bar or resizing it by its lower-right corner. Unlock this option in General to adjust it again."] = true

L["Adjust the preview background and title bar opacity without fading its icons. At zero only the icons remain, and the hidden frame does not intercept blank-space clicks. Restore opacity in General to access the title bar and resize handle."] = true

L["Immediately return the preview window to the screen center and restore 64-pixel icons without Apply. Other pending settings are preserved."] = true

L["Lock position and size"] = true
L["Open General settings"] = true

L["View Changes"] = true

L["Saved"] = true

L["Unsaved"] = true

L["Pending input"] = true

L["Not inspected"] = true

L["Custom widget has pending input."] = true

L["Selected entry"] = true

L["Compared entry"] = true

L["Use step name"] = true

L["Preview icon size"] = true

L["Add or search tags"] = true

L["Search tags"] = true

L["Click to remove this tag. Right-click to choose its color."] = true

L["Apply updates the draft. Apply the rotation to save it."] = true

L["Edit the description, tags, author, realm, email, website and version. Source citations remain separate from your attribution. Apply updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values."] = true

L["Fields"] = true
L['Search...'] = true
L['Add'] = true


L['Use All, Built In or Custom to choose the condition source, then filter by Switch, Other or a named category. Search above these controls narrows the visible list without changing assignments.'] = true
L['Open Manage categories below the list for category maintenance. Manage conditions returns to individual condition settings.'] = true
L['Below the condition list, Import/Export opens the selected custom definition for transfer and code review; it is disabled for built-in conditions. In Manage categories, transfer a category’s ordered condition identifiers. Named categories and Other are exclusive destinations. Switch membership is independent.'] = true

L['Comparison limit'] = true
L['Showing the first 512 conditions per side.'] = true

L['Weapon'] = true
L['Location'] = true
L['Book'] = true
L['Question'] = true
L['Swords'] = true
L['Shield'] = true
L['Healing'] = true
L['Lightning'] = true
L['Fire'] = true
L['Nature'] = true
L['Potions'] = true
L['Food'] = true
L['Armor'] = true
L['Groups'] = true
L['Group'] = true

L['Automatic'] = true
L['Built In syntax highlighting'] = true
L['Plain text'] = true
L['Integrations'] = true
L['Lua editor'] = true
L['Editor'] = true
L['Unavailable'] = true
L['Choose optional addon integrations.'] = true
L['Automatic uses an available editor integration, with built-in syntax highlighting as its fallback. Plain text disables highlighting. Apply changes the editor used the next time you open a custom condition.'] = true
L['Optional addons'] = true
L['Loaded; editor integration not connected.'] = true
L['Not loaded.'] = true
L['These addons are optional. Only connected editor providers appear in the Editor menu. Choosing an unavailable or failing editor falls back to the built-in editor.'] = true
L['Choose the editor for custom Lua conditions. Built In syntax highlighting and Plain text work without another addon. Automatic uses a registered optional provider when available and falls back safely. Apply saves the choice; an open editor keeps its current provider until reopened. LuaWorkbench and WowLua loading status is shown separately from integration availability.'] = true

L["Invalid condition: %s"] = true

L["Unavailable condition: %s"] = true
L["This condition definition is disabled. Rotations using it are unavailable."] = true
L["Availability"] = true

-- Native authoring and tag controls
L['Edit fields'] = true
L['Advanced'] = true
L['Number'] = true
L['Boolean'] = true
L['Condition list'] = true
L['Record / map'] = true
L['Allowed types / list alternatives'] = true
L['Invalid field schema: %s'] = true
L['Back'] = true
L['Named fields. Choose a type, then edit its children for nested data.'] = true
L['Allowed types. A nested record or type list describes each item in a list.'] = true
L['Showing the first 200 fields. Use Advanced schema for larger definitions.'] = true
L['Add field'] = true
L['Tag color'] = true
L['Type a tag and press Enter, or choose an existing tag. Click a tag to remove it; use the search results to change tag colors.'] = true
L['Search existing tags and select any number of them. Click a selected tag to remove it; use the search results to change tag colors.'] = true
L['Click to remove this tag. Use the search results to change tag colors.'] = true

L['Each callback keeps its own pending text while switching tabs. Undo and Redo edit that callback buffer. Reset restores its last saved code, or the template for a new condition, and can be undone. The main Apply saves and registers all callback buffers and metadata; Discard drops the whole draft. Leaving with changes offers Apply, Discard or Cancel. Check syntax runs no callbacks.'] = true
L['No native Lua editor has been opened this session.'] = true
L['Lua input diagnostics'] = true
L['Native input test'] = true
L['Input test'] = true
L['Stock font'] = true
L['RM font'] = true
L['Click the sample, then try Up/Down and look for the caret. Compare Stock font and RM font. This temporary text is not saved.'] = true
L['Diagnostics'] = true
L['Arrow test'] = true
L['Arrows: on'] = true
L['Arrows'] = true
L['Info'] = true
L['Show input diagnostics for this open Lua editor.'] = true
L['Temporary native arrow test enabled. Click to restore the editor hook.'] = true
L['Temporarily remove the editor arrow hook to test native navigation.'] = true
L['Move'] = true
L['Edit fields opens a graphical schema draft. Add, name, reorder or remove fields, choose primitive or nested types, and edit nested fields. Apply stages the schema and its field order. Advanced exposes the equivalent raw schema, parsed as data without executing Lua.'] = true

-- Callback documentation
L['Decide whether this condition currently matches.'] = true
L['The stored values for this condition.'] = true
L['Shared data for this evaluation cycle.'] = true
L['Evaluation start time, in seconds from GetTime().'] = true
L['True matches; false or nil does not match.'] = true
L['Check whether the stored condition values are complete and valid.'] = true
L['Rotation specialization scope.'] = true
L['True when the condition can be evaluated.'] = true
L['Describe the condition in readable words.'] = true
L['The human-readable condition summary.'] = true
L['Build the controls used to edit this condition.'] = true
L['The condition field container supplied by the UI adapter.'] = true
L['Add controls to the supplied container.'] = true
L['Build the help content for this condition.'] = true
L['The help container supplied by the UI adapter.'] = true
L['Add help content to the supplied container.'] = true
L['Initialize resources when the condition is registered.'] = true
L['The condition identifier.'] = true
L['No return value is used.'] = true
L['Release resources when the condition is removed or replaced.'] = true
L['Arguments'] = true
L['Returns'] = true

L['Field names are Lua identifiers. Choose a field type from its dropdown. Records contain named fields; allowed types contain alternatives, including nested records.'] = true
L['A container carries its nested fields. Drop into a highlighted gap. Up / Down moves within the current container; Duplicate copies the complete field; the red trash can deletes it.'] = true
L['The chevron hides or shows nested fields. Add field appends to that container. Undo / Redo affect the draft. Apply validates and stages the schema; Cancel leaves the condition unchanged. Red borders mark invalid names or incomplete types.'] = true

L['Packaged helper from %s.'] = true

L['Functions'] = true
L['Browse packaged helpers and edit reusable custom Lua functions.'] = true
L['Function unavailable: %s'] = true
L['Argument name'] = true
L['Add argument'] = true
L['Add return'] = true
L['Built-in function'] = true
L['Custom function'] = true
L['Delete this function? Existing dependents will become unavailable.'] = true
L['Deletion staged. Apply to remove this function.'] = true
L['Function bindings'] = true
L['Alias'] = true
L['This alias is already in use.'] = true
L['Function'] = true
L['Add binding'] = true
L['Packaged source is read-only. Duplicate it to create an editable custom function.'] = true
L['Arguments become Lua parameters. Bindings expose selected helpers under explicit local aliases. Editing an alias does not rewrite your Lua body.'] = true
L['New function'] = true
L['Describe what this function does.'] = true
L['Add a function or duplicate a packaged helper to edit its source.'] = true

L['LuaWorkbench supplies editing, completion, API knowledge and debugging. Debug runs this buffer explicitly using the test arguments. It does not replace the saved rotation or live callback.']=true
L['Test arguments']=true
L['API knowledge']=true
L['Test arguments must be a Lua table.']=true
L['Connected: embedded editing, completion, API knowledge and debugging.']=true

L['Review the dependency bundle before applying it.'] = true
L['Function bindings (%d)'] = true
L['Aliases are local names in your Lua body. Changing an alias does not rewrite the body.'] = true
L['Reuse existing'] = true
L['Replace existing'] = true
L['Import with new identifier'] = true
L['Create'] = true
L['Review source'] = true
L['Original identifier'] = true
L['Destination identifier'] = true
L['Callback'] = true
L['Include custom function dependencies'] = true
L['Review import'] = true
L['Apply import'] = true
L['Function dependency bundle'] = true
L['Review the complete bundle before applying an import. Imported Lua can execute when registered; only apply code you trust.'] = true
L['Review each original name, destination and dependency below. Apply import saves the complete reviewed bundle.'] = true
L['Conflict action'] = true
L['Imported name'] = true
L['Existing dependents'] = true
L['This imported definition is disabled. Its dependents remain unavailable.'] = true
L['Required functions'] = true
L['Paste a bundle above, then review its original names, destinations and required functions.'] = true

L['Filter Built In or Custom helpers and search their names, identifiers or descriptions. Packaged helpers show read-only source and typed documentation. Duplicate creates an editable copy with a new stable identifier. Argument and return rows document the Lua signature.'] = true
L['Undo and Redo edit the Lua body. Reset restores the saved body or new-function template and can be undone. Check syntax executes no custom Lua. Apply saves the body and metadata together; Discard abandons the draft. Leaving with changes offers Apply, Discard or Cancel.'] = true
L['Expand Function bindings to add explicit helper aliases and choose their targets. Changing an alias does not rewrite your Lua body. Missing, disabled or invalid dependencies keep their dependents unavailable until repaired.'] = true
L['Include custom function dependencies exports their source with the selected definition. Without it, the bundle records required helper identities and versions. Review source shows every imported Lua body. Resolve each original name and destination with Reuse, Replace or a new identifier. Apply import saves the complete reviewed bundle and can register imported Lua. Only apply code you trust.'] = true
L['Check'] = true
L['Live'] = true
L['Preview'] = true
L['The preview failed. Use /rm errors for details.'] = true
L['Test values were not saved because they are not bounded plain data.'] = true
L['Condition check'] = true
L['Fields UI preview'] = true
L['Help preview'] = true
L['Edit detached test values below. Check validates them before evaluating. Live is opt-in; test values are saved separately from the condition source.'] = true
L['Preview runs only this callback with detached sample values. It does not save or register the condition.'] = true
L['Complete the source fields before checking.'] = true
L['Check could not compile the current source. Fix the source before checking again.'] = true
L['Skipped: invalid test values'] = true
L['Validation: %s'] = true
L['Passed'] = true
L['Evaluation: %s'] = true
L['Fields UI and Help offer an explicit Preview of the current callback. Preview uses detached sample values and the normal field or help renderer. It does not save, register, validate or evaluate the condition. Closing it releases its controls and returns to the source draft. Check syntax never runs a callback.'] = true
L['Evaluate and Validate offer Check with the same Fields UI and detached sample values. Check runs validation first, then evaluates only valid values. Results show true, false or an unavailable reason. Live is opt-in and checks at most twice per second while this panel is shown; closing stops it. Test values are saved separately and never enter condition exports or rotation edits. Source changes run no callbacks unless you check again or enable Live.'] = true
L['Functions reference'] = true
L['The Functions page documents public helpers and their typed arguments, return values and source. Context completion and hover use that reference; Ctrl-click a known helper to open its source. Use explicit binding aliases for reusable custom helpers.'] = true

L["The imported definition type does not match this editor."] = true

L['Test values changed. Check again to refresh the result.'] = true
L['Complete the highlighted test inputs before checking.'] = true

L['Test'] = true
L['Run test'] = true
L['Test condition'] = true
L['Debugger output'] = true
L['Set test values in Test before debugging Evaluate.'] = true
L['Debugger output uses a detached sample and the normal field or help container.'] = true
L['Choose test values in Fields UI, then Run test to validate and evaluate. Help is shown below the fields. Opening Test does not evaluate defaults. Live is opt-in.'] = true
L['Test opens one condition-level dialog from any callback tab. It renders Fields UI and Help together with detached values. Choose the fields and Run test to validate, then evaluate only valid values. Opening the dialog does not evaluate defaults. Live is opt-in and stops when the dialog closes. Committed test values are available to the debugger and stay separate from source, exports and rotation edits. Check syntax never runs a callback.'] = true

L['Nullable'] = true
L['Add return value'] = true
L['Lua returns multiple values in order. Each row documents one result.'] = true
L['Expand code editor'] = true
L['Restore code editor'] = true
L['Choose a source helper and the local name used to call it in this Lua body. Renaming the local name does not rewrite code. Source modules distinguish helpers with the same name.'] = true
L['Local name in code'] = true
L['Source helper'] = true
L['Function names use letters, numbers and underscores, beginning with a letter or underscore. Names suggest the local binding used to call them; registry identifiers stay stable.'] = true


L['This cannot be undone.'] = true
L['Delete this announcement?'] = true

L["Type: %s"] = true
L["Supported unit-token to localized unit-name lookup. Use value.unit as a key; for example addon.units[value.unit]. Available tokens vary by client."] = true
L["Supported unit-token to localized possessive unit-name lookup, such as your target."] = true
L["Rotation Master client compatibility adapter. Its methods return ordinary readable results or nil with a reason when an observation is unavailable. Use a colon call, or pass addon.Platform explicitly as self with a dot reference."] = true
L["Rotation Master spell catalog for resolving client-specific spell IDs, ranks, names, icons and links."] = true
L["Utility functions explicitly bound to this condition or function. Choose a completion to bind an available custom function before inserting its reference."] = true
L["Rotation Master custom function"] = true
L["Rotation Master built-in function"] = true
L["Rotation Master value"] = true
L["Global function (documentation unavailable on this client)"] = true
L["This client does not provide signature documentation for this function. No arguments or return types have been inferred."] = true
L["Invoke"] = true
L["Functions are shared across profiles after Apply. Call custom utilities as functions.name(...); accepting completion adds the dependency binding. Typed calls need a binding under Function bindings. Built In examples show dot or colon explicitly."] = true
L["Show line numbers"] = true
L["Line-number visibility applies to every condition and function code editor."] = true
L["Call a saved custom utility as functions.name(...). Accepting a completion attaches its stable dependency binding; for a typed call, choose its helper under Function bindings. Existing direct aliases still work. The Invoke example shows required addon dot or colon syntax for Built In functions. Renaming an alias does not rewrite source. Missing, disabled or invalid dependencies keep consumers unavailable."] = true
L["Choose the editor for custom Lua conditions and functions. Show line numbers applies across code editors. Built In syntax highlighting and Plain text work without another addon. Automatic selects a connected provider or falls back safely. Apply saves settings; editor changes take effect on reopening, and line-number visibility updates open editors. LuaWorkbench and WowLua loading status is shown separately from integration availability."] = true

L['All namespaces'] = true
L['Call a utility as namespace.name(...). Built In namespaces follow source files; custom functions choose their Namespace. Accepting a completion attaches its stable dependency binding; for a typed call, add its qualified name under Function bindings. Namespaces do not supply self: the Invoke example includes a method receiver explicitly, and Existing API preserves its original dot or colon spelling. Existing aliases still work. Renaming a function or namespace does not rewrite existing code or bindings. Missing, disabled or invalid dependencies keep consumers unavailable.'] = true
L['Choose a source helper and its name in this Lua body, such as custom.ready or utils.getCached. Namespaces are private to this callback. Renaming a binding does not rewrite code.'] = true
L['Debug current buffer'] = true
L['Debugger terminal'] = true
L['Existing API'] = true
L['Name in code'] = true
L['Namespace'] = true
L['Namespaces group functions; they do not supply a receiver. Accept a completion to bind the shown dotted call. For a typed call, add the same qualified name under Function bindings. Method examples include the required receiver explicitly. Functions are shared across profiles after Apply.'] = true
L['Play runs the current buffer once without debugging. Condition callbacks use the fields configured in Test; functions use Test arguments. Returns, printed output and full errors are available in Output. Running does not apply source changes or replace the live callback.'] = true
L['Private utility-function namespace. It contains only explicit bindings for this callback.'] = true
L['Run current buffer'] = true
L['The Debug button starts a separate session and pauses at the first executable line or breakpoint. Continue resumes execution, Step over advances past the current operation, and Step into enters instrumented script functions. Native functions cannot be stepped into. Stop ends the session. F5 continues, F10 steps over, F11 steps into, and Shift+F5 stops.'] = true
L['The debugger terminal appears below the code while debugging. When paused, enter expressions or assignments to inspect or change the current variables. The drawer button hides or shows the terminal. Output provides a copyable report of printed output, terminal evaluations and complete errors.'] = true

L['Argument'] = true
L['Arguments and returns'] = true
L['Bindings (%d)'] = true
L['Call a utility as namespace.name(...). Built In namespaces follow source files; custom functions choose their Namespace. Accepting a completion attaches its stable dependency binding; for a typed call, add its qualified name under Function bindings. Namespaces do not supply self. Pass a method receiver explicitly in a namespaced dot call; object:method(x) is Lua shorthand for object.method(object, x). Existing addon APIs remain compatible with saved definitions. Existing aliases still work. Renaming a function or namespace does not rewrite existing code or bindings. Missing, disabled or invalid dependencies keep consumers unavailable.'] = true
L['Changing argument or return order can break existing callers. Rotation Master will not rewrite their Lua code. Continue?'] = true
L['Choose an existing namespace from the suggestions or type a new dotted namespace. Built In namespaces follow source files; custom namespaces are implied by saved functions and need no separate maintenance.'] = true
L['Click an Arguments or Returns heading to collapse or expand it. + Argument and + Return append when clicked, or insert at a highlighted gap when dragged. Drag a row or use Up / Down to reorder; Ctrl-drag carries following rows. The trash can removes a row. Type and Nullable document accepted values; Description explains each input or result. Lua can return several ordered results. Reordering a saved function warns because positional callers may need changes; RM does not rewrite call sites.'] = true
L['Function names use letters, numbers and underscores, beginning with a letter or underscore. The code signature shows the qualified namespace.name used by callers.'] = true
L['Return'] = true
L['Search helpers by name or description, then filter Built In / Custom and namespace. Packaged helpers use the same read-only pane. Duplicate creates an editable custom copy.'] = true

L['Changing argument order can break existing callers. Rotation Master will not rewrite their Lua code. Continue?'] = true
L['Changing return documentation order does not rewrite return statements or existing callers. Review the Lua body and callers for the new order. Continue?'] = true
L['Click an Arguments or Returns heading to collapse or expand it. + Argument and + Return append when clicked, or insert at a highlighted gap when dragged. Drag a row or use Up / Down to reorder; Ctrl-drag carries following rows. The trash can removes a row. Type and Nullable document accepted values; Description explains each input or result. Lua can return several ordered results. Return rows describe those results; moving them does not rewrite return statements. Reordering a saved function warns because positional callers may need changes; RM does not rewrite call sites.'] = true

L['Card controls'] = true
L['Describe this value for function documentation, completion and hover help. Changes remain in the draft until Apply.'] = true
L['Drag a card to reorder arguments; Ctrl-drag includes following arguments. Up and down move one position. Duplicate copies the argument with a unique name; the trash can removes it. Reordering a saved function requires confirmation because existing callers are not rewritten.'] = true
L['Drag a card to reorder return documentation; Ctrl-drag includes following returns. Up and down move one position. Duplicate copies the documented return value; the trash can removes it. Return order in this list does not rewrite return statements or callers.'] = true
L['Preview rendered. Use Output for printed messages.'] = true
L['Rendered output appears here when the callback runs or steps through widget creation.'] = true
L['Set values in Test before running or debugging this condition.'] = true
L['The argument name is the local parameter available in the Lua body. Use a valid Lua identifier. Renaming this documentation does not rewrite references in the code.'] = true
L['Type and Nullable describe the values accepted or returned by this function. They document the contract; they do not rewrite or validate values in the Lua body.'] = true

-- Whole-field General help; each paragraph can be translated independently.
L["Help.General.enable"] = "Enable Rotation Master recommendations, automatic rotation switching and bound item-set updates. Disabling clears active advice and highlights and hides the preview. Apply saves the change."
L["Help.General.poll"] = "Set how often Rotation Master reevaluates the active rotation and independent cooldowns, in seconds. A shorter interval updates advice more often and uses more processing time. It does not cast spells, queue actions, or predict future combat."
L["Help.General.idle_poll"] = "Out of combat with no target and no focus, Rotation Master skips a polling tick unless something it watches has changed: auras, cooldowns, health or power of you, your pet or party, movement, casting, equipment, bags, form, pets or group. It still re-checks at least this often, for time-based conditions (aura or cooldown remaining), distance, and custom code. In combat, with any target or focus, or while configuration is open, every polling tick is evaluated. Zero evaluates every polling tick."
L["Help.General.autoswitch_poll"] = "With automatic switching, Rotation Master checks this often, in and out of combat, whether a different rotation's switch conditions now match, so conditions that change on their own (nearby enemy count, threat, movement, health) take effect. Target, focus and pet changes are checked straight away. Zero turns automatic switching off. Choosing a rotation manually still overrides automatic switching until you choose Auto again."
L["Help.General.disable_autoswitch"] = "Keep Rotation Master from automatically selecting another rotation from its switch condition. This preference survives reloads. Manually choosing a rotation with /rm set <rotation> also suspends automatic switching until you choose automatic selection again."
L["Help.General.disable_buttons"] = "Hide the main rotation recommendation on action bars. Independent cooldown highlights remain available. Enable Preview Spells if you want to see the main advice in a separate window; with both displays off, the main recommendation has no visible icon."
L["Help.General.live_config_update"] = "How often, in seconds, the rotation editor checks each card's condition for its live dot: green when it is satisfied for you right now, red when it is not, grey when it cannot be read at the moment (hover a dot for why and when it was checked). Conditions are checked only while the editor is open; zero turns the dots off. This is separate from the recommendation polling interval."
L["Help.General.minimap"] = "Show the Rotation Master minimap icon. Left-click toggles the configuration window. Right-click opens the quick menu for enabling recommendations and choosing a rotation or automatic switching."
L["Help.General.rotation_view"] = "Choose Diagram or List as the starting rotation view. This profile preference applies when opening a rotation; changing the view inside the editor does not change this setting. Cooldowns always use a scrolling grid."
L["Help.General.spell_history"] = "Choose how many seconds of previous spell casts to retain for history-based conditions. Older casts are removed as recommendations update. A longer history retains more records."
L["Help.General.combat_history"] = "Choose how many seconds of combat events to retain for conditions such as recent hits, parries and blocks. Older events are removed as recommendations update. Availability depends on the client combat-data policy."
L["Help.General.damage_history"] = "Choose how many seconds of observed damage and healing to retain for burn-rate and time-to-die estimates. Recent observations receive more weight. A longer window uses more records and smooths short changes; it cannot supply events the client does not expose."
L["Help.General.preview_spells"] = "Choose a whole number of upcoming recommendations, from zero (hidden) to five. This is the only switch for the preview window: it is shown whenever this is above zero and hidden at zero, and the window has no close button. The preview shows current priority results, not a simulation of future cooldowns or combat. Icons start at 64 pixels; resizing scales all icons while preserving their square shape and the window ratio."
L["Help.General.preview_opacity"] = "Adjust the preview background opacity without fading its icons. At zero only the icons remain, the hidden background does not intercept blank-space clicks and the resize grip is unavailable; an unlocked preview can still be dragged by its icons. Restore opacity in General to resize it."
L["Help.General.preview_locked"] = "Unlocked, drag the preview by any icon or its background to move it, and resize it from the grip that appears at its lower-right corner on hover. Locked, it cannot be moved or resized and its background lets clicks through. Right-click an icon (or the background while unlocked) for a menu to lock, unlock or open these settings. Locking and unlocking take effect immediately and are saved without Apply. Other pending General edits remain unchanged."
L["Help.General.preview_vertical"] = "Arrange preview icons horizontally (default) or vertically. Lock, Direction and Reset share one row below the opacity slider. Changing direction keeps icons square and adjusts the window ratio."
L["Help.General.preview_reset"] = "Immediately return the preview window to the screen center and restore 64-pixel icons without Apply. Other pending settings are preserved."
L["Help.General.preview"] = "This icon previews the selected profile effect, color, size, anchor and offsets. Previewing an effect does not save the draft or change the spell being recommended."
L["Help.General.effect"] = "Choose the highlight used for the main recommendation and as the default for independent cooldowns. Manage available effects on the Effects page. A cooldown can override these profile settings in its action details."
L["Help.General.magnification"] = "Scale the highlight relative to its action icon. A value of 1 uses the icon size. Drag the slider or type its numeric value; the preview updates as you edit."
L["Help.General.color"] = "Choose the highlight color and opacity. Click the color swatch to open the picker, or enter R, G, B and A values between 0 and 1. Alpha controls opacity; individual cooldowns may override this profile color."
L["Help.General.setpoint"] = "Choose the point on the action icon where a texture highlight is anchored by its center. Changing Anchor resets the offsets. The preview shows the resulting placement; non-texture glows may use offsets without a texture anchor."
L["Help.General.yoffs"] = "Vertical offset in pixels. Use Up or Down on the position control, or edit V directly. Hold Shift while using an arrow for ten pixels. Center resets both offsets and the anchor to Center."
L["Help.General.xoffs"] = "Horizontal offset in pixels. Use Left or Right on the position control, or edit H directly. Hold Shift while using an arrow for ten pixels. Non-texture glows interpret offsets according to their effect shape."
L["Help.General.spec1"] = "Choose the display name for your primary specialization. This changes its label in Rotation Master, not your character talents or specialization."
L["Help.General.spec2"] = "Choose the display name for your secondary specialization. This changes its label in Rotation Master, not your character talents or specialization."
L["Help.General.loglevel"] = "Choose the amount of Rotation Master chat output. Silent suppresses routine output. Default reports normal changes such as rotation switching. Debug adds runtime statistics and trigger information. Verbose includes detailed condition and highlight activity and can produce substantial output."
L["Help.General.detailed_profiling"] = "Include component timings in the periodic Debug or Verbose profiling report. Reports show measured runs, total, minimum, average and maximum in milliseconds. Timings include child work; nested scopes overlap and must not be added together. The overall scope starts after rotation preparation. This is elapsed timing, not the native addon CPU report."

-- Complete Effects field and interaction documentation.
L["Help.Effects.overview"] = "Effects define how action-bar icons are highlighted. They are shared across characters. General settings select the main recommendation effect and cooldown default; individual cooldowns can choose another effect. Select an effect in the sidebar to inspect or edit it."
L["Help.Effects.name"] = "Give the effect a name used by selectors in General and cooldown action details. New drafts can change type and fields before being named, but Apply requires a nonempty, unique name."
L["Help.Effects.type"] = "Choose the highlight implementation. Changing type stages the new fields and resets its sequence because different sequence types store different values. Choosing the current type preserves existing values. Apply saves the change; Discard restores the saved effect."
L["Help.Effects.type.texture"] = "Texture: overlay a single image from game data or an installed addon. Its color, magnification and position come from the profile or the individual cooldown."
L["Help.Effects.type.pixel"] = "Pixel: animate short lines around the action icon border. Lines, Frequency, Length and Thickness control this library glow."
L["Help.Effects.type.autocast"] = "Auto Cast: animate groups of glowing particles around the action icon. Particles, Frequency and Scale control this library glow."
L["Help.Effects.type.blizzard"] = "Glow: use the familiar Blizzard-style button glow. Frequency controls its animation rate."
L["Help.Effects.type.dazzle"] = "Dazzle: keep one texture and cycle through the sequence of colors. Each sequence card contains one RGBA color."
L["Help.Effects.type.animate"] = "Animate: cycle through the sequence of texture images. Each card selects one image and previews that selection."
L["Help.Effects.type.pulse"] = "Pulse: keep one texture and cycle through the sequence of magnifications. Each card selects one scale relative to the action icon."
L["Help.Effects.type.rotate"] = "Rotate: animate one texture through evenly spaced angles around a full circle. Steps chooses the number of angles and Reverse changes their order."
L["Help.Effects.type.custom"] = "Custom: cycle through cards containing a texture, angle, magnification and color. Each card supplies its own settings instead of relying on one shared texture."
L["Help.Effects.preview"] = "The image beside Name and Type previews the current draft with a white color and standard size. Texture and sequence changes update the preview without saving. Actual recommendations use their profile or cooldown color, size and offsets."
L["Help.Effects.texture"] = "For Texture, Dazzle, Pulse and Rotate, choose the image used throughout the effect. The arrow beside an image field opens the bundled overlay catalog with previews. Enter an available texture path or numeric file ID to use another image. Animate and Custom choose images in their sequence cards using the same controls. Selections update the draft and preview; Apply saves them."
L["Help.Effects.pixel.lines"] = "Pixel effects: choose the number of animated lines around the button, from 1 to 20."
L["Help.Effects.pixel.frequency"] = "Pixel effects: signed cycles per second. A larger magnitude moves faster; a negative value reverses direction. Zero uses the glow library default of one cycle every four seconds."
L["Help.Effects.pixel.length"] = "Pixel effects: choose line length in pixels. The glow library limits it to the smaller button dimension."
L["Help.Effects.pixel.thickness"] = "Pixel effects: choose line thickness in pixels, from 1 to 5."
L["Help.Effects.autocast.particles"] = "Auto Cast effects: choose 1 to 4 particles in each of the glow library particle groups."
L["Help.Effects.autocast.frequency"] = "Auto Cast effects: signed cycles per second. A larger magnitude moves faster; a negative value reverses direction. Zero uses the glow library default of one cycle every eight seconds."
L["Help.Effects.autocast.scale"] = "Auto Cast effects: scale the particles relative to the glow library default. A value of 1 uses their normal size."
L["Help.Effects.blizzard.frequency"] = "Glow effects: adjust the library animation rate. Larger positive values animate faster. Zero uses the library default rather than stopping the glow."
L["Help.Effects.dazzle.frequency"] = "Dazzle effects: seconds between color cards. A smaller positive interval changes colors more often; the sequence repeats after the last color."
L["Help.Effects.animate.frequency"] = "Animate effects: seconds between texture cards. A smaller positive interval changes images more often; the sequence repeats after the last image."
L["Help.Effects.pulse.frequency"] = "Pulse effects: seconds between magnification cards. A smaller positive interval changes size more often; the sequence repeats after the last size."
L["Help.Effects.rotate.frequency"] = "Rotate effects: seconds between angle steps. A smaller positive interval rotates faster. One full cycle uses this interval multiplied by Steps."
L["Help.Effects.rotate.steps"] = "Rotate effects: choose 2 to 36 evenly spaced angles for a full turn. More steps at the same Frequency interval make a longer complete cycle."
L["Help.Effects.rotate.reverse"] = "Rotate effects: reverse the order of angle steps. Changing this checkbox does not alter the texture or number of steps."
L["Help.Effects.custom.frequency"] = "Custom effects: seconds between sequence cards. A smaller positive interval changes settings more often; the sequence repeats after the last card."
L["Help.Effects.sequence"] = "Sequence cards play in order and repeat. Add step, on the Sequence header row, appends a card; drag Add step into a gap to insert one there. Drag a card into an insertion gap to reorder it; hold Ctrl when starting to carry it and all following cards. Up and Down move one card and are disabled at their respective ends. The red trash removes a card from the draft. Canceling a drag restores its original position."
L["Help.Effects.sequence.texture"] = "Animate and Custom cards: choose a texture path or numeric file ID. The card preview shows the selected image. Custom also keeps an independent angle, magnification and color on that card."
L["Help.Effects.sequence.angle"] = "Custom cards: set the texture angle in degrees from 0 to 359. This is the angle for this card, rather than a continuous rotation speed."
L["Help.Effects.sequence.magnification"] = "Pulse and Custom cards: scale the texture relative to the action icon. A value of 1 uses the icon size. Use the slider or edit its numeric value."
L["Help.Effects.sequence.color"] = "Dazzle and Custom cards: choose an RGBA color. Click the swatch to open the picker, or edit channels between 0 and 1. Alpha controls opacity."
L["Help.Effects.save"] = "Edits and sequence changes remain in a draft. Apply saves; Discard restores the saved effect. Cancel closes a new creation draft. View Changes compares saved and unsaved values. New drafts require a unique name and valid fields before Apply. Leaving with edits offers Apply, Discard or Cancel."
L["Help.Effects.delete"] = "The red trash at the upper right deletes the selected effect after a permanent-deletion warning. Resolve pending edits first. Choose a replacement for any profile or cooldown using that effect; deletion does not silently rewrite those references."
L["Help.Effects.collections"] = "New, Duplicate, Import/Export and Compare are below the sidebar. Duplicate copies the selected effect into a draft. Transfers show the original name and let you create a renamed copy or replace the selection when allowed. Compare inspects differences without saving them."

L["Debuffs"] = true
L["Resources"] = true
L["Pet"] = true
L["Logic"] = true
L["Environment"] = true
L["Time"] = true

L["Spell Auto-Repeat Active"] = true
L["%s {{!is|is not}} auto-repeating"] = true
L["Tests whether the selected spell is currently auto-repeating, such as Shoot or Auto Shot. This is different from a spell being current or queued: a queued cast alone does not satisfy this condition. Unavailable client observations remain unavailable even when negated."] = true

L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."] = true

L["Default.TBC.Paladin.Retribution.Wowhead.Name"] = "Paladin: Retribution (Wowhead & wowsims)"
L["Default.TBC.Paladin.Retribution.Wowhead.Description"] = "Melee Retribution from level 1 to 70, and the default for any Paladin no other premade fits. Opens each target with Judgement of Wisdom (low mana) or the Crusader, keeps your best seal up (Blood or Martyr, Command, then Righteousness), Crusader Strike, judges only Righteousness, Blood or Martyr (or Command on a stunned target), Exorcism on Undead and Demons, Consecration for three or more enemies with mana to spare. Hammer of Wrath is left to you (Wowhead uses it only on fleeing targets). Reminders: Sanctity, Retribution or Devotion Aura, a Blessing on yourself, a heal after the fight, Avenging Wrath. Seal twisting is a separate premade."
L["Default.TBC.Paladin.Retribution.IcyVeins.Name"] = "Paladin: Retribution (Icy Veins)"
L["Default.TBC.Paladin.Retribution.IcyVeins.Description"] = "Icy Veins' Retribution, an alternative to the recommended Wowhead Retribution premade, off by default: enable it and disable that one, or raise its priority. Judgement of the Crusader once per target, Seal of Righteousness (Command only with a slow weapon, Blood or Martyr once learned), Crusader Strike, Hammer of Wrath and Judgement on cooldown, Consecration on two or more enemies, Exorcism on Undead and Demons, and Holy Shock for Holy levelers. Same reminders as the Wowhead variant."
L["Default.TBC.Paladin.Retribution.Twist.Name"] = "Paladin: Retribution seal twisting"
L["Default.TBC.Paladin.Retribution.Twist.Description"] = "Off by default; enable it if you twist seals (level 64+, Seal of Command and Blood or Martyr). Opens with Judgement of the Crusader, then each swing puts up Seal of Command (rank 1) early and switches to Blood or Martyr in the last 0.4 seconds, Crusader Strike between twists, judges only Blood or Martyr, Exorcism and Consecration only as fillers, and rolls Blood without twisting below 12% mana. Needs a reliable swing timer; latency is not accounted for."
L["Default.TBC.Paladin.Protection.Wowhead.Name"] = "Paladin: Protection (Wowhead & wowsims)"
L["Default.TBC.Paladin.Protection.Wowhead.Description"] = "Tanking for the Protection tree or any Paladin with Righteous Fury on. Pulls with Holy Shield, Avenger's Shield and Judgement; against a crushing target (world boss or three or more levels above you) Holy Shield comes first; then Consecration, Exorcism on Undead and Demons, Judgement, Holy Shield, Holy Wrath on undead packs, Avenger's Shield except on crushing targets. Seal of Wisdom on packs when mana is short, Righteousness otherwise. Reminders: Righteous Fury, Devotion Aura, Sanctuary (or Kings, or Wisdom), Avenging Wrath, Lay on Hands. Taunts and target swaps stay with you."
L["Default.TBC.Paladin.Protection.IcyVeins.Name"] = "Paladin: Protection (Icy Veins)"
L["Default.TBC.Paladin.Protection.IcyVeins.Description"] = "Icy Veins' tanking, an alternative to the recommended Wowhead Protection premade, off by default: enable it and disable that one, or raise its priority. Judgement of the Crusader when nobody keeps it up, Righteousness (Wisdom on packs), Consecration as the main threat, Judgement, Holy Shield, then Avenger's Shield and Hammer of Wrath on cooldown. Same reminders as the Wowhead variant without Avenging Wrath."
L["Default.TBC.Paladin.Holy.Name"] = "Paladin: Holy (Icy Veins & Wowhead)"
L["Default.TBC.Paladin.Holy.Description"] = "Healing for a Holy Paladin in a group, on your friendly target: Lay on Hands or Holy Shock for a dying target, Cleanse (Purify before 42), Holy Shock while moving, Holy Light for heavy damage, rank-5 Holy Light to keep Light's Grace up, Flash of Light otherwise. With a hostile target it keeps Judgement of Wisdom up. Reminders: Concentration Aura, Blessing of Wisdom, Divine Illumination and Divine Favor. A soloing Holy Paladin gets a Retribution premade instead."
L["Default.TBC.Paladin.Holy.Wowhead.Name"] = "Paladin: Holy (Wowhead tank healing)"
L["Default.TBC.Paladin.Holy.Wowhead.Description"] = "Wowhead's raid tank healing, an alternative to the recommended Holy premade, off by default: enable it and disable that one, or raise its priority. Holy Light whenever your target is missing a tenth of their health, Flash of Light only for small deficits, with the same emergencies, cleansing, Judgement and reminders as the blended Holy premade."

L["Default.TBC.Hunter.Ranged.Wowsims.Name"] = "Hunter: ranged DPS (wowsims)"
L["Default.TBC.Hunter.Ranged.Wowsims.Description"] = "Levels 1–70, every spec. Pulls with Hunter's Mark, Aimed Shot and Auto Shot, keeps Auto Shot running and uses melee strikes when a target reaches you. Before Steady Shot it keeps your Serpent Sting up and spends mana on Aimed, Multi and Arcane Shot only while you have plenty. From level 62: Multi-Shot when ready, Steady Shot straight after each Auto Shot, Arcane Shot to fill the gap, Serpent Sting when solo. With three or more enemies fighting you, Multi-Shot whenever it is ready. Reminds you of aspects (Viper when mana runs low, Hawk again at half mana), pet care, Kill Command, major cooldowns on elites and bosses and Silencing Shot. Pet commands, Misdirection, traps, Volley, melee weaving and Feign Death stay with you."
L["Default.TBC.Hunter.Ranged.Wowhead.Name"] = "Hunter: ranged DPS (Wowhead)"
L["Default.TBC.Hunter.Ranged.Wowhead.Description"] = "Levels 1–70, every spec, following Wowhead's raid advice. Same pull, melee, leveling shots, multi-target Multi-Shot and reminders as the wowsims version, but once Steady Shot is learned it only offers Multi-Shot and Steady Shot after each Auto Shot: no Arcane Shot filler (except while moving), no Serpent Sting and no Aspect of the Viper reminder. Pet commands, Misdirection, traps, Volley, melee weaving and Feign Death stay with you. An alternative to the recommended wowsims ranged premade, off by default: enable it and disable that one, or raise its priority."

L["Default.TBC.Rogue.DPS.Wowsims.Name"] = "Rogue: melee DPS (wowsims)"
L["Default.TBC.Rogue.DPS.Wowsims.Description"] = "Levels 1–70, every spec. From stealth: Premeditation, then Cheap Shot solo or Garrote in a group, otherwise Ambush (with a dagger in the main hand). In combat: Riposte, Slice and Dice from two combo points (renewed in its last two seconds), Eviscerate on a target about to die, and at five points Rupture when it will last (not while Blade Flurry cleaves), otherwise Eviscerate. Builds with Mutilate or Backstab (dagger) when the target is not attacking you, otherwise Hemorrhage or Sinister Strike. Reminds you of missing poisons, Kick, Blade Flurry and Adrenaline Rush, Cold Blood and Evasion. Expose Armor, Kidney Shot, Feint, Vanish and positioning stay with you."
L["Default.TBC.Rogue.DPS.Wowhead.Name"] = "Rogue: melee DPS (Wowhead)"
L["Default.TBC.Rogue.DPS.Wowhead.Description"] = "Levels 1–70, every spec, following Wowhead. Same stealth openers, builders and reminders as the wowsims version, but Slice and Dice starts from one combo point and every five-point finisher is Eviscerate: no Rupture. Expose Armor, Kidney Shot, Feint, Vanish and positioning stay with you. An alternative to the recommended wowsims melee DPS premade, off by default: enable it and disable that one, or raise its priority."
L["Default.TBC.Druid.Balance.Name"] = "Druid: Balance"
L["Default.TBC.Druid.Balance.Description"] = "Caster Balance from level 1 to 70, and the default for any Druid no other premade fits. Pulls with Starfire (Wrath before 20), Insect Swarm and Moonfire while moving, Faerie Fire in a group, Hurricane for three or more enemies, Moonfire when it has run out and you have 30% mana, Starfire on Nature's Grace, Wrath against a target in melee, then Starfire (Wrath before it is learned). No advice in Cat, Bear or travel forms. Reminders: Mark of the Wild, Thorns while solo, Omen of Clarity, Moonkin Form, Force of Nature on a long fight, Innervate when low."
L["Default.TBC.Druid.Feral.IcyVeins.Name"] = "Druid: Feral (Icy Veins, Warcraft Tavern & wowsims)"
L["Default.TBC.Druid.Feral.IcyVeins.Description"] = "Cat and bear for the Feral tree, following your form. Cat: stealth opener (Pounce, Ravage or Shred), Faerie Fire (Feral), Rip at four combo points on a target that lives, Ferocious Bite between Rips without Clearcasting, Mangle kept up, Shred from behind or Mangle/Claw when the target is on you. Bear: Faerie Fire, Lacerate saved before it drops, Demoralizing Roar unless a warrior's Shout is up, Swipe for packs, Mangle, five Lacerates, Swipe. In caster form it suggests Cat (or Bear) Form. Reminders: Mark, Thorns, Omen, Maul with spare rage, Tiger's Fury before a pull, Frenzied Regeneration. Powershifting is an optional step that starts off (it needs a powershift macro)."
L["Default.TBC.Druid.Feral.Wowhead.Name"] = "Druid: Feral (Wowhead)"
L["Default.TBC.Druid.Feral.Wowhead.Description"] = "Wowhead's Feral, an alternative to the recommended Icy Veins Feral premade, off by default: enable it and disable that one, or raise its priority. Rip whenever it is down at four combo points and Ferocious Bite only on a target about to die (no bite-weaving); bears spend free global cooldowns on Lacerate before Swipe. Innervate when a cat runs low on mana. Otherwise the same as the Icy Veins variant."
L["Default.TBC.Druid.Restoration.Name"] = "Druid: Restoration"
L["Default.TBC.Druid.Restoration.Description"] = "Healing for the Restoration tree on your friendly target (or yourself): Healing Touch after Nature's Swiftness, Swiftmend a dying target that has your Rejuvenation or Regrowth, three rolling Lifeblooms in combat, Rejuvenation and Regrowth when missing, then Regrowth in Tree of Life or Healing Touch outside it. A hostile target gets Moonfire and Wrath for soloing. Reminders: Mark, Omen, Tree of Life, Nature's Swiftness, Tranquility, Innervate and Rebirth. Choosing whom to heal and downranking stay with you."

L["Default.TBC.Warrior.DPS.Wowsims.Name"] = "Warrior: melee DPS (wowsims)"
L["Default.TBC.Warrior.DPS.Wowsims.Description"] = "Levels 1–70, Arms or Fury. Charges to pull, then Victory Rush, Intercept, Rampage, and Whirlwind when two or more enemies fight you (Thunder Clap before it is learned). With Bloodthirst or Mortal Strike: that strike, Whirlwind with rage to spare, Execute, Overpower. Before them: Whirlwind, Execute, Overpower, Rend. Spare rage goes to Devastate or Sunder Armor, then Hamstring. Reminds you of Battle Shout, Bloodrage, Heroic Strike or Cleave as rage dumps, Sweeping Strikes, Death Wish, Recklessness and interrupts. Slam timing, stance dancing and Berserker Rage stay with you."
L["Default.TBC.Warrior.DPS.IcyVeins.Name"] = "Warrior: melee DPS (Icy Veins)"
L["Default.TBC.Warrior.DPS.IcyVeins.Description"] = "Levels 1–70, Arms or Fury, following Icy Veins. Same pull, reminders and leveling steps as the wowsims version, but with Mortal Strike Execute comes first, with Bloodthirst Execute comes right after it, Whirlwind follows without holding rage, and Hamstring only near full rage. Slam timing, stance dancing and Berserker Rage stay with you. An alternative to the recommended wowsims melee DPS premade, off by default: enable it and disable that one, or raise its priority."
L["Default.TBC.Warrior.Protection.Wowhead.Name"] = "Warrior: tank (Wowhead)"
L["Default.TBC.Warrior.Protection.Wowhead.Description"] = "Levels 10–70, chosen while you are in Defensive Stance. Shield Slam, Revenge, Thunder Clap and Demoralizing Shout kept up on elites and bosses, then Devastate or Sunder Armor. On packs: Thunder Clap and Demoralizing Shout first. Reminds you of Shield Block (with a shield equipped) against bosses and higher-level enemies, Heroic Strike or Cleave, Battle Shout, Bloodrage, Shield Bash and emergency Last Stand and Shield Wall. Taunting and other utility stay with you."
L["Default.TBC.Warrior.Protection.IcyVeins.Name"] = "Warrior: tank (Icy Veins)"
L["Default.TBC.Warrior.Protection.IcyVeins.Description"] = "Levels 10–70, chosen while you are in Defensive Stance, following Icy Veins. Shield Slam, Revenge, then Devastate or Sunder Armor, with Rend at the start of a fight until Shield Slam is learned. On packs: Thunder Clap, and Demoralizing Shout against elites. Shield Block is reminded whenever your target is attacking you and you carry a shield. Taunting and other utility stay with you. An alternative to the recommended Wowhead tank premade, off by default: enable it and disable that one, or raise its priority."

L["Default.TBC.Priest.DpsIcyVeins.Name"] = "Priest: damage (Icy Veins)"
L["Default.TBC.Priest.DpsIcyVeins.Description"] = "Damage from level 1 to 70, used whenever the healer premade does not apply. Smite and wand early, then Mind Blast, Shadow Word: Pain, Mind Flay, Shadowform, Vampiric Touch and Shadow Word: Death as you learn them; DoTs before Mind Blast; a dying target is wanded when solo. Holy and Discipline questers get Holy Fire and Smite. Reminders: Inner Fire, Fortitude, racial buffs, Inner Focus, Shadowfiend. A Mind Flay past its first tick is cut short for a ready Mind Blast, or Shadow Word: Death above half health. Shields and healing stay with you."
L["Default.TBC.Priest.DpsWowhead.Name"] = "Priest: damage (Wowhead)"
L["Default.TBC.Priest.DpsWowhead.Description"] = "Damage after Wowhead's guides, an alternative to the recommended Icy Veins damage premade, off by default: enable it and disable that one, or raise its priority. Mind Blast opens and goes before DoT refreshes, Vampiric Embrace only when your health drops, and a dying target gets spells instead of the wand. Otherwise the same as the recommended premade."
L["Default.TBC.Priest.HealerWowhead.Name"] = "Priest: healer (Wowhead)"
L["Default.TBC.Priest.HealerWowhead.Description"] = "Healing in a group when Holy or Discipline is your main talent tree. It advises on the friendly unit you target; you choose whom to heal. Prayer of Mending before pulls and whenever ready, Renew, Power Word: Shield in emergencies, dispels, Circle of Healing or Prayer of Healing for group damage, Binding, Flash and Greater Heal, and Greater Heal rank 1 as a cheap top-up. With an enemy targeted it offers light damage."
L["Default.TBC.Priest.HealerIcyVeins.Name"] = "Priest: healer (Icy Veins)"
L["Default.TBC.Priest.HealerIcyVeins.Description"] = "Healing after Icy Veins' order: Shield, dispels, Binding Heal, Renew, Flash Heal, Greater Heal (any rank), group heals, and Prayer of Mending last. You choose whom to heal. An alternative to the recommended Wowhead healer premade, off by default: enable it and disable that one, or raise its priority."

L["Default.TBC.Warlock.DpsIcyVeins.Name"] = "Warlock: all trees (Icy Veins)"
L["Default.TBC.Warlock.DpsIcyVeins.Description"] = "Every talent tree from level 1 to 70. Curse, then Unstable Affliction, Immolate, Corruption and Siphon Life as learned, Shadow Bolt or Incinerate; Nightfall and Backlash procs first; Seed, Hellfire and Shadowfury for three or more enemies. Solo it drains when hurt, Life Taps, wands, and uses Drain Soul or a finisher on a dying target. Reminders: Fel Armor, Demon Armor or Demon Skin, your demon, sacrifice, Soul Link, Amplify Curse and Soulshatter. Fears and other curses stay with you."
L["Default.TBC.Warlock.DpsWowhead.Name"] = "Warlock: drain-tank (Wowhead)"
L["Default.TBC.Warlock.DpsWowhead.Description"] = "Warlock after Wowhead's guides, an alternative to the recommended Icy Veins Warlock premade, off by default: enable it and disable that one, or raise its priority. Solo it drain-tanks: Drain Life is the filler once your DoTs are up and Immolate and Siphon Life are kept for elite mobs. In a group Immolate always goes on, after Corruption and Siphon Life. Otherwise the same as the recommended premade."

L["Count enemies when selected, or non-enemies when cleared."] = true
L["The number of observed units proven within Distance of you."] = true
L["Counts the addon's observed unit snapshot, including nameplates and tracked unit aliases, rather than every nearby unit. A unit counts only when its upper range bound is within Distance; uncertain membership or unreadable identity, hostility, range or nameplate settings makes the whole count unavailable, including under Unless. Known vanished or reused unit tokens are excluded. Distance cannot exceed the current nameplate distance setting; that setting does not guarantee a complete scan."] = true

L["Help.Profiles.activate"] = "Selecting a sidebar row only inspects that profile. Activate profile switches the live profile immediately, including its rotations and settings. The active profile shows Active profile instead. This operation does not wait for page Apply."
L["Help.Profiles.copy"] = "Choose a source to replace the active profile after confirmation. This copies settings and rotations into the active profile, even when the sidebar is inspecting a different profile. It does not switch to the source or rename the active profile. Cancel at the confirmation preserves the current profile."
L["Help.Profiles.reset"] = "Reset current profile replaces the active profile with its defaults after confirmation. Custom rotations and settings in it are replaced. The control is disabled while inspecting another profile. Reset is immediate after confirmation; there is no later page Apply to undo it."
L["Help.Profiles.delete"] = "The red trash can permanently removes the selected inactive profile after confirmation. The active profile and Default cannot be deleted here. Selecting another profile does not delete or activate it."
L["Help.Profiles.new_name"] = "New and Duplicate open a named draft. Use a nonblank, unused name of at most 50 characters. Apply creates the profile; Cancel abandons creation. Creating a profile leaves the previously active profile active, so use Activate profile when you want to switch to the new copy."
L["Help.Profiles.collections"] = "The buttons below the list create a new profile, duplicate the selected profile, transfer profiles or compare saved settings. Search narrows the list without activating a profile. Import/Export shows the original name and lets you replace the selection or create a renamed copy. Importing a new profile opens a creation draft; Apply saves it. Replacing a selected profile happens when you confirm the import, and replacing the active profile updates its runtime settings. Compare does not apply changes."
L["Help.Integrations.lua_editor"] = "Status pills show Not loaded, Supported, Disabled, Enabled or Selected. Click Enabled to Select or Disable. Disabling Selected chooses the sole enabled available editor, offers a choice when several exist, or leaves none selected. Enabling an editor when none is selected selects it automatically. Native is always available; its Syntax highlighting option is independent of editor selection. With no enabled editor, emergency plain text remains usable. Apply saves preferences for the next source-editor opening; Discard keeps saved settings. An open editor keeps its current provider."
L["Help.Integrations.lua_line_numbers"] = "Show line numbers controls the gutter in every condition and function code editor. It defaults to enabled. Apply saves the preference and updates open code panes; Discard keeps the saved setting. It does not change the Lua source or its line breaks."
L["Help.Integrations.optional_addons"] = "Addon names open copyable official release and source links across available providers. Edition filtering follows declared support for the matching addon identity; unknown compatibility remains visible. An older release date alone does not prove incompatibility. Listed game-edition support describes publisher release evidence, not certification of the integration on your client. Some integrations have only historical or unverified releases. Not loaded means unavailable to RM; Supported identifies an available integration without an enable switch. Bundled libraries are excluded. Rotation Master does not install or enable other addons."
L["Apply / Discard"] = true
L["Edits stay in a draft until Apply. Discard abandons pending changes. Leaving with changes offers Apply, Discard or Cancel; Cancel keeps the page and draft open. Effect previews do not save changes. Action-bar binding operations are explicit and immediate."] = true
L["Diagram / List changes only the rotation view; General settings choose the default. Diagram has floating minus, percentage and plus controls at the bottom right. Scroll to zoom from 25% to 200%; click the percentage or middle-click to reset to 100%. Drag empty diagram space to pan. List uses normal scrollbars with touching cards and boxed branch arms, False before True. Cooldowns use a separate scrolling grid. Dragging cards reorders them in every view. Valid rotation bodies can contain up to 2,000 total steps; large workspaces reuse nearby card controls as you navigate. Folded branches intentionally hide their children."] = true
L["Editor"] = true
L["Optional addons"] = true
L["Activate profile"] = true
L["New / Duplicate / Import / Compare"] = true

L["Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To stages a category destination; its Apply button confirms the move. The assigned category opens category management. Sidebar arrows and dragging order entries. Page Apply saves the draft; Discard abandons edits to a saved entry. Custom conditions can be edited, duplicated or deleted."] = true
L["Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Drag a sequence card surface to reorder it; fields remain editable. New effects can be configured before naming. Apply saves the draft; Discard abandons edits to a saved entry. Import stages a validated replacement."] = true
L["Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; The binding pill removes matching bound bar actions when unbinding, outside combat. Reset restores a packaged set. Search or drag items into reference fields. Apply saves settings; Discard abandons edits to a saved entry. Binding changes are explicit action-bar operations."] = true
L["Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid text stays red and must be corrected before Apply; Discard can abandon it. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents."] = true
-- Native condition item-list editor
L["Apply changes to this selected item list. Other settings keep their own Apply action."] = true
L["Choose an item list before editing."] = true
L["The item list changed elsewhere. Close and reopen it before applying."] = true

L["Editing this list"] = true
L["Help.ItemSets.popup.overview"] = "This window edits only the item list you opened. Search or drag items into the fields, then arrange preferred items first. A named item set is shared by its other users; a custom list belongs to the calling condition or action draft. Applying this list does not apply the parent editor."
L["Help.ItemSets.popup.delete"] = "Use a row's red trash can to remove that entry from the draft list. This does not delete a named item set or remove an item from your inventory. The removal takes effect when you Apply this list."
L["Help.ItemSets.popup.save"] = "Apply validates every entry and writes the edited list back to its original owner. Discard closes without changing it. Closing with pending edits offers Apply, Discard or Cancel; Cancel keeps this window open. View Changes compares the original list with this draft. If the original list changed elsewhere, close and reopen it before applying."
L["Native settings page unavailable: %s"] = true

L["The native rotation editor is unavailable."] = true
L["Required"] = true

L["Required field references need review. Apply keeps the displayed root requirements."] = true

L["Required root fields must have a value before this condition can run. Rename, reorder and duplicate keep this flag; removing the field removes its requirement. Moving it into a nested structure makes it optional. Undo restores both. Callback code is unchanged."] = true
L["Copy condition description"] = true

L["This condition exceeds the supported editor limits."] = true

L["Proc Glow"] = true
L["Loop duration"] = true
L["Start burst"] = true
L["Proc Glow is unavailable on this client; Pixel glow will be used."] = true
L["Help.Effects.type.proc"] = "Proc Glow: use the animated actionbar proc border from LibCustomGlow. Rotation Master checks the required game artwork and animation support before using it. Unsupported clients use Pixel glow instead; the definition remains portable. Color and offsets come from the profile or the cooldown."
L["Help.Effects.proc.duration"] = "Time in seconds for one repeating proc-border animation, from 0.1 to 5. Use the slider or enter an exact value in its number field. Changing the value updates the preview."
L["Help.Effects.proc.startAnim"] = "Play the opening burst when this highlight first appears, then repeat its border animation. Off by default. Refreshing an already visible Proc Glow does not restart the burst."
L['Rotation data requires recovery: %s'] = true
L['Copies belong to your Class unless This character is selected. Replacement keeps its original owner.'] = true
L['Archive report truncated; saved data is unchanged.'] = true
L['Recover unassigned rotations'] = true
L['Ownership required'] = true
L['These records have no assigned owner. Choose Class or This character explicitly. No ownership is inferred from names, spells or profile history.'] = true
L['Recovery unavailable: %s'] = true
L['Unassigned rotation archive'] = true
L['Character archive'] = true
L['Profile archive'] = true
L['No unassigned rotations.'] = true
L['Archive: %s; specialization: %s; identifier: %s'] = true
L['Export archive'] = true
L['Adopt rotation'] = true
L['Could not adopt this record: %s'] = true
L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'] = true
L['The fallback rotation is unavailable. Open Rotations to complete or recover it.'] = true
L['Class rotations are shared by characters of the same class in this settings profile. This character limits the rotation to your current character. Applying a scope change moves the complete saved rotation; an existing destination is never overwritten.'] = true
L['Rotations belong to the active settings profile. New copies use Class, shared by your characters of that class; Metadata can change this to This character. Built In rotations show only for their declared class or universal use. Equal identifiers in different owners remain separate entries.'] = true
L['Older rotations without a recorded owner stay in an archive. Recover unassigned rotations opens the current profile and character archives for inspection or copying. Choose Class or This character to adopt one. Adoption preserves its identifier and evidence, refuses an existing destination, and leaves incomplete records unavailable until repaired.'] = true
L["Unsupported condition editor frame."] = true

L["The native condition editor is unavailable."] = true

L["Native custom condition editor required."] = true
L["Stock"] = true






L["Target"] = true


L["you {{!have|do not have}} {item} equipped"] = true

L["{item} {{!is|is not}} available{carrying}"] = true

L["{item} {{!is|is not}} in range{carrying}"] = true

L["the cooldown on {item} {comparison} {duration}{carrying}"] = true










-- Optional Questie receipt integration
L["Questie"] = true
L["Enable Questie integration"] = true
L["Waiting for Questie."] = true
L["Questie API incompatible."] = true
L["Questie callback connection available."] = true
L["Questie values are restricted by this client."] = true
L["Questie integration unavailable after an adapter error."] = true
L["Questie adapter unavailable."] = true
L["Questie version: %s (%s)"] = true
L["source-tested"] = true
L["unverified"] = true
L["Client family: %s (%s)"] = true
L["declared; unverified"] = true
L["unsupported"] = true
L["Native acceptance: unverified. Coverage: recent update receipts only; no quest progress, completion or rotation selection."] = true
L["Questie is optional and disabled by default. Apply saves this profile preference. No background polling is used."] = true
L["Refresh Questie status"] = true
L["Supported addons"] = true
L["Loaded; integration not connected."] = true
L["%s (version %s)"] = true
L["Supported addons are listed even when missing. Loaded addons are only marked connected when their integration is available."] = true
L["Help.Integrations.overview"] = "Review supported addons, detected versions and status by integration type. Expand or collapse each integration group. Click an addon name to choose a copyable release or source link. Configure editor and optional provider preferences here; Apply saves preferences for this profile and Discard keeps saved settings."
L["Help.Integrations.questie_enabled"] = "Opt in to Questie callbacks for this profile, then Apply. Discard does not change the saved connection. Readiness, API compatibility, source-tested version and native acceptance are reported separately. The adapter retains recent update receipts only; they do not prove quest progress or completion and do not select rotations. No background polling is used."
L["ExtendedCharacterStats"] = true
L["MobInfo2"] = true
L["LuaWorkbench"] = true
L["WowLua"] = true
L["WeakAuras"] = true
L["ElvUI"] = true
L["Bartender4"] = true
L["ButtonForge"] = true
L["G15Buttons"] = true
L["SyncUI"] = true
L["LUI"] = true
L["Dominos"] = true
L["DiabolicUI"] = true
L["AzeriteUI"] = true
L["Neuron"] = true
L["FarmingBar"] = true
L["TotemTimers"] = true
L["SamyTotemTimers"] = true
L["Optional character statistics conditions."] = true
L["Recorded creature history conditions; no current history is queried."] = true
L["Lua editor integration. Choose an editor in Lua editor options."] = true
L["Optional editor addon; no built-in connection is registered."] = true
L["Recommendation event bridge; no WeakAuras display is required."] = true
L["Quest update receipts only; native quest progress is not verified."] = true
L["Optional action-bar mapping and glow support."] = true
L["Optional action-bar glow support."] = true
L["DBM"] = true
L["BigWigs"] = true
L["Titan Panel"] = true
L["Boss mods"] = true
L["Top panels"] = true
L["Boss-mod timers and encounter stage for the Boss Mod conditions."] = true
L["Shows the active rotation from RM's LibDataBroker feed; add Rotation Master from Titan's plugin menu."] = true
L["DBM-Core for Retail, Forever, Classic Era, TBC and Mists Classic. Encounter timers need the matching raid or dungeon module download, such as DBM-Raids-BC for TBC raids."] = true
L["Official historical release page. The authors no longer update it; use CurseForge or GitHub for current releases."] = true
L["BigWigs (Boss Timers & Tools) for Retail, Forever, Classic and Classic progression. Its TOC also declares TBC Anniversary."] = true
L["Official project page. Publisher lists Retail, Classic Era, TBC, Wrath and Cataclysm Classic. Choose the matching file; exact patch and RM integration behavior may be unverified."] = true
L["Titan Panel for Retail, Forever, Mists Classic, Classic and Classic TBC."] = true
L["Official project page. Publisher lists Retail and Classic Era. Choose the matching file; exact patch and RM integration behavior may be unverified."] = true
L["Help.Integrations.encounter_provider"] = "Enable DBM or BigWigs to feed the Boss Mod conditions (encounter, stage and ability timers), then Apply. Only one boss mod can be enabled; enabling one disables the other. RM listens to the boss mod's own callbacks and never polls it or changes its settings. With none enabled, or the enabled addon not loaded, Boss Mod conditions are unavailable. Supported on Classic Era, TBC and Classic progression clients."
L["Help.Integrations.top_panels"] = "Rotation Master publishes a LibDataBroker data source with the active rotation, a tooltip and click menus. Titan Panel and other LibDataBroker displays show it without further setup: in Titan, add Rotation Master from the plugin menu. Panel absence has no effect on rotation selection."
L["Connected"] = true
L["Incompatible"] = true

L["Loaded; connection not confirmed."] = true

-- Volatile cast receipt diagnostic controls.
L["Advice: not available; presentation: not available; ordinary-cast proof: not available."] = true
L["Attempts: %d; results: %d"] = true
L["Capture casts (30s)"] = true
L["Capture: unavailable"] = true
L["Capture: complete; reason=%s"] = true
L["Capture: unavailable; reason=%s"] = true
L["Cast capture cleared."] = true
L["Cast capture is running. Stop it or wait before opening Cast report."] = true
L["Cast capture is unavailable."] = true
L["Cast capture started for 30 seconds. Configuration can be closed during capture."] = true
L["Cast capture status: idle"] = true
L["Cast capture status: running"] = true
L["Cast capture stopped. Open Cast report to inspect receipts."] = true
L["Cast receipt report"] = true
L["Cast report"] = true
L["Stop CPU capture"] = true
L["Stop runtime capture"] = true
L["Stop cast capture"] = true
L["Help.General.cast_capture"] = "Record spell cast receipts for thirty seconds without changing settings or gameplay polling. While it runs this button reads Stop cast capture and ends the capture early, keeping what was recorded."
L["Help.General.cast_report"] = "Open the copyable cast receipt report. It stays disabled until a cast capture has produced a report and while a capture is running."
L["Client: family=%s version=%s build=%s interface=%s locale=%s"] = true
L["Counts describe receipt rows, not gameplay opportunities."] = true
L["Damage: unavailable (no damage observations or encounter denominator)."] = true
L["Duration: %s seconds"] = true
L["Healer: unavailable (no effective healing, absorbs or mana observations)."] = true
L["Native acceptance: unverified"] = true
L["No cast capture is running."] = true
L["No cast capture report is available. Start a capture first."] = true
L["Producer: UNIT_SPELLCAST adapter"] = true
L["Records: %d"] = true
L["Receipt kinds: channel=%d unmodeled=%d"] = true
L["Receipt signals: sent=%d start=%d success=%d failed=%d interrupted=%d stop=%d"] = true
L["Rotation Master cast receipt diagnostics"] = true
L["Rotation attribution: unavailable; capture seconds are not encounter seconds."] = true
L["Rows omitted: %d"] = true
L["Scoring: unavailable"] = true
L["Tank: unavailable (no threat, mitigation or survival observations)."] = true
L["unavailable"] = true




L["Action bars"] = true
L["Addon"] = true
L["Apply changes the editor used the next time a source editor opens. Enable an editor before selecting it."] = true
L["Automatic uses an enabled available provider, then enabled built-in highlighting, otherwise None (plain editor)."] = true
L["Baseline plain editor; always available."] = true
L["Built in"] = true
L["Condition data"] = true
L["Description / status"] = true
L["Editor options"] = true
L["Enable / Select"] = true
L["Lua editors"] = true
L["None (plain editor)"] = true
L["Quest callbacks"] = true
L["Recommendation notifications"] = true
L["Selected"] = true
L["Shared editor settings."] = true
L["Editor settings"] = true
L["Enable built-in syntax highlighting"] = true
L["Lua editor integrations"] = true
L["Native"] = true

L["Syntax highlighting"] = true

L["Not loaded"] = true

L["Supported"] = true

L["Status"] = true

L["Built-in Lua editor."] = true

L["Registered Lua editor provider."] = true

L["Addon release pages"] = true

L["Publisher listings describe release availability; integration behavior on this client may be unverified."] = true

L["Copy %s"] = true

L["Release links checked: 2026-10-20."] = true

L["CurseForge"] = true

L["Classic Era and TBC. Other editions are unverified; Forever Extended Character Stats is a different project."] = true

L["Publisher lists Retail, Forever, Classic Era, TBC and Mists Classic."] = true

L["Retail, Forever and TBC. Other editions are unverified."] = true

L["Retail, Classic Era, TBC and older progression releases. Current-patch support is unverified. RM currently detects WowLua but does not offer it as an editor."] = true

L["Current Classic Era, TBC and Mists Classic releases; Retail release evidence is historical. Current Retail and Forever support is unverified."] = true

L["Classic Era, TBC and Mists Classic. Retail and Forever releases are unverified."] = true

L["Tukui"] = true

L["Official release channel. Publisher TOC lists Retail, Forever, Classic Era, TBC, Mists and Wrath Classic."] = true

L["Retail, Forever, Classic Era, TBC and Mists Classic. Choose the file for your edition."] = true

L["Separate Retail, Classic Era, TBC and Mists Classic releases. Forever is unverified."] = true

L["Historical Retail release. All current editions are unverified. This is G15 Buttons (continued)."] = true

L["WoWInterface"] = true

L["Historical Retail 8.3 release. All current editions are unverified."] = true

L["Primary LUI Core updates for Retail. Fresh installs use the author-linked full bundle below; Classic uses a separate fork."] = true

L["CurseForge — LUI Classic"] = true

L["Classic Era, TBC and Mists Classic fork. Its compatibility with RM action buttons is unverified."] = true

L["WoWInterface — Retail full bundle"] = true

L["Author-linked full Retail bundle; historical 10.0.2 release, older than the Core updates."] = true

L["WoWInterface — Classic full bundle"] = true

L["Author-linked full Classic bundle; historical Wrath release. For current Classic editions, inspect the newer Classic fork above."] = true

L["Retail, Forever, Classic Era, TBC and Mists Classic."] = true

L["Original historical project. Current editions are unverified; newer forks are not verified replacements for the integration."] = true

L["Legacy AzeriteUI5, now deprecated. Current editions are unverified. RM supports this original addon identity."] = true

L["CurseForge — AzeriteUI6 successor"] = true

L["Successor supports all five editions but uses a different addon identity. RM does not yet integrate with AzeriteUI6."] = true

L["Historical project; author reports a development hiatus. All current editions are unverified."] = true

L["Retail, Classic Era, TBC and Mists Classic releases. Latest-patch compatibility and Forever are unverified."] = true

L["Primary project now releases TotemTimers Forever. Retail files are historical. Classic editions use the separate project below."] = true

L["CurseForge — TotemTimers Classic"] = true

L["Classic Era, TBC, Wrath, Cataclysm and Mists Classic. Compatibility with RM action buttons is unverified."] = true

L["Historical Classic Era and TBC releases. Current editions are unverified. Other similarly named addons are not verified replacements."] = true

L["Copy link %d"] = true

L["Disable"] = true
L["Provider"] = true

L["URL"] = true

L["Select URL for copying (Ctrl+C)"] = true
L["Help.Integrations.native_highlighting"] = "Syntax highlighting applies only to the Native Lua editor. Apply saves this preference for the next source-editor opening; it does not switch a selected external editor. Show line numbers under the editor heading applies to every provider."

-- Official integration project labels and edition notes.
L["Wago Addons"] = "Wago Addons"
L["Official project page. Publisher lists Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["GitHub"] = "GitHub"
L["Official source repository. Choose the release for your game edition; source availability does not certify integration behavior."] = "Official source repository. Choose the release for your game edition; source availability does not certify integration behavior."
L["WoWInterface — historical"] = "WoWInterface — historical"
L["Official historical release page. Current patch compatibility is unverified; inspect the release details before downloading."] = "Official historical release page. Current patch compatibility is unverified; inspect the release details before downloading."
L["Official source — CurseForge SVN"] = "Official source — CurseForge SVN"
L["Official project page. Release edition and current patch compatibility are unverified."] = "Official project page. Release edition and current patch compatibility are unverified."
L["Official project page. Publisher lists Retail, Forever, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Retail, Forever, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["Official project page. Publisher lists Retail, Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Retail, Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["GitHub — official published URL, unavailable"] = "GitHub — official published URL, unavailable"
L["Author-published source link. The repository page was unavailable when checked; use another provider if it remains unavailable."] = "Author-published source link. The repository page was unavailable when checked; use another provider if it remains unavailable."
L["Official source — CurseForge Git"] = "Official source — CurseForge Git"
L["WowUp Hub"] = "WowUp Hub"
L["Official website"] = "Official website"
L["Official project page. Publisher lists Forever, Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Forever, Classic Era, TBC, Classic progression. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["Official project page. Publisher lists Retail, Classic Era, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Retail, Classic Era, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["Official project page. Publisher lists Retail, Forever, Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Retail, Forever, Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["WoWAce"] = "WoWAce"
L["CurseForge — LUI Core"] = "CurseForge — LUI Core"
L["CurseForge — LUI Classic fork"] = "CurseForge — LUI Classic fork"
L["GitHub — LUI Core"] = "GitHub — LUI Core"
L["GitHub — LUI Classic fork"] = "GitHub — LUI Classic fork"
L["Official Classic fork for Classic Era, TBC and Mists. RM button integration on this fork is unverified."] = "Official Classic fork for Classic Era, TBC and Mists. RM button integration on this fork is unverified."
L["Official current source/release track uses DiabolicUI2, a different addon identity. Compatibility with the original RM integration is unverified."] = "Official current source/release track uses DiabolicUI2, a different addon identity. Compatibility with the original RM integration is unverified."
L["Wago Addons — AzeriteUI6 successor"] = "Wago Addons — AzeriteUI6 successor"
L["Official AzeriteUI6 successor, with a different addon identity. RM does not yet integrate with AzeriteUI6; use the original project for the existing integration."] = "Official AzeriteUI6 successor, with a different addon identity. RM does not yet integrate with AzeriteUI6; use the original project for the existing integration."
L["GitHub — AzeriteUI6 successor"] = "GitHub — AzeriteUI6 successor"
L["Official source repository. This project is archived; current patch compatibility is unverified."] = "Official source repository. This project is archived; current patch compatibility is unverified."
L["Official project page. Publisher lists Retail, Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Retail, Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["GitHub — TotemTimers Classic"] = "GitHub — TotemTimers Classic"
L["WoWInterface — TotemTimers Classic"] = "WoWInterface — TotemTimers Classic"
L["Official project page. Publisher lists Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."] = "Official project page. Publisher lists Classic Era, Classic progression, TBC. Choose the matching file; exact patch and RM integration behavior may be unverified."
L["Wago Addons — TotemTimers Classic"] = "Wago Addons — TotemTimers Classic"



L['API'] = true
L['Masque'] = true
L['Preview appearance'] = true
L['Skin preview buttons with Masque'] = true
L['Optional preview-button skins; configure skins with /masque.'] = true
L['Help.Integrations.preview_masque'] = "Enable separately installed Masque here and Apply. General > Preview then provides a Skin dropdown that updates the preview immediately. Masque owns the skin selection; /masque opens its other settings. The preview window keeps its native appearance. Missing or incompatible APIs and provider errors retain the native preview."




L["History"] = true
L["Button skins"] = true
L["Bypass observation cache"] = true
L["Bypass observation cache (requires restart)"] = true
L["Bypass observation cache (pending)"] = true
L["Skin"] = true
L["Blizzard Classic"] = true
L["Preview skin is unavailable."] = true
L["Help.General.preview_skin"] = "Enable Masque in Integrations to choose a skin. Skin changes update the open preview immediately and are saved by Masque, independently of Apply or Discard. Without enabled Masque support, the preview uses Blizzard Classic. Preview toggles sample icons whether Masque is enabled or not."
L["Help.General.preview_sample"] = "Click Preview to toggle temporary sample icons when no real recommendations are available. Real recommendations replace the samples. This does not change Preview Spells, cast spells, or save the sample state."

L["Sample icon"] = true


-- Explicit unscored advice/native-preview receipt coverage.
L['Advice/presentation rows describe observed delivery boundaries only; ordinary-cast proof: not available.'] = true
L['Coverage rows: advice=%d presentation=%d visible=%d hidden=%d unknown=%d retired=%d (not opportunities).'] = true
L['Visible means RM-owned preview frame state at a delivery boundary; it does not prove perception or native pixel rendering.'] = true


L['Saved manual choice is unavailable in the current context.'] = true

-- Capture-only START witness diagnostics.
L['START witness rows: observed=%s matched=%s mismatch=%s excluded=%s unknown=%s (not ordinary proof).'] = true
L['START witnesses compare current cast identity and non-autorepeat classification only; they do not classify ordinary casts or enable scoring.'] = true
L["Edit announcement conditions"] = "Edit announcement conditions"
L["Announcement conditions"] = "Announcement conditions"
L["Help.Announces.conditions"] = "Optional conditions use the Announcement condition list and All, Any and Not groups. For spell, pet and item announcements, they run when the configured action and event match. For Via Script/Macro, they run when you invoke the saved identifier. Each output card checks its own conditions. Only a matching result allows that output; unavailable data skips that card while later cards remain independent. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Choose Announcement target to check the spell recipient for automatic entries, or the supplied unit for Via Script/Macro; Whisper uses that same supplied unit. Automatic entries pass the recorded recipient name to native unit queries. A missing or unresolvable recipient skips its required condition; an unrelated selected target is never substituted. Missing or ambiguous required recipients do not match. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes."

L["Spell recipient"] = "Spell recipient"
L["{unit} {{!is|is not}} in a raid"] = "{unit} {{!is|is not}} in a raid"
L["{unit} {{!is|is not}} in a group"] = "{unit} {{!is|is not}} in a group"
L["Help.GROUP.unit"] = "Choose the unit whose membership in your party or raid is checked. Player keeps the original player group-status behavior. Spell recipient uses only the current announcement event context; without that readable context the result is unavailable. It never substitutes your selected target or a previous cast."
L["Help.GROUP.raid"] = "Checked tests raid membership only. Unchecked tests party membership or raid membership. A known nonmember is false; unavailable native data stays unavailable, including under NOT."
L["Announcement target"] = "Announcement target"
-- Unit death and friendliness conditions.
L["Is Dead or Ghost"] = true
L["Is Friendly"] = true
L["{unit} {{!is dead or a ghost|is alive}}"] = true
L["{unit} {{!is friendly to you|is not friendly to you}}"] = true
L["Matches when the selected unit is dead or a ghost. A missing or unreadable unit is unavailable, including under NOT. In a Via Macro announcement, choose Announcement target to follow the supplied unit."] = true
L["Matches when the game reports the selected unit as friendly to you. This does not imply party or raid membership. A missing or unreadable unit is unavailable."] = true
L['Workbench Help'] = 'Workbench Help'

L['Navigation'] = 'Navigation'

L['Help.Window.navigation'] = 'Choose tabs to browse Rotations, General, Conditions, Functions, Effects, Item Sets, Announces, Profiles and Integrations. The opened panes have their own Help for page controls. Search and filters belong to the current page. Built In entries remain read-only; Duplicate creates an editable copy.'

L['Help.Window.scale'] = 'Scale changes the whole workbench and its child windows from 70% to 130%. Drag the top-left slider or enter an integer percentage and press Enter. Escape restores the saved scale text. Drag the title bar to move; drag the lower-right corner to resize.'

L['Help.Window.controls'] = 'Close with X, Escape, or right-click inside the frontmost RM window. Child dialogs have their own close controls and follow the window scale. The language selector changes the workbench language; project links open a copyable address.'

L['Help.Window.drafts'] = 'Most settings and source editors keep drafts until Apply. Leaving a dirty page offers Apply, Discard or Cancel; invalid fields remain visible. Profile activation and confirmed replacement, action-bar binding and diagnostic capture have their own explicit actions. Help never applies or discards edits.'

L['Help.Window.help'] = 'Gold question marks open full Help for their window, page or card. Hover controls for brief tips. Help does not save settings or commit pending text; spell and item fields keep their native reference tooltips.'

L['Help.Brief.full'] = 'Open full Help for these controls without applying edits.'

L['Help.Brief.window'] = 'Explain window navigation, scaling, closing and drafts.'

L['Help.Brief.page'] = 'Open full Help for this page without switching tabs or applying edits.'

L['Help.Brief.scale'] = 'Set the workbench and child-window scale from 70% to 130%; enter a whole percentage or drag the slider.'

L['Help.Brief.edit'] = 'Edit the value; Enter or leaving the field checks and accepts valid text. Page Help explains when changes are saved.'

L['Help.Brief.check'] = 'Click to toggle this option. Page Help explains when changes are saved.'

L['Help.Brief.control'] = 'Use this control for the current page; page Help explains its options and consequences.'

L['Help.Conditions.subject_unavailable'] = 'Help for this condition is unavailable. Its registered definition is missing, disabled or waiting for required functions. Opening Help does not register pending or imported source.'

L['Help.Conditions.subject_missing'] = 'This registered condition does not provide Help.'

L['Help.Conditions.subject_brief'] = 'Open Help for this condition without changing its fields.'

L["Help.Transfers.copy"] = "Select all export text for manual copying. This button does not send it anywhere."

L["Help.Transfers.clear"] = "Clear the transfer text. A previous preview becomes invalid; saved settings stay unchanged."

L["Help.Transfers.apply"] = "Import into the displayed destination. Read the destination and review requirements before continuing."

L["Help.Transfers.cancel"] = "Close this dialog without importing its text."

L["Help.Transfers.destination"] = "Choose a new named copy or replacement of the selected editable entry."

L["Help.Transfers.name"] = "Set the name for a new copy. Replacement keeps the selected entry as its destination."

L["Help.Transfers.preview"] = "Decode and validate the current text for review. Preview does not import it."

L["Help.Transfers.inspect"] = "Show read-only validation details for the current preview."

L["Help.Transfers.profile_brief"] = "Explain profile import destinations and when changes are saved."

L["Help.Transfers.profile_overview"] = "Copy the text to export a profile, or paste profile text to import. The destination controls choose a new profile or replacement of the selected saved profile. Opening Help does not decode, import, or apply the text."

L["Help.Transfers.profile_replace"] = "REPLACE applies immediately to the selected saved profile after Import. Replacing the active profile resets it and applies the imported settings; replacing another profile writes that profile. Reopen the import if the selected saved profile changes."

L["Help.Transfers.profile_new"] = "NEW stages the imported profile in the Profiles editor. Import fills a new-profile draft; the new profile is not saved or activated until you complete the creation controls in that editor. Give it an unused name."

L["Help.Transfers.source_brief"] = "Explain this read-only review of imported source."

L["Help.Transfers.source_review"] = "This view shows the selected imported function or condition source, its original and destination identifiers, and available metadata. For a condition, choose a callback to inspect its text. This view and its Help do not compile, execute, accept, or register the source. Return to the bundle review to decide whether to import it."

L["Help.Transfers.source_close"] = "Close this read-only source view and return to the bundle review."

L["Help.Transfers.bundle_review"] = "Validate the pasted bundle and build a proposed import plan. Review does not apply the plan."

L["Help.Transfers.bundle_dependencies"] = "Include referenced custom function dependencies when producing export text."

L["Help.Transfers.bundle_brief"] = "Explain dependency-bundle export, review, and explicit import."

L["Help.Transfers.bundle"] = "Export produces a function or condition bundle, optionally with its custom function dependencies. For import, paste bundle text, choose Review import, inspect the proposed identifiers and conflicts, and review source before applying. Apply import can register trusted Lua source; accept only source you intend to run. Changing the text invalidates the prior plan. Opening Help neither reviews nor applies the bundle."

L["Help.Transfers.rotation_brief"] = "Explain rotation preview, destination, and import scope."

L["Help.Transfers.rotation"] = "Copy the text to export the current rotation, or paste a rotation to import. Choose replacement of the selected editable rotation or a new named copy. Class and This character set the owner of a new copy; replacement keeps the original owner. The imported rotation is opened for editing after a successful import."

L["Help.Transfers.rotation_preview"] = "Preview import validates the current text and shows an incoming comparison. It does not save the rotation. Import is enabled only for a ready preview; changing the text requires another preview. Inspect import shows read-only diagnostics, including unsupported data that prevents import."

L["Help.Transfers.comparison_brief"] = "Explain this read-only incoming rotation comparison."

L["Help.Transfers.comparison"] = "This view compares the saved or exported rotation with the current incoming preview. It does not apply changes. Close it to choose the destination and import from the transfer dialog. A changed preview, closed owner, or changed profile retires this comparison Help."

L["Destination"] = "Destination"

-- Direct, configured macro announcements.
L["Via Macro"] = true
L["Via Script/Macro"] = true
L["Use a unique Via Script/Macro identifier."] = true
L["Whisper"] = true
L["Macro invocation"] = true
L["Supplied macro unit"] = true
L["Use supplied macro target ({{target}})"] = true
L["Macro call: %s"] = true
L["Help.Announces.macro.brief"] = "Invoke this saved identifier directly from your macro. The supplied unit controls Announcement target conditions and Whisper; there is no implicit target."
L["Help.Announces.type.macro"] = "Via Script/Macro is invoked by its saved Identifier rather than a cast event. It does not require a stored spell or item. Current conditions must match before any output. This call attempts output synchronously; it does not establish that a spell was cast or succeeded."
L["Help.Announces.identifier"] = "Use a unique, case-sensitive identifier of at most 64 ASCII characters. Start with a letter or underscore; subsequent characters may also include digits, dots or hyphens. Identifiers are scoped to the active profile, including disabled entries. Duplicate assigns a distinct identifier; ambiguous imports and Apply are rejected."
L["Help.Announces.macro.example"] = "Use /run RM_Annouce('FOO','mouseover',nil). RM_Announce is the same function. The target unit and spell are optional: /run RM_Announce('FOO',nil,403) or /run RM_Announce('FOO','target','Lightning Bolt'). Spell names depend on client language. {{event}} becomes Via Script/Macro; {{target}} and {{spell}} use the supplied arguments. A required missing argument skips output. {{item}} is not supplied by this API. A resurrection message announces an attempt, not a completed resurrection. Examples are text only; RM does not create or execute macros."
L["Help.Announces.macro.target"] = "Supply a readable unit token such as mouseover, target or focus. RM resolves that exact unit name and rechecks its identity during delivery. Announcement target conditions and Whisper use this same unit. Omitting the argument does not use your selected target, yourself, a prior cast or a prior macro call. Missing Announcement target data remains unavailable, including under NOT."
L["Help.Announces.macro.emote_target"] = "Checked directs a named emote to the supplied macro unit. Missing or unreadable target data skips the targeted emote; unchecked is targetless."
L["Help.Announces.channel.say"] = "Available only for Via Script/Macro. Attempt a Say message directly in the invoking call. Blizzard may reject macro-origin chat, including during instance encounters; RM does not attest hardware input, defer delivery, retry or guarantee visible output."
L["Help.Announces.channel.yell"] = "Available only for Via Script/Macro. Attempt a Yell message directly in the invoking call. Native macro and encounter restrictions still apply; a completed API call is not confirmation of delivery."
L["Help.Announces.channel.whisper"] = "Available only for Via Script/Macro. Whisper uses the exact supplied unit name and requires a readable player identity. No target means no Whisper. Native macro and encounter restrictions still apply; RM never substitutes another recipient or retries."

L['Announcement Condition'] = true
L['Announcement'] = true
L['Show this condition in the announcement condition editor.'] = true
L['Offer this condition type when editing announcement conditions. This flag is independent of Switch Condition and does not remove or invalidate conditions already saved in announcements.'] = true
-- Ordered announcement outputs (configuration only).
L['Outputs']='Outputs'
L['Output %d']='Output %d'
L['Output state']='Output state'
L['Add output']='Add output'
L['Channel']='Channel'
L['Complete this output or choose a destination available for this action type.']='Complete this output or choose a destination available for this action type.'
L['Help.Announces.outputs']='One trigger can send an ordered series of outputs. Each expanded card has its own destination, text or sound, conditions and enabled state. Help describes that card. Duplicate makes an independent card; delete removes it. Use the arrows, or drag a card from anywhere on it, to change order. Add output, on the Outputs header row, appends a card; drag it into a gap to insert one there. A legacy announcement stays unchanged on display. Adding, duplicating or removing a card, choosing Channel, or changing to an action type that cannot use its saved destination converts only the draft to output cards. Up to 64 outputs are allowed; an empty series sends nothing. Apply saves the draft and Discard restores it.'
L['Help.Announces.channel.channel']='Via Script/Macro outputs can send to a joined chat channel. Open Channel to refresh the joined names, then select the exact name. A saved name remains visible when unavailable; that output is skipped until the channel is joined under that name. Numeric channel IDs are not saved and channels are never joined automatically. Native delivery permissions still apply.'

L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.']='Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'


-- Read-only human condition summaries.
L["{unit} {{!is friendly|is not friendly}}"] = true
L["{unit} {{!are friendly|are not friendly}}"] = true
L["{unit} {{!are dead or a ghost|are alive}}"] = true
L["%s {{!are|are not}} an enemy"] = true
L["%s {{!are|are not}} attackable"] = true
L["{unit} {{!are|are not}} in a raid"] = true
L["{unit} {{!is|is not}} in a party or raid"] = true
L["{unit} {{!are|are not}} in a party or raid"] = true
L["Choose a unit for this condition."] = true
L["Group membership option is invalid."] = true
L["For %s"] = true
L["Saved settings"] = true
L["Default.Forever.Rogue.DPS.Name"] = "Forever Rogue: melee DPS"
L["Default.Forever.Rogue.DPS.Description"] = "Melee damage for every Rogue specialization from level 1 to 60, built from Icy Veins, Wowhead and Warcraft Tavern. The builder follows what you know: Mutilate (Sinister Strike for the fifth point), Hemorrhage, Backstab when the target is not facing you, else Sinister Strike. From Stealth it opens with Premeditation, Cheap Shot when solo, Garrote for Subtlety on group elites, else Ambush or Garrote. It keeps Slice and Dice and Venom up, uses Expose Armor in groups on elites when no warrior has five Sunders, then spends five points on Rupture (Subtlety, long fights) or Eviscerate, and never builds past five. Reminders: poisons on each weapon, Kick, Blade Flurry and Adrenaline Rush on packs and elites, Cold Blood, Evasion, Feint, Thistle Tea and Preparation. Left to you: Vanish, Sprint, Kidney Shot, Blind, Sap and positioning. Forever restricts combat data, so Rotation Master lists this premade for reference and does not select it automatically yet."
L["Default.Forever.Rogue.Subtlety.WarcraftTavern.Name"] = "Forever Rogue: Subtlety, Ambush build (Warcraft Tavern)"
L["Default.Forever.Rogue.Subtlety.WarcraftTavern.Description"] = "Warcraft Tavern's Ambush/Cutthroat Subtlety build: Premeditation and Ambush on every opener, Ambush again whenever Cutthroat allows it, Backstab from behind as the builder (Hemorrhage when the target is facing you), Ghostly Strike on cooldown, and Slice and Dice then Eviscerate at five points with no Rupture. Reminds you to Vanish for another Ambush on a tanked boss. Choose it instead of the recommended Rogue premade if you took the Cutthroat talents; it applies with Subtlety as your main talent tree and Cutthroat talented. Same poison and cooldown reminders as the recommended premade. An alternative to the recommended Rogue DPS premade, off by default: enable it and disable that one, or raise its priority."
L["Default.Forever.Rogue.Subtlety.Wowhead.Name"] = "Forever Rogue: Subtlety, Garrote build (Wowhead)"
L["Default.Forever.Rogue.Subtlety.Wowhead.Description"] = "Wowhead's Subtlety: Premeditation and Garrote on every opener, and Vanish (then Preparation) used in the rotation to open with Garrote again once the last one has run out. Slice and Dice kept up, Expose Armor in groups, Rupture as the five-point finisher, Hemorrhage as the only builder. This spends Vanish, your escape, on damage: choose it deliberately. It applies with Subtlety as your main talent tree, Dirty Deeds talented and Premeditation known. Same poison and cooldown reminders as the recommended premade. An alternative to the recommended Rogue DPS premade, off by default: enable it and disable that one, or raise its priority."

L["Default.Forever.Shaman.Restoration.Name"] = "Forever Shaman: Restoration"
L["Default.Forever.Shaman.Restoration.Description"] = "Healing once Restoration is your main talent tree with 16 points (Mana Tide Totem's tier), after Icy Veins. With a friendly target: an instant Healing Wave once you use Nature's Swiftness, Cure Poison and Cure Disease, Riptide on a target without it, Chain Heal in a group, Healing Wave. You pick who to heal by targeting them; health and mana are hidden from addons on Forever, so when to use Nature's Swiftness and Lesser Healing Wave is your call. With a hostile target and nothing to heal: Fire Nova and Chain Lightning on packs, Stormstrike and Earth Shock if you know Stormstrike, Flame Shock on elites and bosses, Lightning Bolt, then melee. Reminders: Water Shield, the Earth Shock interrupt, Mana Tide and group buff totems. Left to you: downranking, other totems, Purge and Ghost Wolf."
L["Default.Forever.Shaman.Elemental.Name"] = "Forever Shaman: Elemental"
L["Default.Forever.Shaman.Elemental.Description"] = "Ranged Elemental once Elemental is your main talent tree with 21 points (Lava Burst's tier), after Icy Veins (before that the Enhancement premade plays the melee hybrid every guide recommends). Pulls with Lightning Bolt (Chain Lightning on a pack), casts only instants while moving, uses Fire Nova and Chain Lightning on three or more enemies, keeps Flame Shock up, Lava Burst on cooldown, Stormstrike and Earth Shock if you know Stormstrike, Fire Nova on Clearcasting in groups, then Lightning Bolt. Reminders: shield, weapon imbue, Searing or Magma Totem, group totems, Elemental Mastery, interrupt. Health and mana are hidden from addons on Forever, so healing yourself and pausing to refill mana are your call. Left to you: Earthbind kiting, Frost Shock, Purge and other totems."
L["Default.Forever.Shaman.Enhancement.Name"] = "Forever Shaman: Enhancement (Icy Veins)"
L["Default.Forever.Shaman.Enhancement.Description"] = "Melee Enhancement from level 1 to 60, and the default for any Shaman before Lava Burst or Mana Tide Totem. Pulls with Lightning Bolt from range, then Stormstrike on cooldown, an instant Lightning Bolt at five Maelstrom Weapon stacks, Fire Nova (with a Fire totem down) and Flame Shock on three or more enemies, Earth Shock into the Stormstrike debuff, Flame Shock in groups, and Earth Shock on cooldown; Lightning Bolt fills the gap while the target is out of reach. Health and mana are hidden from addons on Forever, so healing yourself and pausing to refill mana are your call (the Wowhead premade saves mana instead). Reminders: weapon imbue (Windfury, else Flametongue, else Rockbiter), Water or Lightning Shield, the Earth Shock interrupt, Searing or Magma Totem, group totems, Rage of the Farseer, Stoneclaw Totem. Left to you: totem presets, Frost Shock, Purge and other totems."
L["Default.Forever.Shaman.Enhancement.Wowhead.Name"] = "Forever Shaman: Enhancement, mana-efficient (Wowhead)"
L["Default.Forever.Shaman.Enhancement.Wowhead.Description"] = "Wowhead's and Mobalytics' mana-saving Enhancement: auto-attack does the work, Stormstrike only while Improved Stormstrike's mana regeneration is down, no Earth Shock in the rotation (shocks pull and interrupt), and in groups or on packs Searing Totem with Fire Nova on cooldown. Same imbue, shield and interrupt reminders as the Icy Veins premade. Choose it instead of that premade if mana runs out. An alternative to the recommended Enhancement premade, off by default: enable it and disable that one, or raise its priority."

L["Default.Forever.Warlock.DPS.Name"] = "Forever Warlock: all trees"
L["Default.Forever.Warlock.DPS.Description"] = "Every Warlock talent tree from level 1 to 60, merged from Icy Veins, Wowhead and Method; the steps for a tree appear once you know its talent spells. Pulls with Immolate and Bane of Agony (Destruction precasts Shadow Bolt), uses Nightfall and Decimation procs, keeps Demonic Brand up with Searing Pain. While moving it casts only instants. On packs: Hellfire in a group, Rain of Fire, Corruption and Agony. Then Bane of Doom on elites and bosses or Bane of Agony, Curse of the Elements in groups and on elites, Immolate, Corruption, Siphon Life, Conflagrate and Shadowburn; solo it fills with Wrack, Drain Life (with a drain talent) or the wand; otherwise Incinerate or Shadow Bolt. Reminders: armor, a demon (Succubus, else Voidwalker, else Imp), Fel Domination, Demonic Sacrifice with Demonic Pact, Soul Link, weapon stones, Amplify Curse and Bane of Havoc for a second enemy. Left to you: sending the pet in, other curses, Fear, Healthstones and other targets. Health and mana are hidden from addons on Forever, so the execute window (Drain Soul, Shadowburn as the killing blow), Life Tap, Health Funnel and draining when hurt are your call."
L["Default.Forever.Warlock.DPS.IcyVeins.Name"] = "Forever Warlock: all trees (Icy Veins)"
L["Default.Forever.Warlock.DPS.IcyVeins.Description"] = "Icy Veins' Warlock leveling: the wand is the solo filler, Voidwalker is the default demon, Affliction and Destruction sacrifice their demon and play without one (from 41 and 55), Demonology keeps Demonic Brand up and uses Immolate only as a filler, and Destruction puts Bane of Havoc on the durable enemy of a pack and Conflagrates on cooldown once Incinerate is known. Choose it instead of the recommended Warlock premade if you follow Icy Veins. Health, mana and time to die are hidden from addons on Forever, so Drain Life when hurt, Life Tap and which targets will live long enough for DoTs are your call. An alternative to the recommended Warlock DPS premade, off by default: enable it and disable that one, or raise its priority."
L["Default.Forever.Warlock.DPS.Wowhead.Name"] = "Forever Warlock: all trees (Wowhead)"
L["Default.Forever.Warlock.DPS.Wowhead.Description"] = "Wowhead's level-30 Warlock: Affliction and Demonology drain-tank with the Succubus (Corruption and Agony, no Immolate, then Drain Life for the rest of the fight; health and mana are hidden on Forever, so Life Tap is your call), Demonology keeps Demonic Brand up and Agonies only big targets, Destruction puts Agony, Corruption and Immolate on every mob, Conflagrates just before Immolate ends, saves Shadowburn for the killing blow and wands with the Voidwalker. Amplify Curse on every cooldown; Curse of the Elements and Bane of Doom only on elites and bosses; no pack section. Wowhead's guides stop at level 30. An alternative to the recommended Warlock DPS premade, off by default: enable it and disable that one, or raise its priority."

L["Default.Forever.Warrior.Protection.Name"] = "Forever Warrior: Protection (Icy Veins)"
L["Default.Forever.Warrior.Protection.Description"] = "Tanking whenever you are in Defensive Stance, from level 10 to 60. Charges to pull (in Defensive Stance once you have Vanguard), Victory Rush, and on two or more enemies Thunder Clap on cooldown, Demoralizing Shout, Shield Slam, Revenge and Rend. On one target: Shield Slam, Revenge, Demoralizing Shout, Rend, Sunder Armor (five on elites) and Thunder Clap on dangerous targets. Reminders: Battle Shout, Bloodrage, Shield Bash, Shield Block while you hold the target, Heroic Strike while Shield Slam and Revenge are both recovering, Cleave on packs; Taunt and Shield Wall are listed but off. Rage, health and the target's mana are hidden from addons on Forever, so the rage thresholds, casters and Last Stand are your call. Left to you: swapping to Battle Stance to Charge before Vanguard, taunting other enemies and picking up loose ones."
L["Default.Forever.Warrior.Protection.WarcraftTavern.Name"] = "Forever Warrior: Protection, debuff upkeep (Warcraft Tavern)"
L["Default.Forever.Warrior.Protection.WarcraftTavern.Description"] = "Warcraft Tavern's tanking order: Thunder Clap, Demoralizing Shout and five Sunder Armors kept on every target first, then Revenge, Rend and Shield Slam last, with Heroic Strike or Cleave whenever you can afford them (rage is hidden on Forever, so there is no 60-rage threshold). No Shield Block or defensive reminders. Choose it instead of the Icy Veins tank premade if you prefer to keep the debuffs up first. An alternative to the recommended Protection premade, off by default: enable it and disable that one, or raise its priority."
L["Default.Forever.Warrior.DPS.Name"] = "Forever Warrior: Arms and Fury (Icy Veins)"
L["Default.Forever.Warrior.DPS.Description"] = "Melee Arms and Fury from level 1 to 60, and the default for any warrior outside Defensive Stance. Forever rage is scarce and hidden from addons, so it pools by spending on anything else only while Mortal Strike or Bloodthirst is recovering: Charge to pull, Victory Rush, Intercept, Execute (in its range) on elites, bosses or in a group, Whirlwind or Thunder Clap, Demoralizing Shout and Slam on packs, Spearing Strike on Giants and Dragonkin, Rend until Bloodthirst, Overpower, Mortal Strike, Bloodthirst, then Whirlwind, Slam while standing and two Sunder Armors (five on elites). Reminders: Battle Shout, Bloodrage, the interrupt, Heroic Strike while the main strike recovers, Cleave on packs, Sweeping Strikes, Death Wish and Berserker Rage; Recklessness and Retaliation are listed but off. Left to you: stance dancing, Hamstring and consumables."
L["Default.Forever.Warrior.DPS.WarcraftTavern.Name"] = "Forever Warrior: Arms and Fury, spend rage (Warcraft Tavern)"
L["Default.Forever.Warrior.DPS.WarcraftTavern.Description"] = "Warcraft Tavern's always-spend list for groups and raids: five Sunder Armors first, Execute above everything below 20%, Overpower, Rend until Bloodthirst, Mortal Strike, Bloodthirst, Whirlwind, Spearing Strike on cooldown, Slam once Improved Slam is taken; Heroic Strike or Cleave whenever you can afford them (rage is hidden on Forever, so there is no 60-rage threshold or spare-rage Hamstring), Recklessness on cooldown with Death Wish beside it. Choose it instead of the Icy Veins premade if you play in groups and do not need to save rage between pulls. An alternative to the recommended melee DPS premade, off by default: enable it and disable that one, or raise its priority."

L["Default.Forever.Druid.Balance.Name"] = "Druid: Balance (Forever)"
L["Default.Forever.Druid.Balance.Description"] = "Balance from level 1 to 60, and the default for any Forever Druid no other premade fits (levels 1–9, untalented casters, solo Restoration). Pulls with Wrath; while moving, refreshes Moonfire, Insect Swarm and, in a group, Faerie Fire. Hurricane when three or more enemies are fighting you, then your own Moonfire and Insect Swarm, Starfire while Eclipse charges or Clearcasting are up, and Wrath; when you cannot afford Wrath it lets you melee. Health and mana are hidden from addons on Forever, so healing yourself and judging whether a target is worth a DoT are your call. Reminders: Mark of the Wild, Thorns while solo, Moonkin Form, a pre-pull Rejuvenation while solo, Nature's Grasp when a mob is on you, Innervate whenever it is ready in combat while solo. Form changes, crowd control, Barkskin and target choice stay with you. Built from level-30 beta guides; level 31–60 steps follow the class design and are untested."
L["Default.Forever.Druid.BalanceTavern.Name"] = "Druid: Balance, Multi-DoT (Forever, Warcraft Tavern)"
L["Default.Forever.Druid.BalanceTavern.Description"] = "Warcraft Tavern's Multi-DoT leveling style, an alternative to the recommended Balance premade, off by default: enable it and disable that one, or raise its priority. Pulls with Wrath, keeps your Moonfire and Insect Swarm on the target, roots it with Entangling Roots once both are running while another enemy is fighting you, then Wrath. No Starfire (the build skips Eclipse). Switching to the next enemy is up to you. Reminders: Mark of the Wild, Thorns while solo."
L["Default.Forever.Druid.Feral.Name"] = "Druid: Feral, Cat and Bear (Forever)"
L["Default.Forever.Druid.Feral.Description"] = "Cat and Bear in one premade, chosen by your form; it takes over once Feral is your main talent tree (or has 11 points), or when you shift into Cat or Bear Form. Cat: Ravage or Shred from Prowl, Faerie Fire, Rip at four combo points, Ferocious Bite once Rip runs, Rake, then Shred when the target is not facing you (Claw otherwise). Bear: Faerie Fire and Feral Charge at range, Demoralizing Roar in a group or on two enemies, Primal Bite, Swipe on three or more, Lacerate, Swipe. In caster form it suggests Cat Form (Bear before you have Cat). Reminders: Maul whenever you can afford it in Bear Form, Enrage, Berserk on big pulls or elites, Innervate while solo, Mark of the Wild, Thorns. Health, energy, rage and mana are hidden from addons on Forever, so powershifting, Frenzied Regeneration and healing yourself are your call. Taunts, interrupts and positioning stay with you."
L["Default.Forever.Druid.Restoration.Name"] = "Druid: Restoration (Forever)"
L["Default.Forever.Druid.Restoration.Description"] = "Group healing after Warcraft Tavern, once Restoration is your main talent tree with 11 points. Heals your current friendly target: Swiftmend on a target with your HoT, Wild Growth, Regrowth and Rejuvenation when missing, Healing Touch. Health and mana are hidden from addons on Forever, so the target you pick is the only sign of who needs healing. On a hostile target: Moonfire, Insect Swarm, Wrath. Reminders: Innervate in combat, Nature's Swiftness on a friendly target in combat, Remove Curse and Abolish Poison, Mark of the Wild; Tranquility is yours. You pick who to heal and the spell rank; solo Restoration uses the Balance premade."
L["Default.Forever.Druid.RestorationIcyVeins.Name"] = "Druid: Restoration, HoTs first (Forever, Icy Veins)"
L["Default.Forever.Druid.RestorationIcyVeins.Description"] = "Icy Veins' HoT-first healing, an alternative to the recommended Restoration premade, off by default: enable it and disable that one, or raise its priority. On your friendly target: Rejuvenation, then Regrowth when missing, Healing Touch only with both HoTs running, Swiftmend on a HoT target, then Wild Growth (health is hidden on Forever, so the target you pick decides who is healed). Innervate on cooldown. Otherwise the same reminders and hostile-target list as the Restoration premade."

L["Default.Forever.Hunter.Ranged.Name"] = "Hunter: ranged (Forever, Wowhead)"
L["Default.Forever.Hunter.Ranged.Description"] = "Every ranged Hunter from level 1 to 60 (Beast Mastery, Marksmanship, and Survival until Strider Kick), and the Forever Hunter default. Pull: Hunter's Mark, Sniper Shot while Rapid Killing lasts, Auto Shot. Then your own Serpent Sting, Summon Hawk twice and Arcane Shot once on their shared cooldown (Arcane Shot on cooldown before Summon Hawk), Sniper Shot under Rapid Killing or on elites, Aimed Shot. Two or more enemies fighting you: Multi-Shot instead of Aimed Shot, Explosive Trap with three near you, Volley on five. Moving: instant shots only. A mob in melee range gets Raptor Strike and Mongoose Bite. Reminders: Aspect of the Hawk (Monkey before it), Trueshot Aura, pet calling and reviving, Rapid Fire, Bestial Wrath and Blood Fury on elites or in dungeons, Intimidation when a mob is on you. Pet commands, feeding, kiting and Feign Death stay with you; disable the pet reminders if you play Lone Wolf. It never reads your mana or anyone's health, which Forever hides from addons, so Hunter's Mark and Serpent Sting go on every target and Mend Pet is yours."
L["Default.Forever.Hunter.RangedMobalytics.Name"] = "Hunter: ranged, mana-saving (Forever, Mobalytics)"
L["Default.Forever.Hunter.RangedMobalytics.Description"] = "Mobalytics' mana-saving leveling style, an alternative to the recommended Wowhead ranged premade, off by default: enable it and disable that one, or raise its priority. Keeps your Serpent Sting up, one Summon Hawk out, Aimed Shot (Multi-Shot on two or more enemies), and never Arcane Shot once Summon Hawk is known; its second Hawk on a healthy target is left out, as Forever hides target health. Same pull, melee, movement and reminders as the Wowhead premade."
L["Default.Forever.Hunter.Survival.Name"] = "Hunter: Survival melee (Forever, Wowhead)"
L["Default.Forever.Hunter.Survival.Description"] = "Dual-wield melee Survival once Survival is your main talent tree with 21 points, Strider Kick's tier (until then the ranged premade levels you, as the guides advise). Pull with Hunter's Mark and Serpent Sting, then Mongoose Bite, Strider Kick, Raptor Strike and Counterattack, with Explosive Trap on three or more enemies. Out of melee it shoots: Serpent Sting, Arcane Shot, Aimed Shot, Auto Shot. Reminders: Aspect of the Beast, Hunter's Mark (Expose Prey needs it), Rapid Fire and Blood Fury on elites or in dungeons, Deterrence while you hold the target's attention, pet care (health is hidden on Forever, so Mend Pet is yours). An optional Immolation Trap step is off by default."
L["Default.Forever.Hunter.SurvivalWeave.Name"] = "Hunter: Survival two-hand weave (Forever, Wowhead)"
L["Default.Forever.Hunter.SurvivalWeave.Description"] = "Wowhead's in-and-out weave for a two-handed Survival Hunter, an alternative to the recommended Survival melee premade, off by default: enable it and disable that one, or raise its priority. In melee: Mongoose Bite and Raptor Strike; when Raptor Strike is more than 2.5 seconds away, Strider Kick and step out. Out of melee: Serpent Sting, Arcane Shot, Aimed Shot and Auto Shot until Raptor Strike is nearly ready, then back in. You do the moving; RM follows your range."

L["Default.Forever.Mage.Frost.Name"] = "Mage: Frost (Forever)"
L["Default.Forever.Mage.Frost.Description"] = "Frost from level 1 to 60, and the Forever Mage default before talent spells (Fireball until Frostbolt at level 4). Pulls with Frostbolt; then Ice Lance on Fingers of Frost or a frozen target (also while Frostbolt is still casting, to cancel or batch), Cone of Cold at five Winter's Chill stacks, Arcane Missiles on Missile Barrage, Frostbolt, and a wand when solo and you cannot afford Frostbolt. Moving: Ice Lance, else Fire Blast. Three or more enemies fighting you: Cone of Cold; five or more: Blizzard, or Arcane Explosion with a mob on you. Warcraft Tavern's Flamestrike and Arcane Explosion AoE is included but off. Reminders: Arcane Intellect, armor (Ice or Frost solo, Mage Armor in a group, never replacing one you chose), Ice Barrier, Counterspell, Remove Lesser Curse, Frost Nova when a mob reaches you, Cold Snap. Health and mana are hidden from addons on Forever, so finishing low targets with Fire Blast, Evocation and Ice Block are your call; Blink, kiting, Polymorph and mana gems stay with you too."
L["Default.Forever.Mage.Fire.Name"] = "Mage: Fire (Forever)"
L["Default.Forever.Mage.Fire.Description"] = "Fire once Fire is your main talent tree with 11 points (Pyroblast's tier). Pulls with Pyroblast on elites, else Frostfire Bolt or Fireball; then Pyroblast at three Heating Up stacks, Ice Lance on Fingers of Frost or a frozen target (Fire/Frost hybrids), Fire Blast on cooldown, Scorch to keep your five Fire Vulnerability stacks on elites, Frostfire Bolt (from 40) or Fireball, wand when solo and you cannot afford a spell. Moving: Fire Blast or Ice Lance. Four or more enemies fighting you: Flamestrike, Blast Wave, Arcane Explosion. Scorch starts the stacks only once you have Improved Scorch; a close-range Scorch is off until you enable it. Reminders: Combustion and Presence of Mind on elites, plus the Mage upkeep reminders."
L["Default.Forever.Mage.FireIcyVeins.Name"] = "Mage: Fire leveling (Forever, Icy Veins)"
L["Default.Forever.Mage.FireIcyVeins.Description"] = "Icy Veins' Fire leveling build without Improved Scorch, an alternative to the recommended Fire premade, off by default: enable it and disable that one, or raise its priority. Pulls with Pyroblast, uses Fire Blast to spend Wake of Fire, Scorch as the mob closes (target health is hidden on Forever, so its low-target finishers are yours), then Frostfire Bolt (from 40) or Fireball. Same AoE, movement, wand and reminders as the Fire premade, without Combustion and Presence of Mind."
L["Default.Forever.Mage.Arcane.Name"] = "Mage: Arcane (Forever)"
L["Default.Forever.Mage.Arcane.Description"] = "Arcane once Arcane is your main talent tree with 11 points and you know Arcane Blast. Pulls with Frostbolt solo or Arcane Blast in a group; then Arcane Missiles on Missile Barrage, Arcane Blast on Clearcasting, Arcane Wrath at three Arcane Blast stacks, Arcane Blast up to four stacks on elites and two on other targets while you can afford it (mana is hidden on Forever), then Frostfire Bolt, Frostbolt or Fireball to fish for Missile Barrage, and a wand when solo and you cannot afford a spell. Without Arcane Wrath (the older beta design) Fire Blast spends the stacks. Moving: Fire Blast. Three or more enemies fighting you: Arcane Explosion. Reminders: Presence of Mind and Arcane Power on elites (Arcane Power no longer waits for half your mana), plus the Mage upkeep reminders."

L["Default.Forever.Paladin.Retribution.Name"] = "Paladin: Retribution (Forever)"
L["Default.Forever.Paladin.Retribution.Description"] = "Retribution and every melee Paladin from level 1 to 60, and the Forever Paladin default. Keeps a damage seal up, refreshed only when it runs low: Seal of the Crusader judged once on an elite target, then Seal of Command with a slow (3.0 s) weapon, else Seal of Righteousness. Then Holy Strike on cooldown, Holy Shock and Light's Vigil for a Shockadin, Exorcism on Undead and Demons, Consecration on three or more enemies, Hammer of Wrath when it can be cast, and melee. Judgement is off the global cooldown, so it is a reminder whenever a seal is up. Other reminders: your aura and Blessing (Retribution Aura and Kings once learned; yours are kept). Optional step, off by default: Hammer of Justice before a Seal of Command Judgement. Mana, health and the swing timer are hidden from addons on Forever, so mana saving, healing yourself, Lay on Hands and Twist of Light seal swapping are your call. Built from level-30 beta guides."
L["Default.Forever.Paladin.Protection.Name"] = "Paladin: Protection (Forever, Wowhead)"
L["Default.Forever.Paladin.Protection.Description"] = "Tanking, once Protection is your main talent tree or you turn on Righteous Fury. When the target is fighting someone else: Judgement with Seal of Fury (the taunt), Swift Judgement to reset it. Two or more enemies engaged: Consecration, Exorcism and Holy Wrath on Undead and Demons, Holy Strike. One enemy: Exorcism on Undead and Demons, Holy Strike, Consecration. Reminders: Righteous Fury, Seal of Fury, Judgement on cooldown, Holy Shield while tanking, your aura and Blessing. Health and mana are hidden from addons on Forever, so Templar's Bulwark and Lay on Hands are your call. Pulling, positioning and other taunts stay with you."
L["Default.Forever.Paladin.ProtectionIcyVeins.Name"] = "Paladin: Protection, Consecration first (Forever, Icy Veins)"
L["Default.Forever.Paladin.ProtectionIcyVeins.Description"] = "Icy Veins' tanking style, an alternative to the recommended Wowhead Protection premade, off by default: enable it and disable that one, or raise its priority. Consecration first whenever you can afford it, on one enemy too; Judgement is kept for taunts (no on-cooldown reminder), with Swift Judgement to reset it; then Holy Strike and Exorcism on Undead and Demons. Same tank reminders otherwise."
L["Default.Forever.Paladin.Holy.Name"] = "Paladin: Holy (Forever)"
L["Default.Forever.Paladin.Holy.Description"] = "Group healing once Holy is your main talent tree with 21 points (Holy Shock's tier), while Righteous Fury is off (a grouped Shockadin lands here too). Heals your current friendly target: Holy Shock on a target with your Light's Vigil, Light's Vigil in combat, Cleanse or Purify, Holy Shock while moving, Holy Light with Infusion of Light, Flash of Light as the main heal. On an enemy: Judgement of Light when Seal of Light is up, Holy Shock, Light's Vigil, Holy Strike, Exorcism. Reminders: Seal of Light when you have no seal, Divine Favor in combat on a friendly target, your aura and Blessing. Health and mana are hidden from addons on Forever, so the target you pick is the only sign of who needs healing; emergency Holy Shocks, big Holy Lights and Lay on Hands are your call."
L["Default.Forever.Paladin.HolyWowhead.Name"] = "Paladin: Holy, Holy Shock on cooldown (Forever, Wowhead)"
L["Default.Forever.Paladin.HolyWowhead.Description"] = "Wowhead's healing style, an alternative to the recommended Holy premade, off by default: enable it and disable that one, or raise its priority. Holy Shock as a routine heal on cooldown, dispels, Flash of Light (health is hidden on Forever, so Holy Light for big deficits is your call). On an enemy it keeps your Judgement of Light up by swapping to Seal of Light, judging and swapping back to Seal of Righteousness, then Holy Strike, Exorcism on Undead and Demons, Holy Shock and Consecration. Same reminders as the Holy premade."

L["Default.Forever.Priest.Dps.Name"] = "Priest: Shadow and solo damage (Forever)"
L["Default.Forever.Priest.Dps.Description"] = "Shadow, and every Priest's solo play, from level 1 to 60; the Forever Priest default. Pulls with Power Word: Shield (solo) and Mind Blast (Holy Fire for Holy and Discipline, Smite before Mind Blast). Then Shadowform once learned, your own Shadow Word: Pain and Devouring Plague, Mind Blast, Holy Fire into Penance for Discipline, Mind Flay in Shadowform; solo before Shadowform, Holy Nova on three enemies with Holy Purpose, then the wand (Smite without one). Moving: Pain, Plague. Reminders: Inner Fire, Fortitude, Divine Spirit, racial buffs, Vampiric Embrace, Inner Focus, Silence, Elune's Light; Psychic Scream is off by default. Health and mana are hidden from addons on Forever, so executing with Shadow Word: Death, healing yourself and Dark Sacrifice are your call. Built from level-30 beta guides; Shadowform play follows Mobalytics."
L["Default.Forever.Priest.DpsMobalytics.Name"] = "Priest: DoT and wand leveling (Forever, Mobalytics)"
L["Default.Forever.Priest.DpsMobalytics.Description"] = "Mobalytics' leveling style, an alternative to the recommended Shadow premade, off by default: enable it and disable that one, or raise its priority. Mind Blast and Holy Fire only on tough mobs (elites, or two levels above you), your own Shadow Word: Pain and Devouring Plague, then the wand (Smite without one). From Shadowform: Mind Blast, Pain, Plague, Mind Flay. Shield and Renew on yourself between pulls, Cure Disease on yourself. Health and mana are hidden from addons on Forever, so healing yourself is your call. Spreading Pain across several mobs is up to you."
L["Default.Forever.Priest.Healer.Name"] = "Priest: Discipline and Holy healing (Forever)"
L["Default.Forever.Priest.Healer.Description"] = "Group healing once Discipline or Holy is your main talent tree and you do not know Shadowform. Heals your current friendly target: before the pull Power Word: Shield, Prayer of Mending and Renew; Dispel Magic and Abolish or Cure Disease; Prayer of Mending; Holy Nova on Holy Purpose; Penance; Renew when missing; Heal (Lesser Heal before it). On an enemy: Shadow Word: Pain, Holy Fire, Penance, Smite, wand. Reminders: Inner Fire, Fortitude, Divine Spirit, Power Infusion on another player, Inner Focus in combat and the racial spells. Health and mana are hidden from addons on Forever, so the target you pick is the only sign of who needs healing; emergency heals, Prayer of Healing, Binding Heal, Greater and Flash Heal, Desperate Prayer and Dark Sacrifice are your call. You pick who to heal and the rank; a Discipline healer before Penance (20–29) selects it by hand."

L["Default.Retail.DeathKnight.Blood.Name"] = "Death Knight: Blood (Retail, Blizzard Assisted)"
L["Default.Retail.DeathKnight.Blood.Description"] = "Recommended for Blood. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Vampiric Blood and Raise Dead in combat, Mind Freeze on an interruptible cast, and Icebound Fortitude and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so Mind Freeze lights only where the game shows them; health is hidden on Retail, so when to use Icebound Fortitude is your call. Active mitigation timing, Anti-Magic Shell, taunts and trinkets stay with you."
L["Default.Retail.DeathKnight.BloodGuide.Name"] = "Death Knight: Blood reference (Retail, Icy Veins and Wowhead)"
L["Default.Retail.DeathKnight.BloodGuide.Description"] = "Reference only, off by default: the guides' Blood priority. In Midnight combat your buffs and the target's debuffs are hidden from addons, so the steps that read them wait there; read it, or clone it to experiment. Health and runic power are hidden on Retail, so Death Strike is used whenever you can afford it. Pulls with Death's Caress. Death Strike; Marrowrend (Death's Caress out of melee) when Bone Shield is missing, under five charges, about to expire, or Exterminate is up; during Gift of the San'layn, Death Strike, one Blood Boil, Death and Decay on Crimson Scourge and Heart Strike; Death and Decay on Crimson Scourge or four enemies; Vampiric Strike; Consumption; Blood Boil on Boiling Point, a missing Blood Plague or full charges; Heart Strike. Reminders: Raise Dead, Vampiric Blood, Reaper's Mark, Dancing Rune Weapon after Reaper's Mark, plus the Assisted premade's utility reminders."
L["Default.Retail.DeathKnight.BloodSimc.Name"] = "Death Knight: Blood Deathbringer reference (Retail, SimulationCraft)"
L["Default.Retail.DeathKnight.BloodSimc.Description"] = "Reference only, off by default: SimulationCraft's Deathbringer list, which spends runic power on Death Strike for damage. Hidden combat data keeps it from running in Midnight combat, and runic power is hidden on Retail, so there is no cap dump. Death and Decay whenever it is down, Reaper's Mark, Marrowrend on Exterminate, Death's Caress for Bone Shield while runes are short (else Marrowrend), Death Strike, Blood Boil, Consumption outside Dancing Rune Weapon, Heart Strike. Reminders: Raise Dead, Dancing Rune Weapon, Vampiric Blood and the utility reminders."
L["Default.Retail.DeathKnight.Frost.Name"] = "Death Knight: Frost (Retail, Blizzard Assisted)"
L["Default.Retail.DeathKnight.Frost.Description"] = "Recommended for Frost. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Breath of Sindragosa and Raise Dead in combat, Mind Freeze on an interruptible cast, and Icebound Fortitude and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so Mind Freeze lights only where the game shows them; health is hidden on Retail, so when to use Icebound Fortitude is your call."
L["Default.Retail.DeathKnight.FrostGuide.Name"] = "Death Knight: Frost reference (Retail, Icy Veins and SimulationCraft)"
L["Default.Retail.DeathKnight.FrostGuide.Description"] = "Reference only, off by default: the guides' Frost priority. Killing Machine, Rime and Razorice are hidden in Midnight combat, so it cannot run there; runic power is hidden on Retail, so there is no cap check. Obliterate on two Killing Machines or one with three runes, Frost Strike into five Razorice with Shattering Blade, Howling Blast on Rime, Obliterate on Killing Machine, Frost Strike, Obliterate; three or more enemies swap in Frostscythe and Glacial Advance; Howling Blast out of melee. Reminders: Remorseless Winter, Pillar of Frost, Breath of Sindragosa and Frostwyrm's Fury in Pillar, Reaper's Mark, Raise Dead, Empower Rune Weapon at two charges, plus the utility reminders."
L["Default.Retail.DeathKnight.FrostWowhead.Name"] = "Death Knight: Frost reference (Retail, Wowhead)"
L["Default.Retail.DeathKnight.FrostWowhead.Description"] = "Reference only, off by default: Wowhead's Frost order, which puts its cooldowns in the rotation. Hidden combat data keeps it from running in Midnight combat; runic power is hidden on Retail, so there is no cap check. Empower Rune Weapon at two charges, Reaper's Mark, Pillar of Frost, Breath of Sindragosa, Frostwyrm's Fury; then Obliterate on two Killing Machines or one with Exterminate, Howling Blast on Rime, Obliterate on Killing Machine, Empower Rune Weapon for a new one, Frost Strike, Obliterate, Howling Blast. Three or more enemies swap in Frostscythe and Glacial Advance."
L["Default.Retail.DeathKnight.Unholy.Name"] = "Death Knight: Unholy (Retail, Blizzard Assisted)"
L["Default.Retail.DeathKnight.Unholy.Description"] = "Recommended for Unholy. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it raises your ghoul and uses Army of the Dead and Dark Transformation itself); it waits while you cast or channel. Alongside it: Mind Freeze on an interruptible cast, and Icebound Fortitude and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so Mind Freeze lights only where the game shows them; health is hidden on Retail, so when to use Icebound Fortitude is your call."
L["Default.Retail.DeathKnight.UnholyGuide.Name"] = "Death Knight: Unholy reference (Retail, Icy Veins and Wowhead)"
L["Default.Retail.DeathKnight.UnholyGuide.Description"] = "Reference only, off by default: the guides' Unholy priority. Procs and plagues are hidden in Midnight combat, so it cannot run there; runic power and the target's health are hidden on Retail, so the execute window and the San'layn runic power spend are left out. Raise Dead without a ghoul; Festering Scythe to keep its plague haste up; Soul Reaper on Reaping; Putrefy during Dark Transformation; Death Coil (Epidemic on four or more enemies) on Sudden Doom or Forbidden Knowledge; Festering Strike with no Lesser Ghoul charges, Scourge Strike with them; Death Coil. Reminders: Army of the Dead, Dark Transformation, Outbreak when your plagues are missing, plus the utility reminders."
L["Default.Retail.DeathKnight.UnholySimc.Name"] = "Death Knight: Unholy reference (Retail, SimulationCraft)"
L["Default.Retail.DeathKnight.UnholySimc.Description"] = "Reference only, off by default: SimulationCraft's Unholy list, which spends Death Coil far more often. Hidden combat data keeps it from running in Midnight combat; runic power and target health are hidden on Retail, so the cap and execute checks are left out. Festering Scythe upkeep, Soul Reaper in Dark Transformation, Death Coil on Sudden Doom, Putrefy in Dark Transformation, Death Coil in Dark Transformation or Forbidden Knowledge and whenever Army of the Dead is over 5 seconds away, Scourge Strike with Lesser Ghoul charges, Festering Strike. Three or more enemies: Epidemic for Death Coil and Festering Strike below three charges. Reminders: Outbreak, Death and Decay on packs, Army of the Dead, Dark Transformation."
L["Default.Retail.DeathKnight.Initial.Name"] = "Death Knight: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.DeathKnight.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Death Knight's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Death Knight premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.DemonHunter.Havoc.Name"] = "Demon Hunter: Havoc (Retail, Blizzard Assisted)"
L["Default.Retail.DemonHunter.Havoc.Description"] = "Recommended for Havoc. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what the game's assistant leaves to you: Metamorphosis and The Hunt in combat, Vengeful Retreat if you have Inertia or Exergy, Disrupt on an interruptible cast, and Blur whenever it is ready in combat. Enemy casts are hidden in combat, so Disrupt lights only where the game shows them; health is hidden on Retail, so when to use Blur is your call. Movement, Darkness and trinkets stay with you."
L["Default.Retail.DemonHunter.HavocGuide.Name"] = "Demon Hunter: Havoc reference (Retail, Icy Veins, SimulationCraft and Wowhead)"
L["Default.Retail.DemonHunter.HavocGuide.Description"] = "Reference only, off by default: the guides' Havoc priority. Your procs, Metamorphosis and Essence Break are hidden from addons in Midnight combat, so this list cannot run there; read it, or clone it to experiment. Fury is hidden on Retail, so Felblade does not wait for room. Aldrachi Reaver: Reaver's Glaive when neither Rending Strike nor Glaive Flurry is up, Chaos Strike on Rending Strike. Fel-Scarred: Essence Break, Blade Dance and Chaos Strike in Metamorphosis. Then Blade Dance and Chaos Strike inside Essence Break, Immolation Aura at two charges, Eye Beam, Felblade for Inertia, Essence Break when Eye Beam is over 4 seconds away, Blade Dance, Immolation Aura on two enemies, Chaos Strike, Felblade, Immolation Aura, Throw Glaive, Fel Rush. Reminders: Metamorphosis once Eye Beam and Blade Dance are spent, The Hunt, Vengeful Retreat, plus Disrupt and Blur."
L["Default.Retail.DemonHunter.Vengeance.Name"] = "Demon Hunter: Vengeance (Retail, Blizzard Assisted)"
L["Default.Retail.DemonHunter.Vengeance.Description"] = "Recommended for Vengeance. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what the assistant leaves to you: Demon Spikes, Fiery Brand, Fel Devastation and Metamorphosis whenever they are ready in combat, Disrupt on an interruptible cast, and Blur whenever it is ready in combat. Enemy casts are hidden in combat, so Disrupt lights only where the game shows them; health is hidden on Retail, so when to use Blur is your call. Infernal Strike, Darkness, taunts and trinkets stay with you."
L["Default.Retail.DemonHunter.VengeanceGuide.Name"] = "Demon Hunter: Vengeance reference (Retail, Wowhead and Icy Veins)"
L["Default.Retail.DemonHunter.VengeanceGuide.Description"] = "Reference only, off by default: Wowhead's Vengeance order with Icy Veins' hero-tree goals. Your buffs are hidden in Midnight combat, so it cannot run there; Fury is hidden on Retail, so spenders wait only for their cost and builders do not avoid capping. Aldrachi Reaver: Reaver's Glaive, Fracture on Rending Strike, Soul Cleave on Glaive Flurry. Then Fracture at full charges, Spirit Bomb on three or more enemies, Immolation Aura, Sigil of Flame, Soul Cleave against one target, Fel Devastation, Soul Cleave, Fracture, Felblade, Throw Glaive. Rotation Master cannot count Soul Fragments, so Spirit Bomb follows the enemy count. Reminders: Demon Spikes when it is down, Metamorphosis, Fiery Brand, Sigil of Spite, Soul Carver (Infernal Strike at two charges is off), plus Disrupt and Blur."
L["Default.Retail.DemonHunter.VengeanceSimc.Name"] = "Demon Hunter: Vengeance reference (Retail, SimulationCraft)"
L["Default.Retail.DemonHunter.VengeanceSimc.Description"] = "Reference only, off by default: SimulationCraft's Vengeance lists. Hidden combat data keeps it from running in Midnight combat, and Fury is hidden on Retail, so its Fury thresholds are left out. Aldrachi Reaver: Sigil of Flame and Immolation Aura first, Metamorphosis, the Reaver's Glaive cycle with Felblade, Fiery Brand, Sigil of Spite, Spirit Bomb on packs, Soul Carver in Fiery Demise, then Fracture, Soul Cleave, Felblade, Fel Devastation. Annihilator: spend a ready Voidfall with Spirit Bomb or Soul Cleave, Fracture at two Voidfall stacks, Metamorphosis, Spirit Bomb, Sigil of Spite, Fracture at full charges, Immolation Aura, Sigil of Flame, Fracture, Soul Cleave, Felblade, Throw Glaive. Reminders: Demon Spikes, Disrupt, Blur."
L["Default.Retail.DemonHunter.Devourer.Name"] = "Demon Hunter: Devourer (Retail, Blizzard Assisted)"
L["Default.Retail.DemonHunter.Devourer.Description"] = "Recommended for Devourer. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel Void Ray. Alongside it, reminders for what the assistant leaves to you: Void Metamorphosis, The Hunt and Voidblade whenever they are ready in combat, Disrupt on an interruptible cast, and Blur whenever it is ready in combat. Enemy casts are hidden in combat, so Disrupt lights only where the game shows them; health is hidden on Retail, so when to use Blur is your call."
L["Default.Retail.DemonHunter.DevourerGuide.Name"] = "Demon Hunter: Devourer reference (Retail, Icy Veins)"
L["Default.Retail.DemonHunter.DevourerGuide.Description"] = "Reference only, off by default: Icy Veins' Annihilator priority. Most of your buffs are hidden in Midnight combat, so it cannot run there; Fury is hidden on Retail, so Void Ray waits only for its cost. Outside Void Metamorphosis: Consume on Soulburst, Reap, Soul Immolation when it is not burning, Voidblade and The Hunt once Void Metamorphosis is ready, Void Metamorphosis, Hungering Slash, Void Ray, Consume. Inside it: Devour on Soulburst, Void Ray, the Void-Scarred strikes if you have them, Collapsing Star, Cull, Devour, Soul Immolation. Rotation Master cannot count Soul Fragments, so Reap and Cull go on cooldown. Reminders: Disrupt and Blur."
L["Default.Retail.DemonHunter.DevourerSimc.Name"] = "Demon Hunter: Devourer reference (Retail, SimulationCraft)"
L["Default.Retail.DemonHunter.DevourerSimc.Description"] = "Reference only, off by default: SimulationCraft's Annihilator list, which enters Void Metamorphosis as soon as it is ready. Hidden combat data keeps it from running in Midnight combat. Outside: Voidblade with Devourer's Bite on up to three enemies and a full Void Metamorphosis, Void Metamorphosis, Consume on Soulburst, Reap, Void Ray, Soul Immolation on packs, Consume. Inside: Devour on Soulburst against one target, The Hunt and Voidblade with Devourer's Bite, Void Ray on packs, Collapsing Star, Cull, Void Ray, Soul Immolation, Devour. Reminders: Disrupt and Blur."
L["Default.Retail.DemonHunter.Initial.Name"] = "Demon Hunter: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.DemonHunter.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Demon Hunter's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Demon Hunter premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Druid.Balance.Name"] = "Druid: Balance (Retail, Blizzard Assisted)"
L["Default.Retail.Druid.Balance.Description"] = "Recommended for Balance. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Celestial Alignment (or Incarnation) in combat, Solar Beam on an interruptible cast, Moonkin Form and Mark of the Wild between pulls, and Barkskin and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so Solar Beam lights only where the game shows them; health is hidden on Retail, so when to use Barkskin is your call."
L["Default.Retail.Druid.BalanceGuide.Name"] = "Druid: Balance reference (Retail, Icy Veins, SimulationCraft and Wowhead)"
L["Default.Retail.Druid.BalanceGuide.Description"] = "Reference only, off by default: the guides' Balance priority. Your DoTs, Eclipse and procs are hidden from addons in Midnight combat, so it cannot run there; read it, or clone it to experiment. Astral Power is hidden on Retail, so Starsurge spends at its cost instead of before the cap. Pulls with Moonkin Form and Wrath. Sunfire and Moonfire when missing or about to fall off; Eclipse when neither is active (Lunar on three or more enemies, Solar otherwise); Starfall on Starweaver's Warp, Touch the Cosmos or packs; Starsurge on Starweaver's Weft or Touch the Cosmos; New, Half and Full Moon; Wild Mushroom in an Eclipse; Starsurge whenever you can afford it; Starfire in a Lunar Eclipse or on packs, else Wrath. Reminders: Celestial Alignment or Incarnation, Fury of Elune and Force of Nature before an Eclipse, Convoke in Celestial Alignment, Solar Beam, plus the utility reminders."
L["Default.Retail.Druid.Feral.Name"] = "Druid: Feral (Retail, Blizzard Assisted)"
L["Default.Retail.Druid.Feral.Description"] = "Recommended for Feral. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Berserk (or Incarnation) in combat, Skull Bash on an interruptible cast, Survival Instincts, Barkskin and your racial cooldown whenever they are ready in combat, and Cat Form and Mark of the Wild between pulls. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use the defensives is your call."
L["Default.Retail.Druid.FeralGuide.Name"] = "Druid: Feral reference (Retail, Icy Veins and SimulationCraft)"
L["Default.Retail.Druid.FeralGuide.Description"] = "Reference only, off by default: the guides' Feral priority. Bleeds and procs are hidden in Midnight combat (combo points are not), so it cannot run there; energy is hidden on Retail. Opens with Cat Form, Prowl and Rake. Chomp; Ferocious Bite on Apex Predator's Craving; at five combo points Primal Wrath on two or more enemies, Rip when missing or in its last seconds, else Ferocious Bite, waiting for energy rather than building past five; below five, Rake when missing or about to fall off, Lunar Inspiration Moonfire, Swipe on three or more enemies, Shred. Reminders: Tiger's Fury whenever it is ready in combat, Berserk or Incarnation and Feral or Frantic Frenzy (at two points or fewer) in Tiger's Fury, Convoke in Tiger's Fury and Berserk with Rip up, Skull Bash, Survival Instincts, plus the utility reminders. Snapshotting is left to you."
L["Default.Retail.Druid.Guardian.Name"] = "Druid: Guardian (Retail, Blizzard Assisted)"
L["Default.Retail.Druid.Guardian.Description"] = "Recommended for Guardian. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; Assisted Combat plays for damage only. Alongside it, reminders for what it leaves to you: Berserk (or Incarnation) and Convoke the Spirits in combat, Ironfur, Frenzied Regeneration, Survival Instincts, Barkskin and your racial cooldown whenever they are ready in combat, Skull Bash on an interruptible cast, and Bear Form and Mark of the Wild between pulls. Enemy casts are hidden in combat, so Skull Bash lights only where the game shows them; health and rage are hidden on Retail, so when to use the defensives is your call and Ironfur cannot wait for a rage threshold."
L["Default.Retail.Druid.GuardianGuide.Name"] = "Druid: Guardian reference (Retail, Icy Veins and Wowhead)"
L["Default.Retail.Druid.GuardianGuide.Description"] = "Reference only, off by default: the guides' Guardian priority. Debuffs and procs are hidden in Midnight combat, so it cannot run there; rage and health are hidden on Retail, so the 80-rage Raze and Maul dump is left to you. Thrash and Mangle on cooldown, Red Moon on a single target, Moonfire when missing or on Galactic Guardian, Swipe. Reminders whenever they are ready in combat: Ironfur, Frenzied Regeneration, Survival Instincts; Bear Form between pulls; Berserk or Incarnation, Lunar Beam, Convoke, Heart of the Wild, Skull Bash, plus the utility reminders."
L["Default.Retail.Druid.GuardianSimc.Name"] = "Druid: Guardian defensive reference (Retail, SimulationCraft)"
L["Default.Retail.Druid.GuardianSimc.Description"] = "Reference only, off by default: SimulationCraft's Guardian list, which spends rage on Ironfur first. Hidden combat data keeps it from running in Midnight combat, and rage is hidden on Retail, so its rage thresholds are left out. Ironfur in Berserk; Thrash when missing, about to fall off or under three stacks; Maul on Gory Fur; Thrash on three or more enemies; Mangle while Red Moon ticks; Red Moon; Mangle; Thrash; Moonfire; Swipe. Its cat-form weaving is left out. Reminders: Bear Form, Frenzied Regeneration, Survival Instincts, Berserk or Incarnation, Lunar Beam, Convoke, Skull Bash, plus the utility reminders."
L["Default.Retail.Druid.Restoration.Name"] = "Druid: Restoration (Retail)"
L["Default.Retail.Druid.Restoration.Description"] = "Recommended for Restoration. With an enemy targeted it highlights Blizzard's Assisted Combat suggestion, Blizzard's Restoration damage list in cat or caster form. Otherwise it suggests Icy Veins' maintenance casts on your friendly target (or yourself): Lifebloom, Efflorescence in combat, Swiftmend on a Rejuvenation, Wild Growth in a group in combat, Regrowth on Clearcasting or five Abundance stacks, Rejuvenation when missing. Health and mana are hidden on Retail, so these follow the target you choose, not how hurt anyone is; your heals over time are hidden in Midnight combat, so the steps that read them wait there. Whom to heal, and every healing cooldown, is yours. Reminders: Innervate, Barkskin and your racial cooldown whenever they are ready in combat, Mark of the Wild between pulls."
L["Default.Retail.Druid.Initial.Name"] = "Druid: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Druid.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Druid's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Druid premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Evoker.Devastation.Name"] = "Evoker: Devastation (Retail, Blizzard Assisted)"
L["Default.Retail.Evoker.Devastation.Description"] = "Recommended for Devastation. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast, channel Disintegrate or hold an empowered spell. Choosing the empower rank is up to you. Alongside it, reminders in combat for Dragonrage, Deep Breath and Tip the Scales, Quell on an interruptible cast and Obsidian Scales whenever it is ready, and out of combat Blessing of the Bronze when it is missing and Source of Magic on a friendly target in your group. Enemy casts are hidden in combat, so Quell lights only where the game shows them; health is hidden on Retail, so when to use Obsidian Scales is your call."
L["Default.Retail.Evoker.DevastationGuide.Name"] = "Evoker: Devastation reference (Retail, SimulationCraft and Icy Veins)"
L["Default.Retail.Evoker.DevastationGuide.Description"] = "Reference only, off by default: the optimal Devastation priority. Procs, cooldowns and the target's burn are hidden in Midnight combat, so it cannot run there; read it, or clone it to experiment. Pulls with Living Flame. Scalecommander (Mass Disintegrate known): Eternity Surge, Fire Breath, Deep Breath on two or more enemies, Disintegrate with Mass Disintegrate charges, Pyre on five or more, Disintegrate, Living Flame on Burnout with Leaping Flames, Unbound Flame below two Essence Bursts, Azure Sweep. Flameshaper: Eternity Surge, Fire Breath when its burn is missing or ending, Pyre on five or more, Disintegrate, Deep Breath on four or more, Unbound Flame, Living Flame on Burnout with Leaping Flames, Azure Sweep. Then Azure Strike while moving, Living Flame, Azure Strike. Use empowers at rank 1 on one target (Icy Veins). Reminders: Dragonrage, Tip the Scales in Dragonrage or with Fire Breath ready, Deep Breath for Scalecommander, plus the utility reminders."
L["Default.Retail.Evoker.Augmentation.Name"] = "Evoker: Augmentation (Retail, Icy Veins)"
L["Default.Retail.Evoker.Augmentation.Description"] = "Recommended for Augmentation: Icy Veins' Ebon Might priority. Ebon Might is one of the few buffs the game still shows addons in Midnight combat, so its upkeep works there. Out of combat: Blistering Scales on a friendly group target without it, Living Flame on an enemy. Then Ebon Might when missing or under 4 seconds, and on cooldown unless Breath of Eons is ready; Prescience; Fire Breath; Upheaval; Eruption in Ebon Might or with two Essence Bursts; Azure Strike; Living Flame. Hidden buffs only skip their own step in combat. Reminders: Breath of Eons and Deep Breath (you aim them), Tip the Scales with Fire Breath ready, Time Skip with Fire Breath and Upheaval both cooling, plus the utility reminders. Prescience and Blistering Scales go on your target: choosing the ally, and the empower rank, is up to you."
L["Default.Retail.Evoker.AugmentationAssisted.Name"] = "Evoker: Augmentation (Retail, Blizzard Assisted)"
L["Default.Retail.Evoker.AugmentationAssisted.Description"] = "Blizzard's Assisted Combat suggestion for Augmentation, an alternative to the recommended Icy Veins Augmentation premade, off by default: enable it and disable that one, or raise its priority. It recasts Ebon Might only after it has fallen off, and waits while you cast or hold an empowered spell. Reminders in combat for Breath of Eons, Deep Breath, Tip the Scales and Time Skip, plus Quell, Obsidian Scales, Blessing of the Bronze and Source of Magic as in the other Evoker premades."
L["Default.Retail.Evoker.Preservation.Name"] = "Evoker: Preservation reference (Retail, Icy Veins)"
L["Default.Retail.Evoker.Preservation.Description"] = "Reference only, off by default. Ally health, Echo, Reversion, Essence Burst and every cooldown are hidden from addons in Midnight combat, Rotation Master cannot choose whom to heal, and Blizzard has no Assisted Combat rotation for healers, so this premade does not heal. It reminds you of Blessing of the Bronze and Source of Magic out of combat, and when your target is an enemy it suggests damage: Fire Breath, Disintegrate, Living Flame, and Azure Strike while moving. Quell and Obsidian Scales reminders as in the other Evoker premades. Healing stays with you."
L["Default.Retail.Evoker.Initial.Name"] = "Evoker: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Evoker.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Evoker's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Evoker premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Hunter.BeastMastery.Name"] = "Hunter: Beast Mastery (Retail, Blizzard Assisted)"
L["Default.Retail.Hunter.BeastMastery.Description"] = "Recommended for Beast Mastery. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it calls your pet itself); it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Bloodshed and your racial cooldown in combat, Counter Shot on an interruptible cast, and Survival of the Fittest whenever it is ready in combat. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use your defensives (Exhilaration and Aspect of the Turtle included) is your call. Trinkets, Misdirection and pet care stay with you."
L["Default.Retail.Hunter.BeastMasteryGuide.Name"] = "Hunter: Beast Mastery reference (Retail, SimulationCraft and Icy Veins)"
L["Default.Retail.Hunter.BeastMasteryGuide.Description"] = "Reference only, off by default: the optimised Beast Mastery priority. Charges, cooldowns and procs are hidden from addons in Midnight combat, so it cannot run there; read it, or clone it to experiment. Focus is hidden on Retail. Calls your pet, marks the target before the pull. Barbed Shot just before Bestial Wrath or before it caps; Bestial Wrath; Kill Command on Howl of the Pack Leader or Nature's Ally, or freely while Bestial Wrath is far off; Cobra Shot on Cobra Fang; Cobra Shot; Barbed Shot when Cobra Shot is unaffordable. Dark Ranger: Black Arrow during Withering Fire and Wailing Arrow as it ends. Three or more enemies (two with Beast Cleave): Wild Thrash to start Beast Cleave, then Kill Command, Barbed Shot and Cobra Shot while it lasts. Reminders: Bloodshed and the Assisted premade's utility reminders."
L["Default.Retail.Hunter.Marksmanship.Name"] = "Hunter: Marksmanship (Retail, Blizzard Assisted)"
L["Default.Retail.Hunter.Marksmanship.Description"] = "Recommended for Marksmanship. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Trueshot and your racial cooldown in combat, Counter Shot on an interruptible cast, and Survival of the Fittest whenever it is ready in combat. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use your defensives (Exhilaration and Aspect of the Turtle included) is your call."
L["Default.Retail.Hunter.MarksmanshipGuide.Name"] = "Hunter: Marksmanship reference (Retail, SimulationCraft and Icy Veins)"
L["Default.Retail.Hunter.MarksmanshipGuide.Description"] = "Reference only, off by default: the optimised Marksmanship priority, which spends Precise Shots before the next Aimed Shot. Procs and charges are hidden in Midnight combat, so it cannot run there; Focus is hidden on Retail, so the 70-Focus Multi-Shot dump on packs is left out. Marks the target and opens with Aimed Shot. Sentinel: Explosive Shot, Volley, Trueshot, Moonlight Chakram before its window ends, Aimed Shot in Trueshot without Precise Shots, Rapid Fire, Kill Shot, Multi-Shot (two enemies with Aspect of the Hydra) or Arcane Shot on Precise Shots, Aimed Shot, Moonlight Chakram, Steady Shot. Dark Ranger: Black Arrow on Precise Shots first, no Explosive Shot during Lock and Load, Aimed Shot before it caps, Wailing Arrow. Three or more enemies with Trick Shots: Explosive Shot, Volley, Multi-Shot to apply Trick Shots, Trueshot, then Rapid Fire and Aimed Shot while it lasts. Calling Trueshot for 30 Bullseye stacks or an unmarked target stays with you."
L["Default.Retail.Hunter.Survival.Name"] = "Hunter: Survival (Retail, Blizzard Assisted)"
L["Default.Retail.Hunter.Survival.Description"] = "Recommended for Survival. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it calls your pet itself); it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Takedown and your racial cooldown in combat, Muzzle on an interruptible cast, and Survival of the Fittest whenever it is ready in combat. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use your defensives (Exhilaration and Aspect of the Turtle included) is your call."
L["Default.Retail.Hunter.SurvivalGuide.Name"] = "Hunter: Survival reference (Retail, SimulationCraft)"
L["Default.Retail.Hunter.SurvivalGuide.Description"] = "Reference only, off by default: SimulationCraft's Survival priority, where Kill Command builds Tip of the Spear and Takedown, Boomstick, Wildfire Bomb and Raptor Strike spend it. Tip of the Spear and charges are hidden in Midnight combat, so it cannot run there. Calls your pet, marks the target and opens with Wildfire Bomb. Sentinel: Kill Command without Tip of the Spear, Boomstick, Wildfire Bomb on Sentinel's Mark, Kill Command before a ready Takedown, Takedown, Moonlight Chakram, Raptor Strike, then Kill Command, Wildfire Bomb and Takedown. Pack Leader: Kill Command on Howl of the Pack Leader, then Takedown, Wildfire Bomb, Boomstick and Raptor Strike with Tip of the Spear. Three or more enemies: Boomstick and Wildfire Bomb before Takedown, Raptor Swipe. Reminders: Aspect of the Eagle out of melee and the utility reminders."
L["Default.Retail.Hunter.Initial.Name"] = "Hunter: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Hunter.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Hunter's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Hunter premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Mage.Arcane.Name"] = "Mage: Arcane (Retail, Blizzard Assisted)"
L["Default.Retail.Mage.Arcane.Description"] = "Recommended for Arcane. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Arcane Surge in combat, Arcane Intellect out of combat, Counterspell on an interruptible cast, Prismatic Barrier whenever it is ready in combat, and your racial cooldown in combat. Enemy casts are hidden in combat, so Counterspell lights only where the game shows them; health is hidden on Retail, so Ice Block and other emergency buttons are your call. Mirror Image, Alter Time, Blink and trinkets stay with you."
L["Default.Retail.Mage.ArcaneGuide.Name"] = "Mage: Arcane reference (Retail, Icy Veins and SimulationCraft)"
L["Default.Retail.Mage.ArcaneGuide.Description"] = "Reference only, off by default: the guides' Arcane priority. Arcane Salvo and Clearcasting are hidden from addons in Midnight combat (only Arcane Charges stay visible), so it cannot run there; mana is hidden on Retail, so the low-mana Evocation is yours; read it, or clone it to experiment. Pulls with Arcane Blast. Sunfury: Arcane Missiles on Clearcasting below 12 Salvo, Prismatic Bolt outside Arcane Soul, Arcane Barrage at four charges with 12 Salvo and Clearcasting or 25 Salvo, or with Arcane Soul at any charge count, Prismatic Bolt, Arcane Orb below three charges, Arcane Pulse on three enemies or at no charges, Arcane Blast. Spellslinger (Splintering Sorcery known): Prismatic Bolt, Orb on packs, Barrage at 20 Salvo (only at four charges against two or more enemies), Missiles on Clearcasting below 15 Salvo, Orb and Pulse below three charges (no Pulse in Arcane Surge), Arcane Blast. Arcane Barrage when Blast cannot be cast. Reminders: Arcane Surge, Touch of the Magi after a Barrage or Prismatic Bolt in or well before Surge, Presence of Mind at no charges after a Barrage, plus the Assisted premade's reminders."
L["Default.Retail.Mage.Fire.Name"] = "Mage: Fire (Retail, Blizzard Assisted)"
L["Default.Retail.Mage.Fire.Description"] = "Recommended for Fire. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Combustion in combat, Arcane Intellect out of combat, Counterspell on an interruptible cast, Blazing Barrier whenever it is ready in combat, and your racial cooldown in combat. Enemy casts are hidden in combat, so Counterspell lights only where the game shows them; health is hidden on Retail, so Ice Block and other emergency buttons are your call."
L["Default.Retail.Mage.FireGuide.Name"] = "Mage: Fire reference (Retail, Icy Veins, Wowhead and SimulationCraft)"
L["Default.Retail.Mage.FireGuide.Description"] = "Reference only, off by default: the guides' Fire priority. Hot Streak, Heating Up, Pyroclasm and Fire Blast charges are hidden in Midnight combat, so it cannot run there. Fire Blast while a cast is finishing to turn Heating Up into Hot Streak; pulls with Pyroblast. Pyroblast (Flamestrike on four or more enemies) on Hyperthermia, Meteor, Pyroblast on Hot Streak, Fire Blast on Heating Up inside Combustion, Pyroblast on Pyroclasm, Scorch on Heat Shimmer or while moving, Fire Blast on Heating Up, then Frostfire Bolt or Fireball. Reminders: Combustion as a hard cast finishes, Blazing Barrier and the utility reminders. Waiting for Firestarter and timing Meteor into Combustion stay with you."
L["Default.Retail.Mage.Frost.Name"] = "Mage: Frost (Retail, Blizzard Assisted)"
L["Default.Retail.Mage.Frost.Description"] = "Recommended for Frost. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Summon Water Elemental when you have the talent and no elemental, Arcane Intellect out of combat, Counterspell on an interruptible cast, Ice Barrier whenever it is ready in combat, and your racial cooldown in combat. Enemy casts are hidden in combat, so Counterspell lights only where the game shows them; health is hidden on Retail, so Ice Block and other emergency buttons are your call."
L["Default.Retail.Mage.FrostGuide.Name"] = "Mage: Frost reference (Retail, Icy Veins and SimulationCraft)"
L["Default.Retail.Mage.FrostGuide.Description"] = "Reference only, off by default: the guides' Frost priority for each hero tree. Procs, Freezing stacks and cooldowns are hidden in Midnight combat, so it cannot run there. Pulls with Frostfire Bolt or Frostbolt. Frostfire (Frostfire Bolt known): Glacial Spike when ready, Comet Storm on one or two enemies, Flurry on Brain Freeze without Thermal Void, Ice Lance on two Fingers of Frost, Ray of Frost, Frozen Orb, Blizzard on Freezing Rain with three enemies, Ice Lance on Fingers of Frost with Thermal Void or at twelve Freezing, Flurry, Ice Nova or Cone of Cold on five, then Glacial Spike or Frostfire Bolt. Spellslinger: Comet Storm, Flurry on Brain Freeze, Ice Lance on two Fingers, Frozen Orb, Glacial Spike when ready, Blizzard on Freezing Rain, Ice Lance on Fingers of Frost or six Freezing, Ray of Frost, Flurry, Ice Nova or Cone of Cold on four, Blizzard on seven, then Glacial Spike or Frostbolt. Ice Lance while moving. Reminders: Summon Water Elemental, Ice Barrier and the utility reminders."
L["Default.Retail.Mage.Initial.Name"] = "Mage: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Mage.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Mage's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Mage premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Monk.Brewmaster.Name"] = "Monk: Brewmaster (Retail, Blizzard Assisted with brews)"
L["Default.Retail.Monk.Brewmaster.Description"] = "Recommended for Brewmaster. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Assisted Combat presses no brews, so, as Icy Veins advises, the brews are reminders beside it: Black Ox Brew, Invoke Niuzao, Purifying Brew, Celestial Brew or Celestial Infusion and Touch of Death light whenever they are ready in combat (Rotation Master cannot read Stagger yet, so how heavy it is stays your call). Also Spear Hand Strike on an interruptible cast, and Fortifying Brew and your racial cooldown whenever they are ready in combat; enemy casts are hidden in combat, so the interrupt lights only where the game shows them, and health is hidden on Retail, so when to use Fortifying Brew is your call."
L["Default.Retail.Monk.BrewmasterGuide.Name"] = "Monk: Brewmaster reference (Retail, Icy Veins)"
L["Default.Retail.Monk.BrewmasterGuide.Description"] = "Reference only, off by default: Icy Veins' Brewmaster priority (SimulationCraft agrees in shape). Blackout Combo, Empty Barrel and charges are hidden in Midnight combat, so it cannot run there. Pulls with Keg Smash. Blackout Kick; Chi Burst (Master of Harmony); Tiger Palm on Blackout Combo; Keg Smash at full charges or with Empty Barrel; Breath of Fire; Rushing Jade Wind before Exploding Keg; Chi Burst (Shado-Pan); Keg Smash; Rushing Jade Wind and Spinning Crane Kick on three or more enemies; Tiger Palm; Expel Harm. Reminders: Black Ox Brew once Purifying and Celestial Brew are spent, Invoke Niuzao, Purifying Brew, Celestial Brew or Infusion, Touch of Death, plus the utility reminders."
L["Default.Retail.Monk.Windwalker.Name"] = "Monk: Windwalker (Retail, Blizzard Assisted)"
L["Default.Retail.Monk.Windwalker.Description"] = "Recommended for Windwalker. Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat (it already keeps Combo Strikes); it waits while you cast or channel. Alongside it, reminders for what Assisted Combat leaves to you: Zenith, Celestial Conduit, Invoke Xuen and Touch of Karma in combat, Spear Hand Strike on an interruptible cast, and Fortifying Brew and your racial cooldown whenever they are ready in combat. Enemy casts are hidden in combat, so the interrupt lights only where the game shows them; health is hidden on Retail, so when to use Fortifying Brew is your call."
L["Default.Retail.Monk.WindwalkerGuide.Name"] = "Monk: Windwalker reference (Retail, Icy Veins and SimulationCraft)"
L["Default.Retail.Monk.WindwalkerGuide.Description"] = "Reference only, off by default: Icy Veins' Conduit of the Celestials priority. Every step keeps Combo Strikes (never the spell you cast last); Chi and your own casts stay readable, but Heart of the Jade Serpent, Zenith, Blackout Kick! and Dance of Chi-Ji are hidden in Midnight combat, so it cannot run there; energy is hidden on Retail, so the Tiger Palm before the energy cap is left out. Whirling Dragon Punch with Xuen over 10 seconds away; Zenith Stomp when low on Chi or as Zenith ends; Celestial Conduit without Heart; Fists of Fury as Heart ends; Celestial Conduit, Invoke Xuen, Fists of Fury, Whirling Dragon Punch, Strike of the Windlord; Blackout Kick when short of Chi for Fists; Rushing Wind Kick, Rising Sun Kick; Blackout Kick on two Blackout Kick! charges or in Zenith; Spinning Crane Kick in Zenith or on Dance of Chi-Ji; Touch of Death; Tiger Palm, Blackout Kick, Slicing Winds as fillers. Reminder: Touch of Karma, plus the utility reminders."
L["Default.Retail.Monk.Mistweaver.Name"] = "Monk: Mistweaver reference (Retail, Icy Veins)"
L["Default.Retail.Monk.Mistweaver.Description"] = "Reference only, off by default. Blizzard offers no Assisted Combat list for healers, and in Midnight combat your allies' health, Renewing Mist charges, Mana Tea stacks and procs are hidden from addons, so healing advice is not possible; choose your heals yourself. On a hostile target it suggests the fistweaving filler, Rising Sun Kick, Blackout Kick and Tiger Palm; on a friendly target or none it suggests nothing. Reminders: Spear Hand Strike, and Fortifying Brew and your racial cooldown whenever they are ready in combat."
L["Default.Retail.Monk.Initial.Name"] = "Monk: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Monk.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Monk's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Monk premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."
L["Default.Retail.Paladin.Retribution.Name"] = "Paladin: Retribution, Blizzard Assisted (Retail)"
L["Default.Retail.Paladin.Retribution.Description"] = "Recommended for Retribution in Midnight. In combat the game now hides buffs, debuffs, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation) on your action bars, and stops while you cast or have no enemy targeted. It also reminds you of what that suggestion never covers: an aura between pulls, Rebuke on an interruptible cast, and Divine Protection whenever it is ready in combat. Health is hidden on Retail, so when to use Divine Protection and Lay on Hands is your call. Trinkets and racials stay with you."
L["Default.Retail.Paladin.Retribution.IcyVeins.Name"] = "Paladin: Retribution (Retail, Icy Veins reference)"
L["Default.Retail.Paladin.Retribution.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order reads buffs, charges and enemy counts that Midnight hides in combat, so it cannot run reliably there. Hammer of Light; a free Divine Purpose spender; at 5 Holy Power while Wake of Ashes is cooling, the spender; Wake of Ashes; Divine Toll; Blade of Justice on Art of War; Hammer of Wrath before it caps; at 3 or more Holy Power, Divine Storm on two or more enemies (or with Empyrean Power), else Final Verdict; Hammer of Wrath; Blade of Justice; Judgment; Templar Strike or Crusader Strike. Holy Power stays visible in combat, so its spending points work there. Reminders: Avenging Wrath, Execution Sentence with Wake of Ashes ready, aura, Rebuke, defensives."
L["Default.Retail.Paladin.Protection.Name"] = "Paladin: Protection, Blizzard Assisted (Retail)"
L["Default.Retail.Paladin.Protection.Description"] = "Recommended for Protection in Midnight. Shows Blizzard's Assisted Combat suggestion, which already includes Shield of the Righteous, Avenging Wrath and Sentinel, and stops while you cast or have no enemy targeted. Reminders for what it leaves out: an aura between pulls, Rebuke on an interruptible cast, and Ardent Defender and Guardian of Ancient Kings whenever they are ready in combat. Health is hidden on Retail, so when to use them, and Lay on Hands, is your call. Taunting and positioning stay with you."
L["Default.Retail.Paladin.Protection.IcyVeins.Name"] = "Paladin: Protection (Retail, Icy Veins reference)"
L["Default.Retail.Paladin.Protection.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order needs the Consecration, Vanguard and Shining Light buffs, which Midnight hides in combat. Consecration before the pull; then Divine Toll, Hammer of Light, Consecration when you are not standing in it, Avenger's Shield with Vanguard, Shield of the Righteous at 3 or more Holy Power, Hammer of Wrath, Judgment, Blessed Hammer or Hammer of the Righteous, Avenger's Shield, Word of Glory with Shining Light, Consecration. Reminders: Avenging Wrath or Sentinel, Holy Bulwark, Sacred Weapon outside Avenging Wrath, defensives, aura, Rebuke."
L["Default.Retail.Paladin.Protection.Wowhead.Name"] = "Paladin: Protection, Consecration filler (Retail, Wowhead reference)"
L["Default.Retail.Paladin.Protection.Wowhead.Description"] = "Reference only, off by default: Wowhead's tank order. Judgment on cooldown, Shield of the Righteous, Avenger's Shield, Divine Toll at 0 Holy Power, Blessed Hammer or Hammer of the Righteous, and Consecration only as the filler. Health is hidden on Retail, so Word of Glory below half health is left to you. Same reminders as the Icy Veins reference."
L["Default.Retail.Paladin.Holy.Name"] = "Paladin: Holy (Retail, Icy Veins)"
L["Default.Retail.Paladin.Holy.Description"] = "Holy in Midnight, for reference: Rotation Master picks a spell, not a target, and the game hides everyone's health in combat, so this keeps your Holy Power and cooldowns turning over on whatever you target and leaves deciding who needs healing to you. Holy Power stays visible in combat, so it is spent at 5 first and at 3 or more after your other heals. On a friendly target: Eternal Flame or Word of Glory at 5 Holy Power, Flash of Light on Infusion of Light, Holy Shock, Eternal Flame or Word of Glory at 3 or more, Holy Light, Flash of Light; Light of Dawn is left to you. On an enemy: Shield of the Righteous at 5 Holy Power, Holy Shock, Shield of the Righteous at 3 or more, Judgment, Crusader Strike, Consecration. Reminders in combat: Divine Toll, Holy Prism, Holy Bulwark or Sacred Weapon, Beacon of Virtue on a friendly target, Divine Protection; an aura between pulls; Rebuke. Lay on Hands is left to you. Avenging Wrath and Aura Mastery are left to you."
L["Default.Retail.Paladin.Initial.Name"] = "Paladin: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Paladin.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Paladin's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Paladin premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Priest.Shadow.Name"] = "Priest: Shadow, Blizzard Assisted (Retail)"
L["Default.Retail.Priest.Shadow.Description"] = "Recommended for Shadow in Midnight. In combat the game now hides your DoTs, buffs, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation, which keeps your DoTs, Shadowform and Voidform going and lets Mind Flay finish), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: Power Infusion in the 20 seconds after you cast Voidform, Shadowform and Power Word: Fortitude between pulls, Silence on an interruptible cast (it lights only where the game lets the cast be read). Health is hidden on Retail, so Desperate Prayer is your call."
L["Default.Retail.Priest.Shadow.IcyVeins.Name"] = "Priest: Shadow (Retail, Icy Veins reference)"
L["Default.Retail.Priest.Shadow.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order reads DoT timers, Madness and Voidform, which Midnight hides in combat; Insanity and health are hidden on Retail, so the Insanity-cap Madness, the Shadow Word: Death execute and Desperate Prayer are left to you. Vampiric Touch before the pull; Tentacle Slam to apply Vampiric Touch; Vampiric Touch and Shadow Word: Pain refreshed in their last 30%; Shadow Word: Madness when it is ending or in Voidform; Void Blast during Madness; Tentacle Slam at two charges; Void Torrent; Mind Blast; Tentacle Slam; Mind Flay: Insanity during Madness; Void Volley; Death and Pain while moving; Mind Flay, clipped for a ready Mind Blast. Reminders: Halo, Voidform with both DoTs up, Power Infusion in Voidform."
L["Default.Retail.Priest.Discipline.Name"] = "Priest: Discipline, Atonement (Retail, Icy Veins)"
L["Default.Retail.Priest.Discipline.Description"] = "Discipline in Midnight, for reference: Blizzard's Assisted Combat does not cover healers, the game hides everyone's health in combat and Rotation Master picks a spell, not a target, so this runs the damage that heals through Atonement and leaves deciding who to heal to you. On a friendly target: Power Word: Shield (Void Shield), Penance, Flash Heal. On an enemy: Shadow Word: Pain when you have not cast it for 12 seconds, Mind Blast, Penance, Shield, Shadow Word: Death, Void Blast, Smite. Reminders in combat: Power Word: Radiance, Evangelism, Ultimate Penitence, Pain Suppression on a friendly target; Fortitude between pulls. Desperate Prayer is your call. Raid ramps before big damage are yours to time."
L["Default.Retail.Priest.Discipline.Wowhead.Name"] = "Priest: Discipline, Death first (Retail, Wowhead reference)"
L["Default.Retail.Priest.Discipline.Wowhead.Description"] = "Reference only, off by default: Wowhead's Season 1 Oracle order, which keeps Shadow Word: Pain up by reading the debuff that Midnight hides in combat. Shadow Word: Pain, Shadow Word: Death on cooldown, Penance, Mind Blast, Smite; Penance first on a friendly target. Same reminders as the Icy Veins premade."
L["Default.Retail.Priest.Holy.Name"] = "Priest: Holy (Retail, Icy Veins)"
L["Default.Retail.Priest.Holy.Description"] = "Holy in Midnight, for reference: the game hides everyone's health in combat and Rotation Master picks a spell, not a target, so this keeps your Holy Words, Prayer of Mending and procs moving on whatever you target and leaves triage to you. On a friendly target: Holy Word: Sanctify, Holy Word: Serenity, Prayer of Mending, Prayer of Healing with Surge of Light, Benediction, Prayer of Healing with Lightweaver, Flash Heal with Surge of Light, Prayer of Healing in a group, Holy Nova while moving, Flash Heal. On an enemy: Holy Word: Chastise, Holy Fire, Holy Nova while moving, Smite. Reminders: Apotheosis, Divine Hymn and Halo in combat, Guardian Spirit on a friendly target (health is hidden on Retail, so whether it is about to die is your call), Fortitude. Desperate Prayer is yours."
L["Default.Retail.Priest.Initial.Name"] = "Priest: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Priest.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Priest's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Priest premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Rogue.Assassination.Name"] = "Rogue: Assassination, Blizzard Assisted (Retail)"
L["Default.Retail.Rogue.Assassination.Description"] = "Recommended for Assassination in Midnight. In combat the game now hides your bleeds, buffs, energy, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation, which handles the stealth opener, Garrote, Rupture, Envenom, Deathmark and Kingsbane), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: a lethal and a non-lethal poison and Stealth between pulls, Vanish when you are out of stealth in combat, Kick on an interruptible cast (it lights only where the game lets the cast be read). Health is hidden on Retail, so Crimson Vial is your call."
L["Default.Retail.Rogue.Assassination.IcyVeins.Name"] = "Rogue: Assassination (Retail, Icy Veins reference)"
L["Default.Retail.Rogue.Assassination.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order keeps bleeds up by their timers, which Midnight hides in combat; energy is hidden on Retail, so its energy pooling is left out. From stealth Garrote, then Ambush. Garrote in its last 30% while you are not at full combo points, Rupture at 5+ in its last 30%; at 5+ combo points Coup de Grace or Envenom; below, Crimson Tempest on three or more enemies, Fan of Knives on two or more close by, Ambush, Mutilate. Reminders: Deathmark with both bleeds up, Kingsbane alongside it, Vanish with Deathmark ready, Shiv on a Deathstalker's Mark target, Thistle Tea whenever it is ready in combat, plus the shared poison, Stealth and Kick reminders."
L["Default.Retail.Rogue.Outlaw.Name"] = "Rogue: Outlaw, Blizzard Assisted (Retail)"
L["Default.Retail.Rogue.Outlaw.Description"] = "Recommended for Outlaw in Midnight. Shows Blizzard's Assisted Combat suggestion (it handles the stealth opener, Roll the Bones, Blade Flurry, Adrenaline Rush, Between the Eyes and the finishers), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: poisons and Stealth between pulls, Vanish when you are out of stealth in combat, Kick. Health is hidden on Retail, so Crimson Vial is your call. Keep It Rolling stays with you: the game hides how many Roll the Bones buffs you have."
L["Default.Retail.Rogue.Outlaw.IcyVeins.Name"] = "Rogue: Outlaw (Retail, Icy Veins reference)"
L["Default.Retail.Rogue.Outlaw.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins, SimulationCraft and Wowhead order reads Roll the Bones buffs, Opportunity stacks and energy, which Midnight hides in combat. From stealth Ambush. One combo point short of full or more: Between the Eyes, Killing Spree, Coup de Grace, Dispatch. Otherwise Ambush with Audacity, Pistol Shot at six Opportunity stacks (three when low on combo points), Ambush, Sinister Strike. Reminders: Roll the Bones with no roll up, Adrenaline Rush at two or fewer combo points, Blade Flurry kept up on two or more enemies, Blade Rush, Preparation when Adrenaline Rush, Between the Eyes and Blade Rush are all cooling. Keep It Rolling stays manual."
L["Default.Retail.Rogue.Subtlety.Name"] = "Rogue: Subtlety, Blizzard Assisted (Retail)"
L["Default.Retail.Rogue.Subtlety.Description"] = "Recommended for Subtlety in Midnight. Shows Blizzard's Assisted Combat suggestion (it handles the stealth opener, Shadow Blades, Goremaw's Bite, Shadow Dance, Secret Technique and the finishers), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: poisons and Stealth between pulls, Kick on an interruptible cast. Health is hidden on Retail, so Crimson Vial is your call."
L["Default.Retail.Rogue.Subtlety.IcyVeins.Name"] = "Rogue: Subtlety (Retail, Icy Veins reference)"
L["Default.Retail.Rogue.Subtlety.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order holds Shadow Dance for Secret Technique and reads Shadow Dance, Darkest Night and energy, which Midnight hides in combat. Stealthed before the pull: Shadowstrike. One combo point short of full or more: Eviscerate with Darkest Night, Secret Technique in Shadow Dance, Coup de Grace, Black Powder on three or more enemies, Eviscerate. Otherwise Shadowstrike, Shuriken Storm on two or more, Gloomblade or Backstab. Reminders: Goremaw's Bite in Shadow Dance, Shadow Blades with Shadow Dance ready, Shadow Dance at two or fewer (or six or more) combo points when Secret Technique is ready or Shadow Blades is up, Vanish out of stealth at two or fewer combo points."
L["Default.Retail.Rogue.Initial.Name"] = "Rogue: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Rogue.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Rogue's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Rogue premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Shaman.Elemental.Name"] = "Shaman: Elemental, Blizzard Assisted (Retail)"
L["Default.Retail.Shaman.Elemental.Description"] = "Recommended for Elemental in Midnight. In combat the game now hides Flame Shock, your buffs, Maelstrom, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: Ascendance, Fire or Storm Elemental and Nature's Swiftness in combat, Spiritwalker's Grace while moving, Lightning Shield and Skyfury between pulls (Blizzard's suggestion keeps your weapon and shield imbues), Wind Shear on an interruptible cast (it lights only where the game lets the cast be read), Astral Shift whenever it is ready in combat (health is hidden on Retail, so when to use it is your call)."
L["Default.Retail.Shaman.Elemental.IcyVeins.Name"] = "Shaman: Elemental (Retail, Icy Veins reference)"
L["Default.Retail.Shaman.Elemental.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order reads Flame Shock, Master of the Elements and Stormkeeper, which Midnight hides in combat; Maelstrom is hidden on Retail, so the spenders go at their cost instead of near full Maelstrom. Stormkeeper and Lava Burst before the pull. On three or more engaged enemies: Stormkeeper, Ancestral Swiftness, Flame Shock, Chain Lightning with Stormkeeper, Elemental Blast, Earthquake, Lava Burst on Lava Surge, Tempest, Chain Lightning. Otherwise Stormkeeper, Ancestral Swiftness, Flame Shock and Voltaic Blaze in their last 30% outside Master of the Elements, Lava Burst to start it, Tempest and Stormkeeper's Lightning Bolt inside it, Elemental Blast or Earth Shock inside it, Voltaic Blaze, Tempest, Flame Shock or Frost Shock while moving, Elemental Blast or Earth Shock whenever you can afford it, Lightning Bolt. Reminders: Ascendance once Stormkeeper is used, elementals, Spiritwalker's Grace, and the shared ones."
L["Default.Retail.Shaman.Enhancement.Name"] = "Shaman: Enhancement, Blizzard Assisted (Retail)"
L["Default.Retail.Shaman.Enhancement.Description"] = "Recommended for Enhancement in Midnight. Shows Blizzard's Assisted Combat suggestion (it spends Maelstrom Weapon, keeps Flame Shock and handles Surging Totem and Sundering), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: Ascendance, Doom Winds and Feral Spirit in combat, Lightning Shield and Skyfury between pulls (Blizzard's suggestion keeps Windfury Weapon), Wind Shear, Astral Shift."
L["Default.Retail.Shaman.Enhancement.Stormbringer.Name"] = "Shaman: Enhancement, Stormbringer (Retail, SimulationCraft reference)"
L["Default.Retail.Shaman.Enhancement.Stormbringer.Description"] = "Reference only, off by default: SimulationCraft's Stormbringer list (Icy Veins and Wowhead agree) reads Flame Shock, Crash Lightning, Lashing Flames and cooldown timers, which Midnight hides in combat. On three or more engaged enemies: Crash Lightning for its buff, Tempest at 10 Maelstrom Weapon, Chain Lightning at 9, Crash Lightning, Lava Lash, Sundering. Then Primordial Storm at 9, Voltaic Blaze or Flame Shock when Flame Shock is missing, Sundering, Crash Lightning for its buff, Lava Lash for Lashing Flames, Windstrike, Tempest or Lightning Bolt at 10 (8 with Voltaic Blaze or Crash Lightning about ready), Stormstrike at two charges, Lava Lash, Stormstrike, Voltaic Blaze, Crash Lightning, Lightning Bolt at 5, Flame Shock. Reminders: Doom Winds, Ascendance outside Doom Winds, Feral Spirit, and the shared ones."
L["Default.Retail.Shaman.Enhancement.Totemic.Name"] = "Shaman: Enhancement, Totemic (Retail, SimulationCraft reference)"
L["Default.Retail.Shaman.Enhancement.Totemic.Description"] = "Reference only, off by default: SimulationCraft's Totemic list reads Flame Shock, Hot Hand, Whirling Fire, Crash Lightning and Doom Winds, which Midnight hides in combat. On three or more engaged enemies: Crash Lightning, Chain Lightning at 5 Maelstrom Weapon. Then Voltaic Blaze or Flame Shock when Flame Shock is missing, Surging Totem, Sundering, Lava Lash with Hot Hand or Whirling Fire, Crash Lightning for its buff, Primordial Storm at 10, Windstrike, Crash Lightning and Stormstrike in Doom Winds, Lightning Bolt at 5, Crash Lightning, Lava Lash, Stormstrike, Voltaic Blaze, Flame Shock. Same reminders as the Stormbringer reference."
L["Default.Retail.Shaman.Restoration.Name"] = "Shaman: Restoration (Retail, Icy Veins)"
L["Default.Retail.Shaman.Restoration.Description"] = "Restoration in Midnight, for reference: Blizzard's Assisted Combat does not cover healers, the game hides everyone's health in combat and Rotation Master picks a spell, not a target, so this orders your healing tools by readiness on whatever you target and leaves deciding who to heal to you. On a friendly target: Healing Stream Totem, Unleash Life, Healing Rain in a group, Surging Totem, Riptide, Chain Heal in a group, Healing Wave. On an enemy: Flame Shock when missing, Lava Burst, Lightning Bolt. Reminders: Water Shield, Earth Shield on a friendly target and Skyfury between pulls; Nature's Swiftness in combat; Healing Tide Totem and Spirit Link Totem in grouped combat; Wind Shear; Astral Shift."
L["Default.Retail.Shaman.Initial.Name"] = "Shaman: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Shaman.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Shaman's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Shaman premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Warlock.Affliction.Name"] = "Warlock: Affliction, Blizzard Assisted (Retail)"
L["Default.Retail.Warlock.Affliction.Description"] = "Recommended for Affliction in Midnight. In combat the game now hides your DoTs, procs, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation, which keeps Agony and Corruption, spends shards on Unstable Affliction and handles Grimoire of Sacrifice), and stops while you cast, channel or have no enemy targeted. Reminders for what it leaves out: Summon Darkglare in combat, a Felhunter between pulls unless you sacrificed your demon, Command Demon on an interruptible cast (it lights only where the game lets the cast be read), Dark Pact and Unending Resolve whenever they are ready in combat (health is hidden on Retail, so when to use them is your call)."
L["Default.Retail.Warlock.Affliction.IcyVeins.Name"] = "Warlock: Affliction (Retail, Icy Veins reference)"
L["Default.Retail.Warlock.Affliction.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft (Soul Harvester) order reads DoT timers, Nightfall and Shard Instability, which Midnight hides in combat. Haunt before the pull; Seed of Corruption on three or more engaged enemies without your Corruption; Haunt; Agony and Corruption or Wither under 3 seconds; Dark Harvest at two shards or fewer; Unstable Affliction at 5 shards; Malefic Grasp, else Shadow Bolt, on two Nightfall; Unstable Affliction on Shard Instability or at 4 shards; Drain Soul; Shadow Bolt. Reminders: Summon Darkglare once Dark Harvest is cooling, Malevolence, your Felhunter, and the shared ones."
L["Default.Retail.Warlock.Demonology.Name"] = "Warlock: Demonology, Blizzard Assisted (Retail)"
L["Default.Retail.Warlock.Demonology.Description"] = "Recommended for Demonology in Midnight. Shows Blizzard's Assisted Combat suggestion (Call Dreadstalkers, Hand of Gul'dan, Demonbolt, Power Siphon and Tyrant), and stops while you cast, channel or have no enemy targeted. Reminders for what it leaves out: Summon Demonic Tyrant while the Dreadstalkers you called in the last 12 seconds are out, Grimoire: Imp Lord, Grimoire: Fel Ravager and Summon Doomguard in combat, a Felguard between pulls, Command Demon, Dark Pact, Unending Resolve."
L["Default.Retail.Warlock.Demonology.IcyVeins.Name"] = "Warlock: Demonology (Retail, Icy Veins reference)"
L["Default.Retail.Warlock.Demonology.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft (Diabolist) order reads Demonic Core, imp counts and cooldown timers, which Midnight hides in combat. Power Siphon, Demonbolt and Shadow Bolt before the pull; then Power Siphon at one Demonic Core or none, Grimoire: Imp Lord, Grimoire: Fel Ravager, Summon Doomguard, Call Dreadstalkers, Summon Demonic Tyrant at 5 shards, Implosion on three or more engaged enemies, Ruination, Hand of Gul'dan at 3 shards or more, Infernal Bolt below 3, Demonbolt on Demonic Core below 4, Shadow Bolt."
L["Default.Retail.Warlock.Destruction.Name"] = "Warlock: Destruction, Blizzard Assisted (Retail)"
L["Default.Retail.Warlock.Destruction.Description"] = "Recommended for Destruction in Midnight. Shows Blizzard's Assisted Combat suggestion (Immolate or Wither, Conflagrate, Chaos Bolt, Rain of Fire, Soul Fire, Malevolence), and stops while you cast, channel or have no enemy targeted. Reminders for what it leaves out: Summon Infernal in combat, an Imp between pulls unless you sacrificed your demon, Command Demon, Dark Pact, Unending Resolve. Havoc on a second target stays with you."
L["Default.Retail.Warlock.Destruction.Simc.Name"] = "Warlock: Destruction (Retail, SimulationCraft reference)"
L["Default.Retail.Warlock.Destruction.Simc.Description"] = "Reference only, off by default: SimulationCraft's order reads Immolate, Backdraft, charges and cooldown timers, which Midnight hides in combat. Soul Fire and Incinerate before the pull; on three or more engaged enemies Rain of Fire at 3 shards and Cataclysm; then Soul Fire at 4 shards or fewer, Chaos Bolt only at 5, Conflagrate at two charges or below 4 shards without Backdraft, Summon Infernal, Malevolence, Wither or Immolate in its last 30%, Ruination, Cataclysm, Infernal Bolt at 3 shards or fewer, Incinerate."
L["Default.Retail.Warlock.Destruction.IcyVeins.Name"] = "Warlock: Destruction, Chaos Bolt before capping (Retail, Icy Veins reference)"
L["Default.Retail.Warlock.Destruction.IcyVeins.Description"] = "Reference only, off by default: Icy Veins' Hellcaller order, which spends shards on Chaos Bolt before they cap and uses Shadowburn and Channel Demonfire on cooldown. Rain of Fire on three or more engaged enemies; Wither or Immolate kept up; Summon Infernal; Malevolence; Shadowburn; Soul Fire below 4 shards; Chaos Bolt at 4 or more; Cataclysm; Infernal Bolt below 4; Channel Demonfire; Conflagrate; Incinerate."
L["Default.Retail.Warlock.Initial.Name"] = "Warlock: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Warlock.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Warlock's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Warlock premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Retail.Warrior.Arms.Name"] = "Warrior: Arms, Blizzard Assisted (Retail)"
L["Default.Retail.Warrior.Arms.Description"] = "Recommended for Arms in Midnight. In combat the game now hides rage, Rend, Colossus Smash, procs, cooldown times and health from addons, so this shows Blizzard's own Assisted Combat suggestion (the one-button rotation), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: Heroic Strike (a core button the suggestion never uses), Avatar and Champion's Spear in combat, Battle Shout between pulls, Pummel on an interruptible cast (it lights only where the game lets the cast be read), Die by the Sword whenever it is ready in combat (health is hidden on Retail, so when to use it is your call)."
L["Default.Retail.Warrior.Arms.Slayer.Name"] = "Warrior: Arms, Slayer (Retail, SimulationCraft reference)"
L["Default.Retail.Warrior.Arms.Slayer.Description"] = "Reference only, off by default: the Slayer order from SimulationCraft, Icy Veins and Wowhead reads rage, Rend, Colossus Smash, Sudden Death and Opportunist, which Midnight hides in combat. Charge to open; Sweeping Strikes on two or more engaged enemies; Rend before Colossus Smash when it is running out; Ravager just before Colossus Smash; Execute at two Sudden Death; Colossus Smash; Bladestorm in Colossus Smash or Avatar; Heroic Strike; Overpower at two Opportunist; Mortal Strike; Execute; Overpower; Rend under 5 seconds; Slam. Reminders: Avatar with Colossus Smash ready, Die by the Sword, Battle Shout, Pummel."
L["Default.Retail.Warrior.Arms.Colossus.Name"] = "Warrior: Arms, Colossus (Retail, SimulationCraft reference)"
L["Default.Retail.Warrior.Arms.Colossus.Description"] = "Reference only, off by default: the Colossus order from SimulationCraft and Icy Veins builds Colossal Might with Mortal Strike and reads buffs Midnight hides in combat. Charge to open; Sweeping Strikes on two or more; Mortal Strike below five Colossal Might; Rend before Colossus Smash; Ravager; Execute at two Sudden Death; Colossus Smash; Champion's Spear; Demolish in Colossus Smash with Colossal Might; Heroic Strike; Mortal Strike; Execute; Overpower; Rend under 5 seconds; Bladestorm on two or more; Slam. Reminders: Avatar, Die by the Sword, Battle Shout, Pummel."
L["Default.Retail.Warrior.Fury.Name"] = "Warrior: Fury, Blizzard Assisted (Retail)"
L["Default.Retail.Warrior.Fury.Description"] = "Recommended for Fury in Midnight. Shows Blizzard's Assisted Combat suggestion (Rampage, Bloodthirst, Raging Blow, Execute, Odyn's Fury and Bladestorm), and stops while you cast or have no enemy targeted. Reminders for what it leaves out: Recklessness, Avatar and Champion's Spear in combat, Battle Shout between pulls, Pummel, Enraged Regeneration whenever it is ready in combat (health is hidden on Retail, so when to use it is your call)."
L["Default.Retail.Warrior.Fury.Slayer.Name"] = "Warrior: Fury, Slayer (Retail, SimulationCraft reference)"
L["Default.Retail.Warrior.Fury.Slayer.Description"] = "Reference only, off by default: SimulationCraft's Slayer order reads Enrage, Recklessness and Sudden Death, which Midnight hides in combat; rage is hidden on Retail, so Rampage waits only for its cost. Charge to open; Whirlwind for its buff on two or more engaged enemies; Rampage when Enrage is ending; in Recklessness Rampage, Bladestorm, Execute on Sudden Death, Odyn's Fury; Crushing Blow; Bloodbath; Execute; Odyn's Fury; Raging Blow; Rampage; Bloodthirst; Whirlwind. Reminders: Recklessness, Avatar, Enraged Regeneration, Battle Shout, Pummel."
L["Default.Retail.Warrior.Fury.Thane.Name"] = "Warrior: Fury, Mountain Thane (Retail, Icy Veins reference)"
L["Default.Retail.Warrior.Fury.Thane.Description"] = "Reference only, off by default: the Mountain Thane order from SimulationCraft and Icy Veins weaves Thunder Blast and reads buffs Midnight hides in combat. Charge to open; Whirlwind for its buff on two or more; Rampage when Enrage is missing or ending (rage is hidden on Retail, so there is no 100-rage Rampage); Bloodbath in Recklessness; Thunder Blast at two stacks; Crushing Blow; Bloodbath; Rampage in Recklessness; Thunder Blast in Avatar; Raging Blow; Thunder Blast; Rampage; Bloodthirst; Execute; Odyn's Fury; Thunder Clap; Whirlwind. Same reminders as the Slayer reference."
L["Default.Retail.Warrior.Protection.Name"] = "Warrior: Protection, Blizzard Assisted (Retail)"
L["Default.Retail.Warrior.Protection.Description"] = "Recommended for Protection in Midnight. Shows Blizzard's Assisted Combat suggestion for your damage and threat, and stops while you cast or have no enemy targeted. The suggestion never casts Shield Block or Ignore Pain, so both are reminders whenever they are usable and your target is attacking you; the game hides rage, so Ignore Pain will light more often than you need it. Other reminders: Avatar, Demoralizing Shout and Champion's Spear in combat, Shield Wall and Last Stand whenever they are ready in combat (health is hidden on Retail, so when to use them is your call), Taunt in a group when your target attacks someone else, Battle Shout between pulls, Pummel."
L["Default.Retail.Warrior.Protection.IcyVeins.Name"] = "Warrior: Protection (Retail, Icy Veins reference)"
L["Default.Retail.Warrior.Protection.IcyVeins.Description"] = "Reference only, off by default: the Icy Veins and SimulationCraft order reads Shield Block, Thunder Blast and Colossal Might, which Midnight hides in combat; rage and health are hidden on Retail. Charge to open; Ravager; Thunder Blast at two stacks; Demolish at five Colossal Might; Shield Charge; Thunder Blast; Shield Slam; Thunder Clap; Execute; Revenge; Devastate. Reminders: Shield Block when its buff is down and you are tanking, Ignore Pain, Avatar, Demoralizing Shout, Champion's Spear, Shield Wall and Last Stand whenever they are ready in combat, Battle Shout, Pummel."
L["Default.Retail.Warrior.Initial.Name"] = "Warrior: No specialization (Retail, Blizzard Assisted)"
L["Default.Retail.Warrior.Initial.Description"] = "Recommended before you choose a specialization (levels 1-9, where the game reports the Warrior's initial specialization). Highlights the spell Blizzard's Assisted Combat suggests next, the one rotation advice the game still lets an addon read in Midnight combat; it waits while you cast or channel. Alongside it, the reminders every Warrior premade shares, each once you know its spell. When you choose a specialization at level 10, that specialization's premades take over."

L["Default.Era.Druid.Balance.Name"] = "Druid: Balance"
L["Default.Era.Druid.Balance.Description"] = "Balance from level 1 to 60, and the Druid default before talents or when no other premade fits. Starfire as the filler once learned (Wrath before that, Starfire first on a Nature's Grace proc), Moonfire and Insect Swarm kept on targets that will live while your mana is above 30%, Hurricane when three or more enemies are on you, Faerie Fire in a group, instants while moving, melee when out of mana. In Cat or Bear Form it gives the Feral advice instead. Reminders: Mark of the Wild, Thorns when solo, Omen of Clarity, Moonkin Form when you are in no form, Innervate, Nature's Grasp. Downranking Starfire, roots and target choice stay with you."
L["Default.Era.Druid.Balance.IcyVeins.Name"] = "Druid: Balance (Icy Veins)"
L["Default.Era.Druid.Balance.IcyVeins.Description"] = "Icy Veins' raid list for realms with the 16-debuff limit, an alternative to the recommended Balance premade, off by default: enable it and disable that one, or raise its priority. Starfire and nothing else, no Moonfire or Insect Swarm, Hurricane when three or more enemies are on you, Wrath only before Starfire is learned. Same reminders as the recommended premade."
L["Default.Era.Druid.Feral.Name"] = "Druid: Feral"
L["Default.Era.Druid.Feral.Description"] = "Feral cat and bear from level 10 when Feral is your main talent tree; your form decides which. Cat: stealth opener, Faerie Fire (Feral) kept up, Clearcasting spent on Shred, a finisher from four combo points (Rip before Ferocious Bite is learned and on long fights outside raids, Bite under 63 energy), Rake outside raids, Shred from behind or Claw when the target is on you, and a powershift (Cat Form again) when far short of energy with Furor 5/5 and mana to spare. Bear: Enrage when starved, Demoralizing Roar on packs and elites unless a warrior's Shout is up, Swipe on two or more and with spare rage, Faerie Fire (Feral) otherwise. Caster form: shift. Reminders: Maul every swing, Tiger's Fury before a pull, Manual Crowd Pummeler, Innervate, Frenzied Regeneration. Positioning stays with you."
L["Default.Era.Druid.Feral.WarcraftTavern.Name"] = "Druid: Feral (Warcraft Tavern, Rip and Bite)"
L["Default.Era.Druid.Feral.WarcraftTavern.Description"] = "Warcraft Tavern's powershifting list, an alternative to the recommended Feral premade, off by default: enable it and disable that one, or raise its priority. Rip at five combo points whenever it is missing, raids included, then Ferocious Bite from four combo points under 63 energy, Shred from behind, powershift when far short of energy. Bear and reminders as the recommended premade."
L["Default.Era.Druid.Feral.WarcraftTavernCasual.Name"] = "Druid: Feral (Warcraft Tavern, no powershifting)"
L["Default.Era.Druid.Feral.WarcraftTavernCasual.Description"] = "Warcraft Tavern's list without powershifting, an alternative to the recommended Feral premade, off by default: enable it and disable that one, or raise its priority. Build to five combo points with Shred (Claw from the front), then Rip on a target that will live, Tiger's Fury, Ferocious Bite; otherwise wait for energy. Bear and reminders as the recommended premade."
L["Default.Era.Druid.Feral.Wowhead.Name"] = "Druid: Feral (Wowhead raid bear)"
L["Default.Era.Druid.Feral.Wowhead.Description"] = "The cat of the recommended Feral premade with Wowhead's geared raid bear: Maul every swing (tab-Maul packs yourself), Swipe only with 60 rage to spare, Faerie Fire (Feral) otherwise, no Demoralizing Roar and no Enrage in combat. An alternative to the recommended Feral premade, off by default: enable it and disable that one, or raise its priority."
L["Default.Era.Druid.Restoration.Name"] = "Druid: Restoration"
L["Default.Era.Druid.Restoration.Description"] = "Restoration from level 10 when Restoration is your main talent tree. Heals your current friendly target: Healing Touch after Nature's Swiftness, Swiftmend below 40% on your own HoT, Rejuvenation and Regrowth kept rolling, Regrowth as the main heal with Improved Regrowth, full Healing Touch below 45% or on a Nature's Grace proc, rank 4 Healing Touch otherwise. On an enemy: Moonfire, Insect Swarm and Wrath. Silent in Cat or Bear Form. Reminders: Mark of the Wild, Omen of Clarity, Nature's Swiftness, Tranquility, Innervate, Rebirth, poison and curse removal. Choosing whom to heal stays with you."
L["Default.Era.Druid.Restoration.WarcraftTavern.Name"] = "Druid: Restoration (Warcraft Tavern)"
L["Default.Era.Druid.Restoration.WarcraftTavern.Description"] = "Warcraft Tavern's damage tiers, an alternative to the recommended Restoration premade, off by default: enable it and disable that one, or raise its priority. On your friendly target, with no HoT upkeep while damage is low: Swiftmend below 40%, rank 5 Regrowth below 50%, Rejuvenation and rank 3 Regrowth below 75%, full Healing Touch on a Nature's Grace proc, rank 3 Healing Touch below 90%. Reminders as the recommended premade."
L["Default.SoD.Druid.Balance.Name"] = "Druid: Balance (Season of Discovery)"
L["Default.SoD.Druid.Balance.Description"] = "Season of Discovery Balance from level 1 to 60, and the default for any Druid no other Season of Discovery premade fits. Starsurge whenever its buff is down, Sunfire and Moonfire on targets that will live, Starfire only when Starsurge or Lunar Eclipse empowers it, Wrath as the filler, Hurricane on six or more enemies (four with Gale Winds engraved), Insect Swarm only while moving. Runes are used as you engrave them. In Cat or Bear Form it gives the Feral advice. Reminders: Moonkin Form, Starfall, instant Healing Touch on a dying friend, curse and poison removal, Wild Growth on a hurt group, Innervate. Spreading DoTs to other targets stays with you."
L["Default.SoD.Druid.Balance.IcyVeins.Name"] = "Druid: Balance (Season of Discovery, Icy Veins)"
L["Default.SoD.Druid.Balance.IcyVeins.Description"] = "Icy Veins' Season of Discovery list, an alternative to the recommended Season of Discovery Balance premade, off by default: enable it and disable that one, or raise its priority. Starsurge on cooldown, Hurricane on four or more enemies (for Gale Winds), Starfire when Starsurge empowers it, Moonfire, Sunfire and Insect Swarm all kept up, Wrath as the filler. Reminders as the recommended premade."
L["Default.SoD.Druid.Balance.Wowhead.Name"] = "Druid: Balance (Season of Discovery, Wowhead)"
L["Default.SoD.Druid.Balance.Wowhead.Description"] = "Wowhead's Phase 8 list, an alternative to the recommended Season of Discovery Balance premade, off by default: enable it and disable that one, or raise its priority. Wrath to open, Starsurge on cooldown, Hurricane on six or more, Insect Swarm only while moving, Sunfire and Moonfire kept up, Wrath while your Sunfire has under 5 seconds when Elune's Fires is engraved to extend it, Starfire on Lunar Eclipse, Wrath otherwise. Reminders as the recommended premade."
L["Default.SoD.Druid.Feral.Name"] = "Druid: Feral cat (Season of Discovery)"
L["Default.SoD.Druid.Feral.Description"] = "Season of Discovery cat, chosen when Savage Roar is engraved (or Feral is your main tree without another legs rune). Faerie Fire (Feral) when none is up, Savage Roar, Swipe (Cat) on four or more enemies, the Mangle debuff, Clearcasting on Shred, Rip at five combo points while Savage Roar has 8 seconds left, Rake, Shred from behind or Mangle from the front, powershift with Furor 5/5, Faerie Fire refresh last. In Bear Form it gives the tank advice. Reminders: Tiger's Fury at 60 energy or less, Berserk with Tiger's Fury, Maul, Innervate. Positioning stays with you."
L["Default.SoD.Druid.Tank.Name"] = "Druid: Bear tank (Season of Discovery)"
L["Default.SoD.Druid.Tank.Description"] = "Season of Discovery bear tank, chosen when Lacerate is engraved. Faerie Fire (Feral) or Sunfire (Bear) to pull from range, Lacerate before it drops, Mangle on cooldown, Lacerate, Swipe; on three or more enemies Mangle under Berserk and Swipe. In Cat Form it plays the cat list for off-tanking; in caster form it shifts to Bear. Reminders: Maul with 30 rage, Berserk, Survival Instincts, Frenzied Regeneration and Barkskin when low, Enrage between pulls, Demoralizing Roar on elites. Taunting and target choice stay with you."
L["Default.SoD.Druid.Tank.Wowsims.Name"] = "Druid: Bear tank (Season of Discovery, wowsims cat weave)"
L["Default.SoD.Druid.Tank.Wowsims.Description"] = "Off by default; for experts whose gear also grants Savage Roar. The wowsims Phase 7 cat weave: leave Bear for Cat when your Rake is down, keep Savage Roar and Rake up (Tiger's Fury, Mangle to build), then return to Dire Bear and play the tank list. Reminders as the recommended tank premade."
L["Default.SoD.Druid.Restoration.Name"] = "Druid: Restoration (Season of Discovery)"
L["Default.SoD.Druid.Restoration.Description"] = "Season of Discovery Restoration, chosen when Lifebloom is engraved (or Restoration is your main tree without another legs rune). Heals your current friendly target: instant Healing Touch after Nature's Swiftness or Fury of Stormrage, Wild Growth when two or more nearby are hurt, Swiftmend on your HoT for Efflorescence or below 40%, three Lifebloom stacks refreshed with a second left, Rejuvenation, Regrowth below 60%, Nourish, rank 4 Healing Touch. On an enemy: Sunfire, Moonfire, Wrath. Reminders: Tree of Life and Survival Instincts in heavy moments, Nature's Swiftness, Tranquility, Innervate, Rebirth, Revive, dispels. Choosing whom to heal stays with you."

L["Default.Era.Hunter.Ranged.Name"] = "Hunter: Ranged"
L["Default.Era.Hunter.Ranged.Description"] = "Every Hunter from level 1 to 60, all talent trees. Pull with Hunter's Mark, Aimed Shot and Auto Shot. Solo, the pet tanks: your own Serpent Sting, then Aimed Shot, Arcane Shot and Multi-Shot only while mana is above half, Concussive Shot to kite before you have a pet. In a group, Aimed Shot and Multi-Shot right after an Auto Shot so it is never delayed, Serpent Sting outside raids, Arcane Shot only before Aimed Shot or on a dying target. Melee buttons when an enemy is too close, instants while moving, Multi-Shot and Volley on three or more enemies. Reminders: Hawk (Monkey before it), Trueshot Aura, pet care, Rapid Fire, Bestial Wrath and racials on elites and in instances, Intimidation and Feign Death. Traps, Wing Clip, Feed Pet, Tranquilizing Shot and positioning stay with you."
L["Default.Era.Hunter.Ranged.IcyVeins.Name"] = "Hunter: Ranged, clipped (Icy Veins)"
L["Default.Era.Hunter.Ranged.IcyVeins.Description"] = "Off by default; enable it for a ranged weapon faster than 3.0 seconds. Like Hunter: Ranged, but in a group Aimed Shot and Multi-Shot go out as soon as they are ready, even if that delays an Auto Shot, Serpent Sting is never used, and Rapid Fire, Bestial Wrath and racials are used on every pull."
L["Default.Era.Hunter.Ranged.Wowsims.Name"] = "Hunter: Ranged, raid Serpent Sting (wowsims)"
L["Default.Era.Hunter.Ranged.Wowsims.Description"] = "Off by default; enable it where the raid has debuff room for your sting. Like Hunter: Ranged, but in a group Serpent Sting is kept up everywhere, raids included, refreshed under 5 seconds while Aimed Shot and Multi-Shot are both cooling, and Arcane Shot is never used."
L["Default.SoD.Hunter.Ranged.Name"] = "Hunter: Ranged (Season of Discovery)"
L["Default.SoD.Hunter.Ranged.Description"] = "Every ranged Hunter on a Season of Discovery realm, level 1 to 60; runes are used once engraved. Serpent Sting always up and refreshed by Chimera Shot. With the Kill Shot legs rune: Multi-Shot at four Trick Shots, Kill Shot during Rapid Fire and on targets in execute, Chimera Shot, then Explosive Trap and Arcane Shot while Multi-Shot is cooling. Without it: Chimera Shot, Aimed Shot at two Sniper Training stacks (without that rune, right after an Auto Shot), traps just before Chimera Shot is ready (Frost Trap only to feed Lock and Load), Explosive Shot, Steady Shot, Multi-Shot, Arcane Shot. Melee buttons when an enemy is too close, instants while moving, traps, Multi-Shot and Volley on three or more enemies. Reminders: Hawk, Viper below 10% mana, Heart of the Lion, Trueshot Aura, pet care (none with Lone Wolf engraved), Focus Fire at five Frenzy stacks, Rapid Fire, racials and Bestial Wrath on elites and in instances. With Lock and Load engraved, a Frost Trap before the pull. Melee weaving and positioning stay with you."
L["Default.SoD.Hunter.Melee.Name"] = "Hunter: Melee (Season of Discovery)"
L["Default.SoD.Hunter.Melee.Description"] = "Chosen on a Season of Discovery realm once you engrave Flanking Strike, Wyvern Strike or Carve and neither Chimera Shot nor Explosive Shot. Keeps the Flanking Strike buff up, Mongoose Bite at four Raptor Fury stacks, Wyvern Strike on Clever Strikes, Raptor Strike on every reset, then Mongoose Bite, Wyvern Strike, Flanking Strike and Carve; Immolation Trap and Wing Clip only in empty moments. Carve and Explosive Trap on three or more enemies; Serpent Sting and shots while you cannot reach the target. Reminders: Aspect of the Falcon (Hawk before 60), Viper below 5% mana, pet care (none with Lone Wolf engraved), Rapid Fire and racials once Flanking Strike has stacked, Bestial Wrath. Positioning and pet commands stay with you."

L["Default.Era.Mage.Frost.Name"] = "Mage: Frost"
L["Default.Era.Mage.Frost.Description"] = "Frost from level 1 to 60, also for Arcane builds and the Mage default before talents. Frostbolt (Fireball before level 4); Frost Nova when a mob reaches you, except on raid bosses; Arcane Missiles once a mob reaches you if you have Improved Arcane Missiles; Cone of Cold, Arcane Explosion and Blizzard when three or more enemies are engaged; Fire Blast while moving with mana to spare; Fire Blast and the wand finish ordinary mobs when solo; wand when out of mana. Reminders: armor (Ice Armor solo, Mage Armor in a group, never replacing one you chose), Arcane Intellect, conjuring and using mana gems, Ice Barrier, Mana Shield, Evocation, Counterspell, Remove Lesser Curse, Ice Block, Cold Snap, Arcane Power and Presence of Mind. Off by default: the Shatter Flamestrike and rank-1 Frostbolt to stack Winter's Chill. Blink, Polymorph, kiting and target choice stay with you."
L["Default.Era.Mage.Frost.IcyVeins.Name"] = "Mage: Frost AoE grinding (Icy Veins)"
L["Default.Era.Mage.Frost.IcyVeins.Description"] = "Blizzard leveling after Icy Veins' AoE grinding guide, chosen automatically when you play solo with Improved Blizzard. From two engaged enemies: Frost Nova the pack, Cone of Cold while Nova is cooling, Blizzard once nothing is next to you, Arcane Explosion when they are; Frostbolt on a single target, Fire Blast and the wand to finish. Mana Shield and Ice Barrier go up before each pull. Gathering the pack, Blink and kiting stay with you."
L["Default.Era.Mage.Fire.Name"] = "Mage: Fire"
L["Default.Era.Mage.Fire.Description"] = "Fire from level 10 to 60, chosen when you have Fire points and none in Frost, or Fire is your main tree. Pyroblast (else Fireball) opens; Pyroblast after Presence of Mind; Scorch keeps five Fire Vulnerability stacks with Improved Scorch on targets that will live; Fire Blast and Scorch finish; Fireball fills. Three or more engaged enemies: Blast Wave, Flamestrike, Arcane Explosion, Cone of Cold, Blizzard. Reminders: Combustion at five Scorch stacks on elites and long fights, armor, Arcane Intellect, mana gems, Ice Barrier, Mana Shield, Evocation, Counterspell, Remove Lesser Curse, Ice Block, Presence of Mind. Off by default: weaving Fire Blast whenever it is ready."
L["Default.Era.Mage.Fire.WarcraftTavern.Name"] = "Mage: Fire (Warcraft Tavern)"
L["Default.Era.Mage.Fire.WarcraftTavern.Description"] = "Fire after Warcraft Tavern, an alternative to the recommended Fire premade, off by default: enable it and disable that one, or raise its priority. Combustion is spent at the pull on elites and bosses instead of waiting for Scorch stacks; Pyroblast opens; Scorch keeps five stacks with Improved Scorch; Fireball fills; Fire Blast only while moving. Packs: Flamestrike first, then Arcane Explosion, Cone of Cold and Blast Wave close in, Blizzard at range. Same reminders as the Fire premade."
L["Default.SoD.Mage.Fire.Name"] = "Mage: Fire (Season of Discovery)"
L["Default.SoD.Mage.Fire.Description"] = "Season of Discovery Fire from level 1 to 60, and the Mage default there. Uses the runes you have engraved: Pyroblast on Hot Streak at once; Living Bomb kept on targets that will live; Scorch with Improved Scorch while Fire Vulnerability is below two stacks or about to fade; Living Flame on cooldown; Balefire Bolt at five Fire Vulnerability stacks, never at four Balefire stacks or more (the fifth kills you); Frostfire Bolt, else Fireball. Living Bomb, Living Flame and Fire Blast while moving; Living Flame, Living Bomb, Blast Wave, Cone of Cold, Flamestrike and Blizzard on packs. Reminders: Fire Blast with Overheat, Combustion, Icy Veins and Cold Snap, Molten or other armor, Arcane Intellect, mana gems, Ice Barrier, Mana Shield, Evocation, Counterspell, curse removal, Ice Block. Spreading Living Bomb across targets stays with you."
L["Default.SoD.Mage.Frost.Name"] = "Mage: Frost (Season of Discovery)"
L["Default.SoD.Mage.Frost.Description"] = "Season of Discovery Frost from level 10, chosen when Frost is your main tree. Fingers of Frost goes into Ice Lance at three or more of your Glaciate stacks, otherwise into Deep Freeze; Balefire Bolt on a Brain Freeze proc and otherwise when safe, never at four Balefire stacks or more; Living Bomb and Living Flame when engraved; Spellfrost Bolt, else Frostfire Bolt, else Frostbolt. Ice Lance, Frozen Orb, Living Bomb and Fire Blast while moving; Frozen Orb, Living Flame, Living Bomb, Blizzard and Cone of Cold on packs. Reminders: Frozen Orb, Icy Veins, Cold Snap, armor, mana gems and the other Mage reminders. Queuing a spell as a bolt lands stays with you."
L["Default.SoD.Mage.Frost.WarcraftTavern.Name"] = "Mage: Frost, Fire runes (Season of Discovery, Warcraft Tavern)"
L["Default.SoD.Mage.Frost.WarcraftTavern.Description"] = "Warcraft Tavern's Phase 4 Frost build on Fire runes, an alternative to the recommended Season of Discovery Frost premade, off by default: enable it and disable that one, or raise its priority. Pyroblast opens; Pyroblast on Hot Streak; Living Bomb kept up; Scorch to five stacks with Improved Scorch; Balefire Bolt only on a Brain Freeze proc and never at four Balefire stacks or more; Frostfire Bolt fills. Living Bomb and Fire Blast while moving; Living Bomb, Cone of Cold and Blizzard on packs. Reminders: Fire Blast with Overheat, Frozen Orb during Icy Veins, Icy Veins, Cold Snap and the other Mage reminders."
L["Default.SoD.Mage.Arcane.Name"] = "Mage: Arcane (Season of Discovery)"
L["Default.SoD.Mage.Arcane.Description"] = "Season of Discovery Arcane damage, chosen when Arcane is your main tree and Arcane Blast is engraved. Arcane Missiles on Missile Barrage; Arcane Barrage at four Arcane Blast stacks; Balefire Bolt when safe, never at four Balefire stacks or more; Living Flame on cooldown; Arcane Blast fills. Arcane Barrage and Fire Blast while moving; Living Flame and Arcane Explosion on packs. Reminders: Arcane Power on elites and long fights, Presence of Mind with Arcane Power or while moving, Icy Veins, Cold Snap and the other Mage reminders."
L["Default.SoD.Mage.Healer.Name"] = "Mage: Healer (Season of Discovery)"
L["Default.SoD.Mage.Healer.Description"] = "Season of Discovery Mage healing, chosen when Regeneration or Mass Regeneration is engraved. With a friendly target: Rewind Time and Chronostatic Preservation below half health, Regeneration when your Temporal Beacon is missing, Mass Regeneration, Temporal Anomaly. With an enemy target, damage that heals your beacons: Spellfrost Bolt for Frost healers, otherwise Arcane Missiles on Missile Barrage, Arcane Barrage at two Arcane Blast stacks, Balefire Bolt when safe (never at four Balefire stacks or more) and Arcane Blast. Reminders: Arcane Power, Presence of Mind, Frozen Orb and the other Mage reminders. Off by default: Arcane Explosion on packs, and Ice Lance and Deep Freeze for Frost healers. While you channel Mass Regeneration the next spell already shows, so you can cancel it at once (its direct healing is small). Choosing whom to heal stays with you."

L["Default.Era.Paladin.Retribution.Name"] = "Paladin: Retribution"
L["Default.Era.Paladin.Retribution.Description"] = "Melee Retribution from level 1 to 60, and the default for any Paladin no other premade fits. On elites and long fights outside raids, puts up Seal of the Crusader and judges it once; otherwise keeps a seal up (Command with a weapon of 3.5 seconds or slower, else Righteousness), Exorcism and Holy Wrath on Undead and Demons, Hammer of Wrath, Judgement on cooldown, Consecration while Vengeance is up or on two or more close enemies. Reminders: Sanctity, Retribution or Devotion Aura, Blessing of Wisdom solo or Might in a group, a heal between fights, Divine Shield, Divine Protection or Lay on Hands when you are about to die. Seal twisting is a separate premade; target choice and positioning stay with you."
L["Default.Era.Paladin.Retribution.Twist.Name"] = "Paladin: Retribution, seal twisting"
L["Default.Era.Paladin.Retribution.Twist.Description"] = "Off by default; enable it if you twist seals. For a Retribution Paladin with Seal of Command: keeps Seal of Righteousness up, swaps to rank-1 Seal of Command in the last 0.4 seconds before a swing and back again, Judgement whenever it is ready, Exorcism and Holy Wrath on Undead and Demons, Hammer of Wrath, Consecration with Vengeance. Needs a lot of mana and good timing. Same reminders as the Retribution premade."
L["Default.Era.Paladin.Protection.Name"] = "Paladin: Protection"
L["Default.Era.Paladin.Protection.Description"] = "Tanking from level 1 to 60, chosen by Righteous Fury or the Protection tree. Seal of Righteousness (Seal of Wisdom when mana drops below 40%), Holy Shield and Judgement to pull, Holy Shield kept up, Consecration and Holy Wrath (Undead and Demons) when two or more enemies are on you, otherwise Judgement of the Crusader once, then Judgement and Consecration with mana to spare, Exorcism on Undead and Demons. Reminders: Righteous Fury, Devotion Aura, Sanctuary, Kings or Might, Lay on Hands when nearly dead. Taunting, Blessing of Kings spam and spell ranks stay with you."
L["Default.Era.Paladin.Protection.IcyVeins.Name"] = "Paladin: Protection, Seal of Wisdom (Icy Veins)"
L["Default.Era.Paladin.Protection.IcyVeins.Description"] = "Icy Veins' raid tanking with Wowhead's Wisdom rotation, an alternative to the recommended Protection premade, off by default: enable it and disable that one, or raise its priority. Keeps Seal of Wisdom up and judges it whenever the target lacks Judgement of Wisdom, otherwise judges only to pull; Holy Shield, Consecration every cooldown, Holy Wrath on Undead and Demon packs, Exorcism, and Greater Blessing of Kings as the threat filler in a raid. Same reminders as the recommended premade."
L["Default.Era.Paladin.Holy.Name"] = "Paladin: Holy"
L["Default.Era.Paladin.Holy.Description"] = "Healing in a group with the Holy tree, from level 10. Acts on your friendly target and picks the heal by missing health: Cleanse or Purify, Holy Shock while you move, maximum-rank Holy Light below 40%, rank-6 Holy Light below 65%, maximum-rank Flash of Light below 85%, rank-4 Flash of Light below 95%. With an enemy in melee range: Seal of Wisdom and, outside raids, Judgement. Reminders: Concentration or Devotion Aura, Blessing of Wisdom, Divine Favor and Lay on Hands for a target that is very low. Choosing whom to heal stays with you; soloing Holy Paladins get the Retribution premade."
L["Default.SoD.Paladin.Retribution.Name"] = "Paladin: Retribution (Season of Discovery)"
L["Default.SoD.Paladin.Retribution.Description"] = "Season of Discovery melee from level 1 to 60, and the default for any Paladin there. Keeps Seal of Martyrdom up (Righteousness until you have it), opens with Exorcism, casts Divine Storm at three Holy Power, then by weapon speed: with a two-hander of 3.3 seconds or slower, Crusader Strike, Exorcism, Divine Storm and Judgement; with a faster one, Judgement only as the seal runs out, then Exorcism, Crusader Strike and Divine Storm. Consecration with mana or three close enemies, Holy Wrath on Undead and Demons (on anything with Purifying Power engraved), Hammer of Wrath with mana to spare (always with Improved Hammer of Wrath engraved). Runes are used as you engrave them. Reminders: Sanctity Aura, a Blessing, Avenging Wrath with Aura Mastery, a heal between fights, Divine Shield when about to die."
L["Default.SoD.Paladin.Retribution.IcyVeins.Name"] = "Paladin: Retribution (Season of Discovery, Icy Veins Phase 4)"
L["Default.SoD.Paladin.Retribution.IcyVeins.Description"] = "The older Phase 4 list from Icy Veins and Warcraft Tavern, also fine for levelling, an alternative to the recommended Season of Discovery Retribution premade, off by default: enable it and disable that one, or raise its priority. Judgement of the Crusader once on elites and long fights, Seal of Martyrdom, Exorcism, Crusader Strike, Divine Storm and Judgement on cooldown, Consecration with mana or three close enemies, Hammer of Wrath. Same reminders as the recommended premade."
L["Default.SoD.Paladin.Retribution.Twist.Name"] = "Paladin: Retribution, seal twisting (Season of Discovery)"
L["Default.SoD.Paladin.Retribution.Twist.Description"] = "Off by default; enable it if you twist with a slow two-hander. Swaps between Seal of Martyrdom and Seal of Command in the last 0.4 seconds before each swing, suggests nothing on the global cooldown in the 1.9 seconds before it, judges while both seals linger, and uses one filler per swing: Divine Storm at three Holy Power, Crusader Strike, Exorcism. Needs a swing timer and practice."
L["Default.SoD.Paladin.Retribution.Stacking.Name"] = "Paladin: Retribution, seal stacking (Season of Discovery)"
L["Default.SoD.Paladin.Retribution.Stacking.Description"] = "Off by default; enable it with the Soul of the Sealbearer rune or the six-piece set that makes seals linger (Rotation Master cannot see either). Keeps both Seal of Command and Seal of Martyrdom up, Divine Storm at three Holy Power, Crusader Strike, Exorcism, Holy Wrath on Undead and Demons (on anything with Purifying Power engraved), Consecration, and Judgement while both seals are up."
L["Default.SoD.Paladin.Shockadin.Name"] = "Paladin: Shockadin (Season of Discovery, wowsims)"
L["Default.SoD.Paladin.Shockadin.Description"] = "Off by default; enable it if you deal damage with the Holy tree. It applies with Holy as your main tree and Shock and Awe engraved. Seal of Martyrdom (else Righteousness), judged as it runs out, Holy Shock to keep Sunlight up or at three Holy Power, Exorcism and Crusader Strike. Same reminders as the Season of Discovery Retribution premade."
L["Default.SoD.Paladin.Protection.Name"] = "Paladin: Protection (Season of Discovery)"
L["Default.SoD.Paladin.Protection.Description"] = "Season of Discovery tanking, chosen by Righteous Fury, an engraved Hammer of the Righteous or Shield of Righteousness, or the Protection tree. Seal of Martyrdom, a pull with Holy Shield, Avenger's Shield and Exorcism, Holy Shield kept up; on one target Hammer of the Righteous, Shield of Righteousness, Exorcism, Avenger's Shield, Judgement, Divine Storm, Consecration; with three or more enemies on you Hammer of the Righteous, Avenger's Shield, Consecration, Shield of Righteousness, Exorcism. Reminders: Righteous Fury, Holy Shield before a pull, Devotion Aura, Sanctuary or Kings, Avenging Wrath, Divine Protection below 40%, Lay on Hands, Hand of Reckoning in a group when your target attacks someone else."
L["Default.SoD.Paladin.Protection.Wowsims.Name"] = "Paladin: Protection (Season of Discovery, wowsims)"
L["Default.SoD.Paladin.Protection.Wowsims.Description"] = "The wowsims tank list, an alternative to the recommended Season of Discovery Protection premade, off by default: enable it and disable that one, or raise its priority. Judgement whenever a seal is up, the seal renewed just before it runs out, Holy Shield, Avenger's Shield, Hammer of the Righteous, Exorcism, Shield of Righteousness last. Same reminders as the recommended premade."
L["Default.SoD.Paladin.Holy.Name"] = "Paladin: Holy (Season of Discovery)"
L["Default.SoD.Paladin.Holy.Description"] = "Season of Discovery healing in a group, chosen by an engraved Beacon of Light, Divine Light or Sacred Shield, or the Holy tree without Crusader Strike. Acts on your friendly target: Cleanse, Holy Shock while moving or below 30%, Divine Light (Holy Light when mana is under half) below 60%, Flash of Light below 90%. With an enemy in melee range it only keeps a seal up. Reminders: Beacon of Light and Sacred Shield on the target that lacks them, Concentration or Devotion Aura, Blessing of Wisdom, Divine Favor and Lay on Hands for a target that is very low. The guides behind it are from Phase 4; choosing whom to heal stays with you."
L["Default.SoD.Paladin.Holy.Wowhead.Name"] = "Paladin: Holy, Holy Light first (Season of Discovery, Wowhead)"
L["Default.SoD.Paladin.Holy.Wowhead.Description"] = "Wowhead's Phase 4 healing order for crit-heavy gear, an alternative to the recommended Season of Discovery Holy premade, off by default: enable it and disable that one, or raise its priority. Divine Light or Holy Light below 75%, then Cleanse, Holy Shock for small deficits or while moving, Flash of Light below 95%. Same reminders as the recommended premade."

L["Default.Era.Priest.Dps.Name"] = "Priest: Damage"
L["Default.Era.Priest.Dps.Description"] = "Damage from level 1 to 60, and the Priest default whenever the healer premade does not apply (solo, Shadow, or no talents yet). Shadowform when learned; before a pull a shield when solo, then Holy Fire (without Shadowform), Mind Blast or Smite. Shadow Word: Pain once per target that will live, Mind Blast on cooldown, Mind Flay as the filler (Smite and Holy Nova before you have it), and the wand on a dying target or when your mana runs low while solo. Vampiric Embrace and Devouring Plague on long fights, never in raids. Reminders: Inner Fire, Fortitude, racial buffs, Inner Focus with Mind Blast, Psychic Scream when two enemies reach you at half health, Fade when your target turns on you, Desperate Prayer. Target choice, multi-dotting and downranking stay with you."
L["Default.Era.Priest.Dps.WarcraftTavern.Name"] = "Priest: Damage (Warcraft Tavern wand economy)"
L["Default.Era.Priest.Dps.WarcraftTavern.Description"] = "Warcraft Tavern's low-downtime leveling style, an alternative to the recommended damage premade, off by default: enable it and disable that one, or raise its priority. Solo: Mind Blast to pull, Shadow Word: Pain once, Mind Blast again only while the target is above 30%, and your wand between Mind Blasts instead of Smite or Mind Flay. No automatic shield before pulls. In a group: Shadow Word: Pain, Mind Blast, Mind Flay. Same reminders as the recommended premade."
L["Default.Era.Priest.Dps.Wowsims.Name"] = "Priest: Damage (wowsims Undead raid)"
L["Default.Era.Priest.Dps.Wowsims.Description"] = "The recommended damage priority with wowsims' raid choice for Undead priests: Inner Focus is spent on Devouring Plague instead of Mind Blast, and Devouring Plague is cast in raids too, so use it only where your raid has debuff slots to spare. No Vampiric Embrace. An alternative to the recommended damage premade, off by default: enable it and disable that one, or raise its priority."
L["Default.Era.Priest.Healer.Name"] = "Priest: Healer"
L["Default.Era.Priest.Healer.Description"] = "Chosen in a group when Holy or Discipline is your main talent tree. Heals the friendly unit you target: Power Word: Shield below 30%, Flash Heal below 40%, dispels, Prayer of Healing when three of your party are hurt, Greater Heal (Heal or Lesser Heal before you learn it) below half health, Renew while moving or on light damage, then Heal rank 3 as the efficient top-up. Out of combat it offers Fortitude on your target. Targeting an enemy gives Shadow Word: Pain and Smite. Reminders: Inner Fire, Fortitude, Divine Spirit, Inner Focus, Desperate Prayer; Power Infusion is off by default. Choosing whom to heal and downranking stay with you."
L["Default.SoD.Priest.Dps.Name"] = "Priest: Damage (Season of Discovery)"
L["Default.SoD.Priest.Dps.Description"] = "Damage on Season of Discovery realms, from level 1 to 60, using the runes you have engraved. Shadowform; Vampiric Touch or Mind Blast to pull (Penance, Holy Fire or Smite before Shadowform). Void Plague, Shadow Word: Pain and Vampiric Touch kept up (refreshed near the end only without Pain and Suffering engraved), Mind Blast on cooldown, Mind Flay on Melting Faces, Shadow Word: Death while you are above half health, then Mind Spike as the filler, or Mind Flay with the Phase 8 six-piece set. Void Zone and Mind Sear on four or more enemies. The wand on a dying solo target. Reminders: Inner Fire, Fortitude, Homunculi, Shadowfiend, Eye of the Void and Dispersion, Inner Focus, Psychic Scream, Fade, Desperate Prayer."
L["Default.SoD.Priest.Dps.Wowhead.Name"] = "Priest: Damage (Season of Discovery, Wowhead Mind Spike stacks)"
L["Default.SoD.Priest.Dps.Wowhead.Description"] = "The Wowhead and Warcraft Tavern way for Season of Discovery, an alternative to the recommended Season of Discovery damage premade, off by default: enable it and disable that one, or raise its priority. Mind Blast waits for three of your Mind Spike stacks on the target (it is cast normally until you engrave Mind Spike), Mind Flay only on Melting Faces, Mind Spike as the filler. Everything else matches the recommended premade."
L["Default.SoD.Priest.Healer.Name"] = "Priest: Healer (Season of Discovery)"
L["Default.SoD.Priest.Healer.Description"] = "Chosen on Season of Discovery realms in a group when Holy or Discipline is your main talent tree; follows Icy Veins. Heals the friendly unit you target: Prayer of Mending before the pull and whenever ready, Shield below half health, Penance, instant Flash Heal on Surge of Light, emergency Flash Heal, dispels, Circle of Healing and Prayer of Healing when three of your party are hurt, Greater Heal below half health, Renew while moving or on light damage, then Heal. Targeting an enemy gives Pain, Void Plague, Penance, Holy Fire and Smite. Reminders include Shadowfiend, Pain Suppression on a dying target, Power Word: Barrier and Spirit of the Redeemer when the party is hurt."
L["Default.SoD.Priest.Healer.WarcraftTavern.Name"] = "Priest: Healer (Season of Discovery, Warcraft Tavern)"
L["Default.SoD.Priest.Healer.WarcraftTavern.Description"] = "Warcraft Tavern's Serendipity loop, built for Serendipity and Soul Warding, an alternative to the recommended Season of Discovery healer premade, off by default: enable it and disable that one, or raise its priority. Prayer of Mending on cooldown, Shield on your target whenever it can take one (with Soul Warding engraved; else below half health), Penance on heavy damage, Circle of Healing for three hurt, Greater Heal or Prayer of Healing at three Serendipity stacks, Renew on minor damage, and Flash Heal on minor injuries to build the stacks (with Serendipity engraved; else below 30%)."

L["Default.Era.Rogue.DPS.Name"] = "Rogue: melee DPS"
L["Default.Era.Rogue.DPS.Description"] = "Levels 1–60, every spec, also on Hardcore and Self-Found realms; built from wowsims, Icy Veins and Wowhead. From Stealth: Premeditation, Ambush with a dagger when the target is not facing you, Cheap Shot solo, Garrote outside raids. In combat: Riposte, Slice and Dice from one combo point when it is missing on an elite or a healthy target (renewed at five points in its last three seconds), Expose Armor at five points in a group when you have Improved Expose Armor 2/2 and nobody Sunders, a two-point Eviscerate on a target about to die, otherwise Eviscerate at five and no builder past five. The builder follows what you know: Ghostly Strike and Hemorrhage outside raids, Backstab with a dagger when the target is not facing you, else Sinister Strike. Reminders: poisons on each weapon (Deadly on an off-hand weapon when carried), Kick, Thistle Tea, Blade Flurry and Adrenaline Rush on elites or two enemies with Slice and Dice up, Cold Blood at five, Evasion solo when hurt. Vanish, Gouge, Preparation, Kidney Shot and racials are listed off; Feint, Sprint, Blind, Sap and positioning stay with you."
L["Default.Era.Rogue.DPS.WarcraftTavern.Name"] = "Rogue: melee DPS, five-point finishers (Warcraft Tavern)"
L["Default.Era.Rogue.DPS.WarcraftTavern.Description"] = "Warcraft Tavern's way, an alternative to the recommended melee DPS premade, off by default: enable it and disable that one, or raise its priority. Every finisher waits for five combo points so Relentless Strikes refunds it. Slice and Dice is used from its second rank (level 42) when missing or ending, otherwise Eviscerate; no low-point Slice, no near-death Eviscerate and no Expose Armor (a warrior's Sunder covers it). Same openers, builders and reminders as the recommended premade."
L["Default.Era.Rogue.DPS.Wowsims.Name"] = "Rogue: Swords, swing-synced Sinister Strike (wowsims)"
L["Default.Era.Rogue.DPS.Wowsims.Description"] = "The wowsims \"sweaty\" Combat order for Sword Specialization, an alternative to the recommended melee DPS premade, off by default: enable it and disable that one, or raise its priority. Sinister Strike only right after a main-hand swing (2.0 seconds or more to the next one, set for a 2.6–2.8 speed sword; change it in a clone), unless energy is near full or the target is about to die, so the extra sword attack does not delay your swing. Eviscerate at five also waits for Slice and Dice, full energy or a dying target. Otherwise as the recommended premade."
L["Default.SoD.Rogue.DPS.Name"] = "SoD Rogue: melee DPS"
L["Default.SoD.Rogue.DPS.Description"] = "Season of Discovery, levels 1–60 with runes as you engrave them; built from wowsims Phase 6, Icy Veins and Zockify Phase 8. From Stealth: Shadowstrike, Garrote in a group, Ambush for a Backstab build with a dagger, Cheap Shot solo. On three or more enemies fighting you: Blunderbuss, Crimson Tempest, Fan of Knives first. Then Ambush on a Cutthroat proc (with a dagger), Saber Slash kept at three stacks, Poisoned Knife at four poison stacks, Slice and Dice from two points (renewed from four, unless Cut to the Chase is engraved), Expose Armor duty when nobody Sunders or keeps Sebacious Poison up, with Carnage engraved a bleed (Crimson Tempest, else Rupture; none with Saber Slash), Envenom at five (Eviscerate until you engrave it), and a builder by glove rune: Mutilate, Saber Slash, Backstab (with a dagger), else Sinister Strike. Reminders: a temporary enchant on each weapon, Kick, Thistle Tea, Blade Flurry, Adrenaline Rush, Cold Blood and Evasion, and with Master of Subtlety engraved Vanish to renew it and Preparation."
L["Default.SoD.Rogue.DPS.IcyVeins.Name"] = "SoD Rogue: melee DPS, Rupture for Carnage (Icy Veins)"
L["Default.SoD.Rogue.DPS.IcyVeins.Description"] = "Icy Veins' Season of Discovery order, an alternative to the recommended Season of Discovery melee DPS premade, off by default: enable it and disable that one, or raise its priority. Every finisher at five combo points, first Slice and Dice when missing or ending, then Rupture kept up when Carnage is engraved, then Envenom; Poisoned Knife only at five poison stacks; Blunderbuss or Fan of Knives on three enemies. Same openers, builders and reminders as the recommended premade; Sebacious Poison duty stays with you."
L["Default.SoD.Rogue.DPS.Zockify.Name"] = "SoD Rogue: melee DPS, lean Envenom (Zockify)"
L["Default.SoD.Rogue.DPS.Zockify.Description"] = "Zockify's lean Season of Discovery list, an alternative to the recommended Season of Discovery melee DPS premade, off by default: enable it and disable that one, or raise its priority. No bleeds and no Expose Armor. Poisoned Knife at four poison stacks, Slice and Dice when missing (from two points, four with Saber Slash), Envenom at five, then the glove-rune builder. The Vanish and Cold Blood burst stays with you."
L["Default.SoD.Rogue.Tank.Name"] = "SoD Rogue: tank"
L["Default.SoD.Rogue.Tank.Description"] = "Season of Discovery tank, chosen when Just a Flesh Wound is engraved; built from wowsims Phase 6, Icy Veins, Zockify and Warcraft Tavern. Riposte, Main Gauche on cooldown, Blade Dance from one combo point (renewed from three), Slice and Dice from three (renewed from four), Fan of Knives, Crimson Tempest and Blunderbuss on three or more enemies, Blunderbuss while Blade Dance is up, Eviscerate at five with both buffs up, Poisoned Knife at low energy, then Saber Slash, Mutilate or Sinister Strike. Reminders: Tease in a group when your target attacks someone else, Kick, Evasion below half health, Blade Flurry, Adrenaline Rush, Thistle Tea and weapon poisons (the off-hand one only with an off-hand weapon). Shadowstep and Sebacious Poison duty stay with you."

L["Default.Era.Shaman.Enhancement.Name"] = "Shaman: Enhancement"
L["Default.Era.Shaman.Enhancement.Description"] = "Levels 1–60, also on Hardcore and Self-Found realms, and every Shaman without a talent majority; built from Icy Veins, Wowhead and wowsims. Lightning Bolt pulls from range; Earth Shock interrupts. In raids only Stormstrike and Frost Shock (debuff slots). On three or more enemies fighting you, Fire Nova and Magma totems. Then Stormstrike, Earth Shock into the Stormstrike debuff or to finish, Flame Shock when it will run its course, Earth Shock while you have half your mana, and Lightning Bolt while out of reach. Reminders: Rockbiter solo and Windfury Weapon in dungeons, Lightning Shield, Strength of Earth, Searing, Windfury or Grace of Air, Mana Spring or Healing Stream, healing after a pull and in emergencies. Stoneclaw, Earthbind, totem twisting and racials are listed off; dispels, purges and cleansing totems stay with you."
L["Default.Era.Shaman.Enhancement.WarcraftTavern.Name"] = "Shaman: Enhancement, Flame Shock first (Warcraft Tavern)"
L["Default.Era.Shaman.Enhancement.WarcraftTavern.Description"] = "Warcraft Tavern's Enhancement, an alternative to the recommended Enhancement premade, off by default: enable it and disable that one, or raise its priority. Windfury Weapon as soon as you learn it, Stormstrike, Flame Shock before any direct shock, then Earth Shock while your threat is low, or Frost Shock in a group once it is high; Magma and Chain Lightning on packs. Same totems and reminders as the recommended premade."
L["Default.Era.Shaman.Elemental.Name"] = "Shaman: Elemental"
L["Default.Era.Shaman.Elemental.Description"] = "Elemental from level 10 (most points in Elemental); built from Icy Veins and Wowhead. Earth Shock interrupts and finishes a target about to die. While moving: Flame Shock, else Frost Shock. Solo with the target in melee: Earth Shock above 30% health, then melee. On three or more enemies: Fire Nova and Magma totems when you are in melee, and Chain Lightning. Chain Lightning under Elemental Mastery or Clearcasting, otherwise Lightning Bolt. Reminders: Lightning Shield, Rockbiter outside raids, Searing or Magma, Mana Spring or Healing Stream, Elemental Mastery with Chain Lightning ready, Nature's Swiftness and Healing Wave below 30%, healing after a pull. Dispels, purges and downranking stay with you."
L["Default.Era.Shaman.Elemental.Wowsims.Name"] = "Shaman: Elemental, Chain Lightning on cooldown (wowsims)"
L["Default.Era.Shaman.Elemental.Wowsims.Description"] = "The wowsims Elemental list, an alternative to the recommended Elemental premade, off by default: enable it and disable that one, or raise its priority. Chain Lightning on cooldown even on one target, Earth Shock while Elemental Mastery is up, otherwise Lightning Bolt. Faster but much hungrier for mana than the recommended premade; same interrupt, totems and reminders."
L["Default.Era.Shaman.Restoration.Name"] = "Shaman: Restoration"
L["Default.Era.Shaman.Restoration.Description"] = "Restoration from level 10 (most points in Restoration); built from Icy Veins and Wowhead. On your friendly target: Healing Wave under Nature's Swiftness, Nature's Swiftness below 30%, Lesser Healing Wave below 40%, Cure Poison or Cure Disease, Chain Heal when three group members near you are below 85%, otherwise Healing Wave below 90%. On an enemy it fights: Earth Shock interrupt, Chain Lightning on packs, Flame Shock, Lightning Bolt from range, melee. Reminders: Lightning Shield and Rockbiter solo, Mana Tide in a group, Mana Spring, Strength of Earth, Searing. Choosing whom to heal, downranking and Tremor or cleansing totems stay with you; keeping Healing Way on the tank is listed off."
L["Default.Era.Shaman.Restoration.WarcraftTavern.Name"] = "Shaman: Restoration, Chain Heal first (Warcraft Tavern)"
L["Default.Era.Shaman.Restoration.WarcraftTavern.Description"] = "Warcraft Tavern's Restoration, an alternative to the recommended Restoration premade, off by default: enable it and disable that one, or raise its priority. Chain Heal is the heal for anyone below 90%, with Lesser Healing Wave for someone about to die; Healing Wave is only for an assigned tank healer with Healing Way (listed off). Same cures, damage on enemies and totem reminders as the recommended premade."
L["Default.SoD.Shaman.Enhancement.Name"] = "SoD Shaman: Enhancement"
L["Default.SoD.Shaman.Enhancement.Description"] = "Season of Discovery, levels 1–60 with runes as you engrave them, dual wield or two-hander, and every SoD Shaman no other premade fits; built from wowsims Phase 6, Icy Veins and Wowhead. Flame Shock pulls; Earth Shock interrupts. On three or more enemies: Magma, Fire Nova from a fire totem, Chain Lightning at four Maelstrom stacks, Flame Shock. Then Lava Burst at five Maelstrom stacks, Stormstrike, Lava Lash, Lightning Bolt at five stacks, Flame Shock when it will run, Earth Shock, Molten Blast, Lightning Bolt from range. Reminders: Windfury Weapon (Rockbiter before), Flametongue on an off-hand weapon with Lava Lash (else Windfury; never on a shield; an Icy Veins Windfury-both line is listed off), Water or Lightning Shield, Spirit of the Alpha, Feral Spirit, Shamanistic Rage below 65% mana, totems, Ancestral Guidance. Totemic Projection, dispels and purges stay with you."
L["Default.SoD.Shaman.Elemental.Name"] = "SoD Shaman: Elemental"
L["Default.SoD.Shaman.Elemental.Description"] = "Season of Discovery Elemental from level 10 (most points in Elemental); built from wowsims Phase 6, Wowhead and Icy Veins. Earth Shock interrupts. While moving: Flame Shock, Earth Shock at eight Lightning Shield charges, Lava Burst or Chain Lightning on a Power Surge proc. On three or more enemies: Flame Shock, Chain Lightning, Fire Nova, Lava Burst, Earth Shock at eight charges, Magma. Then Lava Burst on Power Surge, Flame Shock kept up, Lava Burst while your Flame Shock lasts, Earth Shock at eight charges, Chain Lightning on two enemies, Lightning Bolt. Reminders: Flametongue for Burn, Lightning Shield, Earth Shield on yourself, Spirit of the Alpha, Feral Spirit, Shamanistic Rage, Elemental Mastery, totems. Trinkets, Totemic Projection, dispels and purges stay with you."
L["Default.SoD.Shaman.Restoration.Name"] = "SoD Shaman: Restoration"
L["Default.SoD.Shaman.Restoration.Description"] = "Season of Discovery Restoration from level 10 (most points in Restoration); built from Icy Veins and Wowhead. On your friendly target: Riptide then Lesser Healing Wave below 40%, Cure Poison or Cure Disease, Healing Rain when three group members near you are below 85%, Chain Heal when two are (at once on a Power Surge proc), Riptide below 95% for Tidal Waves, Healing Wave below 90%. On an enemy it fights. Reminders: Water Shield (Lightning Shield before), Earth Shield on your friendly target or yourself, Shamanistic Rage, Mana Tide, Mana Spring and Strength of Earth. Choosing whom to heal and Tremor or cleansing totems stay with you."
L["Default.SoD.Shaman.Tank.Name"] = "SoD Shaman: tank (Way of Earth)"
L["Default.SoD.Shaman.Tank.Description"] = "Season of Discovery tank, chosen once Way of Earth is engraved; built from Icy Veins, Wowhead, wowsims and Warcraft Tavern. Flame Shock pulls. Earth Shock taunts a target in melee that is not attacking you, and interrupts. On two or more enemies: Molten Blast, Flame Shock, Chain Lightning at five Maelstrom stacks or on Power Surge, Fire Nova at five stacks. Then Flame Shock kept up, Lava Burst on Power Surge or while Flame Shock lasts, Stormstrike, Earth Shock, Lightning Bolt at five stacks, Molten Blast, Frost Shock. Reminders: Rockbiter, Lightning Shield, Spirit of the Alpha on yourself, Feral Spirit, Shamanistic Rage, Searing or Magma, and group totems."

L["Default.Era.Warlock.DPS.Name"] = "Warlock: every tree"
L["Default.Era.Warlock.DPS.Description"] = "Levels 1–60, every talent tree, also on Hardcore and Self-Found realms; built from Wowhead, Icy Veins, Warcraft Tavern and wowsims. Stops while you cast or channel and never tags a mob someone else is fighting while you are solo. Nightfall's Shadow Trance first; Shadowburn and Searing Pain to finish a group target; a solo target about to die gets Drain Soul (for a shard, or with Improved Drain Soul), Shadowburn or Conflagrate, then the wand, never new DoTs. While moving only instants. On three or more enemies: Hellfire when they are on you and you have half your health, otherwise Rain of Fire. One curse: in raids Curse of Shadow or the Elements when nobody has it, Doom on long elite fights, otherwise Agony. Immolate when it pays (Destruction, raids, or with 40% mana), Corruption, Siphon Life (in raids only on Shadow Vulnerability). Solo: Dark Pact, Life Tap when healthy, Drain Life when hurt, the wand. Shadow Bolt otherwise. Reminders: Demon Armor or Demon Skin, your pet (Voidwalker solo, Imp in a group, Succubus for Demonic Sacrifice), Fel Domination, Demonic Sacrifice, Amplify Curse, Voidwalker Sacrifice and a Healthstone when low, Health Funnel. Curse assignments, Curse of Recklessness on a fleeing mob, Fear, Banish, Soulstones and creating Healthstones stay with you."
L["Default.Era.Warlock.DPS.WarcraftTavern.Name"] = "Warlock: drain tank (Warcraft Tavern)"
L["Default.Era.Warlock.DPS.WarcraftTavern.Description"] = "Warcraft Tavern's leveling style, an alternative to the recommended Warlock premade, off by default: enable it and disable that one, or raise its priority. The Imp, then the Succubus from level 20. Immolate, Siphon Life and Corruption, then solo Drain Life as the filler once you learn its fourth rank (the wand before), Life Tap whenever your health is nearly full and Dark Pact before your pet's mana is full. In raids every DoT the slots allow, then Shadow Bolt. Same finishers, curse and safety reminders as the recommended premade; fearing a second mob stays with you."
L["Default.Era.Warlock.DPS.IcyVeins.Name"] = "Warlock: curse and Corruption raids (Icy Veins)"
L["Default.Era.Warlock.DPS.IcyVeins.Description"] = "Icy Veins' list for realms with the 16-debuff limit, an alternative to the recommended Warlock premade, off by default: enable it and disable that one, or raise its priority. In raids only your curse and Corruption, then Shadow Bolt, with no Immolate and no Siphon Life. Leveling and dungeons play as the recommended premade."
L["Default.SoD.Warlock.Tank.Name"] = "SoD Warlock: tank (Metamorphosis)"
L["Default.SoD.Warlock.Tank.Description"] = "Season of Discovery tank, chosen once Metamorphosis is engraved; built from wowsims, Icy Veins, Wowhead and Warcraft Tavern. Shadow Cleave whenever Defender's Resolve is missing or ending, a Soul Fire! proc, Incinerate to keep its fire buff; on three or more enemies Shadow Cleave, Lake of Fire, Shadowflame and Hellfire. Then a curse (Agony, else Recklessness when nobody has it), Shadowflame (Immolate before you engrave it), Master Channeler Drain Life, Corruption, Siphon Life, Conflagrate for Backdraft, Soul Fire under Decimation below 35%, and Searing Pain as the threat filler. Reminders: Metamorphosis, Fel Armor, your pet, Immolation Aura, Demonic Grace, Vengeance when low, Menace when the target attacks someone else, Demonic Howl on packs, Amplify Curse, Life Tap for a pet low on mana. Infernal Armor stays with you."
L["Default.SoD.Warlock.Fire.Name"] = "SoD Warlock: Fire"
L["Default.SoD.Warlock.Fire.Description"] = "Season of Discovery Destruction, chosen once Chaos Bolt or Incinerate is engraved; built from wowsims Phase 6 and Wowhead. Shadowburn and Searing Pain to finish; instants while moving; Incinerate's buff, Lake of Fire and Hellfire on packs; a curse (Recklessness in a group when nobody has it, Doom on long elite fights, else Agony); Conflagrate only to keep Backdraft; Immolate and Incinerate's buff kept up; below 35% Soul Fire under Decimation instead of Chaos Bolt; Soul Fire! procs; Chaos Bolt; solo Master Channeler Drain Life and Life Tap; Incinerate (Shadow Bolt before you engrave it). Reminders: Fel Armor, the Imp, Amplify Curse and the safety reminders."
L["Default.SoD.Warlock.Fire.IcyVeins.Name"] = "SoD Warlock: Fire, Conflagrate on cooldown (Icy Veins)"
L["Default.SoD.Warlock.Fire.IcyVeins.Description"] = "Icy Veins' and Warcraft Tavern's Season of Discovery Destruction, an alternative to the recommended Season of Discovery Fire premade, off by default: enable it and disable that one, or raise its priority. Immolate kept up, Conflagrate and Chaos Bolt on cooldown (Chaos Bolt also below 35%), Incinerate's buff, Soul Fire under Decimation below 35%, Incinerate filler; the damage curse only while moving, with Recklessness in a group when nobody has it."
L["Default.SoD.Warlock.Shadow.Name"] = "SoD Warlock: Shadow (Affliction, Felguard)"
L["Default.SoD.Warlock.Shadow.Description"] = "Season of Discovery Affliction and Felguard builds, and every SoD Warlock no other premade fits; built from wowsims Phase 6, Wowhead and Icy Veins. Nightfall procs; Shadowburn or Drain Soul to finish a group target; a dying solo target gets Drain Soul, not DoTs; instants while moving; Lake of Fire and Hellfire on packs; a curse (Recklessness in a group when nobody has it, else Agony); Unstable Affliction, Master Channeler Drain Life, Shadowflame (Immolate before it), Corruption, Haunt, Siphon Life (each renewed under 6 seconds with Invocation engraved); Drain Soul below 20% with Soul Siphon engraved; solo sustain and the wand; Shadow Bolt. Reminders: Fel Armor, your pet (a Felguard once engraved), Life Tap for a pet low on mana, Amplify Curse and the safety reminders. Curse assignments and Shadow Bolt Volley packs stay with you."
L["Default.SoD.Warlock.Shadow.Wowsims.Name"] = "SoD Warlock: Shadow, Drain Soul filler (wowsims)"
L["Default.SoD.Warlock.Shadow.Wowsims.Description"] = "The wowsims Phase 6 Affliction list for a Soul Siphon build, an alternative to the recommended Season of Discovery Shadow premade, off by default: enable it and disable that one, or raise its priority. Drain Soul is the filler at any health, and the next step shows as soon as it is due so you can clip the channel for it; any other channel is left to finish. Unstable Affliction and Shadowflame renewed with 7.5 seconds left, Agony and Corruption with 6, Master Channeler Drain Life, Haunt, Shadow Bolt only on a Shadow Trance proc, Siphon Life, Life Tap below 10% mana. Same reminders as the recommended premade."

L["Default.Era.Warrior.DPS.Name"] = "Warrior: melee DPS"
L["Default.Era.Warrior.DPS.Description"] = "Levels 1–60, Arms and Fury, and every warrior outside Defensive Stance, also on Hardcore and Self-Found realms; built from wowsims, Icy Veins and Wowhead. Charge to pull, Intercept a distant target, Whirlwind (Thunder Clap before you learn it) on three or more enemies fighting you, then Execute first below 20%, Sunder Armor to five on bosses without Expose Armor, Bloodthirst, Mortal Strike, Slam right after a swing with Improved Slam (set for a two-hander; change it in a clone), Whirlwind while keeping rage for your main strike, Overpower, Rend until your main strike is learned, Sunder Armor on healthy targets and Hamstring near the rage cap. Reminders: Battle Shout, Heroic Strike from 40 rage (20 while leveling), Cleave on packs, Bloodrage, Sweeping Strikes, Death Wish (bosses: their last 30 seconds), Recklessness with Death Wish, Pummel or Shield Bash. Intimidating Shout and Retaliation are listed off for Hardcore emergencies; stance dancing stays with you."
L["Default.Era.Warrior.Protection.Name"] = "Warrior: tank"
L["Default.Era.Warrior.Protection.Description"] = "Chosen whenever you are in Defensive Stance (Protection, Fury-Prot or a two-hander tank); built from Icy Veins and MaxDps. On four or more enemies: Demoralizing Shout and Battle Shout for threat. Then Revenge, Shield Slam, Bloodthirst, Sunder Armor to five, Demoralizing Shout on elites, Sunder Armor as the filler, and Rend before Shield Slam or Bloodthirst. Shield Slam and Shield Block only with a shield on. Reminders: Battle Shout, Shield Block while the target hits you, Bloodrage, Heroic Strike and Cleave from 50 rage, Shield Bash, Last Stand. Taunt, Shield Wall and Death Wish are listed off; Battle Stance for Execute (the DPS premade takes over) and Challenging Shout stay with you."
L["Default.Era.Warrior.Protection.IcyVeins.Name"] = "Warrior: tank, Battle Shout threat (Icy Veins)"
L["Default.Era.Warrior.Protection.IcyVeins.Description"] = "Icy Veins' \"sunderless\" tanking for groups where four or more players hear your shout (Phase 5 Battle Shout onward), an alternative to the recommended tank premade, off by default: enable it and disable that one, or raise its priority. Demoralizing Shout kept up, Revenge, Shield Slam or Bloodthirst, then Battle Shout as the threat filler instead of Sunder Armor; Shield Slam and Shield Block only with a shield on. Same reminders as the recommended tank; go back to Sunder when focusing one target in a crowd."
L["Default.SoD.Warrior.DPS.Name"] = "SoD Warrior: melee DPS"
L["Default.SoD.Warrior.DPS.Description"] = "Season of Discovery, levels 1–60 with runes as you engrave them: two-hander, dual wield, Gladiator and leveling, and every SoD warrior outside Defensive Stance; built from wowsims Phase 6 and Wowhead Phase 7/8. Charge, Victory Rush, Intercept, Whirlwind (Thunder Clap before it) on two or more enemies, Slam at three Slammin' stacks, Rend kept up, Slam on Blood Surge (on cooldown with Precise Timing engraved), Bloodthirst, Mortal Strike, Shield Slam (with a shield), Overpower; then Quick Strike when it is engraved (two-hander), otherwise Whirlwind, Raging Blow and Devastate (Sunder before it); Execute with 30 rage or on Sudden Death; Hamstring near the rage cap. Reminders: Battle and Commanding Shout, Heroic Strike from 50 rage (always while Consumed by Rage enrages you), Cleave, Bloodrage, Rampage, Death Wish, Recklessness, Sweeping Strikes, interrupts. Berserker Rage and the Taste for Blood Battle Stance dip are listed off."
L["Default.SoD.Warrior.DPS.Wowhead.Name"] = "SoD Warrior: Battle Forecaster stance dance (Wowhead)"
L["Default.SoD.Warrior.DPS.Wowhead.Description"] = "Wowhead's Phase 7/8 rotation for Soul of the Battle Forecaster or the Tier 1 six-piece (which Rotation Master cannot see), an alternative to the recommended Season of Discovery melee DPS premade, off by default: enable it and disable that one, or raise its priority. Stance swaps to keep the forecast buffs up, Heroic Strike almost always, then Bloodthirst, Blood Surge Slam, Whirlwind, Raging Blow and Hamstring; no Rend and no Overpower. Check the swap timing in game before relying on it."
L["Default.SoD.Warrior.DPS.IcyVeins.Name"] = "SoD Warrior: melee DPS (Icy Veins)"
L["Default.SoD.Warrior.DPS.IcyVeins.Description"] = "Icy Veins' Season of Discovery Fury and Arms pages, an alternative to the recommended Season of Discovery melee DPS premade, off by default: enable it and disable that one, or raise its priority. Execute near the top below 20% or on Sudden Death, Slam on Blood Surge, Bloodthirst or Mortal Strike, Whirlwind, Overpower, Raging Blow, then Quick Strike and Hamstring only above 60 rage; no Rend; Heroic Strike only above 80 rage. Same reminders as the recommended premade."
L["Default.SoD.Warrior.Tank.Name"] = "SoD Warrior: tank"
L["Default.SoD.Warrior.Tank.Description"] = "Season of Discovery tank, chosen in Defensive Stance; built from Wowhead Phase 8 and wowsims. Charge; on two or more enemies Thunder Clap, Shockwave, Shield Slam, Revenge, Whirlwind and Devastate; then Shield Slam whenever Defender's Resolve is missing or ending, Revenge, Shield Slam, Shockwave, Execute, Whirlwind at five Gladiator's Cunning stacks, Devastate (Sunder before it), Demoralizing Shout and Thunder Clap on elites, Rend before Shield Slam; Shield Slam and Shield Block only with a shield on. Reminders: Battle and Commanding Shout, Shield Block, Heroic Strike from 50 rage, Cleave from 55, Bloodrage, Rampage, Last Stand, interrupts. Taunt, Shield Wall, Death Wish, Recklessness and Retaliation are listed off; the Gladiator swap for Execute stays with you."

L["Default.MoP.DeathKnight.Blood.Name"] = "Death Knight: Blood (MoP)"
L["Default.MoP.DeathKnight.Blood.Description"] = "Recommended for Blood tanks, chosen in the Blood specialization. Pulls from range with Outbreak, Icy Touch or Death Grip. Death Strike below half health, whenever Blood Shield is missing (from 80), and before all four Frost and Unholy runes sit full; Rune Strike near 90 runic power (Death Coil at 80 before you learn it); Outbreak, else Icy Touch and Plague Strike, for diseases, and Blood Boil to refresh them from 68; Soul Reaper under 35%; Heart Strike (Blood Strike before 60) on two Blood runes; Crimson Scourge on Death and Decay while diseases last, else Blood Boil; Blood Tap at eleven charges; then Death Strike, Heart Strike, Rune Strike and Horn of Winter. Three enemies on you: Death and Decay, a disease spread (Blood Boil with Roiling Blood, else Pestilence) and Blood Boil. Reminders: Blood Presence when you have none, Bone Shield, Horn of Winter, Mind Freeze, Rune Tap, Vampiric Blood, Icebound Fortitude, Empower Rune Weapon and Death Pact by your health, Dancing Rune Weapon on elites, Army of the Dead before a group boss. It cannot see incoming damage, so Anti-Magic Shell (off) and big defensives are yours."
L["Default.MoP.DeathKnight.Blood.Wowsims.Name"] = "Death Knight: Blood, health-reactive (MoP, wowsims)"
L["Default.MoP.DeathKnight.Blood.Wowsims.Description"] = "An alternative to the recommended Blood premade for raid tanks with healers, off by default: enable it and disable that one, or raise its priority. Death Strike only below 70% health, when Blood Shield is missing or about to fade, or before the Frost and Unholy runes cap, instead of on every rune; a lone Blood rune goes to Heart Strike when the Frost and Unholy runes are more than a second away. It has no area-of-effect section, and the same reminders as the recommended one."
L["Default.MoP.DeathKnight.FrostDualWield.Name"] = "Death Knight: Frost, two weapons (MoP)"
L["Default.MoP.DeathKnight.FrostDualWield.Description"] = "Recommended for Frost with two one-handed weapons (Masterfrost); chosen in the Frost specialization while your off hand holds a weapon. Pulls with Outbreak or Howling Blast (Death Grip solo). Death Strike on Dark Succor or below 35% health, Blood Tap at eleven charges, diseases (Unholy Blight, Outbreak, Howling Blast, Plague Strike), Soul Reaper under 35%, Frost Strike on Killing Machine or above 89 runic power, Howling Blast on Rime or with both Frost or both Death runes ready, Obliterate on two Unholy runes below 77 runic power, Frost Strike above 76, Obliterate, Howling Blast, Plague Leech before diseases fade with Outbreak ready, Frost Strike at 40, Horn of Winter. Three enemies on you: a disease spread, Death and Decay and Howling Blast. Reminders: Frost Presence, Pillar of Frost, Raise Dead, Empower Rune Weapon with every rune down, Horn of Winter, Mind Freeze, Icebound Fortitude and Death Pact when low, Army of the Dead before a group boss."
L["Default.MoP.DeathKnight.Frost.Name"] = "Death Knight: Frost, two-hander (MoP)"
L["Default.MoP.DeathKnight.Frost.Description"] = "Frost with a two-handed weapon, the usual leveling setup; chosen in the Frost specialization whenever the two-weapon premade does not apply. Same opening, diseases, survival and AoE as the two-weapon premade, then Obliterate on Killing Machine, Frost Strike above 76 runic power, Howling Blast on Rime, Obliterate whenever a rune pair is full, Obliterate, Howling Blast, Plague Leech, Frost Strike at 40 and Horn of Winter. Before Obliterate (58) Death Strike spends your Unholy runes. Same reminders as the two-weapon premade."
L["Default.MoP.DeathKnight.Unholy.Name"] = "Death Knight: Unholy (MoP)"
L["Default.MoP.DeathKnight.Unholy.Description"] = "Recommended for Unholy, and the premade for any Death Knight Blood and Frost do not claim, including one without a specialization. Pulls from range with Outbreak or Icy Touch (Death Grip solo). Death Strike on Dark Succor or below 35% health, diseases (Unholy Blight, Outbreak, Plague Strike, Icy Touch), Blood Tap at eleven charges, Soul Reaper under 35%, Dark Transformation at five Shadow Infusion stacks, Death Coil near the runic power cap, Death and Decay on a target that will live, Scourge Strike, Death Coil on Sudden Doom or at 40, Outbreak while Unholy Strength is up, Festering Strike (Blood Strike before you learn it), Plague Leech, Horn of Winter. Three enemies on you: a disease spread, Death and Decay, Blood Boil and Icy Touch on a Frost rune. Reminders: Unholy Presence, your ghoul, Summon Gargoyle under Bloodlust or on a long elite fight, Unholy Frenzy, Empower Rune Weapon, Horn of Winter, Mind Freeze, Icebound Fortitude and Death Pact when low, Army of the Dead before a group boss; Anti-Magic Shell is off."
L["Default.MoP.DeathKnight.Unholy.Wowsims.Name"] = "Death Knight: Unholy, rune-cap pooling (MoP, wowsims)"
L["Default.MoP.DeathKnight.Unholy.Wowsims.Description"] = "An alternative to the recommended Unholy premade, as the simulator, wowtbc.gg, Method and MaxDps play it; off by default: enable it and disable that one, or raise its priority. While Dark Transformation is down Death Coil goes to rebuilding Shadow Infusion, Scourge Strike comes first when both Unholy or both Death runes are ready, and Festering Strike first when both Blood and both Frost runes are; otherwise the same opening, diseases, AoE and reminders as the recommended one."

L["Default.MoP.Druid.Unspecialized.Name"] = "Druid: Before a specialization (MoP)"
L["Default.MoP.Druid.Unspecialized.Description"] = "For levels 1 to 9, or any druid who has not chosen a specialization yet; the specialization premades take over once you pick one. In Cat Form it keeps Rake up, spends five combo points (or two on a dying target) on Ferocious Bite and builds with Mangle; in Bear Form it uses Mangle and Maul. Otherwise it pulls with Wrath, keeps Moonfire on targets that will last, casts Wrath (Moonfire while moving) and suggests Rejuvenation on yourself when you are below half health and alone. It stops while you cast, travel or have no enemy targeted."
L["Default.MoP.Druid.Balance.Name"] = "Druid: Balance (MoP)"
L["Default.MoP.Druid.Balance.Description"] = "Recommended for Balance from level 10, after Wowhead's Phase 5 list and wowsims. Keeps Moonfire and Sunfire up and refreshes them inside the matching Eclipse, casts Starfall in Lunar Eclipse, Starsurge on Shooting Stars and on cooldown, Hurricane in Solar or Astral Storm in Lunar at five enemies, Starfire in and after Lunar and Wrath in and after Solar. Rotation Master cannot read Eclipse energy, so between Eclipses it keeps casting Starfire if Starfire was one of your last three casts, otherwise Wrath. Reminders: Mark of the Wild, Moonkin Form, Incarnation as an Eclipse starts and Celestial Alignment as one ends (on elites or long fights), Nature's Vigil, Force of Nature, Nature's Swiftness for Dream of Cenarius, Innervate, Solar Beam, Barkskin and Renewal when low. Wild Mushroom placement stays manual; the Detonate reminder is off by default. It stops while you cast, travel, are in Cat or Bear Form, or have no enemy targeted."
L["Default.MoP.Druid.Feral.Name"] = "Druid: Feral (MoP)"
L["Default.MoP.Druid.Feral.Description"] = "Recommended for Feral from level 10, after wowsims and Wowhead's Phase 5 list. Puts you in Cat Form, opens from Prowl with Savage Roar and Ravage, keeps Savage Roar up, uses Predatory Swiftness for a Healing Touch at four or five combo points with Dream of Cenarius, Rip at five points (Ferocious Bite refreshes it below 25% health), Ferocious Bite at five points while Rip and Savage Roar both have six seconds left, Rake, Thrash on Clearcasting, Shred on Clearcasting or Berserk when the target is not attacking you (Rotation Master cannot tell whether you are behind it) and Mangle; Thrash and Swipe at four enemies. In Bear Form it gives a short tanking list. Reminders: Tiger's Fury under 35 energy, Berserk with it on elites or long fights, Incarnation, Force of Nature, Nature's Vigil, Skull Bash, Survival Instincts and Barkskin when low, Mark of the Wild. Bear- and Wrath-weaving, and Heart of the Wild, stay manual."
L["Default.MoP.Druid.Feral.IcyVeins.Name"] = "Druid: Feral, Bite only in execute (MoP, Icy Veins)"
L["Default.MoP.Druid.Feral.IcyVeins.Description"] = "Icy Veins' Feral order (Wowhead's Bite rule agrees), an alternative to the recommended Feral premade: enable it and disable that one, or raise its priority. Same opener, Savage Roar, Healing Touch and AoE, but combo points above 25% target health go only to Rip and Savage Roar: Ferocious Bite only refreshes Rip in execute (or spends five points before you learn Rip). Rake refreshes at two seconds, Thrash only on Clearcasting, and Berserk waits for 90 energy with Tiger's Fury at least 15 seconds away."
L["Default.MoP.Druid.Guardian.Name"] = "Druid: Guardian (MoP)"
L["Default.MoP.Druid.Guardian.Description"] = "Recommended for Guardian tanks from level 10, after wowsims and Wowhead's Phase 5 list. Puts you in Bear Form, pulls with Faerie Fire from range or Mangle, keeps Weakened Blows up with Thrash and Weakened Armor with Faerie Fire on elites, uses a Dream of Cenarius Healing Touch when hurt, Mangle on cooldown, Thrash and Swipe at three enemies, then Lacerate, Thrash and Faerie Fire. In Cat Form (Heart of the Wild) it gives a short damage list. Reminders: Savage Defense whenever it is down, Enrage for rage, Frenzied Regeneration when low or rage-capped, Maul above 90 rage or on Tooth and Claw, Barkskin while the target attacks you, Survival Instincts when low, Berserk and Incarnation on two enemies or a boss, Force of Nature, Nature's Vigil, Cenarion Ward, Skull Bash, Mark of the Wild. Taunting and Might of Ursoc stay manual (both reminders are off by default)."
L["Default.MoP.Druid.Restoration.Name"] = "Druid: Restoration (MoP)"
L["Default.MoP.Druid.Restoration.Description"] = "Recommended for Restoration from level 10, after Wowhead's Phase 5 group healing. Heals your current friendly target, or you with no target; choosing whom to heal is up to you. Swiftmend on a target with your HoT when it is low, when Harmony has dropped, or into Wild Growth with Soul of the Forest; Wild Growth when three people nearby are hurt; instant Healing Touch on Nature's Swiftness; Regrowth on Clearcasting or a dying target; Rejuvenation; then Healing Touch and Nourish while standing still. An attackable target gets Moonfire and Wrath. Reminders: Lifebloom stacks and Ironbark on your focus (set the tank as focus), Wild Mushroom: Bloom on group damage, Force of Nature, Incarnation, Nature's Vigil, Nature's Swiftness, Innervate, Nature's Cure, Cenarion Ward, Barkskin, Mark of the Wild. Wild Mushroom placement, Tranquility and Genesis reminders are off by default."
L["Default.MoP.Druid.Restoration.Wowhead.Name"] = "Druid: Restoration, tank healing (MoP, Wowhead)"
L["Default.MoP.Druid.Restoration.Wowhead.Description"] = "Wowhead's single-target tank-healing order, an alternative to the recommended Restoration premade for when you are assigned to the tank: enable it and disable that one, or raise its priority. Keep the tank targeted: it keeps three Lifeblooms and Rejuvenation on it, uses Regrowth for heavy damage, Nourish for light damage, Healing Touch once Lifebloom and Rejuvenation are rolling and the tank is below half, and Swiftmend to keep it topped up. Same reminders as the recommended premade."

L["Default.MoP.Hunter.BeastMastery.Name"] = "Hunter: Beast Mastery (MoP)"
L["Default.MoP.Hunter.BeastMastery.Description"] = "Chosen automatically in the Beast Mastery specialization. Opens with Hunter's Mark and Kill Command, then: Kill Shot, Kill Command (held for a moment when Bestial Wrath is about to be ready), A Murder of Crows, Lynx Rush, Dire Beast and your tier-six shot when talented, Focus Fire at five Frenzy stacks (or four about to fall off) but not during Bestial Wrath, Serpent Sting on targets that will live, Cobra Shot to refresh it, Arcane Shot at 80 focus or during Bestial Wrath, then Cobra Shot (Steady Shot before 81). With two or more enemies fighting you it keeps Beast Cleave up with Multi-Shot, saves Kill Command for spare focus on big packs and suggests Explosive Trap from three. Reminders: pet out, revived and mended, Aspect of the Hawk or Iron Hawk, Counter Shot, Fervor, and Bestial Wrath, Rapid Fire, Stampede and racials when the fight is worth it (an elite, a dungeon or raid, or a target that will live). Trap placement, Misdirection, Feign Death and defensives stay with you; Exhilaration and Deterrence reminders are off by default."
L["Default.MoP.Hunter.Marksmanship.Name"] = "Hunter: Marksmanship (MoP)"
L["Default.MoP.Hunter.Marksmanship.Description"] = "Chosen automatically in the Marksmanship specialization. Pre-casts Aimed Shot, then: Steady Shots in pairs to keep Steady Focus up (from 63), Chimera Shot, Serpent Sting on targets that will live, Aimed Shot whenever Fire! makes it instant, Kill Shot, your talents, and a hard-cast Aimed Shot while the target is above 80% health, under Rapid Fire or Bloodlust, at 85 focus or when Chimera Shot is a few seconds away. Arcane Shot only while you are moving; otherwise Steady Shot. Four or more enemies: Chimera Shot, instant Aimed Shot, Multi-Shot, Kill Shot, Explosive Trap. Same reminders as the other Hunter premades. If you prefer spending spare focus on Arcane Shot, use the Arcane Shot variant."
L["Default.MoP.Hunter.Marksmanship.IcyVeins.Name"] = "Hunter: Marksmanship, Arcane Shot dump (MoP, Icy Veins)"
L["Default.MoP.Hunter.Marksmanship.IcyVeins.Description"] = "An alternative to the Marksmanship premade, as Icy Veins, Method, wowtbc.gg and Hekili play it: Aimed Shot is hard-cast only above 80% target health or under Rapid Fire or Bloodlust, and spare focus goes to Arcane Shot at 60 instead. Steady Focus is refreshed under 4 seconds; on four or more enemies Multi-Shot comes first. Off by default: enable it and disable the Marksmanship premade, or raise its priority."
L["Default.MoP.Hunter.Survival.Name"] = "Hunter: Survival (MoP)"
L["Default.MoP.Hunter.Survival.Description"] = "Chosen automatically in the Survival specialization. Opens with Hunter's Mark, Black Arrow and Explosive Shot, then: Explosive Shot on cooldown and on every Lock and Load, Kill Shot, Black Arrow on targets that will live, your talents, Serpent Sting kept up by Cobra Shot, Arcane Shot at 75 focus, with Thrill of the Hunt, or at 55 when Black Arrow is not coming up, then Cobra Shot (Steady Shot before 81). Two or more enemies: Multi-Shot first on Lock and Load with full focus, Explosive Shot up to five targets, Kill Shot, Black Arrow, Explosive Trap from three, Multi-Shot to spend. Same reminders as the other Hunter premades; traps for Lock and Load procs stay with you."
L["Default.MoP.Hunter.Unspecialized.Name"] = "Hunter: before a specialization (MoP)"
L["Default.MoP.Hunter.Unspecialized.Description"] = "For levels 1 to 9 and any Hunter who has not chosen a specialization; the Beast Mastery, Marksmanship and Survival premades take over as soon as you choose a specialization. Pulls with Hunter's Mark and Arcane Shot, then Serpent Sting on targets that will live, Multi-Shot on three or more enemies, Arcane Shot, Steady Shot and Auto Shot. Reminds you to call, revive and mend your pet and to keep Aspect of the Hawk up."

L["Default.MoP.Mage.Arcane.Name"] = "Mage: Arcane (MoP)"
L["Default.MoP.Mage.Arcane.Description"] = "Recommended for Arcane, from level 10 to 90 (selected in the Arcane specialization). Arcane Blast builds four Arcane Charges; with four, an Arcane Missiles! proc is spent with Missiles, and without one Arcane Barrage comes out once your mana drops below 90%. Above 95% mana it keeps blasting, which is how the simulator plays it. Missiles is never left sitting on two procs, Barrage is cast before Alter Time snaps back, and with two or more enemies Barrage goes out every four charges; Cone of Cold and Arcane Explosion when five are close. Keeps your talented bomb up, and Fire Blast or Ice Lance while moving without Ice Floes. Reminders: Arcane Power and Alter Time at four charges with a proc, Frost Armor (Molten before 54), Arcane Brilliance, Counterspell, Mana Gem, Mirror Image, Ice Barrier, Ice Floes, Rune of Power or Invocation. Time Warp, Spellsteal and Presence of Mind are off; Rune of Power still needs placing by hand."
L["Default.MoP.Mage.Arcane.IcyVeins.Name"] = "Mage: Arcane, Barrage at four charges (MoP, Icy Veins)"
L["Default.MoP.Mage.Arcane.IcyVeins.Description"] = "The guides' Arcane rule (Icy Veins, Wowhead, Method, wowtbc.gg), an alternative to the recommended Arcane premade: at four Arcane Charges, Arcane Missiles if a proc is up, otherwise Arcane Barrage, whatever your mana; Missiles only at four charges. Everything else (Alter Time, bombs, AoE, moving, reminders) matches the recommended one, except that Arcane Power is suggested at four charges without waiting for a proc. Off by default: enable it and disable the recommended Arcane premade, or raise its priority."
L["Default.MoP.Mage.Fire.Name"] = "Mage: Fire (MoP)"
L["Default.MoP.Mage.Fire.Description"] = "Recommended for Fire, from level 10 to 90 (selected in the Fire specialization). Opens with a hard Pyroblast, then Inferno Blast (Fire Blast before 24) turns Heating Up into a Pyroblast! proc, which is cast at once unless Combustion is about to come off cooldown; then it waits for the next Heating Up while you cast Fireball. Combustion lights right after a Pyroblast while Ignite and the Pyroblast burn are on the target; the addon cannot see how big Ignite is, so judge a weak one yourself. Keeps your talented bomb up, spreads with Inferno Blast when two or more enemies fight you, Cone of Cold and Arcane Explosion for five close by, Scorch on the move. Reminders: Molten Armor, Presence of Mind, Alter Time with both procs, Mana Gem, Arcane Brilliance, Counterspell, Mirror Image, Ice Barrier, Ice Floes, Invocation or Rune of Power. Dragon's Breath, Time Warp and Spellsteal are off."
L["Default.MoP.Mage.Fire.IcyVeins.Name"] = "Mage: Fire, hold Pyroblast! (MoP, Icy Veins)"
L["Default.MoP.Mage.Fire.IcyVeins.Description"] = "Icy Veins', Method's and wowtbc.gg's Fire play, an alternative to the recommended Fire premade: a Pyroblast! proc is held until a Heating Up joins it, then cast together with your Fireball, and spent alone only when it is about to expire. Everything else matches the recommended one. Off by default: enable it and disable the recommended Fire premade, or raise its priority."
L["Default.MoP.Mage.Frost.Name"] = "Mage: Frost (MoP)"
L["Default.MoP.Mage.Frost.Description"] = "Frost from level 10 to 90 (selected in the Frost specialization). Ice Lance at two Fingers of Frost, Frostfire Bolt on Brain Freeze, your talented bomb, Frozen Orb, Ice Lance on one Fingers of Frost, Frostbolt; from 87 a proc is held for Alter Time when it is less than 10 seconds away. With two or more enemies: Frozen Orb, Cone of Cold and Arcane Explosion when they are close, Blizzard when four stand still. Ice Lance and Fire Blast on the move without Ice Floes. Reminders: Water Elemental, Freeze on anything but a boss (place it yourself), Icy Veins timed with Alter Time, Alter Time at two Fingers of Frost in Icy Veins, Frost Armor (Molten before 54), Mana Gem, Arcane Brilliance, Counterspell, Mirror Image, Ice Barrier, Ice Floes, Invocation or Rune of Power. Cold Snap, Presence of Mind, Time Warp and Spellsteal are off."
L["Default.MoP.Mage.Unspecialized.Name"] = "Mage: before a specialization (MoP)"
L["Default.MoP.Mage.Unspecialized.Description"] = "For levels 1 to 9, and any Mage who has not chosen a specialization yet. Frostfire Bolt, Fire Blast to finish a target or on the move, Ice Lance on the move once learned, Arcane Explosion when three or more enemies are in melee range. Reminders: Frost Nova when a mob reaches you, Counterspell, and Molten Armor and Arcane Brilliance if you reach them. Choosing a specialization at 10 switches to that specialization's premade."

L["Default.MoP.Monk.Brewmaster.Name"] = "Monk: Brewmaster (MoP)"
L["Default.MoP.Monk.Brewmaster.Description"] = "Picked automatically in the Brewmaster specialization. Keeps Shuffle up with Blackout Kick, uses Keg Smash whenever its Chi fits, Expel Harm when you are hurt (at once below 35%), Jab to spend energy, Tiger Palm for Tiger Power and as the free filler (Jab builds Chi before level 34), and Touch of Death when it is usable. From range out of combat: Chi Wave, Dizzying Haze, Clash or Keg Smash. On three or more enemies: Rushing Jade Wind, Breath of Fire and Spinning Crane Kick only while Shuffle has time left. Reminders: Sturdy Ox, Legacy of the Emperor, Purifying Brew on Heavy Stagger (Moderate when Shuffle is banked), Elusive Brew from six stacks, Guard with Power Guard, Chi Brew, Xuen, Fortifying Brew, Dampen Harm or Diffuse Magic when low, Spear Hand Strike. The Black Ox Statue reminder is off; Avert Harm, Zen Meditation and Provoke stay with you."
L["Default.MoP.Monk.Brewmaster.Offensive.Name"] = "Monk: Brewmaster, damage first (MoP, wowsims)"
L["Default.MoP.Monk.Brewmaster.Offensive.Description"] = "An alternative to the Brewmaster premade, off by default: enable it and disable that one, or raise its priority. Follows the simulator's damage-first list for a tank who outgears the content: Rushing Jade Wind before Keg Smash, Chi spent on Blackout Kick for damage, and no routine Purifying Brew or Guard (Purifying Brew only lights on the tier-15 Purifier proc). Elusive Brew, Chi Brew, Xuen and Fortifying Brew are still reminders."
L["Default.MoP.Monk.Windwalker.Name"] = "Monk: Windwalker (MoP)"
L["Default.MoP.Monk.Windwalker.Description"] = "Picked automatically in the Windwalker specialization. Touch of Death when usable, Tiger Palm to keep Tiger Power, Rising Sun Kick on cooldown, Chi Wave, Combo Breaker procs, Fists of Fury when you are standing still and its channel will not cap your energy, Jab when two Chi are missing (Expel Harm instead when hurt), Blackout Kick without starving the next Rising Sun Kick. On two or more enemies Rising Sun Kick keeps its debuff up and Spinning Crane Kick or Rushing Jade Wind joins from three. Reminders: Fierce Tiger, Legacy of the Emperor and of the White Tiger, Tigereye Brew at 19 stacks (15 with Chi to spend, 10 under Bloodlust or near the end of a fight), Energizing Brew at low energy, Chi Brew, Xuen, Storm, Earth, and Fire on two enemies (you cast it on the second one), Touch of Karma, defensives and Spear Hand Strike. Energy-to-cap checks are energy thresholds, so tune them to your haste."
L["Default.MoP.Monk.Windwalker.Simc.Name"] = "Monk: Windwalker, SimulationCraft 5.4.8 (MoP, Hekili and MaxDps)"
L["Default.MoP.Monk.Windwalker.Simc.Description"] = "An alternative to the Windwalker premade, off by default: enable it and disable that one, or raise its priority. The original SimulationCraft list that the Hekili and MaxDps addons ship: Tiger Power refreshed at three seconds, Rising Sun Kick first while its debuff is missing, Fists of Fury saved for Tigereye Brew (active or 15 stacks), Tigereye Brew at 20 stacks or at 15 with Chi and both buffs up. On three or more enemies it spends on Spinning Crane Kick, uses Rising Sun Kick only at full Chi and pools energy below 60."
L["Default.MoP.Monk.Mistweaver.Name"] = "Monk: Mistweaver (MoP)"
L["Default.MoP.Monk.Mistweaver.Description"] = "Picked automatically in the Mistweaver specialization. With a friendly target it heals that target: Renewing Mist on cooldown, Uplift when three or more nearby allies are hurt, Expel Harm and your Chi talent for Chi, Rushing Jade Wind or Spinning Crane Kick for a hurt group, Surging Mist on five Vital Mists, Soothing Mist when the target is below 80%, then Enveloping Mist and Surging Mist inside that channel. With an enemy target it fistweaves: Tiger Palm and Blackout Kick on Muscle Memory to keep Tiger Power and Serpent's Zeal, Blackout Kick when Chi is full, Surging Mist on five Vital Mists, Renewing Mist and Expel Harm for Chi, Jab. Reminders: Wise Serpent, Legacy of the Emperor, the Jade Serpent Statue in a group, Mana Tea in quiet moments, Thunder Focus Tea, Chi Brew, Life Cocoon on a friend below 35%, Xuen, Detox, defensives, Spear Hand Strike. You choose whom to heal; Revival (reminder off) and Healing Sphere stay with you."
L["Default.MoP.Monk.Unspecialized.Name"] = "Monk: before a specialization (MoP)"
L["Default.MoP.Monk.Unspecialized.Description"] = "For levels 1 to 9, or any monk who has not chosen a specialization; a specialization premade takes over as soon as you pick one. Keeps Fierce Tiger and Tiger Power up, spends two Chi on Blackout Kick, uses Expel Harm when you are hurt and Jab otherwise."

L["Default.MoP.Paladin.Retribution.Name"] = "Paladin: Retribution (MoP)"
L["Default.MoP.Paladin.Retribution.Description"] = "Recommended for Retribution, from level 10 in the Retribution specialization. Keeps Inquisition up (cast at 3 Holy Power, refreshed in its last 3 seconds; from 81), spends Templar's Verdict at full Holy Power or on a free proc before generating more, then Hammer of Wrath, Crusader Strike, Judgment and Exorcism, and Templar's Verdict at 3 when nothing else is ready. In Avenging Wrath it spends at once and puts Judgment ahead of Crusader Strike. Two or more enemies on you switch to Divine Storm, with Hammer of the Righteous when four are close. Pulls from range with Judgment or Exorcism, and suggests Word of Glory when you are solo and in danger. Reminders: Seal of Truth when another seal is active or none (Seal of Righteousness is kept), Blessing of Kings or Might, Rebuke, Avenging Wrath and Guardian of Ancient Kings with Inquisition up on elites, Holy Avenger in wings, Execution Sentence and Light's Hammer, and Divine Protection and Lay on Hands when low. Seal of Righteousness for packs and glyph choices stay with you."
L["Default.MoP.Paladin.Retribution.WarcraftTavern.Name"] = "Paladin: Retribution, Exorcism first (MoP, Warcraft Tavern)"
L["Default.MoP.Paladin.Retribution.WarcraftTavern.Description"] = "An alternative to the recommended Retribution premade, off by default: enable it and disable that one, or raise its priority. Exorcism on every cooldown and Art of War reset comes first; Inquisition is cast at any Holy Power when it is missing and refreshed at 3 in its last 20 seconds; then Crusader Strike, Judgment, Templar's Verdict and Hammer of Wrath (first in wings with Sanctified Wrath). Two or more enemies use Crusader Strike, Light's Hammer, Judgment, Divine Storm and Hammer of Wrath. Avenging Wrath and Guardian of Ancient Kings are suggested only on elites. The guide's Seal of Righteousness on any cleave is left to you."
L["Default.MoP.Paladin.Protection.Name"] = "Paladin: Protection (MoP)"
L["Default.MoP.Paladin.Protection.Description"] = "Recommended for Protection, from level 10 in the Protection specialization. Pulls with Avenger's Shield, then Avenger's Shield on a Grand Crusader proc, Avenger's Shield, Hammer of Wrath, Crusader Strike, Judgment, your level-90 talent, Consecration, Holy Wrath and Sacred Shield. Three or more enemies on you switch to Avenger's Shield, Consecration, Hammer of the Righteous, Judgment and Holy Wrath. Shield of the Righteous, Eternal Flame and Word of Glory are off the global cooldown, so they light beside the rotation: Shield of the Righteous whenever you can afford it, Eternal Flame on yourself when it is running out with 3 Holy Power and three Bastion of Glory stacks, Word of Glory below half health without that talent. Other reminders: Righteous Fury, Seal of Insight when another seal (except Righteousness) or none is active, blessings, Rebuke, Sacred Shield, Avenging Wrath and Holy Avenger while you are tanking, and Guardian of Ancient Kings, Ardent Defender, Divine Protection and Lay on Hands by your health. It cannot see incoming damage, so plan big defensives yourself."
L["Default.MoP.Paladin.Protection.Wowsims.Name"] = "Paladin: Protection, pool Holy Power (MoP, wowsims)"
L["Default.MoP.Paladin.Protection.Wowsims.Description"] = "An alternative to the recommended Protection premade, off by default: enable it and disable that one, or raise its priority. Follows the simulator's tank lists: Shield of the Righteous waits for full Holy Power unless you fall below 40% health or Divine Purpose makes it free; Eternal Flame just before it fades with more than two Bastion of Glory stacks; Sacred Shield kept up; Holy Avenger and Avenging Wrath on cooldown. Generators run Crusader Strike, Judgment, then Avenger's Shield, Holy Wrath, the level-90 talent and Hammer of Wrath, with the same three-enemy AoE order. Boss-timed defensives are yours."
L["Default.MoP.Paladin.Holy.Name"] = "Paladin: Holy healing (MoP)"
L["Default.MoP.Paladin.Holy.Description"] = "For Holy, from level 10 in the Holy specialization. With a friend targeted it heals: at 3 Holy Power (or Divine Purpose) Light of Dawn when three people near you are hurt, else Eternal Flame on a target without it, else Word of Glory; Holy Shock on cooldown; Infusion of Light into Holy Radiance or Divine Light, three Selfless Healer stacks into Holy Radiance or Flash of Light; Flash of Light below 35%; Holy Radiance for a hurt group; Divine Light, then Holy Light to top off. With an enemy targeted it deals damage: Holy Shock, Judgment, Crusader Strike, Holy Prism, Execution Sentence, Hammer of Wrath, Denounce. Reminders: Seal of Insight when another seal (except Righteousness) or none is active, blessings, Rebuke, Beacon of Light and Sacred Shield on your focus (set the tank as focus), Divine Plea below 60% mana, Light's Hammer and your healing cooldowns when three people are below 70%, Lay on Hands on a dying target. Choosing whom to heal, dispels and mouseover healing stay with you."
L["Default.MoP.Paladin.Unspecialized.Name"] = "Paladin: before a specialization (MoP)"
L["Default.MoP.Paladin.Unspecialized.Description"] = "For levels 1 to 9, and any paladin who has not chosen a specialization yet; a specialization's premade takes over as soon as you pick one. Pulls from range with Judgment, then Crusader Strike and Judgment, with Hammer of Justice when you are solo and below half health and Word of Glory below 40%. Reminders: Seal of Command (Seal of Truth from 24) when you are not in it, Blessing of Kings, Rebuke, and Flash of Light out of combat when you are hurt."

-- Mists of Pandaria Classic premades: Priest, Rogue, Shaman, Warlock, Warrior.
L["Default.MoP.Priest.Discipline.Name"] = "Priest: Discipline (MoP)"
L["Default.MoP.Priest.Discipline.Description"] = "Discipline healing from level 10 to 90, chosen in the Discipline specialization. Target a friend to heal them: Power Word: Shield when they are low, before the pull and about every 12 seconds for Rapture; Flash Heal on Surge of Light; Penance; Flash Heal when they are very low; Binding Heal when you are both hurt; Prayer of Mending; Prayer of Healing and your tier-6 talent when three allies are hurt; Greater Heal; Renew while moving; Heal to top up. Under Spirit Shell it suggests Prayer of Healing or Greater Heal. Target an enemy to heal through Atonement: Penance, Power Word: Solace or Holy Fire, your tier-6 talent on packs, Shadow Word: Pain when solo, Smite. Reminders: Inner Fire, Fortitude, Archangel at five Evangelism, Inner Focus, Pain Suppression on a dying target, Shadowfiend or Mindbender for mana, Power Infusion, Desperate Prayer. Left to you: whom to heal, Spirit Shell timing (a reminder you can switch on), Power Word: Barrier, Void Shift and Grace stacks on the tank."
L["Default.MoP.Priest.Holy.Name"] = "Priest: Holy (MoP)"
L["Default.MoP.Priest.Holy.Description"] = "Holy healing from level 10 to 90, chosen in the Holy specialization. Target a friend to heal them: Holy Word: Serenity in Chakra: Serenity; Power Word: Shield only when they are about to die; Flash Heal on Surge of Light; Prayer of Mending; Flash Heal when very low; Binding Heal when you are both hurt; in a group with three allies hurt, Circle of Healing, Holy Word: Sanctuary in Chakra: Sanctuary, your tier-6 talent and Prayer of Healing; Renew; Greater Heal when low or at two Serendipity; Heal. Target an enemy to deal damage: Holy Word: Chastise, Power Word: Solace or Holy Fire, Shadow Word: Pain when solo, your tier-6 talent on packs, Smite. An empty chakra is filled for you (Sanctuary in a raid, Serenity in a party, Chastise solo) and never swapped. Reminders: Inner Fire, Fortitude, Guardian Spirit on a dying target, Divine Hymn when five allies are badly hurt, Shadowfiend or Mindbender for mana, Power Infusion, Desperate Prayer. Left to you: whom to heal, placing Holy Word: Sanctuary, Lightwell and Void Shift."
L["Default.MoP.Priest.Holy.IcyVeins.Name"] = "Priest: Holy, emergency heals last (MoP, Icy Veins)"
L["Default.MoP.Priest.Holy.IcyVeins.Description"] = "Off by default. Icy Veins' Holy order, picked by your chakra. In Chakra: Sanctuary: Holy Word: Sanctuary when three allies are hurt, Renew, Circle of Healing, Prayer of Mending, Prayer of Healing, then Binding Heal and Flash Heal only in emergencies. Otherwise: Renew, Holy Word: Serenity, Prayer of Mending, Greater Heal, Heal, Binding Heal, Flash Heal, Power Word: Shield last, and Flash Heal as the filler before you learn Heal. Same switch, reminders and damage list as the recommended Holy premade; enable it and disable that one to use it."
L["Default.MoP.Priest.Shadow.Name"] = "Priest: Shadow (MoP)"
L["Default.MoP.Priest.Shadow.Description"] = "Shadow damage from level 10 to 90, chosen in the Shadow specialization. Opens with Mind Spike, Mind Blast or your DoTs. Devouring Plague at three Shadow Orbs (when Mind Blast is ready or still six seconds away), Mind Blast, Shadow Word: Death below 20% health, Mind Flay while your Devouring Plague is up if you took Solace and Insanity, Shadow Word: Pain and Vampiric Touch refreshed near the end on a target that will live, Mind Spike on Surge of Darkness, Halo, Cascade or Divine Star at their best range, then Mind Flay. A Mind Flay is cut short for Mind Blast or Shadow Word: Death, or after its second tick; other channels are never interrupted. While moving it suggests instants only. On five or more enemies: your tier-6 talent, DoTs on your target and Mind Sear. Reminders: Shadowform, Inner Fire, Fortitude, Silence on interruptible casts, Shadowfiend or Mindbender and Power Infusion on long fights, Vampiric Embrace, Desperate Prayer and Dispersion when low. Left to you: DoTs on other targets and where Mind Sear lands."
L["Default.MoP.Priest.Shadow.WarcraftTavern.Name"] = "Priest: Shadow, no Insanity priority (MoP, Warcraft Tavern)"
L["Default.MoP.Priest.Shadow.WarcraftTavern.Description"] = "Off by default. Warcraft Tavern's Shadow order: Devouring Plague at three Shadow Orbs, Shadow Word: Death below 20%, Mind Blast, Vampiric Touch, Shadow Word: Pain, Mind Spike on Surge of Darkness, your tier-6 talent, Mind Flay. Unlike the recommended Shadow premade it never raises Mind Flay under Devouring Plague and does not hold Devouring Plague for Mind Blast. Same opener, movement, pack and reminder steps; enable it and disable the recommended one to use it."
L["Default.MoP.Priest.Unspecialized.Name"] = "Priest: Unspecialized (MoP)"
L["Default.MoP.Priest.Unspecialized.Description"] = "For levels 1 to 9, or any priest who has not chosen a specialization yet. On an enemy: Shadow Word: Pain when it will live long enough, then Smite. On a friend: Flash Heal when they are low, otherwise Power Word: Shield. Reminders: Inner Fire, and a shield on yourself when you are solo and hurt. Choosing a specialization at 10 switches to its own premade."

L["Default.MoP.Rogue.Assassination.Name"] = "Rogue: Assassination (MoP)"
L["Default.MoP.Rogue.Assassination.Description"] = "Recommended for Assassination, from level 10 to 90 (wowsims and Wowhead for Phase 5, with Icy Veins' levelling steps). Opens from Stealth with Cheap Shot when solo, otherwise Mutilate (Dispatch on Blindside, with a dagger). Keeps Slice and Dice up (Envenom refreshes it from level 60) and Rupture on the target, spends five points on Envenom while Rupture lasts and four points to keep the Envenom buff rolling when you do not have Anticipation, then Marked for Death, Dispatch below 35% or on Blindside (it needs a dagger in the main hand), and Mutilate. Against four or more enemies fighting you: Slice and Dice, Crimson Tempest at seven, Rupture, Envenom and Fan of Knives; tabbing Rupture onto other targets is up to you. Solo it adds Recuperate and a Kidney Shot when you are low. Reminders: poisons, Kick, Vendetta on long fights, Shadow Blades with Vendetta, Vanish and Preparation inside Vendetta, Shadowstep from range, Evasion solo. Left to you: Tricks of the Trade and Expose Armor (listed but off), Feint, Sprint and positioning."
L["Default.MoP.Rogue.Assassination.IcyVeins.Name"] = "Rogue: Assassination, Envenom at five (MoP, Icy Veins)"
L["Default.MoP.Rogue.Assassination.IcyVeins.Description"] = "Off by default. The Icy Veins and Method order: Vanish on cooldown for a stealthed Mutilate, Vendetta on cooldown when the fight is long enough, Envenom only at five points, Rupture kept up, Dispatch below 35% or on Blindside, Mutilate. Four to eight enemies: Fan of Knives with Rupture at three points or more; nine or more: Fan of Knives and Envenom only. The recommended Assassination premade follows the newer Phase 5 advice instead; to use this one, enable it and disable the recommended one."
L["Default.MoP.Rogue.Combat.Name"] = "Rogue: Combat (MoP)"
L["Default.MoP.Rogue.Combat.Description"] = "Recommended for Combat, from level 10 to 90 (Wowhead and wowsims for Phase 5). Since the Siege of Orgrimmar patch Sinister Strike costs 50 energy, so Revealing Strike is the builder and Sinister Strike is used only under Bloodlust or Heroism with Adrenaline Rush (and before level 20). Opens with Cheap Shot solo, otherwise Ambush. Keeps Slice and Dice up from two points and Revealing Strike on the target, spends five points only while Revealing Strike is up (Slice and Dice, Rupture on a long single-target fight without Blade Flurry, Eviscerate) and waits for energy at five. Against eight or more enemies: Slice and Dice, Crimson Tempest and Fan of Knives. Solo it adds Recuperate and Kidney Shot. Reminders: poisons, Kick, Blade Flurry on against two or more enemies and off again, Adrenaline Rush at low energy with Shadow Blades, Killing Spree, Vanish and Preparation for Ambush in Deep Insight, Shadowstep, Evasion solo. Left to you: Tricks of the Trade and Expose Armor (listed but off), Feint and positioning behind the target for Ambush."
L["Default.MoP.Rogue.Combat.IcyVeins.Name"] = "Rogue: Combat, Sinister Strike builder (MoP, Icy Veins)"
L["Default.MoP.Rogue.Combat.IcyVeins.Description"] = "Off by default, and superseded for Phase 5. The Icy Veins, Warcraft Tavern, Method and wowtbc.gg order from before the Siege of Orgrimmar patch: Slice and Dice, Revealing Strike kept up, five-point Rupture on a long single-target fight and Eviscerate, with Sinister Strike as the builder. Same reminders and pack play as the recommended Combat premade. Choose it only if you follow those guides; enable it and disable the recommended one."
L["Default.MoP.Rogue.Combat.Hekili.Name"] = "Rogue: Combat with Anticipation (MoP, Hekili)"
L["Default.MoP.Rogue.Combat.Hekili.Description"] = "Off by default. The Hekili MoP order for Combat with Anticipation: Revealing Strike is the only builder, even under Bloodlust; finishers wait for Deep Insight, four Anticipation charges or Shadow Blades coming back, then Slice and Dice, Rupture on one or two long-lived targets, Crimson Tempest at seven enemies and Eviscerate; Slice and Dice is refreshed early at 11 Bandit's Guile stacks; Fan of Knives from four enemies. It applies only with Anticipation talented. Enable it and disable the recommended Combat premade to use it."
L["Default.MoP.Rogue.Subtlety.Name"] = "Rogue: Subtlety (MoP)"
L["Default.MoP.Rogue.Subtlety.Description"] = "Recommended for Subtlety with Shadow Focus, from level 10 to 90 (wowsims and Wowhead for Phase 5). In Stealth or Shadow Dance: Premeditation, Slice and Dice before the pull, finishers at five points, Ambush, Garrote. Outside: Slice and Dice; at five points Slice and Dice and Rupture when they are about to drop, Eviscerate while both last; Marked for Death; Hemorrhage to keep its bleed; Backstab (with a dagger) when the target is not attacking you, otherwise Hemorrhage. Against three or more enemies: Slice and Dice, Crimson Tempest, Eviscerate and Fan of Knives. Solo it adds Recuperate and Kidney Shot. Reminders: poisons, Kick, Shadow Dance at 75 energy with Slice and Dice and Rupture up, Vanish when Find Weakness is ending, Preparation, Shadow Blades outside Dance and Stealth, Shadowstep, Evasion solo. Left to you: standing behind the target (RM cannot see facing), Tricks of the Trade and Expose Armor (listed but off)."
L["Default.MoP.Rogue.Subtlety.WarcraftTavern.Name"] = "Rogue: Subtlety, Subterfuge (MoP, Warcraft Tavern)"
L["Default.MoP.Rogue.Subtlety.WarcraftTavern.Description"] = "Chosen automatically instead of the Shadow Focus premade when your tier-1 talent is Subterfuge (Warcraft Tavern's build). Premeditation and Slice and Dice before the pull; in Stealth, Shadow Dance or the Subterfuge linger, finishers at five points and then Ambush as often as it lands. Two or three enemies: keep Rupture up and spend five points on Crimson Tempest instead of Eviscerate; four or more add Fan of Knives. One target: Slice and Dice, Rupture, Eviscerate, Hemorrhage for its bleed, Backstab from behind with a dagger, else Hemorrhage. Shadow Dance and Vanish are reminders at 60 energy with Slice and Dice up; timing them to trinket procs, as Tavern suggests, is up to you."
L["Default.MoP.Rogue.Unspecialized.Name"] = "Rogue: Unspecialized (MoP)"
L["Default.MoP.Rogue.Unspecialized.Description"] = "For levels 1 to 9, or a rogue who has not chosen a specialization yet; each specialization's premade takes over once you pick one. Opens from Stealth with Cheap Shot when solo, Ambush or Sinister Strike; suggests Stealth out of combat; Slice and Dice from two points, Recuperate and Kidney Shot when solo and hurt, Eviscerate at four points (two when the target is about to die), Sinister Strike. Reminders: poisons once learned, Kick, Evasion solo."

L["Default.MoP.Shaman.Elemental.Name"] = "Shaman: Elemental (MoP)"
L["Default.MoP.Shaman.Elemental.Description"] = "Recommended for Elemental from level 10, chosen in the Elemental specialization. Wowhead's order: a Lightning Bolt to open (Lava Burst with Unleashed Fury), Unleash Elements with Unleashed Fury, Flame Shock when it is missing or about to run out on a target that will live, Lava Burst into Flame Shock (and on every Lava Surge), Elemental Blast, Earth Shock at six Lightning Shield charges while Flame Shock has 6 seconds left, Chain Lightning on two enemies, Lightning Bolt. Four or more enemies on you: Magma in melee, free Lava Bursts, Lava Beam in Ascendance, Chain Lightning. While moving it shows only instants. Reminders: Lightning Shield, Flametongue, Searing Totem, Fire Elemental on elites and bosses, Elemental Mastery, Ascendance after a Lava Burst, Ancestral Swiftness, Stormlash and Bloodlust in a group, Wind Shear, Thunderstorm for mana, Shamanistic Rage and Astral Shift when low. Earthquake and Earth Elemental are listed but off. Left to you: Spiritwalker's Grace, Flame Shock on extra targets and where to stand."
L["Default.MoP.Shaman.Enhancement.Name"] = "Shaman: Enhancement (MoP)"
L["Default.MoP.Shaman.Enhancement.Description"] = "Recommended for Enhancement from level 10, chosen in the Enhancement specialization. Wowhead's order: Unleash Elements while running in, then Unleash Elements with Unleashed Fury, Elemental Blast and Lightning Bolt at five Maelstrom Weapon (or woven at three when your next swing is over a second away), Stormblast in Ascendance, Stormstrike (Primal Strike before 26), Lava Lash, Flame Shock under Unleash Flame, Unleash Elements, Earth Shock. Two or more enemies on you: Chain Lightning instead of Lightning Bolt, Lava Lash to spread Flame Shock, Fire Nova from four, Magma from six. Reminders: Lightning Shield, Windfury on the main hand and Flametongue on the off hand, Searing Totem, Fire Elemental, Feral Spirit, Ascendance after Stormstrike, Elemental Mastery, Ancestral Swiftness, Stormlash and Bloodlust in a group, Wind Shear, Shamanistic Rage and Astral Shift when low. Earth Elemental is listed but off."
L["Default.MoP.Shaman.Enhancement.Wowsims.Name"] = "Shaman: Enhancement, weave every stack (MoP, wowsims)"
L["Default.MoP.Shaman.Enhancement.Wowsims.Description"] = "Off by default; same switch as the recommended Enhancement premade, so enable it and disable that one to use it. The simulator's list for players who time casts between swings: Lightning Bolt, Elemental Blast or Chain Lightning on any number of Maelstrom Weapon stacks whenever the cast finishes before your next main-hand swing, Unleash Elements also whenever Flame Shock is missing, and Earth Shock only below two stacks. Reminders as the recommended premade."
L["Default.MoP.Shaman.Enhancement.IcyVeins.Name"] = "Shaman: Enhancement, Lava Lash first (MoP, Icy Veins)"
L["Default.MoP.Shaman.Enhancement.IcyVeins.Description"] = "Off by default; same switch as the recommended Enhancement premade, so enable it and disable that one to use it. Icy Veins' order: Stormstrike, then Lava Lash before spending Maelstrom Weapon, Lightning Bolt at five stacks or from three when it lands before your next swing, Unleash Elements then Flame Shock, Earth Shock. On four or more enemies it spreads Flame Shock with Lava Lash and uses Fire Nova; Chain Lightning replaces Lightning Bolt on packs. Shamanistic Rage is suggested on cooldown in combat; other reminders as the recommended premade."
L["Default.MoP.Shaman.Restoration.Name"] = "Shaman: Restoration (MoP)"
L["Default.MoP.Shaman.Restoration.Description"] = "Recommended for Restoration from level 10, chosen in the Restoration specialization. Heals your friendly target (Rotation Master cannot pick who to heal): Greater Healing Wave under Ancestral Swiftness, Healing Surge below 35%, Purify Spirit on Magic or Curses, Unleash Elements then Healing Rain when three allies nearby are hurt, Riptide, Chain Heal for group damage, Greater Healing Wave below 60%, Healing Wave below 90%. With an attackable target it deals damage instead (Flame Shock, Lava Burst, Elemental Blast, Lightning Bolt). Reminders: Water Shield, Earthliving, Earth Shield on your focus, Healing Stream when someone is hurt, Mana Tide, Healing Tide for heavy group damage, Elemental Mastery or Ancestral Guidance, Ancestral Swiftness on a low target, Spiritwalker's Grace while moving, Bloodlust, Wind Shear. Ascendance and Spirit Link Totem are listed but off: use them when your raid assigns them."
L["Default.MoP.Shaman.Restoration.Hekili.Name"] = "Shaman: Restoration, health ladder (MoP, Hekili)"
L["Default.MoP.Shaman.Restoration.Hekili.Description"] = "Off by default; same switch as the recommended Restoration premade, so enable it and disable that one to use it. Hekili's list keeps Earth Shield and Riptide on your target and Healing Stream and Healing Rain going whenever they are down, then heals by the average health of your group within 40 yards: Chain Heal below 80%, Healing Wave on a target below 70%, Greater Healing Wave below 60%, Healing Surge below 40%, with Healing Tide, Ancestral Guidance and Mana Tide on the same ladder. An attackable target gets damage plus Earth Shock."
L["Default.MoP.Shaman.Unspecialized.Name"] = "Shaman: Unspecialized (MoP)"
L["Default.MoP.Shaman.Unspecialized.Description"] = "For levels 1 to 9, and any Shaman who has not chosen a specialization yet; every specialization premade takes over once you pick one. Lightning Bolt to pull from range, Healing Surge when you are low and alone, Primal Strike, Earth Shock, and Lightning Bolt while out of melee range. Keeps Lightning Shield up."

L["Default.MoP.Warlock.Affliction.Name"] = "Warlock: Affliction (MoP)"
L["Default.MoP.Warlock.Affliction.Description"] = "Recommended for Affliction from level 10 to 90 (chosen in the Affliction specialization). Pre-casts Haunt or Unstable Affliction, opens a fresh elite with Soulburn and Soul Swap, keeps Agony, Corruption and Unstable Affliction up (refreshing them early while Dark Soul: Misery is up), casts Haunt whenever it runs low and you have two shards (or in Dark Soul), channels Drain Soul for a shard when Haunt is ending and you have none, Drain Soul below 20%, otherwise Malefic Grasp (Shadow Bolt before 42). Seed of Corruption on three or more enemies (with Soulburn on six). Moving: instants and Fel Flame. Reminders: your pet, Dark Intent, Curse of the Elements in a group, Dark Soul, Doomguard or Infernal, Grimoire of Service or Sacrifice, Life Tap, defensives. Left to you: spreading DoTs to other targets and Soul Swap moves between them."
L["Default.MoP.Warlock.Affliction.WarcraftTavern.Name"] = "Warlock: Affliction, pool Haunt (MoP, Warcraft Tavern)"
L["Default.MoP.Warlock.Affliction.WarcraftTavern.Description"] = "Off by default. Warcraft Tavern's and Method's shard policy: the same DoT upkeep as the recommended Affliction premade, but Haunt is saved for four shards or Dark Soul: Misery, and below 20% Soulburn and Soul Swap refresh every DoT whenever you have a shard. Enable it and disable the recommended Affliction premade to use it."
L["Default.MoP.Warlock.Demonology.Name"] = "Warlock: Demonology (MoP)"
L["Default.MoP.Warlock.Demonology.Description"] = "Recommended for Demonology from level 10 to 90 (chosen in the Demonology specialization). In caster form: Corruption, Hand of Gul'dan by charges, a second Hand of Gul'dan into Metamorphosis when a one-stack Shadowflame is about to drop, Metamorphosis with Dark Soul: Knowledge (or near full fury), Soul Fire at two Molten Core stacks or below 25%, Hellfire on four or more enemies, Shadow Bolt. In Metamorphosis: Doom, Touch of Chaos to keep Corruption up, Soul Fire on Molten Core, Immolation Aura or Void Ray on packs, Touch of Chaos, and a cue to leave it when Dark Soul is down and fury is at 300 or less. Reminders: Felguard (or Wrathguard), Dark Intent, Dark Soul, Imp Swarm, Grimoire: Felguard, Doomguard or Infernal, Life Tap, Health Funnel solo. Left to you: Felstorm (pet autocast) and Demonic Leap."
L["Default.MoP.Warlock.Demonology.Guide.Name"] = "Warlock: Demonology, pool Molten Core (MoP, guides)"
L["Default.MoP.Warlock.Demonology.Guide.Description"] = "Off by default. The guide consensus (Method, wowtbc.gg, Warcraft Tavern, Wowhead): the recommended Demonology premade, except that in caster form Metamorphosis waits for 900 fury or Dark Soul and Soul Fire is only cast at eight Molten Core stacks or below 25%, so the stacks are spent in demon form. Enable it and disable the recommended Demonology premade to use it."
L["Default.MoP.Warlock.Destruction.Name"] = "Warlock: Destruction (MoP)"
L["Default.MoP.Warlock.Destruction.Description"] = "For Destruction from level 10 to 90 (chosen in the Destruction specialization). Pre-casts Incinerate, keeps Immolate up, never sits on two Conflagrate charges, spends embers on Chaos Bolt (Shadowburn below 20%) at 3.5 embers or in Dark Soul: Instability, uses Backdraft on Incinerate, and fills with Incinerate; a dying target gets Shadowburn. On three or more enemies: Rain of Fire and Fire and Brimstone on four, then Immolate, Conflagrate and Incinerate, and a cue to switch Fire and Brimstone off when your embers run out. Moving: Shadowburn, Conflagrate, Fel Flame. Reminders: your pet or Grimoire of Sacrifice, Flames of Xoroth, Dark Intent, Dark Soul, Havoc on two or more enemies (cast it on the second target yourself), Doomguard or Infernal, Ember Tap and defensives."
L["Default.MoP.Warlock.Unspecialized.Name"] = "Warlock: Unspecialized (MoP)"
L["Default.MoP.Warlock.Unspecialized.Description"] = "For a Warlock without a specialization (levels 1 to 9, or later before you choose one). Corruption to pull and kept up, Drain Life below half health, Shadow Bolt. Reminders: the Voidwalker when solo (the Imp in a group), and a Healthstone between pulls."

L["Default.MoP.Warrior.Arms.Name"] = "Warrior: Arms (MoP)"
L["Default.MoP.Warrior.Arms.Description"] = "Recommended for Arms from level 10 to 90, picked in the Arms specialization. Charges to open, and again for rage when you step away. Colossus Smash whenever it is missing or about to end, Mortal Strike, Storm Bolt in the Smash window, Dragon Roar and Bladestorm outside it. Below 20% health: Execute in the window, at 100 rage or to keep Sudden Execute, Overpower on Taste for Blood. Otherwise Slam in the window, Overpower at four stacks, Slam at 100 rage, Overpower, Slam. Two or more enemies fighting you add Sweeping Strikes, Thunder Clap for Deep Wounds, Bladestorm and Dragon Roar. Victory Rush below 70% health; Battle Shout for rage. Reminders: a shout when none is up, Battle Stance, Berserker Rage, Recklessness, Avatar and Bloodbath with Colossus Smash on long fights, Skull Banner, Heroic Strike or Cleave with spare rage, Heroic Leap in the window, Pummel, Die by the Sword and Enraged Regeneration when low. Shattering Throw is listed but off. Left to you: cancelling Bladestorm, stance dancing and positioning."
L["Default.MoP.Warrior.Arms.IcyVeins.Name"] = "Warrior: Arms, pool for Colossus Smash (MoP, Icy Veins)"
L["Default.MoP.Warrior.Arms.IcyVeins.Description"] = "Off by default. The Icy Veins and Wowhead Arms order: outside the Colossus Smash window it uses Overpower and Slams only above 80 rage, banking rage for the window instead of Slamming as filler. In the window: Mortal Strike, Slam, Overpower, Heroic Throw. Below 20% health: Colossus Smash, Mortal Strike, Execute, Overpower, Dragon Roar. Sweeping Strikes on two enemies, a Thunder Clap pack list on three or more. Heroic Strike or Cleave only near the rage cap. Same reminders as the recommended Arms premade. Enable it and disable that one to use it."
L["Default.MoP.Warrior.Fury.Name"] = "Warrior: Fury (MoP)"
L["Default.MoP.Warrior.Fury.Description"] = "Recommended for Fury from level 10 to 90, picked in the Fury specialization. Charges to open and for rage. Colossus Smash once two Raging Blow charges are banked (one with Recklessness), Raging Blow as the window closes, Bloodthirst, Colossus Smash, Storm Bolt, Dragon Roar outside the window, Execute here with Single-Minded Fury (one-handers), Bladestorm while Bloodthirst cools, with Titan's Grip (two-handers) one more Raging Blow outside the window, Execute, Wild Strike on Bloodsurge, Raging Blow keeping a charge for the next window, Wild Strike, Heroic Throw, Battle Shout for rage. Two or more enemies fighting you add Bladestorm, Dragon Roar, Whirlwind for Meat Cleaver and cleaving Raging Blows. Reminders: a shout when none is up, Battle Stance, Berserker Rage for Enrage, Recklessness, Avatar and Bloodbath with Colossus Smash on long fights, Skull Banner, Heroic Strike or Cleave with spare rage, Heroic Leap, Pummel and defensives when low. Left to you: cancelling Bladestorm."
L["Default.MoP.Warrior.Fury.IcyVeins.Name"] = "Warrior: Fury, cooldowns in Colossus Smash (MoP, Icy Veins)"
L["Default.MoP.Warrior.Fury.IcyVeins.Description"] = "Off by default. Icy Veins' Fury order spends Bladestorm or Dragon Roar first inside the Colossus Smash window, and puts Execute ahead of Bloodthirst below 20% health. Outside the window: Colossus Smash, Bloodthirst, Raging Blow only at two charges, Wild Strike on Bloodsurge, shout, Wild Strike. Four or more enemies: Bloodthirst for Enrage, Whirlwind to three Meat Cleaver stacks, Raging Blow. Heroic Strike or Cleave only near the rage cap. Same reminders as the recommended Fury premade. Enable it and disable that one to use it."
L["Default.MoP.Warrior.Protection.Name"] = "Warrior: Protection (MoP)"
L["Default.MoP.Warrior.Protection.Description"] = "Tanking from level 10 to 90, picked in the Protection specialization. Charge or Heroic Throw to pull. Devastate to keep three Weakened Armor on elites and bosses, Dragon Roar, Bladestorm, Shockwave on three enemies and Thunder Clap on cooldown on three or more. Then Revenge for the last rage of a Shield Block, Shield Slam, Revenge on Hold the Line, Devastate for Deep Wounds, Victory Rush below 60% health, Revenge, Thunder Clap for Weakened Blows, Execute, Storm Bolt, a shout for rage and Devastate (Sunder Armor before 26). Reminders: Defensive Stance, a shout when none is up, Shield Block whenever it is down, Shield Barrier when hurt with rage to spare, Heroic Strike or Cleave on Ultimatum, Incite or near the cap, Demoralizing Shout, Berserker Rage, Enraged Regeneration, Last Stand and Shield Wall when low, your offensive cooldowns, Pummel. Taunt and Heroic Leap are listed but off. Left to you: whom to taunt, and Block versus Barrier against magic."
L["Default.MoP.Warrior.Unspecialized.Name"] = "Warrior: Unspecialized (MoP)"
L["Default.MoP.Warrior.Unspecialized.Description"] = "For levels 1 to 9, or until you choose a specialization. Charge to pull, Victory Rush, Execute and Heroic Strike when you have 30 rage; reminds you to be in Battle Stance if you are in no stance."

L['Help.General.memory_capture'] = "Start a ten-minute memory capture. Whole-Lua heap reads occur once per second; slower addon-memory refreshes and bounded container counts occur every thirty seconds. Sampling costs are reported. The capture does not force garbage collection, enable the native profiler or change gameplay polling."
L['Help.General.memory_report'] = "Open the completed or stopped memory observations in a selectable, copyable report. Addon memory is sampled attribution, and container counts are rows or keys rather than bytes. Memory drops alone do not prove garbage collection or the absence of a leak."
L['Help.General.memory_stop'] = "Stop the current memory capture and preserve its observations for Memory report. This cancels only memory-capture timers. No gameplay settings are changed."

L['Silent'] = true


-- Original condition artwork picker labels.
L["Set Pieces"] = true
L["Weapon Imbue"] = true

-- Blizzard Assisted Combat (condition and rotation step).
L["Assisted Combat Suggestion"] = true
L["Assisted Combat {{!is|is not}} suggesting a spell"] = true
L["Assisted Combat {{!suggests|does not suggest}} %s"] = true
L["Matches when Blizzard's Assisted Combat suggests this spell as the next cast. An override counts as its base spell, and the base spell as its override. With no spell chosen, matches whenever Assisted Combat suggests anything."] = true
L["Assisted Combat exists on Retail (and is declared on Forever). Where the game does not offer it, for this character or specialization, or the suggestion cannot be read, this condition is unavailable rather than false, including under NOT."] = true
L["Blizzard's suggestion"] = true
L["Recommends the spell Blizzard's Assisted Combat suggests"] = true
L["Recommends whatever spell Blizzard's Assisted Combat suggests next, read each time the rotation is evaluated. It highlights that spell's button and shows in the preview like a spell step, and is held to the same requirements: known, usable, off cooldown and in range. When nothing is suggested, the suggested spell is not on your bars, or Assisted Combat is unavailable (anywhere but Retail, or a specialization without it), the step is skipped. Rotation list only."] = true
L["Assisted Combat Rotation Spell"] = true
L["%s {{!is|is not}} in Blizzard's Assisted Combat rotation"] = true
L["Matches when this spell is one Blizzard's Assisted Combat can suggest for your current specialization. Its current override and its base spell count too. Use it to highlight what Assisted Combat leaves out, for example a cooldown that is not in the set."] = true
L["The set is read again whenever your spells change, never guessed. Where the game does not offer Assisted Combat for this character or specialization, or the set cannot be read, this condition is unavailable rather than false, including under NOT."] = true
L["Assisted Combat Available"] = true
L["Assisted Combat {{!is|is not}} available"] = true
L["Matches when the game offers Blizzard's Assisted Combat for your character and current specialization. When it does not (for example a specialization Blizzard has no Assisted Combat rotation for, or a client that declares the API but does not offer the feature), this is false, so a branch can fall back to your own steps."] = true
L["Unavailable only where the client has no Assisted Combat API or its answer cannot be read, including under NOT."] = true
-- Who highlights a "Blizzard's suggestion" step (General settings).
L["Blizzard's suggestion highlight"] = true
L["Rotation Master's glow"] = true
L["Blizzard's Assisted Highlight"] = true
L["Both"] = true
L["Assisted Combat is not available for your current specialization, so Blizzard's highlight stays off."] = true
L["Help.General.assisted_highlight"] = "Who highlights the button while a \"Blizzard's suggestion\" step is the recommendation. Rotation Master's glow uses the effect below. Blizzard's Assisted Highlight turns on the game's own highlight (Options, Gameplay, Combat, Assisted Highlight) while a rotation with that step is active, and Rotation Master leaves that step's button to it; Both shows the two. Rotation Master turns Blizzard's highlight on only outside combat, never changes it if it was already on, and puts your setting back when the rotation ends, Rotation Master is disabled, or you log out or reload. If you change the setting yourself meanwhile, your choice is kept. Blizzard's highlight follows Blizzard's suggestion all the time, also while another step is recommended, and it shows on Blizzard's own action bars only, so choose Rotation Master's glow or Both with a bar addon. The choice is hidden on clients without Blizzard's highlight (Forever and the Classic clients)."

-- Season of Discovery rune engraving and trait talents.
L["rune spell %s"] = true
L["rune %s"] = true
L["Engraved Rune"] = true
L["you {{!have|do not have}} the rune %s engraved"] = true
L["<rune>"] = true
L["Your runes have not loaded yet. Reopen this condition shortly, or enter an ID below."] = true
L["This character cannot engrave runes. A rune entered by ID below is kept, and is unavailable here."] = true
L["Slot %d"] = true
L["Equipment Slot"] = true
L["Rune"] = true
L["Rune Spell ID"] = true
L["Rune ID"] = true
L["Matches when a Season of Discovery rune is engraved on one of your equipped items. Passive runes count too, which a known-spell test cannot see."] = true
L["Pick one of your known runes by equipment slot. The rune is saved by the first spell it teaches, so a shared rotation names it on any character."] = true
L["Enter a spell the rune teaches, or the rune's own ID (its skill line ability ID) for a rune that teaches no spell. Entering one clears the other."] = true
L["Engraving exists only on Season of Discovery realms. Elsewhere, and until your runes have loaded after logging in, this condition is unavailable rather than false, including under NOT. The Phase 7 shoulder runes are not engravings and are not seen. This is not the Death Knight Rune condition."] = true
L["Your talents cannot be listed right now. A node ID entered below is kept and evaluated."] = true
L["%s (choice)"] = true
L["Talents"] = true
L["Talent Node ID"] = true
L["Choice Entry ID"] = true
L["talent node %s"] = true
L["ranks in %s"] = true
L["Retail and Forever compare the rank of a talent node in your active loadout. Pick it from your talent tree, or enter the node ID (and, for a choice node, the entry ID of the choice) to share a rotation; a choice node's entry has rank zero unless it is the chosen one. A hero talent outside your chosen hero tree has rank zero. Ranks are read again after any talent change; an unreadable node is unavailable, including under NOT."] = true
L["Forever is the exception: Talent tree is one of the three talent trees of your active loadout (in the order the talent window shows them); their points are read again after any talent change. Retail has no such trees."] = true

-- Specialization and weapon type conditions (Conditions/specialization.lua, Conditions/equipment.lua).
L["Arms"] = true
L["Fury"] = true
L["Protection"] = true
L["Retribution"] = true
L["Beast Mastery"] = true
L["Marksmanship"] = true
L["Survival"] = true
L["Assassination"] = true
L["Subtlety"] = true
L["Discipline"] = true
L["Enhancement"] = true
L["Restoration"] = true
L["Affliction"] = true
L["Demonology"] = true
L["Destruction"] = true
L["Brewmaster"] = true
L["Windwalker"] = true
L["Mistweaver"] = true
L["Balance"] = true
L["Feral"] = true
L["Guardian"] = true
L["Havoc"] = true
L["Vengeance"] = true
L["Devourer"] = true
L["Devastation"] = true
L["Preservation"] = true
L["Augmentation"] = true
L["Initial"] = true
L["One-Handed Axes"] = true
L["Two-Handed Axes"] = true
L["Bows"] = true
L["Guns"] = true
L["One-Handed Maces"] = true
L["Two-Handed Maces"] = true
L["Polearms"] = true
L["One-Handed Swords"] = true
L["Two-Handed Swords"] = true
L["Warglaives"] = true
L["Staves"] = true
L["Fist Weapons"] = true
L["Daggers"] = true
L["Thrown"] = true
L["Crossbows"] = true
L["Wands"] = true
L["Fishing Poles"] = true
L["Specialization"] = true
L["<specialization>"] = true
L["specialization %d"] = true
L["your specialization {{!is|is not}} %s"] = true
L["Weapon Type"] = true
L["Slot"] = true
L["Main Hand"] = true
L["Ranged"] = true
L["Nothing equipped"] = true
L["Any weapon"] = true
L["One-handed weapon"] = true
L["Two-handed weapon"] = true
L["Ranged weapon"] = true
L["Held in off hand"] = true
L["<slot>"] = true
L["<weapon type>"] = true
L["weapon type %d"] = true
L["your %s slot {{!holds|does not hold}} %s"] = true
L["Help.Conditions.SPECIALIZATION"] = "Your talent specialization. Choose a class, then one of its specializations; your own class is selected first, and other classes are offered for rotations shared between characters. A specialization of another class is always false."
L["Help.Conditions.SPECIALIZATION.editions"] = "Retail and Mists of Pandaria Classic compare your active specialization. Classic Era, Burning Crusade and Wrath compare your primary talent tree, the one tree with the most points; Feral and Guardian both mean Feral Combat there. Forever cannot tell its specializations apart this way. No specialization yet, tied or unspent trees and unreadable values are unavailable, including under NOT. The answer is cached until your talents or specialization change."
L["Help.Conditions.WEAPON_TYPE"] = "What is equipped in the main hand, off hand or ranged slot: nothing, any weapon, a one-handed, two-handed or ranged weapon, a shield, an off-hand item, or one weapon type such as Daggers. Types are read from the item's class and subclass, so they work in every language. The answer is cached until your equipment changes."
L["Help.Conditions.WEAPON_TYPE.examples"] = "Dual wielding: off hand holds any weapon. Titan's Grip: off hand holds a two-handed weapon. Backstab and Ambush: main hand holds Daggers. Shield Slam or a tank set: off hand holds a shield. The ranged slot exists only before Mists of Pandaria; elsewhere, and while item data is still loading, this condition is unavailable, including under NOT."

-- Steps whose action is on no action bar (buttons.lua GetStepBinding).
L["Not on your action bars, so it can't be highlighted. It is skipped."] = true
L["Some suggestions are not on your action bars, so they can't be highlighted. They are skipped."] = true
L["Rotation Master highlights a step by lighting the action button that holds it. No action bar button holds this action right now, so this step is skipped and the next step is used instead. Put it on an action bar to use it. Spells inside macros count only where the game lets addons read macros (not on Retail)."] = true
L["Rotation Master highlights a cooldown by lighting the action button that holds it. No action bar button holds this action right now, so this cooldown is never shown or announced. Put it on an action bar to use it. Spells inside macros count only where the game lets addons read macros (not on Retail)."] = true
L["Blizzard can suggest %s, but no action bar button holds it. Rotation Master highlights an action by lighting the button that holds it, so when one of these is suggested this step is skipped and the next step is used instead. Put them on an action bar to use them."] = true
L["Skipped, not on your action bars (they cannot be highlighted): %s."] = true
L["step %s"] = true
L["cooldown"] = true
L["Not on your action bars"] = true
L["An amber border and warning mark a card whose action no action bar button holds right now. Rotation Master highlights an action by lighting the button that holds it, so that step is skipped (a cooldown is never shown) until you put it on a bar. The warning updates when your bars change. Red still marks invalid data."] = true
L["Actions must also be on an action bar: Rotation Master highlights an action by lighting the button that holds it, so a step or cooldown that no button holds is skipped, and its card shows an amber warning."] = true

-- Live condition dots (UI/rotation_cards.lua, UI/rotation_editor.lua).
L["Currently satisfied"] = true
L["Not satisfied"] = true
L["Unavailable: %s"] = true
L["unreadable right now"] = true
L["the condition could not be evaluated"] = true
L["Checked %d seconds ago."] = true
L["Rotation Master is advising this step now."] = true
L["This cooldown is showing now."] = true
L["This rotation is advising now."] = true
L["Not on your action bars, so it can't be highlighted. It is never shown."] = true

-- BEGIN GENERATED RM PUBLIC HELPER DOCS
L["Absolute health target (negative means deficit) or percentage fraction."] = true
L["All original results, preserving nil positions and return count."] = true
L["Apply the legacy integer or canonical numeric-string spelling test. Numbers use floor equality; strings must equal the spelling obtained after numeric conversion and floor. Other types return false. This is not a finite-number validator."] = true
L["Arguments forwarded unchanged to the observed function."] = true
L["Arguments forwarded unchanged; types, identity, arity and nil positions distinguish cache entries."] = true
L["Availability or query-validation reason for a nil level observation."] = true
L["Availability or query-validation reason for a nil level."] = true
L["Availability or query-validation reason when no current state can be read."] = true
L["Availability or query-validation reason when the whole observation is unavailable."] = true
L["Availability or validation reason for a nil result."] = true
L["Availability or validation reason when the record is nil."] = true
L["Availability or validation reason when the result is nil."] = true
L["Availability reason for a nil result."] = true
L["Availability reason when resolution fails; nil on success."] = true
L["Cache an observation after it returns a non-nil value; retry observations whose entire return tuple is nil. Uses the same exact argument keys as getCached."] = true
L["Calculate a checked health-history rate using an explicit finite window and clock. Preserve ordered weighting, per-row live canonical rounding, skipped streams, array holes, fractional keys and final visited ages. A fixed 4096-unit budget covers visited rows and accumulation bins across both streams; excess or invalid consumed arithmetic returns unavailable, never a partial estimate or clamp. This new API has its own source identity; historical trend functions remain unchanged."] = true
L["Call an observation once per cache and exact argument tuple, including nil results. Pass the evaluation cache to share observations within a recommendation cycle; nil cache calls directly."] = true
L["Callback invoked after changing the selected unit."] = true
L["Callback receiving the committed spell value."] = true
L["Caller-owned evaluation observation cache; nil queries afresh."] = true
L["Capability or clock observation availability reason."] = true
L["Capability or observation availability reason for a nil class."] = true
L["Check whether a spell can be recommended now, allowing a spell whose remaining cooldown ends with the current global cooldown. On Retail and Forever, where cooldown times are secret in combat, readiness comes from the never-secret isEnabled, isActive and isOnGCD flags instead. This checks cooldown readiness only; it does not check learned status, range or resource usability. Pass evaluation time from evalStart or GetTime()."] = true
L["Check whether a table has a non-nil value at a key. A stored false value still counts as present; this does not scan table values."] = true
L["Checkbox widget with boolean value and callback methods."] = true
L["Choose the supplied player value only for the literal player unit token; every other unit selects the nonplayer value. Selected false and nil values are preserved."] = true
L["Classification, validation or availability reason for a nil result."] = true
L["Classify a numeric item as a glyph for the requested class, using guarded native item metadata. Class is optional and defaults to the readable player class. This establishes item classification only, not equipped status or an item-to-glyph-spell ID mapping."] = true
L["Client-family, query-validation or required-observation availability reason for a nil result."] = true
L["Client-policy, capability, call or observation availability reason for a nil form."] = true
L["Client-policy, capability, call or observation availability reason for a nil record."] = true
L["Client-policy, native-call or required membership availability reason for a nil record."] = true
L["Closed kind: runner, resist or immune."] = true
L["Closed scalar kind: current or maximum."] = true
L["Collect table keys and sort them by their associated values using Lua less-than comparison. This sorts values rather than key names; equal values have no guaranteed key order."] = true
L["Combat-policy, capability, observation or scan-budget reason for a nil count."] = true
L["Combined signed weighted rate from the original formula; malformed or nonfinite inputs retain the legacy error/numeric behavior."] = true
L["Compare the selected unit creature ID with one existing saved creature-type key. Resolve the fixed key-to-ID identity in one private executable mapper; gameplay matching does not depend on the mutable localized UI caption map. Share complete native observations within the supplied evaluation-pass cache by actual observer, receiver and unit, including absence and unavailable reasons. Known absence or a known different ID returns false; an unavailable required observation returns nil with a reason. No longterm state or caption mutation is added."] = true
L["Compare two exact unit tokens using UnitIsUnit after checking only the first token with UnitExists. A readable absent first unit returns false without comparing. Required missing, failed, restricted or malformed observations return nil with a reason. No second existence query, GUID lookup or inferred identity is added."] = true
L["Compare two values using an RM operator identifier: LESSTHAN, LESSTHANOREQUALS, GREATERTHAN, GREATERTHANOREQUALS, EQUALS, NOTEQUALS or DIVISIBLE. Invalid operators warn and return nil; operands must support the selected Lua operation."] = true
L["Comparison operator key, such as EQUALS or LESSTHAN."] = true
L["Comparison result, or nil for an unknown operator."] = true
L["Comparison text retaining named Boolean alternative markup."] = true
L["Complete matching class count, including zero, or nil when unavailable."] = true
L["Complete nonnegative observed count including zero, or nil when unavailable."] = true
L["Condition container supporting SetLayout, AddChild, SetUserData, SetWidth and DoLayout."] = true
L["Condition value record containing spell, ranked and disabled fields; updated in place."] = true
L["Condition value record updated when a unit is chosen."] = true
L["Configured unit selector; add it with parent:AddChild(widget)."] = true
L["Copy a table using tostring of each original key as the destination key. Values retain their original identities. Colliding stringified keys overwrite each other in unspecified pairs traversal order."] = true
L["Count all entries visited by pairs, including false values and sparse numeric or nonnumeric keys. A nil table has length zero."] = true
L["Count matching class tokens in the current fixed roster. Read group membership first; when requested, raid membership selects raid1 through raid40 without a separate player fact. Solo and party paths read player first, then party1 through party4 when grouped. A complete known roster returns a count, including zero; any required unavailable fact returns nil with a reason. Complete observations share the evaluation-pass cache; no player class persists across passes. Archived raw callbacks retain their original load-time class separately."] = true
L["Count only GUID-keyed units already in the observed membership snapshot. Verify current token identity before using the published threat observer; known absent or reused tokens are excluded without adding replacements. Complete identity and threat observations share only the supplied evaluation cache, while membership is traversed fresh. Known nonenemy or optional nil threat is not counted; required unreadable, malformed or failed facts make the entire result unavailable. This does not enumerate a complete roster, apply a range filter or modify tracked records."] = true
L["Create a condition field container with RM-owned List, Table and responsive spell-field layouts. It accepts registered native condition widgets; add children with AddChild and attach the group to the callback parent."] = true
L["Create a configured unit selector bound to a condition value record. Returns the widget for the caller to add to the condition callback parent."] = true
L["Create a native boolean condition control. Configure SetLabel, SetValue, SetDisabled and OnValueChanged; add it with parent:AddChild(widget)."] = true
L["Create a native button using the shared condition widget lifecycle and workbench theme. SetText, SetDisabled and SetCallback configure its label and interaction; OnClick receives the mouse button. Add it to the supplied parent."] = true
L["Create a native condition selector. SetList accepts key-to-label or key-to-entry maps; SetValue selects a key and OnValueChanged reports changes. Add it with parent:AddChild(widget)."] = true
L["Create a native image control using the condition widget lifecycle. SetImage and SetImageSize choose the texture; SetText optionally adds a caption. OnClick, OnEnter and OnLeave use the shared callback contract. Add the control to the supplied parent."] = true
L["Create a native numeric condition input with a slider and typed numeric field. Configure SetSliderValues, SetValue, SetIsPercent and SetCallback; OnValueChanged reports committed values. Add it with parent:AddChild(widget)."] = true
L["Create a native position pad using the shared directional controls. OnOffsetChanged reports horizontal and vertical direction, whether Center was pressed, and the increment (one, or ten with Shift). SetDisabled controls interaction; add the pad to the supplied parent."] = true
L["Create a native text input using the condition widget contract. SetLabel, SetText, SetDisabled and SetCallback configure it; OnEnterPressed commits text. Add it to the callback parent with parent:AddChild(widget)."] = true
L["Create a shallow filtered copy despite the historical deepcopy name. Nested values retain their original identities and the source metatable is not copied. By default exclude keys listed among except values; invert true includes only listed keys. Nil input returns nil."] = true
L["Create a spell input with suggestions, validation and spell-link support for custom condition widgets. The update callback owns saving a chosen value; add the returned widget to the callback parent."] = true
L["Create a transient named condition summary. Use {name} for scalar values and {{positive|negative}} for predicate alternatives; prefix a primary alternative with !. Escape literal double braces as {{{{ and }}}}. Values are inserted literally without parsing their percent signs, links, colors or braces. Typed predicate values participate in primary selection. Templates, values and rendered text are bounded; malformed input renders a localized unavailable summary. This changes presentation only and runs no condition observations."] = true
L["Create a typed comparison predicate for a named condition phrase. Positive wording uses the original captured operator map and negative wording uses the current negated operator map. A primary predicate takes precedence over qualifiers; only the first eligible predicate negates. Unknown operators use the existing operator placeholder. This formats wording without comparing values or evaluating a condition."] = true
L["Create an iterator over a sorted snapshot of table keys. Default ordering compares keys; a custom order callback receives the original table and two keys. Values are read from the original table when each key is yielded. The legacy iterator ends when the next captured key is nil or false."] = true
L["Create native wrapping text that measures its height from its width and font. SetText, SetFont or SetFontObject configure its contents. Add it to the supplied parent so layout can track its measured height."] = true
L["Create native wrapping text with optional leading image and pointer callbacks. SetImage and SetImageSize configure the image; OnEnter, OnLeave and OnClick use the condition callback contract. Add it to the supplied parent; callbacks expire when its lease is released."] = true
L["Current evaluation time in seconds from GetTime(), normally evalStart."] = true
L["Current positive visibility distance in yards; nil when unavailable."] = true
L["Current unit token whose distance from the player should be observed."] = true
L["Damage/heals arrays of time/value rows; only selected streams are consumed."] = true
L["Decimal places, default zero; negative values round to tens or larger powers of ten."] = true
L["Dense array of keys sorted by associated value."] = true
L["Dense array of nonempty text fields."] = true
L["Destination array modified in place."] = true
L["Display lookup table."] = true
L["Estimate signed health change from weighted damage and healing history. Damage contributes a negative rate and healing a positive rate. Read the live profile window when no window is supplied, use the live clock and legacy rounding service, and preserve the existing weighting and rounded-age calculation. This helper does not validate or sanitize history, clamp timestamps, or guarantee finite results."] = true
L["Estimate time until selected health. Cache complete native identity and lazy scalar observations per evaluation pass, while provider, history, window, clock and forecast stay live. Exact target equality returns zero before history work. Preserve deliberate no-estimate false and initialized-zero results for zero or opposite rates; required invalid facts, overflow or 4096-unit work exhaustion are unavailable. Never mutate history or invent a partial estimate."] = true
L["Evaluation cache, or nil to bypass caching."] = true
L["Evaluation-pass cache for complete unit observations; nil observes directly. Different selected keys reuse the same unit snapshot."] = true
L["Evaluation-pass cache, or nil for fresh observations."] = true
L["Evaluation-pass cache, or nil to observe identity directly. Resource mapping is resolved live on each invocation."] = true
L["Evaluation-pass cache, or nil to observe identity directly. Successful player class observations may use the existing longterm identity cache; resource mapping remains live."] = true
L["Evaluation-pass native observation cache; nil queries afresh."] = true
L["Evaluation-pass presence cache only; name, level and provider history remain fresh."] = true
L["Exact helper-owned player, party1..party4 or raid1..raid40 token."] = true
L["Exact integral native rune slot from 1 through 6."] = true
L["Exact nonempty unit token to observe."] = true
L["Exact nonempty unit token, passed unchanged."] = true
L["Exact readable recipient name recorded for this cast."] = true
L["Exact selected unit token; only the literal player token may select the TBC combo transport."] = true
L["Exact selected unit token; player class alone may use the successful longterm cache."] = true
L["Exact selected unit token; the attacker remains player."] = true
L["Exact unit token checked for existence and passed to the selected metadata API."] = true
L["Exact unit token passed unchanged to UnitExists and, when required, UnitClass."] = true
L["Exact unit token used for existence and as the recipient of player hostility and threat queries."] = true
L["Exact unit token whose resource should be observed; this does not redirect player or vehicle units."] = true
L["Exact unit token whose selected flag should be observed."] = true
L["Exact unit token whose selected resource quantity is requested."] = true
L["Exactly current for UnitPower or maximum for UnitPowerMax."] = true
L["Exactly current for UnitPower or maximum for UnitPowerMax; no other native query is added."] = true
L["Exactly current for the player/target combo query or maximum for the player capacity query."] = true
L["Exactly dead for UnitIsDeadOrGhost, or friendly for UnitIsFriend(player, unit)."] = true
L["Exactly type or school; selects the required subject field without requiring the other."] = true
L["Existing stored CREATURE key: BEAST, DRAGONKIN, DEMON, ELEMENTAL, GIANT, UNDEAD, HUMANOID, CRITTER, MECHANICAL, OTHER, TOTEM, NONCOMBAT_PET or GAS_CLUUD."] = true
L["Explicit finite clock snapshot; signed and fractional values remain valid."] = true
L["Explicit finite weighting window; no profile fallback or clamp."] = true
L["Explicit nonnegative integer power selector, false for a known absent unit, or nil when required data is unavailable."] = true
L["Explicit nonnegative integer selector, false for known unit absence, or nil when required data is unavailable."] = true
L["Explicit readable finite nonnegative integer power selector, including zero."] = true
L["Explicit readable finite nonnegative integer power selector."] = true
L["Finite ETA including zero, false for known absence/no estimate, or nil when unavailable."] = true
L["Finite final stream age, or nil when unavailable."] = true
L["Finite minimum native threat status, preserving signed and fractional thresholds."] = true
L["Finite native creature ID, false for known unit absence, or nil when required observations are unavailable."] = true
L["Finite native resource quantity, retaining its sign and fractional part; nil when unavailable."] = true
L["Finite native threat status, false for known absence/nonenemy/no-threat, or nil for unavailable observations."] = true
L["Finite nonnegative native health scalar, or nil when unavailable."] = true
L["Finite quantity in whole units with its fractional part; nil when unavailable."] = true
L["Finite signed combined rate, or nil for unavailable calculation."] = true
L["First exact unit token, checked for existence before comparison."] = true
L["First table to compare."] = true
L["Format comparison wording with named Boolean alternatives when the operator has a negative form. The primary flag marks the positive form as the primary alternative. Positive operator labels use the captured operator map; negative labels and nullable dispatch retain their live addon APIs."] = true
L["Fresh finite native clock value, or nil when unavailable."] = true
L["Fresh readable class filename, or nil when unavailable."] = true
L["Fresh readable finite clock, or nil when unavailable."] = true
L["Fresh readable record with active, optional name, remainingSeconds and interruptible. Remaining time is in seconds and is clamped to zero. An unavailable optional field has its own reason; it does not invalidate a readable active name."] = true
L["Fresh readable record with exists and, when present, a positive integer level."] = true
L["Fresh readable record with exists and, when present, current health. Maximum health is included only when requested."] = true
L["Fresh readable record with exists and, when present, powerType and finite current quantity. Requested maximum is finite and nonnegative. Quantities may be fractional; current-mode current may be signed."] = true
L["Fresh readable record with finite nonnegative speed, or nil when unavailable."] = true
L["Function or global function name to call."] = true
L["History record with newest-first damage and heals arrays of time/value entries. Falsy history returns only zero without reading the clock."] = true
L["Identifier-keyed scalar values or typed predicates. Strings, finite numbers and booleans are supported; referenced slots must be present. Values are captured when the phrase is created."] = true
L["Insert each value visited by ipairs at its corresponding leading index in the destination array. Existing entries shift after the inserted prefix; traversal stops at the first missing source index."] = true
L["Integral RM statistic selector 1..5, or 6 for effective armor."] = true
L["Iterator yielding a captured key and its current table value, or no values when exhausted."] = true
L["Key to look up."] = true
L["Known active count from zero through the RM scan budget, or nil when unavailable."] = true
L["Known nonempty role string, false for known absent unit, or nil when unavailable."] = true
L["Known nonempty role string, or nil when unavailable."] = true
L["Known unit presence or absence; nil when the required observation is unavailable."] = true
L["Larger rounded stream age in seconds, not a sample count or proof of continuous observation. Omitted when history is falsy."] = true
L["Left operand; use numbers for ordering and divisibility."] = true
L["Literal prefix, including an empty prefix."] = true
L["Literal suffix, including an empty suffix."] = true
L["Live selected talent-group argument, forwarded unchanged as one argument after readability checking."] = true
L["Localized complete sentence with named slots and optional explicit predicate alternatives."] = true
L["Look up a table key for display, preserving non-nil results; invalid tables, missing keys and nil keys use nullable placeholder text."] = true
L["Lookup key."] = true
L["Lua pattern character-class separator, default %s for whitespace."] = true
L["Mark the positive wording as the primary named alternative."] = true
L["Matching key, including a false key, or nil when no match exists."] = true
L["Missing-value display text; omitted uses the localized value placeholder."] = true
L["Native button with label, disabled state and lease-protected callbacks."] = true
L["Native directional pad with center reset and lease-protected callbacks."] = true
L["Native image control with label, texture, disabled state and callbacks."] = true
L["Native interactive text and image control with measured height and disabled state."] = true
L["Native one-based integral active-row index within the 256-row RM scan budget."] = true
L["Native wrapping text control with font, color and alignment methods."] = true
L["New shallow filtered table, or nil for nil input."] = true
L["New table with stringified keys and unchanged values."] = true
L["Newest-first health snapshots containing time, value and max. Falsy input returns only zero without reading the clock."] = true
L["No return values. The destination array is modified in place."] = true
L["No return values. The supplied table is modified in place."] = true
L["Nonempty class filename token to count; no class-token whitelist is applied."] = true
L["Nonempty historical school key for resist/immune; unused for runner."] = true
L["Normalized bounded socket snapshot with slots and complete, or nil when the query is unavailable."] = true
L["Normalized requested subject with finite timeRemaining or timeRemainingReason; nil when the required row or subject is unavailable."] = true
L["Number of entries visited."] = true
L["Number or string to inspect; other types do not match."] = true
L["Numeric widget supporting slider bounds, percent display and pending-edit validation."] = true
L["Observation kind: cast or channel. These use different native interruptibility tuple positions."] = true
L["Observation, history, work-limit or arithmetic availability reason."] = true
L["Observe a fresh protected zero-argument GetTime for a needed health forecast. Require readability and a finite number; preserve signed and fractional values without adding a monotonic, integral or nonnegative restriction. No clock cache or extra native query is used."] = true
L["Observe a point resource that the client reports in fragments (Mists of Pandaria Burning Embers). Current uses exactly UnitPower(unit,powerType,true) and maximum UnitPowerMax(unit,powerType,true); the result is divided by Blizzard MAX_POWER_PER_EMBER (10), so 35 fragments are 3.5. Probe policy only. Missing, failed, restricted or malformed data remains unavailable; it never falls back to the whole-unit query. No cache is added."] = true
L["Observe a readable raw unit level on known clients. A readable absent unit returns exists=false; present units require a positive finite integer UnitLevel. Unknown boss levels, missing, failed, restricted or malformed observations return nil with a reason. This does not use effective or scaled levels."] = true
L["Observe a selected unit role on probe-policy clients without issuing inspection requests. Known unit absence returns false. Prefer the callable modern inspection API, with legacy fallback only when that callable is absent; a selected failure never falls through. Require a positive finite integral specialization ID and consume only role return five from the exact one-argument GetSpecializationInfoByID call. Missing, failed, restricted or malformed required facts are unavailable; readable nonempty future role strings remain exact."] = true
L["Observe a unit casting or channeling on supported readable clients. A readable inactive result returns active=false. Active records contain name and independently available remainingSeconds and interruptible fields, with remainingReason or interruptibleReason when an optional field is unavailable. Missing, failed or restricted observations return nil with a reason."] = true
L["Observe creature identity from native UnitCreatureType return two on probe-policy clients. Check exact UnitExists(unit) first; readable false returns false without requiring or calling creature metadata. A present unit requires a readable finite numeric ID; the unused localized name does not affect availability. Preserve signed, fractional, zero and future finite IDs as known values. Missing, failed, nil, restricted or malformed required facts return nil with a reason. No creature enumeration, translated caption comparison or longterm cache is added."] = true
L["Observe death or ghost state, or friendliness to the player, for the exact selected unit on probe-policy clients. A missing, failed, restricted or malformed required observation is unavailable. Unit absence is unavailable rather than a negative match, including under NOT. No cross-poll state is retained."] = true
L["Observe exact pet existence and optionally its formatted GetUnitName display name. Presence-only queries never require name data. Known absence skips the name query. Present pets require a readable nonempty name only when requested; required missing, failed, nil, restricted or malformed observations return nil with a reason. The display helper is called with its single original pet argument, without UnitName fallback or inferred bar, health or ability state."] = true
L["Observe exact selected-unit existence and optionally its class filename for point-resource conditions. Known absence returns exists=false without reading class. Present units require only UnitClass return two when requested; unused localized names and IDs do not affect availability. Required missing, failed, restricted or malformed observations remain unavailable. This does not select a resource or cache identity."] = true
L["Observe explicit mana or the current raw power resource on supported readable clients. Select resource identities from the live PowerType enum; explicit mana never falls back to the current bar. Known absence returns exists=false; missing, failed, restricted or malformed observations return nil with a reason. Current-mode quantities preserve signed native resources; explicit mana is nonnegative. Request maximum only when needed; percentage consumers must require a positive maximum."] = true
L["Observe glyph sockets on verified Wrath, Cata and Mists client layouts. Returns slots and a complete flag. Each slot has active=false when known locked or empty, active=true plus spellID when occupied, or nil active plus reason when unavailable. Unknown layouts and failed count queries return nil with a reason. This does not compare item names or prove exact item-to-spell identity."] = true
L["Observe one consumed native unit metadata field after checking UnitExists: class uses UnitClass return two, creature uses the localized UnitCreatureType name, and classification uses UnitClassification. A readable absent unit returns false without querying metadata. Unused tuple fields do not affect availability; a required missing, failed, nil, restricted or malformed value returns nil with a reason. No player class, GUID, enum or translation inference is added."] = true
L["Observe one current unit flag: combat uses UnitAffectingCombat, enemy uses UnitIsEnemy with player as the first unit, and pvp uses UnitIsPVP. A readable absent unit returns false without querying the flag. Required missing, failed, restricted or malformed observations return nil with a reason. This preserves the exact selected unit and does not infer friendliness, attackability or other unit states."] = true
L["Observe one exact native rune slot using GetRuneType with its single index argument. Require a readable finite positive integral type; known future numeric types remain distinct from the selected type, and Death is an exact type rather than a wildcard. Missing, failed, restricted or malformed observations remain unavailable. No class, unit, count or inferred base-rune query is added."] = true
L["Observe one independent zero-argument player flag: stealthed uses IsStealthed, control uses HasFullControl, and outdoors uses IsOutdoors. Readable true and false retain their meanings. Required missing, failed, nil, restricted or malformed data returns nil with a reason. No existence, instance or ability-usability inference is added."] = true
L["Observe one protected zero-argument IsInInstance tuple. Required readable Boolean membership is independent of the type field: known outside returns without interpreting the unused type; inside returns a readable string type or an instanceTypeReason when that secondary field is unavailable. Callers testing outside need only membership; inside type comparisons must check the secondary reason. No outdoors, zone or unit inference is added."] = true
L["Observe ordered selected-unit existence, hostility from player, then the player threat status on that unit. Known absence, nonenemy and a successfully read nil threat status return false, preserving the no-threat predicate. Finite status numbers including zero retain their original comparison meaning. Required missing, failed, nil, restricted or malformed facts return nil with a reason. No attackability, death, combat or vehicle inference is added."] = true
L["Observe readable current health and optionally maximum health on supported clients. A readable absent unit returns exists=false. Missing, failed, restricted or malformed observations return nil with a reason; they do not establish an absent unit or a health value."] = true
L["Observe the current player form with one protected zero-argument GetShapeshiftForm call. Preserve every readable finite numeric result, including zero, signed and fractional values; no stronger native index domain is inferred. Missing, failed, nil, restricted or nonfinite data remains unavailable. No form count, class, spell ID, unit or optional argument is added."] = true
L["Observe the effective statistic from native return two only. On probe-policy clients query exact UnitExists(unit), then UnitStat(unit,stat) for selector 1..5 or UnitArmor(unit) for selector 6. Known absence returns exists=false; missing, failed, restricted or nonfinite required facts return nil. Preserve finite signed, fractional and zero values; ignore all unused tuple fields. The 1..6 route is an RM selector policy, not a native value-domain limit."] = true
L["Observe the explicitly selected TBC player combo transport. Current uses exactly GetComboPoints(player,target); maximum uses UnitPowerMax(player,powerType) with the original selector. Other families are unavailable here and must use their existing point-power observer. Preserve readable finite signed, fractional and zero values. Missing, failed, restricted or malformed data remains unavailable; a failed chosen combo query never falls back to UnitPower. This observes no other actor and adds no cache."] = true
L["Observe the first role result of the exact legacy GetTalentGroupRole(group) dot call on probe-policy clients. Forward the readable selected group unchanged, including nil as one argument; do not infer group bounds, substitute another API or query a player unit. The complete legacy primary declaration is not established. Missing, failed, restricted, empty or malformed role data is unavailable; readable nonempty future strings remain exact."] = true
L["Observe the first zone PvP classification result with one protected zero-argument dot call. Prefer callable C_PvP.GetZonePVPInfo and use the global helper only when the modern callable is absent. A successful nil or no returned values produces a known empty record; missing, failed, restricted or malformed observations remain unavailable. Readable empty and future strings retain their exact meaning, and unused return fields do not determine availability. Never switch backends after a modern result or failure."] = true
L["Observe the player current movement speed on supported readable clients. This queries GetUnitSpeed for player only, without testing another unit or redirecting vehicle ownership. Zero means stationary; positive finite fractional speeds remain valid. Missing, failed, restricted or malformed observations return nil with a reason."] = true
L["Observe unit presence on identified client families. Pass the selected unit unchanged to one protected UnitExists call. Preserve readable true and false; missing, failed, restricted, nil or malformed required observations return nil with a reason. No identity, visibility, range or combat-state query is added."] = true
L["Observe whether the player can attack a selected unit that is not dead, using the exact UnitExists, UnitCanAttack and UnitIsDead predicates. Known absence or a readable false attack result returns false without querying death. Required missing, failed, restricted or malformed observations return nil with a reason. This does not test ghosts, range, hostility or ability usability, and does not redirect unit ownership."] = true
L["Observed class filename string, false for a known absent unit, or nil when unavailable."] = true
L["Observed membership, or nil when unavailable."] = true
L["On a selected resource only, target-combo for the explicit TBC player fallback or power for the existing selected-unit transport."] = true
L["On probe-policy clients observe exact UnitExists(unit), then UnitGUID(unit) only for a present unit. Known absence is false. Present identity requires a readable nonempty GUID; missing, failed, malformed or restricted required facts are unavailable. No health, provider or extra-unit observation is added."] = true
L["One of class, creature or classification; other metadata kinds are unsupported."] = true
L["One of combat, enemy or pvp; other flag kinds are not supported."] = true
L["One of stealthed, control or outdoors; no other predicate is invoked."] = true
L["One rounded numeric result from the original formula."] = true
L["Optional collection of key values selecting entries; its own keys are ignored."] = true
L["Optional ordering callback called as order(t, leftKey, rightKey)."] = true
L["Optional positive class ID; nil queries the current player class under protection."] = true
L["Original explicit readable finite nonnegative integer combo-resource selector, including zero; retained for the maximum query."] = true
L["Original non-nil lookup result, or a colored placeholder string."] = true
L["Original non-nil value, or a colored placeholder string."] = true
L["Original rounded-age bucket count, omitted for falsy input."] = true
L["Packaged helper from Conditions/spatial.lua."] = true
L["Packaged helper from utils.lua."] = true
L["Partial current/maximum record, empty when provider absent, or nil when unavailable."] = true
L["Partial record containing ready or readyReason, start or startReason, and duration or durationReason; nil only when the query itself is unavailable."] = true
L["Pet observation with Boolean exists and, for a requested present pet, name; nil when required data is unavailable."] = true
L["Policy or availability reason for a nil movement observation."] = true
L["Policy, capability or clock observation availability reason for a nil time."] = true
L["Policy, capability or required-observation availability reason."] = true
L["Policy, query, capability or required row/subject availability reason for a nil record."] = true
L["Policy, query-validation or availability reason for a nil metadata observation."] = true
L["Policy, query-validation or availability reason for a nil pet observation."] = true
L["Policy, query-validation or availability reason for a nil player flag."] = true
L["Policy, query-validation or availability reason for a nil quantity."] = true
L["Policy, query-validation or availability reason for a nil resource observation."] = true
L["Policy, query-validation or availability reason for a nil threat observation."] = true
L["Policy, query-validation or availability reason for a nil unit flag."] = true
L["Policy, query-validation or availability reason for nil attackability."] = true
L["Policy, query-validation or identity/selector availability reason for a nil selector."] = true
L["Policy, query-validation or required observation availability reason for a nil quantity."] = true
L["Policy, query-validation or required observation availability reason for a nil record."] = true
L["Policy, query-validation or required-observation availability reason for a nil ID."] = true
L["Policy, query-validation or required-observation availability reason for a nil match."] = true
L["Policy, slot-validation or required observation availability reason for a nil type."] = true
L["Policy, slot-validation, capability or native-call availability reason for a nil record."] = true
L["Policy, snapshot, identity or threat observation availability reason."] = true
L["Policy, token-validation or availability reason for a nil identity result."] = true
L["Policy, validation or availability reason for a nil health observation."] = true
L["Policy, validation or availability reason for a nil snapshot."] = true
L["Policy, validation or observation availability reason."] = true
L["Policy, validation or required observation availability reason."] = true
L["Positive integer glyph item ID stored by the condition; arrays, item-set keys and spell IDs are not item references."] = true
L["Positive integer level, false for a known absent unit, or nil when unavailable."] = true
L["Positive integer spell ID, not a spell-book slot."] = true
L["Positive item ID or native-recognized item name/link to classify."] = true
L["Predicate that validates the proposed spell value."] = true
L["Present GUID, false for known absence, or nil when unavailable."] = true
L["Provider, validation or observation availability reason."] = true
L["Query, policy or observation availability reason."] = true
L["RM comparison operator identifier; missing labels use the operator placeholder."] = true
L["RM operator identifier."] = true
L["Range record with applicable and, when applicable, inRange; nil when unavailable."] = true
L["Read a fresh protected UnitClass player observation for rotation ownership. Consume only the readable nonempty class filename from return two. No existence, level, vehicle, family or combat-policy read is added, and no result persists across calls. Core ownership still validates the class token and character key separately; overridden context providers retain their complete original path."] = true
L["Read a fresh protected zero-argument GetTime for rune cooldown arithmetic. Require a readable finite number. This observation is deliberately uncached; callers preserve the original clock-before-scan order and require its value only when a matching rune needs timing. No evaluation-start substitution or inferred time is supplied."] = true
L["Read a lazy health scalar after a separate identity gate. Kind current uses exact UnitHealth(unit); maximum uses exact UnitHealthMax(unit). Probe-policy clients accept readable finite nonnegative numbers including zero. No repeated existence/GUID call or alternate tuple fallback is added."] = true
L["Read a normalized charge record: currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate and isActive. Unsupported spells or restricted client data return nil with a reason."] = true
L["Read a specified unit membership in the player party or raid. True raidOnly queries only UnitInRaid; otherwise a true UnitInParty result short-circuits, false proceeds to UnitInRaid, and unknown remains unavailable. Readable nil raid index means false; integer raid index1..40 means true. Names are passed unchanged to native APIs; native name-query acceptance requires client qualification."] = true
L["Read and normalize a spell cooldown across supported clients. The returned record contains startTime, duration, isEnabled and modRate. The timestamps and duration already describe expiration in GetTime() seconds; do not divide them by modRate. When the client hides the times (Retail and Forever in combat) the record is nil with reason restricted-value, followed by the never-secret isEnabled, isActive and isOnGCD flags when they can be read."] = true
L["Read normalized native item classification metadata. The record contains canonical itemID, classID and subClassID; it does not require loaded item display text. Missing, failed, malformed or restricted metadata returns nil with a reason."] = true
L["Read one documented active loss-of-control row by its native index and requested subject kind. Type queries require only the readable control type string; school queries require only the readable finite nonnegative integer school mask. Optional timing is returned as a finite timeRemaining or an explicit per-field reason, so an unrelated subject does not require a usable timer. Missing rows are unavailable snapshot observations. No display fields, inferred deadline, duration sum, maximum or native alias fallback is used."] = true
L["Read one explicitly selected point-resource quantity with an exact two-argument UnitPower or UnitPowerMax query. The selector is required; no primary-resource inference or actor remapping occurs. Preserve finite signed, fractional and zero quantities without clamping. Missing, failed, restricted or nonfinite data remains unavailable. Current and maximum are separate observations so callers can share current snapshots while requesting maximum lazily."] = true
L["Read one protected GetRuneCooldown tuple for an exact native slot. Normalize ready, start and duration independently: ready requires a readable Boolean, while each time requires a readable finite number and preserves signed, fractional and zero values. Every unavailable field carries its own reason. A successful empty tuple yields a partial record; missing capability, policy or native-call failure yields nil. Never infer ready from timing or timing from ready. Cache this complete record at the caller to share one observation between rune-count and cooldown predicates."] = true
L["Read optional MobInfo2 historical observations on probe-policy clients. Cache only exact selected-unit presence; UnitName result one, UnitLevel result one and the three-argument MI2_GetMobData(name,level,unit) dot call stay fresh each invocation. Known absent units and successful unrecorded nil or omitted history remain distinct from unavailable native/provider facts. Preserve readable runner scalar truthiness, school signs and missing-Hits default one. Positive resistance ratios must be finite; complete immunity consumes finite Hits while partial immunity needs only its negative school observation. Never infer native resistance or borrow old records."] = true
L["Read optional RealMobHealth using its exact one-argument dot call. Absent nil/false namespace returns an empty record. Normalize current and maximum independently: nil/false fields permit native fallback, numeric zero remains present. Malformed, failed, restricted, negative or nonfinite consumed provider facts are unavailable. No provider or stale fallback cache is used."] = true
L["Read public group membership on identified client families. Unknown clients are unsupported. True raidOnly checks IsInRaid; false or nil checks IsInGroup using its native default group category. A readable false result stays false. Missing, failed, malformed or restricted observations return nil with a reason."] = true
L["Read public roster identity on identified client families. Input routing is limited to player, party1 through party4 and raid1 through raid40. Call UnitExists with that exact one-argument token first; known false returns false without querying class. For a present unit, consume only UnitClass return two as a readable nonempty class filename string, without a class enum restriction. Missing, failed, malformed or restricted required facts return nil with a reason."] = true
L["Read spell-specific range for a unit using the appropriate client API or spell-book slot. A spell without a range restriction returns applicable=false; otherwise applicable=true and inRange records whether the unit is in range. Unknown or inaccessible observations return nil with a reason."] = true
L["Read the current positive nameplate visibility distance using the supported CVar API. This limits a Distance Count query; it does not prove that all nearby units have been observed. Missing, malformed, restricted or failed observations return nil with a reason."] = true
L["Read the documented active loss-of-control count with a protected zero-argument dot call. Require a readable finite nonnegative integer. Zero is a complete empty scan and does not require a row API. RM limits a scan to 256 rows and returns unavailable beyond that resource budget; this is not a declared native maximum. Required missing, failed, restricted or malformed observations remain unavailable."] = true
L["Read the player auto-repeat state for a spell such as Shoot or Auto Shot. This is distinct from a current or queued cast. Modern clients receive the exact spell ID; a legacy query resolves the player spell-book slot first. Restricted client policies, unreadable results and unavailable book slots return nil with a reason. This observes state and never starts or stops a spell."] = true
L["Read the public LibRangeCheck interval for a unit. A successful upper bound is inclusive; a positive failed lower bound is strict. A zero lower floor is synthetic. Neither bound is an exact distance, and a missing upper bound is not proof that the unit is outside every radius. Unavailable, malformed, restricted or failed observations return nil with a reason."] = true
L["Readability authority for consumed values."] = true
L["Readable canonical item classification record, or nil when unavailable."] = true
L["Readable canonical itemID/classID/subClassID record when the item is a glyph for the requested class; nil for invalid or unavailable metadata."] = true
L["Readable charge record, or nil when unavailable."] = true
L["Readable consumed metadata string, false for a known absent unit, or nil when required data is unavailable."] = true
L["Readable cooldown record, or nil when unavailable."] = true
L["Readable current state, or nil when unavailable."] = true
L["Readable finite current-form observation, including zero for the current unshifted comparison; nil when unavailable."] = true
L["Readable finite positive integral rune type, or nil when unavailable."] = true
L["Readable interval with optional minimum and maximum bounds in yards. At least one bound is present; nil when unavailable."] = true
L["Readable nonempty selected unit token, passed unchanged as the single argument to existence and creature metadata queries."] = true
L["Readable nonempty unit token or native-recognized name, passed unchanged."] = true
L["Readable nonempty unit token to match, unchanged in the native observation."] = true
L["Readable nonempty unit token, passed unchanged as the single native argument."] = true
L["Readable record with Boolean exists and the requested class filename when present; nil when required data is unavailable."] = true
L["Readable selected flag or nil when required data is unavailable."] = true
L["Readable selected flag, false for a known absent unit, or nil when a required observation is unavailable."] = true
L["Readable unit equality, false for a known absent first unit, or nil when required observations are unavailable."] = true
L["Record with exists=false, or exists=true and finite value; nil when unavailable."] = true
L["Record with exists=false; recorded=false for known no history; or runner, ratio, or immune with hits/hitsReason. Nil means a required observation is unavailable."] = true
L["Record with inInstance and, when inside, instanceType or instanceTypeReason; nil when membership is unavailable."] = true
L["Reference input kind, such as Spec_EditBox, used for spell suggestions."] = true
L["Remove entries in place, preserving only keys listed among except values by default. With invert true, remove listed keys and retain unlisted keys. Without an exception list, the default removes every entry and invert true retains every entry. Nil input does nothing."] = true
L["Remove leading and trailing Lua-pattern whitespace from a string."] = true
L["Resolve a readable raw unit level for condition evaluation. Known absence returns false; unavailable observations return nil with a reason. Cache observations within the supplied evaluation pass. Only valid player levels are retained between passes until a skill, profile or level refresh."] = true
L["Resolve an exact cast-recipient name against the current bounded party or raid roster, then observe membership through a unit token. Missing, ambiguous or changing roster data remains unavailable; never reads the selected target or retains state across casts."] = true
L["Resolve point resources using the original live class mapping and identity cache, with an explicit TBC player ComboPoints-fallback transport policy. A player fallback matching the readable raw Enum.PowerType table and ComboPoints value captured at module load selects target-combo; explicit class-map entries, other actors and other families retain power. Replaced, inherited or unprovable fallback provenance retains power. This versioned policy does not claim native UnitPower is broken or equivalent. Known unit absence returns false; unavailable required observations return nil with a reason. No current or maximum quantity is queried here."] = true
L["Resolve the selected unit point-resource selector using the live class-to-resource map and ComboPoints fallback. Known absence returns false; unavailable required identity or selector data returns nil with a reason. Share complete identity observations within the evaluation pass. Only successful player class observations persist in the current longterm cache, tied to the native UnitClass identity; existence is refreshed each pass. This selects a resource without reading its current or maximum quantity."] = true
L["Resolve the spell identifier stored by a condition. With exact rank enabled the supplied ID is retained; otherwise ranked Classic clients resolve the currently known rank through the spell catalog. Returns nil and an availability reason if resolution cannot be completed."] = true
L["Resolved spell ID, or nil when unavailable."] = true
L["Resolver mapping a typed spell name to its ID."] = true
L["Return a present value unchanged, or a red display placeholder for nil. Use for readable condition labels, not as a boolean fallback."] = true
L["Return the first key whose value equals the supplied value during pairs traversal. Nil or false input tables and absent values return nil. Multiple matching keys have no guaranteed selection order."] = true
L["Right operand; DIVISIBLE requires a nonzero divisor."] = true
L["Rotation Master addon instance (implicit with colon calls)."] = true
L["Rotation Master platform adapter (implicit with colon calls)."] = true
L["Rotation Master platform adapter. A dot reference requires addon.Platform as the first argument; a colon call supplies it implicitly."] = true
L["Round with the existing floor(num * 10^places + 0.5) / 10^places formula. Places defaults to zero and may be negative. Halfway negative values round toward positive infinity; no finite-number validation or alternative rounding policy is added."] = true
L["Run the historical health-snapshot trend formula using the live profile history window, clock and legacy rounding service. Preserve its maximum-health transitions, early stop at full or zero health, weighting, errors and return counts. Empty snapshot arrays retain the original nonfinite result; this is the legacy algorithm rather than a validated forecast."] = true
L["Second exact unit token, passed unchanged to UnitIsUnit."] = true
L["Second table to compare."] = true
L["Selected nonempty unit token, unchanged in native calls."] = true
L["Selected nonempty unit token, unchanged in native/provider calls."] = true
L["Selected nonempty unit token."] = true
L["Selected nonempty unit token; this call alone does not establish presence."] = true
L["Selected nonempty unit token; unchanged native argument."] = true
L["Selected unit token forwarded as the only provider argument."] = true
L["Selected unit token, unchanged in observations."] = true
L["Selector widget supporting SetList, SetValue, SetLabel, SetDisabled and callbacks."] = true
L["Shared evaluation cache; nil observes directly without a per-pass cache."] = true
L["Source array whose ipairs prefix is inserted without copying nested values."] = true
L["Specialization scope used to resolve spell suggestions."] = true
L["Spell ID or client-recognized spell name whose charges should be read."] = true
L["Spell ID or client-recognized spell name whose cooldown should be checked."] = true
L["Spell ID or client-recognized spell name whose cooldown should be read."] = true
L["Spell ID whose range should be checked."] = true
L["Spell field group containing an action icon, reference input and optional rank control."] = true
L["Spell-book scope: spell, pet or any."] = true
L["Split a string into nonempty runs between separator characters. The separator is inserted into a Lua pattern character class; it is not a literal multi-character delimiter. Empty fields are omitted."] = true
L["Stored spell ID to resolve."] = true
L["Successful observation record with pvpType string or nil; nil record means unavailable."] = true
L["Table to copy shallowly, or nil."] = true
L["Table to count, or nil for zero."] = true
L["Table to inspect."] = true
L["Table to modify, or nil to do nothing."] = true
L["Table to search; nil or false returns nil."] = true
L["Table to traverse; keys must be mutually comparable when no custom ordering is supplied."] = true
L["Table whose keys should be converted to strings."] = true
L["Table whose values must be mutually comparable."] = true
L["Target line width, default 72 characters."] = true
L["Test a literal byte prefix using a Lua string slice. Empty prefixes match; pattern characters have no special meaning and case is preserved."] = true
L["Test a literal byte suffix using a Lua string slice. Empty suffixes match; pattern characters have no special meaning and case is preserved."] = true
L["Text or number shown after the comparison wording."] = true
L["Text or number shown before the comparison wording."] = true
L["Text to inspect."] = true
L["Text to split."] = true
L["Text to trim."] = true
L["Text to wrap."] = true
L["Text widget supporting label, text, pending-edit and callback methods."] = true
L["Text with line breaks inserted at word boundaries."] = true
L["The selected value, including false or nil."] = true
L["Transient trusted phrase recognized by condition summary rendering; do not persist it as condition data."] = true
L["Transient typed predicate used as a named phrase value; do not persist it as condition data."] = true
L["Trimmed text."] = true
L["True also observes maximum health; false or nil reads current health only."] = true
L["True also observes the selected resource maximum; false or nil reads current quantity only."] = true
L["True also requires the present unit class filename; false reads existence only."] = true
L["True checks raid membership only; false or nil checks party or raid."] = true
L["True checks raid membership only; false or nil checks party then raid."] = true
L["True for a readable attackable non-dead unit, false for a conclusive negative result, or nil when a required observation is unavailable."] = true
L["True for an exact identity match; false for known absence or mismatch; nil when required data or the query is unavailable."] = true
L["True includes only listed entries; false or nil excludes listed entries."] = true
L["True marks the main comparison to negate; false or nil leaves it eligible only when no primary predicate exists."] = true
L["True permits the raid roster when raid membership is known true; false or nil uses the solo or party roster."] = true
L["True removes listed entries; false or nil preserves only listed entries."] = true
L["True requests raid membership; false or nil requests any group membership."] = true
L["True requests the formatted pet name; false or omitted reads presence only."] = true
L["True selects percentage target and optional fresh provider facts."] = true
L["True skips all access to the damage stream."] = true
L["True skips all access to the healing stream."] = true
L["True to require this exact rank; false or nil follows the available rank."] = true
L["True when array[value] is non-nil."] = true
L["True when every visited entry compares equal in both directions."] = true
L["True when ready by the end of the global cooldown; false when its own cooldown prevents recommendation; nil when the client cannot supply a readable result."] = true
L["True when the client reports this spell auto-repeating; false when it reports inactive; nil when unavailable."] = true
L["Truthy skips the damage stream without reading its array."] = true
L["Truthy skips the heals stream without reading its array."] = true
L["Unit key-to-display-name map shown in the selector."] = true
L["Unit token to compare with the literal player token."] = true
L["Unit token whose current cast or channel should be observed."] = true
L["Unit token whose current health should be observed."] = true
L["Unit token whose raw level should be observed."] = true
L["Unit token whose raw level should be resolved."] = true
L["Unit token, such as target; nil uses target."] = true
L["Validation or availability reason for a nil result."] = true
L["Validation, policy or availability reason for a nil result."] = true
L["Validation, policy or required-fact availability reason for a nil count."] = true
L["Value compared with each table value using Lua equality."] = true
L["Value passed to the original arithmetic formula."] = true
L["Value record field to edit; defaults to unit."] = true
L["Value returned for every other unit."] = true
L["Value returned when unit is player."] = true
L["Value to display; false is preserved."] = true
L["Visit entries in both tables and compare each value with the indexed value in the other table using Lua equality. Normal indexing and equality metamethods apply; nested contents are not compared recursively."] = true
L["Weighted health-snapshot change from the original total/count formula; zero for falsy input."] = true
L["Weighting window in seconds; nil or false uses the current profile damage_history setting."] = true
L["Whether the original floor-equality or exact numeric-spelling predicate matches."] = true
L["Whether the text begins with the exact prefix."] = true
L["Whether the text ends with the exact suffix."] = true
L["With restricted-value only: isActive, true while a cooldown (its own or the global one) is running."] = true
L["With restricted-value only: isEnabled, false while the cooldown is on hold."] = true
L["With restricted-value only: isOnGCD, true when the running cooldown is the global cooldown; may be nil."] = true
L["Work-limit, data or arithmetic availability reason for nil rate/age."] = true
L["Wrap text at whitespace boundaries near a target column count. Long words are retained intact."] = true
L["mana selects the explicit live Mana enum; current reads and forwards the actual UnitPowerType identity, including Mana zero."] = true
L["noheals selects damage only; nodmg selects healing only; other readable values select both."] = true
-- END GENERATED RM PUBLIC HELPER DOCS
