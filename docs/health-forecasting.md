# Health forecast observations

The built-in Time Until Health and Time Until Health Percentage conditions use checked observations and a bounded forecast service. Missing, failed, restricted or invalid required facts remain unavailable through negation and branches. Known unit absence remains a false predicate.

The native calls retain the selected unit token and their original argument counts. Percentage forecasts read optional RealMobHealth values freshly, falling back independently to native current or maximum health only when that provider field is nil or false. Numeric zero is a present value. A failed or malformed provider response is unavailable.

Exact target equality returns zero seconds before reading history, its configured window, or the forecast clock. Missing history for a known GUID, empty valid histories, and histories of at most two seconds retain the existing no-estimate result. For older histories, a zero or opposite-direction rate retains the existing initialized zero-second result. These are different cases; no infinity or partial estimate is invented.

`Functions.forecast.calculate` uses an explicit finite clock and window. It preserves ordered damage/heal weighting, final visited ages, fractional data keys and the numeric accumulation loops. It reads the current namespaced rounding function for each visited row. The total work limit is **4096 visited rows and accumulation-bin iterations**, across both selected streams. Exceeding it returns unavailable before further row fields or bin work; history is not clamped, reordered, truncated, pruned or modified. This is an RM workload policy, not a limit supplied by WoW. Arbitrary custom callbacks and metatable code are outside that work guarantee.

The new service has its own source identity. Existing published `Functions.trends.calculate`, `calculateOld`, their direct compatibility aliases, and saved raw custom code keep their historical implementations and live legacy rounding authority. Opening or importing old code does not rewrite it.
