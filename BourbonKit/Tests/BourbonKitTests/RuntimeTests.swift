import XCTest
@testable import BourbonKit

final class RuntimeTests: XCTestCase {
    let home = URL(fileURLWithPath: "/Users/tester")
    let managed = URL(fileURLWithPath: "/Support/Runtimes")

    func testParsesWineVersionOutput() {
        XCTAssertEqual(WineRuntime.parseVersion("wine-9.0\n"), SemanticVersion(9, 0))
        XCTAssertEqual(WineRuntime.parseVersion("wine-10.5 (Staging)"), SemanticVersion(10, 5))
        XCTAssertNil(WineRuntime.parseVersion("command not found"))
        XCTAssertNil(WineRuntime.parseVersion(""))
    }

    func testPrefersWine64OverWine() {
        let probe = FakeProbe(executables: ["/x/bin/wine", "/x/bin/wine64", "/x/bin/wineserver"])
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        let runtime = locator.runtime(inBinDirectory: URL(fileURLWithPath: "/x/bin"), source: .custom)
        XCTAssertEqual(runtime?.wineBinary.path, "/x/bin/wine64")
    }

    func testSupportsWoW64BuildsWithOnlyWine() {
        let probe = FakeProbe(executables: ["/x/bin/wine", "/x/bin/wineserver"])
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        XCTAssertEqual(locator.runtime(inBinDirectory: URL(fileURLWithPath: "/x/bin"), source: .custom)?
            .wineBinary.lastPathComponent, "wine")
    }

    func testRequiresWineserver() {
        let probe = FakeProbe(executables: ["/x/bin/wine64"])
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        XCTAssertNil(locator.runtime(inBinDirectory: URL(fileURLWithPath: "/x/bin"), source: .custom))
    }

    func testFindsAppBundleLayout() {
        let bin = "/Applications/Wine Stable.app/Contents/Resources/wine/bin"
        let probe = FakeProbe(executables: ["\(bin)/wine", "\(bin)/wineserver"])
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        let all = locator.locateAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.source, .application)
        XCTAssertEqual(all.first?.binDirectory.path, bin)
    }

    func testManagedRuntimesComeFirstAndNewestFirst() {
        let probe = FakeProbe(
            executables: [
                "/Support/Runtimes/wine-9.0/bin/wine64", "/Support/Runtimes/wine-9.0/bin/wineserver",
                "/Support/Runtimes/wine-10.0/Wine Stable.app/Contents/Resources/wine/bin/wine",
                "/Support/Runtimes/wine-10.0/Wine Stable.app/Contents/Resources/wine/bin/wineserver",
                "/opt/homebrew/bin/wine", "/opt/homebrew/bin/wineserver"
            ],
            directories: [
                "/Support/Runtimes": ["wine-9.0", "wine-10.0"],
                "/Support/Runtimes/wine-10.0": ["Wine Stable.app"]
            ]
        )
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        let all = locator.locateAll()
        XCTAssertEqual(all.map(\.source), [.managed, .managed, .homebrew])
        XCTAssertEqual(all.first?.binDirectory.path,
                       "/Support/Runtimes/wine-10.0/Wine Stable.app/Contents/Resources/wine/bin",
                       "Managed runtimes are ordered by version, newest first")
    }

    func testFindsWhiskyLibraries() {
        let bin = "/Users/tester/Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine/bin"
        let probe = FakeProbe(executables: ["\(bin)/wine64", "\(bin)/wineserver"])
        let locator = RuntimeLocator(probe: probe, managedRoot: managed, homeDirectory: home)
        XCTAssertEqual(locator.locateAll().first?.source, .whisky)
    }

    func testDisplayName() {
        var runtime = Fixtures.runtime
        XCTAssertEqual(runtime.displayName, "Wine")
        runtime.version = SemanticVersion(9, 0)
        XCTAssertEqual(runtime.displayName, "Wine 9.0")
    }

    func testPicksStableAssetFromRelease() throws {
        let json = """
        {"tag_name": "v10.0", "assets": [
          {"name": "wine-devel-10.1-osx64.tar.xz", "browser_download_url": "https://example.com/devel", "size": 1},
          {"name": "wine-stable-10.0-osx.tar.xz", "browser_download_url": "https://example.com/stable32", "size": 2},
          {"name": "wine-stable-10.0-osx64.tar.xz", "browser_download_url": "https://example.com/stable", "size": 3},
          {"name": "wine-stable-10.0-osx64.pkg", "browser_download_url": "https://example.com/pkg", "size": 4}
        ]}
        """
        let release = try JSONDecoder().decode(RuntimeRelease.self, from: Data(json.utf8))
        XCTAssertEqual(release.version, SemanticVersion(10, 0))
        XCTAssertEqual(release.asset(for: .stable)?.downloadURL.absoluteString, "https://example.com/stable")
        XCTAssertEqual(release.asset(for: .devel)?.name, "wine-devel-10.1-osx64.tar.xz")
        XCTAssertNil(release.asset(for: .staging))
    }

    func testArchiveExtraction() {
        let command = RuntimeArchive().extractCommand(archive: URL(fileURLWithPath: "/tmp/w.tar.xz"),
                                                      destination: URL(fileURLWithPath: "/rt/w"))
        XCTAssertEqual(command.executable.path, "/usr/bin/tar")
        XCTAssertEqual(command.arguments, ["-xf", "/tmp/w.tar.xz", "-C", "/rt/w"])
        XCTAssertEqual(RuntimeArchive.folderName(for: "wine-stable-10.0-osx64.tar.xz"), "wine-stable-10.0-osx64")
        XCTAssertEqual(RuntimeArchive.folderName(for: "build.zip"), "build")
    }
}
