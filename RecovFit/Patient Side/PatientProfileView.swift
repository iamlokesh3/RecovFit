import SwiftUI

// MARK: - Main Patient Profile View
struct PatientProfileView: View {
    let patientId: String
    @EnvironmentObject var session: SessionManager
    @State private var profileImage: Image?
    @State private var detailNav = false
    @State private var patient: Patient?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isLoggedOut = false
    
    // Delete profile states
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showDeleteError = false
    
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            if isLoggedOut {
                PatientLoginView(path: $path)
                    .transition(.opacity)
            } else {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05),
                        Color.purple.opacity(0.08)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    LoadingView()
                } else if let patient = patient {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            // Profile Header
                            profileHeaderCard(patient: patient)
                                .padding(.top, 8)
                            
                            // Quick Stats
                            quickStatsSection(patient: patient)
                            
                            // Info Sections
                            VStack(spacing: 20) {
                                contactSection(patient: patient)
                                medicalSection(patient: patient)
                            }
                            
                            // Action Buttons
                            actionButtonsSection()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await refreshPatientData()
                    }
                } else {
                    ErrorViews(message: errorMessage ?? "Failed to load patient data") {
                        fetchPatient()
                    }
                }
            }
            
            // Delete confirmation overlay
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.red)
                        
                        Text("Deleting Profile...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThickMaterial)
                    )
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Delete Profile", systemImage: "trash.fill", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(isDeleting)
                    
                    Button("Logout", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        session.logout()
                        path = NavigationPath()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
        }
        .confirmationDialog(
            "Delete Profile",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                deleteProfile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to permanently delete your profile? This action cannot be undone and will remove all your medical data, appointments, and account information.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteErrorMessage ?? "Failed to delete profile. Please try again.")
        }
        .onAppear {
            if !isLoggedOut {
                fetchPatient()
            }
        }
    }
    
    // MARK: - Profile Header Card
    private func profileHeaderCard(patient: Patient) -> some View {
        VStack(spacing: 20) {
            // Profile Image Section
            VStack(spacing: 12) {
                ZStack {
                    // Profile Image
                    Group {
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
            }
            
            // Patient Info
            VStack(spacing: 8) {
                Text(patient.full_name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                HStack(spacing: 16) {
                    InfoChip(text: "ID: \(patient.patient_id)", icon: "number.circle.fill")
                    InfoChip(text: "\(patient.age) years", icon: "calendar.circle.fill")
                    InfoChip(text: patient.gender, icon: "person.circle.fill")
                }
                
                Text(patient.blood_group)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
    }
    
    // MARK: - Quick Stats Section
    private func quickStatsSection(patient: Patient) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Health Stats", icon: "chart.bar.fill")
            
            HStack(spacing: 16) {
                ModernStatCard(
                    icon: "ruler.fill",
                    title: "Height",
                    value: patient.height,
                    color: .green
                )
                
                ModernStatCard(
                    icon: "scalemass.fill",
                    title: "Weight",
                    value: patient.weight,
                    color: .orange
                )
                
                ModernStatCard(
                    icon: "drop.fill",
                    title: "Blood Type",
                    value: patient.blood_group,
                    color: .red
                )
            }
        }
    }
    
    // MARK: - Contact Section
    private func contactSection(patient: Patient) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Contact Information", icon: "person.crop.circle.badge.phone")
            
            VStack(spacing: 12) {
                ModernInfoRow(
                    icon: "phone.fill",
                    title: "Phone",
                    value: patient.phone,
                    color: .green
                )
                
                ModernInfoRow(
                    icon: "envelope.fill",
                    title: "Email",
                    value: patient.email,
                    color: .blue
                )
                
                ModernInfoRow(
                    icon: "person.2.fill",
                    title: "Emergency Contact",
                    value: patient.emergency_contact ?? "Not provided",
                    color: .red
                )
                
                ModernInfoRow(
                    icon: "location.fill",
                    title: "Address",
                    value: patient.address,
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Medical Section
    private func medicalSection(patient: Patient) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Medical Information", icon: "cross.case.fill")
            
            VStack(spacing: 12) {
                ModernInfoRow(
                    icon: "heart.text.square.fill",
                    title: "Chronic Conditions",
                    value: patient.chronic_conditions.isEmpty ? "None reported" : patient.chronic_conditions,
                    color: .orange
                )
                
                ModernInfoRow(
                    icon: "pills.fill",
                    title: "Current Medications",
                    value: patient.medications.isEmpty ? "None reported" : patient.medications,
                    color: .mint
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private func actionButtonsSection() -> some View {
        VStack(spacing: 12) {
            // Primary Action Button
            Button(action: { detailNav = true }) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                    Text("Edit Profile")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
            .navigationDestination(isPresented: $detailNav) {
                PatientDetailView(patientId: patientId, path: $path)
            }
        }
    }
    
    // MARK: - Delete Profile Function
    private func deleteProfile() {
        guard let url = URL(string: ServiceApi.DeleteAccount) else {
            deleteErrorMessage = "Invalid server URL"
            showDeleteError = true
            return
        }
        
        isDeleting = true
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["patient_id": patientId]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
        } catch {
            DispatchQueue.main.async {
                self.isDeleting = false
                self.deleteErrorMessage = "Failed to prepare request"
                self.showDeleteError = true
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                if let error = error {
                    self.deleteErrorMessage = "Network error: \(error.localizedDescription)"
                    self.showDeleteError = true
                    return
                }
                
                guard let data = data else {
                    self.deleteErrorMessage = "No response from server"
                    self.showDeleteError = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = json["success"] as? Bool {
                        
                        if success {
                            // Profile deleted successfully
                            withAnimation(.easeInOut(duration: 0.5)) {
                                // Log out user and redirect to login
                                self.session.logout()
                                self.path = NavigationPath()
                            }
                        } else {
                            let message = json["message"] as? String ?? "Unknown error occurred"
                            self.deleteErrorMessage = message
                            self.showDeleteError = true
                        }
                    } else {
                        self.deleteErrorMessage = "Invalid server response"
                        self.showDeleteError = true
                    }
                } catch {
                    self.deleteErrorMessage = "Failed to parse server response"
                    self.showDeleteError = true
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Patient Data
    private func fetchPatient() {
        guard let url = URL(string: "\(ServiceApi.baseURL)/patient/p_profile.php?patient_id=\(patientId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "No data received from server."
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(PatientResponse.self, from: data)
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.patient = response.patient
                        self.isLoading = false
                    }
                    loadProfileImage(from: response.patient.profile_image)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func loadProfileImage(from path: String?) {
        guard let path = path,
              let url = URL(string: "\(ServiceApi.baseURL)\(path)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let uiImage = UIImage(data: data), error == nil else {
                print("Failed to load image:", error?.localizedDescription ?? "Unknown error")
                return
            }
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut) {
                    profileImage = Image(uiImage: uiImage)
                }
            }
        }.resume()
    }

    // MARK: - Refresh Data
    private func refreshPatientData() async {
        isLoading = true
        fetchPatient()
    }
}

// MARK: - Supporting Views (unchanged)

struct LoadingViews: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Loading Patient Profile...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorViews: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            Text("Something went wrong")
                .font(.title2.bold())
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

struct InfoChip: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct ModernStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15), in: Circle())
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.2), radius: 8, y: 4)
        )
    }
}

struct ModernInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Patient Model (unchanged)
struct Patient: Decodable {
    let patient_id: String
    let full_name: String
    let age: Int
    let gender: String
    let blood_group: String
    let profile_image: String?
    let height: String
    let weight: String
    let phone: String
    let email: String
    let emergency_contact: String?
    let address: String
    let chronic_conditions: String
    let medications: String
}

// MARK: - Response Model (unchanged)
struct PatientResponse: Decodable {
    let success: Bool
    let patient: Patient
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            
            Text("Loading appointments...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
