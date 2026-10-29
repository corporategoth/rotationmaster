# Releasing Rotation Master

How a release is made, what CI does, what to check afterwards and how to back out. The version is the **tag name**; nothing
in the repository is edited to bump it (`## Version: @project-version@` in every TOC is replaced by the packager).

## Tag names decide everything

| Tag | Type | CurseForge | Wago | WoWInterface | Gitea release |
| --- | --- | --- | --- | --- | --- |
| `2.0.0` | release | release file | stable | uploaded | full release |
| `2.0.0-beta.1` | beta | beta file | beta | **not uploaded** (no beta channel; set the variable `WOWI_UPLOAD_BETA=true` to upload anyway) | prerelease |
| `2.0.0-alpha.1` | alpha | alpha file | alpha | **not uploaded** (same variable) | prerelease |

The packager's rule, which `tools/release_plan.py` states in the log before uploading anything: the word `alpha` anywhere in
the tag makes an alpha, else the word `beta` makes a beta, else it is a **release**. So `2.0.0-rc.1` is a release and would
reach every stable user; do not use `rc` or any name that lacks `beta` or `alpha` for a test build. Use `2.0.0-beta.N` until
the final `2.0.0`. A tag must start with a digit (optionally after `v`) or the release workflow does not run.

CurseForge and Wago order files by upload time, not by version, so `2.0.0-beta.1 < 2.0.0` is only a naming convention. Nothing
in the addon compares versions.

## One-time setup

Repository **Settings > Actions > Secrets** (never in a file; the workflows and tools never ask for the values):

| Secret | Used for |
| --- | --- |
| `CF_API_KEY` | CurseForge upload (project id 301085, from `## X-Curse-Project-ID`). Create it under the CurseForge account's API tokens |
| `WAGO_API_TOKEN` | Wago Addons upload (project `vEGPM4N1`, from `## X-Wago-ID`) |
| `WOWI_API_TOKEN` | WoWInterface upload (addon 25079, from `## X-WoWI-ID`); stable tags and, with the variable, betas |
| `RELEASE_TOKEN` | *Optional.* A Gitea access token with permission to write releases, if the workflow's built-in token cannot |

Optional **variables** (Settings > Actions > Variables): `WOWI_UPLOAD_BETA=true` (also upload betas to WoWInterface) and
`BETA_GUIDE_URL` (the public web address of `docs/release/BETA.md`, used in the test-release notice on CurseForge and the Gitea
release; without it the notice names the file's path in the repository).

Nothing is passed to GitHub: it is a push mirror, a release is a Gitea object, and GitHub receives it through the mirror and
its webhook, never from CI. Release workflows run on Gitea; check any future GitHub workflows before tagging so the mirror does
not trigger a second upload.

Runner assumptions (see `.gitea/workflows/test.yml`): the `ubuntu-latest` label is the Gitea Ubuntu image, root or sudo is
available, apt and the internet work, and the runner takes one job at a time. A full release run is three test jobs plus
packaging and takes the better part of an hour (the suite without the single slowest test was about 21 minutes on a loaded workstation; that test alone passes in about
35 more); the job timeouts are 120 minutes.

## Before tagging

1. **Merge** everything intended into the default branch (`master`) with a merge commit or fast-forward (no squash: tags and
   changelog ranges follow the history). A tag is only for a commit that is on `master`.
2. **Green.** The Tests workflow passes on that commit and `tools/known_failures.txt` has no entries. A release run does not use
   that file.
3. **Notes.** Write `docs/release/notes/<tag>.md` (the tag name, for example `2.0.0-beta.1.md`). It is the human summary for
   CurseForge and the Gitea release: highlights, fixes, known issues, upgrade notes; 15 to 40 lines, no commit list. A stable
   tag **requires** it; a beta falls back to a generated summary of commit subjects, which is accurate and not pleasant to read.
   Template:

   ```markdown
   ## Highlights
   - ...

   ## Fixed
   - ...

   ## Known issues
   - ...

   ## Upgrading
   - Back up your saved variables first (docs/release/BETA.md).
   ```
4. **Dry run locally**, from a clean checkout of the commit to tag:

   ```sh
   python3 tools/release_notes.py --tag 2.0.0-beta.1 --target gitea     # read the body
   python3 tools/package_release.py --tag 2.0.0-beta.1 --check          # builds .release/RotationMaster-2.0.0-beta.1.zip and checks it
   python3 tools/package_release.py --parity                            # the offline builder equals the vendored BigWigs packager
   python3 tools/release_plan.py --tag 2.0.0-beta.1 --dry-run           # sites and packager flags
   ```
5. **Install the zip** from the Tests run's `RotationMaster-<sha>` artifact (or your local build) into a clean `Interface/AddOns`
   in a real client before tagging a first beta: the layout of 14 moved modules has never run from a zip.
6. Update `docs/release/BETA.md` (supported clients, known risks) if it changed.
7. If the website pins this addon (catalogs), regenerate and release it in step with the tag.

## Tagging

```sh
git tag -a 2.0.0-beta.1 -m "Rotation Master 2.0.0-beta.1" <commit-on-master>
git push origin 2.0.0-beta.1
```

Push the tag to **Gitea** only. Do not move or delete a published tag; fix forward with the next number
(`2.0.0-beta.2`).

## What CI does (`.gitea/workflows/release.yml`)

1. **Static checks**: pre-commit on every file, workflow lint.
2. **Tests** on Lua 5.1, LuaJIT and Python (`tools/check_all.py`), with no known-failures list. Any failure stops the release.
3. **Package and publish**:
   1. confirms the checkout is the tag;
   2. `tools/release_plan.py` prints the release type, which sites will get the file and the packager flags, and fails if a
      site that should receive the file has no secret;
   3. `tools/release_notes.py` writes `CHANGELOG.md` (sent to CurseForge; `.pkgmeta` keeps it out of the zip) and the Gitea release body;
   4. verifies the vendored `release.sh` checksum, builds the package with it (`-d`, no secrets in the environment);
   5. `tools/package_release.py --check-zip` on that exact zip (only files the client loads plus license and notice files, every TOC lists files that exist, supported
      Interface numbers, no oversize file);
   6. creates or updates the **Gitea release** (prerelease for beta and alpha) with the zip attached (`tools/gitea_release.py`);
   7. runs the packager again with the secrets to upload to CurseForge, Wago and (per the table above) WoWInterface.

**Dry run.** Actions > Release > Run workflow, enter an existing tag, leave `dry_run` on: it does everything except create the
release and upload. `gitea_release` and `upload_sites` re-run only that half after a failure (the Gitea step is idempotent:
it updates the release and replaces the asset). `allow_known_failures` and `allow_missing_tokens` exist for emergencies.

## After the run: verify

- The run is green, and its log shows the plan you expected (`type=beta`, `sites=curseforge wago`).
- The Gitea release exists, is marked prerelease for a beta, has the notes and the zip.
- **CurseForge** lists a *Beta* file with the right game versions; **Wago** shows it as beta; **WoWInterface** shows no new file
  for a beta. If a game version was rejected (CurseForge may not know `38002` or `16001` yet), the upload step says so.
- The mirror on GitHub received the tag and, through the webhook, the release.
- Install the CurseForge package into a clean client and check Settings > About shows the tag as the version.

## Back out

- **A bad file on a site.** Remove or archive that file by hand on CurseForge, Wago and WoWInterface (their project pages). The
  tools cannot delete uploads. WoWInterface keeps the file as the current download until another is uploaded: for a stable
  mistake, upload the corrected version promptly.
- **A bad release on Gitea.** Edit or delete the release in the web UI (a decision for the maintainer), then fix forward.
- **A wrong tag name** (for example a stable name for a test build): remove the files from the sites first, then tag the right
  name on the same commit. Re-pushing the same tag name is not recommended: mirrors and caches keep the old object.
- **A broken beta.** Do not edit the beta. Merge the fix, write notes, tag `-beta.N+1`.
- **Players on the beta who want 1.x**: `docs/release/BETA.md`, "Go back to 1.x".

## Files that make this work

`.pkgmeta` (generated by `tools/generate_artwork_catalog.py`; the ignore list, `move-folders` for the 17 modules, the manual
changelog), `tools/package_release.py`, `tools/release_notes.py`, `tools/release_plan.py`, `tools/gitea_release.py`,
`tools/vendor/bigwigs-packager/` (the pinned upstream `release.sh`, checked against the SHA-256 in `UPSTREAM.json`),
`.gitea/workflows/{test,release,nightly}.yml`, `.gitea/actions/toolchain/action.yml`.
