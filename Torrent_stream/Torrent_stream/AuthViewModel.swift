import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var email = ""
    @Published var errorMessage: String? = nil
    @Published var isLoading = false
    @Published var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? APIConfig.defaultBaseURL

    init() {
        isLoggedIn = APIService.shared.token != nil
        email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIService.shared.login(email: email, password: password)
            APIService.shared.token = resp.access_token
            UserDefaults.standard.set(resp.email, forKey: "userEmail")
            self.email = resp.email
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIService.shared.register(email: email, password: password)
            APIService.shared.token = resp.access_token
            UserDefaults.standard.set(resp.email, forKey: "userEmail")
            self.email = resp.email
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        APIService.shared.token = nil
        UserDefaults.standard.removeObject(forKey: "userEmail")
        isLoggedIn = false
        email = ""
    }

    func saveServerURL() {
        UserDefaults.standard.set(APIConfig.normalized(serverURL), forKey: "serverURL")
    }
}
