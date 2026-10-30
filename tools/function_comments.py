#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Check that every non-trivial named function in the shipped Lua carries the structured header comment.

  python3 tools/function_comments.py                         list every violation in the formatter-owned shipped Lua
  python3 tools/function_comments.py FILE...                 the same, for the named files only
  python3 tools/function_comments.py --summary               counts of violations per directory instead of each one
  python3 tools/function_comments.py --baseline FILE         ignore the violations FILE lists; fail on any new one
  python3 tools/function_comments.py --write-baseline FILE   record today's violations (the ratchet's starting point)
  python3 tools/function_comments.py --strict                every named function with parameters or return values

The header (docs/dev/formatting.md, "Function headers") is a block of plain `--` lines directly above the function, no
blank line between:

    -- Brief description of what the function does, not how it does it.
    -- @param spell number|string  The spell ID or name to look up; nil is not allowed.
    -- @param unit string|nil  The unit token to check; nil means "player".
    -- @return boolean  True when the spell is known and ready.
    -- @return string|nil  The reason code when false; nil when true.
    --
    -- Longer notes, only where they help.
    function addon:IsSpellReady(spell, unit)

Files: the same set as `tools/format_lua.py --tree` (tracked, not vendored, not generated), minus `tests/`. Generated
regions (`-- BEGIN GENERATED ...`) are never read.

Which functions. NAMED functions: `function a.b:c()`, `local function f()`, `[local] name = function` and
`a.b = function` statements outside any function body, and `Name = function` table fields or forward-declared locals
assigned inside a function when they are longer than 15 code lines (shorter ones are callbacks). Anonymous functions
are never checked, nor is anything nested in a frozen Built In helper (its text is hashed: no comment may go inside).
A function is non-trivial when its body has 6 or more code lines, or when it has parameters or returns a value and its
body has more than 3 code lines (blank and comment-only lines do not count); `--strict` drops the second threshold. A
trivial function needs no header, but a header it does carry is checked like any other. A function without parameters
or return values needs only a brief comment; one with them needs the tags.

What is reported:
  missing   a non-trivial function has no structured header: no comment directly above it, a plain comment where tags
            are needed, or the comment sits behind a blank line
  brief     the header has no brief line (it opens with a tag or is empty)
  param     the `@param` names differ from the declared parameters (count, names or order); an implicit `self` of
            `function a:b()` is never listed, an explicit `self` parameter is
  return    the function returns a value and the header has fewer `@return` lines than the values returned, or the
            header has `@return` lines and the function returns nothing
  tag       a `@param`/`@return` tag without a type and a description, a tag that does not start its own line, a tag
            after the longer notes, a `@param` after a `@return`, or an unknown tag
  blank     a header with tags sits above a blank line that separates it from its function

A `---@...` LuaLS annotation line between the header and the function is allowed and ignored.

The baseline file is JSON ({"violations": {"<file>|<function>|<code>": count}}): line numbers are not part of the key,
so a baselined violation survives edits around it, and a new one (or one more of the same kind) fails.

Exit status: 0 clean (or only baselined violations), 1 violations, 2 could not run.
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import format_lua as F  # noqa: E402

ROOT = F.ROOT
TRIVIAL_ALWAYS = 3       # a function with parameters or return values needs a header above this many code lines
TRIVIAL_NEVER = 6        # any function at or above this many code lines needs one
FIELD_MIN = 16           # a `Name = function` table field is only checked from this many code lines
TAG_LINE = re.compile(r'^--\s?(@\S+)(.*)$')
TAG_ANYWHERE = re.compile(r'@(?:param|return)\b')


class Violation:
    __slots__ = ('path', 'line', 'name', 'code', 'message')

    def __init__(self, path, line, name, code, message):
        self.path, self.line, self.name, self.code, self.message = path, line, name, code, message

    def key(self):
        return '%s|%s|%s' % (self.path, self.name, self.code)

    def __str__(self):
        return '%s:%d: %s: [%s] %s' % (self.path, self.line, self.name, self.code, self.message)


# ----------------------------------------------------------------------------------------------------------------------
# Source preparation
# ----------------------------------------------------------------------------------------------------------------------

def blank_generated(src):
    """`src` with every generated region (and the binding suffix) replaced by empty lines, so line numbers hold."""
    authored, suffix = F.split_generated(src)
    src = authored + '\n' * suffix.count('\n') if suffix else src
    return F.GENERATED_REGION.sub(lambda m: '\n' * m.group(0).count('\n'), src)


def comment_lines(src):
    """(source lines, set of 1-based line numbers that hold only a comment). Block comments count line by line; a
    comment after code on the same line does not make its line a comment line."""
    lines = src.split('\n')
    only = set()
    for token in F.lex(src):
        for comment in token.lead:
            for number in range(comment.line, comment.line + comment.text.count('\n') + 1):
                only.add(number)
    return lines, only


def code_lines(lines, comment_only, first, last):
    """How many lines in [first, last] hold code (not blank, not a comment on its own line)."""
    return sum(1 for n in range(first, last + 1) if lines[n - 1].strip() and n not in comment_only)


# ----------------------------------------------------------------------------------------------------------------------
# Walking the tree
# ----------------------------------------------------------------------------------------------------------------------

def children(node):
    """Every Node reachable from `node` by one attribute (a list is flattened)."""
    for value in node.__dict__.values():
        if isinstance(value, F.Node):
            yield value
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, F.Node):
                    yield item


def body_of(func):
    """(statements, first line, last line) of a function body. A frozen Built In helper keeps its text verbatim, so the
    parser hands back no statements for it: its text between `)` and `end` is parsed again here."""
    if func.raw is None:
        statements = func.body.statements
        return statements, statements[0].line if statements else None, statements[-1].end_line if statements else None
    tokens = F.lex(func.raw)
    statements = F.Parser(tokens, func.raw, set()).block().statements
    if not statements:
        return statements, None, None
    return statements, func.line + statements[0].line - 1, func.line + statements[-1].end_line - 1


def returns_of(statements):
    """The `return` statements among `statements` that belong to the function itself, not to one nested in it."""
    found = []

    def walk(node):
        if node.kind == 'func':
            return
        if node.kind == 'return':
            found.append(node)
        for child in children(node):
            walk(child)

    for statement in statements:
        walk(statement)
    return found


def named_functions(chunk):
    """(display name, func node, first line, kind) of every named function, kind in function/local/assign/field."""
    found = []

    def target_name(node):
        if node.kind == 'name':
            return node.name
        if node.kind == 'field':
            base = target_name(node.base)
            return base + '.' + node.name if base else None
        return None

    def walk(node, depth):
        if node.kind == 'function':
            found.append((node.name, node.function, node.line, 'function'))
        elif node.kind == 'localfunction':
            found.append(('local ' + node.name, node.function, node.line, 'local'))
        elif node.kind == 'assign' and len(node.targets) == 1 and len(node.values) == 1 \
                and node.values[0].kind == 'func' and target_name(node.targets[0]) \
                and (depth == 0 or node.targets[0].kind == 'name'):
            found.append((target_name(node.targets[0]), node.values[0], node.line, 'assign' if depth == 0 else 'field'))
        elif node.kind == 'local' and depth == 0 and len(node.names) == 1 and len(node.values) == 1 \
                and node.values[0].kind == 'func':
            found.append(('local ' + node.names[0], node.values[0], node.line, 'assign'))
        elif node.kind == 'table':
            for field in node.fields:
                if field.key is not None and field.key.kind == 'atom' and field.shorthand \
                        and field.value.kind == 'func':
                    found.append((field.key.text, field.value, field.value.line, 'field'))
        for child in children(node):
            walk(child, depth + 1 if child.kind == 'func' else depth)

    walk(chunk, 0)
    return found


# ----------------------------------------------------------------------------------------------------------------------
# Headers
# ----------------------------------------------------------------------------------------------------------------------

def header_above(lines, comment_only, start):
    """(header lines, blank_gap_block): the comment block directly above line `start` (text without the indentation,
    oldest first), and, when a blank line separates the function from a comment block, that block instead."""
    n = start - 1
    block = []
    while n >= 1 and n in comment_only:
        block.append((n, lines[n - 1].strip()))
        n -= 1
    block.reverse()
    if block:
        return block, None
    if n >= 1 and not lines[n - 1].strip():
        while n >= 1 and not lines[n - 1].strip():
            n -= 1
        gap = []
        while n >= 1 and n in comment_only:
            gap.append((n, lines[n - 1].strip()))
            n -= 1
        gap.reverse()
        return [], gap
    return [], None


def split_type(rest):
    """(type, description) of the text after a tag; the type runs to the first space outside brackets."""
    rest = rest.strip()
    depth, i = 0, 0
    while i < len(rest):
        c = rest[i]
        if c in '{[(<':
            depth += 1
        elif c in '}])>':
            depth = max(0, depth - 1)
        elif c == ' ' and depth == 0:
            break
        i += 1
    return rest[:i], rest[i:].strip()


def parse_header(block):
    """Break a comment block into its parts: (brief, params, returns, problems). `params` is a list of
    (name, type, description); `returns` a list of (type, description); `problems` messages for malformed tags."""
    problems, params, returns, brief = [], [], [], []
    state = 'brief'                       # brief -> tags -> notes (a bare `--` line ends the tags)
    for number, text in block:
        if text.startswith('---'):
            continue                      # a LuaLS annotation line: not part of the header
        body = text[2:]
        body = body[1:] if body.startswith(' ') else body
        match = TAG_LINE.match(text)
        if match:
            tag, rest = match.group(1), match.group(2)
            if state == 'notes':
                problems.append('line %d: %s after the longer notes' % (number, tag))
                continue
            state = 'tags'
            if TAG_ANYWHERE.search(rest):
                problems.append('line %d: more than one tag on a line' % number)
            if tag == '@param':
                if returns:
                    problems.append('line %d: @param after @return' % number)
                parts = rest.strip().split(None, 1)
                if not parts:
                    problems.append('line %d: @param without a name, type and description' % number)
                    continue
                kind, description = split_type(parts[1]) if len(parts) > 1 else ('', '')
                if not kind or not description:
                    problems.append('line %d: @param %s lacks a type or a description' % (number, parts[0]))
                params.append((parts[0], kind, description))
            elif tag == '@return':
                kind, description = split_type(rest)
                if not kind or not description:
                    problems.append('line %d: @return lacks a type or a description' % number)
                returns.append((kind, description))
            else:
                problems.append('line %d: unknown tag %s' % (number, tag))
            continue
        if TAG_ANYWHERE.search(body):
            problems.append('line %d: a tag must start its own line' % number)
        if not body.strip():
            if brief or state == 'tags':
                state = 'notes'
        elif state == 'brief':
            brief.append(body.strip())
        # In the tags state a wrapped line continues the tag above it; in the notes state it is free text.
    return ' '.join(brief), params, returns, problems


def declared(func):
    """The parameter names a header must list: all of them. A `function a:b()` method has no `self` in the parser's
    list (it is implicit); an explicit `self` parameter of any other function is listed like any other."""
    return list(func.params)


def check_function(path, lines, comment_only, name, func, start, kind, strict=False):
    """The violations of one named function (`strict`: parameters or return values always need the tags)."""
    out = []

    def bad(code, message):
        out.append(Violation(path, start, name, code, message))

    statements, first, last = body_of(func)
    body = code_lines(lines, comment_only, first, last) if statements else 0
    if kind == 'field' and body < FIELD_MIN:
        return out
    values = max([len(r.values) for r in returns_of(statements)] + [0])
    params = declared(func)
    nontrivial = body >= TRIVIAL_NEVER or (bool(params or values) and (strict or body > TRIVIAL_ALWAYS))
    block, gap = header_above(lines, comment_only, start)
    if not block:
        if gap and any(TAG_ANYWHERE.search(text) for _, text in gap):
            bad('blank', 'the header at line %d is separated from the function by a blank line' % gap[0][0])
        elif nontrivial:
            bad('missing', 'no structured header comment'
                + (' (the comment above sits behind a blank line)' if gap else ''))
        return out
    brief, doc_params, doc_returns, problems = parse_header(block)
    has_tags = bool(doc_params or doc_returns)
    if not has_tags and not problems and (params or values) and nontrivial:
        bad('missing', 'the comment above has no @param/@return lines')
        return out
    for problem in problems:
        bad('tag', problem)
    if not brief and (nontrivial or has_tags):
        bad('brief', 'the header has no brief line')
    if nontrivial or has_tags:
        names = [p[0] for p in doc_params]
        if names != params:
            bad('param', 'documented parameters (%s) differ from declared (%s)' % (', '.join(names) or 'none',
                                                                                  ', '.join(params) or 'none'))
        if values and len(doc_returns) < values:
            bad('return', 'the function returns %d value(s) but the header has %d @return line(s)'
                % (values, len(doc_returns)))
        elif not values and doc_returns:
            bad('return', 'the header documents a return value but the function returns none')
    return out


def check_source(path, src, frozen=None, strict=False):
    """All the violations in the text of one file. `frozen` are the Built In helper bodies recorded for the file (by
    default read from Data/builtin_sources.lua): they are checked as a whole, the functions inside them are not."""
    src = blank_generated(src)
    lines, comment_only = comment_lines(src)
    if frozen is None:
        frozen = F.frozen_codes(path)
    try:
        tokens = F.lex(src)
        chunk = F.Parser(tokens, src, frozen).block()
    except F.FormatError as error:
        return [Violation(path, 1, '<file>', 'parse', 'could not read the file: %s' % error)]
    out = []
    for name, func, start, kind in named_functions(chunk):
        out.extend(check_function(path, lines, comment_only, name, func, start, kind, strict))
    return out


# ----------------------------------------------------------------------------------------------------------------------
# Files, baseline and reporting
# ----------------------------------------------------------------------------------------------------------------------

def tree_files():
    """The formatter's tree, minus the test sources."""
    out = []
    for absolute in F.tree_files():
        relative = str(Path(absolute).relative_to(ROOT))
        if not relative.startswith('tests/'):
            out.append(relative)
    return sorted(out)


def check_files(relatives, strict=False):
    """The violations of the named files (repository-relative paths)."""
    found = []
    for relative in relatives:
        text = (ROOT / relative).read_text(encoding='utf-8')
        found.extend(check_source(relative, text, strict=strict))
    return found


def new_violations(found, baseline):
    """(violations the baseline does not cover, how many baselined entries no longer occur). The baseline maps a key to
    how many violations of it are allowed; the second number says the baseline can shrink."""
    allowed = Counter(baseline)
    fresh = []
    for violation in found:
        if allowed[violation.key()] > 0:
            allowed[violation.key()] -= 1
        else:
            fresh.append(violation)
    return fresh, sum(allowed.values())


def load_baseline(path):
    """The allowed violations of a baseline file: a map from violation key to how many of it are allowed."""
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    return data.get('violations', {})


def write_baseline(path, found):
    """Records the violations in `found` as a baseline file."""
    counts = Counter(v.key() for v in found)
    Path(path).write_text(json.dumps({'violations': dict(sorted(counts.items()))}, indent=1) + '\n', encoding='utf-8')


def summarize(found):
    """Lines with the number of violations per top-level directory, most first."""
    counts = Counter(v.path.split('/')[0] if '/' in v.path else '.' for v in found)
    return ['%5d  %s' % (n, d) for d, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]


def relative_names(files):
    """The repository-relative form of the paths given on the command line."""
    out = []
    for name in files:
        path = Path(name).resolve()
        out.append(str(path.relative_to(ROOT)))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('files', nargs='*', help='files to check; none means the whole formatter tree')
    parser.add_argument('--check', action='store_true', help='list the violations (the default action)')
    parser.add_argument('--strict', action='store_true',
                        help='treat every named function with parameters or return values as non-trivial')
    parser.add_argument('--summary', action='store_true', help='print counts per directory instead of each violation')
    parser.add_argument('--baseline', metavar='FILE', help='violations listed in FILE do not fail')
    parser.add_argument('--write-baseline', metavar='FILE', help='write the current violations to FILE and exit 0')
    args = parser.parse_args(argv)
    try:
        targets = relative_names(args.files) if args.files else tree_files()
        found = check_files(targets, args.strict)
    except (OSError, F.FormatError, ValueError) as error:
        print('function_comments: %s' % error, file=sys.stderr)
        return 2
    if args.write_baseline:
        write_baseline(args.write_baseline, found)
        print('wrote %d violation(s) to %s' % (len(found), args.write_baseline))
        return 0
    fresh, stale = found, 0
    if args.baseline:
        fresh, stale = new_violations(found, load_baseline(args.baseline))
    if args.summary:
        for row in summarize(fresh):
            print(row)
        print('%5d  total (%d baselined)' % (len(fresh), len(found) - len(fresh)))
    else:
        for violation in fresh:
            print(violation)
        if fresh:
            print('%d function comment violation(s)' % len(fresh), file=sys.stderr)
    if stale:
        print('%d baselined violation(s) no longer occur: rewrite the baseline with --write-baseline' % stale,
              file=sys.stderr)
    return 1 if fresh else 0


if __name__ == '__main__':
    sys.exit(main())
