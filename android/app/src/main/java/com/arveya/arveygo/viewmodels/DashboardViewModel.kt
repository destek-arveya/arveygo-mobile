package com.arveya.arveygo.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.WSEvent
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
        loadDummyDriversAndAlerts()
    }

    private fun subscribeToWebSocket() {
        // Observe vehicle list from WebSocketManager
        viewModelScope.launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    _vehicles.value = list
                }
            }
        }
        // Also listen for individual events
        viewModelScope.launch {
            WebSocketManager.events.collect { event ->
                when (event) {
                    is WSEvent.Snapshot -> {
                        _vehicles.value = event.vehicles
                    }
                    is WSEvent.Update -> {
                        val current = _vehicles.value.toMutableList()
                        val idx = current.indexOfFirst { it.id == event.vehicle.id }
                        if (idx >= 0) current[idx] = event.vehicle
                        else current.add(event.vehicle)
                        _vehicles.value = current
                    }
                    else -> {}
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

    private fun loadDummyDriversAndAlerts() {
        _drivers.value = listOf(
            DriverScore("1","Ahmet Yılmaz","34 ABC 123",94,48320,AppColors.Navy),
            DriverScore("2","Zeynep Şahin","41 JKL 654",91,22430,AppColors.Indigo),
            DriverScore("3","Fatma Arslan","34 PRS 111",88,14220,AppColors.Online),
            DriverScore("4","Ayşe Kaya","35 DEF 456",82,31540,androidx.compose.ui.graphics.Color.Blue),
            DriverScore("5","Can Öztürk","16 GHI 321",76,67890,AppColors.Idle),
            DriverScore("6","Mehmet Demir","06 XYZ 789",71,92100,AppColors.Lavender),
            DriverScore("7","Ali Çelik","07 MNO 987",65,55670,AppColors.Offline),
            DriverScore("8","Hasan Koç","06 TUV 222",58,38900,androidx.compose.ui.graphics.Color.Gray),
        )
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
