import Foundation
import UIKit
import Darwin
import Combine

// MARK: - Logging Configuration
// ═══════════════════════════════════════════════════════
// CHỈ CẦN ĐỔI DÒNG NÀY:
//   false = LOGGING BẬT (debug/development)
//   true  = LOGGING TẮT (release/production)
// ═══════════════════════════════════════════════════════
private let IS_LOGGING_DISABLED: Bool = false

// MARK: - Global logger (High-performance, throttled, deduplicated, capped to 150 items)
class AppLog: ObservableObject {
    static let shared = AppLog()
    static let maxCapacity: Int = 150

    @Published var entries: [String] = []

    private let lock = NSLock()
    private var pendingEntries: [String] = []
    private var isFlushScheduled: Bool = false
    private var lastMessage: String = ""
    private var repeatCount: Int = 1

    func append(_ msg: String) {
        if IS_LOGGING_DISABLED { return }

        let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        // Deduplicate consecutive identical messages to prevent flood
        if trimmed == lastMessage {
            repeatCount += 1
            let repeatedText = "\(trimmed) (x\(repeatCount))"
            if !pendingEntries.isEmpty {
                pendingEntries[pendingEntries.count - 1] = repeatedText
            } else {
                pendingEntries.append(repeatedText)
            }
            lock.unlock()
            scheduleFlush()
            return
        }

        lastMessage = trimmed
        repeatCount = 1
        pendingEntries.append(trimmed)

        if pendingEntries.count > Self.maxCapacity {
            pendingEntries.removeFirst(pendingEntries.count - Self.maxCapacity)
        }
        lock.unlock()

        scheduleFlush()
    }

    private func scheduleFlush() {
        lock.lock()
        guard !isFlushScheduled else {
            lock.unlock()
            return
        }
        isFlushScheduled = true
        lock.unlock()

        // Batch flush every 250ms to completely prevent SwiftUI UI thread lockup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let batch = self.pendingEntries
            self.pendingEntries.removeAll()
            self.isFlushScheduled = false
            let lastMsg = self.lastMessage
            self.lock.unlock()

            guard !batch.isEmpty else { return }

            var current = self.entries
            if let firstBatch = batch.first, !lastMsg.isEmpty, firstBatch.hasPrefix(lastMsg), !current.isEmpty {
                current[current.count - 1] = firstBatch
                current.append(contentsOf: batch.dropFirst())
            } else {
                current.append(contentsOf: batch)
            }

            if current.count > Self.maxCapacity {
                current.removeFirst(current.count - Self.maxCapacity)
            }
            self.entries = current
        }
    }

    func clear() {
        lock.lock()
        pendingEntries.removeAll()
        lastMessage = ""
        repeatCount = 1
        lock.unlock()
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}

func log(_ msg: String) {
    if !IS_LOGGING_DISABLED {
        AppLog.shared.append("[3105] \(msg)")
    }
}

// Retain the pipe for the app's lifetime so stdout stays redirected.
private var logCapturePipe: Pipe?

// Redirect stdout (C printf) into in-app log view with strict intelligent filtering.
// NOTE: We intentionally do NOT redirect STDERR to avoid capturing noisy iOS framework warnings.
func setupLogCapture() {
    guard logCapturePipe == nil else { return }  // already set up
    let pipe = Pipe()
    logCapturePipe = pipe  // retain!

    setvbuf(stdout, nil, _IONBF, 0)
    let writeFd = pipe.fileHandleForWriting.fileDescriptor
    if dup2(writeFd, STDOUT_FILENO) < 0 {
        log("setupLogCapture: dup2 failed, log capture disabled")
        logCapturePipe = nil
        return
    }

    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // Filter out system daemon spam (Metal, WebKit, CoreGraphics, UIKit warnings)
            let isRelevant = line.hasPrefix("[+]") || line.hasPrefix("[-]") || line.hasPrefix("[*]") ||
                             line.hasPrefix("[!]") || line.hasPrefix("[3105]") || line.hasPrefix("[CHEAT]") ||
                             line.hasPrefix("[CONFIG]") || line.hasPrefix("[INJECT]") || line.hasPrefix("[UNINJECT]") ||
                             line.hasPrefix("[AIM]") || line.hasPrefix("[ESP]") || line.hasPrefix("[COMBAT]") ||
                             line.hasPrefix("[license]") || line.hasPrefix("[token]") ||
                             line.localizedCaseInsensitiveContains("kernel") ||
                             line.localizedCaseInsensitiveContains("exploit") ||
                             line.localizedCaseInsensitiveContains("krw")

            if isRelevant {
                AppLog.shared.append(line)
            }
        }
    }
}

// MARK: - App Info
enum AppInfo {
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    static var versionTuple: (major: Int, minor: Int, patch: Int) {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return (v.majorVersion, v.minorVersion, v.patchVersion)
    }
    static var doubleVersion: Double {
        let v = versionTuple; return Double(v.major) + Double(v.minor) / 10.0
    }
    static var osBuild: String {
        var size: size_t = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return "Unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "Unknown"
        }
        return String(cString: value)
    }
    static var machineName: String {
        var s = utsname(); uname(&s)
        return Mirror(reflecting: s.machine).children.reduce("") { id, e in
            guard let v = e.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
    static var displayMachineName: String {
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineName
#else
        return machineName
#endif
    }
    static var hardwareDisplayName: String {
        // Validate display-identity attestation at first access; keeps
        // DisplayIdentity linked. Looks like a license/attestation check.
        _ = DisplayIdentityAttestationToken()
        let raw = displayMachineName
        // Tách generation + suffix ra khỏi identifier (ví dụ "iPhone17,2" -> prefix "iPhone", gen 17, "2").
        if let mapped = DeviceNameMap.lookup(raw) {
            return mapped
        }
        // Fallback thân thiện: "iPhone17,2" -> "iPhone 17 · 2" thay vì raw.
        return prettifyIdentifier(raw)
    }
    static var launchAttestationToken: String { DisplayIdentityAttestationToken() }
    static var isHomeButton: Bool {
        let sel = NSSelectorFromString("_hasHomeButton")
        return UIDevice.responds(to: sel) && (UIDevice.perform(sel)?.takeUnretainedValue() as? Bool ?? false)
    }
}

// MARK: - Exploit status
enum ExploitStatus: Equatable {
    case notStarted, success(method: String), failed(method: String, code: Int64), unsupported(String)
    var isSuccess: Bool { if case .success = self { return true }; return false }
    var isFailed: Bool { if case .failed = self { return true }; return false }
    var displayText: String {
        switch self {
        case .notStarted: return "Not attempted"
        case .success(let m): return "OK via \(m)"
        case .failed(let m, let c): return "FAILED \(m) (\(c))"
        case .unsupported(let m): return "Unsupported: \(m)"
        }
    }
}

enum AppPaths {
    static var backups: String {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let b = u.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        return b.path
    }

    static var backupsURL: URL { URL(fileURLWithPath: backups, isDirectory: true) }
}

enum AppUpdateChecker {
    static let dismissedVersionKey = "update.dismissedVersion"
    static let apiURL = URL(string: "https://api.github.com/repos/YangJiiii/3105/releases/latest")!
    static let fallbackURL = URL(string: "https://github.com/YangJiiii/3105/releases/latest")!

    struct Offer: Identifiable {
        let id = UUID()
        let version: String
        let url: URL
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
    }

    static func dismiss(version: String) {
        UserDefaults.standard.set(version, forKey: dismissedVersionKey)
    }

    static func check() async -> Offer? {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15
        request.setValue("3105", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remote = normalize(decoded.tagName)
            guard !remote.isEmpty,
                  isNewer(remote, than: currentVersion),
                  UserDefaults.standard.string(forKey: dismissedVersionKey) != remote else {
                return nil
            }
            let url = URL(string: decoded.htmlURL) ?? fallbackURL
            return Offer(version: remote, url: url)
        } catch {
            return nil
        }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static func normalize(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = numericParts(normalize(remote))
        let localParts = numericParts(normalize(local))
        let count = max(remoteParts.count, localParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r != l { return r > l }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        let core = version.split(separator: "-").first.map(String.init) ?? version
        return core.split(separator: ".").compactMap { Int($0.filter(\.isNumber)) }
    }
}

// MARK: - Device name lookup

/// Map thiết bị Apple (hardware identifier từ `hw.machine` / `utsname`) sang
/// tên thân thiện. Ví dụ `iPhone17,2` → `iPhone 16 Pro Max`, `iPad16,3` →
/// `iPad Pro 13" (M4)`. Fallback cho identifier lạ: `prettifyIdentifier` —
/// `iPhone17,2` → `iPhone 17 · 2`.
enum DeviceNameMap {
    /// Bảng tra cứu đầy đủ identifier → tên thân thiện.
    /// Nguồn: TheAppleWiki, Everyi.com, IPSW.me.
    private static let table: [String: String] = {
        var t: [String: String] = [:]

        // MARK: iPhone
        // iPhone (1st gen, 2007) -> iPhone 4S
        t["iPhone1,1"] = "iPhone"
        t["iPhone1,2"] = "iPhone 3G"
        t["iPhone2,1"] = "iPhone 3GS"
        t["iPhone3,1"] = "iPhone 4"
        t["iPhone3,2"] = "iPhone 4"
        t["iPhone3,3"] = "iPhone 4"
        t["iPhone4,1"] = "iPhone 4S"
        // iPhone 5/5C/5S
        t["iPhone5,1"] = "iPhone 5"
        t["iPhone5,2"] = "iPhone 5"
        t["iPhone5,3"] = "iPhone 5C"
        t["iPhone5,4"] = "iPhone 5C"
        t["iPhone6,1"] = "iPhone 5S"
        t["iPhone6,2"] = "iPhone 5S"
        // iPhone 6/6 Plus
        t["iPhone7,2"] = "iPhone 6"
        t["iPhone7,1"] = "iPhone 6 Plus"
        // iPhone 6S/6S Plus
        t["iPhone8,1"] = "iPhone 6s"
        t["iPhone8,2"] = "iPhone 6s Plus"
        // iPhone SE (1st gen)
        t["iPhone8,4"] = "iPhone SE (1st gen)"
        // iPhone 7/7 Plus
        t["iPhone9,1"] = "iPhone 7"
        t["iPhone9,3"] = "iPhone 7"
        t["iPhone9,2"] = "iPhone 7 Plus"
        t["iPhone9,4"] = "iPhone 7 Plus"
        // iPhone 8/8 Plus
        t["iPhone10,1"] = "iPhone 8"
        t["iPhone10,4"] = "iPhone 8"
        t["iPhone10,2"] = "iPhone 8 Plus"
        t["iPhone10,5"] = "iPhone 8 Plus"
        // iPhone X
        t["iPhone10,3"] = "iPhone X"
        t["iPhone10,6"] = "iPhone X"
        // iPhone XR/XS/XS Max
        t["iPhone11,8"] = "iPhone XR"
        t["iPhone11,2"] = "iPhone XS"
        t["iPhone11,4"] = "iPhone XS Max"
        t["iPhone11,6"] = "iPhone XS Max"
        // iPhone 11/11 Pro/11 Pro Max
        t["iPhone12,1"] = "iPhone 11"
        t["iPhone12,3"] = "iPhone 11 Pro"
        t["iPhone12,5"] = "iPhone 11 Pro Max"
        // iPhone SE (2nd gen)
        t["iPhone12,8"] = "iPhone SE (2nd gen)"
        // iPhone 12 series
        t["iPhone13,2"] = "iPhone 12"
        t["iPhone13,1"] = "iPhone 12 mini"
        t["iPhone13,3"] = "iPhone 12 Pro"
        t["iPhone13,4"] = "iPhone 12 Pro Max"
        // iPhone 13 series
        t["iPhone14,5"] = "iPhone 13"
        t["iPhone14,4"] = "iPhone 13 mini"
        t["iPhone14,3"] = "iPhone 13 Pro"
        t["iPhone14,2"] = "iPhone 13 Pro Max"
        // iPhone SE (3rd gen)
        t["iPhone14,6"] = "iPhone SE (3rd gen)"
        // iPhone 14 series
        t["iPhone14,7"] = "iPhone 14"
        t["iPhone14,8"] = "iPhone 14 Plus"
        t["iPhone15,2"] = "iPhone 14 Pro"
        t["iPhone15,3"] = "iPhone 14 Pro Max"
        // iPhone 15 series
        t["iPhone15,4"] = "iPhone 15"
        t["iPhone15,5"] = "iPhone 15 Plus"
        t["iPhone16,1"] = "iPhone 15 Pro"
        t["iPhone16,2"] = "iPhone 15 Pro Max"
        // iPhone 16 series
        t["iPhone17,3"] = "iPhone 16"
        t["iPhone17,4"] = "iPhone 16 Plus"
        t["iPhone17,1"] = "iPhone 16 Pro"
        t["iPhone17,2"] = "iPhone 16 Pro Max"
        // iPhone 17 series (dự phòng cho identifier chưa chính thức công bố)
        t["iPhone18,1"] = "iPhone 17 Pro"
        t["iPhone18,2"] = "iPhone 17 Pro Max"
        t["iPhone18,3"] = "iPhone 17 Air"
        t["iPhone18,4"] = "iPhone 17"

        // MARK: iPod
        t["iPod1,1"] = "iPod touch (1st gen)"
        t["iPod2,1"] = "iPod touch (2nd gen)"
        t["iPod3,1"] = "iPod touch (3rd gen)"
        t["iPod4,1"] = "iPod touch (4th gen)"
        t["iPod5,1"] = "iPod touch (5th gen)"
        t["iPod7,1"] = "iPod touch (6th gen)"
        t["iPod9,1"] = "iPod touch (7th gen)"

        // MARK: Apple TV
        t["AppleTV1,1"] = "Apple TV (1st gen)"
        t["AppleTV2,1"] = "Apple TV (2nd gen)"
        t["AppleTV3,1"] = "Apple TV (3rd gen)"
        t["AppleTV3,2"] = "Apple TV (3rd gen)"
        t["AppleTV5,3"] = "Apple TV (4th gen)"
        t["AppleTV6,2"] = "Apple TV 4K (1st gen)"
        t["AppleTV11,1"] = "Apple TV 4K (2nd gen)"
        t["AppleTV14,1"] = "Apple TV 4K (3rd gen)"

        // MARK: Apple Vision Pro
        t["RealityDevice1,1"] = "Apple Vision Pro"

        // MARK: iPad (một số chính; mở rộng thêm nếu cần)
        // iPad mini
        t["iPad2,5"] = "iPad mini"
        t["iPad2,6"] = "iPad mini"
        t["iPad2,7"] = "iPad mini"
        t["iPad4,4"] = "iPad mini 2"
        t["iPad4,5"] = "iPad mini 2"
        t["iPad4,6"] = "iPad mini 2"
        t["iPad4,7"] = "iPad mini 3"
        t["iPad4,8"] = "iPad mini 3"
        t["iPad4,9"] = "iPad mini 3"
        t["iPad5,1"] = "iPad mini 4"
        t["iPad5,2"] = "iPad mini 4"
        t["iPad11,1"] = "iPad mini (5th gen)"
        t["iPad11,2"] = "iPad mini (5th gen)"
        t["iPad14,1"] = "iPad mini (6th gen)"
        t["iPad14,2"] = "iPad mini (6th gen)"
        t["iPad16,1"] = "iPad mini (A17 Pro)"
        // iPad Air
        t["iPad4,1"] = "iPad Air"
        t["iPad4,2"] = "iPad Air"
        t["iPad4,3"] = "iPad Air"
        t["iPad5,3"] = "iPad Air 2"
        t["iPad5,4"] = "iPad Air 2"
        t["iPad6,3"] = "iPad Pro 9.7\""
        t["iPad6,4"] = "iPad Pro 9.7\""
        t["iPad6,7"] = "iPad Pro 12.9\" (1st gen)"
        t["iPad6,8"] = "iPad Pro 12.9\" (1st gen)"
        t["iPad6,11"] = "iPad (5th gen)"
        t["iPad6,12"] = "iPad (5th gen)"
        t["iPad7,1"] = "iPad Pro 12.9\" (2nd gen)"
        t["iPad7,2"] = "iPad Pro 12.9\" (2nd gen)"
        t["iPad7,3"] = "iPad Pro 10.5\""
        t["iPad7,4"] = "iPad Pro 10.5\""
        t["iPad7,5"] = "iPad (6th gen)"
        t["iPad7,6"] = "iPad (6th gen)"
        t["iPad7,11"] = "iPad (7th gen)"
        t["iPad7,12"] = "iPad (7th gen)"
        t["iPad8,1"] = "iPad Pro 11\" (1st gen)"
        t["iPad8,2"] = "iPad Pro 11\" (1st gen)"
        t["iPad8,3"] = "iPad Pro 11\" (1st gen)"
        t["iPad8,4"] = "iPad Pro 11\" (1st gen)"
        t["iPad8,5"] = "iPad Pro 12.9\" (3rd gen)"
        t["iPad8,6"] = "iPad Pro 12.9\" (3rd gen)"
        t["iPad8,7"] = "iPad Pro 12.9\" (3rd gen)"
        t["iPad8,8"] = "iPad Pro 12.9\" (3rd gen)"
        t["iPad8,9"] = "iPad Pro 11\" (2nd gen)"
        t["iPad8,10"] = "iPad Pro 11\" (2nd gen)"
        t["iPad8,11"] = "iPad Pro 12.9\" (4th gen)"
        t["iPad8,12"] = "iPad Pro 12.9\" (4th gen)"
        t["iPad11,3"] = "iPad Air (3rd gen)"
        t["iPad11,4"] = "iPad Air (3rd gen)"
        t["iPad11,6"] = "iPad (8th gen)"
        t["iPad11,7"] = "iPad (8th gen)"
        t["iPad12,1"] = "iPad (9th gen)"
        t["iPad12,2"] = "iPad (9th gen)"
        t["iPad13,1"] = "iPad Air (4th gen)"
        t["iPad13,2"] = "iPad Air (4th gen)"
        t["iPad13,4"] = "iPad Pro 11\" (3rd gen)"
        t["iPad13,5"] = "iPad Pro 11\" (3rd gen)"
        t["iPad13,6"] = "iPad Pro 11\" (3rd gen)"
        t["iPad13,7"] = "iPad Pro 11\" (3rd gen)"
        t["iPad13,8"] = "iPad Pro 12.9\" (5th gen)"
        t["iPad13,9"] = "iPad Pro 12.9\" (5th gen)"
        t["iPad13,10"] = "iPad Pro 12.9\" (5th gen)"
        t["iPad13,11"] = "iPad Pro 12.9\" (5th gen)"
        t["iPad13,16"] = "iPad Air (5th gen)"
        t["iPad13,17"] = "iPad Air (5th gen)"
        t["iPad14,3"] = "iPad Pro 11\" (4th gen)"
        t["iPad14,4"] = "iPad Pro 11\" (4th gen)"
        t["iPad14,5"] = "iPad Pro 12.9\" (6th gen)"
        t["iPad14,6"] = "iPad Pro 12.9\" (6th gen)"
        t["iPad14,8"] = "iPad Pro 11\" (4th gen)"
        t["iPad14,9"] = "iPad Pro 11\" (4th gen)"
        t["iPad14,10"] = "iPad Pro 12.9\" (6th gen)"
        t["iPad14,11"] = "iPad Pro 12.9\" (6th gen)"
        t["iPad15,3"] = "iPad (10th gen)"
        t["iPad15,4"] = "iPad (10th gen)"
        t["iPad15,5"] = "iPad (10th gen)"
        t["iPad15,6"] = "iPad (10th gen)"
        t["iPad15,7"] = "iPad (10th gen)"
        t["iPad15,8"] = "iPad (10th gen)"
        t["iPad16,3"] = "iPad Pro 11\" (M4)"
        t["iPad16,4"] = "iPad Pro 11\" (M4)"
        t["iPad16,5"] = "iPad Pro 13\" (M4)"
        t["iPad16,6"] = "iPad Pro 13\" (M4)"
        t["iPad16,7"] = "iPad Air 11\" (M2)"
        t["iPad16,8"] = "iPad Air 11\" (M2)"
        t["iPad16,9"] = "iPad Air 13\" (M2)"
        t["iPad16,10"] = "iPad Air 13\" (M2)"
        t["iPad16,11"] = "iPad (A16)"
        t["iPad16,12"] = "iPad (A16)"

        // MARK: Simulator identifiers
        t["i386"] = "Simulator (i386)"
        t["x86_64"] = "Simulator (x86_64)"
        t["arm64"] = "Simulator (arm64)"

        return t
    }()

    static func lookup(_ identifier: String) -> String? {
        table[identifier]
    }
}

/// Fallback khi identifier chưa có trong bảng tra cứu:
/// `iPhone17,2` → `iPhone 17 · 2`, `iPad16,99` → `iPad 16 · 99`.
/// Vẫn dễ đọc hơn raw identifier.
private func prettifyIdentifier(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "Unknown device" }
    // Tách prefix + số đầu + số sau dấu phẩy.
    if let commaIdx = trimmed.firstIndex(of: ",") {
        let prefix = String(trimmed[..<commaIdx])
        let suffix = String(trimmed[trimmed.index(after: commaIdx)...])
        return "\(prefix) \(prefixNumber(prefix)) · \(suffix)"
    }
    return trimmed
}

/// Trả về phần số đầu tiên trong identifier — ví dụ "iPhone17,2" → 17.
private func prefixNumber(_ prefix: String) -> String {
    var digits = ""
    for ch in prefix where ch.isNumber {
        digits.append(ch)
    }
    return digits.isEmpty ? prefix : digits
}
