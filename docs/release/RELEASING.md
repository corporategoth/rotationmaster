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

GitHub repository **Settings > Secrets and variables > Actions** supplies the publisher's credentials:

| Secret | Used for |
| --- | --- |
| `CF_API_KEY` | CurseForge upload (project id 301085) |
| `WAGO_API_TOKEN` | Wago Addons upload (project `vEGPM4N1`) |
| `WOWI_API_TOKEN` | WoWInterface upload (addon 25079); stable tags and explicitly enabled betas |

Presence of a secret does not prove the token is still valid. Set optional GitHub Actions variables
`WOWI_UPLOAD_BETA=true` to upload betas to WoWInterface, and `BETA_GUIDE_URL` to link the beta guide in the notes.
Gitea only needs its built-in release token, or an optional `RELEASE_TOKEN` if that token cannot write releases.

GitHub Actions is the **only** publisher to the addon sites. Each service creates its own release and attaches a
checked ZIP. The configured mirror carries tags to GitHub and the webhook synchronizes release metadata, but does
not copy assets. Do not add a second addon-site upload to Gitea or another GitHub tag workflow.

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
   in a real client before tagging a first beta. The `2.0.0-beta.1` package loaded in TBC Anniversary and ran a rotation.
6. Update `docs/release/BETA.md` (supported clients, known risks) if it changed.
7. If the website pins this addon (catalogs), regenerate and release it in step with the tag.

## Tagging

```sh
git tag -a 2.0.0-beta.1 -m "Rotation Master 2.0.0-beta.1" <commit-on-master>
git push origin 2.0.0-beta.1
```

Push the tag to **Gitea** only. Do not move or delete a published tag; fix forward with the next number
(`2.0.0-beta.2`). Before pushing, confirm the GitHub mirror's `master` has received the commit: the GitHub publisher
refuses a tag that is not reachable from its `master`.

## What CI does

A tag pushed to Gitea is mirrored to GitHub. Both services run their release workflows for the same tag:

- `.gitea/workflows/release.yml` runs static checks and Lua 5.1, LuaJIT and Python tests, builds and checks the
  package, then creates or updates the Gitea release. It does not upload to addon sites.
- `.github/workflows/release.yml` independently runs static checks and those three test suites, verifies that the tag
  points at a commit on `master`, generates the release plan and notes, checks the vendored packager, builds and checks
  the ZIP, attaches it to the GitHub release, then uploads the same ZIP to CurseForge, Wago and, when the release plan
  allows, WoWInterface. A missing required GitHub secret stops the run before uploading.

For a dry run, use **GitHub Actions > Publish addon > Run workflow**, enter an existing tag and leave `dry_run` enabled.
A manual run with `dry_run` disabled publishes to the sites; do not rerun a successful publication because the sites
may create duplicate files. Gitea's Release workflow has its own dry-run option for checking its package and release.

## After the run: verify

- Both release runs are green, and the GitHub run shows the plan you expected (`type=beta`, `sites=curseforge wago`).
- The Gitea release exists, is marked prerelease for a beta, has the notes and the zip.
- **CurseForge** lists a *Beta* file with the right game versions; **Wago** shows it as beta; **WoWInterface** shows no new file
  for a beta. If a game version was rejected, the upload step says so.
- GitHub has the tag, the correct prerelease status, and the checked ZIP attached to its release.
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
`.gitea/workflows/{test,release,nightly}.yml`, `.github/workflows/release.yml`, `.gitea/actions/toolchain/action.yml`.
