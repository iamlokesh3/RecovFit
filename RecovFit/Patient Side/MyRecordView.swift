import SwiftUI
import AVKit

// MARK: - API Models (updated to decode content_type and content_data)
struct PatientDoctorAPIResponse: Codable {
    let status: String
    let data: [PatientDoctorAPIData]
}

struct PatientDoctorAPIData: Codable {
    let session_id: Int
    let doctor_id: String
    let doctor_name: String
    let doctor_department: String
    let doctor_hospital: String
    let doctor_age: Int
    let doctor_gender: String
    let doctor_profile: String?
    let doctor_profile_url: String?
    let consultant_summary: String
    let appointment_date: String
    let content_type: String
    let content_data: [ContentData]

    struct ContentData: Codable {
        let message_text: String?
        let sets: String?
        let duration: String?
        let frequency: String?
        let file_path: String?
        let file_name: String?
        let file_type: String?
        let file_exists: Bool?
        let full_server_url: String?
    }
}

// MARK: - Local Models
struct DoctorRecord: Identifiable {
    let id = UUID()
    var name: String
    var specialty: String
    var hospital: String
    var lastConsultation: String
    var profileImageURL: URL?
    var summary: String
    var exercisesText: [String] = []
    var exercisesVideo: [ExerciseFiles] = []
}

struct ExerciseFiles: Identifiable {
    let id = UUID()
    var name: String
    var type: String
    var url: URL?
    var sets: String
    var duration: String
    var frequency: String
}

// MARK: - ViewModel
class PatientDoctorViewModel: ObservableObject {
    @Published var doctors: [DoctorRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchDoctors(patientId: String) {
        guard let url = URL(string:"\(ServiceApi.PatientReport)?patient_id=\(patientId)") else {
            updateError("Invalid API configuration")
            return
        }

        withAnimation(.easeInOut) {
            isLoading = true
            errorMessage = nil
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut) {
                    self.isLoading = false
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.updateError("Connection failed. Please try again.")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.updateError("No data received from server")
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(PatientDoctorAPIResponse.self, from: data)

                DispatchQueue.main.async {
                    if decoded.status == "success" {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.doctors = decoded.data.map { apiDoctor in
                                var texts: [String] = []
                                var videos: [ExerciseFiles] = []

                                for content in apiDoctor.content_data {
                                    if let text = content.message_text {
                                        texts.append(text)
                                    } else if let fileName = content.file_name,
                                              let fileType = content.file_type,
                                              let urlStr = content.full_server_url,
                                              let url = URL(string: urlStr) {
                                        let exercise = ExerciseFiles(
                                            name: fileName,
                                            type: fileType,
                                            url: url,
                                            sets: content.sets ?? "-",
                                            duration: content.duration ?? "-",
                                            frequency: content.frequency ?? "-"
                                        )
                                        videos.append(exercise)
                                    }
                                }

                                return DoctorRecord(
                                    name: apiDoctor.doctor_name,
                                    specialty: apiDoctor.doctor_department,
                                    hospital: apiDoctor.doctor_hospital,
                                    lastConsultation: apiDoctor.appointment_date,
                                    profileImageURL: URL(string: apiDoctor.doctor_profile_url ?? ""),
                                    summary: apiDoctor.consultant_summary,
                                    exercisesText: texts,
                                    exercisesVideo: videos
                                )
                            }
                        }
                    } else {
                        self.updateError("Failed to load medical records")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateError("Failed to process medical data")
                }
            }
        }.resume()
    }

    private func updateError(_ message: String) {
        withAnimation(.easeInOut) {
            errorMessage = message
        }
    }
}

// MARK: - Main View
struct MyRecordView: View {
    @StateObject var viewModel = PatientDoctorViewModel()
    let patientId: String
    @State private var animateElements = false

    var body: some View {
        NavigationStack {
            ZStack {
                MedicalRecordsBackground()

                Group {
                    if viewModel.isLoading {
                        MedicalLoadingView()
                    } else if let error = viewModel.errorMessage {
                        MedicalErrorView(message: error) {
                            viewModel.fetchDoctors(patientId: patientId)
                        }
                    } else if viewModel.doctors.isEmpty {
                        EmptyRecordsView()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 20) {
                                RecordsStatsCard(doctorCount: viewModel.doctors.count)
                                    .opacity(animateElements ? 1 : 0)
                                    .offset(y: animateElements ? 0 : 20)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateElements)

                                ForEach(viewModel.doctors.indices, id: \.self) { index in
                                    NavigationLink(destination: EnhancedDoctorDetailView(doctor: viewModel.doctors[index])) {
                                        EnhancedDoctorCard(doctor: viewModel.doctors[index])
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .opacity(animateElements ? 1 : 0)
                                    .offset(y: animateElements ? 0 : 30)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2 + Double(index) * 0.1), value: animateElements)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("My Medical Records")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.fetchDoctors(patientId: patientId)
                withAnimation {
                    animateElements = true
                }
            }
        }
    }
}

// MARK: - Doctor Card
struct EnhancedDoctorCard: View {
    let doctor: DoctorRecord

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let url = doctor.profileImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_):
                            DoctorPlaceholderImage()
                        default:
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    DoctorPlaceholderImage()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(doctor.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    MedicalBadge(text: doctor.specialty, color: .blue)
                    if doctor.exercisesVideo.count > 0 {
                        MedicalBadge(text: "\(doctor.exercisesVideo.count) exercises", color: .green)
                    }
                    if doctor.exercisesText.count > 0 {
                        MedicalBadge(text: "\(doctor.exercisesText.count) instructions", color: .mint)
                    }
                }

                HStack(spacing: 12) {
                    Label(doctor.hospital, systemImage: "building.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Label(formatDate(doctor.lastConsultation), systemImage: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }

    private func formatDate(_ dateString: String) -> String {
        // Implement your preferred date formatting here
        return dateString
    }
}

// MARK: - Doctor Detail View
struct EnhancedDoctorDetailView: View {
    let doctor: DoctorRecord
    @Environment(\.presentationMode) var presentationMode
    @State private var animateElements = false

    var body: some View {
        ZStack {
            MedicalRecordsBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    DoctorProfileHeader(doctor: doctor)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateElements)

                    ConsultationSummaryCard(summary: doctor.summary)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateElements)

                    if !doctor.exercisesText.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Exercise Instructions")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.bottom, 8)

                            ForEach(doctor.exercisesText, id: \.self) { text in
                                Text(text)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(6)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                            }
                        }
                        .padding(.vertical, 20)
                    }

                    if !doctor.exercisesVideo.isEmpty {
                        RecoveryPlanSection(exercises: doctor.exercisesVideo, animateElements: animateElements)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(
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
        .onAppear {
            withAnimation {
                animateElements = true
            }
        }
    }
}

// MARK: - Support Components (same as your existing components)

struct MedicalRecordsBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color.teal.opacity(0.03), Color.mint.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { _ in
                    Circle()
                        .fill(Color.teal.opacity(0.05))
                        .frame(width: 120, height: 120)
                        .blur(radius: 30)
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct DoctorPlaceholderImage: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [.teal.opacity(0.8), .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 72, height: 72)

            Image(systemName: "stethoscope")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct MedicalBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            )
    }
}

struct RecordsStatsCard: View {
    let doctorCount: Int

    var body: some View {
        HStack(spacing: 24) {
            StatItems(icon: "stethoscope", title: "Doctors", value: "\(doctorCount)", color: .teal)
            StatItems(icon: "calendar.badge.checkmark", title: "Consultations", value: "\(doctorCount)", color: .blue)
            StatItems(icon: "heart.text.square", title: "Active Plans", value: "\(doctorCount)", color: .green)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

struct StatItems: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
                )

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DoctorProfileHeader: View {
    let doctor: DoctorRecord

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let url = doctor.profileImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle()
                                .fill(LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(Image(systemName: "stethoscope").font(.system(size: 32)).foregroundColor(.white))
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.white.opacity(0.8), .clear],
                                                  startPoint: .topLeading,
                                                  endPoint: .bottomTrailing),
                                    lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                } else {
                    Circle()
                        .fill(LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: "stethoscope").font(.system(size: 32)).foregroundColor(.white))
                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                }
            }

            VStack(spacing: 12) {
                Text(doctor.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    MedicalInfoPill(icon: "cross.case", text: doctor.specialty, color: .teal)
                    MedicalInfoPill(icon: "building.2", text: doctor.hospital, color: .blue)
                }

                Text("Last consultation: \(doctor.lastConsultation)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing),
                                lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

struct MedicalInfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        )
    }
}

struct ConsultationSummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.purple)

                Text("Consultation Summary")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()
            }

            Text(summary)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .padding(.leading, 16)
                .overlay(
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: 3)
                        .cornerRadius(1.5),
                    alignment: .leading
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing),
                                lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

struct RecoveryPlanSection: View {
    let exercises: [ExerciseFiles]
    let animateElements: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.mint)

                Text("Recovery Plan")
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
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateElements)

            LazyVStack(spacing: 16) {
                ForEach(exercises.indices, id: \.self) { index in
                    EnhancedExerciseCards(exercise: exercises[index])
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4 + Double(index) * 0.1), value: animateElements)
                }
            }
        }
    }
}

struct EnhancedExerciseCards: View {
    let exercise: ExerciseFiles
    @State private var showVideo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: exercise.type.lowercased() == "video" ? [.purple, .pink] : [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: exercise.type.lowercased() == "video" ? "play.fill" : "doc.text.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(exercise.type)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if exercise.type.lowercased() == "video" {
                    Button(action: { showVideo.toggle() }) {
                        Image(systemName: showVideo ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                ExerciseDetailPill(icon: "repeat", title: "Sets", value: exercise.sets.isEmpty ? "-" : exercise.sets, color: .orange)
                ExerciseDetailPill(icon: "clock", title: "Duration", value: exercise.duration.isEmpty ? "-" : exercise.duration, color: .blue)
                ExerciseDetailPill(icon: "calendar", title: "Frequency", value: exercise.frequency.isEmpty ? "-" : exercise.frequency, color: .green)
            }

            if showVideo && exercise.type.lowercased() == "video", let url = exercise.url {
                EnhancedVideoPlayer(url: url)
                    .frame(height: 200)
                    .cornerRadius(16)
                    .transition(.opacity.combined(with: .scale))
            }
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
        .animation(.easeInOut, value: showVideo)
    }
}

struct ExerciseDetailPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }
}

struct EnhancedVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Loading and Error Views

struct MedicalLoadingView: View {
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

            Text("Loading medical records...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MedicalErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unable to load records")
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
                    .background(LinearGradient(colors: [.teal, .mint], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct EmptyRecordsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.teal.opacity(0.6))

            Text("No Medical Records")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("You don't have any medical records yet. Visit a doctor to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
