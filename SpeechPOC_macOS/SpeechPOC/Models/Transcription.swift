//
//  Transcription.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import Foundation

// WordTimestamp is defined in Worcp.swift
// Make sure WordTimestamp.swift is included in your target's Compile Sources build phase
// Both files should be in the same module

struct Transcription: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var content: String
    var tags: [String]
    var wordTimestamps: [WordTimestamp] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.tags == rhs.tags &&
        lhs.wordTimestamps == rhs.wordTimestamps
    }
}

