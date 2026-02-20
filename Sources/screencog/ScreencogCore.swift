import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum ScreencogError: Error, CustomStringConvertible {
    case usage(String)
    case permissionDenied(String)
    case targetNotFound(String)
    case captureFailed(String)
    case io(String)

    var description: String {
        switch self {
        case .usage(let message):
            return "Usage error: \(message)"
        case .permissionDenied(let message):
            return "Permission error: \(message)"
        case .targetNotFound(let message):
            return "Target error: \(message)"
        case .captureFailed(let message):
            return "Capture error: \(message)"
        case .io(let message):
            return "I/O error: \(message)"
        }
    }
}

enum CommandMode: Equatable {
    case capture
    case list
    case input
    case permissions
}

enum OutputFormat: String, Equatable {
    case png
    case jpg
    case jpeg

    var normalized: OutputFormat {
        switch self {
        case .jpeg: return .jpg
        default: return self
        }
    }
}

enum MouseButtonKind: String, Equatable {
    case left
    case right

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        }
    }

    var downEvent: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        }
    }

    var upEvent: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        }
    }
}

enum InputAction: Equatable {
    case click(x: CGFloat, y: CGFloat, button: MouseButtonKind, count: Int)
    case type(String)
    case scroll(dx: Int32, dy: Int32)
}

struct CropRegion: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    static func parse(_ value: String) throws -> CropRegion {
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 4,
              let x = Int(parts[0]),
              let y = Int(parts[1]),
              let width = Int(parts[2]),
              let height = Int(parts[3]) else {
            throw ScreencogError.usage("Invalid --crop value '\(value)'. Expected x,y,width,height")
        }
        guard width > 0, height > 0 else {
            throw ScreencogError.usage("Crop width and height must be positive")
        }
        return CropRegion(x: x, y: y, width: width, height: height)
    }
}

struct CLIOptions: Equatable {
    let mode: CommandMode
    let appName: String?
    let windowTitle: String?
    let windowID: CGWindowID?
    let pid: pid_t?
    let bundleID: String?
    let tabTitle: String?
    let tabURL: String?
    let tabIndex: Int?
    let chromeProfile: String?
    let outputPath: String?
    let writeToStdout: Bool
    let listWindows: Bool
    let listTabs: Bool
    let jsonOutput: Bool
    let resultJSON: Bool
    let restoreDebugJSON: Bool
    let format: OutputFormat
    let quality: Int
    let crop: CropRegion?
    let waitForWindowSeconds: Double
    let retryIntervalMS: UInt64
    let inputAction: InputAction?
    let restoreState: Bool
    let disablePrivateSpaceRestore: Bool
    let restoreHardReattach: Bool
    let restoreSpaceNudge: Bool
    let restoreForceWindowID: CGWindowID?
    let restoreStrict: Bool
    let restoreDiffThreshold: Double
    let restoreStrictSpaceFallback: Bool
    let promptAccessibility: Bool
    let promptScreenRecording: Bool
    let promptPermissions: Bool

    static func parse(arguments: [String]) throws -> CLIOptions {
        var mode: CommandMode?
        var appName: String?
        var windowTitle: String?
        var windowID: CGWindowID?
        var pid: pid_t?
        var bundleID: String?
        var tabTitle: String?
        var tabURL: String?
        var tabIndex: Int?
        var chromeProfile: String?
        var outputPath: String?
        var writeToStdout = false
        var listWindows = false
        var listTabs = false
        var jsonOutput = false
        var resultJSON = false
        var restoreDebugJSON = false
        var format: OutputFormat = .png
        var quality = 90
        var crop: CropRegion?
        var waitForWindowSeconds = 0.0
        var retryIntervalMS: UInt64 = 250
        var inputAction: InputAction?
        var restoreState = true
        var disablePrivateSpaceRestore = false
        var restoreHardReattach = true
        var restoreSpaceNudge = true
        var restoreForceWindowID: CGWindowID?
        var restoreStrict = false
        var restoreDiffThreshold = 0.05
        var restoreStrictSpaceFallback = true
        var promptAccessibility = false
        var promptScreenRecording = false
        var promptPermissions = true

        var args = arguments
        if let first = args.first {
            switch first {
            case "capture":
                mode = .capture
                args.removeFirst()
            case "list":
                mode = .list
                listWindows = true
                args.removeFirst()
            case "input":
                mode = .input
                args.removeFirst()
            case "permissions":
                mode = .permissions
                args.removeFirst()
            default:
                break
            }
        }

        var index = 0
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--app":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --app")
                }
                appName = args[index]
            case "--window-id":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --window-id")
                }
                guard let parsed = UInt32(args[index]) else {
                    throw ScreencogError.usage("Invalid --window-id value: \(args[index])")
                }
                windowID = parsed
            case "--window-title":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --window-title")
                }
                windowTitle = args[index]
            case "--pid":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --pid")
                }
                guard let parsed = Int32(args[index]) else {
                    throw ScreencogError.usage("Invalid --pid value: \(args[index])")
                }
                pid = parsed
            case "--bundle-id":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --bundle-id")
                }
                bundleID = args[index]
            case "--tab-title":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --tab-title")
                }
                tabTitle = args[index]
            case "--tab-url":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --tab-url")
                }
                tabURL = args[index]
            case "--tab-index":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --tab-index")
                }
                guard let parsed = Int(args[index]), parsed > 0 else {
                    throw ScreencogError.usage("Invalid --tab-index value '\(args[index])'. Use 1-based positive integer")
                }
                tabIndex = parsed
            case "--chrome-profile":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --chrome-profile")
                }
                chromeProfile = args[index]
            case "--output":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --output")
                }
                outputPath = args[index]
            case "--stdout":
                writeToStdout = true
            case "--list":
                listWindows = true
                mode = .list
            case "--tabs":
                listTabs = true
                mode = .list
            case "--json":
                jsonOutput = true
            case "--result-json":
                resultJSON = true
            case "--restore-debug-json":
                restoreDebugJSON = true
            case "--format":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --format")
                }
                guard let parsed = OutputFormat(rawValue: args[index].lowercased()) else {
                    throw ScreencogError.usage("Invalid --format value '\(args[index])'. Use png or jpg")
                }
                format = parsed.normalized
            case "--quality":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --quality")
                }
                guard let parsed = Int(args[index]), parsed >= 1, parsed <= 100 else {
                    throw ScreencogError.usage("Invalid --quality value '\(args[index])'. Use 1-100")
                }
                quality = parsed
            case "--crop":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --crop")
                }
                crop = try CropRegion.parse(args[index])
            case "--wait-for-window":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --wait-for-window")
                }
                guard let parsed = Double(args[index]), parsed >= 0 else {
                    throw ScreencogError.usage("Invalid --wait-for-window value '\(args[index])'")
                }
                waitForWindowSeconds = parsed
            case "--retry-interval-ms":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --retry-interval-ms")
                }
                guard let parsed = UInt64(args[index]), parsed > 0 else {
                    throw ScreencogError.usage("Invalid --retry-interval-ms value '\(args[index])'")
                }
                retryIntervalMS = parsed
            case "--click":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --click")
                }
                let point = try parsePoint(args[index], optionName: "--click")
                try ensureNoExistingInputAction(inputAction)
                inputAction = .click(x: point.x, y: point.y, button: .left, count: 1)
                if mode == nil { mode = .input }
            case "--double-click":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --double-click")
                }
                let point = try parsePoint(args[index], optionName: "--double-click")
                try ensureNoExistingInputAction(inputAction)
                inputAction = .click(x: point.x, y: point.y, button: .left, count: 2)
                if mode == nil { mode = .input }
            case "--right-click":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --right-click")
                }
                let point = try parsePoint(args[index], optionName: "--right-click")
                try ensureNoExistingInputAction(inputAction)
                inputAction = .click(x: point.x, y: point.y, button: .right, count: 1)
                if mode == nil { mode = .input }
            case "--type":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --type")
                }
                try ensureNoExistingInputAction(inputAction)
                inputAction = .type(args[index])
                if mode == nil { mode = .input }
            case "--scroll":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --scroll")
                }
                let scroll = try parseScroll(args[index])
                try ensureNoExistingInputAction(inputAction)
                inputAction = .scroll(dx: scroll.dx, dy: scroll.dy)
                if mode == nil { mode = .input }
            case "--no-restore-state":
                restoreState = false
            case "--no-private-space-restore":
                disablePrivateSpaceRestore = true
            case "--no-restore-hard-reattach":
                restoreHardReattach = false
            case "--no-restore-space-nudge":
                restoreSpaceNudge = false
            case "--restore-force-window-id":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --restore-force-window-id")
                }
                guard let parsed = UInt32(args[index]) else {
                    throw ScreencogError.usage("Invalid --restore-force-window-id value: \(args[index])")
                }
                restoreForceWindowID = parsed
            case "--restore-strict":
                restoreStrict = true
            case "--no-restore-strict":
                restoreStrict = false
            case "--restore-diff-threshold":
                index += 1
                guard index < args.count else {
                    throw ScreencogError.usage("Missing value for --restore-diff-threshold")
                }
                guard let parsed = Double(args[index]), parsed >= 0.0, parsed <= 1.0 else {
                    throw ScreencogError.usage("Invalid --restore-diff-threshold value '\(args[index])'. Use 0.0-1.0")
                }
                restoreDiffThreshold = parsed
            case "--no-restore-strict-space-fallback":
                restoreStrictSpaceFallback = false
            case "--permissions", "--verify-permissions":
                mode = .permissions
            case "--prompt-accessibility":
                promptAccessibility = true
                mode = .permissions
            case "--prompt-screen-recording":
                promptScreenRecording = true
                mode = .permissions
            case "--prompt":
                promptAccessibility = true
                promptScreenRecording = true
                mode = .permissions
            case "--no-permission-prompt":
                promptPermissions = false
            case "--help", "-h":
                throw ScreencogError.usage(Self.helpText)
            default:
                throw ScreencogError.usage("Unknown argument: \(arg)\n\n\(Self.helpText)")
            }
            index += 1
        }

        if mode == nil {
            if listWindows || listTabs {
                mode = .list
            } else if inputAction != nil && outputPath == nil && !writeToStdout {
                mode = .input
            } else {
                mode = .capture
            }
        }

        if mode == .input && inputAction != nil && (outputPath != nil || writeToStdout) {
            mode = .capture
        }

        if tabTitle != nil || tabURL != nil || tabIndex != nil {
            if appName == nil && bundleID == nil && pid == nil && windowID == nil {
                if let chromeProfile, chromeProfile.lowercased().contains("chrome") {
                    appName = chromeProfile
                } else {
                    appName = "Google Chrome"
                }
            }
        }

        if mode == .capture && (appName == nil && windowID == nil && windowTitle == nil && pid == nil && bundleID == nil) {
            throw ScreencogError.usage("Capture requires at least one selector: --app/--window-title/--window-id/--pid/--bundle-id")
        }

        if mode == .input && (appName == nil && windowID == nil && windowTitle == nil && pid == nil && bundleID == nil) {
            throw ScreencogError.usage("Input requires at least one selector: --app/--window-title/--window-id/--pid/--bundle-id")
        }

        if mode == .input && inputAction == nil {
            throw ScreencogError.usage("Input mode requires one action: --click/--double-click/--right-click/--type/--scroll")
        }

        if mode == .capture && outputPath == nil && !writeToStdout {
            throw ScreencogError.usage("Provide --output <path> or --stdout\n\n\(Self.helpText)")
        }

        if outputPath != nil && writeToStdout {
            throw ScreencogError.usage("Choose either --output <path> or --stdout, not both")
        }

        if mode == .capture && writeToStdout && resultJSON {
            throw ScreencogError.usage("Cannot combine --stdout with --result-json")
        }

        if mode == .input && (outputPath != nil || writeToStdout) {
            throw ScreencogError.usage("Input mode does not support --output or --stdout")
        }

        if mode == .permissions && inputAction != nil {
            throw ScreencogError.usage("Permissions mode cannot include input actions")
        }

        if mode == .list && resultJSON {
            jsonOutput = true
        }

        if restoreDebugJSON {
            resultJSON = true
        }

        return CLIOptions(
            mode: mode ?? .capture,
            appName: appName,
            windowTitle: windowTitle,
            windowID: windowID,
            pid: pid,
            bundleID: bundleID,
            tabTitle: tabTitle,
            tabURL: tabURL,
            tabIndex: tabIndex,
            chromeProfile: chromeProfile,
            outputPath: outputPath,
            writeToStdout: writeToStdout,
            listWindows: listWindows,
            listTabs: listTabs,
            jsonOutput: jsonOutput,
            resultJSON: resultJSON,
            restoreDebugJSON: restoreDebugJSON,
            format: format.normalized,
            quality: quality,
            crop: crop,
            waitForWindowSeconds: waitForWindowSeconds,
            retryIntervalMS: retryIntervalMS,
            inputAction: inputAction,
            restoreState: restoreState,
            disablePrivateSpaceRestore: disablePrivateSpaceRestore,
            restoreHardReattach: restoreHardReattach,
            restoreSpaceNudge: restoreSpaceNudge,
            restoreForceWindowID: restoreForceWindowID,
            restoreStrict: restoreStrict,
            restoreDiffThreshold: restoreDiffThreshold,
            restoreStrictSpaceFallback: restoreStrictSpaceFallback,
            promptAccessibility: promptAccessibility,
            promptScreenRecording: promptScreenRecording,
            promptPermissions: promptPermissions
        )
    }

    private static func ensureNoExistingInputAction(_ existing: InputAction?) throws {
        if existing != nil {
            throw ScreencogError.usage("Only one input action can be specified per command")
        }
    }

    private static func parsePoint(_ value: String, optionName: String) throws -> (x: CGFloat, y: CGFloat) {
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]) else {
            throw ScreencogError.usage("Invalid \(optionName) value '\(value)'. Expected x,y")
        }
        return (CGFloat(x), CGFloat(y))
    }

    private static func parseScroll(_ value: String) throws -> (dx: Int32, dy: Int32) {
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count == 1, let dy = Int32(parts[0]) {
            return (0, dy)
        }
        if parts.count == 2, let dx = Int32(parts[0]), let dy = Int32(parts[1]) {
            return (dx, dy)
        }
        throw ScreencogError.usage("Invalid --scroll value '\(value)'. Expected dy or dx,dy")
    }

    static let helpText = """
    screencog - targeted window screenshot capture for macOS

    Usage:
      screencog capture --app <AppName> --output <path.png>
      screencog capture --window-id <id> --output <path.png>
      screencog capture --app "Connect IQ Device Simulator" --click 360,520 --output /tmp/after-click.png
      screencog list --json
      screencog list --tabs --json --app "Google Chrome"
      screencog input --window-id <id> --click 120,80
      screencog permissions --json --prompt

    Legacy capture usage also works:
      screencog --app <AppName> --output <path.png>
      screencog --window-title <title> --output <path.png>
      screencog --window-id <id> --output <path.png>
      screencog --list --json

    Options:
      Global:
      --help, -h                   Show this help text
      --no-permission-prompt       Disable permission prompts for operations that require them

      Selectors:
      --app <AppName>              Target app name (for example, "Safari")
      --window-title <title>       Target window title (exact/partial match)
      --window-id <id>             Target window id from --list
      --pid <pid>                  Target process id
      --bundle-id <id>             Target bundle id (for example, com.apple.Safari)
      --tab-title <text>           Chrome tab title contains text (switches tab before capture)
      --tab-url <text>             Chrome tab URL contains text (switches tab before capture)
      --tab-index <n>              Chrome tab index (1-based) in front Chrome window
      --chrome-profile <value>     Chrome profile hint for tab matching; if value contains "chrome", it's treated as app name

      Capture:
      --output <path>              Output PNG path
      --stdout                     Write PNG bytes to stdout instead of a file
      --format <png|jpg>           Output format (default: png)
      --quality <1-100>            JPEG quality when --format jpg (default: 90)
      --crop x,y,w,h               Crop final image in pixels
      --wait-for-window <seconds>  Wait until target appears before failing
      --retry-interval-ms <ms>     Retry interval while waiting (default: 250)
      --result-json                Print structured capture result JSON
      --restore-debug-json         Include before/after restore snapshots in result JSON

      Listing:
      --list                       Print discoverable windows and exit
      --tabs                       In list mode, enumerate Chrome tabs grouped by window/profile
      --json                       Emit JSON output for --list

      Input:
      --click x,y                  Left click at window-relative coordinates
      --double-click x,y           Double left click at window-relative coordinates
      --right-click x,y            Right click at window-relative coordinates
      --type <text>                Type text into the target window after activation
      --scroll <dy|dx,dy>          Scroll wheel input
      --no-restore-state           Do not restore prior app/window state after input
                                  In capture mode, input action runs before screenshot using one shared restore snapshot
      --no-private-space-restore   Disable private API Space restore (enabled by default with fallback)
      --no-restore-hard-reattach   Disable aggressive exact-window reattach fallback during restore
      --no-restore-space-nudge     Disable Mission Control nudge fallback (Ctrl+Right then Ctrl+Left)
      --restore-force-window-id    Force restore target window id (advanced/manual override)
      --restore-strict             Enforce strict restore parity checks (default: disabled)
      --no-restore-strict          Disable strict restore parity checks
      --restore-diff-threshold     Max screenshot diff ratio for strict parity (0.0-1.0, default: 0.05)
      --no-restore-strict-space-fallback
                                  Disable one-shot Space move-and-restore fallback when strict parity fails

      Permissions:
      --permissions                Run permission diagnostics
      --verify-permissions         Alias for --permissions
      --prompt-accessibility       Prompt for Accessibility permission if missing
      --prompt-screen-recording    Prompt for Screen Recording permission if missing
      --prompt                     Prompt for both permissions
    """
}

struct WindowInfo: Equatable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String
    let ownerPID: pid_t
    let bounds: CGRect
    let layer: Int
    let alpha: Double
    let isOnScreen: Bool
    let bundleID: String?

    var area: CGFloat {
        bounds.width * bounds.height
    }

    var isLikelyRenderableWithoutActivation: Bool {
        isOnScreen && alpha > 0.0 && bounds.width > 1 && bounds.height > 1
    }
}

struct ChromeTabSession {
    let applicationName: String
    let originalWindowID: Int
    let originalTabIndex: Int
    let targetTabTitle: String
}

struct ChromeTabInfo: Equatable {
    let index: Int
    let title: String
    let url: String
}

struct ChromeWindowTabListing: Equatable {
    let windowID: Int
    let windowName: String
    let profileName: String?
    let tabs: [ChromeTabInfo]
}

private actor OneShotContinuation<T> {
    private var resumed = false

    func resume(_ continuation: CheckedContinuation<T, Error>, with result: Result<T, Error>) {
        guard !resumed else { return }
        resumed = true
        continuation.resume(with: result)
    }
}

private actor OneShotValueContinuation<T> {
    private var resumed = false

    func resume(_ continuation: CheckedContinuation<T, Never>, value: T) {
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }
}

enum WindowInventory {
    static func allWindows() -> [WindowInfo] {
        guard let raw = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let bundleByPID: [pid_t: String] = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return (app.processIdentifier, bundleID)
            }
        )

        return raw.compactMap { entry in
            guard
                let id = entry[kCGWindowNumber as String] as? UInt32,
                let owner = entry[kCGWindowOwnerName as String] as? String,
                let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t
            else {
                return nil
            }

            let windowName = entry[kCGWindowName as String] as? String ?? ""
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1.0
            let isOnScreen = (entry[kCGWindowIsOnscreen as String] as? Int ?? 0) != 0
            let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary
            let bounds = boundsDict.flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero

            return WindowInfo(
                id: id,
                ownerName: owner,
                windowName: windowName,
                ownerPID: ownerPID,
                bounds: bounds,
                layer: layer,
                alpha: alpha,
                isOnScreen: isOnScreen,
                bundleID: bundleByPID[ownerPID]
            )
        }
    }
}

enum WindowMatcher {
    static func resolveTarget(options: CLIOptions, windows: [WindowInfo]) throws -> WindowInfo {
        if let id = options.windowID {
            guard let match = windows.first(where: { $0.id == id }) else {
                throw ScreencogError.targetNotFound("No window found for id \(id)")
            }
            return match
        }

        var candidates = windows.filter { $0.layer == 0 }

        if let pid = options.pid {
            candidates = candidates.filter { $0.ownerPID == pid }
        }

        if let bundleID = options.bundleID?.lowercased(), !bundleID.isEmpty {
            candidates = candidates.filter { ($0.bundleID ?? "").lowercased() == bundleID }
        }

        if let appName = options.appName?.trimmingCharacters(in: .whitespacesAndNewlines), !appName.isEmpty {
            let appLower = appName.lowercased()
            candidates = candidates.filter { window in
                window.ownerName.lowercased().contains(appLower)
            }
        }

        if let title = options.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            let titleLower = title.lowercased()
            candidates = candidates.filter { window in
                window.windowName.lowercased().contains(titleLower)
            }
        }

        guard !candidates.isEmpty else {
            var reason = "No windows matched"
            if let appName = options.appName, !appName.isEmpty {
                reason += " app '\(appName)'"
            }
            if let title = options.windowTitle, !title.isEmpty {
                reason += options.appName == nil ? " title '\(title)'" : " and title '\(title)'"
            }
            if let pid = options.pid {
                reason += " pid '\(pid)'"
            }
            if let bundleID = options.bundleID, !bundleID.isEmpty {
                reason += " bundle '\(bundleID)'"
            }
            throw ScreencogError.targetNotFound(reason)
        }

        let appLower = options.appName?.lowercased()
        func ownerMatchStrength(_ owner: String) -> Int {
            guard let appLower else { return 0 }
            let ownerLower = owner.lowercased()
            if ownerLower == appLower { return 2 }
            if ownerLower.contains(appLower) { return 1 }
            return 0
        }

        func titleQuality(_ title: String) -> Int {
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized.isEmpty || normalized == "(untitled)" {
                return 0
            }
            if normalized.contains("window") || normalized.contains("panel") || normalized.contains("service") {
                return 1
            }
            return 2
        }

        // Smarter app/title selection: prefer strong owner match, on-screen renderability, meaningful titles, then larger content windows.
        return candidates.sorted { lhs, rhs in
            let lhsOwner = ownerMatchStrength(lhs.ownerName)
            let rhsOwner = ownerMatchStrength(rhs.ownerName)
            if lhsOwner != rhsOwner { return lhsOwner > rhsOwner }

            if lhs.isLikelyRenderableWithoutActivation != rhs.isLikelyRenderableWithoutActivation {
                return lhs.isLikelyRenderableWithoutActivation && !rhs.isLikelyRenderableWithoutActivation
            }

            let lhsTitle = titleQuality(lhs.windowName)
            let rhsTitle = titleQuality(rhs.windowName)
            if lhsTitle != rhsTitle { return lhsTitle > rhsTitle }

            if lhs.area != rhs.area { return lhs.area > rhs.area }
            return lhs.id < rhs.id
        }.first!
    }

    static func resolveActivatedChromeWindow(
        options: CLIOptions,
        activatedTabTitle: String?,
        windows: [WindowInfo]
    ) -> WindowInfo? {
        guard let rawTitle = activatedTabTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else {
            return nil
        }
        let titleLower = rawTitle.lowercased()
        let appLower = (options.appName ?? "Google Chrome").lowercased()
        let candidates = windows.filter { window in
            window.layer == 0
            && window.ownerName.lowercased().contains(appLower)
            && window.windowName.lowercased().contains(titleLower)
        }
        guard !candidates.isEmpty else { return nil }

        return candidates.sorted { lhs, rhs in
            if lhs.isLikelyRenderableWithoutActivation != rhs.isLikelyRenderableWithoutActivation {
                return lhs.isLikelyRenderableWithoutActivation && !rhs.isLikelyRenderableWithoutActivation
            }
            if lhs.area != rhs.area { return lhs.area > rhs.area }
            return lhs.id < rhs.id
        }.first
    }
}

enum CapturePermissions {
    static func ensureScreenRecordingAccess(prompt: Bool) throws {
        if CGPreflightScreenCaptureAccess() {
            return
        }

        if prompt, CGRequestScreenCaptureAccess() {
            return
        }

        throw ScreencogError.permissionDenied(
            "Screen Recording access is required. Enable it in System Settings > Privacy & Security > Screen Recording."
        )
    }

    static func screenRecordingGranted(prompt: Bool) -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        if prompt {
            return CGRequestScreenCaptureAccess()
        }
        return false
    }
}

enum AccessibilityPermissions {
    static func isGranted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    static func ensureGranted(prompt: Bool) throws {
        guard isGranted(prompt: prompt) else {
            throw ScreencogError.permissionDenied(
                "Accessibility access is required for input simulation. Enable it in System Settings > Privacy & Security > Accessibility."
            )
        }
    }
}

enum ChromeTabController {
    static func listTabs(options: CLIOptions) throws -> [ChromeWindowTabListing] {
        let applicationName = resolvedApplicationName(options: options)
        let profileNeedle = resolvedProfileNeedle(options: options)
        let appLiteral = appleScriptLiteral(applicationName)
        let profileNeedleLiteral = profileNeedle.map(appleScriptLiteral) ?? "\"\""
        let hasProfileFilter = profileNeedle != nil ? "true" : "false"
        let fieldSeparator = "\u{001F}"
        let recordSeparator = "\u{001E}"
        let fieldSeparatorLiteral = appleScriptLiteral(fieldSeparator)
        let recordSeparatorLiteral = appleScriptLiteral(recordSeparator)

        let script = """
        with timeout of 8 seconds
          tell application \(appLiteral)
            if (count of windows) is 0 then return ""
            set fieldSep to \(fieldSeparatorLiteral)
            set recordSep to \(recordSeparatorLiteral)
            set hasProfileFilter to \(hasProfileFilter)
            set profileNeedle to \(profileNeedleLiteral)
            set rows to {}
            repeat with w in windows
              set wi to id of w
              set wn to ""
              set wg to ""
              try
                set wn to name of w
              end try
              try
                set wg to given name of w
              end try
              set includeWindow to true
              if hasProfileFilter then
                set includeWindow to false
                ignoring case
                  if wn contains profileNeedle then set includeWindow to true
                  if (includeWindow is false) and (wg contains profileNeedle) then set includeWindow to true
                end ignoring
                if includeWindow is false then
                  repeat with p in tabs of w
                    set pTitle to ""
                    set pURL to ""
                    try
                      set pTitle to title of p
                    end try
                    try
                      set pURL to URL of p
                    end try
                    ignoring case
                      if pTitle contains profileNeedle then
                        set includeWindow to true
                      else if pURL contains profileNeedle then
                        set includeWindow to true
                      end if
                    end ignoring
                    if includeWindow then exit repeat
                  end repeat
                end if
              end if
              if includeWindow then
                set ti to 0
                repeat with t in tabs of w
                  set ti to ti + 1
                  set tt to ""
                  set tu to ""
                  try
                    set tt to title of t
                  end try
                  try
                    set tu to URL of t
                  end try
                  set end of rows to ((wi as string) & fieldSep & (wg as string) & fieldSep & (wn as string) & fieldSep & (ti as string) & fieldSep & tt & fieldSep & tu)
                end repeat
              end if
            end repeat
            if (count of rows) is 0 then return ""
            set AppleScript's text item delimiters to recordSep
            set joined to rows as string
            set AppleScript's text item delimiters to ""
            return joined
          end tell
        end timeout
        """

        let raw = runAppleScript(script)
        if raw.hasPrefix("ERR:") {
            throw ScreencogError.targetNotFound("Chrome tab listing failed: \(raw)")
        }
        return parseTabListing(raw, fieldSeparator: fieldSeparator, recordSeparator: recordSeparator)
    }

    static func formatTabListing(_ listing: [ChromeWindowTabListing], json: Bool) -> String {
        if json {
            let payload: [[String: Any]] = listing.map { window in
                [
                    "windowID": window.windowID,
                    "windowName": window.windowName,
                    "profileName": window.profileName ?? NSNull(),
                    "tabs": window.tabs.sorted(by: { $0.index < $1.index }).map { tab in
                        [
                            "index": tab.index,
                            "title": tab.title,
                            "url": tab.url
                        ]
                    }
                ]
            }
            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return text
        }

        guard !listing.isEmpty else {
            return "No Chrome tabs matched."
        }

        var lines: [String] = []
        for window in listing.sorted(by: { $0.windowID < $1.windowID }) {
            lines.append("windowID=\(window.windowID)\tprofile=\(window.profileName ?? "")\tname=\(window.windowName)")
            for tab in window.tabs.sorted(by: { $0.index < $1.index }) {
                lines.append("  [\(tab.index)] \(tab.title)\t\(tab.url)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func activateTargetTab(options: CLIOptions) throws -> ChromeTabSession? {
        guard options.tabTitle != nil || options.tabURL != nil || options.tabIndex != nil else {
            return nil
        }
        let applicationName = resolvedApplicationName(options: options)
        let profileNeedle = resolvedProfileNeedle(options: options)

        let titleNeedle = options.tabTitle.map(appleScriptLiteral) ?? "\"\""
        let urlNeedle = options.tabURL.map(appleScriptLiteral) ?? "\"\""
        let profileNeedleLiteral = profileNeedle.map(appleScriptLiteral) ?? "\"\""
        let appLiteral = appleScriptLiteral(applicationName)
        let hasTitleFilter = options.tabTitle != nil ? "true" : "false"
        let hasURLFilter = options.tabURL != nil ? "true" : "false"
        let hasProfileFilter = profileNeedle != nil ? "true" : "false"
        let tabIndex = options.tabIndex ?? -1

        let script = """
        with timeout of 8 seconds
          tell application \(appLiteral)
            if (count of windows) is 0 then return "ERR:NO_WINDOWS"
            set origWinId to id of front window
            set origTab to active tab index of front window
            set targetWinId to -1
            set targetTab to -1

            if \(tabIndex) > 0 then
              set targetWinId to id of front window
              set targetTab to \(tabIndex)
            else
              set titleNeedle to \(titleNeedle)
              set urlNeedle to \(urlNeedle)
              set profileNeedle to \(profileNeedleLiteral)
              set hasTitleFilter to \(hasTitleFilter)
              set hasURLFilter to \(hasURLFilter)
              set hasProfileFilter to \(hasProfileFilter)
              repeat with w in windows
                set wi to id of w
                set includeWindow to true
                if hasProfileFilter then
                  set winName to ""
                  set winGivenName to ""
                  try
                    set winName to name of w
                  end try
                  try
                    set winGivenName to given name of w
                  end try
                  set includeWindow to false
                  ignoring case
                    if winName contains profileNeedle then set includeWindow to true
                    if (includeWindow is false) and (winGivenName contains profileNeedle) then set includeWindow to true
                  end ignoring
                  if includeWindow is false then
                    repeat with p in tabs of w
                      set pTitle to ""
                      set pURL to ""
                      try
                        set pTitle to title of p
                      end try
                      try
                        set pURL to URL of p
                      end try
                      ignoring case
                        if pTitle contains profileNeedle then
                          set includeWindow to true
                        else if pURL contains profileNeedle then
                          set includeWindow to true
                        end if
                      end ignoring
                      if includeWindow then exit repeat
                    end repeat
                  end if
                end if
                if includeWindow then
                set ti to 0
                repeat with t in tabs of w
                  set ti to ti + 1
                  set tTitle to ""
                  set tURL to ""
                  try
                    set tTitle to title of t
                  end try
                  try
                    set tURL to URL of t
                  end try
                  set titleMatch to true
                  set urlMatch to true
                  if hasTitleFilter then
                    set titleMatch to false
                    ignoring case
                      if tTitle contains titleNeedle then set titleMatch to true
                    end ignoring
                  end if
                  if hasURLFilter then
                    set urlMatch to false
                    ignoring case
                      if tURL contains urlNeedle then set urlMatch to true
                    end ignoring
                  end if
                  if titleMatch and urlMatch then
                    set targetWinId to wi
                    set targetTab to ti
                    exit repeat
                  end if
                end repeat
                end if
                if targetWinId is not -1 then exit repeat
              end repeat
            end if

            if targetWinId is -1 then return "ERR:NOT_FOUND"
            if (count of (windows whose id is targetWinId)) is 0 then return "ERR:WINDOW_GONE"
            set targetWindow to first window whose id is targetWinId
            set tabCount to count of tabs of targetWindow
            if targetTab < 1 then return "ERR:INVALID_TAB_INDEX"
            if targetTab > tabCount then return "ERR:TAB_INDEX_OOB"
            set index of targetWindow to 1
            set active tab index of targetWindow to targetTab
            set sep to (character id 31)
            set selectedTitle to ""
            try
              set selectedTitle to title of active tab of targetWindow
            end try
            return (origWinId as string) & sep & (origTab as string) & sep & selectedTitle
          end tell
        end timeout
        """

        let result = runAppleScript(script, timeoutSeconds: 12.0)
        if result.hasPrefix("ERR:") {
            throw ScreencogError.targetNotFound("Chrome tab selection failed: \(result)")
        }

        let parts = result.components(separatedBy: "\u{001F}")
        guard parts.count >= 2,
              let originalWindowID = Int(parts[0]),
              let originalTabIndex = Int(parts[1]) else {
            throw ScreencogError.captureFailed("Chrome tab activation returned unexpected response '\(result)'")
        }
        let targetTabTitle = parts.count >= 3 ? parts[2] : ""
        return ChromeTabSession(
            applicationName: applicationName,
            originalWindowID: originalWindowID,
            originalTabIndex: originalTabIndex,
            targetTabTitle: targetTabTitle
        )
    }

    static func restoreOriginalTab(_ session: ChromeTabSession) {
        let appLiteral = appleScriptLiteral(session.applicationName)
        let script = """
        tell application \(appLiteral)
          if (count of (windows whose id is \(session.originalWindowID))) is 0 then return
          set targetWindow to first window whose id is \(session.originalWindowID)
          set index of targetWindow to 1
          set tabCount to count of tabs of targetWindow
          if \(session.originalTabIndex) < 1 then return
          if \(session.originalTabIndex) > tabCount then return
          set active tab index of targetWindow to \(session.originalTabIndex)
        end tell
        """
        _ = runAppleScript(script, timeoutSeconds: 2.0)
    }

    private static func resolvedApplicationName(options: CLIOptions) -> String {
        if let appName = options.appName, !appName.isEmpty {
            return appName
        }
        if let chromeProfile = options.chromeProfile,
           chromeProfile.lowercased().contains("chrome") {
            return chromeProfile
        }
        return "Google Chrome"
    }

    private static func resolvedProfileNeedle(options: CLIOptions) -> String? {
        guard let chromeProfile = options.chromeProfile?.trimmingCharacters(in: .whitespacesAndNewlines),
              !chromeProfile.isEmpty else {
            return nil
        }
        if chromeProfile.lowercased().contains("chrome") {
            return nil
        }
        return chromeProfile
    }

    private static func parseTabListing(_ raw: String, fieldSeparator: String, recordSeparator: String) -> [ChromeWindowTabListing] {
        if raw.isEmpty {
            return []
        }
        var byWindowID: [Int: (windowName: String, profileName: String?, tabs: [ChromeTabInfo])] = [:]
        var order: [Int] = []

        for record in raw.components(separatedBy: recordSeparator) where !record.isEmpty {
            let fields = record.components(separatedBy: fieldSeparator)
            guard fields.count >= 6 else { continue }
            guard let windowID = Int(fields[0]), let tabIndex = Int(fields[3]) else { continue }
            let profileName = fields[1].isEmpty ? nil : fields[1]
            let windowName = fields[2]
            let title = fields[4]
            let url = fields[5]
            let tab = ChromeTabInfo(index: tabIndex, title: title, url: url)

            if byWindowID[windowID] == nil {
                order.append(windowID)
                byWindowID[windowID] = (windowName: windowName, profileName: profileName, tabs: [tab])
            } else {
                byWindowID[windowID]?.tabs.append(tab)
            }
        }

        return order.compactMap { windowID in
            guard let entry = byWindowID[windowID] else { return nil }
            return ChromeWindowTabListing(
                windowID: windowID,
                windowName: entry.windowName,
                profileName: entry.profileName,
                tabs: entry.tabs
            )
        }
    }

    private static func appleScriptLiteral(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func runAppleScript(_ source: String, timeoutSeconds: TimeInterval = 8.0) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return "ERR:RUN:\(error.localizedDescription)"
        }

        if let data = source.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        try? stdinPipe.fileHandleForWriting.close()

        let waitSemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            waitSemaphore.signal()
        }

        if waitSemaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            return "ERR:TIMEOUT"
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorText = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            let message = errorText.isEmpty ? "osascript failed" : errorText
            return "ERR:\(process.terminationStatus):\(message)"
        }
        return output
    }
}

enum AutomationPermissions {
    static func checkSystemEventsAccess() -> (granted: Bool, error: String?) {
        let script = """
        tell application "System Events"
          get name of first process
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else {
            return (false, "failed_to_create_script")
        }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            let number = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "unknown error"
            if let number {
                return (false, "code=\(number) \(message)")
            }
            return (false, message)
        }
        let text = result.stringValue ?? ""
        return text.isEmpty ? (false, "empty_result") : (true, nil)
    }
}

enum ImageEncoder {
    static func encode(_ image: CGImage, format: OutputFormat, quality: Int) throws -> Data {
        let data = NSMutableData()
        let normalized = format.normalized
        let typeIdentifier: CFString = normalized == .png ? UTType.png.identifier as CFString : UTType.jpeg.identifier as CFString

        guard let destination = CGImageDestinationCreateWithData(
            data,
            typeIdentifier,
            1,
            nil
        ) else {
            throw ScreencogError.io("Failed to create image destination for encoding")
        }

        if normalized == .jpg {
            let options: CFDictionary = [kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0] as CFDictionary
            CGImageDestinationAddImage(destination, image, options)
        } else {
            CGImageDestinationAddImage(destination, image, nil)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ScreencogError.io("Failed to finalize image data")
        }

        return data as Data
    }
}

enum WindowRenderRecovery {
    static func withTemporaryActivation(
        targetWindow: WindowInfo,
        promptPermissions: Bool,
        operation: @escaping () async throws -> CGImage
    ) async throws -> CGImage {
        guard let targetApp = NSRunningApplication(processIdentifier: targetWindow.ownerPID) else {
            throw ScreencogError.captureFailed("Unable to find target process for pid \(targetWindow.ownerPID)")
        }

        if !targetWindow.isOnScreen {
            AccessibilityWindowController.bestEffortUnminimize(
                pid: targetWindow.ownerPID,
                preferredTitle: targetWindow.windowName,
                prompt: promptPermissions
            )
        }

        await MainActor.run {
            if targetApp.isHidden {
                targetApp.unhide()
            }
            _ = targetApp.activate(options: [.activateAllWindows])
        }

        try await Task.sleep(nanoseconds: 120_000_000)
        return try await operation()
    }
}

enum AccessibilityWindowController {
    private static let axWindowNumberAttribute = "AXWindowNumber"
    private static let axFullScreenAttribute = "AXFullScreen"

    static func bestEffortUnminimize(pid: pid_t, preferredTitle: String, prompt: Bool) {
        guard AccessibilityPermissions.isGranted(prompt: prompt) else {
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
            let windows = windowsValue as? [AXUIElement],
            !windows.isEmpty
        else {
            return
        }

        let preferred = windows.first { window in
            guard let title = stringAttribute(window, key: kAXTitleAttribute) else {
                return false
            }
            return !preferredTitle.isEmpty && title == preferredTitle
        }

        if let preferred, boolAttribute(preferred, key: kAXMinimizedAttribute) == true {
            AXUIElementSetAttributeValue(preferred, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            return
        }

        for window in windows where boolAttribute(window, key: kAXMinimizedAttribute) == true {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            return
        }
    }

    private static func boolAttribute(_ element: AXUIElement, key: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private static func stringAttribute(_ element: AXUIElement, key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func windowsForPID(_ pid: pid_t) -> [AXUIElement]? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
            let windows = windowsValue as? [AXUIElement],
            !windows.isEmpty
        else {
            return nil
        }
        return windows
    }

    static func findWindowElement(pid: pid_t, preferredTitle: String?) -> AXUIElement? {
        guard let windows = windowsForPID(pid) else { return nil }

        if let preferredTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !preferredTitle.isEmpty {
            let preferredLower = preferredTitle.lowercased()
            if let exact = windows.first(where: {
                stringAttribute($0, key: kAXTitleAttribute)?.lowercased() == preferredLower
            }) {
                return exact
            }
            if let contains = windows.first(where: {
                (stringAttribute($0, key: kAXTitleAttribute) ?? "").lowercased().contains(preferredLower)
            }) {
                return contains
            }
        }

        return windows.first
    }

    static func findWindowElement(
        pid: pid_t,
        preferredWindowID: CGWindowID?,
        preferredTitle: String?
    ) -> AXUIElement? {
        guard let windows = windowsForPID(pid) else { return nil }

        if let preferredWindowID,
           let exact = windows.first(where: { windowNumber($0) == preferredWindowID }) {
            return exact
        }

        return findWindowElement(pid: pid, preferredTitle: preferredTitle)
    }

    static func findFullScreenWindowElement(pid: pid_t, preferredTitle: String?) -> AXUIElement? {
        guard let windows = windowsForPID(pid) else { return nil }
        let fullScreenWindows = windows.filter { boolAttribute($0, key: axFullScreenAttribute) == true }
        guard !fullScreenWindows.isEmpty else { return nil }

        if let preferredTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !preferredTitle.isEmpty {
            let preferredLower = preferredTitle.lowercased()
            if let exact = fullScreenWindows.first(where: {
                stringAttribute($0, key: kAXTitleAttribute)?.lowercased() == preferredLower
            }) {
                return exact
            }
            if let contains = fullScreenWindows.first(where: {
                (stringAttribute($0, key: kAXTitleAttribute) ?? "").lowercased().contains(preferredLower)
            }) {
                return contains
            }
        }

        return fullScreenWindows.first
    }

    static func hasFullScreenWindow(pid: pid_t) -> Bool {
        findFullScreenWindowElement(pid: pid, preferredTitle: nil) != nil
    }

    static func isWindowMinimized(_ window: AXUIElement) -> Bool {
        boolAttribute(window, key: kAXMinimizedAttribute) ?? false
    }

    static func setWindowMinimized(_ window: AXUIElement, minimized: Bool) {
        let value: CFTypeRef = minimized ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
    }

    static func raiseWindow(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    static func isWindowFullScreen(_ window: AXUIElement) -> Bool? {
        boolAttribute(window, key: axFullScreenAttribute)
    }

    static func setWindowFullScreen(_ window: AXUIElement, fullScreen: Bool) {
        let value: CFTypeRef = fullScreen ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(window, axFullScreenAttribute as CFString, value)
    }

    static func focusedWindowTitle() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let rawWindow = focusedWindow else {
            return nil
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        return stringAttribute(window, key: kAXTitleAttribute)
    }

    static func focusedWindowID() -> CGWindowID? {
        let system = AXUIElementCreateSystemWide()
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let rawWindow = focusedWindow else {
            return nil
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        return windowNumber(window)
    }

    static func focusedWindowTitle(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let rawWindow = focusedWindow else {
            return nil
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        return stringAttribute(window, key: kAXTitleAttribute)
    }

    static func focusedWindowID(pid: pid_t) -> CGWindowID? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let rawWindow = focusedWindow else {
            return nil
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        return windowNumber(window)
    }

    static func windowNumber(_ window: AXUIElement) -> CGWindowID? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, axWindowNumberAttribute as CFString, &value) == .success else {
            return nil
        }
        if let n = value as? NSNumber {
            return CGWindowID(n.uint32Value)
        }
        return nil
    }
}

struct CaptureOutcome {
    let data: Data
    let selectedWindow: WindowInfo
    let width: Int
    let height: Int
    let captureMethod: String
    let restoreVerified: Bool
    let restoreDiagnostics: RestoreDiagnostics?
}

struct InputOutcome {
    let selectedWindow: WindowInfo
    let action: InputAction
    let restoredState: Bool
    let restoreVerified: Bool
}

struct PermissionStatus {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
    let automationSystemEventsGranted: Bool
    let automationSystemEventsError: String?
    let privateSpaceAPIAvailable: Bool
}

struct RuntimeSnapshot {
    let frontmostAppPID: pid_t?
    let frontmostAppBundleID: String?
    let menuBarOwnerPID: pid_t?
    let focusedWindowID: CGWindowID?
    let focusedWindowTitle: String?
    let focusedWindowIsFullScreen: Bool?
    let activeSpaces: [String: UInt64]
    let activeSpaceWindowStacks: [String: [CGWindowID]]
    let activeSpaceTopWindow: WindowInfo?
    let desktopScreenshotPath: String?
}

struct RestoreDiagnostics {
    let before: RuntimeSnapshot
    let after: RuntimeSnapshot
    let parity: RestoreParityReport?
    let strictRecoveryAttempted: Bool
    let strictRecoverySucceeded: Bool
}

struct RestoreParityReport {
    let passed: Bool
    let menuBarCompared: Bool
    let menuBarMatches: Bool
    let menuBarBeforePID: pid_t?
    let menuBarAfterPID: pid_t?
    let screenshotCompared: Bool
    let screenshotDiffScore: Double?
    let screenshotDiffThreshold: Double
}

struct FocusSnapshot {
    let appPID: pid_t?
    let appBundleID: String?
    let windowTitle: String?
    let foregroundWindowBefore: WindowInfo?
    let foregroundWindowWasFullScreen: Bool?
    let preferAXFullscreenRestore: Bool
    let foregroundWindowSpace: SpaceLocation?
    let spaces: SpaceSnapshot?
}

struct TargetInteractionSnapshot {
    let app: NSRunningApplication
    let targetWindowID: CGWindowID
    let appWasHidden: Bool
    let windowElement: AXUIElement?
    let windowWasMinimized: Bool
    let focusedWindowIDBefore: CGWindowID?
    let focusedWindowTitleBefore: String?
    let targetSpaceLocation: SpaceLocation?
    let topWindowBeforeInteraction: WindowInfo?
}

struct SpaceSnapshot {
    let displayToSpace: [String: UInt64]
}

struct SpaceLocation: Equatable {
    let displayID: String
    let spaceID: UInt64
}

enum SpaceStepDirection {
    case right
    case left
}

enum SpaceController {
    typealias CGSConnectionID = Int32
    typealias CGSSpaceID = UInt64
    typealias MainConnectionIDFn = @convention(c) () -> CGSConnectionID
    typealias CopyManagedDisplaySpacesFn = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>?
    typealias SetCurrentSpaceFn = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> Int32
    typealias OrderWindowFn = @convention(c) (CGSConnectionID, CGWindowID, Int32, CGWindowID) -> Int32

    private struct API {
        let mainConnectionID: MainConnectionIDFn
        let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn
        let setCurrentSpace: SetCurrentSpaceFn
        let orderWindow: OrderWindowFn?
    }

    private static let api: API? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            return nil
        }

        guard
            let mainPtr = dlsym(handle, "CGSMainConnectionID"),
            let copyPtr = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
            let setPtr = dlsym(handle, "CGSManagedDisplaySetCurrentSpace")
        else {
            return nil
        }

        let orderPtr = dlsym(handle, "CGSOrderWindow")

        return API(
            mainConnectionID: unsafeBitCast(mainPtr, to: MainConnectionIDFn.self),
            copyManagedDisplaySpaces: unsafeBitCast(copyPtr, to: CopyManagedDisplaySpacesFn.self),
            setCurrentSpace: unsafeBitCast(setPtr, to: SetCurrentSpaceFn.self),
            orderWindow: orderPtr.map { unsafeBitCast($0, to: OrderWindowFn.self) }
        )
    }()

    static var isAvailable: Bool {
        api != nil
    }

    static func captureSnapshot() -> SpaceSnapshot? {
        guard let api else { return nil }
        let cid = api.mainConnectionID()
        guard let raw = api.copyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return nil
        }

        var mapping: [String: UInt64] = [:]
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String else {
                continue
            }

            if let current = display["Current Space"] as? [String: Any], let id = parseSpaceID(current) {
                mapping[displayID] = id
                continue
            }

            if let spaces = display["Spaces"] as? [[String: Any]] {
                if let current = spaces.first(where: { (($0["Current Space"] as? Int) ?? 0) == 1 || (($0["isCurrent"] as? Bool) ?? false) }),
                   let id = parseSpaceID(current) {
                    mapping[displayID] = id
                }
            }
        }

        if mapping.isEmpty {
            return nil
        }

        return SpaceSnapshot(displayToSpace: mapping)
    }

    static func restoreSnapshot(_ snapshot: SpaceSnapshot) -> Bool {
        guard let api else { return false }
        let cid = api.mainConnectionID()
        var success = true

        for (displayID, spaceID) in snapshot.displayToSpace {
            let result = api.setCurrentSpace(cid, displayID as CFString, spaceID)
            if result != 0 {
                success = false
            }
            usleep(20_000)
        }

        return success
    }

    static func matchesSnapshot(_ snapshot: SpaceSnapshot) -> Bool {
        guard let current = captureSnapshot() else { return false }
        for (display, expectedSpace) in snapshot.displayToSpace {
            guard let currentSpace = current.displayToSpace[display], currentSpace == expectedSpace else {
                return false
            }
        }
        return true
    }

    static func activeSpaceWindowStacksRaw() -> [String: [CGWindowID]] {
        guard let api else { return [:] }
        let cid = api.mainConnectionID()
        guard let raw = api.copyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return [:]
        }

        var stacks: [String: [CGWindowID]] = [:]
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String else {
                continue
            }

            if let currentSpace = display["Current Space"] as? [String: Any] {
                stacks[displayID] = parseWindowIDs(currentSpace)
                continue
            }

            if let spaces = display["Spaces"] as? [[String: Any]],
               let current = spaces.first(where: { (($0["Current Space"] as? Int) ?? 0) == 1 || (($0["isCurrent"] as? Bool) ?? false) }) {
                stacks[displayID] = parseWindowIDs(current)
            }
        }

        return stacks
    }

    static func windowSpaceMap() -> [CGWindowID: SpaceLocation] {
        guard let api else { return [:] }
        let cid = api.mainConnectionID()
        guard let raw = api.copyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return [:]
        }

        var map: [CGWindowID: SpaceLocation] = [:]
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String else {
                continue
            }

            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    guard let spaceID = parseSpaceID(space) else { continue }
                    let location = SpaceLocation(displayID: displayID, spaceID: spaceID)
                    for windowID in parseWindowIDs(space) {
                        map[windowID] = location
                    }
                }
            }

            if let currentSpace = display["Current Space"] as? [String: Any], let spaceID = parseSpaceID(currentSpace) {
                let location = SpaceLocation(displayID: displayID, spaceID: spaceID)
                for windowID in parseWindowIDs(currentSpace) {
                    map[windowID] = location
                }
            }
        }

        return map
    }

    static func restoreLocation(_ location: SpaceLocation) -> Bool {
        guard let api else { return false }
        let cid = api.mainConnectionID()
        return api.setCurrentSpace(cid, location.displayID as CFString, location.spaceID) == 0
    }

    static func orderWindowToFront(_ windowID: CGWindowID) -> Bool {
        guard let api, let orderWindow = api.orderWindow else {
            return false
        }
        let cid = api.mainConnectionID()
        // Window ordering mode 1 is "above"; relative window 0 means top of stack.
        let result = orderWindow(cid, windowID, 1, 0)
        return result == 0
    }

    static func moveActiveDisplaysToNeighbor(_ direction: SpaceStepDirection) -> Bool {
        guard let api else { return false }
        let cid = api.mainConnectionID()
        guard let raw = api.copyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }

        var movedAny = false
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String else { continue }
            guard let spaces = display["Spaces"] as? [[String: Any]], !spaces.isEmpty else { continue }

            var orderedSpaceIDs: [UInt64] = []
            var currentIndex: Int?
            for space in spaces {
                guard let sid = parseSpaceID(space) else { continue }
                orderedSpaceIDs.append(sid)
                let isCurrent = ((space["Current Space"] as? Int) ?? 0) == 1 || ((space["isCurrent"] as? Bool) ?? false)
                if isCurrent {
                    currentIndex = orderedSpaceIDs.count - 1
                }
            }
            if currentIndex == nil,
               let currentSpace = display["Current Space"] as? [String: Any],
               let currentID = parseSpaceID(currentSpace),
               let idx = orderedSpaceIDs.firstIndex(of: currentID) {
                currentIndex = idx
            }

            guard let index = currentIndex else { continue }
            let delta = (direction == .right) ? -1 : 1
            let next = index + delta
            guard next >= 0, next < orderedSpaceIDs.count else { continue }
            let targetSpaceID = orderedSpaceIDs[next]
            if api.setCurrentSpace(cid, displayID as CFString, targetSpaceID) == 0 {
                movedAny = true
                usleep(22_000)
            }
        }

        return movedAny
    }

    static func transitionPlanToSnapshot(_ target: SpaceSnapshot, maxSteps: Int = 8) -> (direction: SpaceStepDirection, steps: Int)? {
        guard let api else { return nil }
        let cid = api.mainConnectionID()
        guard let raw = api.copyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else {
            return nil
        }

        for display in raw {
            guard let displayID = display["Display Identifier"] as? String else { continue }
            guard let targetSpaceID = target.displayToSpace[displayID] else { continue }
            guard let spaces = display["Spaces"] as? [[String: Any]], !spaces.isEmpty else { continue }

            let orderedSpaceIDs: [UInt64] = spaces.compactMap(parseSpaceID)
            guard !orderedSpaceIDs.isEmpty else { continue }

            var currentSpaceID: UInt64?
            if let current = display["Current Space"] as? [String: Any] {
                currentSpaceID = parseSpaceID(current)
            }
            if currentSpaceID == nil {
                currentSpaceID = spaces.first(where: {
                    (($0["Current Space"] as? Int) ?? 0) == 1 || (($0["isCurrent"] as? Bool) ?? false)
                }).flatMap(parseSpaceID)
            }

            guard let currentSpaceID,
                  let currentIndex = orderedSpaceIDs.firstIndex(of: currentSpaceID),
                  let targetIndex = orderedSpaceIDs.firstIndex(of: targetSpaceID) else {
                continue
            }
            if currentIndex == targetIndex { continue }

            let delta = targetIndex - currentIndex
            let steps = min(abs(delta), maxSteps)
            guard steps > 0 else { continue }
            let direction: SpaceStepDirection = delta < 0 ? .right : .left
            return (direction, steps)
        }

        return nil
    }

    private static func parseSpaceID(_ dictionary: [String: Any]) -> UInt64? {
        if let number = dictionary["id64"] as? NSNumber {
            return number.uint64Value
        }
        if let number = dictionary["ManagedSpaceID"] as? NSNumber {
            return number.uint64Value
        }
        if let number = dictionary["id"] as? NSNumber {
            return number.uint64Value
        }
        return nil
    }

    private static func parseWindowIDs(_ dictionary: [String: Any]) -> [CGWindowID] {
        for key in ["Windows", "windows", "WindowIDs", "window-ids"] {
            guard let value = dictionary[key] else { continue }

            if let numbers = value as? [NSNumber] {
                return numbers.map { CGWindowID($0.uint32Value) }
            }

            if let ints = value as? [Int] {
                return ints.map { CGWindowID($0) }
            }

            if let uints = value as? [UInt64] {
                return uints.map { CGWindowID($0) }
            }

             if let dicts = value as? [[String: Any]] {
                let ids = dicts.compactMap { parseWindowID($0) }
                if !ids.isEmpty { return ids }
            }
        }

        // Some SkyLight payloads nest window arrays under layout dictionaries.
        for key in ["TileLayoutManager", "ManagedSpaceProperties", "Layout", "Configuration"] {
            guard let nested = dictionary[key] as? [String: Any] else { continue }
            let nestedIDs = parseWindowIDs(nested)
            if !nestedIDs.isEmpty { return nestedIDs }
        }
        return []
    }

    private static func parseWindowID(_ dictionary: [String: Any]) -> CGWindowID? {
        if let number = dictionary["id64"] as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        if let number = dictionary["id"] as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        if let number = dictionary["WindowID"] as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        if let number = dictionary["windowID"] as? NSNumber {
            return CGWindowID(number.uint32Value)
        }
        return nil
    }
}

enum PrivateFocusController {
    struct LegacyProcessSerialNumber {
        var highLongOfPSN: UInt32
        var lowLongOfPSN: UInt32
    }

    typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutableRawPointer) -> Int32
    typealias SetFrontProcessWithOptionsFn = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32) -> Int32

    private struct API {
        let getProcessForPID: GetProcessForPIDFn
        let setFrontProcessWithOptions: SetFrontProcessWithOptionsFn
    }

    private static let api: API? = {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)!
        var handles: [UnsafeMutableRawPointer] = []
        if let hi = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY) {
            handles.append(hi)
        }
        if let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) {
            handles.append(sky)
        }

        let getPtr = dlsym(defaultHandle, "GetProcessForPID")
            ?? handles.compactMap { dlsym($0, "GetProcessForPID") }.first
        let frontPtr = dlsym(defaultHandle, "SLPSSetFrontProcessWithOptions")
            ?? dlsym(defaultHandle, "SLSSetFrontProcessWithOptions")
            ?? handles.compactMap { dlsym($0, "SLPSSetFrontProcessWithOptions") ?? dlsym($0, "SLSSetFrontProcessWithOptions") }.first

        guard let getPtr, let frontPtr else { return nil }
        return API(
            getProcessForPID: unsafeBitCast(getPtr, to: GetProcessForPIDFn.self),
            setFrontProcessWithOptions: unsafeBitCast(frontPtr, to: SetFrontProcessWithOptionsFn.self)
        )
    }()

    static var isAvailable: Bool { api != nil }

    static func setFrontmost(pid: pid_t, windowID: CGWindowID?) -> Bool {
        guard let api else { return false }
        var psn = LegacyProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 0)
        guard withUnsafeMutablePointer(to: &psn, { ptr in
            api.getProcessForPID(pid, UnsafeMutableRawPointer(ptr))
        }) == 0 else { return false }

        let targetWindowID = UInt32(windowID ?? 0)
        for option in [UInt32(0), UInt32(1), UInt32(3), UInt32(0x10)] {
            let status = withUnsafeMutablePointer(to: &psn, { ptr in
                api.setFrontProcessWithOptions(UnsafeMutableRawPointer(ptr), targetWindowID, option)
            })
            if status == 0 {
                return true
            }
        }
        return false
    }
}

struct ScreenCogService {
    private struct StrictFallbackAttempt {
        let direction: SpaceStepDirection
        let steps: Int
        let tag: String
    }

    private typealias CGWindowListCreateImageFn =
        @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> CGImage?

    private static let cgWindowListCreateImageFn: CGWindowListCreateImageFn? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else {
            return nil
        }
        return unsafeBitCast(symbol, to: CGWindowListCreateImageFn.self)
    }()

    static var isCoreGraphicsFallbackAvailable: Bool {
        cgWindowListCreateImageFn != nil
    }

    func listWindows(json: Bool = false, appFilter: String? = nil, titleFilter: String? = nil) -> String {
        let windows = WindowInventory.allWindows()
            .filter { $0.layer == 0 && !$0.ownerName.isEmpty }
            .filter { window in
                if let appFilter, !appFilter.isEmpty {
                    return window.ownerName.lowercased().contains(appFilter.lowercased())
                }
                return true
            }
            .filter { window in
                if let titleFilter, !titleFilter.isEmpty {
                    return window.windowName.lowercased().contains(titleFilter.lowercased())
                }
                return true
            }
            .sorted {
                if $0.isOnScreen != $1.isOnScreen {
                    return $0.isOnScreen && !$1.isOnScreen
                }
                if $0.ownerName != $1.ownerName {
                    return $0.ownerName < $1.ownerName
                }
                return $0.id < $1.id
            }

        if windows.isEmpty {
            return json ? "[]" : "No windows discovered."
        }

        if json {
            let payload: [[String: Any]] = windows.map { window in
                [
                    "id": window.id,
                    "ownerName": window.ownerName,
                    "windowName": window.windowName,
                    "ownerPID": window.ownerPID,
                    "bundleID": window.bundleID ?? "",
                    "layer": window.layer,
                    "alpha": window.alpha,
                    "isOnScreen": window.isOnScreen,
                    "isLikelyRenderableWithoutActivation": window.isLikelyRenderableWithoutActivation,
                    "bounds": [
                        "x": window.bounds.origin.x,
                        "y": window.bounds.origin.y,
                        "width": window.bounds.size.width,
                        "height": window.bounds.size.height
                    ],
                    "area": window.area
                ]
            }

            guard
                let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
                let text = String(data: data, encoding: .utf8)
            else {
                return "[]"
            }
            return text
        }

        return windows.map { window in
            let namePart = window.windowName.isEmpty ? "(untitled)" : window.windowName
            let bundle = window.bundleID ?? "(unknown)"
            return "\(window.id)\t\(window.ownerName)\t\(namePart)\tvisible=\(window.isOnScreen)\tpid=\(window.ownerPID)\tbundle=\(bundle)"
        }.joined(separator: "\n")
    }

    func capture(options: CLIOptions) async throws -> CaptureOutcome {
        try CapturePermissions.ensureScreenRecordingAccess(prompt: options.promptPermissions && options.promptScreenRecording)
        let chromeTabSession = try ChromeTabController.activateTargetTab(options: options)
        defer {
            if let chromeTabSession {
                ChromeTabController.restoreOriginalTab(chromeTabSession)
            }
        }
        let shouldRestore = options.restoreState
        let focusSnapshot = shouldRestore
            ? await snapshotFocus(
                usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                restoreForceWindowID: options.restoreForceWindowID
            )
            : nil
        let shouldCollectRuntimeSnapshots = options.restoreDebugJSON || (shouldRestore && options.restoreStrict)
        let debugSnapshotToken = shouldCollectRuntimeSnapshots ? UUID().uuidString.lowercased() : ""
        let beforeRuntimeSnapshot = shouldCollectRuntimeSnapshots
            ? await captureRuntimeSnapshot(
                usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                includeDesktopScreenshot: true,
                snapshotTag: "before",
                debugToken: debugSnapshotToken
            )
            : nil
        var interactionSnapshot: TargetInteractionSnapshot?
        var restoreVerified = true

        do {
            let resolvedTarget = try await resolveTargetWithWait(options: options)
            let target = WindowMatcher.resolveActivatedChromeWindow(
                options: options,
                activatedTabTitle: chromeTabSession?.targetTabTitle,
                windows: WindowInventory.allWindows()
            ) ?? resolvedTarget

            if let action = options.inputAction {
                try AccessibilityPermissions.ensureGranted(prompt: options.promptPermissions && options.promptAccessibility)
                interactionSnapshot = try await prepareTargetForInteraction(target)
                try await Task.sleep(nanoseconds: 200_000_000)
                try performInput(action, targetWindow: target)
            }

            let capture = try await captureImageForTarget(target, options: options)
            let finalImage = try applyCropIfNeeded(capture.image, crop: options.crop)
            let data = try ImageEncoder.encode(finalImage, format: options.format, quality: options.quality)

            if shouldRestore {
                if let interactionSnapshot {
                    await restoreTargetInteraction(interactionSnapshot)
                }
                if let focusSnapshot {
                    restoreVerified = await restoreFocus(
                        focusSnapshot,
                        promptAccessibility: options.promptPermissions && options.promptAccessibility,
                        usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                        useHardReattach: options.restoreHardReattach,
                        useSpaceNudge: options.restoreSpaceNudge
                    )
                }
            }

            var strictRecoveryAttempted = false
            var strictRecoverySucceeded = false
            var afterRuntimeSnapshot = shouldCollectRuntimeSnapshots
                ? await captureRuntimeSnapshot(
                    usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                    includeDesktopScreenshot: true,
                    snapshotTag: "after",
                    debugToken: debugSnapshotToken
                )
                : nil
            var parity: RestoreParityReport?
            if shouldRestore, options.restoreStrict,
               let beforeRuntimeSnapshot,
               let snapshotAfter = afterRuntimeSnapshot {
                parity = evaluateRestoreParity(
                    before: beforeRuntimeSnapshot,
                    after: snapshotAfter,
                    diffThreshold: options.restoreDiffThreshold
                )
                if let firstParity = parity,
                   !firstParity.passed,
                   options.restoreStrictSpaceFallback,
                   shouldAttemptStrictSpaceFallback(
                    before: beforeRuntimeSnapshot,
                    after: snapshotAfter,
                    parity: firstParity
                   ) {
                    strictRecoveryAttempted = true
                    let moved = await performStrictParitySpaceFallback(direction: .right, steps: 1)
                    if moved {
                        if shouldCollectRuntimeSnapshots {
                            afterRuntimeSnapshot = await captureRuntimeSnapshot(
                                usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                                includeDesktopScreenshot: true,
                                snapshotTag: "after-recovery-right-1",
                                debugToken: debugSnapshotToken
                            )
                        }
                        if let recoveredAfter = afterRuntimeSnapshot {
                            parity = evaluateRestoreParity(
                                before: beforeRuntimeSnapshot,
                                after: recoveredAfter,
                                diffThreshold: options.restoreDiffThreshold
                            )
                            strictRecoverySucceeded = parity?.passed == true
                        }
                    }
                }
            }
            if let parity {
                restoreVerified = parity.passed
            }
            let diagnostics: RestoreDiagnostics? = {
                guard let beforeRuntimeSnapshot, let afterRuntimeSnapshot else { return nil }
                return RestoreDiagnostics(
                    before: beforeRuntimeSnapshot,
                    after: afterRuntimeSnapshot,
                    parity: parity,
                    strictRecoveryAttempted: strictRecoveryAttempted,
                    strictRecoverySucceeded: strictRecoverySucceeded
                )
            }()

            return CaptureOutcome(
                data: data,
                selectedWindow: target,
                width: finalImage.width,
                height: finalImage.height,
                captureMethod: capture.method,
                restoreVerified: restoreVerified,
                restoreDiagnostics: diagnostics
            )
        } catch {
            if shouldRestore {
                if let interactionSnapshot {
                    await restoreTargetInteraction(interactionSnapshot)
                }
                if let focusSnapshot {
                    _ = await restoreFocus(
                        focusSnapshot,
                        promptAccessibility: options.promptPermissions && options.promptAccessibility,
                        usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                        useHardReattach: options.restoreHardReattach,
                        useSpaceNudge: options.restoreSpaceNudge
                    )
                }
            }
            throw error
        }
    }

    func input(options: CLIOptions) async throws -> InputOutcome {
        try AccessibilityPermissions.ensureGranted(prompt: options.promptPermissions && options.promptAccessibility)
        let target = try await resolveTargetWithWait(options: options)
        guard let action = options.inputAction else {
            throw ScreencogError.usage("Missing input action")
        }
        let focusSnapshot = await snapshotFocus(
            usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
            restoreForceWindowID: options.restoreForceWindowID
        )
        let interactionSnapshot = try await prepareTargetForInteraction(target)
        try await Task.sleep(nanoseconds: 200_000_000)
        try performInput(action, targetWindow: target)

        var restoreVerified = true
        if options.restoreState {
            await restoreTargetInteraction(interactionSnapshot)
            restoreVerified = await restoreFocus(
                focusSnapshot,
                promptAccessibility: options.promptPermissions && options.promptAccessibility,
                usePrivateSpaceRestore: !options.disablePrivateSpaceRestore,
                useHardReattach: options.restoreHardReattach,
                useSpaceNudge: options.restoreSpaceNudge
            )
        }

        return InputOutcome(
            selectedWindow: target,
            action: action,
            restoredState: options.restoreState,
            restoreVerified: restoreVerified
        )
    }

    func checkPermissions(options: CLIOptions) -> PermissionStatus {
        let accessibilityGranted = AccessibilityPermissions.isGranted(prompt: options.promptPermissions && options.promptAccessibility)
        let screenRecordingGranted = CapturePermissions.screenRecordingGranted(prompt: options.promptPermissions && options.promptScreenRecording)
        let automation = AutomationPermissions.checkSystemEventsAccess()
        return PermissionStatus(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted,
            automationSystemEventsGranted: automation.granted,
            automationSystemEventsError: automation.error,
            privateSpaceAPIAvailable: SpaceController.isAvailable
        )
    }

    private func resolveTargetWithWait(options: CLIOptions) async throws -> WindowInfo {
        let started = Date()
        var lastError: Error?

        while true {
            do {
                return try WindowMatcher.resolveTarget(options: options, windows: WindowInventory.allWindows())
            } catch {
                lastError = error
            }

            let elapsed = Date().timeIntervalSince(started)
            if elapsed >= options.waitForWindowSeconds {
                throw lastError ?? ScreencogError.targetNotFound("No matching target window found")
            }

            let sleepNs = options.retryIntervalMS * 1_000_000
            try await Task.sleep(nanoseconds: sleepNs)
        }
    }

    private func snapshotFocus(
        usePrivateSpaceRestore: Bool,
        restoreForceWindowID: CGWindowID?
    ) async -> FocusSnapshot {
        let frontmost = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        let axGranted = AccessibilityPermissions.isGranted(prompt: false)
        let title = axGranted ? AccessibilityWindowController.focusedWindowTitle() : nil
        let spaces = usePrivateSpaceRestore ? SpaceController.captureSnapshot() : nil
        let windows = WindowInventory.allWindows()
        let focusedWindowID = axGranted ? AccessibilityWindowController.focusedWindowID() : nil
        let focusedWindowIDInFrontmostApp: CGWindowID? = {
            guard axGranted, let frontmost else { return nil }
            return AccessibilityWindowController.focusedWindowID(pid: frontmost.processIdentifier)
        }()
        let focusedWindowTitleInFrontmostApp: String? = {
            guard axGranted, let frontmost else { return nil }
            return AccessibilityWindowController.focusedWindowTitle(pid: frontmost.processIdentifier)
        }()
        let forcedWindow = restoreForceWindowID.flatMap { id in windows.first(where: { $0.id == id }) }
        let focusedWindowFromAX = focusedWindowID.flatMap { id in windows.first(where: { $0.id == id }) }
        let focusedWindowFromFrontmostAppAX = focusedWindowIDInFrontmostApp.flatMap { id in windows.first(where: { $0.id == id }) }
        let focusedWindowFromFrontmostAppTitle: WindowInfo? = {
            guard let frontmost,
                  let title = focusedWindowTitleInFrontmostApp?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                return nil
            }
            return windows.first(where: { $0.layer == 0 && $0.ownerPID == frontmost.processIdentifier && $0.windowName == title })
        }()
        let foregroundWindowFromDesktopFrontmost = frontmost.flatMap { app in
            snapshotForegroundWindowOnDesktopForFrontmostApp(pid: app.processIdentifier, windows: windows)
        }
        let foregroundWindowBySpace = snapshotForegroundWindowForActiveSpaces(spaces: spaces)
        let foregroundWindowFromFrontmostApp = frontmost.flatMap { app in
            snapshotForegroundWindowForFrontmostApp(pid: app.processIdentifier, windows: windows)
        }
        let foregroundWindowBefore = forcedWindow
            ?? focusedWindowFromAX
            ?? focusedWindowFromFrontmostAppAX
            ?? focusedWindowFromFrontmostAppTitle
            ?? foregroundWindowBySpace
            ?? foregroundWindowFromFrontmostApp
            ?? foregroundWindowFromDesktopFrontmost
        let foregroundWindowWasFullScreen: Bool? = {
            guard axGranted, let foregroundWindowBefore else { return nil }
            guard let element = AccessibilityWindowController.findWindowElement(
                pid: foregroundWindowBefore.ownerPID,
                preferredWindowID: foregroundWindowBefore.id,
                preferredTitle: foregroundWindowBefore.windowName
            ) else {
                return nil
            }
            return AccessibilityWindowController.isWindowFullScreen(element)
        }()
        let preferAXFullscreenRestore = (foregroundWindowWasFullScreen == true) && focusedWindowID == nil
        let spaceMap = usePrivateSpaceRestore && SpaceController.isAvailable ? SpaceController.windowSpaceMap() : [:]
        let foregroundWindowSpace = foregroundWindowBefore.flatMap { spaceMap[$0.id] }
        return FocusSnapshot(
            appPID: frontmost?.processIdentifier,
            appBundleID: frontmost?.bundleIdentifier,
            windowTitle: title ?? focusedWindowTitleInFrontmostApp ?? foregroundWindowBefore?.windowName,
            foregroundWindowBefore: foregroundWindowBefore,
            foregroundWindowWasFullScreen: foregroundWindowWasFullScreen,
            preferAXFullscreenRestore: preferAXFullscreenRestore,
            foregroundWindowSpace: foregroundWindowSpace,
            spaces: spaces
        )
    }

    private func captureRuntimeSnapshot(
        usePrivateSpaceRestore: Bool,
        includeDesktopScreenshot: Bool = false,
        snapshotTag: String = "snapshot",
        debugToken: String = ""
    ) async -> RuntimeSnapshot {
        let frontmost = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        let axGranted = AccessibilityPermissions.isGranted(prompt: false)
        let focusedWindowID = axGranted ? AccessibilityWindowController.focusedWindowID() : nil
        let focusedWindowTitle = axGranted ? AccessibilityWindowController.focusedWindowTitle() : nil
        let focusedWindowIsFullScreen: Bool? = {
            guard axGranted,
                  let frontmostPID = frontmost?.processIdentifier else { return nil }
            guard let element = AccessibilityWindowController.findWindowElement(
                pid: frontmostPID,
                preferredWindowID: focusedWindowID,
                preferredTitle: focusedWindowTitle
            ) else { return nil }
            return AccessibilityWindowController.isWindowFullScreen(element)
        }()
        let spaces = usePrivateSpaceRestore ? SpaceController.captureSnapshot() : nil
        let activeSpaceWindowStacks = usePrivateSpaceRestore ? SpaceController.activeSpaceWindowStacksRaw() : [:]
        let topWindow = snapshotForegroundWindowForActiveSpaces(spaces: spaces)
        let menuBarOwnerPID = detectMenuBarOwnerPID()
        let desktopScreenshotPath = includeDesktopScreenshot
            ? captureDesktopScreenshotPath(snapshotTag: snapshotTag, debugToken: debugToken)
            : nil

        return RuntimeSnapshot(
            frontmostAppPID: frontmost?.processIdentifier,
            frontmostAppBundleID: frontmost?.bundleIdentifier,
            menuBarOwnerPID: menuBarOwnerPID,
            focusedWindowID: focusedWindowID,
            focusedWindowTitle: focusedWindowTitle,
            focusedWindowIsFullScreen: focusedWindowIsFullScreen,
            activeSpaces: spaces?.displayToSpace ?? [:],
            activeSpaceWindowStacks: activeSpaceWindowStacks,
            activeSpaceTopWindow: topWindow,
            desktopScreenshotPath: desktopScreenshotPath
        )
    }

    private func restoreFocus(
        _ snapshot: FocusSnapshot,
        promptAccessibility: Bool,
        usePrivateSpaceRestore: Bool,
        useHardReattach: Bool,
        useSpaceNudge: Bool
    ) async -> Bool {
        var spaceRestored = true
        if usePrivateSpaceRestore, let spaces = snapshot.spaces, SpaceController.isAvailable {
            spaceRestored = SpaceController.restoreSnapshot(spaces)
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if usePrivateSpaceRestore,
           let windowSpace = snapshot.foregroundWindowSpace,
           SpaceController.isAvailable {
            _ = SpaceController.restoreLocation(windowSpace)
            try? await Task.sleep(nanoseconds: 35_000_000)
        }

        guard let pid = snapshot.appPID else {
            if usePrivateSpaceRestore, let spaces = snapshot.spaces, SpaceController.isAvailable {
                return spaceRestored && SpaceController.matchesSnapshot(spaces)
            }
            return false
        }

        let app = NSRunningApplication(processIdentifier: pid)
            ?? NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == snapshot.appBundleID })

        guard let app else {
            if usePrivateSpaceRestore, let spaces = snapshot.spaces, SpaceController.isAvailable {
                return spaceRestored && SpaceController.matchesSnapshot(spaces)
            }
            return false
        }

        await MainActor.run {
            _ = app.activate(options: [])
        }

        let canUseAX = AccessibilityPermissions.isGranted(prompt: promptAccessibility)
        promoteWindowToFront(
            appPID: app.processIdentifier,
            expectedWindow: snapshot.foregroundWindowBefore,
            fallbackTitle: snapshot.windowTitle,
            preserveFullScreen: snapshot.foregroundWindowWasFullScreen == true,
            preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore,
            allowAX: canUseAX
        )

        var appRestored = false
        var windowRestored = snapshot.foregroundWindowBefore == nil || !canUseAX
        for _ in 0..<5 {
            let currentPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
            if currentPID == app.processIdentifier {
                appRestored = true
                if canUseAX, let expectedWindowID = snapshot.foregroundWindowBefore?.id {
                    let currentWindowID = AccessibilityWindowController.focusedWindowID()
                    if currentWindowID == expectedWindowID {
                        windowRestored = true
                        break
                    }
                } else {
                    break
                }
            }
            await MainActor.run {
                _ = app.activate(options: [])
            }
            promoteWindowToFront(
                appPID: app.processIdentifier,
                expectedWindow: snapshot.foregroundWindowBefore,
                fallbackTitle: snapshot.windowTitle,
                preserveFullScreen: snapshot.foregroundWindowWasFullScreen == true,
                preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore,
                allowAX: canUseAX
            )
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        if usePrivateSpaceRestore, let spaces = snapshot.spaces, SpaceController.isAvailable {
            let secondPass = SpaceController.restoreSnapshot(spaces)
            try? await Task.sleep(nanoseconds: 40_000_000)
            let baseline = appRestored && windowRestored && spaceRestored && secondPass && SpaceController.matchesSnapshot(spaces)
            if baseline { return true }
            if useHardReattach {
                let fallback = await hardReattachRestore(
                    snapshot: snapshot,
                    useSpaceNudge: useSpaceNudge && shouldAttemptSpaceNudge(snapshot: snapshot)
                )
                if fallback { return true }
            }
            return false
        }

        let baseline = appRestored && windowRestored
        if baseline { return true }
        if useHardReattach {
            return await hardReattachRestore(
                snapshot: snapshot,
                useSpaceNudge: useSpaceNudge && shouldAttemptSpaceNudge(snapshot: snapshot)
            )
        }
        return false
    }

    private func hardReattachRestore(snapshot: FocusSnapshot, useSpaceNudge: Bool) async -> Bool {
        guard let targetWindow = snapshot.foregroundWindowBefore else {
            return false
        }
        guard let app = NSRunningApplication(processIdentifier: targetWindow.ownerPID) else {
            return false
        }

        if let location = snapshot.foregroundWindowSpace, SpaceController.isAvailable {
            _ = SpaceController.restoreLocation(location)
            try? await Task.sleep(nanoseconds: 40_000_000)
        }

        await MainActor.run {
            _ = app.activate(options: [])
        }

        let canUseAX = AccessibilityPermissions.isGranted(prompt: false)
        promoteWindowToFront(
            appPID: targetWindow.ownerPID,
            expectedWindow: targetWindow,
            fallbackTitle: targetWindow.windowName,
            preserveFullScreen: snapshot.foregroundWindowWasFullScreen == true,
            preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore,
            allowAX: canUseAX
        )

        if await verifyFrontmostWindow(targetWindow, preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore) {
            return true
        }

        if useSpaceNudge {
            postMissionControlSpaceNudge()
            try? await Task.sleep(nanoseconds: 130_000_000)
            if let location = snapshot.foregroundWindowSpace, SpaceController.isAvailable {
                _ = SpaceController.restoreLocation(location)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            await MainActor.run {
                _ = app.activate(options: [])
            }
            promoteWindowToFront(
                appPID: targetWindow.ownerPID,
                expectedWindow: targetWindow,
                fallbackTitle: targetWindow.windowName,
                preserveFullScreen: snapshot.foregroundWindowWasFullScreen == true,
                preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore,
                allowAX: canUseAX
            )
        }

        return await verifyFrontmostWindow(targetWindow, preferAXFullscreenRestore: snapshot.preferAXFullscreenRestore)
    }

    private func promoteWindowToFront(
        appPID: pid_t,
        expectedWindow: WindowInfo?,
        fallbackTitle: String?,
        preserveFullScreen: Bool,
        preferAXFullscreenRestore: Bool,
        allowAX: Bool
    ) {
        let privateWindowID: CGWindowID? = preferAXFullscreenRestore ? nil : expectedWindow?.id
        _ = PrivateFocusController.setFrontmost(pid: appPID, windowID: privateWindowID)
        if !preferAXFullscreenRestore,
           let windowID = expectedWindow?.id,
           SpaceController.isAvailable {
            _ = SpaceController.orderWindowToFront(windowID)
        }

        guard allowAX else { return }
        if preferAXFullscreenRestore,
           let fullScreenWindow = AccessibilityWindowController.findFullScreenWindowElement(
               pid: appPID,
               preferredTitle: expectedWindow?.windowName ?? fallbackTitle
           ) {
            AccessibilityWindowController.setWindowFullScreen(fullScreenWindow, fullScreen: true)
            AccessibilityWindowController.raiseWindow(fullScreenWindow)
            return
        }
        guard let window = AccessibilityWindowController.findWindowElement(
            pid: appPID,
            preferredWindowID: expectedWindow?.id,
            preferredTitle: expectedWindow?.windowName ?? fallbackTitle
        ) else {
            return
        }

        if preserveFullScreen {
            AccessibilityWindowController.setWindowFullScreen(window, fullScreen: true)
        }
        AccessibilityWindowController.raiseWindow(window)
    }

    private func verifyFrontmostWindow(_ expected: WindowInfo, preferAXFullscreenRestore: Bool) async -> Bool {
        for _ in 0..<5 {
            let frontPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
            if frontPID == expected.ownerPID {
                if preferAXFullscreenRestore {
                    if AccessibilityPermissions.isGranted(prompt: false),
                       AccessibilityWindowController.hasFullScreenWindow(pid: expected.ownerPID) {
                        return true
                    }
                } else {
                    let focusedWindowID = AccessibilityPermissions.isGranted(prompt: false)
                        ? AccessibilityWindowController.focusedWindowID()
                        : nil
                    if focusedWindowID == expected.id {
                        return true
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    private func postMissionControlSpaceNudge() {
        postKey(vkey: 124, flags: .maskControl) // Right Arrow
        usleep(70_000)
        postKey(vkey: 123, flags: .maskControl) // Left Arrow
    }

    private func strictFallbackAttempts(focusSnapshot: FocusSnapshot) -> [StrictFallbackAttempt] {
        var attempts: [StrictFallbackAttempt] = []
        if let spaces = focusSnapshot.spaces,
           let plan = SpaceController.transitionPlanToSnapshot(spaces) {
            let dir = plan.direction == .right ? "right" : "left"
            attempts.append(StrictFallbackAttempt(direction: plan.direction, steps: plan.steps, tag: "planned-\(dir)-\(plan.steps)"))
        }
        attempts.append(StrictFallbackAttempt(direction: .right, steps: 1, tag: "right-1"))
        attempts.append(StrictFallbackAttempt(direction: .left, steps: 1, tag: "left-1"))

        var deduped: [StrictFallbackAttempt] = []
        var seen = Set<String>()
        for attempt in attempts {
            let directionToken = attempt.direction == .right ? "r" : "l"
            let key = "\(directionToken)-\(attempt.steps)"
            if seen.insert(key).inserted {
                deduped.append(attempt)
            }
        }
        return deduped
    }

    private func shouldAttemptStrictSpaceFallback(
        before: RuntimeSnapshot,
        after: RuntimeSnapshot,
        parity: RestoreParityReport
    ) -> Bool {
        _ = parity
        return before.activeSpaces != after.activeSpaces
    }

    private func shouldAttemptSpaceNudge(snapshot: FocusSnapshot) -> Bool {
        guard let spaces = snapshot.spaces, SpaceController.isAvailable else {
            return false
        }
        return !SpaceController.matchesSnapshot(spaces)
    }

    private func performStrictParitySpaceFallback(direction: SpaceStepDirection, steps: Int) async -> Bool {
        guard steps > 0 else { return false }
        let moved = sendControlSpaceToSystemEvents(direction: direction, steps: steps)
        try? await Task.sleep(nanoseconds: 180_000_000)
        return moved
    }

    private func sendControlSpaceToSystemEvents(direction: SpaceStepDirection, steps: Int) -> Bool {
        let keyCode = direction == .right ? 124 : 123
        let script = """
        tell application "System Events"
          repeat \(steps) times
            key code \(keyCode) using control down
            delay 0.12
          end repeat
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return false
        }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        return error == nil
    }

    private func postKey(vkey: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: vkey, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: vkey, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func prepareTargetForInteraction(_ target: WindowInfo) async throws -> TargetInteractionSnapshot {
        guard let targetApp = NSRunningApplication(processIdentifier: target.ownerPID) else {
            throw ScreencogError.targetNotFound("Target app process no longer available")
        }

        let (targetSpaceLocation, topWindowBeforeInteraction) = snapshotTopWindowInTargetSpace(targetWindowID: target.id)
        let appWasHidden = await MainActor.run { targetApp.isHidden }
        let focusedWindowIDBefore = AccessibilityPermissions.isGranted(prompt: false)
            ? AccessibilityWindowController.focusedWindowID(pid: target.ownerPID)
            : nil
        let focusedWindowTitleBefore = AccessibilityPermissions.isGranted(prompt: false)
            ? AccessibilityWindowController.focusedWindowTitle(pid: target.ownerPID)
            : nil
        let windowElement = AccessibilityWindowController.findWindowElement(
            pid: target.ownerPID,
            preferredWindowID: target.id,
            preferredTitle: target.windowName
        )
        let windowWasMinimized = windowElement.map { AccessibilityWindowController.isWindowMinimized($0) } ?? false

        await MainActor.run {
            if targetApp.isHidden {
                targetApp.unhide()
            }
            _ = targetApp.activate(options: [.activateAllWindows])
        }

        if let windowElement {
            if windowWasMinimized {
                AccessibilityWindowController.setWindowMinimized(windowElement, minimized: false)
            }
            AccessibilityWindowController.raiseWindow(windowElement)
        }

        return TargetInteractionSnapshot(
            app: targetApp,
            targetWindowID: target.id,
            appWasHidden: appWasHidden,
            windowElement: windowElement,
            windowWasMinimized: windowWasMinimized,
            focusedWindowIDBefore: focusedWindowIDBefore,
            focusedWindowTitleBefore: focusedWindowTitleBefore,
            targetSpaceLocation: targetSpaceLocation,
            topWindowBeforeInteraction: topWindowBeforeInteraction
        )
    }

    private func restoreTargetInteraction(_ snapshot: TargetInteractionSnapshot) async {
        if let location = snapshot.targetSpaceLocation,
           let topWindow = snapshot.topWindowBeforeInteraction,
           topWindow.id != snapshot.targetWindowID {
            await restoreTopWindowInTargetSpace(location: location, window: topWindow)
        }

        if let windowElement = snapshot.windowElement, snapshot.windowWasMinimized {
            AccessibilityWindowController.setWindowMinimized(windowElement, minimized: true)
        }
        if !snapshot.appWasHidden,
           let previousWindow = AccessibilityWindowController.findWindowElement(
               pid: snapshot.app.processIdentifier,
               preferredWindowID: snapshot.focusedWindowIDBefore,
               preferredTitle: snapshot.focusedWindowTitleBefore
           ) {
            AccessibilityWindowController.raiseWindow(previousWindow)
        }
        if snapshot.appWasHidden {
            await MainActor.run { _ = snapshot.app.hide() }
        }
    }

    private func snapshotTopWindowInTargetSpace(targetWindowID: CGWindowID) -> (SpaceLocation?, WindowInfo?) {
        guard SpaceController.isAvailable else {
            return (nil, nil)
        }

        let map = SpaceController.windowSpaceMap()
        guard let location = map[targetWindowID] else {
            return (nil, nil)
        }

        let orderedWindows = WindowInventory.allWindows()
        let topWindow = orderedWindows.first { window in
            guard window.layer == 0 else { return false }
            guard let candidateLocation = map[window.id] else { return false }
            return candidateLocation == location
        }

        return (location, topWindow)
    }

    private func restoreTopWindowInTargetSpace(location: SpaceLocation, window: WindowInfo) async {
        guard SpaceController.isAvailable else { return }

        _ = SpaceController.restoreLocation(location)
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = PrivateFocusController.setFrontmost(pid: window.ownerPID, windowID: window.id)

        if SpaceController.orderWindowToFront(window.id) {
            return
        }

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }
        await MainActor.run {
            if app.isHidden { app.unhide() }
            _ = app.activate(options: [])
        }
        if AccessibilityPermissions.isGranted(prompt: false),
           let element = AccessibilityWindowController.findWindowElement(
               pid: window.ownerPID,
               preferredWindowID: window.id,
               preferredTitle: window.windowName
           ) {
            AccessibilityWindowController.raiseWindow(element)
        }
    }

    private func snapshotForegroundWindowForActiveSpaces(spaces: SpaceSnapshot?) -> WindowInfo? {
        guard let spaces, SpaceController.isAvailable else { return nil }
        let activeSpaceByDisplay = spaces.displayToSpace
        if activeSpaceByDisplay.isEmpty { return nil }

        let map = SpaceController.windowSpaceMap()
        return WindowInventory.allWindows().first { window in
            guard window.layer == 0 else { return false }
            guard let location = map[window.id] else { return false }
            return activeSpaceByDisplay[location.displayID] == location.spaceID
        }
    }

    private func snapshotForegroundWindowOnDesktopForFrontmostApp(pid: pid_t, windows: [WindowInfo]) -> WindowInfo? {
        windows.first { window in
            window.layer == 0 &&
            window.isOnScreen &&
            window.alpha > 0 &&
            window.ownerPID == pid
        }
    }

    private func snapshotForegroundWindowForFrontmostApp(pid: pid_t, windows: [WindowInfo]) -> WindowInfo? {
        let candidates = windows.filter { $0.layer == 0 && $0.ownerPID == pid }
        guard !candidates.isEmpty else { return nil }

        return candidates.max { lhs, rhs in
            let lhsScore = foregroundWindowScore(lhs)
            let rhsScore = foregroundWindowScore(rhs)
            if lhsScore == rhsScore {
                return lhs.area < rhs.area
            }
            return lhsScore < rhsScore
        }
    }

    private func foregroundWindowScore(_ window: WindowInfo) -> Int {
        var score = 0
        if window.isOnScreen { score += 100 }
        if window.alpha > 0.0 { score += 40 }
        if !window.windowName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 20 }
        if window.bounds.width >= 300, window.bounds.height >= 220 { score += 10 }
        return score
    }

    private func detectMenuBarOwnerPID() -> pid_t? {
        guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for row in rows {
            let layer = row[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 24 || layer == 25 else { continue }
            guard let boundsDict = row[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }
            let isMenuBarSized = bounds.origin.y <= 1.0 && bounds.height <= 40.0 && bounds.width >= 400.0
            guard isMenuBarSized else { continue }
            if let pid = row[kCGWindowOwnerPID as String] as? pid_t {
                return pid
            }
        }

        return nil
    }

    private func captureDesktopScreenshotPath(snapshotTag: String, debugToken: String) -> String? {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }
        guard let data = try? ImageEncoder.encode(image, format: .png, quality: 100) else {
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = debugToken.isEmpty ? "" : "-\(debugToken)"
        let name = "screencog-restore-\(snapshotTag)\(suffix)-\(timestamp).png"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    private func evaluateRestoreParity(
        before: RuntimeSnapshot,
        after: RuntimeSnapshot,
        diffThreshold: Double
    ) -> RestoreParityReport {
        let menuBarCompared = before.menuBarOwnerPID != nil
        let menuBarMatches = before.menuBarOwnerPID.map { $0 == after.menuBarOwnerPID } ?? true
        let screenshotDiffScore = screenshotDiffRatio(
            beforePath: before.desktopScreenshotPath,
            afterPath: after.desktopScreenshotPath
        )
        let screenshotCompared = screenshotDiffScore != nil
        let screenshotMatches = screenshotDiffScore.map { $0 <= diffThreshold } ?? false
        let passed = menuBarMatches && screenshotMatches

        return RestoreParityReport(
            passed: passed,
            menuBarCompared: menuBarCompared,
            menuBarMatches: menuBarMatches,
            menuBarBeforePID: before.menuBarOwnerPID,
            menuBarAfterPID: after.menuBarOwnerPID,
            screenshotCompared: screenshotCompared,
            screenshotDiffScore: screenshotDiffScore,
            screenshotDiffThreshold: diffThreshold
        )
    }

    private func screenshotDiffRatio(beforePath: String?, afterPath: String?) -> Double? {
        guard let beforePath, let afterPath else { return nil }
        guard let beforeImage = loadImage(atPath: beforePath), let afterImage = loadImage(atPath: afterPath) else {
            return nil
        }
        guard let beforeSample = sampleForDiff(beforeImage), let afterSample = sampleForDiff(afterImage) else {
            return nil
        }

        let width = min(beforeSample.width, afterSample.width)
        let height = min(beforeSample.height, afterSample.height)
        guard width > 0, height > 0 else { return nil }

        let beforeStride = beforeSample.bytesPerRow
        let afterStride = afterSample.bytesPerRow
        var diffTotal: Double = 0
        var count = 0
        for y in 0..<height {
            let beforeRowBase = y * beforeStride
            let afterRowBase = y * afterStride
            for x in 0..<width {
                let beforeOffset = beforeRowBase + (x * 4)
                let afterOffset = afterRowBase + (x * 4)
                diffTotal += abs(Double(beforeSample.data[beforeOffset + 0]) - Double(afterSample.data[afterOffset + 0]))
                diffTotal += abs(Double(beforeSample.data[beforeOffset + 1]) - Double(afterSample.data[afterOffset + 1]))
                diffTotal += abs(Double(beforeSample.data[beforeOffset + 2]) - Double(afterSample.data[afterOffset + 2]))
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return diffTotal / (Double(count) * 3.0 * 255.0)
    }

    private func loadImage(atPath path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func sampleForDiff(_ image: CGImage, maxDimension: Int = 320) -> (data: [UInt8], width: Int, height: Int, bytesPerRow: Int)? {
        let srcWidth = image.width
        let srcHeight = image.height
        guard srcWidth > 0, srcHeight > 0 else { return nil }

        let scale = min(1.0, Double(maxDimension) / Double(max(srcWidth, srcHeight)))
        let width = max(1, Int((Double(srcWidth) * scale).rounded()))
        let height = max(1, Int((Double(srcHeight) * scale).rounded()))
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (data, width, height, bytesPerRow)
    }

    private func applyCropIfNeeded(_ image: CGImage, crop: CropRegion?) throws -> CGImage {
        guard let crop else { return image }

        let maxWidth = image.width
        let maxHeight = image.height
        let clampedX = max(0, min(crop.x, maxWidth - 1))
        let clampedY = max(0, min(crop.y, maxHeight - 1))
        let clampedWidth = max(1, min(crop.width, maxWidth - clampedX))
        let clampedHeight = max(1, min(crop.height, maxHeight - clampedY))
        let rect = CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)

        guard let cropped = image.cropping(to: rect) else {
            throw ScreencogError.captureFailed("Failed to crop image with rect \(rect)")
        }
        return cropped
    }

    private func captureImageForTarget(_ target: WindowInfo, options: CLIOptions) async throws -> (image: CGImage, method: String) {
        // Temporary stability mode: CoreGraphics-first for all apps.
        // ScreenCaptureKit can trigger ReplayKit hangs in this environment.
        if let image = await captureWithCoreGraphicsTimed(windowID: target.id) {
            return (image, "coregraphics")
        }

        if !target.isLikelyRenderableWithoutActivation {
            let image = try await WindowRenderRecovery.withTemporaryActivation(
                targetWindow: target,
                promptPermissions: options.promptPermissions
            ) {
                if let image = await captureWithCoreGraphicsTimed(windowID: target.id) {
                    return image
                }
                throw ScreencogError.captureFailed("Window became available but CoreGraphics capture still failed")
            }
            return (image, "recovery")
        }

        throw ScreencogError.captureFailed(
            "Failed to capture window \(target.id). The window may be protected, minimized, or unavailable."
        )
    }

    private func performInput(_ action: InputAction, targetWindow: WindowInfo) throws {
        switch action {
        case .click(let x, let y, let button, let count):
            let globalPoint = CGPoint(x: targetWindow.bounds.origin.x + x, y: targetWindow.bounds.origin.y + y)
            try postClick(at: globalPoint, button: button, count: count)
        case .type(let text):
            try postText(text)
        case .scroll(let dx, let dy):
            try postScroll(dx: dx, dy: dy)
        }
    }

    private func postClick(at point: CGPoint, button: MouseButtonKind, count: Int) throws {
        guard count > 0 else { return }
        for _ in 0..<count {
            guard let down = CGEvent(mouseEventSource: nil, mouseType: button.downEvent, mouseCursorPosition: point, mouseButton: button.cgButton),
                  let up = CGEvent(mouseEventSource: nil, mouseType: button.upEvent, mouseCursorPosition: point, mouseButton: button.cgButton) else {
                throw ScreencogError.captureFailed("Failed to create mouse events")
            }
            let clickState = Int64(max(1, count))
            down.setIntegerValueField(.mouseEventClickState, value: clickState)
            up.setIntegerValueField(.mouseEventClickState, value: clickState)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func postText(_ text: String) throws {
        for scalar in text.unicodeScalars {
            var utf16 = [UniChar(scalar.value)]
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                throw ScreencogError.captureFailed("Failed to create keyboard events")
            }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func postScroll(dx: Int32, dy: Int32) throws {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else {
            throw ScreencogError.captureFailed("Failed to create scroll event")
        }
        event.post(tap: .cghidEventTap)
    }

    private func captureWithScreenCaptureKit(
        windowID: CGWindowID,
        targetBounds: CGRect
    ) async throws -> CGImage {
        let shareable = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let scWindow = shareable.windows.first(where: { $0.windowID == windowID }) else {
            throw ScreencogError.targetNotFound("ScreenCaptureKit did not expose window id \(windowID)")
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.width = max(Int(targetBounds.width), 2)
        configuration.height = max(Int(targetBounds.height), 2)

        return try await withCheckedThrowingContinuation { continuation in
            let gate = OneShotContinuation<CGImage>()
            let captureTask = Task {
                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: configuration
                    )
                    await gate.resume(continuation, with: .success(image))
                } catch {
                    await gate.resume(continuation, with: .failure(error))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                captureTask.cancel()
                await gate.resume(
                    continuation,
                    with: .failure(ScreencogError.captureFailed("ScreenCaptureKit timed out for window \(windowID)"))
                )
            }
        }
    }

    private func captureWithCoreGraphics(windowID: CGWindowID) -> CGImage? {
        guard let cgWindowListCreateImageFn = Self.cgWindowListCreateImageFn else {
            return nil
        }

        return cgWindowListCreateImageFn(
            .null,
            [.optionIncludingWindow],
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    private func captureWithCoreGraphicsTimed(windowID: CGWindowID, timeoutNs: UInt64 = 800_000_000) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let gate = OneShotValueContinuation<CGImage?>()

            Task {
                let image = captureWithCoreGraphics(windowID: windowID)
                await gate.resume(continuation, value: image)
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNs)
                await gate.resume(continuation, value: nil)
            }
        }
    }
}
