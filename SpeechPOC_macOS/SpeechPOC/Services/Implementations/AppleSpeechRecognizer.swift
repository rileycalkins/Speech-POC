import Foundation
import Speech
import AVFoundation
import Combine

/// Implementation of the SpeechRecognizer protocol using Apple's Speech framework
class AppleSpeechRecognizer: SpeechRecognizer {
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.speechpoc", category: "AppleSpeechRecognizer")
    
    /// The speech recognizer instance
    private let speechRecognizer: SFSpeechRecognizer
    
    /// The current recognition request
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    
    /// The current recognition task
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// The start time of the current recognition task
    private var startTime: Date?
    
    /// Rate limiter for UI updates
    private let rateLimiter = RateLimiter()
    
    /// Initialize with a specific locale
    /// - Parameter locale: The locale to use for recognition
    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()!
        logger.debug("Initialized speech recognizer with locale: \(locale.identifier)")
    }
    
    /// Transcribe a single audio segment
    /// - Parameters:
    ///   - segment: The audio segment to transcribe
    ///   - onProgress: Callback for transcription progress
    ///   - onPartialResult: Callback for partial results
    ///   - onCompletion: Callback with the transcription result
    ///   - onError: Callback for errors
    func transcribeSegment(
        segment: AudioSegment,
        onProgress: @escaping (Double) -> Void,
        onPartialResult: @escaping (String, [WordTimestamp]) -> Void,
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        guard speechRecognizer.isAvailable else {
            logger.error("Speech recognizer is not available")
            onError(.recognizerNotAvailable("Speech recognizer is not available"))
            return
        }
        
        startTime = Date()
        logger.debug("Starting transcription of segment \(segment.index + 1)/\(segment.totalSegments)")
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechURLRecognitionRequest(url: segment.url)
        
        guard let recognitionRequest = recognitionRequest else {
            logger.error("Unable to create recognition request")
            onError(.requestCreationFailed("Unable to create recognition request"))
            return
        }
        
        // Configure the request - set to false to reduce update frequency
        recognitionRequest.shouldReportPartialResults = true
        
        // Set task hint for dictation to better handle longer audio
        recognitionRequest.taskHint = .dictation
        
        // Start progress tracking
        let segmentDuration = segment.duration
        startProgressTracking(segmentDuration: segmentDuration, onProgress: onProgress)
        
        // Start the recognition task
        var lastUpdateTime = Date()
        var lastText = ""
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let now = Date()
                
                // Get the transcription text
                let transcriptionText = result.bestTranscription.formattedString
                
                // Extract word timestamps
                let wordTimestamps = self.extractWordTimestamps(from: result.bestTranscription)
                
                // Update UI at a reasonable rate
                // Only update UI every second or when we have a final result
                if result.isFinal || now.timeIntervalSince(lastUpdateTime) > 1.0 || transcriptionText != lastText {
                    DispatchQueue.main.async {
                        // For final results, update with full completion
                        if result.isFinal {
                            self.logger.debug("Final transcription for segment \(segment.index + 1): \(wordTimestamps.count) words")
                            onCompletion(transcriptionText, wordTimestamps)
                        } else {
                            // Update with partial results if text has changed
                            if transcriptionText != lastText {
                                onPartialResult(transcriptionText, wordTimestamps)
                                lastText = transcriptionText
                                
                                // Update progress based on text length for more responsive UI
                                let textBasedProgress = min(0.7, Double(transcriptionText.count) / 500.0)
                                onProgress(textBasedProgress)
                            }
                        }
                    }
                    
                    lastUpdateTime = now
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.logger.error("Transcription error: \(error.localizedDescription)")
                    onError(.transcriptionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Cancel the current transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        logger.debug("Transcription cancelled")
    }
    
    /// Request authorization for speech recognition
    /// - Parameter completion: Callback with authorization result
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            var authorized = false
            
            switch status {
            case .authorized:
                self.logger.debug("Speech recognition authorization granted")
                authorized = true
            case .denied:
                self.logger.error("Speech recognition authorization denied")
            case .restricted:
                self.logger.error("Speech recognition is restricted")
            case .notDetermined:
                self.logger.error("Speech recognition authorization not determined")
            @unknown default:
                self.logger.error("Unknown authorization status")
            }
            
            DispatchQueue.main.async {
                completion(authorized)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Extract word timestamps from an SFTranscription
    private func extractWordTimestamps(from transcription: SFTranscription) -> [WordTimestamp] {
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
    
    /// Start tracking progress for the current transcription
    private func startProgressTracking(segmentDuration: TimeInterval, onProgress: @escaping (Double) -> Void) {
        // Use a Timer to update progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, let startTime = self.startTime else {
                timer.invalidate()
                return
            }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Calculate progress using non-linear approach for better UX
            let progress = self.calculateNonLinearProgress(
                elapsedTime: elapsedTime,
                segmentDuration: segmentDuration
            )
            
            // Report progress
            onProgress(progress)
            
            // If recognition task is completed or cancelled, stop the timer
            if self.recognitionTask == nil {
                timer.invalidate()
            }
        }
        
        // Add the timer to the current run loop
        RunLoop.current.add(timer, forMode: .common)
    }
    
    /// Calculate a non-linear progress value that feels more responsive
    private func calculateNonLinearProgress(elapsedTime: TimeInterval, segmentDuration: TimeInterval) -> Double {
        // Determine appropriate progress rate based on segment duration
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
        let normalizedTime = min(elapsedTime * progressRate, 10.0) // Cap at 10 (reaches ~95%)
        let newProgress = 1.0 - (1.0 / (1.0 + normalizedTime)) // Approaches 1.0 asymptotically
        
        // Ensure progress is between 0 and 0.95 (save the last 5% for final processing)
        return min(max(newProgress, 0.0), 0.95)
    }
}

/// Simple rate limiter for throttling updates
class RateLimiter {
    private var lastUpdateTimes: [String: Date] = [:]
    
    /// Determines if an update should be allowed based on the minimum interval
    func shouldUpdate(for key: String, minInterval: TimeInterval) -> Bool {
        let now = Date()
        
        if let lastUpdate = lastUpdateTimes[key] {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < minInterval {
                return false
            }
        }
        
        lastUpdateTimes[key] = now
        return true
    }
    
    /// Reset the timer for a specific key
    func reset(for key: String) {
        lastUpdateTimes.removeValue(forKey: key)
    }
    
    /// Reset all timers
    func resetAll() {
        lastUpdateTimes.removeAll()
    }
}

/// Simple logger for debugging
fileprivate class Logger {
    let subsystem: String
    let category: String
    
    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
    
    func debug(_ message: String) {
        #if DEBUG
        print("🔍 [\(category)] \(message)")
        #endif
    }
    
    func info(_ message: String) {
        #if DEBUG
        print("ℹ️ [\(category)] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("⚠️ [\(category)] \(message)")
        #endif
    }
} 