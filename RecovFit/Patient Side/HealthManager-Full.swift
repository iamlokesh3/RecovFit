//
//  HealthManager-Full.swift
//  RecovFit
//
//  Created by SAIL on 06/11/25.
//

import SwiftUI
import Combine
import CoreMotion

// MARK: - Health Manager with Real CoreMotion Pedometer Support
class SimulatedHealthManager: NSObject, ObservableObject {
    // MARK: - Published Properties (Auto-updates UI)
    @Published var currentSteps: Int = 0
    @Published var sleepHours: Double = 0.0
    @Published var caloriesBurned: Double = 0.0
    @Published var stepsGoal: Int = 10000
    @Published var stepStreak: Int = 0
    @Published var weeklyStepsAverage: Int = 0
    @Published var calculatedCalories: Int = 0
    @Published var isLiveTracking: Bool = false
    
    // MARK: - CoreMotion and Data Storage
    private let pedometer = CMPedometer()
    private var baseSteps: Int = 0
    private var lastUpdateDate: Date = Date()
    
    // UserDefaults keys for persistence
    private let stepsKey = "savedSteps"
    private let dateKey = "savedDate"
    private let sleepKey = "savedSleep"
    private let streakKey = "savedStreak"
    private let weeklyKey = "savedWeekly"
    
    // MARK: - Computed Properties
    var stepsProgress: Double {
        guard stepsGoal > 0 else { return 0 }
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
                baseSteps = UserDefaults.standard.integer(forKey: stepsKey)
                currentSteps = baseSteps
                sleepHours = UserDefaults.standard.double(forKey: sleepKey)
                stepStreak = UserDefaults.standard.integer(forKey: streakKey)
                weeklyStepsAverage = UserDefaults.standard.integer(forKey: weeklyKey)
                calculateCaloriesFromSteps()
            }
        }
        
        if UserDefaults.standard.object(forKey: "stepsGoal") != nil {
            stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        }
    }
    
    // MARK: - Check and Reset for New Day
    private func checkAndResetForNewDay() {
        if let savedDate = UserDefaults.standard.object(forKey: dateKey) as? Date {
            let calendar = Calendar.current
            if !calendar.isDateInToday(savedDate) {
                let previousSteps = UserDefaults.standard.integer(forKey: stepsKey)
                
                if previousSteps >= stepsGoal {
                    stepStreak += 1
                } else {
                    stepStreak = 0
                }
                
                updateWeeklyAverage(newDaySteps: previousSteps)
                
                currentSteps = 0
                baseSteps = 0
                caloriesBurned = 0
                calculatedCalories = 0
                
                saveData()
            }
        }
    }
    
    // MARK: - Calculate Initial Sleep
    private func calculateInitialSleep() {
        if sleepHours > 0 { return }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        if hour < 6 {
            sleepHours = Double(hour) + 0.2
        } else if hour < 12 {
            sleepHours = 7.5
        } else {
            sleepHours = 7.2
        }
        
        UserDefaults.standard.set(sleepHours, forKey: sleepKey)
    }
    
    // MARK: - Start Real-Time Updates (Real motion tracking without false increments)
    func startRealTimeUpdates() {
        if CMPedometer.isStepCountingAvailable() {
            isLiveTracking = true
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            
            // Query today's steps so far
            pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self.currentSteps = data.numberOfSteps.intValue
                    self.baseSteps = self.currentSteps
                    self.calculateCaloriesFromSteps()
                    self.saveData()
                }
            }
            
            // Start live updates from now - only updates when physical steps are taken
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self.currentSteps = self.baseSteps + data.numberOfSteps.intValue
                    self.calculateCaloriesFromSteps()
                    self.saveData()
                }
            }
        } else {
            // Simulator or device without step hardware: Keep steps static (do NOT run fake timer)
            isLiveTracking = false
            calculateCaloriesFromSteps()
        }
    }
    
    // MARK: - Calculate Calories
    private func calculateCaloriesFromSteps() {
        // Average: 0.04-0.05 calories per step
        var calories = Double(currentSteps) * 0.045
        
        // Add base metabolic rate for elapsed hours today
        let calendar = Calendar.current
        let hoursPassed = calendar.component(.hour, from: Date())
        let baseMetabolicRate = Double(hoursPassed) * 80.0
        calories += baseMetabolicRate
        
        caloriesBurned = calories
        calculatedCalories = Int(calories)
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
        let currentAverage = weeklyStepsAverage
        weeklyStepsAverage = (currentAverage * 6 + newDaySteps) / 7
    }
    
    // MARK: - Manual Data Refresh
    func refreshAllData() {
        if CMPedometer.isStepCountingAvailable() {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self.currentSteps = data.numberOfSteps.intValue
                    self.baseSteps = self.currentSteps
                    self.calculateCaloriesFromSteps()
                    self.saveData()
                }
            }
        } else {
            loadSavedData()
        }
    }
    
    // MARK: - Update Steps Goal
    func updateStepsGoal(newGoal: Int) {
        stepsGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: "stepsGoal")
    }
    
    // MARK: - Stop Updates
    func stopPeriodicUpdates() {
        pedometer.stopUpdates()
        isLiveTracking = false
        saveData()
    }
    
    // MARK: - Cleanup
    deinit {
        stopPeriodicUpdates()
    }
}
