# Condition modernization audit

## Current source and compatibility contract

The reviewed inventory contains 116 Built In condition definitions across supported client/class combinations. Structural AND/OR/NOT nodes belong to the condition tree, rather than invented executable definitions. Authored modules under `Conditions/` remain the source of truth for executable callbacks; the offline source collector extracts their code and captures, and `tools/generate_builtin_sources.py --write` maintains source records and live getters. The game does not reconstruct source or inspect callback bytecode.

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

The first bounded migration below extends the source registration/collector contract to declare qualified bindings for actual callbacks. Continue applying that contract family by family. A canonical dot call must resolve to the same stable helper identity in both the original Built In execution and its compiled editable duplicate. Receiver-bearing methods still require explicit receivers. Preserve previous binding IDs and legacy aliases; namespace/name edits are metadata changes and must not rewrite arbitrary saved source. Do not add ambient global module tables merely to make the new source compile.

## Remaining runtime and native acceptance work

Spatial proximity's former lower-bound-as-distance bug is corrected across the base predicate and all eight statistics consumers. The completion/status contract and interval evidence are documented below. `DISTANCE_COUNT` now has the separate conservative snapshot contract documented below. Other older spatial predicates remain separate audit targets; these corrections do not claim a complete spatial-API migration.

Other older condition families still invoke client globals directly. Their client API availability, restricted observations and finite numeric validation need family-specific adapter tests before being described as fully migrated. The existing source/catalog corpus validates declarations and compatibility but does not substitute for gameplay observations across clients.

Native acceptance should cover repeated open/close and owner replacement; translated wide/narrow fields; numeric/raw pending input; item popup return; real spell/item drops and asynchronous metadata; field/help heights; and the optional advanced editor's Test/Run/Debug ownership. The offline suites do not make native acceptance claims.

## Follow-up corrections and original icon batch

Hand selection now happens before interpreting enchant observations. This fixes unenchanted offhand predicates falling through to an enchanted main hand, the `offhands` expiration typo, and offhand swing history being ignored before a mainhand swing. Selected malformed/restricted or failed observations stay unavailable beneath NOT. A PvP summary typo now uses the same player/unit choice as its fields and validator.

Single-item controls validate drops before consuming the cursor. Direct rejected inputs repaint their accepted stored value. Switching to an empty custom item list clears the old set preview and invalidates outstanding metadata updates.

The first original icon batch contains sixteen generated transparent fantasy families: combat, character, spell, buff, debuff, item, weapon, spatial, resources, pet, talent, casting, logic, totem, environment and time. All 116 reviewed Built In identities now reference these bundled families; AND/OR/NOT share logic, and Delete uses RM's original trash control. Packaged category icons follow stable category identities after honoring explicit saved choices. No indexed defaults or saved categories are rewritten. Original PNGs, exact generation prompts/provenance, alpha reports, 64/128-pixel RGBA TGA exports and contrasting-background contact sheets remain under `Assets/Conditions/`.

Root and asset reviewers inspected the 20/24/32 and 64/128-pixel contact sheets. The family silhouettes and color cues remain distinct, while fine internal detail is necessarily reduced at small sizes. This is sixteen semantic designs reused across the condition inventory, not 116 unique illustrations. Separate AND/OR/NOT glyphs and more specific health/mana, aura-stack, movement/threat, range and hand-specific variants remain design follow-up. A client reload and native visual acceptance are still required.

## Proximity interval and observation contract

`addon.proximity_eval(value, cache, callback)` retains its public arguments and invokes `callback(cache, unit, distance)`. A complete scan now returns `true`; an unavailable scan returns `nil, reason`. Existing callbacks returning nil without a reason remain valid. For a coordinate observation the callback distance remains the measured Euclidean distance. For a proven-in-range player-centered estimate it is the successful upper bound, rather than the former minimum presented as an exact distance. All nine packaged consumers check completion before comparing counts or aggregating values. Saved custom source is preserved: callers that ignore the status must explicitly adopt that completion check to obtain the same fail-closed policy.

The shipped `LibRangeCheck:GetRange` and `getRangeWithCheckerList` supply the boundary evidence. Successful checkers establish inclusive upper bounds. A positive lower bound comes from a failed checker and therefore excludes a radius equal to that bound. The zero floor returned when every checker succeeds is synthetic; `[0, upper]` at radius zero remains uncertain. A nil upper bound means no tested upper limit; its positive failed lower bound can still establish that a member is outside the configured radius. Crossing, missing, malformed, restricted or failed observations never add a member or supply a fabricated zero count.

Readable same-coordinate-space distances retain the original inclusive threshold. Proven other coordinate spaces and known nonexistent roster slots are excluded. An absent or unrelated anchor, unknown roster/subgroup membership, unavailable candidate location, or required unreadable health/mana observation invalidates the whole scan, including when some earlier members were known. Unsupported/missing coordinate observations use the original player-centered range fallback only where that path existed; errors or restricted coordinates do not trigger another backend.

Solo scans retain self at exact distance zero. Thus a normal solo player scan is not an empty raw proximity set. A fully observed scan can legitimately contain no members (for example a solo pet anchor with pets excluded and its player outside the radius), and threshold counts can legitimately be zero. Those zero counts remain comparable. Empty minimum/maximum/average aggregates remain unavailable. Percentage calculations require a positive readable maximum; nonfinite statistics or arithmetic results remain unavailable. Raw observations reuse the existing evaluation cache across all nine consumers.

The dedicated suite exercises all nine consumers beneath NOT and the actual rotation branch executor, where unavailable guards select neither arm and suppress fallthrough. It also covers raid subgroups, included/excluded pets, known zero counts, absent anchors, preserved callback arguments, exact coordinates, observation caching and field Help. `tests/rangecheck.lua` additionally runs the shipped public library against actual checker lists at successful/failed boundaries, including its synthetic zero floor. These are offline behavioral contracts; they are not native gameplay acceptance.

The shared Help paragraph now explains the conservative range/observation policy instead of its former blanket location warning. The primary generated [Unit API declaration](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) was also inspected: current party/raid membership results are boolean, while health/power observations carry explicit restriction metadata. Compatibility reads continue to accept the existing legacy 1/nil flag convention and do not make a client-wide availability claim.


## Distance Count observed snapshot contract

`DISTANCE_COUNT` measures the current `addon.unitsInRange` identity snapshot populated by nameplate events and tracked unit aliases. It does not enumerate every nearby unit or claim a complete world scan. Existing per-GUID entries and saved condition/source data remain unchanged. The original `rcf` binding retains its identity and positional returns for saved custom source; the new owned `Platform:GetRangeCheckBounds` and `Platform:GetNameplateMaxDistance` methods expose actual implementation bodies through the public source collector, without copied implementations.

Every live snapshot entry requires readable current existence, GUID and hostility. A proven vanished token or readable replacement GUID is excluded instead of counting a replacement before its own snapshot event. Hostility is read from the current token rather than stale stored metadata. As before, clearing Enemy means non-enemy units, including neutral units; it does not introduce an attackability or friendliness filter. Only matching live identities require range observations. Inclusive successful upper bounds establish membership; strict positive failed lower bounds establish exclusion, including equality. A synthetic zero floor cannot prove exclusion at radius zero. Any relevant uncertain, missing, malformed, restricted or failed observation invalidates the whole count, even alongside known matches. A known empty snapshot remains the legitimate count zero.

The configured nameplate distance is read through a protected modern C_CVar API or legacy GetCVar fallback. Missing, malformed, restricted or failed settings and requests beyond the current configured limit remain unavailable, including under NOT and branch guards. Authored validation checks finite nonnegative fields and an explicit boolean Enemy choice without observing client settings. The field editor preserves missing Enemy/distance data and disables its existing range slider when a readable positive setting is unavailable; it never writes a guessed setting into the draft. Help explains the snapshot boundary, non-enemy choice, interval evidence and unavailable result policy.

`tests/distance_count.lua` exercises the actual declaration and Platform adapter beneath NOT and the rotation branch executor, including known-false positive controls, token reuse/removal, stale hostility, partial counts, restricted identity/range values, missing native APIs, CVar failures, finite field validation and same-cycle observation caching. `tests/condition_inputs.lua` exercises the real native slider/editor contract. These checks do not substitute for supported-client gameplay/nameplate lifecycle acceptance. Snapshot producers in `main.lua` still directly read identity/hostility and concatenate names during refresh; their broader restricted-value and event lifecycle safety remains a separate core audit target, outside this condition-only slice.

The current primary [CVar API declaration](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua) explicitly permits a nil GetCVar string result. The primary [Unit API declaration](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) marks UnitGUID identity-restricted results and current boolean UnitExists/UnitIsEnemy returns. Compatibility observations retain the legacy 1/nil boolean convention. Interval strictness follows the shipped LibRangeCheck implementation and the public checker-list tests described above; neither a visibility setting nor a range bound is presented as an exact distance.


## First canonical implementation ownership migration

`Functions/values.lua` now owns the single actual implementations of `compare` and `isin`. Their positional arguments, comparison/warning behavior and false-valued map membership remain unchanged. `utils.lua` retains direct legacy addon aliases, and its historical source getter names forward to the same owned implementations. Public helper metadata declares the original `builtin:utils.lua:compare` and `builtin:utils.lua:isin` identities explicitly while presenting the actual `Functions.values` namespace. The registry contains one public identity per helper, with actual source bodies extracted from their owner.

Only Distance Count's validated comparison/operator callbacks adopt the qualified calls in this slice. A selected file-private namespace and explicit qualified dependency metadata let the collector verify actual helper identities and emit leaf bindings. Editable clones reconstruct that namespace through the existing private prelude, with no namespace globals or opaque captured module table. Other authored callbacks continue to use compatible addon APIs until their own bounded migration; this is not a corpus-wide namespace completion claim.

The importer accepts the exact historical namespace shapes for unchanged packaged helper requirements, including the existing pre-namespace shape. It reconstructs only declared previous namespace metadata; it does not ignore executable code, arguments, return documentation or dependency bindings in the hash. `tests/condition_namespaces.lua` pins both prior English helper hashes, tests real legacy custom calls and getter/ID preservation, clones real helpers and the migrated callback, rejects collector identity mismatches, and rejects changed bodies/docs/arguments/dependencies. AceGUI allocation, pooling, optional editor integration and custom-widget compatibility remain separate open lifecycle work.
