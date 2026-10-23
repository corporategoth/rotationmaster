# Importing, exporting and sharing

Almost everything in Rotation Master can be turned into a block of text (an *export string*) and back. Paste it in chat, in Discord, on a forum, or on [this site](/shares). Exports are plain data: decoding one never runs anything. The only exports that *can* contain code are custom functions and custom conditions, and RM asks before installing those.

## What can be exported

| What | Where in game | Notes |
|---|---|---|
| **Rotation** | Rotations → **Import/Export** below the roster | Includes the ordered actions, cooldowns, switch condition, description, tags and metadata. Starts with `RM1:`. Custom conditions it uses are *not* included. |
| **Custom function** | Functions → **Import/Export** | A *function bundle*, optionally with the source of the helpers it depends on. Contains Lua. |
| **Custom condition** | Conditions → **Import/Export** below the list | Also a bundle, optionally with its helper functions. Contains Lua. |
| **Condition category** | Conditions → Manage categories → transfer | Just the ordered list of condition identifiers. |
| **Item set** | Item Sets → **Import/Export** | The name and the ordered items. Plain item lists separated by commas or new lines are accepted on import too. |
| **Effect** | Effects → **Import/Export** | The highlight style and its sequence. |
| **Announcement** | Announces → **Import/Export** | The trigger and all its outputs. |
| **Profile** | Profiles → **Import/Export** | A whole profile, including its rotations. |

## Exporting

Open the Import/Export dialog for the selected entry. The box is filled with its export string; **Copy** selects the text so you can press **Ctrl+C**. The button never sends anything anywhere.

## Importing

Paste the text into the same dialog. RM decodes and validates it first and tells you what it found.

- **Rotations**: choose **Preview import** to see the incoming rotation compared with the selected one, and **Inspect import** for any problems. Then import it as a **new named copy** or to **replace** the selected custom rotation. A new copy belongs to your **Class** unless you tick **This character**; a replacement keeps its owner. The imported rotation opens in the editor.
- **Item sets, effects, announcements**: import as a renamed copy or replace the selected entry, then Apply.
- **Profiles**: import as a new profile (finish creating it, then Apply), or replace the selected profile (immediate).
- **Custom functions and conditions**: choose **Review import**, read every Lua body with **Review source**, resolve any name clashes (**Reuse**, **Replace** or a new identifier), then **Apply import**. Nothing is registered until you apply.

> **Warning:** Custom functions and conditions run Lua inside your game. Read the code, and import only what you trust. If a rotation needs a custom condition, import that condition (or its bundle) first.

A rotation that refers to custom conditions or item sets you do not have is reported as *unresolved* and cannot be imported until you add them. Invalid or unsupported data is refused in the same way; **Inspect import** says exactly what is missing.

## Built In rotations

Built In rotations cannot be edited, but they can be exported, compared and copied:

- **Duplicate** creates your own editable copy. The copy keeps a note of which Built In rotation and revision it came from.
- **Compare rotations** shows what you changed, or what changed in a newer version of the Built In rotation. Updating the addon never rewrites your copy.
- Exporting a Built In rotation gives the same text anyone else would get, so it is a good way to show someone exactly what you are using.

## Sharing on this site

[Share an export](/shares/new) publishes any of the export kinds above with a title and a description, under your name. Others can [browse and search](/shares) by kind, class and game edition, read the description, see what the export contains and copy the string. Your exports are checked when you upload them, and code inside them is only ever shown as text.

You can delete your own shares at any time, and anyone signed in can report a share that is broken or harmful.

## Reading an export without installing it

The [Viewer](/viewer) decodes any export string in your browser, shows its actions, cooldowns and branches, and can compare two exports. Nothing you paste there is uploaded. It also lets you open a link that has a whole export in it, after a share link from the viewer.
