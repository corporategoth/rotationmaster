# Restricted unit data and addon transport

What the pinned Blizzard API documentation says about reading a unit's health and power and about sending addon messages. These
are API-contract conclusions, not an implemented feature: Rotation Master has no party or raid data transport and no spell or item
database, and a per-client, per-context capability matrix measured in a live client does not exist. Nothing here recovers restricted
combat data.

Inspected source snapshots: Retail `b9be9379719047977fca4dba1bb1d9988e8840b3`; Forever `172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`,
in [Blizzard UI source](https://github.com/Gethe/wow-ui-source).

## What a sender could read and send

A field can be public, conditionally restricted or secret independently of the fields next to it, so there is no general
"self versus other player" rule to infer.

| Field/API | Inspected contract | Consequence |
| --- | --- | --- |
| UnitHealth | SecretReturns, no player-token exemption in the declaration | A sender cannot assume it can read its own current health |
| UnitHealthPercent | SecretReturns, plus curve secrecy | A percentage is not automatically readable or comparable |
| UnitHealthMax | SecretWhenUnitHealthMaxRestricted | The predicate describes non-player-controlled units; another player's maximum may already be readable locally |
| UnitPower / UnitPowerPercent | SecretWhenUnitPowerRestricted | Depends on the resource type, not only on unit ownership |
| UnitPowerMax | SecretWhenUnitPowerMaxRestricted | Player-control and per-power-type exceptions apply |
| SendAddonMessage | SecretArguments=NotAllowed | A secret observation cannot be forwarded as a payload |
| AreOutgoingAddonChatMessagesRestricted / InChatMessagingLockdown | Separate communication restrictions | Readability of the data does not establish that transport is available |

Primary contracts: [Retail Unit APIs](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua),
[Forever Unit APIs](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua),
[restriction predicates](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua),
[communication APIs](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).

A known maximum plus a percentage needs both operands readable. When they are, a rounded percentage gives an estimate, not an exact
raw value, and a stale maximum can invalidate it. A secret percentage stays unusable for addon arithmetic even beside a public maximum.

## Static spell and item data

A static dataset (spell and item IDs, ranks, edition and build applicability, source, license, revision) can describe things for
browsing and help. It is not a live observation: a database entry for a normally stealable buff cannot establish its presence,
remaining time or current stealability when those observations are unavailable, and encounter variants and hotfixes can change a
static rule. Rotation Master ships no such database and no coefficient or modifier engine; it does not simulate outcomes or
reconstruct secret state.

## Not built

- Sharing readable data between group members (voluntarily shared configuration, assignments, readable equipment facts). It would
  have to bound payloads and rates, authenticate the actual addon-message sender, carry a protocol version and expire data on group
  leave, and unsupported or restricted transport would have to fail independently of Rotation Master's no-optional-addon baseline.
- A spell, item and mechanic database.
