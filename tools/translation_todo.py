#!/usr/bin/env python3
"""Write the work file for one locale: every string that still needs a translation, with context.

  python3 tools/translation_todo.py deDE --out /tmp/deDE-todo.json        missing + stale + untranslated
  python3 tools/translation_todo.py deDE --include missing                only strings with no entry
  python3 tools/translation_todo.py deDE --format markdown --out todo.md  a readable list instead
  python3 tools/translation_todo.py deDE --limit 50                       the first 50 (a batch)

Each item carries:
  id, key, english  the string to translate; the numeric id is its stable identity, the key what the code reads
                    (usually the English itself; apply the result with either)
  reason            missing | stale | same
  existing          the current translation, when there is one (stale: translated from older English)
  previous_english  for a stale entry, the English that translation was made from, so you can see what changed
  placeholders      tokens that must appear unchanged in the translation (%s, %d, {{name}}, |cAARRGGBB, |r, ...)
  area, files       where the string is used (first 3 "path:line" uses), so you can judge tone and length
  glossary          terms from docs/translators/glossary.md found in the English, with this locale's wording
  hint              a short note when length or tone matters

Fill in "translation" for each item (leave it null to skip) and apply with
tools/translation_apply.py, which validates before it writes anything. Keys are never translated.
"""
import argparse
import json
import sys

import translation_lib as T

REASONS = ('missing', 'stale', 'same')


def hint_for(english, area):
    notes = []
    words = len(english.split())
    if len(english) <= 24 and '\n' not in english:
        notes.append('Short label or button: keep it about as short as the English; it must fit its control.')
    if area == 'help text':
        notes.append('Help text: complete sentences, same register as the other help of this language (docs/translators/style.md).')
    if english.endswith(':'):
        notes.append('Ends with a colon: keep a colon in the way this language writes it.')
    if '\n' in english:
        notes.append('Contains line breaks: keep the same number of paragraphs.')
    if words >= 40:
        notes.append('Long paragraph: translate it as a whole; do not split or merge sentences.')
    return ' '.join(notes) or None


def build_items(corpus, locale, include, limit, context):
    state = corpus.classify(locale)
    chosen = {'missing': state['missing'] if 'missing' in include else [],
              'stale': state['stale'] if 'stale' in include else [],
              'same': state['suspect'] if 'same' in include else []}
    members = {reason: set(keys) for reason, keys in chosen.items()}
    ordered = [(reason, key) for key in corpus.english for reason in REASONS if key in members[reason]]
    if limit:
        ordered = ordered[:limit]
    index = T.source_index([key for _, key in ordered]) if context else {}
    glossary = T.read_glossary()
    items = []
    for reason, key in ordered:
        english = corpus.english[key]
        files = index.get(key, [])
        area = T.key_area(key, files)
        item = {'id': corpus.ids[key], 'key': key, 'english': english, 'reason': reason}
        if reason == 'stale':
            item['previous_english'] = corpus.sources[locale].get(key)
        if key in corpus.entries[locale]:
            item['existing'] = corpus.entries[locale][key]
        item.update({'placeholders': T.placeholders(english), 'area': area, 'files': files[:3],
                     'glossary': T.glossary_hits(english, locale, glossary), 'hint': hint_for(english, area),
                     'translation': None})
        items.append(item)
    return items


def markdown(locale, items):
    lines = [f'# {locale}: strings to translate ({len(items)})', '']
    for n, item in enumerate(items, 1):
        lines.append(f'## {n}. `{item["key"][:90]}`' if len(item['key']) > 90 else f'## {n}. `{item["key"]}`')
        lines.append(f'- reason: {item["reason"]}')
        lines.append('- English:')
        lines.extend('  > ' + part for part in item['english'].split('\n'))
        if item.get('previous_english') and item['previous_english'] != item['english']:
            lines.append('- translated from older English:')
            lines.extend('  > ' + part for part in item['previous_english'].split('\n'))
        if item.get('existing') is not None:
            lines.append('- current translation:')
            lines.extend('  > ' + part for part in item['existing'].split('\n'))
        if item['placeholders']:
            lines.append('- keep unchanged: ' + ' '.join(f'`{p}`' for p in item['placeholders']))
        if item['area']:
            lines.append(f'- used in: {item["area"]}' + (f' ({", ".join(item["files"])})' if item['files'] else ''))
        for hit in item['glossary']:
            lines.append(f'- glossary: {hit["term"]} -> {hit["translation"]}')
        if item['hint']:
            lines.append(f'- note: {item["hint"]}')
        lines.append('')
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('locale', choices=T.LOCALES)
    parser.add_argument('--include', default=','.join(REASONS), help='Comma list of missing, stale, same (default: all).')
    parser.add_argument('--format', choices=['json', 'markdown'], default='json')
    parser.add_argument('--limit', type=int, default=0, help='Only the first N items, in enUS file order.')
    parser.add_argument('--no-context', action='store_true', help='Skip the source-file lookup (faster).')
    parser.add_argument('--out', help='Write here instead of standard output.')
    args = parser.parse_args(argv)
    include = {part.strip() for part in args.include.split(',') if part.strip()}
    if include - set(REASONS):
        parser.error('--include takes missing, stale and same')
    corpus = T.Corpus()
    items = build_items(corpus, args.locale, include, args.limit, not args.no_context)
    text = markdown(args.locale, items) if args.format == 'markdown' else json.dumps(items, ensure_ascii=False, indent=1) + '\n'
    if args.out:
        with open(args.out, 'w', encoding='utf-8') as handle:
            handle.write(text)
        counts = {r: sum(1 for i in items if i['reason'] == r) for r in REASONS}
        print(f'{args.locale}: {len(items)} item(s) written to {args.out} ({counts["missing"]} missing, {counts["stale"]} stale, {counts["same"]} same)')
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
