# Optional integrations

The Integrations page is a fixed inventory of addons that RM actually consumes or detects, with editor preferences alongside it. The current research catalog contains 19 addon identities and 71 release, source and author links. Bundled libraries are dependencies, not addon inventory rows. The Native row is an RM editor preference, not an installable addon. Registered custom editor providers can participate without being fabricated as supported third-party addon records.

| Group | Supported addon identities |
| --- | --- |
| Lua editors | `!!!LuaWorkbench` (LuaWorkbench), `WowLua` (detection only) |
| Condition data | `ExtendedCharacterStats`, `MobInfo2` |
| Recommendation notifications | `WeakAuras` |
| Quest callbacks | `Questie` |
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
