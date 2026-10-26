# WowSims transport

[WowSims](https://www.wowsims.com/) is the community simulator for World of Warcraft Classic. A WowSims rotation is an Action Priority List (APL): an ordered list of actions with conditions, written as proto-JSON. Rotation Master converts to and from it, so a rotation can go from the simulator to the game and back. The Rotation Master website converts the same way, from the same rule table; this document is the in-game half.

## What the player sees

The rotation Import/Export window (`UI/transfer.lua`) has a **Format** choice under the scope row: **Rotation Master** (the default) or **WowSims**. The choice is remembered in the profile (`profile.transfer_format`, `rm` or `wowsims`; `Core/profile_data.lua` validates it). Only rotation transfers have it: item sets, announcements, effects, profiles, condition categories, custom conditions and function bundles have no WowSims form and show no such choice.

- **Export.** With WowSims chosen the box shows the rotation as pretty-printed WowSims JSON (the simulator's settings format with only the rotation in it, `{"player": {"class": "ClassShaman", "rotation": {...}}}`), in the same monospace face as the Base64, and without the 76-column wrapping, which is for Base64 only. The line under the Format row reads "Some detail may be lost converting to WowSims." and **Check export** lists what became of every step (the report window, `addon:ShowTransferReport`). Copy copies the JSON. Choosing a format while the box still holds the export it produced rewrites the box in the new format; text you pasted stays as it is.
- **Import.** With WowSims chosen, pasted JSON is converted first, then the usual **Preview import** / **Compare import** / **Check import** run on the converted rotation (an ordinary rotation body, `kind = "legacy"`). The line under the Format row reads "Some detail may be lost converting from WowSims." The status line adds the counts ("Converted from WowSims: 22 steps, 3 disabled"); **Check import** shows the conversion report (every item: its grade, what became of it, why) followed by the usual check of the converted rotation. Import is gated exactly as before: the converted rotation goes through `RotationData.ValidateBody` with the game's real condition schemas and `GetConditionSupport`, so an invalid, unsupported or unresolved rotation keeps Import off.
- **What it accepts.** The simulator's settings export (`player.rotation`), an `.apl.json` preset, a saved rotation, the in-game WoWSims Exporter's JSON with a `rotation`, and the base64 of any of them. A share link (`wowsims.com/...#...`) holds a compressed binary form and is refused with what to do instead. `TypeAuto`, `TypeLegacy` and a settings export with no APL say: "This export contains no rotation to import. In WowSims, open the Rotation tab, choose an APL (or a preset), then export again." `TypeSimple` says it is a Simple rotation. Rotation Master text pasted with WowSims chosen (and WowSims JSON with Rotation Master chosen) says which format to choose.
- **Edition and class come from the client.** The edition is the client's (Classic Era, TBC, Wrath/Cataclysm/Mists as one, Forever); the class is the character's. A file for another class, or one that cannot be for this edition (spell ranks on Wrath, groups of actions on Era, another edition's spells), is refused with the reason. A different specialization is fine and is recorded in the report. Retail has no simulator: the Format menu is disabled there, a remembered WowSims is read as Rotation Master, and the tooltip says "WowSims has no simulator for this game version, so only the Rotation Master format is available here."

## Fidelity vocabulary

Every item of the source gets a grade and an outcome, and every reason is reported, never dropped silently.

| Grade | Importing from WowSims | Exporting to WowSims |
| --- | --- | --- |
| exact | the same behavior; imported enabled | written as the same behavior |
| approximate | a close substitute (for example the number of targets becomes the number of enemies you have threat on); imported **disabled** unless the conversion was asked to keep approximate steps | a close substitute (for example the Cooldowns list, placed first) |
| lossy | a part was left out (a sequence becomes separate steps, an unknown condition is dropped); imported **disabled** | a condition with no equivalent is left out of its AND, so the step does not check it |
| unsupported | nothing to import (waiting, switching targets, simulator-only actions); listed, not imported | the step is not exported (a pet step, an item set by name) |

The policy table is `policy` in the rule table: `exact` enables, `approximate` and `lossy` disable, an unknown id is flagged and stays enabled, an id that belongs to another class's list disables. A pre-pull action becomes a step that applies only out of combat; the seconds are dropped, which is lossy but benign (the step stays enabled because its condition keeps it out of the fight). A condition the client hides from addons (mana, other power bars and health on Forever and Retail, the combat log on both) is left out, its step is imported **disabled**, and the report names what the game hides (`cond-restricted`, from `Core/condition_support.lua`).

## How spell and item ids are checked

The report names the sources that confirmed each id: **the game client** (`Platform:GetSpellInfo` for spells, `GetItemInfoInstant` for items: the id exists in this client's data) and **WowSims simulator data** (the spell ids each simulator's source names, per class, per edition, from the simulators' repositories, MIT). A spell that appears only in another class's simulator list is taken to be another class's and its step is imported disabled; the client knowing the spell does not override that. An id nothing confirms is flagged and the step stays enabled, unless the player asked for unconfirmed ids to disable. The website additionally checks the ids against Rotation Master's Built In rotations and, in the browser, against Wowhead; the game does not need either, the client being the authority on its own ids. Item ids are not shipped (they are about 66,000); the client confirms those.

## Where the code and data are

| Piece | Where |
| --- | --- |
| Format registry, availability per client, remembered choice, loading the converter, glue to the game (condition support, client id checks, names) | `Core/transfer_formats.lua` (loaded at login, small, knows no APL) |
| The Format row, the per-window conversion state, the report window | `UI/transfer.lua`, `UI/transfer_format.lua` |
| The converters and their data | the **load-on-demand add-on** `Modules/RotationMaster_WowSims` (own TOC, `LoadOnDemand: 1`, `Dependencies: RotationMaster`; the release zip ships it as a top-level AddOns folder like the Built In modules) |
| Bounded JSON reader and deterministic encoder | `Modules/RotationMaster_WowSims/json.lua` |
| WowSims -> Rotation Master | `.../import.lua`, a line-by-line Lua port of the website's `wowsims/import.mjs` |
| Rotation Master -> WowSims | `.../export.lua`, a port of `wowsims/export.mjs` |
| The rule table and the simulators' APL kinds | `.../mapping.lua` (generated) |
| Spell ids per edition and source, rank ladders, mana potions | `.../ids.lua` (generated, decoded on use, released after each conversion) |
| The words of the reports and failures | `.../render.lua` (every English text is a key of `Locales/enUS.lua`, translated in the other ten locales) |
| The pinned source data | `Data/wowsims/` (`mapping.json`, `kinds.json`, `ids.json`, `SOURCE.json`, the simulators' MIT notice) |

The converter is **not part of the add-on until it is wanted**: `RotationMaster.toc` lists nothing of it, the first thing that loads it is opening a transfer window with WowSims remembered, or choosing WowSims in one (`C_AddOns.LoadAddOn("RotationMaster_WowSims")`). Loaded, it holds about 0.6 MB; a conversion decodes the id lists it needs and releases them. Nothing of it runs on the poll path (the bench is unchanged), registers events, or has an OnUpdate. If the add-on cannot be loaded (a development install without its link, a disabled add-on) the window falls back to Rotation Master and says why; everything else keeps working.

A development install (a checkout linked into `Interface/AddOns`) needs one more link: `Interface/AddOns/RotationMaster_WowSims -> <checkout>/Modules/RotationMaster_WowSims`, as for the Built In modules.

## The mapping is the website's, pinned

`mapping.json` is the declarative rule table (value kinds, actions, units, tables, limits, policy, and the whole export direction); the Lua converters interpret it exactly as the website's do, so both sides stay in step. The addon carries a **pinned copy** under `Data/wowsims/` and generates the Lua data from it:

```sh
python3 tools/export_wowsims_mapping.py            # write Modules/RotationMaster_WowSims/mapping.lua and ids.lua
python3 tools/export_wowsims_mapping.py --check    # fail when the Lua, the pinned JSON or SOURCE.json disagree
python3 tools/export_wowsims_mapping.py --refresh <website checkout>
```

`tools/check` runs `--check`, so the Lua data cannot drift from the pinned JSON. `SOURCE.json` records the website commit the copies were taken at, the hash of every website file that was read, and the hash of each pinned copy. **To refresh** after the website's mapping or id lists change: commit the website's change, run `--refresh` with its checkout, review the diff (the rule table is data; a changed rule shows up in the golden tests), run `python3 tools/check`, and commit the pinned JSON, the generated Lua and the updated fixtures together (below). If the website's converters change in code (not only data), port the change to `import.lua` / `export.lua`: the golden tests fail until both agree.

`ids.json` is reduced from the website's per-edition id lists: spell ids per class and source, rank ladders, mana potions. Item ids are left out (see above). Its Lua form writes each sorted id list as `first,delta,delta,...`.

## Tests

- `tests/wowsims_golden.lua`, the drift guard: the Lua converters against the website's golden outputs for 22 real presets (Classic Era and Season of Discovery, TBC, Wrath, Cataclysm, Mists, Forever) and the two real exports a player made on wowsims.com: the same step counts, the same grade and outcome for every item, the same reason codes, the same conditions; the export of 9 real Built In rotations to the same APL; the round trip. The website's verifier data is narrowed to the ids the fixtures mention and the condition-support check is the game's own `Core/condition_support.lua` on a simulated client of each edition (so Forever's hidden mana and health are exercised for real).
- `tests/wowsims_module.lua`: hostile and malformed text, limits, the messages for text with no rotation, class and edition checks, how an id is verified, export of branches, Stops, cooldowns, pre-pull, ranks and potions, the id data against its pinned JSON, and that every word a report can show is in the English locale and in the other ten.
- `tests/wowsims_transfer_ui.lua`: the window: the Format row only for rotations, the warning per mode, the remembered choice, Preview / Compare / Check after conversion with nothing mutated, hostile text, mismatches, every client with a simulator, Retail's tooltip, a converter that cannot load, and that nothing is loaded until it is wanted.
- `tests/wowsims_real_catalog.lua`: the real TBC condition catalog and Built In packs: converted rotations are valid, supported and resolved by the real validators; every Built In of the class exports and imports back; the add-on's own Enhancement Built In exports to exactly the APL the website makes of it.

The fixtures (`tests/fixtures/wowsims/`, a subset of the website's, with `SOURCES.json` saying where each file came from, and the simulators' MIT notice) come from `tools/wowsims_test_data.py <website checkout>`.

## What is not verified here

No real client has run this. The conversion, the data and the window are tested against the website's outputs, the real condition catalog and window fixtures; what the game's API returns for an id (`GetSpellInfo`, `GetItemInfoInstant`) on each client, how the new row lays out in the real frame, and that the load-on-demand add-on loads from a release zip are for a check in game. Merging with the data of the in-game WoWSims Exporter add-on for the same specialization is out of scope here.
