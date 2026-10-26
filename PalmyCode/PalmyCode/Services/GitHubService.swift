import Foundation

enum GitHubServiceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case rateLimited(resetDate: Date?)
    case apiError(message: String)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Add a GitHub Personal Access Token in Settings to continue."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .rateLimited(let resetDate):
            if let resetDate {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "GitHub API rate limit reached. Try again after \(formatter.string(from: resetDate))."
            }
            return "GitHub API rate limit reached. Please try again later."
        case .apiError(let message):
            return message
        case .decodingFailed:
            return "Failed to read data from GitHub."
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor GitHubService {
    static let shared = GitHubService()

    private let baseURL = URL(string: "https://api.github.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func authToken() throws -> String {
        guard let token = KeychainService.loadToken(), !token.isEmpty else {
            throw GitHubServiceError.notAuthenticated
        }
        return token
    }

    private func makeRequest(path: String, method: String = "GET", queryItems: [URLQueryItem]? = nil, body: Data? = nil) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("token \(try authToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubServiceError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubServiceError.invalidResponse
        }

        if http.statusCode == 403, let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining"), remaining == "0" {
            var resetDate: Date?
            if let resetString = http.value(forHTTPHeaderField: "X-RateLimit-Reset"), let epoch = TimeInterval(resetString) {
                resetDate = Date(timeIntervalSince1970: epoch)
            }
            throw GitHubServiceError.rateLimited(resetDate: resetDate)
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(GitHubAPIError.self, from: data) {
                throw GitHubServiceError.apiError(message: apiError.message)
            }
            throw GitHubServiceError.apiError(message: "GitHub request failed with status \(http.statusCode).")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubServiceError.decodingFailed
        }
    }

    func validateToken() async throws -> GitHubUser {
        let request = try makeRequest(path: "/user")
        return try await perform(request)
    }

    func fetchUserRepos(page: Int = 1) async throws -> [GitHubRepo] {
        let items = [
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: "updated")
        ]
        let request = try makeRequest(path: "/user/repos", queryItems: items)
        return try await perform(request)
    }

    func searchRepos(query: String, page: Int = 1) async throws -> [GitHubRepo] {
        struct SearchResult: Codable { let items: [GitHubRepo] }
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        let request = try makeRequest(path: "/search/repositories", queryItems: items)
        let result: SearchResult = try await perform(request)
        return result.items
    }

    func fetchContents(owner: String, repo: String, path: String = "") async throws -> [GitHubContentItem] {
        let request = try makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)")
        return try await perform(request)
    }

    func fetchFile(owner: String, repo: String, path: String, ref: String? = nil) async throws -> GitHubFileContent {
        var queryItems: [URLQueryItem]?
        if let ref {
            queryItems = [URLQueryItem(name: "ref", value: ref)]
        }
        let request = try makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)", queryItems: queryItems)
        return try await perform(request)
    }

    @discardableResult
    func updateFile(owner: String, repo: String, path: String, message: String, contentBase64: String, sha: String, branch: String?) async throws -> GitHubUpdateFileResponse {
        let author = GitHubCommitAuthor(name: "Palmy Code", email: "palmycode@palmyflask.studio")
        let payload = GitHubUpdateFileRequest(message: message, content: contentBase64, sha: sha, branch: branch, committer: author)
        let body = try JSONEncoder().encode(payload)
        let request = try makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)", method: "PUT", body: body)
        return try await perform(request)
    }
}
