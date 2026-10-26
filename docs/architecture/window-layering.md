# Window layering

Every Rotation Master window, popup, prompt and menu is laid out by one registry in `UI/window.lua`. A window never sets its own strata, frame level or click-raise; it opens through the registry, which keeps a popup in front of the window that opened it.

## How the client orders frames

A frame is drawn by (strata, level) and nothing else. A level is global inside its strata, not relative to the parent: a control deep inside window A can have a higher level than window B's own frame, and is then drawn over B.

* A window's own level says nothing about its content. Content sits above it (`+1` per nesting level, plus explicit offsets such as `+50`, `+80`, `+90`, `+200`, `+250`).
* Clicking a frame marked `SetToplevel(true)` (or anything inside it) raises it natively. It does not know it has a popup, so a clicked opener ends up over the popup it opened.
* `OnShow` fires only when a hidden frame is shown. Showing a window that is already visible does not move it.

## Rules

1. **Strata.** Windows are `FULLSCREEN_DIALOG`. A popup is never in a lower strata than its opener. `TOOLTIP` belongs to tooltips, the drag ghost and the spell search suggestion list, which are not windows. A foreign panel in a higher strata raises the popup into that strata.
2. **Open above everything.** A window that opens is placed above the content of every other open window, measured from the highest level inside each of them, not from their own level. A window that is already the frontmost is not moved, so repeated opens never ratchet the levels up.
3. **A popup stays above its opener.** The opener is the window it was opened from: the one named in `addon:OpenPopup(widget, opener)`, otherwise the window its frame is nested in, otherwise (only when it first opens) the frontmost open window. Whenever the frontmost window changes, the registry lifts every popup back over its opener's content. A native click-raise of the opener is therefore undone before the frame is drawn. The popups of one opener keep their relative order. If an opener is hidden (a window that hides while its child is open), its popups follow the window beneath it.
4. **Peers are not chained.** The settings window and the errors report are peer windows (`kind = "window"`): neither opens the other, clicking either one raises it, and a popup opened from one stays with that one.
5. **Every open goes through the registry**, including one that re-shows a window that is already visible (`ShowConditionEditor` on an open editor, `ShowConfig` on an open settings window). The registry also hooks `OnShow`, so a pooled popup that is hidden and shown again is placed afresh and picks its opener again.
6. **Escape** closes the frontmost registered window only. The registry and the Escape target are the same list.
7. **Blizzard panels.** `OpenPopup(widget, opener, {over = frame})` keeps the popup above a foreign frame and its content, and `RaiseForeignWindow(frame, popup)` puts the panel in front of the RM windows that spawned it. A protected frame is never touched in combat. Nothing else in RM moves a Blizzard frame.
8. **Cost.** There is no per-window `OnUpdate`. The Escape watcher that already runs while a registered window is open compares the frontmost window and the levels of foreign panels; the ordering work runs only when the frontmost window changes, or when a window opens or is raised.
9. **Levels** stay under 8000 (the client rejects 10000). A stack that would pass the ceiling is compacted to the floor, keeping its order.

## API

| Call | Use |
| --- | --- |
| `addon:OpenPopup(widget, opener, options)` | Register on first use, then place above everything open and above `opener` (a frame or widget inside the opener window). Call after every `Show`. `options.over`: foreign frames to clear. `options.kind = "window"`: a peer window. `options.escape = false`: not an Escape target. `options.layer = false`: only an Escape target, no ordering (the drag ghost). |
| `addon:RaiseWindow(widget)` | Bring a window and the windows that opened it to the front; their popups stay above them. |
| `addon:RaiseForeignWindow(frame, popup)` | Put a Blizzard panel in front of every RM window except `popup` and what it opened. |
| `addon:RegisterWindowForEscape(widget)` | Compatibility entry used by `addon.HideOnEscape`. Same registration. |
| `addon:GetWindowLayers()` / `addon:SyncWindowLayers()` | The registry in registration order; one frame of the watcher's work (tests). |

`widget.rmLayerKind` and `widget.rmLayerStrata` set the defaults before registration.

## Layer map

All windows are registered; the opener is the window the user acts in when they open it.

| Layer | Strata | Created in | Opened from |
| --- | --- | --- | --- |
| Settings window (peer) | `FULLSCREEN_DIALOG` | `UI/config.lua` | `/rm`, minimap, keybinding |
| Errors report (peer, no Escape entry) | `FULLSCREEN_DIALOG` (was `DIALOG`) | `UI/errors.lua` | `/rm errors` |
| Settings window link pane (nested) | `FULLSCREEN_DIALOG` | `UI/config.lua` | settings window |
| Condition editor | `FULLSCREEN_DIALOG` | `UI/condition_editor.lua` | settings window |
| Condition type picker (nested in the editor card) | `FULLSCREEN_DIALOG` | `UI/condition_picker.lua` | the editor |
| Dropdown menus | `FULLSCREEN_DIALOG` | `UI/selector.lua` | the control they drop from |
| Color picker, icon picker, item list popup | `FULLSCREEN_DIALOG` | `color_picker.lua`, `icon_picker.lua`, `item_list_popup.lua` | the pane / editor |
| Help, integration links, full condition text, Lua input probe, Lua debug output | `FULLSCREEN_DIALOG` | `help.lua`, `condition_text.lua`, `lua_input_probe.lua`, `lua_debug_output.lua` | whatever was frontmost |
| Rotation metadata, comparison, adoption, defaults, collection compare | `FULLSCREEN_DIALOG` | `rotation_metadata.lua`, `rotation_comparison.lua`, `rotation_adoption.lua`, `defaults.lua`, `collection_compare.lua` | the rotation pane |
| Text transfer, text report, import preview/content, function bundle transfer, source review | `FULLSCREEN_DIALOG` | `settings_transfer.lua`, `transfer.lua`, `function_bundle_transfer.lua` | the pane |
| Custom condition editor, field schema editor, source preview / debug surface | `FULLSCREEN_DIALOG` | `custom_condition_editor.lua`, `schema_editor.lua`, `condition_source_preview.lua` | the pane, or the editor that hides for it |
| Confirm and unsaved-changes prompts | `FULLSCREEN_DIALOG` | `settings_form.lua`, `rotation_navigation.lua`, `custom_condition_transfer.lua` | the pane |
| Talent tree control strip | `FULLSCREEN_DIALOG` | `talent_popup.lua` | the condition pane; over Blizzard's talent window |
| Embedded Lua editor panels (Inspector, probe terminal / snapshot) | `FULLSCREEN_DIALOG` (library: `DIALOG`) | `Integrations/lua_workbench.lua` | the embedded editor |
| Drag ghost | `TOOLTIP`, not ordered | `controls.lua` | a drag |
| Spell search suggestions | `TOOLTIP` | `spell_search.lua` | an edit box |
| Preview overlay | `MEDIUM` | `preview.lua` | not a window |

## Testing

`tests/window_layering.lua` drives the registry with windows shaped like RM's. `tests/window_layering_ui.lua` opens the real windows. Both run over `tests/fixtures/layer_model.lua`, a model of the client's ordering, under two readings of what `Raise()` does (above its siblings, or above everything in the strata) because the client's rule is not documented. `RM_WINDOW_FILE=<path to an older UI/window.lua>` runs the registry test against another revision.

The model is not the client. In-game checks remain: the condition editor, Help and every prompt in front of the settings window after clicking it, the talent control strip over Blizzard's window, and the embedded editor's Inspector.
