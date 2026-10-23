# General

The **General** tab holds settings that apply to the whole addon for the current [profile](/help/profiles). Changes stay in a draft until you choose **Apply** (a few preview-window controls are the exception, noted below).

## On and off

| Setting | What it does |
|---|---|
| **Enable** | Turns recommendations, automatic rotation switching and bound item-set updates on or off. Turning it off clears all highlights and hides the preview window. |
| **Disable Bar Highlighting** | Hides the *main* recommendation on your action bars. Cooldown highlights still appear. Turn on **Preview Spells** if you still want to see the main recommendation somewhere. |
| **Minimap Icon** | Shows the minimap icon. Left-click it to open settings; right-click for a quick menu to enable RM and choose a rotation or automatic switching. |

> **Tip:** You can also bind a key to *Toggle Rotation Master* in the game's Key Bindings menu, or type `/rm toggle`.

## Timing

| Setting | Default | What it does |
|---|---|---|
| **Polling Interval** | 0.15 s | How often RM re-evaluates the active rotation and cooldowns (0.05 to 1 second). Shorter is more responsive and uses more processing time. |
| **Idle Re-check Interval** | 1 s | Out of combat with no target and no focus, RM skips a check unless something it watches changed (auras, cooldowns, health or power of you, your pet or party, movement, casting, equipment, bags, form, pets or group). It still re-checks at least this often for time-based conditions, distance and custom code. In combat, with a target or focus, or while settings are open, every check runs. **0** checks every time. |
| **Auto-Switch Re-check Interval** | 1 s | How often RM looks for a better rotation to switch to, in and out of combat (0 to 10 seconds). **0** turns automatic switching off. See [Switch conditions and auto-switching](/help/switching). |
| **Live Status Update Frequency** | 2 s | While you edit, how often condition status ("currently satisfied") refreshes. 0 turns it off. This is separate from the polling interval. |

## History

Some conditions look back in time. These control how much is remembered.

| Setting | Default | Used by |
|---|---|---|
| **Spell History Memory** | 60 s | Conditions about spells you cast recently. |
| **Combat History Memory** | 10 s | Conditions about recent hits, parries, blocks and other combat events (where the game provides them). |
| **Damage History Memory** | 30 s | Burn-rate and time-to-die estimates. Recent observations count more. |

## Highlight style

These set how the main recommendation is highlighted, and the default for [cooldowns](/help/cooldowns) (each cooldown can override them).

- **Effect** — the highlight style. Manage the styles on the [Effects](/help/effects) tab.
- **Magnification** — size relative to the action icon (1 = same size; default 1.4).
- **Highlight Color** — click the swatch for a colour picker, or type R, G, B and A between 0 and 1. A is opacity.
- **Anchor** and **V / H** offsets — where a texture highlight sits on the button. Use the arrow pad (hold **Shift** for 10-pixel steps); **Center** resets the anchor and offsets.

The icon beside these settings previews the result. Previewing never saves anything.

## Preview window

The preview window shows upcoming recommendations as a row of icons, separately from your action bars.

| Setting | What it does |
|---|---|
| **Preview Spells** | How many upcoming recommendations to show, from 0 (hidden) to 5. It shows the current priority results, not a simulation of the future. |
| **Preview window opacity** | Fades the background and title bar, not the icons. At 0 only the icons remain; raise it again to reach the title bar and resize handle. |
| **Lock position and size** | Stops the window moving or resizing. Saved immediately, without Apply. |
| **Horizontal / vertical** | Arranges the icons in a row or a column. |
| **Reset preview position** | Moves the window back to the centre with 64-pixel icons, immediately. |
| **Skin** | With [Masque](/help/integrations#masque) enabled, choose a button skin. Masque saves this itself. |
| **Preview** | Shows sample icons while there are no real recommendations, so you can position the window. |

Drag the title bar to move the window and its lower-right corner to resize it.

## Rotation view

**Default rotation view** chooses whether rotations open as a **Diagram** or a **List**. You can switch views inside the editor at any time; this setting only picks the starting view.

## Specialization names

On Classic editions with dual specialization, you can give your **Primary** and **Secondary** specializations a display name. This changes only the label RM shows, not your talents.

## Diagnostics

These are for tracking down problems; most players never need them. See also [Troubleshooting](/help/troubleshooting).

- **Log Level** — how much RM writes to chat: *Silent*, *Default* (normal changes, like switching rotation), *Debug* (adds statistics) or *Verbose* (a lot of detail).
- **Detailed Profiling** — adds timings to the Debug/Verbose profiling report.
- **Enable observation cache** — optionally reuses repeated lookups made by conditions. Off by default. Takes effect after `/reload`, and saves immediately.
- **Capture CPU / runtime / memory / casts** and their **reports** — timed diagnostic captures you can copy into a bug report. The same captures are available as [`/rm perf`](/help/slash-commands#performance-captures) commands.
