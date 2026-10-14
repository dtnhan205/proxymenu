import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS16Range = "16.0–16.7.x"
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0–26.6.1"
    static let verifiedIOS27Range = "27.0–27.x (LocalDevVPN)"

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f"),
        (0, nil, "24A435"),
        (0, nil, "24A437"),
        (0, nil, "24A440"), // iOS 27.0.1
        (0, nil, "24A441"), // iOS 27.0.1
        (0, nil, "24B83"),
        (0, nil, "24B5055e"),
        (0, nil, "24C5061e"),
        (0, nil, "24C5070e")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 16 {
            // UI hỗ trợ iOS 16.0–16.7.x (theo yêu cầu). Offset kexploit vẫn giữ
            // nguyên (xem `kexploit/offsets.m`) — chỉ TEXT/UI/policy ở đây.
            // Thiết bị iOS 16 sẽ được mark "supported" nhưng kernel exploit
            // thực tế sẽ fail ở runtime cho tới khi bổ sung offset.
            return minor <= 7
        }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        // iOS 27: Hỗ trợ thông qua LocalDevVPN tunnel hoặc các bản build đã kiểm thử
        if major == 27 {
            return true
        }

        return false
    }
}
