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
