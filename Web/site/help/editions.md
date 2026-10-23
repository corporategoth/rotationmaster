# Game editions

Rotation Master runs on several World of Warcraft editions, but they do not all give addons the same information. This page explains what to expect on each.

| Edition | Status |
|---|---|
| **TBC Anniversary** | The main edition RM is developed and tested on. Built In rotations are written for it. |
| **Classic Era** (including seasonal and hardcore realms) | Supported, with the full set of conditions. Less tested in the live game. |
| **Classic progression** (Wrath, Cataclysm, Mists) | Supported, with the full set of conditions. Less tested in the live game. |
| **Forever** | Loads, with restricted combat data (see below). Not yet verified in the live game. |
| **Retail** | Loads, with restricted combat data (see below). Not yet verified in the live game. |

If the game says the addon is out of date for your client, tick *Load out of date AddOns* on the AddOns screen, and tell us on [Discord](https://discord.gg/4aKZSpUMet) how it goes.

## Built In rotations

The Built In rotations are leveling previews for **TBC Anniversary**, covering every TBC class from level 1 into the 40s or 50s depending on the class. They adapt published leveling guides into a modest priority list and are not complete or optimal for every situation. They appear only for their own class and level range. Open the [Viewer](/viewer) and choose **Bundled rotations** to read the current set.

On other editions you build your own rotations, or use ones [other players have shared](/shares) for your edition.

## Restricted combat data (Retail and Forever)

On Retail and Forever, the game restricts what addons can read about units in combat. RM respects that: conditions that need restricted data (for example a unit's health, stats, threat, creature type or recent combat events) are **reference only**. They stay in your rotations and are shown, but cannot be evaluated, so they never match, even inside **Not**.

Built In rotations are also reference only there, and announcements triggered by casts do not run on reference-only clients.

## Spell ranks

Classic editions have spell ranks. RM's spell actions and conditions use the ranks you have learned; options such as **Use this exact spell rank** and **Match all ranks** let you be more precise. These options are not shown where ranks do not exist.

## Talents

**Primary Talent Tree** and **Talent Tree Points** work with the Classic talent-tree layout. Clients with a different talent system keep the condition but cannot evaluate it.

## Item-set macros

The `/click RM_…` item-set macro buttons ([Item sets](/help/item-sets#macros)) are only available where the client still allows that kind of secure button.

## Dual specialization names

Classic editions with dual specialization can give each specialization a display name in [General](/help/general#specialization-names).
