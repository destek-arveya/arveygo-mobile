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

            let type = (dict["type"] as? String) ?? "polygon"
            let color = (dict["color"] as? String) ?? "#3b82f6"

            var points: [GeofencePoint] = []
            if let pArr = dict["points"] as? [[String: Any]] {
                points = pArr.compactMap { p in
                    guard let lat = p["lat"] as? Double,
                          let lng = p["lng"] as? Double else { return nil }
                    return GeofencePoint(lat: lat, lng: lng)
                }
            }

            let radius = dict["radius"] as? Double
            let centerLat = dict["center_lat"] as? Double
            let centerLng = dict["center_lng"] as? Double
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
