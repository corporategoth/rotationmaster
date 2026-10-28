# Rotation Master

Rotation Master is a World of Warcraft addon that tells you the next spell or item to use and lights the matching button on
your action bars. You describe a *rotation* as an ordered list of steps with conditions, or start from one of about 155
*Built In* rotations, and the addon follows your game: your target, your cooldowns, your talents, your gear.

Version 2.0 is a rewrite of the 1.x addon (new editor, Built In rotations for five client families, Retail and Forever support,
ten languages). It is released as a beta first: see [docs/release/BETA.md](docs/release/BETA.md) before installing.

## Supported clients

| Client | Interface |
| --- | --- |
| Classic Era / Season of Discovery 1.15 | 11509 |
| TBC Anniversary 2.5 | 20506 |
| Wrath of the Lich King Classic 3.4 | 30405 |
| Wrath Titan Reforged 3.80 | 38002 |
| Cataclysm Classic 4.4 | 40402 |
| Mists of Pandaria Classic 5.5 | 50504 |
| Retail (Midnight) 12.1 | 120105 |
| WoW Forever 1.60 | 16001 |

What has been run in a real client and what has not is in [docs/quality/client-support.md](docs/quality/client-support.md).
The game language is used automatically (English, German, Spanish, Latin American Spanish, French, Italian, Korean,
Brazilian Portuguese, Russian, Simplified and Traditional Chinese).

## Install

- **CurseForge, Wago Addons, WowUp:** search for Rotation Master. Betas appear only if you choose the beta release type.
- **WoWInterface:** stable releases only.
- **By hand:** download the zip from the release page, close the game and extract it into `Interface/AddOns`. The zip holds 18
  folders (`RotationMaster`, one `RotationMaster_<Class>` per class, four `RotationMaster_*Text` translation folders); all
  of them must be there.

Open the settings and rotation editor with `/rm config`. `/rm help` lists the commands.

## WowSims is not supported

Rotation Master does not import or export WowSims rotations. Test builds of 2.0 had a WowSims converter in the rotation
transfer window; it was removed before release. The reason is the WowSims maintainers' attitude toward addon developers they
consider beneath them: they indicated that community submissions supporting small addons, with only around 200,000 downloads,
are not wanted. Rotation Master therefore no longer supports their project, and the pull requests sent to their repositories
were closed. Rotations move between players as Rotation Master exports, which is the only transfer format.

## Documentation

| For | Start at |
| --- | --- |
| Testers | [docs/release/BETA.md](docs/release/BETA.md) |
| Contributors | [CONTRIBUTING.md](CONTRIBUTING.md), then [docs/dev/](docs/dev/architecture.md) |
| Translators | [docs/translators/README.md](docs/translators/README.md) |
| Maintainers | [docs/release/RELEASING.md](docs/release/RELEASING.md) |
| Topic references | [docs/architecture/](docs/architecture), [docs/quality/](docs/quality), [Modules/README.md](Modules/README.md) |

## Building and testing

```sh
python3 tools/setup_lint.py        # once: the pinned static checker
python3 tools/check --static       # about 20 seconds
python3 tools/check_all.py --baseline tools/known_failures.txt   # the whole suite, Lua 5.1 and LuaJIT (tens of minutes)
python3 tools/package_release.py --check
```

Requirements are `python3`, `lua5.1` and `luajit`. See [docs/dev/running-things.md](docs/dev/running-things.md).

## Source, issues and contact

The source of truth is the project's Gitea repository; the GitHub repository is a mirror. Report problems with the issue
tracker linked from the addon's TOC, on the [Discord](https://discord.gg/4aKZSpUMet), or by email to feedback@neuromancy.net.

## License

A modified MIT license, "MIT + Attribution" ([LICENSE](LICENSE)), Copyright 2018-2026 Preston A. Elder: use, copy, fork,
modify and redistribute freely, but a derivative's credits or About pages, including in game, must acknowledge
Rotation Master and its original author, PreZ. Versions up to 1.4.3e were plain MIT
and may continue to be used under it. Vendored libraries keep their own
licenses (`Libs/UPSTREAM.json`, `Libs/Ace3-LICENSE.txt`); the monospace font is under the SIL OFL (`Fonts/OFL.txt`).
Built In rotations written from the WowSims simulators' APLs carry the simulators' MIT notice in `THIRD_PARTY_NOTICES.md`,
which ships with the addon.
