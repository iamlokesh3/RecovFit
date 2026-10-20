import SwiftUI

struct DoctorTabBar: View {
    @Binding var selectedTab: DoctorTabBar.Tab
    @Binding var path: NavigationPath
    var unreadNotificationCount: Int = 0 // Pass this from NotificationStore

    enum Tab: String, CaseIterable {
        case home, schedule, patient, notification
    }
    
    var body: some View {
        HStack {
            tabButton(icon: "house.fill", tab: .home)
            tabButton(icon: "calendar", tab: .schedule)
            tabButton(icon: "person.fill", tab: .patient)
            tabButton(icon: "bell.fill", tab: .notification, badgeCount: unreadNotificationCount)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 30)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
        )
        .padding(.bottom, -18)
    }
    
    private func tabButton(icon: String, tab: Tab, badgeCount: Int = 0) -> some View {
        Button {
            selectedTab = tab
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                    Text(tab.rawValue.capitalized)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                .background(
                    Circle()
                        .fill(selectedTab == tab ? Color.blue.opacity(0.12) : Color.clear)
                )
                .animation(.easeInOut(duration: 0.15), value: selectedTab)
                
                // Badge
                if badgeCount > 0 {
                    Text(badgeCount > 3 ? "+3" : "\(badgeCount)")
                        .font(.caption2).bold()
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.red))
                        .offset(x: 12, y: -10)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut, value: badgeCount)
                }
            }
        }
    }
}
