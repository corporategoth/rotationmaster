# Git and worktrees

## Destructive commands are forbidden

Never run `git reset` (any form), `git checkout -- <path>`, `git restore`, `git clean`, `git stash`, `git switch -f`,
`git merge --abort`, `git rebase --abort`, `git worktree remove -f`, force pushes, or any "sync" step that resolves to one of
them. Two things have gone wrong, both more than once: you clobber another agent's uncommitted work in the same checkout, and
you reset for one reason and forget what else was uncommitted (unstaged changes were never git objects: no reflog, no
recovery). Revert by reading the file and editing it. If the tree is dirty and that blocks you, say so and stop.
A restore of a single file you know you broke, written from `git show HEAD:<path>`, is a deliberate edit and fine; a bulk
command is not.

Commit explicit paths only (`git add <file>`; never `-A`, `.`, or `commit -a`): a concurrent agent that stages a whole file
sweeps your uncommitted edit into its commit, and the reverse.

## One worktree per topic

The repository has many worktrees (dozens, in different states). Work in your own: `git worktree add -b claude/<topic>
<dir> <base>` from a clean base, and keep the topic small. Branch names: `claude/<topic>` for agent work, `coord/<topic>`
where a coordinator integrates. An integration branch collects merged topic branches (`Merge claude/<topic>: <what changed for
a reader>`); merge with a merge commit, not a squash, so the history, `git describe` and the changelog range survive.

The main checkout of the repository may be the live install: its working tree can carry a large "deployed payload overlay"
(modified and untracked files that are copies of the integration branch). It is not a source of truth. Never tag, build,
clean, reset or commit from it.

## Pushing

`push.default=upstream` can send a worktree branch to the wrong remote branch. Push with `--no-track` and an explicit
`src:dst` (`git push --no-track origin claude/topic:claude/topic`). Do not push the default branch from a topic worktree.
When a push needs a signature or credential approval that is not available, stop; do not retry with another credential.
Batch network calls; do not fetch repeatedly.

## Finding where something went

`git log -S'<exact text>' --oneline -- <path>` finds the commit that added or removed a string; `git log --first-parent` is the
integration history; `git show <sha>:<path>` reads a past version without touching the tree.

## No leftovers

No `.bak`, `.orig` or scratch files in the tree; scratch goes outside the repository. Generated build output (`.release/`,
`dist/`, `CHANGELOG.md` at the root) is ignored and never committed.
