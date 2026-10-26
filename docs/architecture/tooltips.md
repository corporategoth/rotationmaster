# Tooltip integration

`Core/tooltips.lua` adds up to two lines to spell and item tooltips:

* **Item tooltips:** `Rotation Master item sets: Healing Potions, Healthstones`, the Rotation Master item sets (the profile's and the shared ones; a personal set shadows a shared set with the same key) that contain the item.
* **Spell and item tooltips:** `Rotation Master rotations: Arcane PvE, Arcane AoE (disabled), ...`, the rotations that use the spell or item.

Lines are only appended. The tooltip is never read, so the Midnight secret-value and taint rules do not apply to its text; the hovered ID is checked readable (`Platform:CanReadValue`) before it is looked up.

## Settings

All on the General page, under Tooltips, in the profile (and so in profile transfer and the General draft/Apply workflow):

| Key | Default | Meaning |
| --- | --- | --- |
| `tooltips` | on | Master switch. Off: nothing is added and nothing is registered at login. |
| `tooltip_itemsets` | on | The item set line in item tooltips. |
| `tooltip_rotations` | on | The rotation line in spell and item tooltips. |
| `tooltip_conditions` | off | Also count a spell or item that appears only inside a condition (any depth through AND, OR and NOT, and on branch steps). |
| `tooltip_limit` | 3 | Names per line (1 to 20); the rest is counted as `(+N more)`. |

## What counts as "uses"

The rotations in the Rotations list for the **current specialization**, built from the same sources the list uses (`ListRotationHeaders` for your rotations, `GetBuiltinStates` for Built Ins). A spell or item counts when an enabled, reachable step of the rotation or cooldown list names it (`spell`, `pet` and `any` steps by spell ID; `item` steps by item set key or an inline list). A disabled step, and the arm of a branch that can never run, does not count. A rotation is named once however many steps use the spell.

* A rotation that is switched off is listed after the enabled ones, dimmed and marked `(disabled)`. Enabled rotations come first, then by priority (higher first), then by name.
* Built Ins that are not for this client's edition, expansion or build, not for this class, not valid here, or restricted to another specialization are left out. Every other Built In the list shows is listed, including ones above your level.
* Names go through `addon:RotationDisplayName`, so a Built In never shows its locale key.
* Spells match through the spells the client relates to them (`GetSpellIdRelatives`: base and override, so a talent swap still matches). On clients with spell ranks a hovered rank matches a step that is not rank-exact; a step with "Use this exact spell rank" matches only that rank.

## Two registration paths

`TooltipDataProcessor` exists on every client (it lives in Blizzard_SharedXMLGame), but only the mainline `GameTooltip` is built on the data handler that calls it. The Classic `GameTooltip` still fires `OnTooltipSetItem` and `OnTooltipSetSpell` and never calls the processor, so a PostCall registered there would never run. The path is therefore chosen by the tooltip object:

* `GameTooltip.ProcessInfo` is a function (and the processor and `Enum.TooltipDataType.Item/Spell` exist): `TooltipDataProcessor.AddTooltipPostCall` for Item and Spell. The callback receives the structured data; `data.id` is the ID.
* Otherwise `GameTooltip` and `ItemRefTooltip` get `HookScript` on `OnTooltipSetItem`, `OnTooltipSetSpell` and `OnTooltipCleared`. The ID comes from `GetItem()` (the link) or `GetSpell()`. A weak per-tooltip flag, cleared by `OnTooltipCleared`, stops a repeated fire adding a second line; `Show()` is called only when a line was added, to recompute the size.

Only `GameTooltip` and `ItemRefTooltip` are touched; comparison tooltips and other addons' tooltips are skipped, and so is a forbidden tooltip.

## Index lifetime and cost

Two lazy indexes, built on the first relevant tooltip after something changed, never in combat (in combat the previous index, or nothing, is served):

* **Item sets** (item ID to set names). Rebuilt when the dependency stamp (`GetRotationValidationStamp`, which `InvalidateRotationDependencies` advances for item set, condition, function and effect writes) or the profile table changes. An entry that is an item name resolves only once the client has the item cached; until then the index is marked incomplete and retried, at most every five seconds, after `GET_ITEM_INFO_RECEIVED`.
* **Uses** (spell ID and item ID to rotations). The same stamps, plus the specialization, the conditions setting, and the rotation roster stamp that `ListRotationHeaders` returns. A rotation edit moves neither the dependency stamp nor the specialization, so the roster stamp is re-read at most once a second while tooltips keep coming; the cost of that read is one `ListRotationHeaders` call.

The formatted line is cached per ID until the index is replaced. Hooks are registered only when the master switch is on at login (or when it is turned on later), and the retained hook of a feature turned off is one settings read. The polling path is not touched: no event handler, timer or function of `main.lua` changed except the profile defaults.

## Failure

The callback runs under `Diagnostics:Call`. A failure is reported through the error collector (module `tooltips`) and retires the feature for the session; other addons' tooltip callbacks are not affected.

## Not verified without a client

The offline tests (`tests/tooltips.lua`, plus the two General page tests in `tests/settings_pages.lua`) drive both paths with fake tooltips and a fake processor. They cannot show the following; check them in the game:

1. Retail and Forever: hover a spell on an action bar and an item in a bag, out of combat and in combat. The lines appear, no taint or "blocked action" message appears, and the tooltip is not cut off.
2. Retail and Forever: hover a spell in the spellbook and an item link in chat (`ItemRefTooltip`).
3. Classic Era, TBC Anniversary and Mists: the same hovers. Each line appears once (not doubled) and the tooltip resizes to fit it; hover the same thing twice in a row.
4. With another tooltip addon (TipTac, ElvUI, Auctionator, Baganator): the Rotation Master lines are styled like the others and nothing else changes.
5. Edit a rotation (change a spell step), close the editor, hover the spell: the list is current within a second of hovering again. Switch a Built In off in the Rotations list: it shows dimmed and marked disabled.
6. Turn the master switch off, Apply, hover: no lines. `/reload` with it off: the lines stay off and `/rm perf` shows no extra work.
