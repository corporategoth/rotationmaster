# Restricted clients (Retail and Forever)

Retail (Midnight, 12.x) and Forever (Interface 16001) run under the *restricted* combat-data policy
(`Platform/client.lua`, `combatDataPolicy`). While `C_Secrets.HasSecretRestrictions()` is true, many APIs return *secret values*:
you can show them or pass them back to Blizzard APIs, but comparing them, doing arithmetic on them, using them as table keys or
passing them to `string.format` raises an error in addon code. The full classification per condition and the evidence are in
`docs/restricted-clients.md`; client evidence is in `docs/quality/client-support.md`.

## Rules

- **Every read goes through `platform:CanReadValue`** (both `issecretvalue` and `canaccessvalue`) before it is compared. A value
  that is secret this poll makes the condition *unavailable*, not false.
- **Unavailable means incomplete only when it can never work.** A condition that cannot work on this client at all (missing API,
  unsupported policy, always-secret source) is declared in `Core/condition_support.lua`; a rotation using it is *incomplete* and
  inactive, and the editor says which condition and why. Momentary uncertainty (range straddling, data still loading, secret
  this poll) keeps today's behavior: a Branch or Stop pauses that poll and an action step is skipped. Never add an option to
  "treat unavailable as false/true", and never blank the rotation because one condition is momentarily unavailable. Both were
  proposed and rejected.
- **Conditions that only give secret data on an edition do not exist on that edition**: hidden from the editor, unsupported in
  the registry, and that edition's premades never use them. There is no blanket "never auto-select on Retail/Forever": a
  rotation that is complete there auto-selects.
- **Use Blizzard's Assisted Combat data** for conditions where it helps, and offer letting Blizzard do the highlighting.
- Health and primary power are secret even out of combat on Retail (observed). The GCD start time and a cast's spell id were
  readable in combat. Everything not listed in `docs/restricted-clients.md` as verified is unverified.
- Classic-family builds report `HasSecretRestrictions() == false` as a build guarantee; `Platform/client.lua` then makes the
  readability check a constant. Do not "optimize" this differently without measuring.

## Retail levels 1 to 9

The class's *initial specialization* (`GetSpecialization() == 5`, for example Monk 1450) is its own editor entry, "No
specialization" (a label only, no level range: you can stay unspecialized well past 10) with its own rotations. Retail premades
include a Blizzard Assisted one for it, and class-wide rotations also apply below 10.

## Fixtures

The test fixtures once defined globals the real Retail client removed (`BOOKTYPE_SPELL`/`BOOKTYPE_PET` are gone since 11.0, so
every Retail "spell" step resolved no ids; `HasAction` and related moved to `C_ActionBar`), and suites passed while the client was
dead. Fixtures install per-client API manifests and must model ABSENT globals. In-game diagnostics (`/rm debug glow`, `/rm why`,
both saved to the saved variables) beat assumptions.

## Taint

Do not write to Blizzard tables, call protected functions in combat, or hook secure frames without proof. Driving Blizzard's
talent window from the "Show talent tree" button is modeled and unverified for taint: treat any "blocked action" report that
names Rotation Master as a defect first.
