//
//  Transcription.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import Foundation

// WordTimestamp is defined in WordTimestamp.swift
// Make sure WordTimestamp.swift is included in your target's Compile Sources build phase
// Both files should be in the same module

struct Transcription: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var content: String
    var tags: [String]
    var wordTimestamps: [WordTimestamp] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: Transcription, rhs: Transcription) -> Bool {
        return lhs.id == rhs.id
    }
}

