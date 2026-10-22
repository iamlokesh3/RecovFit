import SwiftUI

// MARK: - Appointment Status
enum RequestStatus: String, CaseIterable, Identifiable, Codable {
    case pending, accepted, rejected
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [color.opacity(0.6), color],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - API Appointment Model
struct Appointment: Identifiable, Codable, Equatable {
    let id = UUID()
    var patientId: String
    var name: String
    var age: Int
    var gender: String
    var date: String
    var time: String
    var reason: String
    var status: RequestStatus

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case name = "full_name"
        case age, gender
        case date = "appointment_date"
        case time = "appointment_time"
        case reason = "reason_for_visit"
        case status
    }
}

// MARK: - API Response
struct APIResponses: Codable {
    let status: String
    let message: String
    let data: [Appointment]?
}

// MARK: - Filter Chip
// MARK: - Filter Chip (Alternative)
struct FilterChips: View {
    let title: String
    let isSelected: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(tint.gradient)
                            .shadow(color: tint.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        Capsule()
                            .fill(.regularMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(tint.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }
                .foregroundColor(isSelected ? .white : tint)
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}


// MARK: - Appointment Card
struct AppointmentsCardView: View {
    let appointment: Appointment
    let accept: () -> Void
    let reject: () -> Void
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header section
            HStack(alignment: .center, spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(initials(for: appointment.name))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
                
                // Patient info
                VStack(alignment: .leading, spacing: 6) {
                    Text(appointment.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(appointment.age)y", systemImage: "person.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(appointment.gender, systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status badge
                VStack(spacing: 4) {
                    Text(appointment.status.title)
                        .font(.caption.weight(.bold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(appointment.status.gradient, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: appointment.status.color.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            
            // Appointment details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Label(appointment.date, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label(appointment.time, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Reason: \(appointment.reason)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)

            // Action buttons for pending appointments
            if appointment.status == .pending {
                HStack(spacing: 12) {
                    Button(action: reject) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Reject")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.red.opacity(0.8), .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(isProcessing)
                    
                    Button(action: accept) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Accept")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.green.opacity(0.8), .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(isProcessing)
                }
                .scaleEffect(isProcessing ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isProcessing)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

struct AppointmentRequestView: View {
    let doctorId: String
    @Binding var path: NavigationPath
    
    @State private var requests: [Appointment] = []
    @State private var selectedFilter: RequestStatus? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Confirmation alert states
    @State private var showAcceptAlert = false
    @State private var showRejectAlert = false
    @State private var selectedAppointment: Appointment?

    var filteredRequests: [Appointment] {
        guard let status = selectedFilter else { return requests }
        return requests.filter { $0.status == status }
    }

    var body: some View {
        ZStack {
            // Modern background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.indigo.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Content section
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if filteredRequests.isEmpty {
                    emptyStateView
                } else {
                    appointmentsList
                }
            }
        }
        .navigationTitle("Appointment Requests")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            fetchAppointments()
        }
        // Accept confirmation alert
        .alert("Accept Appointment", isPresented: $showAcceptAlert) {
            Button("Cancel", role: .cancel) {
                selectedAppointment = nil
            }
            Button("Accept", role: .none) {
                if let appointment = selectedAppointment {
                    confirmAcceptAppointment(appointment)
                }
            }
        } message: {
            if let appointment = selectedAppointment {
                Text("Are you sure you want to accept the appointment with \(appointment.name) on \(appointment.date) at \(appointment.time)?")
            }
        }
        // Reject confirmation alert
        .alert("Reject Appointment", isPresented: $showRejectAlert) {
            Button("Cancel", role: .cancel) {
                selectedAppointment = nil
            }
            Button("Reject", role: .destructive) {
                if let appointment = selectedAppointment {
                    confirmRejectAppointment(appointment)
                }
            }
        } message: {
            if let appointment = selectedAppointment {
                Text("Are you sure you want to reject the appointment with \(appointment.name) on \(appointment.date) at \(appointment.time)?")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Stats card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(requests.count)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    statusCounter(.pending)
                    statusCounter(.accepted)
                    statusCounter(.rejected)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChips(title: "All", isSelected: selectedFilter == nil, tint: .accentColor) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedFilter = nil
                        }
                    }
                    ForEach(RequestStatus.allCases) { status in
                        FilterChips(title: status.title, isSelected: selectedFilter == status, tint: status.color) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedFilter = status
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }
    
    private func statusCounter(_ status: RequestStatus) -> some View {
        VStack(spacing: 2) {
            Text("\(requests.filter { $0.status == status }.count)")
                .font(.headline.weight(.bold))
                .foregroundColor(status.color)
            
            Text(status.title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.3)
                .tint(.blue)
            
            Text("Loading appointments...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                fetchAppointments()
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.blue, in: Capsule())
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "tray.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .indigo.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Requests Found")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(selectedFilter == nil ? "No appointment requests at the moment" : "No \(selectedFilter?.title.lowercased() ?? "") requests found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if selectedFilter != nil {
                Button("Show All Requests") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedFilter = nil
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.blue, in: Capsule())
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Appointments List
    private var appointmentsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredRequests) { appointment in
                    AppointmentsCardView(
                        appointment: appointment,
                        accept: {
                            selectedAppointment = appointment
                            showAcceptAlert = true
                        },
                        reject: {
                            selectedAppointment = appointment
                            showRejectAlert = true
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Confirm Actions
    private func confirmAcceptAppointment(_ appointment: Appointment) {
        updateStatus(appointment: appointment, to: .accepted)
        selectedAppointment = nil
    }
    
    private func confirmRejectAppointment(_ appointment: Appointment) {
        updateStatus(appointment: appointment, to: .rejected)
        selectedAppointment = nil
    }

    // MARK: - Fetch Appointments
    private func fetchAppointments() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(ServiceApi.Status)?doctor_id=\(doctorId)") else {
            self.errorMessage = "Invalid API URL"
            self.isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isLoading = false
                }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(APIResponses.self, from: data)
                    if decoded.status == "success", let appointments = decoded.data {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.requests = appointments
                        }
                    } else {
                        self.errorMessage = decoded.message
                    }
                } catch {
                    self.errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    // MARK: - Update Appointment Status
    private func updateStatus(appointment: Appointment, to status: RequestStatus) {
        guard let url = URL(string: "\(ServiceApi.Status)?doctor_id=\(doctorId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "patient_id": appointment.patientId,
            "appointment_date": appointment.date,
            "appointment_time": appointment.time,
            "status": status.rawValue
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else { return }
                do {
                    let decoded = try JSONDecoder().decode(APIResponses.self, from: data)
                    if decoded.status == "success" {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if let index = requests.firstIndex(of: appointment) {
                                requests[index].status = status
                            }
                        }
                    } else {
                        self.errorMessage = decoded.message
                    }
                } catch {
                    self.errorMessage = "Update failed: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
