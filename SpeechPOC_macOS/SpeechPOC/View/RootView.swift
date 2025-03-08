////
////  RootView.swift
////  SpeechPOC
////
////  Created by Generated on 3/7/25.
////
//
//import SwiftUI
//import Foundation
//
//struct RootView: View {
//    @StateObject private var transcriptionViewModel = TranscriptionViewModel()
//    @StateObject private var audioFileTranscriberViewModel = AudioFileTranscriberViewModel()
//    @State private var temporaryTranscription = Transcription(
//        id: UUID(),
//        title: "New Transcription",
//        content: "",
//        tags: [],
//        wordTimestamps: []
//    )
//    
//    var body: some View {
//        NavigationSplitView {
//            // Sidebar with proper navigation handling
//            VStack(spacing: 0) {
//                List(selection: $transcriptionViewModel.selectedTranscription) {
//                    ForEach(transcriptionViewModel.transcriptions) { transcription in
//                        Text(transcription.title)
//                            .tag(transcription)
//                            .padding()
//                            .background(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .fill(transcriptionViewModel.selectedTranscription?.id == transcription.id ?
//                                          Color(NSColor.selectedTextBackgroundColor).opacity(0.2) : Color.clear)
//                            )
//                            .contentShape(Rectangle())
//                    }
//                    .onMove(perform: moveTranscriptions)
//                }
//            }
//            .navigationTitle("Transcriptions")
//            .toolbar {
//                ToolbarItem(placement: .primaryAction) {
//                    Button(action: addTranscription) {
//                        Image(systemName: "plus")
//                    }
//                }
//            }
//            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
//        } detail: {
//            // Detail view
//            ZStack {
//                if let index = transcriptionViewModel.transcriptions.firstIndex(where: { $0.id == transcriptionViewModel.selectedTranscription?.id }) {
//                    // Show existing transcription
//                    TranscriptionDetailView(
//                        transcription: $transcriptionViewModel.transcriptions[index],
//                        onSave: { updatedTranscription in
//                            transcriptionViewModel.updateTranscription(updatedTranscription)
//                            transcriptionViewModel.selectedTranscription = nil
//                        }
//                    )
//                    .toolbar {
//                        ToolbarItem(placement: .navigation) {
//                            Button(action: { transcriptionViewModel.selectedTranscription = nil }) {
//                                HStack {
//                                    Image(systemName: "arrow.left")
//                                    Text("Back to Recording")
//                                }
//                            }
//                        }
//                        
//                        ToolbarItem(placement: .destructiveAction) {
//                            Button(action: {
//                                transcriptionViewModel.deleteTranscription(transcriptionViewModel.transcriptions[index])
//                                transcriptionViewModel.selectedTranscription = nil
//                            }) {
//                                Image(systemName: "trash")
//                            }
//                        }
//                    }
//                } else if audioFileTranscriberViewModel.isTranscribing || 
//                         audioFileTranscriberViewModel.isPreparingSegments ||
//                         !audioFileTranscriberViewModel.transcribedText.isEmpty {
//                    // Show recording view
//                    AudioFileTranscriberView(
//                        viewModel: audioFileTranscriberViewModel,
//                        onTranscriptionComplete: { transcribedText, wordTimestamps in
//                            saveFileTranscription(transcribedText, wordTimestamps)
//                        }
//                    )
//                    .padding()
//                    .toolbar {
//                        ToolbarItem(placement: .primaryAction) {
//                            Button(action: {
//                                audioFileTranscriberViewModel.selectAndTranscribeFile()
//                            }) {
//                                Label("Select Audio File", systemImage: "doc.badge.plus")
//                            }
//                            .buttonStyle(.borderedProminent)
//                            .labelStyle(.titleAndIcon)
//                            .help("Transcribe an audio file")
//                        }
//                    }
//                } else {
//                    // Default: Show empty transcription
//                    TranscriptionDetailView(
//                        transcription: $temporaryTranscription,
//                        onSave: { newTranscription in
//                            // Create a copy with a new ID to ensure uniqueness
//                            var transcriptionToSave = newTranscription
//                            transcriptionToSave.id = UUID()
//                            
//                            // Add to the collection
//                            transcriptionViewModel.addTranscription(transcriptionToSave)
//                            
//                            // Select the newly created transcription
//                            DispatchQueue.main.async {
//                                transcriptionViewModel.selectedTranscription = transcriptionToSave
//                            }
//                            
//                            // Reset the temporary transcription for next time
//                            temporaryTranscription = Transcription(
//                                id: UUID(),
//                                title: "New Transcription",
//                                content: "",
//                                tags: [],
//                                wordTimestamps: []
//                            )
//                        }
//                    )
//                    .toolbar {
//                        ToolbarItem(placement: .primaryAction) {
//                            Button(action: {
//                                audioFileTranscriberViewModel.selectAndTranscribeFile()
//                            }) {
//                                Label("Select Audio File", systemImage: "doc.badge.plus")
//                            }
//                            .buttonStyle(.borderedProminent)
//                            .labelStyle(.titleAndIcon)
//                            .help("Transcribe an audio file")
//                        }
//                    }
//                }
//            }
//        }
//        .frame(minWidth: 800, minHeight: 600)
//        .environmentObject(transcriptionViewModel)
//    }
//    
//    private func addTranscription() {
//        let newTranscription = Transcription(
//            id: UUID(),
//            title: "New Transcription",
//            content: "",
//            tags: [],
//            wordTimestamps: []
//        )
//        transcriptionViewModel.addTranscription(newTranscription)
//        transcriptionViewModel.selectedTranscription = newTranscription
//    }
//    
//    private func saveFileTranscription(_ text: String, _ wordTimestamps: [WordTimestamp]) {
//        let title = "File Transcription \(transcriptionViewModel.transcriptions.count + 1)"
//        let tags = transcriptionViewModel.generateTags(for: text)
//        
//        let newTranscription = Transcription(
//            id: UUID(),
//            title: title,
//            content: text,
//            tags: tags,
//            wordTimestamps: wordTimestamps
//        )
//        
//        transcriptionViewModel.addTranscription(newTranscription)
//        
//        DispatchQueue.main.async {
//            audioFileTranscriberViewModel.transcribedText = ""
//            transcriptionViewModel.selectedTranscription = newTranscription
//        }
//    }
//    
//    private func moveTranscriptions(from source: IndexSet, to destination: Int) {
//        transcriptionViewModel.transcriptions.move(fromOffsets: source, toOffset: destination)
//    }
//}
//
//#Preview {
//    RootView()
//} 
