import SwiftUI
import AVFoundation
import Speech
import Combine

// Fix the missing imports by explicitly importing from the project structure
// No need for explicit imports as they're in the same module, but we need to ensure these files are included in the build
// The comments below serve as documentation for future developers

// WordTimestamp is defined in Model/WordTimestamp.swift
// RateLimiter is defined in Utilities/RateLimiter.swift

// ViewModel for audio file transcription
class AudioFileTranscriberViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var progress: Double = 0.0
    @Published var estimatedRemainingTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var wordTimestamps: [WordTimestamp] = []
    
    // New properties for file splitting
    @Published var numberOfSegments: Int = 1
    @Published var currentSegmentIndex: Int = 0
    @Published var segmentProgress: [Double] = []
    @Published var isPreparingSegments: Bool = false
    @Published var overallProgress: Double = 0.0
    
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var fileURL: URL?
    private var startTime: Date?
    private var audioDuration: TimeInterval = 0
    private var progressTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Properties for segments
    private var segmentURLs: [URL] = []
    private var segmentDurations: [TimeInterval] = []
    private var segmentTexts: [String] = []
    private var segmentWordTimestamps: [[WordTimestamp]] = []
    private var temporaryDirectoryURL: URL?
    
    // Add throttling for UI updates
    private var lastUpdateTime = Date()
    
    // Add rate limiter
    private let rateLimiter = RateLimiter()
    
    init() {
        requestSpeechRecognitionAccess()
    }
    
    func selectAndTranscribeFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .mp3, .wav, .mpeg4Audio, .aiff]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        // Make sure the panel appears in front of the application's window
        if let window = NSApplication.shared.windows.first {
            openPanel.level = .floating
            openPanel.beginSheetModal(for: window) { [weak self] response in
                guard let self = self else { return }
                
                if response == .OK, let url = openPanel.url {
                    self.fileURL = url
                    self.showSegmentSelectionDialog(url: url)
                }
            }
        } else {
            // Fallback if we can't get the main window
            openPanel.level = .modalPanel
            openPanel.begin { [weak self] response in
                guard let self = self else { return }
                
                if response == .OK, let url = openPanel.url {
                    self.fileURL = url
                    self.showSegmentSelectionDialog(url: url)
                }
            }
        }
    }
    
    private func showSegmentSelectionDialog(url: URL) {
        // Create an alert to ask the user for the number of segments
        let alert = NSAlert()
        alert.messageText = "Split Audio File"
        alert.informativeText = "Enter the number of equal segments to split the audio file into:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "1"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if let window = NSApplication.shared.windows.first {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn { // OK button
                    if let segments = Int(textField.stringValue), segments > 0 {
                        self.numberOfSegments = segments
                        self.segmentProgress = Array(repeating: 0.0, count: segments)
                        self.processAudioFile(url: url)
                    } else {
                        self.errorMessage = "Please enter a valid number of segments"
                    }
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn { // OK button
                if let segments = Int(textField.stringValue), segments > 0 {
                    self.numberOfSegments = segments
                    self.segmentProgress = Array(repeating: 0.0, count: segments)
                    self.processAudioFile(url: url)
                } else {
                    self.errorMessage = "Please enter a valid number of segments"
                }
            }
        }
    }
    
    private func processAudioFile(url: URL) {
        guard !isTranscribing else { return }
        
        // Reset previous state
        self.transcribedText = ""
        self.progress = 0
        self.errorMessage = nil
        self.wordTimestamps = []
        self.overallProgress = 0.0
        self.currentSegmentIndex = 0
        
        // Clean up previous temporary files
        self.cleanupTemporaryFiles()
        
        // Get audio file duration for progress calculation
        getAudioDuration(for: url) { [weak self] duration in
            guard let self = self else { return }
            
            self.audioDuration = duration
            
            if self.numberOfSegments > 1 {
                self.isPreparingSegments = true
                self.splitAudioFile(url: url)
            } else {
                self.segmentURLs = [url]
                self.segmentDurations = [duration]
                self.startProcessingNextSegment()
            }
        }
    }
    
    private func splitAudioFile(url: URL) {
        // Create temporary directory
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            self.temporaryDirectoryURL = temporaryDirectory
        } catch {
            self.errorMessage = "Failed to create temporary directory: \(error.localizedDescription)"
            self.isPreparingSegments = false
            return
        }
        
        // Split the audio file using AVAssetExportSession
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                guard status == .loaded else {
                    self.errorMessage = "Failed to load audio asset: \(error?.localizedDescription ?? "Unknown error")"
                    self.isPreparingSegments = false
                    return
                }
                
                let duration = CMTimeGetSeconds(asset.duration)
                let segmentDuration = duration / Double(self.numberOfSegments)
                
                // Create export sessions for each segment
                for i in 0..<self.numberOfSegments {
                    let startTime = Double(i) * segmentDuration
                    let endTime = min(startTime + segmentDuration, duration)
                    
                    let startCMTime = CMTimeMakeWithSeconds(startTime, preferredTimescale: 600)
                    let endCMTime = CMTimeMakeWithSeconds(endTime, preferredTimescale: 600)
                    let timeRange = CMTimeRangeFromTimeToTime(start: startCMTime, end: endCMTime)
                    
                    let fileType = self.determineFileType(from: url)
                    let segmentFileName = "segment_\(i).\(fileType.fileExtension)"
                    let segmentURL = temporaryDirectory.appendingPathComponent(segmentFileName)
                    
                    // Setup export session
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                        self.errorMessage = "Failed to create export session"
                        self.isPreparingSegments = false
                        return
                    }
                    
                    exportSession.outputURL = segmentURL
                    exportSession.outputFileType = fileType
                    exportSession.timeRange = timeRange
                    
                    self.segmentURLs.append(segmentURL)
                    self.segmentDurations.append(endTime - startTime)
                    
                    exportSession.exportAsynchronously {
                        DispatchQueue.main.async {
                            if exportSession.status == .completed {
                                // Check if all segments are processed
                                if self.segmentURLs.count == self.numberOfSegments {
                                    self.isPreparingSegments = false
                                    self.startProcessingNextSegment()
                                }
                            } else if exportSession.status == .failed {
                                self.errorMessage = "Failed to export segment \(i): \(exportSession.error?.localizedDescription ?? "Unknown error")"
                                self.isPreparingSegments = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func determineFileType(from url: URL) -> AVFileType {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "wav":
            return .wav
        case "mp3":
            return .mp3
        case "m4a":
            return .m4a
        case "aiff", "aif":
            return .aiff
        default:
            // Default to mp4 as a fallback
            return .mp4
        }
    }
    
    private func startProcessingNextSegment() {
        guard currentSegmentIndex < segmentURLs.count else {
            // All segments processed, combine results
            finishTranscription()
            return
        }
        
        let segmentURL = segmentURLs[currentSegmentIndex]
        startTranscription(url: segmentURL)
    }
    
    private func finishTranscription() {
        // Combine all segment texts
        transcribedText = segmentTexts.joined(separator: " ")
        
        // Adjust timestamps for word timings across segments
        var allWordTimestamps: [WordTimestamp] = []
        var timeOffset: TimeInterval = 0
        
        for (i, segmentTimestamps) in segmentWordTimestamps.enumerated() {
            // Create adjusted timestamps with proper offset
            let adjustedTimestamps = segmentTimestamps.map { timestamp -> WordTimestamp in
                return WordTimestamp(
                    word: timestamp.word,
                    startTime: timestamp.startTime + timeOffset,
                    endTime: timestamp.endTime + timeOffset
                )
            }
            
            allWordTimestamps.append(contentsOf: adjustedTimestamps)
            
            // Add this segment's duration to the offset for the next segment
            timeOffset += segmentDurations[i]
        }
        
        wordTimestamps = allWordTimestamps
        isTranscribing = false
    }
    
    private func getAudioDuration(for url: URL, completion: @escaping (TimeInterval) -> Void) {
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                if status == .loaded {
                    let duration = CMTimeGetSeconds(asset.duration)
                    completion(duration)
                } else {
                    // If we can't get duration, use a default estimate
                    completion(60) // Default 1 minute
                }
            }
        }
    }
    
    private func startTranscription(url: URL) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.errorMessage = "Speech recognizer not available"
            return
        }
        
        isTranscribing = true
        startTime = Date()
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        
        guard let recognitionRequest = recognitionRequest else {
            self.errorMessage = "Unable to create recognition request"
            isTranscribing = false
            return
        }
        
        // Set to false to reduce update frequency
        recognitionRequest.shouldReportPartialResults = false
        
        // Set task hint for dictation to better handle longer audio
        recognitionRequest.taskHint = .dictation
        
        // Start progress tracking with a slower update interval
        startProgressTracking()
        
        // Start the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let now = Date()
                
                // Store the latest segment transcription
                let segmentText = result.bestTranscription.formattedString
                
                // Extract word timestamps
                let segmentWordTimestamps = self.extractWordTimestampsArray(from: result.bestTranscription)
                
                // Only update UI at most once per second to prevent rate limit issues
                if now.timeIntervalSince(self.lastUpdateTime) > 1.0 || result.isFinal {
                    DispatchQueue.main.async {
                        // Update progress based on the transcribed text length if final
                        if result.isFinal {
                            // Save this segment's results
                            self.segmentTexts.append(segmentText)
                            self.segmentWordTimestamps.append(segmentWordTimestamps)
                            
                            // Update segment progress
                            self.segmentProgress[self.currentSegmentIndex] = 1.0
                            self.progress = 1.0
                            
                            // Update overall progress
                            self.updateOverallProgress()
                            
                            // Move to next segment
                            self.stopProgressTracking()
                            self.currentSegmentIndex += 1
                            self.startProcessingNextSegment()
                        }
                    }
                    
                    self.lastUpdateTime = now
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error in segment \(self.currentSegmentIndex + 1): \(error.localizedDescription)"
                    // Still try to move to next segment
                    self.stopProgressTracking()
                    self.currentSegmentIndex += 1
                    self.startProcessingNextSegment()
                }
            }
        }
    }
    
    private func extractWordTimestampsArray(from transcription: SFTranscription) -> [WordTimestamp] {
        var wordTimestamps: [WordTimestamp] = []
        
        for segment in transcription.segments {
            // Split the segment's substring into individual words
            let words = segment.substring.split(separator: " ").map(String.init)
            
            // If there are no words in this segment, skip it
            if words.isEmpty { continue }
            
            if words.count == 1 {
                // If there's only one word, use the segment's timing directly
                let wordTimestamp = WordTimestamp(
                    word: words[0],
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration
                )
                wordTimestamps.append(wordTimestamp)
            } else {
                // For multiple words, distribute the timing proportionally based on word length
                let totalCharacters = words.reduce(0) { $0 + $1.count }
                var startOffset: TimeInterval = 0.0
                
                for word in words {
                    // Calculate the proportion of the segment's duration to allocate to this word
                    // This is based on the word's length relative to the total segment length
                    let wordProportion = Double(word.count) / Double(totalCharacters)
                    let wordDuration = segment.duration * wordProportion
                    
                    // Create a timestamp for this word
                    let wordTimestamp = WordTimestamp(
                        word: word,
                        startTime: segment.timestamp + startOffset,
                        endTime: segment.timestamp + startOffset + wordDuration
                    )
                    wordTimestamps.append(wordTimestamp)
                    
                    // Update the start offset for the next word
                    startOffset += wordDuration
                }
            }
        }
        
        return wordTimestamps
    }
    
    private func extractWordTimestamps(from transcription: SFTranscription) {
        // Only update if allowed by rate limiter (no more than once per second)
        // This prevents the "Message send exceeds rate-limit threshold" error
        if rateLimiter.shouldUpdate(for: "word-timestamps", minInterval: 1.0) {
            // Reuse the logic from extractWordTimestampsArray for consistency
            let updatedTimestamps = extractWordTimestampsArray(from: transcription)
            self.wordTimestamps = updatedTimestamps
        }
    }
    
    func cancelTranscription() {
        isTranscribing = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        progressTimer?.invalidate()
        progressTimer = nil
        errorMessage = "Transcription canceled."
        cleanupTemporaryFiles()
    }
    
    private func updateOverallProgress() {
        // Calculate overall progress based on completed segments
        let completedProgress = segmentProgress.reduce(0.0, +)
        overallProgress = completedProgress / Double(numberOfSegments)
    }
    
    private func startProgressTracking() {
        // Increase timer interval to reduce update frequency
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing, let startTime = self.startTime else { return }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Get current segment duration
            let segmentDuration = self.currentSegmentIndex < self.segmentDurations.count ? 
                self.segmentDurations[self.currentSegmentIndex] : self.audioDuration
            
            // Calculate progress as a ratio of elapsed time to estimated duration
            // We add a 20% processing overhead to account for recognition processing time
            let estimatedTotalTime = segmentDuration * 1.2
            let newProgress = min(elapsedTime / estimatedTotalTime, 0.95) // Cap at 95% until final result
            
            // Calculate estimated remaining time
            let remainingTime = max(0, estimatedTotalTime - elapsedTime)
            
            DispatchQueue.main.async {
                self.progress = newProgress
                self.segmentProgress[self.currentSegmentIndex] = newProgress
                self.updateOverallProgress()
                self.estimatedRemainingTime = remainingTime
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func cleanupTemporaryFiles() {
        guard let temporaryDirectoryURL = temporaryDirectoryURL else { return }
        
        do {
            try FileManager.default.removeItem(at: temporaryDirectoryURL)
            self.temporaryDirectoryURL = nil
        } catch {
            print("Error cleaning up temporary files: \(error)")
        }
    }
    
    private func requestSpeechRecognitionAccess() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    // Ready to transcribe
                    break
                default:
                    self.errorMessage = "Speech recognition authorization not granted"
                }
            }
        }
    }
    
    // Format time interval to string (e.g., "2:30" for 2 minutes and 30 seconds)
    func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Extension for AVFileType to get file extensions
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

// View for audio file transcription
struct AudioFileTranscriberView: View {
    @ObservedObject var viewModel: AudioFileTranscriberViewModel
    var onTranscriptionComplete: (String, [WordTimestamp]) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // File selection button
            Button(action: {
                viewModel.selectAndTranscribeFile()
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                    Text("Select Audio File")
                        .font(.headline)
                }
                .frame(minWidth: 180, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTranscribing || viewModel.isPreparingSegments)
            
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
            }
            
            // Show segments progress
            if viewModel.numberOfSegments > 1 && !viewModel.segmentProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.overallProgress * 100))%")
                    }
                    
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Divider().padding(.vertical, 8)
                    
                    Text("Segments")
                        .font(.headline)
                    
                    ForEach(0..<viewModel.segmentProgress.count, id: \.self) { index in
                        HStack {
                            Text("Segment \(index + 1)")
                                .font(.callout)
                            Spacer()
                            Text("\(Int(viewModel.segmentProgress[index] * 100))%")
                                .font(.callout)
                                .foregroundColor(viewModel.currentSegmentIndex == index ? .blue : .gray)
                        }
                        ProgressView(value: viewModel.segmentProgress[index])
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(viewModel.currentSegmentIndex == index ? .blue : .gray)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            // Current segment progress when transcribing
            else if viewModel.isTranscribing {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Text("Transcribing... \(Int(viewModel.progress * 100))%")
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
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Transcribed text preview (when available and not empty)
            if !viewModel.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Transcription Preview")
                            .font(.headline)
                        Spacer()
                        Button("Save") {
                            onTranscriptionComplete(viewModel.transcribedText, viewModel.wordTimestamps)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    ScrollView {
                        Text(viewModel.transcribedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct AudioFileTranscriberView_Previews: PreviewProvider {
    static var previews: some View {
        AudioFileTranscriberView(
            viewModel: AudioFileTranscriberViewModel(),
            onTranscriptionComplete: { _, _ in }
        )
        .frame(width: 500, height: 400)
        .previewLayout(.sizeThatFits)
    }
}
