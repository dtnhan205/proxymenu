// GENERATED FILE — DO NOT EDIT BY HAND
//
// Nguồn: tools/gen_branding.py
// Build script sẽ regenerate file này mỗi lần build. Đổi brand strings
// tại BRAND_STRINGS trong gen_branding.py, KHÔNG sửa trực tiếp file này.
//
// Mục đích: tránh cracker `strings` ra binary và đổi tên app sang "FooBar"
// để rebrand. Plaintext không tồn tại trong binary, chỉ có hex byte + key.
// Runtime XOR-decode khi cần hiển thị (cached).

import Foundation

enum AppBranding {

    /// Tham chiếu 1 entry đã XOR-encode. Positional tuple `(name, key, ct)`.
    private typealias EntryTuple = (String, [UInt8], [UInt8])

    /// Nhóm các entry của 1 locale. Init nhận mảng tuple và zip thành dictionary.
    private struct LocaleBlock {
        let locale: String
        let entries: [String: [UInt8]]   // name → ct
        let keys:    [String: [UInt8]]   // name → key
        init(locale: String, entries: [EntryTuple]) {
            self.locale = locale
            var ctMap: [String: [UInt8]] = [:]
            var keyMap: [String: [UInt8]] = [:]
            for (name, k, ct) in entries {
                ctMap[name] = ct
                keyMap[name] = k
            }
            self.entries = ctMap
            self.keys = keyMap
        }
    }

    /// Dữ liệu đã encode, key theo locale. Plaintext KHÔNG tồn tại trong binary.
    private static let blocks: [LocaleBlock] = [
        LocaleBlock(
            locale: "en",
            entries: [
            ("tabHome", [0xB1, 0x38, 0x96, 0x09, 0x5D, 0x23, 0xAA, 0x59, 0x76, 0xAF, 0xD1, 0x25, 0x92], [0xE1, 0x4A, 0xF9, 0x71, 0x24, 0x6A, 0xFA, 0x18, 0x56, 0xE0, 0x93, 0x10, 0xA7]),
            ("tabFiles", [0xC2, 0x10, 0xE2, 0xD6, 0x4C, 0xC7, 0x03, 0xFA], [0x84, 0x79, 0x8E, 0xB3, 0x3F]),
            ("tabPatches", [0x7C, 0xBD, 0xA4, 0x2F, 0x1A, 0x13, 0xF3, 0x5B], [0x2C, 0xDC, 0xD0, 0x4C, 0x72, 0x76, 0x80]),
            ("tabSettings", [0x5C, 0xE8, 0x67, 0x53, 0x98, 0x1A, 0xBA, 0x71], [0x0F, 0x8D, 0x13, 0x27, 0xF1, 0x74, 0xDD, 0x02]),
            ("tabWallpapers", [0x78, 0x22, 0x92, 0xF1, 0x58, 0x5D, 0x9F, 0xD7, 0x09, 0xBA], [0x2F, 0x43, 0xFE, 0x9D, 0x28, 0x3C, 0xEF, 0xB2, 0x7B, 0xC9]),
            ]
        ),
        LocaleBlock(
            locale: "vi",
            entries: [
            ("tabHome", [0x68, 0x59, 0x0A, 0x02, 0xA2, 0x89, 0x09, 0xF4, 0x91, 0x0A, 0x64, 0x29, 0xBB], [0x38, 0x2B, 0x65, 0x7A, 0xDB, 0xC0, 0x59, 0xB5, 0xB1, 0x45, 0x26, 0x1C, 0x8E]),
            ("tabFiles", [0x37, 0xA4, 0xF6, 0x03, 0xBC, 0x41, 0x20, 0x0A], [0x63, 0x45, 0x4D, 0x84, 0xCC]),
            ("tabPatches", [0x37, 0x0A, 0x2C, 0x9C, 0xBE, 0xF5, 0x9F, 0xF2], [0x67, 0x6B, 0x58, 0xFF, 0xD6]),
            ("tabSettings", [0x02, 0x7F, 0x06, 0xED, 0x70, 0x84, 0xAB, 0x48, 0x00, 0xA0, 0x1E], [0x41, 0xBC, 0xA6, 0x84, 0x50, 0x40, 0x3A, 0xA9, 0xBA, 0x17, 0x6A]),
            ("tabWallpapers", [0x7D, 0xC8, 0x43, 0x15, 0xE3, 0x30, 0xEA, 0x3E, 0xA6, 0xE9, 0x5F], [0x35, 0x0B, 0xEF, 0x7B, 0x8B, 0x10, 0x84, 0xDF, 0x1D, 0x68, 0x31]),
            ]
        ),
        LocaleBlock(
            locale: "zhHans",
            entries: [
            ("tabHome", [0x95, 0x9C, 0x91, 0x87, 0xEB, 0xB7, 0x12, 0x11, 0x0B, 0x1E, 0x67, 0xE9, 0xDB, 0xC7, 0x4F, 0x5E, 0x3C], [0xC5, 0xEE, 0xFE, 0xFF, 0x92, 0xFE, 0x42, 0x50, 0x2B, 0x51, 0x25, 0xDC, 0xEE, 0xE7, 0x0B, 0x0D, 0x6B]),
            ("tabFiles", [0xB2, 0x4F, 0x7E, 0xBE, 0xCD, 0x2C, 0x2E, 0x8C], [0x54, 0xD9, 0xF9, 0x5A, 0x76, 0x9A]),
            ("tabPatches", [0x0E, 0x75, 0x87, 0x65, 0x0B, 0xC8, 0xFD, 0xE1], [0xE6, 0xD4, 0x22, 0x81, 0xB3, 0x49]),
            ("tabSettings", [0x07, 0x3F, 0x5B, 0xA3, 0xDB, 0x0C, 0xE3, 0x08], [0xEF, 0x91, 0xE5, 0x44, 0x66, 0xA2]),
            ("tabWallpapers", [0xE4, 0x9F, 0xEC, 0x35, 0x29, 0x3E, 0xDB, 0xE8], [0x01, 0x3C, 0x6D, 0xD2, 0x93, 0x86]),
            ]
        )
    ]

    // MARK: - Lazy cache (chỉ decode 1 lần / locale).

    private static var cache: [String: [String: String]] = [:]

    private static func decode(key: [UInt8], ct: [UInt8]) -> String {
        var out = [UInt8](repeating: 0, count: ct.count)
        for i in 0..<ct.count {
            out[i] = ct[i] ^ key[i % key.count]
        }
        return String(bytes: out, encoding: .utf8) ?? ""
    }

    private static func decodedMap(for locale: String) -> [String: String] {
        if let cached = cache[locale] { return cached }
        guard let block = blocks.first(where: { $0.locale == locale }) else {
            // Fallback về "en" nếu locale không có (vd en-GB, zh-Hant).
            if locale != "en" {
                return decodedMap(for: "en")
            }
            return [:]
        }
        var map: [String: String] = [:]
        for (name, ct) in block.entries {
            guard let key = block.keys[name] else { continue }
            map[name] = decode(key: key, ct: ct)
        }
        cache[locale] = map
        return map
    }

    // MARK: - Public API

    /// Trả về brand string đã decode cho locale hiện tại.
    /// - Parameters:
    ///   - name: tên entry, ví dụ "tabHome", "tabFiles", "tabSettings".
    ///   - locale: "en", "vi", hoặc "zh-Hans" (map nội bộ sang key).
    static func string(_ name: String, locale: String) -> String {
        let key = canonicalLocale(locale)
        return decodedMap(for: key)[name] ?? ""
    }

    /// Map locale code sang key trong `blocks`. iOS trả "zh-Hans" → "zhHans".
    private static func canonicalLocale(_ locale: String) -> String {
        switch locale {
        case "zh-Hans", "zhHans": return "zhHans"
        case "vi":                return "vi"
        case "en":                return "en"
        default:                  return "en"
        }
    }
}
