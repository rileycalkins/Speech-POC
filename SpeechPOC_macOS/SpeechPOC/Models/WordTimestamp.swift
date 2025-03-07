//
//  WordTimestamp.swift
//  SpeechPOC
//
//  Created by Generated on 3/6/25.
//

import Foundation

struct WordTimestamp: Identifiable, Codable, Equatable {
    var id: String
    var word: String
    var startTime: Double
    var endTime: Double
    
    var formattedStartTime: String {
        formatTime(startTime)
    }
    
    var formattedEndTime: String {
        formatTime(endTime)
    }
    
    private func formatTime(_ timeInSeconds: Double) -> String {
        let minutes = Int(timeInSeconds / 60)
        let seconds = Int(timeInSeconds.truncatingRemainder(dividingBy: 60))
        let milliseconds = Int((timeInSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
} 