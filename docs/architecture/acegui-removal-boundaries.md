# Native-only UI

Rotation Master no longer ships or supports AceGUI. The legacy GUI compatibility contract was explicitly retired. There is no on-demand companion, proxy library, global LibStub interception or fallback to another addon's GUI.

The distribution removes AceGUI and its widget packages, AceConfig, AceDBOptions, LibAboutPanel, the old Options/Widgets renderers, registration bridges and predictor manifests. AceAddon, AceDB, AceLocale, AceConsole, AceEvent, AceTimer, AceSerializer, AceComm and AceBucket remain independent runtime services. LibSharedMedia remains for sound selection. Retained vendor files keep their upstream hashes and license notices.

## Native field ownership

`UI/condition_widgets.lua` owns registered native widgets, lease-scoped callbacks, pools and disposal. `RegisterConditionWidget(widget)` establishes identity; copying public flags does not make a foreign control native. Groups accept active registered native children only. Batch insertion checks all children before changing ownership. Releasing a root marks it as queued before hiding or releasing children, preventing teardown callbacks from committing pending edits. Failed releases quarantine the widget.

`CreateConditionGroup()` supports `List`, `Table` and `RM-SpellField`. Table supports responsive columns, min/max/fixed/relative/weighted sizing, spacing, alignment callbacks and row/column spans with bounded work. Unsupported names, arbitrary layout functions and invalid descriptors fail explicitly. Native ownership replaces mixed GUI/native pool transfers.

Ordinary settings, condition fields, Help, Test/Run/Debug surfaces, item-list drafts, read-only references, comparisons, import previews and recommendation icons all use native controls. RM's native observation mechanism tracks unattached controls during authoring/debug execution. External roots own native widgets through their frames and explicit release lists; they do not impersonate condition containers.

## Custom code and modules

Saved custom code is preserved byte-for-byte. Older Fields UI/Help code must be adapted to RM's native factories and registered child protocol; raw Ace controls and layouts are unsupported even if another addon provides AceGUI. Seven historical captured AceGUI library records have been retired. Sources depending on them become unavailable through normal missing-binding validation; RM does not rewrite or delete those sources.

Use namespaced documented functions and the native factories exposed in Functions. For example:

```lua
local input = addon:CreateConditionEditBox()
input:SetText(tostring(value.amount or ''))
input:SetCallback('OnEnterPressed', function(_, _, text)
    value.amount = tonumber(text)
end)
parent:AddChild(input)
```

`Core/condition_catalog.lua`, `Core/custom_condition_services.lua` and `Core/itemset_services.lua` retain their data/runtime responsibilities. `UI/settings_setup.lua` owns the native launcher and specialization metadata. Legacy module SetupOptions/AceConfig application hosting has been removed; modules must adapt their configuration UI. Runtime module registration is unaffected.

## Reference metadata and previews

Spell inputs use `SpellCatalog`. Items use `Core/reference_catalog.lua` and guarded platform observations. Successful item metadata events update its private index through `UpdateReferenceItem`. Search retains earlier readable names while metadata is merely unloaded. Failed, malformed or restricted observations suppress stale entries until a readable observation succeeds. Indexed metadata never establishes inventory ownership.

The recommendation preview implements `AddRecommendation`, `ReleaseChildren`, `PauseLayout`, `ResumeLayout` and `DoLayout`. Unsupported historical preview objects are ignored without invoking their methods or requesting GUI controls.

## Verification

Run `python3 tools/check`. Distribution tests verify the complete TOC/XML graph and absence of GUI payload, while native tests cover the full condition inventory, source dependencies, native layout/pooling/ownership, item indexing, profile lifecycle and authoring/Test/debug cleanup. Native input, layering and visual acceptance still require WoW.
