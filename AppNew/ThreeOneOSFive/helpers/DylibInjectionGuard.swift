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

    // MARK: - Constants
    private static let expectedAppNames: Set<String> = [
        "INNOVA CHEAT",
        "INNOVACHEAT",
        "MobileHouseArrest"
    ]

    private static let expectedAppIcon1024SHA256 = "e69a84bf756dd47159be10ea4f08f210686961e98c4a50d9e5fb8a6ba5b61b02"

    // Danh sách đen các dylib / công cụ bẻ khóa rõ ràng (không chặn jailbreak engine thông thường như ElleKit, Substitute, libhooker)
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

    /// Kiểm tra tên framework / binary có bắt đầu bằng "service" hoặc "support" hay không
    private static func hasAllowedPrefix(_ nameOrPath: String) -> Bool {
        let lower = nameOrPath.lowercased()
        let lastComponent = URL(fileURLWithPath: lower).lastPathComponent
        let cleanName = lastComponent.replacingOccurrences(of: ".framework", with: "")

        if cleanName.hasPrefix("service") || cleanName.hasPrefix("support") {
            return true
        }

        if lower.contains("/service") || lower.contains("/support") {
            return true
        }

        return false
    }

    /// Quét sâu nội dung tệp binary của Framework trên đĩa: Phát hiện nếu bị kẻ xấu tráo đổi ruột bằng tool Hook / Cheat
    private static func scanFrameworkBinaryForHooks(frameworkURL: URL) -> String? {
        let fm = FileManager.default
        let infoPlistURL = frameworkURL.appendingPathComponent("Info.plist")

        // 1. Framework hợp lệ của Apple / web signer bắt buộc phải có Info.plist
        guard fm.fileExists(atPath: infoPlistURL.path) else {
            return "Framework thiếu tệp Info.plist hợp lệ: \(frameworkURL.lastPathComponent)"
        }

        // 1.1. Bắt buộc tên folder framework phải bắt đầu bằng 'Service' hoặc 'Support'
        let folderName = frameworkURL.lastPathComponent.lowercased()
        if !folderName.hasPrefix("service") && !folderName.hasPrefix("support") {
            return "Framework không đúng chuẩn chứng chỉ (tên bắt buộc bắt đầu bằng Service hoặc Support): \(frameworkURL.lastPathComponent)"
        }

        // Đọc tên binary thực thi từ Info.plist (hoặc mặc định lấy tên folder không có đuôi .framework)
        var executableName = frameworkURL.deletingPathExtension().lastPathComponent
        if let plistData = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let exec = plist["CFBundleExecutable"] as? String, !exec.isEmpty {
            executableName = exec
        }

        // 1.2. Bắt buộc tên binary thực thi phải bắt đầu bằng 'Service' hoặc 'Support'
        let execLower = executableName.lowercased()
        if !execLower.hasPrefix("service") && !execLower.hasPrefix("support") {
            return "Tệp nhị phân trong framework không đúng chuẩn (phải bắt đầu bằng Service hoặc Support): \(executableName)"
        }

        let binaryURL = frameworkURL.appendingPathComponent(executableName)
        guard fm.fileExists(atPath: binaryURL.path) else {
            return "Không tìm thấy file binary thực thi trong: \(frameworkURL.lastPathComponent)"
        }

        // 1.3. RÀNG BUỘC DUNG LƯỢNG BẮT BUỘC ĐÚNG CHUẨN 1.27 MB:
        if let attrs = try? fm.attributesOfItem(atPath: binaryURL.path),
           let fileSize = attrs[.size] as? Int64 {
            let fileSizeMB = Double(fileSize) / (1024.0 * 1024.0)
            let formattedMB = String(format: "%.2f", fileSizeMB)

            // Chuẩn của binary Service/Support từ cổng ký là 1,336,176 bytes (~1.27 MB)
            // Nếu làm tròn 2 chữ số khác 1.27 hoặc nằm ngoài biên độ 1.26MB - 1.28MB (1,320,000 - 1,350,000 bytes) -> Vi phạm, ban ngay!
            if formattedMB != "1.27" && (fileSize < 1_320_000 || fileSize > 1_350_000) {
                return "Dung lượng binary bất thường (\(formattedMB) MB / \(fileSize) bytes)! Bắt buộc đúng chuẩn 1.27 MB (1,336,176 bytes) của chứng chỉ."
            }
        }

        // 2. Đọc và quét chuỗi trong binary (tối đa 3MB)
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

        return nil
    }

    // MARK: - Whitelist cho các Framework ký trực tiếp (Web Signer / Enterprise Direct Install)
    private static func isWhitelistedFramework(_ pathOrName: String) -> Bool {
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

        // 3. RÀNG BUỘC CHẶT CHẼ: BẮT BUỘC TÊN BẮT ĐẦU BẰNG "SERVICE" HOẶC "SUPPORT"
        guard hasAllowedPrefix(lower) else {
            return false
        }

        // 4. Bắt buộc phải là gói Apple Framework nằm trong Frameworks/ hoặc có đuôi .framework
        if lower.contains("frameworks/") && (lower.contains(".framework") || lower.contains("/service") || lower.contains("/support")) {
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
    private static func checkMachOLoadCommands() -> String? {
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
                    if isWhitelistedFramework(lower) {
                        // Quét sâu tệp binary trên đĩa để đảm bảo không bị tráo đổi bằng tool Hook / Cheat
                        if lower.contains("@executable_path") || lower.contains("@rpath") {
                            if let bundleURL = Bundle.main.bundleURL as URL? {
                                let cleanRel = dylibName.replacingOccurrences(of: "@executable_path/", with: "")
                                    .replacingOccurrences(of: "@rpath/", with: "")
                                let parts = cleanRel.components(separatedBy: ".framework")
                                if parts.count >= 2 {
                                    let fwRelPath = parts[0] + ".framework"
                                    let fwURL = bundleURL.appendingPathComponent(fwRelPath)
                                    if let hookErr = scanFrameworkBinaryForHooks(frameworkURL: fwURL) {
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
    private static func checkLoadedDyldImages() -> String? {
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
            if isWhitelistedFramework(lowerImage) {
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
    private static func checkBundleIntegrity() -> String? {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return nil }

        // 1. Kiểm tra số lượng và tính toàn vẹn của các framework trong Frameworks/:
        let frameworksDir = bundleURL.appendingPathComponent("Frameworks")
        if FileManager.default.fileExists(atPath: frameworksDir.path),
           let items = try? FileManager.default.contentsOfDirectory(atPath: frameworksDir.path) {
            let frameworkBundles = items.filter { $0.hasSuffix(".framework") }
            // Cổng ký trực tiếp chỉ nhúng tối đa 1 framework chứng chỉ
            if frameworkBundles.count > 1 {
                return "Phát hiện nhiều framework bất thường được nhét vào thư mục Frameworks (\(frameworkBundles.count) frameworks)"
            }

            // Quét sâu tệp binary bên trong framework duy nhất đó để ngăn kẻ xấu tráo bằng tool Hook / Cheat
            for fw in frameworkBundles {
                let fwURL = frameworksDir.appendingPathComponent(fw)
                if let hookErr = scanFrameworkBinaryForHooks(frameworkURL: fwURL) {
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
                    if isWhitelistedFramework(lower) {
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

    /// Entry point: Kiểm tra an toàn chống đổi tên, đổi logo, tiêm dylib và can thiệp nhị phân
    static func enforceAllProtections() {
        // 1. Chống đổi tên app -> Thoát ngay nếu bị đổi tên
        if let err = checkAppName() {
            triggerTamperReaction(reason: err, violationType: "APP_NAME_TAMPER")
        }

        // 2. Chống thay đổi logo / icon app -> Thoát ngay nếu bị sửa logo
        if let err = checkAppLogo() {
            triggerTamperReaction(reason: err, violationType: "APP_LOGO_TAMPER")
        }

        // 3. Kiểm tra file .dylib bị tiêm vào Bundle (Esign, Scarlet, Sideloadly)
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 4. Kiểm tra Header Mach-O xem có bị optool / Esign chèn lệnh nạp dylib không
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err, violationType: "MACHO_HEADER_TAMPER")
        }

        // 5. Kiểm tra các dylib tiêm lậu đang nạp trong RAM
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 6. Kiểm tra biến môi trường tiêm dylib bẻ khóa
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err, violationType: "DYLD_INSERT_LIBRARIES")
        }
    }
}
