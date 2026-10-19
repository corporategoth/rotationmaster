# Condition modernization audit

## Current source and compatibility contract

The reviewed inventory contains 115 Built In condition definitions across supported client/class combinations. Structural AND/OR/NOT nodes belong to the condition tree, rather than invented executable definitions. Authored modules under `Conditions/` remain the source of truth for executable callbacks; the offline source collector extracts their code and captures, and `tools/generate_builtin_sources.py --write` maintains source records and live getters. The game does not reconstruct source or inspect callback bytecode.

The Functions namespace system is already implemented. `Core/functions.lua` validates explicit qualified call paths, builds callback-private namespace tables at compilation, and resolves stable dependency identities. It does not publish ambient `Conditions`, `Platform.spells` or `utils` globals. A displayed namespace is therefore not evidence that the authored callback has migrated to a function module. Existing `addon` dot/colon methods and original captured bindings must remain available to saved custom definitions, imports and source duplicates.

The older unchecked progress items for the utility registry, readonly Built In source/duplicates, transitive dependency transfer and definition enable/disable describe work now implemented. Native client acceptance remains separate from those offline contracts. The AceGUI removal checklist is still real.

## Implemented audit corrections

* Distance field commits now notify their owning editor through the same status/proxy synchronization used by sibling fields. Previously the field changed a detached value without updating the editor session.
* Missing, failed, malformed and restricted Distance range observations now return explicit unavailable reasons. Legacy nil-as-false compatibility previously allowed NOT to turn a missing range into a match. Readable intervals retain the documented maximum-bound comparison.
* Native condition inputs inspect ancestor release flags before committing pending text. AceGUI hides a root before recursively releasing children, so a focus-loss callback could otherwise commit an abandoned child edit.
* RM owns ordinary List, numeric Table and responsive spell-field geometry in `UI/condition_layout.lua`. Shared Built In field groups, compact condition-editor roots and Test/preview roots use this container. The container still registers with AceGUI for pooling and release, and explicitly accepts legacy custom child widgets. Saved callbacks requesting other registered layouts or complex table cells retain a compatibility path.
* Native group pooling clears failed-layout state; legacy custom layout height changes reach native parents. A ten-level native group chain previously performed 1,023 layout passes because each child width change was followed by a second explicit layout; the reviewed fix bounds that traversal to the group depth.
* Twelve condition modules no longer load an unused AceGUI local. Actual uses in common, combat and talent remain visible.

Focused regressions exercise actual Distance declarations, engine behavior beneath NOT, shipped AceGUI pooling/widget methods, real native field controls and the existing condition/Test adapters. Frame fixtures establish offline contracts; they do not establish native input, visual layout or client acceptance.

## Native bridge removal map

| Owner | Current responsibility | Next coherent boundary |
| --- | --- | --- |
| `UI/condition_layout.lua` | Native common geometry; Ace pool/release and explicit custom-layout fallback | Move RM widgets to an owned lifecycle while retaining an isolated legacy-child adapter. |
| `UI/condition_inputs.lua`, `UI/checkbox.lua`, `UI/selector.lua` | Native frames with Ace registration, events and widget pooling | Share native callback/userdata/size/release behavior; preserve existing public factories. |
| `UI/spell_search.lua` and `UI/spell_icon.lua` | Owned reference identity/search/drop behavior over Ace EditBox/Icon contracts | Replace allocation/pooling after preserving pending-input, async metadata and exact script restoration tests. |
| `Conditions/common.lua` | Native field groups; ordinary Icon edit/preview controls and legacy item popup lifetime | Replace remaining Icons/popups through shared owned reference controls. |
| `Help/common.lua` | Ace SimpleGroup/Label/Icon/Button help output | Introduce owned text/picture/button documentation rows while accepting saved custom help callbacks. |
| `Conditions/combat.lua`, `Conditions/talent.lua` | Remaining ordinary Icon/Label use | Convert after the shared icon/text contracts exist. |
| `UI/condition_editor.lua`, `UI/condition_source_preview.lua` | RM root layout; release/tracking of arbitrary custom allocations | Keep explicit custom allocation guards until external widgets no longer need Ace ownership. |
| Legacy `Options/*`, `Widgets/*`, embedded libraries | Existing APIs still callable by saved source or compatibility entry points | Audit actual callers before removing code or TOC dependencies. |

This slice removes ordinary condition layout ownership from AceGUI. It does not remove the AceGUI dependency or imply that legacy custom Lua can lose access to it.

## Function module migration map

The largest authored `addon` references are nullable formatting, cached observations, unit/operator maps, validation lookups and comparison functions. The next migration should move one family end to end, rather than rewrite all textual `addon` references.

| Proposed authored module | Existing implementations | Required migration evidence |
| --- | --- | --- |
| Pure value/format helpers | `utils.lua`: compare, isin, nullable, nullable_value, compareString, playerize, keys | Identical positional arguments/returns; preserved nil tuples; stable original IDs and compatibility wrappers. |
| Evaluation observations | `utils.lua` cache helpers plus `Platform/*` methods | Explicit cache and receiver inputs; platform unreadable/error results remain unavailable. |
| Condition field builders | `Conditions/common.lua`, native input/selector/check/group factories | Explicit owner/value/update arguments; same callback parent protocol, pending input and release behavior. |
| Condition help | `Help/common.lua`, `Help/conditional.lua` | Render-independent documentation where possible; source browsing extracts actual functions without copying their bodies. |
| Family helpers | Aura/item/spatial/weapon/talent helpers | Typed context and local state dependencies; optional integration/class availability tested across inventory. |

Before migrating authored callbacks, extend the source registration/collector contract to declare qualified bindings for those actual callbacks. A canonical dot call must resolve to the same stable helper identity in both the original Built In execution and its compiled editable duplicate. Receiver-bearing methods still require explicit receivers. Preserve previous binding IDs and legacy aliases; namespace/name edits are metadata changes and must not rewrite arbitrary saved source. Do not add ambient global module tables merely to make the new source compile.

## Remaining runtime and native acceptance work

Spatial proximity's player fallback currently consumes the first LibRangeCheck bound as though it were an exact distance. Coordinate-based paths have different observation capabilities, and all eight proximity-statistics consumers share that helper. A follow-up must define interval membership/uncertainty for the whole family, propagate unavailable observations through counts and aggregates, and test NOT and False branches. Changing only the shared return tuple would leave consumers silently ignoring errors.

Other older condition families still invoke client globals directly. Their client API availability, restricted observations and finite numeric validation need family-specific adapter tests before being described as fully migrated. The existing source/catalog corpus validates declarations and compatibility but does not substitute for gameplay observations across clients.

Native acceptance should cover repeated open/close and owner replacement; translated wide/narrow fields; numeric/raw pending input; item popup return; real spell/item drops and asynchronous metadata; field/help heights; and the optional advanced editor's Test/Run/Debug ownership. The offline suites do not make native acceptance claims.

## Follow-up corrections and original icon batch

Hand selection now happens before interpreting enchant observations. This fixes unenchanted offhand predicates falling through to an enchanted main hand, the `offhands` expiration typo, and offhand swing history being ignored before a mainhand swing. Selected malformed/restricted or failed observations stay unavailable beneath NOT. A PvP summary typo now uses the same player/unit choice as its fields and validator.

Single-item controls validate drops before consuming the cursor. Direct rejected inputs repaint their accepted stored value. Switching to an empty custom item list clears the old set preview and invalidates outstanding metadata updates.

The first original icon batch contains sixteen generated transparent fantasy families: combat, character, spell, buff, debuff, item, weapon, spatial, resources, pet, talent, casting, logic, totem, environment and time. All 115 reviewed Built In identities now reference these bundled families; AND/OR/NOT share logic, and Delete uses RM's original trash control. Packaged category icons follow stable category identities after honoring explicit saved choices. No indexed defaults or saved categories are rewritten. Original PNGs, exact generation prompts/provenance, alpha reports, 64/128-pixel RGBA TGA exports and contrasting-background contact sheets remain under `Assets/Conditions/`.

Root and asset reviewers inspected the 20/24/32 and 64/128-pixel contact sheets. The family silhouettes and color cues remain distinct, while fine internal detail is necessarily reduced at small sizes. This is sixteen semantic designs reused across the condition inventory, not 115 unique illustrations. Separate AND/OR/NOT glyphs and more specific health/mana, aura-stack, movement/threat, range and hand-specific variants remain design follow-up. A client reload and native visual acceptance are still required.
