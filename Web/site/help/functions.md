# Functions

The **Functions** tab holds reusable Lua helpers for [custom conditions](/help/conditions#custom-conditions) (and for other helpers). Write a calculation once, document it, and use it from many conditions.

> **Warning:** Functions are Lua code that runs inside your game. Only write or import code you trust.

## Built In and custom helpers

The list shows **Built In** helpers that ship with the addon and your **Custom** ones. Search by name or description, and filter by Built In / Custom and by namespace. Built In helpers open read-only; **Duplicate** gives you an editable copy.

## Defining a function

- **Namespace** — a dotted group name such as `custom` or `mymod.util`. Pick an existing one or type a new one. Callers use `namespace.name`.
- **Name** — letters, numbers and underscores, starting with a letter or underscore.
- **Description** — what it does.
- **Arguments** and **Returns** — document each input and result with a name, type, whether it may be nil, and a description. Lua can return several values; the rows describe them in order.
- **Code** — the Lua body. **Undo** / **Redo** edit it; **Reset** restores the saved body; **Check syntax** compiles it without running anything.

Click a heading to fold Arguments or Returns. Add rows with **+ Argument** and **+ Return**, drag or use Up/Down to reorder (RM warns you, because callers pass arguments by position and it does not rewrite them).

**Apply** saves the code and documentation together; **Discard** abandons the draft.

## Dependencies

When a function or custom condition uses another helper, record it as a **dependency**: choose the source helper and the local name you will call it by, such as `custom.ready` or `utils.getCached`. Accepting a completion while typing records the dependency for you; typing a call by hand does not.

Dependencies tell RM what to load, what to include in exports and what to check is available. Game globals and the addon's own API are always available without one.

A namespaced call does not receive `self` automatically: write `object.method(object, x)`, or the usual `object:method(x)`.

## Exporting and importing

**Import/Export** produces a *function bundle*. Tick **Include custom function dependencies** to put the source of every custom helper it uses into the same export; otherwise the bundle only records which helpers (and which versions) it needs.

To import, paste the bundle and choose **Review import**. RM shows what it would add, any name conflicts and every Lua body (**Review source**). For each one choose **Reuse**, **Replace** or a new identifier, then **Apply import**. Changing the text throws away the reviewed plan.

See also [Importing, exporting and sharing](/help/sharing).
