# Localization validation

`python3 tools/catalog_check.py` checks that every literal `L["..."]` the addon reads is a key of one of the English catalogs
(`Locales/enUS.lua` and each text bundle's `enUS.lua`, which are generated in the stable-ID layout by `tools/locales.py`) and
that no key is defined in two catalogs.

`python3 tools/locales.py check` validates the locale files themselves: IDs unique across catalogs, never retired, each
hash matching its text, every translation's placeholders (`%s`/`%d` order, `{{name}}`, color codes, line breaks) matching
the English, the generated headers and translator tables matching `tools/locale_translators.json`, the context/notes
comments matching `tools/locale_registry.json`, and the registration order (translations first, English last).
`--complete` also fails on untranslated or stale IDs; `--require-notes` and `--require-context` fail for strings that still
lack their notes or context. `python3 tools/translation_status.py` reports coverage per language. Actual AceLocale
fallback behavior is checked separately in both Lua runtimes (`tests/locale_fallback.lua`, `tests/client_locale.lua`,
`tests/text_bundles.lua`).

Static completeness does not certify linguistic quality, fonts or native layout. The existing translations were produced
by an AI and have not been reviewed by a native speaker; each file's header says so.
