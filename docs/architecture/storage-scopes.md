# Storage scopes

This documents the current persistence boundary, including profile-contained Class and Character rotation ownership and preserved legacy recovery data.

## Current behavior

RM stores one account SavedVariables table per client installation, using AceDB's `profile`, `char` and `global` sections. It does not currently use AceDB's class or realm sections. A profile name is a sharing choice, not proof of class or character ownership. New characters use the shared `Default` profile unless their profile selection says otherwise.

| Data | Current scope |
| --- | --- |
| Rotations, fallback rotation, clone/import lineage and comparisons | Selected profile, then Class or Character owner, specialization key and rotation ID |
| Built In rotation definitions | Immutable packaged assets with class/client applicability |
| Built In enable preferences | Selected profile |
| Desired manual rotation choice | Selected profile, character, edition family, class, specialization and action context |
| Desired stock targets | Selected profile; exact item IDs and desired minimum/target quantities only |
| Announcement rules, personal item sets | Selected profile; personal currently means profile, not character |
| Condition categories, picker visibility/order, tag colors | Selected profile |
| General, editor, preview and minimap preferences | Selected profile; configuration scale is global |
| Effects, custom conditions/functions and source import provenance | Global reusable libraries |
| Global item sets | Global; a same-ID profile set takes precedence |
| Condition Test samples | Global, keyed by condition identifier; restored samples do not authorize debugging |
| Observation-cache choice (`diagnosticCacheBypass`) | Global; absent defaults to direct, explicit false selects cached and true selects direct; selected after database initialization and takes effect on reload |
| Item-set action-bar bindings and optional specialization labels | Character |
| Which profile is selected | Character, managed by AceDB |
| Observation caches, compiled registries, combat histories, editor drafts/camera/undo and diagnostics | Runtime only |

Declared class applicability is a hard gate for packaged/sourced rotation candidates, normal Built In lists and direct Built In cloning. Other eligibility constraints can still broaden candidate discovery within that class. Explicit reference/cleanup access retains old definitions and saved bodies. Ordinary custom storage uses the scoped coordinator. Legacy bodies without authoritative ownership remain preserved for explicit recovery/adoption; packaged-definition filtering alone is not ownership evidence.

“Global” means shared by characters using that account's SavedVariables store. It does not imply sharing across accounts, client installations or game editions. No current data requires realm-only storage. The `realm` field in rotation metadata is attribution, not an ownership key.

Profile Copy/Reset/Import affects the profile domain, including every Class and Character rotation partition in that profile, not just the owner currently visible in the browser. It does not copy/reset global source libraries or character bindings. Profile export includes the scoped rotation store and its lineage, but excludes those separate global/character domains; it is consequently not a complete backup of referenced global effects, item sets, custom conditions or custom functions.

## Rotation ownership

New custom rotations default to Class, with Character as an explicit alternative. Packaged Built Ins require either a declared class or explicit `applicability.universal=true`; Universal and class cannot both be set. Classless legacy portable envelopes remain readable without being reinterpreted as newly packaged Universal definitions. Cloning a Universal Built In restricts the new custom manifest to the current class and preserves the original Universal lineage baseline. Visibility, automatic/manual candidates, tags, comparisons and direct editing must use the same ownership policy.

Ownership needs real partitions behind one storage facade. Adding a class tag to the existing map cannot separate its single `DEFAULT` key into distinct class/character fallbacks. Profile selection and ownership are separate axes. The chosen design retains partitions within each profile, preserving current profile operations. Character fallback takes precedence over Class fallback; both remain separately addressable.

A scope change must be staged until Apply and move body, origins, imports and comparison mappings atomically. Workspace identities and concurrency guards must include the partition. Reuse AceDB's character keys rather than inventing a name/realm format. Owner identity is distinct from source applicability and user-entered author metadata.

`Data/rotation_store.lua` provides the pure foundation for the integrated coordinator: full scoped addresses, detached reads with validity diagnostics, explicit fallback selection, and guarded plans for create/replace/delete/move/adoption. A record carries its body and source/comparison sidecars together. The migration planner only proposes an unclaimed archive; it never guesses an owner or writes to a live profile. Production workspace, browser, runtime, transfer and adoption paths use the scoped coordinator and `profile.rotationStore`; invalid or unclaimed legacy evidence remains preserved rather than silently assigned.

Owned reads use a validated structural index and inspect only the requested records. External container, membership, record-identity or Character-class changes require explicit `Refresh`; successful refresh retires old plans/tokens, and failed refresh publishes no index. Full inventory and every commit still validate the entire store, including cross-owner aliases. Tests keep Get/ListVisible work constant with 100 versus 1,000 unrelated records. Public APIs return detached copies; source-owned runtime/header readers and guarded workspace transactions provide the internal integration. Loading the module writes no persistence root. Profile transport accepts the optional scoped root without activating it, canonicalizes specialization keys only at the declared structural maps, preserves all owners/lineage/unclaimed evidence, and rejects unsafe aliases or key collisions. Safe incomplete scoped bodies remain repairable; aggregate profile codec limits still apply.

## Migration safety

Legacy ordinary bodies have no authoritative class/character owner. Profile names, numeric spec keys and spell contents are insufficient evidence. Valid source manifests can establish declared class applicability, while unknown records need preserved recovery/adoption rather than assignment to whichever character logs in first. Independent class/character fallback collisions must remain separate; no silent merge or replacement is acceptable.

Migration must cover inactive profiles and offline character records, preserve source baselines/IDs, version the new domain and portable schema, and remain idempotent. It must not execute saved source or use Repair as a cleanup step. AceDB strips defaults at logout, so absent raw versions/values must not be mistaken for missing data or ownership evidence.

Repair recognizes current custom bindings, parameter aliases, requirements, schema/order and numeric icons without compiling saved source. Invalid semantic metadata is retained and the condition disabled; a matching active custom definition is also disabled and its registry version invalidated without running registration hooks. Read-only Check never performs those writes.

Repair also retains valid item-announcement references, numeric effect textures, current pet/any spell steps and their exact-rank/appearance fields, optional minimap state, global import provenance and offline character legacy roots. Unknown effect types are reported and preserved. These corrections do not move data between scopes or perform legacy adoption. Optional library fields are validator schema rather than manufactured saved defaults.

## Stock-target foundation

The optional profile `stockTargets` map stores only desired item IDs, minimum/target quantities and enabled state. It has no manufactured default or schema-version bump. Profile copy and portable transfer carry detached desired rows; profile reset removes the absent optional default. Carried counts, shortages, timestamps and display metadata remain runtime inputs/results and are rejected from stored rows.

The pure model accepts at most 128 uniquely identified item targets and rejects malformed shapes before profile conversion reaches generic recursive copying. Maintenance reports invalid optional plans and preserves their exact root rather than deleting or guessing repairs. Missing inventory is unavailable, while a successful complete plain count map treats absent item IDs as zero. Reports refill to the target only when carried quantity falls below the minimum; disabled rows never create shortages. The plain copyable shortage format is deterministic. This foundation does not yet add a stock editor, inventory event subscription, recurring polling or an external shopping integration.

Malformed stock is also excluded by a shallow top-level projection before generic settings-draft copying; saved data remains untouched, and all other profile values keep their original identity before the ordinary detached copy. Profile duplicate, Copy, saved-profile Compare and import replacement validate only the optional stock field again at their actual copy/comparison boundaries. They do not impose the stricter portable profile schema on ordinary copying.

If a profile-change callback invalidates the duplicate source after creating its destination, copying is refused and the previous active profile is restored. The newly created destination is retained because callbacks may have written their own data there. This bounded recovery does not promise rollback of arbitrary callbacks. Other collection comparisons retain the shared footer's existing default behavior. These safety guards prepare the stock editor; they do not add inventory observation or a stock-editing UI.

## Desired stock editor

Item Sets provides separate Item Sets and Stock sources. Stock edits exact item IDs, enabled state, and integer minimum/target quantities through the existing draft, history, View Changes, Apply and Discard controls. Minimum cannot exceed target. Item metadata is presentation only and out-of-bag IDs remain valid. Stock and item-set selections have separate identities even when their saved IDs coincide. While Stock is visible, one private session reads carried bag counts on entry, explicit Refresh and coalesced bag/world events. Leaving the view cancels its timer and unregisters its events; ordinary recommendations and polling are unchanged. Count updates change labels without rebuilding the form, moving focus, flushing pending edits or adding history. Unknown counts remain unknown. Copy shortage list requires a clean saved plan and complete required counts; it produces detached text and never applies edits or rewrites itself after bag changes. One event frame and one report surface are reused per pane across sessions.

Invalid saved stock is excluded from recursive draft/history/compare operations and remains intact until an explicit stock-only recovery confirmation. Recovery requires the same raw saved root; an equality metamethod cannot authorize replacing another root. Untouched stock is omitted from unrelated Item Sets saves and confirmed item-set deletion, preserving an external stock replacement. Changed stock must pass current/proposed validation and ordinary saved-baseline conflict checks before Apply.

The Stock page also summarizes whether saved enabled targets meet their minimums, using the same already-built count report as shortage copying. It adds no inventory queries or recurring work. Unknown quantities remain unknown; pending counts and dirty/new drafts have distinct guidance. The summary reserves its layout space when the pane is drawn, so count updates do not move the editor or reset focus/history. Readiness describes minimum quantities, while the shortage list still refills qualifying rows to their target.

## Remembered manual selection

Explicit chat/menu selection remembers a detached stable Built In ID or complete
Class/Character reference in optional `rotationChoicePreferences` version1.
The bounded dense list has at most256 unique domains; numeric specialization0
is a value, so profile transport requires no additional numeric-key conversion.
No entry means Auto. Old profiles are not seeded from transient active IDs.
Profile copy/import transfers desired data, while reset removes it. Existing
closed transfer validation rejects extra fields, aliases and foreign reference
ownership before copying; no runtime handle or native observation is saved.

Restoration is cold on initialization/profile/spec/context notifications and
managed rotation publications. Ordinary selection calls check only private
cache/profile/root/spec/character/context-method authority; they do not rescan preferences or query the
context. The active coordinator resolves the exact reference and fresh runtime
eligibility, then uses the same chat/menu cleanup/commit/timer/message sequence.
Manual selection bypasses only the automatic switch predicate. Unavailable
choices remain saved and suspend, permitting the existing Auto fallback or no
advice; the broker tooltip reports suspension. Restoration does not clear
initialization or advice diagnostic stops. Bare custom records gain no inferred
vehicle applicability: each saved action context is a separate domain.

Successful exact ownership moves retarget only that reference; exact deletion
removes it, preventing reused IDs from restoring a deleted entity. A consumed
source-owned cold prepare/finish pair in the scoped coordinator performs these
changes after Store success, before existing post-save copying, without public
notification, copy or native callbacks. Finalization checks the live coordinator,
profile, store root, preference root, private choice generation and unchanged
prepared data. Newer choices or profile/root replacement win. Failed Store
commits leave preferences untouched, and unrelated malformed preferences cannot
block rotation Move/Delete.

A custom Store transport may recursively move/delete the newly saved target
before returning. If the exact target no longer exists, completion removes only
the still-matching old desired choice; it does not infer the newest address in a
chain. One private cold token also detects nested successful scoped publication,
including deletion followed by exact-ID reuse. Failed writes do not advance it.
Direct custom Store transports bypassing Scope do not confer chained choice
ownership. This conservative boundary avoids resurrecting a missing target. It is
not a move-history registry. Automatic/Single-target/AoE strategy declarations,
new context-specific packs and target-count rules remain separate work.
