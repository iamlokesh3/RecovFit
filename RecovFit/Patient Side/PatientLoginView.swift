import SwiftUI

// MARK: - API Response Models
struct PatientLoginResponse: Decodable {
    let status: String
    let message: String
    let patient_id: String?
    let is_first_time: Bool?
}

struct AdminLoginResponse: Decodable {
    let status: String
    let message: String
    let user_id: String?
}

// MARK: - Navigation State
enum LoginNavigation: Hashable {
    case patientDetail(String)   // patientId
    case patientHome(String)     // patientId
    case adminHome               // admin dashboard
}

struct PatientLoginView: View {
    @EnvironmentObject var session: SessionManager
    
    // Form state
    @State private var userId = ""
    @State private var password = ""
    
    // UI feedback
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showPassword = false
    
    @State private var naviForget = false
    @State private var showRegistration = false
    
    // Navigation
    @State private var navigation: LoginNavigation? = nil
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.teal.opacity(0.03),
                    Color.mint.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Header Section
                    headerSection
                    
                    // Login Card
                    loginCard
                    
                    VStack(spacing: 16) {
                        // Forgot Password
                        Button(action: {
                            naviForget = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("Forgot Password?")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.teal)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.teal.opacity(0.1), in: Capsule())
                        }
                        
                        
                    
                    // Registration
                    Button(action: {
                        showRegistration = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 14))
                            Text("Create New Patient Account")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.mint)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.mint.opacity(0.1), in: Capsule())
                    }
                    .navigationDestination(isPresented: $showRegistration) {
                        PatientRegistrationView(path: $path)
                    }
                        // Security Message
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text("HIPAA Compliant & Secure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Admin/Patient Info
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            
                            Text("Use your Patient ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
        }
        // Main Navigation Handler
        .navigationDestination(item: $navigation) { destination in
            switch destination {
            case .patientDetail(let id):
                PatientDetailView(patientId: id, path: $path)
            case .patientHome(let id):
                PatientHomeView(patientId: id, path: $path)
            case .adminHome:
                AdminDoctorListView()
            }
        }
        .navigationDestination(isPresented: $naviForget) {
            ForgotPasswordView(path: $path)
        }
        .navigationBarBackButtonHidden(false)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Logo/Icon with dual colors
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal, .mint, .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .teal.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("RecovFit")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Login Portal For Patient")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Welcome! Access your health records")
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
                // User ID Field (Patient ID or Admin ID)
                ModernPatientInputField(
                    icon: "person.text.rectangle.fill",
                    title: "User ID",
                    placeholder: "Enter Patient ID",
                    text: $userId
                )
                
                // Password Field
                ModernPatientPasswordField(
                    title: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    showPassword: $showPassword
                )
            }
            
            // Error Message
            if showError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.red.opacity(0.1))
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Login Button
            Button(action: performLogin) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 16))
                    }
                    
                    Text(isLoading ? "Signing in..." : "Sign In")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isFormValid ? [.teal, .mint] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: isFormValid ? .teal.opacity(0.3) : .clear,
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .scaleEffect(isLoading ? 0.98 : 1.0)
            }
            .disabled(!isFormValid || isLoading)
            .buttonStyle(PressedButtonStyles())
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
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Login Logic
    private func performLogin() {
        hideKeyboard()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoading = true
            showError = false
        }
        
        // Try admin login first, then patient login
        tryAdminLogin { adminSuccess in
            if !adminSuccess {
                self.tryPatientLogin()
            }
        }
    }

    // MARK: - Admin Login (FIXED)
    private func tryAdminLogin(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: ServiceApi.Admin) else {
            print("❌ Admin URL is invalid: \(ServiceApi.Admin)")
            completion(false)
            return
        }
        
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Trying admin login with ID: \(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // FIXED: Changed from "user_id" to "userId" to match PHP script expectations
        request.httpBody = "userId=\(id)&password=\(pw)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Admin login network error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ Admin login: No data received")
                    completion(false)
                    return
                }
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 Admin response: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔍 Admin JSON: \(json)")
                        
                        if let status = json["status"] as? String,
                           status.lowercased() == "success" {
                            
                            let adminId = json["user_id"] as? String ?? id
                            print("✅ Admin login successful with ID: \(adminId)")
                            
                            // Update session
                            self.session.loginAdmin(adminId: adminId)
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.isLoading = false
                            }
                            
                            // Navigate to admin home
                            self.navigation = .adminHome
                            completion(true)
                            return
                        } else {
                            print("❌ Admin login failed: \(json["message"] ?? "Unknown error")")
                        }
                    } else {
                        print("❌ Admin login: Invalid JSON response")
                    }
                } catch {
                    print("❌ Admin login JSON parsing error: \(error)")
                }
                
                completion(false)
            }
        }.resume()
    }

    // MARK: - Patient Login
    private func tryPatientLogin() {
        guard let url = URL(string: ServiceApi.PatiientLogin) else {
            print("❌ Patient URL is invalid: \(ServiceApi.PatiientLogin)")
            updateError("Invalid URL configuration")
            return
        }
        
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Trying patient login with ID: \(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "patient_id=\(id)&password=\(pw)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("❌ Patient login network error: \(error.localizedDescription)")
                    self.updateError("Connection failed. Please check your network.")
                    return
                }
                
                guard let data = data else {
                    print("❌ Patient login: No data received")
                    self.updateError("Server connection error. Please try again.")
                    return
                }
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 Patient response: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔍 Patient JSON: \(json)")
                        
                        if let status = json["status"] as? String {
                            if status.lowercased() == "success" {
                                let firstTime = json["is_first_time"] as? Bool ?? false
                                print("✅ Patient login successful, first_time: \(firstTime)")
                                
                                // ✅ Pass firstTime into SessionManager
                                self.session.loginPatient(patientId: id, isFirstTime: firstTime)
                                
                                if firstTime {
                                    self.navigation = .patientDetail(id)
                                } else {
                                    self.navigation = .patientHome(id)
                                }
                            } else {
                                let errorMsg = json["message"] as? String ?? "Invalid credentials"
                                print("❌ Patient login failed: \(errorMsg)")
                                self.updateError("Invalid credentials. Please check your User ID and password.")
                            }
                        } else {
                            print("❌ Patient login: No status in response")
                            self.updateError("Authentication failed. Please try again.")
                        }
                    } else {
                        print("❌ Patient login: Invalid JSON response")
                        self.updateError("Authentication failed. Please try again.")
                    }
                } catch {
                    print("❌ Patient login JSON parsing error: \(error)")
                    self.updateError("Authentication failed. Please try again.")
                }
            }
        }.resume()
    }

    private func updateError(_ msg: String) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showError = true
            errorMessage = msg
        }
        
        // Haptic feedback for error
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Modern Patient Input Field
struct ModernPatientInputField: View {
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
                    .foregroundColor(.teal)
                
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
                        .stroke(
                            isFocused ? .teal.opacity(0.5) : .secondary.opacity(0.2),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.teal.opacity(0.3), lineWidth: isFocused ? 2 : 0)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Modern Patient Password Field
struct ModernPatientPasswordField: View {
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
                    .foregroundColor(.teal)
                
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
                    .stroke(
                        isFocused ? .teal.opacity(0.5) : .secondary.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.teal.opacity(0.3), lineWidth: isFocused ? 2 : 0)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Pressed Button Style
struct PressedButtonStyles: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

