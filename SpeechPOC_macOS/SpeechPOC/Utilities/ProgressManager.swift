import SwiftUI
import Foundation
import Combine

/// Represents the state of a segment in the progress tracking
enum SegmentState {
    case pending
    case inProgress
    case completed
    case error
    
    var description: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }
}

/// A class to manage progress tracking for multi-segment operations
class ProgressManager: ObservableObject {
    @Published var segmentProgress: [Double]
    @Published var overallProgress: Double = 0.0
    @Published var segmentStates: [SegmentState] = []
    
    private let numberOfSegments: Int
    private var segmentDurations: [TimeInterval] = []
    private var totalDuration: TimeInterval = 0.0
    private var lastLogTime = Date()
    private let logThrottleInterval: TimeInterval = 2.0 // Log at most every 2 seconds
    
    /// Initialize with a fixed number of segments
    /// - Parameter segments: The number of segments to track
    init(segments: Int) {
        self.numberOfSegments = max(segments, 1)
        self.segmentProgress = Array(repeating: 0.0, count: self.numberOfSegments)
        self.segmentStates = Array(repeating: .pending, count: self.numberOfSegments)
    }
    
    /// Set the durations for all segments
    /// - Parameter durations: Array of durations for each segment
    func setSegmentDurations(_ durations: [TimeInterval]) {
        segmentDurations = durations
        totalDuration = durations.reduce(0.0, +)
        calculateOverallProgress()
        logProgressState()
    }
    
    /// Update the progress for a specific segment
    /// - Parameters:
    ///   - index: The segment index
    ///   - progress: The progress value (0.0 to 1.0)
    func updateSegment(_ index: Int, progress: Double) {
        guard index >= 0 else { return }
        
        // Resize arrays if needed
        while segmentProgress.count <= index {
            segmentProgress.append(0.0)
        }
        
        while segmentStates.count <= index {
            segmentStates.append(.pending)
        }
        
        // Update progress and state
        let boundedProgress = min(max(progress, 0.0), 1.0)
        segmentProgress[index] = boundedProgress
        
        // Update segment state based on progress
        if boundedProgress >= 0.99 {
            segmentStates[index] = .completed
        } else if boundedProgress > 0 {
            segmentStates[index] = .inProgress
        } else {
            segmentStates[index] = .pending
        }
        
        calculateOverallProgress()
        
        // Log progress state periodically to avoid console spam
        let now = Date()
        if now.timeIntervalSince(lastLogTime) >= logThrottleInterval {
            logProgressState()
            lastLogTime = now
        }
    }
    
    /// Set the state for a specific segment directly
    /// - Parameters:
    ///   - index: The segment index
    ///   - state: The new segment state
    func setSegmentState(_ index: Int, state: SegmentState) {
        guard index >= 0 else { return }
        
        // Resize arrays if needed
        while segmentStates.count <= index {
            segmentStates.append(.pending)
        }
        
        segmentStates[index] = state
        
        // Also update progress based on state
        if state == .completed {
            updateSegment(index, progress: 1.0)
        } else if state == .error {
            // Don't change progress on error
        } else if state == .pending {
            updateSegment(index, progress: 0.0)
        }
    }
    
    /// Get the state of a specific segment
    /// - Parameter index: The segment index
    /// - Returns: The state of the segment
    func getSegmentState(_ index: Int) -> SegmentState {
        guard index >= 0, index < segmentStates.count else {
            return .pending
        }
        return segmentStates[index]
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
        let segmentCount = segments ?? numberOfSegments
        self.segmentProgress = Array(repeating: 0.0, count: max(segmentCount, 1))
        self.segmentStates = Array(repeating: .pending, count: max(segmentCount, 1))
        self.overallProgress = 0.0
        logProgressState()
    }
    
    /// Mark all segments as completed
    func completeAll() {
        for i in 0..<segmentProgress.count {
            segmentProgress[i] = 1.0
            segmentStates[i] = .completed
        }
        overallProgress = 1.0
        logProgressState()
    }
    
    /// Log the current progress state
    private func logProgressState() {
        #if DEBUG
        var stateInfo = ""
        for i in 0..<segmentProgress.count {
            stateInfo += "Segment \(i+1): \(Int(segmentProgress[i] * 100))% (\(segmentStates[i].description)), "
        }
        print("🔧 ProgressManager: Overall \(Int(overallProgress * 100))% - \(stateInfo)")
        #endif
    }
} 
