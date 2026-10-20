# Development checks

Run the explicit setup once for the current pinned checker:

```sh
python3 tools/setup_lint.py
python3 tools/check
```

Setup downloads the official TradeSkillMaster wowlua-ls binary into the ignored `.tools/` directory and verifies the SHA256 recorded in `tools/lint-tool.json`. It refuses to replace a different existing file. `--from-file` accepts a previously downloaded binary with the same checksum. There is no system-wide installation. Normal checks do not download anything; CI runs setup separately.

The runner checks Lua 5.1 syntax, actual TOC/XML load paths, vendor hashes, literal English localization keys, condition declaration/help metadata, WoW-aware static diagnostics and headless behavior. Behavioral tests require Lua 5.1 and LuaJIT; browser-module tests additionally require Node with its built-in test runner (locally verified with Node 24.22.0), without npm dependencies. Python tests exercise the runner and guard tools. `python3 tools/check --static` omits behavior tests.

wowlua-ls is a beta development tool. Its current flavors are retail, classic, classic_era and forever; it has no separate TBC flavor. Configuration lists all four, scans vendored libraries as type declarations, and excludes the headless tests from the WoW environment. This does not certify compatibility with every client.

The initial audit had 224 warnings. Reproduced inherited defects were fixed, leaving 203 warnings in the reviewed starting baseline. Remaining warnings include migration work, optional addon globals and checker inference/stub limitations. New warnings and all errors fail. Fingerprints include the path, diagnostic, message and source text; line-number movement alone does not create a new warning. Duplicate occurrences are counted. Tool/configuration failures fail even when the checker exits successfully.

Use `python3 tools/lint.py --report-all` to inspect remaining warnings. A deliberate baseline update uses `--write-baseline`; review every change and explain the remaining debt. CI and normal checks never regenerate it. Passing the baseline gate means no new diagnostics, not that the addon is warning-free or fully type-checked.

`.pre-commit-config.yaml` invokes the same runner. Local hook installation is optional and must be inspected per checkout with `python3 tools/install_hooks.py --check`; normal checks never change personal/system hooks. In-game testing is still required for native API behavior, protected actions, layout, tooltips and gameplay results. Literal English-key coverage does not mean every locale is translated.

## Integration catalog onboarding

The offline source of truth is `tools/integration_projects.json`; do not hand-edit its generated Lua block. When adding an actually supported addon identity or revising its links:

1. Match the exact addon folder, author and existing consumer. Keep forks and different-folder successors distinct. Update the explicit supported identity declaration only when the integration exists.
2. Research CurseForge, WoWInterface, Wago Addons, WowUp Hub and GitHub independently, plus an official author site when applicable. Record each search and its evidence as verified, not_found or unverified. Access failure is unverified. Retain official source repositories even when another host is the primary download.
3. Add all curated project URLs with provider, display label, note, per-link edition evidence and one primary link listed first. A verified official website takes this first position ahead of hosted release and source pages. Prefer stable project pages over version-caption or file-specific URLs; for WoWInterface verify the numeric project ID and project-name address. Document unavailable published URLs honestly. There is a hard 32-link per-identity limit, not silent truncation. Do not substitute guessed slugs, similarly named addons or unrelated repositories.
4. Record declared scope separately from current-patch evidence. List progression branches explicitly. Keep genuinely unknown scope visible; add interface bounds only with explicit evidence, never by treating an old release as a maximum supported version.
5. Regenerate and inspect the exact generated delta:

```sh
python3 tools/generate_integration_projects.py --write
python3 tools/generate_integration_projects.py
```

The generator uses local files only. It validates all five coverage records, exact identity coverage, URL/provider consistency, duplicate URLs, primary ordering, link bounds and scope evidence. Without `--write` it checks freshness and does not modify files. Review localized labels/notes and any derived source fingerprints required by the integration checks; retain the original historical assertions when composing a source inverse.

Use focused checks for the behavior changed, for example the generator regression tests or the relevant Lua catalog, project-link or settings test on both Lua 5.1 and LuaJIT. A card-layout-only edit should exercise affected geometry, state transitions and retired callbacks; it does not require rerunning unrelated codecs or gameplay suites after every edit. Broaden verification for an observed failure, a changed shared boundary, or a required release/hook check. Record commands, results and any native-library skip. This focused iteration policy does not bypass normal hooks or the checks required for the final integration checkpoint.
