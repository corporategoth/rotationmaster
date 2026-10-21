# Runtime condition evaluation

AND evaluates children in authored order and stops at the first no-match. OR stops at the first match. NOT evaluates its one child and inverts only a known match/no-match. An encountered unavailable result stops its group and remains unavailable through NOT.

A decisive prefix skips later children entirely: their validation/evaluation callbacks, native queries, errors, unknown condition tags, cycles and depth are not visited. Consequently NOT(AND(false, unavailable)) matches, while NOT(OR(true, unavailable)) does not match. If unavailable is reached first, neither expression may treat it as false. This deliberate runtime policy differs from the earlier engine, which kept evaluating all normal siblings to discover later unavailable values.

Each reached AND/OR still checks its complete immediate child list for valid numeric keys, density and width before executing any child. Nested structure is checked when reached. Existing depth/node budgets apply to reached traversal. Empty AND matches; empty OR does not. Disabled nodes retain their existing match behavior. Saved-body/schema validation is separate and still inspects the saved tree; runtime skipping does not repair or validate an invalid definition.

Reached callback errors retain existing diagnostics, quarantine and path behavior. Each top-level condition retains its own fresh cache/timestamp, shared by its reached descendants. There is no cross-poll result cache or new shared observation registry. The normal polling cadence, event handlers and volatile readiness checks are unchanged.
