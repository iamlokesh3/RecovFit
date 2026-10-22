import SwiftUI
import Foundation

// MARK: - API Response Model
struct APIResponse: Codable {
    let success: Bool
    let type: String? // "patient" or "doctor"
    let message: String
}

// MARK: - ViewModel for Forgot Password
class ForgotPasswordViewModel: ObservableObject {
    @Published var mobileNumber = ""
    @Published var isVerified = false
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var navigateToHome = false
    @Published var userType: String?
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var isLoading = false
    @Published var showResetAlert = false

    // Verify mobile number with API
    func verifyMobile() async {
        let trimmedPhone = mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            showError(message: "Mobile number cannot be empty.")
            return
        }
        
        await MainActor.run { self.isLoading = true }
        
        guard let url = URL(string: ServiceApi.ForgetPassword) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["phone": trimmedPhone]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)

            await MainActor.run {
                self.isLoading = false
                if response.success {
                    self.isVerified = true
                    self.userType = response.type
                } else {
                    self.showError(message: response.message)
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                showError(message: "Failed to connect to server.")
            }
        }
    }

    // Show reset confirmation alert
    func requestPasswordReset() {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            showError(message: "Password fields cannot be empty.")
            return
        }
        guard newPassword == confirmPassword else {
            showError(message: "Passwords do not match.")
            return
        }
        showResetAlert = true
    }

    // Reset password with API
    func resetPassword() async {
        await MainActor.run { self.isLoading = true }
        
        guard let url = URL(string: ServiceApi.ForgetPassword) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "phone": mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "new_password": newPassword
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)

            await MainActor.run {
                self.isLoading = false
                if response.success {
                    self.userType = response.type
                    self.navigateToHome = true
                } else {
                    self.showError(message: response.message)
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                showError(message: "Failed to connect to server.")
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - SwiftUI View for Forgot Password
struct ForgotPasswordView: View {
    @StateObject private var vm = ForgotPasswordViewModel()
    @Binding var path: NavigationPath
    @State private var animateCard = false
    
    var body: some View {
        ZStack {
            // Clean white background like your login page
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    // Header section with app logo
                    VStack(spacing: 20) {
                        // App icon similar to your login page
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.teal, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "heart.text.square.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color.teal.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 8) {
                            Text("RecovFit")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.teal)
                            
                            Text("Password Recovery")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(vm.isVerified ? "Create your new secure password" : "Enter your registered mobile number")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .opacity(animateCard ? 1 : 0)
                    .offset(y: animateCard ? 0 : -50)
                    .animation(.easeInOut(duration: 0.8), value: animateCard)
                    
                    // Main card
                    VStack(spacing: 24) {
                        if !vm.isVerified {
                            mobileVerificationCard
                        } else {
                            passwordResetCard
                        }
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    .opacity(animateCard ? 1 : 0)
                    .offset(y: animateCard ? 0 : 50)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateCard)
                    
                    // Footer - security note
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            
                            Text("HIPAA Compliant & Secure")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Your health data is protected with enterprise-grade encryption")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(animateCard ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateCard)
                }
                .padding(.vertical, 40)
            }
        }
        .onAppear {
            animateCard = true
        }
        .navigationDestination(isPresented: $vm.navigateToHome) {
            LoginHomeView()
        }
        .alert(vm.errorMessage, isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        }
        .alert("Reset Password?", isPresented: $vm.showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset") {
                Task { await vm.resetPassword() }
            }
        } message: {
            Text("Are you sure you want to reset your password? This action cannot be undone.")
        }
    }
    
    // MARK: - Mobile Verification Card
    private var mobileVerificationCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 18))
                    Text("Mobile Number")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                TextField("Enter your mobile number", text: $vm.mobileNumber)
                    .keyboardType(.phonePad)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            Button {
                Task { await vm.verifyMobile() }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "key.fill")
                            .font(.system(size: 16))
                    }
                    
                    Text(vm.isLoading ? "Verifying..." : "Verify Mobile")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
            }
            .disabled(vm.isLoading)
        }
    }
    
    // MARK: - Password Reset Card
    private var passwordResetCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 18))
                    Text("New Password")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                SecureField("Enter new password", text: $vm.newPassword)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 18))
                    Text("Confirm Password")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                SecureField("Re-enter new password", text: $vm.confirmPassword)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            Button {
                vm.requestPasswordReset()
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                    }
                    
                    Text(vm.isLoading ? "Resetting..." : "Reset Password")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
            }
            .disabled(vm.isLoading)
        }
    }
}
