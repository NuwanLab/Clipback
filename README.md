# Clipboard History for macOS

A lightweight menu bar app that brings a Windows-style clipboard history (Win+V) to the Mac. Press a shortcut, pick something you copied earlier, and it's pasted straight into the app you're using.

Built with SwiftUI and AppKit. No dependencies, no web views, no network access. The whole app is a single Swift file.

## Features

- **Clipboard history popup** that opens near your mouse pointer and doesn't steal focus from the app you're typing in
- **Text and images** are both captured
- **Click or press Return** to paste an item into the active app
- **Pin items** to keep them at the top of the list, and delete items individually or clear everything except pinned items
- **Search:** just start typing when the popup opens to filter your text clips
- **Keyboard navigation:** ↑ ↓ to move, Return to paste, ⌘⌫ to remove an item, Esc to clear the search (or close the popup)
- **Movable window:** drag it from anywhere
- **Custom shortcut** to open the history (default **⌃⌘V**), set in Settings
- **Configurable history size:** keep 10, 25, 50, 100, or 200 clips
- **Open at login** option
- **Persistent history** that survives restarts
- **Private:** everything stays on your Mac

## Requirements

- macOS 14 (Sonoma) or later
- Xcode or the Xcode Command Line Tools (`xcode-select --install`) to build

## Installation

1. Download the latest release from the [Releases page](../../releases) and unzip it.
2. Move `ClipCache.app` into your **Applications** folder (or a subfolder of it).
3. Open the app. If macOS blocks it, click **Done**, then go to **System Settings → Privacy & Security**, scroll down, and click **Allow Anyway**. Reopen ClipCache and confirm.
4. Grant **Accessibility** permission when prompted (see [below](#accessibility-permission-required-for-pasting)).
5. Start copying and pasting! Press **⌃⌘V** to open your history.

Prefer to compile it yourself? See [Build from source](#build-from-source).

## Build from source

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git
cd YOUR-REPO
chmod +x build.sh
./build.sh
open ClipboardHistory.app
```

`build.sh` compiles `main.swift`, creates the `.app` bundle, and signs it ad hoc so it can run locally. To install it, drag `ClipboardHistory.app` to your Applications folder. If you want it to open at login, do that before enabling the setting, since macOS handles login items more reliably for apps in Applications.

## Accessibility permission (required for pasting)

To paste into other apps, the app simulates a ⌘V keystroke. macOS only allows this if you grant Accessibility access.

1. On first launch, macOS will prompt you. Click **Open System Settings**.
2. Go to **Privacy & Security → Accessibility**.
3. Turn on **Clipboard History**. If it isn't listed, click **+** and add `ClipboardHistory.app`.

Without this permission, selecting an item still places it on your clipboard, but you'll have to press ⌘V yourself.

**After rebuilding:** each build gets a new ad-hoc signature, so macOS may treat it as a different app. If pasting stops working after a rebuild, remove `ClipboardHistory` from the Accessibility list (select it and click **−**), then add it again.

## Usage

1. Launch the app. A clipboard icon appears in the menu bar.
2. Copy things as usual.
3. Press **⌃⌘V** (or your own shortcut) to open the history.
4. Type to search, if you want to narrow the list.
5. Click an item or press Return to paste it.

### Settings

Open them from the menu bar icon → **Settings…** (or ⌘,).

| Setting | What it does |
| --- | --- |
| Open at login | Starts the app automatically when you log in |
| Change shortcut | Click the button, then press the key combination you want. It must include at least one of ⌘ ⌃ ⌥ ⇧. Press Esc to cancel |
| Clips to keep | Number of unpinned clips to store. The oldest are removed first. Pinned clips are always kept |

## Where data is stored

History is saved as plain JSON at:

```
~/Library/Application Support/ClipboardHistory/history.json
```

**Heads up:** the file is not encrypted, and the app records everything you copy, including anything copied from a password manager. Delete the file or use **Clear all** if you copied something sensitive. Pinned items are not removed by **Clear all**.

## Known limitations

- Items are pasted as plain text. Rich text formatting isn't preserved
- Only text and images are captured, not files
- The popup opens at the mouse pointer, not at the text cursor (macOS doesn't expose the caret position to other apps)
- Search matches text clips only (images are hidden while searching)
- No iCloud sync
- The app doesn't skip clips from password managers

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Selecting an item doesn't paste | Grant Accessibility access (see above) |
| Shortcut does nothing | Another app may be using the same combination. Choose a different one in Settings |
| "Open at login" doesn't stick | Move the app to Applications and check **System Settings → General → Login Items** |
| App can't be opened because the developer can't be verified | Only affects copies downloaded from elsewhere. Right-click the app, choose **Open**, then confirm. Building it yourself avoids this |

## Project structure

```
main.swift   # the entire app: clipboard monitoring, popup window, settings, hotkey
build.sh     # compiles, draws the app icon, and packages the .app bundle
```

## License

Released under the [MIT License](LICENSE).
