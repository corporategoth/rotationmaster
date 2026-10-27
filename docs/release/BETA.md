# Rotation Master 2.0 beta: guide for testers

Thank you for testing. Rotation Master 2.0 is a large rewrite of the 1.x addon, released first as a **beta** (version names
like `2.0.0-beta.1`). It works offline-tested against models of every supported game client, but most of it has never run in
a real client. Your reports are what turn it into a release.

**Read the three boxes before you install.**

> **Back up first.** 2.0 converts your saved data on first load, and the conversion cannot be undone. Copy your saved
> variables file (see "Back up and restore") before you install.
>
> **Your old rotations wait for you.** Rotations saved by 1.x have no recorded owner, so after the conversion they are in
> an archive and do not run until you adopt them. Rotation Master says so once in chat and shows a banner in the settings
> window. Choose Rotations, then Recover unassigned rotations, and adopt them one by one, or all at once for your class.
>
> **Install the whole package.** The zip contains 18 folders (`RotationMaster`, one per class `RotationMaster_<Class>`, and
> four `RotationMaster_*Text` translation folders). Copy all of them into `Interface/AddOns`. Without the class folders
> there are no Built In rotations.
>
> **It is a beta.** Expect rough edges. Do not use it for content where a broken rotation would cost you or your group
> something you care about.

## What is in 2.0 (at a glance)

- **A new rotation editor** with cards and a tree, a library of rotations with Class and Character scopes, tags and search,
  drafts with undo and redo, unsaved-change guards, and Compare / Preview / Check for imported rotations.
- **About 155 Built In rotations** for Classic Era / Season of Discovery, TBC Anniversary, Mists, Forever and Retail, shipped as
  one small add-on per class so only your class and client load. Enable, disable and re-prioritize them per profile; each
  specialization has one recommended premade enabled and alternatives off.
- **Many more conditions**, talent trees named instead of numbered, a talent picker with a "Show talent tree" window on Retail
  and Forever, rune and Assisted Combat conditions, Branch and Stop steps, a live "currently matches" bar, and custom Lua
  conditions with a code editor.
- **Retail and Forever support** with the game's restricted ("secret") combat data handled explicitly: a condition either reads
  what the game allows, is shown as unavailable, or does not exist on that client.
- **Faster**: an idle gate, a lean evaluation engine, much less garbage per poll.
- **Integrations**: Masque, Questie, boss-mod timers, more action-bar addons, tooltips that show your item sets and rotations.
- **Ten languages**, following the game's language.
- **Not supported: WowSims.** Rotation Master does not import or export WowSims rotations; rotations travel as Rotation
  Master exports. Early test builds had a converter, removed because of the WowSims maintainers' attitude toward addon
  developers they consider beneath them (they indicated that community submissions supporting small addons, with only
  around 200,000 downloads, are not wanted).
- **Replaced**: the 1.x windows (built on AceGUI) are gone; every window is now native.

The list of every renamed Built In is in `docs/builtin-name-changes.md`.

## Supported clients

| Client | Interface | Verified in a real client |
| --- | --- | --- |
| TBC Anniversary 2.5.6 | 20506 | Yes: startup, settings, the copy window and buttons |
| Retail (Midnight) 12.1.5 | 120105 | Partly: some restricted-data probes only |
| Forever 1.60.1 | 16001 | Loads; startup and play not verified |
| Classic Era / SoD 1.15.9 | 11509 | No |
| Wrath of the Lich King Classic 3.4.5 | 30405 | No |
| Wrath Titan Reforged 3.80.2 | 38002 | No |
| Cataclysm Classic 4.4.2 | 40402 | No |
| Mists of Pandaria Classic 5.5.4 | 50504 | No |

"No" means only tests with a model of the client have run. Reports from those clients are the most valuable.

## Install the beta

**CurseForge app.** Open the Rotation Master page, then change its **Release Type** to **Beta** (the app only offers beta
files for an addon once you allow them). Update. Check that `AddOns` now has `RotationMaster` and all the
`RotationMaster_*` folders.

**Wago Addons app or WowUp.** Set the addon's release channel to beta. WoWInterface does not carry betas.

**By hand.** Download `RotationMaster-<version>.zip` from the release page of the project, close the game, and extract the zip
*into* `Interface/AddOns` (so that `RotationMaster` and the 14 module folders sit side by side). Delete the old
`RotationMaster` folder first.

The version appears in the Settings > About page and in the startup message. If it still says `@project-version@`, you are
running a development copy, not the package.

## Back up and restore your saved variables

Everything Rotation Master stores is in one file per account (`RotationMasterDB`):

```
World of Warcraft/<client folder>/WTF/Account/<ACCOUNT>/SavedVariables/RotationMaster.lua
```

where `<client folder>` is `_retail_` (Retail), `_classic_era_` (Classic Era), `_anniversary_` (TBC Anniversary), `_classic_`
(Wrath, Cataclysm and Mists Classic) or `_forever_` (Forever). The same folder may hold `RotationMaster.lua.bak`, which the
game keeps as its own previous copy. Copy both.

**Back up (before installing):** quit the game, copy `RotationMaster.lua` (and `.bak`) somewhere safe, for example to a
dated folder. Do this for each account you play with it.

**Restore (to return to your old data):** quit the game, put the copy back in the same place (replace the file). Do not
restore while the game is running; it rewrites the file on logout.

The profile conversion is **not reversible**: after 2.0 has run, version 1.x does not understand what it saved. Restoring your
backup is the way back.

## Go back to 1.x

1. Quit the game.
2. Delete the `RotationMaster` folder and every `RotationMaster_*` folder from `Interface/AddOns`. Leftover module folders are
   harmless but confusing.
3. Restore your backed-up `RotationMaster.lua`.
4. Install the last release, 1.4.3e: in the CurseForge app set the Release Type back to **Release**, or take 1.4.3e from the
   project's file list.

## Report a problem

Please report with as much of this as you can; every item saves a round trip.

1. **What you did and what you expected** (one or two sentences). If it concerns one rotation, its **identifier** (`/rm list`).
2. **Client and version**: which client (Retail, TBC Anniversary, ...), the build from `/dump GetBuildInfo()`, your class and
   specialization, and the Rotation Master version from Settings > About.
3. **`/rm errors`** : click Copy, press Ctrl+C, paste. If there is a Lua error, paste the BugSack (or default error frame)
   text instead or as well.
4. **`/rm why`** : why each rotation can or cannot be chosen right now.
5. **A button does not light up: `/rm debug glow`** while it is happening, copy the window. For the Retail or Forever talent
   lists: `/rm debug talents`.
6. **Slow or heavy?** `/rm perf cpu` (then `/rm perf cpu report`), and say what else is loaded.

Where to send it:

- the project's issue tracker (linked from the CurseForge page and the addon's TOC),
- the project Discord: https://discord.gg/4aKZSpUMet,
- or email feedback@neuromancy.net.

Do not attach your whole saved variables file unless asked; it contains your rotations and character names.

## Known risks: what has never run in a real client

These are the features most likely to misbehave. If you can exercise one, please tell us what happened, good or bad.

1. **Talent picker and "Show talent tree" window** (Retail, Forever): modeled only; whether driving Blizzard's talent window
   taints anything is unverified.
2. **Tooltips** that add item-set and rotation lines: untested in and out of combat on Retail and Forever, with other
   tooltip addons, and for doubled lines on the Classic clients. If you see "blocked action" errors naming Rotation Master,
   turn tooltips off (Settings) and report it.
3. **Retail and Forever restricted data**: only health, the global cooldown and cast IDs have been probed. A condition that
   shows "unavailable" in combat when it should work is a useful report.
4. **Assisted Combat and button glow** on Retail: glow animations have been iterated, not proven everywhere.
5. **Classic Era / SoD, Wrath, Titan, Cataclysm, Mists, Forever**: no in-game acceptance of startup or rotations yet.
6. **The packaged layout**: 14 add-ons moved out of one folder. Only symlinked installs have been run, never the zip.
7. **Integrations** (Masque, Questie, boss mods, EllesmereUI, Dominos) and the native profiler: tested with fakes only.
8. **Translations**: ten languages, not all strings are translated and none are guaranteed reviewed by a native speaker.
9. **Premade quality**: the Built In rotations follow public guides; they are a starting point, not proof of an optimal rotation.

## Thanks

If something is wrong, it helps to know even if you are not sure it is a bug.
