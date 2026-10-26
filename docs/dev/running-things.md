# Running things

Everything runs from a checkout with `python3`, `lua5.1` (with `luac5.1`) and `luajit` on `PATH`. Nothing needs the
network except the one-time checker download. Use absolute paths when you call a tool from another directory.

## One-time setup

```sh
python3 tools/setup_lint.py            # downloads the pinned wowlua-ls into .tools/ and checks its SHA256
pre-commit install --install-hooks     # optional: the hooks in .pre-commit-config.yaml
pre-commit install --hook-type pre-push
```

`tools/setup_lint.py` never replaces a different existing file; `--from-file` accepts a binary you already downloaded.
`.tools/` is ignored by git. A separate local alternative to the framework is `python3 tools/install_hooks.py --install`,
which installs a plain `pre-commit` hook running `tools/check --static` (it backs up any hook already there and refuses to
touch `core.hooksPath`).

## The checks

| Command | What it does | Time |
| --- | --- | --- |
| `python3 tools/check --static` | Lua 5.1 syntax of every source, the real TOC/XML load graph, vendor hashes, literal localization keys, `locales.py check`, the pinned WoW static analysis against its baseline, Built In names, and the freshness of every generated file | about 20 s |
| `python3 tools/check` | The above plus every behavior suite on Lua 5.1 and LuaJIT and the Python checks; stops at the first failure | minutes |
| `python3 tools/check_all.py` | The same command list, never stopping at the first failure; prints one line per command and the output of failures | minutes |
| `python3 tools/check_all.py --runtime lua5.1` (or `luajit`, `python`) | Only the commands that use that runtime (CI runs the three as a matrix) | |
| `python3 tools/check_all.py --baseline tools/known_failures.txt` | Lets the commands listed in that file fail (see below) | |
| `python3 tools/check_all.py --skip-slow tools/slow_tests.txt` | Leaves out the six commands that take over 30 s each (what the pre-push hook runs) | about 15 min |
| `python3 tools/fast_tests.py Core/foo.lua` | Only the suites named after the files you changed (the pre-commit hook) | seconds |
| `python3 tools/test_devtools.py` | The tools' own tests (package builder, release notes, translation tools, workflow lint) | about 10 s |
| `python3 tests/test_us_spelling.py` | American English in enUS, help text and Markdown | seconds |
| `lua5.1 tests/<name>.lua`, `luajit tests/<name>.lua` | One suite | usually under a second |

`tools/check_all.py --json out.json` also writes every command's exit code and duration. `default_corpus.lua` is the one
very slow suite (many minutes); `tools/check_all.py --list` prints the command list without running anything.

### Heavy runs

The full suite is CPU heavy and the machine is usually in use. Run it serially, at low priority, once, and read its output
rather than re-running it:

```sh
nice -n 19 ionice -c3 python3 tools/check_all.py --json /tmp/results.json
```

Do not write busy loops or synthetic load to "test performance"; use the native profiler (`/rm perf`, below) in a client.
Do not run several full suites at once. A test must leave nothing behind: no files written into the tree and no leaked temporary directories (use
`tempfile.TemporaryDirectory` with cleanup).

### Known failures

`tools/known_failures.txt` lists commands that are red on the current branch (a command is a line such as
`lua5.1 tests/x.lua`). It is a temporary, honest list, not an exemption: CI's push workflow tolerates exactly those
commands; the release workflow does not. Many suites are byte-freeze checks that fail by design when a frozen file is
edited (`docs/dev/architecture.md`, "Tests"); fix them by updating the recorded fixture on purpose, then remove the line.

## Generated files

`python3 tools/<generator>.py` checks freshness and fails when a file is stale; `--write` rewrites it (`builtin_names.py`
takes `check`, `apply` or `docs`; `export_wowsims_mapping.py` takes `--check` or `--refresh <website checkout>`; see each
docstring). The table is in `docs/dev/architecture.md`. After changing
anything a generator reads (an `Assets/*/provenance.json`, a condition definition, an integration record), run the
generator and commit both the input and the output in the same commit.

## Static analysis (wowlua-ls)

`python3 tools/lint.py` runs the pinned checker against `tools/lint-baseline.json`: new diagnostics and all errors fail,
existing warnings are tolerated. `python3 tools/lint.py --report-all` lists the remaining warnings.
`--write-baseline` updates the baseline; review every change and never use it to silence a diagnostic you introduced.
The checker is a beta tool: it knows four flavors (retail, classic, classic_era, forever) and is not a certificate of
compatibility with every client.

## Building the release package locally

```sh
python3 tools/release_notes.py --target curseforge --out CHANGELOG.md     # optional; becomes CHANGELOG.md in the zip
python3 tools/package_release.py --check                                   # .release/RotationMaster-<version>.zip
python3 tools/package_release.py --tag 2.0.0-beta.1 --check                # as that tag would be packaged
python3 tools/package_release.py --parity                                  # compare with the vendored BigWigs packager
```

The builder reproduces the packager from `.pkgmeta` without a network, a token or a `zip` binary, and `--check` fails if
the package holds anything that is not for the game or lacks something that is. It packages tracked files from the
working tree. `--parity` clones HEAD into a scratch directory, runs the vendored `tools/vendor/bigwigs-packager/release.sh`
there and compares every file byte for byte; commit first, since a clone only has committed content.
`tools/package_release.py --check-zip FILE` verifies any zip, including the packager's.

## Translation tools

```sh
python3 tools/translation_status.py                       # missing / stale / untranslated / invalid per locale
python3 tools/translation_todo.py deDE --out deDE.json     # work file with context and glossary hits
python3 tools/translation_apply.py deDE deDE.json --dry-run
python3 tools/translation_apply.py deDE deDE.json
python3 tools/locales.py check
```

`docs/translators/README.md` has the whole workflow.

## Slash commands in game

| Command | Use |
| --- | --- |
| `/rm config` | Open the settings and rotation editor |
| `/rm current`, `/rm set <identifier>\|auto`, `/rm list`, `/rm why` | Which rotation is active, choose one, list identifiers, explain why each can or cannot be chosen |
| `/rm enable`, `/rm disable`, `/rm toggle` | Turn advising on and off |
| `/rm errors` | The session error report in a copyable window |
| `/rm check`, `/rm repair` | Validate the saved data; repair what internal validation can |
| `/rm debug glow [seconds\|show]`, `/rm debug talents [views]`, `/rm debug editor` | See `docs/dev/debugging.md` |
| `/rm perf cpu\|runtime\|memory [seconds\|stop\|report]`, `/rm perf probe`, `/rm perf engine [lean\|standard]` | Capture performance observations; choose the evaluation engine |
