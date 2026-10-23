# Rotation Master website and export viewer

`Web/` holds two things that share the same decoding modules:

- **The website** (`site/` + `server/`): player help, public sharing of exports, and the viewer inside a site shell. It needs the small Node service described in [The website](#the-website) below.
- **The local export viewer** (`index.html`, `viewer/`, `codec/`, `schema/`, `catalog/`, `editor/`): a backend-free page that reads pasted RM exports as data. It still works on its own, exactly as described in the rest of this file.

Imported Lua and HTML are never executed by either. Hosting and publishing are separate decisions; see [DECISIONS.md](DECISIONS.md).

## The website

Run it locally with one command from the repository root (Node 22.13 or later; verified on 24.22.0; no `npm install`):

```sh
node Web/server/server.mjs
```

Then open `http://127.0.0.1:8790/`. Data goes to `Web/server/data/site.sqlite` (ignored by git). Use `--db :memory:` for a throwaway run, `--port` to change the port. The server binds `127.0.0.1` by default and refuses to expose the development sign-in on any other address. Session cookies are signed with a random key per start unless `RM_SESSION_SECRET` is set, so a restart signs everyone out. All options are listed at the top of `server/server.mjs`.

| Path | What it is |
| --- | --- |
| `/` | Home: what RM is, links to help, sharing, the viewer and the Discord. |
| `/help/…` | The player guide: Markdown files in `site/help/` listed by `site/help/index.json`, rendered by the server with the safe Markdown module. `/help/conditions-reference` appends tables generated from `site/conditions.json`. |
| `/shares` | Browse and search public shares (kind, class, edition, text, uploader). Server-rendered; works without JavaScript. |
| `/shares/new` | Upload form: checks the export in the browser and with `/api/check`, shows the same import warnings viewers will see, previews the Markdown description, then publishes. |
| `/s/<id>` | A share: warnings first, the description, the export string with Copy, the fully decoded content (every step, branch arm, cooldown, nested condition, Lua source as text), the original viewer's structure check and raw data, delete (uploader only) and report. |
| `/viewer` | The local export viewer and comparison, inside the site shell. |
| `/signin` | The development sign-in (display name only). |

### Layout

| Path | Role |
| --- | --- |
| `server/server.mjs` | Entry point and options. |
| `server/app.mjs` | `node:http` request handler: static allowlist, pages, JSON API, CSP and security headers, same-origin checks, body limits, rate limits. |
| `server/validate.mjs` | Upload validation: decodes with `codec/`, validates rotations with `schema/`, classifies with `site/kinds.mjs`, scans with `site/risks.mjs`. |
| `server/storage/store.mjs`, `sqlite.mjs` | Storage interface and its `node:sqlite` implementation. |
| `server/identity/provider.mjs`, `dev.mjs`, `session.mjs` | Identity-provider interface, the development provider, signed session cookies. |
| `server/ratelimit.mjs` | In-memory sliding-window limiter. |
| `server/pages.mjs` | Server-rendered HTML (everything escaped). |
| `server/moderate.mjs` | Moderation command line: list reports, hide/unhide/delete shares, ban users. |
| `site/markdown.mjs` | Safe Markdown subset → escaped HTML or DOM nodes; no raw HTML, http(s) links only for user content, no images. |
| `site/kinds.mjs` | Classifies every export kind (rotation envelope and legacy body, function bundle, custom function/condition, condition category, item set, effect, announcement, profile) and extracts display metadata. |
| `site/risks.mjs` | Import warnings: Lua code, code that runs on apply, chat/whisper/emote output to other players, macro-triggerable announcements, profile replacement, custom conditions a rotation needs, unrecognised content. |
| `site/tree-render.mjs`, `kind-render.mjs` | Browser rendering of the full decoded content and of the warnings. |
| `site/share-form.mjs`, `share-page.mjs`, `signin.mjs`, `site.mjs`, `client.mjs` | Page scripts. |
| `site/site.css`, `theme-init.js` | Light/dark theme (follows the system, with a toggle) and phone-width layout. |

### API

All JSON. State-changing calls need `X-Requested-With: rotationmaster`, `Content-Type: application/json` and, when the browser sends one, a same-origin `Origin`.

| Call | Purpose |
| --- | --- |
| `GET /api/health`, `GET /api/me` | Liveness; the signed-in user, identity provider and limits. |
| `POST /api/auth/dev` `{displayName}`, `POST /api/auth/logout` | Development sign-in; sign out. |
| `POST /api/check` `{export}` | Decode, classify and scan an export without saving it. |
| `GET /api/shares?q=&kind=&class=&edition=&owner=&page=` | List shares (never includes export text). |
| `POST /api/shares` `{title,description,export,kind?,class?,editions?}` | Publish. Class/editions declared by the export win; a conflicting declaration is refused. |
| `GET /api/shares/<id>` | One share including its export text. |
| `DELETE /api/shares/<id>` | Delete; uploader only. |
| `POST /api/shares/<id>/report` `{reason,details?}` | Report (one per user per share). |

Limits (defaults in `server/app.mjs` and `server/validate.mjs`): export 256 KiB, title 3–120 characters, description 20,000 characters, uploads 10 per user and 30 per address per hour, reports 20 per user per hour, sign-ins 30 per address per hour, checks 60 per address per minute. The same user cannot publish an identical export twice.

### Help content

Help is sourced from the addon's own in-game help (`Help/*.lua`, `UI/help.lua`, `Locales/enUS.lua`), `docs/` and the code (for example `main.lua`'s `/rm` handler). When the addon changes, update the matching `site/help/*.md` page. Run `python3 tools/export_web_conditions.py` after adding or renaming a condition type; `--check` (part of `tools/check`) fails while it is stale. `tests/web_site_content.mjs` checks that every help link and anchor resolves, that every catalog condition has a name and category, and that every `/rm` command from the in-game help is documented.

### Tests

```sh
node --test tests/web_site_api.mjs tests/web_site_content.mjs
```

They start the app on an ephemeral `127.0.0.1` port with an in-memory database and stop it afterwards.

## Local export viewer

Serve this directory over loopback HTTP from the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory Web
```

Open `http://127.0.0.1:8765/`. Browser ES modules and the local declaration catalog require HTTP; opening `index.html` with `file://` is not supported. The application fetches only its same-origin static catalog. It does not fetch imported source URLs, spell metadata or remote assets.

Paste an export and choose Decode. “Compare another export” opens an optional second input with its own Decode, Clear and original-copy controls. Comparison is explicit and uses two current accepted decodes. Decoding, structural validity, supported fields, declarative reference resolution and native readiness are separate states. Native readiness and gameplay quality are never certified by this viewer. A declared class, edition, source or review date is imported metadata. The browser does not infer missing applicability from spell IDs.

Known structures show ordered actions, cooldowns, branch arms and nested conditions. Unknown or invalid data stays available in a typed raw view. Display is bounded and paginated; byte escapes and shortened previews do not change the import. Copy original export retains the exact successful text, including wrapping. Editing the input retires that copy authority until another successful Decode. Clipboard denial offers a manual-copy field.

The current UI is English. Localization remains separate work. There is no local history or application storage. Browser form, clipboard and operating-system behavior are outside that statement.

## Transport and data

See [codec/README.md](codec/README.md) for the fixed input, decompression and portable-data limits, Lua byte-string/Map representation, actual bundled-codec oracle and protocol provenance. The viewer uses those modules without re-encoding imports. Numeric and byte-string keys remain distinct; decoded source is inert text.

## Declarative schema

`schema/catalog.json` contains the reviewed condition declarations and source hashes, not callback code or native facts. Generate a new candidate for review with:

```sh
lua5.1 tools/export_web_schema.lua > /a/new/review/path/catalog.json
```

Run this command from the repository root. Compare the candidate before deliberately replacing the committed catalog. The exporter loads only trusted authored declarations through the offline registration fixture; it does not invoke validation, evaluation, summary, Help, Fields UI or registration callbacks.

The schema module exposes `validateBody(value, catalogText, options?)`, `validateEnvelope(...)` and `indexRotationSteps(body, options?)`. Values use the codec's original byte-string/Map model. Catalog input is JSON **text**, checked before user data. Validation returns `valid`, `supported`, `resolved`, ordered diagnostics and explicit semantic/execution/quality states, plus a structural-only scope and unverified native availability. Indexing returns `{ok,index}` or `{ok:false,diagnostic}`; the index's rows retain read-only input references.

Optional `declarationCase` selects an observed fixture case rather than a native-client promise. The viewer does not guess a case. Ambiguous ROLE variants, provider-dependent declarations and unknown/custom conditions remain unresolved. Optional string Sets `itemsets`/`effects` describe known reference IDs only; they establish neither runtime availability nor execution permission. Dynamic definition flags and executable custom-schema providers are not accepted options. Tags are validated without normalization or input mutation.

Lua metadata-field diagnostic order differs between VMs because its implementation uses `pairs`. JavaScript uses author/realm/email/website/version order for that specific set of type errors. Tests compare code/path multiplicity only in the explicit five-invalid-metadata case; ordinary ordered diagnostics remain exact comparisons. Sampled differential agreement is not exhaustive equivalence or native acceptance.

## Pure two-way comparison

`schema/diff.mjs` exposes `diffRotations(left, right, options?)` for envelope-like Maps. It returns structural `valid`/`complete` flags, changes and diagnostics. The local comparison UI uses this module without inferring applicability, execution readiness or lineage. Legacy wrapping follows the explicit eligibility rule below.

Changes retain typed field/step segments and detached before/after payloads. Priority matching uses exact step IDs or caller-supplied `leftOrigins`/`rightOrigins` Maps, with a longest-increasing-subsequence move calculation. Arbitrary regenerated IDs produce add/remove changes. Both branch arms are indexed, including forced-away arms; ordinary nested fields named `onTrue`/`onFalse` remain data. The saved `body.revision` counter is ignored; root `id`/`revision` are ignored only with explicit Boolean `ignoreIdentity`. Nested custom fields called `revision` remain significant.

Options are a closed, caller-owned plain descriptor object; imported callbacks and accessor options are refused. This is not a sandbox for hostile JavaScript proxies or modified standard primitives. The comparator uses the codec's per-input portable bounds and the schema index's strict 2,000-step/16-branch-depth bounds. It emits at most 500 changes and marks overlong paths or truncated changes incomplete. These logical limits do not establish a precise browser memory or CPU bound.

Typed segments carry identity. Display paths use the actual LuaJIT oracle's quoting of control bytes; Lua 5.1 can spell those paths differently. Preserve byte values and never parse a display path to recover keys. Three-way clone comparison, conflict detection and patches remain later work.

## Comparing two inputs

Decode each input before choosing Compare; changed text is not silently decoded. Each side retains its own accepted original-copy authority. Editing, clearing or decoding either side retires the pair result. Closing comparison clears the second input and its accepted/manual-copy data, then restores the first reader. Navigation between First export, Second export and Differences does not decode or compare again. Only one result viewport is mounted.

Both inputs need successful transport and valid declarative structure. Future envelope schemas remain raw-only and cannot produce equality. A legacy body is wrapped in-memory only after actual body validation and an exact Map priority field named `rotation` or `cooldowns`; no identifier, class, edition, provenance or source revision is invented. Mixed legacy/envelope comparison includes existing envelope metadata, with missing legacy metadata left absent. Raw-inspectable future branch fields can still fail the comparator's strict graph contract. Unresolved references may be compared as literal data without becoming available for execution.

Only a complete valid comparison with zero changes reports no structural differences. Failed comparisons are unavailable; bounded incomplete results remain partial, including when no changes could be returned. The UI uses the comparator's default full-envelope identity behavior and offers no origin-mapping or automatic merge controls. Regenerated step IDs appear as additions/removals.

Differences page 25 returned changes at a time. Typed field/step segments retain numeric/byte-key distinctions; display paths are text only. Before/after uses the reader's shared raw pager and byte inspector, preserving false, zero, empty values and absent sides. Rendering remains bounded to one result viewport, with no imported code, HTML or URLs executed. Clipboard feedback belongs to its own input and cannot replace a comparison result. These source/state controls do not establish screen-reader or all-browser conformance.

## Bundled source catalog

`catalog/defaults.json` contains the thirty-six current bundled definitions, generated through production registration, library initialization and export. It records explicit `enUS` display strings separately from unchanged symbolic manifest keys and raw Lua bytes. Source file hashes provide consistency metadata; they do not authenticate upstream content or establish native readiness. The catalog and browser add no addon runtime work.

Generate the primary catalog with `lua5.1 tools/export_web_defaults.lua` or `luajit tools/export_web_defaults.lua` from the repository root. Both produce identical sorted typed JSON. The trusted generator loads only reviewed fixed source paths and supplies an explicit offline English locale; it does not execute condition/provider callbacks or query gameplay facts. `luajit tools/export_web_defaults.lua --fixtures` creates actual bundled-codec wire snapshots. Their decoded semantics are tested; compressed/serialized wire iteration order is not promised to be canonical.

`createBundledRotationCatalog(text, declarationCatalogText)` in `catalog/defaults.mjs` accepts JSON text and the existing declaration catalog text. It returns a private facade with fresh detached `list()` summaries and `get(id)` manifests, or a fixed failure reason. Applicability/tags and manifest tables remain typed Maps; human display strings remain Unicode. Number markers retain finite IEEE-754 bits, including signed zero values; byte markers retain exact raw bytes. Duplicate decoded keys, malformed closed fields and inconsistent declared IDs/source/display keys are refused.

The parser bounds catalog UTF-8 text to 2 MiB, records to 64 and source-file declarations to 128. Each manifest retains the codec's depth/node/string bounds and actual schema/strict graph checks. Validity, support and reference resolution remain separate; native availability is always unverified. The facade executes no imported code and invokes no game/provider callbacks, DOM, fetch or encoder. Sharing, generated exports and execution remain separate work.

## Browsing bundled definitions

Choose Bundled rotations to load the packaged catalog on demand. Select an entry to inspect its declared applicability, identity, English name/description and ordered/raw data through the same reader used for imports. Class filtering uses the manifest's declared token; All declarations includes unclassified or universal definitions. Filtering out the selected entry clears its inspection rather than silently selecting another entry. These are declarations, not the current character's eligibility.

Generated data is identified as Bundled rotation, with source path/hash and declared revision. It is never described as decoded transport and has no original-export copy authority. Human prose preserves Unicode and uses its own code-point pager with visible control/bidi/surrogate escapes; raw Lua byte strings retain the existing byte inspector. Complete long descriptions remain reachable.

Imports and its accepted originals/two-input comparison remain independent. Returning to Imports restores its prior result; source navigation releases old result handlers. Catalog selection does not decode, compare, edit or encode anything. Bundled generated definitions have no original export to share or download; editing remains later work.

With a bundled definition selected, choose Compare with first export to compare its manifest against the current accepted First export. The Second export and its comparison are preserved. Comparison never decodes changed input, invents catalog transport or changes either source. The same eligibility, strict graph checks, typed structural diff, limits and incomplete-result handling apply to both comparison modes. Missing or unsupported structure is unavailable, never equality.

The comparison names the right source Bundled rotation and shows bounded declared identity/revision/source/name context. Read bundled rotation returns to the complete shared source reader without rerunning comparison. Selecting or reselecting a definition, filtering it out, changing First export, leaving the catalog or disposing the mount retires its comparison. A class filter that retains the same selection may retain the result. Returning to the catalog starts in Read mode. Metadata and matching step IDs do not establish native readiness or clone lineage.

Only fixed local declaration/catalog resources are loaded, with credentials omitted, redirects refused, fatal UTF-8 decoding and separate streamed byte caps: 512 KiB for declarations and 2 MiB for bundled data. A failed catalog has an explicit Retry; it does not disable imported transport/raw recovery. Validated catalog data is cached only for the current mount; retired loads cannot replace newer visible state or focus. No metadata/source-guide URLs are fetched.

## Sharing an original export

After a successful Decode, Copy share link creates a link containing the complete original export in the `#rm-import-v1=` fragment. Anyone with that link can read the export. The browser app does not upload it or shorten the link. The final HTTP(S) link has an 8,192-byte limit; longer exports remain available through exact original copy and download. Clipboard denial offers a separate manual-copy link field. Editing, clearing or replacing the input retires sharing authority until the next successful Decode.

Download original export requests a file named `rotation-master-export.txt`, containing the exact accepted UTF-8 export bytes without newline conversion or re-encoding. Browser download policy determines what happens to that request; RM does not claim a file was saved. Generated bundled definitions have neither original transport nor these sharing controls.

An incoming recognized fragment offers Load into first export or Dismiss. Loading explicitly replaces the First input and retires its old decode/comparison; the Second input is preserved. Decode remains a separate action. Fragment changes never silently decode or compare data, change browser history or overwrite either input. There is no application storage or telemetry service.

## Checks

From the repository root:

```sh
node --test tests/web_codec.mjs
node --test tests/web_schema.mjs
node --test tests/web_viewer.mjs
node --test tests/web_diff.mjs
node --test tests/web_compare.mjs
node --test tests/web_defaults.mjs
node --test tests/web_catalog.mjs
node --test tests/web_catalog_compare.mjs
node --test tests/web_share.mjs
node --test tests/web_sharing_ui.mjs
node --test tests/web_site_api.mjs
node --test tests/web_site_content.mjs
python3 tools/check
```

These use Node's built-in test runner and the actual Lua 5.1/LuaJIT oracles; no npm install is required. Local verification uses Node 24.22.0. Isolated author worktrees may explicitly supply a read-only codec dependency root; ordinary repository checks use adjacent committed modules. Source tests, actual-browser rendering/accessibility checks and in-game acceptance establish different things. No screen-reader or native-game result follows from headless tests.

`Web/`, tests and build tools are excluded from the WoW addon archive. The browser application adds no gameplay polling or SavedVariables state.

## Local draft editing

After decoding First, choose Edit a copy to create a detached local draft. Body priority can be unset or an integer from -100000 to 100000; body disabled distinguishes unset, false and true. Existing non-branch spell, item, pet, any and none steps also expose only disabled, with the same three states. Choose a strict stable step ID from pages of at most 50 rows; section, position, branch-arm and literal action context identify the selected row. Stop rows show suppress_attack as unset, false or true. Imported type/action text uses bounded escaped byte previews; long item lists show at most eight entries with a remaining count. Preview formatting does not alter stored bytes. Branches and unknown action types remain read-only. Opening or navigating a draft does not create missing fields. Name/description editing is deferred until Unicode-to-Lua-byte and newline policies are defined. Other text, actions, conditions, structure, bundled clones and generated source identities are outside this editor.

Editing requires the local schema, valid recognized structure and a strict step index. Custom or unresolved data may remain opaque without becoming executable or natively available. Invalid/future structures remain read-only. The original accepted input, Second import and bundled catalog remain independent. Existing envelope IDs, revisions and source declarations are retained as imported metadata, not authenticated provenance or a new official revision. No revision is automatically incremented.

Review changes explicitly, then Generate new export and Copy new export. Each step change is reviewed by exact ID and structural path. Generation uses the reviewed Ace1/LibCompress Store encoder; a new export can have different compressed bytes from the original while retaining the same typed values except the selected edits. Numeric/byte-string keys, opaque subtrees, unedited number bits and byte strings remain data. A step edit copies its bounded structural path, so opaque aliases to that step or its containing body/list/branch/arm keep their prior values. The comparator ignores body revision and step IDs, so closed private write commands preserve those independently of the displayed diff. The draft review separately compares literal priority presence and signed-zero values, so changing 0 to -0 or back is shown before generation even though structural comparison equates them. No custom Lua, provider callbacks, imported HTML or source URLs are executed.

Every edit clears prior review and generated output. Invalid input blocks generation. Encoder refusal shows a bounded failure and keeps the draft; it never substitutes an original or partial export. Clipboard denial leaves the separate, labelled generated manual-copy field available. Original-copy/share/download always refer to the accepted original string. Generated share links and downloads are outside this slice.

Changing, clearing or decoding First retires its draft and clears generated output. Matching text does not revive it. Body fields and the selected step's disabled value remain visible for recovery until explicit Discard draft; discard before opening another copy. Source-tab navigation preserves a still-current draft. Step selection, paging and writing recheck their render and draft lease after callbacks and source reads; an old handler cannot act on a replacement draft with the same step ID. Late copy completions and disposed or replaced step handlers cannot restore obsolete output or move focus into a hidden draft. Drafts have no persistence and disappear when the page is replaced or closed.
