import XCTest
@testable import BourbonKit

final class PEFileTests: XCTestCase {
    func testParses64BitGUIExecutable() throws {
        let pe = try PEFile(data: Fixtures.peImage())
        XCTAssertEqual(pe.machine, .amd64)
        XCTAssertTrue(pe.is64Bit)
        XCTAssertEqual(pe.subsystem, .gui)
        XCTAssertFalse(pe.isDLL)
        XCTAssertEqual(pe.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testParses32BitConsoleExecutable() throws {
        let pe = try PEFile(data: Fixtures.peImage(machine: 0x014C, magic: 0x010B, subsystem: 3,
                                                   optionalHeaderSize: 224))
        XCTAssertEqual(pe.machine, .i386)
        XCTAssertFalse(pe.is64Bit)
        XCTAssertEqual(pe.subsystem, .console)
    }

    func testDetectsDLLAndARM64() throws {
        let pe = try PEFile(data: Fixtures.peImage(machine: 0xAA64, characteristics: 0x2022))
        XCTAssertEqual(pe.machine, .arm64)
        XCTAssertTrue(pe.isDLL)
    }

    func testUnknownMachineKeepsRawValue() throws {
        let pe = try PEFile(data: Fixtures.peImage(machine: 0x1234))
        XCTAssertEqual(pe.machine, .unknown(0x1234))
        XCTAssertEqual(pe.machine.displayName, "Unknown (0x1234)")
    }

    func testMissingOptionalHeaderFallsBackToMachine() throws {
        let pe = try PEFile(data: Fixtures.peImage(optionalHeaderSize: 0))
        XCTAssertTrue(pe.is64Bit)
        XCTAssertNil(pe.subsystem)
    }

    func testRejectsNonExecutables() {
        XCTAssertThrowsError(try PEFile(data: Data(repeating: 0x41, count: 128))) {
            XCTAssertEqual($0 as? PEError, .notAnExecutable)
        }
    }

    func testRejectsTruncatedData() {
        XCTAssertThrowsError(try PEFile(data: Data([0x4D, 0x5A]))) {
            XCTAssertEqual($0 as? PEError, .truncated)
        }
        var image = Fixtures.peImage()
        image = image.prefix(0x82)
        XCTAssertThrowsError(try PEFile(data: image)) {
            XCTAssertEqual($0 as? PEError, .truncated)
        }
    }

    func testRejectsBadSignature() {
        var image = Fixtures.peImage()
        image[0x80] = 0x4E // "NE" instead of "PE"
        XCTAssertThrowsError(try PEFile(data: image)) {
            XCTAssertEqual($0 as? PEError, .invalidSignature)
        }
    }

    func testOutOfRangeHeaderOffsetIsTruncated() {
        var image = Fixtures.peImage()
        image[0x3C] = 0xFF
        image[0x3D] = 0xFF
        XCTAssertThrowsError(try PEFile(data: image)) {
            XCTAssertEqual($0 as? PEError, .truncated)
        }
    }

    func testWorksOnDataSlices() throws {
        let padded = Data([0, 0, 0]) + Fixtures.peImage()
        let slice = padded.dropFirst(3)
        XCTAssertNotEqual(slice.startIndex, 0)
        XCTAssertEqual(try PEFile(data: slice).machine, .amd64)
    }

    func testReadsFromDisk() throws {
        let directory = try TemporaryDirectory()
        let file = try directory.touch("game.exe", contents: Fixtures.peImage())
        XCTAssertEqual(try PEFile(url: file).subsystem, .gui)
    }
}
