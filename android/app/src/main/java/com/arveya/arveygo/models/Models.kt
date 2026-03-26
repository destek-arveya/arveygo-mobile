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
    ONLINE("online"),
    OFFLINE("offline"),
    IDLE("idle");

    val color: Color
        get() = when (this) {
            ONLINE -> AppColors.Online
            OFFLINE -> AppColors.Offline
            IDLE -> AppColors.Idle
        }

    val label: String
        get() = when (this) {
            ONLINE -> "Aktif"
            OFFLINE -> "Çevrimdışı"
            IDLE -> "Rölanti"
        }

    val icon: String
        get() = when (this) {
            ONLINE -> "check_circle"
            OFFLINE -> "cancel"
            IDLE -> "pause_circle"
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
    var temperatureC: Double? = null,
    var humidityPct: Double? = null,
    var odometer: Double = 0.0,
    var speedLimit: Int = 0,
    var driverId: String? = null,
    var alarmCode: String? = null,
    var deviceTime: String? = null,
    var ts: Int = 0,
    var deviceId: Int = 0,
    // Ignition timestamps (from WebSocket)
    var firstIgnitionOnAtToday: String? = null,
    var lastIgnitionOnAt: String? = null,
    var lastIgnitionOffAt: String? = null
) {
    val isMotorcycle: Boolean get() = vehicleCategory == "motorcycle"

    val formattedTotalKm: String
        get() {
            val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR"))
            return fmt.format(totalKm)
        }

    val formattedTodayKm: String get() = "$todayKm km"

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
            VehicleStatus.ONLINE -> FleetVehicleStatus.ACTIVE
            VehicleStatus.OFFLINE -> FleetVehicleStatus.PASSIVE
            VehicleStatus.IDLE -> FleetVehicleStatus.MAINTENANCE
        }

    val group: String
        get() = when (city) {
            "İstanbul" -> "İstanbul Filo"
            "Ankara" -> "Ankara Filo"
            "İzmir" -> "İzmir Filo"
            else -> "Diğer"
        }

    val vehicleType: String
        get() = when {
            vehicleCategory == "motorcycle" -> "Motosiklet"
            model.contains("Transit") || model.contains("Sprinter") -> "Panelvan"
            model.contains("Crafter") || model.contains("Master") -> "Kamyonet"
            else -> "Ticari"
        }

    val lastService: String
        get() {
            val dates = listOf("12.01.2026","28.11.2025","05.02.2026","18.12.2025","22.01.2026","10.10.2025","01.03.2026","15.11.2025")
            val idx = id.toIntOrNull()
            return if (idx != null && idx in 1..dates.size) dates[idx - 1] else "—"
        }

    val nextService: String
        get() {
            val dates = listOf("12.04.2026","28.02.2026","05.05.2026","18.03.2026","22.04.2026","10.01.2026 ⚠","01.06.2026","15.02.2026")
            val idx = id.toIntOrNull()
            return if (idx != null && idx in 1..dates.size) dates[idx - 1] else "—"
        }

    val muayeneDate: String
        get() {
            val dates = listOf("15.06.2026","03.04.2026","20.08.2026","12.05.2026","28.07.2026","01.03.2026 ⚠","10.09.2026","05.04.2026")
            val idx = id.toIntOrNull()
            return if (idx != null && idx in 1..dates.size) dates[idx - 1] else "—"
        }

    val insuranceDate: String
        get() {
            val dates = listOf("01.07.2026","15.05.2026","10.09.2026","22.06.2026","30.08.2026","05.04.2026","20.10.2026","12.05.2026")
            val idx = id.toIntOrNull()
            return if (idx != null && idx in 1..dates.size) dates[idx - 1] else "—"
        }

    val recentCosts: List<VehicleCost>
        get() = listOf(
            VehicleCost("c1", "Yakıt", "15.03.2026", "₺2.450"),
            VehicleCost("c2", "Bakım", "12.03.2026", "₺1.850"),
            VehicleCost("c3", "Sigorta", "01.03.2026", "₺4.200"),
        )

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
            val speedLimit = json.optInt("speed_limit", 0)
            val companyId = json.optInt("company_id", 0)
            val driverId = if (json.has("driver_id")) json.optString("driver_id") else null
            val alarmCode = if (json.has("alarm_code")) json.optString("alarm_code") else null
            val deviceTime = if (json.has("device_time")) json.optString("device_time") else null
            val ts = json.optInt("ts", 0)
            val deviceIdValue = if (json.has("id") && !json.isNull("id")) json.optInt("id", 0) else json.optInt("deviceId", 0)
            val firstIgnitionOnAtToday = if (json.has("first_ignition_on_at_today")) json.optString("first_ignition_on_at_today") else null
            val lastIgnitionOnAt = if (json.has("last_ignition_on_at")) json.optString("last_ignition_on_at") else null
            val lastIgnitionOffAt = if (json.has("last_ignition_off_at")) json.optString("last_ignition_off_at") else null
            val batteryVoltage = if (json.has("battery_voltage")) json.optDouble("battery_voltage") else null
            val externalVoltage = if (json.has("external_voltage")) json.optDouble("external_voltage") else null
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

            // Match web backend's 4-condition status logic
            val status = when {
                !isOnline -> VehicleStatus.OFFLINE
                ignition && speed > 5 -> VehicleStatus.ONLINE
                ignition -> VehicleStatus.IDLE
                else -> VehicleStatus.OFFLINE
            }

            return Vehicle(
                id = imei, plate = plate, model = name, status = status,
                kontakOn = ignition, totalKm = odometer.toInt(), todayKm = speed.toInt(),
                driver = driverId ?: "", city = "", lat = lat, lng = lon,
                vehicleCategory = vehicleCategory,
                imei = imei, companyId = companyId, name = name,
                speed = speed, direction = direction, ignition = ignition,
                isOnline = isOnline, fix = fix, hdop = hdop,
                input1 = input1, input2 = input2, output = output,
                batteryVoltage = batteryVoltage, externalVoltage = externalVoltage,
                temperatureC = temperatureC, humidityPct = humidityPct,
                odometer = odometer, speedLimit = speedLimit,
                driverId = driverId, alarmCode = alarmCode,
                deviceTime = deviceTime, ts = ts,
                firstIgnitionOnAtToday = firstIgnitionOnAtToday,
                lastIgnitionOnAt = lastIgnitionOnAt,
                lastIgnitionOffAt = lastIgnitionOffAt,
                deviceId = deviceIdValue
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
            todayKm = patch.speed.toInt(),
            deviceTime = patch.deviceTime ?: deviceTime,
            ts = if (patch.ts > 0) patch.ts else ts,
            fix = patch.fix, hdop = patch.hdop,
            input1 = patch.input1, input2 = patch.input2, output = patch.output,
            batteryVoltage = patch.batteryVoltage ?: batteryVoltage,
            externalVoltage = patch.externalVoltage ?: externalVoltage,
            temperatureC = patch.temperatureC ?: temperatureC,
            humidityPct = patch.humidityPct ?: humidityPct,
            driverId = patch.driverId ?: driverId,
            alarmCode = patch.alarmCode ?: alarmCode,
            firstIgnitionOnAtToday = patch.firstIgnitionOnAtToday ?: firstIgnitionOnAtToday,
            lastIgnitionOnAt = patch.lastIgnitionOnAt ?: lastIgnitionOnAt,
            lastIgnitionOffAt = patch.lastIgnitionOffAt ?: lastIgnitionOffAt,
            vehicleCategory = if (patch.vehicleCategory != "car") patch.vehicleCategory else vehicleCategory,
            deviceId = if (patch.deviceId > 0) patch.deviceId else deviceId
        )
    }
}

// MARK: - Fleet Vehicle Status
enum class FleetVehicleStatus(val label: String, val color: Color) {
    ACTIVE("Aktif", AppColors.Online),
    PASSIVE("Pasif", Color(0xFF94A3B8)),
    MAINTENANCE("Bakımda", AppColors.Idle)
}

// MARK: - Vehicle Cost
data class VehicleCost(val id: String, val category: String, val date: String, val amount: String)

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
    val createdAt: String? = null
) {
    val initials: String get() {
        val parts = name.split(" ")
        return if (parts.size >= 2) "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
        else name.take(2).uppercase()
    }

    val statusColor: Color get() = when (status) {
        "online" -> AppColors.Online
        "idle" -> AppColors.Idle
        else -> AppColors.Offline
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
                createdAt = json.optString("created_at", null)
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
