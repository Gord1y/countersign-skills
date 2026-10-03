# Native macOS app

Views rendered by the repo's own snapshot command, else captured from a running window.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| How to render views without launching the app (a snapshot command) | `swift run Snapshots --out <dir>`, each pane in light and dark |
| How to run a separate debug copy with its own config, if the repo supports one | `swift build`, then `.build/debug/<App>` with `<APP>_CONFIG_DIR=<scratch>` |
| The app's name, bundle id and log subsystem | `MyApp`, `com.example.myapp`, the same as its subsystem |

## Tools

- **The snapshot command first.** It renders the real views to PNG without touching the copy the
  user runs, and it exits on its own.
- **A window capture otherwise**, of a debug copy you launched or of the user's running copy.
  `swift <this skill's folder>/scripts/window-id.swift <App>` prints the app's on-screen window
  numbers; capture one with `screencapture -x -o -l <number> "$QA/<file>.png"`. Both run outside
  the sandbox: inside it the window list comes back empty. Without the Screen Recording permission
  the capture shows only the desktop: read it back, and on a blank one mark the case BLOCKED,
  naming the permission and the app that needs it.
- **Never quit, relaunch or script clicks in the user's copy.** AppleScript and UI scripting are
  blocked by the sandbox, and they would act on the user's real state. Drive actions through what
  the repo provides: its UI tests, its URL scheme, its CLI, or the snapshot states.

## The loop for a native app

Reach each state through the snapshot command's fixtures or the repo's UI tests, then assert from
the image and the app's log. For behaviour that persists (settings, a config file), launch the
debug copy against a scratch config, act, quit it, and read the file it wrote.

## Evidence

- `NN-<case>-light.png` and `NN-<case>-dark.png` for any visual change, both appearances, each
  state the change can show.
- `NN-<case>.log` from
  `log show --last 5m --style compact --predicate 'subsystem == "<subsystem>"'` for a FAIL.
- `NN-<case>.txt` for a config file the app wrote, or a test run's transcript.

## Cases worth covering

- **Every changed view** in each state it can show (empty, loading, error, filled), in light and
  dark.
- **Menu bar and menus:** each changed item exists, is enabled when it should be, and does what it
  says.
- **Persistence:** a setting survives quitting and relaunching the debug copy.
- **Its files:** the config it writes has the documented shape, and nothing outside its own folders
  changed.

## Teardown

Quit the debug copy you launched, and only that one. Keep its scratch config in `$SCRATCH`, so it
goes with that folder.
