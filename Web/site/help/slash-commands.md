# Slash commands

Every command starts with `/rm` (or the longer `/rotationmaster`). Type `/rm help` in game for the list.

## Everyday commands

| Command | What it does |
|---|---|
| `/rm help` | List the commands. |
| `/rm config` | Open the settings window on the Rotations tab. |
| `/rm enable` | Turn recommendations on. |
| `/rm disable` | Turn recommendations off and clear highlights. |
| `/rm toggle` | Switch between enabled and disabled. You can also bind a key to *Toggle Rotation Master* in the game's Key Bindings. |
| `/rm current` | Print the name of the active rotation. |
| `/rm set <rotation name>` | Switch to that rotation by hand. Automatic switching stays off until you choose `auto`. The choice is remembered for this character, specialization and action context. |
| `/rm set auto` | Go back to [automatic switching](/help/switching). |

Example macro to flip between two setups:

```text
/rm set Single target
```

```text
/rm set auto
```

## Checking and fixing your data

| Command | What it does |
|---|---|
| `/rm check` | Check your saved data for problems, such as invalid saved priorities, and report them without changing anything. |
| `/rm repair` | Run the same check and fix what can be fixed automatically. For example, a malformed switch priority is cleared back to the default of 0. |
| `/rm errors` | Open a window listing Rotation Master errors, ready to copy into a bug report. Custom code is hidden by default. |

> **Tip:** Run `/rm check` first and read what it says. Export anything important before running `/rm repair`.

## Code editor diagnostics

| Command | What it does |
|---|---|
| `/rm editorinfo` | If you cannot place the cursor or type in a code editor, reproduce the problem and run this. It opens a copyable report of input and focus details (not your code) for a bug report. |
| `/rm editorarrows` | Temporarily test the arrow keys in an open code editor. |

## Performance captures

These measure what RM is doing, for bug reports about slowness. Each produces a copyable report. The same captures are buttons in [General](/help/general#diagnostics).

| Command | What it does |
|---|---|
| `/rm perf cpu [seconds]` | Capture CPU cost and call counts per function (default 10 s, up to 60). Requires the game's script profiling to be enabled before a reload. |
| `/rm perf runtime [seconds]` | Measure rotation evaluation calls with the native profiler (default 10 s, up to 60). |
| `/rm perf memory [seconds]` | Observe memory use (default 600 s, up to 1800). |
| `/rm perf <capture> stop` | Stop a running capture early and keep what was recorded. |
| `/rm perf <capture> report` | Open the report for that capture. |
| `/rm perf probe` | Check which profiler features this client allows, without measuring gameplay. |
| `/rm perf engine` | Show which evaluation engine is in use. |
| `/rm perf engine lean` / `standard` | Choose the engine. *Lean* is the default; *standard* is the original engine, useful for comparing if you suspect a problem with lean. |

After starting a capture, close the settings window and play normally until it finishes.
