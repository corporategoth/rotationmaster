#!/usr/bin/env python3
"""Generate browsable source and binding exports from authored Lua definitions."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from catalog_check import TOKEN
ROOT=Path(__file__).resolve().parents[1]
BEGIN='-- BEGIN GENERATED RM SOURCE BINDINGS'
END='-- END GENERATED RM SOURCE BINDINGS'
DOCS_BEGIN='-- BEGIN GENERATED RM PUBLIC HELPER DOCS'
DOCS_END='-- END GENERATED RM PUBLIC HELPER DOCS'

RETAINED_ACE_GETTERS={path:'addon:GetConditionWidgetCompatibilityLibrary()' for path in ('UI/selector.lua','UI/checkbox.lua','UI/condition_inputs.lua','Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua')}
RETAINED_ACE_GETTERS['UI/condition_layout.lua']='addon:BindConditionGroupCompatibilityLibrary()'

def function_source(source,record,name):
    lines=source.splitlines(keepends=True)
    start=sum(map(len,lines[:record['first']-1]));stop=sum(map(len,lines[:record['last']]))
    tokens=[(m.group(),m.start(),m.end()) for m in TOKEN.finditer(source,start,stop) if m.lastgroup not in ('space','comment')]
    first_line_end=source.find('\n',start);first_line_end=stop if first_line_end<0 else first_line_end
    candidates=[i for i,t in enumerate(tokens) if t[0]=='function' and t[1]<=first_line_end]
    if not candidates: raise ValueError(f'no function at {record}')
    matching=[i for i in candidates if (i>=2 and tokens[i-1][0]=='=' and tokens[i-2][0]==name) or (i+1<len(tokens) and tokens[i+1][0]==name)]
    index=(matching or candidates)[0];opening=index+1
    while opening<len(tokens) and tokens[opening][0]!='(': opening+=1
    closing=opening+1
    while closing<len(tokens) and tokens[closing][0]!=')': closing+=1
    if closing>=len(tokens): raise ValueError('missing function parameters')
    args=''.join(t[0] for t in tokens[opening+1:closing]);params=args.split(',') if args else []
    if any(not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*|\.\.\.',arg) for arg in params): raise ValueError('invalid parameters')
    if any(t[0]==':' for t in tokens[index+1:opening]): params.insert(0,'self')
    stack=['function']
    for token,begin,_ in tokens[closing+1:]:
        if token in ('function','if','repeat'): stack.append(token)
        elif token in ('for','while'): stack.append('loop_wait')
        elif token=='do':
            if stack[-1]=='loop_wait': stack[-1]='loop'
            else: stack.append('do')
        elif token=='until':
            if stack.pop()!='repeat': raise ValueError('unexpected until')
        elif token=='end':
            stack.pop()
            if not stack: return params,source[tokens[closing][2]:begin]
    raise ValueError('unterminated function')


def authored(source):
    if BEGIN not in source: return source.rstrip()+'\n'
    before,after=source.split(BEGIN,1)
    if END not in after or after.split(END,1)[1].strip(): raise ValueError('unexpected generated binding suffix')
    return before.rstrip()+'\n'


def lua(value):
    if isinstance(value,str):
        parts=[]
        for char in value:
            if char in ('"','\\'): parts.append('\\'+char)
            elif ord(char)<32: parts.append('\\%03d'%ord(char))
            else: parts.append(char)
        return '"'+''.join(parts)+'"'
    if isinstance(value,bool): return 'true' if value else 'false'
    if isinstance(value,(int,float)): return str(value)
    if isinstance(value,list): return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value,dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(value.items()))+'}'
    raise ValueError('unsupported generated data')


def generated():
    modules=json.loads(subprocess.check_output(['lua5.1','tools/collect_builtin_sources.lua'],cwd=ROOT,text=True))
    outputs={};legacy_getters={};catalog={'modules':{},'conditions':{}}
    for module in modules.values():
        for alias,entry in module['bindings'].items():
            docs=entry.get('public') or entry.get('ownership') or {};identity=docs.get('bindingID')
            if identity:
                matched=re.fullmatch(r'builtin:(.+):([A-Za-z_][A-Za-z_0-9]*)',identity)
                if not matched: raise ValueError('invalid explicit binding ID: '+identity)
                old_path,old_alias=matched.groups()
                if old_path not in modules: raise ValueError('legacy binding owner unavailable: '+old_path)
                legacy_getters.setdefault(old_path,{})[old_alias]=('addon.'+entry['addonMember'] if entry.get('addonMember') else 'addon.builtinSourceModules['+lua(module['file'])+']('+lua(alias)+')')
    for path,module in sorted(modules.items()):
        source=authored((ROOT/path).read_text());bindings=module['bindings'];catalog['modules'][path]={'hash':hashlib.sha256(source.encode()).hexdigest(),'bindings':{}}
        for alias,entry in sorted(bindings.items()):
            row={'kind':'function' if entry.get('fn') else 'value'}
            if entry.get('ownership'): row.update(entry['ownership'])
            if entry.get('fn'):
                record=entry['fn'];params,body=function_source(source,record,alias)
                row.update(code=body,parameters=params,bindings=record['bindings'],line=record['first'])
                if entry.get('public'):
                    docs=entry['public']
                    if set(docs['args'])!=set(params): raise ValueError('public helper argument metadata drift: '+alias)
                    returns=docs['returns'] if isinstance(docs['returns'],list) else [docs['returns']]
                    row.update(callName=docs['callName'],description=docs['description'],args=[dict(name=name,**docs['args'][name]) for name in params],returns=returns)
                    for metadata in ('bindingID','namespace','compatibilityNamespaces'):
                        if metadata in docs: row[metadata]=docs[metadata]
            catalog['modules'][path]['bindings'][alias]=row
        def condition_callbacks(callbacks):
            result={}
            for name,callback in sorted(callbacks.items()):
                params,body=function_source(source,callback,name)
                result[name]={'code':body,'parameters':params,'bindings':callback['bindings'],'line':callback['first']}
            return result
        records={tag:{'module':path,'callbacks':condition_callbacks(callbacks)} for tag,callbacks in module['conditions'].items()}
        for tag,variants in module.get('conditionVariants',{}).items():
            if tag in records: raise ValueError('mixed builtin source variants for '+tag)
            records[tag]={'module':path,'variants':{variant:{'callbacks':condition_callbacks(callbacks)} for variant,callbacks in variants.items()}}
        for tag,record in sorted(records.items()):
            if tag in catalog['conditions'] and catalog['conditions'][tag]!=record: raise ValueError('ambiguous source for '+tag)
            catalog['conditions'][tag]=record
        # Export live locals by name: getters preserve reassigned module state.
        suffix=[BEGIN,'do','    local function sourceGetter(name)']
        getter_expressions={alias: 'addon.'+entry['addonMember'] if entry.get('addonMember') else alias for alias,entry in bindings.items()}
        for alias,entry in bindings.items():
            expression=entry.get('getterExpression')
            if expression is not None:
                if alias!='AceGUI' or expression!=RETAINED_ACE_GETTERS.get(path):
                    raise ValueError('invalid retained widget getter expression: '+path+':'+alias)
                getter_expressions[alias]=expression
        for alias,expression in legacy_getters.get(path,{}).items():
            if alias in getter_expressions and getter_expressions[alias]!=expression: raise ValueError('conflicting legacy getter: '+path+':'+alias)
            getter_expressions[alias]=expression
        for alias,expression in sorted(getter_expressions.items()):
            if not re.fullmatch('[A-Za-z_][A-Za-z_0-9]*',alias): raise ValueError('invalid binding identifier')
            suffix.append('        if name=='+lua(alias)+' then return '+expression+' end')
        suffix+=['    end','    if addon.RegisterBuiltinSourceModule then',
                 '        addon:RegisterBuiltinSourceModule('+lua(path)+', sourceGetter)',
                 '    else','        addon.builtinSourceModules=addon.builtinSourceModules or {}',
                 '        addon.builtinSourceModules['+lua(path)+']=sourceGetter','    end','end',END]
        outputs[path]=source+'\n'+'\n'.join(suffix)+'\n'
    outputs['Data/builtin_sources.lua']='-- Generated by tools/generate_builtin_sources.py; edit the authored Lua files.\nlocal _,addon=...\naddon.BuiltinSourceCatalog='+lua(catalog)+'\n'
    descriptions=set()
    for module in catalog['modules'].values():
        for row in module['bindings'].values():
            if row.get('description'):
                descriptions.add(row['description'])
            if row.get('callName'):
                descriptions.update(item['description'] for item in row['args']+row['returns'])
    locale=(ROOT/'Locales/enUS.lua').read_text()
    if DOCS_BEGIN in locale:
        before,after=locale.split(DOCS_BEGIN,1)
        if DOCS_END not in after: raise ValueError('unterminated generated public helper locale block')
        _,after=after.split(DOCS_END,1)
        locale=before.rstrip()+'\n'+after.lstrip('\n')
    declarations=[DOCS_BEGIN]+['L['+lua(text)+'] = true' for text in sorted(descriptions)]+[DOCS_END]
    outputs['Locales/enUS.lua']=locale.rstrip()+'\n\n'+'\n'.join(declarations)+'\n'
    return outputs,catalog


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    outputs,catalog=generated();stale=[]
    for name,content in outputs.items():
        path=ROOT/name
        if args.write: path.write_text(content)
        elif not path.exists() or path.read_text()!=content: stale.append(name)
    if stale:
        print('Stale builtin source catalog/bindings: '+', '.join(stale));print('Run python3 tools/generate_builtin_sources.py --write');return 1
    print(f"Builtin source catalog: {len(catalog['conditions'])} conditions, {len(catalog['modules'])} modules; {'generated' if args.write else 'current'}")
    return 0
if __name__=='__main__': sys.exit(main())
