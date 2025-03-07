//
//  Transcription.swift
//  SpeechPOC
//
//  Created by Generated on 3/6/25.
//

import Foundation

struct Transcription: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var content: String
    var tags: [String]
    var wordTimestamps: [WordTimestamp]
    
    // You can add additional computed properties here as needed
    
    // Custom Equatable implementation
    static func ==(lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.tags == rhs.tags &&
        lhs.wordTimestamps == rhs.wordTimestamps
    }
} 