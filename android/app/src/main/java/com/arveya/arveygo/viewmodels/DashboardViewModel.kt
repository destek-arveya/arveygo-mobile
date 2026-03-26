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

    private val _alerts = MutableStateFlow<List<FleetAlert>>(emptyList())
    val alerts: StateFlow<List<FleetAlert>> = _alerts

    private val _selectedPeriod = MutableStateFlow("today")
    val selectedPeriod: StateFlow<String> = _selectedPeriod

    val totalVehicles: Int get() = _vehicles.value.size
    val onlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.ONLINE }
    val offlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.OFFLINE }
    val idleCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IDLE }
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
            loadDriversFromAPI()
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
        loadDriversFromAPI()
        loadDummyAlerts()
    }

    private fun subscribeToWebSocket() {
        // Single source of truth: observe vehicle list from WebSocketManager
        viewModelScope.launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    _vehicles.value = list
                }
            }
        }
        // Fallback: load dummy vehicle data after 3 seconds if no WS data
        viewModelScope.launch {
            delay(3000)
            if (_vehicles.value.isEmpty()) {
                loadDummyVehicles()
            }
        }
    }

    private fun loadDriversFromAPI() {
        viewModelScope.launch {
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
        }
    }

    private fun loadDummyAlerts() {
        _alerts.value = listOf(
            FleetAlert("1","Hız İhlali","34 ABC 123 — 142 km/h, E-5 Karayolu","3 dk",AlertSeverity.RED),
            FleetAlert("2","Geofence Çıkış","35 DEF 456 — İzmir bölge dışına çıktı","18 dk",AlertSeverity.AMBER),
            FleetAlert("3","Bakım Hatırlatma","07 MNO 987 — Yağ değişim zamanı","1 sa",AlertSeverity.BLUE),
            FleetAlert("4","Seyahat Tamamlandı","41 JKL 654 — Kocaeli → İstanbul","2 sa",AlertSeverity.GREEN),
            FleetAlert("5","Ani Fren","34 PRS 111 — Kadıköy civarı","35 dk",AlertSeverity.AMBER),
            FleetAlert("6","Motor Arızası","06 TUV 222 — Check Engine uyarısı","4 sa",AlertSeverity.RED),
        )
    }

    private fun loadDummyVehicles() {
        _vehicles.value = listOf(
            Vehicle("1","34 ABC 123","Ford Transit",VehicleStatus.ONLINE,true,48320,312,"Ahmet Yılmaz","İstanbul",41.0082,28.9784),
            Vehicle("2","06 XYZ 789","Mercedes Sprinter",VehicleStatus.OFFLINE,false,92100,0,"Mehmet Demir","Ankara",39.9334,32.8597),
            Vehicle("3","35 DEF 456","Renault Master",VehicleStatus.ONLINE,true,31540,187,"Ayşe Kaya","İzmir",38.4192,27.1287),
            Vehicle("4","16 GHI 321","Volkswagen Crafter",VehicleStatus.IDLE,false,67890,0,"Can Öztürk","Bursa",40.1885,29.0610),
            Vehicle("5","41 JKL 654","Fiat Ducato",VehicleStatus.ONLINE,true,22430,95,"Zeynep Şahin","Kocaeli",40.7654,29.9408),
            Vehicle("6","07 MNO 987","Peugeot Boxer",VehicleStatus.OFFLINE,false,55670,0,"Ali Çelik","Antalya",36.8969,30.7133),
            Vehicle("7","34 PRS 111","Iveco Daily",VehicleStatus.ONLINE,true,14220,241,"Fatma Arslan","İstanbul",41.0422,29.0083),
            Vehicle("8","06 TUV 222","Ford Transit Custom",VehicleStatus.IDLE,false,38900,0,"Hasan Koç","Ankara",39.9208,32.8541),
        )
    }
}
