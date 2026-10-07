# Contributing to Vault

Thanks for helping. Vault is small on purpose, so the bar is: does it make copying and pasting faster, calmer or safer?

## Getting started

1. Install Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Clone the repo and run `xcodegen generate`.
3. Open `Vault.xcodeproj`, set your own team under Signing, and run.

To build from the command line with your own team:

```bash
xcodegen generate
xcodebuild -project Vault.xcodeproj -scheme Vault DEVELOPMENT_TEAM=YOURTEAMID build
```

## Before you open a pull request

- Run the tests: `xcodebuild -project Vault.xcodeproj -scheme Vault test`.
- Match the surrounding code: SwiftUI, `@Observable`, short doc comments that explain why.
- Keep the interface native: Liquid Glass materials, SF Symbols, system fonts.
- One change per pull request, with a sentence on what it fixes for the person using Vault.

## Reporting bugs

Open an issue with your macOS version, what you copied, what you expected and what happened.
