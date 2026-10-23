# Optional integrations

The Integrations page is a fixed inventory of addons that RM actually consumes or detects, with editor preferences alongside it. The current research catalog contains 23 addon identities and 85 release, source and author links. Bundled libraries are dependencies, not addon inventory rows. The Native row is an RM editor preference, not an installable addon. Registered custom editor providers can participate without being fabricated as supported third-party addon records.

| Group | Supported addon identities |
| --- | --- |
| Lua editors | `!!!LuaWorkbench` (LuaWorkbench), `WowLua` (detection only) |
| Condition data | `ExtendedCharacterStats`, `MobInfo2` |
| Recommendation notifications | `WeakAuras` |
| Quest callbacks | `Questie` |
| Boss mods | `DBM-Core` (DBM), `BigWigs` — one enabled at a time |
| Top panels | `Titan` (Titan Panel; passive, through RM's LibDataBroker object) |
| Action bars | `ElvUI`, `Bartender4`, `ButtonForge`, `G15Buttons`, `SyncUI`, `LUI`, `Dominos`, `DiabolicUI`, `AzeriteUI`, `Neuron`, `FarmingBar`, `TotemTimers`, `SamyTotemTimers` |

## Cards and display evidence

Each nonempty group uses the existing collapsible settings section. Collapse state belongs to the view, does not dirty the profile, and does not enable or disable an integration. Cards span the available form width and align Addon, Version, Description and Status columns. Versions wrap rather than being clipped or abbreviated. A version is shown only with addon-loaded evidence; installed-but-not-loaded metadata is retained by the catalog but omitted from the card. Loaded state is independent of cached connection state, so a loaded addon can still show its version when its integration status is unknown.

Pill colors distinguish Not loaded (gray), Supported (blue, read-only), Disabled (red), Enabled (green) and Selected (yellow). Supported means the row has no implemented enable/select control; it is not native compatibility certification. The catalog separately distinguishes loaded from connected and only reports a connection when an existing RM capability or cached service status establishes it. Not loaded does not mean not installed. Display strings escape native markup and controls, preserve complete UTF-8 characters, and are bounded; an oversized version is refused rather than displayed as a misleading prefix.

Only Native syntax highlighting has card-specific Help. Its gold Help button uses the same 20-pixel button and 18-pixel icon as condition cards. It sits below Status, right aligned; Native Help shares the first option row instead of adding space before it. General editor, line-number and integration guidance remains in the page Help. Show line numbers appears directly below the Lua editor section heading, outside Native; Native contains only its Syntax highlighting checkbox. Passive or detection-only integrations have no invented preference switches. Some read-only integrations still call provider APIs during their existing gameplay work; read-only controls do not imply a data-only backend.

Clicking a linked addon name opens a draggable, reusable Provider / URL / Copy dialog. Provider labels, URL fields and Copy icons share each row’s vertical center, including wrapped labels. It lists every curated channel for that identity; Copy selects the immutable URL for manual Ctrl+C. It neither opens an external browser nor installs anything. The author-published WowLua GitHub URL is deliberately retained with an unavailable label and note; it is not presented as a working repository, and another official source is listed.

## Release channels and client scope

`tools/integration_projects.json` is the reviewed research input. Every identity records independent searches of CurseForge, WoWInterface, Wago Addons, WowUp Hub and GitHub, even when a primary download is already known. Official author sites may add links. An official GitHub repository is retained alongside a primary CurseForge or other release channel. A verified official website is listed first and marked primary when one exists; otherwise exactly one release/source link is primary. Forks, historical bundles and different-folder successors are labeled separately. WoWInterface links use stable project IDs and project-name URLs rather than release-version captions; file-specific download links do not substitute for the project page. An unavailable page or failed access is unverified, not evidence of absence. A not-found result means no exact matching project was found in the recorded search, not that an addon manager cannot install the addon through another provider.

The generated block in `Integrations/catalog.lua` contains links and declared edition scopes. `GetIntegrationClientSupport(id, client)` classifies them as supported, unsupported or unknown. The settings page hides only explicit unsupported results, including editor candidates and menu alternatives; unknown entries stay visible. Native remains available. Editor resolution applies the same scope rules when an editor is opened. Client information is read on these cold paths, not on a recommendation timer.

Scope describes the editions advertised for the exact addon identity, not actual-client acceptance. An old patch or lack of a recent release does not establish a maximum supported interface version. Interface bounds require explicit evidence; progression branches are stated separately, and an unknown progression branch remains unknown. G15 Buttons and SyncUI are historical Retail identities without an inferred patch maximum. LUI's same-folder Classic fork is distinguished from Retail Core. A different-folder successor cannot silently widen the original integration's scope.

Catalog loading performs no discovery or native query. Listing uses bounded addon load/version metadata and existing cached status; it does not construct editors, invoke gameplay readiness callbacks, query quest progress, install/load another addon, or register a provider. Controls are pooled and guarded by the form owner and drawing generation. These settings changes add no gameplay subscription, polling loop, recommendation work or CPU-profiling behavior. Offline geometry checks do not establish native pixel acceptance.

## Editor enablement and selection

Enabled and selected are separate. An enabled, available editor offers Disable or Select. Clicking Selected stages its disable together with a handoff to the sole enabled available alternative. Several alternatives require an explicit menu choice; cancel changes nothing. With none available, RM falls back to plain editing. Enabling a disabled editor selects it when no editor is effectively selected; otherwise it only enables it. Availability and client scope are checked again before menu publication.

The UI has no None or Automatic row. Existing `profile.lua_editor="auto"` remains compatible: it resolves to a sorted enabled, available registered external provider, then Native. Disabled providers are excluded. Plain remains the emergency fallback when Native is disabled; it cannot itself be disabled. `profile.lua_native_highlighting` is an optional Boolean. When absent, its legacy value follows whether `lua_editor` is plain; explicit editor actions preserve that inferred preference. Selecting Native uses the native or plain token according to this preference.

`profile.lua_editor_disabled` is an optional plain true-only map with at most 64 entries. Provider identifiers follow the existing nonblank name contract, are bounded to 128 bytes, and exclude auto/plain. Stored unknown identifiers are inert future preferences. Registered custom providers can be selected and disabled through this same map. Adding a 65th disabled identifier is refused without partial changes. WowLua remains detection-only unless a real editor provider is separately registered.

Editor preference changes and Questie's independent opt-in use the existing Apply/Discard transaction. Selection plus disable/handoff are staged atomically; conflicts refuse partial publication. Profile copy/import preserve the preferences, reset restores defaults, and merely drawing or collapsing the page does not normalize saved data. Apply affects the next source-editor opening and does not forcibly replace an editor already open.

## Questie callbacks

`addon.Integrations.NewQuestie(options)` is an original consumer of the documented public Questie API. RM retains one private service for its lifetime. `profile.questie_enabled` defaults to false and follows Apply/Discard, profile copy/reset and import rules; profile transport accepts only a Boolean preference. Toggling the card changes the draft, and synchronization waits for Apply. The card has no refresh button, inline status prose or Help icon; the page Help explains the receipt-only scope.

A dedicated ADDON_LOADED observer is registered only while the saved preference is enabled. It survives rotation event cleanup and refreshes when Questie loads later; there is no timer or background polling. The backend's explicit refresh method can check current provider availability. Equally enabled profiles share recent player-provider observations; switching to a disabled preference retires callbacks and receipts. No observation is assigned to a rotation or profile.

Readiness and update callbacks use the upstream dot-call contract. Upstream has no unsubscribe handle, so guarded lifetime trampolines provide logical retirement. Replaced APIs, stale callbacks, failed registrations and reentrant disable cannot publish into a newer connection. Recent update receipts are bounded to 64 quest identities and 30 seconds. They report callback arrival only; they do not infer current objective progress, completion, eligibility or rotation selection.

The source-tested callback contract is pinned to Questie 12.1.0, commit `876731025e1e02248c6b19afb46027fd4cf69766`. Other versions are marked unverified. Published edition scope, source-tested API compatibility and native acceptance are separate facts; unsupported or restricted observations cannot borrow another client's success. No provider implementation, database or artwork is bundled. Native behavior remains unverified until actual-client testing.


## Boss mods (DBM / BigWigs)

`addon.Integrations.NewEncounterTimers(options)` in `Integrations/encounters.lua` consumes one boss mod's public callbacks into a small cache that the `BOSSMOD_ENCOUNTER`, `BOSSMOD_STAGE` and `BOSSMOD_TIMER` conditions read. `profile.encounter_provider` is optional (`DBM-Core`, `BigWigs` or absent) and follows Apply/Discard, copy/reset and import; transport rejects any other value. The two cards are Enabled/Disabled pills; enabling one disables the other, so there is never a reconciliation between two boss mods. Nothing is registered with either addon until one is enabled.

Contracts were read from source, not inferred from names:

| Provider | Registration | Events consumed |
| --- | --- | --- |
| DBM-Core 12.1.17 (installed TBC Anniversary copy) | `DBM:RegisterCallback(event,f)` / `DBM:UnregisterCallback(event,f)`; `f(event,...)` | `DBM_Pull`, `DBM_Kill`, `DBM_Wipe`, `DBM_SetStage`, `DBM_TimerBegin`, `DBM_TimerStop`, `DBM_TimerUpdate`, `DBM_TimerPause`, `DBM_TimerResume` |
| BigWigs master `5592509` (GitHub `Loader.lua`, `Core/BossPrototype.lua`) | `BigWigsLoader.RegisterMessage(owner,event,f)` / `.UnregisterMessage(owner,event)` with a private owner; `f(event,...)` | `BigWigs_OnBossEngage/Win/Wipe/Disable`, `BigWigs_SetStage`, `BigWigs_StartBar/StopBar/PauseBar/ResumeBar/StopBars` |

Encounter identity is the game's encounter ID (`mod.encounterId` / `module.engageId`), which both providers share; display names are labels only. DBM fires Kill/Wipe only for mods that keep statistics, so liveness is read from `mod.inCombat` (BigWigs: `module.isEngaged`) whenever a condition asks, and a mod that left combat ends the encounter without any callback. A stage that was never reported counts as 1. Timers are keyed by the provider's bar ID (DBM) or module plus bar text (BigWigs) and matched by the ability's spell ID; bars without a spell ID (pull, respawn, queue timers, BigWigs option keys) are ignored. At most 64 timers are kept, evicting the soonest; expired timers drop lazily on read. Pause keeps the remaining time; update recomputes it.

Cost: no frame, timer or OnUpdate exists while disabled. While enabled, work happens only inside the boss mod's own callbacks (a few table writes) and when a condition reads the cache (one table scan of running timers, no allocation). A selected provider that is not yet loaded registers ADDON_LOADED only until it binds. A callback error, restricted payload or invalid clock faults the adapter: observations are cleared, later callbacks are ignored and the status reports the reason; re-selecting rebinds. Callbacks are not removed from inside the provider's own dispatch loop. Retail and Forever report the adapter incompatible, because their boss-mod payloads may carry secret values; the conditions are then unavailable.

Without an enabled, loaded provider every boss-mod condition is unavailable (also under NOT), never silently false. With a provider, no encounter or no running timer is a real false. One-time seeding (`bossModConditionsSeeded`) adds the predicates to the Combat category and `BOSSMOD_ENCOUNTER`/`BOSSMOD_STAGE` to the Switch picker in existing profiles; later removals stay saved. Automatic switching sees encounter changes on its normal re-check interval; no extra switch trigger is added. The condition icons are temporary Blizzard textures: packaged semantic artwork for the three predicates has not been generated yet (`tests/condition_icons.lua` reports this).

## Top panels (Titan Panel)

RM has always published a LibDataBroker data source (active rotation text, tooltip, left-click configuration, right-click rotation menu). Titan Panel's `TitanLDB.lua` adopts existing objects through `DataObjectIterator` and `LibDataBroker_DataObjectCreated`, so no Titan-specific code exists; the card is passive. Text changes only on rotation changes, never on the polling path. Panel absence has no effect on selection; the minimap button remains the native fallback.

## Evaluated and not integrated

| Candidate (TBC Anniversary install) | Decision |
| --- | --- |
| Details! (+ TinyThreat) | Not now. Rotation conditions do not need meter totals; Details' own data is built from the same combat log RM already reads. Design for later analytics: read completed-segment totals through Details' published `API.lua` after combat, never during polling, labelled as Details-sourced and never mixed with RM's own measurements. |
| Threat meters (TinyThreat, ThreatClassic) | Not needed. They re-export native `UnitDetailedThreatSituation`; RM's THREAT/THREAT_COUNT already read the native API. |
| Plater | Not needed. Plater renders the same native nameplates RM already counts (NAME_PLATE_UNIT_ADDED/REMOVED); it adds no enemy information. |
| Method Raid Tools | Not now. Raid notes are free text authored per raid; there is no stable assignment contract RM could read safely. |
| GTFO | Not now. Its alerts are sound/visual side effects without a documented callback; "standing in bad" is better left to the player. |
| TomTom, HandyNotes, Atlas, GatherMate2, RareScanner, NovaInstanceTracker | No rotation value; native ZONE/INSTANCE/OUTDOORS cover location. |
| LittleWigs | Uses the BigWigs contract; covered by the BigWigs adapter when installed. |
| ElvUI skins / other themes | ElvUI is not installed on the test client; Masque covers button skins. |

## Masque preview button skins

`profile.preview_masque` is an optional Boolean; missing and false both retain the native preview. General has separate History and Preview sections. Preview contains a Skin dropdown and a transient sample Preview button on the same row. Enablement belongs to the native Integrations pill through Apply/Discard; General does not duplicate that toggle. Skin choices are immediate appearance actions saved by Masque, outside the RM General draft. When support is disabled or unavailable, the disabled dropdown shows Blizzard Classic and Preview remains usable. The inventory groups Masque under Button skins; it does not have a separate Preview appearance page. Masque remains separately installed; its own profiles/settings are not synchronized. No AceGUI component or provider assets are bundled. The backend inventory distinguishes saved enablement, a loaded provider and a connected preview, and reports the detected addon version and cached LibStub API minor. The native Status column uses only Not loaded, Supported, Disabled, Enabled and Selected. Masque’s pill shows the profile preference as Enabled/Disabled when loaded; Not loaded stays gray even for a retained opt-in, which remains clickable to opt out. Masque and Questie have no card Help because these rows have no inline addon options; their toggle guidance stays in page Help. Missing/incompatible/error states fall back to native art. Discovery occurs on Configure, including explicit preview refresh; no load observer or timer discovers providers.

At most five native preview owners and five isolated skin child buttons are retained. Only the child receives Masque's public Group/AddButton/RemoveButton/ReSkin calls, with the display name `Rotation Master` and a stable `RecommendationPreview` group ID and explicit Icon/Normal regions under Strict=true. The native frame, header, controls, tooltip owner and pristine texture remain RM-owned. Publications update recommendation art and retain membership through ReleaseChildren. Actual child dimension changes, explicit skin choices and provider appearance callbacks may call ReSkin; no skin polling is added. No click-to-cast attributes or gameplay evaluation hooks are added.

Window release, reacquisition, profile switch, optout and provider replacement remove membership. Public RemoveButton in pinned Masque12.1.0 clears group membership after applying a default skin, so the whole child surface is hidden and the untouched native texture is revealed. Successful removal permits bounded reuse; a throwing removal permanently quarantines that child until UI reload, reports unavailable on another opt-in, and never allocates replacement frames. Synchronous provider reentry retires the outer operation and performs a late cleanup if AddButton completes after retirement.

The source contract is pinned to Masque12.1.0 commit `3b1ae9a74bf57452ffe0e0c08c4a62b5d6eebd04`, API minor110210. Edition declarations and source-model tests do not establish native pixel acceptance. Actual TBC20506 and declared modern-client checks remain required for square/masked skins, tooltip hit testing, resize, optout and independent Masque settings.

General reads selectable skins and the current selection through Masque public APIs/options. Skin changes use the setter returned by the public Group:GetOptions SkinID option, preserving Masque as the sole saved authority; private provider database or internal setters are not accessed. Public group appearance callbacks update attached children and the current General dropdown without restarting the preview. After an RM skin action succeeds, RM optionally calls the already-loaded AceConfigRegistry `NotifyChange('Masque')` so Masque's own widgets reread the saved selection. This adds no bundled/required GUI dependency and no notification during recommendation polling. Parent/global Masque settings remain separate from the RecommendationPreview subgroup. Existing valid provider choices are preserved; Blizzard Classic is the native/unavailable fallback. The documented `/masque` command remains available for other provider settings; General no longer displays a settings launcher.

The preview lock checkbox is an immediate window action in both directions, like moving/resetting the preview. It synchronizes only the saved, draft and baseline lock field, leaving unrelated staged settings and invalid text untouched. Apply/Discard does not rewind an immediate lock change.

General retains cache bypass only as an A/B diagnostic. Its checkbox is the saved requested mode. The caption shows `(pending)` when requested and loaded modes differ, otherwise `(requires restart)`. Shared Help explains checked/unchecked behavior, immediate diagnostic saving and `/reload`; redundant active/next-mode prose is absent. Cache execution and polling are unchanged.
