# Follow-on addon investigations

User-requested future work, after RM modernization. These are feasibility candidates, not implemented dependencies or promises of recovering restricted combat data.

## Optional party/raid data transport

The sender must be able to read a value, serialize it and send it through an available addon communication channel; the receiver must know its source, unit identity, version and freshness. A field can be public, conditionally restricted or secret independently of adjacent fields. Do not infer a general self-versus-other-player rule.

Inspected source snapshots: Retail `b9be9379719047977fca4dba1bb1d9988e8840b3`; Forever `172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`, in [Blizzard UI source](https://github.com/Gethe/wow-ui-source).

| Field/API | Inspected contract | Feasibility consequence |
| --- | --- | --- |
| UnitHealth | SecretReturns, no player-token exemption in declaration | Cannot assume sender can inspect their own current health |
| UnitHealthPercent | SecretReturns, plus curve secrecy | Percentage is not automatically readable/comparable |
| UnitHealthMax | SecretWhenUnitHealthMaxRestricted | Predicate describes non-player-controlled units; another player's maximum may already be readable locally |
| UnitPower / UnitPowerPercent | SecretWhenUnitPowerRestricted | Depends on resource type, not just unit ownership |
| UnitPowerMax | SecretWhenUnitPowerMaxRestricted | Player-control and per-power-type exceptions apply |
| SendAddonMessage | SecretArguments=NotAllowed | A secret observation cannot simply be forwarded as a payload |
| AreOutgoingAddonChatMessagesRestricted / InChatMessagingLockdown | Separate communication restrictions | Data readability alone does not establish transport availability |

Primary contracts: [Retail Unit APIs](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua), [Forever Unit APIs](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua), [restriction predicates](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua), [communication APIs](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).

The known-maximum plus percentage idea requires both operands to be readable. When they are, a rounded percentage gives an estimate rather than an exact raw value, and stale maxima can invalidate it. A secret percentage remains unusable for addon arithmetic even with a public maximum. These are API-contract conclusions; a per-client, per-context live capability matrix still needs verification.

Possible useful public-data scope includes voluntarily shared configuration, assignments, build/equipment facts where readable, and explicit player intent. First compare existing maintained communication libraries/providers rather than create another transport. Before implementation define field allowlists, opt-in behavior, bounded payloads/rates, actual addon-message sender identity, protocol versions, snapshot/change events, expiry and group-leave cleanup. Unsupported/restricted transport must fail independently of RM's no-optional-addon baseline. Do not queue secret payloads or silently treat stale reports as current observations.

## Versioned spell/item/mechanic database

Evaluate maintained datasets first. Keep stable spell/item IDs, ranks, edition/build/ruleset applicability, source/license/revision and uncertainty. Public static properties can support browsing, help and reviewed default applicability. They are not live observations: a database entry for a normally stealable buff cannot establish its presence, remaining time or current stealability when those observations/identifiers are unavailable. Encounter variants and hotfixes can alter a static rule.

Base values and coefficients, with permitted character modifiers, may eventually support explicit estimates. Distinguish base database facts, measured modifiers and modeled outcomes, including units and assumptions. The general coefficient/modifier engine remains deferred per the user's earlier direction. No simulator, secret-state reconstruction or database addon is implemented by this note.
