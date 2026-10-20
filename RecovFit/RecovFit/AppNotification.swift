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
    let is_read: Int
    
    var formattedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: date) ?? Date()
    }
}

struct NotificationResponse: Decodable {
    let status: String
    let user_type: String
    let notifications: [AppNotification]
    let message: String?
}

// ─────────────────────────────────────────────
// MARK: Notification Store
// ─────────────────────────────────────────────
@MainActor
final class NotificationStore: ObservableObject {
    @Published var notifications: [AppNotification] = []

    // Fetch notifications
    func fetchFromBackend(session: SessionManager) async {
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
        request.httpBody = "user_id=\(userID)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(NotificationResponse.self, from: data)
            if decoded.status == "success" {
                self.notifications = decoded.notifications
            } else {
                self.notifications = []
                print("No notifications: \(decoded.message ?? "")")
            }
        } catch {
            print("Failed to fetch notifications: \(error)")
        }
    }
    
    // Mark a notification as read
    func markAsRead(notification: AppNotification, session: SessionManager) async {
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
            notifications.removeAll { $0.id == notification.id }
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
    @StateObject private var store = NotificationStore()
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.25), .blue.opacity(0.15)],
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
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.type.capitalized)
                    .font(.headline)
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(notification.formattedDate, style: .relative)
                    Text("•")
                    Text(notification.formattedDate, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button {
                onRead()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08))
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
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
