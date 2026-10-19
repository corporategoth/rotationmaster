# Remaining AceGUI boundaries

## Normal page loading

The TOC no longer loads the seven old ordinary page renderers in `Options/general.lua`, `effects.lua`, `announce.lua`, `itemset.lua`, `rotations.lua`, `custom_condition.lua` and `conditions.lua`. Their files remain available for explicit compatibility callers and regression fixtures. This does not remove AceDB, AceEvent, AceTimer, AceLocale, serialization or communication services.

Live services have independent owners:

| Owner | Contract |
| --- | --- |
| `Core/condition_catalog.lua` | Condition group/catalog queries, four-result descriptions and widget callback dispatch. Original registry identities, ordering/hiding quirks and callback arguments remain. |
| `Core/custom_condition_services.lua` | Templates, generated-header normalization and modern/legacy registration. The old renderer reuses an internal compiler/signature bridge without resetting services. |
| `Core/itemset_services.lua` | Secure ItemSet macro buttons, use queries, named-set lists and the native popup forwarding API. Original captured APIs, list/priority semantics and secure-button policy remain. |
| `UI/settings_setup.lua` | Native launcher/category registration, specialization metadata, preview forwarding and optional module discovery. Preserves profile/about option metadata and profile-switch lifecycle. |

Every shipped ordinary tab opens the native browser or native settings forms. A missing native page displays an explicit native error surface; it does not revive an unloaded renderer. Rotation selection similarly reports a missing native editor. Explicit externally supplied legacy page builders remain an opt-in compatibility path.

Configured `module:*` applications have a separate `BuildModuleConfigurationPane` bridge to AceConfigDialog. The module display name resolves to its registered application ID. Only this known module host or an explicitly supplied compatibility renderer allocates the shell's Ace group. Shell/browser pane release still clears Ace focus because native condition fields can contain explicitly authored historical Ace children.

## Ordinary field and auxiliary windows

RM owns normal field allocation, leases, pooling, callbacks and geometry. Reference providers, item-list drafts, Test/Run/Debug surfaces, Built In references, comparisons and import previews use native groups and measured viewports. The native recommendation preview implements `AddRecommendation`; main's old Icon fallback is only for an externally supplied legacy preview. Main no longer looks up AceGUI at registration or during native recommendations; only that explicit fallback resolves its widget library.

Numeric Table fields support simple top/middle/bottom vertical cell alignment without Ace layout lookup. Rows are measured before positioning, including partial rows and changing child heights. Container-level alignment/spacing, nonnumeric columns, row/column spans, arbitrary align callbacks and other advanced custom layouts retain the explicit compatibility route. Actual shipped ItemWidget tests forbid both Ace construction and GetLayout; real Ace tests retain the advanced route and its spacing/alignment semantics.

`UI/condition_entrypoints.lua` owns the native `EditCondition` and compact `LayoutConditionFrame` dispatch without looking up AceGUI. `Options/conditional.lua` remains loaded as an inert compatibility factory: its historical renderer initializes once, on an actual legacy route, preserving registration-time registry and utility captures. Its old full renderer and `Widgets/help.lua`, `directional.lua`, `disable_inline.lua` remain available to historical custom code. Live catalog/query/dispatch no longer depends on initializing this renderer.

## Dependencies that still prevent removing the AceGUI embed

- Saved custom Fields UI/Help can deliberately request Ace controls, source bindings and arbitrary registered layouts. Native containers accept those children, and shared disposal observers cover unattached allocations during errors/debugger pauses.
- Optional modules can register AceConfig applications. Removing their configuration bridge would change a public extension contract.
- Historical RM widget registrations preserve original saved-source identities and mixed native/Ace pool transfer. The normal factories acquire RM widgets directly; the registrations are compatibility entry points.
- Native Icon, PositionPad and display implementations no longer look up or register with AceGUI. `UI/native_widget_compat.lua` separately registers their five historical names using the original constructor getters, versions and legacy arguments. It remains loaded for compatibility; constructors, public factories and saved private source identities were not copied or replaced.
- Selector, checkbox and condition input implementations also load/acquire without Ace lookups or registrations. `UI/native_field_compat.lua` separately registers their four historical names with the original constructors, argument tuples, versions and order. Saved source that captures AceGUI resolves the actual current library lazily; missing, proxy or foreign values are rejected by the collector. Existing constructor/factory/value source hashes remain exact. This bridge remains loaded.
- Common, Combat and Talent condition definitions no longer import AceGUI. Their three retained saved-source value IDs use the same strict lazy real-library getter as native fields. `UI/spell_field_compat.lua`, loaded immediately after Common, owns the historical RM-SpellField layout registration with its original forwarding callback. Native definitions/factories load with Ace lookup and layout registration forbidden; historical library values retain their original hashes. The native Group implementation still captures the real library for advanced custom layouts and remains a separate extraction boundary.
- `LibsAugment/FAIAP.lua` now exports the native syntax engine without any Ace lookup. Its unchanged historical LuaEditBox constructor lives in the separately loaded `FAIAP-AceGUI.lua` compatibility bridge and shares the same engine. The bridge remains loaded for existing custom sources.
- `AceGUI-3.0-ItemLoader` supplies item discovery and metadata callbacks used by Core/reference_catalog and main. It is a data service despite its library name. RM loads the two unchanged loader scripts directly. The root `reference-predictors-compat.xml` and `reference-predictor-augments-compat.xml` manifests retain predictor and augmentation registrations separately and in their original order. Both compatibility manifests remain loaded; no vendor file, LibStub name, widget version or constructor was changed.
- Spell/spec/totem/glyph, ActionSlot and SharedMedia widget registrations may be explicitly requested by historical source or optional modules. Their names are not evidence that an ordinary native control uses them.

## Verification

Run `python3 tools/check`, including source catalog/hash compatibility, no-Ace normal field/settings/window allocation, real Ace mixed-parent/pool/layout tests, custom source/Test/debug disposal, native popup drafts, secure ItemSet service behavior and configured module-host tests. Fixture checks establish source/runtime contracts; native input, layering and gameplay acceptance still require WoW.
