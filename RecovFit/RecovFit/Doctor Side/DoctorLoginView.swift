import SwiftUI

// MARK: - API Response Model
struct DoctorLoginResponse: Decodable {
    let status: String
    let message: String
    let doctor_id: String?
    let is_first_time: Bool?
}

struct DoctorLoginView: View {
    @EnvironmentObject var session: SessionManager
    
    // Form state
    @State private var doctorId = ""
    @State private var password = ""
    
    // UI feedback
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showPassword = false
    
    @Binding var path: NavigationPath
    
    // Navigation
    @State private var navigateToDetails = false
    @State private var navigateToHome = false
    @State private var navigateToForgotPassword = false
    @State private var navigateToSignup = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.03), Color.mint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        headerSection
                        loginCard
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                }
                
                // NavigationLinks
                NavigationLink(destination: DoctorDetailsView(doctorId: doctorId, path: $path), isActive: $navigateToDetails) { EmptyView() }
                NavigationLink(destination: DoctorHomeView(doctorId: doctorId, path: $path), isActive: $navigateToHome) { EmptyView() }
                NavigationLink(destination: ForgotPasswordView(path: $path), isActive: $navigateToForgotPassword) { EmptyView() }
                NavigationLink(destination: DoctorSignupView(path: $path), isActive: $navigateToSignup) { EmptyView() }
            }
            .navigationBarBackButtonHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                Image(systemName: "stethoscope")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("RecovFit")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.blue, .mint], startPoint: .leading, endPoint: .trailing))
                Text("Doctor Portal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Welcome back! Please sign in to continue.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Login Card
    private var loginCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                ModernInputField(
                    icon: "person.text.rectangle.fill",
                    title: "Doctor ID",
                    placeholder: "Enter your doctor ID",
                    text: $doctorId
                )
                ModernPasswordField(
                    title: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    showPassword: $showPassword
                )
            }
            
            if showError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.red.opacity(0.1))
                        .stroke(.red.opacity(0.3))
                )
            }
            
            Button(action: loginDoctor) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 16))
                    }
                    
                    Text(isLoading ? "Signing in..." : "Sign In")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isFormValid
                        ? AnyView(
                            LinearGradient(
                                colors: [.blue, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyView(Color.gray)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: isFormValid ? .blue.opacity(0.3) : .clear,
                        radius: 12, x: 0, y: 6)
            }
            .disabled(!isFormValid || isLoading)
            .buttonStyle(PressedButtonStyle())
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                navigateToForgotPassword = true
            } label: {
                Text("Forgot Password?").foregroundColor(.blue)
            }
            
            Button {
                navigateToSignup = true
            } label: {
                Text("New to RecovFit? Create Account").foregroundColor(.mint)
            }
        }
    }
    
    // MARK: - Form Validation
    private var isFormValid: Bool {
        !doctorId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Networking
    private func loginDoctor() {
        hideKeyboard()
        showError = false
        isLoading = true
        
        guard let url = URL(string: ServiceApi.Doctorlogin) else {
            updateError("Invalid URL")
            return
        }
        
        let id = doctorId.trimmingCharacters(in: .whitespaces)
        let pw = password.trimmingCharacters(in: .whitespaces)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "doctor_id=\(id)&password=\(pw)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    updateError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    updateError("No data received")
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(DoctorLoginResponse.self, from: data)
                    
                    if response.status.lowercased() == "success",
                       let docId = response.doctor_id {
                        
                        // ✅ Pass backend flag directly
                        session.loginDoctor(doctorId: docId, isFirstTime: response.is_first_time ?? false)
                        
                        if response.is_first_time == true {
                            navigateToDetails = true   // go to DoctorDetailsView
                        } else {
                            navigateToHome = true      // go to DoctorHomeView
                        }
                    }
                    else {
                        updateError(response.message)
                    }
                    
                } catch {
                    updateError("Failed to parse server response")
                }
            }
        }.resume()
    }
    
    private func updateError(_ msg: String) {
        showError = true
        errorMessage = msg
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - Modern Input & Password Fields + Button Style
struct ModernInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .stroke(isFocused ? .blue.opacity(0.5) : .secondary.opacity(0.2),
                                lineWidth: 1.5)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct ModernPasswordField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            HStack {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .focused($isFocused)
                .textFieldStyle(.plain)
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(isFocused ? .blue.opacity(0.5) : .secondary.opacity(0.2),
                            lineWidth: 1.5)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
