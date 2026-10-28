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
| `RotationMaster.toc`, `embeds.xml`, `locales.xml`, `Bindings.xml` | Load list; the libraries; the 11 main locale files; key bindings |
| `globals.lua`, `compat.lua`, `constants.lua`, `utils.lua`, `profiler.lua`, `validate.lua` | Early globals and color codes; compatibility shims; constants; helpers; native profiler access; saved-data validation |
| `init.lua`, `main.lua`, `buttons.lua` | Addon object, saved-variable defaults and migrations (`init.lua`); slash commands, events, the poll and both evaluation engines (`main.lua`); action-bar button discovery and highlighting (`buttons.lua`) |
| `Platform/` | One adapter per Blizzard API family (`unit_health`, `spells`, `auras`, `talents`, `range`, ...). Everything that touches a game API goes through here and returns a value or `nil, reason`. |
| `Core/` | Rotation logic that does not draw: the condition registry and runtime, rotation library/catalog/scopes/selection, sequences, announcements, item sets, imports, tooltips, custom-code services |
| `Conditions/` | The Built In condition definitions (`addon:RegisterCondition`), one file per area |
| `Data/` | Pure data modules (rotation store, drafts, codec, validation, tags, export text) and generated tables (`artwork.lua`, `builtin_sources.lua`, `talent_trees.lua`) |
| `Functions/` | Named utility functions conditions and custom code call |
| `UI/` | The native widget set and every window (rotation editor, condition editor, settings, window registry `UI/window.lua`) |
| `Help/` | Authored help text, one file per area |
| `Diagnostics/`, `Analytics/` | Error reports, CPU/runtime/memory capture, `/rm debug` reports; analytics capture and replay |
| `Integrations/` | Optional addons: Masque, Questie, boss mods, LuaWorkbench, the supported-addon catalog |
| `Modules/` | Load-on-demand add-ons: 13 class modules of Built In rotations and four text bundles (`RotationMaster_HelpText`, `_ConditionText`, `_DiagnosticsText`, `_IntegrationsText`) |
| `Libs/`, `LibsAugment/` | Vendored libraries (hash-pinned in `Libs/UPSTREAM.json`) and local additions |
| `THIRD_PARTY_NOTICES.md` | The WowSims MIT notice for the Built In rotations written from its APLs; ships in the package, and `tools/package_release.py --check` requires it |
| `Locales/` | `enUS.lua` (source) and ten generated translations for the text read at startup; `bundles.json` names the load-on-demand text bundles that hold the rest (see "Text bundles") |
| `Assets/`, `Fonts/`, `textures/` | Icons and overlays (`Assets/*/provenance.json` records each one), the monospace font, the two `.blp` textures the help and condition pages still draw |
| `tests/` | Headless suites (Lua 5.1 and LuaJIT) and Python checks; `tests/fixtures/` holds client models and frozen predecessor sources |
| `tools/` | Generators, checkers, the package builder, translation tools (`docs/dev/running-things.md`) |
| `docs/` | Human documentation: `dev/`, `translators/`, `release/`, and the topic documents |
| `.gitea/`, `.claude/`, `.pre-commit-config.yaml` | CI, agent instructions and personas, hooks. None of these ship. |

### Integrations that do not exist

Rotation Master has no WowSims import or export, and none will be added. Early 2.0 test builds had a converter (a
load-on-demand module, a Format choice in the rotation transfer window and pinned simulator data); it was removed before
release because of the WowSims maintainers' attitude toward addon developers they consider beneath them: they indicated that
community submissions supporting small addons, with only around 200,000 downloads, are not wanted. The decision record is
in `.claude/learnings/product-decisions.md`; the only trace in saved data is `profile.transfer_format`, which `init.lua`
drops on load and `Core/profile_data.lua` still accepts in an imported profile. The addon-side integrations that do exist
are in `docs/architecture/integrations.md`.

### Where a new file goes

A game-facing file lives in the folder named for what it does (the roles above) and is listed in `RotationMaster.toc` (or
the XML it includes) in load order; `tests/verify.py` fails on a file the TOC names but the tree lacks, and on an authored
Lua file outside `tests/`, `tools/`, `Libs/` and `Modules/` that no TOC or XML loads; `tools/test_devtools.py` fails on a
`tests/*.lua` or `*.py` that `tools/check` does not run. Nothing in the addon folders is unreferenced: a file no TOC, test, tool or document names is dead and is removed (`git grep` for its name
first). Generators write only the generated files in the table below; a hand-edited generated file fails
`python3 tools/check --static`. Dev-only material stays out of the package (`.pkgmeta`, `tools/package_release.py --check`).
Planning documents are never committed.

### Byte-pinned text

No source file is pinned to its exact bytes any more: the suites that rebuilt an earlier version of a file from its
current text were retired, so every authored Lua file can be reformatted and commented
(`docs/dev/formatting.md`). What stays fixed is text that saved data binds to:

- **Built In helper and callback bodies.** Saved custom copies and exported bundles hash the text between a function's
  parameter list and its `end` (`tests/private_helper_identities.lua` records 64 helper hashes; `Core/function_data.lua`
  puts them in a bundle's requirements), and the Built In source browser shows the callback text from
  `Data/builtin_sources.lua`. `tools/format_lua.py` prints every body recorded there verbatim, so those functions keep
  their older, denser layout, and no comment may be added inside one. After changing a Built In module run
  `python3 tools/generate_builtin_sources.py --write` and `python3 tools/bytecode_equal.py --catalog`.
- **The Built In composition ledger** (`tests/fixtures/builtin_composition_ledger.lua`) and the premade rotation data under
  `Modules/`, whose revisions and digests are values, not layout.
- A few suites still slice a source file by pattern (`tests/edition_state_conditions.lua` and
  `tests/combat_history_time_conditions.lua` cut `handle_combat_log` and the `UNIT_COMBAT` handler out of `main.lua`,
  `tests/rotation_scope_init.lua` cuts `init.lua` up to `function addon:augmentDefaults`, `tests/settings_metadata.lua`
  and `tests/talent_trees.lua` read other files). Keep the shape those patterns expect or update the pattern with the file.

## Load order and namespaces

`RotationMaster.toc` is the load order and it matters. Roughly: `globals.lua`; `Core/dependency_revisions.lua`; all of
`Platform/` (adapters first, so everything above can use them); `compat.lua`; the libraries (`embeds.xml`) and locales
(`locales.xml`) with the text-bundle index and loader (`Data/text_bundle_index.lua`, `Core/text_bundles.lua`); `constants.lua`, early `Data/`, `Functions/`; `utils.lua`, `profiler.lua`, `Diagnostics/`; the `Core/`
condition services and `Data/` modules; the rest of `Core/`; `main.lua`, `buttons.lua`; `init.lua`, `validate.lua`; all
of `UI/` and `Integrations/`; `Help/`; and last `Conditions/`, which register themselves into the registry `Core/`
created. `tests/verify.py` walks this graph (TOC and XML includes, exact filename case) and fails on a missing file.

Every file starts `local addon_name, addon = ...`: the addon table is passed by the client. Platform adapters are
methods on `addon.Platform` (`function platform:GetUnitHealthObservation(unit)`), other modules hang functions on `addon`.
Several files capture `addon.X` into a local at load and delete the public name so later code cannot swap it.

## Load-on-demand Built In modules

Built In rotations are not in the main addon. `Modules/RotationMaster_<Class>/` (13 classes) is a separate add-on with
`## LoadOnDemand: 1` and `## Dependencies: RotationMaster`, one TOC per client flavor (`_Vanilla`, `_TBC`, `_Camelot` and
`_Forever`, `_Standard`, `_Mists`) plus a fallback TOC that loads nothing. At startup `Core/builtin_modules.lua`
(`addon:LoadBuiltInModule`) asks the client for exactly the player's class module, and the client picks the flavor TOC, so
only that edition's packs run. `bind.lua` (identical in every module) gives the module's private namespace
`RegisterDefaultBlock` and `RegisterDefaultRotation`. The four text bundles under `Modules/` are not Built In modules;
see "Text bundles" below. In the release zip each module is moved to its own top-level folder (`.pkgmeta`
`move-folders`); in a development install each needs its own symlink. Full detail, authoring rules and the premade
policy are in `Modules/README.md`.

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

The poll runs every `poll` seconds (default 0.15). The *idle gate* skips ticks out of combat with no target, no focus and
the configuration window closed: a tick evaluates only after one of the unit, cooldown or bag notifications listed in
`main.lua`, or once per `idle_poll` seconds (default 1.0) as a floor for time and position (`idle_poll = 0` turns the gate off). Any code that
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
| `Data/talent_trees.json` | `tools/export_talent_trees.py` |
| `docs/builtin-name-changes.md`, Built In names | `tools/builtin_names.py apply|docs` |
| `tests/fixtures/client_api_<client>.lua` | `tools/generate_client_api.py` |
| `Locales/*.lua`, `Modules/RotationMaster_*Text/*.lua` (English and the ten languages), `tools/locale_registry.json`, `tools/locale_translators.json` | `tools/locales.py` (`build` via `tools/translation_apply.py`, `add`, `reword`, `notes set`, `credit`, `rebuild`) |
| `Data/text_bundle_index.lua` | `tools/locales.py index` (hashes of every bundle key) |
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
- **Predecessor fixtures.** Some suites rebuilt an earlier version of a file from its current text
  (`tests/fixtures/restore_*.lua`: a recorded "before" and "after") and ran both. A proof that "this refactor changed
  nothing else" is established when the refactor lands and git keeps it; what lasts is a test of the behavior, so these
  were retired: the whole-file pins first (about a hundred), then the last ones that stopped the sources from being
  formatted (suites that only compared old and new text were removed with their `tools/check` entries; behavior suites kept
  their behavior tests). Do not add a test that compares a file's text with an earlier version. Fixtures named `restore_*`
  that remain only rebuild small, still-valid shapes; if one fails after an edit, find out what it guards before
  touching it. `tests/private_helper_identities.lua` is the deliberate pin: the identity of the private helpers saved
  copies and exported bundles bind to (`builtin:<module>:<name>`, whose source hash `Core/function_data.lua` carries in a
  bundle's requirements). Where a helper changes on purpose, record its new hash there, against the commit that changed it.
- **Client model suites** (`client_api_surface.lua`, `client_baseline.lua`) guard against fixtures that define globals the
  real client removed.

The exact command list is `tools/check`; `tools/check_all.py` runs the same list without stopping at the first failure.

## Text bundles (load-on-demand translations)

A Lua table's hash part doubles past 4,096 entries (about 177 KB resident, for every player in every language), and
`Locales/enUS.lua` had crossed the line. The text nothing reads while the game loads therefore lives outside the main
table, in four load-on-demand add-ons named in `Locales/bundles.json`: `RotationMaster_HelpText` (Help articles and
tooltips), `RotationMaster_ConditionText` (condition summaries, help and choices), `RotationMaster_DiagnosticsText`
(performance, memory, analytics and error reports, `/rm debug`) and `RotationMaster_IntegrationsText` (the Integrations
page). Each holds `enUS.lua` and the ten translations by stable ID; the code still reads `L["English text"]`, and a key
lives in exactly one catalog.

### Stable IDs, and how a language is applied

Every string has a number from `tools/locale_registry.json` (append-only, never reused, never derived from the wording).
A locale file is `ID -> text`; `enUS.lua` also records a hash of the English per ID, and a translation records, in a
comment above it, the hash of the English it was made from (stale = hashes differ; the translation is still shown). Code
keeps reading `L["English text"]`. Strings read under a key that is not their text (`Default.*` names, `Help.*` articles,
text whose pipes are doubled for display) are *symbolic* and listed as `[id] = { key, English }`.

Locales load **translations first, English last** (`locales.xml`, each bundle's TOC). The game language's file registers
with `NewLocale(addon_name, "<xx>", false, true)` (every other language's file returns at once) and hands its ID table to
`enUS.lua` through the add-on's private table. `enUS.lua` then builds the final `L` once, eagerly: a translated game gets
`L[english] = translation` for every translated ID (untranslated text is absent and reads as its own English, because the
application is registered silent); an **English game loads no translation table at all**, only the symbolic entries whose
English differs from their key. Nothing is resolved per lookup and nothing of the ID tables stays referenced.

`Core/text_bundles.lua` makes the bundles invisible: a `L["English text"]` read the main table cannot answer asks
`Data/text_bundle_index.lua` (the sorted 32-bit hashes of each bundle's keys, and of the symbolic subset; generated by
`tools/locales.py index`) which bundle owns the key, loads that add-on once through `C_AddOns.LoadAddOn`, **moves every
entry the bundle produced into `L`** and releases the bundle's own AceLocale table. An English game loads a bundle only for
a symbolic key. A bundle that cannot load answers with the key (the English) and is not asked again; a key in no catalog
reads as itself (the registration is silent; the static gate is `tools/catalog_check.py`). `addon:LoadTextBundle(id)`,
`addon:GetTextBundleOf(key)`, `addon:GetTextBundleStates()` serve code and tests; `addon:GetLocaleTranslators()` and
`addon:GetTranslationCredit()` serve the About pages. The index and the loader load straight after `locales.xml`; nothing
in a bundle may be read while the game is loading.

Resident memory (Lua 5.1, after full collections, net of the libraries; `tools/locale_dump.lua`): an English game 680 KB
before and 351 KB now at startup (and 945 / 899 KB after reading every key, which loads the bundles); a German game 1,009 KB
before and 1,015 KB at startup (1,310 / 1,269 KB with every bundle loaded).

Tools and gates. `python3 tools/locales.py bundles` lists the catalogs; `move` moves keys between them (IDs and
translations follow); `check` validates IDs, hashes, placeholders, headers and the index; `reword` changes English without
orphaning translations; `where` finds a string's uses; `tools/translation_*.py` read and write all catalogs as one locale.
`tests/test_locale_bundles.py` fails if any bundle string is untranslated, stale or invalid in any of the ten locales (the
main catalog may carry untranslated IDs, a bundle may not), if a key is in two catalogs, or if the index is stale;
`tests/test_locale_ids.py` covers the formats, the registry, reword (including a runtime proof that a reword orphans nothing),
credits, notes and `where`; `tests/text_bundles.lua` proves the runtime (a normal start loads no bundle, a bundle key loads
exactly its own bundle, every key reads as its translation in every language); `tests/client_locale.lua` holds the main
table at or below 3,900 entries and reports the resident memory. New text goes into the main catalog first
(`locales.py add` or `sync`); move it when it is only read on demand. A new bundle needs an entry in `Locales/bundles.json`,
a TOC (`## LoadOnDemand: 1`, `## Dependencies: RotationMaster`, translations first and `enUS.lua` last), `.pkgmeta`
(`python3 tools/generate_artwork_catalog.py --write`) and the index.

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

English text is the key in code. Write `L["Text"]` in code, then `python3 tools/locales.py sync` (or `add "Text"`) gives it
an ID in `Locales/enUS.lua`; never concatenate sentences, and use `{{name}}` / `%s` placeholders. Keep `Locales/enUS.lua` at or
below 3,900 entries (see "Text bundles"). Text that is only read when a window opens, a report is written or a condition is
described belongs in a text bundle: `python3 tools/locales.py move <bundle> keys.json` moves it (ID and translations
follow) and rebuilds the index. To change the wording of existing text use `python3 tools/locales.py reword "old" "new"`:
it rewrites the code, keeps the ID and leaves every translation (stale by hash). Strings with `%s`/`%d` and short or
abstract strings carry notes and context for translators (`locales.py notes`). `python3 tools/catalog_check.py` and
`python3 tools/locales.py check` must pass; translations catch up through `tools/translation_status.py` /
`translation_todo.py` / `translation_apply.py`.

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
