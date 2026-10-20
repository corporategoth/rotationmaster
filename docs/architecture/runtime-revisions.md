# Rotation content and dependency revisions

A saved custom rotation body can contain a readonly positive integer `revision`. Legacy bodies without this member have logical revision 1; reading or opening them does not write the member. New rotations and copies start at 1. A committed content or ownership change increments the canonical saved count once. Unsaved commands, discard, failed commits and semantic no-op Apply do not increment it. Editing the draft count cannot choose the next revision.

This counter records no history. It is distinct from the source envelope revision, packaged source revision and comparison provenance. New imports retain a valid incoming body revision; replacing a local rotation increments its local revision. Profile transfer, ordinary serialization and repair preserve valid saved values. Invalid or exhausted counts reject publication. Only the body's own revision is excluded from semantic dirty comparison; nested user fields named `revision` remain content, and concurrency checks retain the complete canonical record.

The dependency service starts immediately after `globals.lua`, before dependency writers capture its notification function. It maintains a private monotonic generation and an opaque non-repeating stamp. The real addon owner uses that generation together with root identities to check unchanged dependency maps without traversing their entries. Normal AceDB default metatables do not disable this path. Public validation options remain fresh detached maps, rather than retained private projections. These map copies are shallow: table-valued entries still refer to canonical dependency objects, so changing those objects also requires notification.

Controlled commits notify after publishing canonical state and before subsequent user callbacks or reentrant selection. Registration, removal, availability changes, failed-registration rollback, function bundles, itemsets, effects, profile replacement, repair and migrations all participate. Rollback advances freshness; it never reinstates an earlier stamp. Unsaved draft edits do not notify.

Third-party code that directly changes a managed dependency in place must notify before returning to evaluation or invoking reentrant addon work:

```lua
rotationmaster:InvalidateRotationDependencies('condition', conditionId)
rotationmaster:InvalidateRotationDependencies('function', functionId)
rotationmaster:InvalidateRotationDependencies('itemset', itemsetId)
rotationmaster:InvalidateRotationDependencies('effect', effectId)
-- Bulk or otherwise unclassified canonical changes:
rotationmaster:InvalidateRotationDependencies('all')
```

An unnotified in-place write is outside this managed contract. Replacing an observed root still changes freshness. Foreign receivers or loaders without the private startup capability retain the scanner compatibility path. Public callback overrides retain their dispatch and error behavior.

This checkpoint uses one aggregate dependency generation. The identity parameters describe cold publications; they do not yet select only the active rotation's dependencies. The next refinement will keep a generated dependency set and volatile dependency revision alongside the active rotation ID, rebuild that state at activation, and distinguish active freshness from inactive catalog validation. Dependency sets and runtime generations are not saved in rotation bodies or exported. Persistent metadata for individually editable dependencies is a separate remaining task.

These revisions cache authoring validity. Casts, channels, cooldowns, range, combat relationships and other changing gameplay facts retain their current polling and per-evaluation observation rules. No cross-poll gameplay result cache is introduced here. Native CPU improvement must be measured after deployment; the offline proof establishes zero dependency-map walks on unchanged managed stamp reads, not a promised CPU percentage.
