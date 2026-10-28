# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('retained_generator',ROOT/'tools/generate_builtin_sources.py')
generator=importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
DECL={'module':'Conditions/character.lua','alias':'character_class','bindingID':'builtin:Conditions/character.lua:character_class','declaration':'local character_class = select(2, UnitClass("player"))','namespace':'Conditions.character','description':'Packaged helper from Conditions/character.lua.','sourceHash':'f9f4e4b5'}
GETTERS={name:name for name in ('character_class','color','helpers','unit_class_num')}
def entry(source):
 first=source.index('    local function sourceGetter(name)')
 last=source.index('\n    end',first)+len('\n    end')
 return {'kind':'string','retained':{'declaration':copy.deepcopy(DECL),'getter':{'file':'Conditions/character.lua','first':source.count('\n',0,first)+1,'last':source.count('\n',0,last)+1,'what':'Lua'}}}
class RetainedValueTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls): cls.source=(ROOT/'Conditions/character.lua').read_text()
 def verify(self,source=None,record=None):
  self.assertTrue(callable(getattr(generator,'verify_retained_value',None)),'generator lacks retained lexical verifier')
  text=self.source if source is None else source
  generator.verify_retained_value('Conditions/character.lua',text,'character_class',record or entry(text),GETTERS)
 def rejects(self,text):
  with self.assertRaises(ValueError): self.verify(text)
 def valid_rejects(self,text):
  result=generator.subprocess.run(['luac5.1','-p','-'],input=text,text=True,capture_output=True)
  self.assertEqual(result.returncode,0,result.stderr)
  self.rejects(text)
 def test_exact_live_top_level_initializer_and_full_generated_getter_are_accepted(self): self.verify()
 def test_identity_metadata_and_value_kind_are_closed(self):
  for field in DECL:
   record=entry(self.source);record['retained']['declaration'][field]='changed'
   with self.subTest(field=field),self.assertRaises(ValueError): self.verify(record=record)
  for field,value in [('fn',{}),('public',{}),('ownership',{}),('addonMember','character_class')]:
   record=entry(self.source);record[field]=value
   with self.subTest(field=field),self.assertRaises(ValueError): self.verify(record=record)
 def test_initializer_decoys_nesting_rebinding_and_shadowing_are_rejected(self):
  declaration=DECL['declaration']
  for replacement in ['local character_class = nil','local character_class = addon:GetPlayerClass()', '-- '+declaration,'local decoy = '+repr(declaration),'do '+declaration+' end',declaration+'\nlocal character_class = nil',declaration+'\ncharacter_class = nil',declaration+'\nlocal function f(character_class) return character_class end',declaration+'\nfor character_class=1,2 do end',declaration+'\nlocal x;character_class,x=nil,1',declaration.replace(' = ','='),declaration+' or \"OTHER\"',declaration+'\n and \"OTHER\"',declaration+', nil',declaration+' == \"MAGE\"',declaration+' ~= nil',declaration+'(\"OTHER\")',*[declaration+'\n '+tail for tail in ['+ 1','- 1','* 1','/ 1','% 1','^ 1','.. \"x\"','< 1','> 1','<= 1','>= 1','.field','[1]',':method()','\"literal\"','[[literal]]','{1}']]]:
   with self.subTest(replacement=replacement): self.rejects(self.source.replace(declaration,replacement,1))
 def test_rebinding_with_member_index_call_and_parenthesized_later_targets_is_rejected(self):
  declaration=DECL['declaration']
  for target in ['addon.retentionProbe','retentionProbe[1]','retentionProbe[1 + 2].field','getProbe()[1]','(retentionProbe).field','getProbe {1}.field']:
   with self.subTest(target=target): self.valid_rejects(self.source.replace(declaration,declaration+'\nlocal retentionProbe={}; character_class, '+target+' = nil,1',1))
 def test_generated_enclosing_scope_cannot_shadow_the_retained_capture(self):
  for anchor in [generator.BEGIN,'do\n    local function sourceGetter(name)']:
   if anchor==generator.BEGIN: text=self.source.replace(anchor,anchor+'\nlocal character_class=nil',1)
   else: text=self.source.replace(anchor,'do\n    local character_class=nil\n    local function sourceGetter(name)',1)
   with self.subTest(anchor=anchor): self.valid_rejects(text)
 def test_full_getter_rejects_recomputation_shadowing_prologs_and_nested_decoys(self):
  branch='if name=="character_class" then return character_class end'
  for replacement in ['if name=="character_class" then return select(2,UnitClass("player")) end','if name=="character_class" then return addon.character_class end','-- '+branch,'local decoy='+repr(branch),'if false then '+branch+' end',branch+'\n        '+branch]:
   with self.subTest(replacement=replacement): self.rejects(self.source.replace(branch,replacement,1))
  for prolog in ['local character_class = select(2,UnitClass("player"))','character_class = select(2,UnitClass("player"))','if true then return select(2,UnitClass("player")) end']:
   with self.subTest(prolog=prolog): self.rejects(self.source.replace('local function sourceGetter(name)','local function sourceGetter(name)\n        '+prolog,1))
  for field,delta in [('first',-1),('first',1),('last',-1),('last',1)]:
   record=entry(self.source);record['retained']['getter'][field]+=delta
   with self.subTest(field=field,delta=delta),self.assertRaises(ValueError): self.verify(record=record)
 def test_generation_keeps_exact_value_row_and_is_idempotent_in_owned_temporary_files(self):
  self.verify()
  with tempfile.TemporaryDirectory(prefix='rm-retained-test-') as folder:
   root=Path(folder);(root/'Conditions').mkdir();(root/'Locales').mkdir();(root/'Conditions/character.lua').write_text(self.source);(root/'Locales/enUS.lua').write_text('local L={}\n')
   metadata={'Conditions/character.lua':{'file':'Conditions/character.lua','conditions':{},'bindings':{name:({'kind':'nil'} if name=='unit_class_num' else {'kind':'table'}) for name in GETTERS}}}
   metadata['Conditions/character.lua']['bindings']['character_class']=entry(self.source)
   with mock.patch.object(generator,'ROOT',root),mock.patch.object(generator.subprocess,'check_output',return_value=json.dumps(metadata)):
    first,catalog=generator.generated()
    self.assertEqual(catalog['modules']['Conditions/character.lua']['bindings']['character_class'],{'kind':'value'})
    self.assertEqual(first['Conditions/character.lua'].count('if name=="character_class" then return character_class end'),1)
    (root/'Conditions/character.lua').write_text(first['Conditions/character.lua']);(root/'Locales/enUS.lua').write_text(first['Locales/enUS.lua'])
    metadata['Conditions/character.lua']['bindings']['character_class']=entry(first['Conditions/character.lua'])
   with mock.patch.object(generator,'ROOT',root),mock.patch.object(generator.subprocess,'check_output',return_value=json.dumps(metadata)):
    second,_=generator.generated()
   self.assertEqual(first,second)
if __name__=='__main__': unittest.main()
