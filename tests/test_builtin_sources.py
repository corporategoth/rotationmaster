import importlib.util
from pathlib import Path
import unittest
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('builtin_sources',ROOT/'tools/generate_builtin_sources.py')
module=importlib.util.module_from_spec(spec)
class SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): spec.loader.exec_module(module)
    def test_nested_blocks_strings_comments_and_loops(self):
        code='''evaluate = function(value, cache)
 -- end function ()
 local text = "end"
 for i=1,3 do if value then cache[i]=function() return 'end' end end end
 repeat value=value-1 until value==0
 do cache.done=true end
 return value
end, other = function() return false end'''
        params,body=module.function_source(code,{'first':1,'last':9},'evaluate')
        self.assertEqual(params,['value','cache'])
        self.assertIn('repeat value=value-1 until value==0',body)
        self.assertNotIn('other =',body)
    def test_named_helper_and_same_line_callbacks(self):
        params,body=module.function_source('local function helper(_, input) return input end',{'first':1,'last':1},'helper')
        self.assertEqual(params,['_','input']);self.assertEqual(body,' return input ')
        params,body=module.function_source('valid=function() return true end, evaluate=function(value) return value end',{'first':1,'last':1},'evaluate')
        self.assertEqual(params,['value']);self.assertEqual(body,' return value ')
    def test_public_method_signatures_keep_actual_dot_and_colon_parameters(self):
        params,body=module.function_source('function addon.trim(s) return s end',{'first':1,'last':1},'trim')
        self.assertEqual(params,['s']);self.assertEqual(body,' return s ')
        params,body=module.function_source('function addon:CreateConditionEditBox() return self.widget end',{'first':1,'last':1},'CreateConditionEditBox')
        self.assertEqual(params,['self']);self.assertEqual(body,' return self.widget ')

    def test_unterminated_or_non_lua_functions_fail_generation(self):
        with self.assertRaises(ValueError): module.function_source('function() if true then return 1 end',{'first':1,'last':1},'evaluate')
if __name__=='__main__': unittest.main()
