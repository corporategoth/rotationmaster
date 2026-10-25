# Universal talent selector: design

Status: design only. Nothing in this document is built except where it says "shipped with the Retail talent fix".
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

## 4. Providers behind `Platform/`

One module per client family, selected by the existing `GetTalentLayout()`, behind one entry point:

```lua
platform:GetTalentCatalog(query) -> catalog | nil, reason
query = { spec = <body.specs value>, hero = <subtree id>?, want = "active"|"any" }
```

| File (new) | Family | Source | Offline spec |
| --- | --- | --- | --- |
| `Platform/talent_provider_traits.lua` | Retail | what `GetTraitTalents` does today, plus positions and edges (`GetNodeInfo` `posX/posY/visibleEdges`) | view loadout (shipped) |
| same file, Forever branch | Forever | the class trait tree; its three classic trees are node groups (`GetGroupDisplayInfoByTreeID`), so `trees` = the groups and `layout = "graph"` with the group as the tab | not needed: one class tree, all groups readable in the active config |
| `Platform/talent_provider_tree.lua` | Era, SoD, TBC, Wrath, Cata | `GetNumTalentTabs`, `GetNumTalents`, `GetTalentInfo{specializationIndex, talentIndex, groupIndex}` -> `row` = `tier`, `col` = `column`, `maxRank`, `rank`, `talentID`, `spellID`; `GetTalentTabInfo` for tab name/icon/background | all three trees are always readable; `groupIndex` reads the inactive talent group of dual spec (the rotation's slot) |
| `Platform/talent_provider_grid.lua` | Mists | `GetTalentInfo{tier, column, groupIndex}`, 6 x 3, class-wide (not per specialization) | `groupIndex` for the other group |

Today's `GetTreeTalentInfo`, `GetGridTalentInfo`, `GetTraitTalents` stay as the low-level readers; the providers are thin and only normalize. Evaluation never goes through a catalog (it keeps the cached per-notification reads in `Core/build_context.lua`); catalogs are built when an editor opens and dropped when it closes, so there is no hot-path cost.

Mapping the rotation to a catalog: `body.specs` holds one kind of value per client (`Platform/specializations.lua` `GetRotationSpecKind`): Retail and Mists specialization IDs ("portable"), everything else a talent group slot. The editor passes the rotation's spec (already available to the widget as `spec`). Retail with several `body.specs` opens on the first one that is not the played specialization if the rotation is not for the played one, else the played one; a specialization switcher lists the class's others.

## 5. The popup window

### What the user sees

A resizable workbench dialog (`UI/window.lua`, same chrome and Escape handling as the other pickers), opened by an icon button beside the Talent dropdowns (which stay: section 8).

* Header: specialization switcher (Retail), hero tree switcher, the active/preview badge ("Your talents" vs "Preview: Frost, not your active loadout").
* Body, by `layout`:
  * **graph** (Retail, Forever): node icons at `x/10, -y/10` from the tree origin, lines between linked nodes, class tree on the left and specialization tree on the right as in the game's window (the node coordinates already encode this), hero tree as a separate tab or panel so its coordinates (which overlap the main tree's) do not collide. Choice nodes draw as a split icon; clicking a half selects that entry. Pan and zoom are needed only for Forever's group tabs and small screens; a fixed fit-to-width scale computed from the bounding box is enough for the first version.
  * **tree** (Era/TBC/Wrath/Cata): three tabs (or three columns when width allows) with the 4-column classic grid at `row`/`col`, rank badges, the tab's background art by `GetTalentTabInfo`.
  * **grid** (Mists): 6 rows of 3.
* Click behavior: single click selects the talent for the condition (the dialog closes unless Shift is held, for conditions that want several). Multi-rank talents: the rank is not part of the choice; the condition's `Rank` field stays where it is, and the popup shows `n/m` only as information. A selected talent shows a highlight ring; the talent currently stored in the condition is pre-selected and scrolled into view.
* Hover: spell tooltip, `GameTooltip:SetSpellByID(spellID)` (classic additionally `SetTalent(talentID, inspect, pet, group)` where available so rank text is right). If the spell is unknown to the client, the name only.
* Active-state decoration (rank > 0) only for `source = "active"`; a previewed specialization shows no ranks, because it is not the character's.

### Reuse Blizzard's buttons, or draw our own

| | Reuse `Blizzard_SharedTalentUI` templates (`TalentButtonSpendTemplate`, `TalentButtonSelectTemplate`, `TalentEdgeStraightTemplate`...) | Draw our own (textures, `CreateLine`, atlases) |
| --- | --- | --- |
| Look | Exactly Blizzard's, including future art changes | Close, but ours; frozen until we update |
| Coupling | Heavy: the mixins expect a `TalentFrameBaseMixin` parent (`GetAndCacheNodeInfo`, `GetTalentFrame`, currency, search, gating) and Blizzard_SharedTalentUI/Blizzard_PlayerSpells loaded | None |
| Taint | Mixin code and its callbacks run under our script's taint; any template path that touches secure state or `securecall`-guarded Blizzard globals can spread taint to Blizzard frames that share a mixin table | None: our frames, our scripts |
| Secret values | Blizzard code would read C_Traits and compare/format values itself; a secret value reaching it errors inside Blizzard code where we cannot guard | We read through `CanReadValue` and decide |
| Clients | Retail and Forever only; classic frames are a different generation | One drawing layer for all five |
| Cost | Low to start, high to maintain (every Blizzard UI refactor, 11.0 and 12.x both moved things) | Medium once, then small |

Recommendation: draw our own, borrowing only what is data: atlas names for node art and edges (read from `Blizzard_SharedTalentUI/Blizzard_TalentButtonArt.lua` and the edge templates, checked for existence with `C_Texture.GetAtlasInfo` and replaced by plain textures when absent) and the position math above. Rejected on the same grounds: hooking Blizzard's talent window in view mode and capturing clicks (view mode disables clicks, and hooks on secure buttons are the classic taint source).

Cost of drawing: node pool (about 120 nodes for a Retail class + spec, plus hero), line pool (about 150), one `OnEnter/OnLeave/OnClick` set bound by index. All pooled, built once, reconfigured per catalog; nothing runs on a timer.

## 6. Offline editing

The editor is open for a rotation whose specialization the character is not playing (a Frost mage editing a Fire rotation).

* **Retail**: view loadout (shipped). Remaining work for the popup: positions and edges come from the same view-config `GetNodeInfo`; hero trees of the previewed specialization come from `GetHeroTalentSpecsForClassSpec(VIEW_TRAIT_CONFIG_ID, specID)`. Constraints: not in combat; replaces whatever build Blizzard's own window is previewing from a link (a one-line notice in the dialog); `level` should be the maximum level so hero nodes are visible (the shipped code passes `GetMaxLevelForPlayerExpansion()`, else the player's level). Unverified in a real client: that the view config answers `isVisible = true` for exactly the previewed specialization's nodes, and that `InitializeViewLoadout` is callable from addon code outside a hardware event.
* **Forever**: not needed, one class tree.
* **Era/TBC/Wrath/Cata**: the three trees are all readable; dual spec's other group is read with `groupIndex`. A character with a single talent group has no second group, but the *shape* of the trees is identical, so the preview reads group 1's data and hides ranks.
* **Mists**: grid is class-wide, group index only changes which choice is selected.
* **Class mismatch**: a rotation for another class cannot be previewed on any client (the API only knows the character's class). The popup then says so and falls back to node/ID entry.

Failure reasons (`in-combat`, `talent-tree-unavailable`, `missing-api`, `restricted-value`, `api-error`) are surfaced as one line in the dialog and in the condition editor; they never produce an empty tree.

## 7. Fallback dropdown (d)

Kept as the always-available path, not removed:

* where the popup cannot draw (any reason from section 6, a client the provider does not know, no `CreateLine`), the existing dropdowns remain and now share the catalog (icons in the list, group tabs, the specialization list). This is what the Retail fix ships.
* manual entry (node ID, choice entry ID; spell ID for the website) stays for sharing and for talents the client cannot list.

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

## 9. Work estimate (one developer, in-game testing included)

| Step | Work | Days |
| --- | --- | --- |
| A | Providers and `GetTalentCatalog` (tree, grid, traits incl. positions/edges), unit tests with fixtures per client | 4-5 |
| B | Popup shell, graph layout and drawing, pooled nodes/lines, Retail + Forever, tooltips, selection | 6-8 |
| C | Classic tree and Mists grid drawing, tab art, dual-group handling | 3-4 |
| D | Spec/hero switchers, offline preview notices, combat handling, fallback wiring in the condition editor | 3 |
| E | Localization of new strings (ten locales), help text, docs | 1-2 |
| F | In-game verification pass per client (Retail, Forever, Era, TBC, Wrath/Cata, Mists) and fixes | 5-8 (largest uncertainty; needs real clients) |
| G | Dump command and committed catalogs for all classes/editions; check tool | 3-4 plus maintainer login time |
| H | Game Data API snapshot job and 30-day expiry logic | 3-4 (+2 if classic endpoints need discovery) |
| I | Web picker (SVG), per-edition catalog loading, tests | 5-7 |

Total about 33-45 working days; A-F (the in-game selector) about 22-30, G-I (website) about 11-17. The Retail fix already delivered covers part of A and D for Retail.

## 10. Risks

1. **View loadout behavior is unverified in a real client** (section 6). If `InitializeViewLoadout` is blocked for addons or returns different visibility, offline Retail editing degrades to node ID entry; nothing else breaks. This is the first thing to test.
2. **Taint**: custom drawing avoids the Blizzard templates for this reason; the remaining taint surface is `GameTooltip` use, which every picker already has.
3. **Blizzard changes the tree shape** (12.x already reshuffled hero talent containers). The model keys on node and spell IDs and ignores layout containers, and the spell fallback covers node renumbering; position math follows `TranslateNodePositionsToAnchorPositions`, which is one function to re-read per major patch.
4. **Hero tree overlap**: hero nodes use their own coordinate space; drawing them in the main canvas would overlay. They get their own panel.
5. **Classic Game Data endpoints may not exist**; plan G does not depend on them.
6. **API data quality** (missing specs, duplicate talents, IDs that may not match `C_Traits`): the API is a validator, not the primary source.
7. **Performance**: a catalog is built per editor open (roughly 600 API reads for a Retail class) -- fine for a dialog, never on the evaluation path. If it shows in profiling, cache per talent notification the way the build context does.
8. **Window size**: Retail trees are about 800 x 600 at Blizzard's scale; on low UI scales the dialog must scale to fit and fall back to the dropdowns when it cannot.
9. **Saved data**: only additive optional fields (`spell`, later `talentID`), validated in `valid`; the website schema catalog must be regenerated when merged (`tools/export_web_schema.lua` / `tools/export_web_conditions.py` on the website branch) because TALENT's field list gained `spell`.

## 11. Decisions needed

1. Draw our own tree (recommended) versus reuse Blizzard's templates for Retail.
2. Whether the in-game dump may be the primary website source, with the Game Data API as validator (recommended), or the API must be primary.
3. Whether classic references gain an optional `talentID` now or later.
4. Whether the popup replaces the dropdowns where it works, or sits beside them (recommended: beside, until in-game verified on every client).
