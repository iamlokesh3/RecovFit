import SwiftUI

struct Schedule: Identifiable, Codable {
    var id = UUID()
    let patientID: String
    let patientName: String
    let date: Date
    let time: String
}

struct DoctorScheduleView: View {
    let doctorId: String
    @State private var selectedDate = Date()
    @State private var showDatePickerAlert = false
    @State private var allAppointments: [Schedule] = []
    @State private var rejectedAppointments: Set<UUID> = []
    @State private var isLoading = false
    @State private var rejectingAppointments: Set<UUID> = []
    
    // New state variables for confirmation alert
    @State private var showRejectConfirmation = false
    @State private var appointmentToReject: Schedule?
    
    var filteredAppointments: [Schedule] {
        allAppointments
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { !rejectedAppointments.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    if isLoading {
                        loadingView
                    } else if filteredAppointments.isEmpty {
                        emptyStateView
                    } else {
                        appointmentsListView
                    }
                }
                
                // Date picker overlay
                if showDatePickerAlert {
                    datePickerOverlay
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchAppointments(for: selectedDate)
            }
            // Confirmation Alert
            .alert("Reject Appointment", isPresented: $showRejectConfirmation) {
                Button("Cancel", role: .cancel) {
                    appointmentToReject = nil
                }
                Button("Reject", role: .destructive) {
                    if let appointment = appointmentToReject {
                        confirmRejectAppointment(appointment)
                    }
                }
            } message: {
                if let appointment = appointmentToReject {
                    Text("Are you sure you want to reject the appointment with \(appointment.patientName) at \(appointment.time)?")
                }
            }
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Doctor Dashboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showDatePickerAlert = true
                    }
                }) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(showDatePickerAlert ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: showDatePickerAlert)
            }
            
            // Date card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(selectedDate))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("\(filteredAppointments.count)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.blue)
                +
                Text(" appointments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("Loading appointments...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("No Appointments Today")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Your schedule is clear for this date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showDatePickerAlert = true
                }
            }) {
                Label("Choose Different Date", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
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
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Appointments List View
    private var appointmentsListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredAppointments) { appointment in
                    appointmentCard(appointment)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Appointment Card
    private func appointmentCard(_ appointment: Schedule) -> some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack(spacing: 4) {
                Text(timePrefix(appointment.time))
                    .font(.title3.weight(.bold))
                    .foregroundColor(.blue)
                
                Text(timeSuffix(appointment.time))
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.7))
            }
            .frame(width: 60)
            
            // Patient info
            VStack(alignment: .leading, spacing: 6) {
                Text(appointment.patientName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("Patient ID: \(appointment.patientID.prefix(8))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Reject button - Modified to show confirmation
            Button(action: {
                appointmentToReject = appointment
                showRejectConfirmation = true
            }) {
                Group {
                    if rejectingAppointments.contains(appointment.id) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [.red.opacity(0.8), .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(rejectingAppointments.contains(appointment.id))
            .scaleEffect(rejectingAppointments.contains(appointment.id) ? 0.9 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
    
    // MARK: - Date Picker Overlay
    private var datePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showDatePickerAlert = false
                    }
                }
            
            VStack(spacing: 24) {
                Text("Select Date")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showDatePickerAlert = false
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    
                    Button("Apply") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showDatePickerAlert = false
                        }
                        fetchAppointments(for: selectedDate)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 40)
            .scaleEffect(showDatePickerAlert ? 1 : 0.8)
            .opacity(showDatePickerAlert ? 1 : 0)
        }
    }
    
    // MARK: - Helper Functions
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func timePrefix(_ time: String) -> String {
        return String(time.prefix(5)) // "09:30"
    }
    
    private func timeSuffix(_ time: String) -> String {
        guard time.count > 5 else { return "" }
        return String(time.suffix(2)) // "AM" or "PM"
    }
    
    // MARK: - Confirm Reject Appointment (New Function)
    private func confirmRejectAppointment(_ appointment: Schedule) {
        withAnimation(.easeInOut(duration: 0.3)) {
            rejectingAppointments.insert(appointment.id)
        }
        
        rejectAppointment(
            appointmentID: appointment.id,
            patientID: appointment.patientID,
            appointmentTime: appointment.time
        )
        
        appointmentToReject = nil
    }
    
    // MARK: - Fetch Appointments
    private func fetchAppointments(for date: Date) {
        isLoading = true
        allAppointments.removeAll()
        
        guard let url = URL(string: ServiceApi.Doctoresechudled) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let body: [String: Any] = [
            "doctor_id": doctorId,
            "appointment_date": formatter.string(from: date)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = false
                }
            }
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            print("Raw Response:", String(data: data, encoding: .utf8) ?? "nil")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let appointmentsArray = json["data"] as? [[String: Any]] {
                    
                    var fetchedAppointments: [Schedule] = []
                    
                    for item in appointmentsArray {
                        let patientID = item["patient_id"] as? String ?? ""
                        let fullName = item["full_name"] as? String ?? "Unknown"
                        let time = item["appointment_time"] as? String ?? "N/A"
                        
                        fetchedAppointments.append(
                            Schedule(patientID: patientID,
                                   patientName: fullName,
                                   date: date,
                                   time: time)
                        )
                    }
                    
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                            self.allAppointments = fetchedAppointments
                        }
                    }
                } else {
                    print("Invalid JSON structure")
                }
            } catch {
                print("JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Reject Appointment
    private func rejectAppointment(appointmentID: UUID, patientID: String, appointmentTime: String) {
        guard let url = URL(string: ServiceApi.Doctoresechudledupdated) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "doctor_id": doctorId,
            "patient_id": patientID,
            "appointment_time": appointmentTime
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                rejectingAppointments.remove(appointmentID)
            }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status == "success" {
                    
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            rejectedAppointments.insert(appointmentID)
                        }
                        print("✅ Appointment rejected for patient \(patientID) at \(appointmentTime)")
                    }
                } else {
                    print("❌ Failed to reject appointment, response: \(String(data: data, encoding: .utf8) ?? "")")
                }
            } catch {
                print("JSON Parsing Error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
