import Foundation

/// Lightweight compile-time obfuscation cho string nhạy cảm (server URL,
/// endpoint paths, header values). Khi build `.ipa`, các hằng số này tồn
/// tại dưới dạng mảng byte XOR-encoded, không hiện plaintext khi `strings`.
///
/// Không phải crypto thật — chỉ là rào cản static analysis. Attacker runtime
/// vẫn dump được trong RAM, nhưng sẽ KHÔNG thấy URL trong binary scan.
enum Obfuscated {

    /// Decode 1 mảng byte đã XOR với key (cùng độ dài).
    /// `bytes[i] = plaintext[i] XOR key[i]`.
    static func decode(_ bytes: [UInt8], key: [UInt8]) -> String {
        precondition(bytes.count == key.count, "obfuscated length mismatch")
        var out = [UInt8](repeating: 0, count: bytes.count)
        for i in 0..<bytes.count {
            out[i] = bytes[i] ^ key[i]
        }
        return String(bytes: out, encoding: .utf8) ?? ""
    }

    /// Helper tiện cho compile-time literal:
    /// ```swift
    /// let s = Obfuscated.string(bytes: [...], key: [...])
    /// ```
    static func string(bytes: [UInt8], key: [UInt8]) -> String {
        decode(bytes, key: key)
    }
}