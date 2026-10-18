# Development checks

Run the explicit setup once for the current pinned checker:

```sh
python3 tools/setup_lint.py
python3 tools/check
```

Setup downloads the official TradeSkillMaster wowlua-ls binary into the ignored `.tools/` directory and verifies the SHA256 recorded in `tools/lint-tool.json`. It refuses to replace a different existing file. `--from-file` accepts a previously downloaded binary with the same checksum. There is no system-wide installation. Normal checks do not download anything; CI runs setup separately.

The runner checks Lua 5.1 syntax, actual TOC/XML load paths, vendor hashes, literal English localization keys, condition declaration/help metadata, WoW-aware static diagnostics and headless behavior. Behavioral tests require Lua 5.1 and LuaJIT; Python tests exercise the runner and guard tools. `python3 tools/check --static` omits behavior tests.

wowlua-ls is a beta development tool. Its current flavors are retail, classic, classic_era and forever; it has no separate TBC flavor. Configuration lists all four, scans vendored libraries as type declarations, and excludes the headless tests from the WoW environment. This does not certify compatibility with every client.

The initial audit had 224 warnings. Reproduced inherited defects were fixed, leaving 203 warnings in the reviewed starting baseline. Remaining warnings include migration work, optional addon globals and checker inference/stub limitations. New warnings and all errors fail. Fingerprints include the path, diagnostic, message and source text; line-number movement alone does not create a new warning. Duplicate occurrences are counted. Tool/configuration failures fail even when the checker exits successfully.

Use `python3 tools/lint.py --report-all` to inspect remaining warnings. A deliberate baseline update uses `--write-baseline`; review every change and explain the remaining debt. CI and normal checks never regenerate it. Passing the baseline gate means no new diagnostics, not that the addon is warning-free or fully type-checked.

`.pre-commit-config.yaml` invokes the same runner. Hooks have not been installed on this checkout. In-game testing is still required for native API behavior, protected actions, layout, tooltips and gameplay results. Literal English-key coverage does not mean every locale is translated.
