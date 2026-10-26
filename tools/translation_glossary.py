#!/usr/bin/env python3
"""Write docs/translators/glossary.md: the wording each locale already uses for the addon's recurring terms.

  python3 tools/translation_glossary.py            print the glossary
  python3 tools/translation_glossary.py --write    update docs/translators/glossary.md

The wording is read from the current locale files (exact one-word entries such as "Rotation" or "Switch",
or a counted string such as "Priority %s" with its placeholder removed), so it records what is used, not
what ought to be. Change the wording by changing the locale files and regenerating. tools/translation_todo.py
reads this file to put the matching term beside each string it hands a translator.
"""
import argparse
import re
import sys

import translation_lib as T

# (term shown in the glossary, enUS key whose translation is the term, note)
CORE = [
    ('Rotation', 'Rotation', 'The ordered priority list the addon advises from. Plural: Rotations.'),
    ('Rotations', 'Rotations', ''),
    ('Step', 'Step %d', 'One entry in a rotation: an action, Branch or Stop. Taken from "Step %d".'),
    ('Steps', 'Steps', ''),
    ('Condition', 'Condition', 'A test (health below 30%, spell ready, ...). Plural: Conditions.'),
    ('Conditions', 'Conditions', ''),
    ('Switch', 'Switch', 'The condition that decides when a rotation is selected automatically; not the verb.'),
    ('Built In', 'Built In', 'A premade rotation shipped with the addon; read-only, can be cloned.'),
    ('Priority', 'Priority %s', 'Higher is tried first. Taken from "Priority %s".'),
    ('Specialization', 'Specialization', 'Follow the game client: talent specialization.'),
    ('Cooldown', 'Cooldown', 'Follow the game client; also names the rotation section that runs on its own.'),
    ('Cooldowns', 'Cooldowns', ''),
    ('Stop', 'Stop', 'A step type: end the pass when its condition holds.'),
    ('Branch', 'Branch', 'A step type: an If / Else split.'),
    ('Action', 'Action', ''),
    ('Spell', 'Spell', 'Follow the game client.'),
    ('Item', 'Item', 'Follow the game client.'),
    ('Talent', 'Talent', 'Follow the game client.'),
    ('Target', 'Target', 'Follow the game client.'),
    ('Pet', 'Pet', 'Follow the game client.'),
    ('Class', 'Class', 'Follow the game client.'),
    ('Level', 'Level', 'Follow the game client.'),
    ('Health', 'Health', 'Follow the game client.'),
    ('Mana', 'Mana', 'Follow the game client.'),
    ('Combat', 'Combat', 'Follow the game client.'),
    ('Channel', 'Channel', 'Spell channeling in this addon (not a chat channel in the combat-log sense).'),
    ('Stacks', 'Stacks', 'Aura stacks.'),
    ('Unit', 'Unit', 'A game unit token: player, target, focus, ...'),
    ('Identifier', 'Identifier', 'Short name used with /rm set. Never "Handle".'),
    ('Tags', 'Tags', 'Labels on a rotation.'),
    ('Function', 'Function', 'A named reusable Lua function.'),
    ('Functions', 'Functions', ''),
    ('Effect', 'Effect', 'A highlight effect.'),
    ('Effects', 'Effects', ''),
    ('Item Set', 'Item Set', 'An ordered list of items the addon treats as one button.'),
    ('Item Sets', 'Item Sets', ''),
    ('Announce', 'Announce', 'Chat or sound output when something happens.'),
    ('Default', 'Default', 'The fallback rotation / default value.'),
    ('Fallback', 'Fallback', 'The rotation used when no other can be selected.'),
    ('Custom', 'Custom', 'User-made, as opposed to Built In.'),
    ('Unavailable', 'Unavailable', 'A condition that cannot be evaluated right now.'),
    ('Preview', 'Preview', ''),
    ('Import', 'Import', ''),
    ('Copy', 'Copy', ''),
    ('Duplicate', 'Duplicate', ''),
    ('Undo', 'Undo', ''),
    ('Redo', 'Redo', ''),
    ('Apply', 'Apply', ''),
    ('Cancel', 'Cancel', ''),
    ('Discard', 'Discard', 'Throw away unsaved edits.'),
    ('Delete', 'Delete', ''),
    ('Add', 'Add', ''),
    ('Edit', 'Edit', ''),
    ('Reset', 'Reset', ''),
    ('Compare', 'Compare', ''),
    ('Check', 'Check', ''),
    ('Search', 'Search', ''),
    ('General', 'General', ''),
    ('Enable', 'Enable', ''),
    ('Disable', 'Disable', ''),
    ('Enabled', 'Enabled', ''),
    ('Disabled', 'Disabled', ''),
    ('Minimum', 'Minimum', ''),
    ('Maximum', 'Maximum', ''),
    ('Description', 'Description', ''),
    ('Name', 'Name', ''),
    ('Scale', 'Scale', ''),
    ('Any', 'Any', ''),
    ('All', 'All', ''),
    ('Always', 'Always', ''),
    ('None', 'None', ''),
    ('Yes', 'Yes', ''),
    ('No', 'No', ''),
    ('AND', 'AND', 'Logic operators stay short and capitalized where the language allows.'),
    ('OR', 'OR', ''),
    ('NOT', 'NOT', ''),
]
# Terms that exist only inside longer strings: (term, an enUS key that contains it, note).
IN_CONTEXT = [
    ('Buff', 'Buff Present', 'Use the client\'s word for a beneficial aura.'),
    ('Debuff', 'Debuff Present', 'Use the client\'s word for a harmful aura.'),
    ('Own', 'Own Buff', 'Cast by the player.'),
    ('Clone', 'Clone to edit', 'Make an editable copy of a Built In.'),
    ('Remove', 'Remove condition', ''),
    ('Export', 'Export archive', ''),
    ('Profile', 'Profile archive', 'The saved-variables profile.'),
    ('Announcement', 'Announcement', ''),
    ('Switch priority', 'Switch priority', ''),
    ('Switch condition', 'Switch condition', ''),
]
LOCALE_NAMES = {'deDE': 'German', 'esES': 'Spanish (Spain)', 'esMX': 'Spanish (Latin America)', 'frFR': 'French',
                'itIT': 'Italian', 'koKR': 'Korean', 'ptBR': 'Portuguese (Brazil)', 'ruRU': 'Russian',
                'zhCN': 'Chinese (Simplified)', 'zhTW': 'Chinese (Traditional)'}


def term_text(value, key):
    """The translated term: the entry itself, or the counted string without its placeholder and punctuation."""
    if key.endswith(('%s', '%d')):
        value = re.sub(r'\s*%[sd]\s*', ' ', value)
    return value.strip(' :：')


def row(corpus, term, key):
    cells = []
    for locale in T.LOCALES:
        value = corpus.entries[locale].get(key)
        cells.append(term_text(value, key) if value else '-')
    return cells


def render(corpus):
    out = ['# Translation glossary', '',
           'The wording each locale already uses for the addon\'s recurring terms, read from the locale files by '
           '`python3 tools/translation_glossary.py --write`. Use the same word for the same thing: a player sees '
           '"Switch" in a menu, a tooltip and a help paragraph, and they must match. When a locale changes its wording, '
           'change it everywhere and regenerate this file. Game vocabulary (spells, classes, specializations, stats, '
           'zones) follows the game client\'s own translation, not this table.', '',
           '`-` means no short entry exists in that locale yet. Columns: ' +
           ', '.join(f'{code} {name}' for code, name in LOCALE_NAMES.items()) + '.', '',
           '## Core terms', '', '| Term | ' + ' | '.join(T.LOCALES) + ' | Note |', '|' + '---|' * (len(T.LOCALES) + 2)]
    for term, key, note in CORE:
        out.append('| ' + ' | '.join([term] + row(corpus, term, key) + [note]) + ' |')
    out += ['', '## Terms found inside longer strings', '',
            'These words have no entry of their own. The example string shows how each locale renders the term in context.', '',
            '| Term | Example | ' + ' | '.join(T.LOCALES) + ' | Note |', '|' + '---|' * (len(T.LOCALES) + 3)]
    for term, key, note in IN_CONTEXT:
        out.append('| ' + ' | '.join([term, f'`{key}`'] + row(corpus, term, key) + [note]) + ' |')
    names = sorted(corpus.exempt.get('names', []), key=str.lower)
    out += ['', '## Never translated', '',
            'Product, site and addon names; slash commands and their arguments (`/rm set`, `/rm debug glow`); '
            'condition and field identifiers inside `{{braces}}`; format placeholders (`%s`, `%d`); color codes (`|cffffd100...|r`); '
            'the word "Rotation Master". Names the tools never flag as untranslated:', '',
            ', '.join(names) + '.', '']
    return '\n'.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args(argv)
    corpus = T.Corpus()
    text = render(corpus)
    if args.write:
        T.GLOSSARY_PATH.parent.mkdir(parents=True, exist_ok=True)
        T.GLOSSARY_PATH.write_text(text, encoding='utf-8')
        print(f'wrote {T.GLOSSARY_PATH.relative_to(T.ROOT)}')
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
