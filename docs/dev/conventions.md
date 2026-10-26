# Coding conventions

Read from the code as it is. When a file you edit differs from this page, match the file; when it is new, follow the page.

## Lua

**Layout.** Four-space indentation, no tabs (only `buttons.lua`, `main.lua` and a few legacy files still have some; do not
add more). No trailing whitespace, LF endings, a final newline, UTF-8. `tools/precommit_hygiene.py endings` and the
whitespace hooks enforce this outside `Libs/`.

**Spacing.** New and heavily edited code is compact: `local x=value`, `a==b`, `if x then return y end` on one line when it
reads as a sentence. The older `Conditions/` and root files use spaced style (`local x = value`). Do not reformat a file
to change its style: the byte-freeze suites (`docs/dev/architecture.md`, "Tests") hash many files, so a whitespace-only
diff can break them.

**File header.** `local addon_name,addon=...` (or `local _,addon=...` when the name is not needed), then
`local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)` where text is shown. Platform files start
`local platform=addon.Platform`. Every file registers into `addon`; the only new globals are the fixed ones the design
allows (for example `RotationMasterBuiltIns`). Capture an `addon.X` you depend on into a local at load.

**Naming.**

| Thing | Style | Example |
| --- | --- | --- |
| Methods on `addon` and `platform` | PascalCase verbs | `addon:GetRotationName`, `platform:GetUnitHealthObservation` |
| Local functions and variables | camelCase | `observeActionContext`, `readExecutionGeneration` |
| Condition tags | UPPER_SNAKE | `SPELL_KNOWN`, `HEALTHPCT` |
| Constants | UPPER_SNAKE | `LEAN_MAX_AGE` |
| Reason codes (second return of `nil, reason`) | lower kebab | `'restricted-value'`, `'missing-api'`, `'unit-data-unavailable'` |
| Source files | lower snake, grouped by folder | `Core/rotation_scope.lua`, `Platform/unit_health.lua` |
| Suites | name the area; variants add a suffix | `tests/rotation_scope_core.lua`, `tests/defaults_tbc_mage.lua` |
| Rotation ids | `rm.<edition>.<class>.<name>`; identifier `^[A-Za-z][A-Za-z0-9_-]*$` | `rm.tbc.mage.fire.icyveins` |

**Game API access.** Only `Platform/` talks to Blizzard. A reader checks that the function exists, calls it under `pcall`,
passes the result through `platform:CanReadValue` before comparing it, validates its type, and returns the value or
`nil, reason`. Never compare, do arithmetic on or index by a value from a restricted API without that check.
Feature-detect namespaced and legacy functions (`C_Spell.GetSpellInfo` / `GetSpellInfo`); do not branch on the client
version for something the client can tell you.

**Errors.** A poll must not throw. Wrap what can throw in `pcall` or the diagnostics boundary (`addon.Diagnostics`), return
`nil, reason` for what cannot be read, and let the caller decide. Do not swallow an error silently when the player could
act on it: print one message (`addon:warn(L["..."], ...)`).

**Comments.** Comments say *why*, in full sentences, above the code. State the contract at the top of a module: what it
owns, what it must not do, what loads before it. Comment non-obvious client behavior with the evidence (client, date, probe
output). Document a trap where it will bite (`-- /rm perf engine standard turns this off.`). No commented-out code, no
change-log comments, no TODO that is not also in an issue. LuaLS annotations (`---@type fun(f: number|function): table`)
are used where the static checker needs them; keep them valid.

**Text.** User-facing text is American English (color, behavior, gray, -ize) and goes through `L["literal"]`. The key is the
English; do not build keys by concatenation (the tools find literal keys only). No sentence assembled from fragments.
Placeholders are `%s`/`%d` (positional order must survive translation, so avoid two of the same kind in one string when you
can) or `{{name}}`. Terminology: *Identifier* (never Handle), *Built In*, *Priority*, *Switch*, *Stop*, *Branch*.

**Performance.** No allocation in a path that runs every poll: reuse tables, avoid closures and string building, cache per
evaluation pass (the `cache` argument), invalidate on events. Measure with `/rm perf` before and after a change that claims
to help.

**Saved data.** A new field has a default, survives an older release ignoring it, and is migrated by an `upgrade*()` pass in
`init.lua` if it replaces something. A missing user preference means the shipped default; only an explicit user action
writes one.

## Tests

A suite starts `local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()` and ends `finish()`. A test is
`test('sentence stating the behavior',function() ... end)` using plain `assert(cond,'what failed')`. Fixtures model the
client, including what it does *not* have. Assert the exact result, not "something happened". A suite that must run on both
interpreters must pass on both. Add the suite to the right list in `tools/check` (the `lua5.1` and `luajit` lines).

## Python tools

Standard library only, four spaces, single quotes, a module docstring that is the `--help` text with examples,
`ROOT = Path(__file__).resolve().parents[1]`, `argparse`, exit status 0/1 (2 for "could not run"). A tool that changes files
has a check mode that does not (`--check`, or no flag); a generator writes only with `--write`. Tools never download except
`tools/setup_lint.py`, which verifies a pinned checksum.

## Git

One topic per commit, explicit paths (`git add <file>`, never `-A` or `.`), a subject that says what changed for a reader,
a body that says why. Branch per topic (`claude/<topic>`, `coord/<topic>`) in its own worktree. Never run commands that
discard changes (`reset`, `checkout --`, `restore`, `clean`, `stash`, `rebase --abort`): undo by editing. Do not push to the
default branch from a topic worktree; push the topic branch and open a pull request. No planning documents in the repository
(`docs/` describes how things are); no backup files.
