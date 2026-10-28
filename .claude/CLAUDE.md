# Rotation Master: instructions for Claude Code

World of Warcraft addon (Lua 5.1 / LuaJIT-compatible, Ace3-based, no AceGUI any more) that advises the next spell or item and
lights the action-bar button. Eight game clients, ten locales, a companion website in a separate repository.
Start with `README.md`, `CONTRIBUTING.md` and `docs/dev/architecture.md`; the details of every rule below are in
`.claude/learnings/`.

## Directives (read these before touching anything)

1. **Never run a command that discards changes**: no `git reset`, `checkout --`, `restore`, `clean`, `stash`, `switch -f`,
   `merge/rebase --abort`, `worktree remove -f`. Revert by reading the file and editing it. Other agents work in other
   worktrees of this repository at the same time. Commit explicit paths (`git add <file>`), never `-A`, `.` or `commit -a`.
   Work in your own worktree on your own branch (`claude/<topic>`); the main checkout may be a live install with a dirty
   deployed overlay: never clean, reset or reformat it. See `learnings/git-and-worktrees.md`.
2. **Run only what you need, serially, at low priority.** The full suite takes tens of minutes; run it once, with
   `nice -n 19 ionice -c3`, and read the output. No busy loops, no synthetic load, no several heavy jobs at once, no
   killing processes by name. Tests must leave nothing behind (no files in the tree, no leaked temp directories).
3. **The whole suite is green and `tools/known_failures.txt` is empty.** A red command is yours until you prove otherwise
   on the base commit. Some suites still rebuild a predecessor of a file (`tests/fixtures/restore_*.lua`) and fail on any
   edit of it by design: record the change in the fixture on purpose, never to turn a run green, and do not add new
   byte-exact pins (prove behavior instead). `learnings/tests-and-locales.md`.
4. **Restricted clients (Retail, Forever) hide combat data.** Never compare, calculate with or index by a value from a
   restricted API without `platform:CanReadValue`. A condition either reads what the game allows, is *unavailable* this poll,
   or does not exist on that edition. Fixtures must model ABSENT globals. `learnings/restricted-clients.md`.
5. **User-facing text is American English** (color, behavior, gray, -ize) and goes through `L["literal"]` and
   `Locales/enUS.lua`. Keep it at or below **3,900** entries: text only read when a window opens belongs in a load-on-demand
   text bundle (`tools/locales.py move`; `docs/dev/architecture.md`, "Text bundles"). Strings have stable IDs; translations are written only by
   `tools/locales.py` through the translation tools and English is changed only with `tools/locales.py reword/add/move`; never
   hand-edit headers, hashes or IDs of `Locales/<xx>.lua` or a bundle's locale files.
   `learnings/translations.md`.
6. **Generated files are never hand-edited** (`.pkgmeta`, `Data/artwork.lua`, `Data/builtin_sources.lua`, the integration
   tables, locale files, the glossary). Run the generator; `python3 tools/check --static` proves freshness.
7. **Docs describe how things are. Planning documents are never stored in the repository** (no plans, roadmaps, to-do lists,
   proposals, notes-to-self); the pre-commit guard refuses them. Update the topic document with the code.
8. **Keep the website in step.** Any change to data, semantics or user-facing behavior (rotation fields, selection order,
   step types, conditions, the premade catalog, reason codes) has a matching change in the website repository: say what.
9. **Releases only contain what the game loads.** `tests/`, `tools/`, `docs/`, `.claude/`, `.gitea/` and the
   generators' source files are not in the package; `python3 tools/package_release.py --check` proves it. Never put a credential in a file.
   `learnings/deploy-and-release.md`.
10. **Every original source file starts with the copyright notice line** and every TOC says `## X-License: MIT + Attribution`.
    `python3 tools/copyright.py --write` adds it; the check is part of `tools/check --static`. Never copy the licence terms into
    a file and never hand-edit the notice in a generated file. `learnings/copyright-notice.md`.
11. **In-game probes need a copy box.** Anything a tester must paste back goes into a selectable multi-line window (focus and
    highlight so Ctrl-A, Ctrl-C works), not only chat; make test visuals visible in their resting state.

## Where things are

| Need | Look at |
| --- | --- |
| Layout, load order, engines, condition registry, how to add things | `docs/dev/architecture.md` |
| Commands: checks, generators, packaging, translation, slash commands | `docs/dev/running-things.md` |
| Style and naming, the copyright notice | `docs/dev/conventions.md` |
| Debugging a report from game | `docs/dev/debugging.md` |
| Premade rotations, modules, policy | `Modules/README.md` |
| Restricted clients | `docs/restricted-clients.md`, `docs/quality/client-support.md` |
| Translators | `docs/translators/` |
| Release procedure and beta guide | `docs/release/RELEASING.md`, `docs/release/BETA.md` |
| Review personas | `.claude/agents/` (`backend-developer`, `frontend-developer`, `security-analyst`, `test-fanatic`) |

## Quick commands

```sh
python3 tools/check --static                     # 20 s: syntax, load graph, locales, lint, generated files
python3 tools/fast_tests.py <changed .lua files> # suites named after them
python3 tools/check_all.py --baseline tools/known_failures.txt   # everything, never stops at the first failure (the list is empty)
python3 tools/package_release.py --check         # build the release zip offline and verify it
```

## When reviewing

Use the four personas in `.claude/agents/`. Each ends with the same rule: do not raise work to prove you did something; if the
findings are minor or only fix your own mistakes, say nothing needs to change.
