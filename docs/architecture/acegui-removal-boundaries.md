# Remaining AceGUI boundary audit

Source boundary audit after `6ba007c`, including the completed native item-list popup. No production files changed.

## Result

I found no additional ordinary shipped configuration path constructing Ace widgets after the item-list popup replacement. AceGUI is still loaded and required for compatibility registrations, optional module settings, and historical custom Fields UI/Help code. Removing its embed now would break those contracts even though the main UI is native.

## Traced entry points

| Entry point | Actual route | Remaining Ace boundary |
| --- | --- | --- |
| `/rm config` / settings launcher | `UI/config.lua:281` → `SelectSection` → `CreateRotationBrowser` or `OpenNativeSettings` | Every shipped tab has a native builder in `UI/settings_collections.lua:22`. `UI/config.lua:267` constructs an Ace group only after both native routes decline; optional `module:*` tabs intentionally take this branch. |
| Rotation selection | `UI/rotation_browser.lua:213` → `CreateRotationEditor` | Its Ace group at line 225 is the fallback only when the native factory is absent. A native construction failure displays its reason; it does **not** fall back to Ace. |
| Condition editing | `Options/conditional.lua:461` → `ShowConditionEditor` | The legacy Frame construction is below the native early return. Native field cards dispatch the registered `definition.widget`; built-in declarations now acquire RM primitives. Custom callbacks may deliberately acquire Ace widgets. |
| Spells/items/totems/glyphs | `Conditions/common.lua` → `UI/spell_search.lua:31` → `CreateConditionEditBox` | Strings such as `Spec_EditBox`, `Totem_EditBox`, and `Glyph_EditBox` select provider/filter semantics; they do not instantiate the corresponding old Ace widget. |
| Custom condition source editing | Native source pane → `condition_edit_box` | `UI/custom_condition_editor.lua:8` overrides the earlier legacy function from `Options/custom_condition.lua`; its native `LayoutCustomConditionEditor` also overrides the legacy implementation. |
| Built In reference/comparison/import | `UI/defaults.lua`, `UI/rotation_comparison.lua`, `UI/transfer.lua` | Native groups, links and measured viewports. The embedded legacy holder is itself an RM group; its host may still be an explicit Ace caller. |
| Recommendation preview | `UI/preview.lua:8` supplies `AddRecommendation` | The Ace Icon fallback at `main.lua:887` runs only for a non-native externally supplied/legacy `nextWindow`. The shipped preview always takes the native branch at line 883. |
| Item-list condition editing | `Widget_ItemWidget` → `item_list_popup` | `Options/itemset.lua:455` delegates to `OpenItemListPopup`, which uses the native form/ordered-row primitives and its own detached list draft. |

## Compatibility that remains intentional

- `UI/config.lua` / `Options/general.lua:1078`: optional modules register their own AceConfig applications through `SetupOptions`. Opening a module tab still calls `AceConfigDialog:Open` in an Ace host. Built-in Profiles/About no longer require that renderer, although their old option tables are still registered during setup.
- `UI/condition_widgets.lua`, `condition_layout.lua`, `condition_display.lua`, `condition_inputs.lua`, `condition_icon.lua`, `condition_position.lua`, `checkbox.lua`, `selector.lua`: RM factories own normal acquisition/release. Their Ace registrations and explicit legacy-pool transfer preserve saved/custom source compatibility. Advanced custom layout requests still use `AceGUI:GetLayout`.
- `Conditions/common.lua:8`: the named `RM-SpellField` Ace layout remains available to historical Fields UI code. The ordinary native layout calls the same RM geometry directly.
- `Widgets/help.lua`, `directional.lua`, `disable_inline.lua`: remaining in-repository constructors are reached from legacy `Options/*` renderers, or explicitly authored custom code. In particular, `DisablableInlineGroup` is used by the legacy conditional renderer; native condition cards do not use it.
- `Integrations/lua_workbench.lua:106` temporarily observes Ace allocations only while explicitly running/debugging user Fields UI/Help. This is a disposal compatibility hook, not an ordinary editor constructor.

## Safest next extraction order

1. **Extract live non-UI helpers before unloading Options files.**
   - `Options/conditional.lua:489–610`: condition catalog/query/dispatch functions (`findConditionGroup`, `listConditions`, `describeCondition`, `widgetCondition`) are used by the native picker/settings, validation and callback rendering. Keep `EditCondition` as the native forwarding API. Keep the compact `LayoutConditionFrame` forwarding contract used by historical field callbacks.
   - `Options/custom_condition.lua`: move `empty_condition`, template-header normalization / `PrepareCustomConditionEditorSource`, and `register_custom_condition` out of the old editor module. Startup (`main.lua:328`), validation, new drafts and native source editing still depend on these.
   - `Options/itemset.lua`: move `UpdateItemSetButtons` (startup/runtime and native Apply), `get_item_list` (ordinary condition picker), and the native `item_list_popup` forwarding API. Preserve `ItemSetInUse` if retaining its existing public compatibility API. Do not mix this mechanical extraction with changes to secure bar binding behavior.
   - `Options/general.lua:967`: native browser still requires `GetRotationEditorSpecs`. Move it independently of the legacy rotation renderer. Retain the native `CreatePreviewWindow` forwarding API if external compatibility is preserved.

2. **Separate native setup from the optional-module bridge.** `SetupOptions` still creates the native launcher, registers the Blizzard settings category and discovers module applications. Keep those operations. Profiles/About Ace option table registration can be isolated with the module renderer rather than loading the whole old General UI. Built-in tabs should fail explicitly if a native builder is absent instead of silently reviving their old renderers.

3. **Then stop loading old built-in renderers.** `Options/effects.lua`, `announce.lua`, `rotations.lua`, `conditions.lua` contain legacy rendering APIs without an ordinary native caller. After the helper extraction, the UI-heavy portions of General/Itemset/Custom Condition/Conditional can be excluded too. Keep any desired old public renderer APIs in a clearly named compatibility module rather than deleting them accidentally during extraction.

4. **Separate syntax/data services from widget wrappers before editing `embeds.xml`.**
   - `LibsAugment/FAIAP.lua` exports `addon.LuaSyntax` used by native `UI/lua_editor.lua:160`; its last section also registers legacy `LuaEditBox`. Keep the engine while isolating that registration.
   - `AceGUI-3.0-ItemLoader` is still used by `Core/reference_catalog.lua:58` for item discovery and by `main.lua:1589` for metadata-load updates. The loader is a data service, distinct from the old ItemPredictor widgets. Removing the entire item-editbox XML would remove this service too.
   - Native spell search uses `SpellCatalog`; the old spell/totem/spec/glyph predictor registrations are needed only for explicit historical widgets after this split.

5. **Decide compatibility policy before removing AceGUI itself.** Optional module AceConfig rendering, native-to-Ace pool/layout bridges, and explicitly selected source bindings still require it. AceDB, AceEvent, AceTimer, AceLocale, AceSerializer and AceComm are separate services; replacing GUI calls does not require replacing them.

## Verification to retain at each extraction

Keep the existing no-Ace allocation tests for built-in fields, settings pages, references, comparisons, previews and item-list popup. Also retain shipped-Ace mixed-parent/pool tests, historical custom Fields UI tests, and an optional module tab test. Run the generated-source compatibility gate after moving public/helper bodies so stable captured identities and dependencies remain valid.
