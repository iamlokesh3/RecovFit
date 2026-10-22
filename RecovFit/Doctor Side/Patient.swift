import SwiftUI

// MARK: - DoctorPatient Model
struct DoctorPatient: Identifiable, Equatable, Codable {
    var id = UUID()
    let patientID: String
    let password: String
    var dateAdded: Date = Date()
    
    // Computed property for display
    var displayName: String {
        "Patient \(patientID)"
    }
}

// MARK: - Modern Patient List View
struct PatientListView: View {
    @State private var patients: [DoctorPatient] = []
    @State private var showAddPatientSheet = false
    @State private var patientID = ""
    @State private var password = ""
    @State private var patientToDelete: DoctorPatient? = nil
    @State private var showDeleteConfirmation = false
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var searchText = ""
    @State private var isAddingPatient = false
    
    var filteredPatients: [DoctorPatient] {
        if searchText.isEmpty {
            return patients
        } else {
            return patients.filter { $0.patientID.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.mint.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                if patients.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    patientListContent
                }
            }
        }
        .sheet(isPresented: $showAddPatientSheet) {
            AddPatientSheet(
                patientID: $patientID,
                password: $password,
                isAdding: $isAddingPatient,
                onAdd: addPatient,
                onCancel: resetAddPatientFields
            )
        }
        .alert("Confirm Deletion", isPresented: $showDeleteConfirmation, presenting: patientToDelete) { patient in
            Button("Delete", role: .destructive) {
                deletePatient(patient)
            }
            Button("Cancel", role: .cancel) { }
        } message: { patient in
            Text("Are you sure you want to remove \(patient.displayName)? This action cannot be undone.")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationTitle("My Patients")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Stats card
            HStack(spacing: 20) {
                StatCards(
                    icon: "person.2.fill",
                    title: "Total Patients",
                    value: "\(patients.count)",
                    color: .blue
                )
                
                StatCards(
                    icon: "person.badge.plus.fill",
                    title: "This Month",
                    value: "\(patientsThisMonth)",
                    color: .green
                )
            }
            .padding(.horizontal, 20)
            
            // Search and Add section
            HStack(spacing: 12) {
                SearchBar(text: $searchText)
                
                Button(action: { showAddPatientSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [.blue, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    // MARK: - Patient List Content
    private var patientListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredPatients) { patient in
                    ModernPatientCard(
                        patient: patient,
                        onDelete: {
                            patientToDelete = patient
                            showDeleteConfirmation = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            // Refresh functionality if needed
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .mint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("No Patients Yet")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Add your first patient to get started with managing their care")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Button(action: { showAddPatientSheet = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add First Patient")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Computed Properties
    private var patientsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return patients.filter { patient in
            calendar.isDate(patient.dateAdded, equalTo: now, toGranularity: .month)
        }.count
    }
    
    // MARK: - Functions
    private func resetAddPatientFields() {
        patientID = ""
        password = ""
    }
    
    private func addPatient() {
        guard !patientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please fill in all fields"
            showAlert = true
            return
        }
        
        isAddingPatient = true
        
        guard let url = URL(string: ServiceApi.Addpatient) else {
            alertMessage = "Invalid API URL"
            showAlert = true
            isAddingPatient = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyData = "patientID=\(patientID)&password=\(password)"
        request.httpBody = bodyData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isAddingPatient = false
                
                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                guard let data = data else {
                    alertMessage = "No response from server"
                    showAlert = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String,
                       let message = json["message"] as? String {
                        
                        if status == "success" {
                            let newPatient = DoctorPatient(
                                patientID: patientID,
                                password: password,
                                dateAdded: Date()
                            )
                            
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                patients.append(newPatient)
                            }
                            
                            showAddPatientSheet = false
                            resetAddPatientFields()
                            
                            // Success haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        } else {
                            alertMessage = message
                            showAlert = true
                        }
                    }
                } catch {
                    alertMessage = "Failed to process server response"
                    showAlert = true
                }
            }
        }.resume()
    }
    
    private func deletePatient(_ patient: DoctorPatient) {
        guard let url = URL(string: ServiceApi.Deletepatient) else {
            alertMessage = "Invalid API URL"
            showAlert = true
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyData = "patientID=\(patient.patientID)"
        request.httpBody = bodyData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                guard let data = data else {
                    alertMessage = "No response from server"
                    showAlert = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String,
                       let message = json["message"] as? String {
                        
                        if status == "success" {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if let index = patients.firstIndex(of: patient) {
                                    patients.remove(at: index)
                                }
                            }
                        } else {
                            alertMessage = message
                            showAlert = true
                        }
                    }
                } catch {
                    alertMessage = "Failed to process server response"
                    showAlert = true
                }
            }
        }.resume()
    }
}

// MARK: - Supporting Views

struct StatCards: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15), in: Circle())
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            TextField("Search patients...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ModernPatientCard: View {
    let patient: DoctorPatient
    let onDelete: () -> Void
    @State private var showingDetails = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .mint.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(String(patient.patientID.prefix(2)).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("ID: \(patient.patientID)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Added: \(dateFormatter.string(from: patient.dateAdded))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Menu button
                Menu {
                    Button(action: { showingDetails = true }) {
                        Label("View Details", systemImage: "info.circle")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove Patient", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick actions
            HStack(spacing: 12) {
                ActionButton(
                    title: "Message", icon: "message.fill",
                    color: .blue
                ) {
                    // Message action
                }
                
                ActionButton(
                    title: "Call", icon: "phone.fill",
                    color: .green
                ) {
                    // Call action
                }
                
                ActionButton(
                    title: "Schedule", icon: "calendar.badge.plus",
                    color: .orange
                ) {
                    // Schedule action
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ActionButtons: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct AddPatientSheet: View {
    @Binding var patientID: String
    @Binding var password: String
    @Binding var isAdding: Bool
    let onAdd: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Add New Patient")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter patient credentials to add them to your care")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 20) {
                    ModernTextFields(
                        icon: "person.text.rectangle",
                        title: "Patient ID",
                        placeholder: "Enter patient ID",
                        text: $patientID
                    )
                    
                    ModernSecureField(
                        icon: "lock.fill",
                        title: "Password",
                        placeholder: "Enter password",
                        text: $password
                    )
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onAdd()
                    }) {
                        HStack(spacing: 12) {
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                            }
                            
                            Text(isAdding ? "Adding Patient..." : "Add Patient")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isFormValid ? [.blue, .mint] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(
                            color: isFormValid ? .blue.opacity(0.3) : .clear,
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    }
                    .disabled(!isFormValid || isAdding)
                    
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        !patientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ModernTextFields: View {
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
                        .stroke(
                            isFocused ? .blue.opacity(0.5) : .secondary.opacity(0.2),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: isFocused ? 2 : 0)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct ModernSecureField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    
    @FocusState private var isFocused: Bool
    @State private var showPassword = false
    
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
                        isFocused ? .blue.opacity(0.5) : .secondary.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.3), lineWidth: isFocused ? 2 : 0)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
}
struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
