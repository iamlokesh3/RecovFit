import SwiftUI
import PhotosUI

// MARK: - API Response Models
struct DoctorResponse: Codable {
    let status: String
    let message: String
    let doctor_id: String?
    let profile_path: String?
    let profile_url: String?
}

struct DoctorDetailsResponse: Codable {
    let status: String
    let message: String
    let data: DoctorData?
}

struct DoctorData: Codable {
    let doctor_id: String
    let fullName: String?
    let age: String?
    let gender: String?
    let phone: String?
    let email: String?
    let workingDays: String?
    let startTime: String?
    let endTime: String?
    let clinicAddress: String?
    let hospitalAffiliations: String?
    let specializations: String?
    let languages: String?
    let collegeName: String?
    let boardCertified: String?
    let fellowship: String?
    let certifications: String?
    let profile_url: String?
}

// MARK: - Doctor Detail View
struct DoctorDetailsView: View {
    // Profile Image
    let doctorId: String
    @State private var profileItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var hasNewProfileImage = false
    
    // Basic info
    @State private var fullName = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var phone = ""
    @State private var email = ""
    
    // Working hours
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var startTime: Date = defaultTime(hour: 9, minute: 0)
    @State private var endTime: Date = defaultTime(hour: 17, minute: 0)
    
    // Clinic & profile
    @State private var clinicAddress = ""
    @State private var hospitalAffiliations = ""
    @EnvironmentObject var session: SessionManager
    @Binding var path: NavigationPath
    // Specializations
    private let allSpecializations = [
        "Cardiology","Dermatology","Endocrinology","ENT","Gastroenterology","General Medicine",
        "Neurology","Nephrology","Oncology","Orthopedics","Pediatrics","Psychiatry",
        "Pulmonology","Radiology","Rheumatology","Urology","Gynecology","Dentistry",
        "Physiotherapy","Ophthalmology"
    ]
    @State private var selectedSpecializations: Set<String> = []
    
    // Languages
    private let allLanguages = ["English","Tamil","Hindi","Telugu","Kannada","Malayalam","Bengali","Marathi","Urdu"]
    @State private var selectedLanguages: Set<String> = []
    
    // Education & Certifications
    @State private var collegeName = ""
    @State private var boardCertified = false
    @State private var fellowship = ""
    @State private var certifications = ""
    
    // UI state
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var hasLoadedData = false
    @State private var originalData: [String: String] = [:]
    @State private var hasChanges: Bool = false
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.teal.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
                    Text("Loading your profile...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        profileImageSection
                        
                        LazyVStack(spacing: 20) {
                            basicInfoSection
                            workingHoursSection
                            clinicSection
                            specializationSection
                            languagesSection
                            educationSection
                        }
                        
                        saveButtonSection
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            if !hasLoadedData {
                loadExistingData()
            }
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                // ✅ Close alert and navigate to home
                session.isFirstTime = false
                UserDefaults.standard.set(false, forKey: "isFirstTime")

                // Reset the navigation stack → goes directly to home
                path = NavigationPath()
            }
        } message: {
            Text("Doctor details updated successfully!")
        }

        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Load Existing Data Function
    private func loadExistingData() {
        guard !hasLoadedData else { return }
        
        isLoading = true
        
        guard let url = URL(string: ServiceApi.Doctordetails) else {
            isLoading = false
            showErrorMessage("Invalid URL for loading data")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let payload = "doctor_id=\(doctorId)"
        request.httpBody = payload.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                hasLoadedData = true
                
                if let error = error {
                    print("❌ Network Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    return
                }
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📱 Raw Response: \(responseString)")
                }
                
                do {
                    let decoded = try JSONDecoder().decode(DoctorDetailsResponse.self, from: data)
                    if decoded.status == "success", let doctorData = decoded.data {
                        populateFields(from: doctorData)
                        print("✅ Data loaded successfully for doctor: \(doctorData.doctor_id)")
                    } else {
                        print("⚠️ Server returned: \(decoded.message)")
                    }
                } catch {
                    print("❌ Decoding Error: \(error)")
                    // If structured response fails, try to parse as simple JSON
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📊 JSON Response: \(json)")
                    }
                }
            }
        }.resume()
    }
    
    private func populateFields(from data: DoctorData) {
        fullName = data.fullName ?? ""
        age = data.age ?? ""
        gender = data.gender ?? ""
        phone = data.phone ?? ""
        email = data.email ?? ""
        clinicAddress = data.clinicAddress ?? ""
        hospitalAffiliations = data.hospitalAffiliations ?? ""
        collegeName = data.collegeName ?? ""
        fellowship = data.fellowship ?? ""
        certifications = data.certifications ?? ""
        boardCertified = (data.boardCertified ?? "0") == "1"
        
        // Parse working days
        if let workingDaysString = data.workingDays, !workingDaysString.isEmpty {
            selectedDays = Set(workingDaysString.split(separator: ",").compactMap {
                DayOfWeek(rawValue: String($0.trimmingCharacters(in: .whitespaces)))
            })
        }
        
        // Parse times
        if let startTimeString = data.startTime {
            startTime = timeFromString(startTimeString) ?? defaultTime(hour: 9, minute: 0)
        }
        if let endTimeString = data.endTime {
            endTime = timeFromString(endTimeString) ?? defaultTime(hour: 17, minute: 0)
        }
        
        // Parse specializations
        if let specializationsString = data.specializations, !specializationsString.isEmpty {
            selectedSpecializations = Set(specializationsString.split(separator: ",").map {
                String($0.trimmingCharacters(in: .whitespaces))
            })
        }
        
        // Parse languages
        if let languagesString = data.languages, !languagesString.isEmpty {
            selectedLanguages = Set(languagesString.split(separator: ",").map {
                String($0.trimmingCharacters(in: .whitespaces))
            })
        }
        
        // Load existing profile image if available
        if let profileUrl = data.profile_url, !profileUrl.isEmpty {
            loadProfileImage(from: profileUrl)
        }
        
        // Store original data for change detection
        storeOriginalData()
        detectChanges()
    }
    
    private func loadProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("❌ Failed to load profile image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ Invalid image data")
                return
            }
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    profileImage = image
                }
            }
        }.resume()
    }
    
    private func storeOriginalData() {
        originalData = [
            "fullName": fullName,
            "age": age,
            "gender": gender,
            "phone": phone,
            "email": email,
            "clinicAddress": clinicAddress,
            "hospitalAffiliations": hospitalAffiliations,
            "collegeName": collegeName,
            "fellowship": fellowship,
            "certifications": certifications,
            "boardCertified": boardCertified ? "1" : "0",
            "workingDays": selectedDays.sorted(by: { $0.order < $1.order }).map { $0.rawValue }.joined(separator: ","),
            "startTime": timeString(from: startTime),
            "endTime": timeString(from: endTime),
            "specializations": Array(selectedSpecializations).joined(separator: ","),
            "languages": Array(selectedLanguages).joined(separator: ",")
        ]
    }
    
    private func detectChanges() {
        let currentData = [
            "fullName": fullName,
            "age": age,
            "gender": gender,
            "phone": phone,
            "email": email,
            "clinicAddress": clinicAddress,
            "hospitalAffiliations": hospitalAffiliations,
            "collegeName": collegeName,
            "fellowship": fellowship,
            "certifications": certifications,
            "boardCertified": boardCertified ? "1" : "0",
            "workingDays": selectedDays.sorted(by: { $0.order < $1.order }).map { $0.rawValue }.joined(separator: ","),
            "startTime": timeString(from: startTime),
            "endTime": timeString(from: endTime),
            "specializations": Array(selectedSpecializations).joined(separator: ","),
            "languages": Array(selectedLanguages).joined(separator: ",")
        ]
        
        hasChanges = currentData != originalData || hasNewProfileImage
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Complete Your Profile")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Help patients find you by completing your professional details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .teal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: .blue.opacity(0.2), radius: 12, x: 0, y: 6)
                } else {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 130, height: 130)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .teal],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Add Photo")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        )
                }
                
                if hasNewProfileImage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(.blue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: -10, y: -10)
                        }
                    }
                    .frame(width: 130, height: 130)
                }
            }
            
            PhotosPicker(selection: $profileItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                    Text(profileImage == nil ? "Upload Photo" : "Change Photo")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.blue, .teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .onChange(of: profileItem) { oldItem, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            profileImage = uiImage
                            hasNewProfileImage = true
                            detectChanges()
                        }
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        ModernCard(
            icon: "person.text.rectangle.fill",
            title: "Basic Information",
            subtitle: "Essential details about you"
        ) {
            VStack(spacing: 16) {
                ModernTextField(
                    icon: "person.fill",
                    label: "Full Name",
                    placeholder: "Dr. John Smith",
                    text: $fullName
                )
                .onChange(of: fullName) { _, _ in detectChanges() }
                
                HStack(spacing: 12) {
                    ModernTextField(
                        icon: "calendar",
                        label: "Age",
                        placeholder: "35",
                        text: $age,
                        keyboardType: .numberPad
                    )
                    .onChange(of: age) { _, _ in detectChanges() }
                    
                    ModernTextField(
                        icon: "person.2.fill",
                        label: "Gender",
                        placeholder: "Male/Female",
                        text: $gender
                    )
                    .onChange(of: gender) { _, _ in detectChanges() }
                }
                
                HStack(spacing: 12) {
                    ModernTextField(
                        icon: "phone.fill",
                        label: "Phone",
                        placeholder: "+91 9876543210",
                        text: $phone,
                        keyboardType: .phonePad
                    )
                    .onChange(of: phone) { _, _ in detectChanges() }
                    
                    ModernTextField(
                        icon: "envelope.fill",
                        label: "Email",
                        placeholder: "doctor@email.com",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    .onChange(of: email) { _, _ in detectChanges() }
                }
            }
        }
    }
    
    // MARK: - Working Hours Section
    private var workingHoursSection: some View {
        ModernCard(
            icon: "clock.fill",
            title: "Working Hours",
            subtitle: "When are you available?"
        ) {
            VStack(spacing: 20) {
                ModernDaySelector(selectedDays: $selectedDays)
                    .onChange(of: selectedDays) { _, _ in detectChanges() }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Time Range")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start Time")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .onChange(of: startTime) { _, _ in detectChanges() }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("End Time")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .onChange(of: endTime) { _, _ in detectChanges() }
                        }
                    }
                    
                    if endTime <= startTime {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("End time must be later than start time")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Clinic Section
    private var clinicSection: some View {
        ModernCard(
            icon: "building.2.fill",
            title: "Clinic & Affiliations",
            subtitle: "Where do you practice?"
        ) {
            VStack(spacing: 16) {
                ModernTextEditor(
                    icon: "location.fill",
                    label: "Clinic Address",
                    placeholder: "Enter your clinic address",
                    text: $clinicAddress
                )
                .onChange(of: clinicAddress) { _, _ in detectChanges() }
                
                ModernTextEditor(
                    icon: "building.columns.fill",
                    label: "Hospital Affiliations",
                    placeholder: "List affiliated hospitals",
                    text: $hospitalAffiliations
                )
                .onChange(of: hospitalAffiliations) { _, _ in detectChanges() }
            }
        }
    }
    
    // MARK: - Specialization Section
    private var specializationSection: some View {
        ModernCard(
            icon: "stethoscope",
            title: "Specializations",
            subtitle: "Your areas of expertise"
        ) {
            ModernChipSelector(
                options: allSpecializations,
                selection: $selectedSpecializations,
                searchPlaceholder: "Search specializations"
            )
            .onChange(of: selectedSpecializations) { _, _ in detectChanges() }
        }
    }
    
    // MARK: - Languages Section
    private var languagesSection: some View {
        ModernCard(
            icon: "globe.asia.australia.fill",
            title: "Languages",
            subtitle: "Languages you speak"
        ) {
            ModernChipSelector(
                options: allLanguages,
                selection: $selectedLanguages,
                searchPlaceholder: "Search languages"
            )
            .onChange(of: selectedLanguages) { _, _ in detectChanges() }
        }
    }
    
    // MARK: - Education Section
    private var educationSection: some View {
        ModernCard(
            icon: "graduationcap.fill",
            title: "Education & Certifications",
            subtitle: "Your qualifications"
        ) {
            VStack(spacing: 16) {
                ModernTextField(
                    icon: "building.columns",
                    label: "Medical College",
                    placeholder: "Harvard Medical School",
                    text: $collegeName
                )
                .onChange(of: collegeName) { _, _ in detectChanges() }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                        Text("Board Certified")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Toggle("", isOn: $boardCertified)
                            .scaleEffect(0.8)
                            .onChange(of: boardCertified) { _, _ in detectChanges() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                ModernTextField(
                    icon: "star.fill",
                    label: "Fellowship",
                    placeholder: "Fellowship details (optional)",
                    text: $fellowship
                )
                .onChange(of: fellowship) { _, _ in detectChanges() }
                
                ModernTextEditor(
                    icon: "doc.text.fill",
                    label: "Additional Certifications",
                    placeholder: "List your certifications",
                    text: $certifications
                )
                .onChange(of: certifications) { _, _ in detectChanges() }
            }
        }
    }
    
    // MARK: - Save Button Section
    private var saveButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: saveTapped) {
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 18))
                    }
                    
                    Text(isSaving ? "Saving..." : hasChanges ? "Save Changes" : "No Changes")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isSaving ? [.gray, .gray] :
                               hasChanges ? [.blue, .teal] : [.gray.opacity(0.5), .gray.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: (isSaving || !hasChanges) ? .clear : .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                .scaleEffect(isSaving ? 0.98 : 1.0)
            }
            .disabled(isSaving || !hasChanges)
            .padding(.horizontal, 20)
            
            Text(hasChanges ? "You have unsaved changes" : "All information is up to date")
                .font(.caption)
                .foregroundColor(hasChanges ? .orange : .secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - API Save Function
    private func saveTapped() {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorMessage("Please enter your full name")
            return
        }
        guard endTime > startTime else {
            showErrorMessage("End time must be after start time")
            return
        }
        guard !selectedDays.isEmpty else {
            showErrorMessage("Please select your working days")
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            isSaving = true
        }

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add text fields
        let textFields: [String: String] = [
            "doctor_id": doctorId,
            "fullName": fullName,
            "age": age,
            "gender": gender,
            "phone": phone,
            "email": email,
            "workingDays": selectedDays.sorted(by: { $0.order < $1.order }).map { $0.rawValue }.joined(separator: ","),
            "startTime": timeString(from: startTime),
            "endTime": timeString(from: endTime),
            "clinicAddress": clinicAddress,
            "hospitalAffiliations": hospitalAffiliations,
            "specializations": Array(selectedSpecializations).joined(separator: ","),
            "languages": Array(selectedLanguages).joined(separator: ","),
            "collegeName": collegeName,
            "boardCertified": boardCertified ? "1" : "0",
            "fellowship": fellowship,
            "certifications": certifications
        ]
        
        // Add text fields to body
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add profile image if selected
        if hasNewProfileImage,
           let profileImage = profileImage,
           let imageData = profileImage.jpegData(compressionQuality: 0.7) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"profile_image\"; filename=\"\(doctorId)_profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        guard let url = URL(string: ServiceApi.Doctordetails) else {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSaving = false
            }
            showErrorMessage("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSaving = false
                }
                
                if let error = error {
                    showErrorMessage("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    showErrorMessage("No response from server")
                    return
                }
                
                // Print response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📱 Server Response: \(responseString)")
                }
                
                do {
                    let decoded = try JSONDecoder().decode(DoctorResponse.self, from: data)
                    if decoded.status == "success" {
                        showSuccess = true
                        hasNewProfileImage = false
                        storeOriginalData() // Update original data after successful save
                        detectChanges() // Reset change detection
                        print("✅ Doctor Updated: \(decoded.doctor_id ?? "")")
                        if let profileUrl = decoded.profile_url {
                            print("🖼️ Profile Image URL: \(profileUrl)")
                        }
                    } else {
                        showErrorMessage("Server Error: \(decoded.message)")
                    }
                } catch {
                    print("❌ Decoding Error: \(error)")
                    showErrorMessage("Failed to process server response")
                }
            }
        }.resume()
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Helper Functions
private func defaultTime(hour: Int, minute: Int) -> Date {
    var comps = DateComponents()
    comps.hour = hour
    comps.minute = minute
    return Calendar.current.date(from: comps) ?? Date()
}

private func timeString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

private func timeFromString(_ timeString: String) -> Date? {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.date(from: timeString)
}

// MARK: - Modern UI Components

struct ModernCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .background(.regularMaterial, in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Content
            content()
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}

struct ModernTextField: View {
    let icon: String
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(text.isEmpty ? Color.secondary.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct ModernTextEditor: View {
    let icon: String
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(text.isEmpty ? Color.secondary.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

struct ModernDaySelector: View {
    @Binding var selectedDays: Set<DayOfWeek>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Working Days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(DayOfWeek.allCases.sorted(by: { $0.order < $1.order }), id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isSelected {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }
                    } label: {
                        Text(day.rawValue)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                isSelected ?
                                LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? .clear : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                            .shadow(color: isSelected ? .blue.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }
}

struct ModernChipSelector: View {
    let options: [String]
    @Binding var selection: Set<String>
    let searchPlaceholder: String
    
    @State private var searchText = ""
    
    var filteredOptions: [String] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return options
        }
        return options.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField(searchPlaceholder, text: $searchText)
                    .textInputAutocapitalization(.words)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Chips
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 10) {
                    ForEach(filteredOptions, id: \.self) { option in
                        let isSelected = selection.contains(option)
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isSelected {
                                    selection.remove(option)
                                } else {
                                    selection.insert(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                
                                Text(option)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ?
                                LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? .clear : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                            .shadow(color: isSelected ? .blue.opacity(0.2) : .clear, radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 200)
            
            // Selected items summary
            if !selection.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected (\(selection.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selection.removeAll()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    Text(selection.sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Day of Week Enum
enum DayOfWeek: String, CaseIterable, Identifiable {
    case Mon, Tue, Wed, Thu, Fri, Sat, Sun
    var id: String { rawValue }
    var order: Int {
        switch self {
        case .Mon: return 1
        case .Tue: return 2
        case .Wed: return 3
        case .Thu: return 4
        case .Fri: return 5
        case .Sat: return 6
        case .Sun: return 7
        }
    }
}
