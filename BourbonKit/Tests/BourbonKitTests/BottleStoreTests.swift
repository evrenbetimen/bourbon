import XCTest
@testable import BourbonKit

final class BottleStoreTests: XCTestCase {
    var directory: TemporaryDirectory!
    var store: BottleStore!

    override func setUpWithError() throws {
        directory = try TemporaryDirectory()
        store = BottleStore(root: directory.url.appendingPathComponent("Bottles"))
    }

    override func tearDown() {
        store = nil
        directory = nil
    }

    func testEmptyWhenRootMissing() throws {
        XCTAssertEqual(try store.loadAll(), [])
    }

    func testCreateWritesMetadataAndDriveC() throws {
        let bottle = try store.create(BottleSettings(name: "  Steam Games  "))
        XCTAssertEqual(bottle.name, "Steam Games")
        XCTAssertEqual(bottle.url.lastPathComponent, "Steam-Games")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bottle.metadataURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bottle.driveC.path))
        XCTAssertFalse(bottle.isInitialized)
        XCTAssertEqual(try store.loadAll().map(\.name), ["Steam Games"])
    }

    func testCreateRejectsInvalidNames() {
        XCTAssertThrowsError(try store.create(BottleSettings(name: "   "))) {
            XCTAssertEqual($0 as? BottleNameError, .empty)
        }
        XCTAssertThrowsError(try store.create(BottleSettings(name: "a/b")))
    }

    func testSameNameGetsUniqueFolders() throws {
        let first = try store.create(BottleSettings(name: "Games"))
        let second = try store.create(BottleSettings(name: "Games"))
        XCTAssertNotEqual(first.url, second.url)
        XCTAssertEqual(second.url.lastPathComponent, "Games-2")
    }

    func testLoadAllSortsAndSkipsForeignFolders() throws {
        try store.create(BottleSettings(name: "zeta"))
        try store.create(BottleSettings(name: "Alpha"))
        try store.create(BottleSettings(name: "beta 10"))
        try store.create(BottleSettings(name: "beta 9"))
        try FileManager.default.createDirectory(at: store.root.appendingPathComponent("not-a-bottle"),
                                                withIntermediateDirectories: true)
        XCTAssertEqual(try store.loadAll().map(\.name), ["Alpha", "beta 9", "beta 10", "zeta"])
    }

    func testSaveAndReload() throws {
        var bottle = try store.create(BottleSettings(name: "Office"))
        bottle.settings.dxvkEnabled = true
        bottle.settings.windowsVersion = .win7
        try store.save(bottle)

        let reloaded = try store.load(at: bottle.url)
        XCTAssertTrue(reloaded.settings.dxvkEnabled)
        XCTAssertEqual(reloaded.settings.windowsVersion, .win7)
    }

    func testRenameKeepsFolder() throws {
        let bottle = try store.create(BottleSettings(name: "Old"))
        let renamed = try store.rename(bottle, to: "New Name")
        XCTAssertEqual(renamed.url, bottle.url)
        XCTAssertEqual(try store.load(at: bottle.url).name, "New Name")
        XCTAssertThrowsError(try store.rename(bottle, to: ""))
    }

    func testDuplicateCopiesFilesAndPicksUniqueName() throws {
        let bottle = try store.create(BottleSettings(name: "Main"))
        try directory.touch("Bottles/Main/drive_c/app.exe")

        let copy = try store.duplicate(bottle)
        XCTAssertEqual(copy.name, "Main Copy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.driveC.appendingPathComponent("app.exe").path))

        let another = try store.duplicate(bottle)
        XCTAssertEqual(another.name, "Main Copy 2")
        XCTAssertEqual(try store.loadAll().count, 3)
    }

    func testDeleteRemovesBottle() throws {
        let bottle = try store.create(BottleSettings(name: "Temp"))
        try store.delete(bottle, useTrash: false)
        XCTAssertEqual(try store.loadAll(), [])
    }

    func testLoadThrowsForNonBottles() {
        XCTAssertThrowsError(try store.load(at: directory.url)) {
            XCTAssertEqual($0 as? BottleStoreError, .notABottle(directory.url))
        }
    }

    func testSlugs() {
        XCTAssertEqual(BottleStore.slug(for: "Çılgın Oyunlar!"), "Cilgin-Oyunlar")
        XCTAssertEqual(BottleStore.slug(for: "Steam / Epic"), "Steam-Epic")
        XCTAssertEqual(BottleStore.slug(for: "???"), "bottle")
        XCTAssertEqual(BottleStore.slug(for: "Café Déjà Vu"), "Cafe-Deja-Vu")
    }

    func testNameValidation() {
        XCTAssertEqual(try BottleStore.validateName(" ok ").get(), "ok")
        XCTAssertThrowsError(try BottleStore.validateName(String(repeating: "x", count: 49)).get()) {
            XCTAssertEqual($0 as? BottleNameError, .tooLong(limit: 48))
        }
        XCTAssertThrowsError(try BottleStore.validateName("a:b").get()) {
            XCTAssertEqual($0 as? BottleNameError, .invalidCharacters)
        }
    }

    func testRelativePaths() throws {
        let bottle = try store.create(BottleSettings(name: "Paths"))
        let exe = bottle.driveC.appendingPathComponent("Games/run.exe")
        XCTAssertEqual(bottle.relativePath(of: exe), "drive_c/Games/run.exe")
        XCTAssertEqual(bottle.resolve(relativePath: "drive_c/Games/run.exe").path, exe.path)
        XCTAssertNil(bottle.relativePath(of: URL(fileURLWithPath: "/somewhere/else.exe")))
        XCTAssertNil(bottle.relativePath(of: bottle.url))
    }
}
