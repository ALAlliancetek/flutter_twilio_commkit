import Foundation
import os.log

/// Internal logger for the iOS plugin.
final class TwilioLogger {

    enum Level: Int, Comparable {
        case debug = 0, warning, error, none

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private static var currentLevel: Level = .none
    private static let log = OSLog(subsystem: "com.twiliocommkit", category: "SDK")

    static func configure(level: String) {
        switch level.lowercased() {
        case "debug":   currentLevel = .debug
        case "warning": currentLevel = .warning
        case "error":   currentLevel = .error
        default:        currentLevel = .none
        }
    }

    static func debug(_ message: String) {
        guard currentLevel <= .debug else { return }
        os_log(.debug, log: log, "%{public}@", message)
    }

    static func warning(_ message: String) {
        guard currentLevel <= .warning else { return }
        os_log(.default, log: log, "%{public}@", message)
    }

    static func error(_ message: String) {
        guard currentLevel <= .error else { return }
        os_log(.error, log: log, "%{public}@", message)
    }
}

