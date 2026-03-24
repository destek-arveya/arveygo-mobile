package com.arveya.arveygo.services

import android.util.Base64
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * JWT Helper (HS256) — matches iOS JWTHelper.swift exactly.
 *
 * CRITICAL: The WS server validates the JWT signature byte-for-byte.
 * The JSON field order in the payload MUST exactly match the PHP backend:
 *   Header:  {"alg":"HS256","typ":"JWT"}
 *   Payload: {"sub":"...","company_id":...,"exp":...}
 *
 * PHP's json_encode preserves array insertion order: sub → company_id → exp.
 * Using JSONObject would sort keys alphabetically → different signature → auth failure.
 * We use raw string concatenation instead.
 *
 * PHP uses the secret as a raw UTF-8 string (NOT hex-decoded).
 * We must do the same: secret.toByteArray(Charsets.UTF_8).
 */
object JWTHelper {

    /**
     * Issue a live-map WebSocket JWT token.
     *
     * @param sub        User identifier (user ID as string, or email)
     * @param companyId  The company whose vehicles should be streamed
     * @param secret     HMAC secret (defaults to AppConfig.WS_JWT_SECRET)
     * @param ttl        Token lifetime in seconds (defaults to AppConfig.WS_JWT_TTL)
     * @return           Compact JWT string: header.payload.signature
     */
    fun issueLiveMapToken(
        sub: String,
        companyId: Int,
        secret: String = AppConfig.WS_JWT_SECRET,
        ttl: Int = AppConfig.WS_JWT_TTL
    ): String {
        val now = (System.currentTimeMillis() / 1000).toInt()
        val exp = now + ttl

        // Header JSON — must match PHP: {"alg":"HS256","typ":"JWT"}
        val headerJSON = """{"alg":"HS256","typ":"JWT"}"""

        // Payload JSON — field order MUST match Laravel's AtsJwtService:
        //   sub (string) → company_id (int) → exp (int)
        val payloadJSON = """{"sub":"$sub","company_id":$companyId,"exp":$exp}"""

        val headerB64 = base64url(headerJSON.toByteArray(Charsets.UTF_8))
        val payloadB64 = base64url(payloadJSON.toByteArray(Charsets.UTF_8))

        val signingInput = "$headerB64.$payloadB64"

        // HMAC-SHA256
        // IMPORTANT: PHP's hash_hmac uses the secret as a raw UTF-8 string,
        // NOT as hex-decoded bytes. We must do the same.
        val keyBytes = secret.toByteArray(Charsets.UTF_8)
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(keyBytes, "HmacSHA256"))
        val signature = mac.doFinal(signingInput.toByteArray(Charsets.UTF_8))
        val signatureB64 = base64url(signature)

        return "$signingInput.$signatureB64"
    }

    /**
     * Standard Base64 → Base64-URL (no padding).
     */
    private fun base64url(data: ByteArray): String {
        return Base64.encodeToString(data, Base64.NO_WRAP or Base64.NO_PADDING)
            .replace('+', '-')
            .replace('/', '_')
    }
}
