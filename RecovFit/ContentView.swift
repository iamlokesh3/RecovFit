//
//  ContentView.swift
//  RecovFit
//
//  Created by SAIL L1 on 31/05/25.
//

import SwiftUI
import SwiftData

// Define your model if not already defined
@Model
class Item: Identifiable {
    var id: UUID
    var timestamp: Date

    init(timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
    }
}

