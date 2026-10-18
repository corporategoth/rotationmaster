local addon_name = ...

local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true)
if not L then return end
L["Undo"] = true
L["Redo"] = true

local color = color

-- from main.lua

L["/rm help                - This text."] = true
L["/rm config              - Open the config dialog."] = true
L["/rm disable             - Disable battle rotation."] = true
L["/rm enable              - Enable battle rotation."] = true
L["/rm toggle              - Toggle between enabled and disabled."] = true
L["/rm current             - Print out the name of the current rotation."] = true
L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."] = true
L["                          This is reset upon switching specializations."] = true
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
L["This condition matches if any sub-condition matches. With no sub-conditions, it does not match."] = true

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

L["Default.TBC.Shaman.Starter.Name"] = "Shaman: early leveling (1–19)"
L["Default.TBC.Shaman.Starter.Description"] = "TBC solo starter preview. Optional highlights remind you to maintain your weapon imbue and Lightning Shield, with Attack as an implicit final priority when needed. The sequence opens with Lightning Bolt, stops further spell suggestions while out of combat, uses Earth Shock in combat, and continues Lightning Bolt beyond close range while stationary. Skips unlearned abilities. Once Attack is active your weapon keeps swinging between spells. Healing, totems, consumables and later talents are not covered."

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
L["AND requires every child; OR requires any child; NOT reverses its child. Unavailable data remains unavailable."] = true
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

L["All (AND) requires every child to match. An empty group always matches. Unavailable data remains unavailable."] = true
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
L["The question mark explains the visible controls. With condition fields open, it adds that condition’s help below the fields. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data."] = true
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
L["Default.TBC.Mage.Starter.Name"] = "Mage: early Frost leveling (1–19)"
L["Default.TBC.Mage.Starter.Description"] = "TBC single-target Frost starter preview. Optional Intellect and armor upkeep, stationary pulls and combat fillers adapt to trained early ranks. Each training-dependent arm selects one filler; unavailable spells do not select the opposite arm. The same decision handles safe pulls and combat, without duplicated actions. Uses ranked action lookup with availability fallback; no automatic kiting, crowd control, shields, finishers or consumable use. Fire/Arcane specialization and later levels need other rotations."

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
L["Help.Announces.overview"] = "Announce selected spell casts or item uses independently of your active rotation. Select an entry in the sidebar, or use New to prepare one. The fields below choose what to watch and how to notify you; they do not cast spells or use items. Cast-triggered announcements follow RM's combat-data policy and do not run on reference-only clients."
L["Help.Announces.name"] = "An optional name identifies this announcement in the sidebar. Without one, the action name is used. Changing the name does not change the spell or items being watched."
L["Help.Announces.type"] = "Choose Spell, Pet Spell, or Item. Changing to a different action type clears the previous action and exact-rank choice; choosing the current type keeps them."
L["Help.Announces.type.spell"] = "Watch one of your spells. Choose the spell in the searchable field below Action Type."
L["Help.Announces.type.pet"] = "Watch a spell from your pet spellbook. The spell selector uses the pet catalog for this action type."
L["Help.Announces.type.item"] = "Watch item-use spells from a reusable item set or a custom list. This is an announcement trigger; it does not choose an item to use for you."
L["Help.Announces.spell"] = "Search by spell name, select a result, or drag a spell from your spellbook or action bar into the field. The icon and name identify the selected spell. Spell and pet spell choices keep their respective catalog scope."
L["Help.Announces.ranked"] = "Checked limits matching to the selected rank. Unchecked includes the known ranks in that spell family. This checkbox is shown for Spell and Pet Spell, not Item."
L["Help.Announces.items"] = "Choose a reusable set, or Custom to edit this announcement's own list. For a custom list, search for or drag items into the fields; Add item appends one and a red trash can removes an entry. Any matching item-use spell in the list can trigger the announcement; list order does not limit announcements to the first carried item. Changes to a shared set belong on the Item Sets page."
L["Help.Announces.event"] = "Choose which observed cast event triggers this entry. A start, stop, interruption, failure, or delay is different from a successful cast. The events available and the information they carry depend on the client."
L["Help.Announces.event.START"] = "The cast or channel started. This event does not mean it will finish successfully."
L["Help.Announces.event.STOP"] = "The cast or channel stopped. A stop alone does not establish whether it succeeded."
L["Help.Announces.event.SUCCEEDED"] = "The client reported a successful spell cast or item-use spell. For a channel, this can occur as channeling begins rather than after its final tick."
L["Help.Announces.event.INTERRUPTED"] = "The client reported that the cast was interrupted. This can include cancelling a cast yourself."
L["Help.Announces.event.FAILED"] = "The client reported that the cast failed. This is separate from the successful-cast event."
L["Help.Announces.event.DELAYED"] = "The client reported a delay to the cast. This event is not a completion or success notification."
L["Help.Announces.announce"] = "Choose a chat destination, local chat output, or Audible. Audible replaces the Text field with Sound selection and a preview button. Existing text is retained when switching to sound and back."
L["Help.Announces.channel.audible"] = "Play the selected sound locally on the Master audio channel; no chat message is sent. Choose an available sound before applying the announcement."
L["Help.Announces.channel.partyraid"] = "Use raid chat while in a raid, party chat while in a party, or your local chat frame while solo."
L["Help.Announces.channel.party"] = "Use party chat when grouped, including your party within a raid. This destination produces no solo chat message."
L["Help.Announces.channel.raidwarn"] = "Request group warning output. Depending on group membership and permissions, RM may use raid chat, party chat, or local output instead."
L["Help.Announces.channel.emote"] = "Send the text as an emote. Other players who can receive that emote may see it."
L["Help.Announces.channel.local"] = "Write to your own chat frame. Other players do not receive this message."
L["Help.Announces.text"] = "Enter the message for a chat destination. The substitutions below insert action and cast information when it is available. This text is not used for Audible output."
L["Help.Announces.substitutions"] = "Use {{spell}} for a spell link, {{item}} for an item link, and {{event}} for the localized event name. {{target}} uses the target recorded for that cast, with the last recorded target for that spell as a fallback; it does not automatically use your current target or your own name. A substitution can remain unchanged if its metadata or target is unavailable."
L["Help.Announces.sound"] = "Choose a sound supplied by the shared-media catalog, then click Play to preview it. Preview is local and does not save the draft. An unavailable sound cannot be previewed; Audible announcements require a nonempty sound selection."
L["Help.Announces.state"] = "The pill turns this entry on or off while keeping its fields. Disabled entries do not announce matching casts. Save the changed state with Apply."
L["Help.Announces.save"] = "Edits stay in a draft until Apply. Complete the action and required fields before saving. Cancel discards the page draft. Leaving with pending changes asks whether to Apply, Discard, or Cancel navigation."
L["Help.Announces.collections"] = "Use the buttons below the sidebar to create, duplicate, transfer, or compare announcements. Import can create a renamed entry or replace the selected one after validation; Apply saves the staged result. Compare does not merge entries. The red trash can removes the selected announcement from the draft; Cancel can discard that deletion before saving."
L["Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid text stays red and blocks navigation until corrected. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents."] = true

-- Item-set and item-list help: translate each paragraph as a whole.
L["Help.ItemSets.overview"] = "An item set is an ordered list of alternatives, such as different mana potions. Runtime selection checks the list from the top for a carried or, where requested, equipped item. Priority comes from the order you choose, not the item level. Selecting an item does not by itself prove that it is usable, off cooldown, or in range; action readiness is checked separately."
L["Help.ItemSets.name"] = "Name the selected set so it can be found in the sidebar and referenced by rotations or conditions. New opens a name form; its first Apply saves an empty named set. Add items afterward and Apply again to save them. Cancelling later item edits keeps that already saved set. Renaming a set does not change its identity in saved references."
L["Help.ItemSets.global"] = "Checked stores this set in the shared global collection, available to other profiles and characters using this addon database. Unchecked stores it in the current profile, which can itself be shared by characters. This is a staged move; Apply saves it. A profile set takes precedence if a global set has the same saved identity."
L["Help.ItemSets.items"] = "Click the heading to hide or show the list. Put preferred items first. RM can leave a selection unavailable when required inventory or identity observations are missing; it does not treat unknown data as proof that a lower-priority item should be used. The sidebar icon represents the first defined item and need not be the currently carried or highlighted one."
L["Help.ItemSets.item"] = "Search by item name and choose a result, or drag an item from your bags or action bar into its field. The icon identifies the item; metadata can take time to load. Edit a row to replace that entry. Use its red trash can to remove it rather than clearing a required item field."
L["Help.ItemSets.add"] = "Choose or drag an item into the empty Item field, then click Add item to append it to the priority list. Entering an item in this field alone does not add a row."
L["Move Up / Move Down"] = true
L["Help.ItemSets.order"] = "Use the arrows on the left, or drag an item row into a highlighted insertion gap. The floating preview identifies what you are moving. Moves past the beginning or end are unavailable. Reordering changes priority and stays in the draft until Apply."
L["Bind / Unbind"] = true
L["Help.ItemSets.binding"] = "Outside combat, apply pending item-set edits before binding. Bind picks up an available item for you to place on an action bar. RM records the slot and updates it as item availability changes. The pill shows bound slot numbers; click it to unbind and remove still-matching bar items. Replaced bar actions are preserved. Binding changes are immediate action-bar operations, independent of Apply, Cancel, and draft history."
L["Help.ItemSets.reset"] = "Restore the packaged item list for this set. Reset is available only for a set with a packaged default. The restored list is staged until Apply; the name is kept."
L["Help.ItemSets.delete"] = "The red trash can at the top right removes the selected set after confirmation. References to that set in rotations or conditions then need another set. Deletion is staged; Cancel can discard it before Apply. Saving the deletion also reconciles its bindings."
L["Undo / Redo"] = true
L["Help.ItemSets.history"] = "Undo and Redo travel through recent item-set draft edits, including replacements, additions, ordering, and removals. They are unavailable when that direction has no history. Apply, Cancel, or leaving the page clears this bounded history. They do not reverse explicit action-bar binding operations."
L["Apply / Cancel"] = true
L["Help.ItemSets.save"] = "Ordinary item-set edits stay in a draft until Apply. Cancel restores the saved item sets. Leaving with pending changes offers Apply, Discard, or Cancel navigation. Invalid fields must be corrected or discarded before saving."
L["Help.ItemSets.collections"] = "Use the buttons below the sidebar to create, duplicate, transfer, or compare sets. Duplicate makes an independent profile copy. Import shows the source name and can create a renamed copy or replace the selected list; Apply saves the staged result. Compare inspects differences without merging or modifying either set."
L["Legacy macro buttons"] = true
L["Help.ItemSets.macros"] = "Legacy clients may allow /click to invoke an RM item-set button separately from action-bar binding. The name is RM_ followed by the set name with non-alphanumeric characters removed, then an underscore and unit token. For a set named Bandages, an example is /click [@mouseover,nodead,help] RM_Bandages_mouseover. Other unit suffixes include player, pet, target, focus, pettarget, targettarget, focustarget, and mouseovertarget. These buttons contain item-use macro lines and do not provide the same readiness or first-item guarantee as the recommendation engine. Availability is subject to the client's secure-button and macro restrictions; reference-only support does not promise executable macro buttons."
L["Help.ItemSets.list.item"] = "Search for an item or drag it into the item field or icon. Choose the result to retain its exact item identity. The icon and name may be unavailable until metadata loads. Field clearing and save behavior belong to the editor that contains this list; use Delete when you intend to remove an entry."
L["Help.ItemSets.list.top"] = "Move this entry to the first position in the item priority list, when that control is offered."
L["Help.ItemSets.list.up"] = "Move this entry one position earlier. A move before the first entry is unavailable."
L["Help.ItemSets.list.down"] = "Move this entry one position later. A move past the final entry is unavailable."
L["Help.ItemSets.list.bottom"] = "Move this entry to the final position in the item priority list, when that control is offered."
L["Help.ItemSets.list.delete"] = "Remove this entry from the list. In a draft editor this remains pending until Apply, and Cancel discards it. Undo is available where the containing editor provides draft history."

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

L["%s {{!are|are not}} currently channeling"] = true

L["%s {{!are|are not}} currently channeling %s"] = true

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

L["%s {{!is|is not}} currently casting %s"] = true

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

L["your primary talent tree {{!is|is not}} %s"] = true

L["zone {{!is|is not}} a %s zone"] = true

L["{{!in|not in}} %s"] = true

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

L['Each callback keeps its own pending text while switching tabs. Its Apply stages the code; its Cancel restores the staged code. The callback Undo and Redo buttons edit its buffer. The main Apply saves and registers the whole condition; the main Cancel discards the whole draft. Check syntax runs no callbacks.'] = true
L['Edit fields opens a graphical schema draft. Add, name, reorder or remove fields, choose primitive or nested types, and edit nested fields. Apply stages the schema and its field order. Advanced exposes the equivalent raw schema, parsed as data without executing Lua.'] = true
