# Troubleshooting

## Nothing is highlighted

Work down this list:

1. **Is RM enabled?** `/rm enable`, or tick **Enable** in [General](/help/general).
2. **Is a rotation active?** `/rm current` names it. If none is, see [Switch conditions](/help/switching#troubleshooting-switching).
3. **Is the action on your action bars?** Highlights appear on action bar buttons. Turn on **Preview Spells** in General to see recommendations even if they are not on your bars.
4. **Is bar highlighting turned off?** Untick **Disable Bar Highlighting**.
5. **Can the action be used right now?** RM skips spells you have not learned, cannot afford, are on cooldown or out of range, and items you are not carrying.
6. **Do the card's conditions match?** Open the rotation; with live status on, each card shows whether its conditions are *currently satisfied*.
7. **Is the rotation valid?** A red warning above the switch condition explains what is incomplete. Click it for details.
8. **Are you on Retail or Forever?** Some conditions are reference only there; see [Game editions](/help/editions).

## The wrong rotation is active

- Check whether you chose one by hand: a manual choice holds until `/rm set auto`.
- Check rotation priorities and switch conditions; custom rotations are tried before Built In ones, highest priority first. See [Switch conditions](/help/switching).

## Errors

`/rm errors` opens a window listing Rotation Master errors, ready to copy. Custom Lua is hidden by default. Include this report when you ask for help.

If a custom condition or function is the cause, its error is listed there too. Fix or disable it on the Conditions or Functions tab.

## Saved data looks wrong

- `/rm check` reports problems without changing anything.
- `/rm repair` fixes what it safely can. Export important rotations or your profile first.
- Older rotations that lost their owner can be recovered with **Recover unassigned rotations** on the Rotations tab.

## The game feels slow

- Raise the **Polling Interval** in General a little (the default is 0.15 seconds).
- Make sure **Idle Re-check Interval** is not 0, so RM can skip work when idle.
- Custom conditions run on every check; keep them simple.
- Capture what RM is doing with `/rm perf runtime` (and `/rm perf runtime report`), and share the report. See [Slash commands](/help/slash-commands#performance-captures).

## The code editor will not let me type

Reproduce the problem, then run `/rm editorinfo` and copy the report. You can also choose a different editor, or plain text, on the [Integrations](/help/integrations#lua-editor) tab.

## Asking for help

- **[Discord](https://discord.gg/4aKZSpUMet)** — the fastest way to get an answer from the author and other players.
- **[Bug reports](https://github.com/corporategoth/rotationmaster/issues)** — for confirmed bugs. Include your game edition, what you did, what you expected, and the `/rm errors` report.

If your question is about a rotation, [share it here](/shares/new) or paste its export string, so others can see exactly what you have.
