# Native CPU captures

General → Debugging has **Capture CPU (10s)**, **CPU report**, and **Cancel capture**. These diagnostic actions use current runtime settings and do not apply a settings draft.

WoW's `scriptProfile` must already be enabled before a reload. If capture reports that it is disabled, enable it with `/console scriptProfile 1` and `/reload`. RM never changes that setting or resets shared CPU counters. Profiling adds overhead to the client; disable it with `/console scriptProfile 0` and `/reload` when the investigation is finished.

For a normal gameplay measurement, close configuration and run `/rm cpu start`. Leave the same rotation, polling interval, and character activity in place for the ten-second capture. Then use `/rm cpu report` to open the selectable, copyable report. `/rm cpu cancel` cancels an active capture. The buttons provide the same actions without chat commands.

Compare separate captures with the rotation active and inactive. Record whether the character was idle or fighting, which visual effects and preview were enabled, and the polling interval. The report records configuration visibility and combat state at its boundaries; it cannot prove those states stayed unchanged between them.

The report uses differences between native cumulative counters for the same function objects. Exclusive costs rank the selected functions; inclusive costs include their callees and overlap, so they must not be added together. Call counts and per-call costs help distinguish frequent inexpensive work from a few costly calls. This is selected coverage, not a complete accounting of every function, frame script, native operation, or shared-library cost. Collection overhead is part of the measurement.

Missing APIs, invalid counters, counter resets, and functions replaced during capture are reported as unavailable. A capture must not turn those cases into zero CPU usage. Captures remain in session memory and include no source code, condition values, or character ownership keys.

## Cache and validation boundaries

The exact-key observation cache reuses complete return tuples, including false and nil results, for the same function object, receiver and argument tuple. Normal condition evaluation currently creates a cache for each root condition tree. Environment updates have a separate cache, and different normalized adapters also have distinct keys. Thus a cache hit within a tree does not mean the underlying WoW API runs only once per polling tick.

Sharing every cache across a tick changes observable behavior when custom callbacks change state before a later card. Performance changes must preserve that behavior or introduce explicit safe invalidation boundaries. Native observations, optional provider responses and ownership checks have different freshness contracts.

Runtime assets already retain validation results while their record and dependency stamps remain current. Repeated stamp checks still inspect dependency identities to catch direct table changes and changes made by callbacks before advice is published. Optimizing these checks must retain retirement on dependency, record, profile and context changes. Host timing probes and dispatch-count regressions help identify improvements; a comparable native capture is still needed to establish a gameplay CPU reduction.
