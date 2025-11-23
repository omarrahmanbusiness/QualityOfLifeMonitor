//
//  AuthView.swift
//  QualityOfLifeMonitor
//
//  Created on 23/11/2025.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var inviteCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    @State private var showResetSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Quality of Life Monitor")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Passive health monitoring for better outcomes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    if showForgotPassword {
                        // Forgot Password Form
                        VStack(spacing: 16) {
                            Text("Reset Password")
                                .font(.headline)

                            Text("Enter your email address and we'll send you a link to reset your password.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            // Email Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("your@email.com", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }

                            // Send Reset Button
                            Button(action: requestPasswordReset) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Send Reset Link")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(email.contains("@") ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(!email.contains("@") || authManager.isLoading)

                            // Back to Sign In
                            Button("Back to Sign In") {
                                showForgotPassword = false
                            }
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                    } else {
                        // Mode Toggle
                        Picker("", selection: $isSignUp) {
                            Text("Sign Up").tag(true)
                            Text("Sign In").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)

                        // Form
                        VStack(spacing: 16) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("your@email.com", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(isSignUp ? .newPassword : .password)
                            }

                            // Confirm Password (Sign Up only)
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Confirm Password")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.newPassword)
                                }

                                // Invite Code
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Invite Code")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextField("Enter your invite code", text: $inviteCode)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.none)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Submit Button
                        Button(action: submit) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal)

                        // Forgot Password (Sign In only)
                        if !isSignUp {
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                        }

                        // Info text for sign up
                        if isSignUp {
                            VStack(spacing: 8) {
                                Text("By creating an account, you agree to participate in health monitoring research.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Text("Your data will be collected passively and securely synced for analysis.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Check Your Email", isPresented: $showResetSuccess) {
                Button("OK", role: .cancel) {
                    showForgotPassword = false
                }
            } message: {
                Text("If an account exists for \(email), you will receive a password reset link shortly.")
            }
        }
    }

    private var isFormValid: Bool {
        let emailValid = !email.isEmpty && email.contains("@")
        let passwordValid = password.count >= 6

        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword && !inviteCode.isEmpty
        } else {
            return emailValid && passwordValid
        }
    }

    private func submit() {
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(
                        email: email,
                        password: password,
                        inviteCode: inviteCode
                    )
                } else {
                    try await authManager.signIn(
                        email: email,
                        password: password
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func requestPasswordReset() {
        Task {
            do {
                try await authManager.resetPassword(email: email)
                await MainActor.run {
                    showResetSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AuthView()
}
