# Talent selector

How the TALENT condition picks a talent on each client, what the "Show talent tree" window is, and what is deliberately not
there. Written from the pinned Blizzard UI source (`docs/quality/client-api-sources.json`: live 12.1.5.70575, forever
1.60.1.70532, classic 5.5.4.70579, classic_era 1.15.9.70003, classic_anniversary 2.5.6.70006) and the committed client API
manifests. Only the Retail window has been seen in a real client (section 5); everything else is verified against models of the
documented API, and the claims below say which.

## 1. The three layouts

`Platform/talents.lua` `GetTalentLayout` names the layout of the client; each one stores a different reference in the condition.

| Layout | Clients | Reference stored in the condition | Reader |
| --- | --- | --- | --- |
| `tree` | Era, SoD, TBC Anniversary, Wrath, Cataclysm | `tree`, `talent` (indices), `operator`, `value` | `GetNumTalentTabs`, `C_SpecializationInfo.GetTalentInfo{specializationIndex,talentIndex,groupIndex}` |
| `grid` | Mists Classic | `layout="grid"`, `value` = slot 1-18 | `C_SpecializationInfo.GetTalentInfo{tier,column,groupIndex}` |
| `traits` | Retail, Forever | `layout="traits"`, `node`, `entry` (choice nodes only), `spell`, `operator`, `value` | `C_ClassTalents` + `C_Traits` |

A talent picked from the Retail or Forever list also stores its `spell`; evaluation falls back to the spell when the saved node no
longer holds it (Blizzard renumbered the tree). A reference without `spell` evaluates exactly as before.

## 2. The dropdown picker

The lists are the picker on every client (`Conditions/talent.lua` `block`, laid out by `UI/condition_layout.lua`
`layoutIconRows`, tested by `tests/talent_picker_layout.lua`): the talent's icon is the left column and spans two rows (a question
mark until a talent is chosen), the upper list and the talent list sit to its right, and the "Show talent tree" button sits beside
the talent list when the pane has room, else under the rows.

| Client | Upper list | Talent list |
| --- | --- | --- |
| Retail | Specialization (the rotation's, any of the class's) | one list, grouped under headings: class, specialization, then one heading per hero tree; a choice node lists each choice |
| Forever | Talent Tree (the three trees of the loadout) | that tree's talents |
| Era, SoD, TBC, Wrath, Cataclysm | Talent Tree | that tree's talents, with icons |
| Mists | Tier (1 to 6, with its level) | the tier's three talents |

What is read, and what is not (`Platform/talents.lua`):

* The played specialization (and Retail's own specialization whenever the active config is not yet known) is read from the
  **active config**: `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo/GetTreeNodes/GetNodeInfo/GetEntryInfo/GetDefinitionInfo`,
  the same reads Blizzard's talent window makes, with the same visibility rule (`isVisible`,
  `HeroTalentsContainer:IsNodeInAvailableSubTree`). Nothing is loaded or opened for it.
* Another specialization is read from Blizzard's **view config**: `C_ClassTalents.GetTraitTreeForSpec(specID)` names its tree,
  `C_ClassTalents.InitializeViewLoadout(specID, level)` fills config `-3` (`Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID`), and
  `C_Traits.GetTreeNodes/GetNodeInfo/GetEntryInfo` answer for it (this is what the talent window does to show a shared build,
  `Blizzard_ClassTalentImportExport.lua` `ViewLoadout`). It is refused in combat (`in-combat`) and while the talent window is showing
  someone else's build (`talent-window-inspecting`). This is the one read path not proven in a real client.
* `C_Traits.GetTreeNodes(treeID)` returns the nodes of every specialization of the class plus the hero nodes; `isVisible` and the
  hero subtree list (`C_ClassTalents.GetHeroTalentSpecsForClassSpec`) say which belong to the specialization shown. That call is
  documented "MayReturnNothing"; when it answers nothing, the subtrees named by the visible hero selection node's entries are used.
* Names and icons are the talent window's own (`overrideName`, else the spell's name; `overrideIcon`, else the spell's icon). A spell
  record the game refuses or has not loaded falls back to `C_Spell.GetSpellName/GetSpellTexture` before an entry is given up on.
* Class and specialization talents are split by the talent window's own columns (class tree left, specialization tree right, a gap
  between); with no clean gap they stay one group, "Class and specialization talents", rather than guess.
* No Retail return in the talent APIs is documented secret; every value is still read through `CanReadValue`.
* When nothing can be listed the editor says why, with the reason code, and the tree button is disabled; the node and entry IDs
  stay editable.

`/rm debug talents [views]` writes a report of each call and what it answered (raw error text included) into a copyable window and
`RotationMasterDB.diagnostics.talents`; `views` also reads every other specialization of the class (`Diagnostics/talents.lua`). It is
the way to find out what a real client says.

## 3. The tree window and its providers

`Platform/talent_tree.lua` is the provider registry: `platform:RegisterTalentTreeProvider(id, {families, priority, available, open})`.
`open(context)` returns a handle (`Reload`, `Close`) or nil and a reason; `platform:GetTalentTreeProviders()` lists the providers
that can serve the client now, lower priority first; `platform:HasTalentTreeProvider()` decides whether the button exists at all. The
window (`UI/talent_popup.lua`) tries them in order and keeps the first whose `open` succeeds, so a provider that cannot show the tree
now (combat, a window it must not disturb, a missing API) says why and the next one runs. The context carries the wanted
specialization and hero tree, the saved selection `{node, entry, spell}`, and `onSelect` / `onClose` / `onChange` callbacks. A pick
writes exactly the fields the dropdown writes, so no saved data changes.

The same file holds the trait view both providers consume: `GetTraitView` (node order, geometry in tenths of a pixel, entries, edges,
hero trees, active or view loadout; never in combat), `FindTraitViewSelection` (node and entry, else the spell), `EncodeTraitView` and
`GetTraitViewLevel`. Node kinds are `Enum.TraitNodeType` Single 0, Tiered 1, Selection 2 (choice), SubTreeSelection 3 (hero chooser).

| Provider | Clients | Priority | Available |
| --- | --- | --- | --- |
| `drawn` | Retail, Forever | 50 | whenever the trait tree can be read |
| `blizzard` | Retail, Forever | 10 | only when `RotationMaster.db.global.talent_popup_provider == 'blizzard'` |
| (none) | Era, SoD, TBC, Wrath, Cataclysm, Mists | | the button is hidden; the dropdowns serve |

The window itself (the control strip: specialization and hero tree switchers, the current choice, the reason a tree cannot be shown)
is movable, uses the same chrome and Escape handling as the other windows, and closes when the editor that opened it is released.

### The drawn tree (the default)

RM draws the nodes from `C_Traits.GetNodeInfo` of the specialization's view loadout. It looks like Blizzard's tree because it uses
Blizzard's art where the client has it: the `talents-node-square-*` and `talents-node-circle-*` frames (square for an ability, circle
for a passive, from `Enum.TraitNodeEntryType`), `talents-node-circle-mask`, the `talents-background-<class>-<spec>` backdrop (through
`ClassTalentUtil.GetVisualsForSpecID` when Blizzard's talent UI is loaded) and plain textures where an atlas is missing. The class
tree is on the left, the chosen hero tree in the middle and the specialization tree on the right (the client's own coordinates
already put them there), with a title over each pane, a choice node as its two entries at half size, the rank count on a multi-rank
talent, faint lines between linked talents, all scaled to fit.

Every talent shows in the green "selectable" frame: the tree is read as it stands and never shows the player's own purchased
talents, and the saved talent is the one gold frame with a glow. Hover gives `GameTooltip:SetSpellByID` plus the ranks, a note on a
choice node and what a click does; a click chooses the talent and closes the window; clicking the chosen one clears it (the node,
entry and spell are emptied). Escape and right click close it; the window takes the global UI scale. It is built lazily on first open,
reuses its frames and has no `OnUpdate`. Nothing is read in combat.

### Blizzard's talent window (opt-in)

The `blizzard` provider drives the PlayerSpells talents frame in view mode. Read from the pinned source (the import/export file is
byte-identical on live and forever):

* `PlayerSpellsUtil.InspectLoadout("specID:level:importString")` calls `TalentsFrame:ViewLoadout`, which validates only the header
  (serialization version, at least 152 bits), calls `C_ClassTalents.InitializeViewLoadout(specID, level)` and
  `C_ClassTalents.ViewLoadout(entries, importText)`. The 128 bit tree hash is never checked in view mode, so a zero-filled hash is valid.
* The loadout string carries the hero choice: `EncodeTraitView` writes per node `0`, or `1,1,0,<choice bit>[,<2 bit entry>]`, packed
  six bits per base64 character, least significant bit first. The test fixture decodes the strings with an independent
  reimplementation of Blizzard's `ImportDataStream`.
* The saved talent is encoded as purchased, RM calls `TalentDisplayMixin:SetGlowing(true)` on its button and anchors a gold ring to
  it, re-applied on `TalentFrameBase.ButtonsUpdated`. If the client refuses the loadout, the string is retried with the hero choice
  alone and then with the bare tree.
* A click arrives through `EventRegistry "TalentButton.OnClick"`, which all three button mixins trigger before their inspect checks.
  The pick is applied on the next frame so it does not run inside Blizzard's click handler.
* On close RM restores the window's strata, tab and visibility. It refuses to disturb the window when it is inspecting a link or
  another player, or has staged talent changes. Nothing is opened in combat; `PLAYER_REGEN_DISABLED` ends the session.
* Forever has no specialization API of its own; the header uses `PlayerUtil.GetCurrentSpecID()`, which answers the pseudo-specialization
  IDs its frame is keyed by.

Why it is opt-in: the first real-client test (Retail, Brewmaster Monk, 2026-10-26) showed the window titled "Linked Talents", filled with
the player's current purchased talents instead of an empty tree, with Blizzard's "Copy Loadout Code" button, flat gray rows below
the unlocked ones, and clicks that selected nothing. the gray rows are Blizzard's own rule: `TalentButtonSpendMixin:IsSelectable()`
requires `not IsInspecting()`, so in view mode no unpurchased node can look selectable, whatever the loadout string says. The copy
button is shown by `ClassTalentsFrameMixin:UpdateInspecting`. The player's own talents and the dead clicks are not explained by the
Lua source (`InitializeViewLoadout` and `ViewLoadout` are native); the likeliest reading is that the player's own specialization
starts from the current loadout and the entries overlay it. Other addons that drive this frame (Talent Tree Tweaks, Talent Loadout
Manager) ship workarounds for taint around `SetInspecting`, `ShowUIPanel` and `PlayerSpellsFrame:OnHide`; RM does not port them,
because they edit Blizzard's secure environment and cannot be checked without a client. The drawn tree is the default for these
reasons, and the Blizzard window falls back to it when it cannot open.

Still unconfirmed in a real client: taint in the player's own talent window after the tree was opened; that `ViewLoadout` accepts a
loadout with only the chosen hero tree and one purchased talent; that the Forever frame honors the same calls; how the frame layers
against RM's windows; that a 12.x client has not renamed `TalentButton.OnClick`, `ButtonsUpdated` or `PlayerSpellsFrame.CloseFrame`.
Each degrades to the drawn tree, never to a broken window.

## 4. The classic clients

No provider serves them, so the button is hidden and the dropdowns are the picker. Blizzard's classic frames cannot be driven the
way the modern one can (read in classic_era 8165d4c, classic 15c8a754 and anniversary 2cfec7c):

* `Blizzard_TalentUI` (`PlayerTalentFrame`) shows only the player's own class and talent group, has no view or link mode, and
  `PlayerTalentFrameTalent_OnClick` spends or previews a point; hooking the button cannot stop that. Cataclysm is the same; on Mists
  `PlayerTalentFrame_SelectTalent(tier, id)` makes a real choice.
* `Blizzard_InspectUI` shows an inspected unit's trees (`NotifyInspect`, `INSPECT_READY`) of that unit's class only.
* No classic talent API takes a class: `C_SpecializationInfo.GetTalentInfo`, `GetNumTalentTabs`, `GetTalentTabInfo` and
  `TalentFrame_Update` have no class parameter, and there is no `C_ClassTalents` / `C_Traits` view loadout. The player's own class
  can be read live; any other class would need shipped data. Only Forever, a trait client, reads any class from the game.

Every classic talent addon draws its own buttons with Blizzard's textures (Talented, Classic Talent Viewer, Modern Talents TBC for the
player's own class). Their data is not copied (Talented's licenses conflict, Classic Talent Viewer's table is All Rights Reserved), and
no third-party addon or library is embedded or depended on. LibTalentTree-1.0 was evaluated and set aside: its README grants
redistribution of unmodified copies with all other rights reserved, its TOC allows embedding, its CurseForge page says LGPLv3 and its
repository has no LICENSE file; it also rewrites the shared view config for every specialization to build its cache, which would swap
a tree RM is showing. If it is ever embedded, record exactly that and keep its header intact.

## 5. Tests and files

* `Platform/talents.lua`, `Platform/talent_tree.lua`, `UI/talent_popup.lua`, `Conditions/talent.lua`, `Diagnostics/talents.lua`.
* `tests/talent_tree_popup.lua` with `tests/fixtures/blizzard_talent_window.lua` (a model of the window and its events that decodes
  the strings independently), `tests/fixtures/retail_traits.lua` (a model of the documented trait API), `tests/retail_talent_picker.lua`,
  `tests/talent_picker_layout.lua`, `tests/talent_diagnostic.lua`, `tests/platform_talents.lua`, `tests/talent_conditions.lua`.

## 6. Not built

* A classic provider. It would need a shipped per-class table of trees, rows, columns, rank spell IDs and prerequisites (wowsims
  publishes MIT-licensed per-class JSON for Classic, Wrath, Cataclysm and Mists, none for TBC; Wrath's index order is not row-major,
  so the saved `{tree, talent}` indices need an in-game dump to map) and a grid drawn from it.
* A single catalog structure shared by all layouts. Each layout keeps its own reference; the trait view is the only structured tree.
* Storing a stable `talentID` next to the classic `tree` and `talent` indices, which would survive an index shift between builds.
* Talent catalogs for the website. The web editor cannot read game data, so it keeps the numeric-field form for talents; the data
  would have to be generated from the same trait view in game.
