import SwiftUI

// MARK: - Appointment Model
struct AppointmentStatus: Identifiable, Codable {
    var id = UUID()
    let date: String
    let time: String
    let status: StatusType
    let doctor: Doctor

    enum StatusType: String, Codable {
        case pending, rejected, accepted

        var text: String {
            switch self {
            case .pending: return "Pending"
            case .rejected: return "Rejected"
            case .accepted: return "Accepted"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .orange
            case .rejected: return .red
            case .accepted: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .rejected: return "xmark.circle.fill"
            case .accepted: return "checkmark.seal.fill"
            }
        }
    }

    struct Doctor: Codable {
        let doctorId: String
        let name: String
        let specialty: String
        let hospital: String
        let imageName: String
    }

    var doctorNameMapped: String { doctor.name }
    var departmentMapped: String { doctor.specialty }
    var hospitalNameMapped: String { doctor.hospital }
    var imageURL: URL? { URL(string: "\(ServiceApi.baseURL)\(doctor.imageName)") }
}

// MARK: - Main View with Enhanced UI
struct AppointmentTrackView: View {
    let patientId: String
    
    @State private var appointments: [AppointmentStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: FilterType = .all
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case accepted = "Accepted"
        case rejected = "Rejected"
        
    }
    
    var filteredAppointments: [AppointmentStatus] {
        switch selectedFilter {
        case .all:
            return appointments
        case .pending:
            return appointments.filter { $0.status == .pending }
        case .rejected:
            return appointments.filter { $0.status == .rejected }
        case .accepted:
            return appointments.filter { $0.status == .accepted }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(message: errorMessage)
                } else if appointments.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
        }
        .navigationTitle("My Appointments")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await fetchAppointments()
        }
        .refreshable {
            await fetchAppointments()
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Filter tabs
            filterTabs
            
            // Appointments list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredAppointments) { appointment in
                        EnhancedAppointmentCardView(appointment: appointment)
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Loading your appointments...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                Task {
                    await fetchAppointments()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Appointments Yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your appointment history will appear here once you book your first appointment.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - API Fetch
    func fetchAppointments() async {
        guard let url = URL(string: "\(ServiceApi.baseURL)/patient/track.php?patient_id=\(patientId)") else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(APIResponse.self, from: data)
            if response.success {
                DispatchQueue.main.async {
                    self.appointments = response.appointments.map { apiAppointment in
                        AppointmentStatus(
                            date: apiAppointment.appointmentDate,
                            time: apiAppointment.appointmentTime,
                            status: AppointmentStatus.StatusType(rawValue: apiAppointment.status.lowercased()) ?? .pending,
                            doctor: AppointmentStatus.Doctor(
                                doctorId: apiAppointment.doctor.doctorId,
                                name: apiAppointment.doctor.name,
                                specialty: apiAppointment.doctor.specialty,
                                hospital: apiAppointment.doctor.hospital,
                                imageName: apiAppointment.doctor.imageName
                            )
                        )
                    }
                    isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to load appointments"
                    isLoading = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Network error occurred: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - API Response Structs
    struct APIAppointment: Codable {
        let appointmentDate: String
        let appointmentTime: String
        let status: String
        let doctor: APIDoctor
    }

    struct APIDoctor: Codable {
        let doctorId: String
        let name: String
        let specialty: String
        let hospital: String
        let imageName: String
    }

    struct APIResponse: Codable {
        let success: Bool
        let appointments: [APIAppointment]
    }
}

// MARK: - Enhanced Appointment Card View
struct EnhancedAppointmentCardView: View {
    let appointment: AppointmentStatus
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Doctor image with enhanced styling
                doctorImageView
                
                // Doctor info
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.doctorNameMapped)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(appointment.departmentMapped)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text(appointment.hospitalNameMapped)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status with icon
                statusBadge
            }
            .padding(20)
            
            // Divider
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Date and Time section
            HStack(spacing: 20) {
                Label {
                    Text(formatDate(appointment.date))
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Label {
                    Text(appointment.time)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
                .shadow(
                    color: .black.opacity(0.08),
                    radius: isPressed ? 2 : 8,
                    x: 0,
                    y: isPressed ? 1 : 4
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }
    }
    
    // MARK: - Doctor Image View
    private var doctorImageView: some View {
        Group {
            if let url = appointment.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 64, height: 64)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    case .failure(_):
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
            }
        }
        .overlay(
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: appointment.status.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(appointment.status.color)
            
            Text(appointment.status.text)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(appointment.status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(appointment.status.color.opacity(0.15))
        )
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM dd, yyyy"
            return formatter.string(from: date)
        }
        return dateString
    }
}
