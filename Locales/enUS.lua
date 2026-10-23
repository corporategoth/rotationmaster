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

L["Default.TBC.Shaman.Starter.Name"] = "Shaman: early leveling (1–29)"
L["Default.TBC.Shaman.Starter.Description"] = "Bounded TBC solo starter preview for levels 1–29. Optional highlights remind you to maintain your weapon imbue and Lightning Shield, with Attack as an implicit final priority when needed. The sequence opens with Lightning Bolt, stops further spell suggestions while out of combat, uses Earth Shock in combat, and continues Lightning Bolt beyond close range while stationary. Uses learned ranks with native availability checks. Healing, interrupts, totems, consumables, talent cooldowns and resource management remain manual."

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
L["Game locale: %s. English is the installed translation; other languages use English until translated."] = true
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
L["Higher priority wins within custom or Built In rotations. Custom rotations and a valid saved fallback take precedence over Built In rotations. Equal priorities use name, then identity. Blank means zero."] = true
L["Invalid switch priority for %s:%s; explicit repair resets it to zero."] = true

-- Rank-aware aura families.
L["Match all ranks"] = true
L["%s (any rank)"] = true
L["For a numeric spell selection, also recognize auras with the same readable localized spell name. Exact IDs remain the default. Spell names already match by name. Unavailable metadata or restricted aura identity stays unavailable, including under NOT. Different spells sharing a name can match; use exact IDs when that distinction matters."] = true

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
L["Default.TBC.Mage.Starter.Name"] = "Mage: early Frost leveling (1–29)"
L["Default.TBC.Mage.Starter.Description"] = "Bounded TBC single-target Frost preview for levels 1–29. Optional Intellect and Frost Armor upkeep, stationary pulls and combat fillers adapt to trained ranks. Each training-dependent arm selects one filler; unavailable spells do not select the opposite arm. Uses ranked action lookup with availability fallback. Talent cooldowns, mana management, kiting, crowd control, emergency shields and consumables remain manual. Other specializations and levels 30+ need separate rotations."

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

L["Edit the description, tags, switch priority, author, realm, email, website and version. Source citations remain separate from your attribution. Apply updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values."] = true

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
L['/rm editorinfo          - Copy native Lua input diagnostics.'] = true
L['/rm editorarrows        - Temporarily test native arrows in an open editor.'] = true
L['Open or reopen a Lua editor before using /rm editorarrows.'] = true
L['Temporary native arrow test enabled. Try up/down; run /rm editorarrows again to restore the editor hook.'] = true
L['Temporary native arrow test disabled; the editor hook is restored.'] = true
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
L["Help.General.live_config_update"] = "Set the refresh interval for condition status while editing, in seconds. Zero turns off periodic status updates. This is separate from the recommendation polling interval and does not enable live condition testing unless you explicitly choose it."
L["Help.General.minimap"] = "Show the Rotation Master minimap icon. Left-click toggles the configuration window. Right-click opens the quick menu for enabling recommendations and choosing a rotation or automatic switching."
L["Help.General.rotation_view"] = "Choose Diagram or List as the starting rotation view. This profile preference applies when opening a rotation; changing the view inside the editor does not change this setting. Cooldowns always use a scrolling grid."
L["Help.General.spell_history"] = "Choose how many seconds of previous spell casts to retain for history-based conditions. Older casts are removed as recommendations update. A longer history retains more records."
L["Help.General.combat_history"] = "Choose how many seconds of combat events to retain for conditions such as recent hits, parries and blocks. Older events are removed as recommendations update. Availability depends on the client combat-data policy."
L["Help.General.damage_history"] = "Choose how many seconds of observed damage and healing to retain for burn-rate and time-to-die estimates. Recent observations receive more weight. A longer window uses more records and smooths short changes; it cannot supply events the client does not expose."
L["Help.General.preview_spells"] = "Choose a whole number of upcoming recommendations, from zero (hidden) to five. The preview shows current priority results, not a simulation of future cooldowns or combat. Icons start at 64 pixels; resizing scales all icons while preserving their square shape and the window ratio."
L["Help.General.preview_opacity"] = "Adjust the preview background and title bar opacity without fading its icons. At zero only the icons remain, and the hidden frame does not intercept blank-space clicks. Restore opacity in General to access the title bar and resize handle."
L["Help.General.preview_locked"] = "Prevent moving the preview by its title bar or resizing it by its lower-right corner. Locking and unlocking take effect immediately and are saved without Apply. Other pending General edits remain unchanged."
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

L["Default.TBC.Paladin.Starter.Name"] = "Paladin: early leveling (1–19)"
L["Default.TBC.Paladin.Starter.Description"] = "Bounded melee preview with optional Devotion Aura and Seal of Righteousness upkeep, preserving your chosen Retribution Aura or Crusader seal. Judgement requires observed Righteousness during combat. Blessings, healing, pulls and mana conservation remain manual."

L["Default.TBC.Hunter.Starter.Name"] = "Hunter: early leveling (1–19)"
L["Default.TBC.Hunter.Starter.Description"] = "Bounded ranged preview: establish Auto Shot, then own Serpent Sting and Arcane Shot; optional Hawk preserves Monkey. No implicit melee advice. Pet control, ammunition, positioning and resource conservation remain manual; native readiness governs recommendations."

L["Default.TBC.Rogue.Starter.Name"] = "Rogue: early leveling (1–19)"
L["Default.TBC.Rogue.Starter.Description"] = "Melee preview: missing own Slice and Dice from two combo points, Eviscerate from five, otherwise Sinister Strike. Preserves stealth, casts and channels. Openers, poisons, utility, targets and resource planning remain manual."
L["Default.TBC.Druid.Caster.Starter.Name"] = "Druid: early caster leveling (1–19)"
L["Default.TBC.Druid.Caster.Starter.Description"] = "Caster-only preview in humanoid form: own Moonfire, then stationary Wrath. Preserves your manually chosen forms and suppresses implicit melee advice. Feral combat, form selection, targeted support and resource decisions remain manual."

L["Default.TBC.Warrior.Starter.Name"] = "Warrior: early leveling (1–19)"
L["Default.TBC.Warrior.Starter.Description"] = "Bounded combat-only Warrior preview: optional Battle Shout, own Rend, Heroic Strike and normal melee fallback. Queued Heroic Strike is preserved. Rend through level 19 and spending available rage are RM preview policies; pulls, reactive abilities, stances and resource conservation remain manual."

L["Default.TBC.Priest.Starter.Name"] = "Priest: early leveling (1–19)"
L["Default.TBC.Priest.Starter.Description"] = "Bounded solo Priest preview with optional Inner Fire, opening Mind Blast, own Shadow Word: Pain, wanding and Smite. The half-health cutoff is an RM heuristic; healing, shields, party support and resources remain manual."

L["Default.TBC.Warlock.Starter.Name"] = "Warlock: early leveling (1–29)"
L["Default.TBC.Warlock.Starter.Description"] = "Bounded solo Affliction preview: owned damage-over-time spells, conservative Drain Life, wanding and optional Demon Skin or Demon Armor upkeep. Learned Demon Armor supersedes Demon Skin. Manual demon and resource control; expires at level 30."

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








L["Default.TBC.Priest.Continuation.Name"] = "Priest: wand / learned Mind Flay (20–29)"
L["Default.TBC.Priest.Continuation.Description"] = "Bounded solo Priest preview for levels 20–29. Optional Inner Fire, opening Mind Blast and own Shadow Word: Pain precede learned Mind Flay above half health, then stationary wanding or Smite fallback. Manually choose when to channel or wand; active channels and wand filler are preserved. Repeated Mind Flay and the half-health cutoff are RM preview policies; talents, healing, shields, party support and resources remain manual."

L["Default.TBC.Warrior.Continuation.Name"] = "Warrior: early leveling (20–29)"
L["Default.TBC.Warrior.Continuation.Description"] = "Bounded combat-only Warrior preview for levels 20–29. Optional Battle Shout, learned Execute below 20% target health, then Heroic Strike and normal melee fallback. Preserves all four queued Heroic Strike ranks in this bracket. Rend maintenance ends here; reactive abilities, stances, pulls and resource or queue planning remain manual."

L["Default.TBC.Hunter.Thirty.Name"] = "Hunter: ranged leveling (30–39)"
L["Default.TBC.Hunter.Thirty.Description"] = "Bounded single-target ranged preview. Preserves current casts, channels, chosen Monkey or Cheetah, and attributable own Scorpid. Starts inactive Auto Shot while stationary, then own missing Serpent Sting and Arcane Shot. Learned ranks, mappings and current readiness remain authoritative; pets, ammunition, positioning, shot timing, melee, talents and resources remain manual."
L["Default.TBC.Hunter.Forty.Name"] = "Hunter: ranged leveling (40–49)"
L["Default.TBC.Hunter.Forty.Description"] = "Bounded single-target ranged preview. Preserves current casts, channels, chosen Monkey or Cheetah, and attributable own Scorpid. Starts inactive Auto Shot while stationary, then own missing Serpent Sting and Arcane Shot. Learned ranks, mappings and current readiness remain authoritative; pets, ammunition, positioning, shot timing, melee, talents and resources remain manual."
L["Default.TBC.Hunter.Continuation.Name"] = "Hunter: early leveling (20–29)"
L["Default.TBC.Hunter.Continuation.Description"] = "Bounded ranged preview for levels 20–29. Auto Shot, own Serpent Sting and Arcane Shot use native learned ranks and availability. Preserves current casts, channels, Auto Shot, chosen Monkey or Cheetah, and attributable own Scorpid Sting. Pets, melee, ammunition, shot timing, positioning and resources remain manual."
L["Default.TBC.Paladin.Continuation.Name"] = "Paladin: manual seal/aura preview (20–29)"
L["Default.TBC.Paladin.Continuation.Description"] = "Bounded preview for levels 20–29. Optional Devotion and Righteousness preserve recognized manual aura and Crusader, Command or Justice choices. Only Righteousness Judgement is advised in combat; choose other seals, auras, their Judgements and resource use manually. Native learned ranks, bar mappings and readiness remain authoritative."
L["Default.TBC.Druid.Caster.Continuation.Name"] = "Druid: caster leveling (20–29)"
L["Default.TBC.Druid.Caster.Continuation.Description"] = "Bounded humanoid caster preview for levels 20–29. Maintains attributable own Moonfire, then prefers actually learned stationary Starfire before Wrath fallback. Preserves current casts and channels; shifted forms stop caster advice. Feral attacks, forms, healing, talents, crowd control and resources remain manual."

L["Default.TBC.Rogue.Continuation.Name"] = "Rogue: early leveling (20–29)"
L["Default.TBC.Rogue.Continuation.Description"] = "Bounded melee preview for levels 20–29. Retains missing own Slice and Dice from two combo points, Eviscerate from five, otherwise Sinister Strike, using actually learned ranks and native readiness. Preserves stealth, casts and channels. Poisons, openers, positional attacks, reactive talents, target lifetime and resources remain manual."
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

L["Default.TBC.Mage.Thirties.Name"] = "TBC Mage 30–39 Frost single-target preview"
L["Default.TBC.Mage.Thirties.Description"] = "Bounded level 30–39 Frost single-target preview. Preserves any existing Frost, Ice or Mage Armor; offers learned Mage, then Ice, then Frost Armor only when all are absent. Intellect remains independent. Talents, kiting, emergency defenses and resources stay manual."

L["Default.TBC.Shaman.Enhancement30.Name"] = "Shaman: Enhancement leveling (30–39)"
L["Default.TBC.Shaman.Enhancement30.Description"] = "Bounded TBC solo Enhancement-oriented preview for levels30–39, selected only when Enhancement has the unique positive highest talent allocation. Uses learned ranks for a Lightning Bolt pull, Earth Shock in combat and stationary ranged Lightning Bolt, with independent Lightning Shield and mainhand imbue reminders. Prefers learned Windfury over Rockbiter only when no temporary mainhand enchant is present; preserves any manual enchant and does not infer a weapon type or complete build. Equipment, healing, interrupts, totems, consumables, weapon timing and resource optimization remain manual. Not native gameplay certified."

L["Default.TBC.Warlock.Thirties.Name"] = "TBC Warlock 30–39 single-target preview"
L["Default.TBC.Warlock.Thirties.Description"] = "Bounded Affliction-oriented preview with learned Siphon Life; proc priorities, talents, pets and resources remain manual."

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


L["Default.TBC.Priest.Shadow30.Name"] = "Priest: Shadow leveling (30–39)"
L["Default.TBC.Priest.Shadow30.Description"] = "Bounded Shadow-oriented solo preview; learned spells and native readiness remain authoritative. Choose channels and wand manually; healing and resources remain manual."
L["Default.TBC.Priest.Shadow40.Name"] = "Priest: Shadow leveling (40–49)"
L["Default.TBC.Priest.Shadow40.Description"] = "Bounded Shadow-oriented solo preview; learned spells and native readiness remain authoritative. Choose channels and wand manually; healing and resources remain manual."


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

L["Default.TBC.Paladin.Thirty.Name"] = "Paladin: manual seals and auras (30–39)"
L["Default.TBC.Paladin.Thirty.Description"] = "Bounded combat preview with fully manual aura and seal upkeep. Only attributable own Righteousness permits Judgement; conflicting seals and current casts or channels block it. Learned actions, mappings and native readiness govern recommendations; talents, support, resources and other seal judgements remain manual."
L["Default.TBC.Rogue.Thirty.Name"] = "Rogue: melee leveling (30–39)"
L["Default.TBC.Rogue.Thirty.Description"] = "Bounded single-target melee preview. Preserves manual stealth, casts and channels. Missing attributable own Slice and Dice from two current-target combo points, Eviscerate at five, otherwise Sinister Strike. Learned ranks, mappings and native readiness govern actions; openers, poisons, talents, positioning, reactive utility, target lifetime and resources remain manual."
L["Default.TBC.Druid.Caster.Thirty.Name"] = "Druid: caster leveling (30–39)"
L["Default.TBC.Druid.Caster.Thirty.Description"] = "Bounded humanoid caster preview. Preserves manual forms, casts and channels; own missing Moonfire, learned stationary Starfire, then independently ready Wrath. Native learned ranks, mappings and readiness govern recommendations. Feral combat, talents, support and resources remain manual; no implicit melee advice."
L["Default.TBC.Warrior.Thirty.Name"] = "Warrior: combat leveling (30–39)"
L["Default.TBC.Warrior.Thirty.Description"] = "Bounded combat preview. Learned Execute below 20% target health, five exact learned Heroic Strike queue guards, then native-ready Heroic Strike. Optional Battle Shout respects casts and channels. Native ranks, mappings and readiness govern actions; stances, reactive abilities, Rend, pulls, talents and resource or queue planning remain manual."
L["Default.TBC.Shaman.Enhancement40.Name"] = "Shaman: Enhancement leveling (40–49)"
L["Default.TBC.Shaman.Enhancement40.Description"] = "Bounded TBC solo Enhancement-oriented preview for levels40–49, selected only when Enhancement has the unique positive highest talent allocation. Uses learned ranks for a Lightning Bolt pull, Earth Shock in combat and stationary ranged Lightning Bolt, with independent Lightning Shield and mainhand imbue reminders. Prefers learned Windfury over Rockbiter only when no temporary mainhand enchant is present; preserves any manual enchant and does not infer a weapon type or complete build. Equipment, healing, interrupts, totems, consumables, weapon timing and resource optimization remain manual. Not native gameplay certified."
L["Default.TBC.Warlock.Forties.Name"] = "TBC Warlock 40–49 single-target preview"
L["Default.TBC.Warlock.Forties.Description"] = "Bounded Affliction-oriented preview with learned Siphon Life; proc priorities, talents, pets and resources remain manual."

-- Explicit unscored advice/native-preview receipt coverage.
L['Advice/presentation rows describe observed delivery boundaries only; ordinary-cast proof: not available.'] = true
L['Coverage rows: advice=%d presentation=%d visible=%d hidden=%d unknown=%d retired=%d (not opportunities).'] = true
L['Visible means RM-owned preview frame state at a delivery boundary; it does not prove perception or native pixel rendering.'] = true

L["Default.TBC.Mage.Forties.Name"] = "TBC Mage 40–49 Frost single-target preview"
L["Default.TBC.Mage.Forties.Description"] = "Inherited bounded level 40–49 Frost single-target preview. Preserves manual armor; offers learned Mage, then Ice, then Frost Armor only when all are absent. Talents, kiting, emergency defenses and resources stay manual."
L["Default.TBC.Mage.Fifties.Name"] = "TBC Mage 50–59 Frost single-target preview"
L["Default.TBC.Mage.Fifties.Description"] = "Inherited bounded level 50–59 Frost single-target preview. Preserves manual armor; offers learned Mage, then Ice, then Frost Armor only when all are absent. Talents, kiting, emergency defenses and resources stay manual."
L["Default.TBC.Warrior.Forty.Name"] = "TBC Warrior40–49 combat preview"
L["Default.TBC.Warrior.Forty.Description"] = "Levels40–49: inherited melee preview with seven exact learned Heroic Strike queue guards. Stances, talents, reactive abilities and resources remain manual."
L["Default.TBC.Paladin.Forty.Name"] = "TBC Paladin40–49 manual seal/aura preview"
L["Default.TBC.Paladin.Forty.Description"] = "Levels40–49: preserve manual auras and seals; only affirmative own Righteousness permits Judgement. Support, talents and resources remain manual."
L["Default.TBC.Rogue.Forty.Name"] = "Rogue: melee leveling (40–49)"
L["Default.TBC.Rogue.Forty.Description"] = "Bounded single-target melee preview. Preserves manual stealth, casts and channels. Missing attributable own Slice and Dice from two current-target combo points, Eviscerate at five, otherwise Sinister Strike. Learned ranks, mappings and native readiness govern actions; openers, poisons, talents, positioning, reactive utility, target lifetime and resources remain manual. This inherited subset is not a complete or optimal 40s build."
L["Default.TBC.Druid.Caster.Forty.Name"] = "Druid: limited caster leveling (40–49)"
L["Default.TBC.Druid.Caster.Forty.Description"] = "Bounded humanoid caster-only preview. Preserves manual forms, casts and channels; own missing Moonfire, learned stationary Starfire, then independently ready Wrath. Native learned ranks, mappings and readiness govern recommendations. Feral combat, form changes, talents, support and resources remain manual; no implicit melee advice. This inherited subset is not a complete or optimal 40s build."

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

L["Default.TBC.Shaman.Enhancement50.Name"] = "Shaman: Enhancement leveling (50–59)"
L["Default.TBC.Shaman.Enhancement50.Description"] = "Bounded TBC solo Enhancement-oriented preview for levels50–59, selected only when Enhancement has the unique positive highest talent allocation. Uses learned ranks for a Lightning Bolt pull, Earth Shock in combat and stationary ranged Lightning Bolt, with independent Lightning Shield and mainhand imbue reminders. Prefers learned Windfury over Rockbiter only when no temporary mainhand enchant is present; preserves any manual enchant and does not infer a weapon type or complete build. Equipment, healing, interrupts, totems, consumables, weapon timing and resource optimization remain manual. Not native gameplay certified."

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
L["Default.TBC.Priest.Shadow50.Name"] = "Priest: Shadow leveling (50–59)"
L["Default.TBC.Priest.Shadow50.Description"] = "Bounded Shadow-oriented solo preview; learned spells and native readiness remain authoritative. Choose channels and wand manually; healing and resources remain manual."
L['Help.General.memory_capture'] = "Start a ten-minute memory capture. Whole-Lua heap reads occur once per second; slower addon-memory refreshes and bounded container counts occur every thirty seconds. Sampling costs are reported. The capture does not force garbage collection, enable the native profiler or change gameplay polling."
L['Help.General.memory_report'] = "Open the completed or stopped memory observations in a selectable, copyable report. Addon memory is sampled attribution, and container counts are rows or keys rather than bytes. Memory drops alone do not prove garbage collection or the absence of a leak."
L['Help.General.memory_stop'] = "Stop the current memory capture and preserve its observations for Memory report. This cancels only memory-capture timers. No gameplay settings are changed."

L['Silent'] = true

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
L["Check whether a spell can be recommended now, allowing a spell whose remaining cooldown ends with the current global cooldown. This checks cooldown readiness only; it does not check learned status, range or resource usability. Pass evaluation time from evalStart or GetTime()."] = true
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
L["Finite ETA including zero, false for known absence/no estimate, or nil when unavailable."] = true
L["Finite final stream age, or nil when unavailable."] = true
L["Finite minimum native threat status, preserving signed and fractional thresholds."] = true
L["Finite native creature ID, false for known unit absence, or nil when required observations are unavailable."] = true
L["Finite native resource quantity, retaining its sign and fractional part; nil when unavailable."] = true
L["Finite native threat status, false for known absence/nonenemy/no-threat, or nil for unavailable observations."] = true
L["Finite nonnegative native health scalar, or nil when unavailable."] = true
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
L["Read and normalize a spell cooldown across supported clients. The returned record contains startTime, duration, isEnabled and modRate. The timestamps and duration already describe expiration in GetTime() seconds; do not divide them by modRate."] = true
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
L["Work-limit, data or arithmetic availability reason for nil rate/age."] = true
L["Wrap text at whitespace boundaries near a target column count. Long words are retained intact."] = true
L["mana selects the explicit live Mana enum; current reads and forwards the actual UnitPowerType identity, including Mana zero."] = true
L["noheals selects damage only; nodmg selects healing only; other readable values select both."] = true
-- END GENERATED RM PUBLIC HELPER DOCS
