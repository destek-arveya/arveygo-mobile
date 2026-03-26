package com.arveya.arveygo.services

import android.content.Context
import android.util.Log
import com.arveya.arveygo.models.AppUser
import com.arveya.arveygo.models.WSConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

/**
 * API Service — handles communication with the Laravel backend.
 * Uses Bearer token auth: POST /api/mobile/auth/login → access_token
 */
object APIService {
    private const val TAG = "API"
    private val baseURL = AppConfig.API_BASE_URL

    private val client = OkHttpClient.Builder()
        .followRedirects(false)
        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    /// Current Bearer token — persisted in SharedPreferences
    var accessToken: String? = null
        private set

    // MARK: - Init from stored token
    fun initialize(context: Context) {
        accessToken = TokenStore.load(context)
        if (accessToken != null) {
            Log.d(TAG, "Restored saved token: ${accessToken!!.take(20)}...")
        }
    }

    val hasStoredToken: Boolean get() = accessToken != null

    fun clearToken(context: Context) {
        accessToken = null
        TokenStore.delete(context)
    }

    // MARK: - Login
    data class LoginResponse(val accessToken: String, val tokenType: String, val user: AppUser)

    suspend fun login(email: String, password: String, context: Context): LoginResponse = withContext(Dispatchers.IO) {
        val json = JSONObject().apply {
            put("email", email)
            put("password", password)
        }

        val requestBody = json.toString().toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$baseURL/api/mobile/auth/login")
            .post(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        val respJson = try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }

        when (response.code) {
            in 200..299 -> { /* success */ }
            401 -> throw APIException.HttpError(401, respJson.optString("message", "E-posta veya şifre hatalı"))
            422 -> {
                val errors = respJson.optJSONObject("errors")
                val msg = errors?.keys()?.asSequence()?.firstOrNull()?.let {
                    errors.optJSONArray(it)?.optString(0)
                } ?: respJson.optString("message", "E-posta veya şifre hatalı")
                throw APIException.HttpError(422, msg)
            }
            else -> throw APIException.HttpError(response.code, respJson.optString("message", null))
        }

        val token = respJson.optString("access_token", "")
        if (token.isEmpty()) throw APIException.DecodingError("access_token bulunamadı")

        val tokenType = respJson.optString("token_type", "bearer")
        val user = parseUser(respJson)

        // Persist token
        accessToken = token
        TokenStore.save(context, token)

        Log.d(TAG, "Login OK — token: ${token.take(20)}..., user: ${user.name}")
        return@withContext LoginResponse(token, tokenType, user)
    }

    // MARK: - Me (current user)
    suspend fun fetchMe(): AppUser = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$baseURL/api/mobile/auth/me")
            .get()
            .addHeader("Accept", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        validateResponse(response.code, body)

        val json = try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }

        return@withContext parseUser(json)
    }

    // MARK: - Refresh Token
    suspend fun refreshToken(context: Context): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$baseURL/api/mobile/auth/refresh")
            .post("".toRequestBody())
            .addHeader("Accept", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        validateResponse(response.code, body)

        val json = try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }

        val newToken = json.optString("access_token", "")
        if (newToken.isEmpty()) throw APIException.DecodingError("Yeni token alınamadı")

        accessToken = newToken
        TokenStore.save(context, newToken)
        Log.d(TAG, "Token refreshed")
        return@withContext newToken
    }

    // MARK: - Logout
    suspend fun logout(context: Context) = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url("$baseURL/api/mobile/auth/logout")
                .post("".toRequestBody())
                .addHeader("Accept", "application/json")
                .addHeader("Authorization", "Bearer $accessToken")
                .build()
            client.newCall(request).execute()
        } catch (_: Exception) {}

        accessToken = null
        TokenStore.delete(context)
        Log.d(TAG, "Logged out, token cleared")
    }

    // MARK: - Generic Authenticated GET
    suspend fun get(path: String): JSONObject = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$baseURL$path")
            .get()
            .addHeader("Accept", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        validateResponse(response.code, body)

        return@withContext try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }
    }

    // MARK: - Generic Authenticated POST
    suspend fun post(path: String, jsonBody: JSONObject? = null): JSONObject = withContext(Dispatchers.IO) {
        val requestBody = (jsonBody?.toString() ?: "").toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$baseURL$path")
            .post(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        validateResponse(response.code, body)

        return@withContext try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }
    }

    // MARK: - Generic Authenticated PUT
    suspend fun put(path: String, jsonBody: JSONObject): JSONObject = withContext(Dispatchers.IO) {
        val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$baseURL$path")
            .put(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .addHeader("Authorization", "Bearer $accessToken")
            .build()

        val response = try {
            client.newCall(request).execute()
        } catch (e: Exception) {
            throw APIException.NetworkError(e)
        }

        val body = response.body?.string() ?: ""
        validateResponse(response.code, body)

        return@withContext try { JSONObject(body) } catch (_: Exception) {
            throw APIException.DecodingError("JSON ayrıştırılamadı")
        }
    }

    // MARK: - Geofences
    suspend fun fetchGeofences(): List<com.arveya.arveygo.models.Geofence> = withContext(Dispatchers.IO) {
        val json = get("/api/mobile/geofences")
        val dataArray = json.optJSONArray("data") ?: return@withContext emptyList()
        (0 until dataArray.length()).map { i ->
            com.arveya.arveygo.models.Geofence.fromJson(dataArray.getJSONObject(i))
        }
    }

    // MARK: - Drivers
    suspend fun fetchDrivers(): com.arveya.arveygo.models.DriversResponse = withContext(Dispatchers.IO) {
        val json = get("/api/mobile/drivers")
        val driversArray = json.optJSONArray("drivers") ?: org.json.JSONArray()
        val statsJson = json.optJSONObject("stats") ?: org.json.JSONObject()
        val drivers = (0 until driversArray.length()).map { i ->
            com.arveya.arveygo.models.Driver.fromJson(driversArray.getJSONObject(i))
        }
        val stats = com.arveya.arveygo.models.DriverStats(
            total = statsJson.optInt("total", 0),
            active = statsJson.optInt("active", 0),
            tracked = statsJson.optInt("tracked", 0),
            good = statsJson.optInt("good", 0),
            mid = statsJson.optInt("mid", 0),
            low = statsJson.optInt("low", 0)
        )
        com.arveya.arveygo.models.DriversResponse(drivers, stats)
    }

    suspend fun fetchDriver(id: String): com.arveya.arveygo.models.Driver? = withContext(Dispatchers.IO) {
        val json = get("/api/mobile/drivers/$id")
        val data = json.optJSONObject("data") ?: return@withContext null
        com.arveya.arveygo.models.Driver.fromJson(data)
    }

    suspend fun createDriver(body: Map<String, Any>): com.arveya.arveygo.models.Driver? = withContext(Dispatchers.IO) {
        val json = post("/api/mobile/drivers", org.json.JSONObject(body))
        val data = json.optJSONObject("data") ?: return@withContext null
        com.arveya.arveygo.models.Driver.fromJson(data)
    }

    // MARK: - Helpers

    private fun validateResponse(code: Int, body: String) {
        when (code) {
            in 200..299 -> return
            401 -> {
                accessToken = null
                throw APIException.Unauthorized
            }
            422 -> {
                val json = try { JSONObject(body) } catch (_: Exception) { null }
                val errors = json?.optJSONObject("errors")
                val msg = errors?.keys()?.asSequence()?.firstOrNull()?.let {
                    errors.optJSONArray(it)?.optString(0)
                } ?: "Doğrulama hatası"
                throw APIException.HttpError(422, msg)
            }
            else -> {
                val json = try { JSONObject(body) } catch (_: Exception) { null }
                throw APIException.HttpError(code, json?.optString("message"))
            }
        }
    }

    private fun parseUser(json: JSONObject): AppUser {
        val u = json.optJSONObject("user") ?: json
        val id = "${u.opt("id") ?: "0"}"
        val name = u.optString("name", "Kullanıcı")
        val email = u.optString("email", "")
        val role = u.optString("role_label", u.optString("role", ""))
        val roleKey = u.optString("role_key", u.optString("role", ""))
        val companyId = u.optInt("company_id", 1)

        return AppUser(
            id = id, name = name, email = email,
            avatar = name.take(1).uppercase(),
            role = role, roleKey = roleKey, companyId = companyId
        )
    }
}

// MARK: - API Exceptions
sealed class APIException(message: String) : Exception(message) {
    data object InvalidURL : APIException("Geçersiz URL")
    data class HttpError(val code: Int, val msg: String?) : APIException(msg ?: "HTTP $code")
    data class DecodingError(val msg: String) : APIException("Veri hatası: $msg")
    data class NetworkError(val reason: Throwable) : APIException(reason.localizedMessage ?: "Ağ hatası")
    data object Unauthorized : APIException("Oturum süresi doldu. Lütfen tekrar giriş yapın.")
}

// MARK: - Token Store (SharedPreferences)
private object TokenStore {
    private const val PREFS_NAME = "arveygo_auth"
    private const val KEY_TOKEN = "access_token"

    fun save(context: Context, token: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TOKEN, token)
            .apply()
    }

    fun load(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
    }

    fun delete(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_TOKEN)
            .apply()
    }
}
