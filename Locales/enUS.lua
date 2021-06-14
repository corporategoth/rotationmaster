local L = LibStub("AceLocale-3.0"):NewLocale("RotationMaster", "enUS", true)
if not L then return end

local color = color

-- from main.lua

L["/rm help                - This text"] = true
L["/rm config              - Open the config dialog"] = true
L["/rm disable             - Disable battle rotation"] = true
L["/rm enable              - Enable battle rotation"] = true
L["/rm toggle              - Toggle between enabled and disabled"] = true
L["/rm current             - Print out the name of the current rotation"] = true
L["/rm set [auto|profile]  - Switch to a specific rotation, or use automatic switching again."] = true
L["                          This is reset upon switching specializations."] = true

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

L["[Tier: %d, Column: %d]"] = true
L["Autoswitch rotation list has been updated."] = true

L["Button Fetch triggered."] = true
L["Notified configuration to update it's status."] = true
L["Removing all glows."] = true
L["Active rotation is incomplete and may not work correctly!"] = true
L["Cache hit rate at %.02f%%"] = true

-- from constants.lua

L["Spells / Items"] = true
L["Buffs"] = true
L["Combat"] = true
L["Other"] = true
L["Custom"] = true

L["Bind"] = true
L["Unbind"] = true

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
L["This is specifically how often the configuration pane will receive updates about live status.  Too frequently could make your configuration pane unusable.  0 = Disabled."] = true
L["Are you sure you wish to delete this rotation?"] = true
L["This item set is in use, are you sure you wish to delete it?"] = true
L["Import/Export Rotation"] = true
L["Import/Export Item Set"] = true
L["Copy and paste this text share your profile with others, or import someone else's."] = true
L["bytes"] = true
L["lines"] = true
L["Parse Error"] = true
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
L["Rotations"] = true
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
L["Action Type"] = true
L["Spell"] = true
L["Rank"] = true
L["Pet Spell"] = true
L["Item"] = true
L["Conditions"] = true
L["THIS CONDITION DOES NOT VALIDATE"] = true
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
L["<talent>"] = true
L["<talent tree>"] = true
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

L["Unit"] = true
L["Role"] = true
L["Class"] = true
L["Is Same As"] = true
L["Creature Type"] = true
L["Talent"] = true
L["Talent Tree"] = true
L["Operator"] = true
L["Count"] = true
L["Quantity"] = true
L["Distance"] = true
L["Distance Count"] = true
L["yards"] = true

L["Health"] = true
L["%s health"] = true
L["Health Percentage"] = true

L["Mana"] = true
L["%s mana"] = true
L["Mana Percentage"] = true

L["Power"] = true
L["%s power"] = true
L["Power Percentage"] = true

L["Points"] = true
L["%s points"] = true

L["Spell Available"] = true
L["%s is available"] = true
L["Spell In Range"] = true
L["%s is in range"] = true
L["Spell Cooldown"] = true
-- This is used for things like "the cooldown on <spell> is less than 5 seconds"
L["the %s"] = true
L["cooldown on %s"] = true
L["%s seconds"] = true
L["Seconds"] = true
L["Spell Active or Pending"] = true
L["%s is active or pending"] = true

L["Spell Time Remaining"] = true
L["remaining time on %s"] = true
L["Spell Charges"] = true
L["number of charges on %s"] = true
L["Charges"] = true

L["Spell Cast History Time"] = true
L["Spell Cast History"] = true
L["%s was cast"] = true
L["%s casts ago"] = true
L["%s seconds ago"] = true
L["Combat Action History Time"] = true
L["Combat Action History"] = true
L["%s actions ago"] = true

L["Pet Spell Available"] = true
L["Pet Spell In Range"] = true
L["Pet Spell Cooldown"] = true
L["Pet Spell Time Remaining"] = true
L["Pet Spell Charges"] = true

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
L["Has Dispellable Debuff"] = true
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
L["%s is an enemy"] = true
L["%s is attackable"] = true
L["number of party or raid members within %d yards"] = true
L["number of enemies you are at least %s"] = true
L["closer than %s yards"] = true
L["allies"] = true
L["enemies"] = true
L["Number of %s within %s yards"] = true
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
