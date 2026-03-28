package com.arveya.arveygo.models

import androidx.compose.ui.graphics.Color
import com.arveya.arveygo.ui.theme.AppColors
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

// MARK: - User Model
data class AppUser(
    val id: String,
    val name: String,
    val email: String,
    val avatar: String,
    val role: String,
    val roleKey: String,
    val companyId: Int
) {
    companion object {
        val dummy = AppUser(
            id = "1",
            name = "Admin",
            email = "admin@admin.com",
            avatar = "A",
            role = "Süper Yönetici",
            roleKey = "super_admin",
            companyId = 1
        )
    }
}

// MARK: - Vehicle Status
enum class VehicleStatus(val key: String) {
    IGNITION_ON("ignition_on"),
    IGNITION_OFF("ignition_off"),
    NO_DATA("no_data"),
    SLEEPING("sleeping");

    val color: Color
        get() = when (this) {
            IGNITION_ON -> AppColors.Online
            IGNITION_OFF -> AppColors.Offline
            NO_DATA -> Color(0xFF94A3B8)
            SLEEPING -> AppColors.Idle
        }

    val label: String
        get() = when (this) {
            IGNITION_ON -> "Kontak Açık"
            IGNITION_OFF -> "Kontak Kapalı"
            NO_DATA -> "Bilgi Yok"
            SLEEPING -> "Cihaz Uykuda"
        }

    val icon: String
        get() = when (this) {
            IGNITION_ON -> "check_circle"
            IGNITION_OFF -> "cancel"
            NO_DATA -> "help"
            SLEEPING -> "bedtime"
        }
}

// MARK: - Vehicle Model
data class Vehicle(
    val id: String,
    var plate: String,
    var model: String,
    var status: VehicleStatus,
    var kontakOn: Boolean,
    var totalKm: Int,
    var todayKm: Int,
    var driver: String,
    var city: String,
    var lat: Double,
    var lng: Double,
    // Vehicle category: "car", "motorcycle", "truck", etc.
    var vehicleCategory: String = "car",
    // WebSocket / ATS fields
    var imei: String = "",
    var companyId: Int = 0,
    var name: String = "",
    var speed: Double = 0.0,
    var direction: Double = 0.0,
    var ignition: Boolean = false,
    var isOnline: Boolean = false,
    var fix: Boolean = false,
    var hdop: Double = 0.0,
    var input1: Boolean = false,
    var input2: Boolean = false,
    var output: Boolean = false,
    var batteryVoltage: Double? = null,
    var externalVoltage: Double? = null,
    var deviceBattery: Double? = null,
    var temperatureC: Double? = null,
    var humidityPct: Double? = null,
    var odometer: Double = 0.0,
    var speedLimit: Int = 0,
    var driverId: String? = null,
    var driverName: String = "",
    var alarmCode: String? = null,
    var deviceTime: String? = null,
    var ts: Int = 0,
    var deviceId: Int = 0,
    var assignmentId: Int? = null,
    var pdop: Double? = null,
    var satellites: Int? = null,
    var gsmSignal: Int? = null,
    var altitude: Double? = null,
    var lastPacketAt: String? = null,
    var lastPacketTs: Int = 0,
    var reportIntervalSec: Int? = null,
    var sleepIntervalSec: Int? = null,
    var offlineAfterSec: Int? = null,
    var secondsSinceLastPacket: Int? = null,
    var livenessStatus: String = "",
    var connectedNow: Boolean = false,
    var telemetry: JSONObject? = null,
    var beacons: org.json.JSONArray? = null,
    var beaconCount: Int = 0,
    var sensors: org.json.JSONArray? = null,
    var sensorCount: Int = 0,
    // Ignition timestamps (from WebSocket)
    var firstIgnitionOnAtToday: String? = null,
    var lastIgnitionOnAt: String? = null,
    var lastIgnitionOffAt: String? = null,
    // API-enriched fields (from /api/mobile/vehicles/{id})
    var groupName: String = "",
    var vehicleBrand: String = "",
    var vehicleModel: String = "",
    var address: String = "",
    var dailyKm: Double = 0.0,
    var fuelType: String = "",
    var dailyFuelLiters: Double = 0.0,
    var dailyFuelPer100km: Double = 0.0,
    var fuelPer100km: Double = 0.0
) {
    val isMotorcycle: Boolean get() = vehicleCategory == "motorcycle"

    /** Estimated daily fuel consumption in liters: dailyKm * fuelPer100km / 100 */
    val estimatedDailyFuelLiters: Double
        get() {
            val rate = if (dailyFuelPer100km > 0) dailyFuelPer100km else fuelPer100km
            if (rate <= 0 || dailyKm <= 0) return 0.0
            return dailyKm * rate / 100.0
        }

    /** Estimated daily fuel cost in TL */
    val estimatedDailyFuelCostTL: Double
        get() {
            val liters = estimatedDailyFuelLiters
            if (liters <= 0) return 0.0
            val pricePerLiter = when {
                fuelType.contains("Dizel", ignoreCase = true) || fuelType.contains("diesel", ignoreCase = true) -> 42.75
                fuelType.contains("Benzin", ignoreCase = true) || fuelType.contains("gasoline", ignoreCase = true) -> 44.49
                fuelType.contains("LPG", ignoreCase = true) -> 17.54
                else -> 42.75 // default Dizel
            }
            return liters * pricePerLiter
        }

    val formattedDailyFuelCost: String
        get() {
            val cost = estimatedDailyFuelCostTL
            if (cost <= 0) return "—"
            val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR"))
            fmt.maximumFractionDigits = 0
            return "\u20ba${fmt.format(cost)}"
        }

    val formattedDailyFuelLiters: String
        get() {
            val liters = estimatedDailyFuelLiters
            if (liters <= 0) return "—"
            return String.format("%.1f L", liters)
        }

    val formattedTotalKm: String
        get() {
            // Odometer metre cinsinden gelebilir, km'ye çevir (noktadan sonrası metre olduğu için sadece km kısmı)
            val kmValue = if (totalKm > 10000) totalKm / 1000 else totalKm
            val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR"))
            fmt.maximumFractionDigits = 0
            return fmt.format(kmValue)
        }

    val formattedTodayKm: String
        get() {
            val kmVal = if (dailyKm > 0) dailyKm else todayKm.toDouble()
            if (kmVal <= 0) return "0 km"
            return if (kmVal < 1) {
                String.format("%.0f m", kmVal * 1000)
            } else {
                val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR"))
                fmt.maximumFractionDigits = 1
                fmt.format(kmVal) + " km"
            }
        }

    val formattedSpeed: String get() = "${speed.toInt()} km/h"

    val kontakLabel: String get() = if (ignition) "Kontak A\u00e7\u0131k" else "Kontak Kapal\u0131"

    private fun formatTimestamp(raw: String?): String {
        if (raw.isNullOrEmpty()) return "\u2014"
        val cleaned = raw.replace(Regex("\\.\\d+"), "")
        
        fun formatSmart(date: java.util.Date): String {
            val tz = TimeZone.getTimeZone("Europe/Istanbul")
            val calNow = java.util.Calendar.getInstance(tz)
            val calDate = java.util.Calendar.getInstance(tz).apply { time = date }
            val isToday = calNow.get(java.util.Calendar.YEAR) == calDate.get(java.util.Calendar.YEAR) &&
                    calNow.get(java.util.Calendar.DAY_OF_YEAR) == calDate.get(java.util.Calendar.DAY_OF_YEAR)
            calNow.add(java.util.Calendar.DAY_OF_YEAR, -1)
            val isYesterday = calNow.get(java.util.Calendar.YEAR) == calDate.get(java.util.Calendar.YEAR) &&
                    calNow.get(java.util.Calendar.DAY_OF_YEAR) == calDate.get(java.util.Calendar.DAY_OF_YEAR)
            val pattern = when {
                isToday -> "HH:mm"
                isYesterday -> "'D\u00fcn' HH:mm"
                else -> "dd.MM HH:mm"
            }
            val fmt = SimpleDateFormat(pattern, Locale("tr", "TR"))
            fmt.timeZone = tz
            return fmt.format(date)
        }
        
        return try {
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            val date = inputFormat.parse(cleaned) ?: return raw
            formatSmart(date)
        } catch (_: Exception) {
            try {
                val inputFormat2 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                inputFormat2.timeZone = TimeZone.getTimeZone("UTC")
                val date2 = inputFormat2.parse(cleaned) ?: return raw
                formatSmart(date2)
            } catch (_: Exception) { raw }
        }
    }

    val formattedFirstIgnitionToday: String get() = formatTimestamp(firstIgnitionOnAtToday)
    val formattedLastIgnitionOn: String get() = formatTimestamp(lastIgnitionOnAt)
    val formattedLastIgnitionOff: String get() = formatTimestamp(lastIgnitionOffAt)
    val formattedLastPacketAt: String get() = formatTimestamp(lastPacketAt)

    /** Liveness status display label */
    val livenessLabel: String
        get() = when (livenessStatus) {
            "connected" -> "Bağlı"
            "reporting" -> "Raporluyor"
            "sleeping" -> "Uyku"
            "late" -> "Gecikmeli"
            "offline" -> "Çevrimdışı"
            else -> if (isOnline) "Çevrimiçi" else "Çevrimdışı"
        }

    val formattedDeviceTime: String
        get() {
            val raw = deviceTime ?: return "—"
            // Strip fractional seconds that can cause parse failure (e.g. .456+03:00)
            val cleaned = raw.replace(Regex("\\.\\d+"), "")
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
                val outputFormat = SimpleDateFormat("dd.MM.yyyy HH:mm", Locale("tr", "TR"))
                outputFormat.timeZone = TimeZone.getTimeZone("Europe/Istanbul")
                val date = inputFormat.parse(cleaned) ?: return raw
                outputFormat.format(date)
            } catch (_: Exception) {
                try {
                    val inputFormat2 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                    inputFormat2.timeZone = TimeZone.getTimeZone("UTC")
                    val outputFormat2 = SimpleDateFormat("dd.MM.yyyy HH:mm", Locale("tr", "TR"))
                    outputFormat2.timeZone = TimeZone.getTimeZone("Europe/Istanbul")
                    val date2 = inputFormat2.parse(cleaned) ?: return raw
                    outputFormat2.format(date2)
                } catch (_: Exception) {
                    raw
                }
            }
        }

    // Fleet extensions
    val fleetStatus: FleetVehicleStatus
        get() = when (status) {
            VehicleStatus.IGNITION_ON -> FleetVehicleStatus.ACTIVE
            VehicleStatus.IGNITION_OFF -> FleetVehicleStatus.PASSIVE
            VehicleStatus.NO_DATA -> FleetVehicleStatus.PASSIVE
            VehicleStatus.SLEEPING -> FleetVehicleStatus.MAINTENANCE
        }

    val group: String
        get() = if (groupName.isNotEmpty()) groupName else "—"

    val vehicleType: String
        get() {
            if (vehicleBrand.isNotEmpty() && vehicleModel.isNotEmpty()) return "$vehicleBrand $vehicleModel"
            if (vehicleBrand.isNotEmpty()) return vehicleBrand
            return when {
                vehicleCategory == "motorcycle" -> "Motosiklet"
                model.contains("Transit") || model.contains("Sprinter") -> "Panelvan"
                model.contains("Crafter") || model.contains("Master") -> "Kamyonet"
                else -> "Ticari"
            }
        }

    val locationDisplay: String
        get() {
            if (address.isNotEmpty()) return address
            if (city.isNotEmpty()) return city
            if (lat != 0.0 && lng != 0.0) return String.format("%.4f, %.4f", lat, lng)
            return "—"
        }

    companion object {
        fun fromWSPayload(json: JSONObject): Vehicle? {
            val imei = json.optString("imei", "")
            if (imei.isEmpty()) return null

            val plate = json.optString("plate", "")
            val name = json.optString("name", "")
            val lat = json.optDouble("lat", 0.0)
            val lon = json.optDouble("lon", 0.0)
            val speed = json.optDouble("speed", 0.0)
            val direction = json.optDouble("direction", 0.0)
            val ignition = json.optBoolean("ignition", false)
            val isOnline = json.optBoolean("is_online", false)
            val fix = json.optBoolean("fix", false)
            val hdop = json.optDouble("hdop", 0.0)
            val input1 = json.optBoolean("input1", false)
            val input2 = json.optBoolean("input2", false)
            val output = json.optBoolean("output", false)
            val odometer = json.optDouble("odometer", 0.0)
            val dailyKmVal = json.optDouble("dailyKm", json.optDouble("daily_km", 0.0))
            val todayKmVal = json.optDouble("todayKm", json.optDouble("today_km", 0.0))
            val fuelPer100kmVal = json.optDouble("fuelPer100km", json.optDouble("fuel_per_100km", 0.0))
            val fuelTypeVal = json.optString("fuelType", json.optString("fuel_type", ""))
            val speedLimit = json.optInt("speed_limit", 0)
            val companyId = json.optInt("company_id", 0)
            val driverId: String? = if (json.has("driver_id") && !json.isNull("driver_id")) {
                val v = json.optString("driver_id", "")
                if (v.isEmpty() || v == "null") null else v
            } else null
            val alarmCode: String? = if (json.has("alarm_code") && !json.isNull("alarm_code")) {
                val v = json.optString("alarm_code", "")
                if (v.isEmpty() || v == "null") null else v
            } else null
            val deviceTime = if (json.has("device_time") && !json.isNull("device_time")) json.optString("device_time") else null
            val ts = json.optInt("ts", 0)
            val deviceIdValue = if (json.has("id") && !json.isNull("id")) json.optInt("id", 0) else json.optInt("deviceId", 0)
            val assignmentId: Int? = if (json.has("assignment_id") && !json.isNull("assignment_id")) json.optInt("assignment_id") else null
            val firstIgnitionOnAtToday: String? = if (json.has("first_ignition_on_at_today") && !json.isNull("first_ignition_on_at_today")) json.optString("first_ignition_on_at_today").let { if (it == "null") null else it } else null
            val lastIgnitionOnAt: String? = if (json.has("last_ignition_on_at") && !json.isNull("last_ignition_on_at")) json.optString("last_ignition_on_at").let { if (it == "null") null else it } else null
            val lastIgnitionOffAt: String? = if (json.has("last_ignition_off_at") && !json.isNull("last_ignition_off_at")) json.optString("last_ignition_off_at").let { if (it == "null") null else it } else null
            val lastPacketAt: String? = if (json.has("last_packet_at") && !json.isNull("last_packet_at")) json.optString("last_packet_at") else null
            val lastPacketTs = json.optInt("last_packet_ts", 0)
            val batteryVoltage = when {
                json.has("battery_voltage") -> json.optDouble("battery_voltage")
                json.has("battery") -> json.optDouble("battery")
                else -> null
            }
            val externalVoltage = when {
                json.has("external_voltage") -> json.optDouble("external_voltage")
                json.has("externalVoltage") -> json.optDouble("externalVoltage")
                else -> null
            }
            // deviceBattery (battery_level_pct = percentage): check top-level, then camelCase, then inside telemetry
            val telObj = if (json.has("telemetry") && !json.isNull("telemetry")) json.optJSONObject("telemetry") else null
            val deviceBatteryRaw = when {
                json.has("battery_level_pct") && !json.isNull("battery_level_pct") -> json.optDouble("battery_level_pct")
                json.has("deviceBatteryLevelPct") && !json.isNull("deviceBatteryLevelPct") -> json.optDouble("deviceBatteryLevelPct")
                json.has("device_battery") && !json.isNull("device_battery") -> json.optDouble("device_battery")
                json.has("deviceBattery") && !json.isNull("deviceBattery") -> json.optDouble("deviceBattery")
                telObj != null && telObj.has("battery_level_pct") && !telObj.isNull("battery_level_pct") -> telObj.optDouble("battery_level_pct")
                else -> null
            }
            val deviceBattery = if (deviceBatteryRaw != null && !deviceBatteryRaw.isNaN()) deviceBatteryRaw else null
            val vehicleCategory = json.optString("vehicle_category", "car")

            // Temperature: check top-level first (backend sends snake_case: temperature_c)
            // Note: optDouble returns NaN for null/missing values, so we must filter NaN
            fun safeDouble(v: Double): Double? = if (v.isNaN()) null else v

            var temperatureC: Double? = null
            for (key in listOf("temperature_c", "temperatureC", "tempCurrent")) {
                if (json.has(key)) {
                    temperatureC = safeDouble(json.optDouble(key))
                    if (temperatureC != null) break
                }
            }
            var humidityPct: Double? = null
            for (key in listOf("humidity_pct", "humidityPct")) {
                if (json.has(key)) {
                    humidityPct = safeDouble(json.optDouble(key))
                    if (humidityPct != null) break
                }
            }

            // If not at top level, look inside sensors array (backend sends sensor data here)
            if (temperatureC == null && json.has("sensors")) {
                val sensors = json.optJSONArray("sensors")
                if (sensors != null) {
                    for (i in 0 until sensors.length()) {
                        val sensor = sensors.optJSONObject(i) ?: continue
                        for (key in listOf("temperature_c", "temperatureC")) {
                            if (sensor.has(key)) {
                                val t = safeDouble(sensor.optDouble(key))
                                if (t != null) {
                                    temperatureC = t
                                    if (humidityPct == null) {
                                        for (hKey in listOf("humidity_pct", "humidityPct")) {
                                            if (sensor.has(hKey)) {
                                                humidityPct = safeDouble(sensor.optDouble(hKey))
                                                if (humidityPct != null) break
                                            }
                                        }
                                    }
                                    break
                                }
                            }
                        }
                        if (temperatureC != null) break
                    }
                }
            }

            android.util.Log.d("Vehicle", "TEMP PARSE [$plate]: temperatureC=$temperatureC, humidityPct=$humidityPct")

            // New fields
            val pdop: Double? = if (json.has("pdop") && !json.isNull("pdop")) safeDouble(json.optDouble("pdop")) else null
            val satellites: Int? = if (json.has("satellites") && !json.isNull("satellites")) json.optInt("satellites") else null
            val gsmSignal: Int? = if (json.has("gsm_signal") && !json.isNull("gsm_signal")) json.optInt("gsm_signal") else null
            val altitude: Double? = if (json.has("altitude") && !json.isNull("altitude")) safeDouble(json.optDouble("altitude")) else null
            val reportIntervalSec: Int? = if (json.has("report_interval_sec") && !json.isNull("report_interval_sec")) json.optInt("report_interval_sec") else null
            val sleepIntervalSec: Int? = if (json.has("sleep_interval_sec") && !json.isNull("sleep_interval_sec")) json.optInt("sleep_interval_sec") else null
            val offlineAfterSec: Int? = if (json.has("offline_after_sec") && !json.isNull("offline_after_sec")) json.optInt("offline_after_sec") else null
            val secondsSinceLastPacket: Int? = if (json.has("seconds_since_last_packet") && !json.isNull("seconds_since_last_packet")) json.optInt("seconds_since_last_packet") else null
            val livenessStatus = json.optString("liveness_status", "")
            val connectedNow = json.optBoolean("connected_now", false)
            val telemetry: JSONObject? = if (json.has("telemetry") && !json.isNull("telemetry")) json.optJSONObject("telemetry") else null
            val beacons: org.json.JSONArray? = if (json.has("beacons") && !json.isNull("beacons")) json.optJSONArray("beacons") else null
            val beaconCount = json.optInt("beacon_count", 0)
            val sensorsArr: org.json.JSONArray? = if (json.has("sensors") && !json.isNull("sensors")) json.optJSONArray("sensors") else null
            val sensorCount = json.optInt("sensor_count", 0)

            // Status derivation — 4 states: Kontak Açık, Kontak Kapalı, Bilgi Yok, Cihaz Uykuda
            val status = when {
                !isOnline && secondsSinceLastPacket != null && secondsSinceLastPacket > (offlineAfterSec ?: 3600) -> VehicleStatus.NO_DATA
                !isOnline -> VehicleStatus.IGNITION_OFF
                ignition -> VehicleStatus.IGNITION_ON
                else -> VehicleStatus.IGNITION_OFF
            }

            val effectiveDailyKm = if (dailyKmVal > 0) dailyKmVal else todayKmVal

            return Vehicle(
                id = imei, plate = plate, model = name, status = status,
                kontakOn = ignition, totalKm = odometer.toInt(), todayKm = effectiveDailyKm.toInt(),
                driver = driverId ?: "", city = "", lat = lat, lng = lon,
                vehicleCategory = vehicleCategory,
                imei = imei, companyId = companyId, name = name,
                speed = speed, direction = direction, ignition = ignition,
                isOnline = isOnline, fix = fix, hdop = hdop,
                input1 = input1, input2 = input2, output = output,
                batteryVoltage = batteryVoltage, externalVoltage = externalVoltage, deviceBattery = deviceBattery,
                temperatureC = temperatureC, humidityPct = humidityPct,
                odometer = odometer, speedLimit = speedLimit,
                driverId = driverId, alarmCode = alarmCode,
                deviceTime = deviceTime, ts = ts,
                deviceId = deviceIdValue,
                assignmentId = assignmentId,
                pdop = pdop, satellites = satellites, gsmSignal = gsmSignal, altitude = altitude,
                lastPacketAt = lastPacketAt, lastPacketTs = lastPacketTs,
                reportIntervalSec = reportIntervalSec, sleepIntervalSec = sleepIntervalSec,
                offlineAfterSec = offlineAfterSec, secondsSinceLastPacket = secondsSinceLastPacket,
                livenessStatus = livenessStatus, connectedNow = connectedNow,
                telemetry = telemetry, beacons = beacons, beaconCount = beaconCount,
                sensors = sensorsArr, sensorCount = sensorCount,
                firstIgnitionOnAtToday = firstIgnitionOnAtToday,
                lastIgnitionOnAt = lastIgnitionOnAt,
                lastIgnitionOffAt = lastIgnitionOffAt,
                dailyKm = effectiveDailyKm,
                fuelType = fuelTypeVal,
                dailyFuelPer100km = fuelPer100kmVal
            )
        }
    }

    fun mergeUpdate(patch: Vehicle): Vehicle {
        return this.copy(
            plate = if (patch.plate.isNotEmpty()) patch.plate else plate,
            model = if (patch.model.isNotEmpty()) patch.model else model,
            lat = if (patch.lat != 0.0 || patch.lng != 0.0) patch.lat else lat,
            lng = if (patch.lat != 0.0 || patch.lng != 0.0) patch.lng else lng,
            speed = patch.speed, direction = patch.direction,
            ignition = patch.ignition, isOnline = patch.isOnline,
            kontakOn = patch.ignition, status = patch.status,
            totalKm = if (patch.odometer > 0) patch.odometer.toInt() else totalKm,
            odometer = if (patch.odometer > 0) patch.odometer else odometer,
            todayKm = if (patch.todayKm > 0) patch.todayKm else todayKm,
            // null alanları gerçekten null olarak işle, eski değeri koruma
            deviceTime = patch.deviceTime,
            ts = if (patch.ts > 0) patch.ts else ts,
            fix = patch.fix, hdop = patch.hdop,
            input1 = patch.input1, input2 = patch.input2, output = patch.output,
            // Sensör/batarya verileri her pakette gelmeyebilir, null ise eski değeri koru
            batteryVoltage = patch.batteryVoltage ?: batteryVoltage,
            externalVoltage = patch.externalVoltage ?: externalVoltage,
            deviceBattery = patch.deviceBattery ?: deviceBattery,
            temperatureC = patch.temperatureC ?: temperatureC,
            humidityPct = patch.humidityPct ?: humidityPct,
            // driver_id null olabilir (kart çıkarılınca), eski değeri tutma
            driverId = patch.driverId,
            driverName = if (patch.driverName.isNotEmpty()) patch.driverName else if (patch.driverId == null) "" else driverName,
            alarmCode = patch.alarmCode,
            firstIgnitionOnAtToday = patch.firstIgnitionOnAtToday ?: firstIgnitionOnAtToday,
            lastIgnitionOnAt = patch.lastIgnitionOnAt ?: lastIgnitionOnAt,
            lastIgnitionOffAt = patch.lastIgnitionOffAt ?: lastIgnitionOffAt,
            vehicleCategory = if (patch.vehicleCategory != "car") patch.vehicleCategory else vehicleCategory,
            deviceId = if (patch.deviceId > 0) patch.deviceId else deviceId,
            assignmentId = patch.assignmentId ?: assignmentId,
            pdop = patch.pdop ?: pdop,
            satellites = patch.satellites ?: satellites,
            gsmSignal = patch.gsmSignal ?: gsmSignal,
            altitude = patch.altitude ?: altitude,
            lastPacketAt = patch.lastPacketAt ?: lastPacketAt,
            lastPacketTs = if (patch.lastPacketTs > 0) patch.lastPacketTs else lastPacketTs,
            reportIntervalSec = patch.reportIntervalSec ?: reportIntervalSec,
            sleepIntervalSec = patch.sleepIntervalSec ?: sleepIntervalSec,
            offlineAfterSec = patch.offlineAfterSec ?: offlineAfterSec,
            secondsSinceLastPacket = patch.secondsSinceLastPacket,
            livenessStatus = if (patch.livenessStatus.isNotEmpty()) patch.livenessStatus else livenessStatus,
            connectedNow = patch.connectedNow,
            telemetry = patch.telemetry ?: telemetry,
            beacons = patch.beacons ?: beacons,
            beaconCount = if (patch.beaconCount > 0) patch.beaconCount else beaconCount,
            sensors = patch.sensors ?: sensors,
            sensorCount = if (patch.sensorCount > 0) patch.sensorCount else sensorCount,
            // Preserve API-enriched fields (WS doesn't provide these)
            groupName = if (patch.groupName.isNotEmpty()) patch.groupName else groupName,
            vehicleBrand = if (patch.vehicleBrand.isNotEmpty()) patch.vehicleBrand else vehicleBrand,
            vehicleModel = if (patch.vehicleModel.isNotEmpty()) patch.vehicleModel else vehicleModel,
            address = if (patch.address.isNotEmpty()) patch.address else address,
            dailyKm = if (patch.dailyKm > 0) patch.dailyKm else dailyKm,
            fuelType = if (patch.fuelType.isNotEmpty()) patch.fuelType else fuelType,
            dailyFuelLiters = if (patch.dailyFuelLiters > 0) patch.dailyFuelLiters else dailyFuelLiters,
            dailyFuelPer100km = if (patch.dailyFuelPer100km > 0) patch.dailyFuelPer100km else dailyFuelPer100km,
            fuelPer100km = if (patch.fuelPer100km > 0) patch.fuelPer100km else fuelPer100km
        )
    }
}

// MARK: - Fleet Vehicle Status
enum class FleetVehicleStatus(val label: String, val color: Color) {
    ACTIVE("Aktif", AppColors.Online),
    PASSIVE("Pasif", Color(0xFF94A3B8)),
    MAINTENANCE("Bakımda", AppColors.Idle)
}

// MARK: - Fleet Tire
data class FleetTire(
    val id: String,
    val imei: String = "",
    val plate: String = "",
    val position: String = "",
    val brand: String = "",
    val model: String = "",
    val size: String = "",
    val dotCode: String = "",
    val installDate: String = "",
    val kmAtInstall: Int = 0,
    val kmLimit: Int = 0,
    val status: String = "active",
    val notes: String = "",
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    val statusLabel: String
        get() = when (status) {
            "active" -> "Aktif"
            "worn" -> "Aşınmış"
            "replaced" -> "Değiştirildi"
            "critical" -> "Kritik"
            else -> status
        }

    val statusColor: Color
        get() = when (status) {
            "active" -> Color(0xFF22C55E)
            "worn" -> Color(0xFFF59E0B)
            "replaced" -> Color(0xFF94A3B8)
            "critical" -> Color(0xFFEF4444)
            else -> Color(0xFF94A3B8)
        }

    val positionLabel: String
        get() = when (position) {
            "sol_on" -> "Sol Ön"
            "sag_on" -> "Sağ Ön"
            "sol_arka" -> "Sol Arka"
            "sag_arka" -> "Sağ Arka"
            "yedek" -> "Yedek"
            else -> position
        }

    companion object {
        fun fromJson(json: org.json.JSONObject): FleetTire {
            return FleetTire(
                id = json.optString("id", "0"),
                imei = json.optString("imei", ""),
                plate = json.optString("plate", ""),
                position = json.optString("position", ""),
                brand = json.optString("brand", ""),
                model = json.optString("model", ""),
                size = json.optString("size", ""),
                dotCode = json.optString("dot_code", ""),
                installDate = json.optString("install_date", ""),
                kmAtInstall = json.optInt("km_at_install", 0),
                kmLimit = json.optInt("km_limit", 0),
                status = json.optString("status", "active"),
                notes = json.optString("notes", ""),
                createdAt = json.optString("created_at", null),
                updatedAt = json.optString("updated_at", null)
            )
        }
    }
}

// MARK: - Vehicle Cost (API-backed)
data class VehicleCost(
    val id: String,
    val imei: String = "",
    val plate: String = "",
    val category: String,
    val amount: Double = 0.0,
    val currency: String = "TRY",
    val costDate: String = "",
    val description: String = "",
    val referenceNo: String = "",
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    /** Formatted amount for display */
    val formattedAmount: String
        get() {
            val fmt = java.text.NumberFormat.getNumberInstance(java.util.Locale("tr", "TR"))
            fmt.maximumFractionDigits = 0
            val symbol = if (currency == "TRY") "₺" else currency
            return "$symbol${fmt.format(amount)}"
        }

    companion object {
        fun fromJson(json: org.json.JSONObject): VehicleCost {
            return VehicleCost(
                id = json.optString("id", "0"),
                imei = json.optString("imei", ""),
                plate = json.optString("plate", ""),
                category = json.optString("category", ""),
                amount = json.optDouble("amount", 0.0),
                currency = json.optString("currency", "TRY"),
                costDate = json.optString("cost_date", ""),
                description = json.optString("description", ""),
                referenceNo = json.optString("reference_no", ""),
                createdAt = json.optString("created_at", null),
                updatedAt = json.optString("updated_at", null)
            )
        }
    }
}

// MARK: - Fleet Maintenance
data class FleetMaintenance(
    val id: String,
    val imei: String = "",
    val plate: String = "",
    val maintenanceType: String = "",
    val serviceDate: String? = null,
    val nextServiceDate: String? = null,
    val kmAtService: Int? = null,
    val nextServiceKm: Int? = null,
    val cost: Double? = null,
    val workshop: String = "",
    val description: String = "",
    val status: String = "done",
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    val statusLabel: String
        get() = when (status) {
            "done" -> "Tamamlandı"
            "scheduled" -> "Planlandı"
            "overdue" -> "Gecikmiş"
            else -> status
        }

    val statusColor: Color
        get() = when (status) {
            "done" -> Color(0xFF22C55E)
            "scheduled" -> Color.Blue
            "overdue" -> Color.Red
            else -> Color(0xFFFF9800)
        }

    val formattedCost: String
        get() {
            if (cost == null || cost <= 0) return "—"
            val fmt = java.text.NumberFormat.getNumberInstance(java.util.Locale("tr", "TR"))
            fmt.maximumFractionDigits = 0
            return "₺${fmt.format(cost)}"
        }

    companion object {
        fun fromJson(json: org.json.JSONObject): FleetMaintenance {
            return FleetMaintenance(
                id = json.optString("id", "0"),
                imei = json.optString("imei", ""),
                plate = json.optString("plate", ""),
                maintenanceType = json.optString("maintenance_type", ""),
                serviceDate = if (json.has("service_date") && !json.isNull("service_date")) json.optString("service_date") else null,
                nextServiceDate = if (json.has("next_service_date") && !json.isNull("next_service_date")) json.optString("next_service_date") else null,
                kmAtService = if (json.has("km_at_service") && !json.isNull("km_at_service")) json.optInt("km_at_service") else null,
                nextServiceKm = if (json.has("next_service_km") && !json.isNull("next_service_km")) json.optInt("next_service_km") else null,
                cost = if (json.has("cost") && !json.isNull("cost")) json.optDouble("cost") else null,
                workshop = json.optString("workshop", ""),
                description = json.optString("description", ""),
                status = json.optString("status", "done"),
                createdAt = json.optString("created_at", null),
                updatedAt = json.optString("updated_at", null)
            )
        }
    }
}

// MARK: - Fleet Document
data class FleetDocument(
    val id: String,
    val imei: String = "",
    val plate: String = "",
    val docType: String = "",
    val title: String = "",
    val issueDate: String? = null,
    val expiryDate: String? = null,
    val reminderDays: Int = 30,
    val filePath: String = "",
    val notes: String = "",
    val status: String = "active",
    val daysLeft: Int? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    val statusLabel: String
        get() = when (status) {
            "active" -> "Aktif"
            "expiring_soon" -> "Yaklaşıyor"
            "expired" -> "Süresi Dolmuş"
            else -> status
        }

    val statusColor: Color
        get() = when (status) {
            "active" -> Color(0xFF22C55E)
            "expiring_soon" -> Color(0xFFFF9800)
            "expired" -> Color.Red
            else -> Color(0xFF94A3B8)
        }

    val docTypeLabel: String
        get() = when (docType) {
            "ruhsat" -> "Ruhsat"
            "sigorta" -> "Sigorta"
            "muayene" -> "Muayene"
            "egzoz" -> "Egzoz"
            "fenni_muayene" -> "Fenni Muayene"
            "other" -> "Diğer"
            else -> docType.replaceFirstChar { it.uppercase() }
        }

    companion object {
        fun fromJson(json: org.json.JSONObject): FleetDocument {
            return FleetDocument(
                id = json.optString("id", "0"),
                imei = json.optString("imei", ""),
                plate = json.optString("plate", ""),
                docType = json.optString("doc_type", ""),
                title = json.optString("title", ""),
                issueDate = if (json.has("issue_date") && !json.isNull("issue_date")) json.optString("issue_date") else null,
                expiryDate = if (json.has("expiry_date") && !json.isNull("expiry_date")) json.optString("expiry_date") else null,
                reminderDays = json.optInt("reminder_days", 30),
                filePath = json.optString("file_path", ""),
                notes = json.optString("notes", ""),
                status = json.optString("status", "active"),
                daysLeft = if (json.has("days_left") && !json.isNull("days_left")) json.optInt("days_left") else null,
                createdAt = json.optString("created_at", null),
                updatedAt = json.optString("updated_at", null)
            )
        }
    }
}

// MARK: - Fleet Catalog
data class FleetCatalog(
    val vehicles: List<FleetCatalogVehicle> = emptyList(),
    val costCategories: List<String> = emptyList(),
    val maintenanceStatuses: List<String> = emptyList(),
    val documentTypes: List<String> = emptyList()
) {
    companion object {
        fun fromJson(json: org.json.JSONObject): FleetCatalog {
            val vehiclesArr = json.optJSONArray("vehicles") ?: org.json.JSONArray()
            val vehicles = (0 until vehiclesArr.length()).map { i ->
                val v = vehiclesArr.getJSONObject(i)
                FleetCatalogVehicle(
                    id = v.optInt("id", 0),
                    imei = v.optString("imei", ""),
                    plate = v.optString("plate", ""),
                    name = v.optString("name", ""),
                    type = v.optString("type", "")
                )
            }
            fun jsonArrayToStringList(arr: org.json.JSONArray?): List<String> {
                if (arr == null) return emptyList()
                return (0 until arr.length()).map { arr.optString(it, "") }
            }
            return FleetCatalog(
                vehicles = vehicles,
                costCategories = jsonArrayToStringList(json.optJSONArray("cost_categories")),
                maintenanceStatuses = jsonArrayToStringList(json.optJSONArray("maintenance_statuses")),
                documentTypes = jsonArrayToStringList(json.optJSONArray("document_types"))
            )
        }
    }
}

data class FleetCatalogVehicle(
    val id: Int = 0,
    val imei: String = "",
    val plate: String = "",
    val name: String = "",
    val type: String = ""
)

// MARK: - Fleet Reminder
data class FleetReminder(
    val id: Int,
    val imei: String,
    val plate: String,
    val type: String,       // "document" or "maintenance"
    val label: String,      // doc_type/title or maintenance_type
    val dueDate: String?,   // expiry_date or next_service_date
    val daysLeft: Int
)

// MARK: - Pagination
data class PaginationMeta(
    val total: Int = 0,
    val perPage: Int = 20,
    val currentPage: Int = 1,
    val lastPage: Int = 1
) {
    val hasMore: Boolean get() = currentPage < lastPage

    companion object {
        fun fromJson(json: org.json.JSONObject?): PaginationMeta {
            if (json == null) return PaginationMeta()
            return PaginationMeta(
                total = json.optInt("total", 0),
                perPage = json.optInt("per_page", 20),
                currentPage = json.optInt("current_page", 1),
                lastPage = json.optInt("last_page", 1)
            )
        }
    }
}

// MARK: - Driver Score
data class DriverScore(
    val id: String,
    val name: String,
    val plate: String,
    val score: Int,
    val totalKm: Int,
    val color: Color
) {
    val scoreColor: Color
        get() = when {
            score >= 85 -> AppColors.Online
            score >= 70 -> AppColors.Idle
            else -> AppColors.Offline
        }
}

// MARK: - Fleet Alert
data class FleetAlert(
    val id: String,
    val title: String,
    val description: String,
    val time: String,
    val severity: AlertSeverity
)

enum class AlertSeverity(val color: Color) {
    RED(Color.Red),
    AMBER(Color(0xFFFFA000)),
    BLUE(Color.Blue),
    GREEN(Color(0xFF4CAF50))
}

// MARK: - Dashboard Metric
data class DashboardMetric(
    val title: String,
    val value: String,
    val icon: String,
    val iconBg: Color,
    val iconColor: Color,
    val change: String,
    val changeType: ChangeType
)

enum class ChangeType {
    UP, DOWN, FLAT;

    val color: Color
        get() = when (this) {
            UP -> AppColors.Online
            DOWN -> AppColors.Offline
            FLAT -> AppColors.TextFaint
        }

    val iconName: String
        get() = when (this) {
            UP -> "arrow_upward"
            DOWN -> "arrow_downward"
            FLAT -> "remove"
        }
}

// MARK: - Route Models
data class RoutePoint(val lat: Double, val lng: Double, val speed: Int, val time: String)

data class RouteTrip(
    val id: String,
    val dateLabel: String,
    val startTime: String,
    val endTime: String,
    val startAddress: String,
    val endAddress: String,
    val distance: String,
    val duration: String,
    val maxSpeed: String,
    val avgSpeed: String,
    val fuelUsed: String,
    val points: List<RoutePoint>
)

// MARK: - WS Config
data class WSConfig(val url: String, val token: String, val pingInterval: Int)

// MARK: - Geofence Model
data class GeofencePoint(val lat: Double, val lng: Double)

data class Geofence(
    val id: Int,
    val name: String,
    val type: String = "polygon",     // "polygon" or "circle"
    val color: String = "#3b82f6",    // hex
    val points: List<GeofencePoint> = emptyList(),
    val radius: Double? = null,
    val centerLat: Double? = null,
    val centerLng: Double? = null,
    val createdAt: String? = null
) {
    val isCircle: Boolean get() = type == "circle"

    val composeColor: Color
        get() {
            return try {
                val hex = color.removePrefix("#")
                val int = hex.toLong(16)
                Color(
                    red = ((int shr 16) and 0xFF) / 255f,
                    green = ((int shr 8) and 0xFF) / 255f,
                    blue = (int and 0xFF) / 255f
                )
            } catch (_: Exception) {
                Color.Blue
            }
        }

    companion object {
        fun fromJson(json: JSONObject): Geofence {
            // API returns "path" with {lat, lon} — normalise to GeofencePoint {lat, lng}
            val rawPath = when {
                json.has("path") && !json.isNull("path") -> {
                    val v = json.get("path")
                    when (v) {
                        is org.json.JSONArray -> v
                        is String -> try { org.json.JSONArray(v) } catch (_: Exception) { org.json.JSONArray() }
                        else -> org.json.JSONArray()
                    }
                }
                json.has("points") && !json.isNull("points") -> json.optJSONArray("points") ?: org.json.JSONArray()
                else -> org.json.JSONArray()
            }
            val pts = (0 until rawPath.length()).map { i ->
                val p = rawPath.getJSONObject(i)
                val lat = p.optDouble("lat", 0.0)
                val lng = if (p.has("lon")) p.optDouble("lon", 0.0) else p.optDouble("lng", 0.0)
                GeofencePoint(lat, lng)
            }

            // API returns shape_type, radius_m, center_lon
            val type = if (json.has("shape_type") && !json.isNull("shape_type"))
                json.optString("shape_type", "polygon") else json.optString("type", "polygon")

            val radius = when {
                json.has("radius_m") && !json.isNull("radius_m") -> json.optDouble("radius_m")
                json.has("radius") && !json.isNull("radius") -> json.optDouble("radius")
                else -> null
            }
            val centerLat = if (json.has("center_lat") && !json.isNull("center_lat")) json.optDouble("center_lat") else null
            val centerLng = when {
                json.has("center_lon") && !json.isNull("center_lon") -> json.optDouble("center_lon")
                json.has("center_lng") && !json.isNull("center_lng") -> json.optDouble("center_lng")
                else -> null
            }

            return Geofence(
                id = json.optInt("id", 0),
                name = json.optString("name", ""),
                type = type,
                color = json.optString("color", "#3b82f6"),
                points = pts,
                radius = radius,
                centerLat = centerLat,
                centerLng = centerLng,
                createdAt = json.optString("created_at", null)
            )
        }
    }
}

// MARK: - Driver Model
data class Driver(
    val id: String,
    val driverCode: String = "",
    val name: String,
    val avatar: String = "",
    val color: String = "#3b82f6",
    val role: String = "Sürücü",
    val phone: String = "",
    val email: String = "",
    val license: String = "",
    val licenseNo: String = "",
    val employeeNo: String = "",
    val vehicle: String = "",
    val lastVehicle: String = "",
    val model: String = "",
    val city: String = "",
    val vehicleCount: Int = 0,
    val status: String = "offline",
    val profileStatus: String = "no_profile",
    val hasProfile: Boolean = false,
    val profileId: Int? = null,
    val notes: String = "",
    val hiredAt: String? = null,
    val scoreGeneral: Int = 0,
    val scoreSpeed: Int = 0,
    val scoreBrake: Int = 0,
    val scoreFuel: Int = 0,
    val scoreSafety: Int = 0,
    val totalDistanceKm: Double = 0.0,
    val tripCount: Int = 0,
    val overspeedCount: Int = 0,
    val alarmCount: Int = 0,
    val hasTelemetry: Boolean = false,
    val createdAt: String? = null,
    val vehicleStatus: String = ""
) {
    val initials: String get() {
        val parts = name.split(" ")
        return if (parts.size >= 2) "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
        else name.take(2).uppercase()
    }

    /** Sürücüye atanmış aracın durumuna göre renk: araç online/idle ise yeşil/sarı, değilse sürücü statüsü */
    val statusColor: Color get() {
        // Araç durumu varsa onu kullan
        if (vehicleStatus.isNotEmpty()) {
            return when (vehicleStatus) {
                "online" -> AppColors.Online
                "idle" -> AppColors.Idle
                else -> AppColors.Offline
            }
        }
        // Fallback: sürücü kendi statüsü
        return when (status) {
            "online" -> AppColors.Online
            "idle" -> AppColors.Idle
            else -> AppColors.Offline
        }
    }

    val scoreColor: Color get() = when {
        scoreGeneral >= 85 -> AppColors.Online
        scoreGeneral >= 70 -> AppColors.Idle
        else -> AppColors.Offline
    }

    val avatarColor: Color get() {
        return try {
            val hex = color.removePrefix("#")
            val int = hex.toLong(16)
            Color(red = ((int shr 16) and 0xFF) / 255f, green = ((int shr 8) and 0xFF) / 255f, blue = (int and 0xFF) / 255f)
        } catch (_: Exception) { Color.Blue }
    }

    companion object {
        fun fromJson(json: JSONObject): Driver {
            val metrics = json.optJSONObject("metrics")
            return Driver(
                id = json.optString("id", ""),
                driverCode = json.optString("driverCode", ""),
                name = json.optString("name", ""),
                avatar = json.optString("avatar", ""),
                color = json.optString("color", "#3b82f6"),
                role = json.optString("role", "Sürücü"),
                phone = json.optString("phone", ""),
                email = json.optString("email", ""),
                license = json.optString("license", ""),
                licenseNo = json.optString("licenseNo", ""),
                employeeNo = json.optString("employeeNo", ""),
                vehicle = json.optString("vehicle", ""),
                lastVehicle = json.optString("lastVehicle", ""),
                model = json.optString("model", ""),
                city = json.optString("city", ""),
                vehicleCount = json.optInt("vehicleCount", 0),
                status = json.optString("status", "offline"),
                profileStatus = json.optString("profileStatus", "no_profile"),
                hasProfile = json.optBoolean("hasProfile", false),
                profileId = if (json.has("profileId") && !json.isNull("profileId")) json.optInt("profileId") else null,
                notes = json.optString("notes", ""),
                hiredAt = if (json.has("hiredAt") && !json.isNull("hiredAt")) json.optString("hiredAt") else null,
                scoreGeneral = json.optInt("scoreGeneral", 0),
                scoreSpeed = json.optInt("scoreSpeed", 0),
                scoreBrake = json.optInt("scoreBrake", 0),
                scoreFuel = json.optInt("scoreFuel", 0),
                scoreSafety = json.optInt("scoreSafety", 0),
                totalDistanceKm = json.optDouble("totalDistanceKm", 0.0),
                tripCount = json.optInt("tripCount", 0),
                overspeedCount = json.optInt("overspeedCount", 0),
                alarmCount = json.optInt("alarmCount", 0),
                hasTelemetry = json.optBoolean("hasTelemetry", false),
                createdAt = json.optString("created_at", null),
                vehicleStatus = run {
                    val cv = json.optJSONArray("currentVehicles")
                    if (cv != null && cv.length() > 0) cv.getJSONObject(0).optString("status", "") else ""
                }
            )
        }
    }
}

data class DriverStats(
    val total: Int = 0,
    val active: Int = 0,
    val tracked: Int = 0,
    val good: Int = 0,
    val mid: Int = 0,
    val low: Int = 0
)

data class DriversResponse(
    val drivers: List<Driver> = emptyList(),
    val stats: DriverStats = DriverStats()
)

data class CatalogVehicle(
    val id: Int,
    val imei: String,
    val plate: String,
    val name: String
)
