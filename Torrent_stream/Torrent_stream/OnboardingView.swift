import SwiftUI

enum AppThemePreference: String {
    case dark
    case light

    var colorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    mutating func toggle() {
        self = self == .dark ? .light : .dark
    }
}

private struct AppColors {
    static let background = Color(appHex: "#000000")
    static let accentPurple = Color(appHex: "#8B5CF6")
    static let accentBlue = Color(appHex: "#3B82F6")
    static let primaryText = Color(appHex: "#FFFFFF")
    static let secondaryText = Color(appHex: "#9CA3AF")
    static let lightBackground = Color(appHex: "#F5F3FF")
    static let lightPrimaryText = Color(appHex: "#1F2937")
    static let green = Color(appHex: "#22C55E")
    static let red = Color(appHex: "#EF4444")
    static let orange = Color(appHex: "#F97316")
    static let cardBackground = Color.white.opacity(0.07)
    static let cardBorder = accentPurple.opacity(0.24)
    static let inactiveDot = secondaryText.opacity(0.52)

    static let brandGradient = LinearGradient(
        colors: [accentPurple, accentBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [accentPurple, accentBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func screenBackground(for theme: AppThemePreference) -> Color {
        theme == .dark ? background : lightBackground
    }

    static func headline(for theme: AppThemePreference) -> Color {
        theme == .dark ? primaryText : lightPrimaryText
    }
}

private struct OnboardingSlide: Identifiable {
    let id = UUID()
    let icon: String
    let headline: String
    let subtitle: String
}

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appTheme") private var appTheme = AppThemePreference.dark.rawValue
    @State private var selectedPage = 0
    @State private var glowPulse = false

    private let slides = [
        OnboardingSlide(
            icon: "magnifyingglass.circle.fill",
            headline: "Search Torrents",
            subtitle: "Find anything instantly. Search millions of torrents with seeders, size, and category info."
        ),
        OnboardingSlide(
            icon: "play.circle.fill",
            headline: "Stream Instantly",
            subtitle: "No waiting. Play video directly in-app via our progressive torrent streamer."
        ),
        OnboardingSlide(
            icon: "rectangle.stack.badge.plus",
            headline: "Build Your Lists",
            subtitle: "Organize your content. Save to Watchlist, Wishlist, Watch Later, or custom Playlists."
        ),
        OnboardingSlide(
            icon: "person.3.fill",
            headline: "Join the Community",
            subtitle: "Discover & share. Post torrents, vote, and comment with other users."
        ),
    ]

    private var theme: AppThemePreference {
        AppThemePreference(rawValue: appTheme) ?? .dark
    }

    private var isLastSlide: Bool {
        selectedPage == slides.count - 1
    }

    var body: some View {
        ZStack {
            AppColors.screenBackground(for: theme)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    AppColors.accentPurple.opacity(theme == .dark ? 0.34 : 0.18),
                    AppColors.screenBackground(for: theme).opacity(0.0),
                ],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .scaleEffect(glowPulse ? 1.16 : 0.92)
            .opacity(glowPulse ? 1.0 : 0.74)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selectedPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        OnboardingSlideView(slide: slide, theme: theme)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedPage)

                OnboardingPageIndicator(
                    count: slides.count,
                    selectedPage: selectedPage
                )
                .padding(.bottom, 22)

                if isLastSlide {
                    getStartedButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(height: 88)
                        .padding(.bottom, 8)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: appTheme)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: toggleTheme) {
                Image(systemName: theme == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.brandGradient)
                    .frame(width: 44, height: 44)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
            }
            .accessibilityLabel(theme == .dark ? "Switch to light theme" : "Switch to dark theme")

            Spacer()

            if !isLastSlide {
                Button("Skip", action: finishOnboarding)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .frame(height: 72)
    }

    private var getStartedButton: some View {
        Button(action: finishOnboarding) {
            Text("Get Started")
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppColors.buttonGradient)
                .cornerRadius(16)
                .shadow(color: AppColors.accentPurple.opacity(0.32), radius: 18, x: 0, y: 10)
        }
    }

    private func toggleTheme() {
        var nextTheme = theme
        nextTheme.toggle()
        appTheme = nextTheme.rawValue
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
    }
}

private struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let theme: AppThemePreference

    var body: some View {
        VStack {
            Spacer(minLength: 24)

            VStack(spacing: 28) {
                GradientIcon(systemName: slide.icon)

                VStack(spacing: 14) {
                    Text(slide.headline)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.headline(for: theme))
                        .multilineTextAlignment(.center)

                    Text(slide.subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.vertical, 44)
            .background(AppColors.cardBackground)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 28)
        }
    }
}

private struct GradientIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 82, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(AppColors.brandGradient)
            .frame(width: 122, height: 122)
            .background(
                Circle()
                    .fill(AppColors.accentPurple.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

private struct OnboardingPageIndicator: View {
    let count: Int
    let selectedPage: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                if index == selectedPage {
                    Capsule()
                        .fill(AppColors.buttonGradient)
                        .frame(width: 28, height: 8)
                } else {
                    Capsule()
                        .fill(AppColors.inactiveDot)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
    }
}

private extension Color {
    init(appHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch cleaned.count {
        case 6:
            red = int >> 16
            green = int >> 8 & 0xFF
            blue = int & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

#Preview {
    OnboardingView()
}
