#!/usr/bin/env python3
"""Validate a translated work file and merge it into the locale files of one language.

  python3 tools/translation_apply.py deDE deDE-todo.json --dry-run                   validate and show what would change
  python3 tools/translation_apply.py deDE deDE-todo.json --translator "Name"         validate, write, and credit Name

The input is the file tools/translation_todo.py wrote with "translation" filled in (items whose translation
is null or empty are skipped), or a plain JSON object {id: translation} (an id or the English key). Nothing is written
unless every supplied translation passes; the write itself is tools/locales.py `build`, so the files keep their format,
their order and the "-- <hash> English:" comment above each entry (the English that entry was translated from).
--translator credits the person (or --ai a model) in the header and, for a human, on the About page of that language.

Errors (nothing is written):
  - the key is not an enUS key, or the translation is empty or not text
  - placeholders differ from the English: %s %d ..., {{name}}, {name}, |cAARRGGBB, |r, |n, \\n and line breaks,
    or the order of format specifiers changed, or a bare % appears in a formatted string
  - a color code is broken, a stray | or backslash appears, a control or zero-width character is present
  - leading/trailing whitespace or the number of line breaks differs from the English
  - the text is far longer than the English (the limit locales.py enforces)
  - the translation equals the English and is not a name (pass --allow-identical when it is correct, and
    --record-keep to remember that in tools/translation_exempt.json)

Warnings (printed, not blocking): text much longer than the English, missing end punctuation, a language's
punctuation rule (French spaces, Chinese full-width colon), and a long text with no letters of the locale's script.
"""
import argparse
import json
from pathlib import Path
import re
import sys

import translation_lib as T

L = T.L
STRAY = re.compile(r'\|(?!\||c[0-9a-fA-F]{8}|r|n|T|t|A|a)')
ZERO_WIDTH = re.compile('[\u200b\u200c\u200d\u2060\ufeff]')
CONTROL = re.compile('[\x00-\x09\x0b-\x1f\x7f]')
BACKSLASH = re.compile(r'\\(?!n)')


def stray_pipes(text):
    """Pipes that are not part of a color code, escape or {{a|b}} alternative."""
    text = L.ALTERNATIVE.sub(lambda m: '\0'.join(m.group(2).split('|')), text)
    text = L.TOKEN.sub(' ', text)
    return len(STRAY.findall(text))


def read_work(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if isinstance(data, dict):
        return {key: value for key, value in data.items() if value not in (None, '')}
    out = {}
    for number, item in enumerate(data, 1):
        if not isinstance(item, dict) or 'key' not in item:
            raise SystemExit(f'item {number}: expected an object with "key" and "translation"')
        text = item.get('translation')
        if text not in (None, ''):
            key = item['key']
            if key in out:
                raise SystemExit(f'item {number}: key appears twice: {key!r}')
            out[key] = text
    return out


def to_keys(incoming):
    """Work-file names (an id or a key) as keys; an unknown name is left for validate to reject."""
    by_id = L.by_id()
    out = {}
    for name, text in incoming.items():
        key = by_id[int(name)].key if str(name).isdigit() and int(name) in by_id else name
        if key in out:
            raise SystemExit(f'{name!r} names a string that is supplied twice')
        out[key] = text
    return out


def validate(corpus, locale, key, text, args):
    """Return (errors, warnings) for one translation."""
    errors, warnings = [], []
    english = corpus.english.get(key)
    if english is None:
        return ['not an enUS key'], warnings
    if not isinstance(text, str) or not text.strip():
        return ['empty or not text'], warnings
    errors.extend(L.problems(key, english, text))
    if CONTROL.search(text):
        errors.append('contains a control character')
    if ZERO_WIDTH.search(text):
        errors.append('contains a zero-width character or byte order mark')
    if BACKSLASH.search(text) and not BACKSLASH.search(english):
        errors.append('contains a backslash escape the English does not have')
    if stray_pipes(text) != stray_pipes(english):
        errors.append('a | that is not part of a color code, |r, |n or an alternative {{a|b}}')
    if text[:len(text) - len(text.lstrip())] != english[:len(english) - len(english.lstrip())]:
        errors.append('leading whitespace differs from the English')
    if text[len(text.rstrip()):] != english[len(english.rstrip()):]:
        errors.append('trailing whitespace differs from the English')
    if text.count('\n') != english.count('\n'):
        errors.append(f'{text.count(chr(10))} line break(s), the English has {english.count(chr(10))}')
    if text == english and corpus.identical_reason(locale, key) is None and not args.allow_identical:
        errors.append('identical to the English; if that is correct pass --allow-identical (and --record-keep)')
    if len(english) >= 8 and len(text) > args.max_ratio * len(english) and len(text) <= max(64, len(english) * 4):
        warnings.append(f'{len(text)} characters for {len(english)} in English: check it fits')
    if re.search(r'[.!?]$', english) and not re.search(r'[.!?。！？…)]$', text):
        warnings.append('the English ends a sentence and this does not')
    if locale in T.SCRIPT and len(re.sub(r'[^\W\d_]', '', strip_for_script(text))) >= 12:
        name, pattern = T.SCRIPT[locale]
        if not pattern.search(text):
            warnings.append(f'no {name} letters in a long text: is it still English?')
    if locale.startswith('zh') and re.search(r'\S:\s*$', text):
        warnings.append('Chinese uses the full-width colon "："')
    if locale == 'frFR' and re.search(r'(?<=[^\W_]|\)|\])[:;?!](?:\s|$)', text):
        warnings.append('French puts a space before : ; ? !')
    return errors, warnings


def strip_for_script(text):
    return T.strip_tokens(text)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('locale', choices=T.LOCALES)
    parser.add_argument('file', help='Work file from translation_todo.py, or a JSON object {id: translation}.')
    parser.add_argument('--translator', help='Credit this name in the header of every file written (and on the About page if human).')
    parser.add_argument('--url', help='A link or handle shown beside the name in the header.')
    kind = parser.add_mutually_exclusive_group()
    kind.add_argument('--human', action='store_const', const='human', dest='kind', help='A human translator (the default for a new name).')
    kind.add_argument('--ai', action='store_const', const='ai', dest='kind', help='An AI translator (header only).')
    parser.add_argument('--dry-run', action='store_true', help='Validate and report; write nothing.')
    parser.add_argument('--allow-identical', action='store_true', help='Accept translations equal to the English.')
    parser.add_argument('--record-keep', action='store_true', help='Remember accepted identical strings as keep_english for this locale.')
    parser.add_argument('--max-ratio', type=float, default=2.5, help='Warn when a translation is more than this many times the English length.')
    args = parser.parse_args(argv)

    incoming = to_keys(read_work(args.file))
    if not incoming:
        print('translation_apply: nothing to apply (no item has a translation)')
        return 0
    corpus = T.Corpus([args.locale])
    failures, notices = {}, {}
    for key, text in incoming.items():
        errors, warnings = validate(corpus, args.locale, key, text, args)
        if errors:
            failures[key] = errors
        if warnings:
            notices[key] = warnings
    for key, warnings in notices.items():
        print(f'warning {key[:80]!r}: ' + '; '.join(warnings))
    if failures:
        for key, errors in failures.items():
            print(f'ERROR   {key[:80]!r}: ' + '; '.join(errors), file=sys.stderr)
        print(f'translation_apply: {len(failures)} of {len(incoming)} translation(s) rejected; nothing written', file=sys.stderr)
        return 1

    before_entries, before_hashes = dict(corpus.entries[args.locale]), dict(corpus.hashes[args.locale])
    new = sum(1 for key in incoming if key not in before_entries)
    changed = sum(1 for key, text in incoming.items() if key in before_entries and before_entries[key] != text)
    same = len(incoming) - new - changed
    print(f'{args.locale}: {len(incoming)} translation(s) valid ({new} new, {changed} changed, {same} unchanged), {len(notices)} warning(s)')
    if args.dry_run:
        return 0

    # A language spans the main catalog and every text bundle, the registration files and the credits: snapshot them all
    # to put back exactly what this run replaced if the read-back disagrees.
    paths = [each.path(args.locale) for each in L.catalogs()]
    paths += [T.ROOT / 'locales.xml', T.ROOT / L.TRANSLATORS_FILE, T.ROOT / L.REGISTRY_FILE]
    paths += [L.toc_path(each) for each in L.catalogs() if not each.is_main]
    originals = {path: path.read_bytes() for path in paths if path.exists()}
    L.build(args.locale, incoming, translator=args.translator, kind=args.kind, url=args.url)

    problems = []
    after_entries, after_hashes = dict(L.locale_entries(args.locale)), L.read_hashes(args.locale)
    for key, text in incoming.items():
        if after_entries.get(key) != text:
            problems.append(f'{key[:60]!r}: not written as given')
        if after_hashes.get(key) != L.text_hash(corpus.english[key]):
            problems.append(f'{key[:60]!r}: the recorded English hash is wrong')
    for key, value in before_entries.items():
        if key not in incoming and (after_entries.get(key) != value or after_hashes.get(key) != before_hashes.get(key)):
            problems.append(f'{key[:60]!r}: an entry you did not supply changed')
    if problems:
        # Put back exactly the bytes this run replaced (our own write; no VCS command is involved).
        for path in paths:
            if path in originals:
                path.write_bytes(originals[path])
            else:
                path.unlink(missing_ok=True)
        print('translation_apply: verification failed, the previous file was restored:', file=sys.stderr)
        for problem in problems[:20]:
            print('  ' + problem, file=sys.stderr)
        return 2
    if args.allow_identical and args.record_keep:
        exempt = T.load_exempt()
        keep = exempt.setdefault('keep_english', {}).setdefault(args.locale, [])
        added = [key for key, text in incoming.items() if text == corpus.english[key] and corpus.identical_reason(args.locale, key) is None]
        keep.extend(key for key in added if key not in keep)
        if added:
            T.save_exempt(exempt)
            print(f'recorded {len(added)} identical string(s) as keep_english in tools/translation_exempt.json')
    print('Next: python3 tools/locales.py check, then test the strings in game (docs/translators/README.md)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
