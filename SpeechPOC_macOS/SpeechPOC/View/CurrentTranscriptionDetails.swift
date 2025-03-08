//
//  CurrentTranscriptionDetails.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/8/25.
//
import SwiftUI

struct CurrentTranscriptionDetails: View {
    @Binding var isTranscribing: Bool
    @Binding var selectedTranscription: Transcription?
    @Binding var transcriptions: [Transcription]
    @Binding var showTranscriptionPreview: Bool
    @ObservedObject var audioViewModel: AudioFileTranscriberViewModel
    
    var body: some View {
        DisclosureGroup(
            isExpanded: .constant(true),
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    // If we have a selected transcription or a preview from audioViewModel
                    if let transcription = selectedTranscription {
                        // Editable transcription details
                        TextField("Title", text: Binding(
                            get: { transcription.title },
                            set: { newValue in
                                if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
                                    transcriptions[index].title = newValue
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextEditor(text: Binding(
                            get: { transcription.content },
                            set: { newValue in
                                if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
                                    transcriptions[index].content = newValue
                                }
                            }
                        ))
                        .frame(minHeight: 150)
                        .border(Color.gray.opacity(0.3))
                        
                        // Save button
                        HStack {
                            Spacer()
                            Button("Save Changes") {
                                // Save changes logic
                                // (could dispatch to a ViewModel or persistence service)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if showTranscriptionPreview && !audioViewModel.transcribedText.isEmpty {
                        // Show transcription preview from audio viewModel
                        Text("Transcription Preview")
                            .font(.headline)
                        
                        TextEditor(text: .constant(audioViewModel.transcribedText))
                            .frame(minHeight: 150)
                            .border(Color.gray.opacity(0.3))
                            .disabled(true)
                        
                        // Save Preview button
                        HStack {
                            Spacer()
                            Button("Save as New Transcription") {
                                saveTranscriptionFromPreview()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text("Waiting for transcription...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            },
            label: {
                Label("Transcription Content", systemImage: "doc.text")
                    .font(.headline)
            }
        )

    }
    
    /// Create a new transcription from the audio transcription preview
    private func saveTranscriptionFromPreview() {
        let newTranscription = Transcription(
            title: "Transcription \(Date().formatted(date: .abbreviated, time: .shortened))",
            content: audioViewModel.transcribedText,
            tags: [],
            wordTimestamps: audioViewModel.wordTimestamps
        )
        transcriptions.append(newTranscription)
        
        // Update UI state for new transcription
        selectedTranscription = newTranscription
        isTranscribing = false
        showTranscriptionPreview = false
        
        // Clear audio transcription state
        DispatchQueue.main.async {
            audioViewModel.transcribedText = ""
            audioViewModel.wordTimestamps = []
        }
    }
}

 
