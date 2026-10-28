# Coding conventions

Read from the code as it is. When a file you edit differs from this page, match the file; when it is new, follow the page.

## Lua

**Layout.** Four-space indentation, no tabs (only `main.lua`, `Bindings.xml` and one line of `Functions/collections.lua`
still have some; do not add more). No trailing whitespace, LF endings, a final newline, UTF-8.
`tools/precommit_hygiene.py endings` and the whitespace hooks enforce this outside `Libs/`.

**Spacing and line shape.** One statement per line, spaces around operators and after commas (`local x = value`,
`a == b`, `{ key = value }`), lines wrapped at 120 columns, a blank line around every multi-line statement. No block is
written on one line: `if x then return end` is three lines. `docs/dev/formatting.md` has the whole standard and
`python3 tools/format_lua.py` applies it without changing what the file compiles to; `tools/check --static` fails a file
that is not laid out that way. The addon source, the tests and the repo's Lua tools are formatted, except the frozen Built In helper and callback bodies
(`docs/dev/architecture.md`, "Byte-pinned text"), which keep their older compact style, the premade packs under
`Modules/` and the exemptions listed in `docs/dev/formatting.md`. Match the file you edit and run the formatter on code you write.

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

**Comments.** Comments say *why*, in full sentences, above the code. Every file starts with a header (purpose, what it
owns and must not do, what loads it, the dependencies that matter); every function has a header above it: a brief line,
one `@param name type  description` line per parameter and one `@return type  description` line per returned value, then
the notes a caller must know (`docs/dev/formatting.md`, "Function headers"; `python3 tools/function_comments.py --check` enforces it with no baseline,
and is part of `tools/check --static`, so the commit hook and CI fail a function without one); files longer than about 150 lines have section headers. Comment non-obvious client behavior with the evidence (client, date, probe output). Document a trap where it will
bite (`-- /rm perf engine standard turns this off.`). No commented-out code, no change-log comments, no TODO that is not
also in an issue. LuaLS annotations (`---@type fun(f: number|function): table`) are used where the static checker needs
them; keep them valid. The exact standard, with examples, is `docs/dev/formatting.md`. The text of a Built In helper or
condition callback is hashed (`tests/private_helper_identities.lua`): never add a comment inside one.

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

## Copyright notice and licence

Rotation Master is released under a modified MIT license ("MIT + Attribution"); the only place the terms are written is
`LICENSE`. Every original source file carries one line, the first line of the file (after a shebang, or after the XML
declaration), in its own comment syntax:

```
-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
```

- Lua `-- `; Python, shell, YAML, `.pkgmeta` and TOC `# ` (a TOC comment is a line that starts with a single `#`; it sits above
  `## Interface:`); XML `<!-- ... -->` after the declaration. A Lua, Python, shell or YAML file has one blank line after it,
  before the file's own header. Do not repeat the terms in a file.
- Every TOC says `## X-License: MIT + Attribution` (the in-game About page shows the field).
- `python3 tools/copyright.py --check` (part of `tools/check --static`, so the commit hook and CI) lists the files that lack the
  notice, carry an older year or wording, or are of a kind nobody classified. `--write` adds or upgrades the notice and is
  idempotent. The years and the wording are constants at the top of the tool and nowhere else; a new year is one edit and
  `--write`.
- The tool classifies every tracked file, by path then extension: `include` with a comment syntax, or `skip` with a reason.
  Skipped: vendored code (`Libs/`, `LibsAugment/`, `tools/vendor/`, which keep their own licences), art, fonts, textures, JSON
  and prose (no comment syntax or not source), and generated files whose generator owns the first line
  (`Locales/*.lua`, the text bundles' locale tables, `Data/text_bundle_index.lua`, `Data/artwork.lua`, the generated client API
  fixtures). A new kind of file (an extension or a name no rule covers) fails with "not classified": add a rule.
- A generated file that is source-like and not skipped has its generator emit the notice (`tools/generate_builtin_sources.py`
  for `Data/builtin_sources.lua`, `tools/generate_artwork_catalog.py` for `.pkgmeta`, `tools/locales.py` for the TOC of a new
  text bundle); never hand-add the line to one.
- The notice is a comment, so the compiled program is the same: `python3 tools/bytecode_equal.py` proves it. It does move every
  line number down by two; `Data/builtin_sources.lua` records line numbers and module hashes, so regenerate it
  (`python3 tools/generate_builtin_sources.py --write`) after adding the notice to a Built In module.
- `tools/format_lua.py` keeps a leading notice as line 1 followed by one blank line.

## Git

One topic per commit, explicit paths (`git add <file>`, never `-A` or `.`), a subject that says what changed for a reader,
a body that says why. Branch per topic (`claude/<topic>`, `coord/<topic>`) in its own worktree. Never run commands that
discard changes (`reset`, `checkout --`, `restore`, `clean`, `stash`, `rebase --abort`): undo by editing. Do not push to the
default branch from a topic worktree; push the topic branch and open a pull request. No planning documents in the repository
(`docs/` describes how things are); no backup files.
