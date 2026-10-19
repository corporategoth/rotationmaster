# Storage scopes

This documents the current persistence boundary and the proposed rotation ownership change. The ownership partitions below are a design, not an already completed migration.

## Current behavior

RM stores one account SavedVariables table per client installation, using AceDB's `profile`, `char` and `global` sections. It does not currently use AceDB's class or realm sections. A profile name is a sharing choice, not proof of class or character ownership. New characters use the shared `Default` profile unless their profile selection says otherwise.

| Data | Current scope |
| --- | --- |
| Rotations, fallback rotation, clone/import lineage and comparisons | Selected profile, then specialization key and rotation ID |
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

Declared class applicability is a hard gate for packaged/sourced rotation candidates, normal Built In lists and direct Built In cloning. Other eligibility constraints can still broaden candidate discovery within that class. Explicit reference/cleanup access retains old definitions and saved bodies. Ordinary legacy custom bodies still need the ownership migration below; filtering packaged definitions does not partition custom storage.

“Global” means shared by characters using that account's SavedVariables store. It does not imply sharing across accounts, client installations or game editions. No current data requires realm-only storage. The `realm` field in rotation metadata is attribution, not an ownership key.

Profile Copy/Reset/Import affects the profile domain. It does not copy/reset global source libraries or character bindings. A profile export is consequently not a complete backup of referenced global effects, item sets or trusted code.

## Rotation ownership direction

New custom rotations should default to Class, with Character as an explicit alternative. Built Ins must be limited to their declared class, with a future explicit Universal marker for intentionally shared definitions. Visibility, automatic/manual candidates, tags, comparisons and direct editing must use the same ownership policy.

Ownership needs real partitions behind one storage facade. Adding a class tag to the existing map cannot separate its single `DEFAULT` key into distinct class/character fallbacks. Profile selection and ownership are separate axes. The chosen design retains partitions within each profile, preserving current profile operations. Character fallback takes precedence over Class fallback; both remain separately addressable.

A scope change must be staged until Apply and move body, origins, imports and comparison mappings atomically. Workspace identities and concurrency guards must include the partition. Reuse AceDB's character keys rather than inventing a name/realm format. Owner identity is distinct from source applicability and user-entered author metadata.

## Migration safety

Legacy ordinary bodies have no authoritative class/character owner. Profile names, numeric spec keys and spell contents are insufficient evidence. Valid source manifests can establish declared class applicability, while unknown records need preserved recovery/adoption rather than assignment to whichever character logs in first. Independent class/character fallback collisions must remain separate; no silent merge or replacement is acceptable.

Migration must cover inactive profiles and offline character records, preserve source baselines/IDs, version the new domain and portable schema, and remain idempotent. It must not execute saved source or use Repair as a cleanup step. AceDB strips defaults at logout, so absent raw versions/values must not be mistaken for missing data or ownership evidence.

Repair recognizes current custom bindings, parameter aliases, requirements, schema/order and numeric icons without compiling saved source. Invalid semantic metadata is retained and the condition disabled; a matching active custom definition is also disabled and its registry version invalidated without running registration hooks. Read-only Check never performs those writes.

Repair also retains valid item-announcement references, numeric effect textures, current pet/any spell steps and their exact-rank/appearance fields, optional minimap state, global import provenance and offline character legacy roots. Unknown effect types are reported and preserved. These corrections do not move data between scopes or perform legacy adoption. Optional library fields are validator schema rather than manufactured saved defaults.
