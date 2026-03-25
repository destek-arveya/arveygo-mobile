package com.arveya.arveygo.services

/**
 * App Configuration — matches iOS AppConfig.swift
 */
object AppConfig {
    // API / Backend
    const val API_BASE_URL = "https://demo.arveygo.com"

    // ATS WebSocket
    const val WS_URL = "wss://websocket.arveygo.com/ws"
    const val WS_URL_FALLBACK = "ws://77.245.158.21:8765/ws"

    // HS-256 shared secret — must match server's ATS_WS_SECRET
    const val WS_JWT_SECRET = "9af6e20fa3ad924f86e24905148a404523b219c50be3cc16e4b6e7dff53b7bb2"

    // JWT time-to-live in seconds (default 1 hour)
    const val WS_JWT_TTL = 3600

    // Ping interval in seconds
    const val WS_PING_INTERVAL = 30L

    // Snapshot timeout — reconnect if no snapshot within this duration
    const val WS_SNAPSHOT_TIMEOUT = 12L

    // Max reconnect delay in seconds
    const val WS_MAX_RECONNECT_DELAY = 30L
}
