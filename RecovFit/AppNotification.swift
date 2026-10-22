import SwiftUI

// ─────────────────────────────────────────────
// MARK: Notification Model
// ─────────────────────────────────────────────
struct AppNotification: Identifiable, Hashable, Decodable {
    let id: Int
    let user_id: String
    let user_type: String
    let type: String
    let message: String
    let date: String
    var is_read: Int
    
    var formattedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = formatter.date(from: date) {
            return d
        }
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: date) {
            return d
        }
        return Date()
    }
}

struct NotificationResponse: Decodable {
    let status: String
    let user_type: String
    let notifications: [AppNotification]
    let message: String?
}

// Model for decoding appointment requests for notifications
private struct DoctorAppointmentItem: Decodable {
    let appointment_date: String?
    let appointment_time: String?
    let reason_for_visit: String?
    let status: String?
    let patient_id: String?
    let full_name: String?
}

private struct DoctorAppointmentResponse: Decodable {
    let status: String
    let message: String?
    let data: [DoctorAppointmentItem]?
}

// ─────────────────────────────────────────────
// MARK: Notification Store
// ─────────────────────────────────────────────
@MainActor
final class NotificationStore: ObservableObject {
    @Published var notifications: [AppNotification] = []
    private let readLocalKey = "read_local_notifications"

    private var localReadIds: Set<Int> {
        get {
            let list = UserDefaults.standard.array(forKey: readLocalKey) as? [Int] ?? []
            return Set(list)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: readLocalKey)
        }
    }

    // Fetch notifications from both backend and pending appointment requests
    func fetchFromBackend(session: SessionManager) async {
        let userID: String
        let isDoctor: Bool
        switch session.role {
        case .doctor:
            guard let doctorId = session.doctorId else { return }
            userID = doctorId
            isDoctor = true
        case .patient:
            guard let patientId = session.patientId else { return }
            userID = patientId
            isDoctor = false
        default:
            return
        }

        var loadedNotifications: [AppNotification] = []

        // 1. Fetch from standard notification endpoint
        if let url = URL(string: ServiceApi.Notification) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "user_id=\(userID)".data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoded = try JSONDecoder().decode(NotificationResponse.self, from: data)
                if decoded.status == "success" {
                    loadedNotifications.append(contentsOf: decoded.notifications)
                }
            } catch {
                print("Notification API fetch error: \(error.localizedDescription)")
            }
        }

        // 2. For Doctors: Also check pending appointment requests and generate notifications
        if isDoctor {
            if let statusUrl = URL(string: "\(ServiceApi.Status)?doctor_id=\(userID)") {
                do {
                    let (data, _) = try await URLSession.shared.data(from: statusUrl)
                    let decoded = try JSONDecoder().decode(DoctorAppointmentResponse.self, from: data)
                    if decoded.status == "success", let appointments = decoded.data {
                        let readSet = self.localReadIds
                        
                        for apt in appointments {
                            // Any appointment in 'pending' status requires doctor review
                            if (apt.status?.lowercased() == "pending") {
                                let patientName = apt.full_name ?? "A patient"
                                let aptDate = apt.appointment_date ?? "Today"
                                let aptTime = apt.appointment_time ?? ""
                                let reason = apt.reason_for_visit ?? "Consultation"
                                
                                // Unique positive ID based on appointment details
                                let hashInput = "pending_\(apt.patient_id ?? "")_\(aptDate)_\(aptTime)"
                                let uniqueId = abs(hashInput.hashValue % 10000000) + 500000
                                
                                let isRead = readSet.contains(uniqueId) ? 1 : 0
                                
                                let appNotif = AppNotification(
                                    id: uniqueId,
                                    user_id: userID,
                                    user_type: "doctor",
                                    type: "appointment",
                                    message: "New appointment request from \(patientName) for \(aptDate) (\(aptTime)): \(reason)",
                                    date: aptDate,
                                    is_read: isRead
                                )
                                loadedNotifications.append(appNotif)
                            }
                        }
                    }
                } catch {
                    print("Doctor appointments status fetch error: \(error.localizedDescription)")
                }
            }
        }

        // Remove duplicates if any and update store
        var seenIds = Set<Int>()
        var uniqueNotifs: [AppNotification] = []
        for notif in loadedNotifications {
            if !seenIds.contains(notif.id) {
                seenIds.insert(notif.id)
                uniqueNotifs.append(notif)
            }
        }

        self.notifications = uniqueNotifs
    }
    
    // Mark a notification as read
    func markAsRead(notification: AppNotification, session: SessionManager) async {
        // If it's a locally generated pending request notification
        if notification.id >= 500000 {
            var readSet = self.localReadIds
            readSet.insert(notification.id)
            self.localReadIds = readSet
            
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[idx].is_read = 1
            }
            return
        }

        // Backend notification
        let userID: String
        switch session.role {
        case .doctor:
            guard let doctorId = session.doctorId else { return }
            userID = doctorId
        case .patient:
            guard let patientId = session.patientId else { return }
            userID = patientId
        default:
            return
        }

        guard let url = URL(string: ServiceApi.Notification) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "user_id=\(userID)&mark_read_id=\(notification.id)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            _ = try await URLSession.shared.data(for: request)
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[idx].is_read = 1
            }
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }
    
    // Mark all notifications as read
    func markAllRead(session: SessionManager) async {
        for notif in notifications {
            await markAsRead(notification: notif, session: session)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: Notification View
// ─────────────────────────────────────────────
struct NotificationView: View {
    @ObservedObject var store: NotificationStore
    @EnvironmentObject var session: SessionManager
    
    init(store: NotificationStore? = nil) {
        if let store = store {
            self._store = ObservedObject(wrappedValue: store)
        } else {
            self._store = ObservedObject(wrappedValue: NotificationStore())
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.15), .blue.opacity(0.08)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            if store.notifications.isEmpty {
                EmptyStatesView()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(store.notifications) { notif in
                            NotificationCard(notification: notif) {
                                Task {
                                    await store.markAsRead(notification: notif, session: session)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await store.markAsRead(notification: notif, session: session)
                                    }
                                } label: {
                                    Label("Mark Read", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await store.fetchFromBackend(session: session)
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            if !store.notifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark All Read") {
                        Task {
                            await store.markAllRead(session: session)
                        }
                    }
                    .font(.subheadline.bold())
                }
            }
        }
        .task {
            await store.fetchFromBackend(session: session)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: Notification Card (Type-based Icon & Color)
// ─────────────────────────────────────────────
private struct NotificationCard: View {
    let notification: AppNotification
    let onRead: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconForType(notification.type))
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(notification.is_read == 0 ? colorForType(notification.type) : .gray)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.type.capitalized)
                        .font(.headline)
                    
                    if notification.is_read == 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                }
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(notification.date)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if notification.is_read == 0 {
                Button {
                    onRead()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue.opacity(0.8))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(notification.is_read == 0 ? Color.blue.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
    
    // MARK: Icon Mapping
    func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "appointment": return "calendar.circle.fill"
        case "exercise": return "figure.walk.circle.fill"
        case "message": return "envelope.circle.fill"
        case "alert": return "exclamationmark.triangle.fill"
        case "file": return "doc.circle.fill"
        default: return "bell.fill"
        }
    }
    
    // MARK: Color Mapping
    func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "appointment": return .blue
        case "exercise": return .green
        case "message": return .purple
        case "alert": return .orange
        case "file": return .teal
        default: return .teal
        }
    }
}

// ─────────────────────────────────────────────
// MARK: Empty State
// ─────────────────────────────────────────────
private struct EmptyStatesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("No Notifications")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("You will see upcoming appointments and updates here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
