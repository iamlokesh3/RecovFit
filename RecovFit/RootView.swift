import SwiftUI

struct RootView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var session: SessionManager

    var body: some View {
        if session.isLoggedIn {
            NavigationStack(path: $path) {
                switch session.role {
                case .patient:
                    if let patientId = session.patientId {
                        if session.isFirstTime {
                            // ✅ Show details only once
                            PatientDetailView(patientId: patientId, path: $path)
                                .onDisappear {
                                    // After completing details, mark as not first time
                                    session.isFirstTime = false
                                    UserDefaults.standard.set(false, forKey: "isFirstTime")
                                }
                        } else {
                            PatientHomeView(patientId: patientId, path: $path)
                        }
                    } else {
                        LoginHomeView()
                    }

                case .doctor:
                    if let doctorId = session.doctorId {
                        if session.isFirstTime {
                            DoctorDetailsView(doctorId: doctorId, path: $path)
                                .onDisappear {
                                    session.isFirstTime = false
                                    UserDefaults.standard.set(false, forKey: "isFirstTime")
                                }
                        } else {
                            DoctorHomeView(doctorId: doctorId, path: $path)
                        }
                    } else {
                        LoginHomeView()
                    }

                case .admin:
                    if let _ = session.adminId {
                        AdminDoctorListView()
                    } else {
                        LoginHomeView()
                    }

                case .none:
                    LoginHomeView()
                }
            }
        } else {
            NavigationStack {
                LoginHomeView()
            }
        }
    }
}
