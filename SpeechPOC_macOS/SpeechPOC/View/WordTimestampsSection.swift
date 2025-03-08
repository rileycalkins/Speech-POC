//
//  WordTimestampsSection.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/8/25.
//
import SwiftUI

struct WordTimestampsSection: View {

    @Binding var showWordTimestamps: Bool
    var currentTranscription: Transcription

    var body: some View {
        DisclosureGroup(
            isExpanded: $showWordTimestamps,
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(currentTranscription.wordTimestamps) { timestamp in
                            WordTimestampView(
                                word: timestamp.word,
                                startTime: timestamp.formattedStartTime,
                                endTime: timestamp.formattedEndTime
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                )
            },
            label: {
                Label("Word Timestamps", systemImage: "clock")
                    .font(.headline)
            }
        )

    }
}

