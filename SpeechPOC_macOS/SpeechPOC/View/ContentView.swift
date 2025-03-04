//
//  ContentView.swift
//  SpeechPOC
//
//  Created by Alex Lifa on 9/24/24.
//
//TODO: Refactor and tweak
import SwiftUI

struct ContentView: View {
    @StateObject private var transcriptionViewModel = TranscriptionViewModel()
    @StateObject private var audioFileTranscriberViewModel = AudioFileTranscriberViewModel()
    
    var body: some View {
        NavigationSplitView {
            transcriptionListView
        } detail: {
            if let index = transcriptionViewModel.transcriptions.firstIndex(where: { $0.id == transcriptionViewModel.selectedTranscription?.id }) {
                TranscriptionDetailView(
                    transcription: $transcriptionViewModel.transcriptions[index],
                    onSave: { updatedTranscription in
                        transcriptionViewModel.updateTranscription(updatedTranscription)
                        transcriptionViewModel.selectedTranscription = nil
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            transcriptionViewModel.deleteTranscription(transcriptionViewModel.transcriptions[index])
                            transcriptionViewModel.selectedTranscription = nil
                        }) {
                            Image(systemName: "trash")
                        }
                    }
                    ToolbarItem(placement: .navigation) {
                        Button(action: { transcriptionViewModel.selectedTranscription = nil }) {
                            Image(systemName: "arrow.left")
                            Text("Back to Recording")
                        }
                    }
                }
            } else {
                recordingView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .environmentObject(transcriptionViewModel)
    }
    
    private var transcriptionListView: some View {
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
        .frame(minWidth: 200)
        .listStyle(SidebarListStyle())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addTranscription) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationTitle("Transcriptions")
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
    
    private func saveFileTranscription(_ text: String, _ wordTimestamps: [WorldTimestamp]) {
        let title = "File Transcription \(transcriptionViewModel.transcriptions.count + 1)"
        let tags = transcriptionViewModel.generateTags(for: text)
        
        let newTranscription = Transcription(
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
            title: "New Transcription",
            content: "",
            tags: []
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
