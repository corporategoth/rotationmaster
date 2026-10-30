#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Install a local static gate without changing system/personal hook settings."""
import argparse
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

MARKER = b'# Rotation Master offline guard v1 (managed by tools/install_hooks.py)\n'
GUARD = MARKER + b'''(
    rotationmaster_hook_root=$(git rev-parse --show-toplevel) || exit 1
    if [ -f "$rotationmaster_hook_root/tools/check" ]; then
        python3 "$rotationmaster_hook_root/tools/check" --static
    fi
) || exit "$?"
'''
SHELLS = {b'#!/bin/sh', b'#!/usr/bin/sh', b'#!/bin/bash', b'#!/usr/bin/bash',
          b'#!/usr/bin/env sh', b'#!/usr/bin/env bash'}


def snapshot(path):
    if path.is_symlink():
        raise ValueError(f'Refusing symlink: {path}')
    try:
        info = path.stat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(info.st_mode) or info.st_size > 1024 * 1024:
        raise ValueError(f'Expected a regular hook/state file no larger than 1 MiB: {path}')
    return {'data': path.read_bytes(), 'mode': stat.S_IMODE(info.st_mode),
            'stamp': (info.st_dev, info.st_ino, info.st_mtime_ns, info.st_size)}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def installed_content(original, enabled):
    source = original if enabled else b'#!/bin/sh\n'
    first, separator, body = source.partition(b'\n')
    if first not in SHELLS:
        raise ValueError('Executable pre-commit is not a supported shell script; integrate the project gate manually.')
    if MARKER in source:
        raise ValueError('Hook already contains the RM marker without matching installation state; inspect it manually.')
    return first + b'\n' + GUARD + (body if separator else b'')


def state_original(state, backup):
    if type(state) is not dict or set(state) != {'version', 'original'} or type(state['version']) is not int or state['version'] != 1:
        raise ValueError('Unknown RM hook state; refusing to replace it.')
    record = state['original']
    saved = snapshot(backup)
    if record is None:
        if saved is not None:
            raise ValueError('Unexpected original-hook backup; inspect it manually.')
        return b'', False, 0o755
    if type(record) is not dict or set(record) != {'sha256', 'mode', 'executable'} or type(record['mode']) is not int or not 0 <= record['mode'] <= 0o7777 or type(record['executable']) is not bool:
        raise ValueError('Invalid original-hook state; refusing to replace it.')
    if saved is None or saved['mode'] != record['mode'] or digest(saved['data']) != record['sha256']:
        raise ValueError('Original-hook backup is missing or changed; refusing to replace it.')
    return saved['data'], record['executable'], record['mode'] | stat.S_IXUSR


def exclusive_write(path, data, mode):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    with os.fdopen(fd, 'wb') as target:
        target.write(data)
        target.flush()
        os.fchmod(target.fileno(), mode)
        os.fsync(target.fileno())


def hooks_directory(repo):
    output = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', '--git-common-dir'], text=True).strip()
    common = Path(output)
    if not common.is_absolute():
        common = repo / common
    # --git-path hooks would honor core.hooksPath and might target system files.
    hooks = common.resolve() / 'hooks'
    if hooks.is_symlink():
        raise ValueError(f'Refusing a symlink hooks directory: {hooks}')
    return hooks


def run(repo, install=False, check=False):
    hooks = hooks_directory(repo)
    hook = hooks / 'pre-commit'
    backup = hooks / '.rotationmaster-pre-commit.original'
    state_path = hooks / '.rotationmaster-pre-commit.json'
    current, saved_state = snapshot(hook), snapshot(state_path)
    if saved_state is not None:
        state = json.loads(saved_state['data'])
        original, enabled, mode = state_original(state, backup)
        expected = installed_content(original, enabled)
        if current is None or current['data'] != expected or current['mode'] != mode:
            raise ValueError('Installed hook changed or installation is incomplete; existing files are preserved for manual inspection.')
        print(f'RM static gate is installed: {hook}')
        return 0
    if snapshot(backup) is not None:
        raise ValueError('An unrecognized original-hook backup already exists; refusing to overwrite it.')
    enabled = current is not None and os.access(hook, os.X_OK)
    original = current['data'] if current else b''
    content = installed_content(original, enabled)
    mode = (current['mode'] | stat.S_IXUSR) if current else 0o755
    if check:
        print(f'RM static gate is not installed: {hook}')
        return 1
    if not install:
        print(f'Would install the RM static gate in {hook}; existing hook bytes/mode will be backed up. Use --install.')
        return 0
    hooks.mkdir(exist_ok=True)
    state = {'version': 1, 'original': None if current is None else {
        'sha256': digest(original), 'mode': current['mode'], 'executable': enabled}}
    # Exclusive state creation also prevents simultaneous installers sharing a
    # checkout. An interrupted attempt keeps its evidence instead of cleaning up.
    exclusive_write(state_path, (json.dumps(state, sort_keys=True) + '\n').encode(), 0o600)
    if current is not None:
        exclusive_write(backup, original, current['mode'])
    if hooks.is_symlink() or snapshot(hook) != current:
        raise ValueError('Hook changed during installation; current hook and original snapshot are preserved.')
    with tempfile.NamedTemporaryFile(prefix='.rotationmaster-hook-', dir=hooks, delete=False) as target:
        target.write(content)
        target.flush()
        os.fchmod(target.fileno(), mode)
        os.fsync(target.fileno())
        temporary = target.name
    if hooks.is_symlink() or snapshot(hook) != current:
        raise ValueError('Hook changed before publication; current hook, backup and candidate are preserved.')
    publish_candidate(Path(temporary), hook, current)
    print(f'Installed RM static gate: {hook}; original hook behavior follows successful checks.')
    return 0


def atomic_exchange(candidate, hook):
    if not sys.platform.startswith('linux') or candidate.parent != hook.parent:
        raise OSError(errno.ENOTSUP, 'Atomic hook exchange is unavailable; integrate the gate manually.')
    library = ctypes.CDLL(None, use_errno=True)
    exchange = getattr(library, 'renameat2', None)
    if exchange is None:
        raise OSError(errno.ENOTSUP, 'renameat2 is unavailable; integrate the gate manually.')
    exchange.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    exchange.restype = ctypes.c_int
    directory = os.open(hook.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        # RENAME_EXCHANGE atomically retains the actual displaced live entry.
        if exchange(directory, os.fsencode(candidate.name), directory, os.fsencode(hook.name), 2) != 0:
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code))
    finally:
        os.close(directory)


def publish_candidate(candidate, hook, current):
    if current is None:
        directory = os.open(hook.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            # Creation is exclusive: a newly appeared hook is never replaced.
            os.link(candidate.name, hook.name, src_dir_fd=directory, dst_dir_fd=directory, follow_symlinks=False)
        finally:
            os.close(directory)
        return
    atomic_exchange(candidate, hook)
    try:
        if snapshot(candidate) != current:
            raise ValueError('The live hook changed at publication.')
    except (OSError, ValueError) as error:
        try:
            atomic_exchange(candidate, hook)
        except OSError as rollback:
            raise ValueError(f'Hook publication needs manual inspection; both live entries remain at {hook} and {candidate}: {rollback}') from error
        raise ValueError(f'Concurrent hook change preserved; publication reversed. Both versions remain at {hook} and {candidate}.') from error
    print(f'Displaced live hook retained at {candidate}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--install', action='store_true')
    action.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        return run(args.repo.resolve(), args.install, args.check)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Hook setup failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
