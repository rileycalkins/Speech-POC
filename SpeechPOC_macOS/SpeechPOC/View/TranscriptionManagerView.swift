import SwiftUI
import AVFoundation
import Speech
import Combine
import Foundation

/// A combined view that integrates transcription listing, creation, and editing in one interface
struct TranscriptionManagerView: View {
    // ViewModel for audio transcription
    @StateObject private var audioViewModel = AudioFileTranscriberViewModel()
    
    // State for transcriptions management
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription?
    @State private var isTranscribing: Bool = false
    @State private var isEditMode: Bool = false
    
    // UI State
    @State private var showWordTimestamps: Bool = false
    @State private var showTagsSection: Bool = false
    @State private var showTranscriptionPreview: Bool = false
    
    var body: some View {
        NavigationSplitView {
            // SIDEBAR: Transcription List (from TranscriptionListView)
            VStack {
                List(selection: $selectedTranscription) {
                    ForEach(transcriptions) { transcription in
                        Text(transcription.title)
                            .tag(transcription)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTranscription?.id == transcription.id ?
                                          Color(NSColor.selectedTextBackgroundColor).opacity(0.2) : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .onMove(perform: moveTranscriptions)
                    .onDelete(perform: deleteTranscriptions)
                }
                
                // Button for new transcription
                Button(action: addTranscription) {
                    Label("New Transcription", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .navigationTitle("Transcriptions")
            .frame(minWidth: 220)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                    }
                }
            }
        } detail: {
            // DETAIL VIEW: Combined transcription details and creation
            ScrollView {
                VStack(spacing: 20) {
                    // SECTION 1: Transcription Actions
                    DisclosureGroup(
                        isExpanded: .constant(true),
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                Button("Select Audio File for Transcription") {
                                    audioViewModel.selectAndTranscribeFile()
                                    isTranscribing = true
                                    showTranscriptionPreview = true
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
                    .padding(.horizontal)
                    
                    // SECTION 2: Transcription Progress (from AudioFileTranscriberView)
                    // Only show when actively transcribing
                    if isTranscribing {
                        DisclosureGroup(
                            isExpanded: .constant(true),
                            content: {
                                TranscriptionProgressView(viewModel: audioViewModel)
                                    .padding(.vertical, 8)
                            },
                            label: {
                                Label("Transcription Progress", systemImage: "chart.bar.fill")
                                    .font(.headline)
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // SECTION 3: Current Transcription Details (from TranscriptionDetailView)
                    // Only show when a transcription is selected or being created
                    if selectedTranscription != nil || showTranscriptionPreview {
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
                                                isTranscribing = false
                                                showTranscriptionPreview = false
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
                        .padding(.horizontal)
                        
                        // SECTION 4: Word Timestamps (collapsible)
                        if let currentTranscription = getCurrentTranscription(),
                           !currentTranscription.wordTimestamps.isEmpty {
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
                            .padding(.horizontal)
                        }
                        
                        // SECTION 5: Tags (collapsible)
                        if let transcription = selectedTranscription {
                            DisclosureGroup(
                                isExpanded: $showTagsSection,
                                content: {
                                    TranscriptionTagsView(tags: Binding(
                                        get: { transcription.tags },
                                        set: { newValue in
                                            if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
                                                transcriptions[index].tags = newValue
                                            }
                                        }
                                    ))
                                    .padding(.vertical, 8)
                                },
                                label: {
                                    Label("Tags", systemImage: "tag")
                                        .font(.headline)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Error message (if any)
                    if let errorMessage = audioViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .frame(minWidth: 500, minHeight: 600)
            .navigationTitle(selectedTranscription?.title ?? "New Transcription")
        }
        .onAppear {
            // Load saved transcriptions (placeholder)
            loadTranscriptions()
        }
    }
    
    // MARK: - Helper Functions
    
    /// Get current transcription (either selected or from audio viewModel)
    private func getCurrentTranscription() -> Transcription? {
        if let transcription = selectedTranscription {
            return transcription
        } else if showTranscriptionPreview && !audioViewModel.transcribedText.isEmpty {
            // Create a temporary transcription object from the audio viewModel
            return Transcription(
                title: "Preview",
                content: audioViewModel.transcribedText,
                tags: [],
                wordTimestamps: audioViewModel.wordTimestamps
            )
        }
        return nil
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
        selectedTranscription = newTranscription
    }
    
    /// Add a new empty transcription
    private func addTranscription() {
        let newTranscription = Transcription(
            title: "New Transcription", 
            content: "", 
            tags: []
        )
        transcriptions.append(newTranscription)
        selectedTranscription = newTranscription
    }
    
    /// Reorder transcriptions in the list
    private func moveTranscriptions(from source: IndexSet, to destination: Int) {
        transcriptions.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Delete transcriptions from the list
    private func deleteTranscriptions(at offsets: IndexSet) {
        if let selected = selectedTranscription,
           offsets.contains(transcriptions.firstIndex(where: { $0.id == selected.id }) ?? -1) {
            selectedTranscription = nil
        }
        transcriptions.remove(atOffsets: offsets)
    }
    
    /// Load saved transcriptions (placeholder implementation)
    private func loadTranscriptions() {
        // In a real app, load from persistent storage
        // This is just a placeholder
        transcriptions = [
            Transcription(
                title: "Sample Transcription 1",
                content: "This is a sample transcription content.",
                tags: ["sample", "demo"]
            ),
            Transcription(
                title: "Sample Transcription 2",
                content: "Another sample transcription for demonstration.",
                tags: ["sample"]
            )
        ]
    }
}

// MARK: - Subviews

/// Subview for displaying transcription progress
struct TranscriptionProgressView: View {
    @ObservedObject var viewModel: AudioFileTranscriberViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Show file splitting progress
            if viewModel.isPreparingSegments {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Preparing audio segments...")
                        .font(.callout)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.isPreparingSegments)
            }
            
            // Show segments progress
            if viewModel.numberOfSegments > 1 && !viewModel.segmentProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .animation(.easeInOut, value: viewModel.overallProgress)
                    }
                    
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
                    
                    if viewModel.estimatedRemainingTime > 0 {
                        Text("Estimated time: \(viewModel.formatTimeRemaining(viewModel.estimatedRemainingTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    HStack {
                        Text("Segments")
                            .font(.headline)
                        Spacer()
                        Text("Processing segment \(viewModel.currentSegmentIndex + 1) of \(viewModel.numberOfSegments)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .animation(.easeInOut, value: viewModel.currentSegmentIndex)
                    }
                    
                    ForEach(0..<viewModel.segmentProgress.count, id: \.self) { index in
                        SegmentProgressView(viewModel: viewModel, index: index)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .transition(.opacity)
                .animation(.easeInOut, value: !viewModel.segmentProgress.isEmpty)
            }
            // Current segment progress when transcribing
            else if viewModel.isTranscribing {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
                    
                    HStack {
                        if viewModel.numberOfSegments > 1 {
                            Text("Transcribing segment \(viewModel.currentSegmentIndex + 1) of \(viewModel.numberOfSegments) • \(Int(viewModel.overallProgress * 100))%")
                                .animation(.easeInOut, value: viewModel.overallProgress)
                        } else {
                            Text("Transcribing... \(Int(viewModel.overallProgress * 100))%")
                                .animation(.easeInOut, value: viewModel.overallProgress)
                        }
                        Spacer()
                        if viewModel.estimatedRemainingTime > 0 {
                            Text("Estimated time: \(viewModel.formatTimeRemaining(viewModel.estimatedRemainingTime))")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Cancel") {
                        viewModel.cancelTranscription()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.isTranscribing)
            }
        }
    }
}

/// Individual segment progress view
struct SegmentProgressView: View {
    @ObservedObject var viewModel: AudioFileTranscriberViewModel
    let index: Int
    
    // Helper to get segment state from viewModel
    private func getSegmentState() -> SegmentState {
        // Access segment state directly through the view model
        let state = viewModel.progressManager.getSegmentState(index)
        
        // If segment states aren't populated yet, fall back to basic state logic
        if case .pending = state, viewModel.currentSegmentIndex > 0 {
            if viewModel.currentSegmentIndex == index && viewModel.isTranscribing {
                return .inProgress
            } else if index < viewModel.currentSegmentIndex {
                return .completed
            }
        }
        
        return state
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Get state for this segment
            let state = getSegmentState()
            
            HStack {
                Text("Segment \(index + 1)")
                    .font(.callout)
                
                Text(state.label)
                    .font(.caption)
                    .foregroundColor(state.color)
                
                Spacer()
                Text("\(Int(viewModel.segmentProgress[index] * 100))%")
                    .font(.callout)
                    .foregroundColor(state.color)
                    .animation(.easeInOut, value: viewModel.segmentProgress[index])
            }
            ProgressView(value: viewModel.segmentProgress[index])
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(state.color)
                .animation(.easeInOut(duration: 0.5), value: viewModel.segmentProgress[index])
        }
    }
}

/// Word timestamp display item
struct WordTimestampView: View {
    let word: String
    let startTime: String
    let endTime: String
    
    var body: some View {
        HStack {
            Text(word)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Text("\(startTime) - \(endTime)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

/// Custom tag editing view
struct TranscriptionTagsView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Current tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .font(.caption)
                                .padding(.leading, 8)
                                .padding(.trailing, 4)
                            
                            Button(action: {
                                tags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .padding(.trailing, 8)
                        }
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Add new tag
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}


