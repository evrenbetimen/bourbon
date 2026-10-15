import XCTest
@testable import BourbonKit

final class CommandLineTextTests: XCTestCase {
    func testSplitHandlesQuotesAndEscapes() {
        XCTAssertEqual(CommandLineText.split(""), [])
        XCTAssertEqual(CommandLineText.split("  -a   -b  "), ["-a", "-b"])
        XCTAssertEqual(CommandLineText.split(#"--name "Big Game" 'single quoted'"#), ["--name", "Big Game", "single quoted"])
        XCTAssertEqual(CommandLineText.split(#"path\ with\ spaces"#), ["path with spaces"])
        XCTAssertEqual(CommandLineText.split(#"say "it's" 'a "b"'"#), ["say", "it's", #"a "b""#])
        XCTAssertEqual(CommandLineText.split(#"empty "" end"#), ["empty", "", "end"])
        XCTAssertEqual(CommandLineText.split(#"-dx11 -windowed"#), ["-dx11", "-windowed"])
    }

    func testShellQuote() {
        XCTAssertEqual(CommandLineText.shellQuote("simple-path/file.exe"), "simple-path/file.exe")
        XCTAssertEqual(CommandLineText.shellQuote("has space"), "'has space'")
        XCTAssertEqual(CommandLineText.shellQuote("it's"), #"'it'\''s'"#)
        XCTAssertEqual(CommandLineText.shellQuote(""), "''")
        XCTAssertEqual(CommandLineText.shellQuote("$HOME"), "'$HOME'")
    }

    func testSplitRoundTripsShellQuote() {
        let words = ["a b", "it's", #"q"uote"#, "", "plain"]
        let line = words.map(CommandLineText.shellQuote).joined(separator: " ")
        XCTAssertEqual(CommandLineText.split(line), words)
    }

    func testEnvironmentNames() {
        XCTAssertTrue(CommandLineText.isValidEnvironmentName("DXVK_HUD"))
        XCTAssertTrue(CommandLineText.isValidEnvironmentName("_private1"))
        XCTAssertFalse(CommandLineText.isValidEnvironmentName(""))
        XCTAssertFalse(CommandLineText.isValidEnvironmentName("9LIVES"))
        XCTAssertFalse(CommandLineText.isValidEnvironmentName("HAS-DASH"))
        XCTAssertFalse(CommandLineText.isValidEnvironmentName("ÜNICODE"))
    }
}

final class SemanticVersionTests: XCTestCase {
    func testParsing() {
        XCTAssertEqual(SemanticVersion("9.0"), SemanticVersion(9, 0, 0))
        XCTAssertEqual(SemanticVersion("v10.2.1"), SemanticVersion(10, 2, 1))
        XCTAssertEqual(SemanticVersion("wine-9.0-rc3 (Staging)"), SemanticVersion(9, 0))
        XCTAssertEqual(SemanticVersion("11"), SemanticVersion(11))
        XCTAssertNil(SemanticVersion("latest"))
    }

    func testOrdering() {
        XCTAssertLessThan(SemanticVersion(9, 0), SemanticVersion(10, 0))
        XCTAssertLessThan(SemanticVersion(9, 9, 9), SemanticVersion(9, 10))
        XCTAssertEqual([SemanticVersion(2), SemanticVersion(1, 5), SemanticVersion(1)].sorted(),
                       [SemanticVersion(1), SemanticVersion(1, 5), SemanticVersion(2)])
    }

    func testDescription() {
        XCTAssertEqual(SemanticVersion(9, 0).description, "9.0")
        XCTAssertEqual(SemanticVersion(9, 0, 3).description, "9.0.3")
    }
}

final class WinetricksTests: XCTestCase {
    let sample = """
    Using winetricks 20240105 - sha256sum: abc
    ===== dlls =====
    vcrun2022                Visual C++ 2015-2022 libraries (Microsoft, 2022) [downloadable]
    d3dx9                    MS d3dx9_??.dll from DirectX 9 redistributable (Microsoft, 2010) [cached]
    ===== fonts =====
    corefonts                MS Arial, Courier, Times fonts (Microsoft, 2008) [downloadable]

    ===== settings =====
    win10
    """

    func testParsesCategoriesAndStripsMarkers() {
        let verbs = Winetricks.parse(sample)
        XCTAssertEqual(verbs.map(\.name), ["vcrun2022", "d3dx9", "corefonts", "win10"])
        let vcrun = verbs[0]
        XCTAssertEqual(vcrun.category, "dlls")
        XCTAssertEqual(vcrun.summary, "Visual C++ 2015-2022 libraries (Microsoft, 2022)")
        XCTAssertEqual(verbs[1].summary, "MS d3dx9_??.dll from DirectX 9 redistributable (Microsoft, 2010)")
        XCTAssertEqual(verbs[2].category, "fonts")
        XCTAssertEqual(verbs[3].category, "settings")
        XCTAssertEqual(verbs[3].summary, "")
    }

    func testFilter() {
        let verbs = Winetricks.essentials
        XCTAssertEqual(Winetricks.filter(verbs, query: "").count, verbs.count)
        XCTAssertEqual(Winetricks.filter(verbs, query: "VCRUN").map(\.name), ["vcrun2022"])
        XCTAssertEqual(Set(Winetricks.filter(verbs, query: "settings").map(\.category)), ["settings"])
        XCTAssertTrue(Winetricks.filter(verbs, query: "zzz-nothing").isEmpty)
    }

    func testEssentialsAreUnique() {
        XCTAssertEqual(Set(Winetricks.essentials.map(\.id)).count, Winetricks.essentials.count)
    }
}

final class LibraryQueryTests: XCTestCase {
    let programs = ["Zeta", "alpha", "Beta 10", "Beta 9"].map {
        Program(url: URL(fileURLWithPath: "/b/drive_c/\($0).exe"), relativePath: "drive_c/\($0).exe")
    }

    func testSortsByNameNaturally() {
        let sorted = LibraryQuery().apply(to: programs, settings: BottleSettings(name: "B"))
        XCTAssertEqual(sorted.map(\.name), ["alpha", "Beta 9", "Beta 10", "Zeta"])
    }

    func testFiltersCaseInsensitively() {
        let result = LibraryQuery(text: "beta").apply(to: programs, settings: BottleSettings(name: "B"))
        XCTAssertEqual(result.map(\.name), ["Beta 9", "Beta 10"])
    }

    func testRecentPutsLaunchedFirst() {
        var settings = BottleSettings(name: "B")
        settings.programSettings["drive_c/Zeta.exe"] = ProgramSettings(lastLaunchedAt: Date(timeIntervalSince1970: 10))
        settings.programSettings["drive_c/Beta 10.exe"] = ProgramSettings(lastLaunchedAt: Date(timeIntervalSince1970: 20))
        let result = LibraryQuery(sort: .recent).apply(to: programs, settings: settings)
        XCTAssertEqual(result.map(\.name), ["Beta 10", "Zeta", "alpha", "Beta 9"])
    }

    func testFiltersBottles() {
        let bottles = ["Steam", "Office", "Battle.net"].map {
            Bottle(url: URL(fileURLWithPath: "/b/\($0)"), settings: BottleSettings(name: $0))
        }
        XCTAssertEqual(LibraryQuery.filter(bottles, text: "st").map(\.name), ["Steam"])
        XCTAssertEqual(LibraryQuery.filter(bottles, text: " ").count, 3)
    }
}

final class RunnableFileTests: XCTestCase {
    func testAcceptsWindowsProgramsInstallersAndScripts() {
        for name in ["setup.exe", "SETUP.EXE", "Installer.Msi", "run.bat"] {
            XCTAssertTrue(RunnableFile.isRunnable(URL(fileURLWithPath: "/tmp/\(name)")), name)
        }
    }

    func testRejectsOtherFilesAndRemoteURLs() {
        XCTAssertFalse(RunnableFile.isRunnable(URL(fileURLWithPath: "/tmp/readme.txt")))
        XCTAssertFalse(RunnableFile.isRunnable(URL(fileURLWithPath: "/tmp/exe")))
        XCTAssertFalse(RunnableFile.isRunnable(URL(string: "https://example.com/setup.exe")!))
    }
}
