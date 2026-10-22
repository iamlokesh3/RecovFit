import SwiftUI
import AVKit

// MARK: - Enhanced Video Player View
struct EnhancedExerciseVideoPlayerView: View {
    let filePath: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "\(ServiceApi.baseURL)doctor/uploads/exercises/\(encodedPath)") {
                
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 240)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .onAppear {
                        player = AVPlayer(url: url)
                    }
            } else {
                // Error state with modern styling
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Video Unavailable")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Unable to load video content")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Flexible Response Models
struct PatientExerciseResponse: Codable {
    let status: String
    let message: String?
    let session: ExerciseSession?
    let content_type: String?
    let content_data: [ContentDataRaw]?
}

struct ExerciseSession: Codable {
    let id: Int
    let doctor_id: String
    let patient_id: String
    let appointment_date: String
    let appointment_id: Int
    let consultant_summary: String?
    let created_at: String
}

// Raw content that can handle both text and video formats
struct ContentDataRaw: Codable {
    // Text content fields
    let id: Int?
    let message_text: String?
    let created_at: String?
    
    // Video content fields
    let sets: String?
    let duration: String?
    let frequency: String?
    let file_path: String?
    let file_name: String?
    let file_type: String?
    let file_exists: Bool?
    let full_server_url: String?
}

// Processed models
struct TextExercise: Identifiable {
    let id: String
    let message: String
    let createdAt: String?
    
    init(from raw: ContentDataRaw) {
        self.id = "\(raw.id ?? 0)"
        self.message = raw.message_text ?? ""
        self.createdAt = raw.created_at
    }
}

struct VideoExercise: Identifiable {
    let id: String
    let sets: String
    let duration: String
    let frequency: String
    let filePath: String
    let fileName: String
    let fileType: String
    let fileExists: Bool
    let fullServerUrl: String?
    
    init(from raw: ContentDataRaw) {
        self.id = raw.file_path ?? "\(raw.id ?? 0)"
        self.sets = raw.sets ?? ""
        self.duration = raw.duration ?? ""
        self.frequency = raw.frequency ?? ""
        self.filePath = raw.file_path ?? ""
        self.fileName = raw.file_name ?? ""
        self.fileType = raw.file_type ?? ""
        self.fileExists = raw.file_exists ?? false
        self.fullServerUrl = raw.full_server_url
    }
}

// MARK: - Updated ViewModel
class ExerciseViewModel: ObservableObject {
    @Published var session: ExerciseSession?
    @Published var textExercises: [TextExercise] = []
    @Published var videoExercises: [VideoExercise] = []
    @Published var contentType: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasNoExercises = false

    func fetchExercises(for patientId: String) {
        withAnimation { isLoading = true }
        errorMessage = nil
        hasNoExercises = false

        guard let url = URL(string: "\(ServiceApi.baseURL)patient/p_exercise.php") else {
            updateError("Invalid server URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "patient_id=\(patientId)".data(using: .utf8)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.updateError(error.localizedDescription) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.updateError("No data from server") }
                return
            }

            // Debug: Print raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            }

            do {
                let decoded = try JSONDecoder().decode(PatientExerciseResponse.self, from: data)
                DispatchQueue.main.async {
                    self.handleAPIResponse(decoded)
                }
            } catch {
                DispatchQueue.main.async {
                    print("Decoding error: \(error)")
                    self.updateError("Failed to decode server data: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func handleAPIResponse(_ response: PatientExerciseResponse) {
        print("API Response Status: \(response.status)")
        print("Content Type: \(response.content_type ?? "nil")")
        print("Content Data Count: \(response.content_data?.count ?? 0)")
        
        if response.status.lowercased() == "success" {
            self.session = response.session
            self.contentType = response.content_type ?? ""
            
            guard let contentData = response.content_data, !contentData.isEmpty else {
                self.hasNoExercises = true
                return
            }
            
            if response.content_type?.lowercased() == "text" {
                // Process text exercises
                self.textExercises = contentData.map { TextExercise(from: $0) }
                self.videoExercises = []
                self.hasNoExercises = self.textExercises.isEmpty
                print("Text exercises loaded: \(self.textExercises.count)")
            } else if response.content_type?.lowercased() == "video" {
                // Process video exercises
                self.videoExercises = contentData.map { VideoExercise(from: $0) }
                self.textExercises = []
                self.hasNoExercises = self.videoExercises.isEmpty
                print("Video exercises loaded: \(self.videoExercises.count)")
            } else {
                self.hasNoExercises = true
            }
        } else {
            self.hasNoExercises = true
            self.session = response.session
            self.textExercises = []
            self.videoExercises = []
        }
    }

    private func updateError(_ message: String) {
        withAnimation {
            self.errorMessage = message
            self.hasNoExercises = false
        }
    }
}

// MARK: - Main View
struct ExerciseRoutineView: View {
    let patientId: String
    @StateObject private var vm = ExerciseViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color(.systemBackground), Color.teal.opacity(0.02), Color.mint.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Content
            if vm.isLoading {
                EnhancedLoadingView()
            } else if let error = vm.errorMessage {
                EnhancedErrorView(message: error) { vm.fetchExercises(for: patientId) }
            } else if vm.hasNoExercises {
                NoExercisesView { vm.fetchExercises(for: patientId) }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        if let session = vm.session {
                            SessionHeaderCard(session: session)
                        }

                        // Show content based on type
                        if vm.contentType.lowercased() == "text" && !vm.textExercises.isEmpty {
                            TextExercisesSection(exercises: vm.textExercises)
                        } else if vm.contentType.lowercased() == "video" && !vm.videoExercises.isEmpty {
                            VideoExercisesSection(exercises: vm.videoExercises, animateElements: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("My Exercises")
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear { vm.fetchExercises(for: patientId) }
    }
}

// MARK: - Text Exercises Section
struct TextExercisesSection: View {
    let exercises: [TextExercise]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Exercise Instructions")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(exercises.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            
            // Text content cards
            ForEach(exercises) { exercise in
                TextExerciseCard(exercise: exercise)
            }
        }
    }
}

struct TextExerciseCard: View {
    let exercise: TextExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Exercise Plan")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let createdAt = exercise.createdAt {
                    Text(formatDate(createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Exercise text content
            Text(exercise.message)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [.blue.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        
        if let date = formatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Video Exercises Section (Updated)
struct VideoExercisesSection: View {
    let exercises: [VideoExercise]
    let animateElements: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.mint)
                
                Text("Exercise Videos")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(exercises.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .opacity(animateElements ? 1 : 0)
            .offset(y: animateElements ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateElements)
            
            // Exercise cards
            LazyVStack(spacing: 16) {
                ForEach(exercises.indices, id: \.self) { index in
                    NavigationLink(destination: VideoExerciseDetailView(exercise: exercises[index])) {
                        VideoExerciseCard(exercise: exercises[index])
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(animateElements ? 1 : 0)
                    .offset(y: animateElements ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.1), value: animateElements)
                }
            }
        }
    }
}

// MARK: - Video Exercise Card
struct VideoExerciseCard: View {
    let exercise: VideoExercise
    
    var body: some View {
        HStack(spacing: 16) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Exercise info
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.fileName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    ExerciseTag(icon: "repeat", value: exercise.sets, color: .orange)
                    ExerciseTag(icon: "clock", value: exercise.duration, color: .blue)
                }
                
                ExerciseTag(icon: "calendar", value: exercise.frequency, color: .green)
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Video Exercise Detail View
struct VideoExerciseDetailView: View {
    let exercise: VideoExercise
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.teal.opacity(0.02),
                    Color.mint.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Video Section
                    EnhancedExerciseVideoPlayerView(filePath: exercise.filePath)
                    
                    // Exercise Details Card
                    VideoExerciseDetailsCard(exercise: exercise)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(
            // Custom back button
            HStack {
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 50)
            }
        )
    }
}

struct VideoExerciseDetailsCard: View {
    let exercise: VideoExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Exercise Details")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                DetailRow(icon: "repeat", title: "Sets", value: exercise.sets, color: .orange)
                DetailRow(icon: "clock", title: "Duration", value: exercise.duration, color: .blue)
                DetailRow(icon: "calendar", title: "Frequency", value: exercise.frequency, color: .green)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

// MARK: - Remaining Support Components (keeping all the other components the same)
struct NoExercisesView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.mint.opacity(0.1), .teal.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.mint)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text("No Exercises Yet")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("You haven't been assigned any exercises yet. Check back later or contact your doctor for a personalized workout plan.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Refresh")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(colors: [.mint, .teal], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(25)
                }
                .padding(.horizontal, 40)
                
                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Session Header Card
struct SessionHeaderCard: View {
    let session: ExerciseSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.teal)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.teal.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Details")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Dr. \(session.doctor_id)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.teal)
                }
                
                Spacer()
            }
            
            // Appointment info
            HStack(spacing: 16) {
                InfoPills(icon: "calendar", value: formatDate(session.appointment_date), color: .blue)
                InfoPills(icon: "number", value: "ID: \(session.appointment_id)", color: .purple)
            }
            
            // Consultant summary
            if let summary = session.consultant_summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Doctor's Notes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(summary)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .padding(.leading, 16)
                        .overlay(
                            Rectangle()
                                .fill(Color.teal)
                                .frame(width: 3)
                                .cornerRadius(1.5),
                            alignment: .leading
                        )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatterGet = DateFormatter()
        formatterGet.dateFormat = "yyyy-MM-dd"
        
        let formatterPrint = DateFormatter()
        formatterPrint.dateStyle = .medium
        
        if let date = formatterGet.date(from: dateString) {
            return formatterPrint.string(from: date)
        }
        return dateString
    }
}

// MARK: - Support Components
struct InfoPills: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ExerciseTag: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Loading and Error Views
struct EnhancedLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.teal.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            
            Text("Loading your exercises...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EnhancedErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
