# Condition modernization audit

> Current contract: the user explicitly retired all AceGUI support. GUI packages, compatibility renderers/registrations, module AceConfig hosting and seven captured GUI library values are removed. Earlier compatibility checkpoints below are historical. Use the [native-only UI migration](acegui-removal-boundaries.md) for the supported API and current boundaries.


## Current source and compatibility contract

The reviewed inventory contains 116 Built In condition definitions across supported client/class combinations. Structural AND/OR/NOT nodes belong to the condition tree, rather than invented executable definitions. Authored modules under `Conditions/` remain the source of truth for executable callbacks; the offline source collector extracts their code and captures, and `tools/generate_builtin_sources.py --write` maintains source records and live getters. The game does not reconstruct source or inspect callback bytecode.

The Functions namespace system is already implemented. `Core/functions.lua` validates explicit qualified call paths, builds callback-private namespace tables at compilation, and resolves stable dependency identities. It does not publish ambient `Conditions`, `Platform.spells` or `utils` globals. A displayed namespace is therefore not evidence that the authored callback has migrated to a function module. Existing `addon` dot/colon methods and original captured bindings must remain available to saved custom definitions, imports and source duplicates.

The older unchecked progress items for the utility registry, readonly Built In source/duplicates, transitive dependency transfer and definition enable/disable describe work now implemented. Native client acceptance remains separate from those offline contracts. AceGUI removal is complete in a8711a9; historical compatibility checkpoints below describe the migration path, not supported GUI APIs. Current native-only boundaries override those earlier records.

## Current presentation audit follow-up

PROXIMITY's summary now preserves its accepted fractional distance and the empty-field editing placeholder. Its current text uses the new `number of %s members%s within %s yards` locale key. The old integer-format key remains available for archived custom callbacks; no saved source or external translation is rewritten. Range, membership, counts, evaluation and field behavior are unchanged.

POWER and POINT deficit summaries now display the positive amount that their evaluators compare. Their stored negative sentinel and all runtime observations remain unchanged. Fractional deficits, signed zero, localization, negation, current duplicates and archived source contracts have dedicated coverage.

FORM summaries and field choices now obtain spell names/icons through the existing platform spell adapter. GLYPH summaries use the existing item display adapter for their link. These changes retain live metadata reads, configured values, native form enumeration, class capture and existing placeholders; they add no negative cache. Evaluators, validators, schemas and historical private source identities remain unchanged. Dedicated current-source/duplicate tests cover readable, missing, failed and restricted metadata, alongside strict historical module inverses. Native appearance and optional client branches remain separate acceptance work.

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

The first sixteen shared fantasy families are retained as historical artwork. They are superseded in the active catalog by 128 distinct selected designs: one for each of the 116 Built In condition identities, nine category designs, and separate AND/OR/NOT glyphs. The second batch combines subjects with qualifiers so, for example, buff time and cast time have different silhouettes. `Data/artwork.lua` is generated from the selected artwork manifest; explicit saved category and custom icon choices keep their original values.

The selected condition/category textures ship at 128 and 64 pixels. Nine new transparent overlays ship at 256 and 128 pixels and are available through the shared Effects texture selector. Original PNGs, generation prompts, provenance and alpha/hash audit reports remain in Git under `Assets/Conditions/v2/` and `Assets/Overlays/`; contrasting-background contact sheets are reproducible with the documented exporter. The generated release manifest excludes source/QA artifacts and superseded textures. The 274 selected runtime TGA paths total approximately 12.81 MiB. The package name matches the case of the actual root `RotationMaster.toc`.

Root and independent reviewers inspected the small-size contact sheets and overlay composites. Coverage, distinct file hashes, alpha, selected paths and native-draft portability are checked offline. The unique-artwork batch is integrated and committed; native WoW rendering and a complete release-archive smoke test remain separate acceptance work.

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


## Combat and item canonical consumers; independent service ownership

Combat's sixteen declarations now select six explicit leaves from `Functions.values`, `Functions.presentation` and `Functions.cache`: 71 exact calls across 38 callbacks. Raw combat/threat/crowd-control/history APIs, all observation helpers, field layouts and captured historical values remain unchanged. Compiled source copies are compared to actual packaged declarations across the supported fixture inventory, including cache reuse, validators, positive/negated summaries, missing data and diagnostic errors.

All five Item declarations select three existing pure leaves with eleven exact calls: `Functions.values.isin`, `Functions.presentation.nullable` and `Functions.presentation.compareString`. Their evaluator callbacks, descriptor/Help private sources, widget bodies and adapter policies are unchanged. Actual clones preserve custom/named set identity, personal/global precedence, unavailable observations under NOT and shared evaluation caching. No new historical helper IDs or permissive hash aliases were invented.

Condition catalog/widget dispatch, custom template/registration and ItemSet runtime/query/popup services now load independently from their old Options renderers. The normal TOC excludes seven old ordinary renderers; explicit custom/module compatibility remains. Ordinary item-field vertical alignment is native, while advanced custom container/table options still take their requested compatibility route. See [AceGUI boundaries](acegui-removal-boundaries.md) for the remaining embeds and extension contracts.


## Aura and direct totem consumers

Buff/debuff declarations use 35 explicit pure helper calls across all eight declarations, with unchanged evaluation, rank/caster identity, field schemas, Help and widgets. Registered source clones are compared against modern/legacy observations, exact IDs and rank families, permanent/absent/restricted states, cache reuse and NOT/branch semantics. Historical captured color/Help identities remain pinned.

Totem declarations migrate nine direct callback calls through three existing canonical leaves. Their private observation, validation and specific-spell search helpers deliberately retain their exact old bodies, getters and all nine private hashes, including old addon helper dispatch. This is a bounded consumer migration; the three calls inside private helpers are not silently changed or accepted through a looser hash resolver. Actual clones retain omitted timestamp/GetTime behavior, nil tuple arity, slot ordering, rank identity, cached observations and unavailable states. Other condition families and private ownership migrations remain open.


## Spell callbacks and loader boundaries

All nine spell declarations now use37 direct canonical calls (29 pure helpers and eight cache calls) through five existing stable utils identities. Original captured color/Help records remain exact; native observation expressions and cache argument tuples are unchanged. Real source clones are compared against legacy-shaped callbacks, modern/legacy spell adapters, rank/name/book-slot auto-repeat identities, charges, history, missing/restricted/failed observations, NOT/branches, cache nil tuples and call-time defaults. Private helper bodies and generic dependency hash rules were not changed.

ItemLoader and SpellLoader load directly as metadata services, before explicit compatibility-only predictor/augmentation manifests. Tests use the actual pinned libraries with AceGUI lookup forbidden, verify no frames/scans on load, preserve existing LibStub table/minor identities, exercise lazy scanner/predictor acquire/release, and route real successful item-data events into native reference search. Current/restricted/failed native observations retain authority over the loader index. Vendor files and metadata policies remain unchanged; this packaging isolation does not claim removal of saved custom widget or optional module compatibility.

## Pet/any-spell and environment callbacks

Eight pet-spell and five any-spell declarations use43 and23 direct canonical calls respectively, with the same five stable helper identities as ordinary spell callbacks. The any-spell SpellData capture and both families' color/Help records retain their original identities. Rank selection, player-first/pet-fallback spell-book lookup, learned-pet gating, history ordering, raw native observation arguments and unavailable outcomes are unchanged. Real modern/legacy adapters and compiled legacy-shaped copies share cache observations, including nil tuple slots and receiver identity.

Level, PvP, instance and outdoors callbacks use21 direct canonical calls through eight leaves, adding the existing collections keys/deepcopy owners to values/presentation/cache. Validators, raw API expressions and widgets remain unchanged, including existing raw-error boundaries; this source migration does not claim to add missing environment capability adapters. Unit option copies remain shallow and detached, dropdown ordering remains value-sorted, and the two historical capture hashes stay pinned. No opaque Functions table is captured by editable source and no namespace global is installed.

## Cast/channel observation correction

`Platform/casting.lua` owns cast/channel observations. Its eight condition consumers no longer compare native milliseconds against a seconds field or read the channel spell ID as the interruptibility flag. The current audited Blizzard cast bar uses cast slot8 versus channel slot7 and divides timestamps by1000: [TBC source](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L348), [modern source](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L366). This does not invent a separate historical tuple fallback.

The adapter checks policy, query, API presence, failure and readability before using native values. Known absent units and readable nil names yield active=false. Missing/invalid/restricted unit or name data stays unavailable. An active readable name remains useful when only its optional timer or flag is unavailable: remainingSeconds/remainingReason and interruptible/interruptibleReason are independent. Unknown interruptibility stays unknown for that predicate; it is not inferred from a nullable flag. Remaining seconds are clamped to zero.

Consumers cache the complete record by adapter receiver, unit and cast/channel kind. New condition/function clones use the owned adapter and verified private source getters. Existing saved raw callback bodies, old addon helper APIs, validators, summaries, fields, Help and captured condition values are preserved. Tests cover real adapter observations, cache sharing, optional-field failures, NOT and both branch arms, supported/restricted policy boundaries, public helper cloning and exact old-source execution. Native client/gameplay acceptance remains separate.

## Shared settings roster viewport

Functions, Conditions/category maintenance, Effects, Item Sets, Announces and Profiles share complete filtered roster data with native viewport row/gap pools. ID-to-order and ID-to-visible-position maps replace full-list searches for each row. Unsaved markers follow bound IDs and indexed baseline/current contexts. Full filtered Ctrl suffixes include hidden and offscreen entries; a visible final gap still targets the full logical order.

Only visible rows plus overscan and initially carried drag sources own controls. Newly exposed carried suffix positions show passive gray placeholders. Repeated scrolling does not allocate the complete source tail or rebuild filtering/order maps. Recycled row/gap callbacks guard outer native wrappers as well as data callbacks, so stale drag scripts cannot suppress a later legitimate click. A failed bind retires the partial lease and can recover on refresh. Retained-row resize remeasures labels while preserving pending detail text, focus, caret and callbacks.

The same native fixture with100/200/1000 entries now opens with24 rows; ordered variants have23 gaps and459 fixture objects instead of1000 rows/1001 gaps/15079 objects. Opening identity calls are100/200/1000 rather than1000's1,001,000. These are fixture allocation/operation observations, not WoW frame-rate claims. Full4096-entry reachability, warm reuse and lifetime regressions are covered independently of native clipping/input acceptance.

## Conditional Built In source variants

ROLE has separate inspect-role and talent-role implementations. The original collector overwrote five callback bodies while traversing clients, so a Retail clone could execute Classic talent-role code with Retail fields. Both declarations now name their internal source variant; the generated catalog stores each complete callback set. Runtime source export selects the variant on the registered definition. Unknown or absent variant markers fail explicitly; ordinary unmarked conditions retain their existing record shape.

The collector rejects divergent unmarked declarations, mixed marked/unmarked variants, invalid names, conflicting callback sets under the same key and missing callbacks in an observed variant. Reversing the full registration inventory produces identical output. The audit found only ROLE's five callbacks conflicting in the reviewed inventory. Actual source clones match native role evaluation, validators, summaries, fields and widget structure for both branches. Existing custom code is untouched, private source IDs/hashes remain exact, and no runtime stack/bytecode inspection or copied implementation is used.

## Selector and rotation-browser viewport leases

Selectors and the rotation browser retain their complete result data while leasing nearby rows. They share the flat visible-range calculation with SettingsForm rosters. A native fixture with4096 selector choices warms15 row controls;1003 rotation results warm16. Repeated warmed traversal allocates no additional fixture objects. Browser scrolling/resizing preserves its existing editor, pending raw text, selection and source metadata; it does not rebuild the detail pane or full result index.

Opening, filtering, rebinding and navigation have distinct lifetime tokens. Stale row/search/update handlers cannot select an old entry, close a reopened selector or run a queued navigation after the owner/profile/spec/filter changes. A harmless saved-target rename refresh can still complete its already requested navigation. Partial bind failures retire their leases and recover on the next refresh.

Tag color children return an optional owner and receive a scoped color-session validity predicate. Their original swatch remains pinned while visible, independent of ordinary result-filter row leases. Explicit color Cancel restores the old color before the session retires; closing/reopening cannot leave a delayed callback able to mutate another entry. One stable child Hide hook retires the current session immediately without accumulating hooks. Native script-then-hook ordering is exercised explicitly in the fixture; client clipping/anchor appearance still needs native acceptance.

## Group and glyph observations

GROUP selects exactly one roster query through `Platform:GetGroupMembership`. A readable false raid result stays false instead of falling through to party membership. Public roster state is independent of enemy combat-data policy; unknown client families and missing, failed or unreadable APIs remain unavailable.

Glyph socket observations use the verified Wrath third return versus Cata/Mists fourth return, gated by published product, edition and interface layouts. Unsupported/future layouts do not query socket APIs. Locked/empty sockets differ from unknown observations. A definite positive match survives unrelated unknown slots, but an absent result requires a complete readable scan. Target item and occupied spell display metadata is guarded and cached only for the evaluation pass. Localized nonempty names remain the explicit matching mechanism: native item classification does not prove an item-to-glyph-spell identity.

`GetItemInfoInstant` and `GetGlyphItemInfo` normalize native classification independently of display loading. Glyph fields use the shared item provider with current-class filtering for searches, typed references, menu selection and item drops, including revalidation at commit. Current native failure cannot borrow stale loader classification. The condition retains its original captured class, private source identities and editing registration across clients even where live socket observation is unsupported. Original saved raw callback code is unchanged; new Built In duplicates use the guarded adapters. Tests include actual public-helper and condition source clones, all reviewed registration branches, unavailable observations under NOT/branches and next-pass metadata recovery.

## Completion of direct callback helper qualification

The remaining354 direct helper calls now use existing owning Functions leaves: Character94, Stats118, SpatialStats88 and54 across the other eight remaining families. Actual collector boundaries, named ROLE variants and tokenization verify there are no direct callback calls left to the nine migrated legacy helper names. Exact reverse-qualified callback source/parameters, private hashes, registration inventories and real source copies are tested. The namespace migration preserves raw observation/error boundaries rather than silently introducing new gameplay policies.

One callback still passes the old cache function to pcall, and ten references remain inside nine captured helper bodies. Their identities are unchanged; those ownership migrations need separate compatibility work. Old addon helper aliases remain valid for arbitrary saved source. Direct qualification does not imply removal of every legacy API name or completion of the client API audit.

A separately reproduced ECS integration bug is corrected in this batch: installed ExtendedCharacterStats5.5.2 declares Data.GetStatInfo(refName), while RM passed the data object as a receiver during deferred registration and both evaluators. All three calls now use its actual one-argument dot API; ECSLoader:ImportModule remains a method. The former fixture modeled the wrong convention and is corrected. Native and source-cloned callbacks share the same per-evaluation cache and deferred maps. Exceptions remain unavailable under NOT. No vendor code or generic source-hash policy changed.

The final DISTANCE passed-function callback reference is now qualified as well. Protected invocation retains the same cache, range function, unit argument, both returned bounds and availability reasons. Actual native/compiled/legacy-shaped consumers share the same observation, including a nil lower bound followed by a readable upper bound. No selected legacy helper references remain in callback bodies; the ten references within nine captured helpers are still tracked separately.

## Unit UI and protected cache implementation ownership

`UI/condition_unit.lua` now owns the single `Widget_UnitWidget` implementation. Its public method, live key-order dispatch, native field leases and historical Common binding identity/hash remain unchanged. Loading the owner creates no controls and performs no AceGUI lookup. Existing saved dependency bundles and new source clones execute the same body.

`Functions/cache.lua` owns `protectedRead`; Spatial keeps a direct local alias. An exact offline ownership declaration verifies the physical function, both live getters and its complete capture set before retaining the old Spatial binding ID, namespace, description and hash. The owner getter returns the original closure rather than an editable public table member. The body deliberately retains its live global `type`/`pcall` and legacy cache dispatch. This relocates two of the ten remaining compatibility references without pretending to remove them. Tuple arity, cached nil/false results, protected failure behavior and real proximity consumers are covered on both runtimes; malformed owners/getters/captures are rejected.

Generated localization now includes every packaged helper description, including private ownership records. A strict locale fixture loads the generated catalog and rejects missing description keys; runtime hash validation remains unchanged.

## Lazy host compatibility and shared allocation observation

Configuration, browser and Test/preview modules no longer acquire AceGUI while loading. Explicit legacy/module hosts still request the real compatibility library when constructed or released. Shared focus cleanup supports native inputs and optional legacy focus.

`UI/condition_observation.lua` brackets synchronous native and optional Ace allocations for both Test/preview and embedded LuaWorkbench debugging. It preserves the caller's protected-execution result tuple, including nil values, and restores observers and the previous Create function on callback/executor failures and nested scopes. This removes duplicated interception code without changing saved factory bodies, getters or hashes. Headless checks exercise native-only and actual shipped-Ace allocation/lifecycle paths; advanced saved layouts, arbitrary saved Ace widget code and optional module hosting still require their explicit compatibility distribution.

## Player movement observation boundary

`Platform:GetPlayerMovementObservation()` observes only the first return of
`GetUnitSpeed("player")`. It keeps the original actor and arguments, with no
new existence, form, target or vehicle queries. A readable finite nonnegative
speed is returned in a fresh record: zero is stationary, and positive
fractional speeds are valid. Missing, failed, restricted, nil or malformed
observations return `nil, reason` on supported probe policies. Other policies
remain unavailable without calling the native API.

The Built In MOVING evaluator caches that complete observation only within its
evaluation pass. Unavailable speed no longer satisfies either MOVING or its
negation, including when guarding a rotation branch. Known zero and positive
speeds retain their ordinary Boolean meanings. Current editable condition and
public helper copies share this boundary; saved raw Lua keeps its original
behavior. The movement tests pin every other combat callback and original
private helper identity, as well as fresh-pass recovery and exact native calls.
These checks do not establish native gameplay acceptance across WoW clients.

## Attackability observation boundary

`Platform:GetUnitAttackabilityObservation(unit)` retains the existing selected
unit, literal player attacker, and `UnitIsDead` predicate. It adds no ghost,
hostility, range, usability or vehicle-ownership interpretation. Readable false
existence returns false before attack/death queries; readable false
`UnitCanAttack("player", unit)` returns false without querying death. Otherwise
all required observations must be readable Booleans. A dead unit is false; a
non-dead unit the player can attack is true. Missing, failed, nil, restricted
or malformed required observations return `nil, reason`. Unsupported combat
data policies make no native calls.

ATTACKABLE caches the complete Boolean/reason tuple per evaluation pass.
Unknown data stays unknown beneath NOT, groups and branch guards. Built In,
editable condition copies and the public helper use the same implementation;
saved raw Lua keeps its historical semantics. Other combat callbacks,
including the movement repair, and original private identities remain exact.
Normalized combat-flag and attackability queries retain separate cache
owners; repeated copies of each share their respective observations.

Current Blizzard-generated API declarations establish non-nil Boolean
existence and attack results across the reviewed product branches. The
current Classic declarations omit `UnitIsDead`; UI truthiness checks alone
do not establish whether its false result is nil or false. The adapter uses
the conservative Boolean model, corroborated by current external API schemas,
and treats nil as unavailable. This explicit boundary and the headless tests
do not certify native return conventions on every supported build. Any
verified version-specific normalization belongs at this boundary rather than
in the generic Boolean condition engine.


## Shared combat, hostility and PvP flag boundary

`Platform:GetUnitFlagObservation(unit, kind)` supports exactly `combat`,
`enemy` and `pvp`. These retain `UnitAffectingCombat(unit)`,
`UnitIsEnemy("player", unit)` and `UnitIsPVP(unit)` respectively. A known absent
unit returns false before the selected flag API is required. Present units
require readable Boolean existence and flag observations. Required missing,
failed, restricted, nil or malformed data returns `nil, reason`; other kinds
are rejected before any native query. Unsupported combat data policies do not
query units. Hostility does not imply attackability or friendliness.

COMBAT, ENEMY and PVP now cache the complete result/reason tuple using the
exact unit and kind within one evaluation pass. False and unavailable tuples
stay distinct, copies share their observation, different kinds or units do
not share results, and subsequent passes can recover without a longterm cache.
Other callbacks, metadata, private identities and saved raw source remain
unchanged. The inverse proofs restore only the three exact approved bodies
and compare both complete modules with checkpoint `6b046b1`; earlier movement
and attackability proofs retain their original hashes.

Current primary declarations establish non-nil Boolean hostility and PvP
flags across the reviewed branches. Classic generated documents omit
`UnitAffectingCombat`, just as they omit `UnitIsDead`; they do not declare a
nil false result. The conservative Boolean model and external corroboration
remain explicit offline assumptions pending native client acceptance. This
adapter does not establish a general rule for metadata functions such as
`UnitClass` or zone PvP metadata, which have documented optional results.

## Ordered unit identity observation

`Platform:GetUnitIdentityObservation(unit, otherunit)` preserves ISSAME's two exact unit tokens and original query order: `UnitExists(unit)` followed by `UnitIsUnit(unit, otherunit)`. Readable false existence returns false without an identity query. No second-unit existence query, GUID comparison or inferred identity is added. Both input tokens are validated/readable before native access; required observations must be readable Booleans. Missing, failed, nil, restricted or malformed observations return `nil, reason`. Unsupported combat-data policies make no native calls.

Current ISSAME and its editable copies cache the complete result/reason tuple per evaluation pass and ordered token pair. Unknown identity no longer selects either branch or becomes true through NOT. Known true, false and first-unit absence keep their existing meanings. Raw saved callback source is unchanged. Tests restore only the exact new evaluator in memory to pin every other byte of Conditions/character.lua against a8711a9, alongside its four private source identities.

The pinned [Anniversary declaration](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) declares two required UnitTokens, RequiresComparableUnitTokens and a nonnil Boolean result. Era/Classic agree. [Retail](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) and Forever also mark restricted comparisons. Probe-only policy remains RM's conservative boundary; these declarations and headless tests do not establish native return/access acceptance. CLASS and other metadata conditions retain their distinct contracts and remain separate audit work.

## Player flags and consumed unit metadata

`Platform:GetPlayerFlagObservation(kind)` observes exactly one zero-argument player predicate: IsStealthed, HasFullControl or IsOutdoors. It does not add an existence query, infer outdoors from instance state, or infer usable abilities from control. Current STEALTHED/INCONTROL/OUTDOORS cache the complete Boolean/reason tuple per kind and evaluation pass. Missing, failed, nil, restricted or malformed required results stay unavailable through NOT and branch guards; readable false remains ordinary false. Probe-only policy is an RM choice. Pinned [Retail PlayerScript declarations](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua) and Forever declare nonnil Booleans; the inspected Classic generated documentation omits these APIs. Native false/nil acceptance therefore remains separate.

`Platform:GetUnitMetadataObservation(unit, kind)` preserves each consumed native field: CLASS reads UnitClass return two, CREATURE reads the localized UnitCreatureType name, and CLASSIFICATION reads UnitClassification. Readable false UnitExists returns known absence without requiring a metadata API. An unavailable consumed value stays unknown; unused localized class labels, numeric class IDs and creature IDs do not poison a readable consumed field. There is no inferred player class, GUID comparison, translation conversion or native-string whitelist. Whole tuples are cached per unit/kind/pass and recover on fresh passes.

The pinned [Anniversary Unit declarations](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) explicitly allow UnitClass to return nothing and declare the consumed class filename and creature name as nonnil when returned. A present unit with no class tuple is unknown. [Retail Unit declarations](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) and Forever also declare classification strings; classification declarations are omitted in the inspected Classic snapshots. Headless tests establish guarded behavior, not native access/return conventions.

Only six selected evaluator bodies change. Strict literal inverses preserve the complete prior Character/Combat/Misc module bytes and private source identities. Current condition and public helper copies use the guarded observations; raw saved callback bodies remain unchanged. CLASS_GROUP, ROLE, POINT, PET/PET_NAME and threat observations remain distinct audit work rather than being silently included.

## Remaining canonical helper consumers

Fifteen ordinary consumers now use their actual owners: six UI shallow copies, seven Core cache/comparison calls and two common operator-list key queries. Calls keep the original receiver: inventory cache/comparisons use the supplied self.Functions with self.Platform, while item-list observers and common widgets use the captured addon namespace. Operator order reads the current canonical keys function at configure time. No new local captures, fallback namespaces, proxy libraries or duplicate executable bodies are introduced.

Actual UI/runtime regressions poison the old aliases and verify nested shallow identity, ordered item selection, exact cache receiver/argument arity, nil/false reasons, refresh, detached inventory publication, private workspace history and stale-owner callbacks. Reversing each of the fifteen individual qualifications fails its regression. Reversing the exact expressions restores every affected product file to742794c. The nine Core/common changes leave collector metadata byte-identical.

The selected helper-family audit now has fifteen deliberately retained references: ten in saved-source-bound/live-dispatch helpers, three live presentation nullable calls and two live condition-catalog index calls. UnitWidget's current keys dispatch, protectedRead's current cache/type/pcall dispatch, presentation's current nullable/operator maps and catalog's current index dispatch have explicit compatibility tests. Private executable bodies, IDs, getters and import requirements remain intact. These are compatibility boundaries, not evidence that normal UI/runtime consumers still need the old alias. Every inventoried direct condition callback helper call and the DISTANCE passed cache reference is already canonical.


## Pet and threat continuation

The next bounded pet observation retains UnitExists("pet") and the actual GetUnitName("pet") wrapper, including its realm-display formatting and omitted optional argument. Presence-only checks do not require name metadata. An observed absent pet is false; a present pet with an unavailable required name remains unknown. The two modes have separate per-pass cache identities. Do not replace the display helper with UnitName or infer a usable pet from bars, health, range or abilities.

The THREAT observation preserves selected-unit existence followed by UnitIsEnemy("player", unit) and UnitThreatSituation("player", unit). Known absence or nonenemy short-circuits false. Required missing, failed, nil, restricted or malformed Boolean observations remain unknown. A successfully read nil threat result preserves the existing no-threat/no-match behavior. Native zero remains numeric and can satisfy the lowest configured threshold; other finite numbers retain the same comparison without new integer/range tightening. Nonfinite/nonnumber threat values are unavailable. THREAT_COUNT is a separate tracked snapshot predicate.

All five pinned primary Unit API declarations explicitly allow nil for UnitThreatSituation and declare Boolean existence/hostility. Nilability supports preserving the old optional-result handling; it does not by itself describe gameplay meaning. These contracts and the source/engine tests remain offline evidence, with actual client return/access acceptance separate.


## Instance membership and type readiness

`Platform:GetInstanceObservation()` reads one protected zero-argument IsInInstance tuple per observation. Required membership must be a readable Boolean. Known outside returns without interpreting the unused type. For known inside, the record contains a readable string instanceType or an instanceTypeReason; unavailable secondary data is never published as a fabricated mode. INSTANCE's Outside selection uses only membership, while inside mode comparisons require the type. Empty and future readable type strings stay distinct rather than becoming none/scenario. All selectors and current copies share one cached tuple within a pass; subsequent passes retry transient errors.

The pinned [Instance API declaration](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua) and four other reviewed branches declare nonnil Boolean membership and string type. Unlike combat-sensitive adapters, this public environment observation is allowed on every identified family, including Retail/Forever; unknown families remain unavailable. Readability checks still precede interpretation. Only the INSTANCE evaluator changes, with a strict complete-misc inverse and historical private/source identities preserved. ZONEPVP's valid empty classification and the separate selector model typo are not folded into this boundary.

## Four additional pure helper owners

The exact round/isint implementations now live in Functions.values, and starts_with/ends_with in Functions.text. utils keeps direct aliases for saved code. Rounding retains its floor-based halfway/decimal behavior; isint retains its existing numeric/string spelling rules, including its nonfinite spelling quirks, rather than gaining a new validation policy. Runtime local floor/type/tonumber/tostring captures retain their original choices. Prefix/suffix operations remain literal byte slices.

These four functions had no previous source IDs/getters. Their new canonical source records use their physical modules, with an actual captured floor value dependency; no invented old utils requirement or hash exemption is added. The established collector convention omits standard primitive captures, so editable isint copies do not claim frozen primitive identity under later global replacement. All existing function hashes, private bindings and other condition records remain unchanged.

Three ordinary callers now resolve the owning namespace: main retains a local starts_with snapshot, item cooldown rounding uses the supplied self.Functions.values, and the native single-item field resolves the current canonical isint. Curated spell-field/private totem/trend dispatches stay live through their existing addon APIs. Five direct authored rounding callbacks and the separate main isin initializer remain explicit next migration work. Physical helper extraction does not itself complete every namespace consumer.


## Zone PvP classification boundary

`Platform:GetZonePVPObservation()` prefers the callable documented C_PvP.GetZonePVPInfo dot API and uses the global helper only when that modern callable is absent. Unreadable capabilities are unavailable, and failures, malformed data and successful empty results never trigger another backend. One protected zero-argument call consumes only its first result. A successful nil or no returned values produces a known empty record; empty and future strings retain their exact values. Missing/failed/restricted/malformed observations stay unknown. ZONEPVP compares its original stored selection against that record and shares the sample across selectors/copies within a pass.

The pinned [PvP API declaration](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/PvpInfoDocumentation.lua) and four other reviewed branches explicitly permit no returned tuple. This public environment query is allowed on identified families, including Retail/Forever, with readability checks; unknown families remain unavailable. A successful unclassified result is preserved rather than inferred from missing capabilities. Raw saved callbacks and whole-misc/private identities remain protected by strict inverses. The selector model-clearing typo remains a distinct authoring repair.

## Active loss-of-control observations and school schema

`Platform:GetLossOfControlCount()` and `GetLossOfControlEvent(index, kind)` use the documented active count and one-index table APIs. The pinned [Anniversary declarations](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/LossOfControlDocumentation.lua) and four other current branches describe these methods and optional timing fields. No invented legacy API aliases or duration/deadline fallback are installed. Probe-only policy is RM's conservative combat boundary.

Counts and indices must be readable finite integers. Zero count is a known empty scan without row/bit requirements. RM's explicit 256-row resource budget returns unavailable beyond the limit; it is not claimed as a native maximum. Rows require only their selected subject: a readable type string or finite nonnegative integral school mask. Unused subject/display fields are not required. Finite timing, including negative/fractional values, is preserved; absent/failed/restricted/nonfinite timing is carried as a per-field reason and blocks only a selected event. Missing rows or required subjects remain unknown and recover on fresh passes.

LOC_TYPE preserves its existing equivalence map and first-selected-row comparison. LOC_BLOCKED now checks the bitmask result against zero, so an unrelated school no longer matches merely because Lua considers numeric zero truthy. Both scan lazily in index order and stop at the first selected event even when its comparison is false; later events do not become a maximum/any-match fallback. Protected field and bit-library failures remain transient unavailable results. Counts and per-kind/index rows cache complete observations within a pass.

LOC_BLOCKED's schema now declares school as number, matching its actual dropdown and validator. The previous string declaration caused Data.ValidateBody to reject the numeric value produced by its own UI; actual native-widget and storage-validation regressions prove the correction. No stored values are coerced. Current editable copies receive the repair, while saved raw source/schema remains unchanged. Strict full-combat inverses restore the two approved evaluator bodies and this one schema declaration, retaining private IDs/getters and every unrelated byte. FORM and other raw event/count APIs remain separate audit work.

## Five remaining rounding callback qualifications

Five authored evaluators now use the live addon.Functions.values.round owner: player, pet and any-spell cooldowns, rune cooldown and totem remaining time. Exact arithmetic arguments, three-place rounding, clamp/comparison order, time sources and native/cache calls stay unchanged. No leaf is added to private Functions maps, so unrelated captured helper identities are untouched. Main's isin initializer also snapshots its canonical owner once, preserving later live unit-map dispatch.

Actual runtime versus raw callback probes cover divergent supplied/current clocks, held or unavailable spell data, inactive totems, native argument arity, cache sharing and old saved source. Every individual inverse mutation fails its targeted test, and whole-file inverses match f537fe1. Private totem rounding, curated spell-field integer checks, trend helpers and the unused main integer capture remain deliberately separate live compatibility references.

## Current form observation and existing empty selector callbacks

FORM now reads the current player form through a probe-only Platform observation, preserving the exact zero-argument native call and its first result. Readable finite numeric values remain unchanged, including zero and fractional/signed values: the inspected primary UI establishes indexed use but does not declare a stricter native return domain. Required missing, failed, nil, restricted, malformed or nonfinite observations remain unavailable through NOT, groups and branch selection. No unit existence, current class, count, spell ID or optional boolean argument is added. The canonical per-pass cache retains complete nil/reason tuples and permits fresh-pass recovery.

Only FORM.evaluate changes. Its captured SHAMAN mapping, inclusive configured bounds, raw non-SHAMAN form count and existing label/icon/Fields UI metadata remain separate audit work. Current editable source copies and the public helper use the normalized boundary; historical raw source is preserved. An exact whole-module inverse retains private identities and every unrelated authored byte.

ZONEPVP and INSTANCE each correct one misspelled value field in their existing empty-selection callback. Selecting ZONEPVP's existing no-PvP row now clears the previous stored mode before formatting the summary. INSTANCE keeps its current list, which has no empty entry; its defensive empty callback receives the same narrow correction. No new option or nil-selector meaning is inferred. Real native-selector tests cover list ownership, status ordering, reopen, normal choices, recycled callback guards, current exported copies and unchanged historical source. Strict full-widget inverses preserve the prior source proofs without broad exclusions.


## Effective statistics and health forecasting

STAT now observes only the effective statistic in native return two: UnitStat(unit, selector) for the five authored attribute choices and UnitArmor(unit) for the armor choice. Known absence differs from missing, failed, restricted or invalid required values. Signed, fractional and zero finite values remain valid. Configured comparison-threshold validation is unchanged. ECS continues using its independently corrected one-argument dot API.

Time Until Health and Time Until Health Percentage now use the checked services described in [Health forecast observations](../health-forecasting.md). The new kernel bounds visited rows and accumulation bins, preserves ordinary ordered arithmetic and deliberate no-estimate/initialized-zero distinctions, and leaves published historical trend functions and saved raw sources untouched.

## Role observations

ROLE retains its existing product/expansion registration branches. Its inspection variant uses a probe-policy adapter with exact selected-unit existence, modern-first inspection capability selection and a legacy fallback only when that callable is absent. A selected capability's failure does not trigger another backend. A positive finite integral specialization ID leads to the existing one-argument GetSpecializationInfoByID call; role is consumed from return five, while unrelated tuple fields are ignored. No inspection request, class inference or extra actor query is added.

The talent variant keeps the exact live currentSpec argument to GetTalentGroupRole, including a readable nil forwarded as one argument. A complete primary declaration for that legacy API remains unavailable; no native group-domain guarantee or substitute API is invented. Both observers require a readable nonempty string role, preserve future strings exactly and keep missing/failed/restricted/malformed facts unavailable through negation and branches. These readiness and probe-policy choices are explicit RM policy. Retail/Forever denial remains separate from positive probe-policy fixture tests. Complete tuples share the existing per-condition cache, with fresh-pass recovery.

Current editable callbacks and helper copies receive these observations. Saved raw ROLE sources retain their old global dispatch and old sixth-result behavior. Strict two-evaluator and whole-character inverses protect all unrelated callbacks, schemas, Help, registration variants, retained class state and private source identities.

## Local combat-time arithmetic

TIME_IN_COMBAT reads the live stored combatStart and the evaluation timestamp already supplied by the engine. Readable nil start remains deliberate absence and skips the timestamp. Present timestamps and their derived difference must be readable finite numbers; signed, fractional and negative elapsed values remain exact. Unknown facts cannot authorize either branch or become a match through negation. No clock call, new policy gate, cache or producer change is added.

This bounded consumer change leaves threshold validation and outer clock/error handling unchanged. A nil returned by the event producer still has the existing absence representation; distinguishing producer failure requires a separate producer-state contract. Current editable source receives the guard, while archived raw code retains its prior behavior. Exact single-evaluator and whole-combat inverses protect every other callback and private identity.

## Combat-history timestamp readiness

Only `COMBAT_HISTORY_TIME.evaluate` changes. The existing event producer, history lookups and traversal, action/severity matching, configured threshold validation and evaluation-clock sampling retain their boundaries. A visited row requires readable finite evaluation and recorded timestamps, a readable table entry, and a readable finite elapsed result. Missing or empty history remains known false without consuming the clock; the first matching row still short-circuits. Finite signed, fractional and negative elapsed values retain their original comparisons.

The comparison function and operator are captured at their original expression boundary, before timestamp getters; the threshold is read after subtraction. This preserves ordinary getter ordering while invalid observations return unavailable through NOT, logical groups and both branch arms. The added readability checks have a cost; this repair is not a CPU optimization or a claim that native clocks normally produce nonfinite values. Historical raw source remains unchanged, while current Built In and editable copies use the repaired callback. Strict inverse proofs retain every parameter, binding, unrelated callback and private helper identity.

## Signed ExtendedCharacterStats percentages

`ECS_STAT_PCT.evaluate` accepts an optional leading minus in the existing numeric-prefix pattern. ExtendedCharacterStats 5.5.2's spell-haste provider applies Curse of Tongues modifiers and can legitimately return `-50%`, `-60%` or `-0.25%`; the unsigned parser made an otherwise valid less-than-zero condition unavailable. Provider behavior was reproduced from unchanged published source at commit `c48ccf8cab7ef4171209aa49fcdf49b07e83600c`.

Only that literal pattern changes. Existing unsigned integer/fraction/prefix/suffix acceptance, one-argument dot API, cache sharing, threshold multiplication and nonnegative configured-threshold validation retain their contracts. Current Built In and newly created editable copies receive the repair; archived raw source retains its original parser. Strict complete-evaluator and whole-module inverses preserve all other callbacks, private identities, bindings, fields and registration behavior.

## Count-based spell history scans

`SPELL_HISTORY` and `PETSPELL_HISTORY` now inspect later history rows when an earlier row does not satisfy the count predicate. The existing Help explicitly treats repeated casts separately, so any qualifying occurrence can match. Actual player/pet cast event handlers reproduce the prior first-row-only failure, including incorrect NOT and branch outcomes.

The shared history producer, traversal order, player rank resolution, pet spell-known/cache gate and configured fields retain their behavior. The scan returns the comparison's actual first non-false result, preserving legacy nil and other truthy return semantics; it does not coerce them or change the engine's interpretation. Only the two count evaluators change. Time-based history callbacks and observation-readiness contracts remain separate audit work. Current editable copies receive the repaired code; archived raw source stays unchanged, with strict whole-module and private-identity preservation checks.

## Elapsed-time spell history scans

`SPELL_HISTORY_TIME` and `PETSPELL_HISTORY_TIME` now continue past false comparisons to find a qualifying retained occurrence, including an older repeated cast. Actual player and pet event producers exercise the scan, logical groups, negation and branch outcomes. The callbacks continue to consume the supplied `evalStart`; empty and unrelated history do not introduce a native clock read or consume unrelated timestamps.

Only the two evaluator expressions change. Exact-rank resolution, pet known-state caching, traversal order, threshold schema and comparison/getter order remain unchanged. The first non-false comparison result is returned without coercing nil or other truthy values, preserving the existing engine contract. Timestamp readiness is separate audit work; this repair does not claim to validate every historical observation. Current editable copies receive the code; saved raw sources remain unchanged. Strict complete-module inverses and a structured generated-catalog comparison protect unrelated code, fields, bindings, signatures and private identities.
