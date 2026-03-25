package com.arveya.arveygo.utils

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dashboard page localization strings – TR/EN/ES/FR
 */
object DashboardStrings {
    private val _currentLang = MutableStateFlow("TR")
    val currentLang: StateFlow<String> = _currentLang

    fun setLanguage(lang: String) {
        _currentLang.value = lang
    }

    // Navigation
    val title: String get() = s("Dashboard", "Dashboard", "Panel", "Tableau de bord")
    val subtitle: String get() = s("Filo Yönetim Paneli", "Fleet Management Panel", "Panel de Gestión de Flota", "Panneau de Gestion de Flotte")

    // Welcome
    fun welcomeMsg(name: String): String = s("Hoş Geldiniz, $name", "Welcome, $name", "Bienvenido, $name", "Bienvenue, $name")
    val welcomeSubtitle: String get() = s("Filonuzun son durumunu görüntüleyin", "View your fleet's latest status", "Vea el estado más reciente de su flota", "Consultez le dernier état de votre flotte")
    fun kontakOnChip(n: Int): String = s("$n Kontak Açık", "$n Ignition On", "$n Encendido", "$n Contact On")
    fun kontakOffChip(n: Int): String = s("$n Kontak Kapalı", "$n Ignition Off", "$n Apagado", "$n Contact Off")
    fun bilgiYokChip(n: Int): String = s("$n Bilgi Yok", "$n No Data", "$n Sin Datos", "$n Pas de Données")

    // Period
    val periodToday: String get() = s("Bugün", "Today", "Hoy", "Aujourd'hui")
    val periodWeek: String get() = s("Hafta", "Week", "Semana", "Semaine")
    val periodMonth: String get() = s("Ay", "Month", "Mes", "Mois")
    val periodYear: String get() = s("Yıl", "Year", "Año", "Année")

    // Cards
    val activeVehicles: String get() = s("Aktif Araçlar", "Active Vehicles", "Vehículos Activos", "Véhicules Actifs")
    val allLabel: String get() = s("Tümü", "All", "Todos", "Tous")
    val driverPerformance: String get() = s("Sürücü Performansı", "Driver Performance", "Rendimiento del Conductor", "Performance Conducteur")
    val detailLabel: String get() = s("Detay", "Detail", "Detalle", "Détail")
    val recentAlarms: String get() = s("Son Alarmlar", "Recent Alarms", "Alarmas Recientes", "Alarmes Récentes")
    val aiInsights: String get() = s("AI Filo İçgörüleri", "AI Fleet Insights", "Insights AI de Flota", "Insights IA de Flotte")

    // Settings
    val settingsTitle: String get() = s("Ayarlar", "Settings", "Configuración", "Paramètres")
    val languageLabel: String get() = s("Dil", "Language", "Idioma", "Langue")
    val appInfoTitle: String get() = s("Uygulama Bilgisi", "App Info", "Info de la App", "Info de l'App")

    // ---------- Helper ----------
    private fun s(tr: String, en: String, es: String, fr: String): String =
        when (_currentLang.value) {
            "EN" -> en
            "ES" -> es
            "FR" -> fr
            else -> tr
        }
}
