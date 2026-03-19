import Foundation

enum SecondBrainContactAPIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor SecondBrainContactAPIClient {
    static let shared = SecondBrainContactAPIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "http://localhost:8022")!) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    func getContacts(userId: UUID, limit: Int = 50, offset: Int = 0) async throws -> SecondBrainContactListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/contact/contacts"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId.uuidString),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components?.url else {
            throw SecondBrainContactAPIError.invalidURL
        }

        return try await performRequest(URLRequest(url: url), as: SecondBrainContactListResponse.self)
    }

    func searchContacts(userId: UUID, query: String) async throws -> [SecondBrainContact] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/contact/contacts/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId.uuidString),
            URLQueryItem(name: "q", value: query),
        ]

        guard let url = components?.url else {
            throw SecondBrainContactAPIError.invalidURL
        }

        let response: SecondBrainContactListResponse = try await performRequest(URLRequest(url: url), as: SecondBrainContactListResponse.self)
        return response.contacts
    }

    func triggerGmailSync(userId: UUID) async throws {
        guard let url = URLComponents(url: baseURL.appendingPathComponent("/api/v1/contact/sync/gmail"), resolvingAgainstBaseURL: false)?.url else {
            throw SecondBrainContactAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["user_id": userId.uuidString])

        let _: EmptyResponse = try await performRequest(request, as: EmptyResponse.self)
    }

    func triggerDedup(userId: UUID) async throws -> Int {
        guard let url = URLComponents(url: baseURL.appendingPathComponent("/api/v1/contact/dedup"), resolvingAgainstBaseURL: false)?.url else {
            throw SecondBrainContactAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["user_id": userId.uuidString])

        let response: DedupResponse = try await performRequest(request, as: DedupResponse.self)
        return response.mergeCount
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SecondBrainContactAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SecondBrainContactAPIError.httpError(statusCode: 0, body: "Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw SecondBrainContactAPIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        // For empty responses (e.g. 204 No Content or empty body)
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SecondBrainContactAPIError.decodingError(error)
        }
    }
}

// MARK: - Internal Response Types

private struct EmptyResponse: Codable {
    init() {}
}

private struct DedupResponse: Codable {
    let mergeCount: Int

    enum CodingKeys: String, CodingKey {
        case mergeCount = "merge_count"
    }
}
