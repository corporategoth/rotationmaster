# Keeping the code readable

How Lua in this repository is laid out and commented, which files are exempt, and how to reformat one without changing
what it does. `docs/dev/conventions.md` has the naming and error-handling rules; this page is about the page itself.

## The layout

- One statement per line. No `;` between statements, no `if a then b() c() end` carrying two statements. A guard clause
  (`if not x then return end`) may stay on one line when it is a single plain statement and short.
- Four spaces per level, no tabs, no trailing whitespace, LF, one final newline.
- Spaces around operators, after commas and inside braces: `local x = a + b`, `{ key = value }`, `f(a, b)`.
- Lines wrap at 120 columns, at argument, field and `and`/`or` boundaries. A long string literal may exceed it; do not
  split a user-facing sentence across lines (the translation tools read one literal).
- A function passed as the last argument of a call opens on the call's line (`addon:Foo(a, function()` ... `end)`).
- A blank line before and after every statement that spans several lines (`if`, loops, functions, long calls and tables),
  and between groups of related statements. Do not stack blank lines.

`python3 tools/format_lua.py FILE` prints the diff the formatter would make, `--write` applies it. It never changes what
the program compiles to: it compiles the original and the result with `luac5.1` (listing without line numbers) and refuses
the file if they differ, if a comment would be lost or if a second pass would change the text again. The formatter is a
tool you run on purpose; no hook rewrites files.

`python3 tools/bytecode_equal.py` proves a formatting-only commit by comparing every changed Lua file with the base
revision under both `luac5.1` and `luajit -bl`; `--catalog` also compares the Built In helper function texts.
`python3 tools/readability_report.py` lists the files with the most long lines, statement-joining `;` and uncommented
functions. It reports and never fails.

## Comments

Comments say why, not what. The standard:

1. **A header** at the top of every file, above the first statement: what the file is for, what it owns and must not do,
   what loads it (the TOC position or the module that requires it) and the dependencies that matter (load order, a
   restricted-client rule, a saved-data shape). Three to eight lines.
2. **A comment above every function** (including `function addon:Name` and local helpers): what it does, in terms of
   its inputs and result (`returns value, or nil and a reason`), and the assumption a caller must keep (called on the poll
   path, must not allocate, only valid while the window is open). A trivial accessor gets one line.
3. **Section headers** in a file longer than about 150 lines, a line of `=` above and below the section title.
4. **Inside a function** a comment explains a trap or a non-obvious reason (a client quirk with its evidence, a workaround
   and what removes it, why an order matters). It does not narrate the next line.

Do not write change-log comments, do not leave commented-out code, do not add a to-do that is not an issue.

## Files that must keep their exact bytes

Layout changes are never free for these. Run the suite before assuming a file can be reformatted.

- **Built In helper and callback bodies.** The text between a helper's parameter list and its `end` is what saved
  custom copies and exported bundles hash (`tests/private_helper_identities.lua`, `Core/function_data.lua`). The formatter
  prints every body recorded in `Data/builtin_sources.lua` verbatim, so those functions keep their old, denser layout; do
  not reformat or add a comment inside one. After changing a Built In module run
  `python3 tools/generate_builtin_sources.py --write` and `python3 tools/bytecode_equal.py --catalog`.
- **Files a predecessor fixture rebuilds.** Suites such as `tests/cpu.lua`, `tests/analytics_start_witness.lua`,
  `tests/editor_provider_reuse.lua` and the Built In condition suites rebuild an earlier version of a file from its current
  bytes (`tests/fixtures/restore_*.lua`) and fail on any other change, comments and whitespace included. The files they pin
  today are listed in `docs/dev/architecture.md`, "Byte-pinned files". Retiring one of these proofs is a decision about a whole suite;
  until it is made the file keeps its bytes.
- Generated files (`Data/builtin_sources.lua`, `Data/artwork.lua`, the locale catalogs), vendored libraries, premade
  rotation data under `Modules/` and pinned simulator data are never reformatted by hand.
