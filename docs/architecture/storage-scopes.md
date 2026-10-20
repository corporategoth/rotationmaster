# Storage scopes

This documents the current persistence boundary, including profile-contained Class and Character rotation ownership and preserved legacy recovery data.

## Current behavior

RM stores one account SavedVariables table per client installation, using AceDB's `profile`, `char` and `global` sections. It does not currently use AceDB's class or realm sections. A profile name is a sharing choice, not proof of class or character ownership. New characters use the shared `Default` profile unless their profile selection says otherwise.

| Data | Current scope |
| --- | --- |
| Rotations, fallback rotation, clone/import lineage and comparisons | Selected profile, then Class or Character owner, specialization key and rotation ID |
| Built In rotation definitions | Immutable packaged assets with class/client applicability |
| Built In enable preferences | Selected profile |
| Announcement rules, personal item sets | Selected profile; personal currently means profile, not character |
| Condition categories, picker visibility/order, tag colors | Selected profile |
| General, editor, preview and minimap preferences | Selected profile; configuration scale is global |
| Effects, custom conditions/functions and source import provenance | Global reusable libraries |
| Global item sets | Global; a same-ID profile set takes precedence |
| Condition Test samples | Global, keyed by condition identifier; restored samples do not authorize debugging |
| Item-set action-bar bindings and optional specialization labels | Character |
| Which profile is selected | Character, managed by AceDB |
| Observation caches, compiled registries, combat histories, editor drafts/camera/undo and diagnostics | Runtime only |

Declared class applicability is a hard gate for packaged/sourced rotation candidates, normal Built In lists and direct Built In cloning. Other eligibility constraints can still broaden candidate discovery within that class. Explicit reference/cleanup access retains old definitions and saved bodies. Ordinary custom storage uses the scoped coordinator. Legacy bodies without authoritative ownership remain preserved for explicit recovery/adoption; packaged-definition filtering alone is not ownership evidence.

“Global” means shared by characters using that account's SavedVariables store. It does not imply sharing across accounts, client installations or game editions. No current data requires realm-only storage. The `realm` field in rotation metadata is attribution, not an ownership key.

Profile Copy/Reset/Import affects the profile domain. It does not copy/reset global source libraries or character bindings. A profile export is consequently not a complete backup of referenced global effects, item sets or trusted code.

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
