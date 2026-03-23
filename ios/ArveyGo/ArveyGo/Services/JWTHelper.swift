import Foundation
import CryptoKit

// MARK: - JWT Helper (HS256)
/// Generates HS-256 signed JWT tokens matching AtsJwtService on the Laravel backend.
/// Uses only Apple CryptoKit — no third-party dependencies.
///
/// CRITICAL: The WS server validates the JWT signature byte-for-byte.
/// The JSON field order in the payload MUST exactly match the PHP backend:
///   Header:  {"alg":"HS256","typ":"JWT"}
///   Payload: {"sub":"...","company_id":...,"exp":...}
/// Using JSONSerialization with .sortedKeys would produce alphabetical order
/// (company_id, exp, sub) which generates a different signature → auth failure.
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
        let exp = now + ttl

        // Header JSON — must match PHP: {"alg":"HS256","typ":"JWT"}
        let headerJSON = #"{"alg":"HS256","typ":"JWT"}"#

        // Payload JSON — field order MUST match Laravel's AtsJwtService:
        //   sub (string) → company_id (int) → exp (int)
        // PHP's json_encode preserves array insertion order.
        let payloadJSON = #"{"sub":"\#(sub)","company_id":\#(companyId),"exp":\#(exp)}"#

        let headerB64 = base64url(Data(headerJSON.utf8))
        let payloadB64 = base64url(Data(payloadJSON.utf8))

        let signingInput = "\(headerB64).\(payloadB64)"

        // HMAC-SHA256
        // IMPORTANT: PHP's hash_hmac uses the secret as a raw UTF-8 string,
        // NOT as hex-decoded bytes. We must do the same.
        let keyData = Data(secret.utf8)
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8),
            using: key
        )
        let signatureB64 = base64url(Data(signature))

        return "\(signingInput).\(signatureB64)"
    }

    // MARK: - Helpers

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
