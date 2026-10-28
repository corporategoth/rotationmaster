"""tools/format_lua.py: layout rules, the safety checks and the frozen-body rule."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
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

    def test_function_argument_hugs_the_call(self):
        out = fmt("addon:On('E',function(a)\nprint(a)\nprint(a)\nend)\n")
        self.assertEqual(out, "addon:On('E', function(a)\n    print(a)\n    print(a)\nend)\n")

    def test_long_call_wraps_at_120_columns(self):
        out = fmt("f(" + ", ".join("argument%02d" % n for n in range(14)) + ")\n")
        self.assertTrue(all(len(line) <= 120 for line in out.split("\n")))
        self.assertGreater(out.count("\n"), 2)

    def test_formatting_is_stable(self):
        once = fmt("local t={1,2,3}\nfor i,v in ipairs(t) do print(i,v) end\nif a then return end\nif b then return end\n")
        self.assertEqual(fmt(once), once)

    def test_comments_survive_and_a_comment_inside_an_expression_moves_up(self):
        out = fmt("-- lead\nlocal x = f(a, -- why\n b) -- trail\n")
        self.assertEqual(format_lua.comment_list(out), format_lua.comment_list("-- lead\nlocal x = f(a, -- why\n b) -- trail\n"))

    def test_statement_starting_with_a_parenthesis_keeps_its_separator(self):
        source = "local f = g\n;(f or g)()\n"
        self.assertEqual(format_lua.same_program(source, fmt(source)), (True, ''))


class OneLineStatements(unittest.TestCase):
    """No block is written on one line; each rewrite is also proved to compile to the same program."""

    def check(self, source, expected):
        out = fmt(source)
        self.assertEqual(out, expected)
        self.assertEqual(format_lua.same_program(source, out), (True, ''))
        self.assertEqual(fmt(out), out)

    def test_if_is_split_over_three_lines(self):
        self.check("if x then return end\n", "if x then\n    return\nend\n")

    def test_if_elseif_else(self):
        self.check("if a then f() elseif b then g() else h() end\n",
                   "if a then\n    f()\nelseif b then\n    g()\nelse\n    h()\nend\n")

    def test_nested_one_line_blocks(self):
        self.check("for k, v in pairs(t) do if v then break end end\n",
                   "for k, v in pairs(t) do\n    if v then\n        break\n    end\nend\n")

    def test_numeric_for_and_while_and_repeat_and_do(self):
        self.check("for i = 1, 3 do f(i) end\n", "for i = 1, 3 do\n    f(i)\nend\n")
        self.check("while a do a = a.next end\n", "while a do\n    a = a.next\nend\n")
        self.check("repeat a = a.next until not a\n", "repeat\n    a = a.next\nuntil not a\n")
        self.check("do f() end\n", "do\n    f()\nend\n")

    def test_named_function_bodies_are_split(self):
        self.check("local function f() return 1 end\n", "local function f()\n    return 1\nend\n")
        self.check("function M.f(a) a.x = 1 end\n", "function M.f(a)\n    a.x = 1\nend\n")

    def test_an_empty_body_stays_on_the_head_line_for_functions_only(self):
        self.check("function addon:Noop() end\n", "function addon:Noop() end\n")
        self.check("if a then end\n", "if a then\nend\n")

    def test_anonymous_function_that_only_returns_stays_inline(self):
        self.check("table.sort(t, function(p, q) return p.n < q.n end)\n",
                   "table.sort(t, function(p, q) return p.n < q.n end)\n")
        self.check("local t = { get = function(o) return o.x end }\n", "local t = { get = function(o) return o.x end }\n")
        self.check("local h = function() return 1 end\n", "local h = function() return 1 end\n")

    def test_anonymous_function_with_another_statement_is_split(self):
        self.check("C_Timer.After(1, function() f() end)\n", "C_Timer.After(1, function()\n    f()\nend)\n")
        self.check("local t = { run = function(o) o.x = 1 end }\n",
                   "local t = {\n    run = function(o)\n        o.x = 1\n    end,\n}\n")

    def test_a_return_that_does_not_fit_leaves_the_line_and_a_written_split_stays_split(self):
        out = fmt("f(function(a) return " + " + ".join("argument%02d" % n for n in range(12)) + " end)\n")
        self.assertTrue(all(len(line) <= 120 for line in out.split("\n")))
        self.assertEqual(fmt("f(function(a)\n    return a\nend)\n"), "f(function(a)\n    return a\nend)\n")

    def test_a_comment_after_a_one_line_statement_moves_to_its_first_line(self):
        self.check("if x then y() end -- note\n", "if x then  -- note\n    y()\nend\n")
        self.check("for i = 1, 3 do f(i) end -- note\n", "for i = 1, 3 do  -- note\n    f(i)\nend\n")
        self.check("while a do a = a.n end -- note\n", "while a do  -- note\n    a = a.n\nend\n")
        self.check("if a then f() else g() end -- note\n", "if a then  -- note\n    f()\nelse\n    g()\nend\n")

    def test_a_comment_after_a_multi_line_statement_stays_on_its_last_line(self):
        self.check("if x then\n    y()\nend -- note\n", "if x then\n    y()\nend  -- note\n")

    def test_strings_and_comments_that_look_like_keywords_are_not_touched(self):
        self.check("if s == 'end' then print('then end') end\n",
                   "if s == 'end' then\n    print('then end')\nend\n")
        self.check("if x then y = [[ if a then b end ]] end\n",
                   "if x then\n    y = [[ if a then b end ]]\nend\n")
        self.check("-- if a then b end\nlocal x = 1\n", "-- if a then b end\nlocal x = 1\n")

    def test_method_call_chains(self):
        self.check("if a then a:Get():Set(1):Run() end\n", "if a then\n    a:Get():Set(1):Run()\nend\n")

    def test_semicolon_separated_statements(self):
        self.check("if a then x = 1; y = 2; return x end\n", "if a then\n    x = 1\n    y = 2\n    return x\nend\n")
        self.check("local a = 1; local b = 2;\n", "local a = 1\nlocal b = 2\n")

    def test_return_stays_the_last_statement_of_its_block(self):
        self.check("if a then return end; f()\n", "if a then\n    return\nend\n\nf()\n")
        self.check("while true do if a then return 1 end break end\n",
                   "while true do\n    if a then\n        return 1\n    end\n\n    break\nend\n")

    def test_a_long_condition_still_wraps(self):
        out = fmt("if " + " and ".join("condition_number_%02d" % n for n in range(10)) + " then return end\n")
        self.assertTrue(all(len(line) <= 120 for line in out.split("\n")))
        self.assertTrue(out.rstrip().endswith("return\nend"))


class BlankLines(unittest.TestCase):
    def test_guard_clauses_of_one_kind_have_no_blank_line_between_them(self):
        out = fmt("if not a then return end\nif not b then return end\nif c then return 1 end\n")
        self.assertEqual(out, "if not a then\n    return\nend\nif not b then\n    return\nend\nif c then\n    return 1\nend\n")

    def test_a_run_of_six_guards_is_eighteen_tight_lines(self):
        out = fmt("".join("if a%d then return end\n" % n for n in range(6)))
        self.assertEqual(len(out.rstrip("\n").split("\n")), 18)
        self.assertNotIn("\n\n", out)

    def test_guards_of_different_kinds_are_apart(self):
        out = fmt("if a then return end\nif b then x = 1 end\nif c then break end\n")
        self.assertEqual(out.count("\n\n"), 2)

    def test_a_guard_next_to_another_statement_keeps_the_blank_line(self):
        self.assertEqual(fmt("local x = f()\nif not x then return end\nlocal y = x\n"),
                         "local x = f()\n\nif not x then\n    return\nend\n\nlocal y = x\n")

    def test_if_with_else_or_two_statements_is_not_a_guard(self):
        out = fmt("if a then return end\nif b then f() g() end\nif c then return end\n")
        self.assertEqual(out.count("\n\n"), 2)

    def test_a_commented_guard_is_not_run_together_with_the_one_above(self):
        out = fmt("if a then return end\n-- why\nif b then return end\n")
        self.assertEqual(out, "if a then\n    return\nend\n\n-- why\nif b then\n    return\nend\n")


class Regressions(unittest.TestCase):
    def test_a_long_string_index_keeps_the_space_that_stops_it_opening_a_long_string(self):
        source = "records[ [====[main.lua]====] ]={bytes=1}\nlocal t={[ [[k]] ]=1}\n"
        out = fmt(source)
        self.assertEqual(out, "records[ [====[main.lua]====] ] = { bytes = 1 }\nlocal t = { [ [[k]] ] = 1 }\n")
        self.assertEqual(format_lua.same_program(source, out), (True, ''))

    def test_generated_region_markers_inside_a_string_are_text(self):
        source = "local s=[[\n-- BEGIN GENERATED X\nbody\n-- END GENERATED X\n]]\nlocal b=2\n"
        out = fmt(source)
        self.assertEqual(out, "local s = [[\n-- BEGIN GENERATED X\nbody\n-- END GENERATED X\n]]\n\nlocal b = 2\n")
        self.assertEqual(format_lua.same_program(source, out), (True, ''))


class CheckMode(unittest.TestCase):
    def run_check(self, source):
        with tempfile.TemporaryDirectory() as scratch:
            path = Path(scratch) / 'sample.lua'
            path.write_text(source, encoding='utf-8')
            with contextlib.redirect_stderr(io.StringIO()):
                status = format_lua.main(['--check', str(path)])
            self.assertEqual(path.read_text(encoding='utf-8'), source)
            return status

    def test_check_fails_on_a_one_line_if(self):
        self.assertEqual(self.run_check("if x then return end\n"), 1)

    def test_check_passes_on_the_split_layout(self):
        self.assertEqual(self.run_check("if x then\n    return\nend\n"), 0)


class Tree(unittest.TestCase):
    def test_tree_mode_owns_authored_files_only(self):
        owned = {str(Path(path).relative_to(ROOT)) for path in format_lua.tree_files()}
        self.assertIn('main.lua', owned)
        self.assertIn('Core/rotation_library.lua', owned)
        self.assertIn('tools/builtin_modules.lua', owned)
        for exempt in ('Data/builtin_sources.lua', 'tests/startup.lua', 'tests/fixtures/client_api.lua'):
            self.assertNotIn(exempt, owned)
        self.assertFalse([path for path in owned if path.startswith(format_lua.EXEMPT_PREFIXES)])

    def test_every_exemption_names_a_tracked_file(self):
        import subprocess
        tracked = set(subprocess.run(['git', '-C', str(ROOT), 'ls-files'], capture_output=True, text=True,
                                     check=True).stdout.splitlines())
        missing = (format_lua.EXEMPT_FILES | format_lua.READ_AS_TEXT_BY_TESTS) - tracked
        self.assertEqual(missing, set())


class GeneratedRegions(unittest.TestCase):
    def test_a_generated_region_is_kept_byte_for_byte(self):
        region = "-- BEGIN GENERATED X\nlocal t={a=1,b=2}\n-- END GENERATED X"
        out = fmt("local a=1\n" + region + "\nlocal b=2\n")
        self.assertEqual(out, "local a = 1\n\n" + region + "\n\nlocal b = 2\n")


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
