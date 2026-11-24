import SwiftUI

struct AuthFlowView: View {
    @State private var mode: Mode = .signIn

    enum Mode {
        case signIn, signUp, forgot
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .signIn:
                    SignInView(
                        onSignUp: { withAnimation(MarqueeMotion.standard) { mode = .signUp } },
                        onForgot: { withAnimation(MarqueeMotion.standard) { mode = .forgot } }
                    )
                case .signUp:
                    SignUpView(onSignIn: { withAnimation(MarqueeMotion.standard) { mode = .signIn } })
                case .forgot:
                    ForgotPasswordView(onBack: { withAnimation(MarqueeMotion.standard) { mode = .signIn } })
                }
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
    @State private var googleBusy = false
    @State private var appleBusy = false
    @State private var error: String?

    private var socialBusy: Bool { googleBusy || appleBusy }

    var body: some View {
        AuthScaffold(
            kicker: "Marquee",
            title: "Sign in",
            subtitle: "Use Apple, Google, or email."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ContinueWithAppleButton(busy: appleBusy) {
                    Task { await appleSignIn() }
                }
                .disabled(busy || googleBusy)

                ContinueWithGoogleButton(busy: googleBusy) {
                    Task { await googleSignIn() }
                }
                .disabled(busy || appleBusy)

                AuthOrDivider()

                AuthTextField(
                    title: "Email",
                    text: $email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                AuthTextField(
                    title: "Password",
                    text: $password,
                    isSecure: true,
                    contentType: .password
                )

                if let error {
                    Text(error)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.accentInk)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if busy { ProgressView().tint(theme.onAccent) }
                    else { Text("Sign in") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || socialBusy || email.isEmpty || password.isEmpty)

                Button("Forgot password?", action: onForgot)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 28)

                AuthFooterLink(title: "Create an account", action: onSignUp)
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
        googleBusy = true
        error = nil
        defer { googleBusy = false }
        do {
            let token = try await GoogleAuth.signIn()
            try await auth.signInWithGoogle(idToken: token)
        } catch {
            if GoogleAuth.isCancellation(error) { return }
            self.error = error.localizedDescription
        }
    }

    private func appleSignIn() async {
        appleBusy = true
        error = nil
        defer { appleBusy = false }
        do {
            let credentials = try await AppleAuth.signIn()
            try await auth.signInWithApple(credentials)
        } catch {
            if AppleAuth.isCancellation(error) { return }
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
    @State private var googleBusy = false
    @State private var appleBusy = false
    @State private var error: String?

    private var socialBusy: Bool { googleBusy || appleBusy }

    var body: some View {
        AuthScaffold(
            kicker: "Marquee",
            title: "Create an account",
            subtitle: "Use Apple, Google, or email."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ContinueWithAppleButton(busy: appleBusy) {
                    Task { await appleSignIn() }
                }
                .disabled(busy || googleBusy)

                ContinueWithGoogleButton(busy: googleBusy) {
                    Task { await googleSignIn() }
                }
                .disabled(busy || appleBusy)

                AuthOrDivider()

                AuthTextField(
                    title: "Email",
                    text: $email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                AuthTextField(
                    title: "Password",
                    text: $password,
                    isSecure: true,
                    contentType: .newPassword
                )

                Text("At least 6 characters.")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)

                if let error {
                    Text(error)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.accentInk)
                }

                Button {
                    Task { await signUp() }
                } label: {
                    if busy { ProgressView().tint(theme.onAccent) }
                    else { Text("Create account") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || socialBusy || email.isEmpty || password.count < 6)

                Spacer(minLength: 28)

                AuthFooterLink(title: "Sign in", action: onSignIn)
            }
        }
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

    private func googleSignIn() async {
        googleBusy = true
        error = nil
        defer { googleBusy = false }
        do {
            let token = try await GoogleAuth.signIn()
            try await auth.signInWithGoogle(idToken: token)
        } catch {
            if GoogleAuth.isCancellation(error) { return }
            self.error = error.localizedDescription
        }
    }

    private func appleSignIn() async {
        appleBusy = true
        error = nil
        defer { appleBusy = false }
        do {
            let credentials = try await AppleAuth.signIn()
            try await auth.signInWithApple(credentials)
        } catch {
            if AppleAuth.isCancellation(error) { return }
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
        AuthScaffold(
            kicker: "Marquee",
            title: "Reset password",
            subtitle: "Enter the email on your account."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                AuthTextField(
                    title: "Email",
                    text: $email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )

                if let message {
                    Text(message)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.olive)
                }

                Button {
                    Task { await send() }
                } label: {
                    if busy { ProgressView().tint(theme.onAccent) }
                    else { Text("Send reset link") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || email.isEmpty)

                Spacer(minLength: 28)

                AuthFooterLink(title: "Back to sign in", action: onBack)
            }
        }
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
