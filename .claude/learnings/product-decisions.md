# Product decisions (the maintainer's, with dates)

These were decided by the maintainer; do not reopen them without being asked, and do not quietly work around them.

## Scope

- **No inventory counting or restocking** (2026-10-23): other addons do that. Item sets only make one
  button that uses the first available item in order. The "Stock" feature was removed; do not reintroduce inventory monitoring.
- **No RM-to-RM signals** (addon messages between players): Retail and Forever refuse addon sends in boss encounters, M+ and PvP
  and hide mob identity in instances, so the use cases die where they matter. Scrapped.
- **No language picker**: the addon uses the client's language.
- **Integrations** that do nothing for a client are dropped for that client. Tooltips are on by default with a master switch.

## Selection and eligibility

- **No switch condition means the rotation matches.** A rotation with no switch is auto-selectable; users can disable it. There
  is no "manual-only" concept and no separate "Automatic selection" setting.
- **Spec is a rotation property**: `body.specs` (empty means any) gates listing, manual and automatic selection; the switch is
  not consulted for the minimap and manual list. Level stays in the switch. On a client capable of dual spec the spec is an
  account-local *slot*: exports strip `specs` and imports insert the importer's slot; portable spec ids (Mists and later,
  Retail) export as they are.
- **Priority**: higher is tried first; Built In and custom compete equally (no "custom first" tier); Default is the last resort.
  Rotations whose switches overlap are marked so priority (or a tie) is the only differentiator.
- **Built In defaults**: a missing preference means the shipped default. Writing `enabled=false` the user never chose made a
  premade vanish once; only an explicit user action writes a preference.
- **One enabled premade per specialization**: every lower same-spec alternative ships disabled ("an alternative to the
  recommended X premade, off by default..."), the recommended one stays enabled at the highest priority. Deliberate layering
  (level-1 catch-alls, Era under SoD, Retail initial specs) is not an alternative.
- **Skip what cannot be highlighted**: a step or cooldown whose action is on no action bar is skipped like a not-ready step and
  its card warns, amber, "Not on your action bars, so it can't be highlighted."
- **`suppress_attack`** suppresses Attack, Shoot and Auto Shot, even where caster premades use it to stay out of melee (then it
  also hides the wand at range). Keep it.
- **Rotation handles** are called *Identifier* (`body.identifier`, short *ID*): `^[A-Za-z][A-Za-z0-9_-]*$`, case-insensitive, for
  `/rm set <identifier>`. Built Ins derive theirs from the pack id minus `rm.<edition>.<class>.`; custom ones are editable and
  auto-slugged from the name.

## Editor and UI

- **Anything that stops a rotation from being selected must be visible up the tree**: a red border on the Rotation and Cooldowns
  headers and on the rotation's list entry; refusal messages say WHY (which condition or step).
- **Vertical space is at a premium**: no rows of explanatory text for things that are implied; use pills, color and tooltips. A
  Built In view shows a blue "Read-Only" pill in place of Undo/Redo.
- **Show a local override by coloring the VALUE amber**, never the label or border; do not reword a label for an override
  ("Priority", not "Your priority"). Applicability notes never list specializations; only a minimum level ("level 10+").
- **Live match indicator**: a thin green/red (grey = unavailable) bar on the LEFT edge of each condition field, tooltip starting
  "Currently Matches" / "Does Not Currently Match" on its own line, only while the editor is open.
- **Preview window**: no title bar, no close button; it shows iff Preview Spells is greater than 0 (0 turns it off); drag the
  body to move it when unlocked.
- **Terminology**: Identifier, Built In, Priority, Switch, Stop, Branch. American spelling.

## Premade rules

One premade per role from level 1 to the cap, no level brackets; Stop and Branch instead of repeated conditions; short switches,
cheapest check first; separate per edition; separate per-source variants where sources materially differ (recommended variant
at the highest priority). No Branch whose outermost condition is NOT: drop the outer NOT and use the false arm. No consecutive
Stops that could be one Stop with OR; no consecutive Branches with the same arms (`tests/premade_style.lua`). Only Retail and
Mists premades declare `body.specs`; elsewhere a "specialization" value is a talent group a premade cannot know.
`Modules/README.md` is the long form.
