# Architecture map

This is how the addon is put together today. It points at the code and at the topic documents in `docs/architecture/`
and `docs/quality/`; those go deeper than this page.

## What it is

Rotation Master (RM) advises the next spell or item and lights the matching action-bar button. A *rotation* is an
ordered list of *steps* (actions, Branches, Stops), each with *conditions*; a rotation's *switch* decides when it is
selected automatically. Rotations are either **Built In** (premades shipped in the load-on-demand modules, read-only,
clonable) or **custom** (stored in the saved variables).

### Supported clients

The main TOC declares one Interface number per client; `tools/package_release.py` (`SUPPORTED_CLIENTS`) checks the
packaged TOC against the same list.

| Interface | Client | `family` (`Platform/client.lua`) |
| --- | --- | --- |
| 11509 | Classic Era 1.15.9 (also Season of Discovery, Hardcore, Self-Found) | `era` |
| 20506 | TBC Anniversary 2.5.6 | `tbc` |
| 30405 | Wrath of the Lich King Classic 3.4.5 | `progression` |
| 38002 | Wrath Titan Reforged 3.80.2 | `progression` |
| 40402 | Cataclysm Classic 4.4.2 | `progression` |
| 50504 | Mists of Pandaria Classic 5.5.4 | `progression` (expansion 4) |
| 120105 | Retail (Midnight) 12.1.5 | `retail` |
| 16001 | WoW Forever 1.60.1 | `forever` |

Retail and Forever run under the *restricted* combat-data policy (secret values; `docs/restricted-clients.md`). What has
and has not been verified in a real client is in `docs/quality/client-support.md`.

## Repository layout

| Path | Role |
| --- | --- |
| `RotationMaster.toc`, `embeds.xml`, `locales.xml`, `Bindings.xml` | Load list; the libraries; the 11 locale files; key bindings |
| `globals.lua`, `compat.lua`, `constants.lua`, `utils.lua`, `profiler.lua`, `validate.lua` | Early globals and color codes; compatibility shims; constants; helpers; native profiler access; saved-data validation |
| `init.lua`, `main.lua`, `buttons.lua` | Addon object, saved-variable defaults and migrations (`init.lua`); slash commands, events, the poll and both evaluation engines (`main.lua`); action-bar button discovery and highlighting (`buttons.lua`) |
| `Platform/` | One adapter per Blizzard API family (`unit_health`, `spells`, `auras`, `talents`, `range`, ...). Everything that touches a game API goes through here and returns a value or `nil, reason`. |
| `Core/` | Rotation logic that does not draw: the condition registry and runtime, rotation library/catalog/scopes/selection, sequences, announcements, item sets, imports, tooltips, custom-code services |
| `Conditions/` | The Built In condition definitions (`addon:RegisterCondition`), one file per area |
| `Data/` | Pure data modules (rotation store, drafts, codec, validation, tags, export text) and generated tables (`artwork.lua`, `builtin_sources.lua`, `talent_trees.lua`); `Data/wowsims/` is pinned simulator JSON (not shipped) |
| `Functions/` | Named utility functions conditions and custom code call |
| `UI/` | The native widget set and every window (rotation editor, condition editor, settings, window registry `UI/window.lua`) |
| `Help/` | Authored help text, one file per area |
| `Diagnostics/`, `Analytics/` | Error reports, CPU/runtime/memory capture, `/rm debug` reports; analytics capture and replay |
| `Integrations/` | Optional addons: Masque, Questie, boss mods, LuaWorkbench, the supported-addon catalog |
| `Modules/` | Load-on-demand add-ons: 13 class modules of Built In rotations and `RotationMaster_WowSims` |
| `Libs/`, `LibsAugment/` | Vendored libraries (hash-pinned in `Libs/UPSTREAM.json`) and local additions |
| `Locales/` | `enUS.lua` (source) and ten generated translations |
| `Assets/`, `Fonts/`, `textures/` | Icons and overlays (`Assets/*/provenance.json` records each one), the monospace font, minimap and chat textures |
| `tests/` | Headless suites (Lua 5.1 and LuaJIT) and Python checks; `tests/fixtures/` holds client models and frozen predecessor sources |
| `tools/` | Generators, checkers, the package builder, translation tools (`docs/dev/running-things.md`) |
| `docs/` | Human documentation: `dev/`, `translators/`, `release/`, and the topic documents |
| `.gitea/`, `.claude/`, `.pre-commit-config.yaml` | CI, agent instructions and personas, hooks. None of these ship. |

## Load order and namespaces

`RotationMaster.toc` is the load order and it matters. Roughly: `globals.lua`; `Core/dependency_revisions.lua`; all of
`Platform/` (adapters first, so everything above can use them); `compat.lua`; the libraries (`embeds.xml`) and locales
(`locales.xml`); `constants.lua`, early `Data/`, `Functions/`; `utils.lua`, `profiler.lua`, `Diagnostics/`; the `Core/`
condition services and `Data/` modules; the rest of `Core/`; `main.lua`, `buttons.lua`; `init.lua`, `validate.lua`; all
of `UI/` and `Integrations/`; `Help/`; and last `Conditions/`, which register themselves into the registry `Core/`
created. `tests/verify.py` walks this graph (TOC and XML includes, exact filename case) and fails on a missing file.

Every file starts `local addon_name, addon = ...`: the addon table is passed by the client. Platform adapters are
methods on `addon.Platform` (`function platform:GetUnitHealthObservation(unit)`), other modules hang functions on `addon`.
Several files capture `addon.X` into a local at load and delete the public name so later code cannot swap it; the byte
freeze tests below depend on that style being stable.

## Load-on-demand Built In modules

Built In rotations are not in the main addon. `Modules/RotationMaster_<Class>/` (13 classes) is a separate add-on with
`## LoadOnDemand: 1` and `## Dependencies: RotationMaster`, one TOC per client flavor (`_Vanilla`, `_TBC`, `_Camelot` and
`_Forever`, `_Standard`, `_Mists`) plus a fallback TOC that loads nothing. At startup `Core/builtin_modules.lua`
(`addon:LoadBuiltInModule`) asks the client for exactly the player's class module, and the client picks the flavor TOC, so
only that edition's packs run. `bind.lua` (identical in every module) gives the module's private namespace
`RegisterDefaultBlock` and `RegisterDefaultRotation`. `RotationMaster_WowSims` is a converter module loaded by
`Core/transfer_formats.lua` the first time a transfer window needs it. In the release zip each module is moved to its own
top-level folder (`.pkgmeta` `move-folders`); in a development install each needs its own symlink. Full detail,
authoring rules and the premade policy are in `Modules/README.md`.

## Evaluation

A poll resolves the active rotation (eligibility, scope, switch conditions), then walks its cooldowns and rotation steps
and publishes the first advisable action. Conditions return `true`, `false`, or `nil, reason` for *unavailable*
(a Branch or Stop pauses that poll; an action step is skipped; NOT of unavailable stays unavailable).

Two engines evaluate (`main.lua`, `BEGIN LEAN EVALUATION`; `/rm perf engine lean|standard`):

- **standard** acquires and proves the whole active body every poll (ownership, eligibility, scope, conditions);
- **lean** records a compiled plan after a completed standard poll and reuses it while nothing it depends on changes:
  spec, rotation, profile, preview window, the *execution generation* (advanced by every rotation, condition, function,
  item set and effect writer), the *context epoch* (events that change eligibility: level, talents, spells, form,
  combat...) and a 60 second age cap. Conditions, readiness, range and cooldowns are still read fresh every poll.

The runtime also gates idle polls (no target, focus or combat: evaluate on events or about once a second). Any code that
writes a rotation, condition, function, item set or effect in place must notify
(`addon:InvalidateRotationDependencies`, `docs/architecture/runtime-revisions.md`) or the lean plan goes stale.

## Condition registry

`addon:RegisterCondition(tag, definition)` (`Core/conditions.lua`) installs a condition; `UnregisterCondition` removes it.
A definition has `description`, `icon`, `fields` (the typed field schema), `valid(spec, value)`, `evaluate(value, cache)`
(returns a boolean, or `nil, reason`), `print(spec, value)` (the readable summary, with `{{!a|b}}` alternatives for
negation), `help(frame)`, and optionally `requiredFields`, `disabled`, `on_register` and `supported(value)`. Whether a
condition can work on this client at all is declared in `Core/condition_support.lua` (policy, family, native APIs): a
rotation using an unsupported condition is *incomplete*, which is different from momentarily unavailable. Declarations are
checked by `tests/catalog.lua` and `tests/declaration_schema.lua`; the Built In source browser reads
`Data/builtin_sources.lua`, generated from the authored Lua by `tools/generate_builtin_sources.py`.
Custom conditions use the same contract (`docs/architecture/condition-authoring.md`, `docs/custom-conditions.md`).

## Built In rotations and their revision ledger

A pack is a version-1 envelope with a stable id (`rm.<edition>.<class>.<name>`), a `revision`, applicability facts
(families, class, expansion range, rulesets), `body.specs`, a `switch`, and `rotation`/`cooldowns` steps with stable ids.
Shared steps live in a class's `blocks.lua` per edition; a pack pins every block it reaches in `blocks`, and
`RegisterDefaultRotation` expands them once at load. Any change to block content needs a new block revision, new pins in
every consumer and new rows in `tests/fixtures/builtin_composition_ledger.lua`; `tests/builtin_composition.lua` fails when
content changes without a revision bump, so a saved clone always sees a source-side diff. Display names are derived and
checked by `tools/builtin_names.py` (the before/after list is `docs/builtin-name-changes.md`). Enable and priority
overrides are per profile and never copy the rotation.

## Saved data

`RotationMasterDB` (AceDB, one account table per client installation). Rotations live in the selected profile under a
Class or Character owner (`docs/architecture/storage-scopes.md`); Built In preferences, announcement rules and UI
preferences are per profile; effects, custom conditions and functions are global; item-set bindings are per character.
`init.lua` migrates in place (`profile.version = 3` when `profile.rotationStore` exists, plus the `upgrade*()` passes).
The migration is **not reversible**: an older release does not read the new store.

## Generated files and their generators

Never hand-edit these; `python3 tools/check --static` fails when one is stale.

| File | Generator |
| --- | --- |
| `Data/artwork.lua`, `.pkgmeta` | `tools/generate_artwork_catalog.py --write` (from `Assets/*/provenance.json`; `.pkgmeta` also carries the release ignore list) |
| `Data/builtin_sources.lua` | `tools/generate_builtin_sources.py --write` |
| integration catalog block in `Integrations/catalog.lua` | `tools/generate_integration_projects.py --write` (from `tools/integration_projects.json`) |
| `Modules/RotationMaster_WowSims/*.lua` tables | `tools/export_wowsims_mapping.py` (from `Data/wowsims/*.json`) |
| `Data/talent_trees.json` | `tools/export_talent_trees.py` |
| `docs/builtin-name-changes.md`, Built In names | `tools/builtin_names.py apply|docs` |
| `tests/fixtures/client_api_<client>.lua` | `tools/generate_client_api.py` |
| `Locales/<xx>.lua` | `tools/locales.py build` (via `tools/translation_apply.py`) |
| `docs/translators/glossary.md` | `tools/translation_glossary.py --write` |
| `Assets/Controls/*.tga` | `tools/generate_control_icons.py` (needs rsvg-convert and ImageMagick) |

## Tests

`tests/*.lua` are headless suites: each builds a model of one client (`tests/fixtures/client_api_*.lua` list which globals
that client really has, and fixtures must model ABSENT globals), loads real addon files, and asserts through a tiny
`PASS`/`FAIL` harness. Most run under both `lua5.1` and `luajit`; `tools/check` lists which. `tests/*.py` check the
tooling (`verify.py` is the load-graph and vendor-integrity check, `test_us_spelling.py` the spelling rule). Kinds worth
knowing:

- **Behavior suites** (`conditions.lua`, `rotation_sequence.lua`, `startup.lua`, ...) drive real modules.
- **Class scenario suites** (`defaults_<edition>_<class>.lua`) run each premade through the real predicates and sequence
  executor with modeled observations. `default_corpus.lua` checks every pack of every module against five synthetic client
  families and thirteen class tokens and is by far the slowest test (minutes).
- **Byte-freeze and predecessor ("inverse") suites.** Many suites guard a refactor by proving old and new behave the same.
  `tests/fixtures/restore_*.lua` turn the *current* source text of a file back into its predecessor (a recorded "before" and
  "after"); the suite loads the predecessor and compares behavior. The restore asserts the current file equals the recorded
  "after" byte for byte and fails with `unrelated ... source change: <path>` when it does not. So **editing a frozen file
  breaks those suites by design**; the change has to be recorded in the fixture on purpose. They are not flaky tests and
  they are not regressions in behavior; compare against a clean baseline before drawing conclusions.
- **Client model suites** (`client_api_surface.lua`, `client_baseline.lua`) guard against fixtures that define globals the
  real client removed.

The exact command list is `tools/check`; `tools/check_all.py` runs the same list without stopping at the first failure.

## How to...

### Add a condition

1. Write the definition in the right `Conditions/<area>.lua` with `addon:RegisterCondition` (follow the nearest neighbor).
   Read game data only through a `Platform` adapter and return `nil, reason` when it cannot be read.
2. Declare client support in `Core/condition_support.lua`, and a Retail/Forever classification in
   `docs/restricted-clients.md`. A condition that cannot work on an edition does not exist there.
3. Add the strings as literal `L["..."]` reads and `L["..."] = true` in `Locales/enUS.lua`; add `Help/` text.
4. Add or extend a suite in `tests/` (declaration, help callback, evaluation including the unavailable case).
5. `python3 tools/generate_builtin_sources.py --write`, then `python3 tools/check`. The website mirrors condition data:
   say what it must regenerate.

### Add a Built In premade

Follow `Modules/README.md` (file in `Modules/RotationMaster_<Class>/<edition>/`, listed in every flavor TOC of that edition
after `blocks.lua`, localized name and description keys, provenance, one enabled premade per specialization, alternatives
shipped disabled). Add scenarios to the class suite, run `python3 tools/builtin_names.py check` and
`python3 tools/generate_builtin_sources.py --write`, and translate the new name and description (`docs/translators/README.md`).

### Add or change a locale string

English text is the key. Write `L["Text"]` in code and `L["Text"] = true` in `Locales/enUS.lua`; never concatenate
sentences, and use `{{name}}` / `%s` placeholders. Keep `enUS` under 4096 entries (see `.claude/learnings/tests-and-locales.md`).
`python3 tools/catalog_check.py` and `python3 tools/locales.py check` must pass; translations catch up through
`tools/translation_status.py` / `translation_todo.py` / `translation_apply.py`.

### Add a client

Add its Interface number to `RotationMaster.toc` and the module TOCs it needs, to `SUPPORTED_CLIENTS` in
`tools/package_release.py`, and an edition row in `Core/builtin_modules.lua` (`addon.BuiltInModules.editions`) if it has
premades. Teach `Platform/client.lua` its family and policy, generate its API manifest
(`tools/generate_client_api.py`, `tests/fixtures/client_api_*.lua`), record evidence and what is unverified in
`docs/quality/client-support.md`, and keep any wording about the supported list in `README.md` and
`docs/release/BETA.md` current.

### Add a library

Vendor it under `Libs/`, record its source revision in `Libs/UPSTREAM.json` (`tests/verify.py` checks the hashes), and add
it to `embeds.xml`. Keep its license file with it; the package ships `Libs/`.

## Deploy and release flow

*Development install.* Link the checkout into `Interface/AddOns/RotationMaster`, and link every `Modules/RotationMaster_*`
folder as `Interface/AddOns/RotationMaster_*` (the client only scans top-level folders). `@project-version@` shows
literally in a symlink install. Reload with `/reload`.

*Release.* Merge to the default branch, write `docs/release/notes/<tag>.md`, tag, push. CI re-runs the suites, builds the
package with the vendored BigWigs packager, creates the Gitea release and uploads to CurseForge, Wago and (stable tags)
WoWInterface. The version is the tag name. See `docs/release/RELEASING.md`; beta testers use `docs/release/BETA.md`.
