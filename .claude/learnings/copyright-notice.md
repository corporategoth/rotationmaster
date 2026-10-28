# The copyright notice and the licence field

The terms are in `LICENSE` only ("MIT + Attribution"). A source file carries one line that names the owner and points there;
the exact text, the years and the comment syntaxes are the constants at the top of `tools/copyright.py`. The rule and its
reasons are in `docs/dev/conventions.md`; what to remember:

- **`python3 tools/copyright.py --write` is how a notice gets in** (a new file, a new year, new wording); `--check` is part of
  `tools/check --static`. Never paste the line by hand into a generated file: its generator emits it
  (`generate_builtin_sources.py`, `generate_artwork_catalog.py`, `locales.py` for a new bundle TOC) or the file is on the
  checker's skip list with the reason.
- **A new kind of file must be classified.** An extension or a name no rule in `tools/copyright.py` covers fails the static
  check with "not classified"; decide include (with a comment syntax) or skip (with a reason), do not widen a rule to hide it.
- **Vendored code is never touched** (`Libs/`, `LibsAugment/`, `tools/vendor/`): it keeps its own licence and pinned bytes.
- **Line one means line one**, after a shebang or the XML declaration (an XML comment before the declaration breaks the parse).
  A TOC comment is a line starting with a single `#`; `## Interface:` need not be first.
- **The notice moves every line down by two.** Comments are stripped from bytecode, so a Lua file compiles to the same program
  (`python3 tools/bytecode_equal.py` proves it), but `Data/builtin_sources.lua` records module hashes and callback line numbers:
  regenerate it after the notice goes into a Built In module, and prove only `hash` and `line` changed. Never touch the bytes
  of a frozen Built In helper body (`tests/private_helper_identities.lua`).
- **Every TOC says `## X-License: MIT + Attribution`**; the About page prints the field. The `tests/fixtures/restore_*.lua`
  snapshots embed old TOC bodies on purpose: leave them.
- If a test ever slices a source file by line number or compares its first line, fix the test to find its anchor by pattern; do
  not exempt the file from the notice unless it is a frozen byte-for-byte oracle (add it to `FROZEN` in the tool with the reason).
