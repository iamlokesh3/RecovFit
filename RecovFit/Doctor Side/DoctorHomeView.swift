import SwiftUI

// MARK: - Modern DoctorHomeView
struct DoctorHomeView: View {
    let doctorId: String
    @StateObject private var vm = DoctorProfileViewModel()
    @State private var selectedTab: DoctorTabBar.Tab = .home
    @Binding var path: NavigationPath
    
    @State private var todayAppointments: [AppointmentAPI] = []
    @State private var isLoadingAppointments = false
    @State private var appointmentError: String?
    @State private var currentTime = Date()
    
    // Add dynamic stats state variables
    @State private var pendingCount: Int = 0
    @State private var completedCount: Int = 0
    @State private var isLoadingStats = false
    @StateObject private var notificationStore = NotificationStore()
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ZStack {
            // Modern glass-inspired background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.teal.opacity(0.04),
                    Color.mint.opacity(0.03),
                    Color.cyan.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                switch selectedTab {
                case .home:
                    homeContent
                case .schedule:
                    DoctorScheduleView(doctorId: session.doctorId ?? "")
                case .patient:
                    PatientListView()
                case .notification:
                    NotificationView()
                        .environmentObject(session)
                }
            }
            .safeAreaInset(edge: .bottom) {
                DoctorTabBar(
                    selectedTab: $selectedTab,
                    path: $path,
                    unreadNotificationCount: notificationStore.notifications.filter { $0.is_read == 0 }.count
                )
            }
            .task {
                await notificationStore.fetchFromBackend(session: session)
            }
            .onChange(of: selectedTab) { newTab in
                if newTab == .notification {
                    Task {
                        await notificationStore.markAllRead(session: session)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await vm.fetchDoctor(doctorId: doctorId)
            fetchTodayAppointments()
            fetchAppointmentStats()
            startTimeTimer()
        }
    }

    // MARK: - Home Content
    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header Section
                if let doctor = vm.doctor {
                    ModernWelcomeCard(doctor: doctor, currentTime: currentTime)
                } else if vm.isLoading {
                    LoadingHeaderCard()
                } else {
                    ErrorHeaderCard()
                }

                // Stats Overview with dynamic values
                StatsOverviewCard(
                    todayAppointments: todayAppointments.count,
                    pendingCount: pendingCount,
                    completedCount: completedCount,
                    isLoading: isLoadingAppointments,
                    isLoadingStats: isLoadingStats
                )

                // Quick Actions
                ModernQuickActionsGrid(doctorId: doctorId, path: $path)

                // Today's Schedule
                ModernTodaySchedule(
                    appointments: todayAppointments,
                    isLoading: isLoadingAppointments,
                    error: appointmentError,
                    doctorId: doctorId,
                    path: $path
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await vm.fetchDoctor(doctorId: doctorId)
            fetchTodayAppointments()
            fetchAppointmentStats()
        }
    }

    // MARK: - Helper Functions
    private func startTimeTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Fetch Appointment Stats
    private func fetchAppointmentStats() {
        isLoadingStats = true
        
        guard let url = URL(string: "\(ServiceApi.Status)?doctor_id=\(doctorId)") else {
            isLoadingStats = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                    isLoadingStats = false
                }
                
                if let error = error {
                    print("Error fetching stats: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received for stats")
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(APIResponses.self, from: data)
                    if response.status == "success", let appointments = response.data {
                        
                        let pending = appointments.filter { $0.status == .pending }.count
                        let completed = appointments.filter { $0.status == .accepted }.count
                        
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                            self.pendingCount = pending
                            self.completedCount = completed
                        }
                    } else {
                        print("Failed to load appointment stats")
                    }
                } catch {
                    print("Failed to decode stats: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // MARK: - Fetch Appointments
    private func fetchTodayAppointments() {
        isLoadingAppointments = true
        appointmentError = nil
        
        guard let url = URL(string: "\(ServiceApi.TodayAppoinment)?doctor_id=\(doctorId)") else {
            appointmentError = "Invalid URL"
            isLoadingAppointments = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                    isLoadingAppointments = false
                }
                
                if let error = error {
                    appointmentError = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    appointmentError = "No data received"
                    return
                }
                do {
                    let response = try JSONDecoder().decode(AppointmentResponse.self, from: data)
                    if response.status == "success" {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                            todayAppointments = response.appointments
                        }
                    } else {
                        appointmentError = "Failed to load appointments"
                    }
                } catch {
                    appointmentError = "Failed to process data"
                }
            }
        }.resume()
    }
}

// MARK: - Modern Welcome Card with Glass Effect
private struct ModernWelcomeCard: View {
    let doctor: Doctor
    let currentTime: Date
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Floating time card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateFormatter.string(from: currentTime))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text(timeFormatter.string(from: currentTime))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                // Weather-like mini card
                VStack(spacing: 2) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange.opacity(0.8))
                    
                    Text("Good Day")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            // Doctor profile glass card
            HStack(spacing: 18) {
                // Enhanced avatar with depth
                ZStack {
                    // Outer glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.teal.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 50
                            )
                        )
                        .frame(width: 84, height: 84)
                    
                    // Main avatar container
                    Circle()
                        .fill(.ultraThickMaterial)
                        .frame(width: 68, height: 68)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.teal.opacity(0.4), .mint.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    if let profile = doctor.dr_profile,
                       !profile.isEmpty,
                       let url = URL(string: "\(ServiceApi.baseURL)\(profile)") {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                            } else if phase.error != nil {
                                Text(initials(from: doctor.full_name))
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.teal, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                ProgressView()
                                    .tint(.teal)
                            }
                        }
                    } else {
                        Text(initials(from: doctor.full_name))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                // Doctor info with enhanced typography
                VStack(alignment: .leading, spacing: 8) {
                    Text("Good Morning")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Text(doctor.full_name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let specialization = doctor.specializations?.first {
                        HStack(spacing: 6) {
                            Image(systemName: "stethoscope")
                                .font(.caption)
                                .foregroundColor(.teal)
                            Text(specialization)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.teal.opacity(0.1), in: Capsule())
                    }
                }
                
                Spacer()
                
                // Status with breathing animation
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(.green.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .scaleEffect(1.5)
                            .opacity(0.6)
                            .animation(.easeInOut(duration: 2).repeatForever(), value: currentTime)
                        
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("Active")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(
                // Glass morphism effect
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                }
            )
        }
    }
    
    private func initials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
    }
}

// MARK: - Enhanced Loading Header Card
private struct LoadingHeaderCard: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.15))
                        .frame(width: 100, height: 12)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.25))
                        .frame(width: 70, height: 20)
                }
                Spacer()
                Capsule()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 60, height: 24)
            }
            
            HStack(spacing: 18) {
                Circle()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 68, height: 68)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.15))
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.25))
                        .frame(width: 140, height: 18)
                    Capsule()
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 90, height: 16)
                }
                
                Spacer()
                
                Circle()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 20, height: 20)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Enhanced Error Header Card
private struct ErrorHeaderCard: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Connection Issue")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Unable to load your profile at the moment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Modern Stats Cards with Glass Effect
private struct StatsOverviewCard: View {
    let todayAppointments: Int
    let pendingCount: Int
    let completedCount: Int
    let isLoading: Bool
    let isLoadingStats: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            StatsCards(
                icon: "calendar.badge.clock",
                title: "Today",
                value: isLoading ? "--" : "\(todayAppointments)",
                color: .teal,
                accent: .cyan
            )
            
            StatsCards(
                icon: "hourglass.tophalf.filled",
                title: "Pending",
                value: isLoadingStats ? "--" : "\(pendingCount)",
                color: .orange,
                accent: .yellow
            )
            
            StatsCards(
                icon: "checkmark.seal.fill",
                title: "Completed",
                value: isLoadingStats ? "--" : "\(completedCount)",
                color: .green,
                accent: .mint
            )
        }
    }
}

private struct StatsCards: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let accent: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), accent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Modern Quick Actions with Cards
private struct ModernQuickActionsGrid: View {
    let doctorId: String
    @Binding var path: NavigationPath
    
    private let actions = [
        ActionItem(icon: "calendar", label: "Schedule", color: .teal, accent: .cyan, id: "appointments"),
        ActionItem(icon: "person.2.fill", label: "Patients", color: .green, accent: .mint, id: "patients"),
        ActionItem(icon: "bell.badge", label: "Requests", color: .orange, accent: .yellow, id: "requests"),
        ActionItem(icon: "person.crop.circle.badge", label: "Profile", color: .purple, accent: .indigo, id: "profile")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Access")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(actions) { action in
                    actionCard(for: action)
                }
            }
        }
    }
    
    @ViewBuilder
    private func actionCard(for action: ActionItem) -> some View {
        NavigationLink(destination: destinationView(for: action.id)) {
            VStack(spacing: 14) {
                // Floating icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [action.color.opacity(0.15), action.accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [action.color, action.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(action.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(SoftPressStyle())
    }
    
    @ViewBuilder
    private func destinationView(for actionId: String) -> some View {
        switch actionId {
        case "appointments":
            AppointmentTodayView(doctorId: doctorId, path: $path)
        case "patients":
            DoctorPatientListView(doctorId: doctorId)
        case "requests":
            AppointmentRequestView(doctorId: doctorId, path: $path)
        case "profile":
            DoctorProfileView(doctorId: doctorId, path: $path)
        default:
            EmptyView()
        }
    }
}

private struct ActionItem: Identifiable {
    let id: String
    let icon: String
    let label: String
    let color: Color
    let accent: Color
    
    init(icon: String, label: String, color: Color, accent: Color, id: String) {
        self.icon = icon
        self.label = label
        self.color = color
        self.accent = accent
        self.id = id
    }
}

// MARK: - Enhanced Today Schedule
private struct ModernTodaySchedule: View {
    let appointments: [AppointmentAPI]
    let isLoading: Bool
    let error: String?
    let doctorId: String
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Schedule")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !appointments.isEmpty && !isLoading {
                    NavigationLink(destination: AppointmentTodayView(doctorId: doctorId, path: $path)) {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.teal)
                    }
                }
            }
            
            if isLoading {
                loadingScheduleView
            } else if let error = error {
                errorScheduleView(error)
            } else if appointments.isEmpty {
                emptyScheduleView
            } else {
                scheduleList
            }
        }
    }
    
    private var loadingScheduleView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.secondary.opacity(0.15))
                            .frame(width: 100, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.1))
                            .frame(width: 70, height: 10)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .shimmering()
    }
    
    private func errorScheduleView(_ errorMessage: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 6) {
                Text("Connection Error")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyScheduleView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.teal.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)
            }
            
            VStack(spacing: 8) {
                Text("All Clear!")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("No appointments scheduled for today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(51)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var scheduleList: some View {
        VStack(spacing: 8) {
            ForEach(appointments.prefix(3)) { appointment in
                NavigationLink(
                    destination: AppointmentTodayView(
                        doctorId: doctorId,
                        path: $path
                    )
                ) {
                    HStack(spacing: 16) {
                        // Time card
                        VStack(spacing: 2) {
                            Text(timeComponent(appointment.appointment_time))
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.teal)
                            
                            Text(periodComponent(appointment.appointment_time))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.teal.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        
                        // Patient details
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appointment.full_name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("Age: \(appointment.age)")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.teal.opacity(0.6))
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func timeComponent(_ time: String) -> String {
        if time.count >= 5 {
            return String(time.prefix(5))
        }
        return time
    }
    
    private func periodComponent(_ time: String) -> String {
        if time.count > 5 {
            return String(time.suffix(2))
        }
        return ""
    }
}

// MARK: - Enhanced Button Styles
private struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect Extension
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 300 : -300)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
            .onAppear {
                isAnimating = true
            }
    }
}
