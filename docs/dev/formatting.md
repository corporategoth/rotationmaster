# Keeping the code readable

How Lua in this repository is laid out and commented, which files are exempt, and how to reformat one without changing
what it does. `docs/dev/conventions.md` has the naming and error-handling rules; this page is about the page itself.

## The layout

- One statement per line. No `;` between statements.
- No block on one line. The body of every `if`, `elseif`, `else`, `for`, `while`, `repeat`, `do` and named `function`
  goes on its own indented lines, a guard clause included:

  ```lua
  if not unit then
      return
  end
  ```

  The one exception is an anonymous function whose whole body is one `return`, written on one line and short enough to fit
  (`table.sort(rows, function(a, b) return a.n < b.n end)`, `{ get = function(o) return o.x end }`); an empty body
  (`function addon:Noop() end`) also stays on the head's line. A comment after a one-line statement moves to its first
  line.
- Four spaces per level, no tabs, no trailing whitespace, LF, one final newline.
- Spaces around operators, after commas and inside braces: `local x = a + b`, `{ key = value }`, `f(a, b)`.
- Lines wrap at 120 columns, at argument, field and `and`/`or` boundaries. A long string literal may exceed it; do not
  split a user-facing sentence across lines (the translation tools read one literal).
- A function passed as the last argument of a call opens on the call's line (`addon:Foo(a, function()` ... `end)`).
- A blank line before and after every statement that spans several lines (`if`, loops, functions, long calls and tables),
  and between groups of related statements. Do not stack blank lines. The exception is a run of guard clauses (an `if`
  with no `else` whose body is one plain statement) that do the same thing: consecutive `if ... then return end`
  guards, or consecutive `if ... then x = ... end` defaults, stand together with no blank line between them.

A copyright notice comment as the first line of a file (`tools/copyright.py`, `docs/dev/conventions.md`) is not formatted: it stays
line 1, followed by exactly one blank line, then the file's header comment.

`python3 tools/format_lua.py FILE` prints the diff the formatter would make, `--write` applies it. It never changes what
the program compiles to: it compiles the original and the result with `luac5.1` (listing without line numbers) and refuses
the file if they differ, if a comment would be lost or if a second pass would change the text again. The formatter is a
tool you run on purpose; no hook rewrites files. `--tree` stands for every file it owns (all tracked Lua except the
exemptions below), so `python3 tools/format_lua.py --write --tree` formats the repository. `--check` writes nothing and exits
1 for a file that is not laid out as the formatter would write it; `tools/check --static` runs
`python3 tools/format_lua.py --check --tree`, so a block written on one line fails the check.

`python3 tools/bytecode_equal.py` proves a formatting-only commit by comparing every changed Lua file with the base
revision under both `luac5.1` and `luajit -bl`; `--catalog` also compares the Built In helper function texts.
`python3 tools/readability_report.py` lists the files with the most long lines, statement-joining `;` and uncommented
functions. It reports and never fails.

## Comments

Comments say why, not what. The standard:

1. **A header** at the top of every file, above the first statement: what the file is for, what it owns and must not do,
   what loads it (the TOC position or the module that requires it) and the dependencies that matter (load order, a
   restricted-client rule, a saved-data shape). Three to eight lines.
2. **A header above every function** (including `function addon:Name` and local helpers): what it does, then each
   parameter and each returned value on its own line, then the assumption a caller must keep (called on the poll path,
   must not allocate, only valid while the window is open). The exact shape is in "Function headers" below. A trivial
   accessor gets one line.
3. **Section headers** in a file longer than about 150 lines, a line of `=` above and below the section title.
4. **Inside a function** a comment explains a trap or a non-obvious reason (a client quirk with its evidence, a workaround
   and what removes it, why an order matters). It does not narrate the next line.

Do not write change-log comments, do not leave commented-out code, do not add a to-do that is not an issue.

## Function headers

A header is a block of plain `--` lines directly above the function, no blank line between them and the function:

```lua
-- Brief description of what the function does, not how it does it.
-- @param spell number|string  The spell ID or name to look up; nil is not allowed.
-- @param unit string|nil  The unit token to check; nil means "player".
-- @return boolean  True when the spell is known and ready.
-- @return string|nil  The reason code when false; nil when true.
--
-- Longer notes only where they help: how it works, what a caller must know (side effects, ordering, timing).
function addon:IsSpellReady(spell, unit)
```

- The first line says what the function does, not how. Tags follow, then a bare `--` line, then the notes. A wrapped
  description continues on the next line indented by two spaces (`--   more text`). Wrap at 120 columns.
- One `@param name type  description` line per parameter, in declaration order, with the names the code uses. A method
  declared `function a:b()` does not list `self`; an explicit `self` parameter of any other function is listed. A
  varargs parameter is `@param ... type  what`.
- One `@return type  description` line per returned value, in order. Say in the type and the description whether nil is
  possible (`string|nil`). A function that returns nothing has no `@return` line; one with no parameters and no return
  values needs only the brief line.
- Types are Lua type names plus `table`, `function`, `any` and shapes where they help (`table{id=number,name=string}`,
  `table[]`, `string|nil`). A type may contain spaces only inside brackets. Read the body and the callers to decide the
  type and whether nil is allowed; a wrong type is worse than none.
- Use `--`, never `---`: three dashes start a LuaLS annotation and the static checker would begin type-checking the
  function. An existing `---@param` annotation stays directly above the function, below the header.
- A header never goes inside a Built In helper or condition callback (their text is hashed), and the functions nested in
  one cannot carry a comment either; they are left undocumented on purpose. Put the header above the helper and run
  `python3 tools/generate_builtin_sources.py --write` (the catalog's line numbers and module hashes move; nothing else
  may).

`python3 tools/function_comments.py` checks all of it: every named function that is not trivial (six or more code lines,
or parameters or a return value and more than three code lines) must carry a header whose tags match the code, and a
header that is malformed (missing brief line, a tag without a type and a description, two tags on one line, a header
behind a blank line, `@param` names that differ from the declaration, a missing or surplus `@return`) is reported. It
reads the same files as `format_lua.py --tree` minus `tests/`. `--summary` counts the violations per directory,
`--strict` also requires the tags on short functions, `--write-baseline FILE` records today's violations and
`--baseline FILE` makes only new ones fail (a ratchet: the key is file, function and kind, not the line number).

## Text that must keep its exact bytes

- **Built In helper and callback bodies.** The text between a helper's parameter list and its `end` is what saved
  custom copies and exported bundles hash (`tests/private_helper_identities.lua`, `Core/function_data.lua`), and the Built In
  source browser shows the callback text from `Data/builtin_sources.lua`. The formatter prints every body recorded there
  verbatim, so those functions keep their older, denser layout; do not reformat or add a comment inside one. Comments go
  above them or between the fields of a condition's registration table. After changing a Built In module run
  `python3 tools/generate_builtin_sources.py --write` and `python3 tools/bytecode_equal.py --catalog`.
- **Generated regions**: a block between `-- BEGIN GENERATED X` and `-- END GENERATED X` (the integration project
  catalog), the generated binding block at the end of a Built In module, `Data/builtin_sources.lua`, `Data/artwork.lua` and
  the locale catalogs are written by their generators; the formatter leaves them alone.
- Vendored libraries, premade rotation data under `Modules/` and pinned simulator data are never reformatted.
- Generated or golden fixtures (`EXEMPT_FILES` in `tools/format_lua.py`) and the test sources other tests read as text and
  cut up with string patterns or fixed anchors (`READ_AS_TEXT_BY_TESTS`, for example `tests/startup.lua`) keep their dense
  layout. When a new test slices another file's source, add that file to the list instead of loosening the pattern.
- The predecessor suites that used to pin whole files were retired (`docs/dev/architecture.md`, "Byte-pinned text"); do not
  add a test that compares a file's text with an earlier version. A test that slices source by pattern must tolerate the
  formatter's layout.
