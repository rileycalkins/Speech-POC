import Foundation
import SwiftUI
import Combine

/// ViewModel for handling audio file transcription in the UI
class AudioFileTranscriberViewModel: ObservableObject {
    // Properties for managing the audio file transcription process
    @Published var transcribedText: String = ""
    @Published var wordTimestamps: [WordTimestamp] = []
    @Published var isTranscribing: Bool = false
    @Published var errorMessage: String? = nil
    
    // Progress tracking properties
    @Published var overallProgress: Double = 0.0
    @Published var segmentProgress: [Double] = []
    @Published var currentSegmentIndex: Int = 0
    @Published var numberOfSegments: Int = 1
    @Published var isPreparingSegments: Bool = false
    @Published var estimatedRemainingTime: TimeInterval = 0
    
    // Access to the progress manager for segment state information
    var progressManager: ProgressManager {
        return _progressManager
    }
    
    // Private implementation
    private var _progressManager = ProgressManager(segments: 1)
    
    // Method to get the formatted segment duration for a given index
    func getFormattedSegmentDuration(index: Int) -> String {
        // If we have segment durations and the index is valid
        if index < segmentDurations.count {
            return formatDuration(segmentDurations[index])
        }
        
        // Otherwise estimate based on audio duration and number of segments
        if audioDuration > 0 && numberOfSegments > 0 {
            let estimatedDuration = audioDuration / Double(numberOfSegments)
            return formatDuration(estimatedDuration)
        }
        
        // Default value
        return "(00:00)"
    }
    
    // Format a duration as (MM:SS)
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "(%02d:%02d)", minutes, seconds)
    }
    
    // ... rest of the implementation
} 