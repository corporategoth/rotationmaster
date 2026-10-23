# Integrations

Rotation Master works on its own, but can use some other addons if you have them. The **Integrations** tab lists them, grouped by type, with their status.

| Status | Meaning |
|---|---|
| **Not loaded** | The addon is not installed or not enabled, so RM cannot use it. |
| **Supported** | Available, and used automatically. |
| **Enabled** / **Disabled** | Available, and you choose whether RM uses it. |
| **Selected** | The one in use, where only one can be (such as the Lua editor). |

Click an addon's name for copyable links to its official release and source pages. The listed game editions describe what the addon's publisher says it supports, not a guarantee that it works with RM on your client. RM never installs or enables other addons for you.

Changes on this tab are saved for the current profile with **Apply**.

## Lua editor

Choose which editor opens for custom conditions and functions. The **Native** editor is always available; its **Syntax highlighting** option applies only to it. If several editors are enabled you can pick one; with none enabled, a plain text box still works. **Show line numbers** applies to every editor. Changes take effect the next time you open a code editor.

## Masque

If you have the Masque addon installed, enable it here and Apply; then the [General](/help/general#preview-window) tab's preview window gets a **Skin** choice. Masque stores the skin itself, and `/masque` opens its other settings.

## Questie

Opt in to Questie updates for the current profile and Apply. RM only reads recent updates from Questie; it does not treat them as proof of quest progress, does not switch rotations because of them, and does not poll in the background.

## Condition providers

Some condition types need another addon. For example, the **Extended Character Stat** conditions use *Extended Character Stats*. Without the provider, those conditions stay in your rotations but cannot be evaluated.
