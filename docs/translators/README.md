# Translating Rotation Master

Rotation Master uses the game client's own language; there is no language picker. English (`Locales/enUS.lua`) is the
source. Ten translations exist, each a generated file:

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

A string missing from a locale shows in English, so a translation can be finished in stages. (The strings of the load-on-demand text bundles in `Modules/` are the exception: all ten languages must be complete for them, and `tests/test_locale_bundles.py` fails otherwise.) Nothing here needs a
programmer except running the tools below.

## How the files work

`Locales/enUS.lua` assigns each string as `L["English text"] = true`: the key *is* the English the player sees. A translation
file maps the same key to the translated text:

```lua
-- en: "Choose a duration from 1 to %d seconds."
L["Choose a duration from 1 to %d seconds."] = "Wähle eine Dauer von 1 bis %d Sekunden."
```

- **Never edit `Locales/<xx>.lua` (or a text bundle's `<xx>.lua` under `Modules/RotationMaster_*`) by hand and never translate a key.** The tools read and write the main catalog and the bundles as one language; the files are written by `tools/locales.py`, which keeps
  their order and format. You provide `{key: translation}` and the tools do the rest.
- The `-- en:` comment above each entry is the English that entry was translated from. When the English later changes, the
  entry becomes **stale**: the game still shows the old translation until someone updates it, and the tools list it again.
- A few keys are names (`Rotation Master`, `WowSims`, addon and site names): they stay identical in every language and the
  tools do not ask for them (`tools/translation_exempt.json`).

## Workflow

```sh
python3 tools/translation_status.py                       # what is open, per language
python3 tools/translation_todo.py deDE --out deDE.json     # the work file for one language
# translate deDE.json (fill in each "translation")
python3 tools/translation_apply.py deDE deDE.json --dry-run
python3 tools/translation_apply.py deDE deDE.json
python3 tools/locales.py check
```

1. **Status.** `translation_status.py` counts, per locale: *complete*, *missing* (no entry), *stale* (English changed),
   *same* (equal to the English but not a name, so probably never translated) and *invalid* (placeholders broken; must be
   zero). `--json` is machine readable; `--json --details` lists the keys; `--fail-on invalid,orphans` is what CI runs.
   Words such as `Paladin` or `Frost` that really are the same in a language show up under *same*: review them and, when they
   are right, apply them with `--allow-identical --record-keep` so they are remembered and not asked again.
2. **Work file.** `translation_todo.py <locale>` writes a JSON list. Each item has the key, the English, why it is listed
   (`missing`, `stale` or `same`), for a stale entry the English it was translated from and the current translation, the
   placeholders that must survive, where the string is used (help text, editor window, Built In premade, ...) with the first
   source lines, the glossary words found in it, and a note when length or tone matters. `--limit 50` makes a batch,
   `--include missing` narrows it, `--format markdown` makes a readable list.
3. **Translate.** Fill each item's `"translation"` (leave `null` to skip an item). Use `glossary.md` so the same word is
   used for the same thing, and `style.md` for the register of your language. Use the game client's own wording for game
   terms (spells, classes, specializations, stats, zones).
4. **Apply.** `translation_apply.py <locale> <file>` validates everything first and writes nothing unless every translation
   passes; `--dry-run` only validates. It then writes the locale file through `tools/locales.py` and re-reads it to prove that
   exactly the supplied entries changed and each has the right `-- en:` source. It restores the previous file if that proof
   fails.
5. **Check.** `python3 tools/locales.py check` must pass for every locale. Commit `Locales/<xx>.lua` (and `locales.xml` if a
   language is new) with a message that says which language and how many strings, and how they were produced and reviewed.

## What the tools check

Errors (nothing is written): the key is not in English; empty text; a placeholder differs (`%s`, `%d`, `{{name}}`,
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

Report problems with the key (copy the English from the window) so they can be found.

## Adding a language

Not a translator task: it needs the locale code added to `tools/locales.py` (`LOCALES`) and `locales.xml`, and the website
to know it. Ask first.
