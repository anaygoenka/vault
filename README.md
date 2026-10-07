# Vault

A Liquid Glass clipboard history app for macOS 26 and later. It runs in the menu bar and opens with ⇧⌘V.

## Build and install

```bash
Scripts/install.sh
```

Runs the tests, makes a clean Release build, replaces `/Applications/Vault.app`, and relaunches it. Requires XcodeGen.

## Keys in the panel

| Keys | Action |
|---|---|
| ↩ | Paste (or copy, without Accessibility) |
| ⇧↩ | Paste as plain text |
| ⌥↩ / ⌘C | Copy without pasting |
| ⌘1 to ⌘9 | Paste that clip |
| ↑ ↓, ⌘↑ ⌘↓ | Move the selection |
| ⇥ / ⇧⇥ | Next or previous filter |
| ⌘P | Pin or unpin |
| ⌘O | Open link, show file, or open image |
| ⌘⌫ | Delete |
| ⎋ | Clear search, then close |

## Permissions

Accessibility is requested through PermissionFlow (the same drag-card flow as FocusDragon) and is used only to press ⌘V for you. Without it, Vault copies the clip and you press ⌘V.

History is stored in `~/Library/Application Support/Vault`.
