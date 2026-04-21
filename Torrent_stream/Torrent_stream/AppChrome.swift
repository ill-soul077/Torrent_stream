import SwiftUI

enum AppPalette {
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black : Color(.systemGroupedBackground)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white
    }

    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    static func subtleFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(.label)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .gray : Color(.secondaryLabel)
    }
}

struct AppHeaderModifier: ViewModifier {
    @EnvironmentObject private var auth: AuthViewModel
    let title: String
    var showProfileLink: Bool = true

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.purple)
                        Text(title)
                            .font(.headline)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if showProfileLink {
                        NavigationLink(destination: ProfileView().environmentObject(auth)) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.purple)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
    }
}

extension View {
    func appHeader(_ title: String, showProfileLink: Bool = true) -> some View {
        modifier(AppHeaderModifier(title: title, showProfileLink: showProfileLink))
    }
}
