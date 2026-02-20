import CoreGraphics
import XCTest
@testable import screencog

final class CLIOptionsTests: XCTestCase {
    func testParseAppAndOutput() throws {
        let options = try CLIOptions.parse(arguments: ["--app", "Safari", "--output", "/tmp/out.png"])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertEqual(options.appName, "Safari")
        XCTAssertNil(options.windowTitle)
        XCTAssertNil(options.windowID)
        XCTAssertNil(options.pid)
        XCTAssertNil(options.bundleID)
        XCTAssertEqual(options.outputPath, "/tmp/out.png")
        XCTAssertFalse(options.writeToStdout)
        XCTAssertFalse(options.listWindows)
        XCTAssertFalse(options.jsonOutput)
        XCTAssertEqual(options.format, .png)
        XCTAssertEqual(options.quality, 90)
        XCTAssertNil(options.crop)
        XCTAssertFalse(options.disablePrivateSpaceRestore)
        XCTAssertFalse(options.restoreDebugJSON)
        XCTAssertTrue(options.restoreHardReattach)
        XCTAssertTrue(options.restoreSpaceNudge)
        XCTAssertNil(options.restoreForceWindowID)
        XCTAssertFalse(options.restoreStrict)
        XCTAssertEqual(options.restoreDiffThreshold, 0.05)
        XCTAssertTrue(options.restoreStrictSpaceFallback)
    }

    func testParseWindowIdAndStdout() throws {
        let options = try CLIOptions.parse(arguments: ["--window-id", "12345", "--stdout"])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertNil(options.appName)
        XCTAssertNil(options.windowTitle)
        XCTAssertEqual(options.windowID, 12345)
        XCTAssertNil(options.outputPath)
        XCTAssertTrue(options.writeToStdout)
        XCTAssertFalse(options.listWindows)
        XCTAssertFalse(options.jsonOutput)
    }

    func testListModeAllowsNoTarget() throws {
        let options = try CLIOptions.parse(arguments: ["--list", "--json"])
        XCTAssertEqual(options.mode, .list)
        XCTAssertTrue(options.listWindows)
        XCTAssertFalse(options.listTabs)
        XCTAssertTrue(options.jsonOutput)
    }

    func testParseListTabsSwitchesToListMode() throws {
        let options = try CLIOptions.parse(arguments: ["--tabs", "--json"])
        XCTAssertEqual(options.mode, .list)
        XCTAssertFalse(options.listWindows)
        XCTAssertTrue(options.listTabs)
        XCTAssertTrue(options.jsonOutput)
    }

    func testParseListTabsWithChromeProfileFilter() throws {
        let options = try CLIOptions.parse(arguments: ["list", "--tabs", "--app", "Google Chrome", "--chrome-profile", "attila@markster.ai", "--json"])
        XCTAssertEqual(options.mode, .list)
        XCTAssertTrue(options.listTabs)
        XCTAssertEqual(options.appName, "Google Chrome")
        XCTAssertEqual(options.chromeProfile, "attila@markster.ai")
    }

    func testParseCaptureTabWithEmailProfileDefaultsToGoogleChrome() throws {
        let options = try CLIOptions.parse(arguments: [
            "capture",
            "--chrome-profile", "attila@markster.ai",
            "--tab-title", "event-scout-web",
            "--output", "/tmp/out.png"
        ])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertEqual(options.chromeProfile, "attila@markster.ai")
        XCTAssertEqual(options.tabTitle, "event-scout-web")
        XCTAssertEqual(options.appName, "Google Chrome")
    }

    func testParseTitleOnlyAndOutput() throws {
        let options = try CLIOptions.parse(arguments: ["--window-title", "ChatGPT", "--output", "/tmp/out.png"])
        XCTAssertNil(options.appName)
        XCTAssertEqual(options.windowTitle, "ChatGPT")
        XCTAssertNil(options.windowID)
        XCTAssertEqual(options.outputPath, "/tmp/out.png")
    }

    func testParseListWithFilters() throws {
        let options = try CLIOptions.parse(arguments: ["--list", "--json", "--app", "ChatGPT", "--window-title", "ChatGPT"])
        XCTAssertEqual(options.mode, .list)
        XCTAssertTrue(options.listWindows)
        XCTAssertTrue(options.jsonOutput)
        XCTAssertEqual(options.appName, "ChatGPT")
        XCTAssertEqual(options.windowTitle, "ChatGPT")
    }

    func testParseCaptureWithFormatCropAndWait() throws {
        let options = try CLIOptions.parse(arguments: [
            "--app", "Ghostty",
            "--output", "/tmp/out.jpg",
            "--format", "jpg",
            "--quality", "77",
            "--crop", "10,20,300,200",
            "--wait-for-window", "2.5",
            "--retry-interval-ms", "120",
            "--result-json"
        ])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertEqual(options.format, .jpg)
        XCTAssertEqual(options.quality, 77)
        XCTAssertEqual(options.crop, CropRegion(x: 10, y: 20, width: 300, height: 200))
        XCTAssertEqual(options.waitForWindowSeconds, 2.5)
        XCTAssertEqual(options.retryIntervalMS, 120)
        XCTAssertTrue(options.resultJSON)
    }

    func testParseInputClick() throws {
        let options = try CLIOptions.parse(arguments: ["input", "--app", "ChatGPT", "--click", "100,200"])
        XCTAssertEqual(options.mode, .input)
        XCTAssertEqual(options.appName, "ChatGPT")
        XCTAssertEqual(options.inputAction, .click(x: 100, y: 200, button: .left, count: 1))
        XCTAssertTrue(options.restoreState)
    }

    func testParseInputTypeAndNoRestore() throws {
        let options = try CLIOptions.parse(arguments: ["--window-id", "123", "--type", "hello", "--no-restore-state"])
        XCTAssertEqual(options.mode, .input)
        XCTAssertEqual(options.inputAction, .type("hello"))
        XCTAssertFalse(options.restoreState)
    }

    func testParseCaptureWithPreInputAction() throws {
        let options = try CLIOptions.parse(arguments: ["capture", "--app", "Connect IQ Device Simulator", "--click", "360,520", "--output", "/tmp/out.png", "--no-private-space-restore", "--no-restore-hard-reattach", "--no-restore-space-nudge", "--restore-force-window-id", "44100"])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertEqual(options.inputAction, .click(x: 360, y: 520, button: .left, count: 1))
        XCTAssertEqual(options.outputPath, "/tmp/out.png")
        XCTAssertTrue(options.disablePrivateSpaceRestore)
        XCTAssertFalse(options.restoreHardReattach)
        XCTAssertFalse(options.restoreSpaceNudge)
        XCTAssertEqual(options.restoreForceWindowID, 44100)
    }

    func testParseRestoreDebugJsonEnablesResultJson() throws {
        let options = try CLIOptions.parse(arguments: ["capture", "--app", "Safari", "--output", "/tmp/out.png", "--restore-debug-json"])
        XCTAssertEqual(options.mode, .capture)
        XCTAssertTrue(options.restoreDebugJSON)
        XCTAssertTrue(options.resultJSON)
    }

    func testParseRestoreStrictFlagsAndThreshold() throws {
        let options = try CLIOptions.parse(arguments: [
            "capture",
            "--app", "Safari",
            "--output", "/tmp/out.png",
            "--no-restore-strict",
            "--restore-diff-threshold", "0.07",
            "--no-restore-strict-space-fallback"
        ])
        XCTAssertFalse(options.restoreStrict)
        XCTAssertEqual(options.restoreDiffThreshold, 0.07)
        XCTAssertFalse(options.restoreStrictSpaceFallback)
    }

    func testParsePermissionsMode() throws {
        let options = try CLIOptions.parse(arguments: ["permissions", "--json", "--prompt"])
        XCTAssertEqual(options.mode, .permissions)
        XCTAssertTrue(options.jsonOutput)
        XCTAssertTrue(options.promptAccessibility)
        XCTAssertTrue(options.promptScreenRecording)
    }

    func testParseRejectsMissingTarget() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: ["--output", "/tmp/a.png"]))
    }

    func testParseRejectsMissingOutputAndStdout() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: ["--app", "Safari"]))
    }

    func testParseRejectsUnknownArgument() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: ["--bogus"]))
    }

    func testParseRejectsMixedInputActions() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: ["input", "--app", "ChatGPT", "--click", "1,2", "--type", "x"]))
    }

    func testParseRejectsResultJsonWithStdout() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: ["--app", "Safari", "--stdout", "--result-json"]))
    }

    func testParseRejectsInvalidRestoreDiffThreshold() {
        XCTAssertThrowsError(try CLIOptions.parse(arguments: [
            "capture",
            "--app", "Safari",
            "--output", "/tmp/out.png",
            "--restore-diff-threshold", "1.5"
        ]))
    }
}

final class WindowMatcherTests: XCTestCase {
    func testResolveByWindowId() throws {
        let options = try CLIOptions.parse(arguments: ["--window-id", "41", "--stdout"])
        let windows = [
            WindowInfo(
                id: 41,
                ownerName: "Safari",
                windowName: "Tab 1",
                ownerPID: 111,
                bounds: CGRect(x: 0, y: 0, width: 1200, height: 800),
                layer: 0,
                alpha: 1.0,
                isOnScreen: true,
                bundleID: nil
            )
        ]

        let target = try WindowMatcher.resolveTarget(options: options, windows: windows)
        XCTAssertEqual(target.id, 41)
    }

    func testResolveByAppPrefersVisibleWindow() throws {
        let options = try CLIOptions.parse(arguments: ["--app", "Safari", "--stdout"])
        let hidden = WindowInfo(
            id: 12,
            ownerName: "Safari",
            windowName: "Hidden",
            ownerPID: 222,
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            layer: 0,
            alpha: 1.0,
            isOnScreen: false,
            bundleID: nil
        )
        let visible = WindowInfo(
            id: 13,
            ownerName: "Safari",
            windowName: "Visible",
            ownerPID: 222,
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            bundleID: nil
        )

        let target = try WindowMatcher.resolveTarget(options: options, windows: [hidden, visible])
        XCTAssertEqual(target.id, 13)
    }

    func testResolveByTitleOnly() throws {
        let options = try CLIOptions.parse(arguments: ["--window-title", "Dashboard", "--stdout"])
        let windows = [
            WindowInfo(
                id: 20,
                ownerName: "ChatGPT",
                windowName: "Home",
                ownerPID: 10,
                bounds: CGRect(x: 0, y: 0, width: 500, height: 500),
                layer: 0,
                alpha: 1.0,
                isOnScreen: true,
                bundleID: nil
            ),
            WindowInfo(
                id: 21,
                ownerName: "ChatGPT",
                windowName: "Dashboard",
                ownerPID: 10,
                bounds: CGRect(x: 0, y: 0, width: 700, height: 700),
                layer: 0,
                alpha: 1.0,
                isOnScreen: false,
                bundleID: nil
            )
        ]
        let target = try WindowMatcher.resolveTarget(options: options, windows: windows)
        XCTAssertEqual(target.id, 21)
    }

    func testResolveSmarterAppSelectionPrefersNamedWindow() throws {
        let options = try CLIOptions.parse(arguments: ["--app", "Connect IQ Device Simulator", "--stdout"])
        let untitledLarge = WindowInfo(
            id: 100,
            ownerName: "Connect IQ Device Simulator",
            windowName: "",
            ownerPID: 42,
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 1200),
            layer: 0,
            alpha: 1.0,
            isOnScreen: false,
            bundleID: nil
        )
        let namedPrimary = WindowInfo(
            id: 101,
            ownerName: "Connect IQ Device Simulator",
            windowName: "CIQ Simulator - Instinct 2X Solar",
            ownerPID: 42,
            bounds: CGRect(x: 0, y: 0, width: 384, height: 563),
            layer: 0,
            alpha: 1.0,
            isOnScreen: false,
            bundleID: nil
        )
        let target = try WindowMatcher.resolveTarget(options: options, windows: [untitledLarge, namedPrimary])
        XCTAssertEqual(target.id, 101)
    }

    func testResolveActivatedChromeWindowPrefersMatchingTabTitle() throws {
        let options = try CLIOptions.parse(arguments: ["--app", "Google Chrome", "--stdout"])
        let wrongWindow = WindowInfo(
            id: 360,
            ownerName: "Google Chrome",
            windowName: "slnqu73bjvy2.deploy.mcp-use.com | 525: SSL handshake failed",
            ownerPID: 596,
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            bundleID: "com.google.Chrome"
        )
        let targetWindow = WindowInfo(
            id: 478,
            ownerName: "Google Chrome",
            windowName: "event-scout-web",
            ownerPID: 596,
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 900),
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            bundleID: "com.google.Chrome"
        )

        let refined = WindowMatcher.resolveActivatedChromeWindow(
            options: options,
            activatedTabTitle: "event-scout-web",
            windows: [wrongWindow, targetWindow]
        )
        XCTAssertEqual(refined?.id, 478)
    }
}

final class CoreGraphicsFallbackTests: XCTestCase {
    func testFallbackSymbolIsAvailable() {
        XCTAssertTrue(ScreenCogService.isCoreGraphicsFallbackAvailable)
    }
}
