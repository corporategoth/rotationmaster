# Contributing

Thank you for helping. This page is the short version; the details are in [docs/dev/](docs/dev/architecture.md).

## Set up

```sh
git clone <the project's Gitea URL> && cd rotationmaster
python3 tools/setup_lint.py            # downloads and checks the pinned WoW static checker into .tools/
pip install pre-commit                 # or: pipx install pre-commit
pre-commit install --install-hooks
pre-commit install --hook-type pre-push
```

You need `python3`, `lua5.1` (with `luac5.1`) and `luajit`. `pre-commit install` refuses when `core.hooksPath` is set (by a
system or global git configuration). Then run the hooks by hand: `pre-commit run --all-files`, and before pushing
`pre-commit run --all-files --hook-stage pre-push`. A simpler local alternative, which installs a plain commit hook that runs
only the static checks and never touches `core.hooksPath`, is `python3 tools/install_hooks.py --install`.

To try changes in the game, link the checkout into `Interface/AddOns/RotationMaster` and each `Modules/RotationMaster_*`
folder into `Interface/AddOns` as well.

## Before you commit

| When | Run | Time |
| --- | --- | --- |
| Always | `python3 tools/check --static` | 20 s |
| You touched Lua | `python3 tools/fast_tests.py <files>` (the pre-commit hook does this) | seconds |
| You touched a generated input (an `Assets/*/provenance.json`, a condition, an integration record) | the generator with `--write`, then commit both | seconds |
| Before a pull request | `python3 tools/check_all.py --baseline tools/known_failures.txt --skip-slow tools/slow_tests.txt` (never stops at the first failure; CI also runs the five slow commands) | about a quarter of an hour; run it once, at low priority |

The hooks (`.pre-commit-config.yaml`) run: whitespace and file checks, Lua 5.1 syntax, LF line endings, a guard against
planning documents and local files, a credential scan, the static gate, American spelling, the development tools' tests, and
the suites named after the changed files. The full suite and a package build run at push. CI runs all of it again.

## Rules that matter

- **American English** in everything a player or developer reads: color, behavior, gray, -ize. `tests/test_us_spelling.py` checks.
- **User-facing text** goes through `L["literal English"]` and `Locales/enUS.lua`; see `docs/dev/architecture.md`
  ("Add or change a locale string"). Each string has a stable ID; change wording with `python3 tools/locales.py reword`. Translations go through the tools in `docs/translators/`, never by hand.
- **Generated files are never edited by hand** (`docs/dev/architecture.md` lists them). `.pkgmeta` is one of them.
- **Platform first.** Game APIs are read only in `Platform/` and return `nil, reason` when they cannot be read. Retail and Forever
  hide combat data from addons; never compare a value you have not checked with `CanReadValue`.
- **Many tests are byte-freeze checks.** Editing a frozen file fails them on purpose until the recorded fixture is updated;
  read "Tests" in `docs/dev/architecture.md` first, and compare against a baseline (`tools/known_failures.txt`) before
  calling a failure a regression.
- **Docs describe how things are.** Do not commit plans, to-do lists, roadmaps or proposals; the pre-commit guard refuses them.
  Update the topic document in the same commit as the code.
- **No new global state, no busy loops, no allocation in the poll.** See `docs/dev/conventions.md`.
- **Keep the website in step.** A change to data, semantics or user-facing behavior (fields, step types, conditions, the premade
  catalog, reason codes) usually needs a matching change in the website repository; say so in the commit message.
- **Git:** one topic per branch and worktree, `git add <paths>` (never `-A`), a commit message that says why. Never run commands
  that discard changes (`reset`, `checkout --`, `restore`, `clean`, `stash`); undo by editing.

## Pull requests

Describe what changed for a player or a developer, what you ran (commands and results, including anything you could not run
and why), and what has *not* been tried in a real client. Say which clients the change was reasoned against. A change that
adds or alters strings lists the languages that now lag.

## Reporting problems and translating

Players: see `docs/release/BETA.md`, "Report a problem". Translators: `docs/translators/README.md`. Maintainers cutting a
release: `docs/release/RELEASING.md`.

## License

By contributing you agree your contribution is released under the project's [MIT license](LICENSE).
