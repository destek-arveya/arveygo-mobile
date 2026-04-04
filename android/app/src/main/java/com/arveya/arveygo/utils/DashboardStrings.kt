package com.arveya.arveygo.utils

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dashboard page localization strings – TR/EN/ES/FR
 */
object DashboardStrings {
    private val _currentLang = MutableStateFlow("TR")
    val currentLang: StateFlow<String> = _currentLang

    private var appContext: Context? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
        val saved = context.getSharedPreferences("arveygo_prefs", Context.MODE_PRIVATE)
            .getString("app_lang", "TR") ?: "TR"
        _currentLang.value = saved
    }

    fun setLanguage(lang: String) {
        _currentLang.value = lang
        appContext?.getSharedPreferences("arveygo_prefs", Context.MODE_PRIVATE)
            ?.edit()?.putString("app_lang", lang)?.apply()
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
    val appInfoApp: String get() = s("Uygulama", "Application", "Aplicación", "Application")
    val appInfoPlatform: String get() = s("Platform", "Platform", "Plataforma", "Plateforme")
    val appInfoDeveloper: String get() = s("Geliştirici", "Developer", "Desarrollador", "Développeur")
    val legalTitle: String get() = s("Yasal", "Legal", "Legal", "Légal")
    val termsOfUse: String get() = s("Kullanım Koşulları", "Terms of Use", "Términos de Uso", "Conditions d'utilisation")
    val privacyPolicy: String get() = s("Gizlilik Politikası", "Privacy Policy", "Política de Privacidad", "Politique de confidentialité")
    val allRightsReserved: String get() = s("Tüm hakları saklıdır.", "All rights reserved.", "Todos los derechos reservados.", "Tous droits réservés.")
    val notificationSettings: String get() = s("Bildirim Ayarları", "Notification Settings", "Configuración de Notificaciones", "Paramètres de notifications")
    val notificationSettingsSubtitle: String get() = s("Push, kategoriler, sessiz saatler", "Push, categories, quiet hours", "Push, categorías, horas silenciosas", "Push, catégories, heures silencieuses")

    // Sidebar menu sections
    val menuSectionMain: String get() = s("ANA MENÜ", "MAIN MENU", "MENÚ PRINCIPAL", "MENU PRINCIPAL")
    val menuSectionFleet: String get() = s("FİLO YÖNETİMİ", "FLEET MANAGEMENT", "GESTIÓN DE FLOTA", "GESTION DE FLOTTE")
    val menuSectionMonitor: String get() = s("İZLEME", "MONITORING", "MONITOREO", "SURVEILLANCE")
    val menuSectionSettings: String get() = s("AYARLAR", "SETTINGS", "CONFIGURACIÓN", "PARAMÈTRES")
    val menuSectionSupport: String get() = s("DESTEK", "SUPPORT", "SOPORTE", "ASSISTANCE")

    // Sidebar menu items
    val menuDashboard: String get() = s("Dashboard", "Dashboard", "Panel", "Tableau de bord")
    val menuLiveMap: String get() = s("Canlı Harita", "Live Map", "Mapa en Vivo", "Carte en Direct")
    val menuRouteHistory: String get() = s("Rota Geçmişi", "Route History", "Historial de Rutas", "Historique des Trajets")
    val menuVehicles: String get() = s("Araçlar", "Vehicles", "Vehículos", "Véhicules")
    val menuDrivers: String get() = s("Sürücüler", "Drivers", "Conductores", "Conducteurs")
    val menuMaintenance: String get() = s("Bakım / Belgeler / Masraflar", "Maintenance / Docs / Expenses", "Mantenimiento / Docs / Gastos", "Maintenance / Docs / Dépenses")
    val menuAlarms: String get() = s("Alarmlar", "Alarms", "Alarmas", "Alarmes")
    val menuGeofence: String get() = s("Geofence", "Geofence", "Geocerca", "Géofence")
    val menuReports: String get() = s("Raporlar", "Reports", "Informes", "Rapports")
    val menuSettings: String get() = s("Ayarlar", "Settings", "Configuración", "Paramètres")
    val menuSupport: String get() = s("Destek Talebi", "Support Request", "Solicitud de Soporte", "Demande d'assistance")
    val menuLogout: String get() = s("Çıkış Yap", "Log Out", "Cerrar Sesión", "Se déconnecter")
    val menuCompany: String get() = s("Arveya Teknoloji", "Arveya Technology", "Arveya Tecnología", "Arveya Technologie")

    fun t(tr: String, en: String, es: String, fr: String): String = s(tr, en, es, fr)

    // ---------- Helper ----------
    private fun s(tr: String, en: String, es: String, fr: String): String =
        when (_currentLang.value) {
            "EN" -> en
            "ES" -> es
            "FR" -> fr
            else -> tr
        }
}
