import Foundation
import Darwin

@main
struct ScreenCogCLI {
    static func main() async {
        do {
            let options = try CLIOptions.parse(arguments: Array(CommandLine.arguments.dropFirst()))
            let service = ScreenCogService()

            if options.mode == .list || options.listWindows {
                let listing: String
                if options.listTabs {
                    let tabs = try ChromeTabController.listTabs(options: options)
                    listing = ChromeTabController.formatTabListing(tabs, json: options.jsonOutput)
                } else {
                    listing = service.listWindows(
                        json: options.jsonOutput,
                        appFilter: options.appName,
                        titleFilter: options.windowTitle
                    )
                }
                FileHandle.standardOutput.write(Data((listing + "\n").utf8))
                exit(0)
            }

            switch options.mode {
            case .capture:
                let outcome = try await service.capture(options: options)
                if options.writeToStdout {
                    FileHandle.standardOutput.write(outcome.data)
                } else if let outputPath = options.outputPath {
                    let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
                    try outcome.data.write(to: outputURL, options: .atomic)
                    if options.resultJSON {
                        var payload: [String: Any] = [
                            "mode": "capture",
                            "outputPath": outputURL.path,
                            "format": options.format.normalized.rawValue,
                            "width": outcome.width,
                            "height": outcome.height,
                            "captureMethod": outcome.captureMethod,
                            "restoreVerified": outcome.restoreVerified,
                            "window": [
                                "id": outcome.selectedWindow.id,
                                "ownerName": outcome.selectedWindow.ownerName,
                                "windowName": outcome.selectedWindow.windowName,
                                "ownerPID": outcome.selectedWindow.ownerPID,
                                "bundleID": outcome.selectedWindow.bundleID ?? ""
                            ]
                        ]
                        if let diagnostics = outcome.restoreDiagnostics {
                            var restorePayload: [String: Any] = [
                                "before": runtimeSnapshotJSON(diagnostics.before),
                                "after": runtimeSnapshotJSON(diagnostics.after)
                            ]
                            if let parity = diagnostics.parity {
                                restorePayload["parity"] = restoreParityJSON(parity)
                            }
                            restorePayload["strictRecoveryAttempted"] = diagnostics.strictRecoveryAttempted
                            restorePayload["strictRecoverySucceeded"] = diagnostics.strictRecoverySucceeded
                            payload["restoreDiagnostics"] = restorePayload
                        }
                        if let json = encodeJSON(payload) {
                            FileHandle.standardOutput.write(Data((json + "\n").utf8))
                        } else {
                            FileHandle.standardError.write(Data("Saved screenshot to \(outputURL.path)\n".utf8))
                        }
                    } else {
                        FileHandle.standardError.write(Data("Saved screenshot to \(outputURL.path)\n".utf8))
                    }
                } else {
                    throw ScreencogError.usage("Missing output target")
                }
                exit(0)
            case .input:
                let outcome = try await service.input(options: options)
                if options.resultJSON {
                    var actionPayload: [String: Any] = [:]
                    switch outcome.action {
                    case .click(let x, let y, let button, let count):
                        actionPayload = ["type": "click", "x": x, "y": y, "button": button.rawValue, "count": count]
                    case .type(let text):
                        actionPayload = ["type": "type", "text": text]
                    case .scroll(let dx, let dy):
                        actionPayload = ["type": "scroll", "dx": dx, "dy": dy]
                    }
                    let payload: [String: Any] = [
                        "mode": "input",
                        "restoredState": outcome.restoredState,
                        "restoreVerified": outcome.restoreVerified,
                        "action": actionPayload,
                        "window": [
                            "id": outcome.selectedWindow.id,
                            "ownerName": outcome.selectedWindow.ownerName,
                            "windowName": outcome.selectedWindow.windowName,
                            "ownerPID": outcome.selectedWindow.ownerPID,
                            "bundleID": outcome.selectedWindow.bundleID ?? ""
                        ]
                    ]
                    if let json = encodeJSON(payload) {
                        FileHandle.standardOutput.write(Data((json + "\n").utf8))
                    }
                } else {
                    FileHandle.standardError.write(Data("Input action executed successfully.\n".utf8))
                }
                exit(0)
            case .permissions:
                let status = service.checkPermissions(options: options)
                if options.jsonOutput || options.resultJSON {
                    let payload: [String: Any] = [
                        "mode": "permissions",
                        "accessibilityGranted": status.accessibilityGranted,
                        "screenRecordingGranted": status.screenRecordingGranted,
                        "automationSystemEventsGranted": status.automationSystemEventsGranted,
                        "automationSystemEventsError": status.automationSystemEventsError ?? NSNull(),
                        "privateSpaceAPIAvailable": status.privateSpaceAPIAvailable
                    ]
                    if let json = encodeJSON(payload) {
                        FileHandle.standardOutput.write(Data((json + "\n").utf8))
                    }
                } else {
                    let text = """
                    Accessibility: \(status.accessibilityGranted ? "granted" : "missing")
                    Screen Recording: \(status.screenRecordingGranted ? "granted" : "missing")
                    Automation (System Events): \(status.automationSystemEventsGranted ? "granted" : "missing")
                    Automation Error: \(status.automationSystemEventsError ?? "none")
                    Private Space API: \(status.privateSpaceAPIAvailable ? "available" : "unavailable (fallback)")
                    """
                    FileHandle.standardOutput.write(Data((text + "\n").utf8))
                }
                exit((!status.accessibilityGranted || !status.screenRecordingGranted) ? 3 : 0)
            case .list:
                exit(0)
            }
        } catch let error as ScreencogError {
            FileHandle.standardError.write(Data("\(error.description)\n".utf8))
            exit(2)
        } catch {
            FileHandle.standardError.write(Data("Unexpected error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

private func encodeJSON(_ object: Any) -> String? {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return nil
    }
    return text
}

private func runtimeSnapshotJSON(_ snapshot: RuntimeSnapshot) -> [String: Any] {
    let topWindowJSON: Any = snapshot.activeSpaceTopWindow.map(windowJSON) ?? NSNull()
    let frontmostPID: Any = snapshot.frontmostAppPID.map { Int($0) } ?? NSNull()
    let menuBarOwnerPID: Any = snapshot.menuBarOwnerPID.map { Int($0) } ?? NSNull()
    let focusedWindowID: Any = snapshot.focusedWindowID.map { Int($0) } ?? NSNull()
    let focusedWindowIsFullScreen: Any = snapshot.focusedWindowIsFullScreen ?? NSNull()
    let stacks: [String: [Int]] = snapshot.activeSpaceWindowStacks.mapValues { ids in
        ids.map { Int($0) }
    }
    return [
        "frontmostAppPID": frontmostPID,
        "frontmostAppBundleID": snapshot.frontmostAppBundleID ?? NSNull(),
        "menuBarOwnerPID": menuBarOwnerPID,
        "focusedWindowID": focusedWindowID,
        "focusedWindowTitle": snapshot.focusedWindowTitle ?? NSNull(),
        "focusedWindowIsFullScreen": focusedWindowIsFullScreen,
        "activeSpaces": snapshot.activeSpaces,
        "activeSpaceWindowStacks": stacks,
        "activeSpaceTopWindow": topWindowJSON,
        "desktopScreenshotPath": snapshot.desktopScreenshotPath ?? NSNull()
    ]
}

private func windowJSON(_ window: WindowInfo) -> [String: Any] {
    [
        "id": window.id,
        "ownerName": window.ownerName,
        "windowName": window.windowName,
        "ownerPID": window.ownerPID,
        "bundleID": window.bundleID as Any,
        "isOnScreen": window.isOnScreen,
        "bounds": [
            "x": window.bounds.origin.x,
            "y": window.bounds.origin.y,
            "width": window.bounds.width,
            "height": window.bounds.height
        ]
    ]
}

private func restoreParityJSON(_ parity: RestoreParityReport) -> [String: Any] {
    [
        "passed": parity.passed,
        "menuBarCompared": parity.menuBarCompared,
        "menuBarMatches": parity.menuBarMatches,
        "menuBarBeforePID": parity.menuBarBeforePID.map { Int($0) } ?? NSNull(),
        "menuBarAfterPID": parity.menuBarAfterPID.map { Int($0) } ?? NSNull(),
        "screenshotCompared": parity.screenshotCompared,
        "screenshotDiffScore": parity.screenshotDiffScore ?? NSNull(),
        "screenshotDiffThreshold": parity.screenshotDiffThreshold
    ]
}
