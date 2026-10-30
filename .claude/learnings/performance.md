# Performance

## Why it was slow (2026-10-22) and what fixed it

The first design layered per-step "proof" guards: `getfenv` identity checks, leases and generation re-reads, about 3000 calls per
poll for a five-entry rotation and about 20 KB of garbage per poll at a 0.15 s poll. The fixes, now in `main.lua`:

- **Idle gate**: with no target, focus or combat, evaluate on events (or about once a second, `idle_poll`) instead of every poll.
- **Lean engine**: after a completed standard poll, record a plan and reuse it while the spec, rotation, profile, preview window,
  *execution generation* (advanced by every rotation, condition, function, item-set and effect writer), *context epoch* and a 60
  second age are unchanged. `/rm perf engine lean|standard` chooses. Conditions, readiness, range and cooldowns are still read
  fresh every poll.
- **Allocation-free dispatch**: `Diagnostics.Call` and the event wrapper allocate nothing in the hot path.
- Cast events for player and pet only; demand-driven histories; a constant `CanReadValue` when restrictions are off.

## Traps learned

- The scoped rotation route advances the execution generation on every acquire. A lean plan must snapshot the generation
  *after* acquiring or it never caches (premades cost 20 times as much).
- Built Ins register only for the character's edition and class (`addon.loadAllDefaults` exists for offline tools and
  cross-edition tests). Loading all 155 premades costs about 20 MB.
- Any code that changes a rotation, condition, function, item set or effect in place must call
  `addon:InvalidateRotationDependencies`, or the lean plan serves a stale answer.
- Do not add per-window `OnUpdate`; the window registry piggybacks on the Escape watcher.
- Measure with the native profiler (`/rm perf cpu|runtime|memory`) in a client, or with the benchmark harness for a premade
  (`BENCH_PACK`, `BENCH_CLASS`, `BENCH_FILES` select it; load `Core/*_conditions.lua` except aura for premades). Never claim a
  speedup from reasoning alone, and never generate synthetic load to prove one.
