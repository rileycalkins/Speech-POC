//
//  WordTimestamp.swift
//  SpeechPOC
//
//  Created automatically
//

import Foundation

struct WordTimestamp: Identifiable, Hashable {
    var id = UUID()
    var word: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    
    var formattedStartTime: String {
        return formatTimeInterval(startTime)
    }
    
    var formattedEndTime: String {
        return formatTimeInterval(endTime)
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
} 