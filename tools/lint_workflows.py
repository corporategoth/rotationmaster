#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Check the Gitea workflows and composite actions: structure, pinning, shell syntax, secret handling.

  python3 tools/lint_workflows.py              every file under .gitea/workflows and .gitea/actions
  python3 tools/lint_workflows.py --require-yaml    fail instead of skipping when PyYAML is not installed

This is not a substitute for running the workflow (see docs/release/RELEASING.md for what has and has not been run),
but it catches the mistakes that only show up on the runner:
  - duplicate keys, a job without runs-on, steps or timeout-minutes, a `needs` that names no job
  - a step with both or neither of `run` and `uses`
  - `uses:` that is not a local action that exists or an action pinned to a full 40-character commit SHA
  - a `run` script that does not parse with `bash -n` (after the ${{ }} expressions are replaced by a word)
  - a secret inside a `run` script (secrets belong in `env:`), or an expression in a `run` script that can carry
    attacker-controlled text (only matrix.*, steps.*.outputs.* and a few github.* values are allowed there)
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PINNED = re.compile(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$')
EXPRESSION = re.compile(r'\$\{\{\s*(.*?)\s*\}\}')
SAFE_IN_RUN = re.compile(r'^(matrix\.[\w-]+|steps\.[\w-]+\.outputs\.[\w-]+|github\.(sha|run_id|run_number|repository|workspace)|runner\.temp)$')


def load(path):
    import yaml

    class Strict(yaml.SafeLoader):
        pass

    def mapping(loader, node, deep=False):
        seen = set()
        for key_node, _ in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in seen:
                raise yaml.constructor.ConstructorError(None, None, f'duplicate key {key!r}', key_node.start_mark)
            seen.add(key)
        return yaml.SafeLoader.construct_mapping(loader, node, deep)

    Strict.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    return yaml.load(path.read_text(encoding='utf-8'), Loader=Strict)


def lint_steps(name, steps, problems):
    for number, step in enumerate(steps, 1):
        label = f'{name} step {number} ({step.get("name", step.get("uses", "?"))})'
        if ('run' in step) == ('uses' in step):
            problems.append(f'{label}: needs exactly one of run and uses')
        uses = step.get('uses')
        if uses:
            if uses.startswith('./'):
                if not (ROOT / uses / 'action.yml').is_file():
                    problems.append(f'{label}: local action {uses} has no action.yml')
            elif not PINNED.match(uses):
                problems.append(f'{label}: {uses} is not pinned to a 40-character commit SHA')
        script = step.get('run')
        if script is None:
            continue
        for expression in EXPRESSION.findall(script):
            if 'secrets.' in expression:
                problems.append(f'{label}: a secret inside a run script; pass it through env:')
            elif not SAFE_IN_RUN.match(expression):
                problems.append(f'{label}: ${{{{ {expression} }}}} in a run script; copy it into env: and use the variable')
        shell = step.get('shell', 'bash')
        if shell == 'bash':
            plain = EXPRESSION.sub('word', script)
            done = subprocess.run(['bash', '-n'], input=plain, capture_output=True, text=True)
            if done.returncode:
                problems.append(f'{label}: bash -n: {done.stderr.strip()}')


def lint_workflow(path, problems):
    name = path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else str(path)
    try:
        data = load(path)
    except Exception as error:  # noqa: BLE001 - report any parse problem with the file name
        problems.append(f'{name}: {error}')
        return
    if not isinstance(data, dict):
        problems.append(f'{name}: not a mapping')
        return
    if path.name == 'action.yml':
        for key in ('name', 'description', 'runs'):
            if key not in data:
                problems.append(f'{name}: missing {key}')
        if data.get('runs', {}).get('using') != 'composite':
            problems.append(f'{name}: runs.using must be composite')
        lint_steps(name, data.get('runs', {}).get('steps', []), problems)
        return
    trigger = data.get('on', data.get(True))  # PyYAML reads the bare key `on` as the boolean True
    if 'name' not in data or trigger is None or 'jobs' not in data:
        problems.append(f'{name}: needs name, on and jobs')
        return
    jobs = data['jobs']
    for job_id, job in jobs.items():
        where = f'{name} job {job_id}'
        if 'runs-on' not in job:
            problems.append(f'{where}: no runs-on')
        if 'timeout-minutes' not in job:
            problems.append(f'{where}: no timeout-minutes (a hung job would hold the shared runner for the default 6 hours)')
        if not job.get('steps'):
            problems.append(f'{where}: no steps')
        needs = job.get('needs', [])
        for need in [needs] if isinstance(needs, str) else needs:
            if need not in jobs:
                problems.append(f'{where}: needs {need}, which is not a job')
        lint_steps(where, job.get('steps', []), problems)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--require-yaml', action='store_true')
    args = parser.parse_args(argv)
    try:
        import yaml  # noqa: F401
    except ImportError:
        print('lint_workflows: PyYAML is not installed; skipped (pre-commit installs it)')
        return 1 if args.require_yaml else 0
    files = sorted((ROOT / '.gitea' / 'workflows').glob('*.yml')) + sorted((ROOT / '.gitea' / 'actions').glob('*/action.yml'))
    problems = []
    for path in files:
        lint_workflow(path, problems)
    for problem in problems:
        print(problem)
    print(f'lint_workflows: {len(files)} file(s), {len(problems)} problem(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
