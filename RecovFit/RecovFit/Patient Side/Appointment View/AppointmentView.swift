import SwiftUI

// MARK: - Doctor Model
struct AppointmentDoctor: Identifiable, Codable {
    let doctor_id: String
    var id: String { doctor_id }
    let name: String
    let specialty: String
    let imageName: String
    let hospital: String
}

// MARK: - AppointmentView
struct AppointmentView: View {
    let patientId: String
    @State private var searchText = ""
    @State private var selectedSpecialty = "All"
    @State private var doctors: [AppointmentDoctor] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var selectedTab: PatientTabBar.Tab
    
    let specialties = ["All","Cardiology","Dermatology","Endocrinology","ENT","Gastroenterology","General Medicine",
                       "Neurology","Nephrology","Oncology","Orthopedics","Pediatrics","Psychiatry",
                       "Pulmonology","Radiology","Rheumatology","Urology","Gynecology","Dentistry",
                       "Physiotherapy","Ophthalmology"]

    var filteredDoctors: [AppointmentDoctor] {
        doctors.filter {
            (selectedSpecialty == "All" || $0.specialty == selectedSpecialty) &&
            (searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Search Bar
                searchSection
                
                // Specialty Chips
                specialtyChipsSection
                
                // Doctor List
                doctorListSection
            }
            .background(backgroundGradient)
            .task {
                await fetchDoctors()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Find Your Doctor")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Book appointments with trusted healthcare professionals")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "stethoscope")
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .font(.system(size: 18, weight: .medium))
            
            TextField("Search doctors, specialties...", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .indigo.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Specialty Chips Section
    private var specialtyChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(specialties, id: \.self) { specialty in
                    specialtyChip(for: specialty)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }
    
    private func specialtyChip(for specialty: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                selectedSpecialty = specialty
            }
        } label: {
            Text(specialty)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    Group {
                        if selectedSpecialty == specialty {
                            LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color(.systemGray5), Color(.systemGray4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .foregroundColor(selectedSpecialty == specialty ? .white : .primary)
                .clipShape(Capsule())
                .shadow(
                    color: selectedSpecialty == specialty ? .blue.opacity(0.3) : .black.opacity(0.1),
                    radius: selectedSpecialty == specialty ? 8 : 4,
                    y: selectedSpecialty == specialty ? 4 : 2
                )
        }
    }
    
    // MARK: - Doctor List Section
    private var doctorListSection: some View {
        Group {
            if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else {
                doctorScrollView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("Finding doctors...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private var doctorScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(filteredDoctors) { doctor in
                    NavigationLink(destination: BookingDetailView(
                        doctor: doctor,
                        patientId: patientId,
                        selectedTab: $selectedTab
                    )) {
                        EnhancedDoctorCardView(doctor: doctor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.05),
                Color.indigo.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - API Call
    func fetchDoctors() async {
        guard let url = URL(string: ServiceApi.Patiientappointment) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let fetchedDoctors = try decoder.decode([AppointmentDoctor].self, from: data)
            DispatchQueue.main.async {
                self.doctors = fetchedDoctors
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load doctors: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Enhanced Doctor Card (FIXED)
struct EnhancedDoctorCardView: View {
    let doctor: AppointmentDoctor

    var body: some View {
        HStack(spacing: 18) {
            // Doctor Image
            doctorImageView
            
            // Doctor Info
            doctorInfoView
            
            Spacer()
            
            // Navigation Indicator (replaces conflicting button)
            navigationIndicator
        }
        .padding(24)
        .background(cardBackground)
        .overlay(cardOverlay)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
    
    private var doctorImageView: some View {
        AsyncImage(url: URL(string: "\(ServiceApi.baseURL)\(doctor.imageName)")) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if phase.error != nil {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                ProgressView()
                    .frame(width: 80, height: 80)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .indigo.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var doctorInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(doctor.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text(doctor.specialty)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(doctor.hospital)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    // FIXED: Replaced conflicting button with navigation indicator
    private var navigationIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Book")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .indigo.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .blue.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [.blue.opacity(0.2), .indigo.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Enhanced Booking Detail View
struct BookingDetailView: View {
    let doctor: AppointmentDoctor
    let patientId: String
    
    @State private var selectedDate = Date()
    @State private var startTime: String? = nil
    @State private var endTime: String? = nil
    @Binding var selectedTab: PatientTabBar.Tab
    
    private let availableTimes = [
        "09:00 AM","09:30 AM","10:00 AM","10:30 AM","11:00 AM","11:30 AM","12:00 PM",
        "12:30 PM","01:00 PM","01:30 PM","02:00 PM","02:30 PM","03:00 PM","03:30 PM",
        "04:00 PM","04:30 PM","05:00 PM"
    ]
    
    private var selectedTimeRange: String? {
        if let start = startTime, let end = endTime {
            return "\(start) - \(end)"
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header Card
                enhancedDoctorCard
                
                // Date Selection Card
                enhancedDatePickerCard
                
                // Time Selection Card
                enhancedTimeSlotCard
                
                // Book Button or Warning
                if let time = selectedTimeRange {
                    NavigationLink(destination: NewPatientDetailView(
                        doctor: doctor,
                        selectedDate: selectedDate,
                        selectedTime: time,
                        patientId: patientId,
                        selectedTab: $selectedTab
                    )) {
                        enhancedGradientButton(title: "Continue to Book")
                    }
                    .padding(.top, 12)
                } else {
                    warningMessage
                }
            }
            .padding(24)
        }
        .navigationTitle("Book Appointment")
        .navigationBarTitleDisplayMode(.large)
        .background(enhancedBackgroundGradient)
    }
    
    // MARK: - Enhanced Doctor Card
    private var enhancedDoctorCard: some View {
        HStack(spacing: 20) {
            AsyncImage(url: URL(string: "\(ServiceApi.baseURL)\(doctor.imageName)")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(colors: [.blue.opacity(0.4), .indigo.opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
            )
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(doctor.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(doctor.specialty)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .indigo],
                                     startPoint: .leading, endPoint: .trailing)
                    )
                
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(doctor.hospital)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(colors: [.blue.opacity(0.2), .indigo.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Enhanced Date Picker Card
    private var enhancedDatePickerCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .indigo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("Select Appointment Date")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
            }
            
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.blue)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(16)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Enhanced Time Slot Card
    private var enhancedTimeSlotCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .indigo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("Select Time Range")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                // From Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("Start Time", selection: $startTime) {
                        ForEach(availableTimes, id: \.self) { time in
                            Text(time).tag(time as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                }
                
                // To Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("End Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("End Time", selection: $endTime) {
                        ForEach(availableTimes, id: \.self) { time in
                            if let start = startTime {
                                if availableTimes.firstIndex(of: time)! > availableTimes.firstIndex(of: start)! {
                                    Text(time).tag(time as String?)
                                }
                            } else {
                                Text(time).tag(time as String?)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Enhanced Button
    private func enhancedGradientButton(title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.blue, .indigo, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Warning Message
    private var warningMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.orange)
            
            Text("Please select both start and end times to continue")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Background
    private var enhancedBackgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.03),
                Color.indigo.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Enhanced NewPatientDetailView
struct NewPatientDetailView: View {
    let doctor: AppointmentDoctor
    let selectedDate: Date
    let selectedTime: String
    let patientId: String
    
    @Binding var selectedTab: PatientTabBar.Tab
    @Environment(\.dismiss) private var dismiss
    
    @State private var reasonForAppointment: String = ""
    @State private var bookingMessage: String?
    @State private var isBooking = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Appointment Summary Card
                appointmentSummaryCard
                
                // Reason Input Card
                reasonInputCard
                
                // Confirm Button
                confirmButton
                
                // Status Message
                if let message = bookingMessage {
                    statusMessage(message)
                }
            }
            .padding(24)
        }
        .navigationTitle("Confirm Appointment")
        .navigationBarTitleDisplayMode(.large)
        .background(enhancedBackgroundGradient)
    }
    
    // MARK: - Appointment Summary Card
    private var appointmentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .blue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("Appointment Details")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                appointmentDetailRow(icon: "person.fill.checkmark", title: "Doctor", value: doctor.name)
                appointmentDetailRow(icon: "stethoscope", title: "Specialty", value: doctor.specialty)
                appointmentDetailRow(icon: "building.2.fill", title: "Hospital", value: doctor.hospital)
                appointmentDetailRow(icon: "calendar", title: "Date", value: selectedDate.formatted(date: .long, time: .omitted))
                appointmentDetailRow(icon: "clock.fill", title: "Time", value: selectedTime)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
    
    private func appointmentDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .indigo],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Reason Input Card
    private var reasonInputCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .indigo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("Reason for Visit")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
            }
            
            TextEditor(text: $reasonForAppointment)
                .frame(minHeight: 120)
                .padding(16)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .overlay(
                    Group {
                        if reasonForAppointment.isEmpty {
                            Text("Please describe your symptoms or reason for this appointment...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Confirm Button
    private var confirmButton: some View {
        Button {
            Task { await bookAppointment() }
        } label: {
            HStack(spacing: 12) {
                if isBooking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                }
                
                Text(isBooking ? "Booking..." : "Confirm Appointment")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: isBooking ? [.gray, .gray.opacity(0.8)] : [.green, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isBooking ? .gray.opacity(0.3) : .green.opacity(0.4), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isBooking || reasonForAppointment.isEmpty)
    }
    
    // MARK: - Status Message
    private func statusMessage(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: message.contains("success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(message.contains("success") ? .green : .red)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((message.contains("success") ? Color.green : Color.red).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((message.contains("success") ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Background
    private var enhancedBackgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.green.opacity(0.03),
                Color.blue.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Book Appointment API Call
    func bookAppointment() async {
        guard !reasonForAppointment.isEmpty else {
            bookingMessage = "Please enter a reason for your visit"
            return
        }
        
        guard let url = URL(string: ServiceApi.Appointmentbooking) else {
            bookingMessage = "Invalid URL"
            return
        }
        
        isBooking = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        
        let payload: [String: Any] = [
            "doctor_id": doctor.doctor_id,
            "patient_id": patientId,
            "appointment_date": dateString,
            "appointment_time": selectedTime,
            "reason_for_visit": reasonForAppointment
        ]
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    self.isBooking = false
                    if let success = response["success"] as? Bool, success {
                        self.selectedTab = .home
                        self.dismiss()
                    } else {
                        self.bookingMessage = "Failed to book appointment. Please try again."
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isBooking = false
                self.bookingMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
