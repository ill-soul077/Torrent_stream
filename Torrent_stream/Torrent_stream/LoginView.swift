import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var showServerConfig = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("TorrentStream")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(isRegistering ? "Create Account" : "Sign In")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    TSTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TSTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button(action: submit) {
                        Group {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isRegistering ? "Create Account" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                    }
                    .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                    .padding(.horizontal, 32)

                    Button(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Register") {
                        withAnimation { isRegistering.toggle() }
                        auth.errorMessage = nil
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }

                Spacer()

                Button(action: { showServerConfig = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                        Text("Configure Server")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet().environmentObject(auth)
        }
    }

    private func submit() {
        Task {
            if isRegistering {
                await auth.register(email: email, password: password)
            } else {
                await auth.login(email: email, password: password)
            }
        }
    }
}

struct TSTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
        .foregroundColor(.white)
    }
}

struct ServerConfigSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Server URL") {
                    TextField(APIConfig.defaultBaseURL, text: $auth.serverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Enter the URL of your TorrentStream server. Example: https://rural-kylila-kuet-e06c376e.koyeb.app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Server Configuration")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        auth.saveServerURL()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
