# Optional integration status

The Integrations page combines editor/provider preferences with a fixed inventory of supported addons. Aligned RM cards are grouped into Lua editors, condition data, recommendation notifications, quest callbacks and action bars. Their columns show Addon, Version, Description/status and the controls that RM actually supports; settings stay under the relevant card. Addons that are not loaded remain listed; a detected version does not imply the addon is loaded. Missing metadata is not proof that an addon is uninstalled.

The inventory covers LuaWorkbench editing and detection of WowLua, ExtendedCharacterStats and MobInfo2 conditions, WeakAuras notifications, Questie callbacks and the action-bar providers recognized by RM. Bundled libraries are implementation dependencies rather than install suggestions. Arbitrary user extension modules have no reliable addon identity and are not fabricated as inventory rows.

Loaded and connected are separate observations. The catalog uses existing RM editor/condition availability and the cached Questie service status when it can establish a connection. Other loaded providers remain connection-unconfirmed. Rows do not construct editors, query gameplay values, invoke provider discovery or install/load another addon. Reading the page performs bounded addon loading/version metadata queries; loading the catalog itself does no work. Labels and versions escape native markup and controls and retain complete UTF-8 characters within their display limits.

## Editor enablement and selection

The editor cards keep enabled and selected separate. None is always available and persists the existing `profile.lua_editor="plain"` choice. Automatic is a selection mode, not an addon: it chooses an enabled registered provider, then enabled built-in highlighting, otherwise plain. An enabled available editor can be selected directly even when another editor is selected. Disabling the selected editor stages None; enabling it does not select it. Missing providers remain visible with status rather than becoming selectable.

The optional `profile.lua_editor_disabled` map is closed to true values for the known `native` and `LuaWorkbench` IDs. An absent or empty map preserves existing enabled defaults. Registered custom editor extensions keep their selection and Automatic contract without fabricated persisted enable switches. WowLua is detection-only. Integrations without implemented preferences remain status-only rather than receiving fake Enable controls. Status-only does not imply data-only passivity: ExtendedCharacterStats, MobInfo2 and WeakAuras invoke provider APIs.

Both fields use the existing Integrations Apply/Discard transaction. Conflicts refuse partial publication, profile copy/import retain the map, and reset returns to enabled defaults. Apply affects the next source-editor opening; it does not forcibly replace a control already open. The bundled baseline choices, highlighting preference and line numbers live in a separate Editor settings area without Addon/Version cards, and Questie retains its own independent preference and receipt details.

All added resolution work is on editor opening or provider listing. The page creates no gameplay subscription, timer or polling loop and does not change recommendation evaluation or CPU profiling. Its pooled controls retain native form owner/drawing guards; offline layout tests do not claim actual-client pixel acceptance.

## Questie callbacks

`addon.Integrations.NewQuestie(options)` is an original consumer of the documented public Questie API. RM retains one private service for its lifetime. `profile.questie_enabled` defaults to false and follows the existing settings Apply/Discard transaction, profile copy/reset and import rules. The closed profile transport schema accepts only a Boolean preference.

A dedicated ADDON_LOADED observer is registered only while the saved preference is enabled. It survives rotation event cleanup and refreshes when Questie loads later; there is no timer or background polling. An explicit Refresh action can check current provider availability. Equally enabled profiles share recent player-provider observations; switching to a disabled preference retires callbacks and receipts. No observation is assigned to a rotation or a profile.

Readiness and update callbacks use the upstream dot-call contract. Because upstream has no unsubscribe handle, registrations use guarded lifetime trampolines with logical retirement. Replaced APIs, stale callbacks, failed registrations and reentrant disable cannot publish into a newer connection. Recent update receipts are bounded to 64 quest identities and 30 seconds. They report callback arrival only, without inferring current objective progress, completion, eligibility or rotation selection.

The source-tested callback contract is pinned to Questie 12.1.0, commit `876731025e1e02248c6b19afb46027fd4cf69766`. Other versions are marked unverified. Declared Classic-family support is separate from native acceptance; Retail/unknown policy and restricted observations cannot borrow a Classic success. No provider implementation, database or artwork is bundled. Native behavior remains unverified until actual-client testing.
