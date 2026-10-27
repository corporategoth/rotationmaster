"""tools/format_lua.py: layout rules, the safety checks and the frozen-body rule."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import format_lua  # noqa: E402


def fmt(source, frozen=frozenset()):
    return format_lua.format_source(source, frozen)


class Layout(unittest.TestCase):
    def test_one_statement_per_line_with_spacing_and_blank_lines(self):
        out = fmt("local a=1;local b={x=1,y=2}\nif a then b.x=2;b.y=3 end\nreturn a\n")
        self.assertEqual(out, "local a = 1\nlocal b = { x = 1, y = 2 }\n\nif a then\n    b.x = 2\n    b.y = 3\nend\n\nreturn a\n")

    def test_guard_clause_stays_on_one_line_only_if_the_author_wrote_it_so(self):
        self.assertIn("if x then return end\n", fmt("if x then return end\n"))
        self.assertIn("if x then\n    return\nend\n", fmt("if x then\n return\nend\n"))

    def test_function_argument_hugs_the_call(self):
        out = fmt("addon:On('E',function(a)\nprint(a)\nprint(a)\nend)\n")
        self.assertEqual(out, "addon:On('E', function(a)\n    print(a)\n    print(a)\nend)\n")

    def test_long_call_wraps_at_120_columns(self):
        out = fmt("f(" + ", ".join("argument%02d" % n for n in range(14)) + ")\n")
        self.assertTrue(all(len(line) <= 120 for line in out.split("\n")))
        self.assertGreater(out.count("\n"), 2)

    def test_formatting_is_stable(self):
        once = fmt("local t={1,2,3}\nfor i,v in ipairs(t) do print(i,v) end\n")
        self.assertEqual(fmt(once), once)

    def test_comments_survive_and_a_comment_inside_an_expression_moves_up(self):
        out = fmt("-- lead\nlocal x = f(a, -- why\n b) -- trail\n")
        self.assertEqual(format_lua.comment_list(out), format_lua.comment_list("-- lead\nlocal x = f(a, -- why\n b) -- trail\n"))

    def test_statement_starting_with_a_parenthesis_keeps_its_separator(self):
        source = "local f = g\n;(f or g)()\n"
        self.assertEqual(format_lua.same_program(source, fmt(source)), (True, ''))


class Safety(unittest.TestCase):
    def test_a_changed_program_is_detected(self):
        self.assertFalse(format_lua.same_program("local a = 1\n", "local a = 2\n")[0])

    def test_layout_only_changes_are_not_a_difference(self):
        self.assertTrue(format_lua.same_program("local a=1 local b=2\n", "local a = 1\n\n-- c\nlocal b = 2\n")[0])


class FrozenBodies(unittest.TestCase):
    def test_a_recorded_body_is_printed_byte_for_byte(self):
        body = "\n    local a=1;return a ,2\n"
        source = "local function f(x)" + body + "end\nlocal y=f(1)\n"
        out = fmt(source, frozenset([body]))
        self.assertIn("local function f(x)" + body + "end\n", out)
        self.assertIn("local y = f(1)", out)


if __name__ == '__main__':
    unittest.main()
