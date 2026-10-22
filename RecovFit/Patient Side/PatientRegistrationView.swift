import SwiftUI

struct PatientRegistrationView: View {
    @State private var patientID: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isRegistrationSuccessful = false
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @Binding var path: NavigationPath
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Animated Header Section
                        headerSection
                            .padding(.top, 20)
                        
                        // Main Content Card
                        VStack(spacing: 24) {
                            registrationFormSection
                            passwordRequirementsSection
                            actionButtonsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        
                        Spacer(minLength: 40)
                    }
                }
                .frame(minHeight: geometry.size.height)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        Color(.systemGroupedBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Registration Status", isPresented: $showingAlert) {
                Button("OK") {
                    if isRegistrationSuccessful {
                        // ✅ Auto go back to Login
                        path = NavigationPath()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 5)
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Join RecovFit to start monitoring your health")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Registration Form Section
    private var registrationFormSection: some View {
        VStack(spacing: 20) {
            CustomTextField(
                icon: "person.circle.fill",
                placeholder: "Patient ID",
                text: $patientID,
                isValid: !patientID.isEmpty
            )
            
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "Email Address",
                text: $email,
                keyboardType: .emailAddress,
                isValid: isValidEmail(email) || email.isEmpty
            )
            
            CustomPasswordField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                showPassword: $showPassword,
                isValid: isValidPassword(password) || password.isEmpty
            )
            
            CustomPasswordField(
                icon: "lock.shield.fill",
                placeholder: "Confirm Password",
                text: $confirmPassword,
                showPassword: $showConfirmPassword,
                isValid: (password == confirmPassword && !confirmPassword.isEmpty) || confirmPassword.isEmpty
            )
        }
    }
    
    // MARK: - Password Requirements Section
    private var passwordRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                Text("Password Requirements")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                RequirementRow(
                    text: "At least 8 characters",
                    isMet: password.count >= 8
                )
                RequirementRow(
                    text: "Contains uppercase & lowercase",
                    isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil &&
                           password.range(of: "[a-z]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "Contains at least one number",
                    isMet: password.range(of: "[0-9]", options: .regularExpression) != nil
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: registerPatient) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Create Account")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isFormValid && !isLoading {
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                )
                .cornerRadius(28)
                .scaleEffect(isLoading ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isLoading)
            }
            .disabled(!isFormValid || isLoading)
            
            // Login Link
            NavigationLink(destination: PatientLoginView(path: $path)) {
                HStack(spacing: 6) {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .font(.system(size: 16))
            }
        }
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        return !patientID.isEmpty &&
        isValidEmail(email) &&
        isValidPassword(password) &&
        password == confirmPassword
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#
        return NSPredicate(format:"SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$"#
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }

    // MARK: - API Integration
    private func registerPatient() {
        guard isFormValid else {
            alertMessage = "Please fill in all fields correctly."
            showingAlert = true
            return
        }

        isLoading = true

        guard let encodedPatientID = patientID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            alertMessage = "Error encoding form data."
            showingAlert = true
            isLoading = false
            return
        }

        guard let url = URL(string: ServiceApi.PatientRegistration) else {
            alertMessage = "Invalid server URL."
            showingAlert = true
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        let bodyComponents = "patient_id=\(encodedPatientID)&email=\(encodedEmail)&password=\(encodedPassword)"
        request.httpBody = bodyComponents.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showingAlert = true
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    alertMessage = "Invalid server response."
                    showingAlert = true
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    alertMessage = "Server error: \(httpResponse.statusCode)"
                    showingAlert = true
                    return
                }

                guard let data = data else {
                    alertMessage = "No response from server."
                    showingAlert = true
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let status = json["status"] as? String ?? "error"
                        let message = json["message"] as? String ?? "Unknown error"

                        alertMessage = message
                        showingAlert = true
                        isRegistrationSuccessful = (status == "success")
                    } else {
                        if let responseString = String(data: data, encoding: .utf8) {
                            alertMessage = responseString
                            showingAlert = true
                            isRegistrationSuccessful = responseString.lowercased().contains("success")
                        } else {
                            alertMessage = "Invalid server response format."
                            showingAlert = true
                        }
                    }
                } catch {
                    alertMessage = "Failed to parse response: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }.resume()
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isValid: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isValid ? .blue : .red)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isValid ? Color.clear : Color.red.opacity(0.5), lineWidth: 1)
                )
        )
    }
}
struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isMet ? .green : .gray)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(isMet ? .primary : .secondary)
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: isMet)
    }
}
struct CustomPasswordField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var isValid: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isValid ? .blue : .red)
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isValid ? Color.clear : Color.red.opacity(0.5), lineWidth: 1)
                )
        )
    }
}
