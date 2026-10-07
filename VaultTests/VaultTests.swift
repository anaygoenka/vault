//
//  VaultTests.swift
//  VaultTests
//

import Foundation
import Testing
@testable import Vault

@MainActor
struct ClassificationTests {
    @Test(arguments: ["#5856F4", "#fff", "#11223344", "rgb(255, 149, 0)", "rgba(0,0,0,0.5)", "hsl(240, 100%, 50%)"])
    func recognisesColours(_ text: String) {
        #expect(ClipboardMonitor.classify(text) == .color)
    }

    @Test(arguments: ["https://apple.com", "http://localhost:3000/path?q=1", "mailto:hi@example.com"])
    func recognisesLinks(_ text: String) {
        #expect(ClipboardMonitor.classify(text) == .link)
    }

    @Test(arguments: ["hello world", "#notacolour", "apple.com is great", "https://a.com and more", "5856F4"])
    func everythingElseIsText(_ text: String) {
        #expect(ClipboardMonitor.classify(text) == .text)
    }
}

struct ColorValueTests {
    @Test func hexRoundTrips() throws {
        let colour = try #require(ColorValue(parsing: "#5856f4"))
        #expect(colour.hexString == "#5856F4")
        #expect(colour.rgbString == "rgb(88, 86, 244)")
    }

    @Test func shortHexExpands() throws {
        #expect(try #require(ColorValue(parsing: "#0f8")).hexString == "#00FF88")
    }

    @Test func hslConvertsToRGB() throws {
        let blue = try #require(ColorValue(parsing: "hsl(240, 100%, 50%)"))
        #expect(blue.hexString == "#0000FF")
        #expect(blue.hslString == "hsl(240, 100%, 50%)")
    }

    @Test func rejectsNonsense() {
        #expect(ColorValue(parsing: "#12") == nil)
        #expect(ColorValue(parsing: "rgb(1, 2)") == nil)
        #expect(ColorValue(parsing: "banana") == nil)
    }
}

struct RetentionTests {
    @Test func foreverNeverExpires() {
        #expect(Retention.forever.cutoff() == nil)
    }

    @Test func weekCutoffIsSevenDaysBack() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cutoff = try #require(Retention.week.cutoff(from: now))
        #expect(now.timeIntervalSince(cutoff) == 7 * 86_400)
    }
}
