import SwiftUI
import UniformTypeIdentifiers
import AVKit

// MARK: - Exercise Instruction Type
enum ExerciseInstructionType: String, CaseIterable {
    case textInstructions = "Text Instructions"
    case fileUploads = "File Uploads"
    
    var icon: String {
        switch self {
        case .textInstructions: return "text.document.fill"
        case .fileUploads: return "folder.fill.badge.plus"
        }
    }
}

// MARK: - Exercise File Model
struct ExerciseFileItem: Identifiable, Equatable {
    let id = UUID()
    var fileURL: URL
    var fileName: String
    var fileType: String
    
    var duration: String = ""
    var set: String = ""
    var frequency: String = ""
    
    static func detectFileType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return "Video"
        case "jpg", "jpeg", "png", "gif": return "Image"
        case "pdf": return "PDF"
        case "doc", "docx": return "Document"
        case "txt": return "Text File"
        default: return "File"
        }
    }
}

// MARK: - Patient Exercise Upload View
struct PatientExerciseUploadView: View {
    let doctorId: String
    let appointment: AppointmentAPI
    
    @State private var exerciseFiles: [ExerciseFileItem] = []
    @State private var showFilePicker = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var consultantSummary: String = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    
    // NEW: Exercise instruction type and text
    @State private var selectedInstructionType: ExerciseInstructionType = .textInstructions
    @State private var exerciseTextInstructions: String = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    
                    // MARK: - Header Section
                    headerSection
                    
                    // MARK: - Patient Information Card
                    patientInfoCard
                    
                    // MARK: - Consultant Summary Card
                    consultantSummaryCard
                    
                    // MARK: - Exercise Instructions Type Selector
                    exerciseInstructionTypeSelector
                    
                    // MARK: - Exercise Instructions Section (Dynamic)
                    exerciseInstructionsSection
                    
                    // MARK: - Upload Button
                    uploadButton
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $showFilePicker) {
            DocumentPickerView(selectedFiles: $exerciseFiles)
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") { }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 2) {
            VStack(spacing: 8) {
                Text("Exercise Upload")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text("Upload exercise files and track patient progress")
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Patient Info Card
    private var patientInfoCard: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Patient Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    PatientInfoRows(icon: "person.fill", title: "Name", value: appointment.full_name)
                    PatientInfoRows(icon: "number", title: "Patient ID", value: appointment.patient_id)
                    PatientInfoRows(icon: "calendar", title: "Appointment", value: appointment.appointment_date)
                    PatientInfoRows(icon: "stethoscope", title: "Symptoms", value: appointment.reason_for_visit)
                }
            }
        }
    }
    
    // MARK: - Consultant Summary Card
    private var consultantSummaryCard: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Consultant Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clinical Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 120)
                        
                        if consultantSummary.isEmpty {
                            Text("Enter your clinical observations and recommendations...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $consultantSummary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }
    
    // MARK: - NEW: Exercise Instruction Type Selector
    private var exerciseInstructionTypeSelector: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "switch.2")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Exercise Instructions Method")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                // Segmented Control
                HStack(spacing: 0) {
                    ForEach(ExerciseInstructionType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedInstructionType = type
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedInstructionType == type ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                selectedInstructionType == type
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - NEW: Dynamic Exercise Instructions Section
    private var exerciseInstructionsSection: some View {
        Group {
            if selectedInstructionType == .textInstructions {
                textInstructionsSection
            } else {
                fileUploadSection
            }
        }
    }
    
    // MARK: - NEW: Text Instructions Section
    private var textInstructionsSection: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "text.document.fill")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Exercise Text Instructions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    
                    Text("\(exerciseTextInstructions.count)/2000")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise Instructions for Patient")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 200)
                        
                        if exerciseTextInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Write detailed exercise instructions for the patient...")
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Example:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Text("• Warm-up: 5 minutes light stretching\n• Main exercise: 3 sets of 10 push-ups\n• Cool down: 5 minutes breathing exercises")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $exerciseTextInstructions)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .onChange(of: exerciseTextInstructions) { newValue in
                                if newValue.count > 2000 {
                                    exerciseTextInstructions = String(newValue.prefix(2000))
                                }
                            }
                    }
                }
                
                // Text formatting helper
                HStack(spacing: 16) {
                    Button(action: { exerciseTextInstructions += "• " }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption)
                            Text("Add bullet")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                    
                    Button(action: { exerciseTextInstructions += "\n\n" }) {
                        HStack(spacing: 4) {
                            Image(systemName: "return")
                                .font(.caption)
                            Text("New line")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - File Upload Section (Existing)
    private var fileUploadSection: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Exercise Files")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(exerciseFiles.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.purple)
                        .clipShape(Circle())
                }
                
                // Add Files Button
                Button(action: { showFilePicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Exercise Files")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Videos, images, documents")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Files List
                if !exerciseFiles.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach($exerciseFiles) { $exercise in
                            ExerciseFileCard(exercise: $exercise) {
                                withAnimation(.spring()) {
                                    exerciseFiles.removeAll { $0.id == exercise.id }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Upload Button (Updated)
    private var uploadButton: some View {
        VStack(spacing: 16) {
            if isUploading {
                VStack(spacing: 12) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Uploading... \(Int(uploadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.purple.opacity(0.8))
                .cornerRadius(16)
            }
            
            Button(action: handleUpload) {
                HStack(spacing: 12) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.title3)
                    }
                    
                    Text(isUploading ? "Uploading..." : "Upload Exercise Instructions")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isUploading ? [.gray] : [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isUploading || (!hasContent()))
            .scaleEffect(isUploading ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isUploading)
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.2),
                Color.indigo.opacity(0.3),
                Color.purple.opacity(0.2),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Functions
    private func hasContent() -> Bool {
        switch selectedInstructionType {
        case .textInstructions:
            return !exerciseTextInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fileUploads:
            return !exerciseFiles.isEmpty
        }
    }
    
    // MARK: - Upload Handler (Updated)
    private func handleUpload() {
        guard hasContent() else { return }
        
        withAnimation(.easeInOut) {
            isUploading = true
            uploadProgress = 0.0
        }
        
        // Simulate upload progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            uploadProgress += 0.05
            if uploadProgress >= 1.0 {
                timer.invalidate()
                
                if selectedInstructionType == .textInstructions {
                    uploadTextInstructions { success, message in
                        DispatchQueue.main.async {
                            handleUploadCompletion(success: success, message: message)
                        }
                    }
                } else {
                    uploadExercises(exercises: exerciseFiles) { success, message in
                        DispatchQueue.main.async {
                            handleUploadCompletion(success: success, message: message)
                        }
                    }
                }
            }
        }
    }
    
    private func handleUploadCompletion(success: Bool, message: String) {
        withAnimation(.easeInOut) {
            isUploading = false
            uploadProgress = 0.0
        }
        alertMessage = message
        showAlert = true
        
        if success {
            if selectedInstructionType == .textInstructions {
                exerciseTextInstructions = ""
            } else {
                exerciseFiles.removeAll()
            }
        }
    }
    
    // MARK: - NEW: Upload Text Instructions
    func uploadTextInstructions(completion: @escaping (Bool, String) -> Void) {
        // 1️⃣ Create session
        guard let sessionURL = URL(string: ServiceApi.CreateSession) else {
            completion(false, "Invalid session URL")
            return
        }
        
        var sessionRequest = URLRequest(url: sessionURL)
        sessionRequest.httpMethod = "POST"
        sessionRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let sessionBody =
        "doctor_id=\(doctorId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&patient_id=\(appointment.patient_id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&appointment_date=\(appointment.appointment_date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&consultant_summary=\(consultantSummary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        sessionRequest.httpBody = sessionBody.data(using: .utf8)                           
        
        URLSession.shared.dataTask(with: sessionRequest) { data, _, error in
            if let error = error {
                completion(false, "Session creation failed: \(error.localizedDescription)")
                return
            }
            
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = json["status"] as? String,
                status == "success",
                let sessionId = json["session_id"] as? Int
            else {
                completion(false, "Invalid session response")
                return
            }
            
            // 2️⃣ Upload text instructions (match PHP keys: session_id + message_text)
            guard let textURL = URL(string: ServiceApi.UploadExerciseText) else {
                completion(false, "Invalid text upload URL")
                return
            }
            
            var textRequest = URLRequest(url: textURL)
            textRequest.httpMethod = "POST"
            textRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let textBody =
            "session_id=\(sessionId)" +
            "&message_text=\(self.exerciseTextInstructions.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            textRequest.httpBody = textBody.data(using: .utf8)
            
            URLSession.shared.dataTask(with: textRequest) { data, _, error in
                if let error = error {
                    completion(false, "Text upload failed: \(error.localizedDescription)")
                    return
                }
                
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let status = json["status"] as? String
                else {
                    completion(false, "Invalid server response")
                    return
                }
                
                if status == "success" {
                    completion(true, "Exercise instructions uploaded successfully!")
                } else {
                    let message = json["message"] as? String ?? "Upload failed"
                    completion(false, message)
                }
                
            }.resume()
            
        }.resume()
    }

    
    // MARK: - Upload Exercises with Integration (Existing - No Changes Needed)
    func uploadExercises(
        exercises: [ExerciseFileItem],
        completion: @escaping (Bool, String) -> Void
    ) {
        // 1️⃣ Create session
        guard let sessionURL = URL(string: ServiceApi.CreateSession) else {
            completion(false, "Invalid session URL")
            return
        }
        
        var sessionRequest = URLRequest(url: sessionURL)
        sessionRequest.httpMethod = "POST"
        sessionRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let sessionBody =
        "doctor_id=\(doctorId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&patient_id=\(appointment.patient_id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&appointment_date=\(appointment.appointment_date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
        "&consultant_summary=\(consultantSummary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        sessionRequest.httpBody = sessionBody.data(using: .utf8)
        
        URLSession.shared.dataTask(with: sessionRequest) { data, _, error in
            if let error = error {
                completion(false, "Session creation failed: \(error.localizedDescription)")
                return
            }
            
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = json["status"] as? String,
                status == "success",
                let sessionId = json["session_id"] as? Int
            else {
                completion(false, "Invalid session response")
                return
            }
            
            // 2️⃣ Upload exercises + files
            guard let exercisesURL = URL(string: ServiceApi.UploadExercise) else {
                completion(false, "Invalid upload URL")
                return
            }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("upload-\(UUID().uuidString).tmp")
            FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
            
            guard let handle = try? FileHandle(forWritingTo: tempURL) else {
                completion(false, "Failed to create upload temp file")
                return
            }
            
            func appendString(_ string: String) {
                if let data = string.data(using: .utf8) {
                    handle.write(data)
                }
            }
            
            // Add session ID
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n")
            appendString("\(sessionId)\r\n")
            
            // Add exercises metadata
            for (index, exercise) in exercises.enumerated() {
                let fields: [(String, String)] = [
                    ("exercise_\(index)_sets", exercise.set),
                    ("exercise_\(index)_duration", exercise.duration),
                    ("exercise_\(index)_frequency", exercise.frequency),
                    ("exercise_\(index)_fileName", exercise.fileName),
                    ("exercise_\(index)_fileType", exercise.fileType)
                ]
                
                for (key, value) in fields {
                    appendString("--\(boundary)\r\n")
                    appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                    appendString(value)
                    appendString("\r\n")
                }
            }
            
            // Add files (streaming in chunks)
            for (index, exercise) in exercises.enumerated() {
                appendString("--\(boundary)\r\n")
                appendString("Content-Disposition: form-data; name=\"files[\(index)]\"; filename=\"\(exercise.fileName)\"\r\n")
                appendString("Content-Type: \(self.mimeType(for: exercise.fileURL))\r\n\r\n")
                
                if let fileHandle = try? FileHandle(forReadingFrom: exercise.fileURL) {
                    while autoreleasepool(invoking: {
                        let chunk = fileHandle.readData(ofLength: 1024 * 1024) // 1MB chunks
                        if chunk.count > 0 {
                            handle.write(chunk)
                            return true
                        }
                        return false
                    }) {}
                    fileHandle.closeFile()
                }
                
                appendString("\r\n")
            }
            
            // Close boundary
            appendString("--\(boundary)--\r\n")
            try? handle.close()
            
            // Prepare request
            var request = URLRequest(url: exercisesURL)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 600
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            let session = URLSession(configuration: config)
            
            // Upload using file streaming
            session.uploadTask(with: request, fromFile: tempURL) { data, _, error in
                defer { try? FileManager.default.removeItem(at: tempURL) } // cleanup
                
                if let error = error {
                    completion(false, "Upload failed: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No response data")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Server Response: \(responseString)")
                }
                
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let status = json["status"] as? String
                else {
                    completion(false, "Invalid server response")
                    return
                }
                
                if status == "success" {
                    completion(true, "Exercises uploaded successfully!")
                } else {
                    let message = json["message"] as? String ?? "Upload failed"
                    completion(false, message)
                }
                
            }.resume()
            
        }.resume()
    }
    
    func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Styled Card Component
struct StyledCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Patient Info Row Component
struct PatientInfoRows: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise File Card
struct ExerciseFileCard: View {
    @Binding var exercise: ExerciseFileItem
    let onDelete: () -> Void
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // File Header
            HStack(spacing: 12) {
                fileIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.fileName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(exercise.fileType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { withAnimation(.spring()) { showDetails.toggle() } }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Exercise Details (Expandable)
            if showDetails {
                VStack(spacing: 12) {
                    Divider()
                    
                    VStack(spacing: 16) {
                        StyledTextField(label: "Duration", placeholder: "e.g., 30 minutes", text: $exercise.duration)
                        StyledTextField(label: "Sets", placeholder: "e.g., 3 sets", text: $exercise.set)
                        StyledTextField(label: "Frequency", placeholder: "e.g., Daily", text: $exercise.frequency)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .background(Color(.systemGray6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .animation(.spring(response: 0.4), value: showDetails)
    }
    
    private var fileIcon: some View {
        Group {
            if exercise.fileURL.pathExtension.lowercased() == "mp4" {
                VideoThumbnailView(url: exercise.fileURL)
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
            } else {
                Image(systemName: fileTypeIcon(for: exercise.fileType))
                    .font(.title2)
                    .foregroundColor(fileTypeColor(for: exercise.fileType))
                    .frame(width: 48, height: 48)
                    .background(fileTypeColor(for: exercise.fileType).opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private func fileTypeIcon(for type: String) -> String {
        switch type {
        case "Video": return "video.fill"
        case "Image": return "photo.fill"
        case "PDF": return "doc.text.fill"
        case "Document": return "doc.fill"
        default: return "doc.fill"
        }
    }
    
    private func fileTypeColor(for type: String) -> Color {
        switch type {
        case "Video": return .purple
        case "Image": return .blue
        case "PDF": return .red
        case "Document": return .green
        default: return .gray
        }
    }
}

// MARK: - Styled Text Field
struct StyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
}

// MARK: - Video Thumbnail (Enhanced)
struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            
            // Play button overlay
            if thumbnail != nil {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
        }
        .clipped()
        .onAppear { generateThumbnail() }
    }
    
    func generateThumbnail() {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, error in
            if let cgImage = cgImage {
                DispatchQueue.main.async {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}

// MARK: - Document Picker (Enhanced)
struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedFiles: [ExerciseFileItem]
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .data, .movie, .image, .pdf, .text
        ], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                if !parent.selectedFiles.contains(where: { $0.fileURL == url }) {
                    let newItem = ExerciseFileItem(
                        fileURL: url,
                        fileName: url.lastPathComponent,
                        fileType: ExerciseFileItem.detectFileType(for: url)
                    )
                    parent.selectedFiles.append(newItem)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
