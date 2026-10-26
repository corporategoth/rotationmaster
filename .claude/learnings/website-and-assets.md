# The website, artwork and probes

## The website is a separate repository

The companion website (Node, its own database) lives in a separate repository and is not mirrored to GitHub. Its catalogs,
decoders, validators and help pages are generated from or checked against this addon, and the converter in
`Modules/RotationMaster_WowSims` is a Lua port of the website's, driven by the same rule table. So:

- every change to rotation fields, selection order, step types, conditions, the premade catalog or reason codes needs a matching
  website change; say in the commit message what must be regenerated;
- generated website catalogs record source hashes of this addon: regenerate them after any merge that touches `Locales/enUS.lua`
  or `Core/`;
- the WowSims data pinned in `Data/wowsims/` must be re-pinned (`tools/export_wowsims_mapping.py --refresh <website checkout>`)
  when the website's mapping changes, in step with the Lua port;
- the website enforces strict canonical validation of uploads and a content filter; do not ship premade text it would reject.

Website facts that bind the addon: use Wowhead's official browser tooltip script, never server-side fetching of Wowhead or its
CDN (their terms forbid automated tools); data from Blizzard's APIs is shown with a source line and expires after 30 days.

## Artwork

- Condition and overlay icons are original: sources and the QA record are under `Assets/*/source` and `provenance.json` (not
  shipped); the runtime textures are TGA at 64 and full size and `Data/artwork.lua` is generated from the manifests.
- Images made with an image model (the system Codex CLI) are produced by the agent itself: `codex exec --json -C <worktree> -o
  <last-message-file> "<brief>"` with a workspace-write sandbox. **Record the session/thread id** (first JSONL event) so the
  same session can be resumed (`codex exec resume <id>`), and review sizes, formats and budgets before wiring outputs in. The
  agent leaves its work uncommitted for review.
- Art for the website (edition backgrounds, icons): original paintings only. No copies of Blizzard art, no logos or text or
  crests, no close-up named characters, no "not affiliated" footer.

## In-game probes

When you need data from the maintainer's game, the output must land in a selectable multi-line EditBox window (focus and
`HighlightText` so Ctrl-A, Ctrl-C works), because chat text cannot be copied out of WoW. Make test visuals visible in their
resting state (an outline), so "nothing happened" is not confused with "not loaded". For one-off `/run` lines, prefer ones whose
result is a short value he can read and type.
