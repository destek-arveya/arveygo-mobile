package com.arveya.arveygo.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.models.VehicleStatus
import com.arveya.arveygo.services.WSConnectionStatus
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.services.WebSocketManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class LiveMapViewModel : ViewModel() {
    private val _vehicles = MutableStateFlow<List<Vehicle>>(emptyList())
    val vehicles: StateFlow<List<Vehicle>> = _vehicles

    /** Incremented every time vehicle data changes – used as LaunchedEffect key */
    private val _vehicleVersion = MutableStateFlow(0L)
    val vehicleVersion: StateFlow<Long> = _vehicleVersion

    private val _statusFilter = MutableStateFlow<VehicleStatus?>(null)
    val statusFilter: StateFlow<VehicleStatus?> = _statusFilter

    private val _searchText = MutableStateFlow("")
    val searchText: StateFlow<String> = _searchText

    private val _wsStatus = MutableStateFlow<WSConnectionStatus>(WSConnectionStatus.Idle)
    val wsStatus: StateFlow<WSConnectionStatus> = _wsStatus

    val onlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.ONLINE }
    val offlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.OFFLINE }
    val idleCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IDLE }

    fun filteredVehicles(): List<Vehicle> {
        var result = _vehicles.value
        _statusFilter.value?.let { filter -> result = result.filter { it.status == filter } }
        val q = _searchText.value.lowercase()
        if (q.isNotEmpty()) {
            result = result.filter {
                it.plate.lowercase().contains(q) || it.model.lowercase().contains(q) ||
                        it.driver.lowercase().contains(q) || it.imei.lowercase().contains(q)
            }
        }
        return result
    }

    fun setFilter(filter: VehicleStatus?) { _statusFilter.value = filter }
    fun setSearch(text: String) { _searchText.value = text }

    init {
        subscribeToWebSocket()
    }

    private fun subscribeToWebSocket() {
        viewModelScope.launch {
            WebSocketManager.vehicleList.collect { list ->
                if (list.isNotEmpty()) {
                    _vehicles.value = list
                    _vehicleVersion.value++
                }
            }
        }
        viewModelScope.launch {
            WebSocketManager.status.collect { _wsStatus.value = it }
        }
        viewModelScope.launch {
            WebSocketManager.events.collect { event ->
                when (event) {
                    is WSEvent.Snapshot -> {
                        _vehicles.value = event.vehicles
                        _vehicleVersion.value++
                    }
                    is WSEvent.Update -> {
                        val current = _vehicles.value.toMutableList()
                        val idx = current.indexOfFirst { it.id == event.vehicle.id }
                        if (idx >= 0) current[idx] = event.vehicle else current.add(event.vehicle)
                        _vehicles.value = current
                        _vehicleVersion.value++
                    }
                    is WSEvent.StatusChanged -> _wsStatus.value = event.status
                    is WSEvent.Pong -> {}
                }
            }
        }
    }

    fun loadDummyDataIfNeeded() {
        if (_vehicles.value.isNotEmpty()) return
        viewModelScope.launch {
            delay(3000)
            if (_vehicles.value.isNotEmpty()) return@launch
            val status = _wsStatus.value
            if (status is WSConnectionStatus.Error || status == WSConnectionStatus.Idle || status == WSConnectionStatus.Disconnected) {
                loadDummyData()
            }
        }
    }

    private fun loadDummyData() {
        _vehicleVersion.value++
        _vehicles.value = listOf(
            Vehicle("1","34 ABC 123","Ford Transit",VehicleStatus.ONLINE,true,48320,87,"Ahmet Yılmaz","İstanbul",41.0082,28.9784),
            Vehicle("2","06 XYZ 789","Mercedes Sprinter",VehicleStatus.OFFLINE,false,92100,0,"Mehmet Demir","Ankara",39.9334,32.8597),
            Vehicle("3","35 DEF 456","Renault Master",VehicleStatus.ONLINE,true,31540,62,"Ayşe Kaya","İzmir",38.4192,27.1287),
            Vehicle("4","16 GHI 321","Volkswagen Crafter",VehicleStatus.IDLE,false,67890,0,"Can Öztürk","Bursa",40.1885,29.0610),
            Vehicle("5","41 JKL 654","Fiat Ducato",VehicleStatus.ONLINE,true,22430,45,"Zeynep Şahin","Kocaeli",40.7654,29.9408),
            Vehicle("6","07 MNO 987","Peugeot Boxer",VehicleStatus.OFFLINE,false,55670,0,"Ali Çelik","Antalya",36.8969,30.7133),
            Vehicle("7","34 PRS 111","Iveco Daily",VehicleStatus.ONLINE,true,14220,112,"Fatma Arslan","İstanbul",41.0422,29.0083),
            Vehicle("8","06 TUV 222","Ford Transit Custom",VehicleStatus.IDLE,false,38900,0,"Hasan Koç","Ankara",39.9208,32.8541),
        )
    }
}
