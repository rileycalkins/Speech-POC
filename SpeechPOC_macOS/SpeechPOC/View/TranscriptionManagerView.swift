import SwiftUI
import AVFoundation
import Speech
import Combine
import Foundation

extension AVFileType {
    var fileExtension: String {
        switch self {
        case .wav:
            return "wav"
        case .mp3:
            return "mp3"
        case .m4a:
            return "m4a"
        case .aiff:
            return "aif"
        case .mp4:
            return "mp4"
        default:
            return "m4a"
        }
    }
}

/// A combined view that integrates transcription listing, creation, and editing in one interface
struct TranscriptionManagerView: View {
    // ViewModel for audio transcription
    @StateObject private var audioViewModel = AudioFileTranscriberViewModel()
    
    // State for transcriptions management
    @State private var transcriptions: [Transcription] = []
    @State private var selectedTranscription: Transcription? {
        didSet {
            // Reset UI state when transcription selection changes
            if selectedTranscription != oldValue {
                resetUIState()
            }
        }
    }
    @State private var isTranscribing: Bool = false {
        didSet {
            // When transcription finishes, ensure preview is shown
            if !isTranscribing && oldValue == true && !audioViewModel.transcribedText.isEmpty {
                showTranscriptionPreview = true
            }
        }
    }
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
                            .onTapGesture {
                                // Explicitly handle selection to ensure UI updates
                                handleTranscriptionSelection(transcription)
                            }
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
                    TranscriptionActions(
                        audioViewModel: audioViewModel, 
                        isTranscribing: $isTranscribing,
                        showTranscriptionPreview: $showTranscriptionPreview
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
                    // Only show when a transcription is selected or being created or when there's transcribed text
                    if selectedTranscription != nil || showTranscriptionPreview || !audioViewModel.transcribedText.isEmpty {
                        CurrentTranscriptionDetails(
                            isTranscribing: $isTranscribing,
                            selectedTranscription: $selectedTranscription,
                            transcriptions: $transcriptions,
                            showTranscriptionPreview: $showTranscriptionPreview,
                            audioViewModel: audioViewModel
                        )
                        .padding(.horizontal)
                        
                        // SECTION 4: Word Timestamps (collapsible)
                        if let currentTranscription = getCurrentTranscription(),
                           !currentTranscription.wordTimestamps.isEmpty {
                            WordTimestampsSection(
                                showWordTimestamps: $showWordTimestamps,
                                currentTranscription: currentTranscription
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
        .onReceive(audioViewModel.$isTranscribing) { isViewModelTranscribing in
            if !isViewModelTranscribing && isTranscribing {
                // Transcription has completed in the ViewModel
                isTranscribing = false
                
                if !audioViewModel.transcribedText.isEmpty {
                    // Make sure the preview is shown
                    showTranscriptionPreview = true
                }
            }
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
    
    
    
    /// Add a new empty transcription
    private func addTranscription() {
        let newTranscription = Transcription(
            title: "New Transcription", 
            content: "", 
            tags: []
        )
        transcriptions.append(newTranscription)
        
        // Select the new transcription and reset UI state
        selectedTranscription = newTranscription
        showTranscriptionPreview = false
        isTranscribing = false
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
    
    /// Reset UI state when switching between transcriptions
    private func resetUIState() {
        // Reset collapsible sections to default states
        showWordTimestamps = false
        showTagsSection = false
        
        // Clear preview state if we've selected an existing transcription
        if selectedTranscription != nil {
            showTranscriptionPreview = false
        }
    }
    
    // New helper method to handle transcription selection
    private func handleTranscriptionSelection(_ transcription: Transcription) {
        // Stop any ongoing transcription
        if isTranscribing {
            audioViewModel.cancelTranscription()
            isTranscribing = false
        }
        
        // Clear any preview state
        showTranscriptionPreview = false
        
        // Set the selected transcription
        selectedTranscription = transcription
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
                        let csIndex = viewModel.currentSegmentIndex
                        let numSegments = viewModel.numberOfSegments
                        let indexEqualsSegments = csIndex == numSegments
                        Text("Processing segment \(indexEqualsSegments ? numSegments : csIndex + 1) of \(numSegments)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .animation(.easeInOut, value: csIndex)
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
    
    // Calculate segment duration based on number of segments
    private func getSegmentDuration() -> String {
        // Use a fixed estimated duration based on the number of segments
        let estimatedTotalDuration: TimeInterval = 180.0 // 3 minutes default
        var segmentDuration: TimeInterval = estimatedTotalDuration
        
        if viewModel.numberOfSegments > 0 {
            segmentDuration = estimatedTotalDuration / Double(viewModel.numberOfSegments)
        }
        
        // Format as MM:SS
        let minutes = Int(segmentDuration) / 60
        let seconds = Int(segmentDuration) % 60
        return String(format: "(%02d:%02d)", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Get state for this segment
            let state = getSegmentState()
            
            HStack {
                Text("Segment \(index + 1)")
                    .font(.callout)
                
                // Add segment duration display
                Text(getSegmentDuration())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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

/// Transcription actions view
struct TranscriptionActions: View {
    @ObservedObject var audioViewModel: AudioFileTranscriberViewModel
    @Binding var isTranscribing: Bool
    @Binding var showTranscriptionPreview: Bool
    
    var body: some View {
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


