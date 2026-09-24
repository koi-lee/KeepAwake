import XCTest
@testable import KeepAwake

final class KeepAwakeTests: XCTestCase {
    func testV1ConfigDecodesWithV2Defaults() throws {
        let data = #"""
        {
          "watchedApps": [
            { "name": "Claude", "bundleId": "com.anthropic.claude" }
          ],
          "checkInterval": 5,
          "showNotifications": false
        }
        """#.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(config.configVersion, 1)
        XCTAssertEqual(config.watchedApps.first?.name, "Claude")
        XCTAssertEqual(config.sleepMode, .system)
        XCTAssertEqual(config.defaultDurationMinutes, 60)
        XCTAssertEqual(config.lowBatteryThreshold, 20)
        XCTAssertFalse(config.onlyOnPower)
    }

    func testV2ConfigRoundTripsSafetySettings() throws {
        let original = AppConfig(
            watchedApps: [WatchedApp(name: "Codex", bundleId: "com.openai.codex")],
            checkInterval: 3,
            showNotifications: true,
            sleepMode: .display,
            defaultDurationMinutes: 90,
            lowBatteryThreshold: 30,
            onlyOnPower: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.configVersion, AppConfig.currentVersion)
        XCTAssertEqual(decoded.sleepMode, .display)
        XCTAssertEqual(decoded.defaultDurationMinutes, 90)
        XCTAssertEqual(decoded.lowBatteryThreshold, 30)
        XCTAssertTrue(decoded.onlyOnPower)
    }

    func testV2ConfigRoundTripsUserSettings() throws {
        var original = AppConfig.default
        original.checkInterval = 12
        original.defaultDurationMinutes = 45
        original.logSizeLimitBytes = 256 * 1024

        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded.checkInterval, 12)
        XCTAssertEqual(decoded.defaultDurationMinutes, 45)
        XCTAssertEqual(decoded.logSizeLimitBytes, 256 * 1024)
        XCTAssertEqual(AppConfig.logSizeLimitKB(decoded.logSizeLimitBytes), 256)
    }

    func testAppDataUsesSandboxSafeApplicationSupportPaths() {
        XCTAssertTrue(ConfigLoader.configPath.path.hasSuffix("Application Support/KeepAwake/config.json"))
        XCTAssertTrue(ConfigLoader.networkLogPath.path.hasSuffix("Application Support/KeepAwake/Logs/network.log"))
        XCTAssertTrue(ConfigLoader.legacyConfigPath.path.hasSuffix(".keepawake.json"))
    }

    func testTimedSessionExpiresOnlyAfterEnd() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = ManualSession(
            startedAt: start,
            kind: .timed(endsAt: start.addingTimeInterval(60))
        )

        XCTAssertFalse(session.isExpired(at: start.addingTimeInterval(59)))
        XCTAssertTrue(session.isExpired(at: start.addingTimeInterval(60)))
    }

    func testIndefiniteSessionDoesNotExpire() {
        let session = ManualSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            kind: .indefinite
        )

        XCTAssertFalse(session.isExpired(at: Date(timeIntervalSince1970: 10_000)))
        XCTAssertNil(session.endsAt)
    }

    func testDurationTextUsesReadableUnits() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            ManualSession.durationText(until: now.addingTimeInterval(30), now: now),
            "30 秒"
        )
        XCTAssertEqual(
            ManualSession.durationText(until: now.addingTimeInterval(90 * 60), now: now),
            "1 小时 30 分钟"
        )
        XCTAssertEqual(ManualSession.durationText(minutes: 90), "1 小时 30 分钟")
    }

    func testPowerSafetyParsesBatteryAndACOutput() {
        let battery = """
        Now drawing from 'Battery Power'
         -InternalBattery-0 (id=1234567)\t79%; discharging; 3:12 remaining
        """
        let ac = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=1234567)\t100%; charging; 0:00 remaining
        """

        XCTAssertEqual(PowerSafety.parse(battery), PowerStatus(isOnBattery: true, batteryPercent: 79, isKnown: true))
        XCTAssertEqual(PowerSafety.parse(ac), PowerStatus(isOnBattery: false, batteryPercent: 100, isKnown: true))
    }

    func testPowerSafetyBlocksOnlyOnPowerWhenStatusIsUnknown() {
        XCTAssertTrue(
            PowerSafety.shouldBlock(
                status: .unknown,
                lowBatteryThreshold: 20,
                onlyOnPower: true
            )
        )
        XCTAssertFalse(
            PowerSafety.shouldBlock(
                status: .unknown,
                lowBatteryThreshold: 20,
                onlyOnPower: false
            )
        )
    }

    func testPowerSafetyBlocksLowBatteryButAllowsAC() {
        let battery = PowerStatus(isOnBattery: true, batteryPercent: 10, isKnown: true)
        let ac = PowerStatus(isOnBattery: false, batteryPercent: 10, isKnown: true)

        XCTAssertTrue(PowerSafety.shouldBlock(status: battery, lowBatteryThreshold: 20, onlyOnPower: false))
        XCTAssertFalse(PowerSafety.shouldBlock(status: ac, lowBatteryThreshold: 20, onlyOnPower: false))
    }

    func testPowerSafetyTreatsThresholdAsInclusiveAndZeroAsDisabled() {
        let atThreshold = PowerStatus(isOnBattery: true, batteryPercent: 20, isKnown: true)
        let aboveThreshold = PowerStatus(isOnBattery: true, batteryPercent: 21, isKnown: true)

        XCTAssertTrue(PowerSafety.shouldBlock(status: atThreshold, lowBatteryThreshold: 20, onlyOnPower: false))
        XCTAssertFalse(PowerSafety.shouldBlock(status: aboveThreshold, lowBatteryThreshold: 20, onlyOnPower: false))
        XCTAssertFalse(PowerSafety.shouldBlock(status: atThreshold, lowBatteryThreshold: 0, onlyOnPower: false))
    }
}
