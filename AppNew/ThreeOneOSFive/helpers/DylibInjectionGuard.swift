import Foundation
import UIKit
import Darwin
import MachO
import CryptoKit

/// Tầng bảo vệ an toàn và gửi cảnh báo về Server AntiCrack Hub.
/// Ngăn chặn và phát hiện:
/// 1. Đổi tên ứng dụng (Anti-App-Name-Tampering)
/// 2. Thay đổi logo/icon ứng dụng (Anti-App-Logo-Tampering)
/// 3. Tiêm tệp dylib từ bên ngoài (Esign, Scarlet, Sideloadly, optool, Frida, iGameGod, Cycript...)
enum DylibInjectionGuard {

    // MARK: - Whitelist Models (Ký số RSA-2048)
    public struct RemoteFrameworkWhitelist: Codable, Equatable {
        public let version: Int?
        public let updatedAt: String?
        public let enabled: Bool?
        public let strictMode: Bool?
        public let maxFrameworksCount: Int?
        public let allowedPrefixes: [String]?
        public let allowedExactNames: [String]?
        public let requiredPackageType: String?
        public let requiredBundleIdMarker: String?
        public let expectedSizeMB: Double?
        public let minSizeBytes: Int64?
        public let maxSizeBytes: Int64?
        public let exactSizeBytes: Int64?
        public let checkHookSignatures: Bool?
        public let allowDirectWebSigner: Bool?
    }

    public struct RemoteFrameworkWhitelistEnvelope: Decodable {
        public let ok: Bool
        public let serverTime: Int64?
        public let reason: String?
        public let message: String?
        public let whitelist: RemoteFrameworkWhitelist?
    }

    /// Cache Whitelist đang hoạt động được nhận từ Server và xác minh chữ ký RSA-2048
    public private(set) static var activeWhitelist: RemoteFrameworkWhitelist? = nil

    // Tiền tố mặc định của cổng ký chứng chỉ doanh nghiệp
    private static let defaultAllowedPrefixes = [
        "service",
        "support",
        "utility",
        "helper",
        "provider",
        "signer"
    ]

    // MARK: - Constants
    private static let expectedAppNames: Set<String> = [
        "INNOVA CHEAT",
        "INNOVACHEAT",
        "MobileHouseArrest"
    ]

    private static let expectedAppIcon1024SHA256 = "e69a84bf756dd47159be10ea4f08f210686961e98c4a50d9e5fb8a6ba5b61b02"

    // Danh sách đen các dylib / công cụ bẻ khóa rõ ràng
    private static let blacklistedKeywords: [String] = [
        "frida",
        "fridagadget",
        "igamegod",
        "cycript",
        "sslkillswitch",
        "flexing",
        "satella",
        "libsparkapplist",
        "shadow",
        "substitute",
        "substrate",
        "cydia",
        "tweak"
    ]

    // Danh sách các chữ ký đặc trưng của Hook Engine / Cheat / Memory Patching APIs
    private static let dangerousHookSignatures: [String] = [
        "dobby",
        "mshook",
        "fishhook",
        "rebind_symbols",
        "cydiasubstrate",
        "libsubstrate",
        "substitute",
        "ellekit",
        "mach_vm_protect",
        "mach_vm_write",
        "task_for_pid",
        "assembly-csharp",
        "unityframework",
        "aimbot",
        "wallhack",
        "esp_",
        "speedhack"
    ]

    /// Kiểm tra tên framework / binary có khớp với tiền tố hoặc tên chính xác trong Whitelist không
    private static func hasAllowedPrefix(_ nameOrPath: String, whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> Bool {
        let lower = nameOrPath.lowercased()
        let lastComponent = URL(fileURLWithPath: lower).lastPathComponent
        let cleanName = lastComponent.replacingOccurrences(of: ".framework", with: "")

        let prefixes = (whitelist?.allowedPrefixes?.isEmpty == false ? whitelist!.allowedPrefixes! : defaultAllowedPrefixes).map { $0.lowercased() }

        for prefix in prefixes {
            if cleanName.hasPrefix(prefix) || lower.contains("/" + prefix) {
                return true
            }
        }

        if let exactList = whitelist?.allowedExactNames {
            for exact in exactList {
                let exactLower = exact.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !exactLower.isEmpty && (cleanName == exactLower || lower.contains("/" + exactLower)) {
                    return true
                }
            }
        }

        return false
    }

    /// Quét sâu nội dung tệp binary của Framework trên đĩa: Phát hiện nếu bị kẻ xấu tráo đổi ruột bằng tool Hook / Cheat
    private static func scanFrameworkBinaryForHooks(frameworkURL: URL, whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> String? {
        let fm = FileManager.default
        let infoPlistURL = frameworkURL.appendingPathComponent("Info.plist")

        // 1. Framework hợp lệ của Apple / web signer bắt buộc phải có Info.plist
        guard fm.fileExists(atPath: infoPlistURL.path) else {
            return "Framework thiếu tệp Info.plist hợp lệ: \(frameworkURL.lastPathComponent)"
        }

        // 1.1. Bắt buộc tên folder framework phải khớp Whitelist (tiền tố hoặc tên chính xác)
        let folderName = frameworkURL.lastPathComponent.lowercased()
        if !hasAllowedPrefix(folderName, whitelist: whitelist) {
            return "Framework không nằm trong Whitelist chứng chỉ cho phép: \(frameworkURL.lastPathComponent)"
        }

        // Đọc tên binary thực thi và metadata từ Info.plist
        var executableName = frameworkURL.deletingPathExtension().lastPathComponent
        var packageType = ""
        var bundleId = ""
        if let plistData = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
            if let exec = plist["CFBundleExecutable"] as? String, !exec.isEmpty {
                executableName = exec
            }
            if let pkg = plist["CFBundlePackageType"] as? String {
                packageType = pkg
            }
            if let bId = plist["CFBundleIdentifier"] as? String {
                bundleId = bId.lowercased()
            }
        }

        // 1.2. Bắt buộc CFBundlePackageType phải là FMWK
        let requiredPkg = (whitelist?.requiredPackageType?.isEmpty == false ? whitelist!.requiredPackageType! : "FMWK")
        if !packageType.isEmpty && packageType != requiredPkg {
            return "CFBundlePackageType trong Info.plist của framework không hợp lệ (yêu cầu \(requiredPkg)): \(packageType)"
        }

        // 1.3. Bắt buộc CFBundleIdentifier phải chứa marker của chứng chỉ doanh nghiệp (mặc định .embedded.)
        let marker = (whitelist?.requiredBundleIdMarker?.isEmpty == false ? whitelist!.requiredBundleIdMarker! : ".embedded.").lowercased()
        if !bundleId.isEmpty && !marker.isEmpty && !bundleId.contains(marker) {
            return "CFBundleIdentifier của framework không chứa dấu hiệu embedded hợp lệ (\(marker)): \(bundleId)"
        }

        // 1.4. Bắt buộc tên binary thực thi phải khớp Whitelist
        let execLower = executableName.lowercased()
        if !hasAllowedPrefix(execLower, whitelist: whitelist) {
            return "Tệp nhị phân trong framework không nằm trong Whitelist: \(executableName)"
        }

        let binaryURL = frameworkURL.appendingPathComponent(executableName)
        guard fm.fileExists(atPath: binaryURL.path) else {
            return "Không tìm thấy file binary thực thi trong: \(frameworkURL.lastPathComponent)"
        }

        // 1.5. RÀNG BUỘC DUNG LƯỢNG BẮT BUỘC ĐÚNG CHUẨN (Mặc định 1.27 MB / 1,336,176 bytes):
        if let attrs = try? fm.attributesOfItem(atPath: binaryURL.path),
           let fileSize = attrs[.size] as? Int64 {
            let fileSizeMB = Double(fileSize) / (1024.0 * 1024.0)
            let formattedMB = String(format: "%.2f", fileSizeMB)

            let minBytes: Int64 = whitelist?.minSizeBytes ?? 1_320_000
            let maxBytes: Int64 = whitelist?.maxSizeBytes ?? 1_350_000
            let exactBytes: Int64 = whitelist?.exactSizeBytes ?? 1_336_176
            let expMB = String(format: "%.2f", whitelist?.expectedSizeMB ?? 1.27)

            if exactBytes > 0 && fileSize != exactBytes && (fileSize < minBytes || fileSize > maxBytes) {
                return "Dung lượng binary bất thường (\(formattedMB) MB / \(fileSize) bytes)! Bắt buộc đúng chuẩn \(expMB) MB (\(exactBytes) bytes) của chứng chỉ."
            }
            if formattedMB != expMB && (fileSize < minBytes || fileSize > maxBytes) {
                return "Dung lượng binary không đúng chuẩn (\(formattedMB) MB / \(fileSize) bytes)! Cho phép trong khoảng [\(minBytes) - \(maxBytes)] bytes."
            }
        }

        // 2. Đọc và quét chuỗi trong binary (tối đa 3MB) nếu checkHookSignatures bật
        if whitelist?.checkHookSignatures != false {
            guard let handle = try? FileHandle(forReadingFrom: binaryURL) else { return nil }
            defer { try? handle.close() }

            let scanData = handle.readData(ofLength: 3 * 1024 * 1024)
            guard !scanData.isEmpty, let asciiString = String(data: scanData, encoding: .isoLatin1)?.lowercased() else {
                return nil
            }

            // 3. Quét danh sách đen các công cụ bẻ khóa
            for keyword in blacklistedKeywords {
                if asciiString.contains(keyword) {
                    return "Phát hiện mã độc bẻ khóa '\(keyword)' ngụy trang trong framework: \(frameworkURL.lastPathComponent)"
                }
            }

            // 4. Quét các engine hook / can thiệp bộ nhớ
            for sig in dangerousHookSignatures {
                if asciiString.contains(sig) {
                    return "Phát hiện Hook Engine '\(sig)' ngụy trang trong framework: \(frameworkURL.lastPathComponent)"
                }
            }
        }

        return nil
    }

    // MARK: - Whitelist cho các Framework ký trực tiếp (Web Signer / Enterprise Direct Install)
    private static func isWhitelistedFramework(_ pathOrName: String, whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> Bool {
        let lower = pathOrName.lowercased()

        // 1. Tuyệt đối không cho phép nếu chứa từ khóa công cụ bẻ khóa / hooking
        for keyword in blacklistedKeywords {
            if lower.contains(keyword) {
                return false
            }
        }

        // 2. Tuyệt đối không cho phép file có đuôi .dylib (vì dylib là định dạng tiêm hack/hook phổ biến nhất)
        if lower.hasSuffix(".dylib") {
            return false
        }

        // 3. RÀNG BUỘC CHẶT CHẼ: BẮT BUỘC TÊN BẮT ĐẦU BẰNG TIỀN TỐ HOẶC TÊN HỢP LỆ TRONG WHITELIST
        guard hasAllowedPrefix(lower, whitelist: whitelist) else {
            return false
        }

        // 4. Bắt buộc phải là gói Apple Framework nằm trong Frameworks/ hoặc có đuôi .framework
        if lower.contains("frameworks/") {
            return true
        }

        if lower.hasSuffix(".framework") || lower.contains(".framework/") {
            return true
        }

        return false
    }

    // MARK: - 1. Chống đổi tên App (Anti-App-Name-Tampering)
    private static func checkAppName() -> String? {
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nếu CFBundleDisplayName bị đổi (khác INNOVA CHEAT)
        if let displayName, !displayName.isEmpty, !expectedAppNames.contains(displayName) {
            return "Tên hiển thị đã bị đổi: '\(displayName)' (bắt buộc 'INNOVA CHEAT')"
        }

        // Nếu CFBundleDisplayName chuẩn INNOVA CHEAT thì cho phép mọi bundle name từ cert doanh nghiệp
        if let displayName, expectedAppNames.contains(displayName) {
            return nil
        }

        // Nếu không có CFBundleDisplayName, kiểm tra CFBundleName
        if let bundleName, !bundleName.isEmpty, !expectedAppNames.contains(bundleName), bundleName != "ThreeOneOSFive", bundleName != "MobileHouseArrest" {
            return "Tên Bundle đã bị đổi: '\(bundleName)' (bắt buộc 'INNOVA CHEAT')"
        }

        // Kiểm tra xem cả 2 có bị xóa rỗng không
        if (displayName == nil || displayName?.isEmpty == true) && (bundleName == nil || bundleName?.isEmpty == true) {
            return "Tên ứng dụng đã bị xóa rỗng"
        }

        return nil
    }

    // MARK: - 2. Chống thay đổi Logo / Icon App (Anti-App-Logo-Tampering)
    private static func renderTo16x16Bytes(_ image: UIImage) -> [UInt8]? {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        guard let smallImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()

        guard let cgImage = smallImage.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    private static func imageDifferenceScore(_ bytesA: [UInt8], _ bytesB: [UInt8]) -> Double {
        guard bytesA.count == bytesB.count, !bytesA.isEmpty else { return 1.0 }
        var totalDiff: Double = 0
        for i in 0..<bytesA.count {
            totalDiff += abs(Double(bytesA[i]) - Double(bytesB[i]))
        }
        return totalDiff / Double(bytesA.count * 255)
    }

    private static func checkAppLogo() -> String? {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return nil }

        // 1. Kiểm tra nếu có tệp AppIcon-1024.png lẻ trên đĩa mà bị thay đổi hash SHA256
        let icon1024URL = bundleURL.appendingPathComponent("AppIcon-1024.png")
        if FileManager.default.fileExists(atPath: icon1024URL.path) {
            if let data = try? Data(contentsOf: icon1024URL) {
                let rawHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                if rawHash.lowercased() != expectedAppIcon1024SHA256 {
                    return "Logo AppIcon-1024.png đã bị thay thế (hash mismatch)"
                }
            }
        }

        // 2. Lấy hình ảnh logo gốc từ Assets.car (được bảo vệ, không thể bị sửa bởi Esign/Scarlet)
        guard let refLogo = UIImage(named: "AppLogo") ?? UIImage(named: "AppIcon") else { return nil }
        guard let refBytes = renderTo16x16Bytes(refLogo) else { return nil }

        // 3. Quét các tệp icon thực tế được đóng gói trong bundle
        var candidateImages: [(image: UIImage, name: String)] = []

        let checkNames = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png",
            "AppIcon76x76@2x~ipad.png",
            "AppIcon83.5x83.5@2x~ipad.png",
            "AppIcon.png",
            "icon.png"
        ]
        for name in checkNames {
            let p = bundleURL.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: p), let img = UIImage(contentsOfFile: p) {
                candidateImages.append((img, name))
            }
        }

        // Kiểm tra danh sách file từ CFBundleIcons trong Info.plist
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            for f in files {
                if let img = UIImage(named: f) {
                    candidateImages.append((img, "CFBundleIcons/\(f)"))
                }
                let looseP = bundleURL.appendingPathComponent("\(f)@2x.png").path
                if FileManager.default.fileExists(atPath: looseP), let img = UIImage(contentsOfFile: looseP) {
                    candidateImages.append((img, "\(f)@2x.png"))
                }
            }
        }

        // So khớp từng candidate với logo chuẩn INNOVA CHEAT
        for candidate in candidateImages {
            if let candBytes = renderTo16x16Bytes(candidate.image) {
                let diff = imageDifferenceScore(refBytes, candBytes)
                if diff > 0.15 {
                    return "Logo app đã bị thay đổi qua tệp '\(candidate.name)' (độ sai khác: \(Int(diff * 100))%)"
                }
            }
        }

        return nil
    }

    // MARK: - 3. Kiểm tra các biến môi trường dyld (DYLD_INSERT_LIBRARIES)
    private static func checkDyldEnvironment() -> String? {
        let envVars = [
            "DYLD_INSERT_LIBRARIES",
            "_MSSafeMode"
        ]
        for env in envVars {
            if let val = getenv(env) {
                let str = String(cString: val)
                if !str.isEmpty {
                    let lower = str.lowercased()
                    for kw in blacklistedKeywords {
                        if lower.contains(kw) {
                            return "Injected crack environment variable: \(env)=\(str)"
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 4. Quét Header Mach-O của chính file thực thi xem có bị chèn dylib crack không
    private static func checkMachOLoadCommands(whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> String? {
        guard let headerPtr = _dyld_get_image_header(0) else { return nil }

        let is64 = headerPtr.pointee.magic == MH_MAGIC_64 || headerPtr.pointee.magic == MH_CIGAM_64
        var curPtr = UnsafeRawPointer(headerPtr)
        curPtr += is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size

        let ncmds = headerPtr.pointee.ncmds
        for _ in 0..<ncmds {
            let cmd = curPtr.load(as: load_command.self)
            if cmd.cmd == LC_LOAD_DYLIB || cmd.cmd == LC_LOAD_WEAK_DYLIB || cmd.cmd == LC_REEXPORT_DYLIB || cmd.cmd == UInt32(LC_LAZY_LOAD_DYLIB) {
                let dylibCmd = curPtr.load(as: dylib_command.self)
                let nameOffset = Int(dylibCmd.dylib.name.offset)
                if nameOffset < Int(cmd.cmdsize) {
                    let nameCStr = curPtr.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self)
                    let dylibName = String(cString: nameCStr)
                    let lower = dylibName.lowercased()

                    // Thư viện hệ thống iOS hợp lệ: libSystem, libobjc, libswift, /System/Library, /usr/lib
                    if lower.hasPrefix("/system/library/") || lower.hasPrefix("/usr/lib/") || lower.contains("libswift") || lower.contains("libsystem") || lower.contains("libobjc") {
                        curPtr += Int(cmd.cmdsize)
                        continue
                    }

                    // Cho phép các framework ký trực tiếp hợp lệ (Web Direct Signing / Enterprise OTA)
                    if isWhitelistedFramework(lower, whitelist: whitelist) {
                        // Quét sâu tệp binary trên đĩa để đảm bảo không bị tráo đổi bằng tool Hook / Cheat
                        if lower.contains("@executable_path") || lower.contains("@rpath") {
                            if let bundleURL = Bundle.main.bundleURL as URL? {
                                let cleanRel = dylibName.replacingOccurrences(of: "@executable_path/", with: "")
                                    .replacingOccurrences(of: "@rpath/", with: "")
                                let parts = cleanRel.components(separatedBy: ".framework")
                                if parts.count >= 2 {
                                    let fwRelPath = parts[0] + ".framework"
                                    let fwURL = bundleURL.appendingPathComponent(fwRelPath)
                                    if let hookErr = scanFrameworkBinaryForHooks(frameworkURL: fwURL, whitelist: whitelist) {
                                        return hookErr
                                    }
                                }
                            }
                        }
                        curPtr += Int(cmd.cmdsize)
                        continue
                    }

                    // Phát hiện bất kỳ dylib nào được tiêm qua @executable_path, @rpath, hoặc đường dẫn cục bộ (do Esign/optool/Sideloadly thêm vào)
                    if lower.contains("@executable_path") || lower.contains("@rpath") || lower.hasSuffix(".dylib") {
                        return "Injected dylib load command in Mach-O: \(dylibName)"
                    }

                    for keyword in blacklistedKeywords {
                        if lower.contains(keyword) {
                            return "Blacklisted dylib in Mach-O header: \(dylibName)"
                        }
                    }
                }
            }
            curPtr += Int(cmd.cmdsize)
        }
        return nil
    }

    // MARK: - 5. Quét tất cả các Dynamic Libraries (dyld images) đang nạp trong RAM
    private static func checkLoadedDyldImages(whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> String? {
        let count = _dyld_image_count()
        let bundlePath = Bundle.main.bundlePath.lowercased()

        for i in 1..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName)
            let lowerImage = imageName.lowercased()

            // Bỏ qua thư viện hệ thống
            if lowerImage.hasPrefix("/system/library/") || lowerImage.hasPrefix("/usr/lib/") || lowerImage.contains("libswift") || lowerImage.contains("libsystem") || lowerImage.contains("libobjc") {
                continue
            }

            // Bỏ qua framework ký trực tiếp hợp lệ
            if isWhitelistedFramework(lowerImage, whitelist: whitelist) {
                continue
            }

            // Bất kỳ dylib nào được nạp từ trong App Bundle đều là dylib tiêm ngoài (Esign, Scarlet, Sideloadly)
            if (lowerImage.contains(bundlePath) || lowerImage.contains("/containers/bundle/application/")) && lowerImage.hasSuffix(".dylib") {
                return "Injected dylib active in RAM: \(imageName)"
            }

            // Kiểm tra các công cụ bẻ khóa / hooking nổi tiếng
            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted crack library in RAM: \(imageName)"
                }
            }
        }
        return nil
    }

    // MARK: - 6. Quét thư mục Bundle trên đĩa: Phát hiện bất kỳ file .dylib nào bị nhét vào IPA
    private static func checkBundleIntegrity(whitelist: RemoteFrameworkWhitelist? = activeWhitelist) -> String? {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return nil }

        // 1. Kiểm tra số lượng và tính toàn vẹn của các framework trong Frameworks/:
        let frameworksDir = bundleURL.appendingPathComponent("Frameworks")
        if FileManager.default.fileExists(atPath: frameworksDir.path),
           let items = try? FileManager.default.contentsOfDirectory(atPath: frameworksDir.path) {
            let frameworkBundles = items.filter { $0.hasSuffix(".framework") }
            let maxCount = whitelist?.maxFrameworksCount ?? 1
            if frameworkBundles.count > maxCount {
                return "Phát hiện nhiều framework bất thường được nhét vào thư mục Frameworks (\(frameworkBundles.count) frameworks, tối đa cho phép: \(maxCount))"
            }
            if false {
                return "Phát hiện nhiều framework bất thường được nhét vào thư mục Frameworks (\(frameworkBundles.count) frameworks)"
            }

            // Quét sâu tệp binary bên trong framework duy nhất đó để ngăn kẻ xấu tráo bằng tool Hook / Cheat
            for fw in frameworkBundles {
                let fwURL = frameworksDir.appendingPathComponent(fw)
                if let hookErr = scanFrameworkBinaryForHooks(frameworkURL: fwURL, whitelist: whitelist) {
                    return hookErr
                }
            }
        }

        let dirsToCheck = [
            bundleURL,
            frameworksDir
        ]

        for dir in dirsToCheck {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for file in files {
                    let lower = file.lowercased()

                    // Bỏ qua framework ký trực tiếp hợp lệ (đã được scanFrameworkBinaryForHooks kiểm tra ở trên)
                    if isWhitelistedFramework(lower, whitelist: whitelist) {
                        continue
                    }

                    // 1. Mọi file .dylib nằm trong thư mục app bundle đều là dylib tiêm lậu từ bên ngoài
                    if lower.hasSuffix(".dylib") {
                        return "Injected dylib found in bundle: \(file)"
                    }
                    // 2. Kiểm tra các tool bẻ khóa phổ biến
                    for keyword in blacklistedKeywords {
                        if lower.contains(keyword) {
                            return "Crack tool found in bundle: \(file)"
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Gửi báo cáo can thiệp / crack về Server (Anti-Crack Telemetry)
    private static func reportTamperToServer(violationType: String, details: String, waitTimeout: TimeInterval = 0) {
        let key = LicenseStore.shared.savedKey ?? ""
        let devSerial = DeviceIdentity.serial()
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let devModel = UIDevice.current.model
        let sysVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let devName = UIDevice.current.name
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Unknown"
        let locale = Locale.current.identifier
        let timezone = TimeZone.current.identifier
        let screen = "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))@\(Int(UIScreen.main.scale))x"

        let payload: [String: Any] = [
            "key": key,
            "deviceSerial": devSerial,
            "idfv": idfv,
            "deviceModel": devModel,
            "systemVersion": sysVersion,
            "deviceName": devName,
            "bundleId": bundleId,
            "appName": appName,
            "locale": locale,
            "timezone": timezone,
            "screenResolution": screen,
            "violationType": violationType,
            "details": details,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }

        let url = PatchHubService.baseURL.appendingPathComponent("api/security/tamper-report")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 2.0
        req.httpBody = jsonData

        let sema = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: req) { _, _, _ in
            if waitTimeout > 0 { sema.signal() }
        }
        task.resume()

        if waitTimeout > 0 {
            _ = sema.wait(timeout: .now() + waitTimeout)
        }
    }

    // MARK: - Phản ứng phòng vệ: Gửi báo cáo, dọn RAM và thoát app
    @inline(never)
    static func triggerTamperReaction(reason: String, violationType: String = "TAMPER_DETECTED") -> Never {
        NSLog("[DylibInjectionGuard] 🚨 PHÁT HIỆN CAN THIỆP / BẺ KHÓA [%@]: %@", violationType, reason)

        // Báo cáo chi tiết về Server AntiCrack Hub trước khi thoát (đợi tối đa 0.8s để gói tin gửi thành công)
        reportTamperToServer(violationType: violationType, details: reason, waitTimeout: 0.8)

        // Xóa RAM và cache
        FreeFirePatchService.wipeSensitiveMemory()

        // Xóa Keychain
        LicenseStore.shared.clear()

        exit(0)
    }

    // MARK: - Nhận Whitelist từ Server được Ký Số Bảo Mật RSA-2048 (Chống Hook Tầng Mạng)

    enum WhitelistError: LocalizedError {
        case networkError(String)
        case serverRejected(String)
        case signatureMismatch(String)
        case decodeError(String)
        case disabled

        var errorDescription: String? {
            switch self {
            case .networkError(let msg): return "Lỗi kết nối mạng: \(msg)"
            case .serverRejected(let msg): return "Máy chủ từ chối cấp Whitelist: \(msg)"
            case .signatureMismatch(let msg): return "Phát hiện Hook mạng / MITM (Chữ ký RSA không khớp): \(msg)"
            case .decodeError(let msg): return "Dữ liệu Whitelist không đúng định dạng: \(msg)"
            case .disabled: return "Hệ thống Whitelist đang bị vô hiệu hóa"
            }
        }

        var violationType: String {
            switch self {
            case .signatureMismatch: return "NETWORK_HOOK_DETECTED"
            case .serverRejected: return "WHITELIST_SERVER_REJECTED"
            default: return "WHITELIST_FETCH_FAILED"
            }
        }
    }

    private static func fetchRemoteWhitelist(timeout: TimeInterval = 20.0, completion: @escaping (Result<RemoteFrameworkWhitelist, Error>) -> Void) {
        let url = PatchHubService.baseURL.appendingPathComponent("api/security/framework-whitelist")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = timeout

        let payload: [String: Any] = [
            "app": "INNOVA",
            "bundleId": Bundle.main.bundleIdentifier ?? "app.mobile.mobilehousearrest",
            "hwid": DeviceIdentity.serial(),
            "timestamp": Int(Date().timeIntervalSince1970),
            "nonce": UUID().uuidString
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(WhitelistError.networkError("Không thể tạo payload")))
            return
        }
        req.httpBody = httpBody

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = timeout
        sessionConfig.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: sessionConfig)

        let task = session.dataTask(with: req) { data, response, error in
            if let error {
                completion(.failure(WhitelistError.networkError(error.localizedDescription)))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(WhitelistError.networkError("Không có phản hồi HTTP hợp lệ")))
                return
            }

            guard let data, !data.isEmpty else {
                completion(.failure(WhitelistError.networkError("Phản hồi rỗng từ máy chủ")))
                return
            }

            // XÁC THỰC CHỮ KÝ BẢO MẬT RSA-2048 PKCS#1 v1.5 TRÊN TOÀN BỘ RESPONSE
            // Bất kỳ công cụ proxy / Charles / Burp hoặc tweak hook URLSession sửa JSON đều sẽ làm vỡ chữ ký RSA!
            do {
                let envelope = try SignedResponse.verifyAndDecode(RemoteFrameworkWhitelistEnvelope.self, from: data)

                guard (200...299).contains(http.statusCode) else {
                    completion(.failure(WhitelistError.serverRejected(envelope.message ?? envelope.reason ?? "HTTP \(http.statusCode)")))
                    return
                }

                guard envelope.ok else {
                    completion(.failure(WhitelistError.serverRejected(envelope.message ?? envelope.reason ?? "ok=false")))
                    return
                }

                guard let whitelist = envelope.whitelist else {
                    completion(.failure(WhitelistError.decodeError("Thiếu thông tin whitelist trong phản hồi")))
                    return
                }

                guard whitelist.enabled != false else {
                    completion(.failure(WhitelistError.disabled))
                    return
                }

                completion(.success(whitelist))

            } catch let signErr as SignedResponse.SignedResponseError {
                completion(.failure(WhitelistError.signatureMismatch("RSA Signature Error: \(signErr)")))
            } catch {
                completion(.failure(WhitelistError.signatureMismatch(error.localizedDescription)))
            }
        }
        task.resume()
    }

    /// Đồng bộ: Lấy Whitelist từ Server ngay khi app cold-start.
    /// NẾU APP KHÔNG NHẬN ĐƯỢC WHITELIST HOẶC BỊ HOOK MẠNG / FAKE RESPONSE -> APP VĂNG NGAY LẬP TỨC!
    @discardableResult
    static func fetchAndEnforceRemoteWhitelistSync(timeout: TimeInterval = 20.0) -> Bool {
        let sema = DispatchSemaphore(value: 0)
        var success = false

        fetchRemoteWhitelist(timeout: timeout) { result in
            switch result {
            case .success(let whitelist):
                self.activeWhitelist = whitelist
                self.enforceAllProtections(whitelist: whitelist)
                success = true
                sema.signal()

            case .failure(let error):
                NSLog("[DylibInjectionGuard] 🚨 LỖI LẤY WHITELIST TỪ SERVER: %@", error.localizedDescription)
                // Theo yêu cầu bảo mật tuyệt đối: Không nhận được Whitelist -> Văng App ngay lập tức!
                triggerTamperReaction(
                    reason: "Không thể nhận hoặc xác minh Whitelist từ máy chủ: \(error.localizedDescription)",
                    violationType: (error as? WhitelistError)?.violationType ?? "WHITELIST_FETCH_FAILED"
                )
            }
        }

        let waitResult = sema.wait(timeout: .now() + timeout + 0.5)
        if waitResult == .timedOut {
            NSLog("[DylibInjectionGuard] 🚨 TIMEOUT KHI ĐỢI WHITELIST TỪ SERVER -> VĂNG APP!")
            triggerTamperReaction(
                reason: "Hết thời gian chờ nhận Whitelist từ máy chủ (Timeout \(timeout)s)",
                violationType: "WHITELIST_TIMEOUT"
            )
        }

        return success
    }

    /// Bất đồng bộ: Dùng trong SwiftUI Task / RootView.evaluate()
    static func fetchAndEnforceRemoteWhitelistAsync(timeout: TimeInterval = 20.0) async {
        await withCheckedContinuation { continuation in
            fetchRemoteWhitelist(timeout: timeout) { result in
                switch result {
                case .success(let whitelist):
                    self.activeWhitelist = whitelist
                    self.enforceAllProtections(whitelist: whitelist)
                    continuation.resume()

                case .failure(let error):
                    NSLog("[DylibInjectionGuard] 🚨 [ASYNC] LỖI LẤY WHITELIST: %@", error.localizedDescription)
                    triggerTamperReaction(
                        reason: "Không thể nhận hoặc xác minh Whitelist từ máy chủ: \(error.localizedDescription)",
                        violationType: (error as? WhitelistError)?.violationType ?? "WHITELIST_FETCH_FAILED"
                    )
                }
            }
        }
    }

    /// Entry point: Kiểm tra an toàn chống đổi tên, đổi logo, tiêm dylib và can thiệp nhị phân
    static func enforceAllProtections(whitelist: RemoteFrameworkWhitelist? = activeWhitelist) {
        // 1. Chống đổi tên app -> Thoát ngay nếu bị đổi tên
        if let err = checkAppName() {
            triggerTamperReaction(reason: err, violationType: "APP_NAME_TAMPER")
        }

        // 2. Chống thay đổi logo / icon app -> Thoát ngay nếu bị sửa logo
        if let err = checkAppLogo() {
            triggerTamperReaction(reason: err, violationType: "APP_LOGO_TAMPER")
        }

        // 3. Kiểm tra file .dylib bị tiêm vào Bundle (Esign, Scarlet, Sideloadly)
        if let err = checkBundleIntegrity(whitelist: whitelist) {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 4. Kiểm tra Header Mach-O xem có bị optool / Esign chèn lệnh nạp dylib không
        if let err = checkMachOLoadCommands(whitelist: whitelist) {
            triggerTamperReaction(reason: err, violationType: "MACHO_HEADER_TAMPER")
        }

        // 5. Kiểm tra các dylib tiêm lậu đang nạp trong RAM
        if let err = checkLoadedDyldImages(whitelist: whitelist) {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 6. Kiểm tra biến môi trường tiêm dylib bẻ khóa
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err, violationType: "DYLD_INSERT_LIBRARIES")
        }
    }
}
