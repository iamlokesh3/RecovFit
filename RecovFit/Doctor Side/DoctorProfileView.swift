import SwiftUI

// MARK: - Doctor Model
struct Doctor: Codable, Identifiable {
    var id: String { full_name }
    let full_name: String
    let age: Int?
    let gender: String?
    let phone: String?
    let email: String?
    let working_days: String?
    let start_time: String?
    let end_time: String?
    let clinic_address: String?
    let hospital_affiliations: [String]?
    let specializations: [String]?
    let languages: [String]?
    let college_name: String?
    let board_certified: Int?
    let fellowship: String?
    let certifications: String?
    let dr_profile: String?
}

// MARK: - API Response
struct DoctorResponses: Codable {
    let success: Bool
    let doctor: Doctor?
}

// MARK: - ViewModel
@MainActor
class DoctorProfileViewModel: ObservableObject {
    @Published var doctor: Doctor?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchDoctor(doctorId: String) async {
        guard let url = URL(string: ServiceApi.Doctorprofile) else {
            self.errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyData = "doctorId=\(doctorId)"
        request.httpBody = bodyData.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DoctorResponses.self, from: data)
            if response.success, let doctor = response.doctor {
                self.doctor = doctor
            } else {
                self.errorMessage = "Doctor not found"
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - DoctorProfileView
struct DoctorProfileView: View {
    let doctorId: String
    @StateObject private var vm = DoctorProfileViewModel()
    @EnvironmentObject var session: SessionManager
    @Binding var path: NavigationPath
    
    // Delete profile states
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showDeleteError = false

    var body: some View {
        ZStack {
            // Clean medical background
            CleanMedicalBackground()

            if vm.isLoading {
                LoadingIndicator()
            } else if let doctor = vm.doctor {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        doctorHeaderCard(doctor: doctor)

                        // Contact Information
                        infoSection("Contact Information") {
                            VStack(spacing: 12) {
                                ContactItems(icon: "phone.fill", label: "Phone", value: doctor.phone ?? "Not provided")
                                ContactItems(icon: "envelope.fill", label: "Email", value: doctor.email ?? "Not provided")
                                ContactItems(icon: "clock.fill", label: "Working Hours", value: doctor.working_days ?? "Not specified")
                                ContactItems(icon: "location.fill", label: "Clinic Address", value: doctor.clinic_address ?? "Not provided")
                            }
                        }

                        // Medical Specializations
                        if let specializations = doctor.specializations, !specializations.isEmpty {
                            infoSection("Medical Specializations") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                    ForEach(specializations, id: \.self) { spec in
                                        SpecializationCard(title: spec, icon: "stethoscope")
                                    }
                                }
                            }
                        }

                        // Education & Certifications
                        infoSection("Education & Certifications") {
                            VStack(spacing: 12) {
                                if let college = doctor.college_name {
                                    EducationCard(title: college, subtitle: "Medical Education", icon: "graduationcap.fill")
                                }
                                if let board = doctor.board_certified, board == 1 {
                                    EducationCard(title: "Board Certified", subtitle: "Professional Certification", icon: "checkmark.seal.fill")
                                }
                                if let fellowship = doctor.fellowship {
                                    EducationCard(title: fellowship, subtitle: "Fellowship", icon: "person.3.fill")
                                }
                                if let certs = doctor.certifications {
                                    EducationCard(title: certs, subtitle: "Additional Certifications", icon: "doc.text.fill")
                                }
                            }
                        }

                        // Hospital Affiliations
                        if let affiliations = doctor.hospital_affiliations, !affiliations.isEmpty {
                            infoSection("Hospital Affiliations") {
                                VStack(spacing: 8) {
                                    ForEach(affiliations, id: \.self) { hospital in
                                        HospitalCard(name: hospital)
                                    }
                                }
                            }
                        }

                        // Languages Spoken
                        if let languages = doctor.languages, !languages.isEmpty {
                            infoSection("Languages Spoken") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                                    ForEach(languages, id: \.self) { lang in
                                        LanguageTag(language: lang)
                                    }
                                }
                            }
                        }

                        // Edit Profile Button
                        NavigationLink(destination: DoctorDetailsView(doctorId: doctorId, path: $path)) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 10)
                }
            } else if let error = vm.errorMessage {
                ErrorStateView(message: error)
            } else {
                EmptyStateViews()
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
        .navigationTitle("Doctor Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Delete Profile", systemImage: "trash.fill", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(isDeleting)
                    
                    Button("Logout", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        logoutDoctor()
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
                Task {
                    await deleteProfile()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to permanently delete your doctor profile? This action cannot be undone and will remove all your professional information, patient appointments, and account data.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteErrorMessage ?? "Failed to delete profile. Please try again.")
        }
        .task {
            await vm.fetchDoctor(doctorId: doctorId)
        }
    }

    // MARK: - Delete Profile Function
    private func deleteProfile() async {
        guard let url = URL(string: ServiceApi.DeleteAccount) else {
            await MainActor.run {
                deleteErrorMessage = "Invalid server URL"
                showDeleteError = true
            }
            return
        }
        
        await MainActor.run {
            isDeleting = true
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["doctor_id": doctorId]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let success = json["success"] as? Bool {
                
                await MainActor.run {
                    isDeleting = false
                    
                    if success {
                        // Profile deleted successfully
                        withAnimation(.easeInOut(duration: 0.5)) {
                            // Log out user and redirect to login
                            session.logout()
                            path = NavigationPath()
                        }
                    } else {
                        let message = json["message"] as? String ?? "Unknown error occurred"
                        deleteErrorMessage = message
                        showDeleteError = true
                    }
                }
            } else {
                await MainActor.run {
                    isDeleting = false
                    deleteErrorMessage = "Invalid server response"
                    showDeleteError = true
                }
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                deleteErrorMessage = "Network error: \(error.localizedDescription)"
                showDeleteError = true
            }
        }
    }

    // MARK: - Logout Function
    private func logoutDoctor() {
        session.logout()
        path.removeLast(path.count)
    }

    // MARK: - Doctor Header Card
    private func doctorHeaderCard(doctor: Doctor) -> some View {
        HStack(spacing: 20) {
            AsyncImage(url: URL(string: "\(ServiceApi.baseURL)\(doctor.dr_profile ?? "")")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(doctor.full_name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("ID: \(doctorId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    if let firstSpec = doctor.fellowship, !firstSpec.isEmpty {
                        Text(firstSpec)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    if doctor.board_certified == 1 {
                        Text("• Board Certified")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

            }
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Section Builder
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - UI Components (unchanged)

struct CleanMedicalBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Subtle accent elements
            Circle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.green.opacity(0.04))
                .frame(width: 150, height: 150)
                .blur(radius: 50)
                .offset(x: 120, y: 300)
        }
    }
}

struct LoadingIndicator: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Loading doctor profile...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct ContactItems: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 18))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct SpecializationCard: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EducationCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 20))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct HospitalCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .foregroundColor(.orange)
                .font(.system(size: 18))
                .frame(width: 24)
            
            Text(name)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct LanguageTag: View {
    let language: String
    
    var body: some View {
        Text(language)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(8)
    }
}

struct ErrorStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Missing ContactItem (in case it was referenced incorrectly)
struct ContactsItems: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        ContactItems(icon: icon, label: label, value: value)
    }
}

struct MedicalCard: View {
    let title: String
    let icon: String

    var body: some View {
        SpecializationCard(title: title, icon: icon)
    }
}

struct EmptyStateViews: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Appointments Today")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("You have no scheduled appointments for today")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
