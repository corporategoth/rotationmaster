# Debugging

Start in game with the report commands; they are built so a tester can paste the result back. Everything that produces a
report opens it in a selectable window (click Copy, press Ctrl+C) because chat text cannot be copied out of WoW.

## "Why is it not doing what I expect?"

| Question | Command | Notes |
| --- | --- | --- |
| Which rotation is active? | `/rm current` | |
| Why was this rotation chosen, or not? | `/rm why` | Lists every rotation for the character with the reason it can or cannot be selected |
| What can I give to `/rm set`? | `/rm list` | Identifiers of selectable rotations |
| A step is right but no button lights | `/rm debug glow [seconds]` | Walks the chain in order (client and bar APIs, active rotation, button scan, each step's conditions, spell IDs and buttons, readiness, Blizzard's suggestion, the glow request) and names the first link that drops the recommendation. With seconds, one compact line per second follows, to catch combat. `/rm debug glow show` reopens the last report |
| Retail or Forever talent lists are short or empty | `/rm debug talents [views]` | One trait call at a time with what each answered; `views` also lists the class's other specializations |
| The Lua editor misbehaves | `/rm debug editor` | Copies the native Lua input diagnostics |
| Errors | `/rm errors` | The bounded session error report; names, GUIDs and home paths are redacted unless you choose the original text |
| Saved data looks wrong | `/rm check`, `/rm repair` | Validation; repair fixes what internal validation can |
| Performance | `/rm perf cpu\|runtime\|memory [seconds]` then `/rm perf <kind> report`; `/rm perf probe` | Native profiler captures; `scriptProfile` must already be on. `/rm perf engine standard` switches off the lean engine to separate an engine problem from a condition problem |

`/rm debug glow` and `/rm debug talents` also keep their last reports in `RotationMasterDB.diagnostics.glow` (at most 5
reports of 600 lines) and `.talents` (3 reports of 400 lines), so they survive `/reload` and can be read from the saved
variables file. Nothing in the diagnostics runs until its command does.

## What a tester sends

Ask for: the report from `/rm debug glow` (or `/rm why`) after standing in the situation; `/rm errors` text; the client
(`/dump GetBuildInfo()`), the class and spec, the rotation identifier; BugSack or the default error frame text if there is
a Lua error; the saved-variables file only if you ask for it and say what is in it. `docs/release/BETA.md` is the version
of this for testers.

## Reading a failure

- **A condition is "unavailable"**: its reader returned `nil, reason`. The reason code is the thing to search for
  (`restricted-value`, `missing-api`, `unit-data-unavailable`, ...); it comes from a `Platform/` adapter. On Retail and
  Forever that is usually a secret value; if the condition is supposed to work there, the classification in
  `docs/restricted-clients.md` is wrong.
- **A rotation is "incomplete"**: it uses a condition that can never work on this client (`Core/condition_support.lua`). The
  editor says which one and why.
- **Nothing is advised but nothing errors**: the idle gate (no target, focus or combat) is on; `/rm perf engine standard`
  and `/rm why` separate engine from selection.
- **A stale answer after editing a rotation, function or item set in code**: a writer did not notify
  (`addon:InvalidateRotationDependencies`, `docs/architecture/runtime-revisions.md`).
- **An error report names Rotation Master inside Blizzard code**: suspect taint. Check for writes to Blizzard tables, calls
  to protected functions in combat, and hooks of secure frames.

## Reproducing offline

The suites run the real files against a client model. To reproduce a report, find the nearest suite
(`ls tests | grep <area>`), copy its fixture setup (`tests/fixtures/addon.lua`), and model what the report says the client
returned, including APIs that are absent. `docs/dev/running-things.md` has the commands. If a probe is needed in game, build a
throwaway addon whose output lands in a multi-line copy window, not only in chat.
