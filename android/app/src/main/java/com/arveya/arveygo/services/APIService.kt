package com.arveya.arveygo.services

import android.util.Log
import com.arveya.arveygo.models.AppUser
import com.arveya.arveygo.models.WSConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.net.CookieManager
import java.net.CookiePolicy

/**
 * API Service — handles communication with the Laravel backend.
 * Laravel uses session/cookie-based auth, so we maintain cookies via CookieManager.
 */
object APIService {
    private const val TAG = "API"
    private val baseURL = AppConfig.API_BASE_URL

    private val cookieManager = CookieManager().apply {
        setCookiePolicy(CookiePolicy.ACCEPT_ALL)
    }

    private val client = OkHttpClient.Builder()
        .cookieJar(JavaNetCookieJar(cookieManager))
        .followRedirects(true)
        .build()

    // MARK: - CSRF Token
    suspend fun fetchCSRFToken(): String = withContext(Dispatchers.IO) {
        // GET the login page to obtain a session cookie + CSRF _token
        try {
            val request = Request.Builder()
                .url("$baseURL/login")
                .get()
                .addHeader("Accept", "text/html")
                .build()
            client.newCall(request).execute().use { response ->
                val body = response.body?.string() ?: ""

                // Parse _token from: <input type="hidden" name="_token" value="...">
                val hiddenRegex = """name="_token"\s+value="([^"]+)"""".toRegex()
                hiddenRegex.find(body)?.groupValues?.get(1)?.let { return@withContext it }

                // Also try reversed attribute order: value="..." name="_token"
                val reversedRegex = """value="([^"]+)"\s+name="_token"""".toRegex()
                reversedRegex.find(body)?.groupValues?.get(1)?.let { return@withContext it }

                // Also try meta tag: <meta name="csrf-token" content="...">
                val metaRegex = """<meta\s+name="csrf-token"\s+content="([^"]+)"""".toRegex()
                metaRegex.find(body)?.groupValues?.get(1)?.let { return@withContext it }

                // Last resort: XSRF-TOKEN cookie (if set by middleware)
                extractXSRFToken()?.let { return@withContext it }

                Log.e(TAG, "No CSRF token found in login page (${body.length} chars)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "CSRF fetch failed: ${e.localizedMessage}")
        }

        throw APIException.CSRFFailed
    }

    private fun extractXSRFToken(): String? {
        val cookies = cookieManager.cookieStore.cookies
        return cookies.firstOrNull { it.name == "XSRF-TOKEN" }
            ?.value
            ?.let { java.net.URLDecoder.decode(it, "UTF-8") }
    }

    // MARK: - Login
    data class LoginResponse(val user: AppUser, val wsConfig: WSConfig?)

    suspend fun login(email: String, password: String): LoginResponse = withContext(Dispatchers.IO) {
        // Step 1: Get CSRF token (also establishes session cookie)
        val csrfToken = fetchCSRFToken()

        // Step 2: POST login as form-encoded (Laravel web route expects this)
        val formBody = FormBody.Builder()
            .add("_token", csrfToken)
            .add("email", email)
            .add("password", password)
            .build()

        val request = Request.Builder()
            .url("$baseURL/login")
            .post(formBody)
            .addHeader("Accept", "application/json")
            .addHeader("Referer", "$baseURL/login")
            .addHeader("Origin", baseURL)
            .build()

        // Don't follow redirect — we just need the session cookie established
        val noRedirectClient = client.newBuilder().followRedirects(false).build()
        val response = noRedirectClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""

        when (response.code) {
            422 -> {
                val errJson = try { JSONObject(responseBody) } catch (_: Exception) { null }
                val errors = errJson?.optJSONObject("errors")
                val msg = errors?.keys()?.asSequence()?.firstOrNull()?.let {
                    errors.optJSONArray(it)?.optString(0)
                } ?: "E-posta veya şifre hatalı"
                throw APIException.HttpError(422, msg)
            }
            401, 403 -> throw APIException.Unauthorized
            302, 301 -> {
                // Redirect means success (Laravel redirects to /dashboard after login)
                val location = response.header("Location") ?: ""
                if (location.contains("login")) {
                    // Redirected back to login → credentials are wrong
                    throw APIException.HttpError(422, "E-posta veya şifre hatalı")
                }
                // Follow the redirect to establish the session fully
                val followReq = Request.Builder().url(location).get()
                    .addHeader("Accept", "text/html").build()
                client.newCall(followReq).execute().close()
            }
            in 200..399 -> { /* success */ }
            else -> throw APIException.HttpError(response.code, null)
        }

        // Step 3: Fetch bootstrap data (now we have a valid session)
        val (user, wsConfig) = fetchBootstrapData()
        return@withContext LoginResponse(user, wsConfig)
    }

    // MARK: - Bootstrap Data
    suspend fun fetchBootstrapData(): Pair<AppUser, WSConfig?> = withContext(Dispatchers.IO) {
        val requestBuilder = Request.Builder()
            .url("$baseURL/api/livemap-bootstrap")
            .get()
            .addHeader("Accept", "application/json")

        extractXSRFToken()?.let {
            requestBuilder.addHeader("X-XSRF-TOKEN", it)
        }

        val response = client.newCall(requestBuilder.build()).execute()
        val body = response.body?.string() ?: ""

        when (response.code) {
            401, 403 -> throw APIException.Unauthorized
            in 200..299 -> { /* ok */ }
            else -> throw APIException.HttpError(response.code, null)
        }

        val json = try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }

        val user = parseUser(json)
        var wsConfig: WSConfig? = null

        val wsJson = json.optJSONObject("socket_config") ?: json.optJSONObject("liveMapSocketConfig")
        if (wsJson != null) {
            val wsURL = wsJson.optString("url", "")
            val wsToken = wsJson.optString("token", "")
            val pingInterval = wsJson.optInt("ping_interval", 30)
            if (wsURL.isNotEmpty() && wsToken.isNotEmpty()) {
                wsConfig = WSConfig(wsURL, wsToken, pingInterval)
            }
        }

        return@withContext Pair(user, wsConfig)
    }

    private fun parseUser(json: JSONObject): AppUser {
        val userJson = json.optJSONObject("user") ?: json
        val id = "${userJson.opt("id") ?: "0"}"
        val name = userJson.optString("name", "Kullanıcı")
        val email = userJson.optString("email", "")
        val role = userJson.optString("role_label", userJson.optString("role", ""))
        val roleKey = userJson.optString("role_key", userJson.optString("role", ""))
        val companyId = userJson.optInt("company_id", 1)

        return AppUser(
            id = id, name = name, email = email,
            avatar = name.take(1).uppercase(),
            role = role, roleKey = roleKey, companyId = companyId
        )
    }

    // MARK: - Logout
    suspend fun logout() = withContext(Dispatchers.IO) {
        try {
            val requestBuilder = Request.Builder()
                .url("$baseURL/logout")
                .post("".toRequestBody())
                .addHeader("Accept", "application/json")

            extractXSRFToken()?.let {
                requestBuilder.addHeader("X-XSRF-TOKEN", it)
            }

            client.newCall(requestBuilder.build()).execute()
        } catch (_: Exception) {}

        cookieManager.cookieStore.removeAll()
    }
}

// MARK: - API Exceptions
sealed class APIException(message: String) : Exception(message) {
    data object InvalidURL : APIException("Geçersiz URL")
    data class HttpError(val code: Int, val msg: String?) : APIException("HTTP $code: ${msg ?: "Bilinmeyen hata"}")
    data class DecodingError(val msg: String) : APIException("Veri hatası: $msg")
    data class NetworkError(val reason: Throwable) : APIException(reason.localizedMessage ?: "Ağ hatası")
    data object Unauthorized : APIException("Oturum süresi doldu")
    data object CSRFFailed : APIException("CSRF token alınamadı")
}

/** OkHttp CookieJar backed by java.net.CookieManager */
private class JavaNetCookieJar(private val cookieManager: CookieManager) : CookieJar {
    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        val uri = url.toUri()
        cookies.forEach { cookie ->
            cookieManager.cookieStore.add(uri, java.net.HttpCookie(cookie.name, cookie.value).apply {
                domain = cookie.domain
                path = cookie.path
                secure = cookie.secure
                maxAge = if (cookie.expiresAt > System.currentTimeMillis()) {
                    ((cookie.expiresAt - System.currentTimeMillis()) / 1000)
                } else -1
            })
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val uri = url.toUri()
        return cookieManager.cookieStore.get(uri).mapNotNull { httpCookie ->
            Cookie.Builder()
                .name(httpCookie.name)
                .value(httpCookie.value)
                .domain(httpCookie.domain ?: url.host)
                .path(httpCookie.path ?: "/")
                .apply { if (httpCookie.secure) secure() }
                .build()
        }
    }
}
