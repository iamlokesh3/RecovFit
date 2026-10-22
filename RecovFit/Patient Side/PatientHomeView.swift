import SwiftUI

// MARK: - Patient Home View with Real-Time Health Data
struct PatientHomeView: View {
    let patientId: String
    @Binding var path: NavigationPath
    @StateObject private var healthManager = SimulatedHealthManager()
    @State private var selectedTab: PatientTabBar.Tab = .home
    @State private var profileNav = false
    @State private var doctorNav = false
    @State private var appointmentNav = false
    @State private var recordNav = false
    @State private var trackNav = false
    @State private var appointmentdetailNav = false
    @State private var exerciseRoutineNav = false
    @State private var cardOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var scrollOffset: CGFloat = 0
    @State private var stepsAnimation: Bool = false
    @State private var showingStepsGoalPicker = false
    @State private var refreshTrigger = false
    @StateObject private var notificationStore = NotificationStore()
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ZStack {
            backgroundDecoration
            mainContent
                .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            setupAnimations()
            healthManager.startRealTimeUpdates()
        }
        .sheet(isPresented: $showingStepsGoalPicker) {
            StepsGoalPickerView(healthManager: healthManager)
        }
        .navigationDestination(isPresented: $appointmentNav) {
            AppointmentView(patientId: patientId, selectedTab: $selectedTab)
        }
        .navigationDestination(isPresented: $recordNav) {
            MyRecordView(patientId: patientId)
        }
        .navigationDestination(isPresented: $exerciseRoutineNav) {
            ExerciseRoutineView(patientId: patientId)
        }
        .navigationDestination(isPresented: $trackNav) {
            AppointmentTrackView(patientId: patientId)
        }
    }
    
    // MARK: - Setup Animations
    private func setupAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
            stepsAnimation = true
        }
    }
    
    // MARK: - Background Decoration
    private var backgroundDecoration: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.teal.opacity(0.04),
                    Color.mint.opacity(0.03),
                    Color.cyan.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            homeContent
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(PatientTabBar.Tab.home)

            ChatBotView()
                .tabItem {
                    Label("Chatbot", systemImage: "message.fill")
                }
                .tag(PatientTabBar.Tab.chatBot)

            PatientProfileView(patientId: patientId, path: $path)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(PatientTabBar.Tab.profile)

            NotificationView(store: notificationStore)
                .tabItem {
                    Label("Notification", systemImage: "bell.fill")
                }
                .badge(notificationStore.notifications.filter { $0.is_read == 0 }.count)
                .tag(PatientTabBar.Tab.notification)
        }
        .task {
            await notificationStore.fetchFromBackend(session: session)
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .notification {
                Task {
                    await notificationStore.markAllRead(session: session)
                }
            }
        }
    }
    
    private var homeContent: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 32) {
                    greetingSection
                    if healthManager.isPermissionDenied {
                        motionPermissionBanner
                    }
                    realTimeStepsSection
                    realTimeSleepSection
                    statusCardsSection
                    quickActionsGrid
                    updatedHealthInsightsSection
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
            }
            .refreshable {
                healthManager.refreshAllData()
            }
        }
    }
    
    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Welcome Back!")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }
    
    // MARK: - Motion Permission Banner
    private var motionPermissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Motion Permission Needed")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Allow Motion & Fitness in Settings to track your steps when walking.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Real-time Steps Section
    private var realTimeStepsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Today's Activity")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        healthManager.refreshAllData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.teal)
                            .rotationEffect(.degrees(healthManager.isRefreshing ? 360 : 0))
                            .animation(healthManager.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: healthManager.isRefreshing)
                            .frame(width: 32, height: 32)
                            .background(Color.teal.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showingStepsGoalPicker = true }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            HStack(spacing: 20) {
                realTimeStepsMainCard
                VStack(spacing: 12) {
                    realTimeStepsGoalCard
                    stepsStreakCard
                }
            }
        }
    }
    
    private var realTimeStepsMainCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.mint.opacity(0.15),
                                    Color.green.opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 35
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                Spacer()
                
                Button(action: {
                    if healthManager.isPermissionDenied {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } else {
                        healthManager.refreshAllData()
                    }
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(healthManager.isPermissionDenied ? .orange : (healthManager.isLiveTracking ? .green : .teal))
                            .frame(width: 8, height: 8)
                        Text(healthManager.isPermissionDenied ? "Needs Access" : (healthManager.isLiveTracking ? "Live" : "Active"))
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(healthManager.isPermissionDenied ? .orange : (healthManager.isLiveTracking ? .green : .teal))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (healthManager.isPermissionDenied ? Color.orange : (healthManager.isLiveTracking ? Color.green : Color.teal)).opacity(0.12)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(healthManager.currentSteps)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.easeInOut(duration: 0.5), value: healthManager.currentSteps)
                    
                    Text("steps")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                
                let progressText = healthManager.stepsProgress >= 1.0 ? "Goal achieved! 🎉" :
                                    healthManager.currentSteps > 0 ? "\(Int((healthManager.stepsProgress * 100)))% of goal" : "Start walking!"
                
                Text(progressText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(healthManager.stepsProgress >= 1.0 ? .green : .blue)
                
                realTimeStepsProgressBar
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.green.opacity(0.08),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
            }
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .shadow(color: .green.opacity(0.25), radius: 20, x: 0, y: 10)
    }
    
    private var realTimeStepsProgressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goal Progress")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(healthManager.stepsProgress * 100))%")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.15))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * healthManager.stepsProgress,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 1.0), value: healthManager.stepsProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(.top, 8)
    }
    
    private var realTimeStepsGoalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
            }
            
            Text("\(healthManager.stepsGoal)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: healthManager.stepsGoal)
            
            Text("Daily Goal")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.orange.opacity(0.06))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: .orange.opacity(0.12), radius: 10, x: 0, y: 5)
    }
    
    private var stepsStreakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                Spacer()
            }
            
            Text("\(healthManager.stepStreak)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: healthManager.stepStreak)
            
            Text("Day Streak")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red.opacity(0.06))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: .red.opacity(0.12), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Real-time Sleep Section
    private var realTimeSleepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Night's Sleep")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            realTimeSleepCard
        }
    }
    
    private var realTimeSleepCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.indigo.opacity(0.3),
                                Color.purple.opacity(0.15),
                                Color.indigo.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 35
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1fh", healthManager.sleepHours))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.5), value: healthManager.sleepHours)
                    
                    Text("sleep")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                
                let sleepQuality = healthManager.sleepHours >= 8 ? "Excellent sleep! ⭐" :
                                    healthManager.sleepHours >= 7 ? "Good rest ✓" :
                                    healthManager.sleepHours >= 6 ? "Could be better" : "Needs improvement"
                
                Text(sleepQuality)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(healthManager.sleepHours >= 7 ? .green : .orange)
            }
            
            Spacer()
            
            VStack {
                Circle()
                    .fill(healthManager.sleepHours >= 7 ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text("Auto")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.indigo.opacity(0.08))
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.indigo.opacity(0.08),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
            }
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .shadow(color: .indigo.opacity(0.18), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Status Cards Section
    private var statusCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Overview")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statusCard(
                    icon: "flame.fill",
                    title: "Calories Burned",
                    value: "\(healthManager.calculatedCalories)",
                    color: .orange,
                    trend: healthManager.caloriesTrend
                )
                
                statusCard(
                    icon: "moon.fill",
                    title: "Sleep Score",
                    value: "\(healthManager.sleepScore)/100",
                    color: .indigo,
                    trend: healthManager.sleepTrend
                )
            }
        }
    }

    // MARK: - Status Card Function
    private func statusCard(icon: String, title: String, value: String, color: Color, trend: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                
                HStack(spacing: 2) {
                    if trend.hasPrefix("+") {
                        Image(systemName: "arrow.up")
                            .font(.system(.caption2, weight: .bold))
                    } else if trend.hasPrefix("-") {
                        Image(systemName: "arrow.down")
                            .font(.system(.caption2, weight: .bold))
                    }
                    
                    Text(trend)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(
                    trend.hasPrefix("+") ? .green :
                    trend.hasPrefix("-") ? .red : .secondary
                )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.5), value: value)
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.08))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .shadow(color: color.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Quick Actions Grid
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                quickActionButton(icon: "calendar.badge.plus", title: "Book Appointment", color: .blue) {
                    appointmentNav = true
                }
                quickActionButton(icon: "doc.text", title: "View Records", color: .green) {
                    recordNav = true
                }
                quickActionButton(icon: "figure.run", title: "Exercise", color: .orange) {
                    exerciseRoutineNav = true
                }
                quickActionButton(icon: "clock.arrow.circlepath", title: "Track Appointment", color: .purple) {
                    trackNav = true
                }
            }
        }
    }
    
    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.thickMaterial)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                }
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Health Insights Section
    private var updatedHealthInsightsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Health Insights")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                insightCard(
                    icon: "figure.walk.circle.fill",
                    title: "Weekly Steps Average",
                    value: "\(healthManager.weeklyStepsAverage)",
                    trend: calculateStepsTrend(),
                    isPositive: healthManager.weeklyStepsAverage >= 8000,
                    color: .green
                )
                
                insightCard(
                    icon: "bed.double.circle.fill",
                    title: "Sleep Quality",
                    value: String(format: "%.1fh", healthManager.sleepHours),
                    trend: healthManager.sleepTrend,
                    isPositive: healthManager.sleepHours >= 7.0,
                    color: .indigo
                )
            }
        }
    }
    
    // MARK: - Insight Card Function
    private func insightCard(icon: String, title: String, value: String, trend: String, isPositive: Bool, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(.caption, weight: .bold))
                        Text(trend)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(isPositive ? .green : .orange)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.08))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .shadow(color: color.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Helper Functions
    private func calculateStepsTrend() -> String {
        let currentAvg = healthManager.weeklyStepsAverage
        let goalPercentage = currentAvg > 0 ? Int((Double(currentAvg) / Double(healthManager.stepsGoal)) * 100) : 0
        
        if goalPercentage >= 100 {
            return "+\(goalPercentage - 100)%"
        } else {
            return "-\(100 - goalPercentage)%"
        }
    }
}

// MARK: - Steps Goal Picker View
struct StepsGoalPickerView: View {
    @ObservedObject var healthManager: SimulatedHealthManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: Int
    
    init(healthManager: SimulatedHealthManager) {
        self.healthManager = healthManager
        _selectedGoal = State(initialValue: healthManager.stepsGoal)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Set Your Daily Steps Goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                Picker("Steps Goal", selection: $selectedGoal) {
                    ForEach(Array(stride(from: 5000, through: 30000, by: 500)), id: \.self) { goal in
                        Text("\(goal) steps").tag(goal)
                    }
                }
                .pickerStyle(.wheel)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recommended goals:")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    ForEach([
                        (8000, "Moderate Activity", "Good for beginners"),
                        (10000, "Active Lifestyle", "Most popular goal"),
                        (12000, "Very Active", "For fitness enthusiasts"),
                        (15000, "Highly Active", "For advanced users")
                    ], id: \.0) { goal, title, description in
                        Button(action: { selectedGoal = goal }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(goal) steps - \(title)")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    Text(description)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedGoal == goal ? .blue.opacity(0.1) : .clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.blue.opacity(0.3), lineWidth: selectedGoal == goal ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Steps Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        healthManager.updateStepsGoal(newGoal: selectedGoal)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}
