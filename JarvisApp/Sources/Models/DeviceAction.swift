import Foundation
import CoreGraphics

// Every action Jarvis can perform on the device
struct DeviceAction: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ActionType
    let params: [String: ParamValue]
    var status: Status

    enum Status: String, Codable { case pending, running, done, failed, skipped }

    enum ActionType: String, Codable, CaseIterable {
        // Touch & gesture
        case tap, doubleTap, longPress, swipe, pinch, scroll, dragDrop
        // Navigation
        case goHome, goBack, openAppSwitcher, openNotificationCenter, openControlCenter
        // Apps
        case openApp, closeApp, forceQuitApp
        // Text
        case typeText, clearField, selectAll, copy, paste, dictate
        // Search
        case spotlight, webSearch, appStoreSearch, mapSearch, youtubeSearch
        // Communication
        case sendIMessage, sendWhatsApp, sendEmail, makeCall, facetime
        // Media
        case playMusic, pauseMusic, nextTrack, prevTrack, setVolume, takePhoto, recordVideo, recordScreen
        // Settings
        case setBrightness, toggleWifi, toggleBluetooth, toggleAirplane, toggleDarkMode
        case toggleLowPower, toggleAutoLock, toggleDoNotDisturb, setWallpaper
        // Productivity
        case createNote, createReminder, createCalendarEvent, setAlarm, setTimer, startStopwatch
        // Files
        case openFile, downloadFile, shareFile, airdrop
        // System
        case lockScreen, screenshot, restartSpringboard, openURL, launchSiri
        // Shortcuts
        case runShortcut
        // Agent
        case wait, think, speak, verify, askUser, loop, abort
        // Keyboard extension
        case injectKeystrokes, submitForm
        // Browser automation
        case browseURL, browserTap, browserFill, browserScroll, browserExtract, browserSubmit, browserBack
        // Document generation
        case createPresentation, createDocument, createSpreadsheet, openGeneratedFile
    }

    init(type: ActionType, params: [String: ParamValue] = [:]) {
        self.id = UUID()
        self.type = type
        self.params = params
        self.status = .pending
    }
}

enum ParamValue: Codable, Equatable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case point(x: Double, y: Double)

    var s: String? { if case .string(let v) = self { return v }; return nil }
    var n: Double? { if case .number(let v) = self { return v }; return nil }
    var b: Bool? { if case .bool(let v) = self { return v }; return nil }
    var pt: CGPoint? { if case .point(let x, let y) = self { return CGPoint(x: x, y: y) }; return nil }

    var description: String {
        switch self {
        case .string(let v): return v
        case .number(let v): return String(format: "%.1f", v)
        case .bool(let v): return v ? "true" : "false"
        case .point(let x, let y): return "(\(Int(x)),\(Int(y)))"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugMessage: "Bad param") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .point(let x, let y): try c.encode("\(x),\(y)")
        }
    }
}
