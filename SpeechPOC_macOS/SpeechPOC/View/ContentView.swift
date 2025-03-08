//
//  ContentView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/24/24.
//
//TODO: Refactor and tweak
import SwiftUI
import Foundation

// Fix imports
// Since we're in the same module, we just need to make sure the files are correctly
// included in the Xcode project target
// No special import statements needed as they're part of the same module

struct ContentView: View {
    @StateObject private var transcriptionViewModel = TranscriptionViewModel()
    @StateObject private var audioFileTranscriberViewModel = AudioFileTranscriberViewModel()
    @State private var temporaryTranscription = Transcription(
        id: UUID(),
        title: "New Transcription",
        content: "",
        tags: [],
        wordTimestamps: []
    )
    
    var body: some View {
        NavigationSplitView {
            transcriptionListView
                .navigationTitle("Transcriptions")
        } detail: {
            if let index = transcriptionViewModel.transcriptions.firstIndex(where: { $0.id == transcriptionViewModel.selectedTranscription?.id }) {
                // Show existing transcription when one is selected
                VStack {
                    HStack {
                        Button(action: { transcriptionViewModel.selectedTranscription = nil }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back to Recording")
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            transcriptionViewModel.deleteTranscription(transcriptionViewModel.transcriptions[index])
                            transcriptionViewModel.selectedTranscription = nil
                        }) {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    TranscriptionDetailView(
                        transcription: $transcriptionViewModel.transcriptions[index],
                        onSave: { updatedTranscription in
                            transcriptionViewModel.updateTranscription(updatedTranscription)
                            transcriptionViewModel.selectedTranscription = nil
                        }
                    )
                }
            } else if audioFileTranscriberViewModel.isTranscribing || 
                     audioFileTranscriberViewModel.isPreparingSegments ||
                     !audioFileTranscriberViewModel.transcribedText.isEmpty {
                // Show recording view only when actively transcribing or has transcription results
                VStack {
                    HStack {
                        Spacer()
                        fileTranscriptionButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    recordingView
                }
            } else {
                // Default: Show a new TranscriptionDetailView with a temporary transcription
                VStack {
                    HStack {
                        Spacer()
                        fileTranscriptionButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    TranscriptionDetailView(
                        transcription: $temporaryTranscription,
                        onSave: { newTranscription in
                            // Create a copy with a new ID to ensure uniqueness
                            var transcriptionToSave = newTranscription
                            transcriptionToSave.id = UUID()
                            
                            // Add to the collection
                            transcriptionViewModel.addTranscription(transcriptionToSave)
                            
                            // Select the newly created transcription
                            DispatchQueue.main.async {
                                transcriptionViewModel.selectedTranscription = transcriptionToSave
                            }
                            
                            // Reset the temporary transcription for next time
                            temporaryTranscription = Transcription(
                                id: UUID(),
                                title: "New Transcription",
                                content: "",
                                tags: [],
                                wordTimestamps: []
                            )
                        }
                    )
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .environmentObject(transcriptionViewModel)
    }
    
    private var fileTranscriptionButton: some View {
        Button(action: {
            audioFileTranscriberViewModel.selectAndTranscribeFile()
        }) {
            Label("Select Audio File", systemImage: "doc.badge.plus")
        }
        .help("Transcribe an audio file")
        .disabled(audioFileTranscriberViewModel.isTranscribing || audioFileTranscriberViewModel.isPreparingSegments)
    }
    
    private var transcriptionListView: some View {
        VStack {
            HStack {
                Text("Transcriptions")
                    .font(.headline)
                Spacer()
                Button(action: addTranscription) {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            
            List(selection: $transcriptionViewModel.selectedTranscription) {
                ForEach(transcriptionViewModel.transcriptions) { transcription in
                    Text(transcription.title)
                        .tag(transcription)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(transcriptionViewModel.selectedTranscription?.id == transcription.id ?
                                      Color(NSColor.selectedTextBackgroundColor).opacity(0.2) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .onMove(perform: moveTranscriptions)
            }
        }
        .frame(minWidth: 200)
        .listStyle(SidebarListStyle())
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            // Audio file transcription view
            AudioFileTranscriberView(
                viewModel: audioFileTranscriberViewModel,
                onTranscriptionComplete: { transcribedText, wordTimestamps in
                    saveFileTranscription(transcribedText, wordTimestamps)
                }
            )
            .padding()
        }
        .padding()
    }
    
    private func saveFileTranscription(_ text: String, _ wordTimestamps: [WordTimestamp]) {
        let title = "File Transcription \(transcriptionViewModel.transcriptions.count + 1)"
        let tags = transcriptionViewModel.generateTags(for: text)
        
        let newTranscription = Transcription(
            id: UUID(),
            title: title,
            content: text,
            tags: tags,
            wordTimestamps: wordTimestamps
        )
        
        transcriptionViewModel.addTranscription(newTranscription)
        
        DispatchQueue.main.async {
            audioFileTranscriberViewModel.transcribedText = ""
            transcriptionViewModel.selectedTranscription = newTranscription
        }
    }
    
    private func addTranscription() {
        let newTranscription = Transcription(
            id: UUID(),
            title: "New Transcription",
            content: "",
            tags: [],
            wordTimestamps: []
        )
        transcriptionViewModel.addTranscription(newTranscription)
        transcriptionViewModel.selectedTranscription = newTranscription
    }

    //TODO: Fix!
    private func moveTranscriptions(from source: IndexSet, to destination: Int) {
        transcriptionViewModel.transcriptions.move(fromOffsets: source, toOffset: destination)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .previewLayout(.fixed(width: 800, height: 600))
            .environmentObject(TranscriptionViewModel())
            .environmentObject(AudioFileTranscriberViewModel())
    }
}
#endif
