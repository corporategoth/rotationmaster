#!/usr/bin/env python3
"""Explicitly install the pinned checker locally; normal checks never download."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import sys
import urllib.request

ROOT=Path(__file__).resolve().parents[1]

def manifest():
    return json.loads((ROOT/'tools/lint-tool.json').read_text())

def host_key():
    machine=platform.machine().lower()
    machine={'amd64':'x86_64','arm64':'aarch64'}.get(machine,machine)
    return sys.platform+'-'+machine

def tool_spec():
    info=manifest()
    key=host_key()
    if key not in info['files']:
        raise ValueError(f'No pinned checker binary for {key}. See tools/lint-tool.json.')
    return info,info['files'][key]

def default_target():
    info,spec=tool_spec()
    suffix='.exe' if spec['name'].endswith('.exe') else ''
    return ROOT/'.tools'/f"wowlua_ls-{info['version']}-{host_key()}{suffix}"

def install_verified(target,payload,digest):
    target=Path(target)
    if hashlib.sha256(payload).hexdigest()!=digest:
        raise ValueError('Downloaded checker checksum does not match the pinned manifest.')
    if target.exists():
        if hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
            raise ValueError(f'Existing file differs from the pinned checker; left unchanged: {target}')
        return target
    target.parent.mkdir(parents=True,exist_ok=True)
    # Exclusive creation preserves other agents' files if another setup races us.
    with target.open('xb') as stream: stream.write(payload)
    target.chmod(0o755)
    return target

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--from-file',type=Path,help='Use an already downloaded binary, verifying the same pinned checksum.')
    args=parser.parse_args()
    try:
        _,spec=tool_spec();target=default_target()
        if target.exists(): payload=target.read_bytes()
        elif args.from_file: payload=args.from_file.read_bytes()
        else:
            with urllib.request.urlopen(spec['url'],timeout=45) as response: payload=response.read()
        print(install_verified(target,payload,spec['sha256']))
        return 0
    except (OSError,ValueError) as error:
        print(f'Checker setup failed: {error}',file=sys.stderr);return 1

if __name__=='__main__':sys.exit(main())
