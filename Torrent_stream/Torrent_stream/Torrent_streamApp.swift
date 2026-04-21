import SwiftUI

@main
struct Torrent_streamApp: App {
    @StateObject private var auth = AuthViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appTheme") private var appTheme = AppThemePreference.dark.rawValue

    private var theme: AppThemePreference {
        AppThemePreference(rawValue: appTheme) ?? .dark
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else if auth.isLoggedIn {
                    MainTabView()
                        .environmentObject(auth)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
            .preferredColorScheme(theme.colorScheme)
        }
    }
}
