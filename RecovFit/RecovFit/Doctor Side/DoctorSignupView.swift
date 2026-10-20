//
// DoctorSignupView.swift
// RecovFit
//
// Created by SAIL L1 on 18/09/25.
//
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct DoctorSignupView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var specialization = ""
    @State private var clinicHospital = ""
    @State private var licenseNumber = ""

    @State private var licenseURL: URL?
    
    @State private var showingLicensePicker = false
    @State private var showingLicensePhotosPicker = false
    
    @State private var licensePhotoItem: PhotosPickerItem?
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSubmissionPending = false
    @State private var isLoading = false
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.03),
                    Color.mint.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    headerSection
                    
                    // Form Card
                    formCard
                    
                    // Document Upload Section
                    documentUploadSection
                    
                    // Submit Button
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Doctor Registration")
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showingLicensePicker,
            allowedContentTypes: [.pdf, .jpeg, .png, .heic, .image],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, for: .license)
        }
        .photosPicker(isPresented: $showingLicensePhotosPicker, selection: $licensePhotoItem, matching: .images)
        .onChange(of: licensePhotoItem) { oldValue, newValue in
            guard let newValue else { return }
            handlePhotoSelection(item: newValue, for: .license)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Registration Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !path.isEmpty {
                        path.removeLast()
                    }

                }
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Logo/Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.mint, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .mint.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Join RecovFit")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Create your doctor profile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Form Card
    private var formCard: some View {
        VStack(spacing: 20) {
            ModernInputField(
                icon: "person.fill",
                title: "Full Name",
                placeholder: "Enter your full name",
                text: $name
            )
            
            ModernInputField(
                icon: "envelope.fill",
                title: "Email Address",
                placeholder: "Enter your email",
                text: $email
            )
            
            ModernInputField(
                icon: "phone.fill",
                title: "Phone Number",
                placeholder: "Enter your phone number",
                text: $phone
            )
            
            ModernInputField(
                icon: "stethoscope",
                title: "Specialization",
                placeholder: "Enter your specialization",
                text: $specialization
            )
            
            ModernInputField(
                icon: "building.2.fill",
                title: "Clinic / Hospital",
                placeholder: "Enter clinic or hospital name",
                text: $clinicHospital
            )
            ModernInputField(
                icon: "number",
                title: "License Number",
                placeholder: "Enter your license number",
                text: $licenseNumber
            )

        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Document Upload Section
    private var documentUploadSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.mint)
                
                Text("Required Documents")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // License Document Upload
                DocumentUploadButtonWithOptions(
                    title: "Medical License",
                    subtitle: "Upload your practice license",
                    icon: "doc.badge.plus",
                    fileURL: licenseURL,
                    documentAction: openLicensePicker,
                    photoAction: openLicensePhotosPicker
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitDoctorDetails) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if isSubmissionPending {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                }
                
                Text(getSubmitButtonText())
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: getButtonColors(),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: getShadowColor(),
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .disabled(!isFormValid || isSubmissionPending || isLoading)
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !specialization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clinicHospital.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        licenseURL != nil
    }

    
    // MARK: - Button Helper Functions
    private func getSubmitButtonText() -> String {
        if isLoading {
            return "Submitting..."
        } else if isSubmissionPending {
            return "Submitted (Pending Approval)"
        } else {
            return "Submit for Verification"
        }
    }
    
    private func getButtonColors() -> [Color] {
        if isLoading {
            return [.blue.opacity(0.7), .mint.opacity(0.7)]
        } else if isFormValid && !isSubmissionPending {
            return [.mint, .blue]
        } else {
            return [.gray, .gray]
        }
    }
    
    private func getShadowColor() -> Color {
        if isLoading {
            return .blue.opacity(0.2)
        } else if isFormValid && !isSubmissionPending {
            return .mint.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    // MARK: - Action Functions
    private func openLicensePicker() {
        print("🔍 License picker button tapped")
        showingLicensePicker = true
        print("🔍 showingLicensePicker set to: \(showingLicensePicker)")
    }
    
    private func openLicensePhotosPicker() {
        print("🔍 License photos picker button tapped")
        showingLicensePhotosPicker = true
        print("🔍 showingLicensePhotosPicker set to: \(showingLicensePhotosPicker)")
    }
    
    // MARK: - Helper Methods
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private enum DocumentType {
        case license
    }
    
    private func handleFileSelection(result: Result<[URL], Error>, for type: DocumentType) {
        print("🔍 File selection result received for: \(type)")
        
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else {
                alertMessage = "No file was selected."
                showingAlert = true
                return
            }
            
            print("Selected file: \(selectedURL)")
            
            // Start accessing security-scoped resource
            let hasAccess = selectedURL.startAccessingSecurityScopedResource()
            print("Security access granted: \(hasAccess)")
            
            defer {
                if hasAccess {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Copy file to app's documents directory
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "doctor_\(type == .license ? "license" : "license")_\(UUID().uuidString).\(selectedURL.pathExtension)"
                let destinationURL = documentsPath.appendingPathComponent(fileName)
                
                print("Copying to: \(destinationURL)")
                
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: selectedURL, to: destinationURL)
                
                // Update the appropriate URL
                DispatchQueue.main.async {
                    switch type {
                    case .license:
                        self.licenseURL = destinationURL
                        print("License file saved: \(destinationURL.lastPathComponent)")
                    }
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                
            } catch {
                print("Error copying file: \(error)")
                DispatchQueue.main.async {
                    self.alertMessage = "Error saving file: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
            
        case .failure(let error):
            print("File selection error: \(error)")
            alertMessage = "Could not select file: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handlePhotoSelection(item: PhotosPickerItem, for type: DocumentType) {
        print("🔍 Photo selection started for: \(type)")
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                guard let imageData = data else { return }
                
                DispatchQueue.main.async {
                    self.saveImageData(imageData, for: type)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.alertMessage = "Could not load image: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func saveImageData(_ data: Data, for type: DocumentType) {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "doctor_\(type == .license ? "license" : "license")_\(UUID().uuidString).jpg"
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            try data.write(to: destinationURL)
            
            switch type {
            case .license:
                licenseURL = destinationURL
                print("License image saved: \(destinationURL.lastPathComponent)")
            }
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            alertMessage = "Error saving image: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // MARK: - API Integration
    private func submitDoctorDetails() {
        guard isFormValid else {
            alertMessage = "Please fill all fields and upload required documents."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response = try await DoctorAPIService.shared.registerDoctor(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    specialization: specialization.trimmingCharacters(in: .whitespacesAndNewlines),
                    clinicHospital: clinicHospital.trimmingCharacters(in: .whitespacesAndNewlines),
                    licenseNumber: licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    licenseURL: licenseURL
                )

                
                await MainActor.run {
                    isLoading = false
                    
                    if response.status == "success" {
                        isSubmissionPending = true
                        alertMessage = response.message
                        
                        // Clear form data after successful submission
                        clearFormData()
                        
                        // Haptic feedback
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)

                    } else {
                        alertMessage = response.message
                    }
                    
                    showingAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Registration failed: \(error.localizedDescription)"
                    showingAlert = true
                    
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func clearFormData() {
        name = ""
        email = ""
        phone = ""
        specialization = ""
        clinicHospital = ""
        licenseNumber = ""
        licenseURL = nil
        licensePhotoItem = nil
    }
}

// MARK: - Document Upload Button with Options Component
struct DocumentUploadButtonWithOptions: View {
    let title: String
    let subtitle: String
    let icon: String
    let fileURL: URL?
    let documentAction: () -> Void
    let photoAction: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Main Upload Button
            HStack(spacing: 16) {
                // Icon Section
                ZStack {
                    Circle()
                        .fill(fileURL != nil ? .mint.opacity(0.2) : .blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: fileURL != nil ? "checkmark" : icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(fileURL != nil ? .mint : .blue)
                }
                
                // Text Section
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(fileURL?.lastPathComponent ?? subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: fileURL != nil ? "checkmark.circle.fill" : "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(fileURL != nil ? .mint : .blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .stroke(
                        fileURL != nil ? .mint.opacity(0.3) : .blue.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                print("🔍 Document upload button tapped for: \(title)")
                documentAction()
            }
            
            // Alternative Photo Upload Button
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("Or select from Photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                print("🔍 Photo upload button tapped for: \(title)")
                photoAction()
            }
        }
    }
}

// MARK: - Modern Input Field Component
struct ModernInputFields: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.mint)
                    .frame(width: 16)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - API Service
class DoctorAPIService {
    static let shared = DoctorAPIService()
    
    private init() {}
    
    func registerDoctor(
        name: String,
        email: String,
        phone: String,
        specialization: String,
        clinicHospital: String,
        licenseNumber: String,
        licenseURL: URL?
    ) async throws -> DoctorRegistrationResponse {
        
        guard let url = URL(string: ServiceApi.DoctorRegistration) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(
            boundary: boundary,
            name: name,
            email: email,
            phone: phone,
            specialization: specialization,
            clinicHospital: clinicHospital,
            licenseNumber: licenseNumber,
            licenseURL: licenseURL
        )
        
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 API Response Status: \(httpResponse.statusCode)")
        print("📡 API Response Data: \(String(data: data, encoding: .utf8) ?? "No data")")
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let registrationResponse = try JSONDecoder().decode(DoctorRegistrationResponse.self, from: data)
            return registrationResponse
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            throw APIError.decodingError
        }
    }
    
    private func createMultipartBody(
        boundary: String,
        name: String,
        email: String,
        phone: String,
        specialization: String,
        clinicHospital: String,
        licenseNumber: String,

        licenseURL: URL?
    ) -> Data {
        var body = Data()
        
        // Add text fields
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n")
        body.append("\(name)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"email\"\r\n\r\n")
        body.append("\(email)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"phone\"\r\n\r\n")
        body.append("\(phone)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"specialization\"\r\n\r\n")
        body.append("\(specialization)\r\n")
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"clinic_hospital\"\r\n\r\n")
        body.append("\(clinicHospital)\r\n")
        // Add license_number field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"license_number\"\r\n\r\n")
        body.append("\(licenseNumber)\r\n")

        // Add file if available
        if let licenseURL = licenseURL {
            do {
                let fileData = try Data(contentsOf: licenseURL)
                let fileName = licenseURL.lastPathComponent
                let mimeType = getMimeType(for: licenseURL.pathExtension)
                
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"license_document\"; filename=\"\(fileName)\"\r\n")
                body.append("Content-Type: \(mimeType)\r\n\r\n")
                body.append(fileData)
                body.append("\r\n")
            } catch {
                print("❌ Error reading license file: \(error)")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
    
    private func getMimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Response Models
struct DoctorRegistrationResponse: Codable {
    let status: String
    let message: String
    let doctorId: Int?
    
    enum CodingKeys: String, CodingKey {
        case status, message
        case doctorId = "doctor_id"
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .decodingError:
            return "Failed to decode server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Extension
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
