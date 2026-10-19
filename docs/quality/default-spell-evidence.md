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
