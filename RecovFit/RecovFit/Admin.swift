import SwiftUI
import PDFKit
import Foundation

// MARK: - Enhanced Data Models with Credentials
struct AdminDoctor: Identifiable {
    let id: Int
    let name: String
    let email: String
    let phone: String
    let specialization: String
    let clinic: String
    let license: String
    let licenseURL: String
    var status: AdminDoctorStatus
    var doctorID: String? // New: Generated doctor ID
    var generatedPassword: String? // New: Generated password
    var approvedDate: Date? // New: Approval timestamp
    var credentialsSent: Bool = false // New: Track if credentials were sent
}

enum AdminDoctorStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

// MARK: - API Service Manager with Email Support
class AdminAPIService: ObservableObject {
    private let baseURL = ServiceApi.baseURL
    
    // MARK: - Data Models for API Responses
    struct DoctorRegistration: Codable, Identifiable {
        let id: String
        let name: String
        let email: String
        let phone: String
        let specialization: String
        let clinic_hospital: String
        let license_number: String
        let license_document: String
        let status: String
        let created_at: String
        let license_url: String // FIXED: Added missing license_url field
    }
    
    struct GetInfoResponse: Codable {
        let status: String
        let registrations: [DoctorRegistration]
    }
    
    struct ApprovalResponse: Codable {
        let status: String
        let message: String
        let credentials: DoctorCredentials?
        let email_status: EmailStatus?
    }
    
    struct DoctorCredentials: Codable {
        let id: String
        let password: String
        let email: String
    }
    
    struct RejectResponse: Codable {
        let status: String
        let message: String
        let email_status: EmailStatus?
    }
    
    struct EmailStatus: Codable {
        let status: String
        let message: String
    }
    
    // MARK: - Get Doctor Registrations
    func getDoctorRegistrations() async throws -> [AdminDoctor] {
        guard let url = URL(string: ServiceApi.AdminGetinfo) else {
            print("❌ Invalid URL: \(ServiceApi.AdminGetinfo)")
            throw APIErrors.invalidURL
        }
        
        print("🌐 Fetching doctors from: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Response Status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📝 Response Data: \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ Server error with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw APIErrors.serverError
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(GetInfoResponse.self, from: data)
            print("✅ Successfully decoded \(apiResponse.registrations.count) doctors")
            
            return apiResponse.registrations.map { registration in
                AdminDoctor(
                    id: Int(registration.id) ?? 0,
                    name: registration.name,
                    email: registration.email,
                    phone: registration.phone,
                    specialization: registration.specialization,
                    clinic: registration.clinic_hospital,
                    license: registration.license_number,
                    licenseURL: registration.license_url, // FIXED: Use the license_url from API response
                    status: AdminDoctorStatus(rawValue: registration.status) ?? .pending
                )
            }
        } catch {
            print("❌ Decoding error: \(error)")
            throw APIErrors.decodingError
        }
    }
    
    // MARK: - Fixed Approve Doctor (Form POST)
    func approveDoctor(doctorId: String, email: String) async throws -> ApprovalResponse {
        guard let url = URL(string: ServiceApi.AdminApprovel) else {
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Send as form data
        let bodyString = "doctor_id=\(doctorId)&email=\(email)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIErrors.serverError
        }
        
        do {
            return try JSONDecoder().decode(ApprovalResponse.self, from: data)
        } catch {
            print("❌ Approval decoding error:", error)
            throw APIErrors.decodingError
        }
    }
    
    // MARK: - Fixed Reject Doctor (Form POST)
    func rejectDoctor(doctorId: String, email: String, rejectionReason: String = "") async throws -> RejectResponse {
        guard let url = URL(string: ServiceApi.AdminReject) else {
            throw APIErrors.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Send as form data
        let bodyString = "doctor_id=\(doctorId)&email=\(email)&rejection_reason=\(rejectionReason)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIErrors.serverError
        }
        
        do {
            return try JSONDecoder().decode(RejectResponse.self, from: data)
        } catch {
            print("❌ Reject decoding error:", error)
            throw APIErrors.decodingError
        }
    }
}

// MARK: - API Error Enum
enum APIErrors: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Enhanced Credentials Management
class CredentialsManager: ObservableObject {
    @Published var approvedDoctors: [String: DoctorCredentials] = [:]
    
    struct DoctorCredentials {
        let doctorID: String
        let password: String
        let approvalDate: Date
        let doctorName: String
        let email: String
    }
    
    func storeCredentials(_ credentials: AdminAPIService.DoctorCredentials, for doctor: AdminDoctor) {
        let localCredentials = DoctorCredentials(
            doctorID: credentials.id,
            password: credentials.password,
            approvalDate: Date(),
            doctorName: doctor.name,
            email: credentials.email
        )
        
        approvedDoctors[credentials.id] = localCredentials
    }
    
    func getCredentials(for doctorID: String) -> DoctorCredentials? {
        return approvedDoctors[doctorID]
    }
    
    func getAllCredentials() -> [DoctorCredentials] {
        return Array(approvedDoctors.values).sorted { $0.approvalDate > $1.approvalDate }
    }
}

// MARK: - Universal Document Viewer Container
struct DocumentViewContainer: UIViewRepresentable {
    let url: URL
    @State private var documentType: DocumentType = .unknown
    
    enum DocumentType {
        case pdf
        case image
        case unknown
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground
        
        // Determine document type from URL
        let pathExtension = url.pathExtension.lowercased()
        
        print("📄 Attempting to load document from: \(url.absoluteString)")
        print("📄 File extension: \(pathExtension)")
        
        if pathExtension == "pdf" {
            documentType = .pdf
            loadPDFDocument(in: containerView)
        } else if ["jpg", "jpeg", "png", "gif", "bmp"].contains(pathExtension) {
            documentType = .image
            loadImageDocument(in: containerView)
        } else {
            print("⚠️ Unknown document type: \(pathExtension)")
            documentType = .unknown
            showErrorDocument(in: containerView, message: "Unsupported document type: .\(pathExtension)")
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
    
    private func loadPDFDocument(in containerView: UIView) {
        let pdfView = PDFView()
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    print("✅ PDF loaded successfully with \(document.pageCount) pages")
                    pdfView.document = document
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Failed to load PDF from URL: \(url.absoluteString)")
                    self.showErrorDocument(in: containerView, message: "Failed to load PDF document")
                }
            }
        }
    }
    
    private func loadImageDocument(in containerView: UIView) {
        let scrollView = UIScrollView()
        let imageView = UIImageView()
        
        scrollView.backgroundColor = UIColor.systemBackground
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Set up scroll view delegate for zooming
        let scrollViewDelegate = ScrollViewDelegate()
        scrollViewDelegate.imageView = imageView
        scrollView.delegate = scrollViewDelegate
        
        // Load image asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    print("✅ Image loaded successfully: \(image.size)")
                    imageView.image = image
                    
                    // Set image view constraints after image is loaded
                    NSLayoutConstraint.activate([
                        imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                        imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: image.size.width),
                        imageView.heightAnchor.constraint(equalToConstant: image.size.height)
                    ])
                    
                    // Set content size for scroll view
                    scrollView.contentSize = image.size
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Failed to load image from URL: \(url.absoluteString)")
                    self.showErrorDocument(in: containerView, message: "Failed to load image document")
                }
            }
        }
    }
    
    private func showErrorDocument(in containerView: UIView, message: String) {
        // Remove any existing subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        let errorView = UIView()
        errorView.backgroundColor = UIColor.systemBackground
        errorView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: "doc.questionmark")
        iconImageView.tintColor = UIColor.systemRed
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Document Unavailable"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .center
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        let urlLabel = UILabel()
        urlLabel.text = url.absoluteString
        urlLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        urlLabel.textColor = UIColor.tertiaryLabel
        urlLabel.textAlignment = .center
        urlLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(urlLabel)
        
        errorView.addSubview(stackView)
        containerView.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            errorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            stackView.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -32)
        ])
    }
}

// MARK: - ScrollView Delegate for Image Zooming
class ScrollViewDelegate: NSObject, UIScrollViewDelegate {
    var imageView: UIImageView?
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: - Enhanced Main Admin View with Fixed Email Integration
struct AdminDoctorListView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var credentialsManager = CredentialsManager()
    @StateObject private var apiService = AdminAPIService()
    
    @State private var doctors: [AdminDoctor] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingCredentialsAlert = false
    @State private var currentCredentials: AdminAPIService.DoctorCredentials?
    @State private var showingCredentialsHistory = false
    @State private var showingLicenseViewer = false
    @State private var selectedDoctor: AdminDoctor?
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var showingLogoutAlert = false
    @State private var isRefreshing = false
    @State private var lastUpdated = Date()
    @State private var pulseAnimation = false
    @State private var processingDoctorId: Int? = nil
    
    // FIXED: Correct email status variables
    @State private var emailStatusMessage: String? = nil  // FIXED: Proper variable name
    @State private var showingEmailStatus = false        // FIXED: Proper variable name
    
    @Environment(\.openURL) private var openURL
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case rejected = "Rejected"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet.rectangle"
            case .pending: return "clock.badge.questionmark"
            case .approved: return "checkmark.circle"
            case .rejected: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .indigo
            case .pending: return .orange
            case .approved: return .green
            case .rejected: return .red
            }
        }
    }
    
    var filteredDoctors: [AdminDoctor] {
        let filtered = doctors.filter { doctor in
            if selectedFilter != .all {
                return doctor.status.rawValue == selectedFilter.rawValue.lowercased()
            }
            return true
        }
        
        if searchText.isEmpty {
            return filtered
        }
        
        return filtered.filter { doctor in
            doctor.name.localizedCaseInsensitiveContains(searchText) ||
            doctor.specialization.localizedCaseInsensitiveContains(searchText) ||
            doctor.clinic.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(UIColor.systemBackground),
                            Color(UIColor.systemGray6).opacity(0.3),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        headerView(availableWidth: geometry.size.width)
                            .padding(.top, 12)
                        
                        if isLoading && doctors.isEmpty {
                            loadingView
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    realTimeStatusView(availableWidth: geometry.size.width)
                                        .padding(.top, 20)
                                    
                                    searchAndFiltersView(availableWidth: geometry.size.width)
                                        .padding(.top, 24)
                                    
                                    statsView(availableWidth: geometry.size.width)
                                        .padding(.top, 32)
                                    
                                    doctorListView(availableWidth: geometry.size.width)
                                        .padding(.top, 32)
                                }
                            }
                            .refreshable {
                                await loadDoctors()
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Doctor Approved Successfully!", isPresented: $showingCredentialsAlert) {
                Button("Copy Credentials") {
                    copyCredentialsToClipboard()
                }
                Button("Done") { }
            } message: {
                if let credentials = currentCredentials {
                    Text("Login credentials generated!\n\nDoctor ID: \(credentials.id)\nPassword: \(credentials.password)\n\nCredentials have been copied to clipboard and emailed to the doctor.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    processingDoctorId = nil
                }
            } message: {
                Text(errorMessage ?? "An unexpected error occurred")
            }
            // FIXED: Correct alert for email status
            .alert("Email Notification Status", isPresented: $showingEmailStatus) {
                Button("OK") {
                    emailStatusMessage = nil
                }
            } message: {
                Text(emailStatusMessage ?? "")
            }
            .alert("Logout Confirmation", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("Are you sure you want to logout from the admin panel? Any unsaved changes will be lost.")
            }
            .fullScreenCover(isPresented: $showingLicenseViewer) {
                if let doctor = selectedDoctor {
                    EnhancedLicenseViewer(doctor: doctor)
                }
            }
            .sheet(isPresented: $showingCredentialsHistory) {
                CredentialsHistoryView(credentialsManager: credentialsManager)
            }
        }
        .task {
            await loadDoctors()
            startRealTimeUpdates()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading doctor applications...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Fixed API Integration Functions with Email Support
    
    @MainActor
    private func loadDoctors() async {
        if doctors.isEmpty {
            isLoading = true
        }
        
        do {
            print("🔄 Starting to load doctors...")
            let fetchedDoctors = try await apiService.getDoctorRegistrations()
            withAnimation(.easeInOut(duration: 0.3)) {
                doctors = fetchedDoctors
                lastUpdated = Date()
            }
            print("✅ Successfully loaded \(fetchedDoctors.count) doctors")
        } catch {
            print("❌ Failed to load doctors: \(error)")
            errorMessage = "Failed to load doctor applications: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Fixed Approval Function with Email
    @MainActor
    private func approveDoctor(_ doctor: AdminDoctor) {
        guard processingDoctorId == nil else {
            print("⚠️ Already processing another doctor")
            return
        }
        
        processingDoctorId = doctor.id
        print("🔄 Approve button tapped for doctor: \(doctor.name)")
        print("🔄 Starting approval process for doctor: \(doctor.name) (ID: \(doctor.id), Email: \(doctor.email))")
        
        Task {
            do {
                // FIXED: Pass both doctor ID and email
                let response = try await apiService.approveDoctor(doctorId: String(doctor.id), email: doctor.email)
                
                await MainActor.run {
                    if response.status == "success", let credentials = response.credentials {
                        print("✅ Doctor approved successfully: \(doctor.name)")
                        print("📧 Email will be sent to: \(doctor.email)")
                        
                        // Update local doctor status
                        if let index = doctors.firstIndex(where: { $0.id == doctor.id }) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                doctors[index].status = .approved
                                doctors[index].doctorID = credentials.id
                                doctors[index].generatedPassword = credentials.password
                                doctors[index].approvedDate = Date()
                                doctors[index].credentialsSent = true
                            }
                        }
                        
                        // Store credentials in manager
                        credentialsManager.storeCredentials(credentials, for: doctor)
                        currentCredentials = credentials
                        
                        // FIXED: Handle email status correctly
                        if let emailStatus = response.email_status {
                            emailStatusMessage = "✅ Approval email sent successfully to \(doctor.email): \(emailStatus.message)"
                            showingEmailStatus = true
                            print("📧 Email status: \(emailStatus.status) - \(emailStatus.message)")
                        } else {
                            // Fallback message if no email_status in response
                            emailStatusMessage = "✅ Doctor approved! Login credentials will be sent to \(doctor.email)"
                            showingEmailStatus = true
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        
                        // Reset processing state first
                        processingDoctorId = nil
                        
                        // Show success alert after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingCredentialsAlert = true
                        }
                    } else {
                        print("⚠️ Approval failed with response: \(response.status) - \(response.message)")
                        errorMessage = "Approval failed: \(response.message)\n\nPlease check the doctor's email address: \(doctor.email)"
                        showingError = true
                        processingDoctorId = nil
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Approval error: \(error)")
                    errorMessage = "Failed to approve doctor: \(error.localizedDescription)\n\nDoctor Email: \(doctor.email)"
                    showingError = true
                    processingDoctorId = nil
                }
            }
        }
    }
    
    // MARK: - Fixed Rejection Function with Email
    @MainActor
    private func rejectDoctor(_ doctor: AdminDoctor) {
        guard processingDoctorId == nil else {
            print("⚠️ Already processing another doctor")
            return
        }
        
        processingDoctorId = doctor.id
        print("🔄 Reject button tapped for doctor: \(doctor.name)")
        print("🔄 Starting rejection process for doctor: \(doctor.name) (ID: \(doctor.id), Email: \(doctor.email))")
        
        Task {
            do {
                // FIXED: Pass both doctor ID and email
                let response = try await apiService.rejectDoctor(doctorId: String(doctor.id), email: doctor.email, rejectionReason: "Application does not meet current requirements")
                
                await MainActor.run {
                    if response.status == "success" {
                        print("✅ Doctor rejected successfully: \(doctor.name)")
                        print("📧 Rejection email will be sent to: \(doctor.email)")
                        
                        // Update local doctor status
                        if let index = doctors.firstIndex(where: { $0.id == doctor.id }) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                doctors[index].status = .rejected
                            }
                        }
                        
                        // FIXED: Handle email status correctly
                        if let emailStatus = response.email_status {
                            emailStatusMessage = "❌ Rejection email sent to \(doctor.email): \(emailStatus.message)"
                            showingEmailStatus = true
                            print("📧 Email status: \(emailStatus.status) - \(emailStatus.message)")
                        } else {
                            // Fallback message if no email_status in response
                            emailStatusMessage = "❌ Doctor rejected. Notification sent to \(doctor.email)"
                            showingEmailStatus = true
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Reset processing state
                        processingDoctorId = nil
                    } else {
                        print("⚠️ Rejection failed with response: \(response.status) - \(response.message)")
                        errorMessage = "Rejection failed: \(response.message)\n\nPlease check the doctor's email address: \(doctor.email)"
                        showingError = true
                        processingDoctorId = nil
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Rejection error: \(error)")
                    errorMessage = "Failed to reject doctor: \(error.localizedDescription)\n\nDoctor Email: \(doctor.email)"
                    showingError = true
                    processingDoctorId = nil
                }
            }
        }
    }
    
    private func copyCredentialsToClipboard() {
        guard let credentials = currentCredentials else { return }
        
        let credentialsText = """
        🏥 RecovFit Doctor Credentials
        
        👨‍⚕️ Doctor: \(doctors.first { $0.doctorID == credentials.id }?.name ?? "Unknown")
        🆔 Doctor ID: \(credentials.id)
        🔑 Password: \(credentials.password)
        📧 Email: \(credentials.email)
        📅 Approved: \(formatDate(Date()))
        
        ⚠️ Please keep these credentials secure and change password upon first login.
        🔔 Login credentials have been sent via email to the doctor.
        """
        
        UIPasteboard.general.string = credentialsText
        
        // Show confirmation
        emailStatusMessage = "📋 Credentials copied to clipboard!"
        showingEmailStatus = true
    }
    
    // MARK: - Real-Time Status View
    private func realTimeStatusView(availableWidth: CGFloat) -> some View {
        let horizontalPadding = pageHorizontalPadding(for: availableWidth)
        
        return HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Text("Live")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Text("Updated \(timeAgo(from: lastUpdated))")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Enhanced Header
    private func headerView(availableWidth: CGFloat) -> some View {
        let horizontalPadding = pageHorizontalPadding(for: availableWidth)
        let isCompact = availableWidth < 390
        let avatarSize: CGFloat = isCompact ? 44 : 50
        
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerTitleContent(isCompact: isCompact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                adminProfileBlock(avatarSize: avatarSize, isCompact: isCompact)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                headerTitleContent(isCompact: isCompact)
                adminProfileBlock(avatarSize: avatarSize, isCompact: isCompact)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    private func headerTitleContent(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(isCompact ? .title3 : .title2)
                    .foregroundStyle(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("RecovFit")
                    .font(isCompact ? .title3 : .title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text("Admin Dashboard")
                .font(.system(size: isCompact ? 28 : 32, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.primary, .secondary], startPoint: .leading, endPoint: .trailing))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Manage doctor applications and approvals with email notifications")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func adminProfileBlock(avatarSize: CGFloat, isCompact: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: avatarSize, height: avatarSize)
                
                Text("AD")
                    .font(isCompact ? .subheadline : .headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
            .scaleEffect(pulseAnimation ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Administrator")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(session.currentUserId ?? "admin123")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Button(action: { showingLogoutAlert = true }) {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Enhanced Search and Filters
    private func searchAndFiltersView(availableWidth: CGFloat) -> some View {
        let horizontalPadding = pageHorizontalPadding(for: availableWidth)
        
        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField("Search by name, specialization, or clinic...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, horizontalPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: availableWidth < 390 ? 8 : 12) {
                    ForEach(FilterOption.allCases, id: \.self) { filter in
                        EnhancedFilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
    
    // MARK: - Enhanced Stats View
    private func statsView(availableWidth: CGFloat) -> some View {
        let horizontalPadding = pageHorizontalPadding(for: availableWidth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: availableWidth < 360 ? 1 : 2)
        
        return VStack(spacing: 20) {
            HStack {
                Text("Real-Time Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await loadDoctors()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .disabled(isRefreshing || processingDoctorId != nil)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(.linear(duration: 1.0).repeatCount(isRefreshing ? 10 : 0, autoreverses: false), value: isRefreshing)
            }
            .padding(.horizontal, horizontalPadding)
            
            LazyVGrid(columns: columns, spacing: 16) {
                EnhancedStatCard(icon: "person.3.fill", title: "Total Applications", value: "\(doctors.count)", subtitle: "All time", color: .indigo, trend: .neutral, isAnimated: true)
                
                EnhancedStatCard(icon: "clock.badge.questionmark.fill", title: "Pending Review", value: "\(pendingCount)", subtitle: "Awaiting action", color: .orange, trend: pendingCount > 0 ? .up : .neutral, isAnimated: true)
                
                EnhancedStatCard(icon: "checkmark.seal.fill", title: "Approved", value: "\(approvedCount)", subtitle: "Ready to practice", color: .green, trend: .up, isAnimated: true)
                
                EnhancedStatCard(icon: "xmark.octagon.fill", title: "Rejected", value: "\(rejectedCount)", subtitle: "Declined applications", color: .red, trend: .neutral, isAnimated: true)
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    // MARK: - Enhanced Doctor List
    private func doctorListView(availableWidth: CGFloat) -> some View {
        let horizontalPadding = pageHorizontalPadding(for: availableWidth)
        
        return VStack(spacing: 20) {
            HStack {
                Text("Doctor Applications")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredDoctors.count) results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, horizontalPadding)
            
            LazyVStack(spacing: 20) {
                ForEach(filteredDoctors) { doctor in
                    EnhancedDoctorCards(
                        doctor: doctor,
                        isProcessing: processingDoctorId == doctor.id,
                        onApprove: { approveDoctor(doctor) },
                        onReject: { rejectDoctor(doctor) },
                        onViewLicense: { viewLicense(doctor) }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
                
                if filteredDoctors.isEmpty {
                    EnhancedEmptyStateView(searchText: searchText, selectedFilter: selectedFilter)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Helper Properties
    private var pendingCount: Int {
        doctors.filter { $0.status == .pending }.count
    }
    
    private var approvedCount: Int {
        doctors.filter { $0.status == .approved }.count
    }
    
    private var rejectedCount: Int {
        doctors.filter { $0.status == .rejected }.count
    }
    
    // MARK: - Enhanced Helper Functions
    private func pageHorizontalPadding(for width: CGFloat) -> CGFloat {
        width < 390 ? 16 : 24
    }
    
    private func countForFilter(_ filter: FilterOption) -> Int {
        switch filter {
        case .all: return doctors.count
        case .pending: return pendingCount
        case .approved: return approvedCount
        case .rejected: return rejectedCount
        }
    }
    
    private func viewLicense(_ doctor: AdminDoctor) {
        selectedDoctor = doctor
        showingLicenseViewer = true
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func performLogout() {
        withAnimation(.easeInOut(duration: 0.5)) {
            session.logout()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func startRealTimeUpdates() {
        pulseAnimation = true
        
        // Refresh every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await loadDoctors()
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

// MARK: - Credentials History View
struct CredentialsHistoryView: View {
    @ObservedObject var credentialsManager: CredentialsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(credentialsManager.getAllCredentials(), id: \.doctorID) { credentials in
                    CredentialRowView(credentials: credentials)
                        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Doctor Credentials")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Individual Credential Row
struct CredentialRowView: View {
    let credentials: CredentialsManager.DoctorCredentials
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(credentials.doctorName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("ID: " + credentials.doctorID)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Approved")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    
                    Text(formatApprovalDate(credentials.approvalDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if showingDetails {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    CredentialDetailRow(title: "Email", value: credentials.email, isSecure: false)
                    CredentialDetailRow(title: "Password", value: credentials.password, isSecure: true)
                }
                .padding(.top, 8)
            }
            
            HStack {
                Button(action: { copyCredentials() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                
                Spacer()
                
                Button(showingDetails ? "Hide" : "Show") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingDetails.toggle()
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func copyCredentials() {
        let credentialsText = """
        Doctor: \(credentials.doctorName)
        ID: \(credentials.doctorID)
        Password: \(credentials.password)
        Email: \(credentials.email)
        """
        UIPasteboard.general.string = credentialsText
    }
    
    private func formatApprovalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Credential Detail Row
struct CredentialDetailRow: View {
    let title: String
    let value: String
    let isSecure: Bool
    @State private var isRevealed = false
    
    var body: some View {
        HStack {
            Text(title + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            if isSecure && !isRevealed {
                Text(String(repeating: "•", count: 8))
                    .font(.body)
                    
            } else {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
            
            Spacer()
            
            if isSecure {
                Button(action: { isRevealed.toggle() }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { UIPasteboard.general.string = value }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Filter Chip
struct EnhancedFilterChip: View {
    let filter: AdminDoctorListView.FilterOption
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(filter.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : filter.color.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AnyShapeStyle(filter.color.gradient) : AnyShapeStyle(Color(UIColor.systemBackground)))
                    .shadow(
                        color: isSelected ? filter.color.opacity(0.3) : .black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .foregroundColor(isSelected ? .white : filter.color)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

// MARK: - Enhanced Stat Card
struct EnhancedStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let trend: TrendDirection
    let isAnimated: Bool
    
    @State private var animateValue = false
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .secondary
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(trend.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(animateValue ? 1.1 : 1.0)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            if isAnimated {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animateValue = true
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateValue)
    }
}

// MARK: - Enhanced Doctor Card with Fixed Processing State
struct EnhancedDoctorCards: View {
    let doctor: AdminDoctor
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onViewLicense: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            if isExpanded {
                contactSection
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            actionSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [statusColor.opacity(0.3), statusColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .opacity(isProcessing ? 0.7 : 1.0)
        .onTapGesture {
            if !isProcessing {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                
                Text(doctorInitials)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(doctor.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    EnhancedStatusBadge(status: doctor.status)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "stethoscope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(doctor.specialization)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(doctor.clinic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Button(action: {
                if !isProcessing {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
    }
    
    private var contactSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            VStack(spacing: 12) {
                EnhancedInfoRow(icon: "envelope.fill", title: "Email Address", value: doctor.email, color: .blue)
                EnhancedInfoRow(icon: "phone.fill", title: "Phone Number", value: doctor.phone, color: .green)
                EnhancedInfoRow(icon: "doc.text.fill", title: "License Number", value: doctor.license, color: .orange)
                
                // Show credentials if approved
                if doctor.status == .approved {
                    if let doctorID = doctor.doctorID {
                        EnhancedInfoRow(icon: "person.text.rectangle.fill", title: "Doctor ID", value: doctorID, color: .indigo)
                    }
                    if let password = doctor.generatedPassword {
                        EnhancedInfoRow(icon: "key.fill", title: "Password", value: password, color: .purple)
                    }
                }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: onViewLicense) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("View Medical License")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
            
            statusActionView
        }
    }
    
    @ViewBuilder
    private var statusActionView: some View {
        switch doctor.status {
        case .pending:
            HStack(spacing: 12) {
                Button("Decline") {
                    print("🔄 Decline button tapped for doctor: \(doctor.name)")
                    onReject()
                }
                .disabled(isProcessing)
                .buttonStyle(EnhancedDeclineButtonStyle())
                
                Button("Approve") {
                    print("🔄 Approve button tapped for doctor: \(doctor.name)")
                    onApprove()
                }
                .disabled(isProcessing)
                .buttonStyle(EnhancedApproveButtonStyle())
            }
            .overlay(
                Group {
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(12)
                    }
                }
            )
            
        case .approved:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    
                    Text("Application Approved")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("Credentials sent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                
                if let doctorID = doctor.doctorID {
                    HStack {
                        Text("Doctor ID: \(doctorID)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Copy ID") {
                            UIPasteboard.general.string = doctorID
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
        case .rejected:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                
                Text("Application Declined")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // Helper properties
    private var doctorInitials: String {
        let components = doctor.name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials)
    }
    
    private var statusColor: Color {
        switch doctor.status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    private var gradientColors: [Color] {
        switch doctor.status {
        case .pending: return [.orange, .yellow]
        case .approved: return [.green, .mint]
        case .rejected: return [.red, .pink]
        }
    }
}

// MARK: - Enhanced Info Row
struct EnhancedInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                UIPasteboard.general.string = value
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Enhanced Status Badge
struct EnhancedStatusBadge: View {
    let status: AdminDoctorStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .fontWeight(.bold)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(textColor.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private var statusIcon: String {
        switch status {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending: return .orange.opacity(0.15)
        case .approved: return .green.opacity(0.15)
        case .rejected: return .red.opacity(0.15)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Enhanced Empty State
struct EnhancedEmptyStateView: View {
    let searchText: String
    let selectedFilter: AdminDoctorListView.FilterOption
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.1), .indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 40))
                    .fontWeight(.light)
                    .foregroundStyle(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(spacing: 12) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if !searchText.isEmpty || selectedFilter != .all {
                Button("Clear Filters") {
                    // Implement clear filters
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 40)
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else if selectedFilter != .all {
            return selectedFilter.icon
        } else {
            return "stethoscope"
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No matching doctors found"
        } else if selectedFilter != .all {
            return "No \(selectedFilter.rawValue.lowercased()) applications"
        } else {
            return "No applications yet"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or check the spelling."
        } else if selectedFilter != .all {
            return "There are no doctors with \(selectedFilter.rawValue.lowercased()) status at the moment."
        } else {
            return "New doctor applications will appear here for your review and approval."
        }
    }
}

// MARK: - Enhanced License Viewer with Document Support
// MARK: - Enhanced License Viewer with Document Support
struct EnhancedLicenseViewer: View {
    let doctor: AdminDoctor
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var showingShareSheet = false
    @State private var documentLoadError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    // FIXED: Use DocumentViewContainer instead of PDFViewContainer
                    if isValidURL(doctor.licenseURL) {
                        if let url = URL(string: doctor.licenseURL) {
                            DocumentViewContainer(url: url)
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                                .onAppear {
                                    // Add delay to show loading state
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            isLoading = false
                                        }
                                    }
                                }
                        } else {
                            contentUnavailableView
                        }
                    } else {
                        contentUnavailableView
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                Group {
                    if isLoading {
                        loadingOverlay
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = URL(string: doctor.licenseURL) {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              url.scheme != nil else {
            print("❌ Invalid URL: \(urlString)")
            return false
        }
        
        // Check if URL has proper file extension
        let pathExtension = url.pathExtension.lowercased()
        let validExtensions = ["pdf", "jpeg", "jpg", "png", "gif", "bmp"]
        
        if !validExtensions.contains(pathExtension) {
            print("⚠️ Warning: Unexpected file extension: \(pathExtension)")
        } else {
            print("✅ Valid document type: .\(pathExtension)")
        }
        
        print("✅ Valid URL: \(urlString)")
        return true
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") {
                    dismiss()
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(documentTypeTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(doctor.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share Document", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: openInSafari) {
                        Label("Open in Safari", systemImage: "safari")
                    }
                    
                    Button(action: copyLink) {
                        Label("Copy Link", systemImage: "link")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // FIXED: Renamed from documentTypeTitle to avoid conflicts
    private var documentTypeTitle: String {
        if let url = URL(string: doctor.licenseURL) {
            let fileExtension = url.pathExtension.lowercased() // FIXED: Changed from 'extension' to 'fileExtension'
            if fileExtension == "pdf" {
                return "Medical License (PDF)"
            } else if ["jpg", "jpeg", "png", "gif", "bmp"].contains(fileExtension) {
                return "Medical License (Image)"
            }
        }
        return "Medical License"
    }
    
    private var contentUnavailableView: some View {
        ContentUnavailableView {
            Label("License Unavailable", systemImage: "doc.questionmark")
        } description: {
            Text("The medical license document could not be loaded. Please check the URL: \(doctor.licenseURL)")
        } actions: {
            Button("Retry") {
                // Retry logic - reload the view
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading document...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
        }
    }
    
    private func openInSafari() {
        if let url = URL(string: doctor.licenseURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyLink() {
        UIPasteboard.general.string = doctor.licenseURL
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Enhanced Button Styles
struct EnhancedApproveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
            )
            .cornerRadius(12)
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct EnhancedDeclineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(colors: [.red, .red.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - ShareSheet for sharing documents
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityViewController
    }
    
    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {
        // Update if needed
    }
}
