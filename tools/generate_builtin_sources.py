#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Generate browsable source and binding exports from authored Lua definitions."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from catalog_check import TOKEN
from copyright import notice_line
ROOT=Path(__file__).resolve().parents[1]
BEGIN='-- BEGIN GENERATED RM SOURCE BINDINGS'
END='-- END GENERATED RM SOURCE BINDINGS'

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


def binding_suffix(path,getters):
    suffix=[BEGIN,'do','    local function sourceGetter(name)']
    for alias,expression in sorted(getters.items()):
        if not re.fullmatch('[A-Za-z_][A-Za-z_0-9]*',alias): raise ValueError('invalid binding identifier')
        suffix.append('        if name=='+lua(alias)+' then return '+expression+' end')
    suffix+=['    end','    if addon.RegisterBuiltinSourceModule then',
             '        addon:RegisterBuiltinSourceModule('+lua(path)+', sourceGetter)',
             '    else','        addon.builtinSourceModules=addon.builtinSourceModules or {}',
             '        addon.builtinSourceModules['+lua(path)+']=sourceGetter','    end','end',END]
    return '\n'.join(suffix)+'\n'


def _prefix_end(words,start):
    """Skip a Lua prefix expression when checking subsequent assignment targets."""
    closing={'(':')','[':']','{':'}'}
    def balanced(index):
        stack=[closing[words[index]]];index+=1
        while index<len(words):
            word=words[index]
            if word in closing: stack.append(closing[word])
            elif word in (')',']','}'):
                if word!=stack.pop(): return None
                if not stack: return index+1
            index+=1
        return None
    def name(index):
        return index<len(words) and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',words[index]) and words[index] not in {
            'and','break','do','else','elseif','end','false','for','function','if','in','local','nil','not','or','repeat','return','then','true','until','while'}
    def arguments(index):
        if index>=len(words): return None
        if words[index] in ('(','{'): return balanced(index)
        if words[index].startswith(('"',"'",'[[','[=')): return index+1
        return None
    if name(start): index=start+1
    elif start<len(words) and words[start]=='(': index=balanced(start)
    else: return None
    while index is not None and index<len(words):
        word=words[index]
        if word=='.':
            if not name(index+1): return None
            index+=2
        elif word=='[': index=balanced(index)
        elif word==':':
            if not name(index+1): return None
            index=arguments(index+2)
        else:
            after=arguments(index)
            if after is None: return index
            index=after
    return index


RETAINED_VALUE={'module':'Conditions/character.lua','alias':'character_class',
                'bindingID':'builtin:Conditions/character.lua:character_class',
                'declaration':'local character_class = select(2, UnitClass("player"))',
                'namespace':'Conditions.character','description':'Packaged helper from Conditions/character.lua.',
                'sourceHash':'f9f4e4b5'}

def _significant(source):
    return [(m.group(),m.start(),m.end()) for m in TOKEN.finditer(source) if m.lastgroup not in ('space','comment')]

def verify_retained_value(path,full_source,alias,entry,getters):
    """Prove the one reviewed historical lexical value, without exporting it."""
    fail=lambda: ValueError('retained value lexical/provenance mismatch: '+path+':'+alias)
    retained=entry.get('retained')
    if (path!=RETAINED_VALUE['module'] or alias!=RETAINED_VALUE['alias']
            or set(entry)!={'kind','retained'} or not isinstance(entry['kind'],str)
            or not isinstance(retained,dict) or set(retained)!={'declaration','getter'}
            or retained['declaration']!=RETAINED_VALUE): raise fail()
    source=authored(full_source);tokens=_significant(source);words=[t[0] for t in tokens]
    expected=[t[0] for t in _significant(RETAINED_VALUE['declaration'])]
    declarations=[];allowed=set();stack=[]
    for i,word in enumerate(words):
        if word=='local':
            j=i+1;names=[]
            if j<len(words) and words[j]=='function':
                if j+1<len(words): names=[words[j+1]]
            else:
                while j<len(words) and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',words[j]):
                    names.append(words[j]);j+=1
                    if j>=len(words) or words[j]!=',': break
                    j+=1
            if alias in names:
                stop=i+len(expected)
                if (stack or words[i:stop]!=expected or stop>len(tokens)
                        or source[tokens[i][1]:tokens[stop-1][2]]!=RETAINED_VALUE['declaration']): raise fail()
                # The approved expression must end here, including across newlines.
                # Reject expression-list additions, operators and call/index suffixes.
                following=words[stop] if stop<len(words) else ''
                continuation={',','or','and','+','-','*','/','%','^','<','>','=','~','.',':','[','(','{'}
                if following in continuation or following.startswith(('\"',"'",'[[','[=')): raise fail()
                declarations.append(i);allowed.add(i+1)
        if word=='function':
            opening=i+1
            while opening<len(words) and words[opening]!='(': opening+=1
            if opening>=len(words): raise fail()
            header=words[i+1:opening]
            if header and header[0]==alias: raise fail()
            closing=opening+1
            while closing<len(words) and words[closing]!=')': closing+=1
            if alias in words[opening+1:closing]: raise fail()
            stack.append('function')
        elif word=='if': stack.append('if')
        elif word in ('for','while'):
            if word=='for':
                j=i+1
                while j<len(words) and words[j] not in ('=','in'):
                    if words[j]==alias: raise fail()
                    j+=1
            stack.append('loop_wait')
        elif word=='repeat': stack.append('repeat')
        elif word=='do':
            if stack and stack[-1]=='loop_wait': stack[-1]='loop'
            else: stack.append('do')
        elif word in ('end','until'):
            if not stack: raise fail()
            previous=stack.pop()
            if word=='until' and previous!='repeat': raise fail()
        if word==alias and i not in allowed and (i==0 or words[i-1] not in ('.',':')):
            j=i+1
            while j is not None and j<len(words) and words[j]==',': j=_prefix_end(words,j+1)
            if j is not None and j<len(words) and words[j]=='=' and (j+1>=len(words) or words[j+1]!='='): raise fail()
    if len(declarations)!=1 or stack: raise fail()
    descriptor=retained['getter']
    if (not isinstance(descriptor,dict) or set(descriptor)!={'file','first','last','what'}
            or descriptor['file']!=path or descriptor['what']!='Lua'
            or type(descriptor['first']) is not int or type(descriptor['last']) is not int
            or descriptor['first']<1 or descriptor['last']<descriptor['first']): raise fail()
    lines=full_source.splitlines(keepends=True)
    if descriptor['last']>len(lines): raise fail()
    start=sum(map(len,lines[:descriptor['first']-1]))
    if start<full_source.index(BEGIN) or [t[0] for t in _significant(lines[descriptor['first']-1])]!=['local','function','sourceGetter','(','name',')']: raise fail()
    params,body=function_source(full_source,descriptor,'sourceGetter')
    expected_body='\n'.join('if name=='+lua(name)+' then return '+expression+' end' for name,expression in sorted(getters.items()))
    expected_getter='local function sourceGetter(name)\n'+expected_body+'\nend'
    actual_getter=''.join(lines[descriptor['first']-1:descriptor['last']])
    if (params!=['name'] or [t[0] for t in _significant(body)]!=[t[0] for t in _significant(expected_body)]
            or [t[0] for t in _significant(actual_getter)]!=[t[0] for t in _significant(expected_getter)]): raise fail()
    if getters.get(alias)!=alias: raise fail()
    # The enclosing generated scope must not introduce a shadow before the getter.
    suffix=full_source[full_source.index(BEGIN):]
    if [t[0] for t in _significant(suffix)]!=[t[0] for t in _significant(binding_suffix(path,getters))]: raise fail()


def generated():
    modules=json.loads(subprocess.check_output(['lua5.1','tools/collect_builtin_sources.lua'],cwd=ROOT,text=True))
    retained_module=modules.get(RETAINED_VALUE['module'],{}).get('bindings',{})
    if not retained_module.get(RETAINED_VALUE['alias'],{}).get('retained'): raise ValueError('retained value declaration missing')
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
        full_source=(ROOT/path).read_text();source=authored(full_source);bindings=module['bindings'];catalog['modules'][path]={'hash':hashlib.sha256(source.encode()).hexdigest(),'bindings':{}}
        getter_expressions={alias: 'addon.'+entry['addonMember'] if entry.get('addonMember') else alias for alias,entry in bindings.items()}
        for alias,expression in legacy_getters.get(path,{}).items():
            if alias in getter_expressions and getter_expressions[alias]!=expression: raise ValueError('conflicting legacy getter: '+path+':'+alias)
            getter_expressions[alias]=expression
        for alias,entry in bindings.items():
            if entry.get('retained'): verify_retained_value(path,full_source,alias,entry,getter_expressions)
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
        outputs[path]=source+'\n'+binding_suffix(path,getter_expressions)
    outputs['Data/builtin_sources.lua']=notice_line('lua')+'\n\n-- Generated by tools/generate_builtin_sources.py; edit the authored Lua files.\nlocal _,addon=...\naddon.BuiltinSourceCatalog='+lua(catalog)+'\n'
    descriptions=set()
    for module in catalog['modules'].values():
        for row in module['bindings'].values():
            if row.get('description'):
                descriptions.add(row['description'])
            if row.get('callName'):
                descriptions.update(item['description'] for item in row['args']+row['returns'])
    # The descriptions are strings of the main catalog like any other: each has a stable ID in tools/locale_registry.json,
    # and the registry remembers which IDs this generator owns so it can add and retire exactly those.
    import locales
    model=locales.Model()
    model.sync_group('public-helper-docs',descriptions)
    outputs.update(model.outputs())
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
