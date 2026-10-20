# Localization validation

The default `python3 tools/catalog_check.py` retains the existing literal English-reference check. Optional `--locales` checks the locale files listed by locales.xml and reports literal coverage, explicit English reuse, missing/fallback entries and computed assignments that need review. It does not infer a universal client locale list or execute locale source. Actual AceLocale fallback behavior is checked separately in both Lua runtimes.

`--locale-report PATH` writes the optional report. `--require-complete` fails incomplete literal coverage, unattested English reuse and an installation with no non-English target locales. Intentional unchanged English terms can be attested using `--allow-english PATH`, a JSON locale-to-key-list policy. A stable identifier accidentally displayed by `L[key]=true` is not an English-label translation. Static completeness does not certify linguistic quality, runtime-computed keys, fonts or native layout.

Only whole literal first arguments to string.format are inferred as printf contracts. Other contracts are supplied with `--contracts PATH`, a JSON key-to-kind-list map. Kinds are printf, summary, announcement and markup. The checks protect supported Lua 5.1 directives, named placeholders, primary-negation predicate position, escaped syntax and WoW color/texture/link payloads. Human hyperlink captions and predicate wording can be translated. Code examples and arbitrary punctuation are not automatically treated as formatting contracts.

Only English is currently installed. Translation and native CJK/font/layout acceptance remain pending; passing the default English check does not establish translated coverage.
