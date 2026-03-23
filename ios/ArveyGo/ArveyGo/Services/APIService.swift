import Foundation

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(String)
    case networkError(Error)
    case unauthorized
    case csrfFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Geçersiz URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Bilinmeyen hata")"
        case .decodingError(let msg):   return "Veri hatası: \(msg)"
        case .networkError(let err):    return err.localizedDescription
        case .unauthorized:             return "Oturum süresi doldu"
        case .csrfFailed:               return "CSRF token alınamadı"
        }
    }
}

// MARK: - Login Response
struct LoginResponse {
    let user: AppUser
    let wsConfig: WSConfig?
}

struct WSConfig {
    let url: String
    let token: String
    let pingInterval: Int
}

// MARK: - API Service
/// Handles communication with the Laravel backend.
/// Laravel uses session/cookie-based auth, so we maintain cookies via URLSession.
final class APIService {

    static let shared = APIService()

    private let baseURL: String
    private let session: URLSession

    private init() {
        baseURL = AppConfig.apiBaseURL

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        session = URLSession(configuration: config)
    }

    // MARK: - CSRF Token
    /// Laravel requires a CSRF token for POST requests.
    /// Fetch it by hitting `/sanctum/csrf-cookie` or by parsing the cookie.
    func fetchCSRFToken() async throws -> String {
        // First, fetch CSRF cookie from the sanctum endpoint
        let url = URL(string: "\(baseURL)/sanctum/csrf-cookie")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // Try alternative: GET the login page to get a cookie
            return try await fetchCSRFFromLoginPage()
        }

        // Extract XSRF-TOKEN from cookies
        if let token = extractXSRFToken() {
            return token
        }

        throw APIError.csrfFailed
    }

    private func fetchCSRFFromLoginPage() async throws -> String {
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)

        // Try to parse CSRF token from HTML meta tag
        if let html = String(data: data, encoding: .utf8),
           let range = html.range(of: "name=\"_token\" value=\"") {
            let start = range.upperBound
            if let end = html[start...].range(of: "\"") {
                return String(html[start..<end.lowerBound])
            }
        }

        // Fallback to cookie
        if let token = extractXSRFToken() {
            return token
        }

        throw APIError.csrfFailed
    }

    private func extractXSRFToken() -> String? {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return nil }
        for cookie in cookies where cookie.name == "XSRF-TOKEN" {
            // Laravel URL-encodes the cookie value
            return cookie.value.removingPercentEncoding ?? cookie.value
        }
        return nil
    }

    // MARK: - Login
    /// Authenticate with the Laravel backend using session-based auth.
    /// Returns user info needed for WebSocket JWT generation.
    func login(email: String, password: String) async throws -> LoginResponse {
        // Step 1: Get CSRF token
        let csrfToken = try await fetchCSRFToken()

        // Step 2: POST login
        guard let url = URL(string: "\(baseURL)/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(csrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
        request.setValue(baseURL, forHTTPHeaderField: "Referer")

        let body: [String: String] = [
            "email": email,
            "password": password,
            "_token": csrfToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1))
        }

        // Laravel may redirect on success (302) or return JSON
        if httpResponse.statusCode == 422 {
            // Validation error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errors = json["errors"] as? [String: [String]] {
                let msg = errors.values.flatMap { $0 }.first ?? "Giriş başarısız"
                throw APIError.httpError(422, msg)
            }
            throw APIError.httpError(422, "E-posta veya şifre hatalı")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.unauthorized
        }

        if !(200...399).contains(httpResponse.statusCode) {
            throw APIError.httpError(httpResponse.statusCode, nil)
        }

        // Step 3: Fetch user info & WS config from livemap bootstrap
        let (user, wsConfig) = try await fetchBootstrapData()

        return LoginResponse(user: user, wsConfig: wsConfig)
    }

    // MARK: - Bootstrap Data
    /// Fetch live map bootstrap which includes user info and WS config.
    func fetchBootstrapData() async throws -> (AppUser, WSConfig?) {
        guard let url = URL(string: "\(baseURL)/api/livemap-bootstrap") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = extractXSRFToken() {
            request.setValue(token, forHTTPHeaderField: "X-XSRF-TOKEN")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "APIService", code: -1))
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode, nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("JSON ayrıştırılamadı")
        }

        // Parse user from bootstrap
        let user = parseUser(from: json)

        // Parse WS config if available
        var wsConfig: WSConfig?
        if let wsJson = json["socket_config"] as? [String: Any] ?? json["liveMapSocketConfig"] as? [String: Any] {
            let wsURL = (wsJson["url"] as? String) ?? ""
            let wsToken = (wsJson["token"] as? String) ?? ""
            let pingInterval = (wsJson["ping_interval"] as? Int) ?? 30
            if !wsURL.isEmpty && !wsToken.isEmpty {
                wsConfig = WSConfig(url: wsURL, token: wsToken, pingInterval: pingInterval)
            }
        }

        return (user, wsConfig)
    }

    private func parseUser(from json: [String: Any]) -> AppUser {
        let userJson = json["user"] as? [String: Any] ?? json

        let id = "\(userJson["id"] ?? "0")"
        let name = (userJson["name"] as? String) ?? "Kullanıcı"
        let email = (userJson["email"] as? String) ?? ""
        let role = (userJson["role_label"] as? String) ?? (userJson["role"] as? String) ?? ""
        let roleKey = (userJson["role_key"] as? String) ?? (userJson["role"] as? String) ?? ""
        let companyId = (userJson["company_id"] as? Int) ?? 1

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

    // MARK: - Logout
    func logout() async {
        guard let url = URL(string: "\(baseURL)/logout") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = extractXSRFToken() {
            request.setValue(token, forHTTPHeaderField: "X-XSRF-TOKEN")
        }

        _ = try? await session.data(for: request)

        // Clear cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}
