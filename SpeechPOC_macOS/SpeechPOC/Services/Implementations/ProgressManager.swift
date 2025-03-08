import SwiftUI
import Foundation
import Combine

/// Implementation of ProgressTrackable that manages multi-segment progress tracking
class ProgressManager: ObservableObject, ProgressTrackable {
    /// Progress values for each segment (0.0 to 1.0)
    @Published var segmentProgress: [Double]
    
    /// Overall progress value (0.0 to 1.0)
    @Published var overallProgress: Double = 0.0
    
    /// Current state of each segment
    @Published var segmentStates: [SegmentState] = []
    
    /// The number of segments being tracked
    private let numberOfSegments: Int
    
    /// Durations for each segment, used for weighted progress calculation
    private var segmentDurations: [TimeInterval] = []
    
    /// Total duration of all segments
    private var totalDuration: TimeInterval = 0.0
    
    /// Last time a log message was emitted
    private var lastLogTime = Date()
    
    /// Throttle interval for logging (to avoid console spam)
    private let logThrottleInterval: TimeInterval = 2.0 // Log at most every 2 seconds
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.speechpoc", category: "ProgressManager")
    
    /// Initialize with a fixed number of segments
    /// - Parameter segments: The number of segments to track
    init(segments: Int) {
        self.numberOfSegments = max(segments, 1)
        self.segmentProgress = Array(repeating: 0.0, count: self.numberOfSegments)
        self.segmentStates = Array(repeating: .pending, count: self.numberOfSegments)
        
        logger.debug("Initialized progress manager with \(self.numberOfSegments) segments")
    }
    
    /// Set the durations for all segments
    /// - Parameter durations: Array of durations for each segment
    func setSegmentDurations(_ durations: [TimeInterval]) {
        segmentDurations = durations
        totalDuration = durations.reduce(0.0, +)
        calculateOverallProgress()
        
        logger.debug("Set segment durations: \(durations.map { String(format: "%.1f", $0) }.joined(separator: ", ")) (total: \(totalDuration)s)")
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
            logger.debug("Segment \(index + 1) marked as error")
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
    /// - Parameter segments: Optional new number of segments
    func reset(segments: Int) {
        let segmentCount = segments
        self.segmentProgress = Array(repeating: 0.0, count: max(segmentCount, 1))
        self.segmentStates = Array(repeating: .pending, count: max(segmentCount, 1))
        self.overallProgress = 0.0
        
        logger.debug("Reset progress manager with \(segmentCount) segments")
    }
    
    /// Reset with optional segment count
    /// - Parameter segments: Optional segment count (uses numberOfSegments if nil)
    func resetWithOptional(segments: Int? = nil) {
        reset(segments: segments ?? numberOfSegments)
    }
    
    /// Mark all segments as completed
    func completeAll() {
        for i in 0..<segmentProgress.count {
            segmentProgress[i] = 1.0
            segmentStates[i] = .completed
        }
        overallProgress = 1.0
        
        logger.debug("Marked all \(segmentProgress.count) segments as completed")
    }
    
    /// Log the current progress state
    private func logProgressState() {
        var stateInfo = ""
        for i in 0..<segmentProgress.count {
            stateInfo += "Segment \(i+1): \(Int(segmentProgress[i] * 100))% (\(segmentStates[i].description)), "
        }
        logger.debug("Overall \(Int(overallProgress * 100))% - \(stateInfo)")
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
        print("🔧 [\(category)] \(message)")
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