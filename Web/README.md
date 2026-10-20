# Local export viewer

The `Web/` application reads pasted RM exports as data. It has no backend, account, upload service or addon connection. Imported Lua and HTML are never executed. Hosting and publishing are separate decisions.

Serve this directory over loopback HTTP from the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory Web
```

Open `http://127.0.0.1:8765/`. Browser ES modules and the local declaration catalog require HTTP; opening `index.html` with `file://` is not supported. The application fetches only its same-origin static catalog. It does not fetch imported source URLs, spell metadata or remote assets.

Paste one export and choose Decode. Decoding, structural validity, supported fields, declarative reference resolution and native readiness are separate states. Native readiness and gameplay quality are never certified by this viewer. A declared class, edition, source or review date is imported metadata. The browser does not infer missing applicability from spell IDs.

Known structures show ordered actions, cooldowns, branch arms and nested conditions. Unknown or invalid data stays available in a typed raw view. Display is bounded and paginated; byte escapes and shortened previews do not change the import. Copy original export retains the exact successful text, including wrapping. Editing the input retires that copy authority until another successful Decode. Clipboard denial offers a manual-copy field.

The current UI is English. Localization, structural diff, rotation-content catalog browsing, sharing links, downloads and editing are separate work. There is no local history or application storage. Browser form, clipboard and operating-system behavior are outside that statement.

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

`schema/diff.mjs` exposes `diffRotations(left, right, options?)` for envelope-like Maps. It returns structural `valid`/`complete` flags, changes and diagnostics. This module is not yet connected to a second-input browser UI. It does not infer legacy wrappers, applicability, execution readiness or lineage.

Changes retain typed field/step segments and detached before/after payloads. Priority matching uses exact step IDs or caller-supplied `leftOrigins`/`rightOrigins` Maps, with a longest-increasing-subsequence move calculation. Arbitrary regenerated IDs produce add/remove changes. Both branch arms are indexed, including forced-away arms; ordinary nested fields named `onTrue`/`onFalse` remain data. The saved `body.revision` counter is ignored; root `id`/`revision` are ignored only with explicit Boolean `ignoreIdentity`. Nested custom fields called `revision` remain significant.

Options are a closed, caller-owned plain descriptor object; imported callbacks and accessor options are refused. This is not a sandbox for hostile JavaScript proxies or modified standard primitives. The comparator uses the codec's per-input portable bounds and the schema index's strict 2,000-step/16-branch-depth bounds. It emits at most 500 changes and marks overlong paths or truncated changes incomplete. These logical limits do not establish a precise browser memory or CPU bound.

Typed segments carry identity. Display paths use the actual LuaJIT oracle's quoting of control bytes; Lua 5.1 can spell those paths differently. Preserve byte values and never parse a display path to recover keys. Three-way clone comparison, conflict detection, patches and visual diff remain later work.

## Checks

From the repository root:

```sh
node --test tests/web_codec.mjs
node --test tests/web_schema.mjs
node --test tests/web_viewer.mjs
node --test tests/web_diff.mjs
python3 tools/check
```

These use Node's built-in test runner and the actual Lua 5.1/LuaJIT oracles; no npm install is required. Local verification uses Node 24.22.0. Isolated author worktrees may explicitly supply a read-only codec dependency root; ordinary repository checks use adjacent committed modules. Source tests, actual-browser rendering/accessibility checks and in-game acceptance establish different things. No screen-reader or native-game result follows from headless tests.

`Web/`, tests and build tools are excluded from the WoW addon archive. The browser application adds no gameplay polling or SavedVariables state.
