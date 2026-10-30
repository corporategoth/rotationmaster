# Owned overlay animation lifetime

Texture sequence and rotation overlays pause their timer when native visibility is lost. The sequence index and active configuration remain available for the next Show, which resumes with one timer at the next animation step. Hidden time does not advance or repaint the animation. Native visibility callbacks and one owned configuration identify that lifetime; queued callbacks from a previous timer cannot repaint or reschedule a newer effect.

Stopping a glow, destroying an overlay or reusing its pooled frame clears the old configuration before callback-capable cancellation. These operations cannot be undone by a late Show. Existing frame scripts are preserved. If visibility cannot be observed, the legacy timer behavior remains available rather than guessing that the frame is hidden. This affects only RM-owned sequence overlays; shared pixel, autocast, Blizzard and proc animations keep their existing libraries. Unchanged publishers retain their existing no-op rendering and external notification behavior.

Headless tests model parent visibility propagation locally. They verify lifecycle and callback behavior, not native frame rendering or a promised whole-addon CPU reduction.

Native runtime capture reports reached rotation/cooldown action decisions separately from visual counts: condition match, cached button mapping and action readiness are distinct stages. An unmet or unavailable condition is not a missing mapping, and a mapped action need not have a visible button. Short-circuited action rows are not recorded as false. Mapping/readiness counters count attempts, including multiple candidates within one row. Ordinary recommendation polls do not collect these diagnostic counters.
