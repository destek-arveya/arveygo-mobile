package com.arveya.arveygo.utils

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dashboard page localization strings – TR/EN
 */
object DashboardStrings {
    private val _currentLang = MutableStateFlow("TR")
    val currentLang: StateFlow<String> = _currentLang

    fun setLanguage(lang: String) {
        _currentLang.value = lang
    }

    // Navigation
    val title: String get() = s("Dashboard", "Dashboard")
    val subtitle: String get() = s("Filo Yönetim Paneli", "Fleet Management Panel")

    // Welcome
    fun welcomeMsg(name: String): String = s("Hoş Geldiniz, $name", "Welcome, $name")
    val welcomeSubtitle: String get() = s("Filonuzun son durumunu görüntüleyin", "View your fleet's latest status")
    fun kontakOnChip(n: Int): String = s("$n Kontak Açık", "$n Ignition On")
    fun kontakOffChip(n: Int): String = s("$n Kontak Kapalı", "$n Ignition Off")
    fun bilgiYokChip(n: Int): String = s("$n Bilgi Yok", "$n No Data")

    // Period
    val periodToday: String get() = s("Bugün", "Today")
    val periodWeek: String get() = s("Hafta", "Week")
    val periodMonth: String get() = s("Ay", "Month")
    val periodYear: String get() = s("Yıl", "Year")

    // Cards
    val activeVehicles: String get() = s("Aktif Araçlar", "Active Vehicles")
    val allLabel: String get() = s("Tümü", "All")
    val driverPerformance: String get() = s("Sürücü Performansı", "Driver Performance")
    val detailLabel: String get() = s("Detay", "Detail")
    val recentAlarms: String get() = s("Son Alarmlar", "Recent Alarms")
    val aiInsights: String get() = s("AI Filo İçgörüleri", "AI Fleet Insights")

    // ---------- Helper ----------
    private fun s(tr: String, en: String): String =
        if (_currentLang.value == "TR") tr else en
}
