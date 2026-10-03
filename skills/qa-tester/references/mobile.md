# iOS and Android apps

The dev build on a booted simulator or emulator, reached by deep links or the repo's UI flows.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| How the dev build is served and installed | Expo: Metro on `:8081`, the dev build installed on the simulator |
| Bundle id, Android package and deep-link scheme | `com.example.app`, `com.example.app`, `example://` |
| Which simulator and emulator to use | iPhone 17 on iOS 26, Pixel 9 on API 36 |
| The repo's UI flows, if any | Maestro flows in `.maestro/`, run with `maestro test <flow>` |

## Tools

- **iOS:** `xcrun simctl list devices booted`; `xcrun simctl io booted screenshot <path>`;
  `xcrun simctl openurl booted <url>`; `xcrun simctl ui booted appearance light|dark`;
  `xcrun simctl spawn booted log show --last 5m --style compact --predicate 'process == "<App>"'`.
- **Android:** `adb devices`; `adb exec-out screencap -p > <path>`;
  `adb shell am start -W -a android.intent.action.VIEW -d <url> <package>`;
  `adb shell cmd uimode night yes|no`; `adb logcat -d -t 500`.
- **The repo's UI flows**, when Repo facts name them: they are the reliable way to tap through a
  flow. Run only the flows in scope.

Use a simulator or emulator that is already booted, with the dev build installed and its bundler
running. When none is, report BLOCKED with the command that starts it. Never boot, erase or shut
down a device, and never start the bundler.

## The loop for a mobile app

Reach each state by deep link or a UI flow, wait for it to settle (the flow's own wait, or a second
screenshot that matches the first), then assert from the screenshot and the log. Taps by
coordinates (`adb shell input tap`) break on any layout change: use them only when nothing else
reaches the state, and say so in the report.

## Evidence

- `NN-<case>-ios.png` and `NN-<case>-android.png`, for each platform the change ships on; add
  `-dark` for the dark appearance. Read each back: a capture taken mid-transition is not evidence.
- `NN-<case>.log`, the log excerpt for a FAIL.
- `NN-<case>.txt`, a UI flow's transcript with its exit code.

## Cases worth covering

- **Every changed screen** in each state it can show (empty, loading, error, filled), in light and
  dark when the change is visual, on both platforms when both ship.
- **Deep links** into the change, including one to something that doesn't exist.
- **The awkward moments:** a permission prompt, the keyboard covering an input, a small screen,
  offline, where reachable.
- **Relaunch:** the change survives the app being terminated and launched again
  (`xcrun simctl terminate` and `launch`, `adb shell am force-stop`).

## Teardown

Set back any appearance you changed. Leave the simulators, emulators and the bundler running.
