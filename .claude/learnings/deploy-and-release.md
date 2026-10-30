# Deploy and release

## Deploying to a live install (maintainer's machine)

The maintainer has a local deploy script outside this repository. Its behavior, which matters when a workflow depends on it:

- it copies only *payload* files that changed (addon files, not tests, tools or docs) from a worktree into the live addon
  directory and refuses if any live file differs from the expected base revision;
- it records each deploy in a ledger and needs `git diff --no-renames` to see moved files, or a moved file leaves a stale
  copy in the live directory;
- writing into the live directory is treated as a production deploy: an agent does not do it unless it was granted
  explicitly; the maintainer runs it;
- **deploy only after the checks pass**; never chain it after a test loop with `;` (a failing suite once still deployed).
  Use `&&` only with a command whose exit status really reports failure, or run the steps separately and look at each result.

Each load-on-demand module needs its own symlink in a development install (`Modules/README.md`).

## Releasing

Procedure: `docs/release/RELEASING.md`. Rules to remember:

- The **tag name is the version** and decides alpha, beta or release (the packager's rule: the word `alpha`, else `beta`, else
  release). `2.0.0-rc.1` is a release. Tag exactly `X.Y.Z-beta.N` for betas.
- **Gitea is the source of truth; GitHub is a push mirror.** Never create or edit a release, push, merge or move a tag on
  GitHub. A release is a database object on each forge and does not cross a mirror; the Gitea release reaches GitHub through
  Gitea's own webhook. The old `.github/workflows/main.yml` would upload from the GitHub side; do not rely on it.
- **WoWInterface has no beta channel** and the packager does not gate it: a beta uploaded there becomes the current download
  for everybody. The release plan skips it for beta and alpha tags unless the repository variable `WOWI_UPLOAD_BETA` is `true`.
- **Secrets** (`CF_API_KEY`, `WOWI_API_TOKEN`, `WAGO_API_TOKEN`, optional `RELEASE_TOKEN`) live only in the repository's Actions
  secrets. No file, log line, artifact or message ever contains a value. Never ask for one.
- The release package is produced by the **vendored BigWigs packager** (`tools/vendor/bigwigs-packager/`, pinned by commit and
  SHA-256) driven by `.pkgmeta`; `tools/package_release.py` reproduces it offline and `--parity` proves they agree. The
  package is checked before anything uploads (`--check-zip`).
- Hand-written release notes (`docs/release/notes/<tag>.md`) are required for a stable tag. Commit subjects are not release
  notes.
- A tag must be on a commit that is on the default branch; the version is not edited anywhere (`@project-version@`).
- The SavedVariables migration of 2.0 is one-way. Betas must tell testers to back up first.
