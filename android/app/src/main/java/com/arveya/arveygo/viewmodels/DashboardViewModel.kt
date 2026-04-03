package com.arveya.arveygo.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Locale

class DashboardViewModel : ViewModel() {
    private val _vehicles = MutableStateFlow<List<Vehicle>>(emptyList())
    val vehicles: StateFlow<List<Vehicle>> = _vehicles

    private val _drivers = MutableStateFlow<List<DriverScore>>(emptyList())
    val drivers: StateFlow<List<DriverScore>> = _drivers

    private val _alerts = MutableStateFlow<List<AlarmEvent>>(emptyList())
    val alerts: StateFlow<List<AlarmEvent>> = _alerts
    private val _vehiclesErrorMessage = MutableStateFlow<String?>(null)
    val vehiclesErrorMessage: StateFlow<String?> = _vehiclesErrorMessage
    private val _alertsErrorMessage = MutableStateFlow<String?>(null)
    val alertsErrorMessage: StateFlow<String?> = _alertsErrorMessage

    private val _isLoadingDrivers = MutableStateFlow(false)
    val isLoadingDrivers: StateFlow<Boolean> = _isLoadingDrivers

    private val _isLoadingDailyKm = MutableStateFlow(true)
    val isLoadingDailyKm: StateFlow<Boolean> = _isLoadingDailyKm

    private val _isLoadingAlerts = MutableStateFlow(false)
    val isLoadingAlerts: StateFlow<Boolean> = _isLoadingAlerts

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _selectedPeriod = MutableStateFlow("today")
    val selectedPeriod: StateFlow<String> = _selectedPeriod

    val totalVehicles: Int get() = _vehicles.value.size
    val onlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IGNITION_ON }
    val offlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IGNITION_OFF || it.status == VehicleStatus.NO_DATA }
    val idleCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.SLEEPING }
    val kontakOnCount: Int get() = _vehicles.value.count { it.ignition }
    val kontakOffCount: Int get() = _vehicles.value.count { it.isOnline && !it.ignition }
    val bilgiYokCount: Int get() = _vehicles.value.count { !it.isOnline }
    val totalKm: Int get() = _vehicles.value.sumOf { it.totalKm }
    val todayKm: Int get() = _vehicles.value.sumOf { it.todayKm }
    val avgScore: Int get() {
        val d = _drivers.value
        return if (d.isEmpty()) 0 else d.sumOf { it.score } / d.size
    }

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing

    fun refreshData() {
        viewModelScope.launch {
            _isRefreshing.value = true
            WebSocketManager.reconnect()
            loadVehiclesFromAPI()
            loadDriversFromAPI()
            loadAlertsFromAPI()
            delay(2000)
            _isRefreshing.value = false
        }
    }

    fun getMetrics(): List<DashboardMetric> = listOf(
        DashboardMetric("Toplam Araç", "$totalVehicles", "car", AppColors.Navy.copy(alpha = 0.06f), AppColors.Navy, "", ChangeType.FLAT),
        DashboardMetric("Kontak Açık", "$kontakOnCount", "check_circle", AppColors.Online.copy(alpha = 0.08f), AppColors.Online, "", ChangeType.FLAT),
        DashboardMetric("Kontak Kapalı", "$kontakOffCount", "cancel", AppColors.Idle.copy(alpha = 0.08f), AppColors.Idle, "", ChangeType.FLAT),
        DashboardMetric("Bilgi Yok", "$bilgiYokCount", "pause_circle", AppColors.Offline.copy(alpha = 0.08f), AppColors.Offline, "", ChangeType.FLAT),
        DashboardMetric("Bugün Km", formatKm(todayKm), "road", AppColors.Indigo.copy(alpha = 0.08f), AppColors.Indigo, "", ChangeType.FLAT),
    )

    fun formatKm(km: Int): String = NumberFormat.getNumberInstance(Locale("tr", "TR")).format(km)

    fun setPeriod(period: String) { _selectedPeriod.value = period }

    init {
        subscribeToWebSocket()
        loadVehiclesFromAPI()
        loadDriversFromAPI()
        loadAlertsFromAPI()
    }

    private fun subscribeToWebSocket() {
        // Single source of truth: observe vehicle list from WebSocketManager
        viewModelScope.launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    _vehicles.value = list
                    _vehiclesErrorMessage.value = null
                    _isLoading.value = false
                    _isLoadingDailyKm.value = false
                }
            }
        }
    }

    private fun loadVehiclesFromAPI() {
        viewModelScope.launch {
            _isLoadingDailyKm.value = true
            _vehiclesErrorMessage.value = null
            try {
                val apiVehicles = APIService.fetchVehicles()
                // Merge API data into existing vehicle list, preserving WS live data
                val wsMap = _vehicles.value.associateBy { it.id }
                val merged = apiVehicles.map { apiV ->
                    val wsV = wsMap[apiV.id]
                    if (wsV != null) {
                        wsV.copy(
                            todayKm = if (apiV.todayKm > wsV.todayKm) apiV.todayKm else wsV.todayKm,
                            dailyKm = if (apiV.dailyKm > wsV.dailyKm) apiV.dailyKm else wsV.dailyKm,
                            lastPacketAt = apiV.lastPacketAt ?: wsV.lastPacketAt,
                            deviceTime = apiV.deviceTime ?: wsV.deviceTime
                        )
                    } else apiV
                }
                _vehicles.value = merged
                _vehiclesErrorMessage.value = null
                _isLoading.value = false
            } catch (e: Exception) {
                android.util.Log.e("DashboardVM", "fetchVehicles error", e)
                _vehiclesErrorMessage.value = e.localizedMessage ?: "Araç verileri alınamadı."
                _isLoading.value = false
            }
            _isLoadingDailyKm.value = false
        }
    }

    private fun loadDriversFromAPI() {
        viewModelScope.launch {
            _isLoadingDrivers.value = true
            try {
                val response = APIService.fetchDrivers()
                val avatarColors = listOf(
                    AppColors.Navy, AppColors.Indigo, AppColors.Online, androidx.compose.ui.graphics.Color.Blue,
                    AppColors.Idle, AppColors.Lavender, AppColors.Offline, androidx.compose.ui.graphics.Color.Gray,
                    androidx.compose.ui.graphics.Color(0xFF9C27B0), androidx.compose.ui.graphics.Color(0xFFFF9800),
                    androidx.compose.ui.graphics.Color(0xFF009688), androidx.compose.ui.graphics.Color(0xFFE91E63)
                )
                _drivers.value = response.drivers
                    .sortedByDescending { it.scoreGeneral }
                    .mapIndexed { index, driver ->
                        DriverScore(
                            id = driver.id,
                            name = driver.name,
                            plate = driver.vehicle.ifEmpty { driver.lastVehicle },
                            score = driver.scoreGeneral,
                            totalKm = driver.totalDistanceKm.toInt(),
                            color = avatarColors[index % avatarColors.size]
                        )
                    }
            } catch (e: Exception) {
                android.util.Log.e("DashboardVM", "fetchDrivers error", e)
            }
            _isLoadingDrivers.value = false
        }
    }

    private fun loadAlertsFromAPI() {
        viewModelScope.launch {
            _isLoadingAlerts.value = true
            try {
                val json = APIService.get("/api/mobile/alarms?per_page=5")
                val dataArr = json.optJSONArray("data")
                if (dataArr != null && dataArr.length() > 0) {
                    val alertList = mutableListOf<AlarmEvent>()
                    for (i in 0 until dataArr.length()) {
                        alertList.add(AlarmEvent.from(dataArr.getJSONObject(i), i))
                    }
                    _alerts.value = alertList
                    _alertsErrorMessage.value = null
                } else {
                    _alerts.value = emptyList()
                    _alertsErrorMessage.value = null
                }
            } catch (e: Exception) {
                android.util.Log.e("DashboardVM", "fetchAlarms error", e)
                _alerts.value = emptyList()
                _alertsErrorMessage.value = "Alarm verileri şu anda alınamıyor."
            }
            _isLoadingAlerts.value = false
        }
    }
}
