#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Run pinned WoW-aware analysis and fail new diagnostics against legacy debt."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from setup_lint import ROOT,default_target,manifest,tool_spec

PATTERN=re.compile(r'^(.*?):(\d+):(\d+): (error|warning|information|hint)\[([\w-]+)\] (.*)$')

def fingerprint(record):
    return json.dumps(record,sort_keys=True,ensure_ascii=False)

def parse_diagnostics(output,root):
    root=Path(root).resolve();records=[];sources={}
    for line in output.splitlines():
        match=PATTERN.match(line)
        if not match:
            # The checker can log invalid configuration and continue with
            # defaults, including a successful exit code. Reject its warning
            # and error logs separately from ordinary source diagnostics.
            if re.match(r'(?i)^\s*(?:\[(?:warn(?:ing)?|error|fatal|panic)\b|(?:error|fatal|panic|failed|warning)\b)',line):
                raise ValueError('Checker reported a tool/configuration failure: '+line)
            continue
        path,line_number,_,severity,code,message=match.groups()
        source=(root/path).resolve()
        try: relative=source.relative_to(root)
        except ValueError: raise ValueError('Checker diagnostic references a file outside the addon.')
        if source not in sources: sources[source]=source.read_text().splitlines()
        index=int(line_number)-1
        if index<0 or index>=len(sources[source]): raise ValueError('Checker diagnostic references an invalid source location.')
        records.append({'path':relative.as_posix(),'severity':severity,'code':code,'message':message,
            'source':sources[source][index].strip()})
    return records

def validate_result(returncode,output,records):
    if returncode not in (0,1) or returncode==1 and not records:
        raise ValueError(f'Checker failed (exit {returncode}): '+output[-2000:])

def make_baseline(records):
    counts=Counter(fingerprint(record) for record in records)
    return {'tool':{'name':'wowlua-ls','version':manifest()['version']},
        'diagnostics':[dict(json.loads(key),count=count) for key,count in sorted(counts.items())]}

def new_diagnostics(records,baseline):
    remaining=Counter()
    for record in baseline['diagnostics']:
        record=dict(record);count=record.pop('count')
        if not isinstance(count,int) or count<1: raise ValueError('Invalid static-analysis baseline count.')
        remaining[fingerprint(record)]+=count
    new=[]
    for record in records:
        key=fingerprint(record)
        if record['severity']=='error' or remaining[key]==0: new.append(record)
        else: remaining[key]-=1
    return new

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-baseline',action='store_true',help='Record reviewed legacy warnings; never run this from CI.')
    parser.add_argument('--report-all',action='store_true',help='Print every upstream diagnostic, including existing debt.')
    args=parser.parse_args()
    try:
        _,spec=tool_spec()
        tool=Path(os.environ.get('RM_WOWLUA_LS',str(default_target()))).resolve()
        if not tool.is_file(): raise ValueError('Checker is missing. Run: python3 tools/setup_lint.py')
        if hashlib.sha256(tool.read_bytes()).hexdigest()!=spec['sha256']: raise ValueError('Checker binary does not match the pinned manifest.')
        result=subprocess.run([str(tool),'check',str(ROOT)],cwd=ROOT,capture_output=True,text=True,timeout=120)
        output=result.stdout+'\n'+result.stderr
        records=parse_diagnostics(output,ROOT);validate_result(result.returncode,output,records)
        baseline_path=ROOT/'tools/lint-baseline.json'
        if args.write_baseline:
            if any(record['severity']=='error' for record in records): raise ValueError('Errors cannot be accepted into the legacy baseline.')
            baseline_path.write_text(json.dumps(make_baseline(records),indent=2,ensure_ascii=False)+'\n')
            print(f'Recorded {len(records)} legacy warnings. Review tools/lint-baseline.json.');return 0
        baseline=json.loads(baseline_path.read_text())
        if baseline['tool']['version']!=manifest()['version']: raise ValueError('Checker and baseline versions differ.')
        new=new_diagnostics(records,baseline)
        if args.report_all: print(output)
        for record in new: print(f"{record['path']}: {record['severity']}[{record['code']}] {record['message']}\n  {record['source']}")
        print(f'WoW static analysis: {len(records)-len(new)} existing warnings; {len(new)} new diagnostics. Legacy baseline is not a clean type-check claim.')
        return 1 if new else 0
    except (OSError,ValueError,KeyError,subprocess.SubprocessError) as error:
        print(f'Static analysis failed: {error}',file=sys.stderr);return 1

if __name__=='__main__':sys.exit(main())
