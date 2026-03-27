import Foundation
import Security

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(String)
    case networkError(Error)
    case unauthorized
    case validationError([String: [String]])

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz URL"
        case .httpError(let code, let msg):
            return msg ?? "HTTP \(code)"
        case .decodingError(let msg):
            return "Veri hatası: \(msg)"
        case .networkError(let err):
            return err.localizedDescription
        case .unauthorized:
            return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        case .validationError(let errors):
            return errors.values.flatMap { $0 }.first ?? "Doğrulama hatası"
        }
    }
}

// MARK: - Response Models
struct LoginResponse {
    let accessToken: String
    let tokenType: String
    let user: AppUser
}

struct MeResponse {
    let user: AppUser
}

struct WSConfig {
    let url: String
    let token: String
    let pingInterval: Int
}

// MARK: - API Service
/// Handles communication with the Laravel backend via Bearer token auth.
/// Endpoints: /api/mobile/auth/{login,me,refresh,logout}
final class APIService {

    static let shared = APIService()

    /// Callback invoked on main thread when a 401 is detected — triggers auto-logout
    var onSessionExpired: (() -> Void)?

    private let baseURL: String
    private let session: URLSession

    /// Current Bearer token — persisted in Keychain
    private(set) var accessToken: String? {
        didSet {
            if let token = accessToken {
                TokenStore.save(token: token)
            } else {
                TokenStore.delete()
            }
        }
    }

    private init() {
        baseURL = AppConfig.apiBaseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        // Restore saved token on launch
        accessToken = TokenStore.load()
    }

    // MARK: - Auth Endpoints

    /// POST /api/mobile/auth/login
    func login(email: String, password: String) async throws -> LoginResponse {
        let url = try makeURL("/api/mobile/auth/login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }

        if let httpResp = response as? HTTPURLResponse {
            switch httpResp.statusCode {
            case 200...299: break
            case 401:
                throw APIError.httpError(401, json["message"] as? String ?? "E-posta veya şifre hatalı")
            case 422:
                if let errors = json["errors"] as? [String: [String]] {
                    throw APIError.validationError(errors)
                }
                throw APIError.httpError(422, json["message"] as? String ?? "E-posta veya şifre hatalı")
            default:
                throw APIError.httpError(httpResp.statusCode, json["message"] as? String)
            }
        }

        guard let token = json["access_token"] as? String else {
            throw APIError.decodingError("access_token bulunamadı")
        }

        let tokenType = (json["token_type"] as? String) ?? "bearer"
        let user = parseUser(from: json)

        // Persist token
        self.accessToken = token

        print("[API] Login OK — token: \(token.prefix(20))…, user: \(user.name)")
        return LoginResponse(accessToken: token, tokenType: tokenType, user: user)
    }

    /// GET /api/mobile/auth/me
    func fetchMe() async throws -> AppUser {
        let url = try makeURL("/api/mobile/auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }
        return parseUser(from: json)
    }

    /// POST /api/mobile/auth/refresh
    func refreshToken() async throws -> String {
        let url = try makeURL("/api/mobile/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw APIError.decodingError("Yeni token alınamadı")
        }

        self.accessToken = newToken
        print("[API] Token refreshed")
        return newToken
    }

    /// POST /api/mobile/auth/logout
    func logout() async {
        guard let url = try? makeURL("/api/mobile/auth/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try? applyAuth(&request)
        _ = try? await session.data(for: request)
        self.accessToken = nil
        print("[API] Logged out, token cleared")
    }

    // MARK: - Generic Authenticated Requests

    /// GET any authenticated endpoint — returns JSON dict
    func get(_ path: String) async throws -> [String: Any] {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }
        return json
    }

    /// POST any authenticated endpoint — returns JSON dict
    func post(_ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }
        return json
    }

    /// PUT any authenticated endpoint
    func put(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }
        return json
    }

    /// DELETE any authenticated endpoint
    func httpDelete(_ path: String) async throws -> [String: Any] {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try applyAuth(&request)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }
        return json
    }

    // MARK: - Helpers

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        return url
    }

    private func applyAuth(_ request: inout URLRequest) throws {
        guard let token = accessToken else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1))
        }
        switch http.statusCode {
        case 200...299: return
        case 401:
            self.accessToken = nil
            DispatchQueue.main.async { [weak self] in
                self?.onSessionExpired?()
            }
            throw APIError.unauthorized
        case 422:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errors = json["errors"] as? [String: [String]] {
                throw APIError.validationError(errors)
            }
            throw APIError.httpError(422, "Doğrulama hatası")
        default:
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw APIError.httpError(http.statusCode, msg)
        }
    }

    private func parseUser(from json: [String: Any]) -> AppUser {
        let u = json["user"] as? [String: Any] ?? json
        let id = "\(u["id"] ?? "0")"
        let name = (u["name"] as? String) ?? "Kullanıcı"
        let email = (u["email"] as? String) ?? ""
        let role = (u["role_label"] as? String) ?? (u["role"] as? String) ?? ""
        let roleKey = (u["role_key"] as? String) ?? (u["role"] as? String) ?? ""
        let companyId = (u["company_id"] as? Int) ?? 1

        return AppUser(
            id: id,
            name: name,
            email: email,
            avatar: String(name.prefix(1).uppercased()),
            role: role,
            roleKey: roleKey,
            companyId: companyId
        )
    }

    /// Whether a stored token exists (for auto-login check)
    var hasStoredToken: Bool { accessToken != nil }

    /// Clear stored token without network call
    func clearToken() { self.accessToken = nil }

    // MARK: - Drivers

    /// GET /api/mobile/drivers
    func fetchDrivers() async throws -> DriversResponse {
        let json = try await get("/api/mobile/drivers")
        let driversArray = json["drivers"] as? [[String: Any]] ?? []
        let statsJson = json["stats"] as? [String: Any] ?? [:]

        let drivers = driversArray.compactMap { dict -> Driver? in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            let metrics = dict["metrics"] as? [String: Any] ?? [:]
            return Driver(
                id: id,
                driverCode: dict["driverCode"] as? String ?? "",
                name: name,
                avatar: dict["avatar"] as? String ?? "",
                color: dict["color"] as? String ?? "#3b82f6",
                role: dict["role"] as? String ?? "Sürücü",
                phone: dict["phone"] as? String ?? "",
                email: dict["email"] as? String ?? "",
                license: dict["license"] as? String ?? "",
                licenseNo: dict["licenseNo"] as? String ?? "",
                employeeNo: dict["employeeNo"] as? String ?? "",
                vehicle: dict["vehicle"] as? String ?? "",
                lastVehicle: dict["lastVehicle"] as? String ?? "",
                model: dict["model"] as? String ?? "",
                city: dict["city"] as? String ?? "",
                vehicleCount: dict["vehicleCount"] as? Int ?? 0,
                status: dict["status"] as? String ?? "offline",
                profileStatus: dict["profileStatus"] as? String ?? "no_profile",
                hasProfile: dict["hasProfile"] as? Bool ?? false,
                profileId: dict["profileId"] as? Int,
                notes: dict["notes"] as? String ?? "",
                hiredAt: dict["hiredAt"] as? String,
                scoreGeneral: dict["scoreGeneral"] as? Int ?? 0,
                scoreSpeed: dict["scoreSpeed"] as? Int ?? 0,
                scoreBrake: dict["scoreBrake"] as? Int ?? 0,
                scoreFuel: dict["scoreFuel"] as? Int ?? 0,
                scoreSafety: dict["scoreSafety"] as? Int ?? 0,
                totalDistanceKm: (dict["totalDistanceKm"] as? Double) ?? Double(dict["totalDistanceKm"] as? Int ?? 0),
                tripCount: dict["tripCount"] as? Int ?? 0,
                overspeedCount: dict["overspeedCount"] as? Int ?? 0,
                alarmCount: dict["alarmCount"] as? Int ?? 0,
                hasTelemetry: dict["hasTelemetry"] as? Bool ?? false,
                createdAt: dict["created_at"] as? String,
                vehicleStatus: {
                    if let cv = dict["currentVehicles"] as? [[String: Any]], let first = cv.first {
                        return first["status"] as? String ?? ""
                    }
                    return ""
                }()
            )
        }

        let stats = DriverStats(
            total: statsJson["total"] as? Int ?? 0,
            active: statsJson["active"] as? Int ?? 0,
            tracked: statsJson["tracked"] as? Int ?? 0,
            good: statsJson["good"] as? Int ?? 0,
            mid: statsJson["mid"] as? Int ?? 0,
            low: statsJson["low"] as? Int ?? 0
        )

        return DriversResponse(drivers: drivers, stats: stats)
    }

    /// GET /api/mobile/drivers/{id}
    func fetchDriver(id: String) async throws -> Driver? {
        let json = try await get("/api/mobile/drivers/\(id)")
        guard let dict = json["data"] as? [String: Any],
              let dId = dict["id"] as? String,
              let name = dict["name"] as? String else { return nil }
        let metrics = dict["metrics"] as? [String: Any] ?? [:]
        return Driver(
            id: dId,
            driverCode: dict["driverCode"] as? String ?? "",
            name: name,
            avatar: dict["avatar"] as? String ?? "",
            color: dict["color"] as? String ?? "#3b82f6",
            role: dict["role"] as? String ?? "Sürücü",
            phone: dict["phone"] as? String ?? "",
            email: dict["email"] as? String ?? "",
            license: dict["license"] as? String ?? "",
            licenseNo: dict["licenseNo"] as? String ?? "",
            employeeNo: dict["employeeNo"] as? String ?? "",
            vehicle: dict["vehicle"] as? String ?? "",
            lastVehicle: dict["lastVehicle"] as? String ?? "",
            model: dict["model"] as? String ?? "",
            city: dict["city"] as? String ?? "",
            vehicleCount: dict["vehicleCount"] as? Int ?? 0,
            status: dict["status"] as? String ?? "offline",
            profileStatus: dict["profileStatus"] as? String ?? "no_profile",
            hasProfile: dict["hasProfile"] as? Bool ?? false,
            profileId: dict["profileId"] as? Int,
            notes: dict["notes"] as? String ?? "",
            hiredAt: dict["hiredAt"] as? String,
            scoreGeneral: dict["scoreGeneral"] as? Int ?? 0,
            scoreSpeed: dict["scoreSpeed"] as? Int ?? 0,
            scoreBrake: dict["scoreBrake"] as? Int ?? 0,
            scoreFuel: dict["scoreFuel"] as? Int ?? 0,
            scoreSafety: dict["scoreSafety"] as? Int ?? 0,
            totalDistanceKm: (dict["totalDistanceKm"] as? Double) ?? Double(dict["totalDistanceKm"] as? Int ?? 0),
            tripCount: dict["tripCount"] as? Int ?? 0,
            overspeedCount: dict["overspeedCount"] as? Int ?? 0,
            alarmCount: dict["alarmCount"] as? Int ?? 0,
            hasTelemetry: dict["hasTelemetry"] as? Bool ?? false,
            createdAt: dict["created_at"] as? String,
            vehicleStatus: {
                if let cv = dict["currentVehicles"] as? [[String: Any]], let first = cv.first {
                    return first["status"] as? String ?? ""
                }
                return ""
            }()
        )
    }

    /// POST /api/mobile/drivers
    func createDriver(data: [String: Any]) async throws -> Driver? {
        let json = try await post("/api/mobile/drivers", body: data)
        guard let dict = json["data"] as? [String: Any] else { return nil }
        let id = dict["id"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        return Driver(
            id: id, driverCode: dict["driverCode"] as? String ?? "", name: name,
            avatar: dict["avatar"] as? String ?? "", color: dict["color"] as? String ?? "#3b82f6",
            role: dict["role"] as? String ?? "Sürücü", phone: dict["phone"] as? String ?? "",
            email: dict["email"] as? String ?? "", license: dict["license"] as? String ?? "",
            licenseNo: dict["licenseNo"] as? String ?? "", employeeNo: dict["employeeNo"] as? String ?? "",
            vehicle: dict["vehicle"] as? String ?? "", lastVehicle: dict["lastVehicle"] as? String ?? "",
            model: dict["model"] as? String ?? "", city: dict["city"] as? String ?? "",
            vehicleCount: dict["vehicleCount"] as? Int ?? 0, status: dict["status"] as? String ?? "offline",
            profileStatus: dict["profileStatus"] as? String ?? "no_profile",
            hasProfile: dict["hasProfile"] as? Bool ?? false, profileId: dict["profileId"] as? Int,
            notes: dict["notes"] as? String ?? "", hiredAt: dict["hiredAt"] as? String,
            scoreGeneral: 0, scoreSpeed: 0, scoreBrake: 0, scoreFuel: 0, scoreSafety: 0,
            totalDistanceKm: 0, tripCount: 0, overspeedCount: 0, alarmCount: 0,
            hasTelemetry: false, createdAt: nil,
            vehicleStatus: ""
        )
    }

    /// PUT /api/mobile/drivers/{id}
    func updateDriver(id: String, data: [String: Any]) async throws -> Driver? {
        let json = try await put("/api/mobile/drivers/\(id)", body: data)
        guard let dict = json["data"] as? [String: Any] else { return nil }
        let dId = dict["id"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        return Driver(
            id: dId, driverCode: dict["driverCode"] as? String ?? "", name: name,
            avatar: dict["avatar"] as? String ?? "", color: dict["color"] as? String ?? "#3b82f6",
            role: dict["role"] as? String ?? "Sürücü", phone: dict["phone"] as? String ?? "",
            email: dict["email"] as? String ?? "", license: dict["license"] as? String ?? "",
            licenseNo: dict["licenseNo"] as? String ?? "", employeeNo: dict["employeeNo"] as? String ?? "",
            vehicle: dict["vehicle"] as? String ?? "", lastVehicle: dict["lastVehicle"] as? String ?? "",
            model: dict["model"] as? String ?? "", city: dict["city"] as? String ?? "",
            vehicleCount: dict["vehicleCount"] as? Int ?? 0, status: dict["status"] as? String ?? "offline",
            profileStatus: dict["profileStatus"] as? String ?? "no_profile",
            hasProfile: dict["hasProfile"] as? Bool ?? false, profileId: dict["profileId"] as? Int,
            notes: dict["notes"] as? String ?? "", hiredAt: dict["hiredAt"] as? String,
            scoreGeneral: 0, scoreSpeed: 0, scoreBrake: 0, scoreFuel: 0, scoreSafety: 0,
            totalDistanceKm: 0, tripCount: 0, overspeedCount: 0, alarmCount: 0,
            hasTelemetry: false, createdAt: nil,
            vehicleStatus: ""
        )
    }

    /// GET /api/mobile/drivers/catalog  — returns form data + vehicles list
    func fetchDriverCatalog() async throws -> [[String: Any]] {
        let json = try await get("/api/mobile/drivers/catalog")
        return json["vehicles"] as? [[String: Any]] ?? []
    }

    /// GET /api/mobile/vehicles/{id} — vehicle detail with driver info
    func fetchVehicleDetail(deviceId: Int) async throws -> [String: Any] {
        let json = try await get("/api/mobile/vehicles/\(deviceId)")
        return json["data"] as? [String: Any] ?? json
    }

    /// POST /api/mobile/vehicles/{id}/assign-driver
    func assignDriverToVehicle(vehicleId: Int, driverProfileId: Int?, driverCode: String?) async throws {
        var body: [String: Any] = [:]
        if let pid = driverProfileId { body["driver_profile_id"] = pid }
        if let code = driverCode { body["driver_code"] = code }
        _ = try await post("/api/mobile/vehicles/\(vehicleId)/assign-driver", body: body)
    }

    /// DELETE /api/mobile/vehicles/{id}/assign-driver
    func clearDriverFromVehicle(vehicleId: Int) async throws {
        _ = try await httpDelete("/api/mobile/vehicles/\(vehicleId)/assign-driver")
    }

    // MARK: - Geofences

    /// GET /api/mobile/geofences
    func fetchGeofences() async throws -> [Geofence] {
        let json = try await get("/api/mobile/geofences")

        guard let dataArray = json["data"] as? [[String: Any]] else {
            return []
        }

        return dataArray.compactMap { dict -> Geofence? in
            guard let id = dict["id"] as? Int,
                  let name = dict["name"] as? String else { return nil }

            // API returns shape_type (circle / polygon / rectangle)
            let type = (dict["shape_type"] as? String) ?? (dict["type"] as? String) ?? "polygon"
            let color = (dict["color"] as? String) ?? "#3b82f6"

            // API returns "path" with {lat, lon} — normalise to GeofencePoint {lat, lng}
            var points: [GeofencePoint] = []
            if let raw = dict["path"] ?? dict["points"] {
                var pathArray: [[String: Any]] = []
                if let arr = raw as? [[String: Any]] {
                    pathArray = arr
                } else if let str = raw as? String,
                          let data = str.data(using: .utf8),
                          let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    pathArray = decoded
                }
                points = pathArray.compactMap { p in
                    guard let lat = p["lat"] as? Double else { return nil }
                    let lng = (p["lon"] as? Double) ?? (p["lng"] as? Double) ?? 0
                    return GeofencePoint(lat: lat, lng: lng)
                }
            }

            // API returns radius_m and center_lon
            let radius = (dict["radius_m"] as? Double) ?? (dict["radius"] as? Double)
            let centerLat = dict["center_lat"] as? Double
            let centerLng = (dict["center_lon"] as? Double) ?? (dict["center_lng"] as? Double)
            let createdAt = dict["created_at"] as? String

            return Geofence(
                id: id, name: name, type: type, color: color,
                points: points, radius: radius,
                centerLat: centerLat, centerLng: centerLng,
                createdAt: createdAt
            )
        }
    }
}

// MARK: - Token Store (Keychain)
private enum TokenStore {
    private static let service = "com.arveya.arveygo"
    private static let account = "access_token"

    static func save(token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
