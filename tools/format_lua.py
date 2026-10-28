#!/usr/bin/env python3
"""Reformat Lua 5.1 source for readability without changing what it compiles to.

  python3 tools/format_lua.py UI/foo.lua              print what would change (a unified diff), write nothing
  python3 tools/format_lua.py --write UI/foo.lua      rewrite the file, after proving it compiles identically
  python3 tools/format_lua.py --write --stdout F      print the formatted text instead of writing it
  python3 tools/format_lua.py --check F...            list the files whose layout differs (exit 1), write nothing
  python3 tools/format_lua.py --tree [--write|--check]   every file the formatter owns: all tracked Lua except Libs/,
                                                      LibsAugment/, Locales/, Assets/, Modules/, tools/vendor/, generated
                                                      files and the test sources other tests read as text

The layout it produces: one statement per line, four-space indentation, lines wrapped at 120 columns at argument, field
and and/or boundaries, and a function that is the last argument of a call hugging that call (`foo(a, function()` ...
`end)`). Comments are kept in place; a comment inside an expression moves to the line above its statement. Strings,
numbers and parentheses are never touched.

Blocks are never written on one line. Every `if`, `elseif`, `else`, `for`, `while`, `repeat`, `do` and named `function`
body goes on its own indented lines, so `if x then return end` becomes `if x then` / `return` / `end`; so does a body
the author wrote after a `;` (`if x then a(); b() end`). The one exception is an anonymous function whose whole body is
a single `return`, which the author wrote on one line and which fits: `function(a) return a.x end` stays inline wherever
it appears (a call argument, a table field, the right side of an assignment). An empty body stays on the head's line
(`function addon:Noop() end`). A comment the author put after a one-line statement (`if x then y end -- note`) moves to the
statement's first line (`if x then -- note`).

Blank lines. A blank line surrounds every statement that spans several lines (blocks, long calls and tables), the author's
own blank lines are kept, and statements are never stacked more than one blank line apart. A guard clause is an `if` with
one condition, no `else` and a body of one plain statement (`return`, `break`, a call, an assignment or a `local`); two
guard clauses in a row whose bodies are the same kind of statement are written without a blank line between them, so a
run of six `if ... then return end` guards is eighteen tight lines.

Safety. Before a file is written, both the original and the result are compiled with `luac5.1 -s` (debug information,
line numbers and comments stripped) and the two bytecode images must be identical, which means the result is the same
program. The comment texts must also match one for one. A file that fails either check is left alone.

Frozen function bodies. Saved custom conditions and exported bundles bind to the source text of the Built In helper
functions listed in `Data/builtin_sources.lua`, so the text between a helper's parameter list and its `end` must stay
byte for byte. For a file that has such helpers the formatter reads their first lines from that catalog (through lua5.1)
and prints those bodies verbatim; only the line around them is reformatted. The generated binding suffix at the end of a
Conditions file is never touched either.

Exit status: 0 formatted or already formatted, 1 a file was refused (it did not compile identically) or, with --check, is
not laid out as the formatter would, 2 could not run.
"""
import argparse
import difflib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIDTH = 120
INDENT = 4
GENERATED_BEGIN = '-- BEGIN GENERATED RM SOURCE BINDINGS'

# Files the formatter never touches when it walks the tree (--tree).
EXEMPT_PREFIXES = ('Libs/', 'LibsAugment/', 'Locales/', 'Assets/', 'Modules/', 'tools/vendor/')
EXEMPT_FILES = {
    # Written by a generator.
    'Data/artwork.lua', 'Data/builtin_sources.lua', 'Data/talent_trees.lua', 'Data/text_bundle_index.lua',
    'tests/fixtures/client_api.lua', 'tests/fixtures/client_api_era.lua', 'tests/fixtures/client_api_forever.lua',
    'tests/fixtures/client_api_mists.lua', 'tests/fixtures/client_api_retail.lua', 'tests/fixtures/client_api_tbc.lua',
    # Golden files and snapshots of earlier source: their text is the point.
    'tests/fixtures/legacy_rotation_exports.lua', 'tests/fixtures/premade_spec_switches.lua',
    'tests/fixtures/restore_final_composition.lua', 'tests/fixtures/restore_runtime_plan_runner.lua',
    'tests/fixtures/removed_builtin_clones.lua', 'tests/fixtures/retail_traits.lua',
}
# Test sources that other tests read as text and cut up with string patterns or fixed anchors (tests/startup.lua,
# tests/fixtures/addon.lua, ...). They keep the dense layout their anchors were written against.
READ_AS_TEXT_BY_TESTS = {
    'tests/acquisition_proof_consolidation.lua',
    'tests/active_runtime_main.lua',
    'tests/active_runtime_plan.lua',
    'tests/analytics_capture_controls.lua',
    'tests/announcement_conditions_events.lua',
    'tests/announcement_macros.lua',
    'tests/announcement_series_runtime.lua',
    'tests/announcement_series_ui.lua',
    'tests/aura_namespaces.lua',
    'tests/buttons_namespaces.lua',
    'tests/cache_mode_lifecycle.lua',
    'tests/casting_conditions.lua',
    'tests/condition_editor_ui.lua',
    'tests/condition_runtime.lua',
    'tests/condition_subject_help.lua',
    'tests/cpu.lua',
    'tests/cpu_native_probe.lua',
    'tests/cpu_runtime.lua',
    'tests/custom_authoring_ui.lua',
    'tests/fixtures/addon.lua',
    'tests/fixtures/rotation_execution.lua',
    'tests/fixtures/shaman_starter_pack.lua',
    'tests/function_data.lua',
    'tests/functions_ui.lua',
    'tests/legacy_regressions.lua',
    'tests/masque_preview.lua',
    'tests/masque_skin_selection.lua',
    'tests/memory_boundary_refresh.lua',
    'tests/nameplate_lifecycle.lua',
    'tests/platform_analytics_casts.lua',
    'tests/point_tbc_transport.lua',
    'tests/rotation_editor_ui.lua',
    'tests/rotation_import.lua',
    'tests/rotation_scope_browser_ui.lua',
    'tests/rotation_scope_runtime.lua',
    'tests/rotation_scope_transport.lua',
    'tests/rotation_scope_workspace.lua',
    'tests/rotation_store_reader.lua',
    'tests/rotation_validation_adjacent.lua',
    'tests/rotation_workspace.lua',
    'tests/runtime_store_native_gate.lua',
    'tests/schema_repair.lua',
    'tests/settings_pages.lua',
    'tests/spell_history_count.lua',
    'tests/spell_search_ui.lua',
    'tests/startup.lua',
    'tests/transfer_subject_help.lua',
    'tests/workbench_reflow.lua',
    'tests/zone_text_conditions.lua',
}

KEYWORDS = {'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not',
            'or', 'repeat', 'return', 'then', 'true', 'until', 'while'}
# Left and right binding power of every binary operator, as in the reference compiler (lparser.c).
BINARY = {'+': (6, 6), '-': (6, 6), '*': (7, 7), '/': (7, 7), '%': (7, 7), '^': (10, 9), '..': (5, 4),
          '==': (3, 3), '~=': (3, 3), '<': (3, 3), '<=': (3, 3), '>': (3, 3), '>=': (3, 3), 'and': (2, 2), 'or': (1, 1)}
UNARY_PRIORITY = 8
RIGHT_ASSOCIATIVE = {'..', '^'}


class FormatError(Exception):
    pass


# ----------------------------------------------------------------------------------------------------------------------
# Lexer
# ----------------------------------------------------------------------------------------------------------------------

class Comment:
    __slots__ = ('text', 'block', 'line', 'blank_before')

    def __init__(self, text, block, line, blank_before):
        self.text, self.block, self.line, self.blank_before = text, block, line, blank_before


class Tok:
    """A token with the comments around it. `lead` are the comments on their own lines before it, `trail` the ones on the
    same line after it; the parser claims them for the statement or list item they belong to."""
    __slots__ = ('kind', 'text', 'line', 'end_line', 'start', 'end', 'lead', 'trail', 'blank_before', 'newline_before')

    def __init__(self, kind, text, line, end_line, start, end):
        self.kind, self.text, self.line, self.end_line, self.start, self.end = kind, text, line, end_line, start, end
        self.lead, self.trail, self.blank_before, self.newline_before = [], [], False, False


NAME = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
NUMBER = re.compile(r'0[xX][0-9a-fA-F]*(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?[0-9]+)?[A-Za-z_]*'
                    r'|(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?[A-Za-z_]*')
LONG_OPEN = re.compile(r'\[(=*)\[')
BLOCK_COMMENT_OPEN = re.compile(r'--\[(=*)\[')


def lex(src):
    """Tokens (with comments attached) of a Lua chunk, ending with an 'eof' token."""
    items, pos, line, n = [], 0, 1, len(src)
    previous_end, previous_line = 0, 1
    while True:
        gap_start = pos
        while pos < n and src[pos] in ' \t\r\n\f\v':
            pos += 1
        gap = src[gap_start:pos]
        line += gap.count('\n')
        newlines = gap.count('\n')
        if pos >= n:
            token = Tok('eof', '', line, line, pos, pos)
            token.blank_before = newlines >= 2
            token.newline_before = newlines >= 1
            items.append(('tok', token))
            break
        start, start_line = pos, line
        blank, newline = newlines >= 2, newlines >= 1
        ch = src[pos]
        if src.startswith('--', pos):
            match = BLOCK_COMMENT_OPEN.match(src, pos)
            if match:
                close = ']' + match.group(1) + ']'
                stop = src.find(close, match.end())
                if stop < 0:
                    raise FormatError('unterminated block comment at line %d' % line)
                pos = stop + len(close)
                text, block = src[start:pos], True
            else:
                stop = src.find('\n', pos)
                pos = n if stop < 0 else stop
                text, block = src[start:pos].rstrip(' \t\r'), False
            line += src.count('\n', start, pos)
            items.append(('com', Comment(text, block, start_line, blank), newline))
            continue
        if ch in '\'"':
            pos += 1
            while True:
                if pos >= n or src[pos] == '\n':
                    raise FormatError('unterminated string at line %d' % line)
                if src[pos] == '\\':
                    pos += 2
                    continue
                if src[pos] == ch:
                    pos += 1
                    break
                pos += 1
            kind = 'str'
        elif ch == '[' and LONG_OPEN.match(src, pos):
            equals = LONG_OPEN.match(src, pos).group(1)
            close = ']' + equals + ']'
            stop = src.find(close, pos + len(equals) + 2)
            if stop < 0:
                raise FormatError('unterminated long string at line %d' % line)
            pos = stop + len(close)
            kind = 'str'
        elif ch.isdigit() or (ch == '.' and pos + 1 < n and src[pos + 1].isdigit()):
            pos = NUMBER.match(src, pos).end()
            kind = 'num'
        elif ch.isalpha() or ch == '_':
            pos = NAME.match(src, pos).end()
            kind = 'kw' if src[start:pos] in KEYWORDS else 'name'
        else:
            kind = 'op'
            if src.startswith('...', pos):
                pos += 3
            elif src[pos:pos + 2] in ('..', '==', '~=', '<=', '>='):
                pos += 2
            elif ch in '+-*/%^#<>=(){}[];:,.':
                pos += 1
            else:
                raise FormatError('unexpected character %r at line %d' % (ch, line))
        text = src[start:pos]
        line += text.count('\n')
        token = Tok(kind, text, start_line, line, start, pos)
        token.blank_before, token.newline_before = blank, newline
        items.append(('tok', token))

    tokens, pending, last = [], [], None
    for item in items:
        if item[0] == 'com':
            comment, newline = item[1], item[2]
            if last is not None and not newline and not pending:
                last.trail.append(comment)
            else:
                pending.append(comment)
        else:
            token = item[1]
            token.lead, pending = pending, []
            tokens.append(token)
            last = token
    return tokens


# ----------------------------------------------------------------------------------------------------------------------
# Parser: Lua 5.1 into a tree that remembers its comments
# ----------------------------------------------------------------------------------------------------------------------

class Node:
    def __init__(self, kind, **fields):
        self.kind = kind
        self.__dict__.update(fields)


class Parser:
    def __init__(self, tokens, src, frozen_codes):
        self.tokens, self.src, self.i = tokens, src, 0
        self.frozen_codes = frozen_codes

    # -- token helpers -----------------------------------------------------------------------------------------------

    @property
    def cur(self):
        return self.tokens[self.i]

    def error(self, message):
        raise FormatError('%s at line %d near %r' % (message, self.cur.line, self.cur.text))

    def is_op(self, text):
        token = self.cur
        return token.kind == 'op' and token.text == text

    def is_kw(self, text):
        token = self.cur
        return token.kind == 'kw' and token.text == text

    def advance(self):
        token = self.tokens[self.i]
        if token.kind != 'eof':
            self.i += 1
        return token

    def expect_op(self, text):
        if not self.is_op(text):
            self.error('expected %r' % text)
        return self.advance()

    def expect_kw(self, text):
        if not self.is_kw(text):
            self.error('expected %r' % text)
        return self.advance()

    def expect_name(self):
        if self.cur.kind != 'name':
            self.error('expected a name')
        return self.advance().text

    def claim_lead(self, token):
        lead, token.lead = token.lead, []
        return lead

    def claim_trail(self, token):
        trail, token.trail = token.trail, []
        return trail

    # -- blocks and statements ---------------------------------------------------------------------------------------

    def block(self):
        statements = []
        while True:
            token = self.cur
            if token.kind == 'eof' or (token.kind == 'kw' and token.text in ('end', 'else', 'elseif', 'until')):
                break
            statements.append(self.statement())
            if statements[-1].kind in ('return',):
                break
        token = self.cur
        closing = self.claim_lead(token)
        gap = token.blank_before
        return Node('block', statements=statements, closing=closing, closing_gap=gap, closing_blank=(closing[0].blank_before if closing else False))

    def statement(self):
        first = self.cur
        lead = self.claim_lead(first)
        blank = lead[0].blank_before if lead else first.blank_before
        lead_gap = first.blank_before if lead else False
        start = self.i
        node = self.simple_statement()
        node.first_text = first.text
        node.line, node.end_line = first.line, self.tokens[self.i - 1].end_line
        last_token = self.tokens[self.i - 1]
        trail = self.claim_trail(last_token)
        if self.is_op(';'):
            semicolon = self.advance()
            trail = trail + self.claim_trail(semicolon)
        if trail and node.line == node.end_line and node.kind in ('if', 'while', 'numfor', 'genfor', 'do', 'repeat'):
            # `if x then y end -- note` is split over lines: the note goes on the first one.
            head = node.clauses[0] if node.kind == 'if' else node
            head.head_trail = head.head_trail + trail
            trail = []
        node.lead, node.blank_before, node.lead_gap, node.trail = lead, blank, lead_gap, trail
        node.start_index, node.stop_index = start, self.i
        # Comments nobody claimed (inside an expression, between an operator and its operand, ...) are moved above the
        # statement so that none is lost.
        hoisted = []
        for token in self.tokens[start:self.i]:
            if token.lead:
                hoisted.extend(token.lead)
                token.lead = []
            if token.trail and token is not last_token:
                hoisted.extend(token.trail)
                token.trail = []
        node.hoisted = hoisted
        return node

    def simple_statement(self):
        token = self.cur
        if token.kind == 'kw':
            word = token.text
            if word == 'if':
                return self.if_statement()
            if word == 'while':
                self.advance()
                cond = self.expr()
                head_trail = self.claim_trail(self.expect_kw('do'))
                body = self.block()
                self.expect_kw('end')
                return Node('while', cond=cond, head_trail=head_trail, body=body)
            if word == 'do':
                head_trail = self.claim_trail(self.advance())
                body = self.block()
                self.expect_kw('end')
                return Node('do', head_trail=head_trail, body=body)
            if word == 'for':
                return self.for_statement()
            if word == 'repeat':
                head_trail = self.claim_trail(self.advance())
                body = self.block()
                self.expect_kw('until')
                cond = self.expr()
                return Node('repeat', head_trail=head_trail, body=body, cond=cond)
            if word == 'function':
                return self.function_statement()
            if word == 'local':
                return self.local_statement()
            if word == 'return':
                self.advance()
                values = []
                nxt = self.cur
                if not (nxt.kind == 'eof' or (nxt.kind == 'kw' and nxt.text in ('end', 'else', 'elseif', 'until'))
                        or (nxt.kind == 'op' and nxt.text == ';')):
                    values = self.expr_list()
                return Node('return', values=values)
            if word == 'break':
                self.advance()
                return Node('break')
        return self.expression_statement()

    def if_statement(self):
        self.expect_kw('if')
        clauses = []
        cond = self.expr()
        head_trail = self.claim_trail(self.expect_kw('then'))
        body = self.block()
        clauses.append(Node('clause', cond=cond, head_trail=head_trail, body=body))
        else_clause = None
        while True:
            if self.is_kw('elseif'):
                self.advance()
                cond = self.expr()
                head_trail = self.claim_trail(self.expect_kw('then'))
                body = self.block()
                clauses.append(Node('clause', cond=cond, head_trail=head_trail, body=body))
            elif self.is_kw('else'):
                head_trail = self.claim_trail(self.advance())
                body = self.block()
                else_clause = Node('clause', cond=None, head_trail=head_trail, body=body)
            else:
                break
        self.expect_kw('end')
        return Node('if', clauses=clauses, else_clause=else_clause)

    def for_statement(self):
        self.expect_kw('for')
        first = self.expect_name()
        if self.is_op('='):
            self.advance()
            start = self.expr()
            self.expect_op(',')
            stop = self.expr()
            step = None
            if self.is_op(','):
                self.advance()
                step = self.expr()
            head_trail = self.claim_trail(self.expect_kw('do'))
            body = self.block()
            self.expect_kw('end')
            return Node('numfor', var=first, start=start, stop=stop, step=step, head_trail=head_trail, body=body)
        names = [first]
        while self.is_op(','):
            self.advance()
            names.append(self.expect_name())
        self.expect_kw('in')
        values = self.expr_list()
        head_trail = self.claim_trail(self.expect_kw('do'))
        body = self.block()
        self.expect_kw('end')
        return Node('genfor', names=names, values=values, head_trail=head_trail, body=body)

    def function_statement(self):
        function_token = self.expect_kw('function')
        target = Node('name', name=self.expect_name())
        method = None
        parts = [target.name]
        while self.is_op('.'):
            self.advance()
            parts.append(self.expect_name())
        if self.is_op(':'):
            self.advance()
            method = self.expect_name()
        name = '.'.join(parts) + (':' + method if method else '')
        function = self.function_body(function_token)
        return Node('function', name=name, function=function)

    def local_statement(self):
        self.expect_kw('local')
        if self.is_kw('function'):
            function_token = self.advance()
            name = self.expect_name()
            function = self.function_body(function_token)
            return Node('localfunction', name=name, function=function)
        names = [self.expect_name()]
        while self.is_op(','):
            self.advance()
            names.append(self.expect_name())
        values = []
        if self.is_op('='):
            self.advance()
            values = self.expr_list()
        return Node('local', names=names, values=values)

    def expression_statement(self):
        first = self.suffixed_expression()
        if self.is_op('=') or self.is_op(','):
            targets = [first]
            while self.is_op(','):
                self.advance()
                targets.append(self.suffixed_expression())
            self.expect_op('=')
            values = self.expr_list()
            for target in targets:
                if target.kind not in ('name', 'index', 'field'):
                    self.error('cannot assign to this expression')
            return Node('assign', targets=targets, values=values)
        if first.kind not in ('call', 'method'):
            self.error('syntax error')
        return Node('callstat', call=first)

    # -- expressions -------------------------------------------------------------------------------------------------

    def expr_list(self):
        values = [self.expr()]
        while self.is_op(','):
            self.advance()
            values.append(self.expr())
        return values

    def expr(self, limit=0):
        token = self.cur
        if (token.kind == 'kw' and token.text == 'not') or (token.kind == 'op' and token.text in ('-', '#')):
            self.advance()
            left = Node('unop', op=token.text, operand=self.expr(UNARY_PRIORITY))
        else:
            left = self.simple_expression()
        while True:
            token = self.cur
            op = token.text if token.kind in ('op', 'kw') else None
            if op not in BINARY or BINARY[op][0] <= limit:
                break
            self.advance()
            right = self.expr(BINARY[op][1])
            left = Node('binop', op=op, left=left, right=right)
        return left

    def simple_expression(self):
        token = self.cur
        kind, text = token.kind, token.text
        if kind == 'num':
            self.advance()
            return Node('atom', text=text)
        if kind == 'str':
            self.advance()
            return Node('atom', text=text)
        if kind == 'kw' and text in ('nil', 'true', 'false'):
            self.advance()
            return Node('atom', text=text)
        if kind == 'op' and text == '...':
            self.advance()
            return Node('atom', text=text)
        if kind == 'op' and text == '{':
            return self.table()
        if kind == 'kw' and text == 'function':
            self.advance()
            return self.function_body(token)
        return self.suffixed_expression()

    def primary_expression(self):
        token = self.cur
        if token.kind == 'name':
            self.advance()
            return Node('name', name=token.text)
        if token.kind == 'op' and token.text == '(':
            self.advance()
            inner = self.expr()
            self.expect_op(')')
            return Node('paren', inner=inner)
        self.error('unexpected symbol')

    def suffixed_expression(self):
        expr = self.primary_expression()
        while True:
            token = self.cur
            if token.kind == 'op' and token.text == '.':
                self.advance()
                expr = Node('field', base=expr, name=self.expect_name())
            elif token.kind == 'op' and token.text == '[':
                self.advance()
                key = self.expr()
                self.expect_op(']')
                expr = Node('index', base=expr, key=key)
            elif token.kind == 'op' and token.text == ':':
                self.advance()
                name = self.expect_name()
                expr = Node('method', base=expr, name=name, args=self.call_arguments())
            elif (token.kind == 'op' and token.text in ('(', '{')) or token.kind == 'str':
                expr = Node('call', base=expr, args=self.call_arguments())
            else:
                return expr

    def call_arguments(self):
        token = self.cur
        if token.kind == 'str':
            self.advance()
            return Node('args', items=[Node('item', value=Node('atom', text=token.text), lead=[], trail=[])],
                        open_trail=[], closing=[], sugar=True)
        if token.kind == 'op' and token.text == '{':
            value = self.table()
            return Node('args', items=[Node('item', value=value, lead=[], trail=[])], open_trail=[], closing=[],
                        sugar=True)
        open_token = self.expect_op('(')
        open_trail = self.claim_trail(open_token)
        items = []
        while not self.is_op(')'):
            first = self.cur
            lead = self.claim_lead(first)
            value = self.expr()
            last = self.tokens[self.i - 1]
            trail = self.claim_trail(last)
            if self.is_op(','):
                trail = trail + self.claim_trail(self.advance())
            elif not self.is_op(')'):
                self.error('expected , or )')
            items.append(Node('item', value=value, lead=lead, trail=trail))
        close = self.cur
        closing = self.claim_lead(close)
        self.advance()
        return Node('args', items=items, open_trail=open_trail, closing=closing, sugar=False)

    def table(self):
        open_token = self.expect_op('{')
        open_trail = self.claim_trail(open_token)
        expanded = False
        fields = []
        while not self.is_op('}'):
            first = self.cur
            if not fields and (first.newline_before or first.lead):
                expanded = True
            lead = self.claim_lead(first)
            if first.kind == 'name' and self.tokens[self.i + 1].kind == 'op' and self.tokens[self.i + 1].text == '=':
                self.advance()
                self.advance()
                field = Node('field', key=Node('atom', text=first.text), shorthand=True, value=self.expr())
            elif first.kind == 'op' and first.text == '[':
                self.advance()
                key = self.expr()
                self.expect_op(']')
                self.expect_op('=')
                field = Node('field', key=key, shorthand=False, value=self.expr())
            else:
                field = Node('field', key=None, shorthand=False, value=self.expr())
            last = self.tokens[self.i - 1]
            trail = self.claim_trail(last)
            if self.is_op(',') or self.is_op(';'):
                trail = trail + self.claim_trail(self.advance())
            elif not self.is_op('}'):
                self.error('expected , or }')
            field.lead, field.trail = lead, trail
            fields.append(field)
        close = self.cur
        closing = self.claim_lead(close)
        if not fields and closing:
            expanded = True
        if fields and close.newline_before:
            expanded = expanded or bool(closing) or False
        self.advance()
        return Node('table', fields=fields, expanded=expanded, open_trail=open_trail, closing=closing)

    def function_body(self, function_token):
        open_token = self.expect_op('(')
        open_trail = self.claim_trail(open_token)
        params = []
        while not self.is_op(')'):
            if self.is_op('...'):
                self.advance()
                params.append('...')
            else:
                params.append(self.expect_name())
            if self.is_op(','):
                self.advance()
            elif not self.is_op(')'):
                self.error('expected , or )')
        rparen = self.advance()
        rparen_index = self.i - 1
        rparen_trail = self.claim_trail(rparen)
        head_trail = open_trail + rparen_trail
        body = self.block()
        end_token = self.expect_kw('end')
        end_index = self.i - 1
        node = Node('func', params=params, head_trail=head_trail, body=body, line=function_token.line,
                    end_line=end_token.end_line, raw=None)
        raw = self.src[rparen.end:end_token.start]
        if raw in self.frozen_codes:
            node.raw = raw
            node.head_trail = open_trail  # a comment after the `)` is part of the verbatim text
            # Everything between the parameter list and `end` is printed verbatim, so its comments must not be
            # printed a second time.
            for token in self.tokens[rparen_index:end_index]:
                token.lead = []
                token.trail = []
            end_token.lead = []
            body.statements = []
            body.closing = []
        return node


# ----------------------------------------------------------------------------------------------------------------------
# Documents (Wadler/Prettier style) and the renderer
# ----------------------------------------------------------------------------------------------------------------------

HARD = ('hard',)
LINE = ('line',)
SOFT = ('soft',)
FLAT, BREAK = 0, 1


class Group:
    __slots__ = ('doc', 'brk')

    def __init__(self, doc, brk=False):
        self.doc, self.brk = doc, brk


class Cond:
    """The first option whose first line fits, else the last."""
    __slots__ = ('opts',)

    def __init__(self, opts):
        self.opts = opts


def text(s):
    return ('t', s)


def cat(*docs):
    return ('c', list(docs))


def indent(doc):
    return ('i', doc)


def flat(doc):
    return ('f', doc)


def suffix(s):
    return ('s', s)


def gap(previous, following, forced, tight=False):
    """The separator between two statements: a line break, plus a blank line when `forced` or when either statement
    prints on more than one line (decided by the renderer, which knows the real indentation). `tight` (two guard clauses
    of one kind) drops the second reason."""
    return ('bg', previous, following, forced, tight)


def ifbreak(broken, flat_text):
    """`broken` when the enclosing group is broken over several lines, else `flat_text`."""
    return ('ib', broken, flat_text)


def fill(parts):
    return ('fill', parts)


def join(separator, docs):
    parts = []
    for index, doc in enumerate(docs):
        if index:
            parts.append(separator)
        parts.append(doc)
    return cat(*parts)


def propagate(doc):
    """Mark every group that contains a forced line break; return whether `doc` has one."""
    if isinstance(doc, tuple):
        tag = doc[0]
        if tag in ('hard', 'bg'):
            return True
        if tag == 't':
            return '\n' in doc[1]
        if tag == 'c':
            found = False
            for part in doc[1]:
                if propagate(part):
                    found = True
            return found
        if tag in ('i', 'f'):
            return propagate(doc[1])
        if tag == 'fill':
            found = False
            for part in doc[1]:
                if propagate(part):
                    found = True
            return found
        return False
    if isinstance(doc, Group):
        found = propagate(doc.doc)
        if found:
            doc.brk = True
        # A group that was forced open (a table the author wrote over several lines) opens its parents too.
        return doc.brk
    if isinstance(doc, Cond):
        found = False
        for option in doc.opts:
            if propagate(option):
                found = True
        return found
    return False


def has_hard(doc):
    """Whether a document that has been through `propagate` contains a forced line break."""
    if isinstance(doc, tuple):
        tag = doc[0]
        if tag in ('hard', 'bg'):
            return True
        if tag == 't':
            return '\n' in doc[1]
        if tag == 'c':
            return any(has_hard(part) for part in doc[1])
        if tag in ('i', 'f'):
            return has_hard(doc[1])
        if tag == 'fill':
            return any(has_hard(part) for part in doc[1])
        return False
    if isinstance(doc, Group):
        return doc.brk
    if isinstance(doc, Cond):
        return has_hard(doc.opts[-1])
    return False


def fits(first, rest, width, must_be_flat=False):
    """Whether `first` (processed in its mode) and the commands after it reach a line break within `width` columns."""
    rest_index = len(rest)
    cmds = [first]
    while width >= 0:
        if not cmds:
            if rest_index == 0:
                return True
            rest_index -= 1
            cmds.append(rest[rest_index])
            continue
        ind, mode, doc = cmds.pop()
        if isinstance(doc, tuple):
            tag = doc[0]
            if tag == 't':
                if '\n' in doc[1]:
                    return width - len(doc[1].split('\n', 1)[0]) >= 0
                width -= len(doc[1])
            elif tag == 'c':
                for part in reversed(doc[1]):
                    cmds.append((ind, mode, part))
            elif tag == 'i':
                cmds.append((ind, mode, doc[1]))
            elif tag == 'f':
                cmds.append((ind, FLAT, doc[1]))
            elif tag == 'fill':
                for part in reversed(doc[1]):
                    cmds.append((ind, mode, part))
            elif tag == 'line':
                if mode == BREAK:
                    return True
                width -= 1
            elif tag == 'soft':
                if mode == BREAK:
                    return True
            elif tag == 'ib':
                width -= len(doc[1] if mode == BREAK else doc[2])
            elif tag in ('hard', 'bg'):
                return True
        elif isinstance(doc, Group):
            if must_be_flat and doc.brk:
                return False
            cmds.append((ind, BREAK if doc.brk else mode, doc.doc))
        elif isinstance(doc, Cond):
            cmds.append((ind, mode, doc.opts[0] if mode == FLAT else doc.opts[-1]))
    return False


def spans_lines(doc, width, memo):
    key = (id(doc), width)
    if key not in memo:
        memo[key] = render(doc, width, memo, False).count('\n') > 1
    return memo[key]


def render(doc, width=WIDTH, memo=None, gaps=True):
    propagate(doc)
    memo = {} if memo is None else memo
    lines, current, pending_suffix = [], [], []
    position = 0
    cmds = [(0, BREAK, doc)]

    def newline(ind):
        nonlocal current, position
        line = ''.join(current).rstrip(' \t')
        if pending_suffix:
            line = line + '  ' + '  '.join(pending_suffix)
            del pending_suffix[:]
        lines.append(line)
        current = [' ' * ind] if ind else []
        position = ind

    while cmds:
        item = cmds.pop()
        if item[0] == 'fillrest':
            _, ind, parts, index = item
            content = parts[index]
            if index + 1 < len(parts):
                separator, following = parts[index + 1], parts[index + 2]
                two = fits((ind, FLAT, cat(content, separator, following)), [], width - position)
                cmds.append(('fillrest', ind, parts, index + 2))
                cmds.append((ind, FLAT if two else BREAK, separator))
            cmds.append((ind, FLAT, content))
            continue
        ind, mode, d = item
        if isinstance(d, tuple):
            tag = d[0]
            if tag == 't':
                piece = d[1]
                if '\n' in piece:
                    segments = piece.split('\n')
                    current.append(segments[0])
                    lines.append(''.join(current))
                    for segment in segments[1:-1]:
                        lines.append(segment)
                    current = [segments[-1]]
                    position = len(segments[-1])
                else:
                    current.append(piece)
                    position += len(piece)
            elif tag == 'c':
                for part in reversed(d[1]):
                    cmds.append((ind, mode, part))
            elif tag == 'i':
                cmds.append((ind + INDENT, mode, d[1]))
            elif tag == 'f':
                cmds.append((ind, FLAT, d[1]))
            elif tag == 'fill':
                if d[1]:
                    cmds.append(('fillrest', ind, d[1], 0))
            elif tag == 'line':
                if mode == FLAT:
                    current.append(' ')
                    position += 1
                else:
                    newline(ind)
            elif tag == 'soft':
                if mode == BREAK:
                    newline(ind)
            elif tag == 'hard':
                newline(ind)
            elif tag == 'bg':
                newline(ind)
                if gaps and (d[3] or (not d[4] and (spans_lines(d[1], width - ind, memo) or spans_lines(d[2], width - ind, memo)))):
                    newline(ind)
            elif tag == 'ib':
                piece = d[1] if mode == BREAK else d[2]
                current.append(piece)
                position += len(piece)
            elif tag == 's':
                pending_suffix.append(d[1])
        elif isinstance(d, Group):
            if mode == FLAT and not d.brk:
                cmds.append((ind, FLAT, d.doc))
            elif d.brk:
                cmds.append((ind, BREAK, d.doc))
            elif fits((ind, FLAT, d.doc), cmds, width - position):
                cmds.append((ind, FLAT, d.doc))
            else:
                cmds.append((ind, BREAK, d.doc))
        elif isinstance(d, Cond):
            chosen = None
            for number, option in enumerate(d.opts[:-1]):
                if number == 0:
                    ok = fits((ind, FLAT, option), cmds, width - position, True)
                    state = (ind, FLAT, option)
                else:
                    ok = fits((ind, BREAK, option), cmds, width - position)
                    state = (ind, BREAK, option)
                if ok:
                    chosen = state
                    break
            cmds.append(chosen or (ind, BREAK, d.opts[-1]))
    newline(0)
    out = '\n'.join(lines)
    return out.rstrip('\n') + '\n'


# ----------------------------------------------------------------------------------------------------------------------
# The printer: tree to document
# ----------------------------------------------------------------------------------------------------------------------

ATOMS = ('atom', 'name')
STATEMENT_ENDERS = ('return', 'break')


def comment_text(comment):
    return comment.text


class Printer:
    # -- expressions -------------------------------------------------------------------------------------------------

    def expr(self, node):
        kind = node.kind
        if kind == 'atom':
            return text(node.text)
        if kind == 'name':
            return text(node.name)
        if kind == 'paren':
            return cat(text('('), self.expr(node.inner), text(')'))
        if kind == 'unop':
            spacer = ' ' if node.op == 'not' or (node.op == '-' and node.operand.kind == 'unop' and node.operand.op == '-') else ''
            return cat(text(node.op + spacer), self.expr(node.operand))
        if kind == 'binop':
            return self.binary(node)
        if kind == 'field':
            return cat(self.expr(node.base), text('.' + node.name))
        if kind == 'index':
            return cat(self.expr(node.base), text('[' + long_string_gap(node.key)), self.expr(node.key),
                       text(long_string_gap(node.key) + ']'))
        if kind == 'call':
            return cat(self.expr(node.base), self.arguments(node.args))
        if kind == 'method':
            return cat(self.expr(node.base), text(':' + node.name), self.arguments(node.args))
        if kind == 'table':
            return self.table(node)
        if kind == 'func':
            return self.function(node, statement=False)
        raise FormatError('cannot print %s' % kind)

    def binary(self, node, tail_indent=True):
        chain, hug = self.binary_parts(node, tail_indent)
        if hug is not None:
            return Cond([chain, hug, chain])
        return chain

    def binary_parts(self, node, tail_indent=True):
        """A chain of one precedence level as one group (`a and b and c`, broken before each operator) and, when its last
        operand is a call, table or function that can open on the first line (`local ok = a or check({` ... `})`), the
        hugging layout that prefers that to breaking before the operator."""
        left_priority = BINARY[node.op][0]
        operands, operators = [], []

        def collect(current):
            if current.kind == 'binop' and BINARY[current.op][0] == left_priority and current.op not in RIGHT_ASSOCIATIVE \
                    and node.op not in RIGHT_ASSOCIATIVE:
                collect(current.left)
                operators.append(current.op)
                operands.append(current.right)
            elif current.kind == 'binop' and current.op == node.op and node.op in RIGHT_ASSOCIATIVE:
                operands.append(current.left)
                operators.append(current.op)
                collect(current.right)
            else:
                operands.append(current)

        collect(node)
        docs = [self.expr(operand) for operand in operands]
        tail = []
        for operator, doc in zip(operators, docs[1:]):
            tail.append(cat(LINE, text(operator + ' '), doc))
        if len(docs) > 1 and has_hard_doc(docs[0]) and not any(has_hard_doc(d) for d in docs[1:]):
            # Only the first operand is multi-line (`({ ... })[key] or default`): the rest follows its last line.
            pieces = [docs[0]]
            for operator, doc in zip(operators, docs[1:]):
                pieces += [text(' ' + operator + ' '), flat(doc)]
            return cat(*pieces), None
        chain = Group(cat(docs[0], indent(cat(*tail)) if tail_indent else cat(*tail)))
        hug = None
        if huggable(operands[-1]) and not any(has_hard_doc(d) for d in docs[:-1]):
            pieces = [flat(docs[0])]
            for operator, doc in zip(operators[:-1], docs[1:-1]):
                pieces += [text(' ' + operator + ' '), flat(doc)]
            pieces += [text(' ' + operators[-1] + ' '), docs[-1]]
            hug = cat(*pieces)
        return chain, hug

    def arguments(self, args):
        items = args.items
        if not items:
            return text('()')
        has_comments = bool(args.open_trail or args.closing or any(item.lead or item.trail for item in items))
        values = [self.expr(item.value) for item in items]
        if has_comments:
            return self.broken_arguments(args, values)
        flat_all = Group(cat(text('('), join(text(', '), values), text(')')))
        broken = Group(cat(text('('), indent(cat(SOFT, join(cat(text(','), LINE), values))), SOFT, text(')')), True)
        broken_soft = Group(cat(text('('), indent(cat(SOFT, join(cat(text(','), LINE), values))), SOFT, text(')')))
        last, first = items[-1].value, items[0].value
        hug_last = last.kind in ('table', 'func') or (last.kind in ('call', 'method') and huggable(last))
        for item in items[:-1]:
            if item.value.kind in ('func', 'table') and self.is_multiline(values[items.index(item)]):
                hug_last = False
        options = [flat_all]
        if hug_last and not any(has_hard_doc(v) for v in values[:-1]):
            head = [flat(value) for value in values[:-1]]
            parts = [text('(')]
            for value in head:
                parts.append(value)
                parts.append(text(', '))
            parts.append(values[-1])
            parts.append(text(')'))
            options.append(cat(*parts))
        elif first.kind in ('func', 'table') and len(items) > 1 and not any(has_hard_doc(v) for v in values[1:]):
            parts = [text('('), values[0]]
            for value in values[1:]:
                parts.append(text(', '))
                parts.append(flat(value))
            parts.append(text(')'))
            options.append(cat(*parts))
        if len(items) > 1 and len(options) == 1 and all(item.value.kind in ('func', 'table') for item in items):
            # Several function or table arguments (`wrap(function() ... end, function() ... end)`) share the call's lines.
            options.append(cat(text('('), join(text(', '), values), text(')')))
        options.append(broken_soft)
        return Cond(options)

    def is_multiline(self, doc):
        propagate(doc)
        return has_hard(doc)

    def broken_arguments(self, args, values):
        inner = []
        for index, item in enumerate(args.items):
            parts = []
            for comment in item.lead:
                parts.append(text(comment.text))
                parts.append(HARD)
            parts.append(values[index])
            if index < len(args.items) - 1:
                parts.append(text(','))
            for comment in item.trail:
                parts.append(suffix(comment.text))
            inner.append(cat(*parts))
        body = []
        for index, part in enumerate(inner):
            body.append(HARD)
            body.append(part)
        closing = []
        for comment in args.closing:
            closing.append(HARD)
            closing.append(text(comment.text))
        head = [suffix(comment.text) for comment in args.open_trail]
        return cat(text('('), *head, indent(cat(*body, *closing)), HARD, text(')'))

    def table(self, node):
        fields = node.fields
        if not fields:
            if node.closing or node.open_trail:
                inner = [cat(HARD, text(c.text)) for c in node.closing]
                head = [suffix(c.text) for c in node.open_trail]
                return cat(text('{'), *head, indent(cat(*inner)), HARD, text('}'))
            return text('{}')
        has_comments = bool(node.open_trail or node.closing or any(f.lead or f.trail for f in fields))
        docs = []
        for field in fields:
            value = self.expr(field.value)
            if field.key is None:
                doc = value
            elif field.shorthand:
                doc = cat(text(field.key.text + ' = '), value)
            else:
                doc = cat(text('[' + long_string_gap(field.key)), self.expr(field.key),
                          text(long_string_gap(field.key) + '] = '), value)
            docs.append(doc)
        if has_comments:
            body = []
            for index, field in enumerate(fields):
                parts = [HARD]
                for comment in field.lead:
                    parts.append(text(comment.text))
                    parts.append(HARD)
                parts.append(docs[index])
                parts.append(text(','))
                for comment in field.trail:
                    parts.append(suffix(comment.text))
                body.append(cat(*parts))
            for comment in node.closing:
                body.append(cat(HARD, text(comment.text)))
            head = [suffix(c.text) for c in node.open_trail]
            return cat(text('{'), *head, indent(cat(*body)), HARD, text('}'))
        all_atoms = all(f.key is None and f.value.kind in ('atom', 'name') for f in fields)
        if all_atoms and len(fields) > 8:
            parts = []
            for index, doc in enumerate(docs):
                if index:
                    parts.append(LINE)
                parts.append(cat(doc, text(',')) if index < len(docs) - 1 else doc)
            return Group(cat(text('{'), indent(cat(SOFT, fill(parts))), SOFT, text('}')), node.expanded)
        separator = cat(text(','), LINE)
        return Group(cat(text('{'), indent(cat(LINE, join(separator, docs), ifbreak(',', ''))), LINE, text('}')),
                     node.expanded)

    # -- functions ---------------------------------------------------------------------------------------------------

    def function(self, node, statement, name=None):
        prefix = 'function' if name is None else 'function ' + name
        if node.params:
            head = Group(cat(text(prefix + '('),
                             indent(cat(SOFT, join(cat(text(','), LINE), [text(p) for p in node.params]))), SOFT,
                             text(')')))
        else:
            head = text(prefix + '()')
        trail = [suffix(c.text) for c in node.head_trail]
        if node.raw is not None:
            return cat(head, *trail, text(node.raw), text('end'))
        body = node.body
        if not body.statements and not body.closing:
            return cat(head, *trail, text(' end'))
        single = self.single_line_body(node)
        if single is not None and not statement and not trail:
            return Group(cat(head, indent(cat(LINE, single)), LINE, text('end')))
        return cat(head, *trail, indent(cat(HARD, self.block(body))), HARD, text('end'))

    def single_line_body(self, node):
        """The `return` of an anonymous function the author wrote on a single line, when that is all it does."""
        body = node.body
        if node.line != node.end_line or len(body.statements) != 1 or body.closing:
            return None
        statement = body.statements[0]
        if statement.lead or statement.trail or statement.hoisted:
            return None
        if statement.kind != 'return':
            return None
        doc = self.statement(statement)
        if self.is_multiline(doc):
            return None
        return doc

    # -- statements and blocks ---------------------------------------------------------------------------------------

    def block(self, block):
        statements = block.statements
        parts = []
        previous = None
        previous_doc = None
        for index, statement in enumerate(statements):
            doc = self.statement(statement)
            if previous is not None:
                tight = guard_kind(previous) is not None and guard_kind(previous) == guard_kind(statement) \
                    and not statement.lead and not statement.hoisted
                parts.append(gap(previous_doc, doc, statement.blank_before and not tight, tight))
            for comment in statement.hoisted:
                parts.append(text(comment.text))
                parts.append(HARD)
            for number, comment in enumerate(statement.lead):
                if number and comment.blank_before:
                    parts.append(HARD)
                parts.append(text(comment.text))
                parts.append(HARD)
            if statement.lead and statement.lead_gap:
                parts.append(HARD)
            parts.append(doc)
            # Lua 5.1 refuses a statement that starts with `(` on the line after another statement unless the
            # previous one ends in `;`.
            if index + 1 < len(statements) and statements[index + 1].first_text == '(':
                parts.append(text(';'))
            for comment in statement.trail:
                parts.append(suffix(comment.text))
            previous, previous_doc = statement, doc
        if block.closing:
            if previous is not None:
                parts.append(HARD)
                if block.closing_blank:
                    parts.append(HARD)
            for number, comment in enumerate(block.closing):
                if number:
                    if comment.blank_before:
                        parts.append(HARD)
                    parts.append(HARD)
                parts.append(text(comment.text))
        return cat(*parts)

    def statement(self, node):
        kind = node.kind
        if kind == 'local':
            names = ', '.join(node.names)
            if not node.values:
                return text('local ' + names)
            return self.assignment(text('local ' + names), node.values)
        if kind == 'assign':
            targets = join(text(', '), [self.expr(t) for t in node.targets])
            return self.assignment(targets, node.values)
        if kind == 'callstat':
            return self.expr(node.call)
        if kind == 'return':
            if not node.values:
                return text('return')
            return cat(text('return '), self.expression_list(node.values))
        if kind == 'break':
            return text('break')
        if kind == 'do':
            return cat(text('do'), *[suffix(c.text) for c in node.head_trail], self.body(node.body), HARD, text('end'))
        if kind == 'while':
            return cat(self.condition('while', node.cond, 'do', node.head_trail), self.body(node.body), HARD, text('end'))
        if kind == 'repeat':
            return cat(text('repeat'), *[suffix(c.text) for c in node.head_trail], self.body(node.body), HARD,
                       self.condition('until', node.cond, '', []))
        if kind == 'numfor':
            parts = [self.expr(node.start), text(', '), self.expr(node.stop)]
            if node.step is not None:
                parts += [text(', '), self.expr(node.step)]
            head = cat(text('for %s = ' % node.var), *parts, text(' do'), *[suffix(c.text) for c in node.head_trail])
            return cat(head, self.body(node.body), HARD, text('end'))
        if kind == 'genfor':
            head = cat(text('for %s in ' % ', '.join(node.names)), self.expression_list(node.values), text(' do'),
                       *[suffix(c.text) for c in node.head_trail])
            return cat(head, self.body(node.body), HARD, text('end'))
        if kind == 'function':
            return self.function(node.function, True, node.name)
        if kind == 'localfunction':
            return cat(text('local '), self.function(node.function, True, node.name))
        if kind == 'if':
            return self.if_statement(node)
        raise FormatError('cannot print statement %s' % kind)

    def body(self, block):
        if not block.statements and not block.closing:
            return cat()
        return indent(cat(HARD, self.block(block)))

    def assignment(self, left, values):
        """`left = values`. Several values that do not fit on the line move below the `=` as one indented list."""
        if len(values) == 1:
            return cat(left, text(' = '), self.expr(values[0]))
        docs = [self.expr(v) for v in values]
        on_one_line = Group(cat(left, text(' = '), join(text(', '), docs)))
        below = Group(cat(left, text(' ='), indent(cat(LINE, Group(join(cat(text(','), LINE), docs))))))
        options = [on_one_line]
        if huggable(values[-1]) and not any(has_hard_doc(d) for d in docs[:-1]):
            options.append(cat(left, text(' = '), join(text(', '), [flat(d) for d in docs[:-1]] + [docs[-1]])))
        options.append(below)
        return Cond(options)

    def expression_list(self, values):
        docs = [self.expr(v) for v in values]
        if len(docs) == 1:
            return docs[0]
        listed = Group(cat(docs[0], indent(cat(*[cat(text(','), LINE, d) for d in docs[1:]]))))
        if huggable(values[-1]) and not any(has_hard_doc(d) for d in docs[:-1]):
            hugged = join(text(', '), [flat(d) for d in docs[:-1]] + [docs[-1]])
            return Cond([listed, hugged, listed])
        return listed

    def condition(self, keyword, cond, tail, trail):
        """`if a and b then`. An and/or chain too long for the line wraps as `if` / indented operands / `then`, unless its
        last operand is a call or table that can open on the first line."""
        tail_docs = [text(' ' + tail)] if tail else []
        trail_docs = [suffix(c.text) for c in trail]
        if cond.kind == 'binop' and cond.op in ('and', 'or') and tail:
            chain, hug = self.binary_parts(cond, False)
            wrapped = Group(cat(text(keyword), indent(cat(LINE, chain)), LINE, text(tail)))
            if hug is not None:
                inline = cat(text(keyword + ' '), chain, *tail_docs)
                hugged = cat(text(keyword + ' '), hug, *tail_docs)
                return cat(Cond([inline, hugged, wrapped]), *trail_docs)
            return cat(wrapped, *trail_docs)
        return cat(text(keyword + ' '), self.expr(cond), *tail_docs, *trail_docs)

    def if_statement(self, node):
        clauses = node.clauses
        parts = []
        for index, clause in enumerate(clauses):
            keyword = 'if' if index == 0 else 'elseif'
            if index:
                parts.append(HARD)
            parts.append(self.condition(keyword, clause.cond, 'then', clause.head_trail))
            parts.append(self.body(clause.body))
        if node.else_clause is not None:
            parts.append(HARD)
            parts.append(text('else'))
            parts += [suffix(c.text) for c in node.else_clause.head_trail]
            parts.append(self.body(node.else_clause.body))
        parts.append(HARD)
        parts.append(text('end'))
        return cat(*parts)

    def chunk(self, block):
        return self.block(block)


GUARD_BODIES = ('return', 'break', 'callstat', 'assign', 'local')


def guard_kind(statement):
    """The kind of the one statement a guard clause runs (`return`, `break`, ...), or None when `statement` is not a guard
    clause: an `if` with a single condition, no `else`, no comment in or on its head and one plain statement inside."""
    if statement.kind != 'if' or statement.else_clause is not None or len(statement.clauses) != 1:
        return None
    clause = statement.clauses[0]
    body = clause.body
    if clause.head_trail or len(body.statements) != 1 or body.closing:
        return None
    inner = body.statements[0]
    if inner.lead or inner.trail or inner.hoisted or inner.kind not in GUARD_BODIES:
        return None
    return inner.kind


def long_string_gap(key):
    """A space inside the brackets of `t[ [[text]] ]`: without it `[[` would open a long string around the whole key."""
    return ' ' if key.kind == 'atom' and key.text.startswith('[') else ''


def huggable(node):
    """Whether an expression opens a bracket the rest of the line can hug: a call, table or function (or an operator
    chain that ends in one)."""
    if node.kind in ('call', 'method'):
        return bool(node.args.items) and not node.args.sugar or node.args.sugar
    if node.kind in ('table', 'func'):
        return True
    if node.kind == 'binop':
        return huggable(node.right)
    return False


def has_hard_doc(doc):
    propagate(doc)
    return has_hard(doc)


# ----------------------------------------------------------------------------------------------------------------------
# Driver
# ----------------------------------------------------------------------------------------------------------------------


def git_show(revision, path):
    result = subprocess.run(['git', '-C', str(ROOT), 'show', '%s:%s' % (revision, path)], capture_output=True)
    if result.returncode != 0:
        raise FormatError('git show %s:%s failed' % (revision, path))
    return result.stdout.decode('utf-8')


def frozen_codes(path, revision=None):
    """Body texts of the Built In helper functions recorded for `path` in Data/builtin_sources.lua."""
    catalog = ROOT / 'Data' / 'builtin_sources.lua'
    if revision is not None:
        holder = tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8')
        with holder:
            holder.write(git_show(revision, 'Data/builtin_sources.lua'))
        catalog = Path(holder.name)
    try:
        return read_frozen(catalog, path)
    finally:
        if revision is not None:
            catalog.unlink()


_FROZEN_CACHE = {}


def read_frozen(catalog, path):
    if not catalog.exists():
        return set()
    key = (str(catalog), catalog.stat().st_mtime_ns, catalog.stat().st_size)
    if key not in _FROZEN_CACHE:
        _FROZEN_CACHE.clear()
        _FROZEN_CACHE[key] = read_all_frozen(catalog)
    return _FROZEN_CACHE[key].get(path, set())


def read_all_frozen(catalog):
    """Per module path, the body texts the catalog records: helper functions (module bindings) and the callbacks of
    every condition the module defines. Saved copies and bundles are compared against that text."""
    script = (
        "local addon={} local chunk=assert(loadfile(arg[1])) chunk('RotationMaster',addon)\n"
        "local catalog=addon.BuiltinSourceCatalog\n"
        "local function hex(code) return (code:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end\n"
        "local function show(path,code) if type(code)=='string' then print(path..' '..hex(code)) end end\n"
        "local function callbacks(path,list) for _,cb in pairs(list or {}) do show(path,cb.code) end end\n"
        "for path,module in pairs(catalog and catalog.modules or {}) do\n"
        "for _,b in pairs(module.bindings) do if b.kind=='function' then show(path,b.code) end end end\n"
        "for _,c in pairs(catalog and catalog.conditions or {}) do callbacks(c.module,c.callbacks)\n"
        "for _,v in pairs(c.variants or {}) do callbacks(c.module,v.callbacks) end end\n")
    result = subprocess.run(['lua5.1', '-e', 'arg={[1]=%r} ' % str(catalog) + script], capture_output=True, text=True)
    if result.returncode != 0:
        raise FormatError('could not read the builtin source catalog: ' + result.stderr.strip())
    found = {}
    for line in result.stdout.split('\n'):
        if line:
            module, code = line.split(' ')
            found.setdefault(module, set()).add(bytes.fromhex(code).decode('utf-8'))
    return found


def split_generated(src):
    """The authored part of a file and the generated binding suffix (which is never reformatted)."""
    index = src.find('\n' + GENERATED_BEGIN)
    if index < 0:
        return src, ''
    return src[:index + 1], src[index + 1:]


GENERATED_REGION = re.compile(r'^-- BEGIN GENERATED (?!RM SOURCE BINDINGS)([^\n]*)\n.*?^-- END GENERATED \1[ \t]*$', re.M | re.S)


def format_source(src, codes=frozenset()):
    """Format `src`. A region between `-- BEGIN GENERATED X` and `-- END GENERATED X` is some generator's output; it is
    set aside as a placeholder statement while the rest is formatted and put back byte for byte."""
    regions = []
    try:
        strings = [(token.start, token.end) for token in lex(src) if token.kind == 'str']
    except FormatError:
        strings = []

    def hide(match):
        # Marker lines inside a string literal (a fixture that quotes a generated file) are not regions.
        if any(start <= match.start() < end for start, end in strings):
            return match.group(0)
        regions.append(match.group(0))
        return '__RM_GENERATED_REGION_%d__()' % (len(regions) - 1)

    hidden = GENERATED_REGION.sub(hide, src)
    out = format_hidden(hidden, codes)
    for number, region in enumerate(regions):
        placeholder = '__RM_GENERATED_REGION_%d__()' % number
        out = out.replace(placeholder, region)
        # keep the region apart from its neighbors
        index = out.index(region)
        if index > 1 and out[index - 2:index] != '\n\n':
            out = out[:index] + '\n' + out[index:]
        end = out.index(region) + len(region)
        if end < len(out) - 1 and out[end:end + 2] != '\n\n':
            out = out[:end] + '\n' + out[end:]
    return out


def format_hidden(src, codes):
    authored, generated = split_generated(src)
    tokens = lex(authored)
    parser = Parser(tokens, authored, codes)
    chunk = parser.block()
    if parser.cur.kind != 'eof':
        parser.error('unexpected token')
    printer = Printer()
    doc = printer.chunk(chunk)
    out = render(doc)
    leftovers = [token for token in tokens if token.lead or token.trail]
    if leftovers:
        raise FormatError('comment left unplaced at line %d' % leftovers[0].line)
    if not chunk.statements and not chunk.closing:
        out = ''
    if generated:
        out = out.rstrip('\n') + '\n\n' + generated
    return out


def comment_list(src):
    authored, generated = split_generated(src)
    found = []
    for token in lex(authored):
        found.extend(c.text for c in token.lead)
        found.extend(c.text for c in token.trail)
    return sorted(found)


def compile_image(src, name):
    """The compiled form of `src` with everything that depends on layout removed: the `luac5.1 -l -l` listing without
    line numbers, addresses and the chunk name. Instructions, constants, local names and upvalues remain."""
    with tempfile.TemporaryDirectory() as scratch:
        source = Path(scratch) / (name + '.lua')
        source.write_text(src, encoding='utf-8')
        result = subprocess.run(['luac5.1', '-p', '-l', '-l', str(source)], capture_output=True, text=True)
        if result.returncode != 0:
            return None, result.stderr.strip()
    listing = result.stdout.replace(str(source), 'chunk')
    listing = re.sub(r'\[\d+\]', '', listing)
    listing = re.sub(r'<chunk:\d+,\d+>', '<chunk>', listing)
    listing = re.sub(r'0x[0-9a-f]+', '0x', listing)
    return listing, ''


def same_program(before, after):
    first, why = compile_image(before, 'before')
    if first is None:
        return False, 'original does not compile: ' + why
    second, why = compile_image(after, 'after')
    if second is None:
        return False, 'result does not compile: ' + why
    if first != second:
        return False, 'bytecode differs'
    return True, ''


def process(path, write, to_stdout, list_only, base=None, check=False):
    file = Path(path)
    relative = str(file.resolve().relative_to(ROOT)) if file.resolve().is_relative_to(ROOT) else str(file)
    before = git_show(base, relative) if base else file.read_text(encoding='utf-8')
    try:
        codes = frozen_codes(relative, base)
        after = format_source(before, codes)
        # The layout of the first pass can depend on how the author wrapped things (a table written over several lines
        # stays expanded), so format until the text stops changing, as Prettier effectively does.
        for _ in range(0 if check else 4):
            again = format_source(after, codes)
            if again == after:
                break
            after = again
        else:
            if not check:
                raise FormatError('formatting does not settle')
        if not check:  # --check only compares layout; the proof is for writing
            if comment_list(before) != comment_list(after):
                raise FormatError('comments differ after formatting')
            ok, why = same_program(before, after)
            if not ok:
                raise FormatError(why)
    except FormatError as error:
        print('REFUSED %s: %s' % (path, error), file=sys.stderr)
        return 1
    if after == (file.read_text(encoding='utf-8') if file.exists() else None):
        if not list_only and not check:
            print('unchanged %s' % path, file=sys.stderr)
        return 0
    if check:
        print('would reformat %s' % path, file=sys.stderr)
        return 1
    if list_only:
        print(path)
        return 0
    if to_stdout:
        sys.stdout.write(after)
    elif write:
        file.write_text(after, encoding='utf-8')
        print('formatted %s' % path, file=sys.stderr)
    else:
        sys.stdout.writelines(difflib.unified_diff(before.splitlines(True), after.splitlines(True), 'a/' + path,
                                                   'b/' + path))
    return 0


def tree_files():
    """Every Lua file the formatter owns: tracked, not vendored, not generated (listed above, or a first line that says
    `-- Generated by`), not one of the sources other tests cut up as text."""
    listing = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '*.lua'], capture_output=True, text=True, check=True)
    found = []
    for relative in listing.stdout.splitlines():
        if relative.startswith(EXEMPT_PREFIXES) or relative in EXEMPT_FILES or relative in READ_AS_TEXT_BY_TESTS:
            continue
        with open(ROOT / relative, encoding='utf-8') as handle:
            head = handle.readline()
        if head.lower().startswith('-- generated by'):
            continue
        found.append(str(ROOT / relative))
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('files', nargs='*')
    parser.add_argument('--tree', action='store_true', help='all the files the formatter owns (see tree_files)')
    parser.add_argument('--write', action='store_true', help='rewrite the files')
    parser.add_argument('--stdout', action='store_true', help='print the formatted text')
    parser.add_argument('--check', action='store_true', help='exit 1 when a file is not laid out as the formatter would')
    parser.add_argument('--list', action='store_true', help='only list the files that would change')
    parser.add_argument('--base', metavar='REV', help='read the input (and the helper catalog) from this revision instead of the working tree')
    args = parser.parse_args(argv)
    if args.tree:
        args.files = args.files + tree_files()
    if not args.files:
        parser.error('name files or pass --tree')
    status = 0
    for path in args.files:
        status = max(status, process(path, args.write, args.stdout, args.list, args.base, args.check))
    return status


if __name__ == '__main__':
    sys.exit(main())
