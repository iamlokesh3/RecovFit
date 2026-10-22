//
//  HealthManager-Full.swift
//  RecovFit
//
//  Created by SAIL on 06/11/25.
//

import SwiftUI
import Combine

// MARK: - Real-Time Simulated Health Manager
// NO HEALTHKIT OR CORE MOTION REQUIRED - WORKS EVERYWHERE!
class SimulatedHealthManager: NSObject, ObservableObject {
    // MARK: - Published Properties (Auto-updates UI)
    @Published var currentSteps: Int = 0
    @Published var sleepHours: Double = 0.0
    @Published var caloriesBurned: Double = 0.0
    @Published var stepsGoal: Int = 10000
    @Published var stepStreak: Int = 0
    @Published var weeklyStepsAverage: Int = 0
    @Published var calculatedCalories: Int = 0
    
    // MARK: - Timer and Data Storage
    private var updateTimer: AnyCancellable?
    private var sessionStartDate: Date = Date()
    private var lastUpdateDate: Date = Date()
    private var baseSteps: Int = 0
    private var stepIncrement: Double = 0
    
    // UserDefaults keys for persistence
    private let stepsKey = "savedSteps"
    private let dateKey = "savedDate"
    private let sleepKey = "savedSleep"
    private let streakKey = "savedStreak"
    private let weeklyKey = "savedWeekly"
    
    // MARK: - Computed Properties
    var stepsProgress: Double {
        let progress = Double(currentSteps) / Double(stepsGoal)
        return min(progress, 1.0)
    }
    
    var sleepScore: Int {
        let score = Int((sleepHours / 8.0) * 100)
        return min(score, 100)
    }
    
    var caloriesTrend: String {
        let baseCalories = 2000
        let difference = Int(caloriesBurned) - baseCalories
        if difference >= 0 {
            return "+\(difference)"
        } else {
            return "\(difference)"
        }
    }
    
    var sleepTrend: String {
        // Calculate trend based on sleep quality
        if sleepHours >= 8 {
            return "+15%"
        } else if sleepHours >= 7 {
            return "+8%"
        } else if sleepHours >= 6 {
            return "-5%"
        } else {
            return "-12%"
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadSavedData()
        checkAndResetForNewDay()
        calculateInitialSleep()
        startRealTimeUpdates()
    }
    
    // MARK: - Load Saved Data
    private func loadSavedData() {
        if let savedDate = UserDefaults.standard.object(forKey: dateKey) as? Date {
            let calendar = Calendar.current
            if calendar.isDateInToday(savedDate) {
                // Load today's data
                baseSteps = UserDefaults.standard.integer(forKey: stepsKey)
                currentSteps = baseSteps
                sleepHours = UserDefaults.standard.double(forKey: sleepKey)
                stepStreak = UserDefaults.standard.integer(forKey: streakKey)
                weeklyStepsAverage = UserDefaults.standard.integer(forKey: weeklyKey)
            }
        }
        
        // Load goal (persists across days)
        if UserDefaults.standard.object(forKey: "stepsGoal") != nil {
            stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        }
    }
    
    // MARK: - Check and Reset for New Day
    private func checkAndResetForNewDay() {
        if let savedDate = UserDefaults.standard.object(forKey: dateKey) as? Date {
            let calendar = Calendar.current
            if !calendar.isDateInToday(savedDate) {
                // New day - reset daily metrics
                let previousSteps = UserDefaults.standard.integer(forKey: stepsKey)
                
                // Update streak
                if previousSteps >= stepsGoal {
                    stepStreak += 1
                } else {
                    stepStreak = 0
                }
                
                // Update weekly average
                updateWeeklyAverage(newDaySteps: previousSteps)
                
                // Reset daily counters
                currentSteps = 0
                baseSteps = 0
                caloriesBurned = 0
                calculatedCalories = 0
                
                // Save new day
                saveData()
            }
        }
    }
    
    // MARK: - Calculate Initial Sleep
    private func calculateInitialSleep() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        // Simulate sleep based on time of day
        if hour < 6 {
            // Early morning - currently sleeping
            sleepHours = Double(hour) + Double.random(in: 0...0.5)
        } else if hour < 12 {
            // Morning - full night's sleep
            sleepHours = Double.random(in: 6.5...8.5)
        } else {
            // Afternoon/Evening - previous night's sleep
            sleepHours = Double.random(in: 6.0...8.0)
        }
        
        UserDefaults.standard.set(sleepHours, forKey: sleepKey)
    }
    
    // MARK: - Start Real-Time Updates
    func startRealTimeUpdates() {
        // Calculate realistic step increment based on time of day
        calculateStepIncrement()
        
        // Update every 2 seconds for smooth real-time effect
        updateTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateHealthData()
            }
    }
    
    // MARK: - Calculate Step Increment (Realistic Pattern)
    private func calculateStepIncrement() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        // Simulate realistic activity levels throughout the day
        switch hour {
        case 0...5:
            // Night - minimal activity
            stepIncrement = Double.random(in: 0...1)
        case 6...8:
            // Morning - moderate activity
            stepIncrement = Double.random(in: 2...5)
        case 9...11:
            // Late morning - high activity
            stepIncrement = Double.random(in: 5...10)
        case 12...13:
            // Lunch - very high activity
            stepIncrement = Double.random(in: 8...15)
        case 14...17:
            // Afternoon - moderate to high activity
            stepIncrement = Double.random(in: 4...12)
        case 18...20:
            // Evening - moderate activity
            stepIncrement = Double.random(in: 3...8)
        case 21...23:
            // Night - low activity
            stepIncrement = Double.random(in: 1...3)
        default:
            stepIncrement = Double.random(in: 2...5)
        }
    }
    
    // MARK: - Update Health Data (Called by Timer)
    private func updateHealthData() {
        // Recalculate increment occasionally for variety
        if Int.random(in: 0...10) == 0 {
            calculateStepIncrement()
        }
        
        // Update steps with some randomness
        let increment = Int(stepIncrement * Double.random(in: 0.5...1.5))
        currentSteps += increment
        
        // Calculate calories based on steps (rough estimate)
        // Average: 0.04-0.05 calories per step
        caloriesBurned = Double(currentSteps) * 0.045
        calculatedCalories = Int(caloriesBurned)
        
        // Add base metabolic rate
        let calendar = Calendar.current
        let hoursPassed = calendar.component(.hour, from: Date())
        let baseMetabolicRate = Double(hoursPassed) * 80 // ~80 cal/hour at rest
        caloriesBurned += baseMetabolicRate
        calculatedCalories = Int(caloriesBurned)
        
        // Save periodically
        if Date().timeIntervalSince(lastUpdateDate) > 10 {
            saveData()
            lastUpdateDate = Date()
        }
    }
    
    // MARK: - Save Data to UserDefaults
    private func saveData() {
        UserDefaults.standard.set(currentSteps, forKey: stepsKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
        UserDefaults.standard.set(sleepHours, forKey: sleepKey)
        UserDefaults.standard.set(stepStreak, forKey: streakKey)
        UserDefaults.standard.set(weeklyStepsAverage, forKey: weeklyKey)
    }
    
    // MARK: - Update Weekly Average
    private func updateWeeklyAverage(newDaySteps: Int) {
        // Simple rolling average calculation
        let currentAverage = weeklyStepsAverage
        weeklyStepsAverage = (currentAverage * 6 + newDaySteps) / 7
    }
    
    // MARK: - Manual Data Refresh
    func refreshAllData() {
        // Force immediate update
        updateHealthData()
    }
    
    // MARK: - Update Steps Goal
    func updateStepsGoal(newGoal: Int) {
        stepsGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: "stepsGoal")
    }
    
    // MARK: - Stop Updates
    func stopPeriodicUpdates() {
        updateTimer?.cancel()
        updateTimer = nil
        saveData()
    }
    
    // MARK: - Cleanup
    deinit {
        stopPeriodicUpdates()
    }
}

// MARK: - USAGE INSTRUCTIONS
/*
 
 HOW TO USE THIS SIMULATED HEALTH MANAGER:
 
 1. REPLACE YOUR EXISTING HEALTH MANAGER:
    Replace "SimpleHealthManager" or any HealthKit-based manager with "SimulatedHealthManager"
 
 2. NO CODE CHANGES NEEDED:
    The SimulatedHealthManager has the exact same properties and methods as your original manager:
    - currentSteps
    - sleepHours
    - caloriesBurned
    - stepsGoal
    - stepStreak
    - weeklyStepsAverage
    - calculatedCalories
    - stepsProgress
    - sleepScore
    - caloriesTrend
    - sleepTrend
 
 3. INITIALIZATION:
    @StateObject private var healthManager = SimulatedHealthManager()
 
 4. START/STOP:
    - Automatically starts on init()
    - Call startRealTimeUpdates() in onAppear if needed
    - Call stopPeriodicUpdates() in onDisappear to save battery
 
 5. FEATURES:
    ✅ Real-time updates every 2 seconds
    ✅ Realistic time-of-day patterns
    ✅ Data persistence with UserDefaults
    ✅ Automatic daily reset at midnight
    ✅ Streak tracking
    ✅ Weekly averages
    ✅ No HealthKit required
    ✅ Works in Simulator
    ✅ Works on all devices
 
 6. CUSTOMIZATION:
    - Adjust update frequency: Change Timer interval (line 154)
    - Modify step patterns: Edit calculateStepIncrement() (lines 158-187)
    - Change calorie formula: Edit updateHealthData() (lines 197-206)
 
 7. DATA PERSISTENCE:
    - Steps persist across app launches (same day)
    - Goal persists across days
    - Auto-resets at midnight
    - Maintains streak counter
 
 8. TESTING:
    - Check different times of day for varied activity
    - Test goal achievement for streak
    - Verify data persistence by closing/reopening app
 
 */
