package com.arveya.arveygo.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.models.VehicleStatus
import com.arveya.arveygo.services.WSConnectionStatus
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.services.WebSocketManager
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

    val onlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IGNITION_ON }
    val offlineCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.IGNITION_OFF || it.status == VehicleStatus.NO_DATA }
    val idleCount: Int get() = _vehicles.value.count { it.status == VehicleStatus.SLEEPING }

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
                    // Mevcut araç değerlerini koruyarak güncelle (null sıcaklık/nem için)
                    val currentMap = _vehicles.value.associateBy { it.id }
                    _vehicles.value = list.map { newVehicle ->
                        val existing = currentMap[newVehicle.id]
                        existing?.mergeUpdate(newVehicle) ?: newVehicle
                    }
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
                        // Snapshot'ta da mevcut değerleri koru
                        val currentMap = _vehicles.value.associateBy { it.id }
                        _vehicles.value = event.vehicles.map { newVehicle ->
                            val existing = currentMap[newVehicle.id]
                            existing?.mergeUpdate(newVehicle) ?: newVehicle
                        }
                        _vehicleVersion.value++
                    }
                    is WSEvent.Update -> {
                        val current = _vehicles.value.toMutableList()
                        val idx = current.indexOfFirst { it.id == event.vehicle.id }
                        if (idx >= 0) {
                            // mergeUpdate ile null değerlerde önceki değeri koru
                            current[idx] = current[idx].mergeUpdate(event.vehicle)
                        } else {
                            current.add(event.vehicle)
                        }
                        _vehicles.value = current
                        _vehicleVersion.value++
                    }
                    is WSEvent.StatusChanged -> _wsStatus.value = event.status
                    is WSEvent.Pong -> {}
                }
            }
        }
    }


}
