import Foundation
import Speech
import Combine

/// Implementation of the TranscriptionService protocol
class AudioTranscriptionService: TranscriptionService, ObservableObject {
    /// The current state of the transcription process
    @Published private(set) var currentState: TranscriptionState = .idle
    
    /// Progress tracking object
    private(set) var progressTracker: ProgressTrackable
    
    /// Audio segmenter for splitting audio files
    private let audioSegmenter: AudioSegmenter
    
    /// Speech recognizer for transcribing audio
    private let speechRecognizer: SpeechRecognizer
    
    /// Transcription combiner for combining segment results
    private let transcriptionCombiner: TranscriptionCombiner
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.speechpoc", category: "AudioTranscriptionService")
    
    /// Collection of segment transcription results
    private var segmentResults: [(text: String, wordTimestamps: [WordTimestamp])] = []
    
    /// Segment durations
    private var segmentDurations: [TimeInterval] = []
    
    /// Current segment being processed
    private var currentSegmentIndex: Int = 0
    
    /// Total number of segments
    private var totalSegments: Int = 1
    
    /// Cancellables for Combine publishers
    private var cancellables = Set<AnyCancellable>()
    
    /// Initializes a new transcription service with its dependencies
    /// - Parameters:
    ///   - progressTracker: Object for tracking progress
    ///   - audioSegmenter: Service for segmenting audio files
    ///   - speechRecognizer: Service for speech recognition
    ///   - transcriptionCombiner: Service for combining transcription results
    init(
        progressTracker: ProgressTrackable,
        audioSegmenter: AudioSegmenter,
        speechRecognizer: SpeechRecognizer,
        transcriptionCombiner: TranscriptionCombiner
    ) {
        self.progressTracker = progressTracker
        self.audioSegmenter = audioSegmenter
        self.speechRecognizer = speechRecognizer
        self.transcriptionCombiner = transcriptionCombiner
        
        logger.debug("AudioTranscriptionService initialized")
    }
    
    /// Convenience initializer with default implementations
    convenience init() {
        self.init(
            progressTracker: ProgressManager(segments: 1),
            audioSegmenter: AVAudioSegmenter(),
            speechRecognizer: AppleSpeechRecognizer(),
            transcriptionCombiner: TranscriptionCombinerImpl()
        )
    }
    
    /// Transcribe an audio file at the given URL
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe
    ///   - segmentCount: The number of segments to split the audio into (default: 1)
    ///   - onProgress: Callback for progress updates
    ///   - onPartialResult: Callback for partial results
    ///   - onCompletion: Callback for when transcription is complete
    ///   - onError: Callback for errors
    func transcribeAudioFile(
        url: URL,
        segmentCount: Int = 1,
        onProgress: @escaping (Double) -> Void,
        onPartialResult: @escaping (TranscriptionResult) -> Void,
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        // Ensure we're not already processing
        guard case .idle = currentState else {
            onError(.transcriptionFailed("Transcription already in progress"))
            return
        }
        
        // Reset state
        segmentResults = []
        segmentDurations = []
        currentSegmentIndex = 0
        totalSegments = max(1, segmentCount)
        
        // Reset progress tracker
        progressTracker.reset(segments: totalSegments)
        
        // Start segmentation if needed
        if segmentCount > 1 {
            logger.debug("Starting transcription of file \(url.lastPathComponent) with \(segmentCount) segments")
            
            // Update state
            currentState = .preparingSegments
            
            // Split the file into segments
            audioSegmenter.splitAudioFile(
                url: url,
                segmentCount: segmentCount,
                onProgress: { [weak self] progress in
                    // Update segmentation progress
                    DispatchQueue.main.async {
                        onProgress(progress * 0.2) // Segmentation is 20% of total progress
                    }
                },
                onCompletion: { [weak self] segments in
                    guard let self = self else { return }
                    
                    // Store segment durations
                    self.segmentDurations = segments.map { $0.duration }
                    
                    // Update progress tracker with segment durations
                    self.progressTracker.setSegmentDurations(self.segmentDurations)
                    
                    // Start transcribing segments
                    self.processSegments(
                        segments: segments,
                        onProgress: onProgress,
                        onPartialResult: onPartialResult,
                        onCompletion: onCompletion,
                        onError: onError
                    )
                },
                onError: { [weak self] error in
                    guard let self = self else { return }
                    
                    self.currentState = .error(error)
                    onError(error)
                    
                    // Clean up
                    self.audioSegmenter.cleanup()
                }
            )
        } else {
            // No segmentation needed, treat the file as a single segment
            let segment = AudioSegment(
                url: url,
                duration: 0, // We don't know duration yet but it doesn't matter
                index: 0,
                totalSegments: 1
            )
            
            logger.debug("Starting transcription of file \(url.lastPathComponent) as a single segment")
            
            // Start transcribing immediately
            processSegments(
                segments: [segment],
                onProgress: onProgress,
                onPartialResult: onPartialResult,
                onCompletion: onCompletion,
                onError: onError
            )
        }
    }
    
    /// Cancel the current transcription
    func cancelTranscription() {
        logger.debug("Cancelling transcription")
        
        // Cancel speech recognition
        speechRecognizer.cancelTranscription()
        
        // Clean up audio segmenter
        audioSegmenter.cleanup()
        
        // Reset state
        currentState = .idle
    }
    
    /// Request authorization for speech recognition
    /// - Parameter completion: Callback with authorization result
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        speechRecognizer.requestAuthorization(completion: completion)
    }
    
    // MARK: - Private Methods
    
    /// Process a sequence of audio segments
    private func processSegments(
        segments: [AudioSegment],
        onProgress: @escaping (Double) -> Void,
        onPartialResult: @escaping (TranscriptionResult) -> Void,
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        guard !segments.isEmpty else {
            onError(.transcriptionFailed("No segments to process"))
            currentState = .idle
            return
        }
        
        // Set up for processing
        totalSegments = segments.count
        segmentResults = Array(repeating: ("", []), count: totalSegments)
        currentSegmentIndex = 0
        
        // Start processing the first segment
        processNextSegment(
            segments: segments,
            onProgress: onProgress,
            onPartialResult: onPartialResult,
            onCompletion: onCompletion,
            onError: onError
        )
    }
    
    /// Process the next segment in the queue
    private func processNextSegment(
        segments: [AudioSegment],
        onProgress: @escaping (Double) -> Void,
        onPartialResult: @escaping (TranscriptionResult) -> Void,
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        // Check if we've processed all segments
        guard currentSegmentIndex < segments.count else {
            // Combine results from all segments
            combineAndFinish(
                onCompletion: onCompletion,
                onError: onError
            )
            return
        }
        
        // Get the current segment
        let segment = segments[currentSegmentIndex]
        
        // Update state
        currentState = .transcribing(segmentIndex: currentSegmentIndex, totalSegments: totalSegments)
        
        // Update progress tracker
        progressTracker.setSegmentState(currentSegmentIndex, state: .inProgress)
        
        logger.debug("Starting transcription of segment \(currentSegmentIndex + 1)/\(totalSegments)")
        
        // Transcribe the segment
        speechRecognizer.transcribeSegment(
            segment: segment,
            onProgress: { [weak self] progress in
                guard let self = self else { return }
                
                // Update progress for this segment
                self.progressTracker.updateSegment(self.currentSegmentIndex, progress: progress)
                
                // Forward progress to caller
                onProgress(self.progressTracker.overallProgress)
            },
            onPartialResult: { [weak self] text, timestamps in
                guard let self = self else { return }
                
                // Create a partial result
                let result = TranscriptionResult(
                    text: text,
                    wordTimestamps: timestamps,
                    segmentIndex: self.currentSegmentIndex,
                    isComplete: false
                )
                
                // Forward partial result to caller
                onPartialResult(result)
            },
            onCompletion: { [weak self] text, timestamps in
                guard let self = self else { return }
                
                // Store the result for this segment
                self.segmentResults[self.currentSegmentIndex] = (text, timestamps)
                
                // Mark segment as completed
                self.progressTracker.setSegmentState(self.currentSegmentIndex, state: .completed)
                
                // Create a completion result for this segment
                let result = TranscriptionResult(
                    text: text,
                    wordTimestamps: timestamps,
                    segmentIndex: self.currentSegmentIndex,
                    isComplete: true
                )
                
                // Forward result to caller
                onPartialResult(result)
                
                // Move to next segment
                self.currentSegmentIndex += 1
                
                // Process next segment with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.processNextSegment(
                        segments: segments,
                        onProgress: onProgress,
                        onPartialResult: onPartialResult,
                        onCompletion: onCompletion,
                        onError: onError
                    )
                }
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                
                // Mark segment as error
                self.progressTracker.setSegmentState(self.currentSegmentIndex, state: .error)
                
                // Log error
                self.logger.error("Error transcribing segment \(self.currentSegmentIndex + 1): \(error.localizedDescription)")
                
                // Try to continue with next segment
                self.currentSegmentIndex += 1
                
                // Process next segment
                self.processNextSegment(
                    segments: segments,
                    onProgress: onProgress,
                    onPartialResult: onPartialResult,
                    onCompletion: onCompletion,
                    onError: onError
                )
            }
        )
    }
    
    /// Combine results from all segments and finish transcription
    private func combineAndFinish(
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    ) {
        // Update state
        currentState = .combining
        
        logger.debug("Combining results from \(segmentResults.count) segments")
        
        // Combine transcriptions
        let (combinedText, combinedTimestamps) = transcriptionCombiner.combineTranscriptions(
            segmentResults: segmentResults,
            segmentDurations: segmentDurations
        )
        
        // Mark all segments as completed
        progressTracker.completeAll()
        
        // Clean up
        audioSegmenter.cleanup()
        
        // Update state
        currentState = .completed
        
        logger.debug("Transcription completed with \(combinedText.count) chars and \(combinedTimestamps.count) timestamps")
        
        // Call completion
        onCompletion(combinedText, combinedTimestamps)
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
        print("🎙 [\(category)] \(message)")
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