package com.arveya.arveygo.ui.screens.fleet

import com.arveya.arveygo.services.APIService
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject

data class AlarmDuplicateMatch(
    val id: Int,
    val name: String,
    val status: String,
) {
    val statusLabel: String
        get() = when (status) {
            "active" -> "aktif"
            "paused" -> "duraklatildi"
            "draft" -> "taslak"
            "archived" -> "arsiv"
            else -> status
        }
}

private data class AlarmRuleSignature(
    val description: String?,
    val alarmType: String,
    val evaluationMode: String,
    val sourceMode: String,
    val cooldownSec: Int,
    val startsAt: String?,
    val endsAt: String?,
    val conditionsJson: String,
    val targetsJson: String,
    val channelsJson: String,
    val recipientsJson: String,
) {
    val cacheKey: String
        get() = listOf(
            description ?: "",
            alarmType,
            evaluationMode,
            sourceMode,
            cooldownSec.toString(),
            startsAt ?: "",
            endsAt ?: "",
            conditionsJson,
            targetsJson,
            channelsJson,
            recipientsJson,
        ).joinToString("|")
}

private data class AlarmRuleSnapshot(
    val id: Int,
    val name: String,
    val status: String,
    val updatedAt: String,
    val signature: AlarmRuleSignature,
)

private data class CachedAlarmSnapshot(
    val updatedAt: String,
    val snapshot: AlarmRuleSnapshot,
)

object AlarmDuplicateGuard {
    private val mutex = Mutex()
    private var summaries: List<AlarmSet> = emptyList()
    private var detailCache: MutableMap<Int, CachedAlarmSnapshot> = mutableMapOf()
    private var lastSummaryRefreshMs: Long = 0L
    private const val SUMMARY_TTL_MS = 90_000L

    suspend fun invalidate() = mutex.withLock {
        summaries = emptyList()
        detailCache.clear()
        lastSummaryRefreshMs = 0L
    }

    suspend fun duplicateMatch(
        body: JSONObject,
        ignoreId: Int? = null,
        forceRefresh: Boolean = false,
    ): AlarmDuplicateMatch? = duplicateMatch(
        snapshot = body.toCreateAlarmRuleSnapshot(),
        ignoreId = ignoreId,
        forceRefresh = forceRefresh,
    )

    private suspend fun duplicateMatch(
        snapshot: AlarmRuleSnapshot,
        ignoreId: Int? = null,
        forceRefresh: Boolean = false,
    ): AlarmDuplicateMatch? {
        val signature = snapshot.signature
        val loadedSummaries = loadSummaries(forceRefresh)
        loadedSummaries.forEach { summary ->
            if (ignoreId != null && summary.id == ignoreId) return@forEach
            val existing = loadSnapshot(summary)
            if (existing.signature == signature) {
                return AlarmDuplicateMatch(existing.id, existing.name, existing.status)
            }
        }
        return null
    }

    private suspend fun loadSummaries(forceRefresh: Boolean): List<AlarmSet> {
        mutex.withLock {
            val now = System.currentTimeMillis()
            if (!forceRefresh && summaries.isNotEmpty() && now - lastSummaryRefreshMs < SUMMARY_TTL_MS) {
                return summaries
            }
        }

        val loaded = mutableListOf<AlarmSet>()
        var page = 1
        var lastPage = 1

        do {
            val json = APIService.get("/api/mobile/alarm-sets/?page=$page")
            val data = json.optJSONArray("data") ?: JSONArray()
            for (index in 0 until data.length()) {
                loaded += AlarmSet.from(data.optJSONObject(index) ?: JSONObject())
            }
            lastPage = json.optJSONObject("pagination")?.optInt("last_page", 1) ?: 1
            page += 1
        } while (page <= lastPage)

        mutex.withLock {
            summaries = loaded
            lastSummaryRefreshMs = System.currentTimeMillis()
        }

        return loaded
    }

    private suspend fun loadSnapshot(summary: AlarmSet): AlarmRuleSnapshot {
        mutex.withLock {
            val cached = detailCache[summary.id]
            if (cached != null && cached.updatedAt == summary.updatedAt) {
                return cached.snapshot
            }
        }

        val json = APIService.get("/api/mobile/alarm-sets/${summary.id}")
        val snapshot = (json.optJSONObject("data") ?: JSONObject()).toExistingAlarmRuleSnapshot()

        mutex.withLock {
            detailCache[summary.id] = CachedAlarmSnapshot(summary.updatedAt, snapshot)
        }

        return snapshot
    }
}

private fun JSONObject.toExistingAlarmRuleSnapshot(): AlarmRuleSnapshot {
    val alarmType = optString("alarm_type", "")
    return AlarmRuleSnapshot(
        id = optInt("id", 0),
        name = optString("name", ""),
        status = optString("status", "draft"),
        updatedAt = optString("updated_at", ""),
        signature = AlarmRuleSignature(
            description = optNullableString("description"),
            alarmType = alarmType,
            evaluationMode = optString("evaluation_mode", "live"),
            sourceMode = optString("source_mode", "derived"),
            cooldownSec = optInt("cooldown_sec", 300),
            startsAt = optNullableString("starts_at"),
            endsAt = optNullableString("ends_at"),
            conditionsJson = canonicalJson(normalizedExistingConditions(optJSONObject("conditions") ?: JSONObject(), alarmType)),
            targetsJson = canonicalJson(normalizedTargets(optJSONArray("targets") ?: JSONArray())),
            channelsJson = canonicalJson(normalizedChannels(optJSONArray("channels"))),
            recipientsJson = canonicalJson(normalizedExistingRecipients(optJSONArray("recipients"))),
        ),
    )
}

private fun JSONObject.toCreateAlarmRuleSnapshot(): AlarmRuleSnapshot {
    val alarmType = optString("alarm_type", "")
    return AlarmRuleSnapshot(
        id = optInt("id", 0),
        name = optString("name", ""),
        status = optString("status", "active"),
        updatedAt = optString("updated_at", ""),
        signature = AlarmRuleSignature(
            description = optNullableString("description"),
            alarmType = alarmType,
            evaluationMode = optString("evaluation_mode", "live"),
            sourceMode = optString("source_mode", "derived"),
            cooldownSec = optInt("cooldown_sec", 300),
            startsAt = optNullableString("starts_at"),
            endsAt = optNullableString("ends_at"),
            conditionsJson = canonicalJson(normalizedRequestConditions(this, alarmType)),
            targetsJson = canonicalJson(normalizedTargets(optJSONArray("targets") ?: JSONArray())),
            channelsJson = canonicalJson(normalizedChannels(optJSONArray("channels"))),
            recipientsJson = canonicalJson(normalizedRecipientIds(optJSONArray("recipient_ids"))),
        ),
    )
}

private fun JSONObject.optNullableString(key: String): String? =
    optString(key, "").trim().takeIf { it.isNotEmpty() }

private fun normalizedTargets(array: JSONArray): List<Map<String, Any>> =
    buildList {
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val scope = item.optString("scope", "")
            val id = item.optInt("id", 0)
            if (scope.isNotBlank() && id > 0) {
                add(mapOf("scope" to scope, "id" to id))
            }
        }
    }.sortedWith(compareBy<Map<String, Any>> { it["scope"].toString() }.thenBy { it["id"] as Int })

private fun normalizedChannels(array: JSONArray?): List<String> {
    if (array == null) return emptyList()
    return buildSet {
        for (index in 0 until array.length()) {
            val value = array.optString(index, "").trim()
            if (value.isNotEmpty()) add(value)
        }
    }.sorted()
}

private fun normalizedRecipientIds(array: JSONArray?): List<Int> {
    if (array == null) return emptyList()
    return buildSet {
        for (index in 0 until array.length()) {
            val value = array.optInt(index, 0)
            if (value > 0) add(value)
        }
    }.sorted()
}

private fun normalizedExistingRecipients(array: JSONArray?): List<Int> {
    if (array == null) return emptyList()
    return buildSet {
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optBoolean("is_active", true)) {
                val value = item.optInt("id", item.optInt("user_id", 0))
                if (value > 0) add(value)
            }
        }
    }.sorted()
}

private fun csvValues(raw: String?): List<String> =
    raw.orEmpty()
        .split(",")
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .sorted()

private fun normalizedRequestConditions(json: JSONObject, alarmType: String): Map<String, Any> =
    when (alarmType) {
        "speed_violation" -> mapOf(
            "native_alarm_codes" to csvValues(json.optString("condition_native_alarm_codes", "")),
            "native_alarm_categories" to csvValues(json.optString("condition_native_alarm_categories", "")),
            "speed_limit_kmh" to json.optInt("condition_speed_limit_kmh", json.optInt("condition_speed_threshold_kmh", 120)),
            "speed_duration_sec" to json.optInt("condition_speed_duration_sec", 30),
        )

        "movement_detection" -> mapOf(
            "native_alarm_codes" to csvValues(json.optString("condition_native_alarm_codes", "")),
            "native_alarm_categories" to csvValues(json.optString("condition_native_alarm_categories", "")),
            "motion_sensitivity" to json.optString("condition_motion_sensitivity", "medium"),
            "motion_duration_sec" to json.optInt("condition_motion_duration_sec", 5),
        )

        "idle_alarm" -> mapOf(
            "idle_after_sec" to json.optInt("condition_idle_after_sec", 300),
            "speed_threshold_kmh" to json.optInt("condition_speed_threshold_kmh", 0),
            "require_ignition" to json.optBoolean("condition_require_ignition", true),
        )

        "off_hours_usage" -> {
            val days = normalizedRecipientIds(json.optJSONArray("condition_days")).filter { it in 1..7 }
            mapOf(
                "timezone" to json.optString("condition_timezone", "Europe/Istanbul"),
                "days" to days.distinct().sorted(),
                "start_local" to json.optString("condition_start_local", "08:00"),
                "end_local" to json.optString("condition_end_local", "18:00"),
                "require_ignition" to json.optBoolean("condition_require_ignition", true),
                "min_speed_kmh" to json.optInt("condition_min_speed_kmh", 1),
            )
        }

        "geofence_alarm" -> mapOf(
            "geofence_id" to json.optInt("condition_geofence_id", 0),
            "geofence_trigger" to json.optString("condition_geofence_trigger", "both"),
        )

        else -> emptyMap()
    }

private fun normalizedExistingConditions(json: JSONObject, alarmType: String): Map<String, Any> =
    when (alarmType) {
        "speed_violation" -> mapOf(
            "native_alarm_codes" to csvJsonValues(json.optJSONArray("native_alarm_codes")),
            "native_alarm_categories" to csvJsonValues(json.optJSONArray("native_alarm_categories")),
            "speed_limit_kmh" to json.optInt("speed_limit_kmh", 120),
            "speed_duration_sec" to json.optInt("speed_duration_sec", 30),
        )

        "movement_detection" -> mapOf(
            "native_alarm_codes" to csvJsonValues(json.optJSONArray("native_alarm_codes")),
            "native_alarm_categories" to csvJsonValues(json.optJSONArray("native_alarm_categories")),
            "motion_sensitivity" to json.optString("motion_sensitivity", "medium"),
            "motion_duration_sec" to json.optInt("motion_duration_sec", 5),
        )

        "idle_alarm" -> mapOf(
            "idle_after_sec" to json.optInt("idle_after_sec", 300),
            "speed_threshold_kmh" to json.optInt("speed_threshold_kmh", 0),
            "require_ignition" to json.optBoolean("require_ignition", true),
        )

        "off_hours_usage" -> {
            val days = normalizedRecipientIds(json.optJSONArray("days")).filter { it in 1..7 }
            mapOf(
                "timezone" to json.optString("timezone", "Europe/Istanbul"),
                "days" to days.distinct().sorted(),
                "start_local" to json.optString("start_local", "08:00"),
                "end_local" to json.optString("end_local", "18:00"),
                "require_ignition" to json.optBoolean("require_ignition", true),
                "min_speed_kmh" to json.optInt("min_speed_kmh", 1),
            )
        }

        "geofence_alarm" -> mapOf(
            "geofence_id" to json.optInt("geofence_id", 0),
            "geofence_trigger" to json.optString("geofence_trigger", "both"),
        )

        else -> emptyMap()
    }

private fun csvJsonValues(array: JSONArray?): List<String> {
    if (array == null) return emptyList()
    return buildList {
        for (index in 0 until array.length()) {
            val value = array.optString(index, "").trim()
            if (value.isNotEmpty()) add(value)
        }
    }.sorted()
}

private fun canonicalJson(value: Any?): String =
    when (value) {
        null -> "null"
        is Map<*, *> -> value.keys.mapNotNull { it as? String }.sorted().joinToString(
            prefix = "{",
            postfix = "}",
            separator = ",",
        ) { key -> "\"$key\":${canonicalJson(value[key])}" }

        is List<*> -> value.joinToString(prefix = "[", postfix = "]", separator = ",") { canonicalJson(it) }
        is String -> "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""
        else -> value.toString()
    }
