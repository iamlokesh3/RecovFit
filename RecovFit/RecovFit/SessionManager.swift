import SwiftUI

final class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var role: UserRole?
    @Published var patientId: String?
    @Published var doctorId: String?
    @Published var adminId: String?
    @Published var navigationPath = NavigationPath()
    @Published var isFirstTime: Bool = false   // ✅ Added for first-time login tracking
    
    enum UserRole: String, CaseIterable {
        case patient
        case doctor
        case admin
        
        var displayName: String {
            switch self {
            case .patient: return "Patient"
            case .doctor: return "Doctor"
            case .admin: return "Admin"
            }
        }
    }
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        switch role {
        case .patient: return patientId
        case .doctor: return doctorId
        case .admin: return adminId
        case .none: return nil
        }
    }
    
    // MARK: - Initialization
    init() {
        // Load from UserDefaults on app launch
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        if let roleString = UserDefaults.standard.string(forKey: "role"),
           let savedRole = UserRole(rawValue: roleString) {
            self.role = savedRole
        }
        
        self.patientId = UserDefaults.standard.string(forKey: "patientId")
        self.doctorId = UserDefaults.standard.string(forKey: "doctorId")
        self.adminId = UserDefaults.standard.string(forKey: "adminId")
        self.isFirstTime = UserDefaults.standard.bool(forKey: "isFirstTime") // ✅ Load first-time flag
    }
    
    // MARK: - Login Methods
    func loginPatient(patientId: String, isFirstTime: Bool) {
        DispatchQueue.main.async {
            self.role = .patient
            self.isLoggedIn = true
            self.patientId = patientId
            self.doctorId = nil
            self.adminId = nil
            self.isFirstTime = isFirstTime   // ✅ Set from backend response
            self.saveSession(role: .patient, userId: patientId)
            UserDefaults.standard.set(isFirstTime, forKey: "isFirstTime")
            print("✅ Patient logged in with ID: \(patientId), First Time: \(isFirstTime)")
        }
    }
    
    func loginDoctor(doctorId: String, isFirstTime: Bool) {
        DispatchQueue.main.async {
            self.role = .doctor
            self.isLoggedIn = true
            self.doctorId = doctorId
            self.patientId = nil
            self.adminId = nil
            self.isFirstTime = isFirstTime   // ✅ Set from backend response
            self.saveSession(role: .doctor, userId: doctorId)
            UserDefaults.standard.set(isFirstTime, forKey: "isFirstTime")
            print("✅ Doctor logged in with ID: \(doctorId), First Time: \(isFirstTime)")
        }
    }
    
    func loginAdmin(adminId: String) {
        DispatchQueue.main.async {
            self.role = .admin
            self.isLoggedIn = true
            self.adminId = adminId
            self.patientId = nil
            self.doctorId = nil
            self.isFirstTime = false   // ✅ Admin doesn’t use first-time flag
            self.saveSession(role: .admin, userId: adminId)
            print("✅ Admin logged in with ID: \(adminId)")
        }
    }
    
    // MARK: - Logout
    func logout() {
        DispatchQueue.main.async {
            self.role = nil
            self.isLoggedIn = false
            self.patientId = nil
            self.doctorId = nil
            self.adminId = nil
            self.navigationPath = NavigationPath()
            self.isFirstTime = false
            
            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: "isLoggedIn")
            UserDefaults.standard.removeObject(forKey: "role")
            UserDefaults.standard.removeObject(forKey: "patientId")
            UserDefaults.standard.removeObject(forKey: "doctorId")
            UserDefaults.standard.removeObject(forKey: "adminId")
            UserDefaults.standard.removeObject(forKey: "isFirstTime")
            
            print("✅ Session cleared - User logged out")
        }
    }
    
    // MARK: - Session Management
    private func saveSession(role: UserRole, userId: String) {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(role.rawValue, forKey: "role")
        
        switch role {
        case .patient:
            UserDefaults.standard.set(userId, forKey: "patientId")
        case .doctor:
            UserDefaults.standard.set(userId, forKey: "doctorId")
        case .admin:
            UserDefaults.standard.set(userId, forKey: "adminId")
        }
    }
}
