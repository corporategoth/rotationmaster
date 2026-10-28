# Function header comments

The standard and the checker are in `docs/dev/formatting.md` ("Function headers") and `tools/function_comments.py`. What
bit while the headers were written:

- **Read the body and the callers before writing a type.** Return values are the usual trap: `return xpcall(...)` hands
  back what the *handler* returned (a report id), `return (s:gsub(...))` is one value but `return s:gsub(...)` is two, and
  `return pcall(f)` has the error text as a second value only on failure. The `@return` count the checker wants is the
  largest number of values any `return` statement lists; a tail call or `...` can return more, so describe it.
- **Comments never go inside a Built In helper or callback.** Their text is hashed. A function nested inside one cannot be
  commented at all, so the checker skips it. Comments *above* a helper shift the line numbers recorded in
  `Data/builtin_sources.lua`: run `python3 tools/generate_builtin_sources.py --write` and prove that only `["line"]` and
  module `["hash"]` fields changed (normalize both and compare), then `luajit tests/private_helper_identities.lua`.
- **Marker regions stay intact.** `Diagnostics/cpu.lua` is full of `-- BEGIN X` / `-- END X` lines that tests and restore
  fixtures anchor on. A header goes between the marker (and the comment lines that belong to it) and the function, never
  over them: replace only the function's own comment lines.
- **`---@param`/`---@return` LuaLS lines stay directly above the function**, below the `--` header. The checker ignores
  them. Do not convert them: the linter reads them.
- **Duplicate and ignored parameter names are parameters.** `function(_, mod, _, stage)` has four, and the header lists
  `_` twice, in order. An explicit `self` of a local function or of `name = function(self, ...)` is listed; the implicit
  one of `function a:b()` is not.
- **Do not reword to fit.** A header keeps the information of the comment it replaces (move the extra text under a bare
  `--` line). Comment lines wrap at 120 columns; `format_lua.py --check --tree` does not check that, so look.
- **Prove comment-only commits** with `python3 tools/bytecode_equal.py --base <rev> <files>` and
  `python3 tools/format_lua.py --check --tree`; run the suites that load the files you touched (a few, not the whole
  suite).
- **Introducing the check on a tree that is not documented yet**: `python3 tools/function_comments.py --write-baseline FILE`
  records today's violations and `--baseline FILE` makes only new ones fail; delete entries (rewrite the file) as files
  get documented, the tool says when entries no longer occur.
