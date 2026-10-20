import SwiftUI

// MARK: - API Appointment Model
struct AppointmentAPI: Identifiable, Codable {
    let id = UUID()
    let patient_id: String
    let full_name: String
    let age: Int
    let gender: String
    let phone: String
    let profile_image: String
    let reason_for_visit: String
    let appointment_time: String
    let appointment_date: String
    
    enum CodingKeys: String, CodingKey {
        case patient_id, full_name, age, gender, phone, profile_image, reason_for_visit, appointment_time, appointment_date
    }
}

// MARK: - API Response
struct AppointmentResponse: Codable {
    let status: String
    let date: String
    let appointments: [AppointmentAPI]
}

// MARK: - Enhanced Main View: Today's Appointments
struct AppointmentTodayView: View {
    let doctorId: String
    @Binding var path: NavigationPath
    @State private var searchText = ""
    @State private var appointments: [AppointmentAPI] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingFilterOptions = false
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Morning", "Afternoon", "Evening"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced Medical Background
                EnhancedMedicalBackground()
                
                VStack(spacing: 0) {
                    // Enhanced Header with Statistics
                    EnhancedHeader(
                        title: "Today's Appointments",
                        appointmentCount: appointments.count,
                        completedCount: 0 // You can add completed logic here
                    )
                    .padding(.top, 10)
                    
                    // Enhanced Search and Filter Section
                    VStack(spacing: 16) {
                        EnhancedSearchBar(searchText: $searchText)
                        
                        if !appointments.isEmpty {
                            FilterSection(
                                selectedFilter: $selectedFilter,
                                filters: filters,
                                showingOptions: $showingFilterOptions
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Content Area with Enhanced Design
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            if isLoading {
                                EnhancedLoadingViews()
                                    .padding(.top, 80)
                            } else if let errorMessage = errorMessage {
                                EnhancedErrorViews(message: errorMessage) {
                                    fetchAppointments()
                                }
                                .padding(.top, 80)
                            } else if filteredAppointments.isEmpty {
                                EnhancedEmptyState(searchText: searchText)
                                    .padding(.top, 80)
                            } else {
                                ForEach(Array(filteredAppointments.enumerated()), id: \.element.id) { index, appointment in
                                    NavigationLink(destination: EnhancedAppointmentDetailView(
                                        doctorId: doctorId,
                                        appointment: appointment,
                                        path: $path
                                    )) {
                                        EnhancedAppointmentCard(
                                            appointment: appointment,
                                            index: index
                                        )
                                    }
                                    .buttonStyle(EnhancedCardButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                    }
                }
            }
            .onAppear {
                fetchAppointments()
            }
            .refreshable {
                await refreshAppointments()
            }
            .navigationBarBackButtonHidden(false)
        }
        .navigationViewStyle(StackNavigationViewStyle())

    }
    
    var filteredAppointments: [AppointmentAPI] {
        var filtered = appointments
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.full_name.localizedCaseInsensitiveContains(searchText) ||
                $0.reason_for_visit.localizedCaseInsensitiveContains(searchText) ||
                $0.phone.contains(searchText)
            }
        }
        
        // Filter by time period
        if selectedFilter != "All" {
            filtered = filtered.filter { appointment in
                let time = appointment.appointment_time.lowercased()
                switch selectedFilter {
                case "Morning":
                    return time.contains("am") || (time.contains("pm") && time.contains("12"))
                case "Afternoon":
                    return time.contains("pm") && !time.contains("12") && Int(time.prefix(2)) ?? 12 < 17
                case "Evening":
                    return time.contains("pm") && Int(time.prefix(2)) ?? 12 >= 17
                default:
                    return true
                }
            }
        }
        
        return filtered
    }
    
    func fetchAppointments() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(ServiceApi.TodayAppoinment)?doctor_id=\(doctorId)") else {
            errorMessage = "Invalid URL configuration"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorMessage = "No data received from server"
                    return
                }
                do {
                    let response = try JSONDecoder().decode(AppointmentResponse.self, from: data)
                    if response.status == "success" {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            self.appointments = response.appointments
                        }
                    } else {
                        errorMessage = "Failed to load appointments"
                    }
                } catch {
                    errorMessage = "Data parsing error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func refreshAppointments() async {
        await MainActor.run {
            fetchAppointments()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Enhanced Detail View
struct EnhancedAppointmentDetailView: View {
    let doctorId: String
    var doctorName: String? = nil
    let appointment: AppointmentAPI
    @Binding var path: NavigationPath
    @State private var selectedTab = 0
    @State private var showingActionSheet = false
    
    var body: some View {
        ZStack {
            EnhancedMedicalBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Enhanced Patient Profile with Status
                    EnhancedPatientProfileCard(appointment: appointment)
                        .padding(.top, 20)
                    
                    // Enhanced Tab Selector with Icons
                    EnhancedTabSelector(selectedTab: $selectedTab)
                        .padding(.horizontal, 20)
                    
                    // Tab Content with Enhanced Design
                    Group {
                        switch selectedTab {
                        case 0:
                            EnhancedPatientInformation(appointment: appointment)
                        case 1:
                            EnhancedVisitDetails(appointment: appointment)
                        case 2:
                            EnhancedQuickActions(
                                doctorId: doctorId,
                                appointment: appointment,
                                doctorName: doctorName,
                                showingActionSheet: $showingActionSheet
                            )
                        default:
                            EnhancedPatientInformation(appointment: appointment)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 120)
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { /* Add to favorites */ }) {
                        Label("Add to Favorites", systemImage: "heart")
                    }
                    Button(action: { /* Share */ }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Enhanced UI Components

struct EnhancedMedicalBackground: View {
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.6),
                    Color.blue.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Floating medical elements
            GeometryReader { geometry in
                Group {
                    // Heartbeat pattern
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: height * 0.7))
                        path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.7))
                        path.addLine(to: CGPoint(x: width * 0.35, y: height * 0.5))
                        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.9))
                        path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.3))
                        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.7))
                        path.addLine(to: CGPoint(x: width, y: height * 0.7))
                    }
                    .stroke(Color.blue.opacity(0.1), lineWidth: 2)
                    .offset(y: -100)
                }
            }
            
            // Subtle accent circles
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: -120, y: -200)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 35)
                .offset(x: 130, y: 300)
        }
    }
}

struct EnhancedHeader: View {
    let title: String
    let appointmentCount: Int
    let completedCount: Int
    @State private var animateStats = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Statistics Cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total",
                    count: appointmentCount,
                    color: .blue,
                    icon: "calendar.badge.clock"
                )
                
                StatCard(
                    title: "Completed",
                    count: completedCount,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                StatCard(
                    title: "Pending",
                    count: appointmentCount - completedCount,
                    color: .orange,
                    icon: "clock.fill"
                )
            }
            .scaleEffect(animateStats ? 1.0 : 0.8)
            .opacity(animateStats ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                    animateStats = true
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EnhancedSearchBar: View {
    @Binding var searchText: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? .blue : .gray)
                    .font(.system(size: 18, weight: .medium))
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                TextField("Search patients, conditions, or phone...", text: $searchText)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = true
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .scaleEffect(isFocused ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            )
        }
    }
}

struct FilterSection: View {
    @Binding var selectedFilter: String
    let filters: [String]
    @Binding var showingOptions: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        title: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

struct EnhancedAppointmentCard: View {
    let appointment: AppointmentAPI
    let index: Int
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced Patient Avatar with Status Ring
            ZStack {
                AsyncImage(url: URL(string: "\(ServiceApi.baseURL)\(appointment.profile_image)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                
                // Status ring
                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 74, height: 74)
                    .opacity(0.8)
                
                // Online status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 22, y: -22)
            }
            
            // Enhanced Patient Information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appointment.full_name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Enhanced Status Badge
                    StatusBadge(status: "Scheduled", color: .green)
                }
                
                HStack(spacing: 12) {
                    Label {
                        Text("\(appointment.age) yrs")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    
                    Label {
                        Text(appointment.gender)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: appointment.gender.lowercased() == "male" ? "person.fill" : "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                }
                
                Text(appointment.reason_for_visit)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Label(appointment.appointment_time, systemImage: "clock.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.7)
                .delay(Double(index) * 0.1)
            ) {
                isVisible = true
            }
        }
    }
}

struct StatusBadge: View {
    let status: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

struct EnhancedPatientProfileCard: View {
    let appointment: AppointmentAPI
    @State private var animateProfile = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Enhanced Patient Avatar with Animations
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                AsyncImage(url: URL(string: "\(ServiceApi.baseURL)\(appointment.profile_image)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                )
            }
            .scaleEffect(animateProfile ? 1.0 : 0.5)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateProfile)
            
            // Enhanced Patient Details
            VStack(spacing: 16) {
                Text(appointment.full_name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    EnhancedInfoPill(
                        icon: "person.fill",
                        label: "Gender",
                        value: appointment.gender,
                        color: .purple
                    )
                    
                    EnhancedInfoPill(
                        icon: "calendar",
                        label: "Age",
                        value: "\(appointment.age) years",
                        color: .blue
                    )
                    
                    EnhancedInfoPill(
                        icon: "number",
                        label: "ID",
                        value: String(appointment.patient_id.prefix(6)),
                        color: .green
                    )
                }
            }
            .opacity(animateProfile ? 1.0 : 0)
            .offset(y: animateProfile ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.4), value: animateProfile)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 20)
        .onAppear {
            animateProfile = true
        }
    }
}

struct EnhancedInfoPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EnhancedTabSelector: View {
    @Binding var selectedTab: Int
    let tabs = [
        ("Patient Info", "person.text.rectangle"),
        ("Visit Details", "stethoscope"),
        ("Quick Actions", "bolt.circle")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tabs[index].1)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selectedTab == index ? .white : .secondary)
                        
                        Text(tabs[index].0)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedTab == index ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Group {
                            if selectedTab == index {
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
    }
}

struct EnhancedPatientInformation: View {
    let appointment: AppointmentAPI
    
    var body: some View {
        VStack(spacing: 20) {
            EnhancedInfoCard(title: "Appointment Details", icon: "calendar.badge.clock", color: .blue) {
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        EnhancedInfoRows(
                            icon: "calendar",
                            label: "Date",
                            value: appointment.appointment_date,
                            color: .blue
                        )
                        
                        Divider()
                            .frame(height: 40)
                        
                        EnhancedInfoRows(
                            icon: "clock.fill",
                            label: "Time",
                            value: appointment.appointment_time,
                            color: .orange
                        )
                    }
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)
                    
                    EnhancedInfoRows(
                        icon: "phone.fill",
                        label: "Phone Number",
                        value: appointment.phone,
                        color: .green
                    )
                }
            }
        }
    }
}

struct EnhancedVisitDetails: View {
    let appointment: AppointmentAPI
    
    var body: some View {
        VStack(spacing: 20) {
            EnhancedInfoCard(title: "Visit Information", icon: "stethoscope", color: .green) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "medical.thermometer")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reason for Visit")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Primary Concern")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text(appointment.reason_for_visit)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }
            }
        }
    }
}

// MARK: - Updated Quick Actions (Email removed, Exercise added)
struct EnhancedQuickActions: View {
    let doctorId: String
    let appointment: AppointmentAPI
    var doctorName: String?
    @Binding var showingActionSheet: Bool
    
    // Updated actionRows - removed Email, added Exercise
    let actionRows = [
        [
            ("Call Patient", "phone.fill", Color.blue),
            ("Send SMS", "message.fill", Color.green)
        ],
        [
            ("WhatsApp", "bubble.left.and.bubble.right.fill", Color.green),
            ("Exercise Plan", "figure.strengthtraining.traditional", Color.orange)
        ]
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            EnhancedInfoCard(title: "Quick Actions", icon: "bolt.circle", color: .orange) {
                VStack(spacing: 16) {
                    ForEach(0..<actionRows.count, id: \.self) { rowIndex in
                        HStack(spacing: 16) {
                            ForEach(0..<actionRows[rowIndex].count, id: \.self) { itemIndex in
                                let action = actionRows[rowIndex][itemIndex]
                                
                                if action.0 == "Exercise Plan" {
                                    // Special handling for Exercise Plan
                                    NavigationLink(destination: PatientExerciseUploadView(
                                        doctorId: doctorId,
                                        appointment: appointment
                                    )) {
                                        VStack(spacing: 10) {
                                            ZStack {
                                                Circle()
                                                    .fill(action.2.opacity(0.15))
                                                    .frame(width: 56, height: 56)
                                                
                                                Image(systemName: action.1)
                                                    .font(.title2)
                                                    .foregroundColor(action.2)
                                            }
                                            
                                            Text(action.0)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(action.2.opacity(0.3), lineWidth: 1.5)
                                                )
                                                .shadow(
                                                    color: action.2.opacity(0.2),
                                                    radius: 8,
                                                    x: 0,
                                                    y: 4
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    // Regular action buttons
                                    EnhancedActionButton(
                                        title: action.0,
                                        icon: action.1,
                                        color: action.2
                                    ) {
                                        performAction(action.0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func performAction(_ action: String) {
        switch action {
        case "Call Patient":
            callPatient(number: appointment.phone)
        case "Send SMS":
            smsPatient(number: appointment.phone, message: "Hello \(appointment.full_name),We are from the RecovFit app. Your appointment with \(doctorName ?? "Doctor") is starting now.")
        case "WhatsApp":
            whatsappPatient(
                patientName: appointment.full_name,
                doctorName: doctorName,
                number: appointment.phone
            )
        default:
            break
        }
    }

    private func callPatient(number: String) {
        let formattedNumber = number.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(formattedNumber)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func smsPatient(number: String, message: String = "") {
        // Encode the message for URL
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(number)&body=\(encodedMessage)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func whatsappPatient(patientName: String, doctorName: String?, number: String) {
        // Clean phone number
        let cleanedNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Dynamic message
        let message = """
        Hello \(patientName),
        
        We are from the RecovFit app. Your appointment with \(doctorName ?? "Doctor") is starting now.
        
        Please join the session via video call.
        """
        
        // Encode message
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // WhatsApp app URL
        let urlString = "whatsapp://send?phone=\(cleanedNumber)&text=\(encodedMessage)"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to WhatsApp Web
            let webUrlString = "https://wa.me/\(cleanedNumber)?text=\(encodedMessage)"
            if let webUrl = URL(string: webUrlString), UIApplication.shared.canOpenURL(webUrl) {
                UIApplication.shared.open(webUrl)
            } else {
                print("Cannot open WhatsApp or Web for this number.")
            }
        }
    }
}

struct EnhancedActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(
                        color: color.opacity(0.2),
                        radius: isPressed ? 2 : 8,
                        x: 0,
                        y: isPressed ? 1 : 4
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Single Instance Components (No Duplicates)

struct EnhancedInfoRows: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct EnhancedInfoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
    }
}

struct EnhancedLoadingViews: View {
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                }
                
                // Animated circle
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                
                // Center medical icon
                Image(systemName: "stethoscope")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
            }
            
            VStack(spacing: 8) {
                Text("Loading Appointments")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Please wait while we fetch your schedule...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct EnhancedErrorViews: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                Text("Oops! Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: retryAction) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 15,
                    x: 0,
                    y: 8
                )
        )
        .padding(.horizontal, 20)
    }
}

struct EnhancedEmptyState: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: searchText.isEmpty ? "calendar.badge.clock" : "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "No Appointments Today" : "No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty
                     ? "You have no scheduled appointments for today. Take a well-deserved break!"
                     : "We couldn't find any appointments matching '\(searchText)'. Try adjusting your search."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            
            if !searchText.isEmpty {
                Button(action: {
                    // Clear search functionality would go here
                }) {
                    Text("Clear Search")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
            }
        }
        .padding(40)
    }
}

struct EnhancedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
