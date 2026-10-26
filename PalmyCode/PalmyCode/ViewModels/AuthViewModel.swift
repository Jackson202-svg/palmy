import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var isValidating = false
    @Published var errorMessage: String?

    init() {
        if KeychainService.loadToken() != nil {
            Task { await validateExistingToken() }
        }
    }

    func validateExistingToken() async {
        isValidating = true
        errorMessage = nil
        do {
            let user = try await GitHubService.shared.validateToken()
            currentUser = user
            isAuthenticated = true
        } catch {
            // Stored token is invalid or expired; require re-entry.
            KeychainService.deleteToken()
            isAuthenticated = false
        }
        isValidating = false
    }

    func signIn(token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a valid Personal Access Token."
            return
        }
        isValidating = true
        errorMessage = nil
        KeychainService.saveToken(trimmed)
        do {
            let user = try await GitHubService.shared.validateToken()
            currentUser = user
            isAuthenticated = true
        } catch {
            KeychainService.deleteToken()
            errorMessage = error.localizedDescription
        }
        isValidating = false
    }

    func signOut() {
        KeychainService.deleteToken()
        currentUser = nil
        isAuthenticated = false
    }
}
