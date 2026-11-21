# ClipBack

Windows-style clipboard history (Win+V) for macOS. A lightweight menu bar app: press a shortcut, search or pick something you copied earlier, and it's pasted straight into the app you're using.

<img width="728" height="969" alt="image" src="https://github.com/user-attachments/assets/a3e4881f-9d76-448e-8bbf-8785a0a25f2e" />


## Features

- Text and image history, saved between restarts
- Search, pin, and delete clips
- Customizable global shortcut (default **⌃⌘V**)
- Choose how many clips to keep (10 to 200)
- Draggable window, full keyboard control, optional open at login
- Private: everything stays on your Mac

## Installation

1. Download and unzip the [latest release](../../releases/latest).
2. Move `ClipBack.app` into your **Applications** folder (or a subfolder of it).
3. If macOS blocks the app, click **Done**, go to **System Settings → Privacy & Security → Allow Anyway**, then reopen ClipBack.
4. Grant **Accessibility** permission when prompted (**System Settings → Privacy & Security → Accessibility**). This lets ClipBack paste for you.
5. Start copying and pasting!

Requires macOS 14 or later.

## Usage

Press **⌃⌘V** to open your history, type to search, then click an item or press Return to paste it.

| Key | Action |
| --- | --- |
| ↑ ↓ | Move selection |
| Return | Paste selected clip |
| ⌘⌫ | Delete selected clip |
| Esc | Clear search, then close |

Change the shortcut, history size, or open-at-login from the menu bar icon → **Settings…**

## Privacy

ClipBack never connects to the internet. History is stored unencrypted on your Mac at `~/Library/Application Support/ClipBack/`, and it includes anything you copy, such as passwords. Use **Clear all** to wipe it (pinned clips are kept).

## License

[MIT](LICENSE)
