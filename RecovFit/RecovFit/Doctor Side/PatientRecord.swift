import SwiftUI
import AVKit

// MARK: - API Models
struct PatientAPIResponse: Codable {
    let status: String
    let data: [PatientAPIData]
}

struct PatientAPIData: Codable {
    let session_id: Int
    let patient_id: String
    let profile: String?
    let patient_name: String
    let patient_age: Int
    let patient_gender: String
    let consultant_summary: String
    let appointment_date: String
    let content_type: String
    let content_data: [ContentData]
}

// Handles both text + video exercises
struct ContentData: Codable {
    // For text
    let message_text: String?

    // For video
    let sets: String?
    let duration: String?
    let frequency: String?
    let file_path: String?
    let file_name: String?
    let file_type: String?
    let full_server_url: String?
}

// MARK: - Patient Models
struct PatientRecord: Identifiable {
    let id = UUID()
    var name: String
    var age: Int
    var gender: String
    var lastConsultation: String
    var profileImageURL: URL?
    var summary: String
    var exercises: [ExerciseFile]
}

struct ExerciseFile: Identifiable {
    let id = UUID()
    var name: String
    var type: String   // "video" or "text"
    var url: URL?
    var sets: String
    var duration: String
    var frequency: String
    var message: String?   // <-- for text
}

// MARK: - ViewModel
class DoctorPatientViewModel: ObservableObject {
    @Published var patients: [PatientRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    let doctorId: String
    let serverBaseURL = "\(ServiceApi.baseURL)"

    init(doctorId: String) {
        self.doctorId = doctorId
        fetchPatients()
    }

    func fetchPatients() {
        guard let url = URL(string: "\(serverBaseURL)doctor/d_patientrecord.php?doctor_id=\(doctorId)") else { return }
          
        withAnimation(.easeInOut) {
            isLoading = true
            errorMessage = nil
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut) {
                    self.isLoading = false
                }

                if let error = error {
                    withAnimation(.spring()) {
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }

                do {
                    let apiResponse = try JSONDecoder().decode(PatientAPIResponse.self, from: data)
                    let records = apiResponse.data.map { apiPatient -> PatientRecord in
                        let exercises = apiPatient.content_data.map { content -> ExerciseFile in
                            if apiPatient.content_type == "video" {
                                return ExerciseFile(
                                    name: content.file_name ?? "Exercise",
                                    type: "video",
                                    url: content.full_server_url != nil ? URL(string: content.full_server_url!) : nil,
                                    sets: content.sets ?? "",
                                    duration: content.duration ?? "",
                                    frequency: content.frequency ?? "",
                                    message: nil
                                )
                            } else {
                                return ExerciseFile(
                                    name: "Exercise Note",
                                    type: "text",
                                    url: nil,
                                    sets: "",
                                    duration: "",
                                    frequency: "",
                                    message: content.message_text ?? ""
                                )
                            }
                        }

                        return PatientRecord(
                            name: apiPatient.patient_name,
                            age: apiPatient.patient_age,
                            gender: apiPatient.patient_gender,
                            lastConsultation: apiPatient.appointment_date,
                            profileImageURL: apiPatient.profile != nil ? URL(string: "\(self.serverBaseURL)\(apiPatient.profile!)") : nil,
                            summary: apiPatient.consultant_summary,
                            exercises: exercises
                        )
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.patients = records
                    }
                } catch {
                    self.errorMessage = "Failed to parse data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func refreshData() {
        fetchPatients()
    }
    
    func deletePatient(_ patient: PatientRecord) {
        withAnimation(.spring()) {
            patients.removeAll { $0.id == patient.id }
        }
    }
}

// MARK: - Modern Doctor Patient List View
struct DoctorPatientListView: View {
    @StateObject var viewModel: DoctorPatientViewModel
    @State private var searchText = ""

    init(doctorId: String) {
        _viewModel = StateObject(wrappedValue: DoctorPatientViewModel(doctorId: doctorId))
    }

    var filteredPatients: [PatientRecord] {
        if searchText.isEmpty {
            return viewModel.patients
        } else {
            return viewModel.patients.filter { patient in
                patient.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.mint.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    modernLoadingView
                } else if let error = viewModel.errorMessage {
                    modernErrorView(error)
                } else if viewModel.patients.isEmpty {
                    modernEmptyView
                } else {
                    patientListContent
                }
            }
        }
        .navigationTitle("Patient Records")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search patients...")
        .refreshable {
            viewModel.refreshData()
        }
    }

    // MARK: - Patient List Content
    private var patientListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Stats header
                statsHeaderView

                // Patient list
                ForEach(filteredPatients) { patient in
                    NavigationLink(destination: ModernPatientRecoveryDetailView(patient: patient)) {
                        ModernsPatientCard(patient: patient) {
                            viewModel.deletePatient(patient)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Stats Header
    private var statsHeaderView: some View {
        HStack(spacing: 16) {
            StatsCard(
                icon: "person.2.fill",
                title: "Total Patients",
                value: "\(viewModel.patients.count)",
                color: .blue
            )

            StatsCard(
                icon: "figure.strengthtraining.traditional",
                title: "Active Programs",
                value: "\(viewModel.patients.filter { !$0.exercises.isEmpty }.count)",
                color: .green
            )
        }
        .padding(.bottom, 8)
    }

    // MARK: - Loading View
    private var modernLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)

            Text("Loading patient records...")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View
    private func modernErrorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Unable to Load Records")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                viewModel.refreshData()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.blue, in: Capsule())
            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View
    private var modernEmptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .mint.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("No Patient Records")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)

                Text("Patient records will appear here once they're added to the system")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Modern Patient Card
struct ModernsPatientCard: View {
    let patient: PatientRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Patient Avatar
            ZStack {
                if let url = patient.profileImageURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            )
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .mint.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(patient.name.prefix(2).uppercased())
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .shadow(color: .blue.opacity(0.2), radius: 6, x: 0, y: 3)

            // Patient Info
            VStack(alignment: .leading, spacing: 6) {
                Text(patient.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    InfosBadge(icon: "calendar", text: "\(patient.age)y")
                    InfosBadge(icon: "person.fill", text: patient.gender)
                }

                Text("Last visit: \(patient.lastConsultation)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Exercise count badge
            if !patient.exercises.isEmpty {
                VStack(spacing: 4) {
                    Text("\(patient.exercises.count)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.blue)

                    Text("exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Patient", systemImage: "trash")
            }
        }
    }
}

// MARK: - Modern Patient Recovery Detail View
struct ModernPatientRecoveryDetailView: View {
    let patient: PatientRecord
    @State private var selectedExercise: ExerciseFile?

    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02),
                    Color.mint.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    patientHeaderSection
                    consultationSummarySection

                    if !patient.exercises.isEmpty {
                        exerciseProgramSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Patient Record")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Patient Header Section
    private var patientHeaderSection: some View {
        VStack(spacing: 20) {
            // Patient avatar and basic info
            HStack(spacing: 20) {
                ZStack {
                    if let url = patient.profileImageURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(.blue.opacity(0.1))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.7), .mint.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(patient.name.prefix(2).uppercased())
                                    .font(.title.weight(.bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(patient.name)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 6) {
                        PatientInfoRow(icon: "calendar", label: "Age", value: "\(patient.age) years")
                        PatientInfoRow(icon: "person.fill", label: "Gender", value: patient.gender)
                        PatientInfoRow(icon: "clock.fill", label: "Last Visit", value: patient.lastConsultation)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Consultation Summary Section
    private var consultationSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(.green.opacity(0.15), in: Circle())

                Text("Consultation Summary")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

                Spacer()
            }

            Text(patient.summary)
                .font(.body)
                .lineSpacing(6)
                .foregroundColor(.primary)
                .padding(.leading, 44)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Exercise Program Section
    private var exerciseProgramSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(.purple.opacity(0.15), in: Circle())

                Text("Exercise Program (\(patient.exercises.count))")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

                Spacer()
            }

            LazyVStack(spacing: 16) {
                ForEach(patient.exercises) { exercise in
                    ModernExerciseCard(exercise: exercise) {
                        selectedExercise = exercise
                    }
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise)
        }
    }
}

// MARK: - Supporting Views

struct StatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.15), in: Circle())

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
}

struct InfosBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption.weight(.medium))
        }
        .frame(width: 45, height: 45)
        .foregroundColor(.blue)
    }
}

struct PatientInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 16)

            Text(label + ":")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct ModernExerciseCard: View {
    let exercise: ExerciseFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Exercise header
                HStack(spacing: 12) {
                    exerciseTypeIcon

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        // Updated explicit label here
                        Text(exercise.type == "video" ? "Exercise Video" : "Exercise Text")
                            .font(.caption)
                            .foregroundColor(exercise.type == "video" ? .red : .blue)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // Exercise details
                if exercise.type == "video" {
                    HStack(spacing: 12) {
                        ExerciseDetailBadge(
                            icon: "repeat",
                            label: "Sets",
                            value: exercise.sets.isEmpty ? "-" : exercise.sets,
                            color: .blue
                        )

                        ExerciseDetailBadge(
                            icon: "clock",
                            label: "Duration",
                            value: exercise.duration.isEmpty ? "-" : exercise.duration,
                            color: .green
                        )

                        ExerciseDetailBadge(
                            icon: "calendar",
                            label: "Frequency",
                            value: exercise.frequency.isEmpty ? "-" : exercise.frequency,
                            color: .orange
                        )
                    }
                }
                if exercise.type == "video" && exercise.url != nil {
                    ModernVideoThumbnail(url: exercise.url!)
                        .frame(height: 120)
                        .cornerRadius(12)
                } else if exercise.type == "text" {
                    Text(exercise.message ?? "No message")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var exerciseTypeIcon: some View {
        let iconName = exercise.type == "video" ? "play.circle.fill" : "doc.text.fill"
        let iconColor: Color = exercise.type == "video" ? .red : .blue

        Image(systemName: iconName)
            .font(.system(size: 24))
            .foregroundColor(iconColor)
            .frame(width: 48, height: 48)
            .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ExerciseDetailBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ModernVideoThumbnail: View {
    let url: URL
    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))

            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipped()

                // Play button overlay
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    Text("Thumbnail not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 600)

        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                if let cgImage = cgImage {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}

struct ExerciseDetailSheet: View {
    let exercise: ExerciseFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Exercise info
                VStack(spacing: 16) {
                    Text(exercise.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    // Added explicit type label
                    Text(exercise.type == "video" ? "Video Exercise" : "Text Exercise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(exercise.type == "video" ? .red : .blue)

                    // Show details only if video
                    if exercise.type == "video" {
                        HStack(spacing: 20) {
                            DetailItem(icon: "repeat", label: "Sets", value: exercise.sets.isEmpty ? "Not specified" : exercise.sets)
                            DetailItem(icon: "clock", label: "Duration", value: exercise.duration.isEmpty ? "Not specified" : exercise.duration)
                            DetailItem(icon: "calendar", label: "Frequency", value: exercise.frequency.isEmpty ? "Not specified" : exercise.frequency)
                        }
                    }
                }
                // Video player
                if exercise.type == "video", let url = exercise.url {
                    ModernVideoPlayer(url: url)
                        .frame(height: 250)
                        .cornerRadius(16)
                } else if exercise.type == "text" {
                    ScrollView {
                        Text(exercise.message ?? "No notes available")
                            .font(.body)
                            .padding()
                    }
                    .frame(height: 250)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                }
                else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.gray.opacity(0.1))
                        .frame(height: 250)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)

                                Text("Video not available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        )
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ModernVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
