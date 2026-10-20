import Foundation

struct ServiceApi {
    
    static var baseURL = "http://14.139.187.229:8081/recovfit/"
    
    //static var baseURL = "http://localhost/recovfit/"

    
    
    static var DeleteAccount = baseURL + "delete_account.php"
    
    static var ForgetPassword = baseURL + "forget_password.php"
    
    static var Notification = baseURL + "notification.php"
    
    //Admin
    
    static var Admin = baseURL + "admin_login.php"
    
    static var AdminGetinfo = baseURL + "admin_getinfo.php"
    
    static var AdminApprovel = baseURL + "admin_approvel.php"
    
    static var AdminReject = baseURL + "admin_reject.php"
    
    //patient

    static var PatiientLogin = baseURL + "patient/p_login.php"
    
    static var Patiientappointment = baseURL + "patient/get_appointment1.php"
    
    static var Appointmentbooking = baseURL + "patient/appointmentbooking.php"
    
    static var Patientdetails = baseURL + "patient/p_details.php"
    
    static var PatientRegistration = baseURL + "patient/p_registration.php"
    
    static var PatientReport = baseURL + "patient/p_report.php"
    
    
    //Doctor
    
    static var Doctoresechudled = baseURL + "doctor/d_schudled.php"
    
    static var Doctoresechudledupdated = baseURL + "doctor/d_schudledupdate.php"
    
    static var Doctordetails = baseURL + "doctor/d_details.php"
    
    static var Doctorlogin = baseURL + "doctor/d_login.php"
    
    static var Doctorprofile = baseURL + "doctor/d_profile.php"
    
    static var Addpatient = baseURL + "doctor/d_addpatient.php"
    
    static var Deletepatient = baseURL + "doctor/d_deletepatient.php"
    
    static var UploadExercise = baseURL + "doctor/d_exerciseupload.php"
    
    static var CreateSession = baseURL + "doctor/d_createsession.php" 
    
    static var DoctorRegistration = baseURL + "doctor/d_registration.php"
    
    static var UploadExerciseText = baseURL + "doctor/d_exerciseText.php"
    //get doctore
    
    static var Status = baseURL + "doctor/d_status.php"
    
    static var TodayAppoinment = baseURL + "doctor/d_todayAP.php"
    
}
