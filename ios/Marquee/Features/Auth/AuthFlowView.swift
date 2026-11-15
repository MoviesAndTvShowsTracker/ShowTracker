import SwiftUI

struct AuthFlowView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var mode: Mode = .signIn

    enum Mode {
        case signIn, signUp, forgot
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.surface.ignoresSafeArea()
                Group {
                    switch mode {
                    case .signIn:
                        SignInView(onSignUp: { mode = .signUp }, onForgot: { mode = .forgot })
                    case .signUp:
                        SignUpView(onSignIn: { mode = .signIn })
                    case .forgot:
                        ForgotPasswordView(onBack: { mode = .signIn })
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SignInView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    var onSignUp: () -> Void
    var onForgot: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var googleToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            BrandMark(size: 72)
            Text("Marquee")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(theme.olive)
            Text("your watch diary")
                .font(.title3)
                .foregroundStyle(theme.inkMuted)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .foregroundStyle(theme.ink)

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.accent)
            }

            Button {
                Task { await signIn() }
            } label: {
                if busy { ProgressView().tint(theme.onAccent) }
                else { Text("Sign in") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || email.isEmpty || password.isEmpty)

            Button("Forgot password?", action: onForgot)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.inkMuted)

            GoogleSignInPlaceholder(token: $googleToken) {
                Task { await googleSignIn() }
            }

            Spacer()
            Button(action: onSignUp) {
                Text("New here? Create an account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func signIn() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await auth.signIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func googleSignIn() async {
        guard !googleToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Paste a Google ID token, or wire Google Sign-In SDK."
            return
        }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await auth.signInWithGoogle(idToken: googleToken.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SignUpView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme
    var onSignIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            Text("Join Marquee")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.ink)
            Text("Track films and shows in one diary.")
                .foregroundStyle(theme.inkMuted)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            SecureField("Password (6+ characters)", text: $password)
                .textContentType(.newPassword)
                .padding()
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let error {
                Text(error).font(.footnote).foregroundStyle(theme.accent)
            }

            Button {
                Task { await signUp() }
            } label: {
                if busy { ProgressView().tint(theme.onAccent) }
                else { Text("Create account") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy)

            Spacer()
            Button("Already have an account? Sign in", action: onSignIn)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.ink)
    }

    private func signUp() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await auth.signUp(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme
    var onBack: () -> Void

    @State private var email = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            Text("Reset password")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.ink)
            Text("We'll email a reset link if that account exists.")
                .foregroundStyle(theme.inkMuted)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let message {
                Text(message).font(.footnote).foregroundStyle(theme.inkMuted)
            }

            Button {
                Task { await send() }
            } label: {
                if busy { ProgressView().tint(theme.onAccent) }
                else { Text("Send reset link") }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
            Button("Back to sign in", action: onBack)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.ink)
    }

    private func send() async {
        busy = true
        defer { busy = false }
        do {
            try await auth.forgotPassword(email: email)
            message = "If that email is registered, a reset link is on its way."
        } catch {
            message = error.localizedDescription
        }
    }
}

/// Drop-in until GoogleSignIn SDK is added via SPM. Paste token for API testing.
struct GoogleSignInPlaceholder: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var token: String
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google sign-in")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
            TextField("ID token (dev)", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button("Continue with Google token", action: onSubmit)
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}
