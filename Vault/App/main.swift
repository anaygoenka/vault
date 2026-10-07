//
//  main.swift
//  Vault
//
//  `--check-accessibility` answers whether macOS trusts Vault right now and
//  exits. A running process can keep a stale "not trusted" answer after the
//  grant lands; a fresh process gets the real one, so Vault asks a copy of
//  itself.
//

import AppKit
import ApplicationServices

if CommandLine.arguments.contains("--check-accessibility") {
    print(AXIsProcessTrusted() ? "granted" : "denied")
    exit(0)
}

VaultApp.main()
