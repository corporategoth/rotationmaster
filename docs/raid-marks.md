# Raid marks

Rotation Master can follow raid target markers (skull, cross, square, moon, triangle, diamond, circle, star) and can
recommend placing one. There are four parts: the mark table, the mark unit types, two conditions and the Set Mark step.
`/rm debug marks` reports all of them in game. Nothing here has been run in a real client yet; the in-game test script
is at the end.

## What the game gives an addon

- `GetRaidTargetIndex(unit)` answers for a unit token you already hold (`target`, `raid7target`, `nameplate3` ...): 1
  star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull, nothing for no mark.
- There is no unit token for a mark and no call that says which unit holds a mark.
- `RAID_TARGET_UPDATE` fires with no payload when any mark changes.
- `UnitTokenFromGUID(guid)` turns a GUID back into a token where the client has it.
- Retail and Forever hide some data in combat. `GetRaidTargetIndex` and an NPC's GUID may come back secret there
  (`docs/restricted-clients.md`); every read goes through `platform:CanReadValue`, and an unreadable answer is
  unavailable with a reason, never a guess.

## The mark table (`Platform/raid_marks.lua`)

An event-driven table with one record per mark: `held`, `guid`, `token` (the token that holds the mark now, nil while
the unit is out of reach), `lastToken`, `reachable`, `seen` (when it was last verified) and `enemy` / `friend` (read
once when the unit is found). Nothing is scanned per poll.

- **Rescan** on `RAID_TARGET_UPDATE`, `GROUP_ROSTER_UPDATE`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT` and
  `ARENA_OPPONENT_UPDATE`: read every token the client can reach once, in this order, and keep the first token seen
  carrying each mark: `player`, `target`, `focus`, `mouseover`, `softenemy`, `softfriend`, `pet`, the raid
  (`raid1` to `raid40` and their targets) or the party (`party1` to `party4` and their targets), `boss1` to `boss8`,
  `arena1` to `arena5`, `nameplate1` to `nameplate40`. A token class is read only when the event that tells the table
  about it exists on the client.
- **One token** is re-read when it changes: `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UPDATE_MOUSEOVER_UNIT`,
  the soft target events, `NAME_PLATE_UNIT_ADDED` / `REMOVED`, and `UNIT_TARGET` for a raid, party or boss unit. A
  record bound to that token that no longer holds its mark is relocated.
- **Relocation.** A record whose token stops holding the mark is looked up by GUID with `UnitTokenFromGUID` where the
  client has it. If the unit is in reach and carries another mark or none, the record is dropped (the mark is gone). If
  the unit is not in reach, the record stays, flagged `reachable = false`, with its last token, and still counts.
  Without `UnitTokenFromGUID` an out-of-reach record stays until a scanned token shows the mark again.
- **One unit, one mark.** Recording a mark for a unit drops another record with the same GUID, and un-binds another
  record from the same token.
- **Loading screens.** `PLAYER_ENTERING_WORLD` clears the table and rescans, so an out-of-reach record cannot outlive
  the area. This is the only way an out-of-reach record ends without a token showing it gone; a unit that dies
  out of reach keeps its record until then. This is a known limit, not a guess.
- **Unreadable GUIDs.** When a GUID is secret the record has no GUID: it is held by its token only, and out of reach
  once the token moves on.
- **Lazy.** Nothing is registered at load. The first question (resolving a mark unit type, `MARK_COUNT`, or
  `/rm debug marks`; `MARKED` reads its one unit directly and does not start the watch) creates the frame, registers
  the events the client has (the event catalog
  `C_EventUtils.IsEventValid` is asked when it exists, and a registration that throws is skipped) and rescans. Every
  question renews a 30 second lease. When the lease has run out, the next event or a `C_Timer.After` check unregisters
  everything and clears the table. A client that cannot make a frame or register an event answers `missing-api` and is
  not asked again for five seconds.
- A change to the table sets `addon.idleGate.dirty`, so an idle out-of-combat tick evaluates.

## Capabilities

Detected from the client, never from its name: `GetRaidTargetIndex` (read marks; the unit types and conditions are
offered only with it), `SetRaidTarget` or a `TARGET_MARKER` entry in `SecureCmdList` / `SlashCmdList` (the Set Mark
step), `UnitTokenFromGUID`, and each event (`C_EventUtils.IsEventValid`). Names are read through the file environment
(`getfenv(1)`, as `Platform/focus_unit.lua` does), so the generated client manifests make no claim about which client
has what. `/rm debug marks` prints the answers.

## Mark unit types (`Core/raid_mark_units.lua`)

`skull cross square moon triangle diamond circle star` and `anymark`, registered next to the group unit types
([unit-types.md](unit-types.md)) and resolved by `Platform:ResolveGroupUnit` into the token that carries the mark right
now, so every unit-based condition (in range, casting, health, auras ...) works on them. The stored token is verified
with one `GetRaidTargetIndex` read on each resolution.

`anymark` is the highest-priority marked unit: skull, cross, square, moon, triangle, diamond, circle, star, the first
with a reachable unit. A marked unit that is out of reach is skipped for the next mark. When none is reachable, the
answer carries the reason of the highest-priority mark the table knows. "Any marked unit satisfies" is not offered: the
engine hands a condition one resolved token, so the reading would need a second evaluation path. OR the eight specific
mark units for it, or use `MARKED` / `MARK_COUNT`.

Reasons when no token is answered: `no-marked-unit` (no unit is known to carry it), `no-token` (known but out of reach),
`unreadable` (a read was hidden), `missing-api`, `unsupported-policy`.

## Conditions (`Conditions/raid_marks.lua`)

- `MARKED` (`unit`, `mark`): `mark` is `any`, `none`, or a comma-separated list of mark names in skull-first order
  (`skull,moon`); a single name is the one-mark case. It reads the unit directly with `Platform:GetUnitRaidMark` and
  does not use the table. A unit that does not exist is false for every value. A hidden mark or existence is
  unavailable (`restricted-value`), also under NOT. The editor has a choice (any, none, one of these) and eight
  checkboxes that are live only for the third.
- `MARK_COUNT` (`filter` any / enemy / friendly, `operator`, `value`): the number of marked units the table knows,
  out-of-reach records included. Unavailable when the last scan could not read a token (`unreadable`) or, with a filter,
  when a marked unit's hostility is unknown.

Both borrow a related condition's icon until artwork of their own is generated (`MARKED` the Unit Classification skull,
`MARK_COUNT` the Distance Count studs); `tests/condition_icons.lua` lists them.

## The Set Mark step

Step type `mark`, rotation list only. Fields: `unit` (one of `player target focus mouseover pet targettarget
focustarget`; the focus tokens only where the client has a focus target) and `action` (`skull cross square moon
triangle diamond circle star`, or `none` to clear). It is a recommendation: Rotation Master lights an action bar
button; the player presses it. It is offered in the step type menu only where the client has the target marker command
or `SetRaidTarget`; an imported step on a client without them is kept and flagged unresolved
(`unsupported-mark-step`), never dropped.

**The macro.** The command is `/tm [@unit] N` (`TARGET_MARKER`; `N` 1 to 8, `0` clears). The syntax is from memory of
Blizzard's `SecureCmdList["TARGET_MARKER"]` and the common `/tm [@mouseover] 8` macro; it was not checked against
Blizzard's source in this tree and is part of the in-game test.

**The hidden button** `RM_Mark_<unit>_<mark>` (for example `RM_Mark_target_skull`, `RM_Mark_focus_none`) is a
`SecureActionButtonTemplate` button of type `macro` whose `macrotext` is that one line. It is made in
`Core/raid_mark_buttons.lua`, out of combat only, the first time a Set Mark step is evaluated (or bound). This is the
second place Rotation Master writes secure text, after `Core/itemset_services.lua`, with a stricter rule: the text is
built by `Platform:GetMarkMacroText` from the whitelist tables in `Platform/raid_mark_actions.lua`. A saved or imported
`unit` or `action` is only ever a lookup key into those tables; when it is not a key, nothing is built. A global of the
same name that is not ours is never reused. `tests/raid_mark_step.lua` feeds hostile values (macro syntax, newlines,
control characters, brackets, escapes, near misses, wrong types) through every path and checks every attribute write
against the template.

**Bind** (the "Put on an action bar" button on the card) makes the character macro `RM <mark>/<unit code>` with the
body `/click RM_Mark_<unit>_<mark>` if it does not exist, and picks it up. The player drops it on a slot. A macro of
the player's own that contains the same `/click` line works the same.

**Finding it on the bars.** The bar index maps an action button to a spell id. A Set Mark step stands for a pseudo spell
id (`1073741824 + 16 * unit + mark`, far above any real spell id) and `Platform:GetMacroAction` answers that id for a
macro whose body has a `/click RM_Mark_...` line naming a whitelisted button. Macro bodies are read only after a Set Mark
step has been evaluated or bound once (`Platform:SetMarkActionTracking`), so a player who never uses the step pays
nothing. The id also gives the preview window and reports a name and the raid target icon
(`Platform:GetSpellInfo` answers it first). The same-name button lookup that Retail and Forever use for spells skips
pseudo ids, so the step for the skull on your target never takes the button for the skull on your focus.

**Ready.** The step is advisable while the unit exists, does not already carry the mark (or, for `none`, carries one),
and you may place marks: anyone in a party or alone, only the leader and assistants in a raid. A client that cannot
answer the raid question is given the benefit of the doubt; an unreadable unit or mark is not ready.

## `/rm debug marks`

Prints, read only: what the client offers (functions, event catalog), the table (mark, GUID, token, reachable, seconds
since seen, enemy, friendly), what each mark unit resolves to, whether the unit pickers offer them, the state of the Set
Mark step, and whether you may place marks. It starts the watch for the usual lease so the table is current, and
changes nothing else.

## Restricted clients

See the rows in `docs/restricted-clients.md`. On Retail and Forever `GetRaidTargetIndex` was documented as secret in an
earlier survey; the code reads it through `CanReadValue` and everything that depends on it becomes unavailable, not
false. The Set Mark step never reads a mark through the table and its macro does not depend on any read, so placing
marks does not need readable data; only the "already marked" check does, and an unreadable mark means the step is not
advised.

## Known limits

- Unverified in game: the `/tm` syntax, the events and `UnitTokenFromGUID` on each client, `GetMacroBody` and the bar
  macro recognition on Retail, and whether the data is secret there.
- An out-of-reach record cannot see its mark removed; it ends on a loading screen or when the unit comes back in reach.
- `MARK_COUNT` counts what the table knows, so a marked unit nobody can reach and nobody saw leave still counts.
- `UNIT_TARGET` fires for every unit in the world while the watch runs; the handler returns at once for any unit that is
  not a raid, party or boss unit, but the event is delivered. The watch runs only while marks are in use.
- The count and the unit types cover the tokens listed above; a marked unit seen only as someone's pet's target is not.

## Text and translations

The 43 strings of this feature have stable translation IDs (4045-4087) and all ten languages. The mark unit names, the
Set Mark step and its editor strings are in the main catalog (`Locales/`); the condition wording, the mark and filter
choices and the `MARKED` / `MARK_COUNT` help are in the condition text bundle
(`Modules/RotationMaster_ConditionText/`); the Set Mark help is in the help text bundle
(`Modules/RotationMaster_HelpText/`). Strings with format tokens carry translator notes saying what each `%s` receives
(`python3 tools/locales.py where "Set %s on %s"` shows a string, its notes and where the code reads it). A mark name
itself is never translated by the addon: it is the game's own `RAID_TARGET_n` global string, with the English name only
as the fallback when the client has none.

## Checking it in game

Run these on the client in question; each line says what a pass looks like. Nothing here is verified yet.

**TBC Anniversary (or any Classic client).** Alone or in a party, out of combat, with a target dummy or any mob.

1. `/rm debug marks` with no mark in play. Expect `Reading marks: available`; `Functions:` lists `GetRaidTargetIndex=yes`,
   `SetRaidTarget=yes` and `target marker command=yes`, and says whether `UnitTokenFromGUID` exists there; `Watching: yes`
   with the events the client has; every table row `-`; every mark unit `unavailable (no-marked-unit)`.
2. Target a mob and type `/tm 8`, then `/rm debug marks`. Expect the skull row to show a GUID, `target`, `reachable`,
   a small age, and `skull -> target`, `anymark -> target`. Type `/tm 0`: the skull row empties again.
3. Mark two units, then change target. The marked unit you left stays in the table as `NOT reachable` with
   `last target`, the mark unit shows `unavailable (no-token)` (or a new token, if it is on a nameplate or in your
   group's targets), and a condition on `skull` that needs the unit is unavailable.
4. Build a rotation with a Set Mark step (Set Mark, your target, Skull) above a spell step, and put the macro on a bar
   with Put on an action bar. Target an unmarked mob: the macro's slot lights. Press it: the mark appears and the
   glow moves on. In a raid without leader or assistant rights the slot stays dark; in a party it lights.
5. `/rm debug marks` ends with `Set Mark step: available; hidden buttons made 1` (more if you used more steps), and
   `macros on the bars recognized: yes`.

**Retail.** The same steps. The mark may read as hidden: then the table rows stay `-`, `Watching:` shows a count of
`unreadable reads`, every mark unit is `unavailable (unreadable)`, `MARKED` and `MARK_COUNT` are unavailable, and the Set
Mark step is not advised (it cannot tell whether the unit already carries the mark) although the macro still works if
you press it. If the mark reads (for group members, or everything), the output matches the Classic one. Either answer
is the finding; please copy the whole report.

## Known open questions

These are answered by the report above: whether `/tm [@unit] N` is the right syntax on each client, which events and
`UnitTokenFromGUID` exist where, whether `GetMacroBody` and the bar macro recognition work on Retail, and whether the
mark is secret there.
