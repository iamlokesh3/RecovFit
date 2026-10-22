import SwiftUI

struct LoginHomeView: View {
    @State private var path = NavigationPath()
    @State private var isAnimating = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                backgroundGradient
                VStack(spacing: 0) {
                    Spacer()
                    appBrandingSection
                    Spacer()
                    loginOptionsSection
                    Spacer()
                    footerSection
                }
                .padding(.horizontal, 24)
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    isAnimating = true
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .patient:
                    PatientLoginView(path: $path)
                case .doctor:
                    DoctorLoginView(path: $path)
                }
            }
        }
    }

    enum Destination: Hashable {
        case patient
        case doctor
    }

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemTeal).opacity(0.05),
                    Color(.systemBlue).opacity(0.15),
                    Color(.systemIndigo).opacity(0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -200)
                .blur(radius: 30)
            Circle()
                .fill(Color.teal.opacity(0.1))
                .frame(width: 150, height: 150)
                .offset(x: 120, y: 180)
                .blur(radius: 25)
        }
        .ignoresSafeArea()
    }

    private var appBrandingSection: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
                Text("RecovFit")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: isAnimating)
                Text("Your Health, Our Priority")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(0.7), value: isAnimating)
            }
        }
    }

    private var loginOptionsSection: some View {
        VStack(spacing: 24) {
            Text("Choose your login type")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.9), value: isAnimating)
            VStack(spacing: 16) {
                Button {
                    path.append(Destination.patient)
                } label: {
                    EnhancedLoginCard(
                        icon: "heart.circle.fill",
                        title: "Patient Portal",
                        subtitle: "Access your health records",
                        color: .blue,
                        gradientColors: [.blue.opacity(0.8), .teal.opacity(0.6)]
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(x: isAnimating ? 0 : -50)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.1), value: isAnimating)

                Button {
                    path.append(Destination.doctor)
                } label: {
                    EnhancedLoginCard(
                        icon: "stethoscope.circle.fill",
                        title: "Doctor Portal",
                        subtitle: "Manage patient care",
                        color: .purple,
                        gradientColors: [.purple.opacity(0.8), .indigo.opacity(0.6)]
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(x: isAnimating ? 0 : 50)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.3), value: isAnimating)
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Secure • Private • Professional")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(1.5), value: isAnimating)
            HStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.blue)
                Image(systemName: "cross.case.fill")
                    .foregroundColor(.red)
            }
            .font(.caption)
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.8).delay(1.7), value: isAnimating)
        }
        .padding(.bottom, 20)
    }
}

struct EnhancedLoginCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var color: Color
    var gradientColors: [Color]
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(color)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(
            color: color.opacity(0.2),
            radius: isPressed ? 5 : 15,
            x: 0,
            y: isPressed ? 2 : 8
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        // No gesture (Button controls tap)
    }
}
// For preview in Xcode
struct LoginHomeView_Previews: PreviewProvider {
    static var previews: some View {
        LoginHomeView()
    }
}
