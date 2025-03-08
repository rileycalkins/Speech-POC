//
//  TransactionDetails.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/8/25.
//
import SwiftUI

struct TransactionActions: View {
    @ObservedObject var audioViewModel: AudioFileTranscriberViewModel
    @State var selectedTranscription: String?
    @Binding var isTranscribing: Bool
    @State var showTranscriptionPreview: Bool = false
    
    var body: some View {
        // SECTION 1: Transcription Actions
        DisclosureGroup(
            isExpanded: .constant(true),
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Select Audio File for Transcription") {
                        // Cancel any existing transcription
                        if isTranscribing {
                            audioViewModel.cancelTranscription()
                        }
                        
                        // Reset UI state
                        selectedTranscription = nil
                        isTranscribing = true
                        showTranscriptionPreview = true
                        
                        // Start new transcription
                        audioViewModel.selectAndTranscribeFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTranscribing)
                    
                    if isTranscribing && audioViewModel.errorMessage == nil {
                        Text("Transcription in progress...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            },
            label: {
                Label("Transcription Actions", systemImage: "waveform")
                    .font(.headline)
            }
        )

    }
}

