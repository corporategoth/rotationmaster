# Getting started

This page takes you from installing the addon to your first highlighted spell.

## 1. Install the addon

Install **Rotation Master** like any other addon, with your addon manager (it is published on CurseForge, Wago and WoWInterface) or by copying the `RotationMaster` folder into your game's `Interface/AddOns` folder. Then start the game, or type `/reload` if it is already running.

On the character select screen, make sure **Rotation Master** is enabled in the AddOns list. If the list says it is out of date for your game version, see [Game editions](/help/editions).

## 2. Open the settings window

Type `/rm config` in chat, or left-click the Rotation Master icon on your minimap. The settings window (the *workbench*) opens on the **Rotations** tab.

> **Tip:** Right-click the minimap icon for a quick menu: turn recommendations on or off, pick a rotation, or go back to automatic switching.

## 3. Pick a rotation

The list on the left is your **rotation roster**.

- **Built In** rotations (shown in blue) come with the addon. They are read-only, and appear only for the class they were written for. You can turn them on or off, read every card, or **Duplicate** one to get an editable copy.
- **Custom** rotations are yours to edit.

If a Built In rotation exists for your class and level, it may already be working: see whether something on your action bars is highlighted when you target an enemy.

If not, choose **New rotation** below the roster, or **Duplicate** a Built In one to start from it.

## 4. Add a few actions

In the editor, choose **Add action**. Click the new card's action text to open its fields, choose **Spell** and type the spell's name (or drag it from your spellbook into the field). Add two or three of your main abilities in order of importance, most important first.

Then choose **Apply**. Edits stay in a private draft until you do; **Discard** throws them away.

```diagram
Rotation "My first rotation"
 1. Spell: Judgement        ← highest priority
 2. Spell: Crusader Strike
 3. Spell: Consecration     ← only when 1 and 2 are not
```

## 5. See it work

Put those spells on your action bars, target a training dummy or an enemy, and enter combat. The first spell in your list that is ready to use gets a highlight on its action bar button. As cooldowns come and go, the highlight moves.

If nothing lights up, check [Troubleshooting](/help/troubleshooting#nothing-is-highlighted).

## 6. Make it smarter

Once the basics work:

- Add [conditions](/help/conditions) to a card so it is used only when something is true ("only if the target does not already have my debuff").
- Add [cooldowns](/help/cooldowns) for things you want reminding about separately, like a big defensive cooldown or a health potion.
- Give the rotation a [switch condition](/help/switching) so RM picks it automatically, for example only in a group, or only in a certain form.
- Show the next few recommendations in a small window with **Preview Spells** in [General](/help/general#preview-window).

## Where next?

- [How recommendations work](/help/how-it-works) explains exactly what RM checks before it highlights something.
- [Importing, exporting and sharing](/help/sharing) shows how to use rotations other players have published.
