import SwiftUI
import PhotosUI

struct PatientDetailView: View {
    
    let patientId: String
  
    @State private var profileItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
  
    @State private var fullName = ""
    @State private var age = ""
    @State private var gender = ""
    @State private var bloodGroup = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var emergencyContact = ""
    @State private var address = ""
    @State private var chronicConditions = ""
    @State private var medications = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToHome = false // <-- navigation trigger
    @Binding var path: NavigationPath
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .teal.opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // Hidden NavigationLink for automatic navigation
                    NavigationLink(
                        destination: PatientHomeView(patientId: patientId, path: $path),
                        isActive: $navigateToHome,
                        label: { EmptyView() }
                    )
                    
                    // MARK: - Profile Header
                    VStack(spacing: 12) {
                        PhotosPicker(
                            selection: $profileItem,
                            matching: .images,
                            photoLibrary: .shared()) {
                                if let image = profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(.gray)
                                                .padding(10)
                                        )
                                }
                            }
                            .onChange(of: profileItem) { newItem in
                                if let newItem = newItem {
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            profileImage = uiImage
                                        }
                                    }
                                }
                            }
                        
                        Text("Patient Profile")
                            .font(.title.bold())
                            .foregroundColor(.black)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Personal Information
                    SectionCards(title: "Personal Information", icon: "person.fill") {
                        RoundedInputsField(label: "Full Name", text: $fullName)
                        HStack {
                            RoundedInputsField(label: "Age", text: $age, keyboardType: .numberPad)
                            RoundedInputsField(label: "Gender", text: $gender)
                        }
                        HStack {
                            RoundedInputsField(label: "Blood Group", text: $bloodGroup)
                            RoundedInputsField(label: "Height (cm)", text: $height)
                            RoundedInputsField(label: "Weight (kg)", text: $weight)
                        }
                    }
                    
                    // Contact Info
                    SectionCards(title: "Contact Details", icon: "phone.fill") {
                        RoundedInputsField(label: "Phone", text: $phone, keyboardType: .phonePad)
                        RoundedInputsField(label: "Email", text: $email, keyboardType: .emailAddress)
                        RoundedInputsField(label: "Emergency Contact", text: $emergencyContact)
                        TextEditorsField(label: "Address", text: $address)
                    }
                    
                    // Medical History
                    SectionCards(title: "Medical Information", icon: "cross.case.fill") {
                        TextEditorsField(label: "Chronic Conditions", text: $chronicConditions)
                        TextEditorsField(label: "Medications", text: $medications)
                    }
                    
                    // Save Button
                    Button(action: submitDetails) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Details")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.indigo, .purple],
                                                           startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(radius: 4, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .padding(.top, 6)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            fetchPatientDetails()
        }
    }
    
    // MARK: - Fetch existing patient details
    func fetchPatientDetails() {
        guard let url = URL(string:"\(ServiceApi.Patientdetails)?patient_id=\(patientId) ") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                DispatchQueue.main.async {
                    fullName = json["fullName"] as? String ?? ""
                    age = json["age"] as? String ?? ""
                    gender = json["gender"] as? String ?? ""
                    bloodGroup = json["bloodGroup"] as? String ?? ""
                    height = json["height"] as? String ?? ""
                    weight = json["weight"] as? String ?? ""
                    phone = json["phone"] as? String ?? ""
                    email = json["email"] as? String ?? ""
                    emergencyContact = json["emergencyContact"] as? String ?? ""
                    address = json["address"] as? String ?? ""
                    chronicConditions = json["chronicConditions"] as? String ?? ""
                    medications = json["medications"] as? String ?? ""
                    
                    // Load profile image
                    if let imagePath = json["profile_Image"] as? String,
                       let url = URL(string: "\(ServiceApi.baseURL)\(imagePath)") {
                        Task {
                            if let (data, _) = try? await URLSession.shared.data(from: url),
                               let uiImage = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    profileImage = uiImage
                                }
                            }
                        }
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Submit patient details (including image)
    func submitDetails() {
        guard let url = URL(string: ServiceApi.Patientdetails) else { return }
        
        isLoading = true
        showError = false
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        func appendFormField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        appendFormField("patient_id", patientId)
        appendFormField("fullName", fullName)
        appendFormField("age", age)
        appendFormField("gender", gender)
        appendFormField("bloodGroup", bloodGroup)
        appendFormField("height", height)
        appendFormField("weight", weight)
        appendFormField("phone", phone)
        appendFormField("email", email)
        appendFormField("emergencyContact", emergencyContact)
        appendFormField("address", address)
        appendFormField("chronicConditions", chronicConditions)
        appendFormField("medications", medications)
        
        if let image = profileImage, let imageData = image.jpegData(compressionQuality: 0.8) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"profile_Image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            data.append(imageData)
            data.append("\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data
        
        URLSession.shared.dataTask(with: request) { responseData, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    showError = true
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let responseData = responseData else {
                    showError = true
                    errorMessage = "No response from server."
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        if let status = json["status"] as? String, status == "success" {
                            // ✅ Navigate to home automatically
                            navigateToHome = true
                        } else {
                            showError = true
                            errorMessage = json["message"] as? String ?? "Unknown error"
                        }
                    }
                } catch {
                    showError = true
                    errorMessage = "Failed to parse response."
                }
            }
        }.resume()
    }
}

// MARK: - Components
struct SectionCards<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.indigo)
                Text(title)
                    .font(.headline)
            }
            VStack(spacing: 14) { content }
        }
        .padding()
        .background(.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 3)
        .padding(.horizontal)
    }
}

struct RoundedInputsField: View {
    var label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("Enter \(label)", text: $text)
                .keyboardType(keyboardType)
                .padding(12)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
    }
}

struct TextEditorsField: View {
    var label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $text)
                .frame(height: 80)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
    }
}
