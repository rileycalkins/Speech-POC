//
//  TranscriptionViewModel.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/27/24.
//

import NaturalLanguage
import Foundation
import SwiftUI

// If the Transcription and WordTimestamp imports don't resolve,
// you'll need to adjust your project settings in Xcode:
// 1. Make sure Transcription.swift and WordTimestamp.swift are included in the target
// 2. Ensure proper module organization

class TranscriptionViewModel: ObservableObject {
    @Published var transcriptions: [Transcription] = []
    @Published var selectedTranscription: Transcription?
    
    // MARK: Add, update and delete transcriptions

    func addTranscription(_ transcription: Transcription) {
        transcriptions.append(transcription)
    }
    
    func addTranscriptionWithTimestamps(text: String, wordTimestamps: [WordTimestamp], title: String = "New Transcription") {
        let tags = generateTags(for: text)
        let transcription = Transcription(
            title: title,
            content: text,
            tags: tags,
            wordTimestamps: wordTimestamps
        )
        addTranscription(transcription)
    }
    
    func updateTranscription(_ updatedTranscription: Transcription) {
        if let index = transcriptions.firstIndex(where: { $0.id == updatedTranscription.id }) {
            transcriptions[index] = updatedTranscription
            selectedTranscription = updatedTranscription
        }
        objectWillChange.send()
    }

    func deleteTranscription(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        selectedTranscription = nil
    }

    // MARK: - Natural Language tag generation
    /// Generates tags from transcriptions using Natural Language framework
    /// This function uses NLTagger to analyze the transcription and extract relevant tags. It focuses on identifying nouns and verbs, which are often the most meaningful words for tagging purposes.
    ///  Note: The quality and relevance of tags depend on the content and language of the transcription.
    func generateTags(for transcription: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = transcription

        var tags: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

        tagger.enumerateTags(in: transcription.startIndex..<transcription.endIndex, unit: .word, scheme: .lexicalClass, options: options) { (tag, tokenRange) -> Bool in
            if let tag = tag, tag == .noun || tag == .verb {
                tags.append(String(transcription[tokenRange]))
            }
            return true
        }
        return Array(Set(tags)).prefix(10).map { $0 }
    }
}

