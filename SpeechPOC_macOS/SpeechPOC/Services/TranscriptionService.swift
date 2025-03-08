import Foundation
import Speech
import AVFoundation

/// Represents information about an audio segment
struct AudioSegment {
    let url: URL
    let duration: TimeInterval
    let index: Int
    let totalSegments: Int
    
    var isLastSegment: Bool {
        return index == totalSegments - 1
    }
}

/// Result of a transcription operation
struct TranscriptionResult {
    let text: String
    let wordTimestamps: [WordTimestamp]
    let segmentIndex: Int
    let isComplete: Bool
}

/// Represents errors that can occur during transcription
enum TranscriptionError: Error {
    case fileAccessError(String)
    case recognizerNotAvailable(String)
    case requestCreationFailed(String)
    case transcriptionFailed(String)
    case segmentationFailed(String)
    case authorizationDenied
    
    var localizedDescription: String {
        switch self {
        case .fileAccessError(let message):
            return "File access error: \(message)"
        case .recognizerNotAvailable(let message):
            return "Speech recognizer not available: \(message)"
        case .requestCreationFailed(let message):
            return "Failed to create recognition request: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .segmentationFailed(let message):
            return "Failed to segment audio: \(message)"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        }
    }
}

/// Protocol defining progress tracking capabilities
protocol ProgressTrackable: AnyObject {
    var segmentProgress: [Double] { get }
    var overallProgress: Double { get }
    var segmentStates: [SegmentState] { get }
    
    func updateSegment(_ index: Int, progress: Double)
    func setSegmentState(_ index: Int, state: SegmentState)
    func reset(segments: Int)
    func completeAll()
}

/// Protocol for services that handle audio file transcription
protocol TranscriptionService {
    /// Progress tracking object
    var progressTracker: ProgressTrackable { get }
    
    /// Current state of the transcription
    var currentState: TranscriptionState { get }
    
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
        segmentCount: Int,
        onProgress: @escaping (Double) -> Void,
        onPartialResult: @escaping (TranscriptionResult) -> Void,
        onCompletion: @escaping (String, [WordTimestamp]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    )
    
    /// Cancel the current transcription
    func cancelTranscription()
    
    /// Request authorization for speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void)
}

/// The possible states of the transcription process
enum TranscriptionState {
    case idle
    case preparingSegments
    case transcribing(segmentIndex: Int, totalSegments: Int)
    case combining
    case completed
    case error(TranscriptionError)
}

/// Protocol for services that handle audio segmentation
protocol AudioSegmenter {
    /// Split an audio file into multiple segments
    /// - Parameters:
    ///   - url: The URL of the audio file to split
    ///   - segmentCount: The number of segments to create
    ///   - onProgress: Callback for segmentation progress
    ///   - onCompletion: Callback with array of segment URLs and durations
    ///   - onError: Callback for errors
    func splitAudioFile(
        url: URL,
        segmentCount: Int,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping ([AudioSegment]) -> Void,
        onError: @escaping (TranscriptionError) -> Void
    )
    
    /// Clean up temporary files created during segmentation
    func cleanup()
}

/// Protocol for services that handle speech recognition
protocol SpeechRecognizer {
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
    )
    
    /// Cancel the current transcription
    func cancelTranscription()
    
    /// Request authorization for speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void)
}

/// Protocol for services that combine transcription results
protocol TranscriptionCombiner {
    /// Combine multiple segment transcriptions into a single result
    /// - Parameters:
    ///   - segmentResults: Array of segment transcription results
    ///   - segmentDurations: Array of segment durations
    /// - Returns: Combined transcription text and word timestamps
    func combineTranscriptions(
        segmentResults: [(text: String, wordTimestamps: [WordTimestamp])],
        segmentDurations: [TimeInterval]
    ) -> (text: String, wordTimestamps: [WordTimestamp])
} 