import Foundation

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let stargazersCount: Int
    let defaultBranch: String
    let visibility: String?
    let owner: GitHubUser

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner, visibility
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case defaultBranch = "default_branch"
    }
}

struct GitHubContentItem: Codable, Identifiable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let type: String // "file" or "dir"
    let downloadUrl: String?

    var id: String { path }
    var isDirectory: Bool { type == "dir" }

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, type
        case downloadUrl = "download_url"
    }
}

struct GitHubFileContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let content: String
    let encoding: String
}

struct GitHubCommitAuthor: Codable {
    let name: String
    let email: String
}

struct GitHubUpdateFileRequest: Codable {
    let message: String
    let content: String
    let sha: String
    let branch: String?
    let committer: GitHubCommitAuthor
}

struct GitHubUpdateFileResponse: Codable {
    struct CommitInfo: Codable {
        let sha: String
    }
    let commit: CommitInfo
}

struct GitHubAPIError: Codable, Error {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}
