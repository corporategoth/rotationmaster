# Condition modernization audit

## Current source and compatibility contract

The reviewed inventory contains 116 Built In condition definitions across supported client/class combinations. Structural AND/OR/NOT nodes belong to the condition tree, rather than invented executable definitions. Authored modules under `Conditions/` remain the source of truth for executable callbacks; the offline source collector extracts their code and captures, and `tools/generate_builtin_sources.py --write` maintains source records and live getters. The game does not reconstruct source or inspect callback bytecode.

The Functions namespace system is already implemented. `Core/functions.lua` validates explicit qualified call paths, builds callback-private namespace tables at compilation, and resolves stable dependency identities. It does not publish ambient `Conditions`, `Platform.spells` or `utils` globals. A displayed namespace is therefore not evidence that the authored callback has migrated to a function module. Existing `addon` dot/colon methods and original captured bindings must remain available to saved custom definitions, imports and source duplicates.

The older unchecked progress items for the utility registry, readonly Built In source/duplicates, transitive dependency transfer and definition enable/disable describe work now implemented. Native client acceptance remains separate from those offline contracts. The AceGUI removal checklist is still real.

## Implemented audit corrections

* Distance field commits now notify their owning editor through the same status/proxy synchronization used by sibling fields. Previously the field changed a detached value without updating the editor session.
* Missing, failed, malformed and restricted Distance range observations now return explicit unavailable reasons. Legacy nil-as-false compatibility previously allowed NOT to turn a missing range into a match. Readable intervals retain the documented maximum-bound comparison.
* Native condition inputs inspect ancestor release flags before committing pending text. AceGUI hides a root before recursively releasing children, so a focus-loss callback could otherwise commit an abandoned child edit.
* RM owns ordinary List, numeric Table and responsive spell-field geometry in `UI/condition_layout.lua`. Shared Built In field groups, compact condition-editor roots and Test/preview roots use this container. Ordinary leases now belong to RM; the container retains historical Ace registrations and explicitly accepts legacy custom child widgets. Saved callbacks requesting other registered layouts or complex table cells retain a compatibility path.
* Native group pooling clears failed-layout state; legacy custom layout height changes reach native parents. A ten-level native group chain previously performed 1,023 layout passes because each child width change was followed by a second explicit layout; the reviewed fix bounds that traversal to the group depth.
* Twelve condition modules no longer load an unused AceGUI local. Remaining module-local Ace bindings in common, combat and talent are retained for historical source compatibility; their ordinary Icon/Label fields now use native primitives.

Focused regressions exercise actual Distance declarations, engine behavior beneath NOT, shipped AceGUI pooling/widget methods, real native field controls and the existing condition/Test adapters. Frame fixtures establish offline contracts; they do not establish native input, visual layout or client acceptance.

## Native bridge removal map

| Owner | Current responsibility | Next coherent boundary |
| --- | --- | --- |
| `UI/condition_layout.lua` | RM geometry and lifecycle; explicit custom-layout fallback | Native support for remaining useful table-cell geometry, then isolated arbitrary legacy layouts. |
| `UI/condition_inputs.lua`, `UI/checkbox.lua`, `UI/selector.lua`, `UI/condition_widgets.lua` | RM frames, callback leases, userdata, size and pools; bridge for historical Ace leases | Continue preserving saved source and mixed-parent ownership while retiring ordinary external allocations. |
| `UI/spell_search.lua`, `UI/spell_icon.lua`, `UI/condition_icon.lua` | RM reference inputs/icons, provider identity, filtering, cursor drops, metadata retries and cleanup | Reference/default/comparison views now use these primitives; preserve exact links and stale-owner cleanup. |
| `Conditions/common.lua` | Native ordinary field controls, historical layout binding and leased native item-list popup entry point | Extract remaining live Options runtime services while retaining historical source APIs. |
| `Help/common.lua`, `UI/condition_display.lua` | Native groups, wrapping labels, pictures and buttons with owned leases | Native reference cards and themed report/default/comparison windows reuse these primitives; preserve custom help API contracts. |
| `Conditions/combat.lua`, `Conditions/talent.lua` | Native ordinary Icon/Label fields; preserved old Ace source getters | Continue the API/condition correctness audit without changing observation semantics. |
| `UI/condition_editor.lua`, `UI/condition_source_preview.lua`, `Integrations/lua_workbench.lua` | RM roots and native allocation observation, explicit legacy allocation guards | Retain guards for arbitrary saved custom allocations; no factory monkeypatching for native calls. |
| Legacy `Options/*`, `Widgets/*`, embedded libraries | Existing APIs still callable by saved source, optional module or compatibility entry points | Audit actual callers and move runtime helpers before removing code or TOC dependencies. |

The native migrations remove ordinary condition layout, field, reference and Help allocation ownership from AceGUI. It does not remove the AceGUI dependency or imply that legacy custom Lua can lose access to it.

## Function module migration map

The largest authored `addon` references are nullable formatting, cached observations, unit/operator maps, validation lookups and comparison functions. The next migration should move one family end to end, rather than rewrite all textual `addon` references.

| Proposed authored module | Existing implementations | Required migration evidence |
| --- | --- | --- |
| Pure value/format helpers | `Functions/values.lua`: compare/isin; `Functions/presentation.lua`: nullable/nullable_value/compareString/playerize; `Functions/text.lua`: split/wrap/trim; `Functions/collections.lua`: nine collection helpers; remaining `utils.lua` helpers | Identical positional arguments/returns; preserved nil tuples; stable original IDs and compatibility wrappers. |
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


## Canonical presentation implementation ownership

`Functions/presentation.lua` owns the single actual bodies for `nullable`, `nullable_value`, `compareString` and `playerize`. Existing addon APIs are direct aliases, and historical utils source getter names remain available. The two previously public helpers retain their exact `builtin:utils.lua:nullable` and `builtin:utils.lua:nullable_value` identities, old source bodies, documentation and captured `builtin:utils.lua:color` dependency. The collector verifies the existing color getter's actual identity before retaining that reference. The two newly public helpers use documented canonical calls and API-shaped stable identities; no earlier packaged source/hash history is invented for them.

Shared colors/localization and false/nil formatting retain their original behavior. The positive operator table remains captured, while negative labels are read from the live addon map. Internal `addon.nullable` calls deliberately retain their live legacy dispatch rather than freezing or silently rewriting saved-source semantics. All four spatial summary callbacks now use the actual canonical presentation functions through selected private qualified bindings. Condition evaluation, target membership and summary wording remain unchanged.

`tests/presentation_functions.lua` pins both historical nullable hashes and their captured color dependency, rejects mismatched captured-value getters, checks localization/color state, false/nil and malformed maps, every operator/primary wording form, live legacy dispatch, real helper clones and registered condition summaries with fixed baseline wording. Other authored modules still need qualified call migration, and cache/collection implementations remain in utils. Full AceGUI lifecycle removal continues independently; none of these namespace steps require native WoW access to proceed with source, ownership and fixture verification.


## Native condition widget lifecycle ownership

The five ordinary RM field factories (group, text, numeric slider, checkbox and selector) now allocate, acquire, size, dispatch callbacks, clear userdata and recycle through `UI/condition_widgets.lua`. Editor roots release through the same dispatcher. Callback leases reject stale callbacks after reuse. Recursive release marks the ancestor before hiding/blur, detaches the child list, releases every sibling after an error, and quarantines failed objects instead of returning partial state to the native pool.

Historical Ace widget registrations remain for saved custom source and external containers. Direct Ace release transfers a native lease to the compatibility owner; inactive compatibility candidates are reclaimed only through Ace's public Create call, avoiding double pooling and abandoned frames. Inherited `:Release()` and the three historic captured Ace library IDs remain available to old cloned factory bodies. Legacy release callbacks retain their protected dispatch contract. No global Ace pool patch or pool-internal inspection is used.

Synchronous Test/Run/Debug execution subscribes to a central acquisition observer, alongside tracking legacy Ace creation. Captured native factory references and controls not yet attached to a parent are therefore owned and released on failure. Observers and temporary legacy hooks are restored before a paused debugger yields. Native editor field callbacks also check their originating pane lifetime before touching detached values.

The real shipped Ace mixed-parent regression repeats 100 opens, verifies bounded reuse and no blur commit, and checks reentrant acquisition, thrown release callbacks, sibling cleanup and stale leases. Existing condition editor, Test, debugger and saved factory clone regressions exercise the native integration. Native reference EditBox/Icon and Help Label/Button primitives now share that lifecycle. Common item-set, shapeshift and talent fields use them too. Old Options/Widgets and default/reference/comparison entry points remain separate work; this is not removal of the AceGUI embed or of arbitrary saved custom Ace code. Native visuals and client interaction still require WoW acceptance.


## Weapon canonical helper consumers

Weapon duration/stack and swing validators, comparisons and summaries now call the actual owned `Functions.values` and `Functions.presentation` helpers through selected private qualified bindings. This is a consumer migration of existing implementations and stable IDs; no native weapon observation, selected-hand logic, cache call, swing history or client registration guard changes. The `enchantObservation`, `numericObservation` and `swingSpeed` source hashes/getter identities remain exact.

The extended weapon suite compares real registered clones across every reviewed client inventory branch, preserving both hand choices, present/absent states, fixed positive and negated summary wording, failed/restricted/missing observations and original API cache reuse. It pins the three existing observation helper source hashes and verifies exported canonical leaf dependencies without namespace globals. Native observation availability remains a separate runtime contract; these source/clone checks do not claim gameplay acceptance. The remaining legacy consumer inventory is still being migrated family by family.


## Shared native documentation and image primitives

`UI/condition_icon.lua` and `UI/condition_display.lua` supply reusable native image, wrapping-label and button leases. `Help/common.lua` retains its wording, color suffix, font/texture-coordinate options, picture/table/indent/gap contracts while allocating through RM groups and these primitives. Ordinary spell/item action icons keep their adapter-owned exact identity, cursor, metadata and tooltip contracts. Core callback documentation identifies the supplied native condition container. The new helpers expose typed documentation and actual browsable/duplicatable bodies through the same public source collector.

Text layout caches the last requested text height rather than comparing it exactly to quantized native frame height. Reentrant measurement is guarded and unlocks after failure. A shipped-Ace List fixture with independent backing geometry and a fractional height difference verifies bounded layout while content grows/shrinks. Repeated mixed-parent recycling, fonts, disabled state, stale clicks/tooltip scripts, orphan cleanup and ordinary no-Ace allocation are covered offline. This does not remove compatibility registrations or the shipped Ace dependency while older entry points remain callable.


## Canonical text implementation ownership

`Functions/text.lua` owns the single implementations of `split`, `wrap` and `trim`; the original addon APIs are direct aliases. Typed public calls use `Functions.text.*` while all three historical `builtin:utils.lua:*` identities and source getter names remain available. The bodies, signatures, descriptions and argument/return contracts retain their exact earlier form. `split` keeps the original string table through `builtin:utils.lua:string`, verified against its actual getter by the collector. No new duplicate helper identities or namespace globals are installed.

The text suite pins all three historical hashes, runs actual editable clones and imports old-hash dependency bundles. Namespace compatibility reconstructs only the declared old `utils` namespace: changes to code, documentation, argument/return contracts or captured string identity still fail. Character-class separator behavior, omitted empty fields, wrapping whitespace/long words/default width, trimming internal whitespace and single-result contracts remain unchanged. No current Built In callback directly consumed these three helpers, so this slice moves actual implementation ownership without inventing callback rewrites. Cache/collection ownership and remaining authored consumer conversions continue separately; Ace compatibility removal is also still open.


## Canonical collection implementation ownership

`Functions/collections.lua` owns the nine original bodies for `keys`, `spairs`, `tomap`, `index`, `tablelength`, `multiinsert`, `cleanArray`, `deepcopy` and `compareArray`. All original signatures and bodies were compared byte-for-byte against their prior utils implementations. Direct addon aliases preserve existing saved consumers. These nine helpers previously had neither public registry records nor utils getters; new public IDs derive from the actual owning module, without invented historical IDs or namespace-hash compatibility. Captured `pairs` and `tostring` retain their original function values. No runtime callback substitutions accompany this step.

The collection suite first ran eight behavior baselines against the original bodies while ownership/clone checks failed, then passed eleven tests with the actual module and generated public sources. Checks cover value-sorted keys, comparator arguments, snapshotted keys with live iterator values, the legacy false-key stopping behavior, stringified key collisions, nil/false/sparse entries, indexed insertion and no-result mutation, except/invert selection, shallow copy identity and dropped metatables, and both-direction Lua indexing/equality behavior including metamethods. Actual editable clones execute all nine contracts. Dependency imports accept current sources and reject an invented old utils namespace. Cache helper ownership and remaining authored consumers still require separate migration; Ace removal remains independent open work.


## Native reference and comparison windows

Built In reference/options, rotation comparisons and import previews now allocate ordinary groups, labels, interactive spell identities, checkboxes and selectors through RM pools. Shared native measured-group viewports own the attached root lease and detach it before recycling. A stale viewport cannot resize/release another owner’s recycled root or restore an earlier LayoutFinished callback. Rendered children acquire parent ownership before fallible nested rendering, and failed standalone reference/import builds release partial roots.

Reference spell links use the same native wrapping text primitive with an optional leading image and lease-protected hover/click callbacks. Read-only cards restore pooled group methods and hide their decoration on release. The default compatibility entry point still supports shipped Ace parents through an explicit native viewport adapter; arbitrary legacy parent layouts remain isolated. The cooldown Help position illustration uses the same shared directional pad as other native controls.

Comparison/default windows cache their native shells, retain moved coordinates and replace pooled contents on reopen. Closed/replaced-profile callbacks cannot change preferences, open exports or act on a new graph. A confirmed clone closes the old source window and opens a fresh custom editor. Text diagnostic reports share the themed transfer shell, copy selection, measured scroll extent and native caret-to-page scrolling. Rotation models and source data remain immutable. These checks establish offline ownership and behavior; native visual acceptance remains open.


## Native item-list editor and qualified talent callbacks

The condition/action item-list popup now uses the same native compact ordered rows, reference providers, history/footer and scoped Help as the settings pages. It edits a detached local array; Apply verifies the owner and unchanged original, preserves target table identity, writes once and notifies once. Discard writes nothing. Dirty close offers Apply/Discard/Cancel. The parent condition/action keeps its own Apply boundary. All input paths honor the caller predicate and inventory provider, and invalid drops keep the cursor. Queued release cannot commit a pending list through OnHide.

Originating fields guard profile, group lease, current selected reference and named-set record/array identity. A child return is tied to the same active condition session, so rebuilding fields during Apply can still resume that parent; another session or database is never reopened. Window footer controls sit above the common status bar. The old six-argument item_list_popup entry point forwards to this native owner; the optional seventh argument carries a lifetime predicate.

Talent rank/tree-points valid/evaluate/print callbacks now use four verified private Functions.values/presentation leaves. The eight call replacements preserve all observation helpers, fields, native controls, historical Ace source binding and positional contracts. Extracted editable clones are compared with their packaged definitions across the existing client inventory, including unavailable observations under NOT, zero points, respec and shared per-pass cache behavior. The primary-tree callback remains an unchanged control.

## Cache closure ownership

Functions/cache.lua owns the unchanged cache implementation and its complete native closure: counters, nil-argument/result sentinels, internal dispatcher, result packer and ReportCacheStats. Legacy addon methods are direct aliases. The offline ownership manifest verifies actual physical source functions and both old/new live getters before retaining the exact private utils binding identities, namespaces, descriptions and hashes. Public wrapper calls present Functions.cache while retaining declared utils-only namespace hash compatibility. Generic runtime binding resolution and hash comparison are unchanged.

Tests mix legacy, namespaced and compiled public wrappers against one cache, verify tuple/nil/retry semantics, observe counters advancing/resetting through both getter routes, and reject wrong private-function identities, missing capture declarations and swapped sentinels. Compiled private counter captures retain their pre-existing value semantics; this does not create writable references to native numeric upvalue cells. Legacy addon aliases retain verified hover/navigation documentation; completion continues to offer canonical names rather than duplicate compatibility entries. Remaining Ace boundaries and extraction order are documented in acegui-removal-boundaries.md.
