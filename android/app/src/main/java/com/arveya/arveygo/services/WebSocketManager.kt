package com.arveya.arveygo.services

import android.util.Log
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlin.math.min
import kotlin.math.pow

// MARK: - WebSocket Connection Status
sealed class WSConnectionStatus {
    data object Idle : WSConnectionStatus()
    data object Connecting : WSConnectionStatus()
    data object Connected : WSConnectionStatus()
    data class Reconnecting(val attempt: Int) : WSConnectionStatus()
    data class Error(val message: String) : WSConnectionStatus()
    data object Disconnected : WSConnectionStatus()

    val label: String
        get() = when (this) {
            is Idle -> "Bağlantı bekleniyor"
            is Connecting -> "Bağlanıyor…"
            is Connected -> "Canlı"
            is Reconnecting -> "Yeniden bağlanıyor (${attempt})…"
            is Error -> "Hata: $message"
            is Disconnected -> "Bağlantı kesildi"
        }

    val colorName: String
        get() = when (this) {
            is Connected -> "green"
            is Connecting, is Reconnecting -> "orange"
            is Error -> "red"
            else -> "gray"
        }

    val color: androidx.compose.ui.graphics.Color
        get() = when (this) {
            is Connected -> AppColors.Online
            is Connecting, is Reconnecting -> AppColors.Idle
            is Error -> AppColors.Offline
            else -> AppColors.TextMuted
        }
}

// MARK: - WebSocket Event
sealed class WSEvent {
    data class Snapshot(val vehicles: List<Vehicle>, val count: Int, val ts: Int) : WSEvent()
    data class Update(val vehicle: Vehicle, val ts: Int) : WSEvent()
    data class StatusChanged(val status: WSConnectionStatus) : WSEvent()
    data class Pong(val ts: Int) : WSEvent()
}

// MARK: - WebSocket Manager
/**
 * Manages a persistent WebSocket connection to the ATS vehicle tracking server.
 * Uses OkHttp WebSocket. Singleton — observable via StateFlow/SharedFlow.
 */
object WebSocketManager {
    private const val TAG = "WS"

    // Published state
    private val _status = MutableStateFlow<WSConnectionStatus>(WSConnectionStatus.Idle)
    val status: StateFlow<WSConnectionStatus> = _status

    private val _vehicles = MutableStateFlow<Map<String, Vehicle>>(emptyMap())
    val vehicles: StateFlow<Map<String, Vehicle>> = _vehicles

    private val _vehicleList = MutableStateFlow<List<Vehicle>>(emptyList())
    val vehicleList: StateFlow<List<Vehicle>> = _vehicleList

    private val _events = MutableSharedFlow<WSEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<WSEvent> = _events

    // Configuration
    private var wsURL: String = ""
    private var token: String = ""

    // Internal state
    private var webSocket: WebSocket? = null
    private var client: OkHttpClient? = null
    private var pingJob: Job? = null
    private var snapshotTimeoutJob: Job? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempt = 0
    private var manualClose = false
    private var authFailed = false
    private var awaitingSnapshot = false
    private var orderList = mutableListOf<String>()
    // Socket generation counter — prevents stale socket callbacks from triggering reconnect
    private var socketGeneration = 0
    // DNS fallback tracking
    private var useFallbackURL = false
    private var dnsFailCount = 0

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // MARK: - Public API

    fun connect(url: String, token: String) {
        val trimmedURL = url.trim()
        val trimmedToken = token.trim()

        if (trimmedURL.isEmpty() || trimmedToken.isEmpty()) {
            _status.value = WSConnectionStatus.Error("URL veya token eksik")
            return
        }

        // If already connected with same config, skip
        if (wsURL == trimmedURL && this.token == trimmedToken && webSocket != null) return

        wsURL = trimmedURL
        this.token = trimmedToken
        manualClose = false
        authFailed = false
        useFallbackURL = false
        dnsFailCount = 0

        openSocket(isReconnect = false)
    }

    fun connect(sub: String, companyId: Int) {
        val jwt = JWTHelper.issueLiveMapToken(sub = sub, companyId = companyId)
        connect(url = AppConfig.WS_URL, token = jwt)
    }

    fun disconnect() {
        manualClose = true
        clearAllTimers()
        closeSocket()
        _status.value = WSConnectionStatus.Disconnected
        _events.tryEmit(WSEvent.StatusChanged(WSConnectionStatus.Disconnected))
    }

    fun reconnect() {
        if (wsURL.isEmpty() || token.isEmpty()) {
            Log.d(TAG, "Reconnect skipped — no URL/token configured yet")
            return
        }
        manualClose = false
        authFailed = false
        clearAllTimers()
        closeSocket()
        openSocket(isReconnect = true)
    }

    // MARK: - Socket Lifecycle

    private fun openSocket(isReconnect: Boolean) {
        clearAllTimers()
        closeSocket()

        // Increment generation so stale socket callbacks are ignored
        socketGeneration++
        val myGeneration = socketGeneration

        // Use fallback IP-based URL if DNS has failed before
        val effectiveURL = if (useFallbackURL && AppConfig.WS_URL_FALLBACK.isNotEmpty()) {
            Log.d(TAG, "Using fallback URL due to DNS issues")
            AppConfig.WS_URL_FALLBACK
        } else {
            wsURL
        }

        // Build URL as raw string (never use Uri.parse which can mangle wss://)
        val separator = if (effectiveURL.contains("?")) "&" else "?"
        val fullURLString = "$effectiveURL${separator}token=$token"

        awaitingSnapshot = true
        _status.value = if (isReconnect) WSConnectionStatus.Reconnecting(reconnectAttempt) else WSConnectionStatus.Connecting
        _events.tryEmit(WSEvent.StatusChanged(_status.value))

        Log.d(TAG, "Connecting to: $fullURLString")

        // Use custom DNS resolver with fallback
        val dnsResolver = object : okhttp3.Dns {
            override fun lookup(hostname: String): List<java.net.InetAddress> {
                return try {
                    okhttp3.Dns.SYSTEM.lookup(hostname)
                } catch (e: java.net.UnknownHostException) {
                    Log.w(TAG, "System DNS failed for $hostname, trying InetAddress fallback")
                    try {
                        java.net.InetAddress.getAllByName(hostname).toList()
                    } catch (e2: Exception) {
                        Log.e(TAG, "All DNS resolution failed for $hostname")
                        throw e
                    }
                }
            }
        }

        client = OkHttpClient.Builder()
            .dns(dnsResolver)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.MINUTES) // Keep alive
            .writeTimeout(30, TimeUnit.SECONDS)
            .pingInterval(0, TimeUnit.SECONDS) // We handle pings manually
            .build()

        val request = Request.Builder()
            .url(fullURLString)
            .build()

        webSocket = client?.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "Socket opened (gen=$myGeneration)")
                if (myGeneration != socketGeneration) return
                scope.launch {
                    dnsFailCount = 0 // Reset on success
                    startPingLoop()
                    armSnapshotTimeout()
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (myGeneration != socketGeneration) return
                scope.launch { handleMessage(text) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Socket error: ${t.localizedMessage}")
                if (myGeneration != socketGeneration) return
                scope.launch {
                    // If DNS resolution failed, switch to fallback URL
                    if (t is java.net.UnknownHostException) {
                        dnsFailCount++
                        if (!useFallbackURL && AppConfig.WS_URL_FALLBACK.isNotEmpty()) {
                            Log.w(TAG, "DNS resolution failed — switching to fallback URL: ${AppConfig.WS_URL_FALLBACK}")
                            useFallbackURL = true
                            openSocket(isReconnect = true)
                            return@launch
                        }
                    }
                    if (!manualClose) handleDisconnect()
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Socket closing: $code $reason")
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Socket closed: $code $reason (gen=$myGeneration, current=$socketGeneration)")
                if (myGeneration != socketGeneration) return
                scope.launch {
                    if (!manualClose) handleDisconnect()
                }
            }
        })
    }

    private fun closeSocket() {
        try {
            webSocket?.close(1000, "Going away")
        } catch (_: Exception) {}
        webSocket = null
        client?.dispatcher?.executorService?.shutdown()
        client = null
    }

    // MARK: - Message Handling

    private fun handleMessage(text: String) {
        val json = try { JSONObject(text) } catch (_: Exception) { return }
        val type = json.optString("type", "")

        when (type) {
            "snapshot" -> {
                Log.d(TAG, "Received snapshot")
                handleSnapshot(json)
            }
            "update" -> handleUpdate(json)
            "pong" -> {
                val ts = json.optInt("ts", 0)
                _events.tryEmit(WSEvent.Pong(ts))
            }
            "auth_error" -> {
                authFailed = true
                val msg = json.optString("message", "Yetkilendirme hatası")
                Log.e(TAG, "Auth error: $msg")
                _status.value = WSConnectionStatus.Error(msg)
                _events.tryEmit(WSEvent.StatusChanged(_status.value))
                closeSocket()
            }
            "error" -> {
                val msg = json.optString("message", "Sunucu hatası")
                Log.e(TAG, "Server error: $msg")
                _status.value = WSConnectionStatus.Error(msg)
                _events.tryEmit(WSEvent.StatusChanged(_status.value))
                closeSocket()
                scheduleReconnect()
            }
            else -> Log.d(TAG, "Unknown message type: $type")
        }
    }

    private fun handleSnapshot(json: JSONObject) {
        awaitingSnapshot = false
        clearSnapshotTimeout()
        reconnectAttempt = 0

        val vehiclesArray = json.optJSONArray("vehicles") ?: run {
            Log.d(TAG, "Snapshot has no vehicles array")
            return
        }
        val ts = json.optInt("ts", 0)
        Log.d(TAG, "Snapshot: ${vehiclesArray.length()} vehicles, ts=$ts")

        val newVehicles = mutableMapOf<String, Vehicle>()
        val newOrder = mutableListOf<String>()

        for (i in 0 until vehiclesArray.length()) {
            val vehicleJson = vehiclesArray.optJSONObject(i) ?: continue
            var vehicle = Vehicle.fromWSPayload(vehicleJson) ?: continue

            // Merge with existing data
            _vehicles.value[vehicle.imei]?.let { existing ->
                vehicle = existing.mergeUpdate(vehicle)
            }
            newVehicles[vehicle.imei] = vehicle
            newOrder.add(vehicle.imei)
        }

        _vehicles.value = newVehicles
        orderList = newOrder
        rebuildVehicleList()

        _status.value = WSConnectionStatus.Connected
        _events.tryEmit(WSEvent.StatusChanged(WSConnectionStatus.Connected))
        _events.tryEmit(WSEvent.Snapshot(_vehicleList.value, _vehicleList.value.size, ts))
    }

    private fun handleUpdate(json: JSONObject) {
        val vehicleJson = json.optJSONObject("vehicle") ?: json
        val ts = json.optInt("ts", 0)

        val patch = Vehicle.fromWSPayload(vehicleJson) ?: return

        awaitingSnapshot = false
        clearSnapshotTimeout()

        val current = _vehicles.value.toMutableMap()
        val existing = current[patch.imei]
        if (existing != null) {
            current[patch.imei] = existing.mergeUpdate(patch)
        } else {
            current[patch.imei] = patch
            orderList.add(patch.imei)
        }
        _vehicles.value = current
        rebuildVehicleList()

        if (_status.value != WSConnectionStatus.Connected) {
            _status.value = WSConnectionStatus.Connected
            _events.tryEmit(WSEvent.StatusChanged(WSConnectionStatus.Connected))
        }

        current[patch.imei]?.let {
            _events.tryEmit(WSEvent.Update(it, ts))
        }
    }

    private fun rebuildVehicleList() {
        val current = _vehicles.value
        _vehicleList.value = orderList.mapNotNull { current[it] }
    }

    // MARK: - Disconnect & Reconnect

    private fun handleDisconnect() {
        clearPingLoop()
        clearSnapshotTimeout()

        if (authFailed) {
            _status.value = WSConnectionStatus.Error("Yetkilendirme hatası")
            _events.tryEmit(WSEvent.StatusChanged(_status.value))
            return
        }

        _status.value = WSConnectionStatus.Reconnecting(reconnectAttempt + 1)
        _events.tryEmit(WSEvent.StatusChanged(_status.value))
        scheduleReconnect()
    }

    private fun scheduleReconnect() {
        if (manualClose || authFailed || wsURL.isEmpty() || token.isEmpty()) return
        if (reconnectJob?.isActive == true) return

        reconnectAttempt++

        // Exponential backoff with jitter
        val base = min(AppConfig.WS_MAX_RECONNECT_DELAY.toDouble(), 2.0.pow(min(reconnectAttempt - 1, 5).toDouble()))
        val jitter = Math.random() * 0.75
        val delay = (base + jitter).toLong()

        _status.value = WSConnectionStatus.Reconnecting(reconnectAttempt)
        _events.tryEmit(WSEvent.StatusChanged(_status.value))

        reconnectJob = scope.launch {
            delay(delay * 1000)
            openSocket(isReconnect = true)
        }
    }

    // MARK: - Ping

    private fun startPingLoop() {
        clearPingLoop()
        pingJob = scope.launch {
            while (isActive) {
                delay(AppConfig.WS_PING_INTERVAL * 1000)
                sendPing()
            }
        }
    }

    private fun sendPing() {
        try {
            webSocket?.send("""{"type":"ping"}""")
        } catch (e: Exception) {
            Log.e(TAG, "Ping failed: ${e.localizedMessage}")
        }
    }

    // MARK: - Snapshot Timeout

    private fun armSnapshotTimeout() {
        clearSnapshotTimeout()
        snapshotTimeoutJob = scope.launch {
            delay(AppConfig.WS_SNAPSHOT_TIMEOUT * 1000)
            if (awaitingSnapshot) {
                _status.value = WSConnectionStatus.Error("Snapshot zaman aşımı")
                _events.tryEmit(WSEvent.StatusChanged(_status.value))
                closeSocket()
                scheduleReconnect()
            }
        }
    }

    // MARK: - Timer Cleanup

    private fun clearPingLoop() { pingJob?.cancel(); pingJob = null }
    private fun clearSnapshotTimeout() { snapshotTimeoutJob?.cancel(); snapshotTimeoutJob = null }
    private fun clearReconnect() { reconnectJob?.cancel(); reconnectJob = null }
    private fun clearAllTimers() { clearPingLoop(); clearSnapshotTimeout(); clearReconnect() }
}
