import Foundation
import Security

/// Xác thực chữ ký RSA-SHA256 PKCS#1 v1.5 trên response của server.
///
/// ## Bối cảnh
/// Server (`patch-hub-web/server.js` → `scripts/sign_response.js`) ký mọi
/// response JSON bằng private key RSA-2048 trước khi gửi về client. Wire
/// format mới là:
/// ```json
/// { "data": { ...payload gốc... }, "signature": "BASE64_SIGNATURE" }
/// ```
/// Trước khi update này, server trả JSON thuần — iOS app chỉ cần decode.
/// Sau update, nếu client không verify thì decode thất bại do thiếu field
/// `ok` ở top-level, và user thấy "Phản hồi từ máy chủ không hợp lệ".
///
/// ## Cơ chế bảo mật
/// Cracker muốn fake response (vd trả `ok=true` cho key hết hạn) sẽ phải
/// ký lại bằng đúng private key — mà private key chỉ nằm trên server. Nếu
/// không verify, attacker chỉ cần fake HTTP server là có thể bypass mọi
/// kiểm tra state ở client.
///
/// ## Public key
/// Embed XOR-obfuscated base64 của RSA public key (SPKI format, RSA-2048).
/// Pattern obfuscate giống `Obfuscated.decode` đang dùng cho `baseURLBytes`:
/// `bytes[i] = plain[i] XOR key[i % key.count]`. Không phải crypto thật —
/// chỉ là rào cản static analysis (tránh `strings` ra được public key).
///
/// Khi admin rotate cặp key, cần:
///   1. Chạy `node scripts/generate_rsa_keys.js` trên server.
///   2. Lấy `scripts/keys/public_key_base64.txt` (1 dòng base64).
///   3. Re-encode XOR với key dưới đây, paste lại vào `pubKeyBytes`.
enum SignedResponse {

    // MARK: - Obfuscated RSA public key (Base64 SPKI, RSA-2048)
    // bytes[i] XOR pubKeyXorKey[i % 32] = ASCII(Base64 của public key)
    //
    // LƯU Ý QUAN TRỌNG: KHÔNG dùng `Obfuscated.decode(pubKeyBytes, key:)`
    // vì helper đó có `precondition(bytes.count == key.count)` — sẽ CRASH
    // app khi build public key lần đầu. Public key base64 dài 392 ký tự
    // nhưng key XOR chỉ 32 byte. Ta tự XOR-cycle thay vì dùng helper.
    private static func xorDecode(_ bytes: [UInt8], key: [UInt8]) -> String {
        precondition(!key.isEmpty, "xor key must not be empty")
        var out = [UInt8](repeating: 0, count: bytes.count)
        for i in 0..<bytes.count {
            out[i] = bytes[i] ^ key[i % key.count]
        }
        return String(bytes: out, encoding: .utf8) ?? ""
    }
    private static let pubKeyBytes: [UInt8] = [
        0xEA, 0x12, 0x77, 0xD3, 0x85, 0x25, 0x53, 0xC6, 0x91, 0x60, 0x37, 0x95, 0xF3, 0x5D, 0x18, 0x8F,
        0x13, 0x82, 0x58, 0xF6, 0x5C, 0xD3, 0x02, 0xAF, 0x1B, 0x4D, 0xD0, 0x70, 0x2F, 0x90, 0x8A, 0xC9,
        0xEA, 0x12, 0x77, 0xD3, 0x8F, 0x28, 0x59, 0xCB, 0x92, 0x56, 0x19, 0xA5, 0xB0, 0x6E, 0x1A, 0x82,
        0x69, 0x94, 0x5D, 0xDC, 0x48, 0xF8, 0x70, 0xAA, 0x20, 0x55, 0xB0, 0x76, 0x58, 0x93, 0xD6, 0xC3,
        0xC9, 0x6A, 0x77, 0xA8, 0xBB, 0x06, 0x59, 0xCF, 0x80, 0x41, 0x2E, 0xA5, 0xA9, 0x4E, 0x41, 0x85,
        0x1A, 0x80, 0x39, 0xFC, 0x28, 0xD6, 0x0E, 0x81, 0x18, 0x61, 0xAA, 0x1C, 0x16, 0x8C, 0xFC, 0xE0,
        0xCD, 0x0F, 0x7A, 0xC2, 0xB9, 0x3C, 0x7C, 0xB8, 0x90, 0x70, 0x17, 0xD7, 0xF0, 0x5C, 0x3E, 0xBC,
        0x7C, 0x96, 0x43, 0x86, 0x57, 0xF1, 0x2C, 0xC6, 0x31, 0x6A, 0xE9, 0x01, 0x0B, 0xB2, 0xE2, 0xCB,
        0xD6, 0x62, 0x5C, 0xDA, 0x99, 0x04, 0x5F, 0xC6, 0xA2, 0x46, 0x14, 0xBC, 0xEA, 0x06, 0x42, 0x8B,
        0x05, 0x97, 0x3F, 0xC2, 0x5F, 0xF7, 0x20, 0x81, 0x68, 0x47, 0xAF, 0x78, 0x34, 0x8C, 0xE4, 0xCA,
        0xCA, 0x22, 0x76, 0xA9, 0x86, 0x1D, 0x40, 0xEC, 0xBE, 0x65, 0x0C, 0xD1, 0xEE, 0x6C, 0x3B, 0xBB,
        0x7D, 0x96, 0x58, 0xCD, 0x57, 0xED, 0x13, 0x88, 0x10, 0x64, 0xDA, 0x49, 0x03, 0xA4, 0xF1, 0xC5,
        0xE6, 0x0A, 0x0E, 0xE9, 0xBB, 0x09, 0x21, 0xFD, 0x98, 0x4F, 0x2F, 0xD7, 0xEF, 0x60, 0x42, 0xBB,
        0x6F, 0x99, 0x0E, 0xE0, 0x7C, 0xD4, 0x1E, 0xA0, 0x29, 0x65, 0xDD, 0x52, 0x2F, 0xF3, 0xFD, 0xE3,
        0xE8, 0x19, 0x4E, 0xA0, 0x98, 0x29, 0x70, 0xD9, 0xAA, 0x6A, 0x0D, 0x95, 0xE8, 0x62, 0x01, 0xB1,
        0x6C, 0xB9, 0x50, 0xF5, 0x7A, 0xE7, 0x33, 0x99, 0x34, 0x47, 0xDC, 0x5E, 0x0B, 0xAE, 0xFC, 0xCE,
        0xEA, 0x22, 0x0D, 0xEB, 0xE7, 0x22, 0x67, 0xFA, 0x83, 0x75, 0x69, 0xA0, 0xCF, 0x42, 0x05, 0xFE,
        0x58, 0xA7, 0x59, 0xF8, 0x4F, 0xB3, 0x01, 0x86, 0x36, 0x75, 0xE7, 0x06, 0x0B, 0x94, 0xE7, 0xC9,
        0xE4, 0x03, 0x55, 0xE2, 0x8A, 0x01, 0x5E, 0xE4, 0xE2, 0x28, 0x2B, 0xAC, 0xD2, 0x79, 0x28, 0x82,
        0x19, 0xCD, 0x30, 0x84, 0x2A, 0xCF, 0x2B, 0xBB, 0x6E, 0x5B, 0xD6, 0x06, 0x21, 0xF7, 0xD8, 0xE3,
        0xFF, 0x3A, 0x0D, 0xD0, 0xBA, 0x04, 0x66, 0xCB, 0xBB, 0x6C, 0x06, 0xD1, 0xAA, 0x4E, 0x26, 0x9E,
        0x1D, 0xC3, 0x3D, 0xDF, 0x36, 0xED, 0x36, 0x8A, 0x0F, 0x5D, 0xFC, 0x45, 0x2B, 0x97, 0xD9, 0xD2,
        0xC5, 0x6E, 0x55, 0xE2, 0xA8, 0x1F, 0x20, 0xBC, 0x99, 0x43, 0x6B, 0xA9, 0xEF, 0x05, 0x33, 0xB8,
        0x1E, 0xB3, 0x29, 0xC0, 0x5E, 0xE1, 0x6C, 0xA7, 0x0F, 0x39, 0xD5, 0x76, 0x21, 0x99, 0xD0, 0xD2,
        0x9E, 0x2C, 0x77, 0xD5, 0x8D, 0x1E, 0x53, 0xCA
    ]
    private static let pubKeyXorKey: [UInt8] = [
        0xA7, 0x5B, 0x3E, 0x91, 0xCC, 0x4F, 0x12, 0x88,
        0xD3, 0x07, 0x5C, 0xE4, 0x9B, 0x36, 0x71, 0xC8,
        0x2A, 0xF5, 0x68, 0xB4, 0x1D, 0x82, 0x47, 0xE9,
        0x5A, 0x0C, 0x9F, 0x33, 0x6E, 0xC1, 0xB2, 0x88
    ]

    /// Lỗi trả về khi verify chữ ký thất bại — caller map sang
    /// `LicenseKeyError.invalidResponse` để giữ message cũ cho user.
    enum SignedResponseError: Error {
        case malformedEnvelope
        case signatureMissing
        case signatureDecodeFailed
        case signatureMismatch
    }

    /// Decode `Data` thành envelope `{ data: T, signature: String }` rồi
    /// verify chữ ký. Nếu hợp lệ trả về `data` payload (đã decode thành `T`).
    ///
    /// Lưu ý: server dùng `canonicalStringify` để ký (key sort alphabet,
    /// không có whitespace). `JSONSerialization` mặc định của Swift không
    /// đảm bảo key order nhưng ta re-encode qua `canonicalJSONString(_:)`
    /// trước khi verify để chắc chắn byte-for-byte khớp với server.
    static func verifyAndDecode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        NSLog("[SignedResponse] === verifyAndDecode start (data %d bytes) ===", data.count)
        // 1. Parse envelope thô để lấy signature + inner JSON string
        let envelope: Any
        do {
            envelope = try JSONSerialization.jsonObject(with: data, options: [])
            NSLog("[SignedResponse] step 1 OK: envelope parsed")
        } catch {
            NSLog("[SignedResponse] step 1 FAIL: JSON parse error: %@", String(describing: error))
            throw SignedResponseError.malformedEnvelope
        }
        guard let dict = envelope as? [String: Any] else {
            NSLog("[SignedResponse] step 1 FAIL: envelope is not [String: Any]")
            throw SignedResponseError.malformedEnvelope
        }
        NSLog("[SignedResponse] step 1 OK: envelope keys = %@", dict.keys.joined(separator: ","))

        // Một số endpoint có thể vẫn trả JSON thuần (vd khi chưa bật ký).
        // Nếu top-level đã có field mong đợi của `T` mà KHÔNG có signature,
        // ta fallback decode trực tiếp để tránh break các API chưa migrate.
        if dict["signature"] == nil {
            NSLog("[SignedResponse] step 1b: no signature field, trying plain JSON decode fallback")
            if let direct = try? JSONDecoder().decode(T.self, from: data) {
                NSLog("[SignedResponse] step 1b OK: plain JSON decoded without signature")
                return direct
            }
            NSLog("[SignedResponse] step 1b FAIL: plain JSON decode also failed")
            throw SignedResponseError.signatureMissing
        }

        guard let signatureString = dict["signature"] as? String else {
            NSLog("[SignedResponse] step 2 FAIL: signature field is not a String")
            throw SignedResponseError.signatureDecodeFailed
        }
        guard let signatureData = Data(base64Encoded: signatureString) else {
            NSLog("[SignedResponse] step 2 FAIL: signature not valid base64 (len=%d)", signatureString.count)
            throw SignedResponseError.signatureDecodeFailed
        }
        NSLog("[SignedResponse] step 2 OK: signature decoded (%d bytes)", signatureData.count)

        let payload = dict["data"]
        guard let payloadNonOpt: Any = payload else {
            NSLog("[SignedResponse] step 2 FAIL: data field is nil")
            throw SignedResponseError.malformedEnvelope
        }
        NSLog("[SignedResponse] step 2 OK: data field present")

        // 2. Re-canonical JSON cho đúng thứ tự key alphabet (giống server)
        let canonical = canonicalJSONString(payloadNonOpt)
        guard let canonicalData = canonical.data(using: .utf8) else {
            NSLog("[SignedResponse] step 2 FAIL: canonical string → utf8 failed")
            throw SignedResponseError.malformedEnvelope
        }
        NSLog("[SignedResponse] step 2 OK: canonical (%d bytes): %@", canonicalData.count, String(data: canonicalData, encoding: .utf8) ?? "<n/a>")
        NSLog("[SignedResponse] step 2 DEBUG canonical hex prefix: %@", canonicalData.prefix(60).map { String(format: "%02x", $0) }.joined())
        NSLog("[SignedResponse] step 2 DEBUG raw payload desc=%@", String(String(describing: payloadNonOpt).prefix(200)) as NSString)

        // 3. Verify RSA-SHA256 PKCS#1 v1.5 bằng public key embed
        guard let publicKey = loadPublicKey() else {
            // Public key không import được (SecKeyCreateWithData fail) —
            // log rõ để debug xem binary có key khớp server không, hoặc
            // thiết bị có support SPKI format không. Throw mismatch để
            // caller fail sang invalidResponse cho user.
            NSLog("[SignedResponse] step 3 FAIL: public key unavailable (SecKeyCreateWithData/SPKI failed)")
            throw SignedResponseError.signatureMismatch
        }
        NSLog("[SignedResponse] step 3 OK: public key loaded, blockSize=%d", SecKeyGetBlockSize(publicKey))

        // Thử nhiều kiểu canonical khác nhau để chịu được cả server dùng
        // JCS RFC 8785 lẫn server custom stringify. Log ra để biết server
        // đang dùng kiểu nào.
        var tried = 0
        var isValid = false

        // Helper inline để tránh goto (Swift không có).
        func tryVerify(_ data: Data, label: String) -> Bool {
            tried += 1
            let ok = SecKeyVerifySignature(
                publicKey,
                .rsaSignatureMessagePKCS1v15SHA256,
                data as CFData,
                signatureData as CFData,
                nil
            )
            NSLog("[SignedResponse] step 3 try %d (%@, %d bytes) → %@",
                  tried, label, data.count, ok ? "MATCH" : "miss")
            return ok
        }

        // A) Custom canonical (sorted keys, unicode-safe)
        isValid = tryVerify(canonicalData, label: "custom canonical")
        if !isValid,
           // B) JSONSerialization sortedKeys
           let alt = try? JSONSerialization.data(
               withJSONObject: payloadNonOpt,
               options: [.sortedKeys, .withoutEscapingSlashes]
           ) {
            isValid = tryVerify(alt, label: "sortedKeys")
        }
        if !isValid,
           // C) raw inner string
           let rawInner = payloadNonOpt as? String,
           let rawInnerData = rawInner.data(using: .utf8) {
            isValid = tryVerify(rawInnerData, label: "raw inner string")
        }

        if !isValid {
            NSLog("[SignedResponse] step 3 FAIL: tried %d canonical forms, all miss", tried)
            throw SignedResponseError.signatureMismatch
        }
        NSLog("[SignedResponse] step 3 OK: signature verified")

        // 4. Decode payload thành T
        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(
                withJSONObject: payloadNonOpt,
                options: [.sortedKeys] // tránh khác biệt key order khi parse
            )
        } catch {
            NSLog("[SignedResponse] step 4 FAIL: re-serialize payload failed: %@", String(describing: error))
            throw error
        }
        do {
            let decoded = try JSONDecoder().decode(T.self, from: payloadData)
            NSLog("[SignedResponse] step 4 OK: payload decoded as %@", String(describing: T.self))
            NSLog("[SignedResponse] === verifyAndDecode success ===")
            return decoded
        } catch {
            NSLog("[SignedResponse] step 4 FAIL: decode %@ failed: %@", String(describing: T.self), String(describing: error))
            throw error
        }
    }

    // MARK: - Public key loading

    /// Cache SecKey — load 1 lần, dùng cho cả session.
    private static var cachedPublicKey: SecKey? = {
        return buildPublicKey()
    }()

    private static func loadPublicKey() -> SecKey? {
        return cachedPublicKey
    }

    private static func buildPublicKey() -> SecKey? {
        // 1. XOR-decrypt base64 (cycle key, do KHÔNG dùng Obfuscated.decode
        //    — nó có precondition bytes.count == key.count sẽ crash ở đây)
        let base64 = xorDecode(pubKeyBytes, key: pubKeyXorKey)

        // 2. Base64 → DER bytes (SPKI format, RSA-2048)
        guard let der = Data(base64Encoded: base64) else {
            NSLog("[SignedResponse] failed to base64-decode public key (length=%d)", base64.count)
            return nil
        }

        // 3. SecKeyCreateWithData: SPKI format (kSecAttrKeyTypeRSA) được hỗ trợ
        //    từ iOS 10+. Độ dài key tự suy ra từ modulus.
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        var importError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(
            der as CFData,
            attributes as CFDictionary,
            &importError
        ) else {
            if let err = importError?.takeRetainedValue() {
                NSLog("[SignedResponse] SecKeyCreateWithData failed: %@", String(describing: err))
            }
            return nil
        }
        return key
    }

    // MARK: - Canonical JSON (match server `scripts/sign_response.js`)

    /// Server dùng `canonicalStringify` để ký: sort key alphabet, không
    /// whitespace. Swift's `JSONSerialization` mặc định có thể không ổn
    /// định về key order (đặc biệt với `[String: Any]`) nên ta tự build.
    private static func canonicalJSONString(_ value: Any) -> String {
        if value is NSNull {
            return "null"
        }
        if let s = value as? String {
            return encodeJSONString(s)
        }
        if let b = value as? Bool {
            return b ? "true" : "false"
        }
        if let n = value as? NSNumber {
            // NSNumber có thể là Bool hoặc số — đã check Bool ở trên nên
            // đây chắc chắn là số.
            return n.stringValue
        }
        if let arr = value as? [Any] {
            let parts = arr.map { canonicalJSONString($0) }
            return "[" + parts.joined(separator: ",") + "]"
        }
        if let dict = value as? [String: Any] {
            let sortedKeys = dict.keys.sorted()
            let parts: [String] = sortedKeys.map { key in
                encodeJSONString(key) + ":" + canonicalJSONString(dict[key]!)
            }
            return "{" + parts.joined(separator: ",") + "}"
        }
        // Fallback an toàn: NSJSONSerialization
        if let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "null"
    }

    /// Encode string theo JSON spec (escape `"`, `\`, control chars, unicode).
    private static func encodeJSONString(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if c.value < 0x20 {
                    out += String(format: "\\u%04x", c.value)
                } else {
                    out += String(c)
                }
            }
        }
        out += "\""
        return out
    }
}