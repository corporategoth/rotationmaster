#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Concise release notes for a tag. No network, no model: git and the hand-written notes only.

  python3 tools/release_notes.py --tag 2.0.0-beta.1 --target gitea          the Gitea release body
  python3 tools/release_notes.py --tag 2.0.0-beta.1 --target curseforge     the CurseForge changelog (.pkgmeta manual-changelog)
  python3 tools/release_notes.py --tag 2.0.0 --require-curated              fail when docs/release/notes/2.0.0.md is missing

Source of the notes, in order:

1. `docs/release/notes/<tag>.md` (or the tag without a leading "v"): the hand-written summary the
   maintainer writes before tagging. Used as written, minus HTML comments.
2. Otherwise a summary of the commit subjects since the previous tag on the first-parent history
   (merges name their branch's work; plain commits name themselves), grouped by conventional
   prefix, de-noised (no test, chore or worktree chatter, no duplicates), and capped at
   --max-lines bullet lines with a count of what was left out.

The previous tag is the nearest earlier one; for a stable tag, alpha and beta tags are skipped, as the
packager does. A link to the full comparison is added when the repository URL is known
(--changelog-url, or GITHUB_SERVER_URL and GITHUB_REPOSITORY, which Gitea Actions sets).
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
NOTES_DIR = 'docs/release/notes'

CONVENTIONAL = re.compile(r'^(feat|fix|perf|docs|test|tests|chore|refactor|build|ci|style|revert)(\([^)]*\))?(!)?:\s*(.+)$', re.I)
MERGE = re.compile(
    r"^Merge (?:pull request #\d+ from \S+|(?:remote-tracking )?branch '[^']+'(?: into \S+)?|(?:claude|coord|codex)/[\w./-]+)"
    r"(?:\s*[:,-]\s*|\s*$)(.*)$", re.I)
# Subjects that say how the work was done, not what changed for a player or a developer reading the notes.
NOISE = [re.compile(p, re.I) for p in (
    r'^(wip|fixup!|squash!|amend!)',
    r'^merge\b',
    r'\b(fix(es|ed)?|repair(s|ed)?|update[sd]?|adjust(s|ed)?|unflake[sd]?)\s+(the\s+)?(flaky\s+)?(unit\s+)?tests?\b',
    r'^(add(s|ed)?|update[sd]?)\s+tests?\b',
    r'\b(worktrees?|scratchpad|checkpoint)\b',
    r'\b(byte-freeze|predecessor|inverse (check|test)s?|lint baseline|pin the)\b',
    r'^(regenerate[sd]?|refresh(ed)?)\b',
    r'^(typo|whitespace|formatting)\b',
)]
MAINTENANCE_TYPES = {'docs', 'test', 'tests', 'chore', 'refactor', 'build', 'ci', 'style'}
FIX_WORDS = re.compile(r'^(fix|fixes|fixed|correct|corrects|repair|resolve|stop|prevent)\b|\b(bug|crash|error|regression)\b', re.I)
PERF_WORDS = re.compile(r'\b(faster|performance|garbage|allocation|cpu|memory|idle gate|lean engine)\b', re.I)
FEATURE_WORDS = re.compile(r'^(add|adds|added|new|support|supports|introduce|introduces|allow|allows|show|shows)\b', re.I)
MAX_LINE = 140


def git(root, *args):
    done = subprocess.run(['git', '-C', str(root), *args], capture_output=True)
    return done.stdout.decode('utf-8', 'replace').strip() if done.returncode == 0 else ''


def release_type(tag):
    lowered = (tag or '').lower()
    return 'alpha' if 'alpha' in lowered else 'beta' if 'beta' in lowered else 'release'


def previous_tag(root, tag):
    """The nearest earlier tag; a stable release skips alpha and beta tags, a beta skips only alphas."""
    excludes = ['--exclude=*[Aa][Ll][Pp][Hh][Aa]*']
    if release_type(tag) == 'release':
        excludes.append('--exclude=*[Bb][Ee][Tt][Aa]*')
    start = f'{tag}^' if git(root, 'rev-parse', '-q', '--verify', f'refs/tags/{tag}') else 'HEAD'
    return git(root, 'describe', '--tags', '--abbrev=0', *excludes, start)


def curated_notes(root, tag, notes_dir=NOTES_DIR):
    for name in dict.fromkeys([tag, tag[1:] if tag[:1] in 'vV' else tag]):
        path = Path(root) / notes_dir / f'{name}.md'
        if path.is_file():
            text = re.sub(r'<!--.*?-->', '', path.read_text(encoding='utf-8'), flags=re.S)
            lines = text.strip().splitlines()
            while lines and lines[-1].strip() == '':
                lines.pop()
            return path, '\n'.join(lines).strip()
    return None, ''


def clean(subject):
    """One display line from a commit subject, or None when it is noise or says nothing."""
    text = subject.strip()
    merge = MERGE.match(text)
    if merge:
        text = merge.group(1).strip()
    if not text:
        return None, None
    kind = None
    conventional = CONVENTIONAL.match(text)
    if conventional:
        kind, text = conventional.group(1).lower(), conventional.group(4).strip()
    if kind in MAINTENANCE_TYPES:
        return 'maintenance', text
    if any(pattern.search(text) for pattern in NOISE):
        return 'maintenance', text
    if len(text) > MAX_LINE:
        cut = re.split(r'[;]| - ', text, maxsplit=1)[0]
        text = (cut if 20 <= len(cut) <= MAX_LINE else text[:MAX_LINE - 1].rstrip()) + ('' if 20 <= len(cut) <= MAX_LINE else '…')
    text = text[0].upper() + text[1:]
    text = text.rstrip('.')
    if kind is None:
        kind = 'fix' if FIX_WORDS.search(text) else 'perf' if PERF_WORDS.search(text) else 'feat' if FEATURE_WORDS.search(text) else 'change'
    return kind, text


def generated_notes(root, since, max_lines, include_noise=False):
    """Grouped bullet lines from the first-parent subjects since `since`, capped."""
    span = f'{since}..HEAD' if since else 'HEAD'
    subjects = git(root, 'log', '--first-parent', '--format=%s', span).splitlines()
    groups = {'feat': [], 'fix': [], 'perf': [], 'change': []}
    seen, maintenance = set(), 0
    for subject in subjects:
        kind, text = clean(subject)
        if kind is None:
            continue
        key = re.sub(r'\W+', ' ', text.lower()).strip()
        if key in seen:
            continue
        seen.add(key)
        if kind == 'maintenance' and not include_noise:
            maintenance += 1
        else:
            groups.get(kind, groups['change']).append(text)
    titles = [('feat', 'New'), ('fix', 'Fixed'), ('perf', 'Performance'), ('change', 'Changed')]
    lines, left_out, used = [], 0, 0
    for key, title in titles:
        items = groups[key]
        room = max(0, max_lines - used)
        shown = items[:room]
        left_out += len(items) - len(shown)
        if shown:
            lines.extend([f'### {title}'] + [f'- {item}' for item in shown] + [''])
            used += len(shown)
    if left_out:
        lines.append(f'- ...and {left_out} more change{"s" if left_out != 1 else ""}; see the full changelog.')
    if maintenance:
        lines.append(f'- {maintenance} internal change{"s" if maintenance != 1 else ""} (tests, tooling, generated files) not listed.')
    return '\n'.join(lines).strip(), len(subjects)


def repo_url(explicit=None):
    if explicit:
        return explicit.rstrip('/')
    server, repository = os.environ.get('GITHUB_SERVER_URL'), os.environ.get('GITHUB_REPOSITORY')
    return f'{server.rstrip("/")}/{repository}' if server and repository else None


def strip_markdown(text):
    text = re.sub(r'^#{1,6}\s*', '', text, flags=re.M)
    text = re.sub(r'\*\*(.+?)\*\*|__(.+?)__', lambda m: m.group(1) or m.group(2), text)
    text = re.sub(r'`([^`]*)`', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1 (\2)', text)
    return re.sub(r'^\s*[-*]\s+', '- ', text, flags=re.M)


def render(tag, body, target, previous, url, kind, guide=None):
    link = None
    if url and tag:
        link = f'{url}/compare/{previous}...{tag}' if previous else f'{url}/commits/tag/{tag}'
    parts = []
    if target in ('curseforge', 'gitea'):
        label = {'beta': ' (beta)', 'alpha': ' (alpha)'}.get(kind, '')
        parts.append(f'## {tag}{label}' if target == 'curseforge' else '')
        if kind != 'release':
            parts.append('**This is a test release.** Back up your saved variables before installing, and report problems '
                         f'as described in the beta guide ({guide or "docs/release/BETA.md"}).')
    parts.append(body)
    if link:
        parts.append(f'Full changelog: {link}')
    text = '\n\n'.join(part for part in parts if part).strip() + '\n'
    return strip_markdown(text) if target == 'text' else text


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--tag', help='The tag being released (default: the tag on HEAD, else the latest tag).')
    parser.add_argument('--previous', help='Compare against this tag instead of finding the previous one.')
    parser.add_argument('--target', choices=['markdown', 'curseforge', 'gitea', 'text'], default='markdown')
    parser.add_argument('--max-lines', type=int, default=25, help='Bullet lines in a generated summary (default 25).')
    parser.add_argument('--notes-dir', default=NOTES_DIR)
    parser.add_argument('--require-curated', action='store_true', help='Fail when there is no hand-written notes file.')
    parser.add_argument('--include-noise', action='store_true', help='List internal commits too.')
    parser.add_argument('--changelog-url', help='Repository web URL for the compare link.')
    parser.add_argument('--beta-url', help='Web address of the beta guide, for the test-release notice (default: its path in the repository).')
    parser.add_argument('--out', type=Path, help='Write here instead of standard output.')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    tag = args.tag
    if not tag:
        on_head = git(root, 'tag', '--points-at', 'HEAD', '--sort=-v:refname').splitlines()
        tag = on_head[0] if on_head else (git(root, 'describe', '--tags', '--abbrev=0') or 'Unreleased')
    previous = args.previous or previous_tag(root, tag)
    path, body = curated_notes(root, tag, args.notes_dir)
    if body:
        source = f'curated notes {path.relative_to(root)}'
    else:
        if args.require_curated:
            print(f'release_notes: no hand-written notes for {tag}: write {args.notes_dir}/{tag}.md before tagging', file=sys.stderr)
            return 1
        body, count = generated_notes(root, previous, args.max_lines, args.include_noise)
        source = f'generated from {count} commit subject(s) since {previous or "the first commit"}'
        if not body:
            body = '- Internal changes only.'
    print(f'release_notes: {tag} ({release_type(tag)}), {source}', file=sys.stderr)
    text = render(tag, body, args.target, previous, repo_url(args.changelog_url), release_type(tag), args.beta_url)
    if args.out:
        args.out.write_text(text, encoding='utf-8')
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
