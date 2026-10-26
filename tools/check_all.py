#!/usr/bin/env python3
"""Run every command `tools/check` runs, without stopping at the first failure.

`tools/check` is fail-fast, which is right for a commit hook and wrong for CI: one red suite
hides every suite after it. This wrapper loads `tools/check` unchanged, runs the same command
list in the same order, records each result and reports them all, so a run says how much is
red rather than only what is first. The command list stays in one place.

  python3 tools/check_all.py                       all of tools/check
  python3 tools/check_all.py --static              the --static subset
  python3 tools/check_all.py --runtime lua5.1      only the commands that run under lua5.1
  python3 tools/check_all.py --runtime luajit      only luajit
  python3 tools/check_all.py --runtime python      only python (static checks and python suites)
  python3 tools/check_all.py --list                print the selected commands and exit
  python3 tools/check_all.py --baseline FILE       fail only on suites not listed in FILE (known red)
  python3 tools/check_all.py --skip-slow FILE      leave out the commands listed in FILE (tools/slow_tests.txt)

Output of a passing command is dropped; a failing command's output is printed in full after it.
Exit status is 0 when nothing outside the baseline failed. Commands run serially.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def runtime_of(command):
    """Which runtime a tools/check command uses: lua5.1, luajit or python."""
    name = os.path.basename(command[0])
    if name in ('lua5.1', 'luajit'):
        return name
    if command[0] == sys.executable or name.startswith('python'):
        return 'python'
    return name


def label(command):
    return ' '.join([os.path.basename(command[0]) if command[0] == sys.executable else command[0]] + list(command[1:]))


def collect(static=False):
    """Every command tools/check would run, in order, without running any."""
    namespace = runpy.run_path(str(ROOT / 'tools' / 'check'), run_name='rotationmaster_tools_check')
    commands, real_run, saved_argv, saved_out = [], subprocess.run, sys.argv, sys.stdout

    class Sink:
        def write(self, text):
            return len(text)

        def flush(self):
            pass

    def record(command, **kwargs):
        commands.append(list(command))
        return subprocess.CompletedProcess(command, 0)

    sys.argv, subprocess.run, sys.stdout = ['check'] + (['--static'] if static else []), record, Sink()
    try:
        namespace['main']()
    finally:
        sys.argv, subprocess.run, sys.stdout = saved_argv, real_run, saved_out
    return commands


def load_baseline(path):
    if not path:
        return set()
    return {line.strip() for line in Path(path).read_text(encoding='utf-8').splitlines()
            if line.strip() and not line.lstrip().startswith('#')}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--static', action='store_true', help='Pass --static to tools/check.')
    parser.add_argument('--runtime', choices=['all', 'lua5.1', 'luajit', 'python'], default='all')
    parser.add_argument('--list', action='store_true', help='Print the selected commands and exit.')
    parser.add_argument('--timeout', type=int, default=3600, help='Seconds one command may run (default 3600).')
    parser.add_argument('--baseline', help='File of command labels (one per line) known to fail; they do not fail the run.')
    parser.add_argument('--skip-slow', metavar='FILE', help='File of command labels to leave out (the slow ones; see tools/slow_tests.txt).')
    parser.add_argument('--json', dest='json_path', help='Write a machine-readable summary here.')
    parser.add_argument('--verbose', action='store_true', help='Print the output of passing commands too.')
    args = parser.parse_args(argv)

    namespace = runpy.run_path(str(ROOT / 'tools' / 'check'), run_name='rotationmaster_tools_check')
    check_main = namespace['main']
    baseline = load_baseline(args.baseline)
    slow = load_baseline(args.skip_slow)
    out_stream = sys.stdout
    results = []
    real_run = subprocess.run
    started = time.time()

    def selected(command):
        return (args.runtime == 'all' or runtime_of(command) == args.runtime) and label(command) not in slow

    def recording_run(command, **kwargs):
        if args.list:
            if selected(command):
                print(label(command), file=out_stream)
            return subprocess.CompletedProcess(command, 0)
        if not selected(command):
            return subprocess.CompletedProcess(command, 0)
        began = time.time()
        try:
            done = real_run(command, cwd=kwargs.get('cwd', ROOT), capture_output=True, timeout=args.timeout)
            code, out = done.returncode, done.stdout + done.stderr
        except FileNotFoundError:
            code, out = 127, f'Required executable not found: {command[0]}\n'.encode()
        except subprocess.TimeoutExpired as error:
            code, out = 124, ((error.stdout or b'') + (error.stderr or b'') + f'\ntimed out after {args.timeout}s\n'.encode())
        elapsed = time.time() - began
        text = out.decode('utf-8', 'replace')
        results.append({'command': label(command), 'runtime': runtime_of(command), 'code': code, 'seconds': round(elapsed, 2)})
        status = 'ok  ' if code == 0 else ('known' if label(command) in baseline else 'FAIL')
        print(f'{status} {elapsed:6.1f}s  {label(command)}', file=out_stream, flush=True)
        if code != 0 or args.verbose:
            out_stream.write(text if text.endswith('\n') or not text else text + '\n')
            out_stream.flush()
        return subprocess.CompletedProcess(command, 0)

    class Sink:
        # tools/check announces each command itself; this wrapper prints its own, timed, line instead.
        def write(self, text):
            return len(text)

        def flush(self):
            pass

    saved_argv = sys.argv
    sys.argv = ['check'] + (['--static'] if args.static else [])
    subprocess.run = recording_run
    sys.stdout = Sink()
    try:
        check_main()
    finally:
        sys.stdout = out_stream
        subprocess.run = real_run
        sys.argv = saved_argv
    if args.list:
        return 0

    failed = [r for r in results if r['code'] != 0]
    unexpected = [r for r in failed if r['command'] not in baseline]
    total = time.time() - started
    print()
    print(f'{len(results)} commands, {len(failed)} failed ({len(failed) - len(unexpected)} known), {total:.0f}s')
    for r in sorted(results, key=lambda r: -r['seconds'])[:5]:
        print(f'  slowest: {r["seconds"]:6.1f}s  {r["command"]}')
    for r in unexpected:
        print(f'  FAILED (exit {r["code"]}): {r["command"]}')
    if args.json_path:
        Path(args.json_path).write_text(json.dumps(
            {'commands': len(results), 'failed': [r['command'] for r in failed],
             'unexpected': [r['command'] for r in unexpected], 'seconds': round(total, 1), 'results': results},
            indent=1) + '\n', encoding='utf-8')
    return 1 if unexpected else 0


if __name__ == '__main__':
    sys.exit(main())
