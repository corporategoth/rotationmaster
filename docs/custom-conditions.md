# Custom condition authoring

Conditions → Add custom condition or Edit opens the native workbench editor. The identifier is stable for an existing definition. Description, icon and field-schema text describe the condition. Function tabs select Evaluate, Validate, Summary, Fields UI, Help, On register and On unregister. The signature above the code gives the callback parameters. `addon` and `L` are available in each callback. Existing widget/help callbacks retain their original layout contract; condition-specific field rendering still has an AceGUI bridge.

The scrolling code field uses the bundled FAIAP indentation and syntax-color engine directly, with the bundled Inconsolata font. It returns uncolored source. A plain native editor remains available if syntax setup fails. Syntax colors, caret movement and native hit testing require client verification.

Fields use a bounded data grammar, for example:

```
{ spell = { string, number }, unit = string, checks = condition[] }
```

Named tables are records; ordered tables are unions. Supported leaves are `string`, `number`, `boolean`, `condition` and `condition[]`. Nested unions/records are preserved. Legacy field names that are not identifiers are quoted, for example `["legacy-field"] = number`. Root fields may be empty; nested empty/mixed/sparse tables, duplicate names, cycles, unknown types and executable expressions are rejected. Parsing never evaluates Lua. The legacy Item Set schema literal remains readable and exports unchanged; compiled runtime declarations use the canonical table representation. The editable grammar is bounded to 16 levels, 512 parse nodes and 32 KiB of schema text. Existing saved definitions use a separate compatibility-loading policy, retaining generated UUID identifiers, long source/description values and legacy field names; normalized runtime schema traversal remains bounded. New callback bodies are limited to 64 KiB each and 256 KiB combined.

Edits stay in a detached draft. Undo/Redo spans callbacks and definition fields; switching function tabs commits the current code buffer to that history. History retains at most 100 snapshots and 4 MiB. Cancel discards it. X, Escape and right-click ask Apply/Discard/Cancel if there are pending edits. Page/profile replacement invalidates the editor and its child dialogs.

Check syntax compiles every callback but does not construct or invoke it. Apply validates the complete definition, stages every callback, checks that the original definition/source still matches, then installs it. Source is saved only after successful registration. Failed compilation/registration preserves the prior registry entry and saved source. Registration errors enter `/rm errors` with custom source redacted by default and continue to the normal game error handler. Trusted Lua hooks may have external side effects that cannot be rolled back; this is not a sandbox or a proof of callback correctness.

The shared import/export dialog displays the source identifier, a replacement checkbox and new-copy name. Import requires an explicit trust confirmation and opens the imported definition in the draft. It does not register or save it until Apply.

## Optional editor provider contract

`RegisterLuaEditorProvider(name, create)` on the Rotation Master addon instance registers an optional provider factory. Obtain that instance with `LibStub("AceAddon-3.0"):GetAddon(actualInstalledAddonName)` or `_G[actualInstalledAddonName]`; the registered name follows the installation folder, including case. The factory receives `(parent, changed, valid)` and returns a controller with `frame`, `GetText()`, `SetText(text)` and `Release()`. `GetText()` returns plain Lua; `changed` signals edits; `valid()` is the owner's lifetime guard. Release must stop callbacks and release owned resources. Consumers explicitly request a provider through `CreateWorkbenchLuaEditor(parent, changed, valid, name)`; the normal editor defaults to the bundled native implementation. Failed creation, malformed controllers and runtime text-method errors fall back to native controls. No LuaWorkbench-specific API or automatic dependency is assumed.
