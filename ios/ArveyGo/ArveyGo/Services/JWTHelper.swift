import Foundation
import CryptoKit

// MARK: - JWT Helper (HS256)
/// Generates HS-256 signed JWT tokens matching AtsJwtService on the Laravel backend.
/// Uses only Apple CryptoKit — no third-party dependencies.
enum JWTHelper {

    // MARK: - Public

    /// Issue a live-map WebSocket token.
    /// - Parameters:
    ///   - sub: User identifier (user ID as string, or email).
    ///   - companyId: The company whose vehicles should be streamed.
    ///   - secret: Hex-encoded HMAC secret (defaults to `AppConfig.wsJWTSecret`).
    ///   - ttl: Token lifetime in seconds (defaults to `AppConfig.wsJWTTTL`).
    /// - Returns: A compact JWT string (`header.payload.signature`).
    static func issueLiveMapToken(
        sub: String,
        companyId: Int,
        secret: String = AppConfig.wsJWTSecret,
        ttl: Int = AppConfig.wsJWTTTL
    ) -> String {
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "sub": sub,
            "company_id": companyId,
            "exp": now + ttl
        ]
        return sign(payload: payload, secret: secret)
    }

    // MARK: - Internal

    /// Create a signed JWT from an arbitrary payload dictionary.
    private static func sign(payload: [String: Any], secret: String) -> String {
        // Header — always HS256
        let header: [String: String] = [
            "alg": "HS256",
            "typ": "JWT"
        ]

        let headerB64 = base64url(jsonEncode(header))
        let payloadB64 = base64url(jsonEncode(payload))

        let signingInput = "\(headerB64).\(payloadB64)"

        // HMAC-SHA256
        let keyData = hexStringToData(secret)
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8),
            using: key
        )
        let signatureB64 = base64url(Data(signature))

        return "\(signingInput).\(signatureB64)"
    }

    // MARK: - Helpers

    /// JSON-encode a dictionary to `Data`.
    private static func jsonEncode(_ dict: [String: Any]) -> Data {
        // Use sorted keys for deterministic output
        let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return data ?? Data()
    }

    /// Standard Base64 → Base64-URL (no padding).
    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Convert a hex-encoded string to raw `Data`.
    private static func hexStringToData(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let byteString = hex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
}
