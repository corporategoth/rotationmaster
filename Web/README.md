# Local export viewer

The `Web/` application reads pasted RM exports as data. It has no backend, account, upload service or addon connection. Imported Lua and HTML are never executed. Hosting and publishing are separate decisions.

Serve this directory over loopback HTTP from the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory Web
```

Open `http://127.0.0.1:8765/`. Browser ES modules and the local declaration catalog require HTTP; opening `index.html` with `file://` is not supported. The application fetches only its same-origin static catalog. It does not fetch imported source URLs, spell metadata or remote assets.

Paste an export and choose Decode. “Compare another export” opens an optional second input with its own Decode, Clear and original-copy controls. Comparison is explicit and uses two current accepted decodes. Decoding, structural validity, supported fields, declarative reference resolution and native readiness are separate states. Native readiness and gameplay quality are never certified by this viewer. A declared class, edition, source or review date is imported metadata. The browser does not infer missing applicability from spell IDs.

Known structures show ordered actions, cooldowns, branch arms and nested conditions. Unknown or invalid data stays available in a typed raw view. Display is bounded and paginated; byte escapes and shortened previews do not change the import. Copy original export retains the exact successful text, including wrapping. Editing the input retires that copy authority until another successful Decode. Clipboard denial offers a manual-copy field.

The current UI is English. Localization and editing remain separate work. There is no local history or application storage. Browser form, clipboard and operating-system behavior are outside that statement.

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

`catalog/defaults.json` contains the fifteen current bundled definitions, generated through production registration, library initialization and export. It records explicit `enUS` display strings separately from unchanged symbolic manifest keys and raw Lua bytes. Source file hashes provide consistency metadata; they do not authenticate upstream content or establish native readiness. The catalog and browser add no addon runtime work.

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
python3 tools/check
```

These use Node's built-in test runner and the actual Lua 5.1/LuaJIT oracles; no npm install is required. Local verification uses Node 24.22.0. Isolated author worktrees may explicitly supply a read-only codec dependency root; ordinary repository checks use adjacent committed modules. Source tests, actual-browser rendering/accessibility checks and in-game acceptance establish different things. No screen-reader or native-game result follows from headless tests.

`Web/`, tests and build tools are excluded from the WoW addon archive. The browser application adds no gameplay polling or SavedVariables state.
