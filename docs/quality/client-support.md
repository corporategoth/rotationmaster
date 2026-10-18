# Client evidence and outstanding acceptance

This is an implementation/evidence ledger, not a claim that every WoW family is playable with the current addon.

| Family | Product identification | Offline evidence | Actual-client acceptance |
| --- | --- | --- | --- |
| Retail | Defined WOW_PROJECT_MAINLINE | Identity/capability fixtures; existing condition declaration/help branch | Outstanding; custom combat data remains restricted, reference/assisted integration not yet implemented |
| Classic Era/modes | Defined WOW_PROJECT_CLASSIC; independent season/hardcore/game-mode metadata | Identity/ruleset fixtures; existing condition declaration/help branch | Outstanding; adapters and per-mode packs still pending |
| Progression | Defined Mists/Cataclysm/Wrath constants recognized as progression, expansion recorded separately | Identity fixtures; declaration/help branches | Outstanding; current progression APIs/talents/defaults still pending |
| TBC Anniversary | Defined WOW_PROJECT_BURNING_CRUSADE_CLASSIC; build/interface recorded independently | Real vendor startup, Settings, buttons, shutdown, codec, condition/help/evaluator and diagnostics regressions | User runs the source via a symlink in AddOns. Report window opened and showed no captured errors; Copy selection failed. User confirmed Copy selects the visible text after the source fix. Full highlight/taint/collector smoke remains outstanding. |
| Forever | Defined WOW_PROJECT_CAMELOT | Identity/capability fixtures; source restriction audit | Outstanding; reference/assisted behavior and modern API migration still pending |

Source snapshots and revision IDs are in client-api-sources.json. Forever's product-specific file is [Blizzard_ProjectConstants/Camelot/ProjectConstants.lua](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua). Engine-defined Classic constants are matched by their provided names, not synthesized numeric comparisons or a catch-all non-Retail branch.

The new Platform boundary records API declaration presence separately from readability. Native-assisted availability is probed independently; a declared function is not proof that the feature works for a character. `runtimeVerified=false` is deliberate until actual smoke evidence exists. The metadata boundary does not yet migrate every historical API call or select recommendation engines; old callers remain tracked modernization work.

Mode facts are raw: a season ID, hardcore flag, game-mode record and self-found-allowed flag describe different things. Self-found allowed must not become a claim that a character actively uses it. Missing metadata remains absent. Unknown projects keep an explicit unsupported policy rather than borrowing another family's rules.

Current automated guards check Lua/load graph/vendor files, literal English keys and registered help/category metadata. They are not proof of optimal rotations, completed translations, client taint safety, or live API accessibility. Error-report redaction is best effort, with explicit original-text preview/copy; anonymized analytics/LLM exports remain deferred.

Development installation: the source directory is symlinked directly into the user's WoW AddOns directory. Edit the source and use `/reload`; no ZIP/deployment step is needed. Do not generate further deployment archives unless requested.

Item action readiness uses a normalized cooldown record from `Platform:GetItemCooldown`. It prefers `C_Item`, then the older container namespace, then the legacy global, and accepts validated boolean or `0/1` enabled flags. A failed or restricted observation does not trigger fallback to another backend. The generated Blizzard [Item API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) and [Container API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua), inspected on 2026-10-18, expose these different flag forms. Missing metadata remains unavailable; this does not certify native API access in a live client. Legacy UI item-set helper callers still need migration.

The five item predicates now use protected per-evaluation observations through `Core/item_conditions.lua`. Have Item In Bags uses a separate bag-only snapshot, including a declared reagent bag, rather than treating the general ownership count as a bag count. Multiple stacks of the first carried candidate are combined; different candidate items are not summed. The other predicates select the first carried or equipped candidate. Missing item sets, unresolved names, incomplete metadata and restricted results remain unavailable under NOT. An explicit empty item list is known absence. Native metadata supplies item descriptions when available.

Item Available retains its level/cooldown policy and uses the same Classic/later global-cooldown probe as spells. Actual item actions still enforce their own ownership, usability and range. Item Cooldown measures nonnegative remaining seconds at the evaluation timestamp; a disabled timer is unavailable, not an invented zero. Legacy UI item-set helpers and other remaining raw callers still need migration; these five predicates no longer depend on those helpers.
