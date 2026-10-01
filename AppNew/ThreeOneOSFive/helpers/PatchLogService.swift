import Foundation
import SwiftUI

@MainActor
final class PatchLogService: ObservableObject {
    static let shared = PatchLogService()

    @Published var logs: [PatchLogEntry] = []
    @Published var isVisible = false

    private init() {}

    func clear() {
        logs.removeAll()
    }

    func debug(_ message: String) {
        append(level: .debug, message: message)
    }

    func info(_ message: String) {
        append(level: .info, message: message)
    }

    func warning(_ message: String) {
        append(level: .warning, message: message)
    }

    func error(_ message: String) {
        append(level: .error, message: message)
    }

    func success(_ message: String) {
        append(level: .success, message: message)
    }

    private func append(level: LogLevel, message: String) {
        let entry = PatchLogEntry(
            timestamp: Date(),
            level: level,
            message: message
        )
        logs.append(entry)

        // Keep last 100 entries
        if logs.count > 100 {
            logs.removeFirst(logs.count - 100)
        }

        // Auto-show on error
        if level == .error {
            isVisible = true
        }

        // Print to console
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .warning: prefix = "[WARN]"
        case .error: prefix = "[ERROR]"
        case .success: prefix = "[OK]"
        }
        print("\(prefix) \(message)")
    }

    enum LogLevel {
        case debug, info, warning, error, success

        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }

        var icon: String {
            switch self {
            case .debug: return "ladybug"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .success: return "checkmark.circle"
            }
        }
    }
}

struct PatchLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: PatchLogService.LogLevel
    let message: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
