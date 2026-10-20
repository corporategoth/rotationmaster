# Nameplate snapshot lifetime

Nameplate ADD stages the observed GUID and unit record. REMOVE identifies retiring records by their stored unit token, because the native GUID lookup can already be unavailable. An exact readable GUID match through a canonical alias such as target preserves that record under the alias; otherwise it retires. ADD also retires obsolete identities when a token is reused. Unknown stored tokens are retained conservatively.

This work happens on nameplate events. The recommendation polling loop, polling interval and observation-cache policy are unchanged. Snapshot maps are copied before provider/readability calls. A private event ticket, root identity and record/target-slot checks prevent an older or reentrant callback from overwriting newer state. Missing or malformed added GUIDs do not create a table-key error. Existing bag-update behavior is unchanged.

The headless regression reproduces the disappearing-GUID retention problem and verifies canonical aliases, reuse, malformed/unreadable identities, direct record replacement and nested callbacks in both runtimes. Whole-module inverse checks preserve the exact predecessor, including unrelated handlers. This is not evidence that stale nameplates caused a particular native CPU sample; native measurements remain separate.
