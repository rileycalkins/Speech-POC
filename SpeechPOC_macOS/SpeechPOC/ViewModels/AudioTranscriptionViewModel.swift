import Foundation
import SwiftUI
import Combine

/// ViewModel for handling audio transcription in the UI
class AudioTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The transcribed text
    @Published var transcribedText: String = ""
    
    /// Word timestamps for the transcription
    @Published var wordTimestamps: [WordTimestamp] = []
    
    /// Current processing state
    @Published var state: TranscriptionViewState = .idle
    
    /// Error message if transcription fails
    @Published var errorMessage: String? = nil
    
    /// Segment progress data (0.0 to 1.0 for each segment)
    @Published var segmentProgress: [Double] = []
    
    /// Overall progress (0.0 to 1.0)
    @Published var overallProgress: Double = 0.0
    
    /// Current segment being processed
    @Published var currentSegmentIndex: Int = 0
    
    /// Total number of segments
    @Published var numberOfSegments: Int = 1
    
    /// Whether segments are being prepared (splitting audio)
    @Published var isPreparingSegments: Bool = false
    
    /// Estimated time remaining in seconds
    @Published var estimatedRemainingTime: TimeInterval = 0
    
    /// History of segment results
    @Published var segmentResults: [TranscriptionResult] = []
    
    // MARK: - Private Properties
    
    /// The transcription service
    private let transcriptionService: TranscriptionService
    
    /// Time when transcription started
    private var startTime: Date?
    
    /// Timer for updating estimated time remaining
    private var timeEstimationTimer: Timer?
    
    /// Cancellables for combine publishers
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with a transcription service
    /// - Parameter transcriptionService: The service to use for transcription
    init(transcriptionService: TranscriptionService) {
        self.transcriptionService = transcriptionService
        
        // Listen for progress updates from the service
        if let service = transcriptionService as? AudioTranscriptionService {
            service.$currentState
                .sink { [weak self] state in
                    self?.handleStateChange(state)
                }
                .store(in: &cancellables)
        }
        
        // Start timer for time estimation
        startTimeEstimationTimer()
    }
    
    /// Convenience initializer with default service
    convenience init() {
        self.init(transcriptionService: AudioTranscriptionService())
    }
    
    // MARK: - Public Methods
    
    /// Start transcription of an audio file
    /// - Parameters:
    ///   - url: URL of the audio file
    ///   - segmentCount: Number of segments to split into
    func transcribeAudioFile(url: URL, segmentCount: Int = 1) {
        // Reset state
        transcribedText = ""
        wordTimestamps = []
        errorMessage = nil
        segmentResults = []
        overallProgress = 0.0
        currentSegmentIndex = 0
        numberOfSegments = segmentCount
        segmentProgress = Array(repeating: 0.0, count: segmentCount)
        startTime = Date()
        
        // Start transcription
        state = .transcribing
        
        transcriptionService.transcribeAudioFile(
            url: url,
            segmentCount: segmentCount,
            onProgress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.overallProgress = progress
                }
            },
            onPartialResult: { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleTranscriptionResult(result)
                }
            },
            onCompletion: { [weak self] text, timestamps in
                DispatchQueue.main.async {
                    self?.transcribedText = text
                    self?.wordTimestamps = timestamps
                    self?.state = .completed
                    self?.overallProgress = 1.0
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.state = .error
                }
            }
        )
    }
    
    /// Cancel the current transcription
    func cancelTranscription() {
        transcriptionService.cancelTranscription()
        state = .idle
        errorMessage = "Transcription canceled."
    }
    
    /// Request authorization for speech recognition
    /// - Parameter completion: Callback with result
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        transcriptionService.requestAuthorization(completion: completion)
    }
    
    /// Format a time interval as a string (e.g. "2:30")
    /// - Parameter timeInterval: The time interval in seconds
    /// - Returns: Formatted time string
    func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Methods
    
    /// Handle a state change from the service
    private func handleStateChange(_ state: TranscriptionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .idle:
                self.state = .idle
                
            case .preparingSegments:
                self.state = .transcribing
                self.isPreparingSegments = true
                
            case .transcribing(let segmentIndex, let totalSegments):
                self.state = .transcribing
                self.isPreparingSegments = false
                self.currentSegmentIndex = segmentIndex
                self.numberOfSegments = totalSegments
                
                // Ensure we have enough elements in segmentProgress
                while self.segmentProgress.count < totalSegments {
                    self.segmentProgress.append(0.0)
                }
                
            case .combining:
                self.state = .transcribing
                
            case .completed:
                self.state = .completed
                
            case .error(let error):
                self.state = .error
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Handle a transcription result from the service
    private func handleTranscriptionResult(_ result: TranscriptionResult) {
        // Update segment progress
        if currentSegmentIndex < segmentProgress.count {
            // Calculate progress based on text length if no progress is reported
            let textBasedProgress = min(0.8, Double(result.text.count) / 500.0)
            segmentProgress[result.segmentIndex] = max(segmentProgress[result.segmentIndex], textBasedProgress)
        }
        
        // Store result
        if let existingIndex = segmentResults.firstIndex(where: { $0.segmentIndex == result.segmentIndex }) {
            segmentResults[existingIndex] = result
        } else {
            segmentResults.append(result)
        }
        
        // If this is the current segment, update the preview text
        if result.segmentIndex == currentSegmentIndex {
            transcribedText = result.text
            wordTimestamps = result.wordTimestamps
        }
    }
    
    /// Start a timer for estimating time remaining
    private func startTimeEstimationTimer() {
        timeEstimationTimer?.invalidate()
        
        timeEstimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, 
                  self.state == .transcribing,
                  let startTime = self.startTime else { return }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            if self.overallProgress > 0.05 {
                // Only start estimating after we have some progress
                let estimatedTotalTime = elapsedTime / self.overallProgress
                let remainingTime = max(0, estimatedTotalTime - elapsedTime)
                
                DispatchQueue.main.async {
                    self.estimatedRemainingTime = remainingTime
                }
            }
        }
    }
    
    deinit {
        timeEstimationTimer?.invalidate()
    }
}

/// States for the transcription view
enum TranscriptionViewState: Equatable {
    /// Not transcribing
    case idle
    /// Transcription in progress
    case transcribing
    /// Transcription completed
    case completed
    /// Error occurred
    case error
} 