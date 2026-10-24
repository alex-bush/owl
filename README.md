# 🦉 Owl

**Keep your Mac awake — even with the lid closed — while your AI agents work.**

Owl is a tiny macOS menu bar app that toggles system sleep with one click. Start a long-running coding agent, a build or a data job, close the lid, put the laptop aside, and come back to finished work instead of a sleeping Mac and a stalled session.

## Why

AI coding agents (Claude Code, Codex, Cursor, Gemini CLI, Antigravity and friends) can run for tens of minutes or hours. macOS really wants to sleep in the meantime — and closing the lid puts a MacBook to sleep no matter what `caffeinate` or most "keep awake" apps say, unless an external display is attached.

Owl flips the system `SleepDisabled` flag (`pmset disablesleep`), which keeps the Mac running with the lid closed, on battery or AC — and then **automatically turns normal sleep back on** after 1, 2 or 3 hours so you don't forget.

## Features

- **One-click toggle** from the menu bar — "Keep Mac Awake (1h)" / "Restore Normal Sleep".
- **Works with the lid closed**, on AC power and on battery.
- **Auto-restore timer** — keep awake for 1, 2 or 3 hours, then sleep returns automatically.
- **Live status** — the owl's eyes are open when sleep is disabled and closed when it's normal. The state is polled every 5 seconds, so changes made outside Owl are reflected too.
- **Battery warning** when sleep is disabled while running on battery.
- **Safe by default** — quitting Owl restores normal sleep; after a crash, Owl restores it on next launch.
- **No `sudo` prompts, no `sudoers` hacks** — a minimal, signed privileged helper does exactly one thing.
- Menu bar only, no Dock icon.

## Requirements

- macOS 27 or later
- Xcode 27
- An Apple ID signed in to Xcode with an **Apple Development** signing certificate (the privileged helper refuses to run with ad hoc signing)

## Build and install

1. **Clone the repo**

   ~~~sh
   git clone https://github.com/alex-bush/owl.git
   cd owl
   ~~~

2. **Set your Team ID.** Signing settings live in a local, gitignored config file:

   ~~~sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ~~~

   Open `Config/Local.xcconfig` and replace `YOUR_TEAM_ID` with your Apple Developer Team ID (Xcode → Settings → Accounts, or developer.apple.com → Membership). It's applied to both the `Owl` and `OwlHelper` targets.

   > Don't pick a team in Xcode's *Signing & Capabilities* tab — Xcode would write it into `project.pbxproj`.

3. **Build, verify and install**

   ~~~sh
   xcodebuild -quiet -project Owl.xcodeproj -scheme Owl -configuration Release \
     -destination 'platform=macOS' -derivedDataPath build build
   codesign --verify --deep --strict build/Build/Products/Release/Owl.app
   ditto build/Build/Products/Release/Owl.app /Applications/Owl.app
   open /Applications/Owl.app
   ~~~

   Or just open `Owl.xcodeproj` in Xcode and run the **Owl** scheme.

4. **Install the helper.** On first launch, click the owl in the menu bar → **Install Owl Helper**, then approve the background item in **System Settings → General → Login Items & Extensions**. The menu will show "Owl helper is ready".

5. *(Optional)* Add `/Applications/Owl.app` to **Login Items** to start Owl at login.

> After the helper is registered, don't move `Owl.app` to another location without uninstalling and reinstalling the helper.

### Updating

Choose **Quit Owl** first (this restores normal sleep), then repeat step 3. You don't need to reinstall the helper if the menu shows "Owl helper is ready".

## Usage

| Menu item | What it does |
| --- | --- |
| **Keep Mac Awake (1h)** | Disables sleep and schedules normal sleep to return in 1 hour. |
| **Keep Awake For… → 1 / 2 / 3 hours** | Same, with a custom duration. |
| **Restore Normal Sleep** | Turns sleep back on immediately and cancels the timer. |
| **Restore Normal Sleep In…** | When sleep is already disabled, (re)schedules when it returns. |
| **Cancel Timer** | Keeps sleep disabled indefinitely (until you restore it or quit Owl). |
| **Quit Owl** | Restores normal sleep, then quits. |

The timer only runs while Owl is running. If an automatic restore fails, Owl retries every minute while it remains open.

## How it works

```
Owl.app (menu bar, user)  ──XPC──▶  OwlHelper (LaunchDaemon, root)  ──▶  /usr/bin/pmset -a disablesleep 0|1
```

- Changing `disablesleep` requires root, so Owl ships a small privileged helper registered via `SMAppService` (one-time admin approval, no password prompts afterwards).
- The XPC interface accepts **only a single boolean**. The helper runs one of two hard-coded commands — `pmset -a disablesleep 1` or `pmset -a disablesleep 0`. No arbitrary commands or arguments are ever passed.
- The helper only accepts connections from an app with bundle ID `dev.ghostkaa.owl` signed by **the same Apple Developer team** as the helper itself (checked via code-signing requirements). With ad hoc signing it exits.
- Owl reads the current state with `pmset -g` and power source via IOKit.
- When Owl disables sleep, it records that in `UserDefaults`, so it can restore sleep on quit or on the next launch after a crash — without touching sleep settings it didn't change.

## ⚠️ Safety

- With sleep disabled, a MacBook **keeps running with the lid closed and can get hot — especially in a bag**. Restore normal sleep before packing it up.
- On battery, drain is noticeably higher. Owl shows a warning in the menu.
- `pmset disablesleep` is undocumented in the `pmset` man page. It works on current macOS but Apple could change it in a future release.

If Owl crashed and sleep is still disabled, restore it manually:

~~~sh
sudo /usr/bin/pmset -a disablesleep 0
pmset -g | grep SleepDisabled   # should print: SleepDisabled 0
~~~

## Uninstall

1. Restore normal sleep from the menu.
2. Choose **Uninstall Owl Helper**.
3. Choose **Quit Owl**.
4. Delete `/Applications/Owl.app`.

## Troubleshooting

- **"Owl helper is not installed" / "Approve the Owl helper…"** — use the menu item to install it or open System Settings, then enable Owl under Login Items & Extensions.
- **Helper exits immediately** — the app and helper must both be signed with an Apple Development certificate from the same team. Check `Config/Local.xcconfig` and run `codesign -dv --verbose=2 /Applications/Owl.app`.
- **`codesign` fails with "resource fork, Finder information, or similar detritus not allowed"** — the build folder has extended attributes (common in iCloud-synced or some sandboxed folders). Build into a clean location, e.g. `-derivedDataPath /private/tmp/OwlDerivedData`.
- **Compile-only check** without signing (the helper won't work):

  ~~~sh
  xcodebuild -quiet -project Owl.xcodeproj -scheme Owl -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
  ~~~

## Project structure

| Path | Purpose |
| --- | --- |
| `Owl/OwlApp.swift` | SwiftUI `MenuBarExtra`, menu items, icon, termination handler. |
| `Owl/OwlModel.swift` | Menu state, 5-second refresh, toggling, timer, crash recovery, error alerts. |
| `Owl/PowerControl.swift` | Reads `SleepDisabled`, verifies toggles, detects battery power. |
| `Owl/HelperService.swift` | Helper registration via `SMAppService` and the XPC call. |
| `Owl/OwlHelperProtocol.swift` | XPC protocol shared by the app and the helper. |
| `Owl/OwlIcon.swift` | Vector owl icon for the menu bar. |
| `OwlHelper/main.swift` | Client signature check and the two fixed `pmset` invocations. |
| `OwlHelper/dev.ghostkaa.owl.helper.plist` | LaunchDaemon configuration. |
| `Config/Shared.xcconfig` | Shared build settings; includes the gitignored `Local.xcconfig`. |

## Roadmap

- [ ] Notifications when the timer is about to expire / sleep is restored
- [ ] Custom durations

## License

Owl is available under the [MIT License](LICENSE).
