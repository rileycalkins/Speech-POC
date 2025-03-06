import Foundation

/// A class to manage progress tracking for multi-segment operations
class ProgressManager: ObservableObject {
    @Published var segmentProgress: [Double]
    @Published var overallProgress: Double = 0.0
    
    private let numberOfSegments: Int
    private var segmentDurations: [TimeInterval] = []
    private var totalDuration: TimeInterval = 0.0
    
    /// Initialize with a fixed number of segments
    /// - Parameter segments: The number of segments to track
    init(segments: Int) {
        self.numberOfSegments = max(segments, 1)
        self.segmentProgress = Array(repeating: 0.0, count: self.numberOfSegments)
    }
    
    /// Set the durations for all segments
    /// - Parameter durations: Array of durations for each segment
    func setSegmentDurations(_ durations: [TimeInterval]) {
        segmentDurations = durations
        totalDuration = durations.reduce(0.0, +)
        calculateOverallProgress()
    }
    
    /// Update the progress for a specific segment
    /// - Parameters:
    ///   - index: The segment index
    ///   - progress: The progress value (0.0 to 1.0)
    func updateSegment(_ index: Int, progress: Double) {
        guard index >= 0 else { return }
        
        // Resize array if needed
        while segmentProgress.count <= index {
            segmentProgress.append(0.0)
        }
        
        segmentProgress[index] = min(max(progress, 0.0), 1.0)
        calculateOverallProgress()
    }
    
    /// Calculate the overall progress based on segment durations or simple count
    private func calculateOverallProgress() {
        // If we have duration data, weight by duration
        if !segmentDurations.isEmpty && totalDuration > 0 {
            var weightedProgress = 0.0
            
            for i in 0..<min(segmentProgress.count, segmentDurations.count) {
                let weight = segmentDurations[i] / totalDuration
                weightedProgress += segmentProgress[i] * weight
            }
            
            overallProgress = min(weightedProgress, 1.0)
        } else {
            // Otherwise use simple average
            let total = segmentProgress.reduce(0.0, +)
            overallProgress = total / Double(max(segmentProgress.count, 1))
        }
    }
    
    /// Reset all progress
    func reset(segments: Int? = nil) {
        if let segments = segments {
            self.segmentProgress = Array(repeating: 0.0, count: max(segments, 1))
        } else {
            self.segmentProgress = Array(repeating: 0.0, count: numberOfSegments)
        }
        overallProgress = 0.0
    }
} 