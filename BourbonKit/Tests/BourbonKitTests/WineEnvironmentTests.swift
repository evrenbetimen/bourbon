import XCTest
@testable import BourbonKit

final class WineEnvironmentTests: XCTestCase {
    func testBaseEnvironment() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle { $0.syncMode = .none })
        XCTAssertEqual(env, ["WINEPREFIX": "/bottles/test", "WINEDEBUG": "fixme-all"])
    }

    func testMSyncAlsoEnablesESync() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle { $0.syncMode = .msync })
        XCTAssertEqual(env["WINEMSYNC"], "1")
        XCTAssertEqual(env["WINEESYNC"], "1")
    }

    func testESyncOnly() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle { $0.syncMode = .esync })
        XCTAssertEqual(env["WINEESYNC"], "1")
        XCTAssertNil(env["WINEMSYNC"])
    }

    func testDXVKOptions() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle {
            $0.dxvkEnabled = true
            $0.dxvkAsync = false
            $0.dxvkHUD = .fps
        })
        XCTAssertEqual(env["WINEDLLOVERRIDES"], WineEnvironment.dxvkOverrides)
        XCTAssertNil(env["DXVK_ASYNC"])
        XCTAssertEqual(env["DXVK_HUD"], "fps")
    }

    func testDXVKOptionsIgnoredWhenDisabled() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle { $0.dxvkHUD = .full })
        XCTAssertNil(env["DXVK_HUD"])
        XCTAssertNil(env["WINEDLLOVERRIDES"])
    }

    func testMetalAndRosettaFlags() throws {
        let env = try WineEnvironment.make(for: Fixtures.bottle {
            $0.metalHUD = true
            $0.metalTrace = true
            $0.advertiseAVX = true
            $0.logLevel = .quiet
        })
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
        XCTAssertEqual(env["METAL_CAPTURE_ENABLED"], "1")
        XCTAssertEqual(env["ROSETTA_ADVERTISE_AVX"], "1")
        XCTAssertEqual(env["WINEDEBUG"], "-all")
    }

    func testProgramOverridesBottleWhichOverridesDefaults() throws {
        let bottle = Fixtures.bottle { $0.environment = ["WINEDEBUG": "+all", "SHARED": "bottle"] }
        let program = ProgramSettings(environment: ["SHARED": "program"], locale: "tr_TR.UTF-8")
        let env = try WineEnvironment.make(for: bottle, program: program)
        XCTAssertEqual(env["WINEDEBUG"], "+all")
        XCTAssertEqual(env["SHARED"], "program")
        XCTAssertEqual(env["LC_ALL"], "tr_TR.UTF-8")
        XCTAssertEqual(env["LANG"], "tr_TR.UTF-8")
    }

    func testCustomDLLOverridesKeepDXVK() throws {
        let bottle = Fixtures.bottle {
            $0.dxvkEnabled = true
            $0.environment = ["WINEDLLOVERRIDES": "winemenubuilder.exe=d"]
        }
        let env = try WineEnvironment.make(for: bottle)
        XCTAssertEqual(env["WINEDLLOVERRIDES"], WineEnvironment.dxvkOverrides + ";winemenubuilder.exe=d")
    }

    func testRejectsInvalidNames() {
        let bottle = Fixtures.bottle { $0.environment = ["1BAD": "x"] }
        XCTAssertThrowsError(try WineEnvironment.make(for: bottle)) {
            XCTAssertEqual($0 as? WineEnvironmentError, .invalidVariableName("1BAD"))
        }
    }

    func testRejectsReservedNames() {
        let program = ProgramSettings(environment: ["WINEPREFIX": "/elsewhere"])
        XCTAssertThrowsError(try WineEnvironment.make(for: Fixtures.bottle(), program: program)) {
            XCTAssertEqual($0 as? WineEnvironmentError, .reservedVariable("WINEPREFIX"))
        }
    }
}
