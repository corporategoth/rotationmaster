# Translating Rotation Master

Rotation Master uses the game client's own language; there is no language picker. English (`Locales/enUS.lua`) is the
source. Ten translations exist. General text is generated in `Locales/`; Built In rotation text is edited in each class module’s `Locales/` directory:

| Code | Language | Style notes |
| --- | --- | --- |
| deDE | German | `style.md` |
| esES | Spanish (Spain) | |
| esMX | Spanish (Latin America) | |
| frFR | French | |
| itIT | Italian | |
| koKR | Korean | |
| ptBR | Portuguese (Brazil) | |
| ruRU | Russian | |
| zhCN | Chinese (Simplified) | |
| zhTW | Chinese (Traditional) | |

A string missing from a locale shows in English, so a translation can be finished in stages. Nothing here needs a
programmer except running the tools below.

## How the files work

Built In rotation names and descriptions are different: each class module has a `Locales/` directory, and every language
assigns text directly to `<rotation ID>.Name` and `<rotation ID>.Description` without numeric IDs. Run
`python3 tools/builtin_locales.py` to check that every rotation has both entries in all languages and no obsolete entries.

Every string has a **stable ID** within its own catalog, recorded in `tools/locale_registry.json`. IDs may overlap between catalogs; a removed ID is not reused within its catalog. Code reads `L["English text"]`; the catalog’s `enUS.lua` binds the exact English text to its number, `T["English text"] = 1234`, with a hash above it. At load time the matching translation is written to `L[English text]`; the numbers are not needed for lookups. A translation file maps the ID to the translation, with the English it was made from in the comment above:

```lua
-- 1a2b3c4d English: Choose a duration from 1 to %d seconds.
-- %d #1: the longest duration in seconds, e.g. 60
[1234] = "Wähle eine Dauer von 1 bis %d Sekunden.",
```

- **The translation line holds only the ID and the string**, so in vim `f=lC"text",` replaces just the translation. Change
  nothing else on that line and leave the comment lines alone. Never translate or renumber an ID.
- **The first comment line is `-- <hash> English: <text>`**: the short hash is how the tools know the English this
  translation was made from. When the English later changes (a typo fix, a reworded sentence) the ID stays, your translation
  stays and the game keeps showing it, but the hash no longer matches: the entry is **stale** and `python3 tools/locales.py
  missing <xx>` lists it, with the English it was made from. Fix it, or - if the old translation is still right - confirm it
  with `python3 tools/locales.py accept <xx> <id>` for the main catalog or `<catalog>:<id>` for a class catalog.
- **`-- Context:` lines** say where a short or abstract string appears and what it does ("Step type dropdown entry in the
  rotation editor: the step casts a pet ability"), so you can tell a verb from a noun and a button from a heading.
- **`-- %s #1: ...` lines** say what each placeholder receives, in order, with an example (`the profile name, e.g.
  "Default"`). **Lua 5.1 `string.format` has no positional arguments (no `%1$s`): keep every `%s`, `%d` ... in the order of
  the English.** If your language would put them the other way round, reword the sentence so the order still works.
- The files are generated: `tools/locales.py` writes them in one canonical layout, the header comes from
  `tools/locale_translators.json`, and `locales.py check` fails if a header, a hash or an ID has been edited by hand. The
  tools read and write the main catalog and the text bundles as one language. You may edit a translation string in your
  editor; run `check` afterwards, and `python3 tools/locales.py rebuild` puts every file back into the canonical layout.
- A few strings are names (`Rotation Master`, addon and site names): they stay identical in every language and the
  tools do not ask for them (`tools/translation_exempt.json`).

### Where is this string used?

```sh
python3 tools/locales.py where 1234                  # main catalog ID
python3 tools/locales.py where class-shaman:1        # class catalog ID
python3 tools/locales.py where "Pet Spell"           # exact English, or a unique part of it
python3 tools/locales.py where -C 5 1234             # five lines around each use, merged like grep
python3 tools/locales.py where --id 1234 --json      # for editors
```

It prints the ID, the English, the catalog, any context and token notes, and each place the code reads the string (file,
line, the function it sits in, and as many surrounding lines as you ask for with `-B`, `-A`, `-C`). A string the code reads
through a variable is reported as "no direct call site found (looked up dynamically?)". In vim, with the cursor on the
`[1234]` of a translation line:

```vim
nnoremap <leader>w :!python3 tools/locales.py where -C 5 <C-r>=expand('<cword>')<CR><CR>
```

## Workflow

```sh
python3 tools/translation_status.py                       # what is open, per language
python3 tools/translation_todo.py deDE --out deDE.json     # the work file for one language
# translate deDE.json (fill in each "translation")
python3 tools/translation_apply.py deDE deDE.json --dry-run
python3 tools/translation_apply.py deDE deDE.json --translator "Your Name"
python3 tools/locales.py check
```

1. **Status.** `translation_status.py` counts, per locale: *complete*, *missing* (no entry), *stale* (English changed),
   *same* (equal to the English but not a name, so probably never translated) and *invalid* (placeholders broken; must be
   zero). `--json` is machine readable; `--json --details` lists the keys; `--fail-on invalid,orphans` is what CI runs.
   Words such as `Paladin` or `Frost` that really are the same in a language show up under *same*: review them and, when they
   are right, apply them with `--allow-identical --record-keep` so they are remembered and not asked again.
   `python3 tools/locales.py missing <xx>` is the plain list: untranslated IDs and stale IDs, nothing else.
2. **Work file.** `translation_todo.py <locale>` writes a JSON list. Each item has the ID, the key, the English, why it is
   listed (`missing`, `stale` or `same`), for a stale entry the English it was translated from and the current translation, the
   placeholders that must survive, where the string is used (help text, editor window, Built In premade, ...) with the first
   source lines, the glossary words found in it, and a note when length or tone matters. `--limit 50` makes a batch,
   `--include missing` narrows it, `--format markdown` makes a readable list.
3. **Translate.** Fill each item's `"translation"` (leave `null` to skip an item). Use `glossary.md` so the same word is
   used for the same thing, and `style.md` for the register of your language. Use the game client's own wording for game
   terms (spells, classes, specializations, stats, zones).
4. **Apply.** `translation_apply.py <locale> <file>` validates everything first and writes nothing unless every translation
   passes; `--dry-run` only validates. It then writes the locale files through `tools/locales.py` and re-reads them to prove
   that exactly the supplied entries changed and each has the right hash. It restores the previous files if that proof
   fails. A work file may also be a plain JSON object `{"1234": "translation"}`; the exact English key also works in place of an ID. This workflow covers the main catalog; edit Built In rotation files directly as described below.
5. **Check.** `python3 tools/locales.py check` must pass for every locale. Commit the locale files with a message that says
   which language and how many strings, and how they were produced and reviewed.

## Getting credited

Locale files start with a copyright line and a translator header generated from `tools/locale_translators.json`:

```lua
-- Translators: Claude (AI-assisted, not yet reviewed by a native speaker; 3041 strings), Jane Doe <https://example.org/jane> (120 strings, 2026-11-02)
```

The existing translations of all ten languages were produced by Claude (Anthropic) and have **not** been reviewed by a native
speaker; the header says so, truthfully. To be credited for your work, pass your name when the file is applied:

```sh
python3 tools/translation_apply.py deDE deDE.json --translator "Jane Doe" --url https://example.org/jane
python3 tools/locales.py build deDE translations.json --translator "Jane Doe"      # the same, without the validation tool
python3 tools/locales.py credit deDE --translator "Jane Doe"                     # credit hand edits made in a locale file
```

For a Built In rotation, find its class module under `Modules/RotationMaster_<Class>/Locales/`, open your language
file, and edit the text after `L["<rotation ID>.Name"] =` or `L["<rotation ID>.Description"] =`. Leave the key intact.
The same key in `enUS.lua` gives the English. Run `python3 tools/builtin_locales.py` to check all names, descriptions,
and placeholders. These direct-key files do not currently track whether their English has changed.

After editing a class file, credit yourself and optionally record the number of entries you translated:

```sh
python3 tools/locales.py credit deDE --catalog class-shaman --translator "Jane Doe" --url https://example.org/jane --strings 2
```

Replace `class-shaman` with the catalog for your class (`class-deathknight`, `class-demonhunter`, `class-druid`,
`class-evoker`, `class-hunter`, `class-mage`, `class-monk`, `class-paladin`, `class-priest`, `class-rogue`,
`class-shaman`, `class-warlock`, or `class-warrior`). The tool updates that file's header, records your credit, and
adds human translators to the game's About page. It does not count direct edits automatically; omit `--strings` if you
prefer not to provide a count. To credit an AI-assisted contribution, pass `--ai`; only human translators appear in About.

`--translator` adds you to the header of **every file that application wrote** (the main file and each text bundle), counting
the strings you changed (applying the same file again changes nothing); a second application only updates your counts and date
range. Names are matched case-insensitively, so one person is listed once. A model is credited with `--ai` and appears in
the header only.

The **About page** (the AddOns panel page and the About tab of the window) also credits you, in the language you translated:
`Translation (<language name>): Jane Doe, ...`. That line is built from a small data table, `L[0] = { "Jane Doe" }`, that
the tool writes into the same locale file, so it exists only while that language is the game's language, English never loads
it, and it lists **human translators only** (the AI is credited in the header, not on screen). The main file of a language
carries the human translators of all its catalogs, so the About page never has to load a text bundle. The list is cut after
about 480 bytes on the launcher page (whole names, then an ellipsis).

## Authoring context and token notes

For maintainers: `python3 tools/locales.py notes todo` lists the strings that have placeholders and no note per placeholder
(`needs: ["notes"]`) and the short strings (three words or fewer, no sentence punctuation; `--context-words N`) that have no
context (`needs: ["context"]`), each with the call sites found by searching the code, so the author can see the arguments
and the screen. `python3 tools/locales.py notes set notes.json` takes `{"1234": ["first token ...", "second token ..."],
"Pet Spell": {"context": "Step type dropdown entry ..."}}` (an ID or the English; an author may write `%s = what goes in`, the
`%s #1:` label is generated from the English) and regenerates the comments in every file. Notes and context live in
`tools/locale_registry.json` under `annotations`; they survive `rebuild`, `reword` and `move`. `check` fails when the number
of notes differs from the number of placeholders; `check --require-notes` and `check --require-context` fail for every string
that still lacks one.

## Developers: changing the English

`python3 tools/locales.py reword "old English" "new English"` rewrites every `L["old English"]` in the addon (the whole
literal only, in the quote style it uses, escapes handled), changes the enUS text and hash, **keeps the ID** and leaves every
translation in place, stale by hash. Plain strings equal to the old English are listed, not changed (`--all-literals`
changes them); `tests/` is listed, not changed (`--tests` rewrites its `L[...]` sites). `--dry-run` shows the plan. Edit Built In names and descriptions in their class module’s language files. For ordinary text, adding is `locales.py add "New text"` (or `sync` after adding the source literal); `remove` retires the catalog ID. Moving text between catalogs assigns a new destination ID and preserves its translations. `tools/builtin_locales.py` reports class translations no longer referenced by a rotation.

## What the tools check

Errors (nothing is written): the ID or key is not in the English; empty text; a placeholder differs (`%s`, `%d`, `{{name}}`,
`{name}`, `|cAARRGGBB`, `|r`, `|n`, `\n`); the order of `%` specifiers changed (Lua's `string.format` has no positional
arguments); a bare `%` in a formatted string; a `{{!yes|no}}` alternative pair lost its pipe or an empty half; a stray `|` or
backslash; a control or zero-width character; leading or trailing whitespace or the number of line breaks differs from the
English; the text is more than four times as long as the English; the translation equals the English and is not a name.

Warnings (printed): long for its English, a missing final full stop, a long text with none of the language's script, French
punctuation spacing, Chinese colons.

The tools cannot judge meaning, tone, or whether text fits its control. Those are yours.

## Rules for the text

- **Placeholders stay exactly as written**, in the same order. `%s` is replaced by a name or number at run time;
  `{{name}}` is replaced by a named value. Move them within the sentence only if the language needs it and the order of the
  *same kind* of placeholder is unchanged.
- **Alternatives** `{{!knows|does not know}}` pick the first text for a positive condition and the second for a negated
  one (a leading `!` marks the pair). Translate both texts; keep the braces, the `!` and the single `|`.
- **Color codes** `|cffffd100...|r` wrap text: keep each pair and its color; translate only the words inside.
- **Line breaks** stay where they are; a translation has the same number of paragraphs.
- **Slash commands** (`/rm set`, `/rm debug glow`) and their arguments are not translated.
- **Length.** Labels and buttons must fit their control: keep them about as short as the English. Help paragraphs may be
  longer but translate each as a whole; do not split or merge sentences.
- **Sentence case** in languages that use it (everything except German nouns, and CJK).
- Wording is for players of a game: plain, direct, no marketing tone. Use the same register as the existing text
  (`style.md`).

## AI-assisted translation

Machine-assisted drafting is allowed under these rules:

1. The machine writes a **draft**. The work file is the input and the output; the validation above is mandatory, not optional.
2. Give the model what the tool gives you: the English, the previous translation and the English it came from, the
   glossary hits, the area, and `style.md` for the language. Do not ask it to translate without the glossary.
3. Send small batches (50 to 100 items). Never send saved variables, names of other players, tokens or anything personal.
4. A native speaker should review before a release when one is available. If none did, say so in the commit message
   ("machine-assisted, not reviewed by a native speaker"). Do not call a text reviewed unless a person did.
5. When the model is unsure of a game term, leave the item `null` and ask; do not guess a spell or stat name.
6. A change to a glossary word is made everywhere or nowhere: update the locale entries that use it, then
   `python3 tools/translation_glossary.py --write`.

## Testing in game

Strings are only proven in the client. Set the client's text language (the Battle.net launcher's game language, or
`/console textLocale deDE` followed by a full restart; the client must have that language's text installed), log in, and
open `/rm config`:

- every label, button and tooltip in your language; no English left that should be translated, no raw `%s`, `{{...}}` or `|c`
  visible;
- long strings fit: the rotation editor, the condition editor and the settings pages at a small window size;
- the Built In list and the help text read naturally;
- `/rm help` and the chat messages (colors intact).

Report problems with the ID or the English (copy it from the window; `locales.py where` finds the rest) so they can be found.

## Adding a language

Not a translator task: it needs the locale code added to `tools/locales.py` (`LOCALES`) and `locales.xml`, and the website
to know it. Ask first.
