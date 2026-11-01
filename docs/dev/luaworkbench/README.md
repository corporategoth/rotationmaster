# LuaWorkbench isolated editor API

Rotation Master uses a separately installed LuaWorkbench only when it exports
`LuaWorkbenchEmbedding:CreateEngine`. It does not ship the LuaWorkbench editor.
The public LuaWorkbench 1.2.2 release does not provide that API, so RM falls
back to its native editor with that release. WowLua is a separate optional
syntax provider, including on Mists Classic.

`1.2.2-isolated-editor.patch` records the generic API deployed in the local
LuaWorkbench 1.2.2 installation during development. It is not applied by RM or
included in an RM release. It adds isolated engine factories and leaves
RM-specific adaptations in `LibsAugment/LuaWorkbench.lua`. It has not been
published as an upstream LuaWorkbench release. The patch expects the files in
LuaWorkbench's 1.2.2 release archive with LF line endings and no trailing spaces; normalize the
archive's CRLF text files and trailing whitespace in a separate working copy before applying it. The
LuaWorkbench source carries its own MIT license.
