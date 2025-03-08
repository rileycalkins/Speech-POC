//
//  AudioFileTranscriberViewModel.swift
//  SpeechPOC_macOS
//
//  Created by Riley Calkins on 3/6/25.
//
import SwiftUI
import AVFoundation
import Speech
import Combine
import Foundation

// Direct references to required models to fix linter errors
// This is needed because importing from the same module
// doesn't always work with Swift module structure
// WordTimestamp should be defined in Model/WordTimestamp.swift
// RateLimiter should be defined in Utilities/RateLimiter.swift
// ProgressManager should be defined in Utilities/ProgressManager.swift

// If types are still not found after this, we need to ensure all files
// are included in the same target/module in Xcode project settings

class AudioFileTranscriberViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    
    @Published var estimatedRemainingTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var wordTimestamps: [WordTimestamp] = []
    
    // New properties for file splitting
    @Published var numberOfSegments: Int = 1
    @Published var currentSegmentIndex: Int = 0
    @Published var isPreparingSegments: Bool = false
    
    // Progress manager for tracking progress
    private let _progressManager = ProgressManager(segments: 1)
    // Expose progress manager as read-only for the view to access segment states
    var progressManager: ProgressManager { _progressManager }
    // Expose progress properties from the manager
    var segmentProgress: [Double] { _progressManager.segmentProgress }
    var overallProgress: Double { _progressManager.overallProgress }
    
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
    
    func showSegmentSelectionDialog(url: URL) {
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
                        // Initialize progress manager with the number of segments
                        self._progressManager.reset(segments: segments)
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
                    // Initialize progress manager with the number of segments
                    self._progressManager.reset(segments: segments)
                    self.processAudioFile(url: url)
                } else {
                    self.errorMessage = "Please enter a valid number of segments"
                }
            }
        }
    }
    
    private func processAudioFile(url: URL) {
        guard !isTranscribing else { return }
        
        logDebug("Starting to process audio file: \(url.lastPathComponent)")
        
        // Reset previous state
        self.transcribedText = ""
        
        self.errorMessage = nil
        self.wordTimestamps = []
        self.currentSegmentIndex = 0
        
        // Reset segment-related properties
        self.segmentURLs = []
        self.segmentDurations = []
        self.segmentTexts = []
        self.segmentWordTimestamps = []
        
        // Reset progress manager
        self._progressManager.reset(segments: self.numberOfSegments)
        
        // Clean up previous temporary files
        self.cleanupTemporaryFiles()
        
        // Get audio file duration for progress calculation
        getAudioDuration(for: url) { [weak self] duration in
            guard let self = self else { return }
            
            self.audioDuration = duration
            self.logDebug("Audio duration: \(self.formatTimeRemaining(duration))")
            
            if self.numberOfSegments > 1 {
                self.logDebug("Splitting audio into \(self.numberOfSegments) segments")
                self.isPreparingSegments = true
                self.splitAudioFile(url: url)
            } else {
                self.logDebug("Processing single audio file (no splitting)")
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
            logDebug("Created temporary directory: \(temporaryDirectory.lastPathComponent)")
        } catch {
            self.errorMessage = "Failed to create temporary directory: \(error.localizedDescription)"
            self.isPreparingSegments = false
            logDebug("Error creating temporary directory: \(error.localizedDescription)")
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
                    self.logDebug("Error loading audio asset: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let duration = CMTimeGetSeconds(asset.duration)
                let segmentDuration = duration / Double(self.numberOfSegments)
                self.logDebug("Total duration: \(self.formatTimeRemaining(duration)), segment duration: \(self.formatTimeRemaining(segmentDuration))")
                
                // Pre-calculate all segment durations for progress manager
                var segmentDurations: [TimeInterval] = []
                for i in 0..<self.numberOfSegments {
                    let startTime = Double(i) * segmentDuration
                    let endTime = min(startTime + segmentDuration, duration)
                    segmentDurations.append(endTime - startTime)
                }
                
                // Set segment durations in progress manager
                self._progressManager.setSegmentDurations(segmentDurations)
                self.logDebug("Set segment durations in progress manager")
                
                // Create a counter to track completed export operations
                var completedExports = 0
                
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
                    
                    self.logDebug("Creating segment \(i+1): \(segmentFileName), duration: \(self.formatTimeRemaining(endTime - startTime))")
                    
                    // Setup export session
                    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                        self.errorMessage = "Failed to create export session for segment \(i+1)"
                        self.isPreparingSegments = false
                        self.logDebug("Failed to create export session for segment \(i+1)")
                        return
                    }
                    
                    exportSession.outputURL = segmentURL
                    exportSession.outputFileType = fileType
                    exportSession.timeRange = timeRange
                    
                    self.segmentURLs.append(segmentURL)
                    self.segmentDurations.append(endTime - startTime)
                    
                    exportSession.exportAsynchronously {
                        DispatchQueue.main.async {
                            completedExports += 1
                            
                            if exportSession.status == .completed {
                                self.logDebug("Completed export of segment \(i+1)/\(self.numberOfSegments)")
                                
                                // Check if all segments are processed
                                if completedExports == self.numberOfSegments {
                                    self.logDebug("All \(self.numberOfSegments) segments have been exported")
                                    self.isPreparingSegments = false
                                    self.startProcessingNextSegment()
                                }
                            } else if exportSession.status == .failed {
                                let errorMsg = "Failed to export segment \(i+1): \(exportSession.error?.localizedDescription ?? "Unknown error")"
                                self.errorMessage = errorMsg
                                self.isPreparingSegments = false
                                self.logDebug(errorMsg)
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
            logDebug("All segments processed, finalizing transcription")
            finishTranscription()
            return
        }
        
        // Reset progress for the current segment before starting
        _progressManager.updateSegment(currentSegmentIndex, progress: 0.0)
        
        // Update segment state
        _progressManager.setSegmentState(currentSegmentIndex, state: .inProgress)
        
        logDebug("Starting transcription of segment \(currentSegmentIndex + 1)/\(segmentURLs.count)")
        
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
        
        // Mark all segments as completed
        logDebug("Marking all segments as completed")
        
        // Set all segments to completed in progress manager with a slight delay
        // This ensures that users can see the progress bar complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Use the new completeAll method to mark all segments as completed
            self._progressManager.completeAll()
            self.isTranscribing = false
        }
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
            let errorMsg = "Speech recognizer not available"
            self.errorMessage = errorMsg
            self.logDebug(errorMsg)
            
            // Mark segment as failed
            _progressManager.setSegmentState(currentSegmentIndex, state: .error)
            return
        }
        
        isTranscribing = true
        startTime = Date()
        
        logDebug("Creating recognition request for \(url.lastPathComponent)")
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        
        guard let recognitionRequest = recognitionRequest else {
            let errorMsg = "Unable to create recognition request"
            self.errorMessage = errorMsg
            self.logDebug(errorMsg)
            isTranscribing = false
            
            // Mark segment as failed
            _progressManager.setSegmentState(currentSegmentIndex, state: .error)
            return
        }
        
        // Set to false to reduce update frequency
        recognitionRequest.shouldReportPartialResults = false
        
        // Set task hint for dictation to better handle longer audio
        recognitionRequest.taskHint = .dictation
        
        // Start progress tracking with a slower update interval
        startProgressTracking()
        
        logDebug("Starting recognition task for segment \(currentSegmentIndex + 1)")
        
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
                            self.logDebug("Completed transcription of segment \(self.currentSegmentIndex + 1), found \(segmentWordTimestamps.count) words")
                            // Set progress to 100% for this segment
                            self._progressManager.updateSegment(self.currentSegmentIndex, progress: 1.0)
                            
                            // Mark segment as completed
                            self._progressManager.setSegmentState(self.currentSegmentIndex, state: .completed)
                            
                            // Save this segment's results
                            self.segmentTexts.append(segmentText)
                            self.segmentWordTimestamps.append(segmentWordTimestamps)
                            
                            // Move to next segment with a slight delay to show completion
                            self.stopProgressTracking()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.currentSegmentIndex += 1
                                self.startProcessingNextSegment()
                            }
                        } else if !segmentText.isEmpty {
                            // Update progress based on partial results too
                            // This helps show progress even for fast transcriptions
                            let partialProgress = min(0.7, Double(segmentText.count) / 500.0)
                            let currentProgress = self.segmentProgress[self.currentSegmentIndex]
                            if partialProgress > currentProgress {
                                self._progressManager.updateSegment(self.currentSegmentIndex, progress: partialProgress)
                                self.logDebug("Partial progress update: \(Int(partialProgress * 100))% (text length: \(segmentText.count))")
                            }
                        }
                    }
                    
                    self.lastUpdateTime = now
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    let errorMsg = "Error in segment \(self.currentSegmentIndex + 1): \(error.localizedDescription)"
                    self.errorMessage = errorMsg
                    self.logDebug(errorMsg)
                    
                    // Mark segment as failed
                    self._progressManager.setSegmentState(self.currentSegmentIndex, state: .error)
                    
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
        
        // Mark current segment as failed
        if currentSegmentIndex < segmentURLs.count {
            _progressManager.setSegmentState(currentSegmentIndex, state: .error)
        }
        
        cleanupTemporaryFiles()
    }
    
    private func startProgressTracking() {
        // Cancel any existing timer
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Increase timer interval to reduce update frequency
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing, let startTime = self.startTime else { return }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Get current segment duration
            let segmentDuration = self.currentSegmentIndex < self.segmentDurations.count ? 
                self.segmentDurations[self.currentSegmentIndex] : self.audioDuration
            
            // Important: Speech recognition can be much faster than real-time
            // So we need to adjust our progress calculation to account for this
            
            // Use a more sophisticated progress calculation:
            // 1. For smaller files (< 1 minute), use a faster progress rate
            // 2. For medium files (1-5 minutes), use a moderate rate
            // 3. For larger files (> 5 minutes), use a more conservative rate
            
            let progressRate: Double
            if segmentDuration < 60 {
                // For short audio (< 1 min), progress moves quickly
                progressRate = 0.5 // Complete 50% in ~6 seconds
            } else if segmentDuration < 300 {
                // For medium audio (1-5 min), progress moves at moderate pace
                progressRate = 0.3 // Complete 50% in ~10 seconds
            } else {
                // For longer audio (> 5 min), progress moves more slowly
                progressRate = 0.2 // Complete 50% in ~15 seconds
            }
            
            // Calculate non-linear progress that starts quickly and slows down
            // This gives a more responsive feel while still showing meaningful progress
            let normalizedTime = min(elapsedTime * progressRate, 10.0) // Cap at 10 (reaches ~95%)
            let newProgress = 1.0 - (1.0 / (1.0 + normalizedTime)) // Approaches 1.0 asymptotically
            
            // Ensure progress is between 0 and 0.95 (save the last 5% for final processing)
            let boundedProgress = min(max(newProgress, 0.0), 0.95)
            
            // Calculate estimated remaining time (optimistic estimate based on non-linear progress)
            let progressRemaining = 0.95 - boundedProgress
            let progressPerSecond = boundedProgress / elapsedTime
            let remainingTime = progressPerSecond > 0 ? progressRemaining / progressPerSecond : 0
            
            DispatchQueue.main.async {
                // Update the progress for the current segment using progress manager
                self._progressManager.updateSegment(self.currentSegmentIndex, progress: boundedProgress)
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
    
    // Add a debug logger property
    private func logDebug(_ message: String) {
        #if DEBUG
        print("🔊 AudioTranscriber: \(message)")
        #endif
    }
}
