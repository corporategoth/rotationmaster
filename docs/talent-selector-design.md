# Universal talent selector: design

Status: phase 1 (Retail and Forever) is built on branch `claude/talent-popup`; the dropdown pickers and their shared layout (section 2.1) on `claude/talent-dropdown`; the classic clients (phase 2) are designed below and not built. Sections 2 and 4-7 say what exists; section 3 is the long-term data model, of which phase 1 ships the trait half (`Platform:GetTraitView`).
Written against the pinned Blizzard UI source (`docs/quality/client-api-sources.json`: live 12.1.5.70575, forever 1.60.1.70532, classic 5.5.4.70579, classic_era 1.15.9.70003, classic_anniversary 2.5.6.70006) and the committed client API manifests. No real client was available; every in-game claim below is marked as modeled or unverified.

## 1. Where we start

TALENT today has three pickers, one per layout (`Platform/talents.lua` `GetTalentLayout`):

| Layout | Clients | Reference stored in the condition | Reader |
| --- | --- | --- | --- |
| `tree` | Era, SoD, TBC Anniversary, Wrath, Cataclysm | `tree`, `talent` (indices), `operator`, `value` | `GetNumTalentTabs`, `C_SpecializationInfo.GetTalentInfo{specializationIndex,talentIndex,groupIndex}` |
| `grid` | Mists Classic | `layout="grid"`, `value` = slot 1-18 | `C_SpecializationInfo.GetTalentInfo{tier,column,groupIndex}` |
| `traits` | Retail, Forever | `layout="traits"`, `node`, `entry` (choice nodes), `spell` (new), `operator`, `value` | `C_ClassTalents` + `C_Traits` |

Each picker is two or three dropdowns. The Retail one was the weakest; the fix shipped with this document (section 2) is the first step of the design below, not a throwaway.

## 2. Shipped with the Retail talent fix (the base the design builds on)

* `Platform/talents.lua`: `GetTraitSpecTree(specID)`, `GetTraitTalents(specID)` (class and specialization talents as one group, then one group per hero tree the specialization can choose, each talent with name, icon, spell ID, node, choice entry), `GetTraitEntrySpell`, `GetTraitSpellIndex`.
* Another specialization is read from Blizzard's view loadout: `C_ClassTalents.GetTraitTreeForSpec(specID)` names its tree, `C_ClassTalents.InitializeViewLoadout(specID, level)` fills config `-3` (`Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID`), and `C_Traits.GetTreeNodes/GetNodeInfo/GetEntryInfo` then answer for that config (this is what the talent window does to show a shared build: `Blizzard_ClassTalentImportExport.lua` `ViewLoadout`). Refused in combat (`in-combat`). The active config is used whenever the wanted specialization is the one being played.
* A picked talent stores `node`, `entry` (choice nodes only) and `spell`; evaluation falls back to the spell when the node no longer holds it.
* Verified only against `tests/fixtures/retail_traits.lua`, a model of the documented API. See the report for what to check in game.

Facts the design relies on, each read from the pinned source:

* `C_Traits.GetTreeNodes(treeID)` returns the nodes of every specialization of the class plus the hero nodes ("Contains nodes for all class specializations", SharedTraitsDocumentation). `GetNodeInfo(...).isVisible` and the hero subtree list (`C_ClassTalents.GetHeroTalentSpecsForClassSpec(configID, specID)`) say which of them belong to the specialization shown.
* Node geometry: `posX`, `posY` in tenths of a pixel (`TalentButtonUtil.TranslateNodePositionsToAnchorPositions`: `x = posX/10`, `y = -posY/10`); edges are `nodeInfo.visibleEdges[].targetNode`; node kinds are `Enum.TraitNodeType` Single 0, Tiered 1, Selection 2 (choice), SubTreeSelection 3 (hero chooser, entries have `subTreeID` and no definition).
* Blizzard filters hero nodes with `GetHeroTalentSpecsForClassSpec` even though they are already `isVisible` (`HeroTalentsContainer:IsNodeInAvailableSubTree`).
* No Retail return in the talent APIs is documented secret; every value is still read through `CanReadValue`.

### 2.1 The dropdown picker (claude/talent-dropdown)

The lists are the picker; the tree popup is an optional extra. Every client with a TALENT picker uses one layout (`Conditions/talent.lua` `block`, laid out by `UI/condition_layout.lua` `layoutIconRows`, tested by `tests/talent_picker_layout.lua`): the talent's icon is the left column and spans two rows (a question mark until a talent is chosen), the upper list and the talent list sit to its right, and the "Show talent tree" button sits beside the talent list when the pane has room, else under the rows.

| Client | Upper list | Talent list |
| --- | --- | --- |
| Retail | Specialization (the rotation's, any of the class's) | one list, grouped under headings: class, specialization, then one heading per hero tree; a choice node lists each choice |
| Forever | Talent Tree (the three trees of the loadout) | that tree's talents |
| Era, SoD, TBC, Wrath, Cataclysm | Talent Tree | that tree's talents, with icons |
| Mists | Tier (1 to 6, with its level) | the tier's three talents |

What is read, and what is not (`Platform/talents.lua`):

* The played specialization (and Retail's own specialization whenever the active config is not yet known) is read from the **active config**: `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo/GetTreeNodes/GetNodeInfo/GetEntryInfo/GetDefinitionInfo`, the same reads Blizzard's talent window makes, with the same visibility rule (`isVisible`, `HeroTalentsContainer:IsNodeInAvailableSubTree`). Nothing is loaded or opened for it; Blizzard's talent window is never needed.
* Another specialization is read from Blizzard's **view config** (`GetTraitTreeForSpec`, `InitializeViewLoadout`), only out of combat and never while the talent window is showing someone else's build (`talent-window-inspecting`). That path is the one part not proven in a real client.
* The hero subtrees offered are `GetHeroTalentSpecsForClassSpec`'s; that call is documented "MayReturnNothing", so when it answers nothing the subtrees named by the visible hero selection node's entries are used instead.
* Names and icons are the talent window's own (`overrideName`, else the spell's name; `overrideIcon`, else the spell's original icon). A spell record the game refuses or has not loaded falls back to `C_Spell.GetSpellName/GetSpellTexture` before an entry is given up on.
* Class and specialization talents are split by the talent window's own columns (class tree left, specialization tree right, a gap between); with no clean gap they stay one group, "Class and specialization talents", rather than guess.
* When nothing can be listed the editor says why, with the reason code, and the tree button is disabled; node and entry IDs stay editable.

`/rm debug talents [views]` writes a report of each call and what it answered (raw error text included) into a copyable window and `RotationMasterDB.diagnostics.talents`; `views` also reads every other specialization of the class. It is the way to find out what a real client says (`Diagnostics/talents.lua`).

## 3. One data model

Every provider answers the same shape, so the popup, the dropdown fallback and the website all consume one thing.

```lua
catalog = {
  layout   = "graph" | "grid" | "tree",   -- how to draw it
  client   = "retail" | "forever" | "mists" | "wrath" | ... ,
  source   = "active" | "view" | "static", -- live character, Blizzard view loadout, shipped/served data
  spec     = <specialization value or nil>, -- the rotation's body.specs value this catalog is for
  complete = true | false,                 -- false when part of the tree could not be read
  trees    = {                              -- tabs of the popup
    { key = "class", kind = "class"|"spec"|"hero"|"tab", name, icon, order,
      talents = { talent, ... } },
  },
}
talent = {
  key      = string,           -- stable, opaque to callers: "n2204" (node), "n2204e3204" (choice), "t21" (classic talentID)
  name, icon, spellID,         -- spellID drives tooltips and is the cross-patch fallback
  tree     = <trees key>,
  row, col,                    -- grid/tree clients; graph clients leave them nil
  x, y,                        -- graph clients, node units (tenths of a pixel)
  maxRank,
  rank,                        -- present only for source "active": what the character has
  choice   = { {key, name, icon, spellID, entry}, ... } or nil, -- alternatives of a selection node
  edges    = { key, ... },     -- graph clients: talents this one leads to
  ref      = { ...condition fields... },  -- what picking it writes (below)
}
```

`ref` is the part that keeps saved data compatible: picking a talent writes exactly the fields the condition already stores for that layout.

| Layout | `ref` |
| --- | --- |
| traits | `{layout="traits", node, entry?, spell}` (+ default `operator="GREATERTHANOREQUALS", value=1` when the condition had none) |
| tree | `{layout="tree", tree, talent}` (+ operator and points) |
| grid | `{layout="grid", value}` |

No condition format changes are needed for the popup. Two optional hardening steps, not required: classic references could additionally store `talentID` (Era/TBC/Mists `GetTalentInfo` returns a stable `talentID`) so an index shift between client builds cannot repoint a saved talent; and `tree` references could be resolved through a catalog `key` instead of positional indices. Both are additive and follow the `spell` precedent: new optional field, fallback only when the primary reference stops holding.

## 4. Decisions (the user's, in order)

1. "I would kind of prefer to use something already done by others both on the website and in game. It's less for us to maintain and already works." A research pass found no addon that is a drop-in picker: every talent viewer is a standalone window with no selection API, and the useful data library (LibTalentTree-1.0) is not needed once Blizzard's own window does the drawing. No third-party addon or library is embedded or depended on. (LibTalentTree-1.0 was evaluated and set aside: its README grants redistribution of unmodified copies and unrestricted use of its API with all other rights reserved, its TOC says it may be used and redistributed in any way including embedding, its CurseForge page says LGPLv3, and its repository has no LICENSE file. If it is ever embedded, record exactly that and keep its header intact.)
2. "Make it beside the dropdown, a button to pop up the talent tree, with the selection visible (which will then have tooltips for each talent working too)." The dropdown stays; a **Show talent tree** button sits beside the Talent list.
3. "Use the Blizzard talent template to display the tree; it can do all the normal tooltips. We highlight one talent (or none), and when they click a different one we take that and close the template." Plan A below. "Do things the same way [the other addons] are, across different versions of the game": one provider per client family, Blizzard's own frame where the client has one that can show a build read-only.
4. Plan B is RM's own drawn tree. **After the first real-client test (section 5.6) Plan B is the default and Plan A is an opt-in setting.** On a client with no provider the button is hidden.

## 5. The provider interface and what each client can show

One interface (`Platform/talent_tree.lua`): `platform:RegisterTalentTreeProvider(id, {families, priority, available, open})`; `open(context)` returns a handle (`Reload`, `Close`) or nil and a reason; `platform:GetTalentTreeProviders()` lists the available providers for the client in priority order; `platform:HasTalentTreeProvider()` decides whether the button exists. The UI (`UI/talent_popup.lua`) tries them in order and keeps the first whose `open` succeeds, so a provider that cannot show the tree now (combat, a window it must not disturb, a missing API) says why and the next one runs. The context carries the wanted specialization and hero tree, the saved selection `{node, entry, spell}`, and `onSelect` / `onClose` callbacks. `ref` fields written on a pick are exactly the ones the dropdown writes (section 3), so no saved data changes.

### 5.1 Retail and Forever: Blizzard's PlayerSpells talents frame in view mode (Plan A, built, opt-in since the first real-client test)

Verified by reading the pinned Blizzard source (Gethe/wow-ui-source live b9be937 and forever 172a387; the import/export file is byte-identical on both):

* **Showing another build read-only.** `PlayerSpellsUtil.InspectLoadout("specID:level:importString")` calls `PlayerSpellsFrame:SetInspectString(importString, level)`, which calls `TalentsFrame:ViewLoadout`: it validates only the header (serialization version equal to `C_Traits.GetLoadoutSerializationVersion()`, at least 152 bits), calls `C_ClassTalents.InitializeViewLoadout(specID, level)`, reads one record per node of `C_Traits.GetTreeNodes(treeID)` and calls `C_ClassTalents.ViewLoadout(entries, importText)`. **The 128 bit tree hash is never checked in view mode** (it is only checked on import), so a zero-filled hash is valid, as the file's own format notes say for third-party sites. The class and specialization come from the header, so the tree can be any specialization of the class. `SetInspecting` then switches the frame to the view config (`Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID`), hides Apply/Reset/Undo/loadout controls, selects the talents tab and leaves purchase and refund disabled (`IsInspecting()`).
* **Which hero tree shows.** In view mode `HeroTalentsContainer` displays only an *active* subtree, and a subtree is active when the loadout buys the SubTreeSelection node with that subtree's entry. So the loadout string carries the hero choice: the selection node, flagged as a choice node with the 0-based entry index. The addon builds this itself (`EncodeTraitView`): per node `0`, or `1,1,0,<choice bit>[,<2 bit entry>]`, packed six bits per base64 character, least significant bit first (`ExportUtil.ConvertToBase64`). The test fixture decodes our strings with an independent reimplementation of Blizzard's `ImportDataStream`.
* **Highlighting the selected talent.** The talent is encoded as purchased in the same string (Blizzard then draws it learned, and for a choice node shows the chosen entry), and RM also calls `TalentDisplayMixin:SetGlowing(true)` on `TalentsFrame:GetTalentButtonByNodeID(node)` and anchors a gold ring frame of its own to it, both re-applied on `TalentFrameBase.ButtonsUpdated` (buttons are pooled and re-acquired on every tree reload) and cleared on close. If the client refuses a loadout whose talent has no bought path (`ViewLoadout` returns false and `SetInspecting` clears itself, so `IsInspecting()` is false afterwards) the addon retries with the hero choice alone and then with the bare tree; the ring still marks the node.
* **Capturing a click.** `TalentButtonSpendMixin:OnClick`, `TalentButtonSelectMixin:OnClick` and `TalentSelectionChoiceMixin:OnClick` all start with `EventRegistry:TriggerEvent("TalentButton.OnClick", self, button)` *before* the `IsInspecting()` early return, so the event fires in view mode. The callback gets `(owner, button, mouseButton)`. `GetNodeID`, `GetEntryID`, `GetSpellID`, `GetNodeInfo` (and `GetBaseButton` on a choice entry) give the node, the entry and the spell; a choice node is only picked through one of its entries (the base button's entry is the *active* one, nil when nothing was chosen); the hero selection node and right clicks are ignored. The pick is applied on the next frame (`C_Timer.After(0)`) so it does not run inside Blizzard's click handler.
* **Closing and restoring.** `PlayerSpellsFrame:OnHide` runs `ClearInspectUnit`, which returns the frame to the player's own config. RM records whether the window was shown, its tab and its strata before it opens; on close it clears view mode, restores the strata and tab, and hides the window only if it was hidden before. If the player closes Blizzard's window (Escape) the `PlayerSpellsFrame.CloseFrame` event ends the session. RM refuses to disturb the window when it is already inspecting a link or another player, or when `TalentsFrame:HasAnyConfigChanges()` (staged, uncommitted talent changes); the drawn tree serves instead.
* **Specialization of the header.** Retail: the rotation's specialization (the view loadout reads another specialization's tree, as `GetTraitSpecTree` already does) else the played one. Forever has no specialization API of its own; the header uses `PlayerUtil.GetCurrentSpecID()`, and if that is missing the string cannot be built and the drawn tree serves.
* **Combat.** Nothing is read or opened in combat (`InCombatLockdown()`); every talent API call goes through `pcall` and `CanReadValue`. While the session is open `PLAYER_REGEN_DISABLED` ends it (Talent Tree Tweaks notes that closing an inspecting frame in combat can fail, so it is closed as combat starts). Only the header and the node records are written: every node gets its record, so no read runs past the string.

**Needs a real client to confirm (no client was available; the first real-client run is section 5.6):** that `ShowUIPanel(PlayerSpellsFrame)` and `SetInspectString` from addon code leave no taint that surfaces in the player's own talent window (the main risk: all Blizzard code that runs from our call, and every field it writes, runs tainted; out of combat the frame has no protected actions, but this has not been exercised); that `ViewLoadout` accepts a loadout with only the chosen hero tree and one purchased talent; that the Camelot (Forever) frame honors the same calls (its `PlayerSpellsFrame` file is the shared mixin plus overrides, and its `IsTabSystemAvailable` is false, which `SetInspecting` does not depend on); how the frame layers against RM's full-screen-dialog windows (RM raises Blizzard's frame to `FULLSCREEN_DIALOG` and anchors its own small control strip above it); that hovering a choice node in view mode still opens its entries so a click reaches an entry button; and that a 12.x client has not renamed `TalentButton.OnClick`, `ButtonsUpdated` or `CloseFrame`. Each of these degrades to the drawn tree, never to a broken window: `open` fails closed and the next provider runs.

### 5.2 Retail and Forever: the drawn tree (Plan B, built, the default)

RM draws the nodes itself from `C_Traits.GetNodeInfo` (position in tenths of a pixel, `visibleEdges`, entries) of the specialization's view loadout. It looks like Blizzard's tree because it uses Blizzard's own art where the client has it: the `talents-node-square-*` and `talents-node-circle-*` frames (square for an ability, circle for a passive, from the entry type `Enum.TraitNodeEntryType`), `talents-node-circle-mask`, the `talents-background-<class>-<spec>` backdrop (through `ClassTalentUtil.GetVisualsForSpecID` when Blizzard's talent UI is loaded) and, where an atlas is missing, plain textures. Layout: the class tree on the left, the chosen hero tree in the middle and the specialization tree on the right (the client's own coordinates already put them there), a title over each pane, a choice node as its two entries at half size, the rank count on a multi-rank talent, faint lines between linked talents, scaled to fit the window.

Every talent shows in the green "selectable" frame: the tree is read as it stands and never shows the player's own purchased talents, nothing is greyed for locked rows or point gates, and the saved talent is the one gold frame with a glow. Hover gives `GameTooltip:SetSpellByID` plus the ranks, a note on a choice node and what a click does; a click chooses the talent and closes the window; clicking the chosen one clears it (the condition's node, entry and spell are emptied). Escape and right click close it; the window moves by its title bar and takes the global UI scale. It is built lazily on first open, reuses its frames and has no `OnUpdate`.

Reading another specialization fills the shared view config (`VIEW_TRAIT_CONFIG_ID`) with that specialization's empty tree; it never touches the player's real config. If Blizzard's own talent window is on screen showing a linked or inspected build, the read is refused (`talent-window-inspecting`) rather than replace what that window shows. Nothing is read in combat.

### 5.3 Classic clients (phase 2, researched, not built)

Each point below was read in the pinned classic_era 8165d4c, classic (progression) 15c8a754 and anniversary 2cfec7c sources.

| Client | Blizzard frame | Can it show a given tree read-only? | Click capture |
| --- | --- | --- | --- |
| Era, SoD, TBC Anniversary, Wrath | `Blizzard_TalentUI` (`PlayerTalentFrame`, `Classic/Blizzard_TalentUI.lua`), `Blizzard_FrameXML/Vanilla/TalentFrameBase.lua` `TalentFrame_Update(frame)` | Only the player's own class and talent group. There is no view or link mode in the player frame. | `PlayerTalentFrameTalent_OnClick` **spends a point** (`LearnTalent`, or `AddPreviewTalentPoints` with the preview option) on the active group: hooking the button cannot stop it, so the player frame is not usable as a picker. |
| Era, SoD, TBC, Wrath | `Blizzard_InspectUI` `InspectTalentFrame` (`talentButton_OnClick` only inserts a chat link) | It shows an *inspected* unit's trees, filled by `NotifyInspect(unit)` and `INSPECT_READY`; only that unit's class. It cannot show a class or a build the player does not have. | A `HookScript("OnClick")` on `InspectTalentFrameTalent<N>` works (the original does nothing but link), `GetTalentInfo`-style indices come from `PanelTemplates_GetSelectedTab(InspectTalentFrame)` and `button:GetID()`. |
| Cataclysm | `Cata/Blizzard_TalentUI.lua` (`PlayerTalentFrameTalent_OnClick` spends or previews the same way), `Cata/TalentFrameBase.lua` | Same limits as above. | Same. |
| Mists | `Mists/Blizzard_TalentUI.lua`: `PlayerTalentFrame_SelectTalent(tier, id)` on click (a **real choice** of the talent in that tier); `Mists/InspectTalentFrame.lua` `InspectTalentButtonMixin:OnClick` (chat link only) | Own class only, or an inspected unit. | Same pattern. |

Conclusion: Blizzard's classic frames cannot be driven the way the modern one can. There is no loadout string, the player's frame acts on a click, and the inspect frame needs another player and shows only that player's class. The classic provider is therefore a grid RM draws itself from shipped data (section 5.5); only Blizzard's textures, and for the player's own class its live ranks and `GameTooltip:SetTalent`, are reused.

### 5.4 What the other addons do (second research pass)

Read from the source of Talent Tree Tweaks, Talent Loadout Manager, Talent Tree Viewer, LibTalentTree, Talented (Classic, TBC, Forever) and Modern Talents TBC; their code is not copied (several are All Rights Reserved).

* **Talent Tree Tweaks** drives Blizzard's frame exactly as 5.1 does: `SetInspectString` (refused in combat), `EventRegistry "TalentButton.OnClick"` for clicks, `HideUIPanel`. **Both it and Talent Loadout Manager ship taint workarounds** around `SetInspecting`, `ShowUIPanel` / `HideUIPanel` and `PlayerSpellsFrame:OnHide`: tainted `lockInspect`, `inspectUnit` and `inspectString` fields are reset after a close, `OnShow`'s micro-button, action-bar-grid and cast-bar code is stubbed through `setfenv`, because the taint "can block action buttons from working". Rotation Master does **not** port those workarounds (they edit Blizzard's secure environment and cannot be checked without a client). That is one reason the drawn tree is the default.
* **Talent Tree Viewer** never touches Blizzard's frame: it builds its own frame from `TalentFrameBaseTemplate` on LibTalentTree data. That is the shape of the drawn provider, except that RM draws plain textures instead of inheriting Blizzard's templates (no `Blizzard_PlayerSpells` dependency, no Blizzard code running under RM's taint).
* **LibTalentTree** rewrites the shared view config (-3) for every class and specialization to build its cache. It is not used: calling it while RM's view is open would swap the displayed tree.
* **Forever** (Camelot): the frame is the shared `PlayerSpellsFrameMixin` plus overrides; `SetTab` is refused while inspecting ("switching tabs loads the player's own config"), the spec tabs are hidden while inspecting, there are no hero talents, and the class tree is split into pseudo-spec visuals keyed by spec ID (Mage 1482, Druid 1484, ...). The header must carry that pseudo-spec ID, which is what `PlayerUtil.GetCurrentSpecID()` answers; Retail specialization IDs do not load there.
* **Classic**: Talented (Classic, TBC) draws its own buttons with Blizzard's textures and ships static per-class data and its own tooltips; Modern Talents TBC reuses `PlayerTalentButtonTemplate` and native `GameTooltip:SetTalent` but only for the player's own class. `TalentButtonTemplate` delegates a click to a `talentButton_OnClick` field that can be set, and `TalentBranchTemplate` plus the `Interface\TalentFrame` textures are reusable. Nothing hijacks Blizzard's classic frames safely, since a click on them spends or previews points. The phase 2 scope and data plan are in section 5.5; until it is built the button stays hidden on classic clients and the dropdowns serve.

### 5.5 Phase 2 plan: a data-driven grid provider for the classic clients

Research basis: a pass over Talented (Classic, TBC, Forever), Classic Talent Viewer (Mists), Modern Talents TBC, zTalentPlanner and the pinned classic Blizzard sources. Facts:

* **No classic talent API takes a class.** `C_SpecializationInfo.GetTalentInfo`'s query has `groupIndex, isInspect, tier, column, target, specializationIndex, talentIndex, isPet` and nothing that names a class or specialization; `GetNumTalentTabs` and `GetTalentTabInfo` likewise; `TalentFrame_Update(frame)` has no class parameter; there is no `C_ClassTalents` / `C_Traits` view loadout on these clients. `GetSpecializationInfo` takes an optional `classID` and `GetNumSpecializationsForClassID(classID)` exists, which may give another class's tree names and icons (unverified on the classic clients) but not its talents. The Mists inspect frame passes a class to `GameTooltip:SetTalent` and `GetTalentLink`, only for an inspected unit. So the player's own class can be read live, and **any other class needs shipped data**. Only Forever (a trait client) can read any class from the game, which phase 1 already does.
* **Every classic addon draws its own buttons** (Talented, Classic Talent Viewer, Modern Talents TBC's own-class reskin), with Blizzard's textures; none inherits `TalentButtonTemplate` for foreign classes. Talented ships hand-edited tables with English tooltip prose; its licenses conflict (zlib on CurseForge, CC BY in the README, "Ace3 style BSD" on the TBC page, no LICENSE file), so its data is not copied. Classic Talent Viewer's table is All Rights Reserved.
* **Seed data**: wowsims (MIT) publishes per-class tree JSON for classic, wotlk, cata and mop (`row`, `column`, `spellIds` per rank, `maxPoints`, prerequisite position; Mists as a flat 18-per-class list with `spellId`); there is no TBC set. Its provenance is a scraper of Wowhead pages, so the file records the upstream commit and the MIT notice and treats the facts (positions, spell IDs) as game facts.
* **Which key a classic talent is saved under** is already fixed by the condition: `{tree, talent}` (Blizzard's 1-based tab and talent index; Era, TBC, Wrath, Cata) or the grid slot 1-18 (Mists). Wrath's index order is not row-major, so a shipped table needs an explicit index map from the in-game dump; Era and TBC are row-major.

Plan (not built on this branch):

1. `tools/` script that turns the wowsims seed into one committed table per client (Lua, spell IDs only: no tooltip prose; tooltips come from `GameTooltip:SetSpellByID`, icons from `C_Spell`/`GetSpellInfo` of the rank-1 spell), keyed `client -> class -> tree -> {row, column, ranks = {spellID...}, prereq = {row, column}, index}`; a second tools script run in game on one character of each class writes the authoritative tab/index order to SavedVariables and the generator folds it in. TBC has no seed and starts from the dump. Each client's table carries an `X-ExpectedBuild`-style stamp; the picker shows one line when `GetBuildInfo()` differs.
2. A `classic` provider (families `era`, `tbc`, `progression`; progression covers `WOW_PROJECT_ID` 11 Wrath, 14 Cataclysm and 19 Mists) registered with `platform:RegisterTalentTreeProvider`. It draws a grid of RM's own buttons (Blizzard's `Interface\TalentFrame` textures, 63 px cell, 32 px button) and arrows from the table for any class, takes the live rank and the talent group from `GetTalentInfo` when the class is the player's, highlights the saved `{tree, talent}` or Mists slot, and answers a click through `ctx.onSelect({tree=..., talent=...})` or `({value=slot})`. The shell, switchers (trees as tabs instead of specializations), status line, combat rule and close handling in `UI/talent_popup.lua` are provider-neutral; what changes is the selection table the condition writes (`Conditions/talent.lua` `treeWidget` / `gridWidget` call `OpenTalentTree` with their own `onSelect`) and a data-driven variant of the drawn code (`draw` takes nodes from `GetTraitView` today; the classic provider supplies rows, columns, ranks and prerequisite arrows from the table).
3. Own class only on a client with no table for the player's class falls back to reading the live tree; with neither, the button stays hidden.
4. Refresh per patch: rerun the dump on one character of the player's class, diff against the committed table, and spot check the others against a manual wago.tools download (its robots.txt forbids automated fetching). A runtime self-check compares the player's own class to the table and warns on drift. Estimated: converter and table 1-2 days, dump tool and runs 1 day plus game access to each client, provider and grid drawing 3-4 days, 30-60 minutes per client per patch.
Risks: index order on Wrath and Cataclysm (key by rank-1 spell ID as well as index), hotfixed rank spell IDs, no TBC seed, Titan Reforged shares project ID 11 with Wrath but has merged content (out of scope), and per-client class lists (Hunter pet talents, Death Knight, Monk).

### 5.6 Real-client result for Plan A (Retail, 2026-10-26) and what it means

What the user saw with the first live build, on a Brewmaster Monk: the window was titled "Linked Talents (Brewmaster Monk)", showed the player's **current** purchased talents (coloured nodes, "Monk 31", "Brewmaster 30" points spent) instead of an empty tree plus our one highlight, had Blizzard's "Copy Loadout Code" button, drew the rows below the unlocked ones as flat grey, and no talent could be clicked to select anything. Which of these the source explains:

* **(b) Locked and grey rows: explained from source.** `TalentButtonBaseMixin:CalculateVisualState` only returns `Selectable` when `IsSelectable()` is true, and `TalentButtonSpendMixin:IsSelectable()` is `CanPurchaseRank()`, which requires `not IsInspecting()`. In view mode no node can ever be selectable: a node that is not purchased is drawn `Gated`, `Locked` or `Disabled` (flat grey), and the "8" padlock rows are the tree's currency gates read against the points spent in the view config. No loadout string can change this; a talent only looks active once it is purchased. So an "all choosable" look is impossible inside Blizzard's view mode.
* **(d) "Copy Loadout Code": explained from source.** `ClassTalentsFrameMixin:UpdateInspecting` shows `InspectCopyButton` (and hides Apply/Reset/Undo/Warmode/Loadouts) whenever `IsInspecting()`. It could be hidden after every `UpdateInspecting`, but it is moot now.
* **(a) The player's own talents instead of an empty tree: not explainable from source (a guess).** The two calls that fill the view config, `C_ClassTalents.InitializeViewLoadout(specID, level)` and `C_ClassTalents.ViewLoadout(entries, importText)`, are native and not in the Lua source. The Lua only reads the config afterwards (`SetConfigID(VIEW_TRAIT_CONFIG_ID)`, `GetNodeInfo`, the currency spent shown beside each tree name). The likeliest reading of the screenshot is that the view config for the player's *own* specialization starts from the player's current loadout and `ViewLoadout` overlays the entries it is given (a normal link lists the complete build, so an overlay is indistinguishable from a replacement there), or that it ignored our entries. LibTalentTree calls `ViewLoadout({})` for every specialization but never reads purchased ranks, so it does not settle this. The hash path is ruled out as a cause: `ViewLoadout` never reads it, and the header was valid (the window opened on the right class and specialization).
* **(c) Clicks doing nothing: not explainable from source (a guess).** All three click handlers (`TalentButtonSpendMixin`, `TalentButtonSelectMixin`, `TalentSelectionChoiceMixin`) call `EventRegistry:TriggerEvent("TalentButton.OnClick", self, button)` before their inspect and lock checks, and the only `EnableMouse(false)` in the shared frame is on the buttons' parent, not the buttons. So the event should have fired. Candidates that cannot be told apart without the client: the callback ran and `identify` rejected the button (an unpurchased node's base button has no active entry, so `GetSpellID` can be nil and the code falls back to the tree's own entry), the clicked frame was not one of the three button kinds, or the control strip RM anchors above Blizzard's window was hidden behind it (the screenshot shows no strip). There is also the unverified taint question of RM code running inside Blizzard's click path.

Decision: the drawn tree is the default; Blizzard's window is available only with `/run RotationMaster.db.global.talent_popup_provider='blizzard'` (hidden, no settings page) and falls back to the drawn tree when it cannot open. Section 5.1 stays as the record of what that provider does.

## 6. What phase 1 ships

* `Platform/talent_tree.lua`: provider registry, `GetTraitView` (node order, geometry, entries, edges, hero trees, active or view loadout; never in combat), `FindTraitViewSelection` (node and entry, else the spell), `EncodeTraitView`, `GetTraitViewLevel`.
* `UI/talent_popup.lua`: the control strip (specialization and hero tree switchers, the current choice, the reason a tree cannot be shown; movable, same chrome and Escape handling as the other RM dialogs), the `drawn` provider (the default, priority 50) and the `blizzard` provider (priority 10, available only when `talent_popup_provider` is `'blizzard'`), `addon:OpenTalentTree / CloseTalentTree / RefreshTalentTree`.
* `Conditions/talent.lua`: the **Show talent tree** button in a table row with the Talent list (only where a provider exists); a pick writes `node`, `entry`, `spell` through the same path as the list, moves the list and the node and entry boxes, and the tree's specialization switch moves the Specialization list; changing the list or the boxes moves the tree's highlight; releasing the editor closes the tree.
* Tests: `tests/talent_tree_popup.lua` with `tests/fixtures/blizzard_talent_window.lua` (a model of the window and its events, decoding our strings independently) and the extended `tests/fixtures/retail_traits.lua`.

## 7. Offline editing and fallback

Another specialization is read from the view loadout (section 2) and never in combat; the tree, the control strip and the dropdown all use that. A rotation for another class cannot be previewed on any client. The dropdowns and the node and entry boxes stay as the always-available path: where no provider can open (combat, a window that must not be disturbed, a missing API) the strip says why.

## 8. Website equivalent (e)

The web editor cannot read game data, so it needs a talent catalog per edition served by us.

### Sources evaluated

| Source | Coverage | Fit | Problems |
| --- | --- | --- | --- |
| Blizzard Game Data API, Retail: `GET /data/wow/talent-tree/index`, `/data/wow/talent-tree/{talentTreeId}/playable-specialization/{specId}`, `/data/wow/talent/index`, `/data/wow/talent/{talentId}`, namespace `static-{region}` | Class, spec and hero talents with node geometry; Blizzard states `class_talent_trees.talent_nodes` match `C_Traits.GetTreeNodes` (10.0.2/10.0.7 patch notes) | Best Retail match; node IDs line up with `C_Traits` node IDs | Index was incomplete for years (35 of 38 specs, Mistweaver/Arms/Protection missing, regressions in 10.1.0; fixed by Jan 2024 according to the forum thread, with remaining duplicate-talent oddities). Whether the API's talent/entry IDs equal `C_Traits` entry IDs is unverified, so the *spell ID* must be the join key. Hero talent coverage unverified. |
| Blizzard Game Data API, Classic: `/data/wow/talent/...` under classic namespaces | Not confirmed to exist for classic families | The portal docs are rendered client-side; I could not read them here. A forum thread documents the `static-classic-{region}` pattern, a gist uses `static-classic1x-` (Era), `static-classicann-` (Anniversary) and the Progression alias, and Blizzard needed build-specific namespaces (`static-3.4.3_51505-classic-us`) when the aliases broke in 3.4.3. | Existence and shape of classic talent endpoints is the first thing to verify. Forever has no documented namespace yet. |
| In-game dump by a maintainer (`/rm dumptalents` writes the provider catalog for the logged-in character's class and edition as JSON; committed under the existing generated-catalog tooling) | Every edition we support, exact node and entry IDs, hero trees, positions, edges | Exactly the model of section 3, from the same code the addon runs; no network; no license question beyond what the addon already ships | Maintainer effort per patch per class (13 classes x editions), Retail needs each specialization (view loadout makes that one login per class); data goes stale until someone dumps it |
| Third-party databases (wago.tools DB2 CSV: `Talent`, `TalentTab`, `SpellName`; Wowhead tooltips) | Complete for every build including classic | Raw ground truth for IDs | Licensing and terms to check before any use, no stability promise, extra normalization (node/graph reconstruction for Retail from `TraitNode*` tables is a project of its own). Not recommended as a primary source. |

### Proposal

1. **Primary: in-game dump committed to the repo**, one JSON per edition and class (about 13 x 5 files of 20-80 KB), normalized to the section 3 model and carrying `generatedFrom` (client build, date). It reuses the provider, so the web picker can never disagree with the in-game one, and it works for editions Blizzard's API does not cover. Add a check (`tools/check`) that the file for each supported class exists and decodes, in the style of the existing generated catalogs.
2. **Secondary: Game Data API snapshot job**, run on the server (never from the browser: client secret, CORS, rate limits), for the editions the API serves. It exists to *validate and refresh* the dump between maintainer visits (spell IDs added or removed by hotfix) and to supply names in other locales (the API serves localized names with `locale=`).
3. The web editor reads our own static JSON only (`/data/talents/<edition>/<class>.json`), joined to saved conditions by `spell` first, then `node`/`entry`, then classic `tree`/`talent`.

### Caching and the 30-day rule

The rule as given: Blizzard API data may not be kept longer than 30 days without refreshing. I could not retrieve the current terms text, so the exact wording needs confirming before launch; the design is conservative either way:

* Every record served carries `fetchedAt` (the API snapshot) or `generatedFrom` (the dump).
* The snapshot job refreshes weekly. A record older than 25 days is refreshed ahead of the limit; if the API is unreachable at day 30 the record is **removed from the served set and the web picker degrades to node/spell ID entry** rather than serving expired API data. No stale fallback.
* Cache layers: server memory (per process, 1 hour) over the on-disk snapshot (per edition/class/region-independent; talent data does not vary by region, use one region, `us`). Requests are conditional (`If-Modified-Since`) and the job obeys Blizzard's published limits (36,000 requests/hour, 100/second per client as documented in the API overview; to be confirmed against the current portal).
* Dump-derived data is not API data and is not subject to the API cache rule, but still shows its age in the editor ("catalog from client build 12.1.5.70575").
* Refreshing is also the patch signal: when a new snapshot differs from the previous one in node IDs, the job reports the diff so saved shares can be flagged by `spell` (the same fallback as in-game).

### Web UI

The existing `Web/editor` draft/render modules (`Web/editor/draft.mjs`, `render.mjs`) gain a talent picker per edition that mirrors the popup: the same graph/tree/grid drawing with SVG (nodes as `<g>` with `<title>` tooltips from the catalog, edges as `<line>`), specialization/hero switcher from the rotation's `specs`, click writes the same `ref` fields. Without JavaScript or without a catalog for the edition it is the numeric-field form that exists today.

## 9. Work remaining

| Step | Work |
| --- | --- |
| F | In-game verification of phase 1 on Retail and Forever (section 5.1 list), including taint on the player's own talent window |
| C | Classic provider (section 5.5): shipped per-class table (tools script plus in-game dump), data-driven grid, Mists tier/column grid |
| G | Dump command and committed catalogs for the website (in-game `GetTraitView` output; Raidbots `talents.json` as a validator) |
| I | Web picker (SVG) |

## 10. Risks

1. **Taint from driving Blizzard's window** (section 5.1): unverified; a Blizzard error that points at Rotation Master after the tree was opened is the signal. The drawn provider is the answer; a setting that prefers it is a one-line change (`priority`).
2. **The shared view config** (`VIEW_TRAIT_CONFIG_ID`): `InitializeViewLoadout` replaces what the player's open window is previewing from a link. RM refuses when the window is inspecting.
3. **Blizzard renames** `TalentButton.OnClick`, `ButtonsUpdated` or `PlayerSpellsFrame.CloseFrame`: the click is lost, the tree opens but nothing picks; the strip's Close button and the Talent list still work.
4. **Classic data for other classes** does not exist in game (section 5.3).
5. **Window layering**: RM's windows are full-screen dialogs; Blizzard's frame is raised to the same strata and the strip is anchored above it.

## 11. Open decisions

1. Whether to keep Blizzard's window as a hidden opt-in at all (section 5.6), or remove the provider.
2. Whether to build the classic provider now (section 5.3) or after the in-game pass of phase 1.
