# Built In spell identity evidence

Spell records used while checking the bounded TBC starter packs. These are development evidence, rather than rotation-guide citations shown in the metadata dialog. The pack manifests retain their rotation guide source.

- [Fireball rank1 spell record](https://wowclassicdb.com/tbc/spell/133) (mage-starter.lua; reviewed 2026-10-18).
- [Frostbolt rank1 spell record](https://wowclassicdb.com/tbc/spell/116) (mage-starter.lua; reviewed 2026-10-18).
- [Fireball rank2 spell record](https://wowclassicdb.com/tbc/spell/143) (mage-starter.lua; reviewed 2026-10-18).
- [Frostbolt rank2 spell record](https://www.wowhead.com/tbc/spell%3D205/frostbolt) (mage-starter.lua; reviewed 2026-10-18).
- [Arcane Intellect spell record](https://wowclassicdb.com/tbc/spell/1459) (mage-starter.lua; reviewed 2026-10-18).
- [Frost Armor rank1 spell record](https://www.wowhead.com/tbc/spell%3D168/frost-armor) (mage-starter.lua; reviewed 2026-10-18).
- [Rockbiter Weapon spell record](https://wowclassicdb.com/tbc/spell/8017) (shaman-starter.lua; reviewed 2026-10-17).
- [Lightning Shield rank 1 spell record](https://wowclassicdb.com/tbc/spell/324) (shaman-starter.lua; reviewed 2026-10-17).
- [Lightning Shield rank 2 spell record](https://www.wowhead.com/tbc/spell=325/lightning-shield) (shaman-starter.lua; reviewed 2026-10-17).
- [Lightning Bolt spell record](https://www.wowhead.com/tbc/spell=403/lightning-bolt) (shaman-starter.lua; reviewed 2026-10-17).

Warlock revision1 uses base spell families Immolate348, Corruption172, Curse of Agony980, Shadow Bolt686, Drain Life689, Demon Skin687 and wand Shoot5019. The leveling guide’s linked Shoot record identifies5019; [LibRangeCheck’s original spell inventory](https://github.com/WeakAuras/LibRangeCheck-3.0/blob/main/LibRangeCheck-3.0/LibRangeCheck-3.0.lua) independently records Corruption172, Immolate348 and Drain Life689 as the non-Retail rank1 probes. Reviewed2026-10-18.

- [Immolate rank1 record](https://wowclassicdb.com/tbc/spell/348).
- [Curse of Agony rank1 record](https://wowclassicdb.com/tbc/spell/980).
- [Shadow Bolt rank1 record](https://wowclassicdb.com/tbc/spell/686).
- [Demon Skin rank1 record](https://www.wowhead.com/tbc/spell=687/demon-skin), [rank2 record](https://wowclassicdb.com/tbc/spell/696).
- [Leveling guide’s Shoot record](https://wowclassicdb.com/tbc/spell/5019). The current destination’s dynamic body is not a reliable static record; the guide supplies the named link.

Runtime actions use the learned localized rank catalog, not authored training-level guesses. Synthetic scenarios include rank-family samples707,6222,1014,695,705 and696 to verify rank expansion and owned-aura matching; those fixtures are not evidence of live spellbook state. The auto-repeat adapter follows the original [LibActionButton player-book lookup](https://github.com/Nevcairiel/LibActionButton-1.0/blob/master/LibActionButton-1.0.lua) for legacy clients and the native identifier API when available; queued/current spell state is deliberately separate.

Shaman revision9 and Mage revision3 widen only their bounded preview scope to1–29 (source guides rechecked2026-10-20). No new action IDs, rank whitelist, quest/talent assumption or automatic training policy is authored. Their existing base families consume readable learned ranks through the catalog and native readiness.

The original publisher's [Enhancement guide](https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide) supports continued pull/Shock/melee/upkeep basics; its conditional DoT/totem advice is not a universal new priority. The [Frost single-target guide](https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide) retains Frost Armor through the20s and introduces Ice Armor at30. Talent cooldowns, defensive and resource decisions remain manual in these previews.

- [Frost Armor7301 TBC tooltip](https://nether.wowhead.com/tbc/tooltip/spell/7301?dataEnv=5&locale=0), [Ice Armor7302 TBC tooltip](https://nether.wowhead.com/tbc/tooltip/spell/7302?dataEnv=5&locale=0). These mirrored client records identify distinct armor names and required levels20/30; the higher Frost Armor rank belongs to the already authored168 family.
- [Frostbolt7322](https://nether.wowhead.com/tbc/tooltip/spell/7322?dataEnv=5&locale=0), [Frostbolt8406](https://nether.wowhead.com/tbc/tooltip/spell/8406?dataEnv=5&locale=0) and [Arcane Intellect1461](https://nether.wowhead.com/tbc/tooltip/spell/1461?dataEnv=5&locale=0) provide named sample identities for rank scenarios. No player learned state or trainer visit follows from these records.
- [Build-pinned SpellLevels client table](https://wago.tools/db2/SpellLevels/csv?build=2.5.4.44833) supplies SpellID/SpellLevel fields for additional scenario samples. This original-client-data mirror is not a trainer schedule, a complete name/subtext table or current-client acceptance evidence. A scaling MaxLevel must not be interpreted as the next rank's training level.

The twenty-level scenarios use modeled metadata/learned/bar observations to verify unchanged family expansion and readiness; they do not establish exact trainer prices, every rank label or actual character spellbook state. Current static wowclassicdb destinations may expose only an application shell, and unavailable official manual/name/totem records remain evidence gaps rather than successful verification. These Shaman/Mage scenarios infer no quest-dependent totem, Flame Shock lifetime rule, new Mage talent priority or Warlock armor policy. Native learned-rank and highlight acceptance remains outstanding.

Warlock revision2 separately reviews armor supersession for the bounded1–29 preview (2026-10-20). [Demon Armor706 client tooltip](https://nether.wowhead.com/tbc/tooltip/spell/706?dataEnv=5&locale=0) and [Demon Armor1086 client tooltip](https://nether.wowhead.com/tbc/tooltip/spell/1086?dataEnv=5&locale=0) identify the family and required levels20/30; the mirrored client descriptions establish armor exclusivity. These records do not establish a trainer visit or player learned state. Preferring learned Demon Armor and refusing a Demon Skin fallback when it is unavailable is RM policy, not a priority algorithm inferred from the guide. Existing damage priorities remain unchanged; modeled publisher/readiness tests do not establish native gameplay acceptance.
